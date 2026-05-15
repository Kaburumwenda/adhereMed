<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header / toolbar -->
    <div class="d-flex flex-wrap align-center mb-4 no-pdf" style="gap:12px">
      <v-btn variant="text" icon="mdi-arrow-left" @click="goBack" />
      <v-avatar v-if="report" :color="report.color" variant="tonal" rounded="lg" size="44">
        <v-icon :color="report.color">{{ report.icon }}</v-icon>
      </v-avatar>
      <div class="flex-grow-1">
        <h1 class="text-h6 text-md-h5 font-weight-bold mb-0">{{ report?.label || 'Report' }}</h1>
        <div class="text-caption text-medium-emphasis">{{ report?.desc }} · {{ rangeLabel }}</div>
      </div>
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        placeholder="Search rows…"
        density="compact"
        variant="outlined"
        rounded="lg"
        hide-details
        clearable
        style="max-width: 240px"
      />
      <v-select
        v-model="rangeKey"
        :items="rangeOptions"
        item-title="label"
        item-value="key"
        density="compact"
        variant="outlined"
        rounded="lg"
        hide-details
        prepend-inner-icon="mdi-calendar-range"
        style="min-width: 200px"
        @update:model-value="onRangeChange"
      />
      <v-select
        v-if="branchStore.hasBranches"
        v-model="reportBranchFilter"
        :items="branchFilterItems"
        item-title="name"
        item-value="id"
        density="compact"
        variant="outlined"
        rounded="lg"
        hide-details
        prepend-inner-icon="mdi-store-marker"
        style="min-width: 180px"
      />
      <v-btn variant="tonal" color="primary" prepend-icon="mdi-printer" class="text-none" @click="printReport">{{ $t('common.print') }}</v-btn>
      <v-btn variant="tonal" color="error" prepend-icon="mdi-file-pdf-box" class="text-none" :loading="pdfLoading" @click="exportPdf">PDF</v-btn>
      <v-btn variant="flat" color="primary" prepend-icon="mdi-download" class="text-none" @click="exportCsv">CSV</v-btn>
    </div>

    <!-- Custom range dialog -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom date range</v-card-title>
        <v-card-text>
          <v-text-field v-model="customStart" label="Start date" type="date" variant="outlined" density="compact" hide-details class="mb-3" />
          <v-text-field v-model="customEnd" label="End date" type="date" variant="outlined" density="compact" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="flat" class="text-none" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Unknown report -->
    <v-card v-if="!report" rounded="lg" class="pa-8 text-center">
      <v-icon size="48" color="grey">mdi-help-circle-outline</v-icon>
      <div class="text-h6 mt-2">Unknown report</div>
      <div class="text-body-2 text-medium-emphasis mb-4">No report exists for "{{ routeKey }}".</div>
      <v-btn color="primary" variant="flat" class="text-none" to="/reports">Back to reports</v-btn>
    </v-card>

    <template v-else>
      <!-- Capture region -->
      <div ref="captureRoot" class="pdf-capture">
        <!-- PDF-only header -->
        <div class="pdf-only mb-4">
          <h1 style="margin:0;font-size:18px;font-weight:700">{{ report.label }}</h1>
          <div style="color:#666;font-size:11px">{{ rangeLabel }} · generated {{ formatDateTime(now) }}</div>
        </div>

        <!-- KPIs -->
        <v-row v-if="activeKpis.length" dense class="mb-2">
          <v-col v-for="(k, i) in activeKpis" :key="i" cols="6" md="3">
            <v-card rounded="lg" class="pa-3 h-100" elevation="0" style="background: rgba(var(--v-theme-primary), 0.04); border:1px solid rgba(var(--v-theme-primary), 0.12)">
              <div class="text-caption text-uppercase text-medium-emphasis" style="letter-spacing:0.05em">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </v-card>
          </v-col>
        </v-row>

        <!-- Charts -->
        <v-row v-if="chartBlocks.length" dense class="mb-2">
          <v-col v-for="(c, i) in chartBlocks" :key="'c' + i" :cols="12" :md="c.span || 12">
            <v-card rounded="lg" class="pa-3 chart-block" elevation="0" :data-title="c.title">
              <div class="d-flex align-center mb-2">
                <div class="text-subtitle-2 font-weight-bold">{{ c.title }}</div>
              </div>
              <BarChart
                v-if="c.type === 'bar'"
                :values="c.values"
                :labels="c.labels"
                :colors="c.colors"
                :color="c.color"
                :height="c.height || 220"
                :rotate-labels="c.rotateLabels"
                :y-formatter="c.moneyAxis ? moneyAxis : undefined"
              />
              <div v-else-if="c.type === 'donut'" class="d-flex flex-wrap align-center" style="gap:16px">
                <DonutRing :segments="c.segments" :size="180" :thickness="28" />
                <div class="flex-grow-1">
                  <div v-for="(s, j) in c.segments" :key="j" class="d-flex align-center mb-1" style="gap:8px">
                    <span class="legend-dot" :style="{ background: s.color }"></span>
                    <span class="text-body-2">{{ s.label }}</span>
                    <v-spacer />
                    <span class="text-body-2 font-weight-bold">{{ formatMoney(s.value) }}</span>
                  </div>
                </div>
              </div>
              <HourHeatmap v-else-if="c.type === 'heatmap'" :counts="c.counts" :unit="c.unit" />
            </v-card>
          </v-col>
        </v-row>

        <!-- Insights -->
        <v-card v-if="insights.length" rounded="lg" class="pa-4 mb-3" elevation="0" style="background: rgba(var(--v-theme-info), 0.05); border:1px solid rgba(var(--v-theme-info), 0.18)">
          <div class="d-flex align-center mb-1" style="gap:8px">
            <v-icon color="info">mdi-lightbulb-on-outline</v-icon>
            <div class="text-subtitle-2 font-weight-bold">Key insights</div>
          </div>
          <ul class="insights-list">
            <li v-for="(t, i) in insights" :key="i">{{ t }}</li>
          </ul>
        </v-card>

        <!-- Data table -->
        <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
          <v-progress-linear v-if="loading" color="primary" indeterminate />
          <div v-if="!loading && !sortedRows.length" class="pa-8 text-center text-medium-emphasis">
            <v-icon size="48" color="grey">mdi-database-off-outline</v-icon>
            <div class="text-body-1 mt-2">No data for this period.</div>
          </div>
          <div v-else class="table-wrap">
            <table class="report-table">
              <thead>
                <tr>
                  <th
                    v-for="c in activeColumns"
                    :key="c.key"
                    :style="{ textAlign: c.align === 'right' ? 'right' : 'left' }"
                    class="cursor-pointer"
                    @click="setSort(c.key)"
                  >
                    {{ c.label }}
                    <v-icon v-if="sortBy === c.key" size="14">{{ sortDir === 'desc' ? 'mdi-arrow-down' : 'mdi-arrow-up' }}</v-icon>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r, idx) in pagedRows" :key="idx">
                  <td
                    v-for="c in activeColumns"
                    :key="c.key"
                    :style="{ textAlign: c.align === 'right' ? 'right' : 'left' }"
                    v-html="renderCell(c, r)"
                  />
                </tr>
                <tr v-if="activeTotals" class="totals-row">
                  <td
                    v-for="c in activeColumns"
                    :key="c.key"
                    :style="{ textAlign: c.align === 'right' ? 'right' : 'left' }"
                    v-html="renderTotalCell(c)"
                  />
                </tr>
              </tbody>
            </table>
          </div>
          <div v-if="!pdfMode && totalPages > 1" class="d-flex align-center justify-end pa-2 no-pdf" style="gap:8px">
            <span class="text-caption text-medium-emphasis">Page {{ page }} / {{ totalPages }} · {{ sortedRows.length }} rows</span>
            <v-btn size="small" variant="text" icon="mdi-chevron-left" :disabled="page <= 1" @click="page--" />
            <v-btn size="small" variant="text" icon="mdi-chevron-right" :disabled="page >= totalPages" @click="page++" />
          </div>
        </v-card>
      </div>
    </template>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, watch, onMounted, nextTick } from 'vue'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import { REPORT_CATALOG, RANGE_OPTIONS, resolveRange, startOfDay, addDays } from '~/utils/reportsCatalog'
import { useBranchStore } from '~/stores/branch'
import defaultLogoUrl from '~/assets/images/hos_default.png'
import adhereMedLogoUrl from '~/assets/images/logo.png'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const runtimeConfig = useRuntimeConfig()
const branchStore = useBranchStore()

// --- pharmacy info for PDF header ---
const DEFAULT_PHARMACY = { name: 'Tenant Name', email: 'info@example.com', location: 'Kenya', logo: null }
const pharmacy = ref({ ...DEFAULT_PHARMACY })
const pharmacyLogoData = ref(null)
const adhereMedLogoData = ref(null)

// --- which report ---
const routeKey = computed(() => String(route.params.key || ''))
const report = computed(() => REPORT_CATALOG.find(r => r.key === routeKey.value) || null)

// --- state ---
const loading = ref(false)
const txAll = ref([])
const stocksAll = ref([])
const purchaseOrders = ref([])
const search = ref('')
const sortBy = ref('')
const sortDir = ref('desc')
const page = ref(1)
const pageSize = 25
const now = ref(new Date())
const captureRoot = ref(null)
const pdfMode = ref(false)
const pdfLoading = ref(false)
const reportBranchFilter = ref(null) // null = All Branches

