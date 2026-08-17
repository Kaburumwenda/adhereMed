<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <PageHeader :title="displayName || 'Appointment'"
      :subtitle="appointment ? formatDateTime(apptDateTime) : ''"
      icon="mdi-calendar-clock" color="primary">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/appointments`)">Back</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
          @click="navigateTo(`${ns}/appointments/${id}/edit`)">Edit</v-btn>
      </template>
    </PageHeader>

    <!-- ── Loading state ────────────────────────────────────────── -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <div v-else-if="!appointment" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-calendar-question</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Appointment not found</div>
      <v-btn color="primary" rounded="lg" class="text-none mt-3"
        @click="navigateTo(`${ns}/appointments`)">Back to Appointments</v-btn>
    </div>

    <template v-else>
      <!-- ═══ Status banner ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="appt-banner pa-5 mb-4">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar :color="statusInfo.color + '-lighten-5'" size="64" class="mr-2">
            <v-icon :color="statusInfo.color + '-darken-2'" size="36">{{ statusInfo.icon }}</v-icon>
          </v-avatar>
          <div class="flex-grow-1" style="min-width: 220px;">
            <div class="text-h5 font-weight-bold">{{ displayName }}</div>
            <div class="d-flex flex-wrap align-center ga-2 text-body-2 text-medium-emphasis mt-1">
              <v-icon size="16">mdi-calendar</v-icon>
              {{ formatDate(appointment.appointment_date) }}
              <v-icon size="16" class="ml-1">mdi-clock-outline</v-icon>
              {{ appointment.appointment_time || '—' }}
              <v-chip size="small" variant="tonal" :color="statusInfo.color"
                class="text-capitalize font-weight-medium ml-2">
                {{ appointment.status ? appointment.status.replace('_', ' ') : '—' }}
              </v-chip>
            </div>
          </div>
        </div>
      </v-card>

      <!-- ═══ Info cards ═══════════════════════════════════════════ -->
      <v-row dense class="mb-4">
        <!-- Patient info -->
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="indigo-lighten-5" size="32" class="mr-2">
                <v-icon color="indigo-darken-2" size="20">mdi-account</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Patient</div>
            </div>
            <DetailField label="Name" :value="appointment.patient_name" />
            <DetailField label="Patient #" :value="patientNumber" :mono="true" />
            <v-btn v-if="appointment.patient" size="small" variant="tonal" color="indigo"
              rounded="lg" class="text-none mt-2"
              prepend-icon="mdi-account-details"
              @click="navigateTo(`${ns}/patients/${appointment.patient}`)">
              View Patient
            </v-btn>
          </v-card>
        </v-col>

        <!-- Doctor info -->
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="teal-lighten-5" size="32" class="mr-2">
                <v-icon color="teal-darken-2" size="20">mdi-doctor</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Doctor</div>
            </div>
            <DetailField label="Name" :value="appointment.staff_name" />
            <DetailField label="Department" :value="appointment.department_name" />
            <DetailField label="Duration" :value="durationLabel" />
          </v-card>
        </v-col>
      </v-row>

      <!-- Appointment details -->
      <v-card flat rounded="lg" class="info-card pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-3">
          <v-avatar color="primary-lighten-5" size="32" class="mr-2">
            <v-icon color="primary-darken-2" size="20">mdi-calendar-text</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Appointment Details</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <DetailField label="Date" :value="formatDate(appointment.appointment_date)" />
            <DetailField label="Time" :value="appointment.appointment_time" />
            <DetailField label="Status" :value="appointment.status" :capitalize="true" />
          </v-col>
          <v-col cols="12" md="6">
            <DetailField label="Created" :value="formatDateTime(appointment.created_at)" />
            <DetailField label="Updated" :value="formatDateTime(appointment.updated_at)" />
          </v-col>
          <v-col cols="12">
            <DetailField label="Reason" :value="appointment.reason" :full="true" />
            <DetailField label="Notes" :value="appointment.notes" :full="true" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Quick actions ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="actions-card pa-4">
        <div class="d-flex align-center flex-wrap ga-2">
          <div class="text-subtitle-1 font-weight-bold mr-auto">Quick Actions</div>
          <v-btn color="primary" rounded="lg" class="text-none"
            prepend-icon="mdi-stethoscope"
            :disabled="!appointment.patient"
            @click="startConsultation">
            Start Consultation
          </v-btn>
        </div>
      </v-card>
    </template>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()

const r = useResource('/appointments/')

const id = computed(() => route.params.id)
const appointment = ref(null)
const loading = ref(false)
const patientNumber = ref('')

const snack = reactive({ show: false, color: 'success', text: '' })

const displayName = computed(() => appointment.value?.patient_name || '')
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
const durationLabel = computed(() => {
  const m = appointment.value?.duration_minutes
  if (!m) return '—'
  return `${m} min`
})

const statusInfo = computed(() => {
  const s = appointment.value?.status
  const map = {
    scheduled: { color: 'info', icon: 'mdi-clock-outline' },
    confirmed: { color: 'success', icon: 'mdi-check-outline' },
    completed: { color: 'primary', icon: 'mdi-check-circle' },
    cancelled: { color: 'error', icon: 'mdi-close' },
    no_show: { color: 'warning', icon: 'mdi-alert-circle-outline' },
    in_progress: { color: 'secondary', icon: 'mdi-progress-clock' },
  }
  return map[s] || { color: 'grey', icon: 'mdi-circle-medium' }
})

// ── Load appointment on mount ───────────────────────────────────────
onMounted(async () => {
  loading.value = true
  try {
    const data = await r.get(id.value)
    appointment.value = data
    if (data?.patient) {
      // Best-effort patient number lookup for display-only.
      try {
        const patientR = useResource('/patients/')
        const p = await patientR.get(data.patient)
        patientNumber.value = p?.patient_number || ''
      } catch {
        patientNumber.value = ''
      }
    }
  } catch {
    // error reflected by r.error
  } finally {
    loading.value = false
  }
})

function startConsultation() {
  const pid = appointment.value?.patient
  if (!pid) return
  navigateTo(`${ns}/consultations/new?patient=${pid}&appointment=${id.value}`)
}
</script>

<style scoped>
.appt-banner { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.info-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.actions-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
