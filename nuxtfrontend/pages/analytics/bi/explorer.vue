<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Data Explorer"
      subtitle="Self-service analytics — pick a dataset, dimensions, measures and filters"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-database-search"
      color="cyan"
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
        <v-btn variant="tonal" color="cyan" rounded="lg" class="text-none" prepend-icon="mdi-content-save-outline"
               @click="saveQuery">Save query</v-btn>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportResult">Export</v-btn>
      </template>
    </BiToolbar>

    <v-row>
      <!-- Query builder -->
      <v-col cols="12" lg="4">
        <BiPanel title="Query builder" subtitle="Compose a dataset view" icon="mdi-filter-variant" color="cyan">
          <v-select v-model="datasetKey" :items="datasetOptions" item-title="label" item-value="value"
                    label="Dataset" density="compact" variant="outlined" hide-details class="mb-3"
                    prepend-inner-icon="mdi-database" />

          <v-select v-model="dimensions" :items="availableDimensions" item-title="label" item-value="value"
                    label="Group by (dimensions)" multiple chips closable-chips density="compact"
                    variant="outlined" hide-details class="mb-3" prepend-inner-icon="mdi-table-column" />

          <v-select v-model="measures" :items="availableMeasures" item-title="label" item-value="value"
                    label="Measures" multiple chips closable-chips density="compact"
                    variant="outlined" hide-details class="mb-3" prepend-inner-icon="mdi-sigma" />

          <v-select v-model="aggregation" :items="aggregationOptions" item-title="label" item-value="value"
                    label="Aggregation" density="compact" variant="outlined" hide-details class="mb-3"
                    prepend-inner-icon="mdi-function-variant" />

          <v-select v-model="sortKey" :items="sortOptions" item-title="label" item-value="value"
                    label="Sort by" density="compact" variant="outlined" hide-details class="mb-3"
                    prepend-inner-icon="mdi-sort" />
          <v-btn-toggle v-model="sortDir" density="compact" variant="outlined" rounded="lg" mandatory class="mb-3">
            <v-btn value="desc" size="small" class="text-none" prepend-icon="mdi-sort-descending">Desc</v-btn>
            <v-btn value="asc" size="small" class="text-none" prepend-icon="mdi-sort-ascending">Asc</v-btn>
          </v-btn-toggle>

          <v-text-field v-model.number="rowLimit" type="number" label="Row limit" density="compact"
                        variant="outlined" hide-details class="mb-3" prepend-inner-icon="mdi-format-list-numbered" />

          <v-divider class="my-3" />
          <div class="d-flex align-center mb-2">
            <div class="text-subtitle-2 font-weight-bold">Filters</div>
            <v-spacer />
            <v-btn size="x-small" variant="text" color="cyan" class="text-none" prepend-icon="mdi-plus" @click="addFilter">Add</v-btn>
          </div>
          <div v-if="!filters.length" class="text-caption text-medium-emphasis mb-2">No filters applied — showing all rows.</div>
          <div v-for="(f, i) in filters" :key="i" class="d-flex align-center ga-1 mb-2">
            <v-select v-model="f.field" :items="availableFilterFields" item-title="label" item-value="value"
                      density="compact" variant="outlined" hide-details style="max-width: 130px" />
            <v-select v-model="f.op" :items="operators" density="compact" variant="outlined" hide-details style="max-width: 90px" />
            <v-text-field v-model="f.value" density="compact" variant="outlined" hide-details placeholder="value" />
            <v-btn icon="mdi-close" size="x-small" variant="text" color="error" @click="removeFilter(i)" />
          </div>
        </BiPanel>

        <BiPanel title="Saved queries" subtitle="Reusable views for this browser" icon="mdi-bookmark-multiple-outline" color="indigo" class="mt-3">
          <EmptyState v-if="!savedQueries.length" icon="mdi-bookmark-off-outline" title="No saved queries" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="q in savedQueries" :key="q.id" class="px-0">
              <template #prepend>
                <v-icon size="18" color="indigo">mdi-bookmark-outline</v-icon>
              </template>
              <v-list-item-title class="text-body-2">{{ q.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ q.summary }}</v-list-item-subtitle>
              <template #append>
                <v-btn icon="mdi-play" size="x-small" variant="text" color="cyan" @click="loadQuery(q)" />
                <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click="deleteQuery(q.id)" />
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>

      <!-- Result -->
      <v-col cols="12" lg="8">
        <BiPanel :title="resultTitle" :subtitle="resultSubtitle" icon="mdi-table-large" color="indigo">
          <template #actions>
            <v-btn-toggle v-model="view" density="compact" variant="outlined" color="indigo" rounded="lg" mandatory>
              <v-btn value="table" size="small" class="text-none" icon="mdi-table" />
              <v-btn value="bar" size="small" class="text-none" icon="mdi-chart-bar" />
              <v-btn value="line" size="small" class="text-none" icon="mdi-chart-line" />
              <v-btn value="donut" size="small" class="text-none" icon="mdi-chart-donut" />
            </v-btn-toggle>
          </template>

          <EmptyState v-if="!chartable && view !== 'table'" icon="mdi-chart-box-outline"
                      title="Cannot chart this shape"
                      message="Select exactly one dimension and at least one measure to render a chart, or switch back to the table view." />

          <template v-else-if="view === 'table'">
            <EmptyState v-if="!rows.length" icon="mdi-table-off" title="No rows match the query" />
            <div v-else style="overflow: auto; max-height: 640px">
              <v-table density="compact" class="bg-transparent">
                <thead>
                  <tr>
                    <th v-for="c in columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">{{ c.title }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(row, i) in rows" :key="i">
                    <td v-for="c in columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">{{ row[c.key] }}</td>
                  </tr>
                </tbody>
                <tfoot v-if="totals">
                  <tr class="font-weight-bold">
                    <td v-for="(c, i) in columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">
                      {{ i === 0 ? 'Total' : (totals[c.key] || '') }}
                    </td>
                  </tr>
                </tfoot>
              </v-table>
            </div>
          </template>

          <BarChart v-else-if="view === 'bar'" :values="chartValues" :labels="chartLabels" :height="360" rotate-labels show-values />
          <LineChart v-else-if="view === 'line'" :series="chartSeries" :labels="chartLabels" :height="360" />
          <div v-else-if="view === 'donut'" class="d-flex flex-column align-center">
            <DonutRing :segments="chartSegments" :size="260">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">{{ primaryMeasureLabel }}</div>
                <div class="text-subtitle-1 font-weight-bold">{{ primaryMeasureTotalText }}</div>
              </div>
            </DonutRing>
            <div class="mt-3 w-100">
              <div v-for="s in chartSegments" :key="s.label" class="d-flex align-center mb-1">
                <span class="legend-dot" :style="{ background: s.color }" />
                <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ s.display }}</span>
                <span class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
              </div>
            </div>
          </div>

          <template #footer>
            <div class="d-flex flex-wrap align-center ga-3 text-caption text-medium-emphasis">
              <span><v-icon size="14" class="mr-1">mdi-database-outline</v-icon>{{ sourceRows.length }} source rows</span>
              <span><v-icon size="14" class="mr-1">mdi-filter</v-icon>{{ filteredRows.length }} after filters</span>
              <span><v-icon size="14" class="mr-1">mdi-table</v-icon>{{ rows.length }} groups returned</span>
            </div>
          </template>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import { BI_PALETTE, num, sum, mean, compactNumber, downloadCsv, isoDay } from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  inRange, products, stocks, categories, branches, rfm, basket
} = useBiData({ defaultRange: '12m' })

