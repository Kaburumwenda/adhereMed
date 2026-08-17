<template>
  <v-container fluid class="triage-workspace pa-0">
    <!-- ── Allergy Banner (persistent, always visible) ── -->
    <div v-if="allergyBanner" class="allergy-banner d-flex align-center px-4 px-md-6 py-2">
      <v-icon color="white" class="mr-2" size="20">mdi-alert-circle</v-icon>
      <span class="text-body-2 font-weight-bold text-white">{{ allergyBanner }}</span>
    </div>

    <!-- ── Top Action Bar ── -->
    <div class="d-flex align-center justify-space-between px-4 px-md-6 py-3 border-b">
      <div class="d-flex align-center ga-2">
        <v-btn icon variant="text" to="/clinics/triage"><v-icon>mdi-arrow-left</v-icon></v-btn>
        <div>
          <div class="text-h6 font-weight-bold">{{ patientName || 'Triage Workspace' }}</div>
          <div v-if="triageId" class="text-caption text-medium-emphasis">Triage #{{ triageId }} · Draft</div>
        </div>
      </div>
      <div class="d-flex align-center ga-3">
        <!-- Wait-time timer -->
        <div class="wait-time-chip d-flex align-center ga-1 px-3 py-1 rounded-lg" :class="waitTimeClass">
          <v-icon size="16" :color="waitTimeColor">mdi-timer-sand</v-icon>
          <span class="text-body-2 font-weight-bold" :class="waitTextColor">{{ waitTimeLabel }}</span>
        </div>
        <!-- NEWS2 live badge -->
        <v-chip :color="news2Color(news2Score)" variant="flat" size="large" class="font-weight-bold">
          <v-icon start size="18">mdi-heart-pulse</v-icon>
          NEWS2: {{ news2Score }}
        </v-chip>
        <v-chip :color="esiColor(form.esi_level)" variant="tonal" size="large" class="font-weight-bold">
          ESI {{ form.esi_level || '?' }}
        </v-chip>
        <v-chip v-if="bmi" color="info" variant="tonal" class="font-weight-bold">
          BMI: {{ bmi }}
        </v-chip>
        <v-spacer class="d-none d-md-block" />
        <!-- Save status badge -->
        <v-chip v-if="lastSave" size="small" variant="text" prepend-icon="mdi-content-save-check">
          <span class="text-caption text-medium-emphasis">Saved {{ lastSave }}</span>
        </v-chip>
        <v-divider vertical class="mx-1" />
        <v-btn variant="outlined" rounded="lg" :loading="saving" @click="saveDraft">
          <v-icon start>mdi-content-save-outline</v-icon>Save Draft
        </v-btn>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-check-circle" :disabled="!canComplete" :loading="saving" @click="completeTriage">Complete Triage</v-btn>
      </div>
    </div>

    <div class="scroll-container px-4 px-md-6 py-4">
      <!-- ── Patient Context Strip ── -->
      <v-card v-if="patient" rounded="lg" variant="outlined" class="mb-4 pa-3 patient-strip">
        <div class="d-flex align-center flex-wrap ga-3">
          <v-avatar
            :color="patient.gender === 'female' ? 'pink-lighten-4' : 'blue-lighten-4'"
            variant="tonal" size="48"
          >
            <span class="text-h6 font-weight-bold">{{ (patientName || '?').charAt(0) }}</span>
          </v-avatar>
          <div class="flex-grow-1">
            <div class="font-weight-bold text-subtitle-1">{{ patientName }}</div>
            <div class="text-caption text-medium-emphasis">
              <v-icon size="12" class="mr-1">{{ patient.gender === 'female' ? 'mdi-gender-female' : 'mdi-gender-male' }}</v-icon>
              {{ patient.gender || '—' }} · {{ patientAge }}
              <span v-if="patient.blood_type" class="ml-1">· {{ patient.blood_type }}</span>
              <span v-if="patient.patient_number" class="ml-1">· {{ patient.patient_number }}</span>
            </div>
          </div>
          <div class="d-flex ga-2 flex-wrap">
            <v-chip v-if="patient.allergies?.length" color="error" size="small" variant="tonal" prepend-icon="mdi-alert">
              {{ patient.allergies.length }} Allergie(s)
            </v-chip>
            <v-chip v-if="patient.chronic_conditions?.length" color="warning" size="small" variant="tonal" prepend-icon="mdi-heart">
              {{ patient.chronic_conditions.length }} Chronic Condition(s)
            </v-chip>
            <v-chip v-if="activeMeds.length" color="info" size="small" variant="tonal" prepend-icon="mdi-pill">
              {{ activeMeds.length }} Active Medication(s)
            </v-chip>
          </div>
        </div>
      </v-card>

      <!-- Abnormal Vitals Alert -->
      <v-alert v-if="abnormalVitals.length" type="error" variant="tonal" dense class="mb-4" prepend-icon="mdi-alert">
        <span class="font-weight-bold">Abnormal vitals detected: </span>
        <span>{{ abnormalVitals.join(', ') }}</span>
      </v-alert>

      <!-- ── Section: Chief Complaint ── -->
      <SectionCard icon="mdi-format-text" title="Chief Complaint" color="primary" :expanded="true">
        <v-text-field v-model="form.chief_complaint" placeholder="Patient's primary complaint in their own words…" variant="outlined" density="compact" hide-details />
        <div class="d-flex align-center ga-3 mt-3 flex-wrap">
          <v-select v-model="form.arrival_mode" :items="arrivalModes" label="Arrival Mode" variant="outlined" density="compact" hide-details style="max-width: 200px" />
          <div class="d-flex align-center ga-1">
            <span class="text-caption text-medium-emphasis">Pain Score:</span>
            <v-rating v-model="form.pain_scale" length="10" color="error" hover size="x-small" />
            <span class="text-body-2 font-weight-bold">{{ form.pain_scale }}/10</span>
          </div>
        </div>
      </SectionCard>

      <!-- ── Section: Vitals & NEWS2 ── -->
      <SectionCard icon="mdi-heart-pulse" title="Vital Signs" color="error" :expanded="true">
        <div class="vitals-grid">
          <VitalInput v-model="form.vital_signs.temperature" label="Temperature" unit="°C" :normal="[36.1, 38]" :step="0.1" />
          <VitalInput v-model="form.vital_signs.bp_systolic" label="BP Systolic" unit="mmHg" :normal="[110, 140]" />
          <VitalInput v-model="form.vital_signs.bp_diastolic" label="BP Diastolic" unit="mmHg" :normal="[70, 90]" />
          <VitalInput v-model="form.vital_signs.heart_rate" label="Pulse" unit="bpm" :normal="[60, 100]" />
          <VitalInput v-model="form.vital_signs.respiratory_rate" label="Resp Rate" unit="/min" :normal="[12, 20]" />
          <VitalInput v-model="form.vital_signs.oxygen_saturation" label="SpO2" unit="%" :normal="[95, 100]" />
          <VitalInput v-model="form.vital_signs.blood_sugar" label="Blood Sugar" unit="mmol/L" :normal="[4, 7]" :step="0.1" />
          <VitalInput v-model="form.vital_signs.weight" label="Weight" unit="kg" :normal="[0, 0]" @update:model-value="updateBMI" />
          <VitalInput v-model="form.vital_signs.height" label="Height" unit="cm" :normal="[0, 0]" @update:model-value="updateBMI" />
        </div>

        <!-- AVPU -->
        <div class="d-flex align-center ga-2 mt-3">
          <span class="text-body-2 font-weight-bold mr-2">Consciousness:</span>
          <v-btn-toggle v-model="form.avpu" mandatory density="compact" rounded="lg" color="primary">
            <v-btn v-for="a in avpuOptions" :key="a.value" :value="a.value" size="small" variant="outlined">{{ a.label }}</v-btn>
          </v-btn-toggle>
        </div>

        <!-- BMI + NEWS2 display -->
        <div class="d-flex align-center ga-3 mt-3 flex-wrap">
          <v-chip v-if="bmi" :color="bmiCategory(bmi)?.color" variant="tonal" size="large">
            BMI: {{ bmi }} ({{ bmiCategory(bmi)?.label }})
          </v-chip>
          <v-chip :color="news2Color(news2Score)" variant="flat" size="large" class="font-weight-bold">
            NEWS2 Score: {{ news2Score }} → {{ news2Cat.label }}
          </v-chip>
        </div>
      </SectionCard>

      <!-- ── Section: ESI Assignment ── -->
      <SectionCard icon="mdi-clipboard-pulse" title="ESI Level Assignment" color="warning" :expanded="true">
        <div class="d-flex align-center flex-wrap ga-3">
          <div class="d-flex align-center ga-1">
            <span class="text-caption text-medium-emphasis mr-2">System Suggests:</span>
            <v-chip :color="esiColor(suggestedESI)" variant="tonal" size="large">ESI {{ suggestedESI }}</v-chip>
          </div>
          <v-divider vertical class="mx-2" />
          <span class="text-caption text-medium-emphasis">Nurse Assignment:</span>
          <v-btn-toggle v-model="form.esi_level" mandatory density="compact" rounded="lg" color="primary">
            <v-btn v-for="e in 5" :key="e" :value="e" size="small" variant="outlined" :color="esiColor(e)">
              <span class="font-weight-bold">{{ e }}</span>
            </v-btn>
          </v-btn-toggle>
        </div>
        <v-alert v-if="showOverrideWarning" type="warning" variant="tonal" density="compact" class="mt-3">
          <div class="d-flex align-center ga-2">
            <v-icon>mdi-alert-outline</v-icon>
            <span>You are overriding the system suggestion of ESI {{ suggestedESI }}. Please document the reason:</span>
          </div>
          <v-text-field v-model="form.esi_override_reason" placeholder="Reason for override…" variant="outlined" density="compact" hide-details class="mt-2" />
          <v-btn v-if="!overrideConfirmed" color="warning" size="small" class="mt-2" @click="overrideConfirmed = true">Confirm Override</v-btn>
          <v-chip v-else color="success" size="small" class="mt-2" variant="tonal">Override confirmed</v-chip>
        </v-alert>
      </SectionCard>

      <!-- ── Section: Doctor Assignment ── -->
      <SectionCard icon="mdi-doctor" title="Doctor Assignment" color="blue-darken-2" :expanded="true">
        <v-row dense align="center">
          <v-col cols="12" md="7">
            <v-autocomplete
              v-model="form.doctor"
              :items="doctors"
              item-value="id"
              item-title="full_name"
              label="Assign to doctor"
              placeholder="Select a doctor to receive this patient…"
              variant="outlined"
              density="compact"
              clearable
              hide-details
              :loading="doctorsLoading"
              prepend-inner-icon="mdi-account-plus"
            >
              <template #item="{ item, props }">
                <v-list-item v-bind="props">
                  <template #append>
                    <v-chip size="x-small" variant="tonal" color="grey">{{ item.raw.role }}</v-chip>
                  </template>
                </v-list-item>
              </template>
              <template #selection="{ item }">
                <v-icon size="18" class="mr-2" color="blue-darken-2">mdi-doctor</v-icon>
                <span class="font-weight-bold">{{ item.raw.full_name }}</span>
                <v-chip size="x-small" variant="tonal" color="grey" class="ml-2">{{ item.raw.role }}</v-chip>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" md="5" class="d-flex align-center ga-2">
            <v-chip v-if="form.doctor" color="blue-darken-2" variant="tonal" size="large" prepend-icon="mdi-account-check">
              Assigned: {{ assignedDoctorName }}
            </v-chip>
            <v-chip v-else color="grey" variant="tonal" size="large" prepend-icon="mdi-account-clock">
              Unassigned
            </v-chip>
          </v-col>
        </v-row>

        <v-alert v-if="form.doctor" type="info" variant="tonal" density="compact" class="mt-3">
          <div class="d-flex align-center flex-wrap ga-2">
            <v-icon>mdi-stethoscope</v-icon>
            <span class="font-weight-bold">Patient will be routed to {{ assignedDoctorName }} after completing triage.</span>
            <v-spacer />
            <v-btn
              color="primary"
              size="small"
              variant="tonal"
              prepend-icon="mdi-clipboard-text-play"
              :loading="startingConsult"
              :disabled="!canComplete"
              @click="startConsultation"
            >
              Start Consultation
            </v-btn>
          </div>
        </v-alert>

        <div v-else class="text-caption text-medium-emphasis mt-2 d-flex align-center">
          <v-icon size="14" class="mr-1">mdi-information-outline</v-icon>
          Assigning a doctor is optional but recommended to expedite the patient's handoff to a clinician.
        </div>
      </SectionCard>

      <!-- ── Section: Allergies & Medication History ── -->
      <SectionCard icon="mdi-pill" title="Allergies & Medication Reconciliation" color="purple" :expanded="true">
        <div class="mb-3">
          <div class="d-flex align-center justify-space-between mb-2">
            <span class="text-body-2 font-weight-bold">Allergies (confirm/update)</span>
            <v-btn size="small" variant="text" prepend-icon="mdi-plus" @click="addAllergy">Add</v-btn>
          </div>
          <div v-if="form.allergies_updated.length || patient?.allergies?.length" class="d-flex flex-wrap ga-2">
            <v-chip v-for="(a, i) in form.allergies_updated" :key="i" color="error" variant="tonal" closable @click:close="form.allergies_updated.splice(i, 1)">
              {{ a }}
            </v-chip>
          </div>
          <div v-else class="text-body-2 text-medium-emphasis">No allergies documented</div>
          <v-checkbox v-model="form.allergies_confirmed" label="Allergies confirmed with patient" density="compact" hide-details color="primary" class="mt-2" />
        </div>
        <v-divider class="my-3" />
        <div>
          <div class="d-flex align-center justify-space-between mb-2">
            <span class="text-body-2 font-weight-bold">Medication History</span>
            <v-btn size="small" variant="text" prepend-icon="mdi-plus" @click="addMed">Add</v-btn>
          </div>
          <div v-for="(m, i) in form.medication_history" :key="i" class="d-flex align-center ga-2 mb-2">
            <v-text-field v-model="m.name" placeholder="Drug name" variant="outlined" density="compact" hide-details />
            <v-text-field v-model="m.dose" placeholder="Dose" variant="outlined" density="compact" hide-details style="max-width: 120px" />
            <v-text-field v-model="m.frequency" placeholder="Freq" variant="outlined" density="compact" hide-details style="max-width: 120px" />
            <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="form.medication_history.splice(i, 1)" />
          </div>
        </div>
      </SectionCard>

      <!-- ── Section: Screening ── -->
      <SectionCard icon="mdi-clipboard-search" title="Screening" color="teal" :expanded="false">
        <v-row dense>
          <v-col cols="12" md="6"><v-select v-model="form.smoking_status" :items="['never','former','current']" label="Smoking Status" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" md="6"><v-select v-model="form.alcohol_use" :items="['none','occasional','moderate','heavy']" label="Alcohol Use" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="form.pregnancy_status" label="Pregnancy Status (if applicable)" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="form.fall_risk" label="Fall Risk Assessment" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="form.substance_use" label="Substance Use" variant="outlined" density="compact" /></v-col>
        </v-row>
      </SectionCard>

      <!-- ── Section: Nursing Assessment ── -->
      <SectionCard icon="mdi-notebook" title="Nursing Assessment & Interventions" color="indigo" :expanded="false">
        <v-textarea v-model="form.nursing_assessment" label="Initial Nursing Assessment" variant="outlined" density="compact" rows="3" class="mb-3" />
        <v-textarea v-model="form.interventions" label="Interventions Given" variant="outlined" density="compact" rows="2" class="mb-3" />
        <v-textarea v-model="form.patient_education" label="Patient Education Provided" variant="outlined" density="compact" rows="2" />
      </SectionCard>

      <!-- ── Section: Notes ── -->
      <SectionCard icon="mdi-note-edit" title="Additional Notes" color="grey-darken-1" :expanded="false">
        <v-textarea v-model="form.notes" label="Notes" variant="outlined" density="compact" rows="3" />
      </SectionCard>
    </div>
  </v-container>
