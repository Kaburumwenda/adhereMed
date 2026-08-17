<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- ── Toolbar ──────────────────────────────────────────────── -->
    <PageHeader :title="displayName || 'Patient'" :subtitle="patient?.patient_number || ''"
      icon="mdi-account" color="indigo">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo('/clinics/patients')">Back</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
          @click="navigateTo(`/clinics/patients/${id}/edit`)">Edit</v-btn>
      </template>
    </PageHeader>

    <!-- ── Loading state ────────────────────────────────────────── -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <div v-else-if="!patient" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-account-question</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Patient not found</div>
      <v-btn color="primary" rounded="lg" class="text-none mt-3"
        @click="navigateTo('/clinics/patients')">Back to Patients</v-btn>
    </div>

    <template v-else>
      <!-- ═══ Patient identity banner ═════════════════════════════ -->
      <v-card flat rounded="lg" class="patient-banner pa-5 mb-4">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar :color="avatarColor" size="80" class="mr-2">
            <span class="text-white font-weight-bold text-h5">{{ patientInitials }}</span>
          </v-avatar>
          <div class="flex-grow-1" style="min-width: 200px;">
            <div class="text-h5 font-weight-bold">{{ displayName }}</div>
            <div class="d-flex flex-wrap align-center ga-2 text-body-2 text-medium-emphasis">
              <span class="font-monospace">{{ patient.patient_number || '—' }}</span>
              <v-chip size="x-small" variant="tonal"
                :color="patient.gender === 'male' ? 'info' : patient.gender === 'female' ? 'pink' : 'grey'"
                class="text-capitalize">{{ patient.gender || 'unknown' }}</v-chip>
              <span v-if="age != null">{{ age }} yrs</span>
              <v-chip v-if="patient.blood_type" size="x-small" variant="flat" color="red-lighten-5"
                class="text-red-darken-3 font-weight-bold">{{ patient.blood_type }}</v-chip>
            </div>
          </div>
          <div class="d-flex flex-column align-end ga-1">
            <div v-if="patient.user?.phone" class="d-flex align-center text-body-2">
              <v-icon size="16" class="mr-1" color="medium-emphasis">mdi-phone</v-icon>
              {{ patient.user.phone }}
            </div>
            <div v-if="patient.user_email || patient.user?.email"
              class="d-flex align-center text-body-2 text-medium-emphasis">
              <v-icon size="16" class="mr-1" color="medium-emphasis">mdi-email</v-icon>
              {{ patient.user_email || patient.user?.email }}
            </div>
          </div>
        </div>
      </v-card>

      <!-- ═══ Quick stat cards ════════════════════════════════════ -->
      <v-row dense class="mb-4">
        <v-col v-for="stat in quickStats" :key="stat.label" cols="6" md="3">
          <v-card flat rounded="lg" class="qa-card pa-3 h-100" hover
            @click="stat.action ? stat.action() : null">
            <div class="d-flex align-center">
              <v-avatar :color="stat.color + '-lighten-5'" size="36" class="mr-2">
                <v-icon :color="stat.color + '-darken-2'" size="20">{{ stat.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-overline text-medium-emphasis" style="line-height:1.1">{{ stat.label }}</div>
                <div class="text-h6 font-weight-bold" style="line-height:1.2">{{ stat.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- ═══ Tabbed content ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="tab-card">
        <v-tabs v-model="tab" color="primary" density="comfortable" show-arrows>
          <v-tab value="overview" class="text-none">Overview</v-tab>
          <v-tab value="appointments" class="text-none">
            Appointments
            <v-badge v-if="appointments.length" :content="appointments.length"
              color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="consultations" class="text-none">
            Consultations
            <v-badge v-if="consultations.length" :content="consultations.length"
              color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="prescriptions" class="text-none">
            Prescriptions
            <v-badge v-if="prescriptions.length" :content="prescriptions.length"
              color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="vitals" class="text-none">
            Vitals
            <v-badge v-if="vitals.length" :content="vitals.length"
              color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
        </v-tabs>

        <v-divider />

        <v-window v-model="tab" class="pa-4 pa-md-5">
          <!-- ── Overview tab ─────────────────────────────────────── -->
          <v-window-item value="overview">
            <v-row dense>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Personal Information</div>
                <DetailField label="First Name" :value="patient.user?.first_name" />
                <DetailField label="Last Name" :value="patient.user?.last_name" />
                <DetailField label="Date of Birth" :value="formatDate(patient.date_of_birth)" />
                <DetailField label="Gender" :value="patient.gender" :capitalize="true" />
                <DetailField label="Blood Group" :value="patient.blood_type" />
                <DetailField label="Phone" :value="patient.user?.phone" />
                <DetailField label="Email" :value="patient.user_email || patient.user?.email" />
                <DetailField label="Address" :value="patient.address" :full="true" />
              </v-col>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Emergency Contact</div>
                <DetailField label="Contact Name" :value="patient.emergency_contact_name" />
                <DetailField label="Contact Phone" :value="patient.emergency_contact_phone" />

                <div class="section-title mb-3 mt-4">Insurance</div>
                <DetailField label="Provider" :value="patient.insurance_provider" />
                <DetailField label="Policy Number" :value="patient.insurance_number" />

                <div class="section-title mb-3 mt-4">Registration</div>
                <DetailField label="Patient #" :value="patient.patient_number" :mono="true" />
                <DetailField label="Patient ID" :value="patient.patient_id" :mono="true" />
                <DetailField label="Registered" :value="formatDateTime(patient.created_at)" />
              </v-col>
            </v-row>
          </v-window-item>

          <!-- ── Appointments tab ────────────────────────────────── -->
          <v-window-item value="appointments">
            <div v-if="loadingRelated.appointments" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!appointments.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-calendar-blank</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2">No appointments on record.</div>
            </div>
            <v-timeline v-else density="compact" align="start" class="pa-2">
              <v-timeline-item v-for="appt in appointments" :key="appt.id"
                :dot-color="apptColor(appt.status)" size="x-small" width="100%">
                <div class="d-flex align-center flex-wrap ga-2 cursor-pointer"
                  @click="navigateTo(`/clinics/appointments/${appt.id}`)">
                  <div class="font-weight-medium">
                    {{ appt.doctor_name || appt.doctor || 'Doctor' }}
                  </div>
                  <v-chip size="x-small" variant="tonal" :color="apptColor(appt.status)"
                    class="text-capitalize">{{ appt.status || 'pending' }}</v-chip>
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ formatDateTime(appt.appointment_date || appt.date) }}
                  <span v-if="appt.reason"> · {{ appt.reason }}</span>
                </div>
              </v-timeline-item>
            </v-timeline>
          </v-window-item>

          <!-- ── Consultations tab ───────────────────────────────── -->
          <v-window-item value="consultations">
            <div v-if="loadingRelated.consultations" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!consultations.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-medical-bag</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2">No consultations on record.</div>
            </div>
            <v-timeline v-else density="compact" align="start" class="pa-2">
              <v-timeline-item v-for="con in consultations" :key="con.id"
                dot-color="primary" size="x-small" width="100%">
                <div class="cursor-pointer"
                  @click="navigateTo(`/clinics/consultations/${con.id}`)">
                  <div class="font-weight-medium">
                    {{ con.doctor_name || con.doctor || 'Doctor' }}
                    <span v-if="con.chief_complaint" class="text-medium-emphasis font-weight-regular">
                      — {{ con.chief_complaint }}
                    </span>
                  </div>
                  <div class="text-caption text-medium-emphasis">
                    {{ formatDateTime(con.consultation_date || con.date || con.created_at) }}
                  </div>
                  <div v-if="con.diagnosis" class="text-body-2 mt-1">
                    <v-icon size="14" class="mr-1">mdi-clipboard-text</v-icon>{{ con.diagnosis }}
                  </div>
                </div>
              </v-timeline-item>
            </v-timeline>
          </v-window-item>

          <!-- ── Prescriptions tab ───────────────────────────────── -->
          <v-window-item value="prescriptions">
            <div v-if="loadingRelated.prescriptions" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!prescriptions.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-pill</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2">No prescriptions on record.</div>
            </div>
            <v-list v-else lines="three" class="bg-transparent">
              <template v-for="(rx, i) in prescriptions" :key="rx.id">
                <v-list-item>
                  <template #prepend>
                    <v-avatar color="primary-lighten-5" size="40">
                      <v-icon color="primary-darken-2">mdi-pill</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ rx.prescription_number || rx.rx_number || `Rx #${rx.id}` }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    {{ formatDateTime(rx.prescribed_date || rx.date || rx.created_at) }}
                    <span v-if="rx.doctor_name"> · {{ rx.doctor_name }}</span>
                  </v-list-item-subtitle>
                  <v-list-item-subtitle v-if="rx.medications || rx.items">
                    {{ (rx.medications || rx.items || []).length }} medication(s)
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip v-if="rx.status" size="x-small" variant="tonal" color="primary"
                      class="text-capitalize">{{ rx.status }}</v-chip>
                  </template>
                </v-list-item>
                <v-divider v-if="i < prescriptions.length - 1" />
              </template>
            </v-list>
          </v-window-item>

          <!-- ── Vitals tab ──────────────────────────────────────── -->
          <v-window-item value="vitals">
            <div v-if="loadingRelated.vitals" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!vitals.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-heart-pulse</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2">No vitals on record.</div>
            </div>
            <v-list v-else lines="two" class="bg-transparent">
              <template v-for="(v, i) in vitals" :key="v.id">
                <v-list-item>
                  <template #prepend>
                    <v-avatar color="teal-lighten-5" size="40">
                      <v-icon color="teal-darken-2">mdi-heart-pulse</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ formatDateTime(v.recorded_at || v.created_at) }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    <span v-if="v.temperature">Temp: {{ v.temperature }}°C · </span>
                    <span v-if="v.blood_pressure_systolic || v.blood_pressure_diastolic">
                      BP: {{ v.blood_pressure_systolic || '—' }}/{{ v.blood_pressure_diastolic || '—' }} mmHg ·
                    </span>
                    <span v-if="v.pulse">Pulse: {{ v.pulse }} bpm · </span>
                    <span v-if="v.weight">Weight: {{ v.weight }} kg</span>
                  </v-list-item-subtitle>
                </v-list-item>
                <v-divider v-if="i < vitals.length - 1" />
              </template>
            </v-list>
          </v-window-item>
        </v-window>
      </v-card>
    </template>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime } from '~/utils/format'