const branchFilterItems = computed(() => {
  const items = branchStore.activeBranches.map(b => ({ id: b.id, name: b.name }))
  items.unshift({ id: null, name: 'All Branches' })
  return items
})

// --- range picker ---
const rangeOptions = RANGE_OPTIONS
const rangeKey = ref(String(route.query.range || '30d'))
const customDialog = ref(false)
const customStart = ref(String(route.query.start || ''))
const customEnd = ref(String(route.query.end || ''))
const customRange = ref(null)

if (rangeKey.value === 'custom' && customStart.value && customEnd.value) {
  const s = startOfDay(new Date(customStart.value))
  const e = addDays(startOfDay(new Date(customEnd.value)), 1)
  if (e > s) {
    const fmt = (d) => d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
    customRange.value = { start: s, end: e, label: `${fmt(s)} – ${fmt(addDays(e, -1))}` }
  }
}

const activeRange = computed(() => resolveRange(rangeKey.value, customRange.value))
const rangeStart = computed(() => activeRange.value.start)
const rangeEnd = computed(() => activeRange.value.end)
const rangeLabel = computed(() => activeRange.value.label)

function onRangeChange(val) {
  if (val === 'custom') {
    if (!customStart.value) customStart.value = rangeStart.value.toISOString().slice(0, 10)
    if (!customEnd.value) customEnd.value = addDays(rangeEnd.value, -1).toISOString().slice(0, 10)
    customDialog.value = true
  } else {
    syncQuery()
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
  syncQuery()
}
function syncQuery() {
  const query = { range: rangeKey.value }
  if (rangeKey.value === 'custom') { query.start = customStart.value; query.end = customEnd.value }
  router.replace({ path: route.path, query })
}
function goBack() {
  router.push({ path: '/reports', query: { range: rangeKey.value } })
}

// --- helpers ---
function inRangeTx() {
  return txAll.value.filter(t => {
    const d = new Date(t.created_at || 0)
    if (d < rangeStart.value || d >= rangeEnd.value) return false
    if (reportBranchFilter.value != null && t.branch !== reportBranchFilter.value) return false
    return true
  })
}
function isCompleted(t) { return (t.status || 'completed').toLowerCase() === 'completed' }
function itemsCount(t) { return (t.items || []).reduce((s, it) => s + Number(it.quantity || 0), 0) }
function formatPayment(m) {
  if (!m) return 'Other'
  const map = { cash: 'Cash', mpesa: 'M-Pesa', card: 'Card', bank: 'Bank', insurance: 'Insurance', credit: 'Credit' }
  const k = String(m).toLowerCase()
  return map[k] || (k.charAt(0).toUpperCase() + k.slice(1))
}
function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}
const moneyCell = (v) => v == null ? '—' : escapeHtml(formatMoney(v))
const numCell = (v) => v == null ? '—' : Number(v).toLocaleString()
const intCell = (v) => v == null ? '—' : Math.round(Number(v)).toLocaleString()
const pctCell = (v) => v == null ? '—' : `${Number(v).toFixed(1)}%`
const textCell = (v) => v == null ? '—' : escapeHtml(v)
const totalLabel = (v) => v === 'Total' ? `<strong>${t('common.total')}</strong>` : escapeHtml(v)
const dateCell = (v) => v ? escapeHtml(formatDate(v)) : '—'
const dateTimeCell = (v) => v ? escapeHtml(formatDateTime(v)) : '—'
const statusCell = (v) => v == null ? '—' : `<span class="status-pill status-${String(v).toLowerCase()}">${escapeHtml(v)}</span>`

// --- builders ---
function buildSalesSummary() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    const d = new Date(t.created_at)
    const key = d.toISOString().slice(0, 10)
    const cur = map.get(key) || { date: key, orders: 0, items: 0, gross: 0, discount: 0, tax: 0, total: 0 }
    cur.orders += 1
    cur.items += itemsCount(t)
    cur.gross += Number(t.subtotal || t.total || 0)
    cur.discount += Number(t.discount || 0)
    cur.tax += Number(t.tax || 0)
    cur.total += Number(t.total || 0)
    map.set(key, cur)
  }
  const rows = [...map.values()].map(r => ({ ...r, aov: r.orders ? r.total / r.orders : 0 }))
  const totals = rows.reduce((a, r) => ({
    date: 'Total', orders: a.orders + r.orders, items: a.items + r.items,
    gross: a.gross + r.gross, discount: a.discount + r.discount,
    tax: a.tax + r.tax, total: a.total + r.total
  }), { orders: 0, items: 0, gross: 0, discount: 0, tax: 0, total: 0 })
  totals.aov = totals.orders ? totals.total / totals.orders : 0
  return {
    rows, totals,
    columns: [
      { key: 'date', label: 'Date', formatter: (v) => v === 'Total' ? `<strong>${t('common.total')}</strong>` : dateCell(v) },
      { key: 'orders', label: 'Orders', align: 'right', formatter: numCell },
      { key: 'items', label: 'Items', align: 'right', formatter: numCell },
      { key: 'gross', label: 'Gross', align: 'right', formatter: moneyCell },
      { key: 'discount', label: 'Discount', align: 'right', formatter: moneyCell },
      { key: 'tax', label: 'Tax', align: 'right', formatter: moneyCell },
      { key: 'total', label: 'Net Total', align: 'right', formatter: moneyCell },
      { key: 'aov', label: 'AOV', align: 'right', formatter: moneyCell }
    ],
    kpis: [
      { label: 'Days', value: rows.length },
      { label: 'Orders', value: totals.orders },
      { label: 'Net revenue', value: formatMoney(totals.total), sub: `Gross ${formatMoney(totals.gross)}` },
      { label: 'AOV', value: formatMoney(totals.aov) }
    ]
  }
}

function buildSalesByProduct() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    for (const it of (t.items || [])) {
      const name = it.medication_name || it.stock_name || 'Item'
      const cur = map.get(name) || { product: name, category: it.category_name || 'Uncategorized', qty: 0, revenue: 0, orders: new Set() }
      cur.qty += Number(it.quantity || 0)
      cur.revenue += Number(it.total_price || 0)
      cur.orders.add(t.id)
      map.set(name, cur)
    }
  }
  const total = [...map.values()].reduce((s, r) => s + r.revenue, 0) || 1

  // Build stock lookup for enrichment
  const stockLookup = new Map()
  for (const s of stocksAll.value) {
    const key = (s.medication_name || '').toLowerCase()
    if (key) stockLookup.set(key, s)
  }
  const soldNames = new Set([...map.keys()].map(n => n.toLowerCase()))

  // ABC analysis
  const sorted = [...map.values()].sort((a, b) => b.revenue - a.revenue)
  let cumulative = 0
  const rows = sorted.map(r => {
    cumulative += r.revenue
    const cumulativePct = (cumulative / total) * 100
    let grade = 'C'
    if (cumulativePct <= 80) grade = 'A'
    else if (cumulativePct <= 95) grade = 'B'

    const stock = stockLookup.get(r.product.toLowerCase())
    const stockQty = stock ? Number(stock.total_quantity || 0) : 0

    return {
      product: r.product, category: r.category, qty: r.qty,
      orders: r.orders.size, revenue: r.revenue,
      avg_price: r.qty ? r.revenue / r.qty : 0,
      share: (r.revenue / total) * 100,
      grade,
      stock_on_hand: stockQty,
    }
  })

  // Slow moving & dead stock counts (from analytics page logic)
  const rangeDays = Math.max(1, Math.round((rangeEnd.value - rangeStart.value) / 86400000))
  let slowCount = 0, deadCount = 0, deadValue = 0
  for (const s of stocksAll.value) {
    const qty = Number(s.total_quantity || 0)
    if (qty <= 0) continue
    const name = (s.medication_name || '').toLowerCase()
    const sold = map.get([...map.keys()].find(k => k.toLowerCase() === name) || '')
    const qtySold = sold ? sold.qty : 0
    if (qtySold === 0) { deadCount++; deadValue += qty * Number(s.cost_price || 0) }
    else if (qtySold <= 3) { slowCount++ }
  }
  // Never sold (all time)
  const allTimeSold = new Set()
  for (const t of txAll.value) {
    for (const it of (t.items || [])) {
      const n = it.medication_name || it.stock_name || ''
      if (n) allTimeSold.add(n.toLowerCase())
    }
  }
  const neverSold = stocksAll.value.filter(s => !allTimeSold.has((s.medication_name || '').toLowerCase()))

  const abcCounts = { A: 0, B: 0, C: 0 }
  rows.forEach(r => { abcCounts[r.grade]++ })

  const totals = rows.reduce((a, r) => ({
    product: 'Total', qty: a.qty + r.qty, orders: a.orders + r.orders,
    revenue: a.revenue + r.revenue
  }), { qty: 0, orders: 0, revenue: 0 })
  totals.share = 100

  return {
    rows, totals,
    columns: [
      { key: 'product', label: 'Product', formatter: totalLabel },
      { key: 'category', label: 'Category', formatter: textCell },
      { key: 'grade', label: 'ABC', formatter: (v) => v ? `<span class="status-pill status-grade-${v.toLowerCase()}">${v}</span>` : '' },
      { key: 'qty', label: 'Qty sold', align: 'right', formatter: numCell },
      { key: 'orders', label: 'Orders', align: 'right', formatter: numCell },
      { key: 'avg_price', label: 'Avg price', align: 'right', formatter: moneyCell },
      { key: 'revenue', label: 'Revenue', align: 'right', formatter: moneyCell },
      { key: 'share', label: 'Share', align: 'right', formatter: pctCell },
      { key: 'stock_on_hand', label: 'Stock', align: 'right', formatter: intCell },
    ],
    kpis: [
      { label: 'Products sold', value: rows.length },
      { label: 'Units', value: totals.qty.toLocaleString() },
      { label: 'Revenue', value: formatMoney(totals.revenue) },
      { label: 'Avg / product', value: formatMoney(rows.length ? totals.revenue / rows.length : 0) },
      { label: 'Slow moving', value: slowCount },
      { label: 'Dead stock', value: deadCount, sub: formatMoney(deadValue) },
    ],
    // Extra data for charts & insights
    _abc: abcCounts,
    _slowCount: slowCount,
    _deadCount: deadCount,
    _deadValue: deadValue,
    _neverSoldCount: neverSold.length,
  }
}

