<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" variant="text" to="/analytics" class="mr-2" />
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">Top products</h1>
          <div class="text-body-2 text-medium-emphasis">{{ rangeLabel }} · {{ allProducts.length }} products sold</div>
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
        <div class="text-caption text-medium-emphasis">Products sold</div>
        <div class="text-h5 font-weight-bold mt-1">{{ allProducts.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Total units</div>
        <div class="text-h5 font-weight-bold mt-1">{{ totalUnits }}</div>
      </v-card></v-col>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Total revenue</div>
        <div class="text-h5 font-weight-bold mt-1 text-primary">{{ formatMoney(totalRevenue) }}</div>
      </v-card></v-col>
      <v-col cols="6" md="3"><v-card rounded="lg" class="pa-4 h-100">
        <div class="text-caption text-medium-emphasis">Avg. revenue / product</div>
        <div class="text-h5 font-weight-bold mt-1">{{ formatMoney(allProducts.length ? totalRevenue / allProducts.length : 0) }}</div>
      </v-card></v-col>
    </v-row>

    <!-- Top 10 chart -->
    <v-card rounded="lg" class="pa-4 mt-4">
      <div class="d-flex align-center justify-space-between mb-3">
        <h3 class="text-h6 font-weight-bold">Top 10 by {{ sortBy }}</h3>
        <v-btn-toggle v-model="sortBy" density="compact" mandatory variant="outlined" color="primary" rounded="lg">
          <v-btn value="revenue" class="text-none" size="small">Revenue</v-btn>
          <v-btn value="qty" class="text-none" size="small">Quantity</v-btn>
          <v-btn value="orders" class="text-none" size="small">Orders</v-btn>
        </v-btn-toggle>
      </div>
      <BarChart
        v-if="topTenChart.values.length"
        :values="topTenChart.values"
        :labels="topTenChart.labels"
        :colors="topTenChart.colors"
        :height="420"
        rotate-labels
      />
      <EmptyState v-else icon="mdi-package-variant-closed" title="No sales in this period" />
    </v-card>

    <!-- Filters + table -->
    <v-card rounded="lg" class="pa-4 mt-4">
      <div class="d-flex flex-wrap align-center mb-3" style="gap:8px">
        <v-text-field
          v-model="search"
          placeholder="Search product…"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          hide-details
          clearable
          style="min-width: 240px; max-width: 360px"
        />
        <v-select
          v-model="categoryFilter"
          :items="categoryFilterOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          hide-details
          style="min-width: 200px; max-width: 240px"
          prepend-inner-icon="mdi-tag"
        />
        <v-spacer />
        <div class="text-body-2 text-medium-emphasis">{{ filteredProducts.length }} of {{ allProducts.length }}</div>
      </div>

      <EmptyState v-if="!filteredProducts.length" icon="mdi-magnify" title="No products match" />
      <v-table v-else density="comfortable" hover class="bg-transparent">
        <thead>
          <tr>
            <th style="width:48px">#</th>
            <th>Product</th>
            <th>Category</th>
            <th class="text-right cursor-pointer" @click="setSort('qty')">
              Qty
              <v-icon v-if="sortBy === 'qty'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right cursor-pointer" @click="setSort('orders')">
              Orders
              <v-icon v-if="sortBy === 'orders'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right cursor-pointer" @click="setSort('revenue')">
              Revenue
              <v-icon v-if="sortBy === 'revenue'" size="14">mdi-arrow-down</v-icon>
            </th>
            <th class="text-right">Avg. price</th>
            <th style="width:25%">Share of revenue</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(p, i) in pagedProducts" :key="p.name">
            <td class="text-medium-emphasis">{{ (page - 1) * pageSize + i + 1 }}</td>
            <td class="font-weight-medium text-truncate" style="max-width:240px">{{ p.name }}</td>
            <td>
              <v-chip size="x-small" variant="tonal" color="primary">{{ p.category }}</v-chip>
            </td>
            <td class="text-right">{{ p.qty }}</td>
            <td class="text-right">{{ p.orders }}</td>
            <td class="text-right font-weight-medium">{{ formatMoney(p.revenue) }}</td>
            <td class="text-right text-medium-emphasis">{{ formatMoney(p.avgPrice) }}</td>
            <td>
              <div class="d-flex align-center" style="gap:8px">
                <v-progress-linear :model-value="p.share" :color="barColors[i % barColors.length]" height="6" rounded style="flex:1" />
                <span class="text-caption text-medium-emphasis" style="min-width:38px; text-align:right">{{ p.share.toFixed(1) }}%</span>
              </div>
            </td>
          </tr>
        </tbody>
      </v-table>

      <div v-if="filteredProducts.length > pageSize" class="d-flex justify-center mt-3">
        <v-pagination v-model="page" :length="Math.ceil(filteredProducts.length / pageSize)" rounded="lg" density="compact" />
      </div>
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
const categoryFilter = ref('all')
const page = ref(1)
const pageSize = 25

const barColors = ['#3b82f6', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4', '#ef4444', '#14b8a6']

// --- range picker (shared logic) ---
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

const allProducts = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    const orderProductSet = new Set()
    for (const it of (t.items || [])) {
      const name = it.product_name || it.name || it.medication_name || 'Item'
      const qty = Number(it.quantity || 1)
      const rev = Number(it.total || it.subtotal || (it.unit_price * qty) || 0)
      const cat = it.category_name || it.category || 'Uncategorized'
      const cur = map.get(name) || { name, qty: 0, revenue: 0, orders: 0, category: cat }
      cur.qty += qty
      cur.revenue += rev
      if (!orderProductSet.has(name)) {
        cur.orders += 1
        orderProductSet.add(name)
      }
      map.set(name, cur)
    }
  }
  const total = [...map.values()].reduce((s, p) => s + p.revenue, 0) || 1
  return [...map.values()].map(p => ({
    ...p,
    avgPrice: p.qty ? p.revenue / p.qty : 0,
    share: (p.revenue / total) * 100
  }))
})

