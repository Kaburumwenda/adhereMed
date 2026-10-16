<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="KPI Dashboards"
      subtitle="Composable dashboards, widgets and a custom KPI builder"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-view-dashboard-variant"
      color="indigo"
      :range-key="rangeKey"
      :range-options="BI_RANGE_OPTIONS"
      :range-label="rangeLabel"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      :loading="loading"
      :target="monthlyTarget"
      :custom-dialog="customDialog"
      :custom-start="customStart"
      :custom-end="customEnd"
      @update:range-key="onRangeChange"
      @update:branch-filter="(v) => (branchFilter = v)"
      @update:target="setMonthlyTarget"
      @update:custom-dialog="(v) => (customDialog = v)"
      @update:custom-start="(v) => (customStart = v)"
      @update:custom-end="(v) => (customEnd = v)"
      @refresh="load"
      @apply-custom="applyCustom"
    >
      <template #actions>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-plus"
               @click="builderDialog = true">Custom KPI</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportDashboard">Export</v-btn>
      </template>
    </BiToolbar>

    <!-- Dashboard library -->
    <v-card rounded="lg" class="pa-3 mb-4" border>
      <div class="d-flex flex-wrap align-center ga-2">
        <div class="text-caption text-medium-emphasis mr-2">Dashboard library</div>
        <v-chip-group v-model="dashboard" selected-class="text-white" mandatory column>
          <v-chip
            v-for="d in dashboards"
            :key="d.key"
            :value="d.key"
            :color="dashboard === d.key ? d.color : undefined"
            :prepend-icon="d.icon"
            variant="tonal"
            filter
          >{{ d.label }}</v-chip>
        </v-chip-group>
        <v-spacer />
        <v-btn-toggle v-model="density" density="compact" variant="outlined" rounded="lg" mandatory>
          <v-btn value="comfortable" size="small" class="text-none" icon="mdi-view-agenda-outline" />
          <v-btn value="compact" size="small" class="text-none" icon="mdi-view-grid-outline" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Widget grid -->
    <v-row v-if="widgets.length" :dense="density === 'compact'">
      <v-col v-for="w in widgets" :key="w.key" :cols="12" :md="w.md || 6" :lg="w.lg || 6">
        <BiPanel :title="w.title" :subtitle="w.subtitle" :icon="w.icon" :color="w.color">
          <template #actions>
            <v-btn icon="mdi-download-outline" size="x-small" variant="text" @click="exportWidget(w)" />
          </template>

          <!-- KPI strip -->
          <v-row v-if="w.type === 'stats'" dense>
            <v-col v-for="s in w.stats" :key="s.label" cols="6" md="3">
              <div class="bi-stat">
                <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
                <div class="text-subtitle-1 font-weight-bold">{{ s.value }}</div>
                <div v-if="s.hint" class="text-caption text-medium-emphasis">{{ s.hint }}</div>
              </div>
            </v-col>
          </v-row>

          <LineChart
            v-else-if="w.type === 'line'"
            :series="w.series"
            :labels="w.labels"
            :height="260"
            :y-formatter="w.formatter"
          />

          <div v-else-if="w.type === 'bar'" style="overflow-x: auto">
            <BarChart
              :values="w.values"
              :labels="w.labels"
              :colors="w.colors"
              :height="260"
              :rotate-labels="w.labels.length > 8"
              :y-formatter="w.formatter"
            />
          </div>

          <div v-else-if="w.type === 'donut'" class="d-flex flex-column align-center">
            <DonutRing :segments="w.segments" :size="220">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">{{ w.centerLabel }}</div>
                <div class="text-subtitle-1 font-weight-bold">{{ w.centerValue }}</div>
              </div>
            </DonutRing>
            <div class="mt-3 w-100">
              <div v-for="s in w.segments" :key="s.label" class="d-flex align-center mb-1">
                <span class="legend-dot" :style="{ background: s.color }" />
                <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ w.money ? formatMoney(s.value) : s.value }}</span>
                <span v-if="s.pct != null" class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
              </div>
            </div>
          </div>

          <HourHeatmap v-else-if="w.type === 'heatmap'" :counts="w.counts" unit="sales" color="#0d9488" />

          <v-progress-circular
            v-else-if="w.type === 'gauge'"
            :model-value="w.pct"
            :color="w.gaugeColor"
            :size="150"
            :width="14"
            class="mx-auto d-block my-3"
          >
            <div class="text-center">
              <div class="text-h6 font-weight-bold">{{ w.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ w.label }}</div>
            </div>
          </v-progress-circular>

          <v-table v-else-if="w.type === 'table'" density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th v-for="c in w.columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">{{ c.title }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, i) in w.rows" :key="i">
                <td v-for="c in w.columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">{{ row[c.key] }}</td>
              </tr>
            </tbody>
          </v-table>

          <EmptyState v-else-if="w.type === 'empty'" :icon="w.icon2 || 'mdi-chart-box-outline'" :title="w.emptyTitle" :message="w.emptyMessage" />

          <v-list v-else-if="w.type === 'list'" density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(l, i) in w.items" :key="i" class="px-0">
              <v-list-item-title class="text-body-2">{{ l.title }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ l.subtitle }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="l.color" variant="tonal">{{ l.value }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <v-card v-else rounded="lg" class="pa-8 text-center" border>
      <v-icon size="56" color="indigo" class="mb-3">mdi-tune-variant</v-icon>
      <div class="text-h6 font-weight-bold mb-1">No saved KPIs yet</div>
      <div class="text-body-2 text-medium-emphasis mb-4">
        Build your own metric with the custom KPI builder and pin it to this dashboard.
      </div>
      <v-btn color="indigo" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="builderDialog = true">Create a custom KPI</v-btn>
    </v-card>

    <!-- Custom KPI builder -->
    <v-dialog v-model="builderDialog" max-width="620">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom KPI builder</v-card-title>
        <v-card-subtitle>Define a metric, aggregation and chart, then pin it to this dashboard.</v-card-subtitle>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="draft.title" label="KPI title" density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="draft.metric" :items="metricOptions" item-title="label" item-value="value"
                        label="Measure" density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="draft.agg" :items="aggOptions" item-title="label" item-value="value"
                        label="Aggregation" density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="draft.dimension" :items="dimensionOptions" item-title="label" item-value="value"
                        label="Group by" density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="draft.chart" :items="chartOptions" item-title="label" item-value="value"
                        label="Visualisation" density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="draft.target" type="number" label="Target (optional)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-1">Live preview</div>
          <div class="d-flex align-center ga-4">
            <div>
              <div class="text-caption text-medium-emphasis">{{ draft.title || 'Untitled KPI' }}</div>
              <div class="text-h6 font-weight-bold">{{ customKpiPreview.totalText }}</div>
            </div>
            <v-progress-linear v-if="draft.target" :model-value="customKpiPreview.attainment" color="teal" height="8" rounded class="flex-grow-1" />
          </div>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="customKpis.length" variant="text" color="error" class="text-none" @click="clearCustom">Clear all</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="builderDialog = false">Cancel</v-btn>
          <v-btn color="indigo" variant="flat" class="text-none" @click="saveCustomKpi">Pin KPI</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import { BI_PALETTE, num, sum, mean, compactNumber, downloadCsv } from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, rangeDays, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  inRange, revenue, revenueDelta, orders, aov, grossMargin,
  unitsSold, customers, inventoryCost, inventoryRetail, unitsOnHand, lowStock, expiring, daysUntil,
  historyMonthly, historyValues, historyLabels, products, categories, branches,
  hourCounts, rfm, basket, drivers, forecast
} = useBiData({ defaultRange: '12m' })