function buildSalesByCategory() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    for (const it of (t.items || [])) {
      const cat = it.category_name || 'Uncategorized'
      const cur = map.get(cat) || { category: cat, products: new Set(), qty: 0, revenue: 0 }
      cur.products.add(it.medication_name || it.stock_name)
      cur.qty += Number(it.quantity || 0)
      cur.revenue += Number(it.total_price || 0)
      map.set(cat, cur)
    }
  }
  const total = [...map.values()].reduce((s, r) => s + r.revenue, 0) || 1
  const rows = [...map.values()].map(r => ({
    category: r.category, products: r.products.size, qty: r.qty,
    revenue: r.revenue, share: (r.revenue / total) * 100
  }))
  const totals = rows.reduce((a, r) => ({
    category: 'Total', products: a.products + r.products,
    qty: a.qty + r.qty, revenue: a.revenue + r.revenue
  }), { products: 0, qty: 0, revenue: 0 })
  totals.share = 100
  return {
    rows, totals,
    columns: [
      { key: 'category', label: 'Category', formatter: totalLabel },
      { key: 'products', label: 'Products', align: 'right', formatter: numCell },
      { key: 'qty', label: 'Units', align: 'right', formatter: numCell },
      { key: 'revenue', label: 'Revenue', align: 'right', formatter: moneyCell },
      { key: 'share', label: 'Share', align: 'right', formatter: pctCell }
    ],
    kpis: [
      { label: 'Categories', value: rows.length },
      { label: 'Units', value: totals.qty.toLocaleString() },
      { label: 'Revenue', value: formatMoney(totals.revenue) }
    ]
  }
}

function buildSalesByCashier() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    const id = String(t.cashier ?? 'unknown')
    const cur = map.get(id) || { cashier: t.cashier_name || 'Unknown', orders: 0, items: 0, revenue: 0 }
    cur.orders += 1
    cur.items += itemsCount(t)
    cur.revenue += Number(t.total || 0)
    map.set(id, cur)
  }
  const rows = [...map.values()].map(r => ({ ...r, aov: r.orders ? r.revenue / r.orders : 0 }))
  const totals = rows.reduce((a, r) => ({
    cashier: 'Total', orders: a.orders + r.orders, items: a.items + r.items,
    revenue: a.revenue + r.revenue
  }), { orders: 0, items: 0, revenue: 0 })
  totals.aov = totals.orders ? totals.revenue / totals.orders : 0
  return {
    rows, totals,
    columns: [
      { key: 'cashier', label: 'Cashier', formatter: totalLabel },
      { key: 'orders', label: 'Transactions', align: 'right', formatter: numCell },
      { key: 'items', label: 'Items', align: 'right', formatter: numCell },
      { key: 'revenue', label: 'Revenue', align: 'right', formatter: moneyCell },
      { key: 'aov', label: 'AOV', align: 'right', formatter: moneyCell }
    ],
    kpis: [
      { label: 'Cashiers', value: rows.length },
      { label: 'Total orders', value: totals.orders },
      { label: 'Total revenue', value: formatMoney(totals.revenue) }
    ]
  }
}

function buildSalesByBranch() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    const name = t.branch_name || 'Unassigned'
    const cur = map.get(name) || { branch: name, orders: 0, items: 0, revenue: 0 }
    cur.orders += 1
    cur.items += itemsCount(t)
    cur.revenue += Number(t.total || 0)
    map.set(name, cur)
  }
  const rows = [...map.values()].map(r => ({ ...r, aov: r.orders ? r.revenue / r.orders : 0 }))
  const totals = rows.reduce((a, r) => ({
    branch: 'Total', orders: a.orders + r.orders, items: a.items + r.items,
    revenue: a.revenue + r.revenue
  }), { orders: 0, items: 0, revenue: 0 })
  totals.aov = totals.orders ? totals.revenue / totals.orders : 0
  return {
    rows, totals,
    columns: [
      { key: 'branch', label: 'Branch', formatter: totalLabel },
      { key: 'orders', label: 'Transactions', align: 'right', formatter: numCell },
      { key: 'items', label: 'Items', align: 'right', formatter: numCell },
      { key: 'revenue', label: 'Revenue', align: 'right', formatter: moneyCell },
      { key: 'aov', label: 'AOV', align: 'right', formatter: moneyCell }
    ],
    kpis: [
      { label: 'Branches', value: rows.length },
      { label: 'Total orders', value: totals.orders },
      { label: 'Total revenue', value: formatMoney(totals.revenue) }
    ]
  }
}

function buildPaymentMethods() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    const k = String(t.payment_method || 'other').toLowerCase()
    const cur = map.get(k) || { method: formatPayment(k), count: 0, revenue: 0 }
    cur.count += 1
    cur.revenue += Number(t.total || 0)
    map.set(k, cur)
  }
  const total = [...map.values()].reduce((s, r) => s + r.revenue, 0) || 1
  const rows = [...map.values()].map(r => ({ ...r, share: (r.revenue / total) * 100 }))
  const totals = rows.reduce((a, r) => ({
    method: 'Total', count: a.count + r.count, revenue: a.revenue + r.revenue
  }), { count: 0, revenue: 0 })
  totals.share = 100
  return {
    rows, totals,
    columns: [
      { key: 'method', label: 'Payment method', formatter: totalLabel },
      { key: 'count', label: 'Transactions', align: 'right', formatter: numCell },
      { key: 'revenue', label: 'Revenue', align: 'right', formatter: moneyCell },
      { key: 'share', label: 'Share', align: 'right', formatter: pctCell }
    ],
    kpis: [
      { label: 'Methods used', value: rows.length },
      { label: 'Transactions', value: totals.count },
      { label: 'Revenue', value: formatMoney(totals.revenue) }
    ]
  }
}

function buildTaxReport() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    const d = new Date(t.created_at)
    const key = d.toISOString().slice(0, 10)
    const cur = map.get(key) || { date: key, orders: 0, gross: 0, tax: 0, discount: 0, net: 0 }
    cur.orders += 1
    cur.gross += Number(t.subtotal || t.total || 0)
    cur.tax += Number(t.tax || 0)
    cur.discount += Number(t.discount || 0)
    cur.net += Number(t.total || 0)
    map.set(key, cur)
  }
  const rows = [...map.values()]
  const totals = rows.reduce((a, r) => ({
    date: 'Total', orders: a.orders + r.orders,
    gross: a.gross + r.gross, tax: a.tax + r.tax,
    discount: a.discount + r.discount, net: a.net + r.net
  }), { orders: 0, gross: 0, tax: 0, discount: 0, net: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'date', label: 'Date', formatter: (v) => v === 'Total' ? `<strong>${t('common.total')}</strong>` : dateCell(v) },
      { key: 'orders', label: 'Orders', align: 'right', formatter: numCell },
      { key: 'gross', label: 'Gross', align: 'right', formatter: moneyCell },
      { key: 'discount', label: 'Discount', align: 'right', formatter: moneyCell },
      { key: 'tax', label: 'Tax collected', align: 'right', formatter: moneyCell },
      { key: 'net', label: 'Net', align: 'right', formatter: moneyCell }
    ],
    kpis: [
      { label: 'Tax collected', value: formatMoney(totals.tax) },
      { label: 'Discounts given', value: formatMoney(totals.discount) },
      { label: 'Net revenue', value: formatMoney(totals.net) }
    ]
  }
}

function buildVoidedRefunded() {
  const tx = inRangeTx().filter(t => ['voided', 'cancelled', 'refunded'].includes(String(t.status || '').toLowerCase()))
  const rows = tx.map(t => ({
    date: t.created_at,
    receipt: t.transaction_number || `#${t.id}`,
    customer: t.customer_name || 'Walk-in',
    cashier: t.cashier_name || '—',
    payment: formatPayment(t.payment_method),
    status: t.status,
    total: Number(t.total || 0)
  }))
  const totals = rows.reduce((a, r) => ({ receipt: 'Total', total: a.total + r.total }), { total: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'date', label: 'Date', formatter: dateTimeCell },
      { key: 'receipt', label: 'Receipt', formatter: totalLabel },
      { key: 'customer', label: 'Customer', formatter: textCell },
      { key: 'cashier', label: 'Cashier', formatter: textCell },
      { key: 'payment', label: 'Payment', formatter: textCell },
      { key: 'status', label: 'Status', formatter: statusCell },
      { key: 'total', label: 'Total', align: 'right', formatter: moneyCell }
    ],
    kpis: [
      { label: 'Voided / refunded', value: rows.length },
      { label: 'Lost value', value: formatMoney(totals.total) }
    ]
  }
}

