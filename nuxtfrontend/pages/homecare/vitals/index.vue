<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Vitals & Observations"
      subtitle="Track blood pressure, glucose, weight and more across your patient population."
      eyebrow="CLINICAL MONITORING"
      icon="mdi-heart-pulse"
      :chips="[{ icon: 'mdi-clipboard-pulse', label: `${readings.length} readings` }, { icon: 'mdi-account-multiple', label: `${patients.length} patients` }, { icon: 'mdi-clock', label: 'Live data' }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus" class="text-none"
               @click="openRecord"><span class="text-teal-darken-2 font-weight-bold">Record vitals</span></v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col v-for="k in vitalsKpis" :key="k.label" cols="12" sm="6" md="3">
        <HomecareKpiCard v-bind="k" />
      </v-col>
    </v-row>

    <HomecarePanel
      title="Vitals trend"
      subtitle="All vitals · last 10 readings"
      icon="mdi-chart-line"
      color="#ef4444"
      class="mt-1"
    >
      <template #actions>
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search patient…"
                      density="compact" variant="outlined" hide-details rounded="lg"
                      style="max-width:260px" clearable />
      </template>

      <div v-if="trendCards.length" class="trend-grid">
        <div v-for="m in trendCards" :key="m.key" class="trend-card">
          <div class="d-flex align-center mb-1">
            <v-icon :color="m.color" size="18" class="me-2">{{ m.icon }}</v-icon>
            <span class="text-caption font-weight-bold">{{ m.label }}</span>
            <v-spacer />
            <span class="text-body-2 font-weight-bold" :style="{ color: m.color }">
              {{ m.last }}<span class="text-caption text-medium-emphasis ml-1">{{ m.unit }}</span>
            </span>
          </div>
          <svg :viewBox="`0 0 ${SPARK_W} ${SPARK_H}`" preserveAspectRatio="none" class="spark">
            <polyline :points="m.points" fill="none" :stroke="m.color" stroke-width="2"
                      stroke-linejoin="round" stroke-linecap="round" />
            <circle v-for="(p, i) in m.dots" :key="i" :cx="p.x" :cy="p.y" r="2.6" :fill="m.color">
              <title>{{ p.t }} · {{ p.v }} {{ m.unit }}</title>
            </circle>
          </svg>
        </div>
      </div>
      <EmptyState v-else icon="mdi-chart-line" title="No readings yet"
                  message="Record vitals to see trends." />

      <v-divider class="my-4" />
      <h4 class="text-subtitle-2 font-weight-bold mb-2">Recent readings</h4>
      <v-table density="compact" class="readings-table">
        <thead>
          <tr>
            <th>Patient</th>
            <th>Recorded</th>
            <th>NEWS2</th>
            <th>BP</th>
            <th>RR</th>
            <th>Pulse</th>
            <th>Temp</th>
            <th>SpO₂</th>
            <th>Glucose</th>
            <th>Weight</th>
            <th class="text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in recentReadings" :key="r.id">
            <td>
              <div class="text-body-2 font-weight-medium text-truncate" style="max-width:180px">{{ r.patient_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis">{{ r.adheremed_patient_id || r.medical_record_number || '—' }}</div>
            </td>
            <td class="text-caption">{{ formatDate(r.recorded_at) }}</td>
            <td>
              <v-chip v-if="r.news2 != null" size="x-small" variant="tonal"
                      :color="riskColorFor(r.risk)">{{ r.news2 }}<span v-if="r.risk" class="ml-1">· {{ r.risk }}</span></v-chip>
              <span v-else>—</span>
            </td>
            <td>{{ r.systolic || '—' }}/{{ r.diastolic || '—' }}</td>
            <td>{{ r.rr || '—' }}</td>
            <td>{{ r.pulse || '—' }}</td>
            <td>{{ r.temperature || '—' }}</td>
            <td>{{ r.spo2 || '—' }}%</td>
            <td>{{ r.glucose || '—' }}</td>
            <td>{{ r.weight || '—' }}</td>
            <td class="text-right text-no-wrap">
              <v-btn icon="mdi-eye" size="x-small" variant="text" color="teal" @click="openView(r)" />
              <v-btn icon="mdi-pencil" size="x-small" variant="text" color="primary" @click="openEdit(r)" />
              <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="confirmDelete(r)" />
            </td>
          </tr>
          <tr v-if="!recentReadings.length"><td colspan="11" class="text-center text-medium-emphasis py-4">No readings.</td></tr>
        </tbody>
      </v-table>
    </HomecarePanel>

    <v-dialog v-model="dialog" max-width="820" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pe-3 py-3">
          <v-icon color="teal" class="me-2">mdi-heart-pulse</v-icon>
          <div>
            <div class="font-weight-bold">{{ editingId ? 'Edit vitals' : 'Record vitals' }}</div>
            <div class="text-caption text-medium-emphasis">National Early Warning Score (NEWS) 2</div>
          </div>
          <v-chip size="small" variant="tonal" color="teal" class="ms-3">NEWS2</v-chip>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text>
          <v-form ref="formRef">
          <v-select v-model="form.patient" :items="patients" :item-title="patientLabel" item-value="id"
                    label="Patient" variant="outlined" density="comfortable" prepend-inner-icon="mdi-account"
                    :rules="[req]" class="mb-2" />
          <v-row>
            <!-- Inputs -->
            <v-col cols="12" md="7">
              <v-row dense>
                <v-col cols="6">
                  <v-text-field v-model.number="form.rr" label="Respiratory rate (/min)" type="number"
                                variant="outlined" density="comfortable" :rules="[req]"
                                :hint="`Score: ${news2Scores.rr}`" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.spo2" label="SpO₂ (%)" type="number"
                                variant="outlined" density="comfortable" :rules="[req]"
                                :hint="`Score: ${news2Scores.spo2}`" persistent-hint />
                </v-col>
                <v-col cols="12">
                  <v-switch v-model="form.scale2" color="teal" hide-details density="compact"
                            :label="`SpO₂ Scale 2 (hypercapnic / COPD target 88–92%)`" />
                </v-col>
                <v-col cols="6">
                  <v-select v-model="form.oxygen" :items="['Room air', 'Supplemental O₂']" label="Oxygen"
                            variant="outlined" density="comfortable" :rules="[req]"
                            :hint="`Score: ${news2Scores.oxygen}`" persistent-hint />
                </v-col>
                <v-col v-if="form.oxygen === 'Supplemental O₂'" cols="6">
                  <v-select v-model="form.oxygen_delivery" :items="oxygenDeliveryModes"
                            label="Mode of delivery" variant="outlined" density="comfortable"
                            :rules="[req]" hint="Route the supplemental oxygen is given" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-select v-model="form.consciousness"
                            :items="[{title:'A — Alert',value:'A'},{title:'C — New confusion',value:'C'},{title:'V — Voice',value:'V'},{title:'P — Pain',value:'P'},{title:'U — Unresponsive',value:'U'}]"
                            label="ACVPU consciousness" variant="outlined" density="comfortable" :rules="[req]"
                            :hint="`Score: ${news2Scores.consciousness}`" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.systolic" label="Systolic BP (mmHg)" type="number"
                                variant="outlined" density="comfortable" :rules="[req]"
                                :hint="`Score: ${news2Scores.sbp}`" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.diastolic" label="Diastolic BP (mmHg)" type="number"
                                variant="outlined" density="comfortable" :rules="[req]" hint="Recorded (not scored)" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.pulse" label="Heart rate (bpm)" type="number"
                                variant="outlined" density="comfortable" :rules="[req]"
                                :hint="`Score: ${news2Scores.hr}`" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.temperature" label="Temperature (°C)" type="number"
                                variant="outlined" density="comfortable" :rules="[req]"
                                :hint="`Score: ${news2Scores.temp}`" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.glucose" label="Glucose (mmol/L)" type="number"
                                variant="outlined" density="comfortable" hint="Optional" persistent-hint />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="form.weight" label="Weight (kg)" type="number"
                                variant="outlined" density="comfortable" hint="Optional" persistent-hint />
                </v-col>
                <v-col cols="12">
                  <v-textarea v-model="form.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
                </v-col>
              </v-row>
            </v-col>
            <v-col cols="12" md="5">
              <div class="news2-panel" :style="{ background: `linear-gradient(135deg, ${news2Risk.hex}22, ${news2Risk.hex}0d)`, borderColor: `${news2Risk.hex}55` }">
                <div class="text-caption text-uppercase font-weight-bold" :style="{ color: news2Risk.hex }">Aggregate NEWS2</div>
                <div class="news2-total" :style="{ color: news2Risk.hex }">{{ news2Total }}</div>
                <v-chip :color="news2Risk.color" variant="flat" class="font-weight-bold mb-2">{{ news2Risk.label }} risk</v-chip>
                <v-alert v-if="news2WillEscalate" type="warning" variant="tonal" density="compact"
                         icon="mdi-alert-octagram" class="text-caption mb-3">
                  Saving will raise an escalation and email the doctor &amp; patient.
                </v-alert>
                <v-divider class="mb-2" />
                <div v-for="b in news2Breakdown" :key="b.key" class="news2-row">
                  <v-icon size="16" class="me-2" :color="b.score >= 3 ? 'error' : (b.score > 0 ? 'warning' : 'grey')">{{ b.icon }}</v-icon>
                  <span class="text-caption flex-grow-1">{{ b.label }}</span>
                  <span class="text-caption text-medium-emphasis me-2">{{ b.value }}</span>
                  <v-chip size="x-small" variant="tonal"
                          :color="b.score >= 3 ? 'error' : (b.score > 0 ? 'warning' : 'success')">{{ b.score }}</v-chip>
                </div>
              </div>
            </v-col>
          </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="save" prepend-icon="mdi-content-save">
            {{ editingId ? 'Update vitals' : 'Save vitals' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- View reading -->
    <v-dialog v-model="viewDialog.show" max-width="520">
      <v-card rounded="xl" v-if="viewDialog.item">
        <v-card-title class="d-flex align-center pe-3 py-3">
          <v-icon color="teal" class="me-2">mdi-clipboard-pulse</v-icon>
          <div>
            <div class="font-weight-bold">Vitals reading</div>
            <div class="text-caption text-medium-emphasis">{{ viewDialog.item.patient_name }} · {{ viewDialog.item.adheremed_patient_id || viewDialog.item.medical_record_number }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="viewDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-chip v-if="viewDialog.item.news2 != null" :color="riskColorFor(viewDialog.item.risk)" variant="flat" class="font-weight-bold">
              NEWS2 {{ viewDialog.item.news2 }} · {{ viewDialog.item.risk }}
            </v-chip>
            <v-spacer />
            <span class="text-caption text-medium-emphasis">{{ formatDate(viewDialog.item.recorded_at) }}</span>
          </div>
          <v-row dense>
            <v-col v-for="f in viewFields(viewDialog.item)" :key="f.label" cols="6">
              <div class="view-tile">
                <div class="text-caption text-medium-emphasis">{{ f.label }}</div>
                <div class="text-body-1 font-weight-bold">{{ f.value }}</div>
              </div>
            </v-col>
          </v-row>
          <div v-if="viewDialog.item.notes" class="mt-3">
            <div class="text-caption text-medium-emphasis">Notes</div>
            <div class="text-body-2">{{ viewDialog.item.notes }}</div>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-btn variant="text" color="error" prepend-icon="mdi-delete" @click="confirmDelete(viewDialog.item); viewDialog.show = false">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="viewDialog.show = false">Close</v-btn>
          <v-btn color="primary" variant="flat" prepend-icon="mdi-pencil" @click="openEdit(viewDialog.item); viewDialog.show = false">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="delDialog.show" max-width="420">
      <v-card rounded="xl" v-if="delDialog.item">
        <v-card-title class="text-h6 font-weight-bold">Delete reading?</v-card-title>
        <v-card-text>
          This will permanently remove the vitals reading for
          <strong>{{ delDialog.item.patient_name }}</strong> recorded on
          {{ formatDate(delDialog.item.recorded_at) }}.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="delDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="deleting" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="5000" location="top">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const patients = ref([])
const readings = ref([])
const search = ref('')
const dialog = ref(false)
const saving = ref(false)
const deleting = ref(false)
const editingId = ref(null)
const viewDialog = reactive({ show: false, item: null })
const delDialog = reactive({ show: false, item: null })
const snack = reactive({ show: false, color: 'success', text: '' })
const formRef = ref(null)
const req = v => (v !== null && v !== undefined && v !== '') || 'Required'
function patientLabel(p) {
  if (!p) return ''
  const name = p.patient_name || p.user?.full_name || 'Unnamed'
  const id = p.adheremed_patient_id || p.medical_record_number
  return id ? `${name} · ${id}` : name
}
const form = reactive({
  patient: null, systolic: null, diastolic: null, pulse: null,
  temperature: null, spo2: null, glucose: null, weight: null,
  rr: null, scale2: false, oxygen: 'Room air', oxygen_delivery: null,
  consciousness: 'A', notes: ''
})

const oxygenDeliveryModes = [
  'Nasal cannula',
  'Simple face mask',
  'Venturi mask',
  'Non-rebreather mask',
  'Partial rebreather mask',
  'High-flow nasal cannula (HFNC)',
  'CPAP',
  'BiPAP / NIV',
  'Tracheostomy mask',
  'T-piece',
  'Nebuliser',
  'Oxygen hood / headbox',
  'Oxygen tent',
  'Mechanical ventilation'
]

watch(() => form.oxygen, (val) => {
  if (val !== 'Supplemental O₂') form.oxygen_delivery = null
})

// ── NEWS2 (RCP 2017) scoring ─────────────────────────────
function scoreRR(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 8) return 3
  if (v <= 11) return 1
  if (v <= 20) return 0
  if (v <= 24) return 2
  return 3
}
function scoreSpO2Scale1(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 91) return 3
  if (v <= 93) return 2
  if (v <= 95) return 1
  return 0
}
function scoreSpO2Scale2(v, onO2) {
  if (v == null || isNaN(v)) return 0
  if (v <= 83) return 3
  if (v <= 85) return 2
  if (v <= 87) return 1
  if (v <= 92) return 0
  if (!onO2) return 0
  if (v <= 94) return 1
  if (v <= 96) return 2
  return 3
}
function scoreOxygen(o) { return o === 'Supplemental O₂' ? 2 : 0 }
function scoreSBP(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 90) return 3
  if (v <= 100) return 2
  if (v <= 110) return 1
  if (v <= 219) return 0
  return 3
}
function scoreHR(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 40) return 3
  if (v <= 50) return 1
  if (v <= 90) return 0
  if (v <= 110) return 1
  if (v <= 130) return 2
  return 3
}
function scoreTemp(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 35.0) return 3
  if (v <= 36.0) return 1
  if (v <= 38.0) return 0
  if (v <= 39.0) return 1
  return 2
}
function scoreConsciousness(c) { return c === 'A' ? 0 : 3 }

