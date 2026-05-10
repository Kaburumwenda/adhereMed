<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Reports & Analytics"
      subtitle="Operational health of the homecare programme at a glance."
      eyebrow="ANALYTICS"
      icon="mdi-chart-box"
      :chips="[
        { icon: 'mdi-account-group', label: `${kpi.activePatients} active patients` },
        { icon: 'mdi-stethoscope',   label: `${kpi.onDuty} on duty` },
        { icon: 'mdi-percent',       label: `${kpi.adherenceToday}% adherence` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white"
               prepend-icon="mdi-refresh" class="text-none mr-2"
               :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-download" class="text-none" @click="exportCsv">
          <span class="text-teal-darken-2 font-weight-bold">Export CSV</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" size="24" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h5 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
          <v-progress-linear v-if="s.progress != null"
                             :model-value="s.progress" :color="s.color"
                             height="4" rounded class="mt-3" />
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <v-col cols="12" lg="8">
        <HomecarePanel title="7-day adherence trend" subtitle="% of doses taken vs. due"
                       icon="mdi-chart-line" color="#0d9488">
          <BarChart :values="adherenceSeries.values" :labels="adherenceSeries.labels"
                    color="#0d9488" :height="220" />
          <div class="d-flex flex-wrap ga-3 mt-3">
            <v-chip color="teal" variant="tonal">
              <v-icon start icon="mdi-trending-up" />
              7-day avg: {{ adherenceSeries.avg }}%
            </v-chip>
            <v-chip color="success" variant="tonal">
              <v-icon start icon="mdi-arrow-up" />
              Best: {{ adherenceSeries.best }}%
            </v-chip>
            <v-chip color="error" variant="tonal">
              <v-icon start icon="mdi-arrow-down" />
              Worst: {{ adherenceSeries.worst }}%
            </v-chip>
          </div>
        </HomecarePanel>

        <HomecarePanel title="Operational pulse" icon="mdi-pulse" color="#0284c7" class="mt-3">
          <v-row dense>
            <v-col cols="12" md="6">
              <div class="hc-block pa-4 rounded-lg">
                <div class="d-flex align-center mb-2">
                  <v-icon icon="mdi-pill" color="teal" class="mr-2" />
                  <div class="text-subtitle-2 font-weight-bold">Today's doses</div>
                </div>
                <DonutRing :segments="doseSegments" :size="160" :thickness="16">
                  <div class="text-h5 font-weight-bold">{{ data.doses_today_total || 0 }}</div>
                  <div class="text-caption text-medium-emphasis">due today</div>
                </DonutRing>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="hc-block pa-4 rounded-lg">
                <div class="d-flex align-center mb-2">
                  <v-icon icon="mdi-alert-octagram" color="error" class="mr-2" />
                  <div class="text-subtitle-2 font-weight-bold">Escalation severity</div>
                </div>
                <DonutRing :segments="severitySegments" :size="160" :thickness="16">
                  <div class="text-h5 font-weight-bold">{{ data.open_escalations || 0 }}</div>
                  <div class="text-caption text-medium-emphasis">open</div>
                </DonutRing>
              </div>
            </v-col>
          </v-row>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel title="Patient highlights" icon="mdi-star-circle" color="#7c3aed">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(p, idx) in topPatients" :key="p.name" rounded="lg">
              <template #prepend>
                <v-avatar size="32" color="purple" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ p.name }}</v-list-item-title>
              <v-list-item-subtitle>
                {{ p.metric }}
              </v-list-item-subtitle>
            </v-list-item>
            <EmptyState v-if="!topPatients.length" icon="mdi-account-off"
                        title="No patient data" dense />
          </v-list>
        </HomecarePanel>

        <HomecarePanel title="Quick stats" icon="mdi-counter" color="#f59e0b" class="mt-3">
          <div v-for="q in quickStats" :key="q.label"
               class="d-flex align-center pa-2 rounded-lg mb-1"
               :style="{ background: q.bg }">
            <v-avatar size="32" :color="q.color" variant="flat" class="mr-2">
              <v-icon :icon="q.icon" color="white" size="14" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ q.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ q.sub }}</div>
            </div>
            <div class="text-h6 font-weight-bold">{{ q.value }}</div>
          </div>
        </HomecarePanel>
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