function buildTopCustomers() {
  const tx = inRangeTx().filter(isCompleted)
  const map = new Map()
  for (const t of tx) {
    const name = (t.customer_name || '').trim()
    if (!name) continue
    const key = `${name}|${t.customer_phone || ''}`
    const cur = map.get(key) || { customer: name, phone: t.customer_phone || '', orders: 0, items: 0, spent: 0, last: null }
    cur.orders += 1
    cur.items += itemsCount(t)
    cur.spent += Number(t.total || 0)
    const d = new Date(t.created_at)
    if (!cur.last || d > cur.last) cur.last = d
    map.set(key, cur)
  }
  const rows = [...map.values()].map(r => ({
    ...r, aov: r.orders ? r.spent / r.orders : 0,
    last: r.last ? r.last.toISOString() : null
  }))
  const totals = rows.reduce((a, r) => ({
    customer: 'Total', orders: a.orders + r.orders,
    items: a.items + r.items, spent: a.spent + r.spent
  }), { orders: 0, items: 0, spent: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'customer', label: 'Customer', formatter: totalLabel },
      { key: 'phone', label: 'Phone', formatter: textCell },
      { key: 'orders', label: 'Visits', align: 'right', formatter: numCell },
      { key: 'items', label: 'Items', align: 'right', formatter: numCell },
      { key: 'spent', label: 'Total spent', align: 'right', formatter: moneyCell },
      { key: 'aov', label: 'AOV', align: 'right', formatter: moneyCell },
      { key: 'last', label: 'Last visit', formatter: dateCell }
    ],
    kpis: [
      { label: 'Customers', value: rows.length },
      { label: 'Total spent', value: formatMoney(totals.spent) },
      { label: 'Avg / customer', value: formatMoney(rows.length ? totals.spent / rows.length : 0) }
    ]
  }
}

function buildStockOnHand() {
  const rows = stocksAll.value.map(s => {
    const qty = Number(s.total_quantity || s.quantity || 0)
    const cost = Number(s.cost_price || 0)
    const sell = Number(s.selling_price || 0)
    return {
      product: s.medication_name || s.name || `Stock #${s.id}`,
      category: s.category_name || 'Uncategorized',
      qty,
      reorder: Number(s.reorder_level || 0),
      cost_price: cost,
      selling_price: sell,
      cost_value: qty * cost,
      retail_value: qty * sell,
      status: qty <= 0 ? 'Out' : (qty <= Number(s.reorder_level || 0) ? 'Low' : 'OK')
    }
  })
  const totals = rows.reduce((a, r) => ({
    product: 'Total', qty: a.qty + r.qty,
    cost_value: a.cost_value + r.cost_value,
    retail_value: a.retail_value + r.retail_value
  }), { qty: 0, cost_value: 0, retail_value: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'product', label: 'Product', formatter: totalLabel },
      { key: 'category', label: 'Category', formatter: textCell },
      { key: 'qty', label: 'On hand', align: 'right', formatter: intCell },
      { key: 'reorder', label: 'Reorder', align: 'right', formatter: intCell },
      { key: 'cost_price', label: 'Cost', align: 'right', formatter: moneyCell },
      { key: 'selling_price', label: 'Price', align: 'right', formatter: moneyCell },
      { key: 'cost_value', label: 'Cost value', align: 'right', formatter: moneyCell },
      { key: 'retail_value', label: 'Retail value', align: 'right', formatter: moneyCell },
      { key: 'status', label: 'Status', formatter: statusCell }
    ],
    kpis: [
      { label: 'SKUs', value: rows.length },
      { label: 'Units on hand', value: totals.qty.toLocaleString() },
      { label: 'Cost value', value: formatMoney(totals.cost_value) },
      { label: 'Retail value', value: formatMoney(totals.retail_value) }
    ]
  }
}

function buildLowStock() {
  const all = buildStockOnHand().rows
  const rows = all.filter(r => r.status !== 'OK' && r.product !== 'Total')
  const totals = rows.reduce((a, r) => ({
    product: 'Total', qty: a.qty + r.qty,
    cost_value: a.cost_value + r.cost_value
  }), { qty: 0, cost_value: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'product', label: 'Product', formatter: totalLabel },
      { key: 'category', label: 'Category', formatter: textCell },
      { key: 'qty', label: 'On hand', align: 'right', formatter: intCell },
      { key: 'reorder', label: 'Reorder', align: 'right', formatter: intCell },
      { key: 'cost_value', label: 'Cost value', align: 'right', formatter: moneyCell },
      { key: 'status', label: 'Status', formatter: statusCell }
    ],
    kpis: [
      { label: 'Items needing attention', value: rows.length },
      { label: 'Out of stock', value: rows.filter(r => r.status === 'Out').length },
      { label: 'At/below reorder', value: rows.filter(r => r.status === 'Low').length },
      { label: 'Cost value', value: formatMoney(totals.cost_value) }
    ]
  }
}

function buildExpiringSoon() {
  const t = startOfDay(new Date())
  const horizon = addDays(t, 90)
  const rows = stocksAll.value
    .filter(s => s.expiry_date && new Date(s.expiry_date) <= horizon)
    .map(s => {
      const exp = new Date(s.expiry_date)
      const days = Math.round((exp - t) / 86400000)
      const qty = Number(s.total_quantity || s.quantity || 0)
      const cost = Number(s.cost_price || 0)
      return {
        product: s.medication_name || s.name || `Stock #${s.id}`,
        batch: s.batch_number || '—',
        category: s.category_name || 'Uncategorized',
        qty,
        cost_value: qty * cost,
        expiry: s.expiry_date,
        days_left: days,
        status: days < 0 ? 'Expired' : (days <= 30 ? 'Critical' : 'Soon')
      }
    })
    .sort((a, b) => a.days_left - b.days_left)
  const totals = rows.reduce((a, r) => ({
    product: 'Total', qty: a.qty + r.qty,
    cost_value: a.cost_value + r.cost_value
  }), { qty: 0, cost_value: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'product', label: 'Product', formatter: totalLabel },
      { key: 'batch', label: 'Batch', formatter: textCell },
      { key: 'category', label: 'Category', formatter: textCell },
      { key: 'qty', label: 'Qty', align: 'right', formatter: intCell },
      { key: 'cost_value', label: 'Cost value', align: 'right', formatter: moneyCell },
      { key: 'expiry', label: 'Expiry', formatter: dateCell },
      { key: 'days_left', label: 'Days left', align: 'right', formatter: (v) => v == null ? '—' : v },
      { key: 'status', label: 'Status', formatter: statusCell }
    ],
    kpis: [
      { label: 'Items expiring ≤90d', value: rows.length },
      { label: 'Expired', value: rows.filter(r => r.status === 'Expired').length },
      { label: 'Critical (≤30d)', value: rows.filter(r => r.status === 'Critical').length },
      { label: 'At-risk cost value', value: formatMoney(totals.cost_value) }
    ]
  }
}

function buildPurchases() {
  const list = purchaseOrders.value.filter(po => {
    const d = new Date(po.created_at || po.order_date || 0)
    return d >= rangeStart.value && d < rangeEnd.value
  })
  const rows = list.map(po => ({
    date: po.created_at || po.order_date,
    po_number: po.order_number || po.po_number || `PO-${po.id}`,
    supplier: po.supplier_name || po.supplier || '—',
    items: (po.items || []).length,
    status: po.status || 'pending',
    total: Number(po.total_amount || po.total || 0)
  }))
  const totals = rows.reduce((a, r) => ({
    po_number: 'Total', items: a.items + r.items,
    total: a.total + r.total
  }), { items: 0, total: 0 })
  return {
    rows, totals,
    columns: [
      { key: 'date', label: 'Date', formatter: dateCell },
      { key: 'po_number', label: 'PO #', formatter: totalLabel },
      { key: 'supplier', label: 'Supplier', formatter: textCell },
      { key: 'items', label: 'Items', align: 'right', formatter: numCell },
      { key: 'status', label: 'Status', formatter: textCell },
      { key: 'total', label: 'Total', align: 'right', formatter: moneyCell }
    ],
    kpis: [
      { label: 'POs', value: rows.length },
      { label: 'Total spend', value: formatMoney(totals.total) }
    ]
  }
}

const builders = {
  sales_summary: buildSalesSummary,
  sales_by_product: buildSalesByProduct,
  sales_by_category: buildSalesByCategory,
  sales_by_cashier: buildSalesByCashier,
  sales_by_branch: buildSalesByBranch,
  payment_methods: buildPaymentMethods,
  tax_report: buildTaxReport,
  voided_refunded: buildVoidedRefunded,
  top_customers: buildTopCustomers,
  stock_on_hand: buildStockOnHand,
  low_stock: buildLowStock,
  expiring_soon: buildExpiringSoon,
  purchases: buildPurchases
}

const built = computed(() => {
  const fn = builders[routeKey.value]
  if (!fn) return { rows: [], columns: [], kpis: [], totals: null }
  try { return fn() } catch (e) { console.error(e); return { rows: [], columns: [], kpis: [], totals: null } }
})

const activeColumns = computed(() => built.value.columns || [])
const activeKpis = computed(() => built.value.kpis || [])
const activeTotals = computed(() => built.value.totals || null)

const filteredRows = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  if (!q) return built.value.rows
  return built.value.rows.filter(row => Object.values(row).some(v => String(v ?? '').toLowerCase().includes(q)))
})