const palette = BI_PALETTE
const dashboard = ref('executive')
const density = ref('comfortable')
const builderDialog = ref(false)

const dashboards = [
  { key: 'executive', label: 'Executive', icon: 'mdi-crown-outline', color: 'indigo' },
  { key: 'sales', label: 'Sales', icon: 'mdi-cart-outline', color: 'teal' },
  { key: 'inventory', label: 'Inventory', icon: 'mdi-package-variant', color: 'amber' },
  { key: 'procurement', label: 'Procurement', icon: 'mdi-truck-outline', color: 'cyan' },
  { key: 'customer', label: 'Customer', icon: 'mdi-account-group-outline', color: 'deep-purple' },
  { key: 'supply', label: 'Supply chain', icon: 'mdi-transit-connection-variant', color: 'blue' },
  { key: 'custom', label: 'My KPIs', icon: 'mdi-tune-variant', color: 'purple' }
]

// ── page-level derived data ─────────────────────────────────────────────
const paymentSegments = computed(() => {
  const colors = { cash: '#22c55e', mpesa: '#16a34a', card: '#3b82f6', insurance: '#8b5cf6', other: '#94a3b8' }
  const map = {}
  for (const t of inRange.value) {
    const k = String(t.payment_method || 'other').toLowerCase()
    map[k] = (map[k] || 0) + 1
  }
  const total = orders.value || 1
  return Object.entries(map)
    .map(([k, v]) => ({ label: k.charAt(0).toUpperCase() + k.slice(1), value: v, color: colors[k] || '#94a3b8', pct: Math.round((v / total) * 100) }))
    .sort((a, b) => b.value - a.value)
})