const news2Scores = computed(() => ({
  rr: scoreRR(form.rr),
  spo2: form.scale2
    ? scoreSpO2Scale2(form.spo2, form.oxygen === 'Supplemental O₂')
    : scoreSpO2Scale1(form.spo2),
  oxygen: scoreOxygen(form.oxygen),
  sbp: scoreSBP(form.systolic),
  hr: scoreHR(form.pulse),
  temp: scoreTemp(form.temperature),
  consciousness: scoreConsciousness(form.consciousness)
}))
const news2Total = computed(() => Object.values(news2Scores.value).reduce((a, b) => a + b, 0))
const news2HasRed = computed(() => Object.values(news2Scores.value).some(s => s >= 3))
const news2Risk = computed(() => {
  const t = news2Total.value
  if (t === 0) return { label: 'Low', color: 'success', hex: '#059669' }
  if (t <= 4 && !news2HasRed.value) return { label: 'Low – Medium', color: 'info', hex: '#0284c7' }
  if (t <= 6 || news2HasRed.value) return { label: 'Medium', color: 'warning', hex: '#d97706' }
  return { label: 'High', color: 'error', hex: '#b91c1c' }
})
const news2WillEscalate = computed(() => news2Total.value >= 5 || news2HasRed.value)
const news2Breakdown = computed(() => [
  { key: 'rr', icon: 'mdi-lungs', label: 'Respiratory rate',
    value: form.rr != null ? `${form.rr} /min` : '—', score: news2Scores.value.rr },
  { key: 'spo2', icon: 'mdi-water-percent', label: `SpO₂ (Scale ${form.scale2 ? 2 : 1})`,
    value: form.spo2 != null ? `${form.spo2} %` : '—', score: news2Scores.value.spo2 },
  { key: 'oxygen', icon: 'mdi-gas-cylinder', label: 'Supplemental O₂',
    value: form.oxygen, score: news2Scores.value.oxygen },
  { key: 'sbp', icon: 'mdi-heart-pulse', label: 'Systolic BP',
    value: form.systolic != null ? `${form.systolic} mmHg` : '—', score: news2Scores.value.sbp },
  { key: 'hr', icon: 'mdi-heart', label: 'Heart rate',
    value: form.pulse != null ? `${form.pulse} bpm` : '—', score: news2Scores.value.hr },
  { key: 'temp', icon: 'mdi-thermometer', label: 'Temperature',
    value: form.temperature != null ? `${form.temperature} °C` : '—', score: news2Scores.value.temp },
  { key: 'consciousness', icon: 'mdi-brain', label: 'Consciousness',
    value: form.consciousness, score: news2Scores.value.consciousness }
])

