<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="Edit Consultation"
      :subtitle="consultation ? consultation.patient_name : ''"
      icon="mdi-medical-bag" color="success">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/consultations/${id}`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-progress-linear v-if="loadingConsultation" indeterminate color="success" class="mb-4" />

    <v-form ref="formRef" @submit.prevent="save">
      <!-- ═══ Patient & Doctor ═════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="success-lighten-5" size="36" class="mr-3">
            <v-icon color="success-darken-2" size="20">mdi-account-group</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Patient &amp; Doctor</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-select v-model="form.patient" :items="patientOptions"
              label="Patient" variant="outlined"
              :rules="req" prepend-inner-icon="mdi-account"
              :loading="patientR.loading.value" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.doctor" :items="staffOptions"
              label="Doctor" variant="outlined"
              :rules="req" prepend-inner-icon="mdi-doctor"
              :loading="staffR.loading.value" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.consultation_date" type="date"
              label="Consultation date" variant="outlined"
              prepend-inner-icon="mdi-calendar" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.status" :items="statusOptions"
              label="Status" variant="outlined"
              prepend-inner-icon="mdi-list-status" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Complaint & History ═══════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="info-lighten-5" size="36" class="mr-3">
            <v-icon color="info-darken-2" size="20">mdi-clipboard-text-outline</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Complaint &amp; History</div>
        </div>
        <v-row dense>
          <v-col cols="12">
            <v-text-field v-model="form.chief_complaint" label="Chief complaint"
              variant="outlined" :rules="req" prepend-inner-icon="mdi-comment-alert" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.history_present_illness"
              label="History of present illness" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-text-box-outline" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.examination_findings"
              label="Examination findings" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-stethoscope" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Vital Signs ═══════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="red-lighten-5" size="36" class="mr-3">
            <v-icon color="red-darken-2" size="20">mdi-heart-pulse</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Vital Signs</div>
        </div>
        <v-row dense>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.temperature" type="number"
              label="Temperature (°C)" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.blood_pressure_systolic" type="number"
              label="BP Systolic" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.blood_pressure_diastolic" type="number"
              label="BP Diastolic" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.heart_rate" type="number"
              label="Heart Rate (bpm)" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.respiratory_rate" type="number"
              label="Resp Rate" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.oxygen_saturation" type="number"
              label="SpO₂ (%)" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.weight" type="number"
              label="Weight (kg)" variant="outlined" density="compact" hide-details />
          </v-col>
          <v-col cols="6" sm="4" md="3">
            <v-text-field v-model.number="vitals.height" type="number"
              label="Height (cm)" variant="outlined" density="compact" hide-details />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Diagnosis & Treatment ═════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="purple-lighten-5" size="36" class="mr-3">
            <v-icon color="purple-darken-2" size="20">mdi-clipboard-pulse</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Diagnosis &amp; Treatment</div>
        </div>
        <v-row dense>
          <v-col cols="12">
            <v-textarea v-model="form.diagnosis"
              label="Diagnosis" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-clipboard-text" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.treatment_plan"
              label="Treatment plan" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-pill" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.prescription_notes"
              label="Prescription notes" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-prescription" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.follow_up_date" type="date"
              label="Follow-up date (optional)" variant="outlined"
              prepend-inner-icon="mdi-calendar-refresh" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Notes ═════════════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="grey-lighten-4" size="36" class="mr-3">
            <v-icon color="grey-darken-2" size="20">mdi-note-text</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Notes</div>
        </div>
        <v-row dense>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="General notes" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-note-text" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ── Error alert ─────────────────────────────────────────── -->
      <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mb-4">
        {{ r.error.value }}
      </v-alert>

      <!-- ── Action bar ──────────────────────────────────────────── -->
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none"
          @click="navigateTo(`${ns}/consultations/${id}`)">Cancel</v-btn>
        <v-btn color="error" variant="text" rounded="lg" class="text-none"
          prepend-icon="mdi-delete" @click="deleteDialog = true">Delete</v-btn>
        <v-btn type="submit" color="success" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Save Changes</v-btn>
      </div>
    </v-form>

    <!-- ── Delete confirmation dialog ────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Consultation</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete this consultation for
              <strong>{{ consultation?.patient_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const ns = '/clinics'
const route = useRoute()

const r = useResource('/consultations/')
const patientR = useResource('/patients/')
const staffR = useResource('/auth/staff/')

const id = computed(() => route.params.id)

const formRef = ref(null)
const loadingConsultation = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)
const consultation = ref(null)

const req = [v => !!v || 'Required']

const statusOptions = [
  { title: 'Draft', value: 'draft' },
  { title: 'Completed', value: 'completed' },
  { title: 'Pending', value: 'pending' },
  { title: 'In Progress', value: 'in_progress' },
]

const form = reactive({
  patient: null,
  doctor: null,
  appointment: null,
  consultation_date: '',
  chief_complaint: '',
  history_present_illness: '',
  examination_findings: '',
  diagnosis: '',
  treatment_plan: '',
  prescription_notes: '',
  follow_up_date: '',
  notes: '',
  status: 'completed',
})

const vitals = reactive({
  temperature: null,
  blood_pressure_systolic: null,
  blood_pressure_diastolic: null,
  heart_rate: null,
  respiratory_rate: null,
  oxygen_saturation: null,
  weight: null,
  height: null,
})

const snack = reactive({ show: false, color: 'success', text: '' })

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: `${p.patient_number || ''} — ${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown'}`.trim(),
    value: p.id,
  })),
)
const staffOptions = computed(() =>
  staffR.items.value.map(s => ({
    title: s.full_name || s.email,
    value: s.id,
  })),
)

