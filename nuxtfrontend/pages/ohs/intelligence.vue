<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-chart-timeline-variant-shimmer"
      eyebrow="OHSMS · Safety intelligence"
      title="Safety Intelligence"
      subtitle="Leading and lagging indicators, cost of risk, predictive forecasting and site benchmarking — the analytical core of the OHSMS."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportReport">Export report</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-target"
               to="/ohs/objectives">Set objective</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-office-building</v-icon>
        <b>{{ fmt(data.sites.total) }}</b> sites</span>
      <span class="ohs-chip"><v-icon size="12">mdi-account-group</v-icon>
        <b>{{ fmt(data.sites.headcount) }}</b> workers</span>
      <span class="ohs-chip" :class="maturityChip">
        <v-icon size="12">mdi-seal-variant</v-icon>
        <b>{{ data.maturity.level }}</b> · {{ data.maturity.score }}
      </span>
      <span v-if="data.signals?.length" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-radar</v-icon>
        <b>{{ data.signals.length }}</b> signals</span>
    </OhsHero>

    <!-- ══════════ MATURITY + INDICATOR SPLIT ══════════ -->
    <v-row dense class="mb-0">
      <v-col cols="12" lg="4">
        <OhsPanel title="Safety maturity index" subtitle="Composite of six management dimensions" icon="mdi-seal-variant">
          <div class="d-flex align-center" style="gap:16px">
            <div class="gauge" :style="gaugeStyle">
              <div class="gauge-hole">
                <div class="gauge-score">{{ data.maturity.score }}</div>
                <div class="gauge-level">{{ data.maturity.level }}</div>
              </div>
            </div>
            <div class="flex-grow-1">
              <div v-for="p in data.maturity.parts" :key="p.key" class="mb-2">
                <div class="d-flex align-center justify-space-between">
                  <span class="text-caption">{{ p.label }}</span>
                  <span class="text-caption font-weight-bold ohs-tabular">{{ p.score }}</span>
                </div>
                <div class="ohs-meter mt-1" :style="{ color: pctColor(p.score) }">
                  <div class="ohs-meter-fill" :style="{ width: p.score + '%' }" />
                </div>
              </div>
            </div>
          </div>
          <div class="maturity-scale mt-3">
            <div v-for="s in maturityScale" :key="s.label" class="maturity-step"
                 :class="{ 'maturity-step--on': s.label === data.maturity.level }">
              {{ s.label }}
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" lg="8">
        <OhsPanel title="Leading vs lagging indicators" subtitle="Reactive outcomes against proactive activity" icon="mdi-swap-horizontal-bold">
          <div class="ind-split">
            <div class="ind-col ind-col--lag">
              <div class="ind-head">
                <v-icon size="15">mdi-history</v-icon> Lagging — what happened
              </div>
              <div v-for="l in laggingRows" :key="l.label" class="ind-row">
                <span class="ind-label">{{ l.label }}</span>
                <span class="d-flex align-center" style="gap:6px">
                  <span class="ind-value">{{ l.value }}</span>
                  <span v-if="l.delta !== null" class="ind-delta"
                        :class="l.goodWhenUp ? (l.delta >= 0 ? 'ok' : 'err') : (l.delta <= 0 ? 'ok' : 'err')">
                    {{ l.delta > 0 ? '▲' : l.delta < 0 ? '▼' : '■' }} {{ Math.abs(l.delta) }}{{ l.suffix }}
                  </span>
                </span>
              </div>
            </div>
            <div class="ind-col ind-col--lead">
              <div class="ind-head">
                <v-icon size="15">mdi-lightning-bolt</v-icon> Leading — what we are doing
              </div>
              <div v-for="l in leadingRows" :key="l.label" class="ind-row">
                <span class="ind-label">{{ l.label }}</span>
                <span class="ind-value">{{ l.value }}</span>
              </div>
            </div>
          </div>

          <v-divider class="my-3" />

          <div class="d-flex flex-wrap align-center" style="gap:10px">
            <div class="ratio-box">
              <div class="ratio-label">Near-miss to incident ratio</div>
              <div class="ratio-value">{{ data.lagging.near_miss_ratio }}%</div>
              <div class="ratio-note">
                {{ ratioVerdict }}
              </div>
            </div>
            <div class="ratio-box">
              <div class="ratio-label">Observations per 100 workers</div>
              <div class="ratio-value">{{ data.leading.observations_per_100_workers }}</div>
              <div class="ratio-note">World class ≥ 50</div>
            </div>
            <div class="ratio-box">
              <div class="ratio-label">Control implementation</div>
              <div class="ratio-value">{{ data.leading.controls_implemented_pct }}%</div>
              <div class="ratio-note">Hierarchy applied &lt; verified</div>
            </div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ══════════ TREND + FORECAST ══════════ -->
    <OhsPanel class="mt-3" title="12-month trend & 3-month forecast"
              subtitle="Incidents, lost-time injuries, near misses and observation volume" icon="mdi-chart-areaspline">
      <SparkArea :values="trendValues" :labels="trendLabels" :height="190"
                 :color="brand.primary.value" :show-y-axis="true" />
      <div class="forecast-strip mt-3">
        <div class="forecast-item">
          <div class="forecast-label">Next month</div>
          <div class="forecast-value" :style="{ color: forecastTone(0) }">
            {{ data.forecast[0]?.predicted ?? '—' }}
          </div>
          <div class="forecast-meta">{{ data.forecast[0]?.label }}</div>
        </div>
        <div class="forecast-item">
          <div class="forecast-label">+2 months</div>
          <div class="forecast-value" :style="{ color: forecastTone(1) }">
            {{ data.forecast[1]?.predicted ?? '—' }}
          </div>
          <div class="forecast-meta">{{ data.forecast[1]?.label }}</div>
        </div>
        <div class="forecast-item">
          <div class="forecast-label">+3 months</div>
          <div class="forecast-value" :style="{ color: forecastTone(2) }">
            {{ data.forecast[2]?.predicted ?? '—' }}
          </div>
          <div class="forecast-meta">{{ data.forecast[2]?.label }}</div>
        </div>
        <div class="forecast-item forecast-item--wide">
          <div class="forecast-label">Trajectory</div>
          <div class="forecast-value" :style="{ color: slopeColor }">
            {{ slope > 0 ? 'Rising' : slope < 0 ? 'Falling' : 'Flat' }}
          </div>
          <div class="forecast-meta">
            {{ slope > 0 ? '+' : '' }}{{ slope.toFixed(2) }} incidents per month
          </div>
        </div>
      </div>

      <div class="d-flex flex-wrap mt-3" style="gap:14px">
        <div class="d-flex align-center" style="gap:6px">
          <span class="dot" :style="{ background: brand.primary.value }" />
          <span class="text-caption text-medium-emphasis">Incidents</span>
        </div>
        <div class="d-flex align-center" style="gap:6px">
          <span class="dot" style="background: #ef4444" />
          <span class="text-caption text-medium-emphasis">Lost-time injuries</span>
        </div>
        <div class="d-flex align-center" style="gap:6px">
          <span class="dot" style="background: #0d9488" />
          <span class="text-caption text-medium-emphasis">Observations</span>
        </div>
      </div>
    </OhsPanel>

    <!-- ══════════ COST OF RISK ══════════ -->
    <v-row dense class="mt-0">
      <v-col cols="12" lg="5">
        <OhsPanel title="Cost of risk" subtitle="Direct claims loaded with the 4× indirect multiplier" icon="mdi-cash-multiple">
          <div class="cost-hero">
            <div>
              <div class="cost-label">Total cost of risk (12m)</div>
              <div class="cost-value">{{ compactMoney(data.cost_of_risk.loaded) }}</div>
              <div class="cost-split">
                {{ compactMoney(data.cost_of_risk.direct) }} direct ·
                {{ compactMoney(data.cost_of_risk.indirect) }} indirect
              </div>
            </div>
            <v-icon size="40" style="opacity:.28">mdi-chart-donut</v-icon>
          </div>

          <div class="cost-grid mt-3">
            <div class="cost-tile">
              <div class="cost-tile-label">Per worker</div>
              <div class="cost-tile-value">{{ compactMoney(data.cost_of_risk.per_worker) }}</div>
            </div>
            <div class="cost-tile">
              <div class="cost-tile-label">Per incident</div>
              <div class="cost-tile-value">{{ compactMoney(data.cost_of_risk.avg_per_incident) }}</div>
            </div>
            <div class="cost-tile">
              <div class="cost-tile-label">Per 200k hours</div>
              <div class="cost-tile-value">{{ compactMoney(data.cost_of_risk.per_200k_hours) }}</div>
            </div>
            <div class="cost-tile cost-tile--accent">
              <div class="cost-tile-label">Insurance saving potential</div>
              <div class="cost-tile-value">{{ compactMoney(data.cost_of_risk.premium_saving_potential) }}</div>
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" lg="7">
        <OhsPanel title="Where the cost comes from" subtitle="Loaded cost by incident type and by site" icon="mdi-chart-bar">
          <div v-for="t in data.cost_of_risk.by_type" :key="t.key" class="mb-2">
            <div class="d-flex align-center justify-space-between">
              <span class="text-caption font-weight-medium">{{ t.label }}</span>
              <span class="text-caption ohs-tabular">
                {{ compactMoney(t.loaded) }}
                <span class="text-medium-emphasis">· {{ t.count }}×</span>
              </span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: costBarColor(t.loaded) }">
              <div class="ohs-meter-fill" :style="{ width: costShare(t.loaded) + '%' }" />
            </div>
          </div>
          <div v-if="!data.cost_of_risk.by_type.length" class="ohs-empty">No costed incidents in this period.</div>

          <v-divider class="my-3" />
          <div class="text-caption font-weight-bold mb-2">Top sites by loaded cost</div>
          <div v-for="s in data.cost_of_risk.by_site.slice(0, 5)" :key="s.id"
               class="d-flex align-center justify-space-between mb-1">
            <span class="text-caption text-truncate" style="max-width:60%">{{ s.name }}</span>
            <span class="text-caption ohs-tabular">
              {{ compactMoney(s.loaded) }}
              <span class="text-medium-emphasis">· {{ compactMoney(s.per_worker) }}/worker</span>
            </span>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ══════════ BENCHMARK + CLAUSE HEATMAP ══════════ -->
    <v-row dense class="mt-0">
      <v-col cols="12" lg="7">
        <OhsPanel title="Site benchmarking" subtitle="TRIR normalised per 200,000 hours worked" icon="mdi-scale-balance" flush>
          <div class="ohs-scroll" style="max-height:340px">
            <table class="ohs-table ohs-table--plain">
              <thead>
                <tr>
                  <th>Site</th>
                  <th style="width:70px" class="num">Staff</th>
                  <th style="width:80px" class="num">Incidents</th>
                  <th style="width:74px" class="num">TRIR</th>
                  <th style="width:74px" class="num">LTIFR</th>
                  <th style="width:88px" class="num">Hazard close</th>
                  <th style="width:78px" class="num">Compliance</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="b in data.benchmark" :key="b.id">
                  <td>
                    <div class="text-caption font-weight-medium">{{ b.name }}</div>
                    <div class="text-caption text-medium-emphasis text-capitalize">{{ b.risk_profile }} hazard</div>
                  </td>
                  <td class="num">{{ b.headcount }}</td>
                  <td class="num">{{ b.incidents }}</td>
                  <td class="num font-weight-bold" :style="{ color: trirColor(b.trir) }">{{ b.trir }}</td>
                  <td class="num" :style="{ color: trirColor(b.ltifr, 2) }">{{ b.ltifr }}</td>
                  <td class="num" :style="{ color: pctColor(b.hazard_close_rate) }">{{ b.hazard_close_rate }}%</td>
                  <td class="num" :style="{ color: pctColor(b.compliance_pct) }">{{ b.compliance_pct }}%</td>
                </tr>
              </tbody>
            </table>
            <div v-if="!data.benchmark.length" class="ohs-empty">No sites to benchmark.</div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <OhsPanel title="ISO 45001 clause compliance" subtitle="Score per clause area of the standard" icon="mdi-view-grid-plus">
          <div v-for="c in data.clause_heatmap" :key="c.clause" class="clause-row">
            <div class="d-flex align-center justify-space-between">
              <span class="text-caption font-weight-medium">{{ c.clause }}</span>
              <span class="text-caption font-weight-bold ohs-tabular">
                {{ c.score === null ? 'n/a' : c.score + '%' }}
              </span>
            </div>
            <div class="clause-bar">
              <div class="clause-fill"
                   :style="{ width: (c.score ?? 0) + '%', background: clauseColor(c.score) }" />
            </div>
            <div class="text-caption text-medium-emphasis">
              {{ c.requirements }} requirement(s) tracked
            </div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ══════════ EMERGING SIGNALS ══════════ -->
    <OhsPanel class="mt-3" title="Emerging risk signals"
              subtitle="Predictive alerts generated from the register" icon="mdi-radar" flush>
      <div v-if="data.signals?.length">
        <div v-for="(s, i) in data.signals" :key="i" class="signal-row">
          <div class="signal-icon" :class="`signal-icon--${s.severity}`">
            <v-icon size="15">{{ signalIcon(s.kind) }}</v-icon>
          </div>
          <div class="flex-grow-1" style="min-width:0">
            <div class="text-body-2 font-weight-bold">{{ s.title }}</div>
            <div class="text-caption text-medium-emphasis">{{ s.detail }}</div>
          </div>
          <span class="ohs-badge" :class="s.severity === 'high' ? 'ohs-badge--err' : 'ohs-badge--warn'">
            {{ s.severity }}
          </span>
          <v-btn icon="mdi-arrow-right" variant="text" size="x-small" :to="s.href" />
        </div>
      </div>
      <div v-else class="ohs-empty">
        <v-icon size="32" color="success">mdi-check-decagram</v-icon>
        No emerging risks detected. Every leading indicator is within tolerance.
      </div>
    </OhsPanel>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Safety Intelligence · OHSMS' })

