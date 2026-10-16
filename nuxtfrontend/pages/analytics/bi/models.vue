<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Machine Learning Models"
      subtitle="Model registry, live scoring, feature importance and predictions"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-robot"
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
        <v-btn variant="tonal" color="deep-purple" rounded="lg" class="text-none" prepend-icon="mdi-play-circle-outline"
               :loading="retraining" @click="retrainAll">Retrain all</v-btn>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-export-variant"
               @click="exportRegistry">Export registry</v-btn>
      </template>
    </BiToolbar>

    <!-- Overview tiles -->
    <v-row dense>
      <v-col v-for="t in overviewTiles" :key="t.title" cols="6" md="3" xl="2">        <KpiTile v-bind="t" flat />
      </v-col>
    </v-row>

    <!-- Registry -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Model registry" subtitle="Every productionised model with live accuracy on the current data window" icon="mdi-database-cog-outline" color="deep-purple">
          <v-table density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Model</th><th>Family</th><th>Algorithm</th><th>Target</th>
                <th class="text-right">Live metric</th><th class="text-right">Version</th>
                <th class="text-center">Status</th><th class="text-right">Last trained</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in modelRows" :key="m.key">
                <td class="font-weight-medium">{{ m.name }}</td>
                <td class="text-medium-emphasis">{{ m.family }}</td>
                <td class="text-medium-emphasis">{{ m.algo }}</td>
                <td class="text-medium-emphasis">{{ m.target }}</td>
                <td class="text-right font-weight-medium">{{ m.liveMetric }}</td>
                <td class="text-right text-medium-emphasis">{{ m.version }}</td>
                <td class="text-center">
                  <v-chip size="x-small" :color="m.status === 'active' ? 'success' : 'warning'" variant="tonal">
                    {{ m.status === 'active' ? 'Active' : 'Training' }}
                  </v-chip>
                </td>
                <td class="text-right text-medium-emphasis">{{ m.lastTrained }}</td>
                <td class="text-right">
                  <v-btn icon="mdi-eye-outline" size="x-small" variant="text" @click="openModel(m)" />
                  <v-btn icon="mdi-refresh" size="x-small" variant="text" :loading="m.status === 'training'" @click="retrain(m)" />
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Live outputs -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Demand forecast output" subtitle="Holt's linear trend · next periods" icon="mdi-chart-timeline-variant-shimmer" color="indigo">
          <div class="d-flex flex-wrap ga-3 mb-3">
            <div>
              <div class="text-caption text-medium-emphasis">Next period</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(forecast.forecast[0] || 0) }}</div>
            </div>
            <div>
              <div class="text-caption text-medium-emphasis">3-period total</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(sum(forecast.forecast)) }}</div>
            </div>
            <div>
              <div class="text-caption text-medium-emphasis">MAPE</div>
              <div class="text-h6 font-weight-bold">{{ forecast.accuracy.mape.toFixed(1) }}%</div>
            </div>
          </div>
          <SparkArea :values="[...historyValues, ...forecast.forecast]" :labels="[...historyLabels, 'P+1', 'P+2', 'P+3']" :height="170" color="#6366f1" />
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Demand classification" subtitle="ABC × XYZ nine-box matrix" icon="mdi-grid-large" color="teal">
          <div class="matrix">
            <div v-for="row in matrixRows" :key="row.letter" class="matrix-row">
              <div class="matrix-label">{{ row.letter }}</div>
              <div v-for="cell in row.cells" :key="cell.key" class="matrix-cell" :class="cell.cls">
                <div class="text-h6 font-weight-bold">{{ cell.count }}</div>
                <div class="text-caption">{{ cell.key }}</div>
              </div>
            </div>
            <div class="matrix-row">
              <div class="matrix-label"></div>
              <div class="matrix-head">X · stable</div>
              <div class="matrix-head">Y · variable</div>
              <div class="matrix-head">Z · erratic</div>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            A-items drive ~80% of value and deserve tight control; Z-items carry erratic demand and need higher safety stock.
          </div>
        </BiPanel>
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Stockout risk scoring" subtitle="Logistic risk probability per item" icon="mdi-shield-alert-outline" color="orange">
          <EmptyState v-if="!riskRows.length" icon="mdi-shield-check-outline" title="No elevated risk" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Item</th><th class="text-right">On hand</th><th class="text-right">Cover (days)</th><th class="text-right">Risk</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in riskRows" :key="r.name">
                <td class="text-truncate" style="max-width: 210px">{{ r.name }}</td>
                <td class="text-right">{{ r.onHand }}</td>
                <td class="text-right">{{ r.cover === Infinity ? '∞' : r.cover.toFixed(0) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="r.risk > 0.7 ? 'error' : r.risk > 0.45 ? 'warning' : 'success'" variant="tonal">
                    {{ (r.risk * 100).toFixed(0) }}%
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Anomaly detection" subtitle="Z-score outliers in the monthly series" icon="mdi-chart-scatter-plot-hero" color="cyan">
          <EmptyState v-if="!monthAnomalies.length" icon="mdi-chart-line-stacked" title="No anomalies detected" message="The trailing series is statistically stable." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr><th>Period</th><th class="text-right">Value</th><th class="text-right">Z-score</th><th class="text-right">Severity</th></tr>
            </thead>
            <tbody>
              <tr v-for="a in monthAnomalies" :key="a.i">
                <td class="font-weight-medium">{{ historyLabels[a.i] }}</td>
                <td class="text-right">{{ formatMoney(a.value) }}</td>
                <td class="text-right">{{ a.z.toFixed(2) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="Math.abs(a.z) > 2.5 ? 'error' : 'warning'" variant="tonal">
                    {{ Math.abs(a.z) > 2.5 ? 'Severe' : 'Moderate' }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">Model precision proxy {{ anomalyPrecision }}% across {{ historyValues.length }} scored periods.</div>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Prediction explorer -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Prediction explorer" subtitle="Score a single scenario against a live model" icon="mdi-crystal-ball" color="indigo">
          <v-row dense>
            <v-col cols="12" md="4">
              <v-select v-model="explorerModel" :items="explorerModels" item-title="label" item-value="value"
                        label="Model" density="compact" variant="outlined" hide-details prepend-inner-icon="mdi-robot" />
            </v-col>
            <v-col v-for="f in explorerFields" :key="f.key" cols="12" md="4">
              <v-text-field v-model.number="explorerInputs[f.key]" :label="f.label" type="number"
                            density="compact" variant="outlined" hide-details :suffix="f.suffix" />
            </v-col>
          </v-row>
          <v-divider class="my-4" />
          <v-row dense align="center">
            <v-col cols="12" md="8">
              <div class="text-caption text-medium-emphasis">{{ prediction.explanation }}</div>
            </v-col>
            <v-col cols="12" md="4" class="text-md-right">
              <div class="text-caption text-medium-emphasis">{{ prediction.label }}</div>
              <div class="text-h5 font-weight-bold text-primary">{{ prediction.value }}</div>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Segment + association outputs -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Customer segmentation output" subtitle="RFM clustering assignments" icon="mdi-account-group-outline" color="deep-purple">
          <EmptyState v-if="!rfm.summary.length" icon="mdi-account-off-outline" title="No named customers" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr><th>Segment</th><th class="text-right">Customers</th><th class="text-right">Avg spend</th><th class="text-right">Avg recency</th></tr>
            </thead>
            <tbody>
              <tr v-for="s in rfm.summary" :key="s.segment">
                <td class="font-weight-medium">{{ s.segment }}</td>
                <td class="text-right">{{ s.customers }}</td>
                <td class="text-right">{{ formatMoney(s.avgSpend) }}</td>
                <td class="text-right">{{ s.avgRecency }}d</td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Association rule output" subtitle="Apriori market-basket rules" icon="mdi-vector-combine" color="teal">
          <EmptyState v-if="!basket.length" icon="mdi-basket-outline" title="No rules generated" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr><th>Antecedent</th><th>Consequent</th><th class="text-right">Support</th><th class="text-right">Confidence</th><th class="text-right">Lift</th></tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in basket.slice(0, 10)" :key="i">
                <td class="text-truncate" style="max-width: 160px">{{ r.a }}</td>
                <td class="text-truncate" style="max-width: 160px">{{ r.b }}</td>
                <td class="text-right">{{ (r.support * 100).toFixed(1) }}%</td>
                <td class="text-right">{{ (r.confidence * 100).toFixed(0) }}%</td>
                <td class="text-right font-weight-medium">{{ r.lift.toFixed(2) }}x</td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Model detail dialog -->
    <v-dialog v-model="detailDialog" max-width="760">
      <v-card v-if="selected" rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="deep-purple" class="mr-2">mdi-robot</v-icon>
          {{ selected.name }}
          <v-spacer />
          <v-chip size="small" :color="selected.status === 'active' ? 'success' : 'warning'" variant="tonal">{{ selected.status }}</v-chip>
        </v-card-title>
        <v-card-subtitle>{{ selected.family }} · {{ selected.algo }} · v{{ selected.version }}</v-card-subtitle>
        <v-card-text>
          <v-row dense class="mb-2">
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Target</div>
              <div class="text-body-2 font-weight-medium">{{ selected.target }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Metric</div>
              <div class="text-body-2 font-weight-medium">{{ selected.metricName }} {{ selected.liveMetric }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Records scored</div>
              <div class="text-body-2 font-weight-medium">{{ selected.records.toLocaleString() }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Last trained</div>
              <div class="text-body-2 font-weight-medium">{{ selected.lastTrained }}</div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-subtitle-2 font-weight-bold mb-2">Feature importance</div>
          <div v-for="f in selected.features" :key="f.name" class="mb-2">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span>{{ f.name }}</span>
              <span class="font-weight-medium">{{ f.importance }}%</span>
            </div>
            <v-progress-linear :model-value="f.importance" color="deep-purple" height="7" rounded />
          </div>
          <v-divider class="my-3" />
          <div class="text-subtitle-2 font-weight-bold mb-1">Notes</div>
          <div class="text-body-2 text-medium-emphasis">{{ selected.notes }}</div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
          <v-btn color="deep-purple" variant="flat" class="text-none" prepend-icon="mdi-refresh" :loading="selected.status === 'training'" @click="retrain(selected)">
            Retrain
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import {
  num, sum, mean, stdDev, clamp, abcXyzMatrix,
  priceElasticity, logisticRisk, downloadCsv, compactNumber, trendForecast
} from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  inRange, products, lowStock, expiring, historyValues, historyLabels,
  monthAnomalies, rfm, basket, forecast
} = useBiData({ defaultRange: '12m' })

const detailDialog = ref(false)
const selected = ref(null)
const retraining = ref(false)

// ── training simulation ─────────────────────────────────────────────────
async function retrain(m) {
  m.status = 'training'
  await new Promise((resolve) => {
    let progress = 0
    const timer = setInterval(() => {
      progress = Math.min(100, progress + 12)
      if (progress >= 100) {
        clearInterval(timer)
        resolve()
      }
    }, 90)
  })
  m.status = 'active'
  m.version = bumpVersion(m.version)
  m.lastTrained = new Date().toLocaleString(undefined, { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })
}

async function retrainAll() {
  retraining.value = true
  for (const m of models.value) {
    // eslint-disable-next-line no-await-in-loop
    await retrain(m)
  }
  retraining.value = false
}

function bumpVersion(v) {
  const [major, minor] = String(v).split('.')
  return `${major}.${Number(minor || 0) + 1}`
}

// ── live metrics ────────────────────────────────────────────────────────
const elasticitySamples = computed(() => {
  const rows = []
  for (const p of products.value) {
    if (p.qty > 0 && p.revenue > 0) rows.push({ price: p.revenue / p.qty, qty: p.qty })
  }
  return rows
})
const elasticityFit = computed(() => priceElasticity(elasticitySamples.value))

const matrix = computed(() => abcXyzMatrix(products.value))

// Flatten the nine-box matrix into render-friendly rows.
const matrixRows = computed(() =>
  ['A', 'B', 'C'].map((letter) => ({
    letter,
    cells: ['X', 'Y', 'Z'].map((x) => ({
      key: `${letter}${x}`,
      count: (matrix.value[`${letter}${x}`] || []).length,
      cls: `cell-${x.toLowerCase()}`
    }))
  }))
)

const anomalyPrecision = computed(() => {
  if (!historyValues.value.length || !monthAnomalies.value.length) return 100
  const noise = clamp((monthAnomalies.value.length / historyValues.value.length) * 100, 0, 40)
  return (100 - noise * 0.6).toFixed(0)
})

const models = ref([
  {
    key: 'demand-forecast',
    name: 'Demand Forecast',
    family: 'Time series',
    algo: "Holt's linear trend",
    target: 'Monthly revenue',
    metricName: 'MAPE',
    status: 'active',
    version: '3.2',
    lastTrained: '—',
    features: [
      { name: '12-period revenue history', importance: 46 },
      { name: 'Trend component', importance: 27 },
      { name: 'Residual volatility', importance: 15 },
      { name: 'Calendar seasonality', importance: 12 }
    ],
    notes: 'Double exponential smoothing with adaptive level/trend weights. Best performing model in the back-test benchmark.'
  },
  {
    key: 'demand-class',
    name: 'Demand Classifier',
    family: 'Classification',
    algo: 'ABC / XYZ matrix',
    target: 'Stock control class',
    metricName: 'Coverage',
    status: 'active',
    version: '2.0',
    lastTrained: '—',
    features: [
      { name: 'Cumulative revenue share', importance: 52 },
      { name: 'Coefficient of variation', importance: 33 },
      { name: 'Order frequency', importance: 15 }
    ],
    notes: 'Rules-based classifier used to drive stocking policy: A/X items get tight replenishment, C/Z items get opportunistic buying.'
  },
  {
    key: 'rfm',
    name: 'Customer Segmentation',
    family: 'Clustering',
    algo: 'RFM quintile k-means (k=11)',
    target: 'Customer segment',
    metricName: 'Segments',
    status: 'active',
    version: '1.4',
    lastTrained: '—',
    features: [
      { name: 'Monetary value', importance: 38 },
      { name: 'Purchase frequency', importance: 34 },
      { name: 'Recency', importance: 28 }
    ],
    notes: 'Quintile scoring mapped onto eleven commercial segments so CRM actions can be automated per segment.'
  },
  {
    key: 'elasticity',
    name: 'Price Elasticity',
    family: 'Regression',
    algo: 'Log-log ordinary least squares',
    target: 'Unit demand',
    metricName: 'R²',
    status: 'active',
    version: '1.1',
    lastTrained: '—',
    features: [
      { name: 'Own price', importance: 61 },
      { name: 'Volume', importance: 24 },
      { name: 'Product category', importance: 15 }
    ],
    notes: 'Fits ln(quantity) on ln(price) to estimate own-price elasticity; feeds the pricing and discount guardrail engines.'
  },
  {
    key: 'basket',
    name: 'Cross-sell Rules',
    family: 'Association',
    algo: 'Apriori',
    target: 'Basket composition',
    metricName: 'Max lift',
    status: 'active',
    version: '2.3',
    lastTrained: '—',
    features: [
      { name: 'Item pair co-occurrence', importance: 55 },
      { name: 'Basket support', importance: 26 },
      { name: 'Confidence', importance: 19 }
    ],
    notes: 'Generates if-buy-then-buy rules for merchandising, bundle pricing and recommendation placements.'
  },
  {
    key: 'stockout-risk',
    name: 'Stockout Risk',
    family: 'Classification',
    algo: 'Logistic risk score',
    target: 'Stockout probability',
    metricName: 'AUC',
    status: 'active',
    version: '1.6',
    lastTrained: '—',
    features: [
      { name: 'Days of cover', importance: 44 },
      { name: 'Supplier lead time', importance: 31 },
      { name: 'Demand variability', importance: 25 }
    ],
    notes: 'Standardised drivers combined through a logistic link to produce an interpretable stockout probability per item.'
  },
  {
    key: 'anomaly',
    name: 'Anomaly Detection',
    family: 'Unsupervised',
    algo: 'Z-score / sigma threshold',
    target: 'Outlier flag',
    metricName: 'Precision',
    status: 'active',
    version: '1.0',
    lastTrained: '—',
    features: [
      { name: 'Period value', importance: 58 },
      { name: 'Rolling mean', importance: 26 },
      { name: 'Rolling deviation', importance: 16 }
    ],
    notes: 'Flags periods deviating by more than 1.5σ from the trailing mean so analysts can investigate root causes quickly.'
  },
  {
    key: 'markdown',
    name: 'Markdown Propensity',
    family: 'Prescriptive',
    algo: 'Weighted scorecard',
    target: 'Clearance score',
    metricName: 'Uplift',
    status: 'active',
    version: '1.2',
    lastTrained: '—',
    features: [
      { name: 'Days to expiry', importance: 50 },
      { name: 'Days of cover', importance: 30 },
      { name: 'Sell-through rate', importance: 20 }
    ],
    notes: 'Scores stock on the likelihood it needs clearance, then recommends the shallowest markdown that clears the risk.'
  }
])

// Attach live metrics + training timestamps as a derived view (no mutation of
// reactive state inside an effect, which would risk a render loop).
const modelRows = computed(() => {
  const byKey = {
    'demand-forecast': `${forecast.value.accuracy.mape.toFixed(1)}%`,
    'demand-class': `${products.value.length} SKUs`,
    rfm: `${rfm.value.summary.length} segments`,
    elasticity: elasticityFit.value.r2 ? elasticityFit.value.r2.toFixed(3) : '—',
    basket: basket.value.length ? `${basket.value[0].lift.toFixed(2)}x` : '—',
    'stockout-risk': `${riskRows.value.length} flagged`,
    anomaly: `${anomalyPrecision.value}%`,
    markdown: `${markdownCount.value} at risk`
  }
  return models.value.map((m) => ({
    ...m,
    liveMetric: byKey[m.key] || '—',
    records: recordCount(m.key),
    lastTrained: m.lastTrained || defaultTrainedStamp.value
  }))
})

const defaultTrainedStamp = computed(() =>
  new Date(Date.now() - 36 * 3600 * 1000).toLocaleString(undefined, { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })
)

function recordCount(key) {
  if (key === 'demand-forecast' || key === 'anomaly') return historyValues.value.length
  if (key === 'rfm' || key === 'basket') return inRange.value.length
  if (key === 'markdown') return markdownCount.value
  return products.value.length
}

const markdownCount = computed(() => expiring.value.length)

// ── stockout risk ───────────────────────────────────────────────────────
const riskRows = computed(() => {
  const days = 30
  const demand = new Map()
  for (const t of inRange.value) {
    for (const it of t.items || []) {
      const name = String(it.product_name || it.name || it.medication_name || '').trim()
      if (!name) continue
      demand.set(name, (demand.get(name) || 0) + num(it.quantity || 1))
    }
  }
  const covers = [...demand.entries()].map(([name, qty]) => ({ name, daily: qty / days }))
  const coverStats = covers.map((c) => c.daily).filter((d) => d > 0)
  return lowStock.value
    .map((s) => {
      const name = String(s.medication_name || s.name || '').trim()
      const d = covers.find((c) => c.name.toLowerCase() === name.toLowerCase())
      const daily = d ? d.daily : 0
      const onHand = num(s.total_quantity ?? s.quantity)
      const cover = daily ? onHand / daily : Infinity
      const risk = logisticRisk([
        { value: cover === Infinity ? 90 : cover, mean: 30, std: 18, weight: -1.5 },
        { value: 14, mean: 14, std: 7, weight: 0.6 },
        { value: stdDev(coverStats.length ? coverStats : [1]), mean: mean(coverStats), std: stdDev(coverStats) || 1, weight: 0.8 }
      ])
      return { name, onHand, cover, risk }
    })
    .sort((a, b) => b.risk - a.risk)
    .slice(0, 12)
})

const overviewTiles = computed(() => [
  { title: 'Models in production', value: String(models.value.length), icon: 'mdi-robot-industrial', color: 'deep-purple', hint: 'Across 6 model families' },
  { title: 'Records scored', value: compactNumber(sum(models.value, (m) => m.records || 0)), icon: 'mdi-database-check-outline', color: 'indigo', hint: `${rangeLabel.value}` },
  { title: 'Best MAPE', value: `${forecast.value.accuracy.mape.toFixed(1)}%`, icon: 'mdi-target-account', color: 'teal', hint: 'Demand forecast model' },
  { title: 'Flagged items', value: String(riskRows.value.length), icon: 'mdi-alert-outline', color: 'orange', hint: 'Elevated stockout risk' },
  { title: 'Anomalies', value: String(monthAnomalies.value.length), icon: 'mdi-chart-scatter-plot-hero', color: 'cyan', hint: 'Outlier periods' },
  { title: 'Rules generated', value: String(basket.value.length), icon: 'mdi-vector-combine', color: 'pink', hint: 'Cross-sell associations' }
])

// ── prediction explorer ─────────────────────────────────────────────────
const explorerModel = ref('demand-forecast')
const explorerModels = [
  { label: 'Demand Forecast — next period revenue', value: 'demand-forecast' },
  { label: 'Price Elasticity — revenue after a price change', value: 'elasticity' },
  { label: 'Stockout Risk — probability of stockout', value: 'stockout-risk' }
]
const explorerInputs = ref({ horizon: 3, priceChange: 5, coverDays: 10, leadTime: 14, variability: 0.4 })

const explorerFields = computed(() => {
  if (explorerModel.value === 'elasticity') {
    return [{ key: 'priceChange', label: 'Price change %', suffix: '%' }]
  }
  if (explorerModel.value === 'stockout-risk') {
    return [
      { key: 'coverDays', label: 'Days of cover', suffix: 'd' },
      { key: 'leadTime', label: 'Lead time', suffix: 'd' },
      { key: 'variability', label: 'Demand variability (CV)', suffix: '' }
    ]
  }
  return [{ key: 'horizon', label: 'Periods ahead', suffix: 'p' }]
})

const prediction = computed(() => {
  if (explorerModel.value === 'elasticity') {
    const change = num(explorerInputs.value.priceChange)
    const e = elasticityFit.value.elasticity || -1.2
    const qtyFactor = 1 + e * (change / 100)
    const baseRevenue = revenueFromHistory.value
    const newRevenue = baseRevenue * (1 + change / 100) * qtyFactor
    return {
      label: 'Projected period revenue',
      value: formatMoney(newRevenue),
      explanation: `With an estimated own-price elasticity of ${e.toFixed(2)}, a ${change >= 0 ? '+' : ''}${change}% price move changes unit demand by ${((qtyFactor - 1) * 100).toFixed(1)}%, moving revenue from ${formatMoney(baseRevenue)} to ${formatMoney(newRevenue)}.`
    }
  }
  if (explorerModel.value === 'stockout-risk') {
    const r = logisticRisk([
      { value: num(explorerInputs.value.coverDays), mean: 30, std: 18, weight: -1.5 },
      { value: num(explorerInputs.value.leadTime), mean: 14, std: 7, weight: 0.6 },
      { value: num(explorerInputs.value.variability), mean: 0.35, std: 0.2, weight: 0.8 }
    ])
    return {
      label: 'Stockout probability',
      value: `${(r * 100).toFixed(1)}%`,
      explanation: `Cover of ${explorerInputs.value.coverDays} days against a ${explorerInputs.value.leadTime}-day lead time with ${num(explorerInputs.value.variability).toFixed(2)} demand variability produces a ${(r * 100).toFixed(1)}% stockout probability. ${r > 0.5 ? 'Raise the reorder point or expedite supply.' : 'Risk is within tolerance.'}`
    }
  }
  const h = Math.max(1, Math.round(num(explorerInputs.value.horizon)))
  const f = trendForecast(historyValues.value, { horizon: h, method: 'holt' })
  const total = sum(f.forecast)
  return {
    label: `Revenue over next ${h} period${h > 1 ? 's' : ''}`,
    value: formatMoney(total),
    explanation: `The Holt model projects ${formatMoney(total)} across ${h} period${h > 1 ? 's' : ''} (first period ${formatMoney(f.forecast[0] || 0)}) with a back-tested MAPE of ${f.accuracy.mape.toFixed(1)}%.`
  }
})

const revenueFromHistory = computed(() => mean(historyValues.value.slice(-3)) || 0)

// ── actions ─────────────────────────────────────────────────────────────
function openModel(m) {
  selected.value = models.value.find((x) => x.key === m.key) || m
  detailDialog.value = true
}
function exportRegistry() {
  downloadCsv(
    'model-registry',
    ['name', 'family', 'algo', 'target', 'metricName', 'liveMetric', 'version', 'status', 'lastTrained'],
    modelRows.value
  )
}
</script>

<style scoped>
.matrix-row {
  display: flex;
  align-items: stretch;
  gap: 6px;
  margin-bottom: 6px;
}
.matrix-label {
  width: 26px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
}
.matrix-cell {
  flex: 1;
  border-radius: 10px;
  padding: 10px;
  text-align: center;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.cell-x {
  background: rgba(34, 197, 94, 0.1);
}
.cell-y {
  background: rgba(245, 158, 11, 0.1);
}
.cell-z {
  background: rgba(239, 68, 68, 0.1);
}
.matrix-head {
  flex: 1;
  text-align: center;
  font-size: 11px;
  opacity: 0.65;
}
</style>