const palette = BI_PALETTE

// ── datasets ────────────────────────────────────────────────────────────
const transactionsRows = computed(() =>
  inRange.value.map((t) => {
    const gross = num(t.subtotal ?? t.total ?? t.total_amount)
    const discount = num(t.discount ?? t.discount_amount)
    const items = t.items || []
    return {
      date: isoDay(t.created_at || t.date || new Date()),
      month: new Date(t.created_at || t.date || 0).toLocaleDateString(undefined, { month: 'short', year: '2-digit' }),
      branch: t.branch_name || 'Unassigned',
      payment: String(t.payment_method || 'other').toUpperCase(),
      customer: (t.customer_name || 'Walk-in').trim() || 'Walk-in',
      cashier: t.cashier_name || t.created_by_name || 'Unknown',
      lines: items.length,
      units: sum(items, (it) => it.quantity || 1),
      gross,
      discount,
      net: gross - discount
    }
  })
)

const productRows = computed(() =>
  products.value.map((p) => ({
    name: p.name,
    category: p.category,
    abc: p.abc,
    xyz: p.xyz || '—',
    units: num(p.qty),
    revenue: num(p.revenue),
    cost: num(p.cost),
    margin: num(p.revenue) - num(p.cost),
    marginPct: num(p.marginPct)
  }))
)