const ohs = useOhs()
const brand = useBranding()
const { $api } = useNuxtApp()

const empty = {
  sites: { total: 0, headcount: 0, hours: 0 },
  lagging: {},
  leading: {},
  cost_of_risk: { by_type: [], by_site: [] },
  trend: [],
  forecast: [],
  benchmark: [],
  clause_heatmap: [],
  signals: [],
  maturity: { parts: [], score: 0, level: 'Reactive' },
}

const raw = ref(null)
const loading = ref(true)
const data = computed(() => raw.value || empty)

const maturityScale = [
  { label: 'Reactive' }, { label: 'Developing' }, { label: 'Managed' },
  { label: 'Proactive' }, { label: 'World class' },
]

const maturityChip = computed(() => {
  const score = data.value.maturity.score
  if (score >= 90) return 'ohs-chip'
  if (score >= 62) return 'ohs-chip'
  return 'ohs-chip ohs-chip-warn'
})

const gaugeStyle = computed(() => {
  const score = Math.max(0, Math.min(data.value.maturity.score, 100))
  const colour = pctColor(score)
  return {
    background: `conic-gradient(${colour} 0% ${score}%, rgba(15,23,42,.07) ${score}% 100%)`,
  }
})

const trendValues = computed(() => (data.value.trend || []).map((t) => t.incidents))
const trendLabels = computed(() => (data.value.trend || []).map((t) => t.label))

