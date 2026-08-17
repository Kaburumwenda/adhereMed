<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="New Appointment" subtitle="Schedule a new clinic appointment"
      icon="mdi-calendar-plus" color="primary">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/appointments`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" @submit.prevent="save">
      <!-- ═══ Appointment details ══════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="primary-lighten-5" size="36" class="mr-3">
            <v-icon color="primary-darken-2" size="20">mdi-calendar-plus</v-icon>
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
          @click="navigateTo(`${ns}/appointments`)">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Create Appointment</v-btn>
      </div>
    </v-form>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const ns = '/clinics'

const r = useResource('/appointments/')
const patientR = useResource('/patients/')
const staffR = useResource('/auth/staff/')
const deptR = useResource('/departments/')

const formRef = ref(null)
const req = [v => !!v || 'Required']

onMounted(() => {
  patientR.list({ page_size: 1000 })
  staffR.list({ page_size: 1000 })
  deptR.list({ page_size: 1000 })
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

const snack = reactive({ show: false, color: 'success', text: '' })

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  // Build payload from backend-supported fields only.
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
    const created = await r.create(payload)
    snack.text = 'Appointment created successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/appointments/${created.id}`)
  } catch {
    snack.text = r.error.value || 'Failed to create appointment'
    snack.color = 'error'
    snack.show = true
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
