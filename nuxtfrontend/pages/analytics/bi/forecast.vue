<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Forecasts and Trends"
      subtitle="Predictive analytics — trend, seasonality, scenarios and confidence"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-chart-timeline-variant-shimmer"
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
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportForecast">Export</v-btn>
        <v-btn variant="tonal" color="deep-purple" rounded="lg" class="text-none" prepend-icon="mdi-robot"
               :to="`${biBase}/models`">Models</v-btn>
      </template>
    </BiToolbar>

    <!-- Accuracy header -->
    <v-row dense>
      <v-col v-for="m in accuracyTiles" :key="m.title" cols="6" md="3" xl="2">
        <KpiTile v-bind="m" flat />
      </v-col>
    </v-row>

    <!-- Forecast workspace -->
    <v-row class="mt-1">
      <v-col cols="12" lg="9">
        <BiPanel
          title="Projection"
          :subtitle="`${horizonLabel} ahead · ${methodLabel} model · fitted on ${historyLabels.length} periods`"
          icon="mdi-crystal-ball"
          color="indigo"
        >
          <template #actions>
            <v-switch v-model="showBand" label="Band" color="indigo" density="compact" hide-details class="mr-2" />
            <v-btn-toggle v-model="measure" density="compact" variant="outlined" color="indigo" rounded="lg" mandatory>
              <v-btn value="revenue" size="small" class="text-none">Revenue</v-btn>
              <v-btn value="orders" size="small" class="text-none">Orders</v-btn>
              <v-btn value="units" size="small" class="text-none">Units</v-btn>
            </v-btn-toggle>
          </template>

          <LineChart :series="chartSeries" :labels="chartLabels" :height="320" :y-formatter="chartFormatter" />

          <div class="d-flex flex-wrap ga-4 mt-3">
            <div v-for="s in chartSeries" :key="s.label" class="d-flex align-center">
              <span class="legend-dot" :style="{ background: s.color }" />
              <span class="text-caption ml-2">{{ s.label }}</span>
            </div>
          </div>

          <v-divider class="my-4" />
          <v-row dense>
            <v-col cols="12" md="4">
              <div class="text-caption text-medium-emphasis mb-1">Model</div>
              <v-select v-model="method" :items="methodOptions" item-title="label" item-value="value"
                        density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="4">
              <div class="text-caption text-medium-emphasis mb-1">Horizon</div>
              <v-select v-model="horizon" :items="horizonOptions" item-title="label" item-value="value"
                        density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="4">
              <div class="text-caption text-medium-emphasis mb-1">Confidence level</div>
              <v-select v-model="confidence" :items="confidenceOptions" density="compact" variant="outlined" hide-details />
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="3">
        <BiPanel title="Forecast summary" subtitle="Next periods at a glance" icon="mdi-sigma" color="teal">
          <div v-for="f in forecastTable.slice(0, 6)" :key="f.label" class="mb-3">
            <div class="d-flex justify-space-between align-center">
              <span class="text-body-2 font-weight-medium">{{ f.label }}</span>
              <span class="text-body-2 font-weight-bold">{{ f.value }}</span>
            </div>
            <v-progress-linear :model-value="f.pct" color="indigo" height="5" rounded class="mt-1" />
            <div class="text-caption text-medium-emphasis">{{ f.range }}</div>
          </div>
          <v-alert v-if="!forecastTable.length" type="info" variant="tonal" density="compact" class="text-caption">
            Not enough history to project a forecast yet.
          </v-alert>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Scenarios + seasonality -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel title="What-if scenarios" subtitle="Adjust assumptions and re-project" icon="mdi-tune-variant" color="deep-purple">
          <v-row dense>
            <v-col cols="12" md="6">
              <div class="text-body-2 mb-1">Growth adjustment <b>{{ growth > 0 ? '+' : '' }}{{ growth }}%</b></div>
              <v-slider v-model="growth" :min="-30" :max="30" :step="1" color="deep-purple" hide-details thumb-label />
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-body-2 mb-1">Price change <b>{{ priceChange > 0 ? '+' : '' }}{{ priceChange }}%</b></div>
              <v-slider v-model="priceChange" :min="-20" :max="20" :step="1" color="teal" hide-details thumb-label />
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-body-2 mb-1">Promotion uplift <b>{{ promoUplift > 0 ? '+' : '' }}{{ promoUplift }}%</b></div>
              <v-slider v-model="promoUplift" :min="0" :max="40" :step="1" color="amber" hide-details thumb-label />
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-body-2 mb-1">Assumed elasticity <b>{{ elasticity.toFixed(2) }}</b></div>
              <v-slider v-model="elasticity" :min="-2.5" :max="-0.2" :step="0.05" color="pink" hide-details thumb-label />
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <v-row dense>
            <v-col v-for="s in scenarioCards" :key="s.label" cols="12" md="4">
              <v-card rounded="lg" class="pa-3 h-100" variant="tonal" :color="s.color">
                <div class="text-caption font-weight-medium">{{ s.label }}</div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(s.value) }}</div>
                <div class="text-caption">{{ s.delta }}</div>
              </v-card>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <BiPanel title="Seasonality profile" subtitle="Calendar-month index versus the annual mean" icon="mdi-calendar-month-outline" color="cyan">
          <BarChart
            :values="seasonalIndex.map((v) => Math.round((v - 1) * 1000) / 10)"
            :labels="monthLabels"
            :colors="seasonalIndex.map((v) => (v >= 1 ? '#22c55e' : '#f59e0b'))"
            :height="240"
            :y-formatter="(v) => `${num(v).toFixed(0)}%`"
          />
          <div class="text-caption text-medium-emphasis mt-2">
            Values above zero indicate months that historically trade above the annual average.
          </div>
          <v-divider class="my-3" />
          <div class="d-flex flex-wrap ga-2">
            <v-chip v-for="p in peakMonths" :key="p.label" size="small" color="success" variant="tonal" prepend-icon="mdi-trending-up">
              {{ p.label }} · {{ p.text }}
            </v-chip>
            <v-chip v-for="p in troughMonths" :key="p.label" size="small" color="warning" variant="tonal" prepend-icon="mdi-trending-down">
              {{ p.label }} · {{ p.text }}
            </v-chip>
          </div>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Method comparison + forecast table -->
    <v-row class="mt-1">
      <v-col cols="12" lg="5">
        <BiPanel title="Model benchmark" subtitle="Back-tested accuracy across candidate models" icon="mdi-chart-bell-curve" color="purple">
          <v-table density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Model</th><th class="text-right">MAE</th><th class="text-right">MAPE</th>
                <th class="text-right">RMSE</th><th class="text-right">R²</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in benchmark" :key="r.key" :class="r.key === method ? 'bg-primary-lighten-5' : ''">
                <td class="font-weight-medium">
                  {{ r.label }}
                  <v-chip v-if="r.best" size="x-small" color="success" variant="tonal" class="ml-1">Best</v-chip>
                </td>
                <td class="text-right">{{ compactNumber(r.mae) }}</td>
                <td class="text-right">{{ r.mape.toFixed(1) }}%</td>
                <td class="text-right">{{ compactNumber(r.rmse) }}</td>
                <td class="text-right">{{ r.r2.toFixed(3) }}</td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="7">
        <BiPanel title="Projection detail" subtitle="Point forecast with the confidence interval" icon="mdi-table-clock" color="indigo">
          <v-table density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Period</th><th class="text-right">Forecast</th>
                <th class="text-right">Lower</th><th class="text-right">Upper</th>
                <th class="text-right">Cumulative</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="f in forecastTable" :key="f.key">
                <td class="font-weight-medium">{{ f.key }}</td>
                <td class="text-right font-weight-medium">{{ f.value }}</td>
                <td class="text-right text-medium-emphasis">{{ f.lower }}</td>
                <td class="text-right text-medium-emphasis">{{ f.upper }}</td>
                <td class="text-right">{{ f.cumulative }}</td>
              </tr>
            </tbody>
          </v-table>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            Intervals widen with horizon according to residual volatility
            (σ = {{ formatMoney(activeForecast.residualStd) }}) scaled by √step and a
            {{ confidence }}% confidence multiplier. Bias {{ formatMoney(activeForecast.accuracy.bias) }}.
          </div>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import { BI_MONTHS, num, sum, trendForecast, zFor, compactNumber, downloadCsv } from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  historyMonthly, historyValues, historyLabels, seasonal, biBase
} = useBiData({ defaultRange: '12m' })