const sortedRows = computed(() => {
  const arr = [...filteredRows.value]
  if (!sortBy.value) return arr
  const dir = sortDir.value === 'desc' ? -1 : 1
  return arr.sort((a, b) => {
    let av = a[sortBy.value], bv = b[sortBy.value]
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir
    av = String(av ?? ''); bv = String(bv ?? '')
    if (av < bv) return -1 * dir
    if (av > bv) return 1 * dir
    return 0
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(sortedRows.value.length / pageSize)))
const pagedRows = computed(() => {
  if (pdfMode.value) return sortedRows.value
  const s = (page.value - 1) * pageSize
  return sortedRows.value.slice(s, s + pageSize)
})

watch([routeKey, rangeKey, search], () => { page.value = 1 })

function setSort(key) {
  if (sortBy.value === key) sortDir.value = sortDir.value === 'desc' ? 'asc' : 'desc'
  else { sortBy.value = key; sortDir.value = 'desc' }
}

function renderCell(c, row) {
  const v = row[c.key]
  if (c.formatter) return c.formatter(v, row)
  return v == null ? '—' : escapeHtml(v)
}
function renderTotalCell(c) {
  const v = activeTotals.value[c.key]
  if (v == null) return ''
  return `<strong>${c.formatter ? c.formatter(v, activeTotals.value) : escapeHtml(v)}</strong>`
}

// --- export & print ---
function exportCsv() {
  const cols = activeColumns.value
  const rows = [cols.map(c => c.label)]
  for (const r of sortedRows.value) {
    rows.push(cols.map(c => {
      const v = r[c.key]
      if (v == null) return ''
      if (typeof v === 'number') return v
      return String(v).replace(/<[^>]+>/g, '')
    }))
  }
  if (activeTotals.value) {
    rows.push(cols.map(c => {
      const v = activeTotals.value[c.key]
      if (v == null) return ''
      if (typeof v === 'number') return v
      return String(v)
    }))
  }
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${routeKey.value}-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function printReport() {
  const cols = activeColumns.value
  const w = window.open('', '_blank', 'width=1024,height=768')
  if (!w) return
  const headerCells = cols.map(c => `<th style="text-align:${c.align === 'right' ? 'right' : 'left'}">${escapeHtml(c.label)}</th>`).join('')
  const bodyRows = sortedRows.value.map(r => `
    <tr>${cols.map(c => {
      const v = r[c.key]
      const html = c.formatter ? c.formatter(v, r) : (v == null ? '—' : escapeHtml(v))
      return `<td style="text-align:${c.align === 'right' ? 'right' : 'left'}">${html}</td>`
    }).join('')}</tr>`).join('')
  const totalsRow = activeTotals.value ? `<tr class="totals">${cols.map(c => {
    const v = activeTotals.value[c.key]
    const html = v == null ? '' : (c.formatter ? c.formatter(v, activeTotals.value) : escapeHtml(v))
    return `<th style="text-align:${c.align === 'right' ? 'right' : 'left'}">${html}</th>`
  }).join('')}</tr>` : ''
  const kpis = activeKpis.value.map(k => `<div class="kpi"><div class="kpi-label">${escapeHtml(k.label)}</div><div class="kpi-val">${escapeHtml(k.value)}</div></div>`).join('')
  w.document.write(`
    <html><head><title>${escapeHtml(report.value.label)}</title>
    <style>
      body { font-family: Arial, sans-serif; padding: 24px; color: #111; }
      h1 { margin: 0 0 4px; }
      .meta { color: #666; margin-bottom: 16px; font-size: 12px; }
      .kpis { display:flex; gap: 12px; margin: 12px 0 20px; flex-wrap: wrap; }
      .kpi { padding: 10px 14px; border: 1px solid #ddd; border-radius: 8px; min-width: 120px; }
      .kpi-label { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.05em; }
      .kpi-val { font-size: 16px; font-weight: 700; }
      table { width: 100%; border-collapse: collapse; font-size: 12px; }
      th, td { padding: 6px 8px; border-bottom: 1px solid #eee; }
      thead th { background: #f5f5f5; text-transform: uppercase; font-size: 11px; letter-spacing: 0.05em; }
      .totals th { background: #fafafa; border-top: 2px solid #999; }
      .status-pill { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
      .status-out, .status-expired { background: #fee2e2; color: #991b1b; }
      .status-low, .status-critical { background: #fef3c7; color: #92400e; }
      .status-ok { background: #d1fae5; color: #065f46; }
      .status-soon { background: #dbeafe; color: #1e40af; }
      .status-grade-a { background: #d1fae5; color: #065f46; }
      .status-grade-b { background: #fef3c7; color: #92400e; }
      .status-grade-c { background: #fee2e2; color: #991b1b; }
    </style></head><body>
      <h1>${escapeHtml(report.value.label)}</h1>
      <div class="meta">${escapeHtml(rangeLabel.value)} · generated ${escapeHtml(formatDateTime(new Date()))}</div>
      <div class="kpis">${kpis}</div>
      <table><thead><tr>${headerCells}</tr></thead><tbody>${bodyRows}${totalsRow}</tbody></table>
      <script>window.onload = () => { window.print(); }</` + `script>
    </body></html>`)
  w.document.close()
}

// --- chart palette + helpers ---
const CHART_PALETTE = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316', '#6366f1', '#84cc16', '#06b6d4', '#a855f7']
const PAYMENT_COLORS = { cash: '#10b981', mpesa: '#22c55e', card: '#3b82f6', bank: '#6366f1', insurance: '#f59e0b', credit: '#ef4444', other: '#94a3b8' }
const moneyAxis = (v) => {
  if (v >= 1_000_000) return 'KSh ' + (v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1) + 'M'
  if (v >= 1_000) return 'KSh ' + (v / 1_000).toFixed(v >= 10_000 ? 0 : 1) + 'k'
  return 'KSh ' + Math.round(v)
}

const chartBlocks = computed(() => {
  const key = routeKey.value
  const rows = built.value.rows || []
  if (!rows.length) return []
  const tx = inRangeTx().filter(isCompleted)

  if (key === 'sales_summary') {
    const top = [...rows].sort((a, b) => new Date(a.date) - new Date(b.date))
    const blocks = [{
      type: 'bar', title: 'Daily revenue', span: 12, height: 240,
      values: top.map(r => r.total),
      labels: top.map(r => new Date(r.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' })),
      color: '#3b82f6', moneyAxis: true, rotateLabels: top.length > 14
    }]
    const pm = new Map()
    for (const t of tx) {
      const k = String(t.payment_method || 'other').toLowerCase()
      pm.set(k, (pm.get(k) || 0) + Number(t.total || 0))
    }
    if (pm.size) {
      blocks.push({
        type: 'donut', title: 'Payment mix', span: 6,
        segments: [...pm.entries()].map(([k, v]) => ({ value: v, color: PAYMENT_COLORS[k] || '#94a3b8', label: formatPayment(k) }))
      })
    }
    const hours = new Array(24).fill(0)
    for (const t of tx) hours[new Date(t.created_at).getHours()] += 1
    blocks.push({ type: 'heatmap', title: 'Sales by hour', span: 6, counts: hours, unit: 'sales' })
    return blocks
  }

  if (key === 'sales_by_product') {
    const top = [...rows].filter(r => r.product !== 'Total').sort((a, b) => b.revenue - a.revenue).slice(0, 10)
    const abc = built.value._abc || { A: 0, B: 0, C: 0 }
    const abcTotal = abc.A + abc.B + abc.C || 1
    return [
      {
        type: 'bar', title: 'Top 10 Products by Revenue', span: 7, height: 280,
        values: top.map(r => r.revenue),
        labels: top.map(r => r.product.length > 18 ? r.product.slice(0, 16) + '…' : r.product),
        colors: top.map((_, i) => CHART_PALETTE[i % CHART_PALETTE.length]),
        moneyAxis: true, rotateLabels: true
      },
      {
        type: 'donut', title: 'ABC Classification', span: 5,
        segments: [
          { value: abc.A, color: '#22c55e', label: `A — ${abc.A} products (${(abc.A / abcTotal * 100).toFixed(0)}%)` },
          { value: abc.B, color: '#f59e0b', label: `B — ${abc.B} products (${(abc.B / abcTotal * 100).toFixed(0)}%)` },
          { value: abc.C, color: '#ef4444', label: `C — ${abc.C} products (${(abc.C / abcTotal * 100).toFixed(0)}%)` },
        ]
      },
    ]
  }

  if (key === 'sales_by_category') {
    const data = [...rows].filter(r => r.category !== 'Total').sort((a, b) => b.revenue - a.revenue)
    return [{
      type: 'donut', title: 'Revenue by category', span: 12,
      segments: data.map((r, i) => ({ value: r.revenue, color: CHART_PALETTE[i % CHART_PALETTE.length], label: r.category }))
    }]
  }

  if (key === 'sales_by_cashier') {
    const data = [...rows].filter(r => r.cashier !== 'Total').sort((a, b) => b.revenue - a.revenue)
    return [{
      type: 'bar', title: 'Cashier revenue', span: 12, height: 240,
      values: data.map(r => r.revenue),
      labels: data.map(r => r.cashier),
      colors: data.map((_, i) => CHART_PALETTE[i % CHART_PALETTE.length]),
      moneyAxis: true, rotateLabels: data.length > 6
    }]
  }

  if (key === 'sales_by_branch') {
    const data = [...rows].filter(r => r.branch !== 'Total').sort((a, b) => b.revenue - a.revenue)
    return [{
      type: 'bar', title: 'Revenue by branch', span: 7, height: 260,
      values: data.map(r => r.revenue),
      labels: data.map(r => r.branch.length > 18 ? r.branch.slice(0, 16) + '…' : r.branch),
      colors: data.map((_, i) => CHART_PALETTE[i % CHART_PALETTE.length]),
      moneyAxis: true, rotateLabels: data.length > 6
    }, {
      type: 'donut', title: 'Revenue share by branch', span: 5,
      segments: data.map((r, i) => {
        const total = data.reduce((s, x) => s + x.revenue, 0) || 1
        return { value: r.revenue, color: CHART_PALETTE[i % CHART_PALETTE.length], label: r.branch, pct: Math.round((r.revenue / total) * 100) }
      })
    }]
  }

  if (key === 'payment_methods') {
    const data = [...rows].filter(r => r.method !== 'Total')
    return [{
      type: 'donut', title: 'Revenue by payment method', span: 12,
      segments: data.map(r => {
        const k = Object.keys(PAYMENT_COLORS).find(c => formatPayment(c) === r.method) || 'other'
        return { value: r.revenue, color: PAYMENT_COLORS[k] || '#94a3b8', label: r.method }
      })
    }]
  }

  if (key === 'tax_report') {
    const data = [...rows].sort((a, b) => new Date(a.date) - new Date(b.date))
    return [{
      type: 'bar', title: 'Daily tax collected', span: 12, height: 220,
      values: data.map(r => r.tax),
      labels: data.map(r => new Date(r.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' })),
      color: '#8b5cf6', moneyAxis: true, rotateLabels: data.length > 14
    }, {
      type: 'bar', title: 'Daily discounts given', span: 12, height: 220,
      values: data.map(r => r.discount),
      labels: data.map(r => new Date(r.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' })),
      color: '#f59e0b', moneyAxis: true, rotateLabels: data.length > 14
    }]
  }

  if (key === 'top_customers') {
    const top = [...rows].filter(r => r.customer !== 'Total').sort((a, b) => b.spent - a.spent).slice(0, 10)
    return [{
      type: 'bar', title: 'Top 10 customers by spend', span: 12, height: 260,
      values: top.map(r => r.spent),
      labels: top.map(r => r.customer.length > 18 ? r.customer.slice(0, 16) + '…' : r.customer),
      colors: top.map((_, i) => CHART_PALETTE[i % CHART_PALETTE.length]),
      moneyAxis: true, rotateLabels: true
    }]
  }

  return []
})

const insights = computed(() => {
  const out = []
  const key = routeKey.value
  const rows = built.value.rows || []
  const totals = built.value.totals || {}
  if (!rows.length) return out

  if (key === 'sales_summary') {
    const peak = [...rows].sort((a, b) => b.total - a.total)[0]
    const slow = [...rows].sort((a, b) => a.total - b.total)[0]
    if (peak) out.push(`Best day: ${formatDate(peak.date)} with ${formatMoney(peak.total)} from ${peak.orders} orders.`)
    if (slow && slow.date !== peak?.date) out.push(`Slowest day: ${formatDate(slow.date)} (${formatMoney(slow.total)}).`)
    if (totals.aov) out.push(`Average order value across ${totals.orders} orders: ${formatMoney(totals.aov)}.`)
    if (totals.discount && totals.gross) out.push(`Discounts represent ${((totals.discount / totals.gross) * 100).toFixed(1)}% of gross sales.`)
  } else if (key === 'sales_by_product') {
    const top = [...rows].filter(r => r.product !== 'Total').sort((a, b) => b.revenue - a.revenue)
    if (top[0]) out.push(`Best seller: ${top[0].product} — ${formatMoney(top[0].revenue)} (${top[0].share.toFixed(1)}% of revenue).`)
    const top5Share = top.slice(0, 5).reduce((s, r) => s + r.share, 0)
    if (top.length >= 5) out.push(`Top 5 products contribute ${top5Share.toFixed(1)}% of total revenue.`)

    const d = built.value
    const abc = d._abc || {}
    if (abc.A) out.push(`ABC Analysis: ${abc.A} Class A products (top 80% revenue), ${abc.B || 0} Class B, ${abc.C || 0} Class C.`)
    if (d._slowCount) out.push(`${d._slowCount} slow-moving products (≤ 3 units sold) — consider promotions or bundling.`)
    if (d._deadCount) out.push(`${d._deadCount} dead stock items (in stock, zero sales) — idle capital: ${formatMoney(d._deadValue || 0)}.`)
    if (d._neverSoldCount) out.push(`${d._neverSoldCount} catalog items have never been sold (all time).`)
  } else if (key === 'sales_by_category') {
    const top = [...rows].filter(r => r.category !== 'Total').sort((a, b) => b.revenue - a.revenue)
    if (top[0]) out.push(`Leading category: ${top[0].category} (${top[0].share.toFixed(1)}% of revenue).`)
  } else if (key === 'sales_by_cashier') {
    const top = [...rows].filter(r => r.cashier !== 'Total').sort((a, b) => b.revenue - a.revenue)
    if (top[0]) out.push(`Top cashier: ${top[0].cashier} — ${formatMoney(top[0].revenue)} from ${top[0].orders} transactions (AOV ${formatMoney(top[0].aov)}).`)
  } else if (key === 'sales_by_branch') {
    const top = [...rows].filter(r => r.branch !== 'Total').sort((a, b) => b.revenue - a.revenue)
    if (top[0]) out.push(`Top branch: ${top[0].branch} — ${formatMoney(top[0].revenue)} from ${top[0].orders} transactions.`)
    const bestAov = [...rows].filter(r => r.branch !== 'Total' && r.orders >= 3).sort((a, b) => b.aov - a.aov)[0]
    if (bestAov && bestAov.branch !== top[0]?.branch) out.push(`Highest AOV: ${bestAov.branch} at ${formatMoney(bestAov.aov)} per transaction.`)
    if (top.length > 1) {
      const totalRev = top.reduce((s, r) => s + r.revenue, 0) || 1
      out.push(`Top branch contributes ${((top[0].revenue / totalRev) * 100).toFixed(1)}% of total revenue.`)
    }
  } else if (key === 'payment_methods') {
    const top = [...rows].filter(r => r.method !== 'Total').sort((a, b) => b.revenue - a.revenue)
    if (top[0]) out.push(`Most-used payment: ${top[0].method} (${top[0].share.toFixed(1)}% of revenue).`)
  } else if (key === 'tax_report') {
    if (totals.tax) out.push(`Total tax collected in period: ${formatMoney(totals.tax)}.`)
    if (totals.discount) out.push(`Total discounts given: ${formatMoney(totals.discount)}.`)
  } else if (key === 'voided_refunded') {
    if (rows.length) out.push(`${rows.length} voided/refunded transactions worth ${formatMoney(totals.total || 0)}.`)
    else out.push('No voided or refunded transactions in this period — clean operation.')
  } else if (key === 'top_customers') {
    if (rows.length) out.push(`Top customer: ${rows[0].customer} — ${formatMoney(rows[0].spent)} across ${rows[0].orders} visits.`)
  } else if (key === 'stock_on_hand') {
    const out_ = rows.filter(r => r.status === 'Out').length
    const low = rows.filter(r => r.status === 'Low').length
    if (out_) out.push(`${out_} SKUs are out of stock — restock urgently.`)
    if (low) out.push(`${low} SKUs are at or below reorder level.`)
    if (totals.retail_value) out.push(`Total retail value of inventory: ${formatMoney(totals.retail_value)}.`)
  } else if (key === 'low_stock') {
    if (rows.length) out.push(`${rows.length} items need attention; estimated cost to replenish current stock value: ${formatMoney(totals.cost_value || 0)}.`)
  } else if (key === 'expiring_soon') {
    const exp = rows.filter(r => r.status === 'Expired').length
    const crit = rows.filter(r => r.status === 'Critical').length
    if (exp) out.push(`${exp} item(s) already expired — remove from active stock.`)
    if (crit) out.push(`${crit} item(s) expire within 30 days — prioritise dispensing.`)
  } else if (key === 'purchases') {
    if (rows.length) out.push(`${rows.length} purchase order(s) totalling ${formatMoney(totals.total || 0)}.`)
  }
  return out
})

// --- PDF export ---
function hexToRgb(hex) {
  const m = String(hex).trim().replace('#', '')
  const v = m.length === 3 ? m.split('').map(c => c + c).join('') : m
  const num = parseInt(v.slice(0, 6) || '0', 16)
  return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 }
}

function svgToPngDataUrl(svgEl, scale = 2) {
  return new Promise((resolve, reject) => {
    try {
      const clone = svgEl.cloneNode(true)
      clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg')
      const bbox = svgEl.getBoundingClientRect()
      const w = Math.max(1, Math.round(bbox.width))
      const h = Math.max(1, Math.round(bbox.height))
      if (!clone.getAttribute('width')) clone.setAttribute('width', w)
      if (!clone.getAttribute('height')) clone.setAttribute('height', h)
      const xml = new XMLSerializer().serializeToString(clone)
      const svg64 = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(xml)
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        canvas.width = w * scale
        canvas.height = h * scale
        const ctx = canvas.getContext('2d')
        ctx.fillStyle = '#ffffff'
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
        resolve({ dataUrl: canvas.toDataURL('image/png'), width: w, height: h })
      }
      img.onerror = (e) => reject(e)
      img.src = svg64
    } catch (e) { reject(e) }
  })
}

async function captureChartImages() {
  await nextTick()
  await new Promise(r => setTimeout(r, 80))
  const root = captureRoot.value
  if (!root) return []
  const cards = Array.from(root.querySelectorAll('.chart-block'))
  const blocks = chartBlocks.value
  const out = []
  for (let i = 0; i < cards.length; i++) {
    const card = cards[i]
    const block = blocks[i] || {}
    const svg = card.querySelector('svg')
    if (!svg) continue
    try {
      const img = await svgToPngDataUrl(svg, 2)
      out.push({ title: block.title || card.dataset.title || '', block, ...img })
    } catch (e) { console.warn('chart capture failed', e) }
  }
  return out
}

async function exportPdf() {
  pdfLoading.value = true
  try {
    now.value = new Date()
    pdfMode.value = true
    document.body.classList.add('pdf-rendering')
    await nextTick()
    await new Promise(r => setTimeout(r, 80))

    const charts = await captureChartImages()

    const [{ jsPDF }, autoTableMod] = await Promise.all([
      import('jspdf'),
      import('jspdf-autotable')
    ])
    const autoTable = autoTableMod.default || autoTableMod

    const pdf = new jsPDF({ orientation: 'p', unit: 'pt', format: 'a4' })
    const pageW = pdf.internal.pageSize.getWidth()
    const pageH = pdf.internal.pageSize.getHeight()
    const margin = 40
    let cursorY = margin

    // ── Color palette ──
    const C = {
      primary: [37, 99, 235],      // blue-600
      primaryDark: [29, 78, 216],   // blue-700
      accent: [16, 185, 129],       // emerald-500
      dark: [15, 23, 42],           // slate-900
      heading: [30, 41, 59],        // slate-800
      body: [51, 65, 85],           // slate-600
      muted: [100, 116, 139],       // slate-500
      light: [148, 163, 184],       // slate-400
      bg: [248, 250, 252],          // slate-50
      bgCard: [241, 245, 249],      // slate-100
      border: [226, 232, 240],      // slate-200
      white: [255, 255, 255],
      success: [16, 185, 129],
      warning: [245, 158, 11],
      error: [239, 68, 68],
    }

    // ── Utility: draw rounded rect ──
    const roundRect = (x, y, w, h, r, fillColor, strokeColor) => {
      if (fillColor) pdf.setFillColor(...fillColor)
      if (strokeColor) { pdf.setDrawColor(...strokeColor); pdf.setLineWidth(0.5) }
      pdf.roundedRect(x, y, w, h, r, r, fillColor && strokeColor ? 'FD' : fillColor ? 'F' : 'S')
    }

    // ── Draw page header (called on first page) ──
    const drawHeader = () => {
      // Top accent bar
      pdf.setFillColor(...C.primary)
      pdf.rect(0, 0, pageW, 5, 'F')

      // Header background
      pdf.setFillColor(...C.bg)
      pdf.rect(0, 5, pageW, 90, 'F')

      // Left side: Tenant logo + info
      const logoSize = 44
      const logoX = margin
      const logoY = 18
      let textX = margin

      if (pharmacyLogoData.value) {
        try {
          pdf.addImage(pharmacyLogoData.value, 'PNG', logoX, logoY, logoSize, logoSize, undefined, 'FAST')
          textX = logoX + logoSize + 12
        } catch (_) { /* ignore bad image */ }
      }

      // Tenant name
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(13); pdf.setTextColor(...C.dark)
      pdf.text(pharmacy.value.name, textX, logoY + 14)

      // Tenant contact details
      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8); pdf.setTextColor(...C.body)
      const contactParts = []
      if (pharmacy.value.location) contactParts.push(pharmacy.value.location)
      if (pharmacy.value.email) contactParts.push(pharmacy.value.email)
      if (pharmacy.value.phone) contactParts.push(pharmacy.value.phone)
      pdf.text(contactParts.join('  |  '), textX, logoY + 28)

      // Right side: AdhereMed branding (mirrored layout)
      const amLogoSize = logoSize
      const amTextRight = pageW - margin
      const amLogoX = amTextRight - amLogoSize
      const amLogoY = logoY
      if (adhereMedLogoData.value) {
        try {
          pdf.addImage(adhereMedLogoData.value, 'PNG', amLogoX, amLogoY, amLogoSize, amLogoSize, undefined, 'FAST')
        } catch (_) { /* ignore */ }
      }
      // AdhereMed name (right-aligned to left of logo)
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(13); pdf.setTextColor(...C.dark)
      pdf.text('AdhereMed', amLogoX - 12, amLogoY + 14, { align: 'right' })
      // AdhereMed contact (right-aligned to left of logo)
      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8); pdf.setTextColor(...C.body)
      pdf.text('info@adheremed.com  |  Kenya', amLogoX - 12, amLogoY + 28, { align: 'right' })

      // Separator line
      pdf.setDrawColor(...C.border); pdf.setLineWidth(1)
      pdf.line(margin, 95, pageW - margin, 95)

      cursorY = 110

      // Report title band
      roundRect(margin, cursorY, pageW - margin * 2, 42, 6, C.primary)
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(14); pdf.setTextColor(...C.white)
      pdf.text(report.value.label, margin + 16, cursorY + 18)
      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(9); pdf.setTextColor(220, 230, 255)
      pdf.text(rangeLabel.value + '  |  Generated ' + formatDateTime(now.value), margin + 16, cursorY + 32)

      cursorY += 58
    }

    const ensureSpace = (h) => {
      if (cursorY + h > pageH - 50) { pdf.addPage(); cursorY = margin }
    }

    // ── Draw footer on every page ──
    const drawFooter = (pageNum) => {
      const footerY = pageH - 28
      // Separator
      pdf.setDrawColor(...C.border); pdf.setLineWidth(0.5)
      pdf.line(margin, footerY - 8, pageW - margin, footerY - 8)
      // Left: pharmacy info
      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(7); pdf.setTextColor(...C.light)
      pdf.text(`${pharmacy.value.name}  |  ${pharmacy.value.email}  |  Powered by AdhereMed`, margin, footerY)
      // Right: page number
      pdf.text(`Page ${pageNum}`, pageW - margin, footerY, { align: 'right' })
    }

    // ══════════════════════════════════════════
    //  BUILD DOCUMENT
    // ══════════════════════════════════════════

    drawHeader()

    // ── KPI Cards ──
    const kpis = activeKpis.value || []
    if (kpis.length) {
      const cols = Math.min(4, kpis.length)
      const gap = 10
      const cardW = (pageW - margin * 2 - gap * (cols - 1)) / cols
      const cardH = 58
      ensureSpace(cardH + 16)

      kpis.forEach((k, i) => {
        const col = i % cols
        const row = Math.floor(i / cols)
        if (col === 0 && row > 0) { cursorY += cardH + gap; ensureSpace(cardH) }
        const x = margin + col * (cardW + gap)
        const y = cursorY

        // Card background with left accent
        roundRect(x, y, cardW, cardH, 5, C.bgCard, C.border)
        pdf.setFillColor(...C.primary)
        pdf.roundedRect(x, y, 4, cardH, 2, 2, 'F')

        // Label
        pdf.setFont('helvetica', 'normal'); pdf.setFontSize(7.5); pdf.setTextColor(...C.muted)
        pdf.text(String(k.label).toUpperCase(), x + 14, y + 16)
        // Value
        pdf.setFont('helvetica', 'bold'); pdf.setFontSize(15); pdf.setTextColor(...C.dark)
        pdf.text(String(k.value), x + 14, y + 35)
        // Sub
        if (k.sub) {
          pdf.setFont('helvetica', 'normal'); pdf.setFontSize(7); pdf.setTextColor(...C.light)
          pdf.text(String(k.sub), x + 14, y + 48)
        }
      })
      const totalRows = Math.ceil(kpis.length / cols)
      cursorY += cardH * totalRows + (totalRows - 1) * gap + 20
    }

    // ── Key Insights ──
    if (insights.value.length) {
      ensureSpace(50)
      // Section heading
      roundRect(margin, cursorY, pageW - margin * 2, 28, 4, [239, 246, 255])
      pdf.setFillColor(...C.primary)
      pdf.roundedRect(margin, cursorY, 4, 28, 2, 2, 'F')
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(10); pdf.setTextColor(...C.primary)
      pdf.text('\u2728  Key Insights', margin + 14, cursorY + 18)
      cursorY += 36

      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(9); pdf.setTextColor(...C.body)
      for (const t of insights.value) {
        const lines = pdf.splitTextToSize('\u2022  ' + t, pageW - margin * 2 - 10)
        ensureSpace(lines.length * 13 + 4)
        pdf.text(lines, margin + 10, cursorY)
        cursorY += lines.length * 13 + 3
      }
      cursorY += 10
    }

    // ── Charts ──
    for (const c of charts) {
      const isDonut = c.block?.type === 'donut'
      const maxW = pageW - margin * 2
      const ratio = c.height / c.width
      let w = maxW
      let h = w * ratio
      if (isDonut) {
        h = Math.min(200, h)
        w = h / ratio
      }
      const titleH = c.title ? 20 : 0
      const legendLines = isDonut && c.block?.segments ? c.block.segments.length : 0
      const legendH = legendLines ? legendLines * 13 + 8 : 0
      const totalH = h + titleH + legendH + 24

      ensureSpace(totalH)

      // Chart container card
      const containerH = h + titleH + legendH + 16
      roundRect(margin, cursorY, maxW, containerH, 6, C.white, C.border)

      if (c.title) {
        pdf.setFont('helvetica', 'bold'); pdf.setFontSize(10); pdf.setTextColor(...C.heading)
        pdf.text(c.title, margin + 12, cursorY + 16)
        cursorY += titleH
      }

      const x = isDonut ? margin + (maxW - w) / 2 : margin + 6
      const imgW = isDonut ? w : maxW - 12
      const imgH = isDonut ? h : imgW * ratio
      pdf.addImage(c.dataUrl, 'PNG', x, cursorY + 4, imgW, imgH, undefined, 'FAST')

      if (isDonut && c.block?.segments) {
        let ly = cursorY + imgH + 14
        const total = c.block.segments.reduce((s, x) => s + (Number(x.value) || 0), 0) || 1
        for (const seg of c.block.segments) {
          const pct = ((Number(seg.value) || 0) / total * 100).toFixed(1)
          const rgb = hexToRgb(seg.color || '#94a3b8')
          pdf.setFillColor(rgb.r, rgb.g, rgb.b)
          roundRect(margin + 12, ly - 7, 10, 10, 2, [rgb.r, rgb.g, rgb.b])
          pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8.5); pdf.setTextColor(...C.body)
          pdf.text(seg.label, margin + 26, ly + 1)
          pdf.setFont('helvetica', 'bold'); pdf.setTextColor(...C.dark)
          pdf.text(`${formatMoney(seg.value)} (${pct}%)`, pageW - margin - 12, ly + 1, { align: 'right' })
          ly += 13
        }
        cursorY += imgH + 14 + c.block.segments.length * 13 + 12
      } else {
        cursorY += imgH + 20
      }
    }

    // ── Data Table ──
    const cols = activeColumns.value
    if (cols.length && sortedRows.value.length) {
      // Section heading
      ensureSpace(50)
      roundRect(margin, cursorY, pageW - margin * 2, 28, 4, C.bgCard)
      pdf.setFillColor(...C.primary)
      pdf.roundedRect(margin, cursorY, 4, 28, 2, 2, 'F')
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(10); pdf.setTextColor(...C.heading)
      pdf.text('\uD83D\uDCCA  Detailed Data', margin + 14, cursorY + 18)
      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8); pdf.setTextColor(...C.muted)
      pdf.text(`${sortedRows.value.length} records`, pageW - margin - 8, cursorY + 18, { align: 'right' })
      cursorY += 36

      const head = [cols.map(c => c.label)]
      const stripHtml = (s) => String(s ?? '').replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').trim()
      const cellText = (c, row) => {
        const v = row[c.key]
        if (v == null || v === '') return ''
        if (c.formatter) return stripHtml(c.formatter(v, row))
        return String(v)
      }
      const body = sortedRows.value.map(r => cols.map(c => cellText(c, r)))
      const foot = activeTotals.value
        ? [cols.map(c => {
            const v = activeTotals.value[c.key]
            if (v == null) return ''
            return stripHtml(c.formatter ? c.formatter(v, activeTotals.value) : v)
          })]
        : undefined

      autoTable(pdf, {
        startY: cursorY,
        margin: { left: margin, right: margin },
        head, body, foot,
        styles: {
          fontSize: 8,
          cellPadding: { top: 5, right: 6, bottom: 5, left: 6 },
          overflow: 'linebreak',
          lineColor: C.border,
          lineWidth: 0.5,
          textColor: C.body,
        },
        headStyles: {
          fillColor: C.primary,
          textColor: C.white,
          fontStyle: 'bold',
          fontSize: 8,
          cellPadding: { top: 7, right: 6, bottom: 7, left: 6 },
        },
        footStyles: {
          fillColor: [237, 242, 252],
          textColor: C.dark,
          fontStyle: 'bold',
          fontSize: 8.5,
          cellPadding: { top: 6, right: 6, bottom: 6, left: 6 },
        },
        alternateRowStyles: { fillColor: [250, 251, 254] },
        columnStyles: cols.reduce((acc, c, i) => {
          if (c.align === 'right') acc[i] = { halign: 'right' }
          return acc
        }, {}),
        didDrawPage: () => {} // footer handled below
      })
    }

    // ── Apply footers to all pages ──
    const totalPages = pdf.internal.getNumberOfPages()
    for (let i = 1; i <= totalPages; i++) {
      pdf.setPage(i)
      drawFooter(i)
    }

    pdf.save(`${routeKey.value}-${new Date().toISOString().slice(0, 10)}.pdf`)
  } catch (e) {
    console.error('PDF export failed:', e)
    alert('PDF export failed: ' + (e?.message || e))
  } finally {
    pdfMode.value = false
    document.body.classList.remove('pdf-rendering')
    pdfLoading.value = false
  }
}

// --- data loading ---
async function safeList(url) {
  try {
    const r = await $api.get(url)
    return r.data?.results || (Array.isArray(r.data) ? r.data : [])
  } catch { return [] }
}
async function safeGet(url) {
  try { const r = await $api.get(url); return r.data } catch { return null }
}

function absoluteUrl(u) {
  if (!u) return null
  if (/^https?:\/\//i.test(u)) return u
  const base = (runtimeConfig.public?.apiBase || '').replace(/\/api\/?$/, '').replace(/\/$/, '')
  return base + (u.startsWith('/') ? u : '/' + u)
}

async function loadImageDataUrl(url) {
  if (!url) return null
  try {
    const r = await fetch(url, { credentials: 'omit' })
    if (!r.ok) return null
    const blob = await r.blob()
    return await new Promise((resolve, reject) => {
      const fr = new FileReader()
      fr.onload = () => resolve(fr.result)
      fr.onerror = reject
      fr.readAsDataURL(blob)
    })
  } catch { return null }
}

async function loadPharmacyInfo() {
  const [profile, branches] = await Promise.all([
    safeList('/pharmacy-profile/profile/').then(arr => arr[0] || null).catch(() => null),
    safeList('/pharmacy-profile/branches/')
  ])
  const main = branches.find(b => b.is_main) || branches[0] || null
  pharmacy.value = {
    name: profile?.name || DEFAULT_PHARMACY.name,
    email: main?.email || DEFAULT_PHARMACY.email,
    location: main?.address || DEFAULT_PHARMACY.location,
    phone: main?.phone || '',
    logo: profile?.logo_url || (profile?.logo ? absoluteUrl(profile.logo) : null)
  }
  // preload tenant logo (API → fallback default)
  pharmacyLogoData.value = await loadImageDataUrl(pharmacy.value.logo)
  if (!pharmacyLogoData.value) {
    pharmacyLogoData.value = await loadImageDataUrl(defaultLogoUrl)
  }
  // preload AdhereMed logo
  adhereMedLogoData.value = await loadImageDataUrl(adhereMedLogoUrl)
}

async function loadAll() {
  loading.value = true
  try {
    const [tx, stocks, pos] = await Promise.all([
      safeList('/pos/transactions/?page_size=2000'),
      safeList('/inventory/stocks/?page_size=2000'),
      safeList('/purchase-orders/orders/?page_size=1000'),
      loadPharmacyInfo()
    ])
    txAll.value = tx
    stocksAll.value = stocks
    purchaseOrders.value = pos
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)
</script>

<style scoped>
.table-wrap { overflow-x: auto; }
.report-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.report-table thead th {
  font-weight: 700 !important;
  font-size: 12px !important;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgb(var(--v-theme-on-surface)) !important;
  background: rgba(var(--v-theme-primary), 0.08) !important;
  border-bottom: 2px solid rgba(var(--v-theme-primary), 0.3) !important;
  white-space: nowrap;
  padding: 10px 12px;
}
.report-table tbody td { padding: 8px 12px; border-bottom: 1px solid rgba(0,0,0,0.05); }
.report-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.03); }
.report-table .totals-row { background: rgba(var(--v-theme-primary), 0.04); border-top: 2px solid rgba(var(--v-theme-primary), 0.25); }
.report-table .totals-row td { font-weight: 700; }
.cursor-pointer { cursor: pointer; user-select: none; }

:deep(.status-pill) { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; display: inline-block; }
:deep(.status-out), :deep(.status-expired) { background: rgba(239, 68, 68, 0.15); color: rgb(185, 28, 28); }
:deep(.status-low), :deep(.status-critical) { background: rgba(245, 158, 11, 0.15); color: rgb(146, 64, 14); }
:deep(.status-ok) { background: rgba(34, 197, 94, 0.15); color: rgb(6, 95, 70); }
:deep(.status-soon) { background: rgba(59, 130, 246, 0.15); color: rgb(30, 64, 175); }
:deep(.status-grade-a) { background: rgba(34, 197, 94, 0.15); color: rgb(6, 95, 70); }
:deep(.status-grade-b) { background: rgba(245, 158, 11, 0.15); color: rgb(146, 64, 14); }
:deep(.status-grade-c) { background: rgba(239, 68, 68, 0.15); color: rgb(185, 28, 28); }

.legend-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; }
.insights-list { padding-left: 18px; margin: 0; }
.insights-list li { font-size: 13px; line-height: 1.6; }
.pdf-only { display: none; }
.pdf-capture { background: transparent; }
</style>

<style>
body.pdf-rendering .pdf-only { display: block !important; }
body.pdf-rendering .no-pdf { display: none !important; }
</style>