function riskColorFor(band) {
  if (band === 'High') return 'error'
  if (band === 'Medium') return 'warning'
  if (band && band.startsWith('Low –')) return 'info'
  return 'success'
}

// ── Trend (small multiples) ──────────────────────────────
const SPARK_W = 280
const SPARK_H = 64
const trendMetrics = [
  { key: 'systolic', label: 'Systolic BP', unit: 'mmHg', color: '#ef4444', icon: 'mdi-heart-pulse' },
  { key: 'pulse', label: 'Heart rate', unit: 'bpm', color: '#0ea5e9', icon: 'mdi-heart' },
  { key: 'rr', label: 'Resp. rate', unit: '/min', color: '#14b8a6', icon: 'mdi-lungs' },
  { key: 'spo2', label: 'SpO₂', unit: '%', color: '#10b981', icon: 'mdi-water-percent' },
  { key: 'temperature', label: 'Temperature', unit: '°C', color: '#f59e0b', icon: 'mdi-thermometer' },
  { key: 'news2', label: 'NEWS2', unit: '', color: '#8b5cf6', icon: 'mdi-alert' },
  { key: 'glucose', label: 'Glucose', unit: 'mmol/L', color: '#6366f1', icon: 'mdi-water' },
  { key: 'weight', label: 'Weight', unit: 'kg', color: '#0d9488', icon: 'mdi-scale-bathroom' }
]