const method = ref('holt')
const horizon = ref(3)
const confidence = ref(95)
const showBand = ref(true)
const measure = ref('revenue')

const growth = ref(0)
const priceChange = ref(0)
const promoUplift = ref(0)
const elasticity = ref(-1.2)

const methodOptions = [
  { label: "Holt's linear trend", value: 'holt' },
  { label: 'Linear regression', value: 'linear' },
  { label: 'Moving average', value: 'ma' },
  { label: 'Seasonal naive', value: 'seasonal' }
]
const horizonOptions = [
  { label: 'Next 3 periods', value: 3 },
  { label: 'Next 6 periods', value: 6 },
  { label: 'Next 12 periods', value: 12 }
]
const confidenceOptions = [80, 90, 95, 99]
const monthLabels = BI_MONTHS

const methodLabel = computed(() => (methodOptions.find((m) => m.value === method.value) || {}).label || method.value)
const horizonLabel = computed(() => (horizonOptions.find((h) => h.value === horizon.value) || {}).label || `Next ${horizon.value}`)

// ── series selection ────────────────────────────────────────────────────
const ordersSeries = computed(() => historyMonthly.value.map((b) => num(b.orders)))
const unitsSeries = computed(() => historyMonthly.value.map((b) => num(b.qty)))
const activeSeries = computed(() => {
  if (measure.value === 'orders') return ordersSeries.value
  if (measure.value === 'units') return unitsSeries.value
  return historyValues.value
})