</template>

<script setup>
import { calculateNEWS2, news2Category, news2Color, suggestedESIFromNEWS2, calculateBMI, bmiCategory, esiColor } from '~/composables/useClinicalScoring'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()

const triageId = computed(() => route.params.id)
const patientId = computed(() => route.query.patient)
const patient = ref(null)
const activeMeds = ref([])
const doctors = ref([])
const doctorsLoading = ref(false)
const startingConsult = ref(false)
const saving = ref(false)
const overrideConfirmed = ref(false)
const lastSave = ref('')
const now = ref(Date.now())

// Live ticking clock for wait-time
let clockTimer = null
onMounted(() => { clockTimer = setInterval(() => { now.value = Date.now() }, 1000) })
onUnmounted(() => { if (clockTimer) clearInterval(clockTimer) })

// Wait-time computed
const triageStartTime = ref(null)
const waitMinutes = computed(() => {
  if (!triageStartTime.value) return 0
  return Math.floor((now.value - new Date(triageStartTime.value).getTime()) / 60000)
})
const waitTimeLabel = computed(() => {
  const mins = waitMinutes.value
  if (mins < 60) return `${mins}m in triage`
  const hrs = Math.floor(mins / 60)
  return `${hrs}h ${mins % 60}m in triage`
})
const waitTimeColor = computed(() => {
  const m = waitMinutes.value
  if (m > 30) return 'error'
  if (m > 15) return 'warning'
  return 'success'
})
const waitTextColor = computed(() => {
  const c = waitTimeColor.value
  return { success: 'text-success', warning: 'text-warning', error: 'text-error' }[c]
})
const waitTimeClass = computed(() => {
  const c = waitTimeColor.value
  return { success: 'wait-success', warning: 'wait-warning', error: 'wait-error' }[c]
})