const filteredReadings = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  if (!q) return readings.value
  return readings.value.filter(r =>
    (r.patient_name || '').toLowerCase().includes(q) ||
    (r.adheremed_patient_id || '').toLowerCase().includes(q) ||
    (r.medical_record_number || '').toLowerCase().includes(q)
  )
})
const recentReadings = computed(() => filteredReadings.value.slice(0, 10))
// oldest → newest for plotting
const chronological = computed(() => recentReadings.value.slice().reverse())

function shortDate(iso) {
  return iso ? new Date(iso).toLocaleDateString([], { month: 'short', day: 'numeric' }) : ''
}

const trendCards = computed(() => {
  const rows = chronological.value
  const n = rows.length
  if (!n) return []
  const padX = 6, padY = 8
  const innerW = SPARK_W - padX * 2
  const innerH = SPARK_H - padY * 2
  return trendMetrics.map(m => {
    const present = rows
      .map((r, i) => ({ v: Number(r[m.key]), i, r }))
      .filter(p => p.v != null && !Number.isNaN(p.v) && r_has(p.r, m.key))
    if (!present.length) return null
    const vals = present.map(p => p.v)
    let min = Math.min(...vals), max = Math.max(...vals)
    if (min === max) { min -= 1; max += 1 }
    const xOf = i => padX + (n <= 1 ? innerW / 2 : (i / (n - 1)) * innerW)
    const yOf = v => padY + innerH - ((v - min) / (max - min)) * innerH
    const dots = present.map(p => ({ x: xOf(p.i), y: yOf(p.v), v: p.v, t: shortDate(p.r.recorded_at) }))
    return { ...m, points: dots.map(d => `${d.x},${d.y}`).join(' '), dots, last: vals[vals.length - 1] }
  }).filter(Boolean)
})
function r_has(r, key) {
  return r[key] !== null && r[key] !== undefined && r[key] !== ''
}