const categorySegments = computed(() =>
  categories.value.slice(0, 8).map((c, i) => ({ label: c.name, value: c.revenue, color: palette[i % palette.length], pct: revenue.value ? Math.round((c.revenue / revenue.value) * 100) : 0 }))
)

const branchBar = computed(() => ({
  values: branches.value.map((b) => b.value),
  labels: branches.value.map((b) => b.name),
  colors: branches.value.map((_, i) => palette[i % palette.length])
}))

// ── custom KPI engine ───────────────────────────────────────────────────
const metricOptions = [
  { label: 'Revenue', value: 'revenue' },
  { label: 'Orders', value: 'orders' },
  { label: 'Units sold', value: 'units' },
  { label: 'Average order value', value: 'aov' },
  { label: 'Gross margin', value: 'margin' },
  { label: 'Gross margin %', value: 'marginPct' }
]
const aggOptions = [
  { label: 'Sum', value: 'sum' },
  { label: 'Average', value: 'avg' },
  { label: 'Count', value: 'count' },
  { label: 'Maximum', value: 'max' },
  { label: 'Minimum', value: 'min' }
]
const dimensionOptions = [
  { label: 'Total (no grouping)', value: 'none' },
  { label: 'Category', value: 'category' },
  { label: 'Branch', value: 'branch' },
  { label: 'Product', value: 'product' },
  { label: 'Payment method', value: 'payment' }
]
const chartOptions = [
  { label: 'KPI tile', value: 'stats' },
  { label: 'Bar chart', value: 'bar' },
  { label: 'Line chart', value: 'line' },
  { label: 'Donut', value: 'donut' }
]

const draft = ref({ title: '', metric: 'revenue', agg: 'sum', dimension: 'none', chart: 'stats', target: 0 })
const customKpis = ref([])
if (import.meta.client) {
  try {
    const raw = localStorage.getItem('bi.customKpis')
    if (raw) customKpis.value = JSON.parse(raw)
  } catch { /* ignore */ }
}

/** Extract the per-transaction contribution for a measure. */
function txMeasure(t, metric) {
  const rev = num(t.total ?? t.total_amount)
  if (metric === 'revenue') return rev
  if (metric === 'orders') return 1
  if (metric === 'units') return sum(t.items || [], (it) => it.quantity || 1)
  if (metric === 'aov') return rev
  if (metric === 'margin' || metric === 'marginPct') {
    const cost = sum(t.items || [], (it) => num(it.cost_price ?? it.unit_cost) * num(it.quantity || 1))
    return rev - cost
  }
  return 0
}

function aggregate(values, agg) {
  const v = values.map(num)
  if (!v.length) return 0
  if (agg === 'avg') return mean(v)
  if (agg === 'count') return v.length
  if (agg === 'max') return Math.max(...v)
  if (agg === 'min') return Math.min(...v)
  return sum(v)
}

