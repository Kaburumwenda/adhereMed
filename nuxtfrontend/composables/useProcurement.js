// ─────────────────────────────────────────────────────────────────────────
// useProcurement — shared data + derived analytics for the procurement
// (procure-to-pay) workspace.
//
// Loads the tenant's live procurement data from the existing REST surface:
//   /purchase-orders/orders/            purchase orders
//   /purchase-orders/grns/              goods received notes
//   /purchase-orders/rfqs/              requests for quotation
//   /purchase-orders/quotes/            supplier quotes
//   /purchase-orders/evaluations/       supplier evaluations
//   /purchase-orders/reorder-suggestions/  demand-driven requisitions
//   /purchase-orders/dashboard/         server-side KPI aggregate
//   /suppliers/                         supplier directory + price list
//
// Everything richer than the raw records (lead times, fill rates, savings,
// price benchmarking, concentration, purchase-price variance) is derived
// client-side so the workspace needs no bespoke backend service.
// ─────────────────────────────────────────────────────────────────────────
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'
import { num, sum, mean, median, stdDev, pctChange, safeDiv, round } from '~/utils/bi'

export const PO_STATUSES = [
  { value: 'draft', label: 'Draft', description: 'Not yet sent to the supplier', color: 'grey', icon: 'mdi-file-document-edit' },
  { value: 'sent', label: 'Sent', description: 'Issued to the supplier, awaiting delivery', color: 'info', icon: 'mdi-send-check' },
  { value: 'partial', label: 'Partially Received', description: 'Some lines delivered', color: 'warning', icon: 'mdi-progress-alert' },
  { value: 'received', label: 'Received', description: 'Fully delivered and booked in', color: 'success', icon: 'mdi-package-check' },
  { value: 'cancelled', label: 'Cancelled', description: 'Cancelled before fulfilment', color: 'error', icon: 'mdi-cancel' },
  { value: 'returned', label: 'Returned', description: 'Returned to the supplier', color: 'deep-orange', icon: 'mdi-undo-variant' }
]

export const RFQ_STATUSES = [
  { value: 'draft', label: 'Draft', color: 'grey' },
  { value: 'sent', label: 'Sent to Suppliers', color: 'info' },
  { value: 'quoted', label: 'Quotes Received', color: 'warning' },
  { value: 'awarded', label: 'Awarded', color: 'success' },
  { value: 'closed', label: 'Closed', color: 'grey' },
  { value: 'cancelled', label: 'Cancelled', color: 'error' }
]

/** Statuses that represent committed (non-cancelled) purchasing activity. */
const COMMITTED = ['sent', 'partial', 'received']
const OPEN_STATUSES = ['draft', 'sent', 'partial']

function daysBetween(a, b) {
  if (!a || !b) return null
  const d1 = new Date(a)
  const d2 = new Date(b)
  if (Number.isNaN(d1.getTime()) || Number.isNaN(d2.getTime())) return null
  return Math.round((d2 - d1) / 86400000)
}

function todayIso() {
  return new Date().toISOString().slice(0, 10)
}