const totalRevenue = computed(() => allProducts.value.reduce((s, p) => s + p.revenue, 0))
const totalUnits = computed(() => allProducts.value.reduce((s, p) => s + p.qty, 0))

const categoryFilterOptions = computed(() => {
  const cats = [...new Set(allProducts.value.map(p => p.category))].sort()
  return [{ label: 'All categories', value: 'all' }, ...cats.map(c => ({ label: c, value: c }))]
})

const filteredProducts = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = allProducts.value
  if (categoryFilter.value !== 'all') arr = arr.filter(p => p.category === categoryFilter.value)
  if (q) arr = arr.filter(p => p.name.toLowerCase().includes(q))
  const key = sortBy.value
  return [...arr].sort((a, b) => b[key] - a[key])
})

const pagedProducts = computed(() => {
  const start = (page.value - 1) * pageSize
  return filteredProducts.value.slice(start, start + pageSize)
})

watch([search, categoryFilter, sortBy, rangeKey], () => { page.value = 1 })

const topTenChart = computed(() => {
  const top = [...allProducts.value].sort((a, b) => b[sortBy.value] - a[sortBy.value]).slice(0, 10)
  return {
    values: top.map(p => p[sortBy.value]),
    labels: top.map(p => p.name.length > 22 ? p.name.slice(0, 22) + '…' : p.name),
    colors: top.map((_, i) => barColors[i % barColors.length])
  }
})

function setSort(key) { sortBy.value = key }

function exportCsv() {
  const rows = [['Rank', 'Product', 'Category', 'Quantity', 'Orders', 'Revenue', 'Avg Price', 'Share %']]
  filteredProducts.value.forEach((p, i) => {
    rows.push([i + 1, p.name, p.category, p.qty, p.orders, p.revenue.toFixed(2), p.avgPrice.toFixed(2), p.share.toFixed(2)])
  })
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `top-products-${new Date().toISOString().slice(0, 10)}.csv`
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
</style>
