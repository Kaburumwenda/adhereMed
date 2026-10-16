// ─────────────────────────────────────────────────────────────────────────
// useBiData — shared data + derived analytics layer for the BI workspace.
//
// Loads the tenant's live operational data (POS transactions, stock on hand
// and the inventory overview snapshot) and exposes date-range controls plus
// the descriptive/diagnostic/predictive series every BI page needs. Keeping
// this in one composable guarantees the 8 BI screens stay consistent and
// avoids duplicating the (fairly large) range-resolution logic.
// ─────────────────────────────────────────────────────────────────────────
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'
import {
  BI_MONTHS, num, sum, mean, pctChange,
  monthlyBuckets, productRollup, abcClass, xyzClass, rfmSegments,
  marketBasket, seasonalProfile, trendForecast, driverRanking, anomalies
} from '~/utils/bi'

export const BI_RANGE_OPTIONS = [
  { key: '30d', label: 'Last 30 days', days: 30 },
  { key: '90d', label: 'Last 90 days', days: 90 },
  { key: '6m', label: 'Last 6 months', days: 182 },
  { key: '12m', label: 'Last 12 months', days: 365 },
  { key: 'qtd', label: 'Quarter to date' },
  { key: 'ytd', label: 'Year to date' },
  { key: 'lastYear', label: 'Last year' },
  { key: 'custom', label: 'Custom range…' }
]

function startOfDay(d) {
  const x = new Date(d)
  x.setHours(0, 0, 0, 0)
  return x
}
function addDays(d, n) {
  const x = new Date(d)
  x.setDate(x.getDate() + n)
  return x
}