const stockRows = computed(() =>
  stocks.value.map((s) => {
    const onHand = num(s.total_quantity ?? s.quantity)
    return {
      name: s.medication_name || s.name || 'Item',
      category: s.category_name || s.category || 'Uncategorised',
      branch: s.branch_name || 'Unassigned',
      onHand,
      reorder: num(s.reorder_level),
      costPrice: num(s.cost_price),
      sellingPrice: num(s.selling_price),
      stockValue: onHand * num(s.cost_price),
      retailValue: onHand * num(s.selling_price),
      daysToExpiry: s.expiry_date ? Math.round((new Date(s.expiry_date) - new Date()) / 86400000) : 9999
    }
  })
)

const customerRows = computed(() =>
  rfm.value.rows.map((c) => ({
    name: c.name,
    segment: c.segment,
    recency: num(c.recency),
    frequency: num(c.f),
    monetary: num(c.m),
    rScore: num(c.rScore),
    fScore: num(c.fScore),
    mScore: num(c.mScore)
  }))
)

const categoryRows = computed(() => {
  const total = sum(categories.value, (c) => c.revenue) || 1
  return categories.value.map((c) => ({
    name: c.name,
    revenue: num(c.revenue),
    units: num(c.qty),
    orders: num(c.orders),
    share: (num(c.revenue) / total) * 100
  }))
})

const branchRows = computed(() => {
  const total = sum(branches.value, (b) => b.value) || 1
  return branches.value.map((b) => ({
    name: b.name,
    revenue: num(b.value),
    share: (num(b.value) / total) * 100,
    index: num(b.value) / (total / (branches.value.length || 1))
  }))
})

const ruleRows = computed(() =>
  basket.value.map((r) => ({
    antecedent: r.a,
    consequent: r.b,
    support: r.support * 100,
    confidence: r.confidence * 100,
    lift: r.lift
  }))
)