const form = reactive({
  patient: null,
  nurse: null,
  chief_complaint: '',
  arrival_mode: 'walk_in',
  pain_scale: 0,
  avpu: 'alert',
  esi_level: null,
  suggested_esi: null,
  esi_override_reason: '',
  vital_signs: { temperature: null, bp_systolic: null, bp_diastolic: null, heart_rate: null, respiratory_rate: null, oxygen_saturation: null, blood_sugar: null, weight: null, height: null },
  allergies_confirmed: false,
  allergies_updated: [],
  medication_history: [],
  pregnancy_status: '',
  smoking_status: '',
  alcohol_use: '',
  substance_use: '',
  fall_risk: '',
  nursing_assessment: '',
  interventions: '',
  patient_education: '',
  notes: '',
  status: 'draft',
  news2_score: 0,
  bmi: null,
  doctor: null,
})

const arrivalModes = [
  { title: 'Walk-in', value: 'walk_in' },
  { title: 'Ambulance', value: 'ambulance' },
  { title: 'Referral', value: 'referral' },
  { title: 'Police', value: 'police' },
]
const avpuOptions = [
  { label: 'Alert', value: 'alert' },
  { label: 'Voice', value: 'voice' },
  { label: 'Pain', value: 'pain' },
  { label: 'Unresponsive', value: 'unresponsive' },
]