function evalKpi(kpi) {
  const dim = kpi.dimension || 'none'

  // Ungrouped — aggregate the raw measures directly.
  if (dim === 'none') {
    const raw = inRange.value.map((t) => txMeasure(t, kpi.metric))
    const value = aggregate(raw, kpi.agg)
    const isPct = kpi.metric === 'marginPct'
    return {
      entries: [{ label: 'Total', value }],
      total: value,
      totalText: isPct ? `${value.toFixed(1)}%` : (kpi.metric === 'orders' || kpi.metric === 'units') ? compactNumber(value) : formatMoney(value)
    }
  }

  const buckets = new Map()
  const push = (key, value) => {
    if (!buckets.has(key)) buckets.set(key, [])
    buckets.get(key).push(value)
  }

  if (dim === 'category' || dim === 'product') {
    for (const t of inRange.value) {
      const items = t.items || []
      if (!items.length) {
        push(dim === 'category' ? 'Uncategorised' : 'Unspecified', txMeasure(t, kpi.metric))
        continue
      }
      for (const it of items) {
        const key = dim === 'category'
          ? (it.category_name || it.category || 'Other')
          : String(it.product_name || it.name || it.medication_name || 'Item').trim()
        const q = num(it.quantity || 1)
        let value
        if (kpi.metric === 'units') value = q
        else if (kpi.metric === 'orders') value = 1
        else if (kpi.metric === 'margin' || kpi.metric === 'marginPct') value = num(it.total ?? it.subtotal ?? num(it.unit_price) * q) - num(it.cost_price ?? it.unit_cost) * q
        else value = num(it.total ?? it.subtotal ?? num(it.unit_price) * q)
        push(key, value)
      }
    }
  } else if (dim === 'branch' || dim === 'payment') {
    for (const t of inRange.value) {
      const key = dim === 'branch'
        ? (t.branch_name || 'Unassigned')
        : String(t.payment_method || 'other').toUpperCase()
      push(key, txMeasure(t, kpi.metric))
    }
  }

  let entries = [...buckets.entries()].map(([label, values]) => ({ label, value: aggregate(values, kpi.agg) }))
  entries = entries.sort((a, b) => b.value - a.value).slice(0, 12)
  const total = sum(entries, (e) => e.value)
  const isPct = kpi.metric === 'marginPct'
  return {
    entries,
    total,
    totalText: isPct ? `${total.toFixed(1)}%` : (kpi.metric === 'orders' || kpi.metric === 'units') ? compactNumber(total) : formatMoney(total)
  }
}

const customKpiPreview = computed(() => {
  const r = evalKpi(draft.value)
  return {
    totalText: r.totalText,
    attainment: draft.value.target ? Math.max(0, Math.min(100, (r.total / draft.value.target) * 100)) : 0
  }
})

function saveCustomKpi() {
  const kpi = { ...draft.value, id: `kpi-${Date.now()}`, title: draft.value.title || 'Custom KPI' }
  customKpis.value.push(kpi)
  if (import.meta.client) localStorage.setItem('bi.customKpis', JSON.stringify(customKpis.value))
  builderDialog.value = false
  draft.value = { title: '', metric: 'revenue', agg: 'sum', dimension: 'none', chart: 'stats', target: 0 }
}
function clearCustom() {
  customKpis.value = []
  if (import.meta.client) localStorage.removeItem('bi.customKpis')
}

// ── reusable widget factory ─────────────────────────────────────────────
const revenueTrendWidget = computed(() => ({
  key: 'revenueTrend',
  title: 'Revenue trend',
  subtitle: `Trailing 12 months · ${rangeLabel.value}`,
  icon: 'mdi-chart-timeline-variant',
  color: 'teal',
  type: 'line',
  lg: 8,
  labels: historyLabels.value,
  series: [{ label: 'Revenue', color: '#0d9488', values: historyValues.value }],
  formatter: compactNumber
}))

