<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">Pharmacy Analytics</h1>
        <div class="text-body-2 text-medium-emphasis">
          Performance insights · {{ rangeLabel }}
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
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-download" to="/reports">Reports</v-btn>
      </div>
    </div>

    <!-- Custom date range dialog -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom date range</v-card-title>
        <v-card-text>
          <v-text-field
            v-model="customStart"
            label="Start date"
            type="date"
            variant="outlined"
            density="compact"
            hide-details
            class="mb-3"
          />
          <v-text-field
            v-model="customEnd"
            label="End date"
            type="date"
            variant="outlined"
            density="compact"
            hide-details
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" class="text-none" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <v-avatar size="40" :color="k.color" variant="tonal">
              <v-icon>{{ k.icon }}</v-icon>
            </v-avatar>
            <v-chip
              v-if="k.delta != null"
              size="small"
              :color="k.delta >= 0 ? 'success' : 'error'"
              variant="tonal"
              :prepend-icon="k.delta >= 0 ? 'mdi-arrow-up' : 'mdi-arrow-down'"
            >{{ Math.abs(k.delta) }}%</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis">{{ k.title }}</div>
          <div class="text-h5 text-md-h4 font-weight-bold mt-1">{{ k.value }}</div>
          <div v-if="k.hint" class="text-caption text-medium-emphasis mt-1">{{ k.hint }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Revenue + payment mix -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="text-h6 font-weight-bold">Revenue trend</h3>
              <div class="text-caption text-medium-emphasis">Daily revenue · {{ rangeLabel }}</div>
            </div>
            <div class="text-right">
              <div class="text-caption text-medium-emphasis">Total</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(revenueTotal) }}</div>
            </div>
          </div>
          <SparkArea :values="revenueSeries" :labels="seriesLabels" :height="240" color="#3b82f6" />
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-3">Payment methods</h3>
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="paymentSegments" :size="200">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">Transactions</div>
                <div class="text-h5 font-weight-bold">{{ totalOrders }}</div>
              </div>
            </DonutRing>
          </div>
          <div>
            <div v-for="s in paymentSegments" :key="s.label" class="d-flex align-center mb-2">
              <span class="legend-dot" :style="{ background: s.color }"></span>
              <span class="text-body-2 ml-2 flex-grow-1">{{ s.label }}</span>
              <span class="text-body-2 font-weight-medium">{{ s.value }}</span>
              <span class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Orders bar chart + Hourly heat -->
    <v-row>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-1">Orders per day</h3>
          <div class="text-caption text-medium-emphasis mb-3">Volume of transactions over time</div>
          <BarChart :values="ordersSeries" :labels="seriesLabels" :height="220" color="#22c55e" rotate-labels />
        </v-card>
      </v-col>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-1">Hour of day · sales heatmap</h3>
          <div class="text-caption text-medium-emphasis mb-3">When customers buy most</div>
          <HourHeatmap :counts="hourCounts" unit="sales" />
        </v-card>
      </v-col>
    </v-row>

    <!-- Top products + Category breakdown -->
    <v-row>
      <v-col cols="12" lg="7">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Top selling products</h3>
            <div class="d-flex align-center" style="gap:8px">
              <v-btn-toggle v-model="topMetric" density="compact" mandatory variant="outlined" color="primary" rounded="lg">
                <v-btn value="revenue" class="text-none" size="small">Revenue</v-btn>
                <v-btn value="qty" class="text-none" size="small">Quantity</v-btn>
              </v-btn-toggle>
              <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" to="/analytics/products">View all</v-btn>
            </div>
          </div>
          <EmptyState v-if="!topProducts.length" icon="mdi-package-variant-closed" title="No sales yet" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th style="width:40px">#</th>
                <th>Product</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Revenue</th>
                <th style="width:30%">Share</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in topProducts" :key="p.name">
                <td class="text-medium-emphasis">{{ i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:200px">{{ p.name }}</td>
                <td class="text-right">{{ p.qty }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(p.revenue) }}</td>
                <td>
                  <v-progress-linear
                    :model-value="p.pct"
                    :color="barColors[i % barColors.length]"
                    height="6" rounded
                  />
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <v-col cols="12" lg="5">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Sales by category</h3>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" to="/analytics/categories">View all</v-btn>
          </div>
          <EmptyState v-if="!categorySegments.length" icon="mdi-tag-multiple" title="No category data" />
          <div v-else class="d-flex flex-column align-center">
            <DonutRing :segments="categorySegments" :size="220">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">Total</div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(categoryTotal) }}</div>
              </div>
            </DonutRing>
            <div class="mt-3 w-100">
              <div v-for="s in categorySegments" :key="s.label" class="d-flex align-center mb-1">
                <span class="legend-dot" :style="{ background: s.color }"></span>
                <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ formatMoney(s.value) }}</span>
              </div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Inventory section: stock value + low stock + expiring -->
    <v-row>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Inventory value</h3>
          <div class="text-h4 font-weight-bold text-primary">{{ formatMoney(inventoryValue) }}</div>
          <div class="text-caption text-medium-emphasis">at cost · across {{ stocks.length }} SKUs</div>
          <v-divider class="my-3" />
          <div class="d-flex justify-space-between text-body-2 mb-1">
            <span class="text-medium-emphasis">Selling value</span>
            <span class="font-weight-medium">{{ formatMoney(inventorySellValue) }}</span>
          </div>
          <div class="d-flex justify-space-between text-body-2 mb-1">
            <span class="text-medium-emphasis">Potential margin</span>
            <span class="font-weight-medium text-success">{{ formatMoney(inventorySellValue - inventoryValue) }}</span>
          </div>
          <div class="d-flex justify-space-between text-body-2">
            <span class="text-medium-emphasis">Total units</span>
            <span class="font-weight-medium">{{ totalUnits }}</span>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <h3 class="text-subtitle-1 font-weight-bold">Low stock alerts</h3>
            <v-spacer />
            <v-chip size="small" color="warning" variant="tonal">{{ lowStock.length }}</v-chip>
          </div>
          <EmptyState v-if="!lowStock.length" icon="mdi-check-circle" title="All stocked" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item
              v-for="s in lowStock.slice(0, 6)" :key="s.id"
              :to="`/inventory/stocks/${s.id}/edit`" class="px-0"
            >
              <v-list-item-title class="text-body-2">{{ s.medication_name || s.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                Reorder at {{ s.reorder_level }}
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="(s.total_quantity ?? s.quantity ?? 0) <= 0 ? 'error' : 'warning'" variant="tonal">
                  {{ s.total_quantity ?? s.quantity ?? 0 }}
                </v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <h3 class="text-subtitle-1 font-weight-bold">Expiring within 60 days</h3>
            <v-spacer />
            <v-chip size="small" color="error" variant="tonal">{{ expiring.length }}</v-chip>
          </div>
          <EmptyState v-if="!expiring.length" icon="mdi-check-circle" title="No items expiring" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item
              v-for="s in expiring.slice(0, 6)" :key="s.id"
              :to="`/inventory/stocks/${s.id}/edit`" class="px-0"
            >
              <v-list-item-title class="text-body-2">{{ s.medication_name || s.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                Expires {{ formatDate(s.expiry_date) }}
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" color="error" variant="tonal">{{ daysUntil(s.expiry_date) }}d</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- Customers + cashier performance -->
    <v-row>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-3">Top customers</h3>
          <EmptyState v-if="!topCustomers.length" icon="mdi-account-multiple-outline" title="No repeat customers yet" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(c, i) in topCustomers" :key="c.name" class="px-0">
              <template #prepend>
                <v-avatar size="36" color="primary" variant="tonal">{{ initials(c.name) }}</v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ c.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ c.orders }} order{{ c.orders > 1 ? 's' : '' }}</v-list-item-subtitle>
              <template #append>
                <span class="text-body-2 font-weight-bold">{{ formatMoney(c.spent) }}</span>
              </template>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-3">Cashier performance</h3>
          <EmptyState v-if="!cashierStats.length" icon="mdi-account-tie" title="No cashier data" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Cashier</th>
                <th class="text-right">Sales</th>
                <th class="text-right">Revenue</th>
                <th class="text-right">AOV</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="c in cashierStats" :key="c.name">
                <td class="font-weight-medium">{{ c.name }}</td>
                <td class="text-right">{{ c.count }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(c.revenue) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(c.aov) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'

const { $api } = useNuxtApp()

const rangeKey = ref('30d')
const loading = ref(false)
const topMetric = ref('revenue')
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')
const customRange = ref(null) // { start: Date, end: Date, label: string }

const txAll = ref([])
const stocks = ref([])

const barColors = ['#3b82f6', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4', '#ef4444', '#14b8a6']

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

// Returns { start, end, label } where end is EXCLUSIVE
function resolveRange(key) {
  const today = startOfDay(new Date())
  const tomorrow = addDays(today, 1)
  switch (key) {
    case 'today': return { start: today, end: tomorrow, label: 'Today' }
    case 'yesterday': {
      const y = addDays(today, -1)
      return { start: y, end: today, label: 'Yesterday' }
    }
    case '7d': return { start: addDays(today, -6), end: tomorrow, label: 'Last 7 days' }
    case '30d': return { start: addDays(today, -29), end: tomorrow, label: 'Last 30 days' }
    case '90d': return { start: addDays(today, -89), end: tomorrow, label: 'Last 90 days' }
    case '1y': return { start: addDays(today, -364), end: tomorrow, label: 'Last 365 days' }
    case 'thisMonth': {
      const s = new Date(today.getFullYear(), today.getMonth(), 1)
      return { start: s, end: tomorrow, label: 'This month' }
    }
    case 'lastMonth': {
      const s = new Date(today.getFullYear(), today.getMonth() - 1, 1)
      const e = new Date(today.getFullYear(), today.getMonth(), 1)
      return { start: s, end: e, label: 'Last month' }
    }
    case 'thisYear': {
      const s = new Date(today.getFullYear(), 0, 1)
      return { start: s, end: tomorrow, label: 'This year' }
    }
    case 'lastYear': {
      const s = new Date(today.getFullYear() - 1, 0, 1)
      const e = new Date(today.getFullYear(), 0, 1)
      return { start: s, end: e, label: 'Last year' }
    }
    case 'custom':
      return customRange.value || { start: addDays(today, -29), end: tomorrow, label: 'Custom' }
    default: return { start: addDays(today, -29), end: tomorrow, label: 'Last 30 days' }
  }
}

const activeRange = computed(() => resolveRange(rangeKey.value))
const cutoff = computed(() => activeRange.value.start)
const cutoffEnd = computed(() => activeRange.value.end)
const rangeDays = computed(() => Math.max(1, Math.round((cutoffEnd.value - cutoff.value) / 86400000)))
const rangeLabel = computed(() => activeRange.value.label)

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
  const e = addDays(startOfDay(new Date(customEnd.value)), 1) // exclusive
  if (e <= s) return
  const fmt = (d) => d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
  customRange.value = { start: s, end: e, label: `${fmt(s)} – ${fmt(addDays(e, -1))}` }
  rangeKey.value = 'custom'
  customDialog.value = false
}

const inRange = computed(() => txAll.value.filter(t => {
  const d = new Date(t.created_at || t.date || 0)
  return d >= cutoff.value && d < cutoffEnd.value
}))
const inPrevRange = computed(() => txAll.value.filter(t => {
  const d = new Date(t.created_at || t.date || 0)
  return d >= cutoffPrev.value && d < cutoff.value
}))

const totalRevenue = computed(() => inRange.value.reduce((s, t) => s + Number(t.total || t.total_amount || 0), 0))
const prevRevenue = computed(() => inPrevRange.value.reduce((s, t) => s + Number(t.total || t.total_amount || 0), 0))
const revenueDelta = computed(() => prevRevenue.value > 0 ? Math.round(((totalRevenue.value - prevRevenue.value) / prevRevenue.value) * 100) : null)

const totalOrders = computed(() => inRange.value.length)
const prevOrders = computed(() => inPrevRange.value.length)
const ordersDelta = computed(() => prevOrders.value > 0 ? Math.round(((totalOrders.value - prevOrders.value) / prevOrders.value) * 100) : null)

const aov = computed(() => totalOrders.value ? totalRevenue.value / totalOrders.value : 0)
const uniqueCustomers = computed(() => new Set(inRange.value.map(t => (t.customer_name || '').trim().toLowerCase()).filter(Boolean)).size)

const kpis = computed(() => [
  { title: 'Revenue', value: formatMoney(totalRevenue.value), icon: 'mdi-cash-multiple', color: 'primary', delta: revenueDelta.value, hint: `vs prior ${rangeDays.value} day${rangeDays.value > 1 ? 's' : ''}` },
  { title: 'Transactions', value: totalOrders.value, icon: 'mdi-receipt-text', color: 'info', delta: ordersDelta.value },
  { title: 'Avg. order value', value: formatMoney(aov.value), icon: 'mdi-trending-up', color: 'success', delta: null },
  { title: 'Unique customers', value: uniqueCustomers.value, icon: 'mdi-account-multiple', color: 'purple', delta: null }
])

// Day-bucketed series
function isoDay(d) { return d.toISOString().slice(0, 10) }
function shortLabel(d, days) {
  if (days <= 7) return d.toLocaleDateString(undefined, { weekday: 'short' })
  if (days <= 90) return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
  return d.toLocaleDateString(undefined, { month: 'short', year: '2-digit' })
}

const buckets = computed(() => {
  const days = rangeDays.value
  const start = cutoff.value
  const labels = []
  if (days <= 90) {
    const map = {}
    for (let i = 0; i < days; i++) {
      const d = addDays(start, i)
      map[isoDay(d)] = { rev: 0, ord: 0 }
      labels.push(shortLabel(d, days))
    }
    for (const t of inRange.value) {
      const k = isoDay(new Date(t.created_at || t.date))
      if (map[k]) {
        map[k].rev += Number(t.total || t.total_amount || 0)
        map[k].ord += 1
      }
    }
    return { rev: Object.values(map).map(v => v.rev), ord: Object.values(map).map(v => v.ord), labels }
  }
  // > 90d → bucket by week
  const weeks = Math.ceil(days / 7)
  for (let i = 0; i < weeks; i++) {
    labels.push(shortLabel(addDays(start, i * 7), days))
  }
  const rev = new Array(weeks).fill(0); const ord = new Array(weeks).fill(0)
  for (const t of inRange.value) {
    const td = new Date(t.created_at || t.date)
    const idx = Math.floor((td - start) / (7 * 86400000))
    if (idx >= 0 && idx < weeks) {
      rev[idx] += Number(t.total || t.total_amount || 0)
      ord[idx] += 1
    }
  }
  return { rev, ord, labels }
})

const revenueSeries = computed(() => buckets.value.rev)
const ordersSeries = computed(() => buckets.value.ord)
const seriesLabels = computed(() => buckets.value.labels)
const revenueTotal = computed(() => revenueSeries.value.reduce((a, b) => a + b, 0))

// Payment mix
const paymentSegments = computed(() => {
  const palette = { cash: '#22c55e', mpesa: '#16a34a', card: '#3b82f6', insurance: '#8b5cf6', other: '#94a3b8' }
  const map = {}
  for (const t of inRange.value) {
    const m = (t.payment_method || 'other').toLowerCase()
    map[m] = (map[m] || 0) + 1
  }
  const total = totalOrders.value || 1
  return Object.entries(map).map(([k, v]) => ({
    label: k.charAt(0).toUpperCase() + k.slice(1),
    value: v,
    color: palette[k] || '#94a3b8',
    pct: Math.round((v / total) * 100)
  })).sort((a, b) => b.value - a.value)
})

// Top products
const topProducts = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    for (const it of (t.items || [])) {
      const name = it.product_name || it.name || it.medication_name || 'Item'
      const qty = Number(it.quantity || 1)
      const rev = Number(it.total || it.subtotal || (it.unit_price * qty) || 0)
      const cur = map.get(name) || { name, qty: 0, revenue: 0, category: it.category_name || 'Other' }
      cur.qty += qty; cur.revenue += rev
      map.set(name, cur)
    }
  }
  const arr = [...map.values()].sort((a, b) => topMetric.value === 'qty' ? b.qty - a.qty : b.revenue - a.revenue).slice(0, 10)
  const max = arr[0] ? (topMetric.value === 'qty' ? arr[0].qty : arr[0].revenue) : 1
  return arr.map(p => ({ ...p, pct: ((topMetric.value === 'qty' ? p.qty : p.revenue) / max) * 100 }))
})