// Auto-save (debounced)
let saveTimer = null
let firstLoad = true
watch(form, () => {
  if (firstLoad) { firstLoad = false; return }
  if (saveTimer) clearTimeout(saveTimer)
  saveTimer = setTimeout(autoSave, 5000)
}, { deep: true, flush: 'post' })

async function autoSave() {
  if (!triageId.value || triageId.value === 'new') return
  try {
    const payload = { ...form, news2_score: news2Score.value, suggested_esi: suggestedESI.value, bmi: bmi.value }
    await $api.patch(`/triage/${triageId.value}/`, payload)
    lastSave.value = 'just now'
    setTimeout(() => { if (lastSave.value === 'just now') lastSave.value = '10s ago' }, 10000)
    setTimeout(() => { if (lastSave.value === '10s ago') lastSave.value = '20s ago' }, 20000)
    setTimeout(() => { if (lastSave.value === '20s ago') lastSave.value = '30s ago' }, 30000)
    setTimeout(() => { if (lastSave.value === '30s ago') lastSave.value = '1m ago' }, 60000)
  } catch (e) { console.error('Auto-save failed', e) }
}

// Computed
const news2Score = computed(() => calculateNEWS2(form.vital_signs))
const news2Cat = computed(() => news2Category(news2Score.value))
const suggestedESI = computed(() => suggestedESIFromNEWS2(news2Score.value))
const bmi = computed(() => {
  if (form.bmi) return form.bmi
  return calculateBMI(form.vital_signs.weight, form.vital_signs.height)
})
const patientName = computed(() => patient.value ? `${patient.value.user?.first_name || ''} ${patient.value.user?.last_name || ''}`.trim() || patient.value.user_name || '' : '')
const patientAge = computed(() => {
  if (!patient.value?.date_of_birth) return '—'
  const d = new Date(patient.value.date_of_birth)
  return `${Math.floor((Date.now() - d) / 315576000000)}y`
})