async function load() {
  loading.value = true
  try {
    const { data: d } = await $api.get('/homecare/dashboard/summary/')
    data.value = d || {}
  } catch {
    snack.text = 'Failed to load report'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(load)

const kpi = computed(() => ({
  activePatients: data.value.active_patients ?? 0,
  onDuty: data.value.on_duty_caregivers ?? 0,
  adherenceToday: data.value.adherence_today_pct ?? 0,
  openEscalations: data.value.open_escalations ?? 0
}))

const summary = computed(() => [
  { label: 'Active patients',  value: kpi.value.activePatients,
    color: 'teal',    icon: 'mdi-account-group', progress: null },
  { label: 'Caregivers on duty', value: kpi.value.onDuty,
    color: 'info',    icon: 'mdi-stethoscope', progress: null },
  { label: 'Adherence today', value: `${kpi.value.adherenceToday}%`,
    color: 'success', icon: 'mdi-percent', progress: kpi.value.adherenceToday },
  { label: 'Open escalations', value: kpi.value.openEscalations,
    color: 'error',   icon: 'mdi-alert-octagram', progress: null }
])

const adherenceSeries = computed(() => {
  const series = data.value.adherence_7day || []
  const values = series.map(s => Math.round(s.pct ?? 0))
  const labels = series.map(s => {
    if (!s.date) return ''
    const dt = new Date(s.date)
    return dt.toLocaleDateString(undefined, { weekday: 'short' })
  })
  if (!values.length) return { values: [], labels: [], avg: 0, best: 0, worst: 0 }
  const avg = Math.round(values.reduce((a, b) => a + b, 0) / values.length)
  return { values, labels, avg, best: Math.max(...values), worst: Math.min(...values) }
})

const doseSegments = computed(() => {
  const t = data.value.doses_today || {}
  return [
    { label: 'Taken',   value: t.taken   ?? 0, color: 'success' },
    { label: 'Pending', value: t.pending ?? 0, color: 'warning' },
    { label: 'Missed',  value: t.missed  ?? 0, color: 'error' },
    { label: 'Skipped', value: t.skipped ?? 0, color: 'grey' }
  ]
})

const severitySegments = computed(() => {
  const s = data.value.escalation_severity || {}
  return [
    { label: 'Low',      value: s.low      ?? 0, color: 'info' },
    { label: 'Medium',   value: s.medium   ?? 0, color: 'warning' },
    { label: 'High',     value: s.high     ?? 0, color: 'error' },
    { label: 'Critical', value: s.critical ?? 0, color: 'deep-orange' }
  ]
})

const topPatients = computed(() => (data.value.top_patients || []).map(p => ({
  name: p.name || p.patient_name || `Patient ${p.id}`,
  metric: p.metric || (p.adherence_pct != null ? `${p.adherence_pct}% adherence` : '—')
})))

const quickStats = computed(() => [
  { label: 'Visits today', sub: 'Completed home visits',
    icon: 'mdi-home-heart', color: '#0d9488', bg: 'rgba(13,148,136,0.08)',
    value: data.value.visits_today ?? 0 },
  { label: 'Teleconsults', sub: 'Live + scheduled',
    icon: 'mdi-video', color: '#0284c7', bg: 'rgba(2,132,199,0.08)',
    value: data.value.teleconsult_today ?? 0 },
  { label: 'Active Rx', sub: 'Pharmacy in flight',
    icon: 'mdi-prescription', color: '#7c3aed', bg: 'rgba(124,58,237,0.08)',
    value: data.value.active_prescriptions ?? 0 },
  { label: 'Pending claims', sub: 'Awaiting payer',
    icon: 'mdi-shield-clock', color: '#f59e0b', bg: 'rgba(245,158,11,0.08)',
    value: data.value.pending_claims ?? 0 }
])

function exportCsv() {
  const rows = [['metric', 'value']]
  rows.push(['active_patients', kpi.value.activePatients])
  rows.push(['on_duty_caregivers', kpi.value.onDuty])
  rows.push(['adherence_today_pct', kpi.value.adherenceToday])
  rows.push(['open_escalations', kpi.value.openEscalations])
  for (const q of quickStats.value) rows.push([q.label, q.value])
  for (const s of adherenceSeries.value.values
    .map((v, i) => [`adherence_${adherenceSeries.value.labels[i] || i}`, v])) rows.push(s)
  const csv = rows.map(r => r.join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `homecare-report-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
  snack.text = 'Report exported'; snack.color = 'success'; snack.show = true
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(124,58,237,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
}
.hc-block {
  background: rgba(15,23,42,0.03);
  border: 1px solid rgba(15,23,42,0.05);
  text-align: center;
}
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-block { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
</style>