// Category sales
const categorySegments = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    for (const it of (t.items || [])) {
      const cat = it.category_name || it.category || 'Other'
      const rev = Number(it.total || it.subtotal || (it.unit_price * (it.quantity || 1)) || 0)
      map.set(cat, (map.get(cat) || 0) + rev)
    }
  }
  const arr = [...map.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8)
  return arr.map(([label, value], i) => ({ label, value, color: barColors[i % barColors.length] }))
})
const categoryTotal = computed(() => categorySegments.value.reduce((s, x) => s + x.value, 0))

// Hour heatmap
const hourCounts = computed(() => {
  const arr = new Array(24).fill(0)
  for (const t of inRange.value) {
    const d = new Date(t.created_at || 0)
    arr[d.getHours()] += 1
  }
  return arr
})

// Customers
const topCustomers = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    const name = (t.customer_name || '').trim()
    if (!name || name.toLowerCase() === 'walk-in') continue
    const cur = map.get(name) || { name, orders: 0, spent: 0 }
    cur.orders += 1
    cur.spent += Number(t.total || t.total_amount || 0)
    map.set(name, cur)
  }
  return [...map.values()].sort((a, b) => b.spent - a.spent).slice(0, 6)
})

// Cashier
const cashierStats = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    const name = t.cashier_name || t.created_by_name || t.user_name || 'Unknown'
    const cur = map.get(name) || { name, count: 0, revenue: 0 }
    cur.count += 1
    cur.revenue += Number(t.total || t.total_amount || 0)
    map.set(name, cur)
  }
  return [...map.values()].map(c => ({ ...c, aov: c.count ? c.revenue / c.count : 0 })).sort((a, b) => b.revenue - a.revenue)
})