const vitalsKpis = computed(() => {
  const list = readings.value
  const uniquePatients = new Set(list.map(r => r.patient)).size
  const elevated = list.slice(0, 10).filter(r => (r.news2 ?? 0) >= 5).length
  const last = list[0]
  return [
    { label: 'Total readings', value: list.length || '—', icon: 'mdi-clipboard-pulse', color: '#0d9488' },
    { label: 'Patients monitored', value: uniquePatients || '—', icon: 'mdi-account-multiple', color: '#0ea5e9' },
    { label: 'Elevated NEWS2', value: elevated, icon: 'mdi-alert-octagram', color: '#ef4444' },
    { label: 'Last reading', value: last ? shortDate(last.recorded_at) : '—', icon: 'mdi-clock-outline', color: '#8b5cf6' }
  ]
})

function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }
function viewFields(r) {
  return [
    { label: 'Blood pressure', value: `${r.systolic || '—'}/${r.diastolic || '—'} mmHg` },
    { label: 'Respiratory rate', value: `${r.rr ?? '—'} /min` },
    { label: 'Heart rate', value: `${r.pulse ?? '—'} bpm` },
    { label: 'SpO₂', value: `${r.spo2 ?? '—'} % (Scale ${r.scale2 ? 2 : 1})` },
    { label: 'Temperature', value: `${r.temperature ?? '—'} °C` },
    { label: 'Oxygen', value: r.oxygen === 'Supplemental O₂' && r.oxygen_delivery ? `${r.oxygen} · ${r.oxygen_delivery}` : (r.oxygen || 'Room air') },
    { label: 'Consciousness', value: r.consciousness || 'A' },
    { label: 'Glucose', value: r.glucose != null ? `${r.glucose} mmol/L` : '—' },
    { label: 'Weight', value: r.weight != null ? `${r.weight} kg` : '—' }
  ]
}