const route = useRoute()
const { $api } = useNuxtApp()

const ns = '/clinics'
const id = computed(() => route.params.id)

const r = useResource('/patients/')

const patient = ref(null)
const loading = ref(true)
const tab = ref('overview')

// Related records
const appointments = ref([])
const consultations = ref([])
const prescriptions = ref([])
const vitals = ref([])
const loadingRelated = reactive({
  appointments: false, consultations: false, prescriptions: false, vitals: false,
})

// ── Computed identity ────────────────────────────────────────────
const displayName = computed(() => {
  const p = patient.value
  if (!p) return ''
  if (p.user_name) return p.user_name
  const fn = p.user?.first_name || ''
  const ln = p.user?.last_name || ''
  return `${fn} ${ln}`.trim() || p.user_email || p.user?.email || ''
})

const patientInitials = computed(() => {
  const n = displayName.value || '?'
  const parts = n.split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return ((parts[0][0] || '') + (parts[1]?.[0] || '')).toUpperCase()
})

const avatarColor = computed(() => {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(id.value) || 0) % colors.length]
})

const age = computed(() => {
  const dob = patient.value?.date_of_birth
  if (!dob) return null
  const d = new Date(dob)
  if (isNaN(d)) return null
  const t = new Date()
  let a = t.getFullYear() - d.getFullYear()
  const m = t.getMonth() - d.getMonth()
  if (m < 0 || (m === 0 && t.getDate() < d.getDate())) a--
  return a
})

