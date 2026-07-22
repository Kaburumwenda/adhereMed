<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Analytics Command Centre"
      subtitle="A premium, real-time view of operational health across the entire homecare programme."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-chart-box-outline"
      :chips="[
        { icon: 'mdi-account-group', label: `${kpi.activePatients} active patients` },
        { icon: 'mdi-account-heart', label: `${kpi.onDuty} on duty` },
        { icon: 'mdi-pill', label: `${kpi.adherenceToday}% adherence` },
        { icon: 'mdi-cash-multiple', label: money(kpi.monthlyRevenue) + ' /mo`' }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none mr-2" :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-download"
               class="text-none" @click="exportCsv">
          <span class="text-teal-darken-2 font-weight-bold">Export</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Sub-navigation chips -->
    <div class="d-flex flex-wrap ga-2 mb-4">
      <v-chip v-for="s in sections" :key="s.path" :to="s.path" variant="tonal"
              size="large" rounded="pill" class="text-none font-weight-medium"
              :color="s.color">
        <v-icon start :icon="s.icon" size="16" />{{ s.label }}
      </v-chip>
    </div>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="c in kpiCards" :key="c.label" cols="12" sm="6" md="4" lg="3">
        <HomecareKpiCard
          :label="c.label" :value="c.value" :icon="c.icon" :color="c.color"
          :hint="c.hint" :to="c.to" :spark="c.spark" />
      </v-col>
    </v-row>

    <!-- Main chart row -->
    <v-row class="mt-3">
      <v-col cols="12" lg="8">
        <HomecarePanel :title="`${rangeLabel(adherenceRange)} adherence trend`" subtitle="% of doses documented on time"
                       icon="mdi-chart-line" color="#0d9488">
          <template #actions>
            <v-select :model-value="adherenceRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('adherence', val)" />
          </template>
          <LineChart :series="[{ label: 'Adherence', color: '#0d9488', values: adherenceValues }]"
                     :labels="trendLabels" :height="240" />
          <div class="d-flex flex-wrap ga-3 mt-3">
            <v-chip color="teal" variant="tonal">
              <v-icon start icon="mdi-trending-up" />{{ adherenceRange }} avg: {{ avgAdherence }}%
            </v-chip>
            <v-chip color="success" variant="tonal">
              <v-icon start icon="mdi-arrow-up" />Best: {{ bestAdherence }}%
            </v-chip>
            <v-chip color="error" variant="tonal">
              <v-icon start icon="mdi-arrow-down" />Worst: {{ worstAdherence }}%
            </v-chip>
            <v-chip color="info" variant="tonal">
              <v-icon start icon="mdi-pill-multiple" />{{ kpi.adherence30d }}% overall
            </v-chip>
          </div>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel :title="`Dose outcomes (${doseRange})`" subtitle="All scheduled doses"
                       icon="mdi-pill-multiple" color="#10b981">
          <template #actions>
            <v-select :model-value="doseRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('dose', val)" />
          </template>
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="doseSegments" :size="170" :thickness="18">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ doseBreakdown.total || 0 }}</div>
                <div class="text-caption text-medium-emphasis">doses</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="s in doseSegments" :key="s.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Visits + revenue row -->
    <v-row class="mt-3">
      <v-col cols="12" md="6">
        <HomecarePanel :title="`Visit activity (${visitRange})`" subtitle="Completed vs missed visits"
                       icon="mdi-calendar-clock" color="#6366f1">
          <template #actions>
            <v-select :model-value="visitRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('visit', val)" />
          </template>
          <BarChart :values="visitValues" :labels="visitLabels"
                     :colors="visitBarColors" :height="200" />
          <div class="d-flex ga-3 mt-2">
            <v-chip size="small" variant="tonal" color="success">
              <v-icon start icon="mdi-check-circle" />{{ kpi.visitsCompleted30d }} done
            </v-chip>
            <v-chip size="small" variant="tonal" color="error">
              <v-icon start icon="mdi-close-circle" />{{ kpi.visitsMissed30d }} missed
            </v-chip>
            <v-chip size="small" variant="tonal" color="info">
              <v-icon start icon="mdi-calendar-today" />{{ kpi.visitsToday }} today
            </v-chip>
          </div>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="6">
        <HomecarePanel :title="`Revenue collected (${revenueRange})`" subtitle="Daily payments received"
                       icon="mdi-cash-multiple" color="#f59e0b">
          <template #actions>
            <v-select :model-value="revenueRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('revenue', val)" />
          </template>
          <SparkArea :values="revenueValues" :labels="trendLabels" :height="200" color="#f59e0b"
                     :showYAxis="false" />
          <div class="d-flex ga-3 mt-2">
            <v-chip size="small" variant="tonal" color="success">
              <v-icon start icon="mdi-cash" />{{ money(kpi.totalCollected30d) }}
            </v-chip>
            <v-chip size="small" variant="tonal" color="warning">
              <v-icon start icon="mdi-cash-clock" />{{ money(kpi.outstanding) }} outstanding
            </v-chip>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Quick-link tiles to sub-analytic domains -->
    <h3 class="text-subtitle-1 font-weight-bold mt-6 mb-3">
      <v-icon icon="mdi-chart-multiple" color="teal" class="mr-1" />Analytics domains
    </h3>
    <v-row dense>
      <v-col v-for="d in domains" :key="d.path" cols="6" sm="4" md="3" lg="3">
        <v-card :to="d.path" rounded="xl" class="an-tile pa-4 h-100" hover>
          <v-avatar size="44" rounded="lg"
                    :style="{ background: `linear-gradient(135deg,${d.color},${d.color}aa)` }"
                    class="mb-3">
            <v-icon :icon="d.icon" color="white" />
          </v-avatar>
          <div class="text-subtitle-2 font-weight-bold">{{ d.label }}</div>
          <div class="text-caption text-medium-emphasis">{{ d.hint }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const data = ref({})
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })
const adherenceRange = ref('30d')
const doseRange = ref('30d')
const visitRange = ref('30d')
const revenueRange = ref('30d')

const rangeOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Yesterday', value: 'yesterday' },
  { title: 'Last 7 days', value: '7d' },
  { title: 'Last 30 days', value: '30d' },
  { title: 'Last 90 days', value: '90d' },
  { title: 'Last year', value: '1y' },
  { title: 'All time', value: 'all' },
]

function rangeLabel(range) {
  const map = {
    today: "Today's",
    yesterday: "Yesterday's",
    '7d': '7-day',
    '30d': '30-day',
    '90d': '90-day',
    '1y': '1-year',
    all: 'All-time',
  }
  return map[range] || '30-day'
}

const sections = [
  { label: 'Overview', path: '/homecare/analytics', icon: 'mdi-view-dashboard-variant', color: 'teal' },
  { label: 'Patients', path: '/homecare/analytics/patients', icon: 'mdi-account-group', color: 'blue' },
  { label: 'Workforce', path: '/homecare/analytics/caregivers', icon: 'mdi-account-heart', color: 'indigo' },
  { label: 'Visits', path: '/homecare/analytics/visits', icon: 'mdi-calendar-clock', color: 'purple' },
  { label: 'Adherence', path: '/homecare/analytics/adherence', icon: 'mdi-pill-multiple', color: 'success' },
  { label: 'Escalations', path: '/homecare/analytics/escalations', icon: 'mdi-alert-octagram', color: 'error' },
  { label: 'Financials', path: '/homecare/analytics/financials', icon: 'mdi-cash-multiple', color: 'amber' },
  { label: 'Insurance', path: '/homecare/analytics/insurance', icon: 'mdi-shield-account-outline', color: 'deep-orange' },
  { label: 'Equipment', path: '/homecare/analytics/equipment', icon: 'mdi-devices', color: 'cyan' },
]

const domains = [
  { label: 'Patients', hint: 'Demographics & risk', path: '/homecare/analytics/patients', icon: 'mdi-account-group', color: '#0ea5e9' },
  { label: 'Workforce', hint: 'Caregiver performance', path: '/homecare/analytics/caregivers', icon: 'mdi-account-heart', color: '#6366f1' },
  { label: 'Visits', hint: 'Schedules & completion', path: '/homecare/analytics/visits', icon: 'mdi-calendar-clock', color: '#7c3aed' },
  { label: 'Adherence', hint: 'Medication tracking', path: '/homecare/analytics/adherence', icon: 'mdi-pill-multiple', color: '#10b981' },
  { label: 'Escalations', hint: 'Alerts & resolution', path: '/homecare/analytics/escalations', icon: 'mdi-alert-octagram', color: '#ef4444' },
  { label: 'Financials', hint: 'Billing & revenue', path: '/homecare/analytics/financials', icon: 'mdi-cash-multiple', color: '#f59e0b' },
  { label: 'Insurance', hint: 'Claims & approval', path: '/homecare/analytics/insurance', icon: 'mdi-shield-account-outline', color: '#f97316' },
  { label: 'Equipment', hint: 'Device utilisation', path: '/homecare/analytics/equipment', icon: 'mdi-devices', color: '#06b6d4' },
]

const kpi = computed(() => data.value?.kpis || {})
const doseBreakdown = computed(() => data.value?.dose_breakdown || {})

