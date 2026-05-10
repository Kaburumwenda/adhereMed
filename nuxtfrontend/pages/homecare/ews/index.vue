<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Early Warning Score"
      subtitle="Digital NEWS2 calculator for rapid bedside deterioration detection."
      eyebrow="CLINICAL SAFETY"
      icon="mdi-pulse"
      :chips="[
        { icon: 'mdi-check-decagram', label: 'NEWS2 (RCP 2017)' },
        { icon: 'mdi-shield-check',   label: 'Validated thresholds' }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-restore"
               class="text-none" @click="reset">
          <span class="text-teal-darken-2 font-weight-bold">Reset</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row>
      <!-- ───────────── Inputs ───────────── -->
      <v-col cols="12" lg="7">
        <HomecarePanel title="Vital signs" subtitle="Enter the latest set of observations"
                       icon="mdi-stethoscope" color="#0d9488">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-autocomplete v-model="patient" :items="patients" item-title="name"
                              item-value="id" label="Patient (optional)"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-account" clearable
                              :loading="loadingPatients" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="recordedAt" label="Recorded at" type="datetime-local"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-clock-outline" />
            </v-col>

            <v-col cols="12" md="6">
              <v-text-field v-model.number="vitals.rr" label="Respiratory rate (breaths/min)"
                            type="number" variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-lungs"
                            :hint="`Score: ${scores.rr}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="vitals.spo2" label="SpO₂ (%)"
                            type="number" variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-water-percent"
                            :hint="`Score: ${scores.spo2}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="vitals.scale2" color="teal" hide-details
                        label="Use SpO₂ Scale 2 (target 88–92%, e.g. COPD)"
                        density="comfortable" class="mt-n1" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="vitals.oxygen" :items="['Room air','Supplemental O₂']"
                        label="Oxygen" variant="outlined" density="comfortable"
                        rounded="lg" prepend-inner-icon="mdi-gas-cylinder"
                        :hint="`Score: ${scores.oxygen}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model.number="vitals.sbp" label="Systolic BP (mmHg)"
                            type="number" variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-heart-pulse"
                            :hint="`Score: ${scores.sbp}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model.number="vitals.hr" label="Heart rate (bpm)"
                            type="number" variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-heart"
                            :hint="`Score: ${scores.hr}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model.number="vitals.temp" label="Temperature (°C)"
                            type="number" step="0.1" variant="outlined"
                            density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-thermometer"
                            :hint="`Score: ${scores.temp}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="vitals.consciousness"
                        :items="[
                          { value: 'A', title: 'A — Alert' },
                          { value: 'C', title: 'C — Confusion (new)' },
                          { value: 'V', title: 'V — Voice' },
                          { value: 'P', title: 'P — Pain' },
                          { value: 'U', title: 'U — Unresponsive' }
                        ]"
                        item-title="title" item-value="value"
                        label="ACVPU consciousness"
                        variant="outlined" density="comfortable" rounded="lg"
                        prepend-inner-icon="mdi-brain"
                        :hint="`Score: ${scores.consciousness}`" persistent-hint />
            </v-col>
            <v-col cols="12" md="6">
              <v-textarea v-model="notes" label="Clinical notes"
                          rows="2" auto-grow variant="outlined" density="comfortable"
                          rounded="lg" prepend-inner-icon="mdi-note-text"
                          hint="Observed concerns, mitigating actions taken…"
                          persistent-hint />
            </v-col>
          </v-row>

          <v-divider class="my-4" />
          <div class="d-flex flex-wrap ga-2">
            <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-restore"
                   @click="reset">Clear</v-btn>
            <v-spacer />
            <v-btn variant="tonal" rounded="lg" color="indigo" class="text-none"
                   prepend-icon="mdi-history" @click="logScore">Save reading</v-btn>
            <v-btn :color="totalColor" rounded="lg" class="text-none" prepend-icon="mdi-bell-alert"
                   @click="escalate">Escalate</v-btn>
          </div>
        </HomecarePanel>

        <!-- Score history -->
        <HomecarePanel v-if="history.length" title="Today's readings" icon="mdi-chart-line"
                       color="#7c3aed" class="mt-3">
          <v-table density="comfortable">
            <thead>
              <tr>
                <th class="text-left">Time</th>
                <th>RR</th><th>SpO₂</th><th>BP</th><th>HR</th><th>Temp</th><th>ACVPU</th>
                <th>Total</th><th>Risk</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(h, i) in history" :key="i">
                <td class="text-caption">{{ h.time }}</td>
                <td>{{ h.vitals.rr }}</td>
                <td>{{ h.vitals.spo2 }}{{ h.vitals.scale2 ? '*' : '' }}</td>
                <td>{{ h.vitals.sbp }}</td>
                <td>{{ h.vitals.hr }}</td>
                <td>{{ h.vitals.temp }}</td>
                <td>{{ h.vitals.consciousness }}</td>
                <td><strong>{{ h.total }}</strong></td>
                <td>
                  <v-chip size="x-small" :color="riskOf(h.total).color" variant="tonal">
                    {{ riskOf(h.total).label }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </HomecarePanel>
      </v-col>

      <!-- ───────────── Score panel ───────────── -->
      <v-col cols="12" lg="5">
        <v-card rounded="xl" class="hc-score-card pa-5 mb-3" :elevation="0"
                :style="{ background: scoreGradient }">
          <div class="text-overline text-white-soft">TOTAL NEWS2 SCORE</div>
          <div class="d-flex align-center ga-3 mt-1">
            <div class="hc-score-num">{{ total }}</div>
            <div class="flex-grow-1">
              <v-chip color="white" variant="flat" class="font-weight-bold mb-1"
                      :class="`text-${riskHex.text}`">
                <v-icon :icon="risk.icon" size="16" class="mr-1" />
                {{ risk.label }}
              </v-chip>
              <div class="text-body-2 text-white">{{ risk.subtitle }}</div>
            </div>
          </div>
          <v-divider class="my-4" color="white" opacity="0.35" />
          <div class="text-body-2 text-white-soft mb-1">Recommended response</div>
          <div class="text-body-1 text-white font-weight-bold">{{ risk.action }}</div>
          <div class="d-flex flex-wrap ga-2 mt-3">
            <v-chip color="white" variant="outlined" size="small">
              <v-icon icon="mdi-clock-outline" size="14" class="mr-1" />
              Frequency: {{ risk.frequency }}
            </v-chip>
            <v-chip color="white" variant="outlined" size="small">
              <v-icon icon="mdi-account-tie" size="14" class="mr-1" />
              Reviewer: {{ risk.reviewer }}
            </v-chip>
          </div>
        </v-card>

        <HomecarePanel title="Parameter breakdown" icon="mdi-format-list-bulleted-square"
                       color="#0284c7">
          <div v-for="row in breakdown" :key="row.key"
               class="hc-row d-flex align-center pa-2 rounded-lg mb-1">
            <v-icon :icon="row.icon" :color="paramColor(row.score)" class="mr-3" />
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ row.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ row.value }}</div>
            </div>
            <v-chip size="small" :color="paramColor(row.score)" variant="tonal">
              +{{ row.score }}
            </v-chip>
          </div>

          <v-alert v-if="hasRedScore" type="warning" variant="tonal" density="compact"
                   icon="mdi-alert-octagram" class="mt-3">
            One parameter scored <strong>3</strong> — minimum hourly observation required.
          </v-alert>
        </HomecarePanel>

        <HomecarePanel title="NEWS2 thresholds" icon="mdi-traffic-light"
                       color="#475569" class="mt-3">
          <div v-for="t in thresholds" :key="t.label"
               class="d-flex align-center pa-2 rounded-lg mb-1"
               :style="{ background: t.bg }">
            <v-avatar size="32" :color="t.color" variant="flat" class="mr-3">
              <v-icon :icon="t.icon" color="white" size="16" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ t.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ t.range }}</div>
            </div>
            <v-chip size="x-small" variant="outlined" color="grey-darken-2">
              {{ t.frequency }}
            </v-chip>
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