// Stock derived
const inventoryValue = computed(() => stocks.value.reduce((s, x) =>
  s + Number(x.cost_price || 0) * Number(x.total_quantity ?? x.quantity ?? 0), 0))
const inventorySellValue = computed(() => stocks.value.reduce((s, x) =>
  s + Number(x.selling_price || 0) * Number(x.total_quantity ?? x.quantity ?? 0), 0))
const totalUnits = computed(() => stocks.value.reduce((s, x) => s + Number(x.total_quantity ?? x.quantity ?? 0), 0))

const lowStock = computed(() => stocks.value.filter(s => {
  const q = Number(s.total_quantity ?? s.quantity ?? 0)
  const r = Number(s.reorder_level || 0)
  return q <= 0 || (r > 0 && q <= r)
}).sort((a, b) => Number(a.total_quantity ?? a.quantity ?? 0) - Number(b.total_quantity ?? b.quantity ?? 0)))

const expiring = computed(() => {
  const soon = new Date(); soon.setDate(soon.getDate() + 60)
  return stocks.value
    .filter(s => s.expiry_date && new Date(s.expiry_date) <= soon)
    .sort((a, b) => new Date(a.expiry_date) - new Date(b.expiry_date))
})

function daysUntil(date) {
  if (!date) return 0
  return Math.max(0, Math.round((new Date(date) - new Date()) / 86400000))
}
function initials(name) {
  return name.split(/\s+/).map(p => p[0]).slice(0, 2).join('').toUpperCase()
}

async function load() {
  loading.value = true
  const safeList = (p) => $api.get(p).then(r => r.data?.results || (Array.isArray(r.data) ? r.data : [])).catch(() => [])
  const [tx, st] = await Promise.all([
    safeList('/pos/transactions/?page_size=1000'),
    safeList('/inventory/stocks/?page_size=500')
  ])
  txAll.value = tx
  stocks.value = st
  loading.value = false
}
onMounted(load)
</script>

<style scoped>
.legend-dot {
  width: 10px; height: 10px; border-radius: 50%;
  display: inline-block; flex-shrink: 0;
}
.w-100 { width: 100%; }
</style>