const ordersTrendWidget = computed(() => ({
  key: 'ordersTrend',
  title: 'Order volume',
  subtitle: 'Transactions per month',
  icon: 'mdi-chart-bar',
  color: 'indigo',
  type: 'bar',
  lg: 4,
  values: historyMonthly.value.map((b) => b.orders),
  labels: historyLabels.value,
  colors: historyLabels.value.map(() => '#6366f1'),
  formatter: (v) => String(Math.round(num(v)))
}))

const kpiSummaryWidget = computed(() => ({
  key: 'kpiSummary',
  title: 'Headline measures',
  subtitle: rangeLabel.value,
  icon: 'mdi-counter',
  color: 'primary',
  type: 'stats',
  lg: 12,
  stats: [
    { label: 'Revenue', value: formatMoney(revenue.value), hint: revenueDelta.value == null ? '' : `${revenueDelta.value >= 0 ? '+' : ''}${revenueDelta.value.toFixed(1)}% vs prior` },
    { label: 'Orders', value: orders.value.toLocaleString(), hint: `${customers.value} customers` },
    { label: 'Avg order value', value: formatMoney(aov.value), hint: 'Per transaction' },
    { label: 'Gross margin', value: `${grossMargin.value.marginPct.toFixed(1)}%`, hint: formatMoney(grossMargin.value.margin) },
    { label: 'Units sold', value: unitsSold.value.toLocaleString(), hint: 'All lines' },
    { label: 'Inventory at cost', value: formatMoney(inventoryCost.value), hint: `${unitsOnHand.value.toLocaleString()} units` },
    { label: 'Stock turns', value: stockTurn.value, hint: 'Annualised' },
    { label: 'Next period', value: formatMoney(forecast.value.forecast[0] || 0), hint: `MAPE ${forecast.value.accuracy.mape.toFixed(1)}%` }
  ]
}))

const stockTurn = computed(() => {
  const annual = rangeDays.value ? (grossMargin.value.cost / rangeDays.value) * 365 : 0
  return inventoryCost.value ? `${(annual / inventoryCost.value).toFixed(2)}x` : '—'
})

const categoryWidget = computed(() => ({
  key: 'categoryMix',
  title: 'Revenue by category',
  subtitle: 'Contribution analysis',
  icon: 'mdi-shape',
  color: 'deep-purple',
  type: 'donut',
  lg: 4,
  segments: categorySegments.value,
  centerLabel: 'Total',
  centerValue: formatMoney(revenue.value),
  money: true
}))

const paymentWidget = computed(() => ({
  key: 'paymentMix',
  title: 'Payment mix',
  subtitle: 'Transactions by method',
  icon: 'mdi-credit-card-outline',
  color: 'cyan',
  type: 'donut',
  lg: 4,
  segments: paymentSegments.value,
  centerLabel: 'Transactions',
  centerValue: orders.value.toLocaleString(),
  money: false
}))

const branchWidget = computed(() => ({
  key: 'branchPerf',
  title: 'Branch performance',
  subtitle: 'Revenue per location',
  icon: 'mdi-store-marker-outline',
  color: 'blue',
  type: branches.value.length ? 'bar' : 'empty',
  lg: 8,
  values: branchBar.value.values,
  labels: branchBar.value.labels,
  colors: branchBar.value.colors,
  formatter: compactNumber,
  emptyTitle: 'No branch data'
}))

const topProductsWidget = computed(() => ({
  key: 'topProducts',
  title: 'Top products',
  subtitle: 'By revenue in the selected period',
  icon: 'mdi-trophy-outline',
  color: 'amber',
  type: products.value.length ? 'table' : 'empty',
  lg: 6,
  columns: [
    { key: 'name', title: 'Product' },
    { key: 'qty', title: 'Qty', align: 'right' },
    { key: 'revenue', title: 'Revenue', align: 'right' },
    { key: 'marginPct', title: 'Margin', align: 'right' }
  ],
  rows: products.value.slice(0, 10).map((p) => ({
    name: p.name,
    qty: num(p.qty).toLocaleString(),
    revenue: formatMoney(p.revenue),
    marginPct: `${num(p.marginPct).toFixed(1)}%`
  })),
  emptyTitle: 'No product sales'
}))

