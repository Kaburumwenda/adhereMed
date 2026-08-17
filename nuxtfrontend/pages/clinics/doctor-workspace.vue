<script setup>
// Doctor Workspace — a premium, modern command centre for clinicians.
// Aggregates the logged-in doctor's schedule, queue, consultations,
// prescriptions, patients, KPIs, and quick actions into one workspace.
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useNuxtApp, navigateTo } from '#app'
import { useAuthStore } from '~/stores/auth'
import { formatDate, formatDateTime } from '~/utils/format'
import { esiColor, esiLabel } from '~/composables/useClinicalScoring'

const { $api } = useNuxtApp()
const auth = useAuthStore()

const doctorId = computed(() => auth.user?.id)
const doctorName = computed(() => auth.fullName || 'Doctor')
const doctorRole = computed(() => auth.role || '')

const loading = ref(true)
const error = ref(null)

const appointments = ref([])
const consultations = ref([])
const prescriptions = ref([])
const triageQueue = ref([])
const messages = ref([])

const apptTab = ref('today')
const consultTab = ref('drafts')

let refreshTimer = null
const now = ref(new Date())
let clockTimer = null

onMounted(async () => {
  clockTimer = setInterval(() => { now.value = new Date() }, 1000)
  await loadAll()
  refreshTimer = setInterval(loadAll, 60000)
})
onUnmounted(() => {
  if (refreshTimer) clearInterval(refreshTimer)
  if (clockTimer) clearInterval(clockTimer)
})

async function loadAll() {
  if (!doctorId.value) { loading.value = false; error.value = 'No authenticated doctor'; return }
  loading.value = true
  error.value = null
  try {
    const [appt, consult, rx, triage, msg] = await Promise.allSettled([
      $api.get('/appointments/', { params: { staff: doctorId.value, page_size: 200, ordering: 'appointment_date' } }),
      $api.get('/consultations/', { params: { doctor: doctorId.value, page_size: 200, ordering: '-created_at' } }),
      $api.get('/prescriptions/', { params: { doctor: doctorId.value, page_size: 200, ordering: '-created_at' } }),
      $api.get('/triage/', { params: { doctor: doctorId.value, status: 'draft', page_size: 200, ordering: 'esi_level' } }),
      $api.get('/messaging/conversations/', { params: { doctor: doctorId.value, page_size: 50, ordering: '-updated_at' } }),
    ])
    if (appt.status === 'fulfilled') appointments.value = appt.value.data.results || []
    if (consult.status === 'fulfilled') consultations.value = consult.value.data.results || []
    if (rx.status === 'fulfilled') prescriptions.value = rx.value.data.results || []
    if (triage.status === 'fulfilled') triageQueue.value = triage.value.data.results || []
    if (msg.status === 'fulfilled') messages.value = msg.value.data.results || []
  } catch (e) {
    error.value = 'Failed to load workspace data'
    console.error('Doctor workspace load failed', e)
  } finally {
    loading.value = false
  }
}

function isToday(dateStr) {
  if (!dateStr) return false
  const d = new Date(dateStr)
  const n = new Date()
  return d.getDate() === n.getDate() && d.getMonth() === n.getMonth() && d.getFullYear() === n.getFullYear()
}
function isFuture(dateStr) {
  if (!dateStr) return false
  return new Date(dateStr) >= new Date(new Date().toDateString())
}
function timeAgo(dateStr) {
  if (!dateStr) return ''
  const mins = Math.floor((Date.now() - new Date(dateStr).getTime()) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return `${Math.floor(hrs / 24)}d ago`
}
const timeNow = computed(() => now.value.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }))
const dateToday = computed(() =>
  now.value.toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
)

// Appointments filtered by tab
const filteredAppointments = computed(() => {
  const list = appointments.value
  if (apptTab.value === 'today') return list.filter(a => isToday(a.appointment_date))
  if (apptTab.value === 'upcoming') return list.filter(a => isFuture(a.appointment_date) && !isToday(a.appointment_date))
  return list
})

// Consultations filtered by tab
const filteredConsultations = computed(() => {
  const list = consultations.value
  if (consultTab.value === 'drafts') return list.filter(c => c.status === 'draft')
  if (consultTab.value === 'signed') return list.filter(c => c.status === 'signed' || c.status === 'locked')
  return list
})