const datasets = {
  transactions: {
    label: 'Sales transactions',
    rows: transactionsRows,
    dimensions: [
      { value: 'date', label: 'Date' },
      { value: 'month', label: 'Month' },
      { value: 'branch', label: 'Branch' },
      { value: 'payment', label: 'Payment method' },
      { value: 'customer', label: 'Customer' },
      { value: 'cashier', label: 'Cashier' }
    ],
    measures: [
      { value: 'net', label: 'Net revenue', format: 'money' },
      { value: 'gross', label: 'Gross revenue', format: 'money' },
      { value: 'discount', label: 'Discount', format: 'money' },
      { value: 'units', label: 'Units', format: 'number' },
      { value: 'lines', label: 'Line items', format: 'number' }
    ]
  },
  products: {
    label: 'Product performance',
    rows: productRows,
    dimensions: [
      { value: 'name', label: 'Product' },
      { value: 'category', label: 'Category' },
      { value: 'abc', label: 'ABC class' },
      { value: 'xyz', label: 'XYZ class' }
    ],
    measures: [
      { value: 'revenue', label: 'Revenue', format: 'money' },
      { value: 'cost', label: 'Cost', format: 'money' },
      { value: 'margin', label: 'Margin', format: 'money' },
      { value: 'units', label: 'Units sold', format: 'number' },
      { value: 'marginPct', label: 'Margin %', format: 'percent' }
    ]
  },
  stock: {
    label: 'Stock on hand',
    rows: stockRows,
    dimensions: [
      { value: 'name', label: 'Item' },
      { value: 'category', label: 'Category' },
      { value: 'branch', label: 'Branch' }
    ],
    measures: [
      { value: 'onHand', label: 'Units on hand', format: 'number' },
      { value: 'stockValue', label: 'Stock value (cost)', format: 'money' },
      { value: 'retailValue', label: 'Retail value', format: 'money' },
      { value: 'reorder', label: 'Reorder level', format: 'number' },
      { value: 'daysToExpiry', label: 'Days to expiry', format: 'number' }
    ]
  },
  customers: {
    label: 'Customer segmentation',
    rows: customerRows,
    dimensions: [
      { value: 'name', label: 'Customer' },
      { value: 'segment', label: 'RFM segment' }
    ],
    measures: [
      { value: 'monetary', label: 'Spend', format: 'money' },
      { value: 'frequency', label: 'Orders', format: 'number' },
      { value: 'recency', label: 'Recency (days)', format: 'number' }
    ]
  },
  categories: {
    label: 'Category summary',
    rows: categoryRows,
    dimensions: [{ value: 'name', label: 'Category' }],
    measures: [
      { value: 'revenue', label: 'Revenue', format: 'money' },
      { value: 'units', label: 'Units', format: 'number' },
      { value: 'orders', label: 'Orders', format: 'number' }
    ]
  },
  branches: {
    label: 'Branch summary',
    rows: branchRows,
    dimensions: [{ value: 'name', label: 'Branch' }],
    measures: [
      { value: 'revenue', label: 'Revenue', format: 'money' },
      { value: 'share', label: 'Share %', format: 'percent' },
      { value: 'index', label: 'Index vs network', format: 'number' }
    ]
  },
  rules: {
    label: 'Cross-sell rules',
    rows: ruleRows,
    dimensions: [
      { value: 'antecedent', label: 'If bought' },
      { value: 'consequent', label: 'Then also' }
    ],
    measures: [
      { value: 'support', label: 'Support %', format: 'percent' },
      { value: 'confidence', label: 'Confidence %', format: 'percent' },
      { value: 'lift', label: 'Lift', format: 'number' }
    ]
  }
}

const datasetOptions = Object.entries(datasets).map(([value, d]) => ({ value, label: d.label }))

// ── query state ─────────────────────────────────────────────────────────
const datasetKey = ref('transactions')
const dimensions = ref(['month'])
const measures = ref(['net'])
const aggregation = ref('sum')
const filters = ref([])
const sortKey = ref('')
const sortDir = ref('desc')
const rowLimit = ref(50)
const view = ref('table')

const active = computed(() => datasets[datasetKey.value])
const availableDimensions = computed(() => active.value.dimensions)
const availableMeasures = computed(() => active.value.measures)
const availableFilterFields = computed(() => [...active.value.dimensions, ...active.value.measures])

const aggregationOptions = [
  { label: 'Sum', value: 'sum' },
  { label: 'Average', value: 'avg' },
  { label: 'Count', value: 'count' },
  { label: 'Maximum', value: 'max' },
  { label: 'Minimum', value: 'min' }
]
const operators = ['=', '!=', '>', '>=', '<', '<=', 'contains']

// Reset selections when the dataset changes.
watch(datasetKey, () => {
  dimensions.value = [active.value.dimensions[0]?.value].filter(Boolean)
  measures.value = [active.value.measures[0]?.value].filter(Boolean)
  filters.value = []
  sortKey.value = ''
})

const sourceRows = computed(() => active.value.rows.value || [])

function matches(row, f) {
  const raw = row[f.field]
  const val = f.value
  if (val === '' || val == null) return true
  const nRaw = num(raw)
  const nVal = num(val)
  switch (f.op) {
    case '=': return String(raw).toLowerCase() === String(val).toLowerCase() || nRaw === nVal
    case '!=': return String(raw).toLowerCase() !== String(val).toLowerCase()
    case '>': return nRaw > nVal
    case '>=': return nRaw >= nVal
    case '<': return nRaw < nVal
    case '<=': return nRaw <= nVal
    case 'contains': return String(raw).toLowerCase().includes(String(val).toLowerCase())
    default: return true
  }
}