const stockHealthWidget = computed(() => ({
  key: 'stockHealth',
  title: 'Stock health',
  subtitle: 'Live inventory position',
  icon: 'mdi-package-variant',
  color: 'teal',
  type: 'stats',
  lg: 6,
  stats: [
    { label: 'Active SKUs', value: String(products.value.length || 0) },
    { label: 'Units on hand', value: unitsOnHand.value.toLocaleString() },
    { label: 'Below reorder point', value: String(lowStock.value.length) },
    { label: 'Retail value', value: formatMoney(inventoryRetail.value) }
  ]
}))

const expiryWidget = computed(() => ({
  key: 'expiry',
  title: 'Expiry watch',
  subtitle: 'Batches expiring within 90 days',
  icon: 'mdi-calendar-alert',
  color: 'red',
  type: expiring.value.length ? 'list' : 'empty',
  lg: 6,
  items: expiring.value.slice(0, 8).map((s) => ({
    title: s.medication_name || s.name,
    subtitle: `Expires ${new Date(s.expiry_date).toLocaleDateString()}`,
    value: `${daysUntil(s.expiry_date)}d`,
    color: 'error'
  })),
  emptyTitle: 'Nothing expiring',
  emptyMessage: 'No batches expire in the next 90 days.'
}))

const lowStockWidget = computed(() => ({
  key: 'lowStock',
  title: 'Replenishment queue',
  subtitle: 'At or below reorder level',
  icon: 'mdi-bell-alert-outline',
  color: 'warning',
  type: lowStock.value.length ? 'list' : 'empty',
  lg: 6,
  items: lowStock.value.slice(0, 8).map((s) => ({
    title: s.medication_name || s.name,
    subtitle: `Reorder at ${num(s.reorder_level)}`,
    value: String(num(s.total_quantity ?? s.quantity)),
    color: num(s.total_quantity ?? s.quantity) <= 0 ? 'error' : 'warning'
  })),
  emptyTitle: 'All stocked'
}))

const hourWidget = computed(() => ({
  key: 'hour',
  title: 'Demand by hour',
  subtitle: 'When transactions happen',
  icon: 'mdi-clock-outline',
  color: 'purple',
  type: 'heatmap',
  lg: 6,
  counts: hourCounts.value
}))

const rfmWidget = computed(() => ({
  key: 'rfm',
  title: 'Customer segments',
  subtitle: 'RFM segmentation',
  icon: 'mdi-account-group-outline',
  color: 'deep-purple',
  type: rfm.value.summary.length ? 'table' : 'empty',
  lg: 6,
  columns: [
    { key: 'segment', title: 'Segment' },
    { key: 'customers', title: 'Customers', align: 'right' },
    { key: 'revenue', title: 'Revenue', align: 'right' },
    { key: 'avgRecency', title: 'Avg recency', align: 'right' }
  ],
  rows: rfm.value.summary.slice(0, 8).map((s) => ({
    segment: s.segment,
    customers: s.customers,
    revenue: formatMoney(s.revenue),
    avgRecency: `${s.avgRecency}d`
  })),
  emptyTitle: 'No named customers'
}))

const abcWidget = computed(() => {
  const a = products.value.filter((p) => p.abc === 'A').length
  const b = products.value.filter((p) => p.abc === 'B').length
  const c = products.value.filter((p) => p.abc === 'C').length
  return {
    key: 'abc',
    title: 'ABC concentration',
    subtitle: 'Portfolio classification',
    icon: 'mdi-sort-alphabetical-variant',
    color: 'green',
    type: 'bar',
    lg: 6,
    values: [a, b, c],
    labels: ['A — top 80%', 'B — next 15%', 'C — last 5%'],
    colors: ['#22c55e', '#f59e0b', '#94a3b8'],
    formatter: (v) => `${Math.round(num(v))} SKUs`
  }
})