const activeForecast = computed(() => trendForecast(activeSeries.value, { horizon: horizon.value, method: method.value }))

// Apply the what-if assumptions on top of the statistical forecast.
const adjustedForecast = computed(() => {
  const raw = activeForecast.value.forecast
  // Price change alters unit demand through elasticity; promos lift volume.
  const priceVolumeFactor = 1 + elasticity.value * (priceChange.value / 100)
  const factor = (1 + growth.value / 100) * Math.max(0, priceVolumeFactor) * (1 + promoUplift.value / 100)
  return raw.map((v) => Math.max(0, num(v) * factor))
})

const chartLabels = computed(() => {
  const future = Array.from({ length: horizon.value }, (_, i) => `P+${i + 1}`)
  return [...historyLabels.value, ...future]
})

const chartSeries = computed(() => {
  const actual = activeSeries.value
  const f = activeForecast.value
  const fitted = f.fitted.map((v, i) => (i === 0 ? num(actual[0]) : num(v)))
  const projection = [...actual, ...adjustedForecast.value]
  const series = [
    { label: 'Actual', color: '#0d9488', values: actual },
    { label: 'Model fit', color: '#cbd5e1', values: fitted },
    { label: 'Forecast', color: '#6366f1', values: projection }
  ]
  if (showBand.value) {
    const z = zFor(confidence.value)
    const sd = f.residualStd
    const upper = [...actual, ...adjustedForecast.value.map((v, i) => v + z * sd * Math.sqrt(i + 1))]
    const lower = [...actual, ...adjustedForecast.value.map((v, i) => Math.max(0, v - z * sd * Math.sqrt(i + 1)))]
    series.push({ label: `${confidence.value}% upper`, color: '#c7d2fe', values: upper })
    series.push({ label: `${confidence.value}% lower`, color: '#c7d2fe', values: lower })
  }
  return series
})

const chartFormatter = computed(() => (measure.value === 'revenue' ? compactNumber : (v) => String(Math.round(num(v)))))

// ── accuracy tiles ──────────────────────────────────────────────────────
const accuracyTiles = computed(() => {
  const a = activeForecast.value.accuracy
  return [
    { title: 'MAPE', value: `${a.mape.toFixed(1)}%`, icon: 'mdi-percent-outline', color: 'indigo', hint: 'Mean absolute percentage error' },
    { title: 'MAE', value: compactNumber(a.mae), icon: 'mdi-approximately-equal', color: 'teal', hint: 'Mean absolute error' },
    { title: 'RMSE', value: compactNumber(a.rmse), icon: 'mdi-square-root', color: 'purple', hint: 'Root mean squared error' },
    { title: 'Forecast bias', value: compactNumber(a.bias), icon: 'mdi-scale-balance', color: num(a.bias) >= 0 ? 'green' : 'orange', hint: 'Positive = under-forecast' },
    { title: 'Fit R²', value: a.r2.toFixed(3), icon: 'mdi-chart-bell-curve', color: 'cyan', hint: 'Explained variance' },
    { title: 'Next period', value: formatMoney(adjustedForecast.value[0] || 0), valueNum: adjustedForecast.value[0] || 0, icon: 'mdi-calendar-arrow-right', color: 'pink', hint: `${methodLabel.value}` }
  ]
})