const filteredRows = computed(() => {
  const activeFilters = filters.value.filter((f) => f.field && f.value !== '' && f.value != null)
  if (!activeFilters.length) return sourceRows.value
  return sourceRows.value.filter((row) => activeFilters.every((f) => matches(row, f)))
})

function convert(v, format) {
  if (format === 'money') return formatMoney(v)
  if (format === 'percent') return `${num(v).toFixed(1)}%`
  return compactNumber(v)
}

const measureDefs = computed(() => measures.value.map((m) => active.value.measures.find((x) => x.value === m)).filter(Boolean))

const queryResult = computed(() => {
  const dims = dimensions.value
  const ms = measureDefs.value
  const groups = new Map()
  for (const row of filteredRows.value) {
    const key = dims.map((d) => String(row[d] ?? '—')).join(' | ') || 'Total'
    if (!groups.has(key)) groups.set(key, { key, labels: dims.map((d) => String(row[d] ?? '—')), values: {}, counts: {} })
    const g = groups.get(key)
    for (const m of ms) {
      if (!g.values[m.value]) g.values[m.value] = []
      g.values[m.value].push(num(row[m.value]))
    }
    g.counts.all = (g.counts.all || 0) + 1
  }

  const reduce = (arr) => {
    const v = arr || []
    if (aggregation.value === 'avg') return v.length ? mean(v) : 0
    if (aggregation.value === 'count') return v.length
    if (aggregation.value === 'max') return v.length ? Math.max(...v) : 0
    if (aggregation.value === 'min') return v.length ? Math.min(...v) : 0
    return sum(v)
  }

  const out = [...groups.values()].map((g) => {
    const entry = {}
    g.labels.forEach((l, i) => { entry[`dim${i}`] = l })
    for (const m of ms) entry[m.value] = reduce(g.values[m.value])
    return entry
  })

  // Sorting
  const sorted = [...out]
  if (sortKey.value) {
    sorted.sort((a, b) => {
      const av = a[sortKey.value]
      const bv = b[sortKey.value]
      const an = num(av)
      const bn = num(bv)
      const cmp = Number.isFinite(an) && Number.isFinite(bn) ? an - bn : String(av).localeCompare(String(bv))
      return sortDir.value === 'asc' ? cmp : -cmp
    })
  } else if (ms.length) {
    sorted.sort((a, b) => num(b[ms[0].value]) - num(a[ms[0].value]))
  }

  const limited = sorted.slice(0, Math.max(1, Math.round(num(rowLimit.value) || 50)))

  // Formatted rows
  const columns = [
    ...dims.map((d, i) => ({ key: `dim${i}`, title: (active.value.dimensions.find((x) => x.value === d) || {}).label || d, align: 'left' })),
    ...ms.map((m) => ({ key: m.value, title: m.label, align: 'right' }))
  ]
  const rows = limited.map((entry) => {
    const r = {}
    dims.forEach((d, i) => { r[`dim${i}`] = entry[`dim${i}`] })
    for (const m of ms) r[m.value] = convert(entry[m.value], m.format)
    return r
  })

  // Totals
  let totals = null
  if (ms.length && aggregation.value !== 'avg') {
    totals = {}
    for (const m of ms) {
      const total = sum(limited, (e) => e[m.value])
      totals[m.value] = convert(total, m.format)
    }
  }

  return { columns, rows, totals, groups: limited, measureDefs: ms }
})

const columns = computed(() => queryResult.value.columns)
const rows = computed(() => queryResult.value.rows)
const totals = computed(() => queryResult.value.totals)

const sortOptions = computed(() => [
  ...dimensions.value.map((d, i) => ({ label: (active.value.dimensions.find((x) => x.value === d) || {}).label || d, value: `dim${i}` })),
  ...measureDefs.value.map((m) => ({ label: m.label, value: m.value }))
])