const allergyBanner = computed(() => {
  const a = form.allergies_updated?.length ? form.allergies_updated : patient.value?.allergies
  if (!a?.length) return ''
  return `⚠ ALLERGIES: ${a.join(', ')}`
})

const abnormalVitals = computed(() => {
  const v = form.vital_signs
  const ab = []
  if (v.temperature && (v.temperature < 35 || v.temperature > 38.5)) ab.push('Temperature')
  if (v.bp_systolic && (v.bp_systolic < 90 || v.bp_systolic > 180)) ab.push('Systolic BP')
  if (v.heart_rate && (v.heart_rate < 50 || v.heart_rate > 120)) ab.push('Pulse')
  if (v.respiratory_rate && (v.respiratory_rate < 10 || v.respiratory_rate > 25)) ab.push('Resp Rate')
  if (v.oxygen_saturation && v.oxygen_saturation < 92) ab.push('SpO2')
  return ab
})

const showOverrideWarning = computed(() => {
  if (!form.esi_level || !suggestedESI.value) return false
  return form.esi_level > suggestedESI.value && !overrideConfirmed.value
})

const canComplete = computed(() => {
  return form.chief_complaint &&
    form.vital_signs.temperature &&
    form.vital_signs.heart_rate &&
    form.esi_level &&
    form.allergies_confirmed &&
    (!showOverrideWarning.value || overrideConfirmed.value)
})