const laggingRows = computed(() => {
  const l = data.value.lagging || {}
  const delta = (cur, prev) => {
    if (cur === undefined || prev === undefined || prev === null) return null
    return Math.round((cur - prev) * 100) / 100
  }
  return [
    { label: 'Total incidents', value: l.total_incidents ?? 0,
      delta: delta(l.total_incidents, l.total_incidents_prev), suffix: '' },
    { label: 'TRIR', value: l.trir ?? 0, delta: delta(l.trir, l.trir_prev), suffix: '' },
    { label: 'LTIFR', value: l.ltifr ?? 0, delta: delta(l.ltifr, l.ltifr_prev), suffix: '' },
    { label: 'Recordable injuries', value: l.recordable ?? 0, delta: null, suffix: '' },
    { label: 'Lost-time injuries', value: l.lti ?? 0, delta: null, suffix: '' },
    { label: 'Lost days', value: l.lost_days ?? 0, delta: null, suffix: '' },
    { label: 'Near misses reported', value: l.near_miss ?? 0, delta: null, suffix: '', goodWhenUp: true },
  ].map((r) => ({ ...r, goodWhenUp: r.goodWhenUp ?? false }))
})

const leadingRows = computed(() => {
  const l = data.value.leading || {}
  return [
    { label: 'Behaviour observations', value: l.observations ?? 0 },
    { label: 'Safe behaviour ratio', value: `${l.safe_ratio ?? 0}%` },
    { label: 'Completed inspections', value: l.inspections_completed ?? 0 },
    { label: 'Average inspection score', value: `${l.inspection_score ?? 0}%` },
    { label: 'Toolbox talks & briefings', value: l.toolbox_talks ?? 0 },
    { label: 'Training currency', value: `${l.training_currency_pct ?? 0}%` },
    { label: 'Hazard close-out rate', value: `${l.hazard_close_rate ?? 0}%` },
    { label: 'Contractors approved', value: `${l.contractors_approved_pct ?? 0}%` },
  ]
})