// KPIs
const todayAppts = computed(() => appointments.value.filter(a => isToday(a.appointment_date)))
const completedToday = computed(() => todayAppts.value.filter(a => a.status === 'completed'))
const activeRx = computed(() => prescriptions.value.filter(p => p.status === 'active'))
const draftConsults = computed(() => consultations.value.filter(c => c.status === 'draft'))
const signedConsults = computed(() => consultations.value.filter(c => c.status === 'signed' || c.status === 'locked'))
const uniquePatients = computed(() => {
  const ids = new Set()
  for (const a of appointments.value) if (a.patient) ids.add(a.patient)
  for (const c of consultations.value) if (c.patient) ids.add(c.patient)
  return ids.size
})
const unreadMsgs = computed(() => messages.value.filter(m => !m.last_read).length || 0)

// Today's completion progress (0–100)
const todayProgress = computed(() => {
  if (!todayAppts.value.length) return 0
  return Math.round((completedToday.value.length / todayAppts.value.length) * 100)
})

const nextAppointment = computed(() => {
  return appointments.value
    .filter(a => isFuture(a.appointment_date) && a.status !== 'cancelled' && a.status !== 'no_show')
    .sort((a, b) => new Date(a.appointment_date) - new Date(b.appointment_date))[0] || null
})

// Weekly workload chart (last 7 days consultations)
const weeklyWorkload = computed(() => {
  const days = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    const dayStart = new Date(d.toDateString())
    const dayEnd = new Date(dayStart)
    dayEnd.setDate(dayEnd.getDate() + 1)
    const count = consultations.value.filter(c => {
      const cd = new Date(c.created_at)
      return cd >= dayStart && cd < dayEnd
    }).length
    days.push({
      label: d.toLocaleDateString(undefined, { weekday: 'short' }).charAt(0),
      count,
      isToday: i === 0,
    })
  }
  return days
})
const maxWorkload = computed(() => Math.max(1, ...weeklyWorkload.value.map(d => d.count)))

// Triage urgency sorting
const sortedTriage = computed(() => {
  return [...triageQueue.value].sort((a, b) => (a.esi_level || 9) - (b.esi_level || 9))
})

// Color helpers
function apptStatusColor(s) {
  return {
    scheduled: 'info', confirmed: 'success', in_progress: 'warning',
    completed: 'grey', cancelled: 'error', no_show: 'error',
  }[s] || 'grey'
}
function apptStatusIcon(s) {
  return { scheduled: 'mdi-clock-outline', confirmed: 'mdi-check-circle-outline',
    in_progress: 'mdi-doctor', completed: 'mdi-check-circle', cancelled: 'mdi-close-circle', no_show: 'mdi-alert-circle' }[s] || 'mdi-circle-outline'
}
function rxStatusColor(s) {
  return {
    active: 'success', sent_to_exchange: 'info', dispensed: 'grey', cancelled: 'error',
  }[s] || 'grey'
}
function consultStatusColor(s) {
  return { draft: 'warning', signed: 'success', locked: 'primary', completed: 'grey' }[s] || 'grey'
}
function consultStatusIcon(s) {
  return { draft: 'mdi-file-document-edit', signed: 'mdi-file-check', locked: 'mdi-lock', completed: 'mdi-archive-check' }[s] || 'mdi-file-document'
}

function patientName(item) {
  return item?.patient_name || '—'
}

function rxMedNames(rx) {
  if (!rx) return '—'
  const items = rx.items || []
  if (!items.length) return rx.medication_name || '—'
  return items.map(i => i.is_custom ? (i.custom_medication_name || 'Custom') : (i.medication_name || '—')).join(', ')
}

function roleLabel(r) {
  return (r || '').split('_').map(w => w[0]?.toUpperCase() + w.slice(1)).join(' ')
}

// Quick actions
function startConsultation(patientId, triageId, apptId) {
  const params = new URLSearchParams()
  if (patientId) params.set('patient', patientId)
  if (triageId) params.set('triage', triageId)
  if (apptId) params.set('appointment', apptId)
  navigateTo(`/clinics/consultations/new?${params.toString()}`)
}