export function useProcurement() {
  const { $api } = useNuxtApp()
  const branchStore = useBranchStore()
  const auth = useAuthStore()

  const loading = ref(false)
  const error = ref('')
  const lastLoaded = ref(null)

  const orders = ref([])
  const grns = ref([])
  const rfqs = ref([])
  const quotes = ref([])
  const evaluations = ref([])
  const suggestions = ref([])
  const suppliers = ref([])
  const serverKpis = ref({})

  const branchFilter = ref(null)
  const isBranchLocked = computed(() => auth.role === 'branch_admin')

  const branchFilterItems = computed(() => {
    if (isBranchLocked.value) {
      const b = branchStore.currentBranch
      return b ? [{ id: b.id, name: b.name }] : []
    }
    const items = branchStore.activeBranches.map((b) => ({ id: b.id, name: b.name }))
    items.unshift({ id: null, name: 'All Branches' })
    return items
  })

  const branchParam = computed(() => (branchFilter.value ? { branch: branchFilter.value } : {}))

  // ── helpers ─────────────────────────────────────────────────────────────
  const statusMeta = (s) => PO_STATUSES.find((x) => x.value === s) || { value: s, label: s, color: 'grey', icon: 'mdi-circle-medium' }

  /** Ordered quantity for a PO line list. */
  const orderedQty = (po) => sum(po.items || [], (it) => it.qty)
  /** Received quantity for a PO, from its GRNs. */
  const receivedQty = (po) => sum((po.grns || []).flatMap((g) => g.items_received || []), (it) => it.qty ?? it.quantity)

  /** PO value including shipping (landed). */
  const landedCost = (po) => num(po.total_cost) + num(po.shipping_cost)

  /** Receipt date = latest GRN received_date. */
  const receivedDate = (po) => {
    const dates = (po.grns || []).map((g) => g.received_date).filter(Boolean).sort()
    return dates.length ? dates[dates.length - 1] : null
  }

  /** Lead time in days from order date to complete receipt. */
  const leadTime = (po) => {
    const rd = receivedDate(po)
    if (!rd) return null
    return daysBetween(po.order_date, rd)
  }

  // ── derived: enriched order rows ────────────────────────────────────────
  const ordersEnriched = computed(() =>
    orders.value.map((po) => {
      const ordered = orderedQty(po)
      const received = receivedQty(po)
      const isOpen = OPEN_STATUSES.includes(po.status)
      const expected = po.expected_delivery
      const overdueDays = isOpen && expected ? daysBetween(expected, todayIso()) : 0
      return {
        ...po,
        orderedQty: ordered,
        receivedQty: received,
        fillRate: ordered ? clamp100((received / ordered) * 100) : 0,
        landedCost: landedCost(po),
        leadTimeDays: leadTime(po),
        receivedDate: receivedDate(po),
        isOpen,
        overdue: overdueDays > 0,
        overdueDays: overdueDays > 0 ? overdueDays : 0,
        daysToDelivery: isOpen && expected ? daysBetween(todayIso(), expected) : null,
        grnCount: (po.grns || []).length,
        statusLabel: statusMeta(po.status).label,
        statusColor: statusMeta(po.status).color
      }
    })
  )

  const openOrders = computed(() => ordersEnriched.value.filter((o) => o.isOpen))
  const overdueOrders = computed(() => ordersEnriched.value.filter((o) => o.overdue))
  const committedOrders = computed(() => ordersEnriched.value.filter((o) => COMMITTED.includes(o.status)))
  const receivedOrders = computed(() => ordersEnriched.value.filter((o) => o.status === 'received'))
  const draftOrders = computed(() => ordersEnriched.value.filter((o) => o.status === 'draft'))

  // ── headline measures ──────────────────────────────────────────────────
  const totalSpend = computed(() => sum(committedOrders.value, (o) => o.landedCost))
  const committedSpend = computed(() => sum(openOrders.value, (o) => o.landedCost))
  const avgOrderValue = computed(() => (committedOrders.value.length ? totalSpend.value / committedOrders.value.length : 0))
  const shippingSpend = computed(() => sum(committedOrders.value, (o) => o.shipping_cost))
  const shippingShare = computed(() => (totalSpend.value ? (shippingSpend.value / totalSpend.value) * 100 : 0))

  const totalOrderedUnits = computed(() => sum(ordersEnriched.value, (o) => o.orderedQty))
  const totalReceivedUnits = computed(() => sum(ordersEnriched.value, (o) => o.receivedQty))
  const fillRate = computed(() => (totalOrderedUnits.value ? (totalReceivedUnits.value / totalOrderedUnits.value) * 100 : 0))

  const leadTimes = computed(() => ordersEnriched.value.map((o) => o.leadTimeDays).filter((d) => d != null && d >= 0))
  const avgLeadTime = computed(() => (leadTimes.value.length ? mean(leadTimes.value) : 0))
  const medianLeadTime = computed(() => (leadTimes.value.length ? median(leadTimes.value) : 0))
  const leadTimeSpread = computed(() => (leadTimes.value.length > 1 ? stdDev(leadTimes.value) : 0))

  /** On-time delivery rate: receipt on or before the promised date. */
  const onTimeDeliveries = computed(() =>
    ordersEnriched.value.filter((o) => {
      if (!o.receivedDate || !o.expected_delivery) return false
      return daysBetween(o.expected_delivery, o.receivedDate) <= 0
    })
  )
  const onTimeRate = computed(() => {
    const measurable = ordersEnriched.value.filter((o) => o.receivedDate && o.expected_delivery)
    return measurable.length ? (onTimeDeliveries.value.length / measurable.length) * 100 : 0
  })

  const cycleTime = computed(() => {
    const rows = rfqs.value
      .filter((r) => r.awarded_po && r.created_at)
      .map((r) => daysBetween(r.created_at, r.responded_at || r.updated_at || r.created_at))
      .filter((d) => d != null)
    return rows.length ? mean(rows) : 0
  })

  /** Month-over-month spend movement. */
  const spendDelta = computed(() => {
    const cur = monthlySpend.value
    if (cur.length < 2) return null
    return pctChange(cur[cur.length - 1].total, cur[cur.length - 2].total)
  })

  // ── spend series ────────────────────────────────────────────────────────
  const monthlySpend = computed(() => {
    const months = 12
    const base = new Date()
    base.setDate(1)
    const buckets = []
    for (let i = months - 1; i >= 0; i--) {
      const d = new Date(base.getFullYear(), base.getMonth() - i, 1)
      buckets.push({
        y: d.getFullYear(),
        m: d.getMonth(),
        label: d.toLocaleDateString(undefined, { month: 'short', year: '2-digit' }),
        total: 0,
        orders: 0,
        shipping: 0
      })
    }
    const idx = new Map(buckets.map((b, i) => [`${b.y}-${b.m}`, i]))
    for (const o of committedOrders.value) {
      const d = new Date(o.order_date || o.created_at || 0)
      if (Number.isNaN(d.getTime())) continue
      const i = idx.get(`${d.getFullYear()}-${d.getMonth()}`)
      if (i == null) continue
      buckets[i].total += o.landedCost
      buckets[i].orders += 1
      buckets[i].shipping += num(o.shipping_cost)
    }
    return buckets
  })

  const monthlySpendValues = computed(() => monthlySpend.value.map((b) => b.total))
  const monthlySpendLabels = computed(() => monthlySpend.value.map((b) => b.label))

  // ── supplier analytics ──────────────────────────────────────────────────
  const supplierRows = computed(() => {
    const map = new Map()
    const ensure = (name) => {
      if (!map.has(name)) {
        map.set(name, {
          name,
          orders: 0,
          spend: 0,
          shipping: 0,
          openOrders: 0,
          lateOrders: 0,
          measurable: 0,
          onTime: 0,
          leadTimes: [],
          fillRates: [],
          lastOrder: null,
          items: 0
        })
      }
      return map.get(name)
    }

    for (const o of ordersEnriched.value) {
      const row = ensure(o.supplier_name || 'Unassigned')
      row.orders += 1
      if (COMMITTED.includes(o.status)) row.spend += o.landedCost
      row.shipping += num(o.shipping_cost)
      if (o.isOpen) row.openOrders += 1
      if (o.receivedDate && o.expected_delivery) {
        row.measurable += 1
        if (daysBetween(o.expected_delivery, o.receivedDate) <= 0) row.onTime += 1
      }
      if (o.overdue) row.lateOrders += 1
      if (o.leadTimeDays != null) row.leadTimes.push(o.leadTimeDays)
      if (o.orderedQty) row.fillRates.push(o.fillRate)
      const d = o.order_date || o.created_at
      if (d && (!row.lastOrder || new Date(d) > new Date(row.lastOrder))) row.lastOrder = d
    }

    for (const s of suppliers.value) {
      const row = ensure(s.name)
      row.items = (s.items || []).length
      row.paymentTerms = s.payment_terms
      row.supplierId = s.id
      row.isActive = s.is_active
    }

    const total = sum([...map.values()], (r) => r.spend) || 1
    return [...map.values()]
      .map((r) => ({
        ...r,
        share: (r.spend / total) * 100,
        avgLeadTime: r.leadTimes.length ? mean(r.leadTimes) : null,
        avgFillRate: r.fillRates.length ? mean(r.fillRates) : null,
        onTimeRate: r.measurable ? (r.onTime / r.measurable) * 100 : null,
        avgOrderValue: r.orders ? r.spend / r.orders : 0,
        // Composite performance score (0–100) used by the scorecards page.
        score: scoreSupplier(r),
        risk: riskSupplier(r)
      }))
      .sort((a, b) => b.spend - a.spend)
  })

  function scoreSupplier(r) {
    const parts = []
    if (r.onTimeRate != null) parts.push(r.onTimeRate)
    if (r.avgFillRate != null) parts.push(r.avgFillRate)
    if (r.avgLeadTime != null) parts.push(clamp100(100 - r.avgLeadTime * 1.2))
    if (!parts.length) return null
    return round(mean(parts), 1)
  }

  function riskSupplier(r) {
    let risk = 0
    if (r.onTimeRate != null && r.onTimeRate < 80) risk += 2
    if (r.avgFillRate != null && r.avgFillRate < 90) risk += 2
    if (r.openOrders > 3) risk += 1
    if (r.lateOrders > 0) risk += 1
    return risk >= 3 ? 'high' : risk >= 2 ? 'medium' : 'low'
  }

  const supplierConcentration = computed(() => {
    const rows = [...supplierRows.value].sort((a, b) => b.spend - a.spend)
    const total = sum(rows, (r) => r.spend) || 1
    let cum = 0
    return rows.map((r) => {
      cum += r.spend
      return { ...r, cumShare: (cum / total) * 100 }
    })
  })

  /** Herfindahl-Hirschman index scaled 0–100 (higher = more concentrated). */
  const hhi = computed(() => {
    const total = sum(supplierRows.value, (r) => r.spend) || 1
    return sum(supplierRows.value, (r) => ((r.spend / total) * 100) ** 2)
  })

  // ── quote / RFQ analytics ───────────────────────────────────────────────
  const rfqEnriched = computed(() =>
    rfqs.value.map((r) => {
      const rq = quotes.value.filter((q) => q.rfq === r.id)
      const prices = rq.map((q) => num(q.total_cost)).filter((v) => v > 0)
      const best = prices.length ? Math.min(...prices) : null
      const worst = prices.length ? Math.max(...prices) : null
      const avg = prices.length ? mean(prices) : null
      const awarded = rq.find((q) => q.status === 'awarded')
      const savings = best != null && worst != null && rq.length > 1 ? worst - best : 0
      const savingsPct = worst ? (savings / worst) * 100 : 0
      const cycleDays = daysBetween(r.created_at, r.awarded_at || (awarded ? awarded.submitted_at : null))
      const dueIn = r.response_deadline ? daysBetween(todayIso(), r.response_deadline) : null
      return {
        ...r,
        quoteCount: rq.length,
        quotes: rq,
        best,
        worst,
        avg,
        spread: best != null && worst != null ? worst - best : 0,
        spreadPct: worst ? ((worst - best) / worst) * 100 : 0,
        savings,
        savingsPct,
        awardedQuote: awarded,
        cycleDays,
        dueIn,
        expired: dueIn != null && dueIn < 0 && !['awarded', 'closed', 'cancelled'].includes(r.status)
      }
    })
  )

  const openRfqs = computed(() => rfqEnriched.value.filter((r) => !['awarded', 'closed', 'cancelled'].includes(r.status)))
  const awardedRfqs = computed(() => rfqEnriched.value.filter((r) => r.status === 'awarded'))
  const rfqSavings = computed(() => sum(awardedRfqs.value, (r) => r.savings))
  /** Identified savings on all RFQs that received competing quotes. */
  const identifiedSavings = computed(() => sum(rfqEnriched.value, (r) => r.savings))

  const quoteRows = computed(() =>
    quotes.value.map((q) => {
      const rfq = rfqs.value.find((r) => r.id === q.rfq)
      const siblings = quotes.value.filter((x) => x.rfq === q.rfq)
      const prices = siblings.map((x) => num(x.total_cost)).filter((v) => v > 0)
      const best = prices.length ? Math.min(...prices) : null
      const avg = prices.length ? mean(prices) : null
      return {
        ...q,
        rfqNumber: rfq?.rfq_number || `RFQ #${q.rfq}`,
        rfqTitle: rfq?.title || '',
        competitorCount: siblings.length,
        best,
        avg,
        // How the quote compares to the peer average (+ = more expensive)
        varianceVsAvg: avg ? num(q.total_cost) - avg : null,
        variancePct: avg ? (num(q.total_cost) / avg - 1) * 100 : null,
        isLowest: best != null && num(q.total_cost) === best,
        validUntil: q.valid_until || null,
        expired: q.valid_until ? daysBetween(q.valid_until, todayIso()) > 0 : false
      }
    })
  )

  const bestQuotes = computed(() => quoteRows.value.filter((q) => q.isLowest))

  // ── price benchmarking (supplier item price lists) ──────────────────────
  const priceBenchmarks = computed(() => {
    const map = new Map()
    for (const s of suppliers.value) {
      for (const it of s.items || []) {
        const key = String(it.item_name || '').trim().toLowerCase()
        if (!key) continue
        if (!map.has(key)) {
          map.set(key, { item: it.item_name, offers: [], stockId: it.stock || null })
        }
        const entry = map.get(key)
        entry.offers.push({
          supplier: s.name,
          supplierId: s.id,
          unitCost: num(it.unit_cost),
          unitPrice: num(it.unit_price),
          quantity: num(it.quantity),
          notes: it.notes || ''
        })
      }
    }
    return [...map.values()]
      .map((e) => {
        const costs = e.offers.map((o) => o.unitCost).filter((c) => c > 0)
        const best = costs.length ? Math.min(...costs) : null
        const worst = costs.length ? Math.max(...costs) : null
        const avg = costs.length ? mean(costs) : null
        const savingPerUnit = best != null && worst != null ? worst - best : 0
        return {
          ...e,
          supplierCount: e.offers.length,
          best,
          worst,
          avg,
          spreadPct: worst ? ((worst - best) / worst) * 100 : 0,
          savingPerUnit,
          bestSupplier: e.offers.find((o) => o.unitCost === best)?.supplier || null,
          worstSupplier: e.offers.find((o) => o.unitCost === worst)?.supplier || null,
          offers: e.offers.sort((a, b) => (a.unitCost || Infinity) - (b.unitCost || Infinity))
        }
      })
      .sort((a, b) => b.savingPerUnit - a.savingPerUnit)
  })

  /** Annualised opportunity from buying every dual+ sourced item at best price. */
  const priceSavingOpportunity = computed(() => {
    let total = 0
    for (const p of priceBenchmarks.value) {
      if (p.supplierCount < 2 || !p.savingPerUnit) continue
      const monthlyUsage = sum(p.offers, (o) => o.quantity) || 0
      total += p.savingPerUnit * monthlyUsage * 12
    }
    return total
  })

  const multiSourced = computed(() => priceBenchmarks.value.filter((p) => p.supplierCount > 1))
  const singleSourced = computed(() => priceBenchmarks.value.filter((p) => p.supplierCount === 1))

  // ── requisitions / reorder suggestions ──────────────────────────────────
  const requisitions = computed(() =>
    suggestions.value.map((r) => {
      const gap = Math.max(0, num(r.reorder_level) - num(r.current_quantity))
      const qty = num(r.suggested_quantity)
      const coverageMonths = num(r.current_quantity) > 0 ? num(r.current_quantity) / Math.max(1, qty / 3) : 0
      return {
        ...r,
        itemName: r.stock_name || r.stock?.medication_name || r.medication_name || `Stock #${r.stock}`,
        gap,
        qty,
        estimatedCost: num(r.estimated_cost) || qty * num(r.last_unit_cost),
        unitCost: num(r.last_unit_cost),
        urgency: gap > 0 && num(r.current_quantity) <= 0 ? 'critical' : gap > num(r.reorder_level) * 0.5 ? 'high' : 'normal',
        coverageMonths: round(coverageMonths, 1)
      }
    })
  )

  const pendingRequisitions = computed(() => requisitions.value.filter((r) => r.status === 'pending'))
  const requisitionValue = computed(() => sum(pendingRequisitions.value, (r) => r.estimatedCost))

  // ── approvals (value-based routing over draft POs) ──────────────────────
  const approvalThreshold = ref(0)
  if (import.meta.client) {
    const stored = Number(localStorage.getItem('procurement.approvalThreshold') || 0)
    if (stored > 0) approvalThreshold.value = stored
  }
  function setApprovalThreshold(v) {
    approvalThreshold.value = Math.max(0, num(v))
    if (import.meta.client) localStorage.setItem('procurement.approvalThreshold', String(approvalThreshold.value))
  }

  const approvalQueue = computed(() =>
    draftOrders.value
      .map((o) => ({
        ...o,
        band: approvalBand(o.landedCost),
        requiresApproval: approvalThreshold.value > 0 && o.landedCost >= approvalThreshold.value,
        waitingDays: daysBetween(o.order_date || o.created_at, todayIso()) || 0
      }))
      .sort((a, b) => b.landedCost - a.landedCost)
  )

  function approvalBand(value) {
    const t = approvalThreshold.value || 50000
    if (num(value) >= t * 4) return { label: 'Executive', color: 'error', level: 3 }
    if (num(value) >= t * 2) return { label: 'Finance Director', color: 'warning', level: 2 }
    return { label: 'Procurement Manager', color: 'info', level: 1 }
  }

  // ── returns to vendor ───────────────────────────────────────────────────
  /** POs that have synced, received lines — candidates for return. */
  const returnableOrders = computed(() =>
    ordersEnriched.value.filter((o) =>
      ['received', 'partial'].includes(o.status) &&
      (o.items || []).some((it) => it._synced && !it._returned)
    )
  )
  const returnedOrders = computed(() => ordersEnriched.value.filter((o) => o.status === 'returned'))

  // ── receiving (GRN) analytics ──────────────────────────────────────────
  const grnRows = computed(() =>
    grns.value.map((g) => {
      const po = orders.value.find((o) => o.id === g.purchase_order)
      const qty = sum(g.items_received || [], (it) => it.qty ?? it.quantity)
      return {
        ...g,
        poNumber: po?.po_number || `PO #${g.purchase_order}`,
        supplierName: po?.supplier_name || '—',
        lineCount: (g.items_received || []).length,
        qty,
        value: qty && po ? qty * safeDiv(num(po.total_cost), orderedQty(po) || 1) : 0
      }
    })
  )

  const grnMonthly = computed(() => {
    const buckets = new Map()
    for (let i = 11; i >= 0; i--) {
      const d = new Date()
      d.setDate(1)
      const b = new Date(d.getFullYear(), d.getMonth() - i, 1)
      buckets.set(`${b.getFullYear()}-${b.getMonth()}`, {
        label: b.toLocaleDateString(undefined, { month: 'short', year: '2-digit' }),
        receipts: 0,
        qty: 0
      })
    }
    for (const g of grnRows.value) {
      const d = new Date(g.received_date || 0)
      if (Number.isNaN(d.getTime())) continue
      const b = buckets.get(`${d.getFullYear()}-${d.getMonth()}`)
      if (!b) continue
      b.receipts += 1
      b.qty += g.qty
    }
    return [...buckets.values()]
  })

  // ── delivery performance ────────────────────────────────────────────────
  const deliveryRows = computed(() =>
    ordersEnriched.value
      .filter((o) => o.expected_delivery)
      .map((o) => {
        const variance = o.receivedDate ? daysBetween(o.expected_delivery, o.receivedDate) : null
        return {
          ...o,
          varianceDays: variance,
          onTime: variance != null ? variance <= 0 : null,
          status: variance == null ? (o.overdue ? 'overdue' : 'in_transit') : variance <= 0 ? 'on_time' : 'late'
        }
      })
  )

  const overdueBySupplier = computed(() => {
    const map = new Map()
    for (const o of overdueOrders.value) {
      const key = o.supplier_name || 'Unassigned'
      if (!map.has(key)) map.set(key, { name: key, count: 0, value: 0, maxDays: 0, orders: [] })
      const row = map.get(key)
      row.count += 1
      row.value += o.landedCost
      row.maxDays = Math.max(row.maxDays, o.overdueDays)
      row.orders.push({ id: o.id, poNumber: o.po_number, days: o.overdueDays, value: o.landedCost })
    }
    return [...map.values()].sort((a, b) => b.value - a.value)
  })

  const otifRate = computed(() => {
    // On-time-in-full: received on/before promise AND fill rate >= 98%
    const measurable = ordersEnriched.value.filter((o) => o.receivedDate && o.expected_delivery)
    if (!measurable.length) return 0
    const ok = measurable.filter(
      (o) => daysBetween(o.expected_delivery, o.receivedDate) <= 0 && o.fillRate >= 98
    )
    return (ok.length / measurable.length) * 100
  })

  // ── supplier evaluations ───────────────────────────────────────────────
  const evaluationRows = computed(() =>
    evaluations.value.map((e) => ({
      ...e,
      supplierName: e.supplier_name || suppliers.value.find((s) => s.id === e.supplier)?.name || `Supplier #${e.supplier}`,
      rating: num(e.overall_rating)
    }))
  )

  const latestEvaluationBySupplier = computed(() => {
    const map = new Map()
    for (const e of [...evaluationRows.value].sort((a, b) => new Date(b.evaluation_date) - new Date(a.evaluation_date))) {
      if (!map.has(e.supplierName)) map.set(e.supplierName, e)
    }
    return map
  })

  const evaluationDimensions = computed(() => {
    const rows = evaluationRows.value
    if (!rows.length) return []
    const dims = [
      { key: 'on_time_delivery_score', label: 'On-time delivery', icon: 'mdi-truck-check-outline' },
      { key: 'quality_score', label: 'Quality', icon: 'mdi-certificate-outline' },
      { key: 'responsiveness_score', label: 'Responsiveness', icon: 'mdi-message-reply-outline' },
      { key: 'pricing_competitiveness', label: 'Pricing', icon: 'mdi-currency-usd' },
      { key: 'payment_flexibility', label: 'Payment terms', icon: 'mdi-calendar-clock' }
    ]
    const total = rows.length
    return dims.map((d) => {
      const avg = mean(rows.map((r) => num(r[d.key])))
      return { ...d, avg: round(avg, 2), pct: (avg / 5) * 100 }
    })
  })

  // ── exceptions / alerts ────────────────────────────────────────────────
  const alerts = computed(() => {
    const out = []
    for (const o of overdueOrders.value.slice(0, 8)) {
      out.push({
        severity: o.overdueDays > 14 ? 'high' : 'medium',
        icon: 'mdi-truck-alert',
        title: `${o.po_number} is ${o.overdueDays} day${o.overdueDays === 1 ? '' : 's'} overdue`,
        detail: `${o.supplier_name} · ${formatMoney(o.landedCost)} scheduled for ${o.expected_delivery}`,
        to: `/ims/purchase-orders/${o.id}`
      })
    }
    for (const r of rfqEnriched.value.filter((x) => x.expired).slice(0, 4)) {
      out.push({
        severity: 'medium',
        icon: 'mdi-calendar-alert',
        title: `${r.rfq_number} response deadline has passed`,
        detail: `${r.title} · ${r.quoteCount} quote${r.quoteCount === 1 ? '' : 's'} received`,
        to: `/ims/purchase-orders/rfqs/${r.id}`
      })
    }
    for (const q of quoteRows.value.filter((x) => x.expired && !x.isLowest).slice(0, 3)) {
      out.push({
        severity: 'low',
        icon: 'mdi-file-clock-outline',
        title: `Quote from ${q.supplier_name} has expired`,
        detail: `${q.rfqNumber} · valid until ${q.valid_until}`,
        to: `/ims/purchase-orders/quote-comparison`
      })
    }
    for (const s of supplierRows.value.filter((x) => x.risk === 'high').slice(0, 4)) {
      out.push({
        severity: 'high',
        icon: 'mdi-shield-alert-outline',
        title: `${s.name} flagged as high risk`,
        detail: `${s.orders} orders · ${s.onTimeRate == null ? 'no delivery history' : `${s.onTimeRate.toFixed(0)}% on-time`}`,
        to: `/ims/purchase-orders/scorecards`
      })
    }
    return out
  })

  // ── sourcing / risk scores ──────────────────────────────────────────────
  const supplyRiskIndex = computed(() => {
    let risk = 0
    if (hhi.value > 2500) risk += 35
    else if (hhi.value > 1500) risk += 18
    if (onTimeRate.value && onTimeRate.value < 85) risk += 25
    if (fillRate.value && fillRate.value < 92) risk += 20
    if (overdueOrders.value.length > 3) risk += 15
    if (singleSourced.value.length > multiSourced.value.length) risk += 15
    return clamp100(risk)
  })

  // ── do the maths helpers ────────────────────────────────────────────────
  function clamp100(v) {
    return Math.max(0, Math.min(100, num(v)))
  }

  // ── load ───────────────────────────────────────────────────────────────
  const safeList = (path, params = {}) =>
    $api
      .get(path, { params })
      .then((r) => r.data?.results || (Array.isArray(r.data) ? r.data : []))
      .catch(() => [])

  async function load() {
    loading.value = true
    error.value = ''
    if (isBranchLocked.value && branchStore.currentBranchId) branchFilter.value = branchStore.currentBranchId
    const params = branchParam.value
    try {
      const [po, gr, rfq, q, ev, sg, sup, dash] = await Promise.all([
        safeList('/purchase-orders/orders/', { ...params, page_size: 500 }),
        safeList('/purchase-orders/grns/', { ...params, page_size: 500 }),
        safeList('/purchase-orders/rfqs/', { ...params, page_size: 300 }),
        safeList('/purchase-orders/quotes/', { ...params, page_size: 500 }),
        safeList('/purchase-orders/evaluations/', { ...params, page_size: 300 }),
        safeList('/purchase-orders/reorder-suggestions/', { ...params, page_size: 300 }),
        safeList('/suppliers/', { page_size: 300 }),
        $api.get('/purchase-orders/dashboard/', { params }).then((r) => r.data || {}).catch(() => ({}))
      ])
      orders.value = po
      grns.value = gr
      rfqs.value = rfq
      quotes.value = q
      evaluations.value = ev
      suggestions.value = sg
      suppliers.value = sup
      serverKpis.value = dash
      lastLoaded.value = new Date()
    } catch (e) {
      error.value = e?.message || 'Failed to load procurement data'
    } finally {
      loading.value = false
    }
  }

  watch(branchFilter, () => load())
  onMounted(load)

  return {
    // state
    loading, error, lastLoaded,
    orders, ordersEnriched, grns, grnRows, rfqs, rfqEnriched, quotes, quoteRows,
    evaluations, evaluationRows, latestEvaluationBySupplier, evaluationDimensions,
    suggestions, requisitions, suppliers, serverKpis,
    branchFilter, branchFilterItems, isBranchLocked,
    // measures
    totalSpend, committedSpend, avgOrderValue, shippingSpend, shippingShare,
    openOrders, overdueOrders, committedOrders, receivedOrders, draftOrders,
    totalOrderedUnits, totalReceivedUnits, fillRate,
    avgLeadTime, medianLeadTime, leadTimeSpread,
    onTimeRate, otifRate, cycleTime, spendDelta,
    monthlySpend, monthlySpendValues, monthlySpendLabels,
    supplierRows, supplierConcentration, hhi, supplyRiskIndex,
    openRfqs, awardedRfqs, rfqSavings, identifiedSavings, bestQuotes,
    priceBenchmarks, priceSavingOpportunity, multiSourced, singleSourced,
    pendingRequisitions, requisitionValue,
    approvalThreshold, setApprovalThreshold, approvalQueue, approvalBand,
    returnableOrders, returnedOrders,
    deliveryRows, overdueBySupplier, grnMonthly, alerts,
    // helpers
    statusMeta, leadTime, receivedDate, orderedQty, receivedQty, landedCost, load
  }
}

/** Small local currency formatter so the composable stays dependency-light. */
function formatMoney(v) {
  const n = num(v)
  return `KES ${n.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
