<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="Edit Appointment"
      :subtitle="appointment ? formatDateTime(apptDateTime) : ''"
      icon="mdi-calendar-edit" color="primary">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/appointments/${id}`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-progress-linear v-if="loadingAppt" indeterminate color="primary" class="mb-4" />

    <div v-else-if="!appointment &&!loadingAppt" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-calendar-question</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Appointment not found</div>
      <v-btn color="primary" rounded="lg" class="text-none mt-3"
        @click="navigateTo(`${ns}/appointments`)">Back to Appointments</v-btn>
    </div>

    <v-form v-else ref="formRef" @submit.prevent="save">
      <!-- ═══ Appointment details ══════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="primary-lighten-5" size="36" class="mr-3">
            <v-icon color="primary-darken-2" size="20">mdi-calendar-edit</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Appointment Details</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-select v-model="form.patient" :items="patientOptions"
              label="Patient" variant="outlined"
              :rules="req" prepend-inner-icon="mdi-account"
              :loading="patientR.loading.value" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.staff" :items="staffOptions"
              label="Doctor" variant="outlined"
              :rules="req" prepend-inner-icon="mdi-doctor"
              :loading="staffR.loading.value" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.department" :items="deptOptions"
              label="Department (optional)" variant="outlined"
              prepend-inner-icon="mdi-hospital-building" clearable
              :loading="deptR.loading.value" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.appointment_type" :items="typeOptions"
              label="Type" variant="outlined"
              prepend-inner-icon="mdi-tag" />
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-text-field v-model="form.appointment_date" type="date"
              label="Date" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-calendar" />
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-text-field v-model="form.appointment_time" type="time"
              label="Time" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-clock" />
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-select v-model="form.status" :items="statusOptions"
              label="Status" variant="outlined"
              prepend-inner-icon="mdi-list-status" />
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-text-field v-model.number="form.duration_minutes" type="number"
              label="Duration (min)" variant="outlined"
              prepend-inner-icon="mdi-timer" />
          </v-col>
        </v-row>
        <v-row dense>
          <v-col cols="12">
            <v-textarea v-model="form.reason" label="Reason" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-comment-question" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
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
          @click="navigateTo(`${ns}/appointments/${id}`)">Cancel</v-btn>
        <v-btn color="error" variant="text" rounded="lg" class="text-none"
          prepend-icon="mdi-delete" @click="deleteDialog = true">Delete</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Save Changes</v-btn>
      </div>
    </v-form>

    <!-- ── Delete confirmation dialog ────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Appointment</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete the appointment for
              <strong>{{ appointment?.patient_name || 'this patient' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">
                {{ formatDateTime(apptDateTime) }} — This action cannot be undone.
              </div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">
            Delete
          </v-btn>
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
import { formatDateTime } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()

const r = useResource('/appointments/')
const patientR = useResource('/patients/')
const staffR = useResource('/auth/staff/')
const deptR = useResource('/departments/')

const id = computed(() => route.params.id)

const formRef = ref(null)
const loadingAppt = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)
const appointment = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })

const req = [v => !!v || 'Required']

const typeOptions = [
  { title: 'Consultation', value: 'consultation' },
  { title: 'Follow-up', value: 'follow-up' },
  { title: 'Check-up', value: 'check-up' },
  { title: 'Procedure', value: 'procedure' },
  { title: 'Emergency', value: 'emergency' },
]

const statusOptions = [
  { title: 'Scheduled', value: 'scheduled' },
  { title: 'Confirmed', value: 'confirmed' },
  { title: 'In Progress', value: 'in_progress' },
  { title: 'Completed', value: 'completed' },
  { title: 'Cancelled', value: 'cancelled' },
  { title: 'No Show', value: 'no_show' },
]

const form = reactive({
  patient: null,
  staff: null,
  department: null,
  appointment_date: '',
  appointment_time: '',
  appointment_type: null,
  status: 'scheduled',
  duration_minutes: 30,
  reason: '',
  notes: '',
})

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
const deptOptions = computed(() =>
  deptR.items.value.map(d => ({
    title: d.name,
    value: d.id,
  })),
)

const apptDateTime = computed(() => {
  const a = appointment.value
  if (!a) return ''
  const d = a.appointment_date || ''
  const t = a.appointment_time || ''
  if (d && t) {
    const dt = new Date(`${d}T${t}`)
    if (!isNaN(dt)) return dt.toISOString()
    return `${d} ${t}`
  }
  return d || ''
})

// ── Load appointment on mount ───────────────────────────────────────
onMounted(async () => {
  patientR.list({ page_size: 1000 })
  staffR.list({ page_size: 1000 })
  deptR.list({ page_size: 1000 })

  loadingAppt.value = true
  try {
    const data = await r.get(id.value)
    appointment.value = data
    if (data) {
      form.patient = data.patient
      form.staff = data.staff
      form.department = data.department || null
      form.appointment_date = data.appointment_date || ''
      form.appointment_time = data.appointment_time || ''
      form.status = data.status || 'scheduled'
      form.duration_minutes = data.duration_minutes ?? 30
      form.reason = data.reason || ''
      form.notes = data.notes || ''
    }
  } catch {
    // error reflected by r.error
  } finally {
    loadingAppt.value = false
  }
})

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  const payload = {
    patient: form.patient,
    staff: form.staff,
    department: form.department || null,
    appointment_date: form.appointment_date,
    appointment_time: form.appointment_time,
    duration_minutes: Number(form.duration_minutes) || 30,
    status: form.status,
    reason: form.reason,
    notes: form.notes,
  }
  try {
    await r.update(id.value, payload)
    snack.text = 'Appointment updated successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/appointments/${id.value}`)
  } catch {
    snack.text = r.error.value || 'Failed to save appointment'
    snack.color = 'error'
    snack.show = true
  }
}

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(id.value)
    snack.text = 'Appointment deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    navigateTo(`${ns}/appointments`)
  } catch {
    snack.text = r.error.value || 'Failed to delete appointment'
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