export function useBiData({ defaultRange = '12m' } = {}) {
  const { $api } = useNuxtApp()
  const branchStore = useBranchStore()
  const auth = useAuthStore()
  const route = useRoute()

  const isBranchLocked = computed(() => auth.role === 'branch_admin')

  // ── namespace base (works under /ims, /pharmacy and the bare /analytics) ─
  const biBase = computed(() => {
    const p = route.path || ''
    if (p.startsWith('/ims')) return '/ims/analytics/bi'
    if (p.startsWith('/pharmacy')) return '/pharmacy/analytics/bi'
    return '/analytics/bi'
  })

  // ── state ───────────────────────────────────────────────────────────────
  const loading = ref(false)
  const error = ref('')
  const transactions = ref([])
  const stocks = ref([])
  const overview = ref({})

  const rangeKey = ref(defaultRange)
  const branchFilter = ref(null)
  const customDialog = ref(false)
  const customStart = ref('')
  const customEnd = ref('')
  const customRange = ref(null)

  // Monthly sales target — persisted per browser so the "vs target" KPIs and
  // the root-cause / forecast pages can quantify the gap.
  const monthlyTarget = ref(0)
  if (import.meta.client) {
    const stored = Number(localStorage.getItem('bi.monthlyTarget') || 0)
    if (stored > 0) monthlyTarget.value = stored
  }
  function setMonthlyTarget(v) {
    monthlyTarget.value = Math.max(0, num(v))
    if (import.meta.client) localStorage.setItem('bi.monthlyTarget', String(monthlyTarget.value))
  }

  // ── range resolution ────────────────────────────────────────────────────
  function resolveRange(key) {
    const today = startOfDay(new Date())
    const tomorrow = addDays(today, 1)
    switch (key) {
      case '30d': return { start: addDays(today, -29), end: tomorrow, label: 'Last 30 days' }
      case '90d': return { start: addDays(today, -89), end: tomorrow, label: 'Last 90 days' }
      case '6m': return { start: addDays(today, -182), end: tomorrow, label: 'Last 6 months' }
      case '12m': return { start: addDays(today, -364), end: tomorrow, label: 'Last 12 months' }
      case 'qtd': {
        const q = Math.floor(today.getMonth() / 3) * 3
        return { start: new Date(today.getFullYear(), q, 1), end: tomorrow, label: 'Quarter to date' }
      }
      case 'ytd': return { start: new Date(today.getFullYear(), 0, 1), end: tomorrow, label: 'Year to date' }
      case 'lastYear': {
        const s = new Date(today.getFullYear() - 1, 0, 1)
        const e = new Date(today.getFullYear(), 0, 1)
        return { start: s, end: e, label: 'Last year' }
      }
      case 'custom':
        return customRange.value || { start: addDays(today, -364), end: tomorrow, label: 'Custom range' }
      default: return { start: addDays(today, -364), end: tomorrow, label: 'Last 12 months' }
    }
  }

  const activeRange = computed(() => resolveRange(rangeKey.value))
  const cutoff = computed(() => activeRange.value.start)
  const cutoffEnd = computed(() => activeRange.value.end)
  const rangeLabel = computed(() => activeRange.value.label)
  const rangeDays = computed(() => Math.max(1, Math.round((cutoffEnd.value - cutoff.value) / 86400000)))
  const cutoffPrev = computed(() => addDays(cutoff.value, -rangeDays.value))

  function onRangeChange(val) {
    if (val === 'custom') {
      if (!customStart.value) customStart.value = cutoff.value.toISOString().slice(0, 10)
      if (!customEnd.value) customEnd.value = addDays(cutoffEnd.value, -1).toISOString().slice(0, 10)
      customDialog.value = true
    }
  }
  function applyCustom() {
    const s = startOfDay(new Date(customStart.value))
    const e = addDays(startOfDay(new Date(customEnd.value)), 1)
    if (e <= s) return
    const fmt = (d) => d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
    customRange.value = { start: s, end: e, label: `${fmt(s)} – ${fmt(addDays(e, -1))}` }
    rangeKey.value = 'custom'
    customDialog.value = false
  }

  const branchFilterItems = computed(() => {
    if (isBranchLocked.value) {
      const b = branchStore.currentBranch
      return b ? [{ id: b.id, name: b.name }] : []
    }
    const items = branchStore.activeBranches.map((b) => ({ id: b.id, name: b.name }))
    items.unshift({ id: null, name: 'All Branches' })
    return items
  })

  // ── filtered windows ────────────────────────────────────────────────────
  const inRange = computed(() =>
    transactions.value.filter((t) => {
      const d = new Date(t.created_at || t.date || 0)
      if (d < cutoff.value || d >= cutoffEnd.value) return false
      if (branchFilter.value != null && t.branch !== branchFilter.value) return false
      return true
    })
  )
  const inPrevRange = computed(() =>
    transactions.value.filter((t) => {
      const d = new Date(t.created_at || t.date || 0)
      if (d < cutoffPrev.value || d >= cutoff.value) return false
      if (branchFilter.value != null && t.branch !== branchFilter.value) return false
      return true
    })
  )

  // ── headline measures ──────────────────────────────────────────────────
  const revenue = computed(() => sum(inRange.value, (t) => t.total ?? t.total_amount))
  const prevRevenue = computed(() => sum(inPrevRange.value, (t) => t.total ?? t.total_amount))
  const revenueDelta = computed(() => pctChange(revenue.value, prevRevenue.value))
  const orders = computed(() => inRange.value.length)
  const prevOrders = computed(() => inPrevRange.value.length)
  const ordersDelta = computed(() => pctChange(orders.value, prevOrders.value))
  const aov = computed(() => (orders.value ? revenue.value / orders.value : 0))
  const prevAov = computed(() => (prevOrders.value ? prevRevenue.value / prevOrders.value : 0))
  const aovDelta = computed(() => pctChange(aov.value, prevAov.value))
  const unitsSold = computed(() => sum(inRange.value.flatMap((t) => t.items || []), (it) => it.quantity || 1))
  const customers = computed(() => {
    const s = new Set(inRange.value.map((t) => String(t.customer_name || '').trim().toLowerCase()).filter((n) => n && n !== 'walk-in'))
    return s.size
  })

  // Inventory-based measures
  const inventoryCost = computed(() => sum(stocks.value, (s) => num(s.cost_price) * num(s.total_quantity ?? s.quantity)))
  const inventoryRetail = computed(() => sum(stocks.value, (s) => num(s.selling_price) * num(s.total_quantity ?? s.quantity)))
  const unitsOnHand = computed(() => sum(stocks.value, (s) => s.total_quantity ?? s.quantity))
  const lowStock = computed(() =>
    stocks.value
      .filter((s) => {
        const q = num(s.total_quantity ?? s.quantity)
        const r = num(s.reorder_level)
        return q <= 0 || (r > 0 && q <= r)
      })
      .sort((a, b) => num(a.total_quantity ?? a.quantity) - num(b.total_quantity ?? b.quantity))
  )
  const expiring = computed(() => {
    const soon = addDays(new Date(), 90)
    return stocks.value
      .filter((s) => s.expiry_date && new Date(s.expiry_date) <= soon)
      .sort((a, b) => new Date(a.expiry_date) - new Date(b.expiry_date))
  })
  function daysUntil(date) {
    if (!date) return 0
    return Math.max(0, Math.round((new Date(date) - new Date()) / 86400000))
  }

  /** Gross-margin proxy: revenue minus the item cost-at-sale where present. */
  const grossMargin = computed(() => {
    let rev = 0
    let cost = 0
    for (const t of inRange.value) {
      for (const it of t.items || []) {
        const q = num(it.quantity || 1)
        const r = num(it.total ?? it.subtotal ?? num(it.unit_price) * q)
        rev += r
        cost += num(it.cost_price ?? it.unit_cost) * q
      }
      if (!(t.items || []).length) rev += num(t.total ?? t.total_amount)
    }
    return { revenue: rev, cost, margin: rev - cost, marginPct: rev ? ((rev - cost) / rev) * 100 : 0 }
  })

  // ── series ─────────────────────────────────────────────────────────────
  /** 12-month history (independent of the selected range) for forecasting. */
  const historyMonthly = computed(() => {
    const tx = branchFilter.value != null ? transactions.value.filter((t) => t.branch === branchFilter.value) : transactions.value
    return monthlyBuckets(tx, { months: 12 })
  })
  const historyValues = computed(() => historyMonthly.value.map((b) => b.value))
  const historyLabels = computed(() => historyMonthly.value.map((b) => b.label))

  /** Month-over-month descriptive series for the selected range. */
  const rangeMonthly = computed(() => {
    const days = rangeDays.value
    const months = Math.max(1, Math.ceil(days / 30))
    return monthlyBuckets(inRange.value, { months: Math.min(months, 24) })
  })

  /** 12-month seasonal index. */
  const seasonal = computed(() => seasonalProfile(historyMonthly.value.map((b) => ({ m: b.m, value: b.value }))))

  /** Product-level rollup with ABC + XYZ tags. */
  const products = computed(() => {
    const rows = productRollup(inRange.value)
    const withSeries = rows.map((r) => {
      const series = historyMonthly.value.map((b) => {
        let v = 0
        for (const t of transactions.value) {
          const d = new Date(t.created_at || t.date || 0)
          if (d.getFullYear() !== b.y || d.getMonth() !== b.m) continue
          for (const it of t.items || []) {
            const name = String(it.product_name || it.name || it.medication_name || 'Item').trim()
            if (name === r.name) v += num(it.quantity || 1)
          }
        }
        return v
      })
      return { ...r, series }
    })
    const { rows: abcRows } = abcClass(withSeries, { valueKey: 'revenue' })
    return xyzClass(abcRows, { seriesKey: 'series' })
  })

  /** Top-level categories. */
  const categories = computed(() => {
    const map = new Map()
    for (const t of inRange.value) {
      for (const it of t.items || []) {
        const cat = it.category_name || it.category || 'Other'
        const q = num(it.quantity || 1)
        const rev = num(it.total ?? it.subtotal ?? num(it.unit_price) * q)
        const row = map.get(cat) || { name: cat, revenue: 0, qty: 0, orders: 0 }
        row.revenue += rev
        row.qty += q
        row.orders += 1
        map.set(cat, row)
      }
    }
    return [...map.values()].sort((a, b) => b.revenue - a.revenue)
  })

  /** Branch performance comparison. */
  const branches = computed(() => {
    const filtered = transactions.value.filter((t) => {
      const d = new Date(t.created_at || t.date || 0)
      return d >= cutoff.value && d < cutoffEnd.value
    })
    const map = new Map()
    for (const t of filtered) {
      const name = t.branch_name || 'Unassigned'
      map.set(name, (map.get(name) || 0) + num(t.total ?? t.total_amount))
    }
    return [...map.entries()].map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value)
  })

  /** Hour-of-day demand profile. */
  const hourCounts = computed(() => {
    const arr = new Array(24).fill(0)
    for (const t of inRange.value) {
      const d = new Date(t.created_at || 0)
      if (!Number.isNaN(d.getTime())) arr[d.getHours()] += 1
    }
    return arr
  })

  /** Naive next-period forecast + accuracy, recomputed from the range. */
  const forecast = computed(() => trendForecast(historyValues.value, { horizon: 3, method: 'holt' }))

  /** Customer segmentation. */
  const rfm = computed(() => rfmSegments(inRange.value))

  /** Cross-sell association rules. */
  const basket = computed(() => marketBasket(inRange.value, { minSupport: 0.01, minConfidence: 0.15, maxItems: 25 }))

  /** Movement drivers between the current and previous window (diagnostic). */
  const drivers = computed(() => {
    const cats = new Map()
    const prevCats = new Map()
    for (const t of inRange.value) {
      for (const it of t.items || []) {
        const cat = it.category_name || it.category || 'Other'
        cats.set(cat, (cats.get(cat) || 0) + num(it.total ?? it.subtotal ?? num(it.unit_price) * num(it.quantity || 1)))
      }
    }
    for (const t of inPrevRange.value) {
      for (const it of t.items || []) {
        const cat = it.category_name || it.category || 'Other'
        prevCats.set(cat, (prevCats.get(cat) || 0) + num(it.total ?? it.subtotal ?? num(it.unit_price) * num(it.quantity || 1)))
      }
    }
    const rows = [...new Set([...cats.keys(), ...prevCats.keys()])].map((k) => ({
      label: k,
      impact: (cats.get(k) || 0) - (prevCats.get(k) || 0)
    }))
    return driverRanking(rows)
  })

  /** Outlier months in the history. */
  const monthAnomalies = computed(() => anomalies(historyValues.value, { k: 1.5 }))

  // ── load ───────────────────────────────────────────────────────────────
  const safeGet = (p) => $api.get(p).then((r) => r.data?.results || (Array.isArray(r.data) ? r.data : [])).catch(() => [])
  const safeObj = (p) => $api.get(p).then((r) => r.data || {}).catch(() => ({}))

  async function load() {
    loading.value = true
    error.value = ''
    if (isBranchLocked.value && branchStore.currentBranchId) branchFilter.value = branchStore.currentBranchId
    const branchParam = branchFilter.value ? `&branch=${branchFilter.value}` : ''
    try {
      const [tx, st, ov] = await Promise.all([
        safeGet(`/pos/transactions/?page_size=1000${branchParam}`),
        safeGet(`/inventory/stocks/?page_size=500${branchParam}`),
        safeObj(`/inventory/overview/?${branchParam.replace('&', '')}`)
      ])
      transactions.value = tx
      stocks.value = st
      overview.value = ov
    } catch (e) {
      error.value = e?.message || 'Failed to load BI data'
    } finally {
      loading.value = false
    }
  }

  onMounted(load)
  watch(branchFilter, () => load())

  return {
    // state
    loading, error, transactions, stocks, overview,
    rangeKey, rangeLabel, rangeDays, BI_RANGE_OPTIONS, BI_MONTHS,
    branchFilter, branchFilterItems, isBranchLocked,
    customDialog, customStart, customEnd,
    monthlyTarget, setMonthlyTarget,
    biBase,
    // filters
    onRangeChange, applyCustom, resolveRange,
    // windows
    inRange, inPrevRange, cutoff, cutoffEnd,
    // measures
    revenue, prevRevenue, revenueDelta, orders, prevOrders, ordersDelta,
    aov, aovDelta, unitsSold, customers,
    inventoryCost, inventoryRetail, unitsOnHand, lowStock, expiring, daysUntil,
    grossMargin,
    // series
    historyMonthly, historyValues, historyLabels, rangeMonthly, seasonal,
    products, categories, branches, hourCounts, forecast, rfm, basket, drivers, monthAnomalies,
    // utils passthrough
    load,
    helpers: { num, sum, mean, pctChange }
  }
}