async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}
async function loadReadings() {
  try {
    const { data } = await $api.get('/homecare/vitals/', { params: { ordering: '-recorded_at' } })
    readings.value = data?.results || data || []
  } catch { readings.value = [] }
}

async function save() {
  if (!form.patient) { snack.color = 'error'; snack.text = 'Select a patient first.'; snack.show = true; return }
  if (formRef.value) {
    const { valid } = await formRef.value.validate()
    if (!valid) {
      snack.color = 'error'
      snack.text = 'Please complete all required fields.'
      snack.show = true
      return
    }
  }
  saving.value = true
  try {
    const payload = { ...form, news2: news2Total.value }
    let data
    if (editingId.value) {
      ({ data } = await $api.patch(`/homecare/vitals/${editingId.value}/`, payload))
    } else {
      payload.recorded_at = new Date().toISOString()
      ;({ data } = await $api.post('/homecare/vitals/', payload))
    }
    dialog.value = false
    if (data?.escalated) {
      snack.color = 'error'
      snack.text = `Vitals saved. High NEWS2 (${data.news2 ?? news2Total.value}) — escalation raised and doctor + patient notified.`
    } else {
      snack.color = 'success'
      snack.text = editingId.value
        ? `Reading updated. NEWS2 ${data?.news2 ?? news2Total.value}.`
        : `Vitals saved. NEWS2 ${data?.news2 ?? news2Total.value} (${news2Risk.value.label}).`
    }
    snack.show = true
    await loadReadings()
  } catch (e) {
    snack.color = 'error'
    snack.text = e?.response?.data?.detail || 'Could not save vitals.'
    snack.show = true
    console.warn('Vitals save failed', e)
  } finally { saving.value = false }
}

