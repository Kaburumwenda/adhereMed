<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- ── Toolbar ──────────────────────────────────────────────── -->
    <PageHeader :title="consultation?.patient_name || 'Consultation'"
      :subtitle="consultation ? formatDateTime(consultation.created_at) : ''"
      icon="mdi-medical-bag" color="success">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/consultations`)">Back</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
          @click="navigateTo(`${ns}/consultations/${id}/edit`)">Edit</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-printer"
          @click="printPage">Print</v-btn>
      </template>
    </PageHeader>

    <!-- ── Loading state ────────────────────────────────────────── -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="success" size="48" />
    </div>

    <div v-else-if="!consultation" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-medical-bag</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Consultation not found</div>
      <v-btn color="success" rounded="lg" class="text-none mt-3"
        @click="navigateTo(`${ns}/consultations`)">Back to Consultations</v-btn>
    </div>

    <template v-else>
      <!-- ═══ Status banner ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="con-banner pa-5 mb-4">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar :color="statusInfo.color + '-lighten-5'" size="64" class="mr-2">
            <v-icon :color="statusInfo.color + '-darken-2'" size="36">{{ statusInfo.icon }}</v-icon>
          </v-avatar>
          <div class="flex-grow-1" style="min-width: 220px;">
            <div class="text-h5 font-weight-bold">{{ consultation.patient_name || '—' }}</div>
            <div class="d-flex flex-wrap align-center ga-2 text-body-2 text-medium-emphasis mt-1">
              <v-icon size="16">mdi-doctor</v-icon>
              {{ consultation.doctor_name || '—' }}
              <v-icon size="16" class="ml-1">mdi-calendar</v-icon>
              {{ formatDateTime(consultation.created_at) }}
              <v-chip size="small" variant="tonal" :color="statusInfo.color"
                class="text-capitalize font-weight-medium ml-2">
                {{ statusInfo.label }}
              </v-chip>
            </div>
          </div>
        </div>
      </v-card>

      <!-- ═══ Linked records ═══════════════════════════════════════ -->
      <v-row dense class="mb-4">
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="indigo-lighten-5" size="32" class="mr-2">
                <v-icon color="indigo-darken-2" size="20">mdi-account</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Patient</div>
            </div>
            <DetailField label="Name" :value="consultation.patient_name" />
            <v-btn v-if="consultation.patient" size="small" variant="tonal" color="indigo"
              rounded="lg" class="text-none mt-2"
              prepend-icon="mdi-account-details"
              @click="navigateTo(`${ns}/patients/${consultation.patient}`)">
              View Patient
            </v-btn>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="teal-lighten-5" size="32" class="mr-2">
                <v-icon color="teal-darken-2" size="20">mdi-calendar-clock</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Appointment</div>
            </div>
            <DetailField label="Appointment ID" :value="consultation.appointment ? String(consultation.appointment) : ''" :mono="true" />
            <v-btn v-if="consultation.appointment" size="small" variant="tonal" color="teal"
              rounded="lg" class="text-none mt-2"
              prepend-icon="mdi-calendar-clock"
              @click="navigateTo(`${ns}/appointments/${consultation.appointment}`)">
              View Appointment
            </v-btn>
            <div v-else class="text-body-2 text-medium-emphasis mt-1">No linked appointment</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- ═══ Tabbed content ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="tab-card">
        <v-tabs v-model="tab" color="success" density="comfortable" show-arrows>
          <v-tab value="overview" class="text-none">Overview</v-tab>
          <v-tab value="vitals" class="text-none">Vitals</v-tab>
          <v-tab value="diagnosis" class="text-none">Diagnosis &amp; Treatment</v-tab>
          <v-tab value="notes" class="text-none">Notes</v-tab>
        </v-tabs>

        <v-divider />

        <v-window v-model="tab" class="pa-4 pa-md-5">
          <!-- ── Overview tab ─────────────────────────────────────── -->
          <v-window-item value="overview">
            <v-row dense>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Consultation Info</div>
                <DetailField label="Patient" :value="consultation.patient_name" />
                <DetailField label="Doctor" :value="consultation.doctor_name" />
                <DetailField label="Date" :value="formatDateTime(consultation.created_at)" />
                <DetailField label="Status" :value="statusInfo.label" :capitalize="true" />
                <DetailField label="Consultation Date" :value="formatDate(vital_signs.consultation_date)" />
              </v-col>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Chief Complaint</div>
                <div class="text-body-1 pa-3 rounded-lg info-card">
                  {{ consultation.chief_complaint || '—' }}
                </div>
                <div class="section-title mb-3 mt-4">History of Present Illness</div>
                <div class="text-body-2 pa-3 rounded-lg info-card">
                  {{ consultation.history_present_illness || '—' }}
                </div>
                <div class="section-title mb-3 mt-4">Examination Findings</div>
                <div class="text-body-2 pa-3 rounded-lg info-card">
                  {{ consultation.examination_findings || '—' }}
                </div>
              </v-col>
            </v-row>
          </v-window-item>

          <!-- ── Vitals tab ───────────────────────────────────────── -->
          <v-window-item value="vitals">
            <v-row dense>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">Temperature</div>
                  <div class="text-h6 font-weight-bold">
                    {{ vital_signs.temperature != null ? vital_signs.temperature + ' °C' : '—' }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">Blood Pressure</div>
                  <div class="text-h6 font-weight-bold">
                    {{ bpLabel }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">Heart Rate</div>
                  <div class="text-h6 font-weight-bold">
                    {{ vital_signs.heart_rate != null ? vital_signs.heart_rate + ' bpm' : '—' }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">Resp Rate</div>
                  <div class="text-h6 font-weight-bold">
                    {{ vital_signs.respiratory_rate != null ? vital_signs.respiratory_rate : '—' }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">SpO₂</div>
                  <div class="text-h6 font-weight-bold">
                    {{ vital_signs.oxygen_saturation != null ? vital_signs.oxygen_saturation + ' %' : '—' }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">Weight</div>
                  <div class="text-h6 font-weight-bold">
                    {{ vital_signs.weight != null ? vital_signs.weight + ' kg' : '—' }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100">
                  <div class="text-overline text-medium-emphasis">Height</div>
                  <div class="text-h6 font-weight-bold">
                    {{ vital_signs.height != null ? vital_signs.height + ' cm' : '—' }}
                  </div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card flat rounded="lg" class="vital-card pa-4 h-100" :color="bmiVariant">
                  <div class="text-overline text-medium-emphasis">BMI</div>
                  <div class="text-h6 font-weight-bold">
                    {{ bmi ?? '—' }}
                  </div>
                  <div v-if="bmi" class="text-caption text-medium-emphasis">{{ bmiCategory }}</div>
                </v-card>
              </v-col>
            </v-row>
          </v-window-item>

          <!-- ── Diagnosis & Treatment tab ───────────────────────── -->
          <v-window-item value="diagnosis">
            <div class="section-title mb-3">Diagnosis</div>
            <div class="text-body-1 pa-3 rounded-lg info-card mb-4">
              {{ diagnosisText || '—' }}
            </div>
            <div class="section-title mb-3">Treatment Plan</div>
            <div class="text-body-1 pa-3 rounded-lg info-card mb-4">
              {{ consultation.treatment_plan || '—' }}
            </div>
            <div class="section-title mb-3">Prescription Notes</div>
            <div class="text-body-2 pa-3 rounded-lg info-card mb-4">
              {{ vital_signs.prescription_notes || '—' }}
            </div>
            <div class="section-title mb-3">Follow-up</div>
            <div class="text-body-2 pa-3 rounded-lg info-card">
              <span v-if="vital_signs.follow_up_date">
                <v-icon size="16" class="mr-1">mdi-calendar-refresh</v-icon>
                {{ formatDate(vital_signs.follow_up_date) }}
              </span>
              <span v-else class="text-medium-emphasis">No follow-up scheduled</span>
            </div>
          </v-window-item>

          <!-- ── Notes tab ────────────────────────────────────────── -->
          <v-window-item value="notes">
            <div class="section-title mb-3">General Notes</div>
            <div class="text-body-1 pa-3 rounded-lg info-card" style="white-space: pre-wrap;">
              {{ consultation.notes || '—' }}
            </div>
            <div class="section-title mb-3 mt-4">Metadata</div>
            <DetailField label="Created" :value="formatDateTime(consultation.created_at)" />
            <DetailField label="Updated" :value="formatDateTime(consultation.updated_at)" />
          </v-window-item>
        </v-window>
      </v-card>
    </template>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()

const r = useResource('/consultations/')

const id = computed(() => route.params.id)
const consultation = ref(null)
const loading = ref(false)
const tab = ref('overview')

const vital_signs = computed(() => consultation.value?.vital_signs || {})

const statusInfo = computed(() => {
  const s = vital_signs.value.status || 'completed'
  const map = {
    draft: { color: 'grey', icon: 'mdi-pencil-outline', label: 'Draft' },
    completed: { color: 'success', icon: 'mdi-check-circle', label: 'Completed' },
    pending: { color: 'warning', icon: 'mdi-clock-outline', label: 'Pending' },
    in_progress: { color: 'info', icon: 'mdi-progress-clock', label: 'In Progress' },
  }
  return map[s] || { color: 'grey', icon: 'mdi-circle-medium', label: s }
})

const bpLabel = computed(() => {
  const v = vital_signs.value
  if (v.blood_pressure_systolic != null && v.blood_pressure_diastolic != null) {
    return `${v.blood_pressure_systolic}/${v.blood_pressure_diastolic}`
  }
  return '—'
})

const bmi = computed(() => {
  const v = vital_signs.value
  if (v.weight && v.height) {
    const m = v.height / 100
    if (m > 0) {
      const val = v.weight / (m * m)
      return Math.round(val * 10) / 10
    }
  }
  return null
})

const bmiCategory = computed(() => {
  const b = bmi.value
  if (b == null) return ''
  if (b < 18.5) return 'Underweight'
  if (b < 25) return 'Normal'
  if (b < 30) return 'Overweight'
  return 'Obese'
})

const bmiVariant = computed(() => {
  const b = bmi.value
  if (b == null) return ''
  if (b < 18.5) return 'warning-lighten-5'
  if (b < 25) return 'success-lighten-5'
  if (b < 30) return 'warning-lighten-5'
  return 'error-lighten-5'
})

const diagnosisText = computed(() => {
  const d = consultation.value?.diagnosis
  if (!d) return ''
  if (Array.isArray(d)) return d.map(x => typeof x === 'string' ? x : x.description || x.code || '').filter(Boolean).join('; ')
  if (typeof d === 'object') return d.description || d.code || JSON.stringify(d)
  return String(d)
})

// ── Load consultation on mount ─────────────────────────────────────
onMounted(async () => {
  loading.value = true
  try {
    const data = await r.get(id.value)
    consultation.value = data
  } catch {
    // error reflected by r.error
  } finally {
    loading.value = false
  }
})

function printPage() {
  window.print()
}
</script>

<style scoped>
.con-banner { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.info-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); background: rgba(var(--v-theme-on-surface), 0.02); }
.tab-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.vital-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.section-title {
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
</style>