// ── benchmark ───────────────────────────────────────────────────────────
const benchmark = computed(() => {
  const rows = methodOptions.map((m) => {
    const f = trendForecast(activeSeries.value, { horizon: horizon.value, method: m.value })
    return { key: m.value, label: m.label, mae: f.accuracy.mae, mape: f.accuracy.mape, rmse: f.accuracy.rmse, r2: f.accuracy.r2 }
  })
  const best = rows.reduce((a, b) => (num(b.mape) < num(a.mape) ? b : a), rows[0] || null)
  return rows.map((r) => ({ ...r, best: best && r.key === best.key }))
})

// ── forecast table ──────────────────────────────────────────────────────
const forecastTable = computed(() => {
  const f = activeForecast.value
  const z = zFor(confidence.value)
  const sd = f.residualStd
  let cum = 0
  const max = Math.max(...adjustedForecast.value, 1)
  const lastLabel = historyLabels.value[historyLabels.value.length - 1] || ''
  return adjustedForecast.value.map((v, i) => {
    cum += v
    const half = z * sd * Math.sqrt(i + 1)
    const isMoney = measure.value === 'revenue'
    const fmt = (x) => (isMoney ? formatMoney(x) : compactNumber(x))
    return {
      key: `${lastLabel} +${i + 1}`,
      label: `P+${i + 1}`,
      value: fmt(v),
      lower: fmt(Math.max(0, v - half)),
      upper: fmt(v + half),
      cumulative: fmt(cum),
      range: `${fmt(Math.max(0, v - half))} – ${fmt(v + half)}`,
      pct: Math.round((v / max) * 100)
    }
  })
})

// ── scenarios ───────────────────────────────────────────────────────────
const scenarioCards = computed(() => {
  const base = sum(activeForecast.value.forecast)
  const business = sum(adjustedForecast.value)
  const pessimistic = business * 0.92
  const optimistic = business * 1.08
  return [
    { label: 'Pessimistic (-8%)', value: pessimistic, color: 'error', delta: `vs plan ${pctText(pessimistic - base)}` },
    { label: 'Most likely (plan)', value: business, color: 'primary', delta: `statistical base ${pctText(business - base)}` },
    { label: 'Optimistic (+8%)', value: optimistic, color: 'success', delta: `vs plan ${pctText(optimistic - base)}` }
  ]
})

function pctText(delta) {
  const base = sum(activeForecast.value.forecast) || 1
  return `${delta >= 0 ? '+' : ''}${((delta / base) * 100).toFixed(1)}%`
}

// ── seasonality ─────────────────────────────────────────────────────────
const seasonalIndex = computed(() => seasonal.value.index)
const peakMonths = computed(() =>
  seasonalIndex.value
    .map((v, i) => ({ label: BI_MONTHS[i], v }))
    .filter((m) => m.v >= 1.05)
    .sort((a, b) => b.v - a.v)
    .slice(0, 3)
    .map((m) => ({ label: m.label, text: `+${((m.v - 1) * 100).toFixed(1)}%` }))
)
const troughMonths = computed(() =>
  seasonalIndex.value
    .map((v, i) => ({ label: BI_MONTHS[i], v }))
    .filter((m) => m.v <= 0.95)
    .sort((a, b) => a.v - b.v)
    .slice(0, 3)
    .map((m) => ({ label: m.label, text: `${((m.v - 1) * 100).toFixed(1)}%` }))
)

// ── export ──────────────────────────────────────────────────────────────
function exportForecast() {
  const f = activeForecast.value
  const rows = [
    ...historyLabels.value.map((l, i) => ({ period: l, type: 'Actual', value: f.actual[i], lower: '', upper: '' })),
    ...forecastTable.value.map((r, i) => ({ period: r.key, type: 'Forecast', value: adjustedForecast.value[i], lower: r.lower, upper: r.upper }))
  ]
  downloadCsv(`forecast-${measure.value}-${new Date().toISOString().slice(0, 10)}`, ['period', 'type', 'value', 'lower', 'upper'], rows)
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
