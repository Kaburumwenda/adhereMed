<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Patient Analytics"
      subtitle="Demographics, risk stratification, enrolment trends and diagnosis insights."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-account-group"
      :chips="[
        { icon: 'mdi-account-multiple', label: `${d.total} patients` },
        { icon: 'mdi-account-check', label: `${d.active} active` },
        { icon: 'mdi-account-off', label: `${d.discharged} discharged` },
        { icon: 'mdi-account-assign', label: `${d.assigned} assigned` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- KPI strip -->
    <v-row dense>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Patients" :value="d.total" icon="mdi-account-group" color="#0d9488" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Active" :value="d.active" icon="mdi-account-check" color="#10b981" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Assigned" :value="d.assigned || 0" icon="mdi-account-tie" color="#6366f1" :hint="`${d.unassigned || 0} unassigned`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Discharged" :value="d.discharged || 0" icon="mdi-account-off" color="#94a3b8" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Risk distribution -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Risk stratification" subtitle="Patients by risk level"
                       icon="mdi-alert-circle" color="#ef4444">
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="riskSegments" :size="170" :thickness="20">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ d.total || 0 }}</div>
                <div class="text-caption text-medium-emphasis">patients</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="r in riskSegments" :key="r.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="r.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ r.label }}</span>
              <span class="font-weight-bold text-body-2">{{ r.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Gender distribution -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Gender distribution" icon="mdi-gender-male-female" color="#8b5cf6">
          <div class="d-flex flex-column ga-2 mt-2">
            <div v-for="g in genderBars" :key="g.label" class="d-flex align-center">
              <v-icon :icon="g.icon" :color="g.color" size="20" class="mr-3" />
              <span class="text-body-2 flex-grow-1">{{ g.label }}</span>
              <span class="font-weight-bold mr-2">{{ g.value }}</span>
              <v-progress-linear :model-value="g.pct" :color="g.color" rounded
                                 style="max-width:90px;" height="6" />
            </div>
            <EmptyState v-if="!genderBars.length" icon="mdi-gender-male-female" title="No data" dense />
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Age groups -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Age groups" icon="mdi-cake-variant" color="#0ea5e9">
          <BarChart :values="ageValues" :labels="ageLabels" :colors="ageColors" :height="200" />
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Enrolment trend -->
      <v-col cols="12" md="7">
        <HomecarePanel :title="`Enrolment trend (${enrolmentRange})`" subtitle="New patients enrolled per day"
                       icon="mdi-account-plus" color="#10b981">
          <template #actions>
            <v-select :model-value="enrolmentRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('enrolment', val)" />
          </template>
          <BarChart :values="enrolmentValues" :labels="enrolmentLabels" color="#10b981" :height="220" />
          <div class="d-flex ga-3 mt-2">
            <v-chip size="small" variant="tonal" color="success">
              <v-icon start icon="mdi-trending-up" />{{ enrolmentTotal }} enrolled
            </v-chip>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Top diagnoses -->
      <v-col cols="12" md="5">
        <HomecarePanel title="Top diagnoses" subtitle="Most common primary diagnoses"
                       icon="mdi-stethoscope" color="#7c3aed">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(diag, idx) in d.top_diagnoses || []" :key="idx" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" color="purple" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium text-truncate">{{ diag.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ diag.count }} patients</v-list-item-subtitle>
              <template #append>
                <v-chip size="small" variant="tonal" color="purple">{{ diag.count }}</v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!(d.top_diagnoses || []).length" icon="mdi-stethoscope" title="No diagnoses data" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Per-patient table -->
      <v-col cols="12">
        <HomecarePanel title="Patient analysis" subtitle="Per-patient breakdown across the cohort"
                       icon="mdi-account-details" color="#0d9488">
          <template #actions>
            <v-text-field v-model="patientSearch" density="compact" variant="outlined" flat
                          hide-details single-line placeholder="Search patients…"
                          prepend-inner-icon="mdi-magnify" style="max-width: 260px;" />
          </template>
          <v-table density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th class="text-left">#</th>
                <th class="text-left">Patient</th>
                <th class="text-left">MRN</th>
                <th class="text-left">Gender</th>
                <th class="text-right">Age</th>
                <th class="text-left">Risk</th>
                <th class="text-left">Primary diagnosis</th>
                <th class="text-left">Caregiver</th>
                <th class="text-left">Enrolled</th>
                <th class="text-center">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, idx) in pagedPatients" :key="p.id" hover>
                <td class="text-medium-emphasis">{{ patientOffset + idx + 1 }}</td>
                <td class="font-weight-medium">{{ p.name }}</td>
                <td class="text-body-2 text-medium-emphasis">{{ p.mrn }}</td>
                <td class="text-capitalize">{{ p.gender }}</td>
                <td class="text-right">{{ p.age ?? '—' }}</td>
                <td><v-chip size="small" variant="tonal" :color="riskColor(p.risk_level)">{{ p.risk_level }}</v-chip></td>
                <td class="text-body-2 text-truncate" style="max-width: 220px;">{{ p.primary_diagnosis || '—' }}</td>
                <td class="text-body-2">{{ p.assigned_caregiver || 'Unassigned' }}</td>
                <td class="text-body-2 text-medium-emphasis">{{ fmtDate(p.enrolled_at) }}</td>
                <td class="text-center">
                  <v-chip size="small" variant="tonal" :color="p.is_active ? 'success' : 'grey'">
                    {{ p.is_active ? 'Active' : 'Discharged' }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-if="!pagedPatients.length" icon="mdi-account-details" title="No patients found" dense />
          <div v-if="filteredPatients.length > patientPageSize" class="d-flex align-center justify-center ga-2 mt-3">
            <v-btn size="small" variant="tonal" icon="mdi-chevron-left" :disabled="patientPage === 1"
                   @click="patientPage--" />
            <span class="text-body-2 text-medium-emphasis">
              {{ patientPage }} / {{ patientPageCount }} of {{ filteredPatients.length }}
            </span>
            <v-btn size="small" variant="tonal" icon="mdi-chevron-right"
                   :disabled="patientPage === patientPageCount" @click="patientPage++" />
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

const d = ref({})
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })
const enrolmentRange = ref('30d')

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
    today: "Today's", yesterday: "Yesterday's",
    '7d': '7-day', '30d': '30-day', '90d': '90-day',
    '1y': '1-year', all: 'All-time',
  }
  return map[range] || '30-day'
}