function gotoConsultationWorkspace(id) {
  navigateTo(`/clinics/consultations/workspace/${id}`)
}

function newPrescription() {
  navigateTo('/clinics/prescriptions?new=1')
}

const quickActions = [
  { icon: 'mdi-clipboard-text-plus', label: 'New Encounter', color: 'primary', action: () => startConsultation() },
  { icon: 'mdi-pill-plus', label: 'Write Rx', color: 'success', action: newPrescription },
  { icon: 'mdi-calendar-plus', label: 'New Appt', color: 'info', to: '/clinics/appointments/new' },
  { icon: 'mdi-flask-empty-plus', label: 'Lab Orders', color: 'purple', to: '/clinics/lab-orders' },
  { icon: 'mdi-radiology', label: 'Imaging', color: 'warning', to: '/clinics/radiology' },
  { icon: 'mdi-account-edit', label: 'My Profile', color: 'teal', to: '/clinics/doctor-profile' },
]
</script>

<template>
  <v-container fluid class="pa-4 pa-md-6 doctor-workspace">
    <!-- ===== HERO HEADER ===== -->
    <v-card rounded="xl" flat class="hero-card mb-5 overflow-hidden position-relative">
      <div class="hero-blob blob-1" />
      <div class="hero-blob blob-2" />
      <v-card-text class="pa-5 pa-md-6 position-relative" style="z-index: 1">
        <div class="d-flex align-center flex-wrap ga-4">
          <div class="position-relative">
            <v-avatar size="64" color="white" variant="flat" class="elevation-4">
              <span class="text-h4 font-weight-black" style="color: rgb(var(--v-theme-primary))">{{ doctorName.charAt(0) }}</span>
            </v-avatar>
            <div class="hero-online-dot" />
          </div>
          <div class="flex-grow-1">
            <div class="text-h5 font-weight-bold text-white" style="letter-spacing: -0.5px">
              Welcome back, Dr. {{ doctorName }}
            </div>
            <div class="text-body-2 text-white" style="opacity: 0.78">
              {{ roleLabel(doctorRole) }} · {{ dateToday }}
            </div>
            <div class="text-caption text-white mt-1" style="opacity: 0.6">
              {{ todayAppts.length }} appts · {{ triageQueue.length }} in triage · {{ draftConsults.length }} draft notes
            </div>
          </div>

          <!-- Progress ring for today -->
          <div class="d-flex flex-column align-center ga-1">
            <v-progress-circular :model-value="todayProgress" size="68" width="6" color="white" bg-color="rgba(255,255,255,0.2)" rotate="-90">
              <div class="text-center">
                <div class="text-h6 font-weight-bold text-white" style="line-height: 1">{{ todayProgress }}%</div>
                <div class="text-tiny text-white" style="opacity: 0.65; font-size: 0.55rem">DONE</div>
              </div>
            </v-progress-circular>
            <div class="text-caption text-white" style="opacity: 0.65; font-size: 0.7rem">
              {{ completedToday.length }} / {{ todayAppts.length }} today
            </div>
          </div>

          <div class="d-flex ga-2 flex-wrap">
            <v-btn color="white" variant="flat" prepend-icon="mdi-clipboard-text-play" @click="startConsultation()" class="font-weight-bold">
              Start Encounter
            </v-btn>
            <v-btn color="white" variant="outlined" prepend-icon="mdi-pill-plus" @click="newPrescription()">
              Write Rx
            </v-btn>
          </div>
        </div>

        <!-- Live clock + quick stats strip -->
        <v-divider color="white" class="my-4" style="opacity: 0.2" />
        <div class="d-flex align-center justify-space-between flex-wrap ga-2 text-white">
          <div class="d-flex align-center ga-1">
            <v-icon size="20" style="opacity: 0.7">mdi-clock-outline</v-icon>
            <span class="text-body-2 font-weight-medium" style="opacity: 0.78">{{ timeNow }}</span>
          </div>
          <div v-if="nextAppointment" class="d-flex align-center ga-2">
            <v-icon size="20" style="opacity: 0.7">mdi-clock-alert-outline</v-icon>
            <span class="text-body-2 font-weight-medium" style="opacity: 0.78">
              Next: {{ patientName(nextAppointment) }} · {{ formatDate(nextAppointment.appointment_date) }} {{ nextAppointment.appointment_time }}
            </span>
          </div>
          <div v-else-if="sortedTriage.length" class="d-flex align-center ga-2">
            <v-icon size="20" color="amber-accent-1">mdi-alert-circle-outline</v-icon>
            <span class="text-body-2 font-weight-medium" style="opacity: 0.78">
              {{ sortedTriage.length }} patient(s) awaiting triage
            </span>
          </div>
        </div>
      </v-card-text>
    </v-card>

    <!-- ===== KPI STAT CARDS ===== -->
    <v-row dense class="mb-5">
      <v-col cols="6" md="3" lg="2">
        <v-card rounded="xl" variant="outlined" class="kpi-card h-100" @click="apptTab='today'">
          <v-card-text class="pa-4">
            <div class="kpi-icon-wrap mb-2" style="background: rgba(var(--v-theme-primary), 0.12)">
              <v-icon size="22" color="primary">mdi-calendar-today</v-icon>
            </div>
            <div class="text-overline text-medium-emphasis" style="font-size: 0.65rem">Today's Appts</div>
            <div class="text-h4 font-weight-bold text-primary">{{ todayAppts.length }}</div>
            <v-progress-linear :model-value="todayProgress" color="primary" height="3" rounded class="mt-1" />
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6" md="3" lg="2">
        <v-card rounded="xl" variant="outlined" class="kpi-card h-100">
          <v-card-text class="pa-4">
            <div class="kpi-icon-wrap mb-2" style="background: rgba(var(--v-theme-warning), 0.12)">
              <v-icon size="22" color="warning">mdi-file-document-edit</v-icon>
            </div>
            <div class="text-overline text-medium-emphasis" style="font-size: 0.65rem">Draft Notes</div>
            <div class="text-h4 font-weight-bold text-warning">{{ draftConsults.length }}</div>
            <div class="text-caption text-medium-emphasis mt-1" style="font-size: 0.7rem">awaiting signature</div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6" md="3" lg="2">
        <v-card rounded="xl" variant="outlined" class="kpi-card h-100">
          <v-card-text class="pa-4">
            <div class="kpi-icon-wrap mb-2" style="background: rgba(var(--v-theme-success), 0.12)">
              <v-icon size="22" color="success">mdi-pill-multiple</v-icon>
            </div>
            <div class="text-overline text-medium-emphasis" style="font-size: 0.65rem">Active Rx</div>
            <div class="text-h4 font-weight-bold text-success">{{ activeRx.length }}</div>
            <div class="text-caption text-medium-emphasis mt-1" style="font-size: 0.7rem">prescriptions</div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6" md="3" lg="2">
        <v-card rounded="xl" variant="outlined" class="kpi-card h-100" to="/clinics/triage">
          <v-card-text class="pa-4">
            <div class="kpi-icon-wrap mb-2" style="background: rgba(var(--v-theme-error), 0.12)">
              <v-icon size="22" color="error">mdi-heart-pulse</v-icon>
            </div>
            <div class="text-overline text-medium-emphasis" style="font-size: 0.65rem">Triage Queue</div>
            <div class="text-h4 font-weight-bold text-error">{{ triageQueue.length }}</div>
            <div class="text-caption text-medium-emphasis mt-1" style="font-size: 0.7rem">
              {{ sortedTriage.filter(t =&gt; (t.esi_level || 9) &lt;= 2).length }} urgent
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6" md="3" lg="2">
        <v-card rounded="xl" variant="outlined" class="kpi-card h-100">
          <v-card-text class="pa-4">
            <div class="kpi-icon-wrap mb-2" style="background: rgba(var(--v-theme-info), 0.12)">
              <v-icon size="22" color="info">mdi-account-group</v-icon>
            </div>
            <div class="text-overline text-medium-emphasis" style="font-size: 0.65rem">My Patients</div>
            <div class="text-h4 font-weight-bold text-info">{{ uniquePatients }}</div>
            <div class="text-caption text-medium-emphasis mt-1" style="font-size: 0.7rem">unique seen</div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6" md="3" lg="2">
        <v-card rounded="xl" variant="outlined" class="kpi-card h-100">
          <v-card-text class="pa-4">
            <div class="kpi-icon-wrap mb-2" style="background: rgba(var(--v-theme-purple, 0.12)">
              <v-icon size="22" color="purple">mdi-file-check</v-icon>
            </div>
            <div class="text-overline text-medium-emphasis" style="font-size: 0.65rem">Signed Notes</div>
            <div class="text-h4 font-weight-bold text-purple">{{ signedConsults.length }}</div>
            <div class="text-caption text-medium-emphasis mt-1" style="font-size: 0.7rem">completed</div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ===== MAIN GRID ===== -->
    <v-row>
      <!-- LEFT COLUMN: Next up, schedule, consults -->
      <v-col cols="12" lg="8">
        <!-- Next up highlight -->
        <v-card v-if="nextAppointment" rounded="xl" variant="tonal" color="primary" class="mb-4 next-up-card overflow-hidden">
          <v-card-text class="pa-4 d-flex align-center ga-3 flex-wrap">
            <div class="sched-time-circle">
              <v-icon size="24" color="primary">mdi-clock-alert-outline</v-icon>
            </div>
            <div class="flex-grow-1">
              <div class="text-caption text-primary font-weight-black" style="letter-spacing: 1px">NEXT APPOINTMENT</div>
              <div class="text-h6 font-weight-bold">
                {{ patientName(nextAppointment) }}
                <span class="text-body-2 text-medium-emphasis font-weight-regular">· {{ formatDate(nextAppointment.appointment_date) }} {{ nextAppointment.appointment_time }}</span>
              </div>
              <div class="text-body-2 text-medium-emphasis">
                {{ nextAppointment.reason || 'No reason recorded' }}
                <v-chip size="x-small" :color="apptStatusColor(nextAppointment.status)" variant="tonal" class="ml-1">
                  <v-icon start size="12">{{ apptStatusIcon(nextAppointment.status) }}</v-icon>
                  {{ nextAppointment.status }}
                </v-chip>
              </div>
            </div>
            <v-btn color="primary" variant="flat" prepend-icon="mdi-clipboard-text-play" size="small" class="font-weight-bold"
                   @click="startConsultation(nextAppointment.patient, null, nextAppointment.id)">
              Start Visit
            </v-btn>
          </v-card-text>
        </v-card>

        <!-- Week workload chart -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="primary" class="mr-2" size="20">mdi-chart-bar</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Weekly Workload</span>
            <v-spacer />
            <span class="text-caption text-medium-emphasis">Last 7 days</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-4">
            <div class="workload-chart">
              <div v-for="(d, i) in weeklyWorkload" :key="i" class="workload-bar-wrap">
                <div class="d-flex flex-column align-center justify-end h-100" style="gap: 2px">
                  <div class="text-caption font-weight-bold" :class="d.count > 0 ? 'text-primary' : 'text-disabled'">{{ d.count }}</div>
                  <div class="workload-bar" :class="d.isToday ? 'today' : ''"
                       :style="{ height: (d.count / maxWorkload * 100) + '%', minHeight: d.count > 0 ? '8px' : '3px' }" />
                </div>
                <div class="text-tiny text-center mt-1" :class="d.isToday ? 'text-primary font-weight-bold' : 'text-medium-emphasis'">{{ d.label }}</div>
              </div>
            </div>
          </v-card-text>
        </v-card>

        <!-- Today's Schedule -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="primary" class="mr-2" size="20">mdi-calendar-clock</v-icon>
            <span class="text-subtitle-2 font-weight-bold">My Schedule</span>
            <v-spacer />
            <v-btn-toggle v-model="apptTab" mandatory density="compact" rounded color="primary">
              <v-btn value="today" size="small" variant="text">Today</v-btn>
              <v-btn value="upcoming" size="small" variant="text">Upcoming</v-btn>
              <v-btn value="all" size="small" variant="text">All</v-btn>
            </v-btn-toggle>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="loading" class="d-flex justify-center pa-6">
              <v-progress-circular indeterminate color="primary" />
            </div>
            <div v-else-if="!filteredAppointments.length" class="empty-state text-center pa-6">
              <v-icon size="48" class="mb-2" color="grey-lighten-1">mdi-calendar-blank</v-icon>
              <div class="text-body-2 text-medium-emphasis">No appointments in this view</div>
            </div>
            <v-list v-else lines="two" class="py-0">
              <template v-for="(a, i) in filteredAppointments" :key="a.id">
                <v-list-item class="px-4 py-2 sched-row">
                  <template #prepend>
                    <div class="sched-time mr-3 text-center">
                      <div class="text-caption font-weight-bold text-primary">{{ a.appointment_time || '—' }}</div>
                      <div class="text-tiny text-medium-emphasis">{{ formatDate(a.appointment_date).split(',')[0] }}</div>
                    </div>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ patientName(a) }}
                    <v-chip size="x-small" :color="apptStatusColor(a.status)" variant="tonal" class="ml-1">
                      <v-icon start size="10">{{ apptStatusIcon(a.status) }}</v-icon>
                      {{ a.status }}
                    </v-chip>
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    {{ a.reason || 'No reason recorded' }}
                    <span v-if="a.department_name"> · {{ a.department_name }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-btn icon="mdi-clipboard-text-play" size="small" variant="text" color="primary"
                           @click="startConsultation(a.patient, null, a.id)" />
                  </template>
                </v-list-item>
                <v-divider v-if="i < filteredAppointments.length - 1" />
              </template>
            </v-list>
          </v-card-text>
        </v-card>

        <!-- Recent Consultations -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="warning" class="mr-2" size="20">mdi-file-document-multiple</v-icon>
            <span class="text-subtitle-2 font-weight-bold">My Consultations</span>
            <v-spacer />
            <v-btn-toggle v-model="consultTab" mandatory density="compact" rounded color="warning">
              <v-btn value="drafts" size="small" variant="text">Drafts</v-btn>
              <v-btn value="signed" size="small" variant="text">Signed</v-btn>
              <v-btn value="all" size="small" variant="text">All</v-btn>
            </v-btn-toggle>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="loading" class="d-flex justify-center pa-6">
              <v-progress-circular indeterminate color="warning" />
            </div>
            <div v-else-if="!filteredConsultations.length" class="empty-state text-center pa-6">
              <v-icon size="48" class="mb-2" color="grey-lighten-1">mdi-file-document-outline</v-icon>
              <div class="text-body-2 text-medium-emphasis">No consultations in this view</div>
            </div>
            <v-list v-else lines="two" class="py-0">
              <template v-for="(c, i) in filteredConsultations.slice(0, 12)" :key="c.id">
                <v-list-item class="px-4 py-2 consult-row" @click="gotoConsultationWorkspace(c.id)">
                  <template #prepend>
                    <div class="sched-time-circle mr-3" :style="{ background: `rgba(var(--v-theme-${consultStatusColor(c.status)}), 0.12)` }">
                      <v-icon :color="consultStatusColor(c.status)" size="18">{{ consultStatusIcon(c.status) }}</v-icon>
                    </div>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ patientName(c) }}
                    <v-chip size="x-small" :color="consultStatusColor(c.status)" variant="tonal" class="ml-1">{{ c.status }}</v-chip>
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    {{ c.chief_complaint || 'No complaint' }}
                    <span class="ml-1">· {{ formatDateTime(c.created_at) }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-btn icon="mdi-chevron-right" size="small" variant="text" />
                  </template>
                </v-list-item>
                <v-divider v-if="i < Math.min(filteredConsultations.length, 12) - 1" />
              </template>
            </v-list>
            <v-card-actions v-if="consultations.length > 12" class="justify-center pa-3">
              <v-btn variant="text" to="/clinics/consultations" prepend-icon="mdi-arrow-right">
                View all {{ consultations.length }} consultations
              </v-btn>
            </v-card-actions>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- RIGHT COLUMN -->
      <v-col cols="12" lg="4">
        <!-- Quick Actions -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="pa-4 pb-2">
            <v-icon color="primary" class="mr-2" size="20">mdi-lightning-bolt</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Quick Actions</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-3">
            <v-row dense>
              <v-col v-for="qa in quickActions" :key="qa.label" cols="6">
                <v-card
                  rounded="lg"
                  variant="tonal"
                  :color="qa.color"
                  class="qa-btn pa-3 text-center h-100"
                  flat
                  :to="qa.to"
                  @click="qa.action && qa.action()"
                >
                  <v-icon :color="qa.color" size="28" class="mb-1">{{ qa.icon }}</v-icon>
                  <div class="text-caption font-weight-bold" :class="`text-${qa.color}`">{{ qa.label }}</div>
                </v-card>
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>

        <!-- Triage Queue -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="error" class="mr-2" size="20">mdi-heart-pulse</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Awaiting Triage</span>
            <v-spacer />
            <v-chip size="small" color="error" variant="tonal" class="font-weight-bold">{{ triageQueue.length }}</v-chip>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="loading" class="d-flex justify-center pa-4">
              <v-progress-circular indeterminate color="error" />
            </div>
            <div v-else-if="!triageQueue.length" class="empty-state text-center pa-4">
              <v-icon size="40" class="mb-1" color="success">mdi-check-circle</v-icon>
              <div class="text-body-2 text-medium-emphasis">Queue is clear</div>
            </div>
            <v-list v-else lines="one" class="py-0">
              <v-list-item
                v-for="t in sortedTriage.slice(0, 8)" :key="t.id"
                class="px-3 triage-row"
                :class="`urgency-${t.esi_level || 5}`"
                :to="`/clinics/triage/workspace/${t.id}`"
              >
                <template #prepend>
                  <v-avatar :color="esiColor(t.esi_level)" variant="tonal" size="36">
                    <span class="text-subtitle-2 font-weight-black">{{ t.esi_level || '?' }}</span>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">{{ patientName(t) }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption text-medium-emphasis">
                  ESI {{ t.esi_level || '—' }} · {{ t.chief_complaint || 'No complaint' }}
                  <span v-if="t.created_at" class="ml-1">· {{ timeAgo(t.created_at) }}</span>
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
            <v-card-actions v-if="triageQueue.length > 8" class="justify-center">
              <v-btn variant="text" size="small" to="/clinics/triage">View all</v-btn>
            </v-card-actions>
          </v-card-text>
        </v-card>

        <!-- Active Prescriptions -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="success" class="mr-2" size="20">mdi-pill-multiple</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Recent Prescriptions</span>
            <v-spacer />
            <v-chip size="small" color="success" variant="tonal" class="font-weight-bold">{{ activeRx.length }}</v-chip>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="loading" class="d-flex justify-center pa-4">
              <v-progress-circular indeterminate color="success" />
            </div>
            <div v-else-if="!prescriptions.length" class="empty-state text-center pa-4">
              <v-icon size="40" class="mb-1" color="grey-lighten-1">mdi-pill-off</v-icon>
              <div class="text-body-2 text-medium-emphasis">No prescriptions yet</div>
            </div>
            <v-list v-else lines="two" class="py-0">
              <v-list-item
                v-for="rx in prescriptions.slice(0, 8)" :key="rx.id"
                class="px-3"
                :to="`/clinics/prescriptions/${rx.id}`"
              >
                <template #prepend>
                  <v-avatar color="success" variant="tonal" size="36" class="mr-2">
                    <v-icon size="18">mdi-pill</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">
                  {{ patientName(rx) }}
                  <v-chip size="x-small" :color="rxStatusColor(rx.status)" variant="tonal" class="ml-1">{{ rx.status }}</v-chip>
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption" style="white-space: normal; line-height: 1.3">
                  {{ rxMedNames(rx) }}
                  <span class="ml-1 text-medium-emphasis">· {{ formatDate(rx.created_at) }}</span>
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
            <v-card-actions v-if="prescriptions.length > 8" class="justify-center">
              <v-btn variant="text" size="small" to="/clinics/prescriptions">View all</v-btn>
            </v-card-actions>
          </v-card-text>
        </v-card>

        <!-- Messages preview -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="info" class="mr-2" size="20">mdi-chat</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Messages</span>
            <v-spacer />
            <v-badge v-if="unreadMsgs" :content="unreadMsgs" color="error" offset-x="2">
              <v-chip size="small" variant="tonal" color="info" class="font-weight-bold">{{ messages.length }}</v-chip>
            </v-badge>
            <v-chip v-else size="small" variant="tonal" color="info" class="font-weight-bold">{{ messages.length }}</v-chip>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="loading" class="d-flex justify-center pa-4">
              <v-progress-circular indeterminate color="info" />
            </div>
            <div v-else-if="!messages.length" class="empty-state text-center pa-4">
              <v-icon size="40" class="mb-1" color="grey-lighten-1">mdi-chat-outline</v-icon>
              <div class="text-body-2 text-medium-emphasis">No conversations</div>
            </div>
            <v-list v-else lines="one" class="py-0">
              <v-list-item v-for="m in messages.slice(0, 5)" :key="m.id" class="px-3" to="/clinics/messages">
                <template #prepend>
                  <v-avatar color="info" variant="tonal" size="36" class="mr-2">
                    <v-icon size="18">mdi-chat</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">
                  {{ m.patient_name || m.title || 'Conversation' }}
                  <v-badge v-if="!m.last_read" dot color="error" inline />
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption text-medium-emphasis">
                  {{ m.last_message || m.last_message_preview || '' }}
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
            <v-card-actions v-if="messages.length" class="justify-center">
              <v-btn variant="text" size="small" to="/clinics/messages">Open Messages</v-btn>
            </v-card-actions>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<style scoped>
.doctor-workspace { max-width: 1600px; margin: 0 auto; }

/* Hero */
.hero-card {
  background: linear-gradient(135deg, #1565C0 0%, #0D47A1 60%, #082A6D 100%);
}
.hero-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(40px);
  opacity: 0.25;
  pointer-events: none;
}
.blob-1 { width: 300px; height: 300px; background: #42A5F5; top: -120px; right: -60px; }
.blob-2 { width: 200px; height: 200px; background: #66BB6A; bottom: -100px; right: 40%; opacity: 0.12; }
.hero-online-dot {
  position: absolute;
  bottom: 4px;
  right: 4px;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: #4CAF50;
  border: 3px solid white;
  box-shadow: 0 0 8px rgba(76, 175, 80, 0.5);
}

/* KPI cards */
.kpi-card { transition: transform 0.2s ease, box-shadow 0.2s ease; cursor: pointer; }
.kpi-card:hover { transform: translateY(-4px); box-shadow: 0 12px 28px rgba(0,0,0,0.1) !important; }
.kpi-icon-wrap {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Next up */
.next-up-card { border-left: 6px solid rgb(var(--v-theme-primary)) !important; }

/* Workload chart */
.workload-chart {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  height: 120px;
  padding: 0 4px;
}
.workload-bar-wrap {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
}
.workload-bar {
  width: 100%;
  max-width: 36px;
  border-radius: 6px 6px 2px 2px;
  background: rgba(var(--v-theme-primary), 0.3);
  transition: height 0.3s ease, background 0.2s;
  cursor: pointer;
}
.workload-bar.today {
  background: rgb(var(--v-theme-primary));
  box-shadow: 0 0 8px rgba(var(--v-theme-primary), 0.4);
}
.workload-bar:hover {
  filter: brightness(1.15);
}

/* Schedule time blocks */
.sched-time {
  min-width: 56px;
  padding: 6px 8px;
  border-radius: 10px;
  background: rgba(var(--v-theme-primary), 0.08);
}
.sched-time-circle {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.sched-row:hover, .consult-row:hover {
  background: rgba(var(--v-theme-primary), 0.04);
}

/* Quick action cards */
.qa-btn {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  cursor: pointer;
}
.qa-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0,0,0,0.08) !important;
}

/* Triage urgency */
.triage-row {
  border-left: 4px solid transparent;
  transition: background 0.15s;
}
.triage-row.urgency-1 { border-left-color: #D32F2F; }
.triage-row.urgency-2 { border-left-color: #F57C00; }
.triage-row.urgency-3 { border-left-color: #FBC02D; }
.triage-row.urgency-4 { border-left-color: #66BB6A; }
.triage-row.urgency-5 { border-left-color: #90A4AE; }
.triage-row:hover { background: rgba(var(--v-theme-error), 0.04); }

/* Empty states */
.empty-state {
  padding: 28px 16px;
}

/* Misc */
.text-tiny { font-size: 0.7rem; }
</style>