// Methods
function updateBMI() {
  form.bmi = calculateBMI(form.vital_signs.weight, form.vital_signs.height)
}

function addAllergy() {
  const val = prompt('Allergy:')
  if (val) form.allergies_updated.push(val)
}
function addMed() {
  form.medication_history.push({ name: '', dose: '', frequency: '' })
}

const assignedDoctorName = computed(() => {
  if (!form.doctor) return ''
  const d = doctors.value.find(x => x.id === form.doctor)
  return d ? d.full_name : (form.doctor_name || '')
})

async function saveDraft() {
  saving.value = true
  try {
    const payload = { ...form, news2_score: news2Score.value, suggested_esi: suggestedESI.value, bmi: bmi.value }
    if (triageId.value && triageId.value !== 'new') {
      await $api.patch(`/triage/${triageId.value}/`, payload)
    } else {
      const { data } = await $api.post('/triage/', payload)
      router.replace(`/clinics/triage/workspace/${data.id}`)
    }
  } catch (e) {
    console.error('Save draft failed', e)
  } finally { saving.value = false }
}

async function completeTriage() {
  saving.value = true
  try {
    const payload = { ...form, news2_score: news2Score.value, suggested_esi: suggestedESI.value, bmi: bmi.value, status: 'completed' }
    if (triageId.value && triageId.value !== 'new') {
      await $api.patch(`/triage/${triageId.value}/complete/`, payload)
      router.push('/clinics/triage')
    } else {
      const { data } = await $api.post('/triage/', payload)
      await $api.patch(`/triage/${data.id}/complete/`, payload)
      router.push('/clinics/triage')
    }
  } catch (e) {
    console.error('Complete triage failed', e)
  } finally { saving.value = false }
}