onMounted(async () => {
  patientR.list({ page_size: 1000 })
  staffR.list({ page_size: 1000 })
  loadingConsultation.value = true
  try {
    const data = await r.get(id.value)
    consultation.value = data
    if (data) {
      form.patient = data.patient
      form.doctor = data.doctor
      form.appointment = data.appointment
      form.chief_complaint = data.chief_complaint || ''
      form.history_present_illness = data.history_present_illness || ''
      form.examination_findings = data.examination_findings || ''
      // diagnosis may be a JSON array or string
      const d = data.diagnosis
      if (Array.isArray(d)) {
        form.diagnosis = d.map(x => typeof x === 'string' ? x : x.description || x.code || '').join('; ')
      } else if (typeof d === 'object' && d) {
        form.diagnosis = d.description || d.code || ''
      } else {
        form.diagnosis = d || ''
      }
      form.treatment_plan = data.treatment_plan || ''
      form.notes = data.notes || ''
      // Vital signs & metadata stored in JSONField
      const vs = data.vital_signs || {}
      vitals.temperature = vs.temperature ?? null
      vitals.blood_pressure_systolic = vs.blood_pressure_systolic ?? null
      vitals.blood_pressure_diastolic = vs.blood_pressure_diastolic ?? null
      vitals.heart_rate = vs.heart_rate ?? null
      vitals.respiratory_rate = vs.respiratory_rate ?? null
      vitals.oxygen_saturation = vs.oxygen_saturation ?? null
      vitals.weight = vs.weight ?? null
      vitals.height = vs.height ?? null
      form.consultation_date = vs.consultation_date || (data.created_at ? data.created_at.slice(0, 10) : '')
      form.status = vs.status || 'completed'
      form.prescription_notes = vs.prescription_notes || ''
      form.follow_up_date = vs.follow_up_date || ''
    }
  } catch {
    // error handled by r.error
  } finally {
    loadingConsultation.value = false
  }
})

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  const vitalSigns = { ...vitals }
  if (form.consultation_date) vitalSigns.consultation_date = form.consultation_date
  if (form.status) vitalSigns.status = form.status
  if (form.follow_up_date) vitalSigns.follow_up_date = form.follow_up_date
  if (form.prescription_notes) vitalSigns.prescription_notes = form.prescription_notes
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
    vital_signs: vitalSigns,
  }
  try {
    await r.update(id.value, payload)
    snack.text = 'Consultation updated successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/consultations/${id.value}`)
  } catch {
    snack.text = r.error.value || 'Failed to save consultation'
    snack.color = 'error'
    snack.show = true
  }
}

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(id.value)
    snack.text = 'Consultation deleted'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/consultations`)
  } catch {
    snack.text = r.error.value || 'Failed to delete consultation'
    snack.color = 'error'
    snack.show = true
    deleteDialog.value = false
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
