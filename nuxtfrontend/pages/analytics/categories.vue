<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" variant="text" to="/analytics" class="mr-2" />
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">Sales by category</h1>
          <div class="text-body-2 text-medium-emphasis">{{ rangeLabel }} · {{ allCategories.length }} categories</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-select
          v-model="rangeKey"
          :items="rangeOptions"
          item-title="label"
          item-value="key"
          density="compact"
          variant="outlined"
          color="primary"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-calendar-range"
          style="min-width: 220px"
          @update:model-value="onRangeChange"
        />
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-download" @click="exportCsv">Export</v-btn>
      </div>
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
          <v-btn variant="text" class="text-none" @click="customDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" class="text-none" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- KPIs -->
    <v-row dense>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Categories</div>
        <div class="text-h5 font-weight-bold mt-1">{{ allCategories.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Total revenue</div>
        <div class="text-h5 font-weight-bold mt-1 text-primary">{{ formatMoney(totalRevenue) }}</div>
      </v-card></v-col>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Top category</div>
        <div class="text-h6 font-weight-bold mt-1 text-truncate">{{ topCategory.name || '—' }}</div>
        <div class="text-caption text-medium-emphasis">{{ topCategory.share ? topCategory.share.toFixed(1) + '% of revenue' : '' }}</div>
      </v-card></v-col>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Total units</div>
        <div class="text-h5 font-weight-bold mt-1">{{ totalUnits }}</div>
      </v-card></v-col>
    </v-row>

    <!-- Donut + Bar -->
    <v-row class="mt-1">
      <v-col cols="12" lg="5">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-3">Revenue distribution</h3>
          <EmptyState v-if="!donutSegments.length" icon="mdi-tag-multiple" title="No category sales" />
          <div v-else class="d-flex flex-column align-center">
            <DonutRing :segments="donutSegments" :size="240" :thickness="22">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">Total</div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(totalRevenue) }}</div>
              </div>
            </DonutRing>
            <div class="mt-4 w-100">
              <div v-for="s in donutSegments" :key="s.label" class="d-flex align-center mb-2">
                <span class="legend-dot" :style="{ background: s.color }"></span>
                <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ formatMoney(s.value) }}</span>
                <span class="text-caption text-medium-emphasis ml-2" style="min-width:38px;text-align:right">{{ s.pct.toFixed(1) }}%</span>
              </div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="12" lg="7">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Top categories by {{ chartMetric }}</h3>
            <v-btn-toggle v-model="chartMetric" density="compact" mandatory variant="outlined" color="primary" rounded="lg">
              <v-btn value="revenue" class="text-none" size="small">Revenue</v-btn>
              <v-btn value="qty" class="text-none" size="small">Qty</v-btn>
              <v-btn value="orders" class="text-none" size="small">Orders</v-btn>
            </v-btn-toggle>
          </div>
          <BarChart
            v-if="chartData.values.length"
            :values="chartData.values"
            :labels="chartData.labels"
            :colors="chartData.colors"
            :height="320"
            rotate-labels
          />
          <EmptyState v-else icon="mdi-chart-bar" title="No data" />
        </v-card>
      </v-col>
    </v-row>

    <!-- Detailed table -->
    <v-card rounded="lg" class="pa-4 mt-4">
      <div class="d-flex flex-wrap align-center mb-3" style="gap:8px">
        <h3 class="text-h6 font-weight-bold">Category breakdown</h3>
        <v-spacer />
        <v-text-field
          v-model="search"
          placeholder="Search category…"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          hide-details
          clearable
          style="min-width: 240px; max-width: 320px"
        />
      </div>
      <EmptyState v-if="!filteredCategories.length" icon="mdi-magnify" title="No categories match" />
      <v-table v-else density="comfortable" hover class="bg-transparent">
        <thead>
          <tr>
            <th style="width:48px">#</th>
            <th>Category</th>
            <th class="text-right cursor-pointer" @click="sortBy = 'products'">
              Products
              <v-icon v-if="sortBy === 'products'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right cursor-pointer" @click="sortBy = 'qty'">
              Qty
              <v-icon v-if="sortBy === 'qty'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right cursor-pointer" @click="sortBy = 'orders'">
              Orders
              <v-icon v-if="sortBy === 'orders'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right cursor-pointer" @click="sortBy = 'revenue'">
              Revenue
              <v-icon v-if="sortBy === 'revenue'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right">Avg. order</th>
            <th style="width:25%">Share</th>
            <th style="width:60px"></th>
          </tr>
        </thead>
        <tbody>
          <template v-for="(c, i) in filteredCategories" :key="c.name">
            <tr>
              <td class="text-medium-emphasis">{{ i + 1 }}</td>
              <td>
                <v-chip size="small" variant="tonal" :color="catColor(i)" class="font-weight-medium">{{ c.name }}</v-chip>
              </td>
              <td class="text-right">{{ c.products }}</td>
              <td class="text-right">{{ c.qty }}</td>
              <td class="text-right">{{ c.orders }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(c.revenue) }}</td>
              <td class="text-right text-medium-emphasis">{{ formatMoney(c.avgOrder) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:8px">
                  <v-progress-linear :model-value="c.share" :color="catColor(i)" height="6" rounded style="flex:1" />
                  <span class="text-caption text-medium-emphasis" style="min-width:42px;text-align:right">{{ c.share.toFixed(1) }}%</span>
                </div>
              </td>
              <td>
                <v-btn
                  :icon="expanded === c.name ? 'mdi-chevron-up' : 'mdi-chevron-down'"
                  size="small" variant="text"
                  @click="expanded = expanded === c.name ? null : c.name"
                />
              </td>
            </tr>
            <tr v-if="expanded === c.name" class="expanded-row">
              <td colspan="9" class="pa-4">
                <div class="text-subtitle-2 font-weight-bold mb-2">Top products in {{ c.name }}</div>
                <v-table density="compact" class="bg-transparent">
                  <thead>
                    <tr>
                      <th>Product</th>
                      <th class="text-right">Qty</th>
                      <th class="text-right">Revenue</th>
                      <th class="text-right">Share of category</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="p in c.products_list.slice(0, 10)" :key="p.name">
                      <td class="font-weight-medium">{{ p.name }}</td>
                      <td class="text-right">{{ p.qty }}</td>
                      <td class="text-right">{{ formatMoney(p.revenue) }}</td>
                      <td class="text-right text-medium-emphasis">{{ ((p.revenue / c.revenue) * 100).toFixed(1) }}%</td>
                    </tr>
                  </tbody>
                </v-table>
              </td>
            </tr>
          </template>
        </tbody>
      </v-table>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()

const loading = ref(false)
const txAll = ref([])
const search = ref('')
const sortBy = ref('revenue')
const chartMetric = ref('revenue')
const expanded = ref(null)

const barColors = ['#3b82f6', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4', '#ef4444', '#14b8a6', '#0ea5e9', '#f97316']
const chipColors = ['primary', 'success', 'warning', 'pink', 'purple', 'cyan', 'error', 'teal', 'info', 'orange']
function catColor(i) { return chipColors[i % chipColors.length] }

// --- range picker ---
const rangeKey = ref('30d')
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')
const customRange = ref(null)

const rangeOptions = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'thisMonth', label: 'This month' },
  { key: 'lastMonth', label: 'Last month' },
  { key: 'thisYear', label: 'This year' },
  { key: 'lastYear', label: 'Last year' },
  { key: '1y', label: 'Last 365 days' },
  { key: 'custom', label: 'Custom range…' }
]

function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
function addDays(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x }

function resolveRange(key) {
  const t = startOfDay(new Date())
  const tomorrow = addDays(t, 1)
  switch (key) {
    case 'today': return { start: t, end: tomorrow, label: 'Today' }
    case 'yesterday': return { start: addDays(t, -1), end: t, label: 'Yesterday' }
    case '7d': return { start: addDays(t, -6), end: tomorrow, label: 'Last 7 days' }
    case '30d': return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
    case '90d': return { start: addDays(t, -89), end: tomorrow, label: 'Last 90 days' }
    case '1y': return { start: addDays(t, -364), end: tomorrow, label: 'Last 365 days' }
    case 'thisMonth': return { start: new Date(t.getFullYear(), t.getMonth(), 1), end: tomorrow, label: 'This month' }
    case 'lastMonth': return { start: new Date(t.getFullYear(), t.getMonth() - 1, 1), end: new Date(t.getFullYear(), t.getMonth(), 1), label: 'Last month' }
    case 'thisYear': return { start: new Date(t.getFullYear(), 0, 1), end: tomorrow, label: 'This year' }
    case 'lastYear': return { start: new Date(t.getFullYear() - 1, 0, 1), end: new Date(t.getFullYear(), 0, 1), label: 'Last year' }
    case 'custom': return customRange.value || { start: addDays(t, -29), end: tomorrow, label: 'Custom' }
    default: return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
  }
}

const activeRange = computed(() => resolveRange(rangeKey.value))
const rangeStart = computed(() => activeRange.value.start)
const rangeEnd = computed(() => activeRange.value.end)
const rangeLabel = computed(() => activeRange.value.label)

function onRangeChange(val) {
  if (val === 'custom') {
    if (!customStart.value) customStart.value = rangeStart.value.toISOString().slice(0, 10)
    if (!customEnd.value) customEnd.value = addDays(rangeEnd.value, -1).toISOString().slice(0, 10)
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

// --- aggregation ---
const inRange = computed(() => txAll.value.filter(t => {
  const d = new Date(t.created_at || t.date || 0)
  return d >= rangeStart.value && d < rangeEnd.value
}))

const allCategories = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    const seenInOrder = new Set()
    for (const it of (t.items || [])) {
      const cat = it.category_name || it.category || 'Uncategorized'
      const name = it.product_name || it.name || it.medication_name || 'Item'
      const qty = Number(it.quantity || 1)
      const rev = Number(it.total || it.subtotal || (it.unit_price * qty) || 0)
      if (!map.has(cat)) map.set(cat, { name: cat, qty: 0, revenue: 0, orders: 0, productMap: new Map() })
      const cur = map.get(cat)
      cur.qty += qty
      cur.revenue += rev
      if (!seenInOrder.has(cat)) {
        cur.orders += 1
        seenInOrder.add(cat)
      }
      const p = cur.productMap.get(name) || { name, qty: 0, revenue: 0 }
      p.qty += qty; p.revenue += rev
      cur.productMap.set(name, p)
    }
  }
  const arr = [...map.values()]
  const total = arr.reduce((s, c) => s + c.revenue, 0) || 1
  return arr.map(c => ({
    name: c.name,
    qty: c.qty,
    revenue: c.revenue,
    orders: c.orders,
    products: c.productMap.size,
    avgOrder: c.orders ? c.revenue / c.orders : 0,
    share: (c.revenue / total) * 100,
    products_list: [...c.productMap.values()].sort((a, b) => b.revenue - a.revenue)
  }))
})