const vitals = reactive({
  rr: 16, spo2: 97, scale2: false, oxygen: 'Room air',
  sbp: 120, hr: 78, temp: 36.6, consciousness: 'A'
})
const notes = ref('')
const recordedAt = ref(new Date().toISOString().slice(0, 16))
const patient = ref(null)
const patients = ref([])
const loadingPatients = ref(false)
const history = ref([])
const snack = reactive({ show: false, text: '', color: 'info' })

onMounted(async () => {
  loadingPatients.value = true
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 100 } })
    const items = data?.results || data || []
    patients.value = items.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'} · ${p.medical_record_number || ''}`
    }))
  } catch { /* ignore */ }
  finally { loadingPatients.value = false }
})

// ─────── NEWS2 scoring functions (RCP 2017) ───────
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
  // ≥93 with oxygen scores rising
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

const scores = computed(() => ({
  rr: scoreRR(vitals.rr),
  spo2: vitals.scale2
    ? scoreSpO2Scale2(vitals.spo2, vitals.oxygen === 'Supplemental O₂')
    : scoreSpO2Scale1(vitals.spo2),
  oxygen: scoreOxygen(vitals.oxygen),
  sbp: scoreSBP(vitals.sbp),
  hr: scoreHR(vitals.hr),
  temp: scoreTemp(vitals.temp),
  consciousness: scoreConsciousness(vitals.consciousness)
}))