const driversWidget = computed(() => ({
  key: 'drivers',
  title: 'Movement drivers',
  subtitle: 'Category contribution to the period change',
  icon: 'mdi-waterfall',
  color: 'orange',
  type: drivers.value.length ? 'bar' : 'empty',
  lg: 6,
  values: drivers.value.slice(0, 8).map((d) => Math.round(d.impact)),
  labels: drivers.value.slice(0, 8).map((d) => d.label),
  colors: drivers.value.slice(0, 8).map((d) => (d.impact >= 0 ? '#22c55e' : '#ef4444')),
  formatter: compactNumber,
  emptyTitle: 'No movement to attribute'
}))

const crossSellWidget = computed(() => ({
  key: 'crossSell',
  title: 'Cross-sell rules',
  subtitle: 'Market-basket associations',
  icon: 'mdi-vector-combine',
  color: 'teal',
  type: basket.value.length ? 'table' : 'empty',
  lg: 6,
  columns: [
    { key: 'a', title: 'If bought' },
    { key: 'b', title: 'Then also' },
    { key: 'confidence', title: 'Conf.', align: 'right' },
    { key: 'lift', title: 'Lift', align: 'right' }
  ],
  rows: basket.value.slice(0, 8).map((r) => ({
    a: r.a,
    b: r.b,
    confidence: `${(r.confidence * 100).toFixed(0)}%`,
    lift: `${r.lift.toFixed(2)}x`
  })),
  emptyTitle: 'No rules yet'
}))

const marginGaugeWidget = computed(() => ({
  key: 'marginGauge',
  title: 'Margin achievement',
  subtitle: 'Gross margin vs 25% guardrail',
  icon: 'mdi-speedometer',
  color: 'amber',
  type: 'gauge',
  lg: 4,
  pct: Math.max(0, Math.min(100, (grossMargin.value.marginPct / 25) * 100)),
  gaugeColor: grossMargin.value.marginPct >= 25 ? 'success' : grossMargin.value.marginPct >= 18 ? 'warning' : 'error',
  value: `${grossMargin.value.marginPct.toFixed(1)}%`,
  label: 'of 25% floor'
}))

const unitsGaugeWidget = computed(() => ({
  key: 'sellThrough',
  title: 'Sell-through',
  subtitle: 'Units sold vs available',
  icon: 'mdi-package-check',
  color: 'teal',
  type: 'gauge',
  lg: 4,
  pct: Math.max(0, Math.min(100, sellThrough.value)),
  gaugeColor: sellThrough.value >= 60 ? 'success' : sellThrough.value >= 35 ? 'warning' : 'error',
  value: `${sellThrough.value.toFixed(1)}%`,
  label: 'sell-through'
}))

const sellThrough = computed(() => {
  const available = unitsOnHand.value + unitsSold.value
  return available ? (unitsSold.value / available) * 100 : 0
})

const targetGaugeWidget = computed(() => {
  const target = monthlyTarget.value
  const last = historyValues.value[historyValues.value.length - 1] || 0
  const pct = target ? Math.min(100, (last / target) * 100) : 0
  return {
    key: 'targetGauge',
    title: 'Month vs target',
    subtitle: target ? `Target ${formatMoney(target)}` : 'Set a monthly target from the toolbar',
    icon: 'mdi-target',
    color: 'purple',
    type: 'gauge',
    lg: 4,
    pct,
    gaugeColor: pct >= 100 ? 'success' : pct >= 85 ? 'warning' : 'error',
    value: `${pct.toFixed(0)}%`,
    label: 'of target'
  }
})