const kpiCards = computed(() => {
  const k = kpi.value
  return [
    { label: 'Active Patients', value: k.active_patients ?? 0, icon: 'mdi-account-group', color: '#0d9488', to: '/homecare/analytics/patients', hint: `${k.total_patients ?? 0} total` },
    { label: 'Adherence (30d)', value: (k.adherence_30d ?? 0) + '%', icon: 'mdi-pill', color: '#10b981', to: '/homecare/analytics/adherence', hint: `${k.adherence_today ?? 0}% today` },
    { label: 'Visits Done (30d)', value: k.visits_completed_30d ?? 0, icon: 'mdi-calendar-check', color: '#6366f1', to: '/homecare/analytics/visits', hint: `${k.visits_today ?? 0} today` },
    { label: 'Open Escalations', value: k.escalations_open ?? 0, icon: 'mdi-alert-octagram', color: '#ef4444', to: '/homecare/analytics/escalations', hint: `${k.escalations_30d ?? 0} in 30d` },
    { label: 'Monthly Revenue', value: money(k.monthly_revenue), icon: 'mdi-cash-multiple', color: '#f59e0b', to: '/homecare/analytics/financials', hint: money(k.outstanding) + ' outstanding' },
    { label: 'Open Claims', value: k.claims_open ?? 0, icon: 'mdi-shield-account', color: '#f97316', to: '/homecare/analytics/insurance', hint: `${k.claims_30d ?? 0} new` },
    { label: 'Equipment Util.', value: (k.utilisation ?? 0) + '%', icon: 'mdi-devices', color: '#06b6d4', to: '/homecare/analytics/equipment', hint: `${k.devices_available ?? 0} available` },
    { label: 'Teleconsults', value: k.teleconsults_30d ?? 0, icon: 'mdi-video', color: '#8b5cf6', hint: 'last 30 days' },
  ]
})

const trendLabels = computed(() => (data.value?.adherence_trend || []).map(d => d.date.slice(5)))
const adherenceValues = computed(() => (data.value?.adherence_trend || []).map(d => d.rate))
const visitValues = computed(() => (data.value?.visit_trend || []).flatMap(d => [d.completed, d.missed]))
const visitLabels = computed(() => (data.value?.visit_trend || []).flatMap(d => [d.date.slice(5), '']))
const visitBarColors = computed(() => (data.value?.visit_trend || []).flatMap(() => ['#10b981', '#ef4444']))
const revenueValues = computed(() => (data.value?.revenue_trend || []).map(d => d.amount))

const avgAdherence = computed(() => {
  const v = adherenceValues.value
  return v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length) : 0
})
const bestAdherence = computed(() => adherenceValues.value.length ? Math.max(...adherenceValues.value) : 0)
const worstAdherence = computed(() => adherenceValues.value.length ? Math.min(...adherenceValues.value) : 0)

const doseSegments = computed(() => {
  const d = doseBreakdown.value
  return [
    { label: 'Taken', value: d.taken || 0, color: 'success' },
    { label: 'Pending', value: d.pending || 0, color: 'info' },
    { label: 'Missed', value: d.missed || 0, color: 'error' },
    { label: 'Skipped', value: d.skipped || 0, color: 'warning' },
    { label: 'Refused', value: d.refused || 0, color: 'grey' },
  ]
})

function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function onChartRangeChange(chart, val) {
  const ranges = { adherence: adherenceRange, dose: doseRange, visit: visitRange, revenue: revenueRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { adherence: adherenceRange, dose: doseRange, visit: visitRange, revenue: revenueRange }
  const dataKeys = { adherence: 'adherence_trend', dose: 'dose_breakdown', visit: 'visit_trend', revenue: 'revenue_trend' }
  const range = ranges[chart].value
  const dataKey = dataKeys[chart]
  loading.value = true
  try {
    const { data: d } = await $api.get('/homecare/analytics/overview/', { params: { range } })
    if (d && d[dataKey] !== undefined) {
      data.value = { ...data.value, [dataKey]: d[dataKey] }
    }
  } catch {
    snack.text = 'Failed to load chart data'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

async function load() {
  loading.value = true
  try {
    const { data: d } = await $api.get('/homecare/analytics/overview/', { params: { range: '30d' } })
    data.value = d || {}
    adherenceRange.value = '30d'
    doseRange.value = '30d'
    visitRange.value = '30d'
    revenueRange.value = '30d'
  } catch {
    snack.text = 'Failed to load analytics'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

function exportCsv() {
  const k = kpi.value
  const rows = [['metric', 'value']]
  Object.entries(k).forEach(([m, v]) => rows.push([m, v]))
  const db = data.value.dose_breakdown || {}
  Object.entries(db).forEach(([m, v]) => rows.push(['dose_' + m, v]))
  const csv = rows.map(r => r.join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `homecare-analytics-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
  snack.text = 'Analytics exported'; snack.color = 'success'; snack.show = true
}

onMounted(load)
</script>

<style scoped>
.an-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.05) 0%, rgba(99,102,241,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.an-filter-bar { padding: 12px 16px; background: rgba(255,255,255,0.7); border: 1px solid rgba(15,23,42,0.06); border-radius: 16px; }
:global(.v-theme--dark .an-filter-bar) { background: rgba(30,41,59,0.6); border-color: rgba(255,255,255,0.08); }
.an-tile { transition: transform 0.18s ease, box-shadow 0.18s ease; }
.an-tile:hover { transform: translateY(-3px); box-shadow: 0 14px 30px -16px rgba(15,23,42,0.2) !important; }
</style>