function resetForm(patientId = null) {
  form.patient = patientId
  form.systolic = form.diastolic = form.pulse = form.temperature = null
  form.spo2 = form.glucose = form.weight = form.rr = null
  form.scale2 = false
  form.oxygen = 'Room air'
  form.oxygen_delivery = null
  form.consciousness = 'A'
  form.notes = ''
}

function openRecord() {
  editingId.value = null
  resetForm(patients.value[0]?.id ?? null)
  dialog.value = true
  nextTick(() => formRef.value?.resetValidation())
}
function openEdit(r) {
  editingId.value = r.id
  form.patient = r.patient
  form.systolic = r.systolic
  form.diastolic = r.diastolic
  form.pulse = r.pulse
  form.temperature = r.temperature
  form.spo2 = r.spo2
  form.rr = r.rr
  form.glucose = r.glucose
  form.weight = r.weight
  form.scale2 = !!r.scale2
  form.oxygen = r.oxygen || 'Room air'
  form.oxygen_delivery = r.oxygen_delivery || null
  form.consciousness = r.consciousness || 'A'
  form.notes = r.notes || ''
  dialog.value = true
  nextTick(() => formRef.value?.resetValidation())
}
function openView(r) { viewDialog.item = r; viewDialog.show = true }
function confirmDelete(r) { delDialog.item = r; delDialog.show = true }
async function doDelete() {
  if (!delDialog.item) return
  deleting.value = true
  try {
    await $api.delete(`/homecare/vitals/${delDialog.item.id}/`)
    snack.color = 'success'; snack.text = 'Reading deleted.'; snack.show = true
    delDialog.show = false
    await loadReadings()
  } catch (e) {
    snack.color = 'error'; snack.text = 'Could not delete reading.'; snack.show = true
  } finally { deleting.value = false }
}

onMounted(() => { loadPatients(); loadReadings() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.min-w-0 { min-width: 0; }
.trend-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(230px, 1fr));
  gap: 12px;
}
.trend-card {
  border: 1px solid rgba(148,163,184,0.22);
  border-radius: 14px;
  padding: 12px 14px;
  background: #fff;
}
.spark { width: 100%; height: 64px; display: block; overflow: visible; }
.readings-table :deep(td), .readings-table :deep(th) { white-space: nowrap; }
.view-tile {
  border: 1px solid rgba(148,163,184,0.2);
  border-radius: 12px;
  padding: 8px 12px;
}
.news2-panel {
  border: 1px solid rgba(13,148,136,0.2);
  border-radius: 16px;
  padding: 16px;
  position: sticky;
  top: 8px;
}
.news2-total { font-size: 46px; font-weight: 800; line-height: 1; margin: 2px 0 8px; }
.news2-row {
  display: flex; align-items: center;
  padding: 5px 0;
  border-bottom: 1px solid rgba(148,163,184,0.15);
}
.news2-row:last-child { border-bottom: none; }
:global(.v-theme--dark .news2-row) { border-bottom-color: rgba(148,163,184,0.12); }
:global(.v-theme--dark .trend-card) { background: rgba(30,41,59,0.55); border-color: rgba(148,163,184,0.16); }
:global(.v-theme--dark .view-tile) { border-color: rgba(148,163,184,0.16); }
</style>
