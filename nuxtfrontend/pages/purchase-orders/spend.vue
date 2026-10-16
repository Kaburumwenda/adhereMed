<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Spend Analytics"
      subtitle="Where the money goes — supplier concentration, category mix, trend and savings capture"
      eyebrow="INSIGHTS · PROCUREMENT"
      icon="mdi-chart-donut-variant"
      color="indigo"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn-toggle v-model="basis" density="compact" variant="outlined" color="indigo" rounded="lg" mandatory>
          <v-btn value="committed" size="small" class="text-none">Committed</v-btn>
          <v-btn value="all" size="small" class="text-none">All orders</v-btn>
        </v-btn-toggle>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportSpend">Export</v-btn>
      </template>
    </ProcToolbar>

    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3" xl="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- Trend + concentration -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <BiPanel title="Spend trend" subtitle="Monthly purchase value and order count" icon="mdi-chart-areaspline" color="indigo">
          <BarChart
            :values="trendValues"
            :labels="trendLabels"
            :colors="trendLabels.map(() => '#6366f1')"
            :height="260"
            show-values
            :y-formatter="compactNumber"
          />
          <v-divider class="my-3" />
          <LineChart
            :series="[{ label: 'Orders', color: '#f59e0b', values: trendMonthly.map((m) => m.orders) }]"
            :labels="trendLabels"
            :height="160"
          />
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="4">
        <BiPanel title="Supplier concentration" subtitle="Pareto view of spend distribution" icon="mdi-chart-bell-curve-cumulative" color="teal">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <div class="text-caption text-medium-emphasis">Herfindahl index</div>
              <div class="text-h6 font-weight-bold">{{ Math.round(hhi) }}</div>
            </div>
            <v-chip :color="concentrationColor" variant="tonal" class="font-weight-bold">
              {{ concentrationLabel }}
            </v-chip>
          </div>
          <div v-for="s in supplierConcentration.slice(0, 8)" :key="s.name" class="mb-3">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-truncate" style="max-width: 55%">{{ s.name }}</span>
              <span class="font-weight-medium">{{ s.share.toFixed(1) }}%</span>
            </div>
            <v-progress-linear :model-value="s.share" color="teal" height="7" rounded />
            <div class="text-caption text-medium-emphasis">cumulative {{ s.cumShare.toFixed(1) }}%</div>
          </div>
          <v-divider class="my-2" />
          <v-alert :type="hhi > 2500 ? 'warning' : 'info'" variant="tonal" density="compact" class="text-caption">
            {{ concentrationAdvice }}
          </v-alert>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Category mix + top items -->
    <v-row class="mt-1">
      <v-col cols="12" lg="5">
        <BiPanel title="Spend by category" subtitle="Product family mix of purchased value" icon="mdi-shape-outline" color="purple">
          <EmptyState v-if="!categorySpend.length" icon="mdi-tag-off-outline" title="No category data"
                      message="Link purchased items to stock records to classify spend." />
          <template v-else>
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="categorySegments" :size="230">
                <div class="text-center">
                  <div class="text-caption text-medium-emphasis">Total</div>
                  <div class="text-subtitle-1 font-weight-bold">{{ formatMoney(totalSpendBasis) }}</div>
                </div>
              </DonutRing>
            </div>
            <div v-for="s in categorySegments" :key="s.label" class="d-flex align-center mb-1">
              <span class="legend-dot" :style="{ background: s.color }" />
              <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
              <span class="text-body-2 font-weight-medium">{{ formatMoney(s.value) }}</span>
              <span class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
            </div>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="7">
        <BiPanel title="Top purchased items by value" subtitle="Highest-value lines across all purchase orders" icon="mdi-cube-outline" color="amber">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportItems">CSV</v-btn>
          </template>
          <EmptyState v-if="!topItems.length" icon="mdi-cube-off-outline" title="No purchase lines" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th style="width: 36px">#</th>
                <th>Item</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Orders</th>
                <th class="text-right">Spend</th>
                <th class="text-right">Avg unit cost</th>
                <th style="width: 18%">Share</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, i) in topItems.slice(0, 15)" :key="it.name">
                <td class="text-medium-emphasis">{{ i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width: 240px">{{ it.name }}</td>
                <td class="text-right">{{ it.qty.toLocaleString() }}</td>
                <td class="text-right">{{ it.orders }}</td>
                <td class="text-right font-weight-bold">{{ formatMoney(it.value) }}</td>
                <td class="text-right">{{ formatMoney(it.avgCost) }}</td>
                <td>
                  <v-progress-linear :model-value="it.pct" :color="palette[i % palette.length]" height="6" rounded />
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- ABC + savings + freight -->
    <v-row class="mt-1">
      <v-col cols="12" lg="4">
        <BiPanel title="Supplier ABC portfolio" subtitle="Pareto classification of vendor spend" icon="mdi-sort-alphabetical-variant" color="cyan">
          <EmptyState v-if="!abcSummary.length" icon="mdi-chart-box-outline" title="No supplier spend" />
          <template v-else>
            <v-row dense class="mb-3">
              <v-col v-for="a in abcSummary" :key="a.class" cols="4">
                <v-card rounded="lg" class="pa-3 text-center" variant="tonal" :color="abcColor(a.class)">
                  <div class="text-h6 font-weight-bold">{{ a.class }}</div>
                  <div class="text-caption">{{ a.count }} suppliers</div>
                  <div class="text-body-2 font-weight-medium">{{ Math.round(a.share) }}% of spend</div>
                </v-card>
              </v-col>
            </v-row>
            <v-table density="compact" class="bg-transparent">
              <thead><tr><th>Supplier</th><th class="text-center">Class</th><th class="text-right">Spend</th></tr></thead>
              <tbody>
                <tr v-for="r in abcRows.slice(0, 10)" :key="r.name">
                  <td class="text-truncate" style="max-width: 170px">{{ r.name }}</td>
                  <td class="text-center">
                    <v-chip size="x-small" :color="abcColor(r.abc)" variant="tonal">{{ r.abc }}</v-chip>
                  </td>
                  <td class="text-right">{{ formatMoney(r.spend) }}</td>
                </tr>
              </tbody>
            </v-table>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="4">
        <BiPanel title="Savings capture" subtitle="Value secured through competitive sourcing" icon="mdi-piggy-bank-outline" color="success">
          <v-row dense>
            <v-col v-for="s in savingsTiles" :key="s.label" cols="6">
              <v-card rounded="lg" class="pa-3 h-100" variant="tonal" :color="s.color">
                <div class="text-caption font-weight-medium">{{ s.label }}</div>
                <div class="text-h6 font-weight-bold">{{ s.value }}</div>
                <div class="text-caption">{{ s.hint }}</div>
              </v-card>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-2">Savings rate against spend</div>
          <v-progress-linear
            :model-value="Math.min(100, savingsRate)"
            color="success"
            height="12"
            rounded
          >
            <strong>{{ savingsRate.toFixed(1) }}%</strong>
          </v-progress-linear>
          <div class="text-caption text-medium-emphasis mt-2">
            Benchmark organisations typically capture 3–8% of addressable spend per year.
          </div>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="4">
        <BiPanel title="Cost structure" subtitle="Where the purchase budget lands" icon="mdi-chart-waterfall" color="deep-orange">
          <div v-for="c in costStructure" :key="c.label" class="mb-3">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span>{{ c.label }}</span>
              <span class="font-weight-medium">{{ formatMoney(c.value) }}</span>
            </div>
            <v-progress-linear :model-value="c.pct" :color="c.color" height="7" rounded />
            <div class="text-caption text-medium-emphasis">{{ c.hint }}</div>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between text-body-2">
            <span class="text-medium-emphasis">Freight as % of goods</span>
            <span class="font-weight-bold">{{ shippingShare.toFixed(1) }}%</span>
          </div>
          <div class="d-flex justify-space-between text-body-2">
            <span class="text-medium-emphasis">Average order value</span>
            <span class="font-weight-bold">{{ formatMoney(avgOrderValue) }}</span>
          </div>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Supplier table -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Spend by supplier" subtitle="Full breakdown with period-over-period comparison" icon="mdi-truck-outline" color="primary">
          <template #actions>
            <v-text-field v-model="search" placeholder="Search supplier…" variant="solo-filled" density="compact"
                          hide-details flat rounded="lg" bg-color="surface" prepend-inner-icon="mdi-magnify"
                          clearable style="max-width: 220px" />
          </template>
          <EmptyState v-if="!filteredSuppliers.length" icon="mdi-truck-off-outline" title="No supplier spend" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Supplier</th>
                <th class="text-right">Spend</th>
                <th class="text-right">Share</th>
                <th class="text-right">Orders</th>
                <th class="text-right">Average order</th>
                <th class="text-right">Freight</th>
                <th class="text-right">Last order</th>
                <th class="text-right">Score</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in filteredSuppliers" :key="s.name">
                <td>
                  <div class="d-flex align-center ga-2">
                    <v-avatar size="26" :color="palette[0]" variant="tonal">
                      <span class="text-caption font-weight-bold">{{ initials(s.name) }}</span>
                    </v-avatar>
                    <span class="font-weight-medium text-truncate" style="max-width: 200px">{{ s.name }}</span>
                  </div>
                </td>
                <td class="text-right font-weight-bold">{{ formatMoney(s.spend) }}</td>
                <td class="text-right">
                  <div class="d-flex align-center justify-end ga-2">
                    <v-progress-linear :model-value="s.share" color="primary" height="6" rounded style="max-width: 70px" />
                    <span>{{ s.share.toFixed(1) }}%</span>
                  </div>
                </td>
                <td class="text-right">{{ s.orders }}</td>
                <td class="text-right">{{ formatMoney(s.avgOrderValue) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(s.shipping) }}</td>
                <td class="text-right text-medium-emphasis">{{ s.lastOrder ? formatDate(s.lastOrder) : '—' }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="s.score >= 85 ? 'success' : s.score >= 70 ? 'info' : 'warning'" variant="tonal">
                    {{ s.score ?? '—' }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="font-weight-bold">
                <td>Total</td>
                <td class="text-right">{{ formatMoney(totalSpendBasis) }}</td>
                <td class="text-right">100%</td>
                <td class="text-right">{{ sum(filteredSuppliers, (s) => s.orders) }}</td>
                <td colspan="4" />
              </tr>
            </tfoot>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { BI_PALETTE, num, sum, mean, abcClass, compactNumber, downloadCsv, round } from '~/utils/bi'

const {
  loading, ordersEnriched, supplierRows, supplierConcentration, hhi, totalSpend,
  avgOrderValue, shippingSpend, shippingShare, identifiedSavings, rfqSavings,
  priceSavingOpportunity, multiSourced, singleSourced,
  branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const palette = BI_PALETTE
const basis = ref('committed')
const search = ref('')

const baseOrders = computed(() =>
  basis.value === 'committed'
    ? ordersEnriched.value.filter((o) => ['sent', 'partial', 'received'].includes(o.status))
    : ordersEnriched.value
)

const totalSpendBasis = computed(() => sum(baseOrders.value, (o) => o.landedCost))

// Monthly trend respecting the committed/all basis toggle.
const trendMonthly = computed(() => {
  const base = new Date()
  base.setDate(1)
  const buckets = []
  for (let i = 11; i >= 0; i--) {
    const d = new Date(base.getFullYear(), base.getMonth() - i, 1)
    buckets.push({
      label: d.toLocaleDateString(undefined, { month: 'short', year: '2-digit' }),
      y: d.getFullYear(),
      m: d.getMonth(),
      total: 0,
      orders: 0
    })
  }
  const idx = new Map(buckets.map((b, i) => [`${b.y}-${b.m}`, i]))
  for (const o of baseOrders.value) {
    const d = new Date(o.order_date || o.created_at || 0)
    if (Number.isNaN(d.getTime())) continue
    const i = idx.get(`${d.getFullYear()}-${d.getMonth()}`)
    if (i == null) continue
    buckets[i].total += o.landedCost
    buckets[i].orders += 1
  }
  return buckets
})

const trendValues = computed(() => trendMonthly.value.map((b) => b.total))
const trendLabels = computed(() => trendMonthly.value.map((b) => b.label))

const filteredSuppliers = computed(() => {
  if (!search.value) return supplierRows.value
  const q = search.value.toLowerCase()
  return supplierRows.value.filter((s) => s.name.toLowerCase().includes(q))
})

// ── category spend (from stock lookup, when available) ──────────────────
const categorySpend = computed(() => {
  const map = new Map()
  for (const o of baseOrders.value) {
    for (const it of o.items || []) {
      const cat = it.category_name || it.category || 'Uncategorised'
      const value = num(it.total) || num(it.unit_cost) * num(it.qty)
      map.set(cat, (map.get(cat) || 0) + value)
    }
  }
  return [...map.entries()].map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value)
})

const categorySegments = computed(() => {
  const total = sum(categorySpend.value, (c) => c.value) || 1
  return categorySpend.value.slice(0, 8).map((c, i) => ({
    label: c.name,
    value: c.value,
    color: palette[i % palette.length],
    pct: Math.round((c.value / total) * 100)
  }))
})

// ── top items ───────────────────────────────────────────────────────────
const topItems = computed(() => {
  const map = new Map()
  for (const o of baseOrders.value) {
    for (const it of o.items || []) {
      const name = String(it.name || it.item_name || 'Item').trim()
      const qty = num(it.qty)
      const value = num(it.total) || num(it.unit_cost) * qty
      const row = map.get(name) || { name, qty: 0, value: 0, orders: 0 }
      row.qty += qty
      row.value += value
      row.orders += 1
      map.set(name, row)
    }
  }
  const rows = [...map.values()].sort((a, b) => b.value - a.value)
  const max = rows[0]?.value || 1
  const total = sum(rows, (r) => r.value) || 1
  return rows.map((r) => ({
    ...r,
    avgCost: r.qty ? r.value / r.qty : 0,
    pct: (r.value / max) * 100,
    share: (r.value / total) * 100
  }))
})

// ── ABC of suppliers ────────────────────────────────────────────────────
const abcRows = computed(() => abcClass(supplierRows.value, { valueKey: 'spend' }).rows)
const abcSummary = computed(() => abcClass(supplierRows.value, { valueKey: 'spend' }).summary)

function abcColor(k) {
  return k === 'A' ? 'success' : k === 'B' ? 'warning' : 'grey'
}

// ── concentration ───────────────────────────────────────────────────────
const concentrationColor = computed(() =>
  hhi.value > 2500 ? 'error' : hhi.value > 1500 ? 'warning' : 'success'
)
const concentrationLabel = computed(() =>
  hhi.value > 2500 ? 'Highly concentrated' : hhi.value > 1500 ? 'Moderately concentrated' : 'Well diversified'
)
const concentrationAdvice = computed(() => {
  if (hhi.value > 2500) return 'Spend is heavily concentrated. Qualify secondary suppliers to reduce single-source exposure.'
  if (hhi.value > 1500) return 'Moderate concentration. Keep at least two qualified sources for your top categories.'
  return 'Spend is well diversified across suppliers — good continuity of supply.'
})

// ── savings ─────────────────────────────────────────────────────────────
const savingsTiles = computed(() => [
  { label: 'Identified', value: formatMoney(identifiedSavings.value), hint: 'Best vs worst quote', color: 'info' },
  { label: 'Realised', value: formatMoney(rfqSavings.value), hint: 'On awarded RFQs', color: 'success' },
  { label: 'Price opportunity', value: formatMoney(priceSavingOpportunity.value), hint: 'Best agreed price', color: 'teal' },
  { label: 'Competition depth', value: `${multiSourced.value.length} / ${multiSourced.value.length + singleSourced.value.length}`, hint: 'Dual-sourced items', color: 'purple' }
])

const savingsRate = computed(() => {
  const base = totalSpendBasis.value || 1
  return ((identifiedSavings.value + priceSavingOpportunity.value) / base) * 100
})

// ── cost structure ──────────────────────────────────────────────────────
const costStructure = computed(() => {
  const goods = sum(baseOrders.value, (o) => num(o.total_cost))
  const freight = sum(baseOrders.value, (o) => num(o.shipping_cost))
  const total = goods + freight || 1
  return [
    { label: 'Goods value', value: goods, pct: (goods / total) * 100, color: 'indigo', hint: `${((goods / total) * 100).toFixed(1)}% of landed cost` },
    { label: 'Freight and duties', value: freight, pct: (freight / total) * 100, color: 'deep-orange', hint: `${((freight / total) * 100).toFixed(1)}% of landed cost` }
  ]
})

const monthlyKpisSource = computed(() => trendValues.value.filter((v) => v > 0))

const kpis = computed(() => {
  const months = monthlyKpisSource.value
  return [
    { title: 'Total spend', value: formatMoney(totalSpendBasis.value), valueNum: totalSpendBasis.value, icon: 'mdi-cash-multiple', color: 'primary', hint: basis.value === 'committed' ? 'Committed orders' : 'All orders' },
    { title: 'Monthly average', value: formatMoney(months.length ? mean(months) : 0), icon: 'mdi-calendar-month-outline', color: 'indigo', hint: `${months.length} active months` },
    { title: 'Suppliers used', value: String(supplierRows.value.length), icon: 'mdi-truck-outline', color: 'teal', hint: `${multiSourced.value.length} multi-sourced items` },
    { title: 'Average order', value: formatMoney(avgOrderValue.value), valueNum: avgOrderValue.value, icon: 'mdi-cart-outline', color: 'cyan', hint: `${baseOrders.value.length} orders` },
    { title: 'Freight cost', value: formatMoney(shippingSpend.value), valueNum: shippingSpend.value, icon: 'mdi-truck-fast-outline', color: 'deep-orange', invertDelta: true, hint: `${shippingShare.value.toFixed(1)}% of spend` },
    { title: 'Savings captured', value: `${savingsRate.value.toFixed(1)}%`, valueNum: savingsRate.value, icon: 'mdi-piggy-bank-outline', color: 'success', hint: 'Of addressable spend' }
  ]
})

function initials(name) {
  return String(name || '?').split(/\s+/).map((p) => p[0]).slice(0, 2).join('').toUpperCase()
}

function exportSpend() {
  downloadCsv(
    'spend-by-supplier',
    ['name', 'spend', 'share', 'orders', 'avgOrderValue', 'shipping', 'score'],
    filteredSuppliers.value.map((s) => ({
      ...s,
      spend: round(s.spend, 2),
      share: round(s.share, 2),
      avgOrderValue: round(s.avgOrderValue, 2),
      shipping: round(s.shipping, 2)
    }))
  )
}

function exportItems() {
  downloadCsv('top-purchased-items', ['name', 'qty', 'orders', 'value', 'avgCost', 'share'], topItems.value)
}

void num
void compactNumber
void totalSpend
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