// ── charts ──────────────────────────────────────────────────────────────
const chartable = computed(() => dimensions.value.length === 1 && measureDefs.value.length >= 1 && queryResult.value.groups.length > 0)
const primaryMeasure = computed(() => measureDefs.value[0] || null)
const chartLabels = computed(() => queryResult.value.groups.map((g) => g.dim0))
const chartValues = computed(() => queryResult.value.groups.map((g) => num(g[primaryMeasure.value?.value])))
const chartSeries = computed(() => [{ label: primaryMeasure.value?.label || 'Value', color: '#0d9488', values: chartValues.value }])
const primaryMeasureLabel = computed(() => primaryMeasure.value?.label || 'Value')
const primaryMeasureTotalText = computed(() => (primaryMeasure.value ? convert(sum(chartValues.value), primaryMeasure.value.format) : '—'))
const chartSegments = computed(() => {
  const total = sum(chartValues.value) || 1
  return queryResult.value.groups.slice(0, 10).map((g, i) => {
    const v = num(g[primaryMeasure.value?.value])
    return {
      label: g.dim0,
      value: v,
      display: primaryMeasure.value ? convert(v, primaryMeasure.value.format) : String(v),
      color: palette[i % palette.length],
      pct: Math.round((v / total) * 100)
    }
  })
})

const resultTitle = computed(() => `${active.value.label} — result`)
const resultSubtitle = computed(() => {
  const d = dimensions.value.length
  const m = measureDefs.value.length
  return `${d ? `${d} dimension${d > 1 ? 's' : ''}` : 'no grouping'} · ${m} measure${m !== 1 ? 's' : ''} · ${aggregation.value} · ${rangeLabel.value}`
})

function addFilter() {
  filters.value.push({ field: availableFilterFields.value[0]?.value || '', op: '=', value: '' })
}
function removeFilter(i) {
  filters.value.splice(i, 1)
}

// ── saved queries ───────────────────────────────────────────────────────
const savedQueries = ref([])
if (import.meta.client) {
  try {
    const raw = localStorage.getItem('bi.queries')
    if (raw) savedQueries.value = JSON.parse(raw)
  } catch { /* ignore */ }
}
function currentQuery() {
  return {
    datasetKey: datasetKey.value,
    dimensions: [...dimensions.value],
    measures: [...measures.value],
    aggregation: aggregation.value,
    filters: filters.value.map((f) => ({ ...f })),
    sortKey: sortKey.value,
    sortDir: sortDir.value,
    rowLimit: rowLimit.value,
    view: view.value
  }
}
function saveQuery() {
  const q = {
    id: `q-${Date.now()}`,
    name: `${active.value.label} · ${measureDefs.value.map((m) => m.label).join(', ') || 'view'}`,
    summary: `${dimensions.value.length} dim · ${measures.value.length} measure · ${aggregation.value}`,
    config: currentQuery()
  }
  savedQueries.value.unshift(q)
  if (import.meta.client) localStorage.setItem('bi.queries', JSON.stringify(savedQueries.value.slice(0, 20)))
}
function loadQuery(q) {
  const c = q.config || {}
  datasetKey.value = c.datasetKey || 'transactions'
  // dataset watcher resets selections — re-apply after the reset
  requestAnimationFrame(() => {
    dimensions.value = c.dimensions || []
    measures.value = c.measures || []
    aggregation.value = c.aggregation || 'sum'
    filters.value = c.filters || []
    sortKey.value = c.sortKey || ''
    sortDir.value = c.sortDir || 'desc'
    rowLimit.value = c.rowLimit || 50
    view.value = c.view || 'table'
  })
}
function deleteQuery(id) {
  savedQueries.value = savedQueries.value.filter((q) => q.id !== id)
  if (import.meta.client) localStorage.setItem('bi.queries', JSON.stringify(savedQueries.value))
}

function exportResult() {
  downloadCsv(`explorer-${datasetKey.value}`, columns.value.map((c) => c.key), rows.value)
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
</style>