const total = computed(() => Object.values(scores.value).reduce((a, b) => a + b, 0))
const hasRedScore = computed(() => Object.values(scores.value).some(s => s >= 3))

function riskOf(t) {
  if (t === 0) return {
    label: 'Low', color: 'success', icon: 'mdi-shield-check',
    subtitle: 'Patient is clinically stable.',
    action: 'Continue routine monitoring.',
    frequency: '12-hourly', reviewer: 'Nurse'
  }
  if (t <= 4) return {
    label: 'Low – Medium', color: 'info', icon: 'mdi-shield-half-full',
    subtitle: 'Mild physiological derangement.',
    action: 'Inform registered nurse; review and consider increasing observations.',
    frequency: '4–6 hourly', reviewer: 'Registered nurse'
  }
  if (t <= 6 || hasRedScore.value) return {
    label: 'Medium', color: 'warning', icon: 'mdi-alert',
    subtitle: 'Significant deterioration risk.',
    action: 'Urgent review by clinician within 1 hour. Consider escalation.',
    frequency: 'Hourly', reviewer: 'Doctor / clinical team lead'
  }
  return {
    label: 'High', color: 'error', icon: 'mdi-alert-octagram',
    subtitle: 'High risk of clinical deterioration.',
    action: 'Emergency assessment by critical care competent team. Continuous monitoring.',
    frequency: 'Continuous', reviewer: 'Critical care team'
  }
}
const risk = computed(() => riskOf(total.value))

const riskHex = computed(() => ({
  Low: { text: 'success-darken-2' },
  'Low – Medium': { text: 'info-darken-2' },
  Medium: { text: 'warning-darken-2' },
  High: { text: 'error-darken-2' }
}[risk.value.label] || { text: 'grey-darken-3' }))

const totalColor = computed(() => risk.value.color)
const scoreGradient = computed(() => {
  const map = {
    success: 'linear-gradient(135deg,#10b981 0%,#059669 100%)',
    info:    'linear-gradient(135deg,#0ea5e9 0%,#0284c7 100%)',
    warning: 'linear-gradient(135deg,#f59e0b 0%,#d97706 100%)',
    error:   'linear-gradient(135deg,#ef4444 0%,#b91c1c 100%)'
  }
  return map[risk.value.color] || map.info
})