const riskSegments = computed(() => {
  const r = d.value.risk || {}
  return [
    { label: 'Low', value: r.low || 0, color: 'success' },
    { label: 'Medium', value: r.medium || 0, color: 'warning' },
    { label: 'High', value: r.high || 0, color: 'error' },
    { label: 'Critical', value: r.critical || 0, color: 'deep-orange' },
  ]
})

const genderBars = computed(() => {
  const g = d.value.gender || {}
  const total = Object.values(g).reduce((a, b) => a + b, 0) || 1
  const entries = [
    { label: 'Male', icon: 'mdi-gender-male', color: 'blue' },
    { label: 'Female', icon: 'mdi-gender-female', color: 'pink' },
    { label: 'Other', icon: 'mdi-gender-transgender', color: 'purple' },
    { label: 'Unknown', icon: 'mdi-help-circle-outline', color: 'grey' },
  ]
  return entries.map(e => {
    const key = (e.label || '').toLowerCase()
    const value = g[key] || g[e.label] || 0
    return { ...e, value, pct: Math.round(value / total * 100) }
  })
})

const ageLabels = computed(() => Object.keys(d.value.age_groups || {}))
const ageValues = computed(() => Object.values(d.value.age_groups || {}))
const ageColors = computed(() => ageLabels.value.map(() => '#0ea5e9'))

const enrolmentValues = computed(() => (d.value.enrolment_trend || []).map(t => t.count))
const enrolmentLabels = computed(() => (d.value.enrolment_trend || []).map(t => t.date.slice(5)))
const enrolmentTotal = computed(() => enrolmentValues.value.reduce((a, b) => a + b, 0))

// ── Per-patient table ──
const patientSearch = ref('')
const patientPage = ref(1)
const patientPageSize = 15

const riskColorMap = { low: 'success', medium: 'warning', high: 'error', critical: 'deep-orange' }
function riskColor(level) { return riskColorMap[level] || 'grey' }

function fmtDate(iso) {
  if (!iso) return '—'
  const dt = new Date(iso)
  return isNaN(dt) ? '—' : dt.toLocaleDateString()
}

const filteredPatients = computed(() => {
  const list = d.value.patients || []
  const q = patientSearch.value.trim().toLowerCase()
  if (!q) return list
  return list.filter(p =>
    (p.name || '').toLowerCase().includes(q) ||
    (p.mrn || '').toLowerCase().includes(q) ||
    (p.primary_diagnosis || '').toLowerCase().includes(q) ||
    (p.assigned_caregiver || '').toLowerCase().includes(q) ||
    (p.gender || '').toLowerCase().includes(q) ||
    (p.risk_level || '').toLowerCase().includes(q)
  )
})

const patientPageCount = computed(() => Math.max(1, Math.ceil(filteredPatients.value.length / patientPageSize)))
const patientOffset = computed(() => (patientPage.value - 1) * patientPageSize)
const pagedPatients = computed(() => filteredPatients.value.slice(patientOffset.value, patientOffset.value + patientPageSize))

watch(patientSearch, () => { patientPage.value = 1 })

function onChartRangeChange(chart, val) {
  const ranges = { enrolment: enrolmentRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { enrolment: enrolmentRange }
  const dataKeys = { enrolment: ['enrolment_trend'] }
  const range = ranges[chart].value
  const keys = dataKeys[chart]
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/patients/', { params: { range } })
    if (data) {
      const updates = {}
      keys.forEach(k => { if (data[k] !== undefined) updates[k] = data[k] })
      d.value = { ...d.value, ...updates }
    }
  } catch {
    snack.text = 'Failed to load chart data'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/patients/', { params: { range: '30d' } })
    d.value = data || {}
    enrolmentRange.value = '30d'
  } catch {
    snack.text = 'Failed to load patient analytics'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
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
</style>