const customKpiWidgets = computed(() =>
  customKpis.value.map((k, i) => {
    const r = evalKpi(k)
    const isTableLike = k.chart === 'bar' || k.chart === 'line' || k.chart === 'donut'
    const base = {
      key: k.id,
      title: k.title,
      subtitle: `${metricLabel(k.metric)} · ${aggLabel(k.agg)} · by ${dimensionLabel(k.dimension)}`,
      icon: 'mdi-tune-variant',
      color: palette[i % palette.length],
      lg: 6
    }
    if (k.chart === 'donut') {
      return { ...base, type: 'donut', segments: r.entries.map((e, j) => ({ label: e.label, value: e.value, color: palette[j % palette.length], pct: r.total ? Math.round((e.value / r.total) * 100) : 0 })), centerLabel: 'Total', centerValue: r.totalText, money: k.metric !== 'orders' && k.metric !== 'units' }
    }
    if (isTableLike) {
      return { ...base, type: 'bar', values: r.entries.map((e) => e.value), labels: r.entries.map((e) => e.label), colors: r.entries.map((_, j) => palette[j % palette.length]), formatter: k.metric === 'orders' || k.metric === 'units' ? (v) => String(Math.round(num(v))) : compactNumber }
    }
    return { ...base, type: 'stats', stats: [{ label: 'Value', value: r.totalText, hint: k.target ? `Target ${k.target}` : '' }, ...r.entries.slice(0, 3).map((e) => ({ label: e.label, value: k.metric === 'orders' || k.metric === 'units' ? compactNumber(e.value) : formatMoney(e.value) }))] }
  })
)

function metricLabel(m) { return (metricOptions.find((o) => o.value === m) || {}).label || m }
function aggLabel(a) { return (aggOptions.find((o) => o.value === a) || {}).label || a }
function dimensionLabel(d) { return (dimensionOptions.find((o) => o.value === d) || {}).label || d }

// ── dashboard → widget mapping ──────────────────────────────────────────
const widgetMap = {
  executive: ['kpiSummary', 'revenueTrend', 'ordersTrend', 'categoryMix', 'branchPerf', 'marginGauge', 'targetGauge', 'drivers'],
  sales: ['kpiSummary', 'revenueTrend', 'ordersTrend', 'topProducts', 'categoryMix', 'paymentMix', 'hour', 'crossSell'],
  inventory: ['stockHealth', 'abc', 'lowStock', 'expiry', 'sellThrough', 'marginGauge', 'drivers'],
  procurement: ['stockHealth', 'lowStock', 'expiry', 'drivers', 'branchPerf'],
  customer: ['rfm', 'crossSell', 'revenueTrend', 'topProducts', 'hour'],
  supply: ['stockHealth', 'branchPerf', 'lowStock', 'expiry', 'ordersTrend', 'hour'],
  custom: []
}

const allWidgets = computed(() => [
  kpiSummaryWidget.value, revenueTrendWidget.value, ordersTrendWidget.value, categoryWidget.value,
  paymentWidget.value, branchWidget.value, topProductsWidget.value, stockHealthWidget.value,
  expiryWidget.value, lowStockWidget.value, hourWidget.value, rfmWidget.value, abcWidget.value,
  driversWidget.value, crossSellWidget.value, marginGaugeWidget.value, unitsGaugeWidget.value,
  targetGaugeWidget.value
])

const widgets = computed(() => {
  if (dashboard.value === 'custom') return customKpiWidgets.value
  const keys = widgetMap[dashboard.value] || []
  return keys.map((k) => allWidgets.value.find((w) => w.key === k)).filter(Boolean)
})

// ── export ──────────────────────────────────────────────────────────────
function exportWidget(w) {
  if (w.type === 'table') {
    downloadCsv(`${w.key}-${new Date().toISOString().slice(0, 10)}`, w.columns.map((c) => c.key), w.rows)
    return
  }
  if (w.type === 'stats') {
    downloadCsv(`${w.key}-${new Date().toISOString().slice(0, 10)}`, ['label', 'value', 'hint'], w.stats)
    return
  }
  if (w.type === 'donut') {
    downloadCsv(`${w.key}-${new Date().toISOString().slice(0, 10)}`, ['label', 'value', 'pct'], w.segments)
    return
  }
  if (w.values && w.labels) {
    downloadCsv(`${w.key}-${new Date().toISOString().slice(0, 10)}`, ['label', 'value'], w.labels.map((l, i) => ({ label: l, value: w.values[i] })))
  }
}
function exportDashboard() {
  const widget = widgets.value[0]
  if (widget) exportWidget(widget)
}
</script>

<style scoped>
.legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}
.w-100 {
  width: 100%;
}
.bi-stat {
  padding: 8px 0;
}
</style>