const breakdown = computed(() => [
  { key: 'rr',  icon: 'mdi-lungs',         label: 'Respiratory rate',
    value: `${vitals.rr ?? '—'} /min`,            score: scores.value.rr },
  { key: 'spo2',icon: 'mdi-water-percent', label: `SpO₂ (Scale ${vitals.scale2 ? 2 : 1})`,
    value: `${vitals.spo2 ?? '—'} %`,             score: scores.value.spo2 },
  { key: 'o2',  icon: 'mdi-gas-cylinder',  label: 'Supplemental oxygen',
    value: vitals.oxygen,                          score: scores.value.oxygen },
  { key: 'sbp', icon: 'mdi-heart-pulse',   label: 'Systolic BP',
    value: `${vitals.sbp ?? '—'} mmHg`,           score: scores.value.sbp },
  { key: 'hr',  icon: 'mdi-heart',         label: 'Heart rate',
    value: `${vitals.hr ?? '—'} bpm`,             score: scores.value.hr },
  { key: 'temp',icon: 'mdi-thermometer',   label: 'Temperature',
    value: `${vitals.temp ?? '—'} °C`,            score: scores.value.temp },
  { key: 'avpu',icon: 'mdi-brain',         label: 'ACVPU consciousness',
    value: vitals.consciousness,                  score: scores.value.consciousness }
])

function paramColor(s) {
  if (s === 0) return 'success'
  if (s === 1) return 'info'
  if (s === 2) return 'warning'
  return 'error'
}

const thresholds = [
  { label: 'Low (0)',          range: '12-hourly observations',
    color: '#10b981', icon: 'mdi-shield-check', bg: 'rgba(16,185,129,0.07)',
    frequency: '12 h' },
  { label: 'Low–Medium (1–4)', range: 'Min 4–6 hourly; nurse review',
    color: '#0ea5e9', icon: 'mdi-shield-half-full', bg: 'rgba(14,165,233,0.07)',
    frequency: '4–6 h' },
  { label: 'Medium (5–6 or any 3)', range: 'Hourly; urgent clinician review',
    color: '#f59e0b', icon: 'mdi-alert', bg: 'rgba(245,158,11,0.08)',
    frequency: '1 h' },
  { label: 'High (≥ 7)',       range: 'Continuous; emergency team',
    color: '#ef4444', icon: 'mdi-alert-octagram', bg: 'rgba(239,68,68,0.08)',
    frequency: 'Cont.' }
]

function reset() {
  Object.assign(vitals, {
    rr: 16, spo2: 97, scale2: false, oxygen: 'Room air',
    sbp: 120, hr: 78, temp: 36.6, consciousness: 'A'
  })
  notes.value = ''
  recordedAt.value = new Date().toISOString().slice(0, 16)
}

function logScore() {
  history.value.unshift({
    time: new Date(recordedAt.value || Date.now()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    vitals: { ...vitals },
    total: total.value
  })
  snack.text = `Reading saved · NEWS2 = ${total.value}`
  snack.color = 'success'
  snack.show = true
}

function escalate() {
  snack.text = `Escalation alert sent · ${risk.value.label} (NEWS2 ${total.value})`
  snack.color = totalColor.value
  snack.show = true
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}

.hc-score-card {
  position: relative;
  overflow: hidden;
  color: white;
  box-shadow: 0 18px 40px -18px rgba(15,23,42,0.45);
}
.hc-score-num {
  font-size: 72px; line-height: 1; font-weight: 800;
  color: white;
  text-shadow: 0 4px 18px rgba(0,0,0,0.25);
  font-variant-numeric: tabular-nums;
}
.text-white-soft { color: rgba(255,255,255,0.82) !important; }

.hc-row {
  background: rgba(15,23,42,0.03);
}
:global(.v-theme--dark) .hc-row { background: rgba(255,255,255,0.04); }
</style>