const quickStats = computed(() => [
  { label: 'Appointments', value: appointments.value.length, icon: 'mdi-calendar', color: 'indigo',
    action: () => { tab.value = 'appointments' } },
  { label: 'Consultations', value: consultations.value.length, icon: 'mdi-medical-bag', color: 'teal',
    action: () => { tab.value = 'consultations' } },
  { label: 'Prescriptions', value: prescriptions.value.length, icon: 'mdi-pill', color: 'primary',
    action: () => { tab.value = 'prescriptions' } },
  { label: 'Vitals', value: vitals.value.length, icon: 'mdi-heart-pulse', color: 'pink',
    action: () => { tab.value = 'vitals' } },
])

// ── Load patient + related ────────────────────────────────────────
onMounted(async () => {
  loading.value = true
  try {
    const data = await r.get(id.value)
    patient.value = data
    if (data) loadRelated()
  } catch {
    patient.value = null
  } finally {
    loading.value = false
  }
})

async function loadRelated() {
  const pid = id.value
  const safe = async (url, target, label, paramKey = 'patient') => {
    loadingRelated[label] = true
    try {
      const { data } = await $api.get(url, { params: { [paramKey]: pid, page_size: 50 } })
      if (Array.isArray(data)) target.value = data
      else target.value = data?.results || []
    } catch { target.value = [] }
    finally { loadingRelated[label] = false }
  }
  safe('/appointments/', appointments, 'appointments', 'patient')
  safe('/consultations/', consultations, 'consultations', 'patient')
  safe('/prescriptions/', prescriptions, 'prescriptions', 'patient')
  safe('/triage/', vitals, 'vitals', 'patient')
}

// ── Helpers ───────────────────────────────────────────────────────
function apptColor(status) {
  const map = {
    confirmed: 'success', completed: 'primary', cancelled: 'error',
    pending: 'warning', scheduled: 'info', no_show: 'grey',
  }
  return map[status] || 'grey'
}
</script>

<style scoped>
.patient-banner { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.tab-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.qa-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: box-shadow 150ms ease, transform 100ms ease;
}
.qa-card:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05); }
.section-title {
  font-weight: 600;
  font-size: 0.875rem;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.cursor-pointer { cursor: pointer; }
</style>
