<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1000px;">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="primary-lighten-5" size="48">
        <v-icon color="primary-darken-2" size="28">
          {{ loadId ? 'mdi-clipboard-edit-outline' : 'mdi-clipboard-plus-outline' }}
        </v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">
          {{ loadId ? 'Edit Consultation' : 'New Consultation' }}
        </div>
        <div class="text-body-2 text-medium-emphasis">
          {{ loadId ? 'Update consultation details' : 'Record a new patient consultation' }}
        </div>
      </div>
      <v-spacer />
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" :to="backPath">
        Back
      </v-btn>
    </div>

    <v-progress-linear v-if="loadingById" indeterminate color="primary" class="mb-4" />

    <v-form ref="formRef" @submit.prevent="onSubmit">
      <!-- Section: Patient & Doctor -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="blue-lighten-5" size="36" class="mr-3">
            <v-icon color="blue-darken-2" size="22">mdi-account-group-outline</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Patient &amp; Doctor</div>
        </div>

        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete
              v-model="form.patient" :items="patients" item-title="full_name" item-value="id"
              label="Patient *" placeholder="Search patient..." variant="outlined"
              prepend-inner-icon="mdi-account-search" :rules="req" :loading="patientsLoading" clearable
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props">
                  <template #prepend>
                    <v-avatar size="32" :color="avatarColor(item.raw.full_name)" variant="tonal">
                      <span class="text-caption font-weight-bold">{{ initials(item.raw.full_name) }}</span>
                    </v-avatar>
                  </template>
                  <v-list-item-subtitle class="text-caption">
                    {{ item.raw.user_email || item.raw.phone || '—' }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>

          <v-col cols="12" sm="6">
            <v-autocomplete
              v-model="form.doctor" :items="doctors" item-title="full_name" item-value="id"
              label="Doctor *" placeholder="Assign doctor..." variant="outlined"
              prepend-inner-icon="mdi-doctor" :rules="req" :loading="doctorsLoading" clearable
            />
          </v-col>

          <v-col cols="12">
            <v-autocomplete
              v-model="form.appointment" :items="appointments" item-title="label" item-value="id"
              label="Linked Appointment (optional)" placeholder="Select appointment..." variant="outlined"
              prepend-inner-icon="mdi-calendar-link" clearable
              :loading="apptsLoading"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props">
                  <v-list-item-subtitle class="text-caption">
                    {{ formatDate(item.raw.appointment_date) }} · {{ item.raw.appointment_time }} · {{ item.raw.patient_name }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
        </v-row>
      </v-card>

      <!-- Section: Clinical Notes -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="teal-lighten-5" size="36" class="mr-3">
            <v-icon color="teal-darken-2" size="22">mdi-clipboard-text-outline</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Clinical Notes</div>
        </div>

        <v-row dense>
          <v-col cols="12">
            <v-textarea
              v-model="form.chief_complaint" label="Chief Complaint *"
              placeholder="Patient's primary concern..." variant="outlined"
              prepend-inner-icon="mdi-comment-alert-outline" rows="2" auto-grow :rules="req"
            />
          </v-col>
          <v-col cols="12">
            <v-textarea
              v-model="form.history_present_illness" label="History of Present Illness"
              placeholder="Detailed history..." variant="outlined"
              prepend-inner-icon="mdi-history" rows="3" auto-grow
            />
          </v-col>
          <v-col cols="12">
            <v-textarea
              v-model="form.examination_findings" label="Examination Findings"
              placeholder="Physical examination results..." variant="outlined"
              prepend-inner-icon="mdi-stethoscope" rows="3" auto-grow
            />
          </v-col>
          <v-col cols="12">
            <v-textarea
              v-model="form.treatment_plan" label="Treatment Plan"
              placeholder="Planned treatment..." variant="outlined"
              prepend-inner-icon="mdi-clipboard-pulse-outline" rows="3" auto-grow
            />
          </v-col>
          <v-col cols="12">
            <v-textarea
              v-model="form.notes" label="Notes"
              placeholder="Additional notes..." variant="outlined"
              prepend-inner-icon="mdi-note-edit-outline" rows="2" auto-grow
            />
          </v-col>
        </v-row>
      </v-card>

      <!-- Section: Diagnosis -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="purple-lighten-5" size="36" class="mr-3">
            <v-icon color="purple-darken-2" size="22">mdi-clipboard-pulse</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Diagnosis</div>
        </div>

        <div v-if="form.diagnosis.length" class="d-flex flex-wrap ga-2 mb-4">
          <v-chip v-for="(d, i) in form.diagnosis" :key="i" closable variant="tonal" color="primary"
            @click:close="removeDiagnosis(i)">
            <v-icon start size="x-small">mdi-clipboard-pulse</v-icon>
            <strong class="me-1">{{ d.code }}</strong> {{ d.description }}
          </v-chip>
        </div>

        <v-row dense>
          <v-col cols="12" sm="4">
            <v-text-field v-model="newDiag.code" label="ICD-10 Code"
              placeholder="e.g. J00" variant="outlined" prepend-inner-icon="mdi-identifier" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="newDiag.description" label="Description"
              placeholder="e.g. Acute nasopharyngitis" variant="outlined"
              prepend-inner-icon="mdi-text-short" @keyup.enter="addDiagnosis" />
          </v-col>
          <v-col cols="12" sm="2" class="d-flex align-center">
            <v-btn color="primary" variant="tonal" block rounded="lg" class="text-none"
              prepend-icon="mdi-plus" @click="addDiagnosis">Add</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <!-- Section: Vital Signs -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="red-lighten-5" size="36" class="mr-3">
            <v-icon color="red-darken-2" size="22">mdi-heart-pulse</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Vital Signs</div>
        </div>

        <v-row dense>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.temperature" label="Temp"
              placeholder="36.5" variant="outlined" suffix="°C" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.heart_rate" label="Heart Rate"
              placeholder="72" variant="outlined" suffix="bpm" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.blood_pressure_systolic" label="BP Systolic"
              placeholder="120" variant="outlined" suffix="mmHg" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.blood_pressure_diastolic" label="BP Diastolic"
              placeholder="80" variant="outlined" suffix="mmHg" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.respiratory_rate" label="Resp Rate"
              placeholder="16" variant="outlined" suffix="/min" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.oxygen_saturation" label="SpO2"
              placeholder="98" variant="outlined" suffix="%" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.weight" label="Weight"
              placeholder="70" variant="outlined" suffix="kg" density="compact" @input="dirtyVitals" />
          </v-col>
          <v-col cols="6" sm="4" md="2">
            <v-text-field v-model="form.vital_signs.height" label="Height"
              placeholder="170" variant="outlined" suffix="cm" density="compact" @input="dirtyVitals" />
          </v-col>
        </v-row>
      </v-card>

      <!-- Error -->
      <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mb-4">
        {{ topError }}
      </v-alert>

      <!-- Actions -->
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none" :to="backPath">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
          :loading="saving" prepend-icon="mdi-content-save">
          {{ loadId ? 'Save Changes' : 'Record Consultation' }}
        </v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const route = useRoute()
const router = useRouter()

const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePath = computed(() => `${ns.value}/consultations`)
const backPath = computed(() => basePath.value)

const loadId = computed(() => route.params.id || null)
const r = useResource('/consultations/')
const patientsRes = useResource('/patients/')
const doctorsRes = useResource('/auth/staff/')
const apptsRes = useResource('/appointments/')

const formRef = ref(null)
const saving = ref(false)
const loadingById = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const req = [v => (v !== null && v !== undefined && v !== '') || 'Required']

const patients = ref([])
const patientsLoading = ref(true)
const doctors = ref([])
const doctorsLoading = ref(true)
const appointments = ref([])
const apptsLoading = ref(true)

const form = reactive({
  patient: null,
  doctor: null,
  appointment: null,
  chief_complaint: '',
  history_present_illness: '',
  examination_findings: '',
  diagnosis: [],
  treatment_plan: '',
  notes: '',
  vital_signs: {
    temperature: '',
    heart_rate: '',
    blood_pressure_systolic: '',
    blood_pressure_diastolic: '',
    respiratory_rate: '',
    oxygen_saturation: '',
    weight: '',
    height: '',
  },
})

const newDiag = reactive({ code: '', description: '' })

onMounted(async () => {
  await loadOptions()
  if (loadId.value) await loadConsultation()
})

async function loadOptions() {
  try {
    await patientsRes.list({ page_size: 1000 })
    patients.value = patientsRes.items.value.map(p => ({
      ...p,
      full_name: p.user_name || p.user?.full_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || p.user_email || 'Unknown',
    }))
  } catch { /* ignore */ } finally { patientsLoading.value = false }
  try {
    await doctorsRes.list({ page_size: 1000 })
    doctors.value = doctorsRes.items.value.map(s => ({
      ...s,
      full_name: s.full_name || `${s.first_name || ''} ${s.last_name || ''}`.trim() || s.email || 'Unknown',
    }))
  } catch { /* ignore */ } finally { doctorsLoading.value = false }
  try {
    await apptsRes.list({ page_size: 1000 })
    appointments.value = apptsRes.items.value.map(a => ({
      ...a,
      label: `${formatDate(a.appointment_date)} · ${a.appointment_time} · ${a.patient_name || ''}`,
    }))
  } catch { /* ignore */ } finally { apptsLoading.value = false }
}

async function loadConsultation() {
  loadingById.value = true
  try {
    const data = await r.get(loadId.value)
    if (data) {
      form.patient = data.patient || null
      form.doctor = data.doctor || null
      form.appointment = data.appointment || null
      form.chief_complaint = data.chief_complaint || ''
      form.history_present_illness = data.history_present_illness || ''
      form.examination_findings = data.examination_findings || ''
      form.diagnosis = Array.isArray(data.diagnosis) ? data.diagnosis.map(d =>
        typeof d === 'string' ? { code: '', description: d } : { code: d.code || '', description: d.description || '' }
      ) : []
      form.treatment_plan = data.treatment_plan || ''
      form.notes = data.notes || ''
      const vs = data.vital_signs || {}
      form.vital_signs = {
        temperature: vs.temperature || '',
        heart_rate: vs.heart_rate || '',
        blood_pressure_systolic: vs.blood_pressure_systolic || '',
        blood_pressure_diastolic: vs.blood_pressure_diastolic || '',
        respiratory_rate: vs.respiratory_rate || '',
        oxygen_saturation: vs.oxygen_saturation || '',
        weight: vs.weight || '',
        height: vs.height || '',
      }
    }
  } catch (e) {
    topError.value = r.error.value || 'Failed to load consultation'
  } finally {
    loadingById.value = false
  }
}

function addDiagnosis() {
  if (!newDiag.code && !newDiag.description) return
  form.diagnosis.push({ code: newDiag.code || '', description: newDiag.description || '' })
  newDiag.code = ''
  newDiag.description = ''
}

function removeDiagnosis(i) {
  form.diagnosis.splice(i, 1)
}

function dirtyVitals() {
  // Just a marker so Vue knows vital_signs nested object is reactive
}

function getVitalSignsPayload() {
  const vs = form.vital_signs
  const cleaned = {}
  for (const [k, v] of Object.entries(vs)) {
    if (v !== '' && v !== null && v !== undefined) {
      cleaned[k] = isNaN(Number(v)) ? v : Number(v)
    }
  }
  return cleaned
}

async function onSubmit() {
  topError.value = ''
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  saving.value = true
  try {
    const payload = {
      patient: form.patient,
      doctor: form.doctor,
      appointment: form.appointment || null,
      chief_complaint: form.chief_complaint,
      history_present_illness: form.history_present_illness,
      examination_findings: form.examination_findings,
      diagnosis: form.diagnosis,
      treatment_plan: form.treatment_plan,
      notes: form.notes,
      vital_signs: getVitalSignsPayload(),
    }
    const result = loadId.value
      ? await r.update(loadId.value, payload)
      : await r.create(payload)
    snack.text = loadId.value ? 'Consultation updated successfully' : 'Consultation recorded successfully'
    snack.color = 'success'
    snack.show = true
    setTimeout(() => {
      if (result?.id) {
        router.push(`${basePath.value}/${result.id}`)
      } else {
        router.push(basePath.value)
      }
    }, 800)
  } catch (e) {
    topError.value = r.error.value || 'Failed to save consultation'
  } finally {
    saving.value = false
  }
}

function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(s => s[0]).slice(0, 2).join('').toUpperCase()
}
function avatarColor(name) {
  const colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'orange']
  const h = (name || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0)
  return colors[h % colors.length]
}
</script>

<style scoped>
.form-section {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  transition: border-color 0.2s;
}
.form-section:hover {
  border-color: rgba(var(--v-theme-primary), 0.2);
}
</style>