const ratioVerdict = computed(() => {
  const r = Number(data.value.lagging.near_miss_ratio || 0)
  if (r >= 40) return 'Healthy reporting culture'
  if (r >= 20) return 'Adequate — encourage more reporting'
  return 'Weak — under-reporting likely'
})

const slope = computed(() => {
  const t = data.value.trend || []
  if (t.length < 2) return 0
  const n = t.length
  const xs = t.map((_, i) => i)
  const ys = t.map((r) => r.incidents)
  const mx = xs.reduce((a, b) => a + b, 0) / n
  const my = ys.reduce((a, b) => a + b, 0) / n
  const den = xs.reduce((a, x) => a + (x - mx) ** 2, 0) || 1
  return xs.reduce((a, x, i) => a + (x - mx) * (ys[i] - my), 0) / den
})
const slopeColor = computed(() => (slope.value > 0.05 ? '#dc2626' : slope.value < -0.05 ? '#16a34a' : '#64748b'))

function fmt(v) {
  return Number(v || 0).toLocaleString()
}
function compactMoney(v) {
  const n = Number(v || 0)
  if (!n) return 'KES 0'
  if (n >= 1e9) return `KES ${(n / 1e9).toFixed(1)}B`
  if (n >= 1e6) return `KES ${(n / 1e6).toFixed(1)}M`
  if (n >= 1e3) return `KES ${(n / 1e3).toFixed(0)}K`
  return `KES ${n.toFixed(0)}`
}
function pctColor(pct) {
  const n = Number(pct || 0)
  if (n >= 85) return '#16a34a'
  if (n >= 60) return '#f59e0b'
  return '#dc2626'
}
function trirColor(v, warn = 1.5) {
  const n = Number(v || 0)
  if (n === 0) return '#16a34a'
  if (n <= warn) return '#f59e0b'
  return '#dc2626'
}
function clauseColor(score) {
  if (score === null) return '#94a3b8'
  return pctColor(score)
}
function costBarColor(v) {
  const max = Math.max(1, ...(data.value.cost_of_risk.by_type || []).map((t) => t.loaded))
  const ratio = v / max
  if (ratio > 0.66) return '#dc2626'
  if (ratio > 0.33) return '#f59e0b'
  return '#0284c7'
}
function costShare(v) {
  const max = Math.max(1, ...(data.value.cost_of_risk.by_type || []).map((t) => t.loaded))
  return Math.round((v / max) * 100)
}
function forecastTone(i) {
  const f = data.value.forecast?.[i]
  if (!f) return 'rgba(var(--v-theme-on-surface),.4)'
  const avg = (data.value.trend || []).reduce((a, b) => a + b.incidents, 0)
    / Math.max((data.value.trend || []).length, 1)
  return f.predicted > avg ? '#dc2626' : '#16a34a'
}
function signalIcon(kind) {
  return {
    risk: 'mdi-alert-octagon', control: 'mdi-shield-alert', certification: 'mdi-certificate',
    contractor: 'mdi-account-hard-hat', trend: 'mdi-trending-up', culture: 'mdi-account-group',
  }[kind] || 'mdi-radar'
}

