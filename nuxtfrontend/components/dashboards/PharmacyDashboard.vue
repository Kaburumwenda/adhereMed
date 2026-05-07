<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header row with date range -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">
          Welcome back, {{ auth.user?.first_name || 'there' }} 👋
        </h1>
        <div class="text-body-2 text-medium-emphasis">
          {{ today }} · Live overview of your pharmacy operations
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0">
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
          style="min-width: 200px"
          @update:model-value="onRangeChange"
        />
        <v-btn icon="mdi-refresh" variant="text" class="ml-2" :loading="loading" @click="load" />
      </div>
    </div>

    <!-- Custom date range dialog -->
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

    <!-- KPI tiles (6 across on lg) -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="4" lg="2">
        <v-card rounded="lg" class="pa-3 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <v-avatar size="36" :color="k.color" variant="tonal">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <v-chip
              v-if="k.delta != null"
              size="x-small"
              :color="k.delta >= 0 ? 'success' : 'error'"
              variant="tonal"
              :prepend-icon="k.delta >= 0 ? 'mdi-arrow-up' : 'mdi-arrow-down'"
            >
              {{ Math.abs(k.delta) }}%
            </v-chip>
          </div>
          <div class="text-caption text-medium-emphasis text-truncate">{{ k.title }}</div>
          <div class="text-h6 text-md-h5 font-weight-bold mt-1">{{ k.value }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Sales trend + Stock health -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="text-h6 font-weight-bold">Sales trend</h3>
              <div class="text-caption text-medium-emphasis">{{ rangeLabel }}</div>
            </div>
            <div class="text-right">
              <div class="text-caption text-medium-emphasis">Total</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(salesSeriesTotal) }}</div>
            </div>
          </div>
          <SparkArea :values="salesSeries" :labels="salesLabels" :height="220" color="#3b82f6" />
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-3">Stock health</h3>
          <div class="d-flex align-center justify-center mb-3">
            <DonutRing
              :segments="[
                { value: stockHealth.healthy, color: '#22c55e', label: 'Healthy' },
                { value: stockHealth.low, color: '#f59e0b', label: 'Low' },
                { value: stockHealth.out, color: '#ef4444', label: 'Out' }
              ]"
              :size="180"
            >
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ counts.stocks }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex justify-space-around">
            <div class="text-center">
              <v-chip size="small" color="success" variant="tonal">{{ stockHealth.healthy }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Healthy</div>
            </div>
            <div class="text-center">
              <v-chip size="small" color="warning" variant="tonal">{{ stockHealth.low }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Low</div>
            </div>
            <div class="text-center">
              <v-chip size="small" color="error" variant="tonal">{{ stockHealth.out }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Out</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Top sellers + Recent transactions -->
    <v-row>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Top selling products</h3>
            <v-btn variant="text" size="small" class="text-none" to="/analytics" append-icon="mdi-arrow-right">More</v-btn>
          </div>
          <EmptyState v-if="!topProducts.length" icon="mdi-package-variant-closed" title="No sales yet" />
          <div v-else>
            <div v-for="(p, i) in topProducts" :key="p.name" class="mb-3">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span class="text-truncate"><span class="text-medium-emphasis mr-2">{{ i + 1 }}.</span>{{ p.name }}</span>
                <span class="font-weight-medium">{{ formatMoney(p.revenue) }}</span>
              </div>
              <v-progress-linear :model-value="p.pct" :color="barColors[i % barColors.length]" height="8" rounded />
              <div class="text-caption text-medium-emphasis mt-1">{{ p.qty }} units sold</div>
            </div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Recent transactions</h3>
            <v-btn variant="text" size="small" class="text-none" to="/pos" append-icon="mdi-arrow-right">POS</v-btn>
          </div>
          <EmptyState v-if="!recentTx.length" icon="mdi-cash-register" title="No recent sales" />
          <v-table v-else density="compact">
            <thead>
              <tr>
                <th>Receipt #</th>
                <th>Customer</th>
                <th class="text-right">Amount</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="t in recentTx" :key="t.id">
                <td class="font-weight-medium">{{ t.receipt_number || `#${t.id}` }}</td>
                <td class="text-truncate" style="max-width:140px">{{ t.customer_name || 'Walk-in' }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(t.total || t.total_amount || 0) }}</td>
                <td class="text-caption text-medium-emphasis">{{ formatRelative(t.created_at) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

    <!-- Alerts row: low stock + expiring + pending orders -->
    <v-row>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="warning" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-alert</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Low stock</h3>
            <v-spacer />
            <v-chip size="x-small" color="warning" variant="tonal">{{ lowStock.length }}</v-chip>
          </div>
          <EmptyState v-if="!lowStock.length" icon="mdi-check-circle" title="All stocked" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="s in lowStock.slice(0, 5)" :key="s.id" :to="`/inventory/stocks/${s.id}/edit`" class="px-0">
              <v-list-item-title class="text-body-2">{{ s.medication_name || s.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                Only {{ s.total_quantity ?? s.quantity ?? 0 }} left · Reorder at {{ s.reorder_level }}
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-clock-alert</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Expiring soon</h3>
            <v-spacer />
            <v-chip size="x-small" color="error" variant="tonal">{{ expiring.length }}</v-chip>
          </div>
          <EmptyState v-if="!expiring.length" icon="mdi-check-circle" title="No items expiring" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="s in expiring.slice(0, 5)" :key="s.id" :to="`/inventory/stocks/${s.id}/edit`" class="px-0">
              <v-list-item-title class="text-body-2">{{ s.medication_name || s.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                Expires {{ formatDate(s.expiry_date) }} · {{ s.total_quantity ?? s.quantity ?? 0 }} units
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="info" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-receipt-text-clock</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Pending orders</h3>
            <v-spacer />
            <v-chip size="x-small" color="info" variant="tonal">{{ pendingOrders.length }}</v-chip>
          </div>
          <EmptyState v-if="!pendingOrders.length" icon="mdi-check-circle" title="No pending orders" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="o in pendingOrders.slice(0, 5)" :key="o.id" :to="`/pharmacy-orders/${o.id}`" class="px-0">
              <v-list-item-title class="text-body-2">Order #{{ o.id }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ o.customer_name || 'Customer' }} · {{ formatMoney(o.total || 0) }}
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- Quick actions -->
    <v-card rounded="lg" class="pa-4 mt-2">
      <h3 class="text-subtitle-1 font-weight-bold mb-3">Quick actions</h3>
      <v-row dense>
        <v-col v-for="a in actions" :key="a.label" cols="6" sm="4" md="3" lg="2">
          <v-btn block variant="tonal" rounded="lg" class="text-none justify-start" :prepend-icon="a.icon" :to="a.to" :color="a.color">
            {{ a.label }}
          </v-btn>
        </v-col>
      </v-row>
    </v-card>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatMoney, formatDate } from '~/utils/format'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const today = new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
const rangeKey = ref('7d')
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')
const customRange = ref(null)
const loading = ref(false)

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
    case 'custom': return customRange.value || { start: addDays(t, -6), end: tomorrow, label: 'Custom' }
    default: return { start: addDays(t, -6), end: tomorrow, label: 'Last 7 days' }
  }
}

const activeRange = computed(() => resolveRange(rangeKey.value))
const rangeStart = computed(() => activeRange.value.start)
const rangeEnd = computed(() => activeRange.value.end)
const rangeDays = computed(() => Math.max(1, Math.round((rangeEnd.value - rangeStart.value) / 86400000)))
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

const counts = reactive({ stocks: 0, suppliers: 0, exchange: 0 })
const stockHealth = reactive({ healthy: 0, low: 0, out: 0 })
const salesSeries = ref([])
const salesLabels = ref([])
const salesSeriesTotal = computed(() => salesSeries.value.reduce((a, b) => a + b, 0))
const todayRevenue = ref(0)
const todayOrders = ref(0)
const aov = ref(0)
const revDelta = ref(null)
const topProducts = ref([])
const recentTx = ref([])
const lowStock = ref([])
const expiring = ref([])
const pendingOrders = ref([])
let allTx = []

const barColors = ['primary', 'info', 'success', 'warning', 'purple', 'teal']

const kpis = computed(() => [
  { title: "Today's revenue", value: formatMoney(todayRevenue.value), icon: 'mdi-cash-multiple', color: 'primary', delta: revDelta.value },
  { title: "Today's orders", value: todayOrders.value, icon: 'mdi-receipt-text', color: 'info', delta: null },
  { title: 'Avg. order value', value: formatMoney(aov.value), icon: 'mdi-trending-up', color: 'success', delta: null },
  { title: 'Low stock', value: lowStock.value.length, icon: 'mdi-alert', color: 'warning', delta: null },
  { title: 'Expiring', value: expiring.value.length, icon: 'mdi-clock-alert', color: 'error', delta: null },
  { title: 'Pending orders', value: pendingOrders.value.length, icon: 'mdi-package-variant', color: 'purple', delta: null }
])

const actions = [
  { icon: 'mdi-point-of-sale', label: 'Open POS', to: '/pos', color: 'primary' },
  { icon: 'mdi-receipt-text', label: 'Patient Orders', to: '/pharmacy-orders', color: 'info' },
  { icon: 'mdi-package-variant', label: 'Inventory', to: '/inventory', color: 'success' },
  { icon: 'mdi-cart', label: 'Purchase Orders', to: '/purchase-orders/orders', color: 'warning' },
  { icon: 'mdi-clipboard-check', label: 'Dispensing', to: '/dispensing', color: 'purple' },
  { icon: 'mdi-chart-bar', label: 'Analytics', to: '/analytics', color: 'teal' }
]

function formatRelative(v) {
  if (!v) return ''
  const d = new Date(v)
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}

function isoDay(d) { return d.toISOString().slice(0, 10) }
function shortLabel(d, days) {
  if (days <= 14) return d.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric' })
  if (days <= 90) return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
  return d.toLocaleDateString(undefined, { month: 'short', year: '2-digit' })
}

function buildSeries(transactions, start, days) {
  const labels = []
  if (days <= 90) {
    const buckets = {}
    for (let i = 0; i < days; i++) {
      const d = addDays(start, i)
      buckets[isoDay(d)] = 0
      labels.push(shortLabel(d, days))
    }
    for (const t of transactions) {
      const created = t.created_at || t.date
      if (!created) continue
      const key = isoDay(new Date(created))
      if (buckets[key] !== undefined) {
        buckets[key] += Number(t.total || t.total_amount || 0)
      }
    }
    return { values: Object.values(buckets), labels }
  }
  // weekly buckets for > 90 days
  const weeks = Math.ceil(days / 7)
  for (let i = 0; i < weeks; i++) labels.push(shortLabel(addDays(start, i * 7), days))
  const values = new Array(weeks).fill(0)
  for (const t of transactions) {
    const created = t.created_at || t.date
    if (!created) continue
    const td = new Date(created)
    const idx = Math.floor((td - start) / (7 * 86400000))
    if (idx >= 0 && idx < weeks) values[idx] += Number(t.total || t.total_amount || 0)
  }
  return { values, labels }
}

function buildTopProducts(transactions) {
  const map = new Map()
  for (const t of transactions) {
    for (const it of (t.items || [])) {
      const name = it.product_name || it.name || it.medication_name || 'Item'
      const qty = Number(it.quantity || 1)
      const rev = Number(it.total || it.subtotal || (it.unit_price * qty) || 0)
      const cur = map.get(name) || { name, qty: 0, revenue: 0 }
      cur.qty += qty; cur.revenue += rev
      map.set(name, cur)
    }
  }
  const arr = [...map.values()].sort((a, b) => b.revenue - a.revenue).slice(0, 6)
  const max = arr[0]?.revenue || 1
  return arr.map(p => ({ ...p, pct: (p.revenue / max) * 100 }))
}

function rebuildSeries() {
  const series = buildSeries(allTx, rangeStart.value, rangeDays.value)
  salesSeries.value = series.values
  salesLabels.value = series.labels
}

async function load() {
  loading.value = true
  const safeList = (p) => $api.get(p).then(r => r.data?.results || (Array.isArray(r.data) ? r.data : [])).catch(() => [])
  const safeCount = (p) => $api.get(p).then(r => r.data?.count ?? r.data?.results?.length ?? (Array.isArray(r.data) ? r.data.length : 0)).catch(() => 0)

  const [tx, stocks, exchange, suppliersC] = await Promise.all([
    safeList(`/pos/transactions/?page_size=500`),
    safeList(`/inventory/stocks/?page_size=500`),
    safeList(`/exchange/orders/?page_size=100`),
    safeCount(`/suppliers/`)
  ])

  allTx = tx
  counts.suppliers = suppliersC
  counts.stocks = stocks.length || await safeCount('/inventory/stocks/')
  counts.exchange = exchange.length

  rebuildSeries()

  // Today
  const todayKey = isoDay(new Date())
  const todayTx = tx.filter(t => isoDay(new Date(t.created_at || t.date || 0)) === todayKey)
  todayOrders.value = todayTx.length
  todayRevenue.value = todayTx.reduce((s, t) => s + Number(t.total || t.total_amount || 0), 0)
  aov.value = todayOrders.value ? todayRevenue.value / todayOrders.value : 0

  // Yesterday delta
  const y = new Date(); y.setDate(y.getDate() - 1)
  const yKey = isoDay(y)
  const yRev = tx.filter(t => isoDay(new Date(t.created_at || t.date || 0)) === yKey)
    .reduce((s, t) => s + Number(t.total || t.total_amount || 0), 0)
  if (yRev > 0) revDelta.value = Math.round(((todayRevenue.value - yRev) / yRev) * 100)

  topProducts.value = buildTopProducts(tx)

  recentTx.value = [...tx].sort((a, b) =>
    new Date(b.created_at || 0) - new Date(a.created_at || 0)
  ).slice(0, 6)

  // Stock health
  let healthy = 0, low = 0, out = 0
  const lowList = []; const expList = []
  const soon = new Date(); soon.setDate(soon.getDate() + 30)
  for (const s of stocks) {
    const q = Number(s.total_quantity ?? s.quantity ?? 0)
    const r = Number(s.reorder_level || 0)
    if (q <= 0) { out++; lowList.push(s) }
    else if (r > 0 && q <= r) { low++; lowList.push(s) }
    else healthy++
    if (s.expiry_date && new Date(s.expiry_date) <= soon) expList.push(s)
  }
  stockHealth.healthy = healthy
  stockHealth.low = low
  stockHealth.out = out
  lowStock.value = lowList.sort((a, b) => Number(a.total_quantity ?? a.quantity ?? 0) - Number(b.total_quantity ?? b.quantity ?? 0))
  expiring.value = expList.sort((a, b) => new Date(a.expiry_date) - new Date(b.expiry_date))

  pendingOrders.value = exchange.filter(o => ['pending', 'processing', 'new'].includes((o.status || '').toLowerCase()))

  loading.value = false
}

watch(rangeKey, () => rebuildSeries())
watch(customRange, () => rebuildSeries())

onMounted(load)
</script>
