<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Vitals & Observations"
      subtitle="Track blood pressure, glucose, weight and more across your patient population."
      eyebrow="CLINICAL MONITORING"
      icon="mdi-heart-pulse"
      :chips="[{ icon: 'mdi-account-multiple', label: `${patients.length} patients` }, { icon: 'mdi-clock', label: 'Live data' }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus" class="text-none"
               @click="dialog = true"><span class="text-teal-darken-2 font-weight-bold">Record vitals</span></v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col v-for="k in vitalsKpis" :key="k.label" cols="12" sm="6" md="3">
        <HomecareKpiCard v-bind="k" />
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <v-col cols="12" md="4">
        <HomecarePanel title="Patients" subtitle="Select to view trends" icon="mdi-account-multiple" color="#0d9488">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search…"
                        density="compact" variant="outlined" hide-details class="mb-2" />
          <div class="hc-list" style="max-height:540px;overflow-y:auto;">
            <div v-for="p in filteredPatients" :key="p.id" class="hc-list-row"
                 :class="{ 'hc-list-row--active': active?.id === p.id }" @click="select(p)">
              <v-avatar size="36" color="teal" variant="tonal">
                <span class="font-weight-bold">{{ initials(p.patient_name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-bold text-truncate">{{ p.patient_name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ p.primary_diagnosis || '—' }}</div>
              </div>
              <StatusChip :status="p.risk_level || 'low'" />
            </div>
            <EmptyState v-if="!filteredPatients.length" icon="mdi-account-off" title="No patients" />
          </div>
        </HomecarePanel>
      </v-col>
      <v-col cols="12" md="8">
        <HomecarePanel
          :title="active ? `${active.patient_name} · vitals trend` : 'Select a patient'"
          subtitle="Last 14 days"
          icon="mdi-chart-line"
          color="#ef4444"
        >
          <template #actions>
            <v-btn-toggle v-model="metric" mandatory density="compact" color="teal" variant="outlined" rounded="lg">
              <v-btn v-for="m in metrics" :key="m.key" :value="m.key" size="small" class="text-none">
                {{ m.label }}
              </v-btn>
            </v-btn-toggle>
          </template>
          <BarChart v-if="series.length" :values="series" :labels="seriesLabels" :height="260"
                    :color="metricColor" />
          <EmptyState v-else icon="mdi-chart-line" title="No readings yet"
                      message="Record vitals to see trends." />
          <v-divider class="my-4" />
          <h4 class="text-subtitle-2 font-weight-bold mb-2">Recent readings</h4>
          <v-table density="compact">
            <thead>
              <tr>
                <th>Recorded</th>
                <th>BP</th>
                <th>Pulse</th>
                <th>Temp</th>
                <th>SpO₂</th>
                <th>Glucose</th>
                <th>Weight</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in recentReadings" :key="r.id">
                <td class="text-caption">{{ formatDate(r.recorded_at) }}</td>
                <td>{{ r.systolic || '—' }}/{{ r.diastolic || '—' }}</td>
                <td>{{ r.pulse || '—' }}</td>
                <td>{{ r.temperature || '—' }}</td>
                <td>{{ r.spo2 || '—' }}%</td>
                <td>{{ r.glucose || '—' }}</td>
                <td>{{ r.weight || '—' }}</td>
              </tr>
              <tr v-if="!recentReadings.length"><td colspan="7" class="text-center text-medium-emphasis">No readings.</td></tr>
            </tbody>
          </v-table>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-dialog v-model="dialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title>Record vitals</v-card-title>
        <v-card-text>
          <v-select v-model="form.patient" :items="patients" item-title="patient_name" item-value="id" label="Patient" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model.number="form.systolic" label="Systolic" type="number" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="form.diastolic" label="Diastolic" type="number" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="form.pulse" label="Pulse (bpm)" type="number" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="form.temperature" label="Temp (°C)" type="number" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="form.spo2" label="SpO₂ (%)" type="number" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="form.glucose" label="Glucose (mmol/L)" type="number" /></v-col>
            <v-col cols="12"><v-text-field v-model.number="form.weight" label="Weight (kg)" type="number" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const patients = ref([])
const active = ref(null)
const readings = ref([])
const search = ref('')
const dialog = ref(false)
const saving = ref(false)
const metric = ref('systolic')
const form = reactive({ patient: null, systolic: null, diastolic: null, pulse: null,
                       temperature: null, spo2: null, glucose: null, weight: null, notes: '' })

const metrics = [
  { key: 'systolic', label: 'BP', color: '#ef4444' },
  { key: 'pulse', label: 'Pulse', color: '#0ea5e9' },
  { key: 'temperature', label: 'Temp', color: '#f59e0b' },
  { key: 'spo2', label: 'SpO₂', color: '#10b981' },
  { key: 'glucose', label: 'Glucose', color: '#8b5cf6' },
  { key: 'weight', label: 'Weight', color: '#0d9488' }
]

const filteredPatients = computed(() => {
  const q = (search.value || '').toLowerCase()
  if (!q) return patients.value
  return patients.value.filter(p => (p.patient_name || '').toLowerCase().includes(q))
})

const recentReadings = computed(() => readings.value.slice(0, 10))
const series = computed(() => readings.value.slice(0, 14).reverse().map(r => Number(r[metric.value]) || 0))
const seriesLabels = computed(() => readings.value.slice(0, 14).reverse().map(r =>
  new Date(r.recorded_at).toLocaleDateString([], { month: 'short', day: 'numeric' })
))
const metricColor = computed(() => metrics.find(m => m.key === metric.value)?.color || '#0d9488')

const vitalsKpis = computed(() => {
  const last = readings.value[0] || {}
  return [
    { label: 'Last BP', value: last.systolic ? `${last.systolic}/${last.diastolic}` : '—',
      icon: 'mdi-heart', color: '#ef4444' },
    { label: 'Last Pulse', value: last.pulse || '—', suffix: 'bpm', icon: 'mdi-pulse', color: '#0ea5e9' },
    { label: 'Last Glucose', value: last.glucose || '—', suffix: 'mmol/L', icon: 'mdi-water', color: '#8b5cf6' },
    { label: 'Last Weight', value: last.weight || '—', suffix: 'kg', icon: 'mdi-scale-bathroom', color: '#0d9488' }
  ]
})

function initials(n) {
  return (n || '').split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?'
}
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }

async function loadPatients() {
  const { data } = await $api.get('/homecare/patients/')
  patients.value = data?.results || data || []
  if (patients.value.length && !active.value) select(patients.value[0])
}
async function select(p) {
  active.value = p
  try {
    const { data } = await $api.get('/homecare/vitals/', { params: { patient: p.id, ordering: '-recorded_at' } })
    readings.value = data?.results || data || []
  } catch { readings.value = [] }
}
async function save() {
  saving.value = true
  try {
    await $api.post('/homecare/vitals/', { ...form, recorded_at: new Date().toISOString() })
    dialog.value = false
    if (active.value) select(active.value)
  } catch (e) { console.warn('Vitals endpoint not available', e) }
  finally { saving.value = false }
}
onMounted(loadPatients)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-list { display: flex; flex-direction: column; gap: 6px; }
.hc-list-row {
  display: flex; align-items: center; gap: 12px;
  padding: 8px 10px; border-radius: 10px; cursor: pointer;
  transition: background 0.12s ease;
}
.hc-list-row:hover { background: rgba(13,148,136,0.06); }
.hc-list-row--active { background: rgba(13,148,136,0.12); }
.min-w-0 { min-width: 0; }
</style>