function exportReport() {
  const d = data.value
  exportCsv(
    `ohsms_intelligence_${new Date().toISOString().slice(0, 10)}.csv`,
    [
      { metric: 'Maturity score', value: d.maturity.score },
      { metric: 'Maturity level', value: d.maturity.level },
      ...d.maturity.parts.map((p) => ({ metric: `Maturity · ${p.label}`, value: p.score })),
      { metric: 'TRIR', value: d.lagging.trir },
      { metric: 'LTIFR', value: d.lagging.ltifr },
      { metric: 'Total incidents', value: d.lagging.total_incidents },
      { metric: 'Lost days', value: d.lagging.lost_days },
      { metric: 'Near-miss ratio %', value: d.lagging.near_miss_ratio },
      { metric: 'Observations', value: d.leading.observations },
      { metric: 'Safe behaviour %', value: d.leading.safe_ratio },
      { metric: 'Inspection score %', value: d.leading.inspection_score },
      { metric: 'Training currency %', value: d.leading.training_currency_pct },
      { metric: 'Hazard close rate %', value: d.leading.hazard_close_rate },
      { metric: 'Legal compliance %', value: d.leading.legal_compliance_pct },
      { metric: 'Cost of risk (loaded)', value: d.cost_of_risk.loaded },
      { metric: 'Cost per worker', value: d.cost_of_risk.per_worker },
      { metric: 'Insurance saving potential', value: d.cost_of_risk.premium_saving_potential },
    ],
    [{ key: 'metric', label: 'Metric' }, { key: 'value', label: 'Value' }],
  )
}