const totalRevenue = computed(() => allCategories.value.reduce((s, c) => s + c.revenue, 0))
const totalUnits = computed(() => allCategories.value.reduce((s, c) => s + c.qty, 0))
const topCategory = computed(() => [...allCategories.value].sort((a, b) => b.revenue - a.revenue)[0] || {})

const filteredCategories = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = allCategories.value
  if (q) arr = arr.filter(c => c.name.toLowerCase().includes(q))
  const key = sortBy.value
  return [...arr].sort((a, b) => b[key] - a[key])
})

const donutSegments = computed(() => {
  const sorted = [...allCategories.value].sort((a, b) => b.revenue - a.revenue)
  const top = sorted.slice(0, 7)
  const rest = sorted.slice(7)
  const segments = top.map((c, i) => ({
    label: c.name,
    value: c.revenue,
    color: barColors[i % barColors.length],
    pct: c.share
  }))
  if (rest.length) {
    const restRev = rest.reduce((s, c) => s + c.revenue, 0)
    const restPct = rest.reduce((s, c) => s + c.share, 0)
    segments.push({ label: `Other (${rest.length})`, value: restRev, color: '#94a3b8', pct: restPct })
  }
  return segments
})

const chartData = computed(() => {
  const top = [...allCategories.value].sort((a, b) => b[chartMetric.value] - a[chartMetric.value]).slice(0, 10)
  return {
    values: top.map(c => c[chartMetric.value]),
    labels: top.map(c => c.name.length > 22 ? c.name.slice(0, 22) + '…' : c.name),
    colors: top.map((_, i) => barColors[i % barColors.length])
  }
})

function exportCsv() {
  const rows = [['Rank', 'Category', 'Products', 'Quantity', 'Orders', 'Revenue', 'Avg Order', 'Share %']]
  filteredCategories.value.forEach((c, i) => {
    rows.push([i + 1, c.name, c.products, c.qty, c.orders, c.revenue.toFixed(2), c.avgOrder.toFixed(2), c.share.toFixed(2)])
  })
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `category-sales-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

async function load() {
  loading.value = true
  try {
    const r = await $api.get('/pos/transactions/?page_size=2000')
    txAll.value = r.data?.results || (Array.isArray(r.data) ? r.data : [])
  } catch { txAll.value = [] }
  loading.value = false
}
onMounted(load)
</script>

<style scoped>
.cursor-pointer { cursor: pointer; user-select: none; }
.legend-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.expanded-row { background: rgba(var(--v-theme-on-surface), 0.03); }
.w-100 { width: 100%; }
</style>
