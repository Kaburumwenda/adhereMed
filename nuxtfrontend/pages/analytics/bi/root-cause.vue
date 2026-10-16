<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Root-Cause Analysis"
      subtitle="Diagnose why performance moved — price, volume, mix, stockouts and discounting"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-magnify-scan"
      color="deep-purple"
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
        <v-btn variant="tonal" color="deep-purple" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportBridge">Export bridge</v-btn>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-tune-variant"
               :to="`${biBase}/optimization`">Optimiser</v-btn>
      </template>
    </BiToolbar>

    <!-- Verdict banner -->
    <v-alert :color="verdict.color" variant="tonal" rounded="lg" border="start" prominent class="mb-4">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-icon size="26" class="mr-1">{{ verdict.icon }}</v-icon>
        <div class="flex-grow-1">
          <div class="text-subtitle-1 font-weight-bold">{{ verdict.headline }}</div>
          <div class="text-body-2">{{ verdict.detail }}</div>
        </div>
        <div class="d-flex align-center ga-2">
          <v-chip variant="flat" :color="verdict.color" class="font-weight-bold">{{ verdict.chip }}</v-chip>
        </div>
      </div>
    </v-alert>

    <!-- Effect decomposition -->
    <v-row dense>
      <v-col v-for="e in effects" :key="e.label" cols="12" sm="6" md="3" xl="2">
        <KpiTile
          :title="e.label"
          :value="formatMoney(e.value)"
          :value-num="e.value"
          :icon="e.icon"
          :color="e.color"
          :delta="e.pct"
          delta-label="of movement"
          :hint="e.hint"
        />
      </v-col>
    </v-row>

    <!-- Waterfall + drivers -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel
          title="Revenue bridge"
          subtitle="Opening position → closing position, reconciled by driver"
          icon="mdi-waterfall"
          color="deep-purple"
        >
          <template #actions>
            <v-btn-toggle v-model="bridgeView" density="compact" variant="outlined" color="deep-purple" rounded="lg" mandatory>
              <v-btn value="chart" size="small" class="text-none">Chart</v-btn>
              <v-btn value="table" size="small" class="text-none">Table</v-btn>
            </v-btn-toggle>
          </template>

          <template v-if="bridgeView === 'chart'">
            <BarChart
              :values="bridgeChart.values"
              :labels="bridgeChart.labels"
              :colors="bridgeChart.colors"
              :height="280"
              rotate-labels
              show-values
              :y-formatter="compactNumber"
            />
          </template>

          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Step</th>
                <th class="text-right">Impact</th>
                <th class="text-right">Running total</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in bridgeRows" :key="row.label">
                <td :class="row.emphasis ? 'font-weight-bold' : ''">{{ row.label }}</td>
                <td class="text-right" :class="row.tone">{{ row.impactText }}</td>
                <td class="text-right font-weight-medium">{{ row.runningText }}</td>
              </tr>
            </tbody>
          </v-table>

          <v-divider class="my-3" />
          <v-row dense>
            <v-col cols="4">
              <div class="text-caption text-medium-emphasis">Previous</div>
              <div class="text-subtitle-1 font-weight-bold">{{ formatMoney(prevRevenue) }}</div>
            </v-col>
            <v-col cols="4" class="text-center">
              <div class="text-caption text-medium-emphasis">Net change</div>
              <div class="text-subtitle-1 font-weight-bold" :class="netChange >= 0 ? 'text-success' : 'text-error'">
                {{ netChange >= 0 ? '+' : '' }}{{ formatMoney(netChange) }}
              </div>
            </v-col>
            <v-col cols="4" class="text-right">
              <div class="text-caption text-medium-emphasis">Current</div>
              <div class="text-subtitle-1 font-weight-bold">{{ formatMoney(revenue) }}</div>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <InsightNarrative
          title="Why it happened"
          subtitle="Ranked causal narrative"
          color="deep-purple"
          :tone="verdict.tone"
          :headline="narrativeHeadline"
          :points="narrativePoints"
          :loading="loading"
          footer="Attribution uses a price / volume / mix decomposition reconciled to the period-over-period variance."
        />
      </v-col>
    </v-row>

    <!-- Pareto + stockout -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Pareto of loss contributors" subtitle="Cumulative share of the adverse movement" icon="mdi-chart-bell-curve-cumulative" color="error">
          <EmptyState v-if="!lossPareto.length" icon="mdi-check-decagram" title="No adverse contributors" message="No category reduced revenue versus the prior period." />
          <template v-else>
            <div v-for="p in lossPareto" :key="p.label" class="mb-3">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span class="text-truncate" style="max-width: 55%">{{ p.label }}</span>
                <span class="text-error font-weight-medium">{{ formatMoney(Math.abs(p.impact)) }}</span>
              </div>
              <v-progress-linear :model-value="p.cumPct" color="error" height="7" rounded />
              <div class="text-caption text-medium-emphasis">cumulative {{ p.cumPct.toFixed(0) }}%</div>
            </div>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Stockout impact" subtitle="Lost sales opportunity from unavailable stock" icon="mdi-package-variant-remove" color="orange">
          <template #actions>
            <v-chip size="small" color="warning" variant="tonal">{{ stockoutRows.length }}</v-chip>
          </template>
          <v-row dense class="mb-2">
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Estimated lost revenue</div>
              <div class="text-subtitle-1 font-weight-bold text-error">{{ formatMoney(lostRevenue) }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Items fully out of stock</div>
              <div class="text-subtitle-1 font-weight-bold">{{ outOfStockCount }}</div>
            </v-col>
          </v-row>
          <EmptyState v-if="!stockoutRows.length" icon="mdi-check-circle" title="No stockouts" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Item</th><th class="text-right">On hand</th><th class="text-right">Reorder</th><th class="text-right">Est. lost</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in stockoutRows.slice(0, 8)" :key="s.name">
                <td class="text-truncate" style="max-width: 200px">{{ s.name }}</td>
                <td class="text-right">{{ s.onHand }}</td>
                <td class="text-right text-medium-emphasis">{{ s.reorder }}</td>
                <td class="text-right text-error font-weight-medium">{{ formatMoney(s.lost) }}</td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Discount + anomalies -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Discount and pricing pressure" subtitle="How price concessions moved revenue" icon="mdi-sale-outline" color="pink">
          <v-row dense>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Discount given (current)</div>
              <div class="text-subtitle-1 font-weight-bold">{{ formatMoney(discountCur) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Discount given (prior)</div>
              <div class="text-subtitle-1 font-weight-bold">{{ formatMoney(discountPrev) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Avg discount rate</div>
              <div class="text-subtitle-1 font-weight-bold">{{ avgDiscountRate.toFixed(2) }}%</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Price effect</div>
              <div class="text-subtitle-1 font-weight-bold" :class="decomp.price >= 0 ? 'text-success' : 'text-error'">
                {{ decomp.price >= 0 ? '+' : '' }}{{ formatMoney(decomp.price) }}
              </div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-2">Average selling price per unit</div>
          <BarChart
            :values="aspSeries.values"
            :labels="aspSeries.labels"
            color="#ec4899"
            :height="180"
            :y-formatter="compactNumber"
          />
          <v-alert v-if="!hasDiscountData" type="info" variant="tonal" density="compact" class="mt-3 text-caption">
            No explicit discount fields were found on the sales feed. Discount effects are inferred from average selling price
            movement — connect a discount column to sharpen this attribution.
          </v-alert>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Anomaly detection" subtitle="Months deviating more than 1.5σ from the trend" icon="mdi-chart-scatter-plot-hero" color="cyan">
          <EmptyState v-if="!monthAnomalies.length" icon="mdi-chart-line-stacked" title="Series looks stable" message="No month deviates materially from the trailing trend." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Month</th><th class="text-right">Revenue</th><th class="text-right">Z-score</th><th class="text-right">Direction</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="a in monthAnomalies" :key="a.i">
                <td class="font-weight-medium">{{ historyLabels[a.i] }}</td>
                <td class="text-right">{{ formatMoney(a.value) }}</td>
                <td class="text-right">{{ a.z.toFixed(2) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="a.z >= 0 ? 'success' : 'error'" variant="tonal">
                    {{ a.z >= 0 ? 'Above trend' : 'Below trend' }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">Month-on-month change</div>
          <SparkArea :values="momValues" :labels="historyLabels" :height="140" color="#06b6d4" />
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Drill-down -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Cost-centre drill-down" subtitle="Product-level variance with ABC / XYZ classification" icon="mdi-table-search" color="indigo">
          <template #actions>
            <v-text-field v-model="search" placeholder="Search product…" prepend-inner-icon="mdi-magnify"
                          density="compact" variant="outlined" hide-details clearable style="max-width: 260px" />
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportDrill">CSV</v-btn>
          </template>
          <EmptyState v-if="!drillRows.length" icon="mdi-package-variant-closed" title="No product movements" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Product</th><th>Category</th><th class="text-center">ABC</th><th class="text-center">XYZ</th>
                <th class="text-right">Current</th><th class="text-right">Previous</th>
                <th class="text-right">Variance</th><th class="text-right">Var %</th>
                <th style="width: 15%">Contribution</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in drillRows" :key="r.name">
                <td class="text-truncate font-weight-medium" style="max-width: 220px">{{ r.name }}</td>
                <td class="text-medium-emphasis">{{ r.category }}</td>
                <td class="text-center"><v-chip size="x-small" :color="abcColor(r.abc)" variant="tonal">{{ r.abc }}</v-chip></td>
                <td class="text-center"><v-chip size="x-small" :color="xyzColor(r.xyz)" variant="tonal">{{ r.xyz || '—' }}</v-chip></td>
                <td class="text-right">{{ formatMoney(r.current) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(r.previous) }}</td>
                <td class="text-right" :class="r.variance >= 0 ? 'text-success' : 'text-error'">
                  {{ r.variance >= 0 ? '+' : '' }}{{ formatMoney(r.variance) }}
                </td>
                <td class="text-right">{{ r.varPct == null ? '—' : `${r.varPct.toFixed(1)}%` }}</td>
                <td>
                  <v-progress-linear :model-value="r.weight" :color="r.variance >= 0 ? 'success' : 'error'" height="6" rounded />
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Five whys -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Root-cause chain (5 Whys)" subtitle="Auto-generated causal ladder from the attributed drivers" icon="mdi-help-circle-outline" color="amber">
          <v-timeline density="compact" side="end" truncate-line="both">
            <v-timeline-item
              v-for="(w, i) in fiveWhys"
              :key="i"
              :dot-color="w.color"
              size="small"
            >
              <div class="d-flex flex-wrap align-center ga-2 mb-1">
                <span class="text-caption font-weight-bold text-uppercase" style="letter-spacing: .8px">Why {{ i + 1 }}</span>
                <v-chip size="x-small" :color="w.color" variant="tonal">{{ w.tag }}</v-chip>
              </div>
              <div class="text-body-2 font-weight-medium">{{ w.question }}</div>
              <div class="text-body-2 text-medium-emphasis">{{ w.answer }}</div>
            </v-timeline-item>
          </v-timeline>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import { num, sum, pctChange, abcClass, xyzClass, compactNumber, downloadCsv, round } from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, rangeDays, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  inRange, inPrevRange, revenue, prevRevenue, orders, prevOrders,
  aov, lowStock, drivers, historyMonthly, historyValues, historyLabels, monthAnomalies,
  biBase
} = useBiData({ defaultRange: '12m' })

const bridgeView = ref('chart')
const search = ref('')

// ── decomposition maths ─────────────────────────────────────────────────
const prevAov = computed(() => (prevOrders.value ? prevRevenue.value / prevOrders.value : 0))

const decomp = computed(() => {
  const curRev = revenue.value
  const prevRev = prevRevenue.value
  const total = curRev - prevRev
  // Classic price / volume / mix bridge
  const price = (aov.value - prevAov.value) * orders.value
  const volume = (orders.value - prevOrders.value) * prevAov.value
  const mix = total - price - volume
  return { total, price, volume, mix }
})

const discountCur = computed(() => sum(inRange.value, (t) => t.discount ?? t.discount_amount ?? 0))
const discountPrev = computed(() => sum(inPrevRange.value, (t) => t.discount ?? t.discount_amount ?? 0))
const hasDiscountData = computed(() => discountCur.value > 0 || discountPrev.value > 0)
const grossCur = computed(() => sum(inRange.value, (t) => t.subtotal ?? t.total ?? t.total_amount ?? 0))
const avgDiscountRate = computed(() => (grossCur.value ? (discountCur.value / grossCur.value) * 100 : 0))

const discountEffect = computed(() => -(discountCur.value - discountPrev.value))

// Stockout opportunity cost
const stockoutRows = computed(() =>
  lowStock.value
    .map((s) => {
      const onHand = num(s.total_quantity ?? s.quantity)
      const reorder = num(s.reorder_level) || 10
      const gap = Math.max(0, reorder - onHand)
      const lost = gap * num(s.selling_price || s.cost_price)
      return { name: s.medication_name || s.name, onHand, reorder, lost }
    })
    .filter((r) => r.lost > 0)
    .sort((a, b) => b.lost - a.lost)
)
const lostRevenue = computed(() => sum(stockoutRows.value, (r) => r.lost))
const outOfStockCount = computed(() => stockoutRows.value.filter((r) => r.onHand <= 0).length)
const stockoutEffect = computed(() => -lostRevenue.value)

const netChange = computed(() => revenue.value - prevRevenue.value)

const effects = computed(() => {
  const base = netChange.value || 1
  const row = (label, value, icon, color, hint) => ({
    label,
    value,
    icon,
    color,
    pct: round((value / Math.abs(base)) * 100, 1),
    hint
  })
  return [
    row('Price effect', decomp.value.price, 'mdi-currency-usd', 'teal', 'Change from average selling price'),
    row('Volume effect', decomp.value.volume, 'mdi-cube-outline', 'indigo', 'Change from transaction count'),
    row('Mix effect', decomp.value.mix, 'mdi-shuffle-variant', 'cyan', 'Product / category mix shift'),
    row('Discount effect', discountEffect.value, 'mdi-sale-outline', 'pink', hasDiscountData.value ? 'Discount granted vs prior period' : 'No discount data'),
    row('Stockout effect', stockoutEffect.value, 'mdi-package-variant-remove', 'orange', 'Opportunity cost of unavailable stock')
  ]
})

const bridgeChart = computed(() => ({
  labels: ['Previous', 'Price', 'Volume', 'Mix', 'Discount', 'Stockout', 'Current'],
  values: [Math.round(prevRevenue.value), Math.round(decomp.value.price), Math.round(decomp.value.volume), Math.round(decomp.value.mix), Math.round(discountEffect.value), Math.round(stockoutEffect.value), Math.round(revenue.value)],
  colors: ['#94a3b8', '#0d9488', '#6366f1', '#06b6d4', '#ec4899', '#f59e0b', '#0d9488']
}))

const bridgeRows = computed(() => {
  let running = prevRevenue.value
  const rows = [{ label: 'Opening revenue', impact: 0, emphasis: true, running, tone: '' }]
  const steps = [
    { label: 'Price effect', value: decomp.value.price },
    { label: 'Volume effect', value: decomp.value.volume },
    { label: 'Mix effect', value: decomp.value.mix },
    { label: 'Discount effect', value: discountEffect.value },
    { label: 'Stockout effect', value: stockoutEffect.value }
  ]
  for (const s of steps) {
    running += s.value
    rows.push({ label: s.label, impact: s.value, running, tone: s.value >= 0 ? 'text-success' : 'text-error' })
  }
  rows.push({ label: 'Closing revenue', impact: netChange.value, emphasis: true, running: revenue.value, tone: netChange.value >= 0 ? 'text-success' : 'text-error' })
  return rows.map((r) => ({
    ...r,
    impactText: r.impact === 0 ? '—' : `${r.impact >= 0 ? '+' : ''}${formatMoney(r.impact)}`,
    runningText: formatMoney(r.running)
  }))
})

// ── verdict / narrative ─────────────────────────────────────────────────
const lastMonth = computed(() => historyMonthly.value[historyMonthly.value.length - 1] || { label: 'This month', value: 0 })
const effectiveTarget = computed(() => {
  if (monthlyTarget.value) return monthlyTarget.value
  const last3 = historyValues.value.slice(-3)
  return Math.round((last3.length ? sum(last3) / last3.length : 0) * 1.08)
})
const targetGapPct = computed(() => pctChange(lastMonth.value.value, effectiveTarget.value))

const verdict = computed(() => {
  const gap = targetGapPct.value
  const driving = []
  if (discountCur.value > 0) driving.push('discounting')
  if (stockoutRows.value.length) driving.push('stockouts')
  if (!driving.length) driving.push('volume and mix shifts')
  const reasonText = driving.length > 1
    ? `${driving.slice(0, -1).join(', ')} and ${driving[driving.length - 1]}`
    : driving[0]

  if (gap != null && gap < 0) {
    return {
      color: 'error',
      tone: 'negative',
      icon: 'mdi-trending-down',
      headline: `${lastMonth.value.label} sales are ${Math.abs(gap).toFixed(1)}% below the target of ${formatMoney(effectiveTarget.value)}`,
      detail: `${reasonText.charAt(0).toUpperCase()}${reasonText.slice(1)} explain the decline. Forecast the next quarter and review the recommended pricing actions.`,
      chip: `${formatMoney(lastMonth.value.value - effectiveTarget.value)}`
    }
  }
  if (gap != null) {
    return {
      color: 'success',
      tone: 'positive',
      icon: 'mdi-trending-up',
      headline: `${lastMonth.value.label} sales are ${gap.toFixed(1)}% above target`,
      detail: 'Momentum is ahead of plan — protect margin and keep fast movers in stock.',
      chip: `+${formatMoney(lastMonth.value.value - effectiveTarget.value)}`
    }
  }
  return {
    color: 'info',
    tone: 'neutral',
    icon: 'mdi-information',
    headline: 'Not enough history to establish a variance',
    detail: 'Keep capturing sales data to unlock target variance and attribution.',
    chip: '—'
  }
})

const topDriver = computed(() => drivers.value[0])

const narrativeHeadline = computed(() => {
  const d = netChange.value
  if (!prevRevenue.value) return 'No comparable prior period — attribution is unavailable.'
  return `Revenue ${d >= 0 ? 'grew' : 'fell'} <b>${Math.abs(pctChange(revenue.value, prevRevenue.value)).toFixed(1)}%</b> (${d >= 0 ? '+' : ''}${formatMoney(d)}) versus the previous ${rangeDays.value} days.`
})

const narrativePoints = computed(() => {
  const pts = []
  const p = decomp.value
  if (Math.abs(p.price) > 0) pts.push(`${p.price >= 0 ? '+ ' : '- '}Price movement contributed <b>${formatMoney(Math.abs(p.price))}</b>.`)
  if (Math.abs(p.volume) > 0) pts.push(`${p.volume >= 0 ? '+ ' : '- '}Transaction volume contributed <b>${formatMoney(Math.abs(p.volume))}</b>.`)
  if (Math.abs(p.mix) > 0) pts.push(`${p.mix >= 0 ? '+ ' : '- '}Category mix contributed <b>${formatMoney(Math.abs(p.mix))}</b>.`)
  if (discountEffect.value) pts.push(`- Discounting consumed <b>${formatMoney(Math.abs(discountEffect.value))}</b> versus the prior period.`)
  if (lostRevenue.value) pts.push(`- Stockouts removed an estimated <b>${formatMoney(lostRevenue.value)}</b> of sellable revenue.`)
  if (topDriver.value) pts.push(`! The largest single category movement was <b>${topDriver.value.label}</b> (${formatMoney(topDriver.value.impact)}).`)
  return pts.slice(0, 6)
})

// ── pareto ──────────────────────────────────────────────────────────────
const lossPareto = computed(() => {
  const losses = drivers.value.filter((d) => d.impact < 0).sort((a, b) => a.impact - b.impact)
  const totalLoss = sum(losses, (d) => Math.abs(d.impact)) || 1
  let cum = 0
  return losses.map((d) => {
    cum += Math.abs(d.impact)
    return { label: d.label, impact: d.impact, cumPct: (cum / totalLoss) * 100 }
  })
})

// ── ASP series ──────────────────────────────────────────────────────────
const aspSeries = computed(() => {
  const labels = []
  const values = []
  for (const b of historyMonthly.value) {
    labels.push(b.label)
    values.push(b.qty ? b.value / b.qty : 0)
  }
  return { labels, values }
})

const momValues = computed(() => historyMonthly.value.map((b, i, arr) => (i === 0 ? 0 : num(b.value) - num(arr[i - 1].value))))

// ── drill-down ──────────────────────────────────────────────────────────
function rollup(tx) {
  const map = new Map()
  for (const t of tx) {
    for (const it of t.items || []) {
      const name = String(it.product_name || it.name || it.medication_name || 'Item').trim()
      const q = num(it.quantity || 1)
      const rev = num(it.total ?? it.subtotal ?? num(it.unit_price) * q)
      const row = map.get(name) || { name, revenue: 0, qty: 0, category: it.category_name || it.category || 'Other', series: new Array(12).fill(0) }
      row.revenue += rev
      row.qty += q
      map.set(name, row)
    }
  }
  return map
}

const drillRows = computed(() => {
  const cur = rollup(inRange.value)
  const prev = rollup(inPrevRange.value)
  const names = new Set([...cur.keys(), ...prev.keys()])
  const totalAbs = sum([...names].map((n) => Math.abs((cur.get(n)?.revenue || 0) - (prev.get(n)?.revenue || 0)))) || 1
  let rows = [...names].map((n) => {
    const c = cur.get(n)
    const p = prev.get(n)
    const current = c?.revenue || 0
    const previous = p?.revenue || 0
    const variance = current - previous
    return {
      name: n,
      category: c?.category || p?.category || 'Other',
      current,
      previous,
      variance,
      varPct: pctChange(current, previous),
      weight: (Math.abs(variance) / totalAbs) * 100,
      series: c?.series || p?.series || new Array(12).fill(0)
    }
  })
  const { rows: abcRows } = abcClass(rows, { valueKey: 'current' })
  rows = xyzClass(abcRows, { seriesKey: 'series' })
  rows.sort((a, b) => Math.abs(b.variance) - Math.abs(a.variance))
  if (search.value) {
    const q = search.value.toLowerCase()
    rows = rows.filter((r) => r.name.toLowerCase().includes(q) || r.category.toLowerCase().includes(q))
  }
  return rows.slice(0, 40)
})

function abcColor(k) {
  return k === 'A' ? 'success' : k === 'B' ? 'warning' : 'grey'
}
function xyzColor(k) {
  return k === 'X' ? 'success' : k === 'Y' ? 'warning' : k === 'Z' ? 'error' : 'grey'
}

// ── 5 whys ──────────────────────────────────────────────────────────────
const fiveWhys = computed(() => {
  const p = decomp.value
  const top = topDriver.value
  const chain = []
  chain.push({
    tag: 'Symptom',
    color: 'error',
    question: 'Why did revenue move away from plan?',
    answer: `Revenue changed by ${formatMoney(netChange.value)} (${pctChange(revenue.value, prevRevenue.value) == null ? '—' : `${(pctChange(revenue.value, prevRevenue.value)).toFixed(1)}%`}) versus the comparable period.`
  })
  chain.push({
    tag: 'Driver',
    color: 'deep-purple',
    question: top ? `Why did "${top.label}" move?` : 'Which category moved?',
    answer: top ? `It contributed ${formatMoney(top.impact)} — ${top.weight.toFixed(0)}% of the total movement.` : 'No single category dominated the movement.'
  })
  chain.push({
    tag: 'Mechanism',
    color: 'orange',
    question: 'Why is that category under pressure?',
    answer: lostRevenue.value
      ? `Availability constraints removed an estimated ${formatMoney(lostRevenue.value)} of sellable revenue across ${stockoutRows.value.length} items.`
      : 'No availability constraint was detected — the pressure is commercial rather than operational.'
  })
  chain.push({
    tag: 'Behaviour',
    color: 'pink',
    question: 'Why are customers substituting or deferring?',
    answer: discountCur.value > 0
      ? `Discount depth averaged ${avgDiscountRate.value.toFixed(2)}%, indicating price-led demand — margin is funding the volume.`
      : 'Customers respond to assortment and availability rather than price in this period.'
  })
  chain.push({
    tag: 'Root cause',
    color: 'teal',
    question: 'What must change at the root?',
    answer: `${stockoutRows.value.length ? 'Fix replenishment of the flagged items. ' : ''}${discountCur.value > 0 ? 'Re-set discount guardrails to protect margin. ' : ''}Review assortment and pricing on the top-contributing category, then re-forecast next quarter.`
  })
  return chain
})

// ── exports ─────────────────────────────────────────────────────────────
function exportBridge() {
  downloadCsv(`revenue-bridge-${new Date().toISOString().slice(0, 10)}`, ['label', 'impactText', 'runningText'], bridgeRows.value)
}
function exportDrill() {
  downloadCsv(
    `root-cause-drilldown-${new Date().toISOString().slice(0, 10)}`,
    ['name', 'category', 'abc', 'xyz', 'current', 'previous', 'variance', 'varPct', 'weight'],
    drillRows.value
  )
}
</script>