async function load() {
  loading.value = true
  try {
    const { data: payload } = await $api.get('/ohs/intelligence/')
    raw.value = payload
  } catch {
    raw.value = null
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.dot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; }

.gauge { position: relative; width: 104px; height: 104px; border-radius: 50%; flex-shrink: 0; }
.gauge-hole {
  position: absolute; inset: 13px; border-radius: 50%;
  background: rgb(var(--v-theme-surface));
  display: flex; flex-direction: column; align-items: center; justify-content: center;
}
.gauge-score { font-size: 20px; font-weight: 800; line-height: 1; }
.gauge-level {
  font-size: 8px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55); margin-top: 2px; text-align: center;
}
.maturity-scale { display: grid; grid-template-columns: repeat(5, 1fr); gap: 3px; }
.maturity-step {
  padding: 4px 2px; border-radius: 6px; text-align: center;
  font-size: 8.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .2px;
  color: rgba(var(--v-theme-on-surface), .4);
  background: rgba(15, 23, 42, 0.04);
}
.maturity-step--on { color: #fff; background: var(--brand-primary); }

.ind-split { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
@media (max-width: 760px) { .ind-split { grid-template-columns: 1fr; } }
.ind-col { border-radius: 11px; padding: 10px 12px; }
.ind-col--lag { background: rgba(239, 68, 68, 0.045); border: 1px solid rgba(239, 68, 68, 0.14); }
.ind-col--lead { background: rgba(13, 148, 136, 0.045); border: 1px solid rgba(13, 148, 136, 0.16); }
.ind-head {
  display: flex; align-items: center; gap: 6px;
  font-size: 10.5px; font-weight: 800; text-transform: uppercase; letter-spacing: .4px;
  margin-bottom: 7px;
}
.ind-col--lag .ind-head { color: #b91c1c; }
.ind-col--lead .ind-head { color: #0f766e; }
.ind-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 3px 0; border-bottom: 1px dashed rgba(var(--v-theme-on-surface), .07);
  font-size: 12px;
}
.ind-row:last-child { border-bottom: none; }
.ind-label { color: rgba(var(--v-theme-on-surface), .68); }
.ind-value { font-weight: 800; font-variant-numeric: tabular-nums; }
.ind-delta { font-size: 9.5px; font-weight: 700; padding: 1px 5px; border-radius: 999px; }
.ind-delta.ok { color: #15803d; background: rgba(34, 197, 94, .13); }
.ind-delta.err { color: #b91c1c; background: rgba(239, 68, 68, .12); }

.ratio-box {
  flex: 1 1 150px; padding: 9px 11px; border-radius: 10px;
  background: rgba(15, 23, 42, 0.03); border: 1px solid rgba(15, 23, 42, 0.06);
}
.ratio-label {
  font-size: 9.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px;
  color: rgba(var(--v-theme-on-surface), .5);
}
.ratio-value { font-size: 19px; font-weight: 800; line-height: 1.2; }
.ratio-note { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55); }

.forecast-strip { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
@media (max-width: 700px) { .forecast-strip { grid-template-columns: repeat(2, 1fr); } }
.forecast-item {
  padding: 9px 11px; border-radius: 10px;
  border: 1px solid rgba(15, 23, 42, 0.07); background: rgba(15, 23, 42, 0.02);
}
.forecast-label {
  font-size: 9.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px;
  color: rgba(var(--v-theme-on-surface), .5);
}
.forecast-value { font-size: 19px; font-weight: 800; line-height: 1.2; }
.forecast-meta { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55); }

.cost-hero {
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  padding: 14px; border-radius: 12px; color: #fff;
  background: var(--brand-gradient);
}
.cost-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .5px; opacity: .82; }
.cost-value { font-size: 27px; font-weight: 800; line-height: 1.1; }
.cost-split { font-size: 11px; opacity: .82; }
.cost-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.cost-tile { padding: 9px 11px; border-radius: 10px; background: rgba(15, 23, 42, 0.03); }
.cost-tile--accent { background: rgba(34, 197, 94, 0.1); }
.cost-tile-label {
  font-size: 9.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px;
  color: rgba(var(--v-theme-on-surface), .5);
}
.cost-tile-value { font-size: 15px; font-weight: 800; }

.clause-row { margin-bottom: 10px; }
.clause-bar { height: 7px; border-radius: 999px; background: rgba(15, 23, 42, .07); margin: 4px 0 2px; overflow: hidden; }
.clause-fill { height: 100%; border-radius: 999px; transition: width .4s ease; }

.signal-row {
  display: flex; align-items: center; gap: 11px;
  padding: 10px 14px; border-bottom: 1px solid rgba(var(--v-theme-on-surface), .05);
}
.signal-row:last-child { border-bottom: none; }
.signal-icon {
  width: 30px; height: 30px; border-radius: 9px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center; color: #fff;
}
.signal-icon--high { background: #dc2626; }
.signal-icon--medium { background: #f59e0b; }
.signal-icon--low { background: #0284c7; }
</style>