async function startConsultation() {
  if (!form.doctor) return
  startingConsult.value = true
  try {
    // Save the triage draft first so the assigned doctor is persisted
    const payload = { ...form, news2_score: news2Score.value, suggested_esi: suggestedESI.value, bmi: bmi.value }
    if (triageId.value && triageId.value !== 'new') {
      await $api.patch(`/triage/${triageId.value}/`, payload)
    }
    // Check for an existing consultation linked to this triage
    const { data } = await $api.get('/consultations/', { params: { triage: triageId.value, page_size: 1 } })
    if (data.results?.length) {
      router.push(`/clinics/consultations/workspace/${data.results[0].id}`)
    } else {
      const { data: consult } = await $api.post('/consultations/', {
        patient: form.patient,
        triage: Number(triageId.value),
        doctor: form.doctor,
        chief_complaint: form.chief_complaint || '',
        vital_signs: form.vital_signs,
        status: 'draft',
      })
      router.push(`/clinics/consultations/workspace/${consult.id}`)
    }
  } catch (e) {
    console.error('Failed to start consultation', e)
  } finally { startingConsult.value = false }
}

// Load data
onMounted(async () => {
  if (patientId.value) form.patient = Number(patientId.value)
  if (triageId.value && triageId.value !== 'new') {
    try {
      const { data } = await $api.get(`/triage/${triageId.value}/`)
      Object.assign(form, data)
      if (data.vital_signs) Object.assign(form.vital_signs, data.vital_signs)
      if (data.triage_time) triageStartTime.value = data.triage_time
    } catch (e) { console.error('Failed to load triage', e) }
  }
  if (form.patient) {
    try {
      const { data } = await $api.get(`/patients/${form.patient}/`)
      patient.value = data
      if (!form.allergies_updated.length && data.allergies) form.allergies_updated = [...data.allergies]
    } catch (e) { console.error('Failed to load patient', e) }
    // Load active medications
    try {
      const { data } = await $api.get('/prescriptions/', { params: { patient: form.patient, page_size: 100 } })
      activeMeds.value = data.results?.filter(p => p.status === 'active' || p.status === 'sent_to_exchange') || []
      if (!form.medication_history.length) {
        form.medication_history = activeMeds.value.map(p => ({ name: p.items?.[0]?.medication_name || '—', dose: p.items?.[0]?.dosage || '', frequency: p.items?.[0]?.frequency || '' }))
      }
    } catch {}
  }

  // Load available doctors/staff (this clinic tenant only — django_tenants
  // scopes the query to the current tenant's schema automatically)
  try {
    doctorsLoading.value = true
    const { data } = await $api.get('/auth/staff/', {
      params: { roles: 'doctor,clinical_officer,dentist,midwife', page_size: 1000 }
    })
    doctors.value = data.results || []
  } catch (e) {
    console.error('Failed to load doctors', e)
  } finally {
    doctorsLoading.value = false
  }
})
</script>

<style scoped>
.triage-workspace { height: 100vh; display: flex; flex-direction: column; background: rgb(var(--v-theme-surface)); }
.allergy-banner { background: linear-gradient(90deg, #d32f2f, #b71c1c); }
.scroll-container { flex: 1; overflow-y: auto; }
.border-b { border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.12); }
.vitals-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 12px; }
.wait-time-chip { background: rgba(var(--v-theme-on-surface), 0.06); }
.wait-success { border: 1px solid rgba(var(--v-theme-success), 0.3); }
.wait-warning { border: 1px solid rgba(var(--v-theme-warning), 0.3); }
.wait-error { border: 1px solid rgba(var(--v-theme-error), 0.3); }
.patient-strip { border-left: 4px solid rgb(var(--v-theme-primary)); }
</style>

<style>
.triage-workspace .vitals-grid .v-text-field input { font-size: 1.2rem; font-weight: bold; text-align: center; }
</style>
