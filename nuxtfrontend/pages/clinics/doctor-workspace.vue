<script setup>
// ─────────────────────────────────────────────────────────────────────────
// Doctor Workspace — the clinician cockpit.
//
// There is deliberately NO brand-gradient hero here. The identity line is a
// flat surface panel carrying a slim brand spine, so the page opens as a
// working board rather than a banner. Everything below is one of the
// clinician's real work streams: agenda, waiting room, unsigned notes,
// flagged results, prescriptions, earnings and profile readiness.
// ─────────────────────────────────────────────────────────────────────────
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useNuxtApp, navigateTo } from '#app'
import { useAuthStore } from '~/stores/auth'
import { formatDate } from '~/utils/format'
import { esiLabel } from '~/composables/useClinicalScoring'
import { rgba } from '~/utils/branding'

const { $api } = useNuxtApp()
const auth = useAuthStore()
const brand = useBranding()

const AUTO_REFRESH_SECONDS = 60

const doctorId = computed(() => auth.user?.id)
const clinicName = computed(() => auth.tenantName || 'Clinic')
const doctorInitial = computed(() => (doctorName.value || 'D').charAt(0).toUpperCase())
const doctorTitle = computed(() =>
  /^dr\.?\s/i.test(doctorName.value) ? doctorName.value : `Dr. ${doctorName.value}`
)
const doctorName = computed(() => auth.fullName || 'Doctor')
const doctorRole = computed(() => auth.role || '')

// ── Brand theme: published as CSS custom properties on the page root so each
// panel can tint itself without a JS binding per element.
const theme = computed(() => {
  const p = brand.primary.value
  const a = brand.accent.value
  return {
    '--dw-brand': p,
    '--dw-ink': brand.ink.value,
    '--dw-on-brand': brand.onPrimary.value,
    '--dw-tint-03': rgba(p, 0.03),
    '--dw-tint-06': rgba(p, 0.06),
    '--dw-tint-10': rgba(p, 0.10),
    '--dw-tint-18': rgba(p, 0.18),
    '--dw-tint-34': rgba(p, 0.34),
    '--dw-accent': a,
    '--dw-accent-12': rgba(a, 0.12),
    '--dw-shadow': brand.shadow.value
  }
})

const loading = ref(true)
const refreshing = ref(false)
const issues = ref([])

const profile = ref(null)
const appointments = ref([])
const consultations = ref([])
const prescriptions = ref([])
const triageQueue = ref([])
const labOrders = ref([])
const conversations = ref([])
const earnings = ref(null)

const agendaTab = ref('today')
const queueTab = ref('handoff')

const nowTs = ref(Date.now())
const autoDeadline = ref(0)
let tickTimer = null

const busy = computed(() => loading.value || refreshing.value)

onMounted(async () => {
  tickTimer = setInterval(tick, 1000)
  document.addEventListener('visibilitychange', onVisibilityChange)
  await loadAll()
})
onUnmounted(() => {
  if (tickTimer) clearInterval(tickTimer)
  document.removeEventListener('visibilitychange', onVisibilityChange)
})

function tick() {
  nowTs.value = Date.now()
  if (autoDeadline.value && nowTs.value >= autoDeadline.value && !busy.value && !document.hidden) {
    loadAll({ silent: true })
  }
}
// Don't burn requests while the tab is hidden; catch up on return.
function onVisibilityChange() {
  if (!document.hidden && autoDeadline.value && Date.now() >= autoDeadline.value && !busy.value) {
    loadAll({ silent: true })
  }
}

function rowsOf(res) {
  const data = res?.data
  if (Array.isArray(data)) return data
  return data?.results || []
}

// Every stream settles on its own: a failing endpoint must not blank the board,
// and a failed stream keeps the numbers the clinician is already reading.
async function loadAll({ silent = false } = {}) {
  if (!doctorId.value) { loading.value = false; return }
  if (silent) refreshing.value = true
  else loading.value = true

  const jobs = {
    profile: () => $api.get('/doctors/me/'),
    appointments: () => $api.get('/appointments/', { params: { staff: doctorId.value, page_size: 300, ordering: 'appointment_date' } }),
    consultations: () => $api.get('/consultations/', { params: { doctor: doctorId.value, page_size: 300, ordering: '-created_at' } }),
    prescriptions: () => $api.get('/prescriptions/', { params: { doctor: doctorId.value, page_size: 300, ordering: '-created_at' } }),
    // `status=completed` is the doctor handoff queue on /clinics/triage — the
    // nurse has finished triage and the patient is waiting for a clinician.
    // Drafts are still in triage, so they are not the doctor's queue.
    triage: () => $api.get('/triage/', { params: { status: 'completed', page_size: 300, ordering: 'assigned_at' } }),
    labs: () => $api.get('/lab/orders/', { params: { ordered_by: doctorId.value, page_size: 300, ordering: '-created_at' } }),
    conversations: () => $api.get('/messaging/conversations/', { params: { page_size: 50, ordering: '-updated_at' } }),
    earnings: () => $api.get('/usage-billing/doctor/dashboard/')
  }
  const keys = Object.keys(jobs)
  const settled = await Promise.allSettled(keys.map(k => jobs[k]()))

  const failed = []
  settled.forEach((res, i) => {
    const key = keys[i]
    if (res.status !== 'fulfilled') {
      // The profile and the commission dashboard 404 for clinicians who have
      // no DoctorProfile row — a normal state, not a broken stream.
      if (key !== 'profile' && key !== 'earnings') failed.push(key)
      return
    }
    const payload = res.value?.data
    if (key === 'profile') profile.value = payload || null
    else if (key === 'earnings') earnings.value = payload || null
    else if (key === 'appointments') appointments.value = rowsOf(res.value)
    else if (key === 'consultations') consultations.value = rowsOf(res.value)
    else if (key === 'prescriptions') prescriptions.value = rowsOf(res.value)
    else if (key === 'triage') triageQueue.value = rowsOf(res.value)
    else if (key === 'labs') labOrders.value = rowsOf(res.value)
    else if (key === 'conversations') conversations.value = rowsOf(res.value)
  })

  issues.value = failed
  loading.value = false
  refreshing.value = false
  autoDeadline.value = Date.now() + AUTO_REFRESH_SECONDS * 1000
}

function dayKey(value) {
  const d = value instanceof Date ? value : new Date(value)
  if (isNaN(d)) return ''
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}
const todayKey = computed(() => dayKey(nowTs.value))

function isToday(value) {
  return !!value && dayKey(value) === todayKey.value
}
function startOfTodayMs() {
  const d = new Date(nowTs.value)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}
function timeAgo(dateStr) {
  if (!dateStr) return ''
  const mins = Math.floor((nowTs.value - new Date(dateStr).getTime()) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return `${Math.floor(hrs / 24)}d ago`
}
function urgencyLabel(level) {
  return level ? esiLabel(level) : 'Not triaged'
}
// The API splits an appointment into a date column plus a HH:MM column, so the
// two have to be glued back together before they can be compared to `now`.
function apptMoment(appt) {
  if (!appt?.appointment_date) return null
  const datePart = String(appt.appointment_date).slice(0, 10)
  const rawTime = String(appt.appointment_time || '').slice(0, 5)
  const timePart = /^\d{2}:\d{2}$/.test(rawTime) ? rawTime : '00:00'
  const d = new Date(`${datePart}T${timePart}:00`)
  return isNaN(d) ? null : d
}
// `appointment_time` arrives as HH:MM:SS; the board only wants HH:MM.
function timeLabel(appt) {
  const raw = String(appt?.appointment_time || '').slice(0, 5)
  return /^\d{2}:\d{2}$/.test(raw) ? raw : '—'
}
function fmtRelative(date) {
  if (!date) return ''
  const diff = date.getTime() - nowTs.value
  const mins = Math.round(Math.abs(diff) / 60000)
  if (mins < 1) return 'now'
  const span = mins < 60
    ? `${mins}m`
    : mins < 1440
      ? `${Math.floor(mins / 60)}h${mins % 60 ? ` ${mins % 60}m` : ''}`
      : `${Math.floor(mins / 1440)}d`
  return diff >= 0 ? `in ${span}` : `${span} ago`
}

const clockTime = computed(() => {
  const d = new Date(nowTs.value)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
})
const clockSeconds = computed(() => String(new Date(nowTs.value).getSeconds()).padStart(2, '0'))
const clockDate = computed(() => new Date(nowTs.value).toLocaleDateString(undefined, {
  weekday: 'short', day: 'numeric', month: 'short', year: 'numeric'
}))

const secondsLeft = computed(() => Math.max(0, Math.ceil((autoDeadline.value - nowTs.value) / 1000)))
const countdownPct = computed(() => (autoDeadline.value ? (secondsLeft.value / AUTO_REFRESH_SECONDS) * 100 : 0))
const countdownLabel = computed(() => (secondsLeft.value > 0 ? `${secondsLeft.value}s` : 'due'))

function momentMs(appt) {
  return apptMoment(appt)?.getTime() || 0
}
function byMoment(a, b) {
  return momentMs(a) - momentMs(b)
}

const liveAppointments = computed(() =>
  appointments.value.filter(a => !['cancelled', 'no_show'].includes(a.status))
)
const todayAppts = computed(() =>
  liveAppointments.value.filter(a => isToday(a.appointment_date)).sort(byMoment)
)
const upcomingAppts = computed(() =>
  liveAppointments.value
    .filter(a => !isToday(a.appointment_date) && momentMs(a) >= startOfTodayMs())
    .sort(byMoment)
)
const completedToday = computed(() => todayAppts.value.filter(a => a.status === 'completed'))
const todayProgress = computed(() =>
  todayAppts.value.length
    ? Math.round((completedToday.value.length / todayAppts.value.length) * 100)
    : 0
)
const nextAppointment = computed(() => {
  const pending = todayAppts.value.filter(a => a.status !== 'completed')
  const stillToCome = pending.find(a => momentMs(a) >= nowTs.value - 5 * 60000)
  return stillToCome || upcomingAppts.value[0] || null
})
const agendaList = computed(() => {
  if (agendaTab.value === 'today') return todayAppts.value
  if (agendaTab.value === 'upcoming') return upcomingAppts.value.slice(0, 40)
  return [...liveAppointments.value].sort((a, b) => byMoment(b, a)).slice(0, 60)
})

const draftConsults = computed(() => consultations.value.filter(c => c.status === 'draft'))
const signedConsults = computed(() =>
  consultations.value.filter(c => ['signed', 'locked'].includes(c.status))
)
const activeRx = computed(() => prescriptions.value.filter(p => p.status === 'active'))

const sortedTriage = computed(() =>
  [...triageQueue.value].sort((a, b) => (a.esi_level || 9) - (b.esi_level || 9))
)
const urgentTriage = computed(() => sortedTriage.value.filter(t => (t.esi_level || 9) <= 2))
// Mine first, then the rest of the clinic waiting room.
const queueTriage = computed(() => [
  ...sortedTriage.value.filter(t => t.doctor === doctorId.value),
  ...sortedTriage.value.filter(t => t.doctor !== doctorId.value)
])

// ── Doctor handoff queue ────────────────────────────────────────────────
// A patient stops waiting once someone opens a consultation from their triage
// record, so those are filtered out — otherwise the row would linger all day.
const startedTriageIds = computed(() => new Set(
  consultations.value.map(c => c.triage).filter(Boolean)
))
const openHandoffs = computed(() =>
  triageQueue.value.filter(t => !startedTriageIds.value.has(t.id))
)

// Newest assignment last; urgent patients float to the top, then whoever has
// been waiting longest within that acuity band.
const myHandoffs = computed(() =>
  openHandoffs.value
    .filter(t => t.doctor === doctorId.value)
    .sort((a, b) => {
      const esi = (a.esi_level || 9) - (b.esi_level || 9)
      if (esi !== 0) return esi
      return assignedMs(a) - assignedMs(b)
    })
)
const unassignedHandoffs = computed(() =>
  openHandoffs.value.filter(t => !t.doctor).sort((a, b) => assignedMs(a) - assignedMs(b))
)
// Completed triages already routed to a colleague — worth naming in the empty
// state so a doctor can tell "nobody is waiting" from "nobody is waiting *for
// me*".
const othersHandoffs = computed(() =>
  openHandoffs.value.filter(t => t.doctor && t.doctor !== doctorId.value)
)
const urgentHandoffs = computed(() =>
  myHandoffs.value.filter(t => (t.esi_level || 9) <= 2)
)

// How long this specific clinician has been holding the patient. `assigned_at`
// is stamped by the API whenever the assigned doctor changes; older records
// fall back to the triage arrival time.
function assignedAt(t) {
  const raw = t?.assigned_at || t?.completed_at || t?.triage_time
  if (!raw) return null
  const d = new Date(raw)
  return isNaN(d) ? null : d
}
function assignedMs(t) {
  return assignedAt(t)?.getTime() || 0
}
const waitSeconds = (t) => {
  const at = assignedMs(t)
  return at ? Math.max(0, Math.floor((nowTs.value - at) / 1000)) : 0
}
// mm:ss under an hour, then h:mm — always ticking, so the clinician can see
// the queue age in real time rather than an imprecise "23m ago".
function waitClock(t) {
  const total = waitSeconds(t)
  if (!assignedMs(t)) return '—'
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  if (h) return `${h}h ${String(m).padStart(2, '0')}m`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}
const waitUnit = (t) => (waitSeconds(t) >= 3600 ? 'held' : 'waiting')
// Wait-time tone: the 10/30 minute handoff targets used elsewhere in the app.
function waitTone(t) {
  const mins = waitSeconds(t) / 60
  if (mins >= 30) return 'is-late'
  if (mins >= 10) return 'is-warn'
  return 'is-fresh'
}
const longestWait = computed(() =>
  myHandoffs.value.reduce((max, t) => Math.max(max, waitSeconds(t)), 0)
)
function longestWaitLabel() {
  const total = longestWait.value
  if (!total) return '—'
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  return h ? `${h}h ${m}m` : `${m}m`
}

const openLabs = computed(() =>
  labOrders.value.filter(o => ['pending', 'sample_collected', 'processing'].includes(o.status))
)
const returnedLabs = computed(() => labOrders.value.filter(o => o.status === 'completed'))
const flaggedLabs = computed(() => returnedLabs.value.filter(o => hasAbnormal(o)))
function hasAbnormal(order) {
  return (order?.results || []).some(r => r.is_abnormal)
}

const unreadMessages = computed(() => conversations.value.filter(c => !c.last_read).length)

// Weekly load — consultations authored in the last seven days.
const weeklyLoad = computed(() => {
  const out = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date(nowTs.value)
    d.setHours(0, 0, 0, 0)
    d.setDate(d.getDate() - i)
    const key = dayKey(d)
    out.push({
      key,
      label: d.toLocaleDateString(undefined, { weekday: 'narrow' }),
      count: consultations.value.filter(c => dayKey(c.created_at) === key).length,
      isToday: i === 0
    })
  }
  return out
})
const weeklyTotal = computed(() => weeklyLoad.value.reduce((s, d) => s + d.count, 0))
const weeklyPeak = computed(() => Math.max(1, ...weeklyLoad.value.map(d => d.count)))
const weeklyAvg = computed(() => (weeklyTotal.value / 7).toFixed(1))
function barHeight(count) {
  return `${Math.max(4, Math.round((count / weeklyPeak.value) * 100))}%`
}

// Commission — the doctor-scoped dashboard, not the tenant-wide list.
const currency = computed(() => earnings.value?.doctor?.currency || 'KES')
const monthCommission = computed(() => Number(earnings.value?.current_month?.commission_owed || 0))
const monthConsultations = computed(() => Number(earnings.value?.current_month?.consultations || 0))
const prevCommission = computed(() => Number(earnings.value?.previous_month?.commission_owed || 0))
const commissionDelta = computed(() => {
  const prev = prevCommission.value
  if (!prev) return null
  return Math.round(((monthCommission.value - prev) / prev) * 100)
})
// `>=` cannot appear inside a template binding attribute, so the tone, icon and
// label are resolved here instead.
const deltaTone = computed(() => ((commissionDelta.value ?? 0) >= 0 ? 'success' : 'error'))
const deltaIcon = computed(() => ((commissionDelta.value ?? 0) >= 0 ? 'mdi-trending-up' : 'mdi-trending-down'))
const deltaLabel = computed(() =>
  commissionDelta.value === null ? '' : `${Math.abs(commissionDelta.value)}%`
)
const commissionHistory = computed(() =>
  (earnings.value?.monthly_history || []).map(h => ({
    label: String(h.label || '').slice(5),
    value: Number(h.commission || 0)
  }))
)
const maxCommission = computed(() => Math.max(1, ...commissionHistory.value.map(h => h.value)))
function commissionBar(value) {
  return `${Math.max(6, Math.round((value / maxCommission.value) * 100))}%`
}

const metrics = computed(() => [
  { key: 'today', icon: 'mdi-calendar-today', color: 'primary', label: 'Today', value: todayAppts.value.length, to: '/clinics/appointments' },
  { key: 'done', icon: 'mdi-check-circle-outline', color: 'success', label: 'Complete', value: `${todayProgress.value}%`, to: '/clinics/appointments' },
  { key: 'handoff', icon: 'mdi-account-arrow-right-outline', color: 'deep-orange', label: 'Assigned to me', value: myHandoffs.value.length, to: '/clinics/triage' },
  { key: 'drafts', icon: 'mdi-file-document-edit-outline', color: 'warning', label: 'Draft notes', value: draftConsults.value.length, to: '/clinics/consultations' },
  { key: 'rx', icon: 'mdi-pill-multiple', color: 'teal', label: 'Active Rx', value: activeRx.value.length, to: '/clinics/prescriptions' },
  { key: 'labs', icon: 'mdi-flask-outline', color: 'indigo', label: 'Labs open', value: openLabs.value.length, to: '/clinics/lab-orders' },
  { key: 'flag', icon: 'mdi-alert-decagram-outline', color: 'error', label: 'Flagged', value: flaggedLabs.value.length, to: '/clinics/lab-orders' },
  { key: 'triage', icon: 'mdi-heart-pulse', color: 'red-darken-1', label: 'Waiting room', value: sortedTriage.value.length, to: '/clinics/triage' },
  { key: 'msg', icon: 'mdi-message-text-outline', color: 'info', label: 'Unread', value: unreadMessages.value, to: '/clinics/messages' },
  { key: 'earn', icon: 'mdi-percent-outline', color: 'green-darken-2', label: 'Month', value: money(monthCommission.value, true), to: '/clinics/billing/commission' }
])
function onMetric(metric) {
  if (metric?.to) go(metric.to)
}

// Profile readiness — the handful of details that gate signing and payouts.
const readinessChecks = computed(() => {
  const p = profile.value || {}
  const days = Array.isArray(p.available_days) ? p.available_days : []
  const fee = Number(p.consultation_fee || 0)
  return [
    { key: 'licence', label: 'Medical licence', done: !!p.license_number, hint: p.license_number || 'Printed on signed notes' },
    { key: 'signature', label: 'Signature', done: !!p.signature_url, hint: p.signature_url ? 'On file' : 'Stamped on Rx and reports' },
    { key: 'photo', label: 'Profile photo', done: !!p.profile_picture_url, hint: p.profile_picture_url ? 'Visible to patients' : 'Shown in the directory' },
    { key: 'hours', label: 'Availability', done: !!(days.length && p.available_hours), hint: days.length ? days.join(', ') : 'Drives bookable slots' },
    { key: 'specialty', label: 'Specialisation', done: !!p.specialization, hint: p.specialization || 'Shown beside your name' },
    { key: 'fee', label: 'Consultation fee', done: fee > 0, hint: fee > 0 ? money(fee) : 'Basis for commission' }
  ]
})
const readinessDone = computed(() => readinessChecks.value.filter(c => c.done).length)
const readinessMissing = computed(() => readinessChecks.value.filter(c => !c.done))
const readinessPct = computed(() =>
  readinessChecks.value.length
    ? Math.round((readinessDone.value / readinessChecks.value.length) * 100)
    : 0
)

// ── Presenters ──────────────────────────────────────────────────────────
function apptStatusColor(s) {
  return {
    scheduled: 'info', confirmed: 'teal', in_progress: 'warning',
    completed: 'success', cancelled: 'error', no_show: 'error'
  }[s] || 'grey'
}
function apptStatusLabel(s) {
  return {
    scheduled: 'Scheduled', confirmed: 'Confirmed', in_progress: 'In progress',
    completed: 'Completed', cancelled: 'Cancelled', no_show: 'No show'
  }[s] || roleLabel(s)
}
function patientName(item) {
  return item?.patient_name || 'Unknown patient'
}
function rxMedNames(rx) {
  const items = rx?.items || []
  if (items.length) {
    return items
      .map(i => (i.is_custom ? i.custom_medication_name : i.medication_name) || 'Medication')
      .join(', ')
  }
  return rx?.medication_name || 'No items'
}
function roleLabel(value) {
  return (value || '').split('_').filter(Boolean)
    .map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
}
function money(value, compact = false) {
  const n = Number(value ?? 0)
  if (!isFinite(n)) return '—'
  if (compact && Math.abs(n) >= 1000) {
    return `${currency.value} ${(n / 1000).toFixed(Math.abs(n) >= 10000 ? 0 : 1)}k`
  }
  return `${currency.value} ${n.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
}

// ── Navigation ──────────────────────────────────────────────────────────
function go(path) {
  if (path) navigateTo(path)
}
function startEncounter(patientId = null, triageId = null, apptId = null) {
  const params = new URLSearchParams()
  if (patientId) params.set('patient', patientId)
  if (triageId) params.set('triage', triageId)
  if (apptId) params.set('appointment', apptId)
  const qs = params.toString()
  navigateTo(`/clinics/consultations/new${qs ? `?${qs}` : ''}`)
}
function startFromAppointment(appt) {
  startEncounter(appt?.patient || null, null, appt?.id || null)
}
function openConsultation(id) {
  navigateTo(`/clinics/consultations/workspace/${id}`)
}
function openTriage(item) {
  navigateTo(`/clinics/triage/workspace/${item.id}`)
}

// Starting from the handoff queue reuses the patient's triage record, so the
// consultation opens pre-filled with the complaint and vitals the nurse took.
// When a consultation already exists for that triage we jump straight to it
// rather than creating a duplicate.
async function startFromTriage(triage) {
  if (!triage) return
  try {
    const existing = consultations.value.find(c => c.triage === triage.id)
    if (existing) {
      openConsultation(existing.id)
      return
    }
    const { data } = await $api.get('/consultations/', {
      params: { triage: triage.id, page_size: 1 }
    })
    const found = (data?.results || [])[0]
    if (found) {
      openConsultation(found.id)
      return
    }
    const { data: created } = await $api.post('/consultations/', {
      patient: triage.patient,
      triage: triage.id,
      // Keep the clinician the nurse assigned rather than whoever clicked.
      doctor: triage.doctor || doctorId.value,
      draft_owner: doctorId.value,
      chief_complaint: triage.chief_complaint || '',
      vital_signs: triage.vital_signs || {},
      status: 'draft'
    })
    openConsultation(created.id)
  } catch (e) {
    console.error('Could not open a consultation from triage', e)
    // Fall back to the chart so the clinician is never stuck.
    navigateTo(`/clinics/triage/workspace/${triage.id}`)
  }
}

const quickActions = [
  { icon: 'mdi-clipboard-text-plus', label: 'New encounter', to: null, action: () => startEncounter() },
  { icon: 'mdi-pill', label: 'Write prescription', to: '/clinics/prescriptions?new=1' },
  { icon: 'mdi-calendar-plus', label: 'Book visit', to: '/clinics/appointments/new' },
  { icon: 'mdi-flask-empty-plus', label: 'Lab order', to: '/clinics/lab-orders' },
  { icon: 'mdi-heart-pulse', label: 'Triage', to: '/clinics/triage' },
  { icon: 'mdi-account-circle-outline', label: 'My profile', to: '/clinics/doctor-profile' }
]
</script>

<template>
  <v-container fluid class="pa-4 pa-md-6 dw-page" :style="theme">
    <!-- ══ Identity bar — flat by design, not a brand-gradient hero ══ -->
    <section class="dw-head">
      <span class="dw-head-spine" aria-hidden="true" />
      <div class="dw-head-main">
        <div class="dw-ident">
          <div class="dw-avatar-wrap">
            <v-avatar size="52" class="dw-avatar">
              <img v-if="profile?.profile_picture_url" :src="profile.profile_picture_url" alt="">
              <span v-else class="dw-avatar-initial">{{ doctorInitial }}</span>
            </v-avatar>
            <span class="dw-avatar-dot" aria-hidden="true" />
          </div>
          <div class="dw-ident-body">
            <div class="dw-ident-line">
              <h1 class="dw-name">{{ doctorTitle }}</h1>
              <v-chip v-if="profile?.is_verified" size="x-small" class="dw-chip" prepend-icon="mdi-check-decagram">
                Verified
              </v-chip>
              <v-chip v-else size="x-small" variant="tonal" color="warning" prepend-icon="mdi-shield-alert-outline">
                Verification pending
              </v-chip>
              <v-chip v-if="profile?.is_accepting_patients" size="x-small" variant="tonal" color="success"
                      prepend-icon="mdi-account-check-outline">
                Accepting patients
              </v-chip>
            </div>
            <div class="dw-ident-meta">
              <span>{{ roleLabel(doctorRole) }}</span>
              <span class="dw-sep" aria-hidden="true">•</span>
              <span>{{ profile?.specialization || 'General practice' }}</span>
              <span class="dw-sep" aria-hidden="true">•</span>
              <span>{{ clinicName }}</span>
            </div>
          </div>
        </div>

        <div class="dw-head-actions">
          <div class="dw-clock">
            <span class="dw-clock-time">{{ clockTime }}<i>:{{ clockSeconds }}</i></span>
            <span class="dw-clock-date">{{ clockDate }}</span>
          </div>
          <button type="button" class="dw-live" :class="{ 'is-syncing': refreshing }"
                  :aria-label="refreshing ? 'Syncing workspace data' : `Auto refresh in ${countdownLabel}`"
                  @click="loadAll()">
            <v-progress-circular :model-value="countdownPct" :size="16" :width="2" aria-hidden="true"
                                 :color="refreshing ? 'success' : 'primary'" rotate="-90" />
            <span class="dw-live-dot" aria-hidden="true" />
            <span>{{ refreshing ? 'Syncing' : `Live · ${countdownLabel}` }}</span>
          </button>
          <v-btn color="primary" rounded="lg" class="text-none dw-cta" prepend-icon="mdi-clipboard-text-play"
                 @click="startEncounter()">
            Start encounter
          </v-btn>
        </div>
      </div>

      <div v-if="issues.length" class="dw-issues">
        <v-icon size="14">mdi-alert-circle-outline</v-icon>
        <span>{{ issues.length }} stream{{ issues.length === 1 ? '' : 's' }} unavailable — figures may be stale</span>
      </div>
    </section>

    <!-- ══ Attention board — what needs the clinician right now ══ -->
    <section class="dw-attn">
      <article class="dw-tile dw-tile--next" :class="{ 'is-empty': !nextAppointment }">
        <header class="dw-tile-head">
          <v-icon size="15" class="dw-tile-ico">mdi-clock-alert-outline</v-icon>
          <span>Next patient</span>
          <v-spacer />
          <span v-if="nextAppointment" class="dw-tile-rel">{{ fmtRelative(apptMoment(nextAppointment)) }}</span>
        </header>
        <template v-if="nextAppointment">
          <div class="dw-tile-big">{{ timeLabel(nextAppointment) }}</div>
          <div class="dw-tile-name">{{ patientName(nextAppointment) }}</div>
          <div class="dw-tile-sub">{{ nextAppointment.reason || 'No reason recorded' }}</div>
          <div class="dw-tile-foot">
            <v-chip size="x-small" variant="tonal" :color="apptStatusColor(nextAppointment.status)" class="text-none">
              {{ apptStatusLabel(nextAppointment.status) }}
            </v-chip>
            <v-spacer />
            <v-btn size="small" color="primary" rounded="lg" class="text-none" append-icon="mdi-arrow-right"
                   @click="startFromAppointment(nextAppointment)">
              Start
            </v-btn>
          </div>
        </template>
        <template v-else>
          <div class="dw-tile-big dw-tile-big--muted">—</div>
          <div class="dw-tile-name">Nothing booked</div>
          <div class="dw-tile-sub">No patients waiting in your schedule</div>
          <div class="dw-tile-foot">
            <v-spacer />
            <v-btn size="small" variant="text" rounded="lg" class="text-none" to="/clinics/appointments/new">
              Book a visit
            </v-btn>
          </div>
        </template>
      </article>

      <article class="dw-tile">
        <header class="dw-tile-head">
          <v-icon size="15" class="dw-tile-ico">mdi-file-document-edit-outline</v-icon>
          <span>Unsigned notes</span>
          <v-spacer />
          <span class="dw-tile-pill">{{ draftConsults.length }}</span>
        </header>
        <div class="dw-tile-big">{{ draftConsults.length }}</div>
        <div class="dw-tile-name">
          {{ draftConsults.length ? patientName(draftConsults[0]) : 'All notes signed' }}
        </div>
        <div class="dw-tile-sub">
          {{ draftConsults.length
            ? (draftConsults[0].chief_complaint || 'Draft consultation')
            : 'Nothing awaiting your signature' }}
        </div>
        <div class="dw-tile-foot">
          <v-chip size="x-small" variant="tonal" color="success" class="text-none">
            {{ signedConsults.length }} signed
          </v-chip>
          <v-spacer />
          <v-btn size="small" variant="text" rounded="lg" class="text-none" append-icon="mdi-arrow-right"
                 to="/clinics/consultations">
            Review
          </v-btn>
        </div>
      </article>

      <article class="dw-tile">
        <header class="dw-tile-head">
          <v-icon size="15" class="dw-tile-ico">mdi-alert-decagram-outline</v-icon>
          <span>Flagged results</span>
          <v-spacer />
          <span class="dw-tile-pill">{{ flaggedLabs.length }}</span>
        </header>
        <div class="dw-tile-big">{{ flaggedLabs.length }}</div>
        <div class="dw-tile-name">
          {{ flaggedLabs.length ? patientName(flaggedLabs[0]) : 'Nothing flagged' }}
        </div>
        <div class="dw-tile-sub">
          {{ flaggedLabs.length
            ? (flaggedLabs[0].test_names || []).join(', ')
            : 'No abnormal values in returned reports' }}
        </div>
        <div class="dw-tile-foot">
          <v-chip size="x-small" variant="tonal" color="info" class="text-none">
            {{ returnedLabs.length }} returned
          </v-chip>
          <v-spacer />
          <v-btn size="small" variant="text" rounded="lg" class="text-none" append-icon="mdi-arrow-right"
                 to="/clinics/lab-orders">
            Open
          </v-btn>
        </div>
      </article>
    </section>

    <!-- ══ Quick actions ══ -->
    <div class="dw-quick">
      <v-btn v-for="qa in quickActions" :key="qa.label" variant="outlined" rounded="lg" size="small"
             class="text-none dw-quick-btn" :prepend-icon="qa.icon" :to="qa.to"
             @click="qa.action && qa.action()">
        {{ qa.label }}
      </v-btn>
    </div>

    <!-- ══ Metric rail — compact, scrolls horizontally when space is tight ══ -->
    <div class="dw-rail">
      <button v-for="m in metrics" :key="m.key" type="button" class="dw-metric" @click="onMetric(m)">
        <v-avatar :color="m.color" size="26" variant="tonal">
          <v-icon size="14">{{ m.icon }}</v-icon>
        </v-avatar>
        <span class="dw-metric-body">
          <b>{{ m.value }}</b>
          <span>{{ m.label }}</span>
        </span>
      </button>
    </div>

    <!-- ===== MAIN GRID ===== -->
    <v-row>
      <!-- LEFT COLUMN: agenda + personal work queue -->
      <v-col cols="12" lg="8">
        <!-- Agenda -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico">mdi-calendar-clock-outline</v-icon>
              <span>Agenda</span>
              <span class="dw-panel-count">{{ agendaList.length }}</span>
            </div>
            <v-btn-toggle v-model="agendaTab" mandatory density="compact" rounded color="primary" class="dw-toggle">
              <v-btn value="today" size="small" variant="text" class="text-none">Today</v-btn>
              <v-btn value="upcoming" size="small" variant="text" class="text-none">Upcoming</v-btn>
              <v-btn value="history" size="small" variant="text" class="text-none">History</v-btn>
            </v-btn-toggle>
          </header>

          <div v-if="loading" class="dw-loading">
            <v-progress-circular indeterminate size="22" color="primary" />
          </div>
          <div v-else-if="!agendaList.length" class="dw-empty">
            <v-icon size="34">mdi-calendar-blank-outline</v-icon>
            <div>No appointments in this view</div>
          </div>
          <ul v-else class="dw-agenda">
            <li v-for="a in agendaList" :key="a.id" class="dw-agenda-row" :class="`is-${a.status}`">
              <div class="dw-agenda-time">
                <b>{{ timeLabel(a) }}</b>
                <span>{{ a.duration_minutes || 30 }} min</span>
              </div>
              <div class="dw-agenda-rail" aria-hidden="true"><span /></div>
              <div class="dw-agenda-body">
                <div class="dw-agenda-name">{{ patientName(a) }}</div>
                <div class="dw-agenda-sub">
                  {{ a.reason || 'No reason recorded' }}
                  <template v-if="a.clinic_site_name"> · {{ a.clinic_site_name }}</template>
                </div>
              </div>
              <div class="dw-agenda-side">
                <span class="dw-rel">{{ fmtRelative(apptMoment(a)) }}</span>
                <v-chip size="x-small" variant="tonal" :color="apptStatusColor(a.status)" class="text-none">
                  {{ apptStatusLabel(a.status) }}
                </v-chip>
              </div>
              <v-btn icon="mdi-arrow-right" size="x-small" variant="text" class="dw-agenda-go"
                     :title="`Start encounter for ${patientName(a)}`" @click="startFromAppointment(a)" />
            </li>
          </ul>
        </section>

        <!-- Personal work queue -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico">mdi-playlist-check</v-icon>
              <span>My queue</span>
              <span v-if="myHandoffs.length" class="dw-panel-count is-live">{{ myHandoffs.length }}</span>
            </div>
            <v-btn-toggle v-model="queueTab" mandatory density="compact" rounded color="primary" class="dw-toggle">
              <v-btn value="handoff" size="small" variant="text" class="text-none">Assigned {{ myHandoffs.length }}</v-btn>
              <v-btn value="drafts" size="small" variant="text" class="text-none">Notes {{ draftConsults.length }}</v-btn>
              <v-btn value="results" size="small" variant="text" class="text-none">Reports {{ returnedLabs.length }}</v-btn>
              <v-btn value="rx" size="small" variant="text" class="text-none">Rx {{ activeRx.length }}</v-btn>
            </v-btn-toggle>
          </header>

          <!-- Triage handoff — patients the nurse routed to this clinician -->
          <template v-if="queueTab === 'handoff'">
            <div v-if="urgentHandoffs.length" class="dw-alert">
              <v-icon size="14">mdi-alert-octagon-outline</v-icon>
              <span>
                {{ urgentHandoffs.length }} high-acuity patient{{ urgentHandoffs.length === 1 ? '' : 's' }}
                assigned to you
              </span>
            </div>

            <div v-if="loading" class="dw-loading">
              <v-progress-circular indeterminate size="20" color="primary" />
            </div>
            <ul v-else-if="myHandoffs.length" class="dw-handoff">
              <li v-for="t in myHandoffs" :key="t.id" class="dw-handoff-row" :class="`esi-${t.esi_level || 5}`">
                <span class="dw-handoff-esi" :class="`is-esi-${t.esi_level || 5}`">
                  {{ t.esi_level || '–' }}
                </span>

                <div class="dw-handoff-body">
                  <div class="dw-handoff-name">
                    {{ patientName(t) }}
                    <span v-if="t.patient_number" class="dw-handoff-mrn">{{ t.patient_number }}</span>
                  </div>
                  <div class="dw-handoff-sub">
                    {{ urgencyLabel(t.esi_level) }} · {{ t.chief_complaint || 'No complaint recorded' }}
                  </div>
                  <div class="dw-handoff-meta">
                    <span v-if="t.nurse_name">Triaged by {{ t.nurse_name }}</span>
                    <span v-if="t.news2_score >= 5" class="dw-handoff-news">
                      NEWS2 {{ t.news2_score }}
                    </span>
                    <span v-if="t.clinic_site_name">{{ t.clinic_site_name }}</span>
                  </div>
                </div>

                <div class="dw-handoff-wait">
                  <span class="dw-wait-clock" :class="waitTone(t)" :aria-label="`${waitUnit(t)} ${waitClock(t)}`">
                    {{ waitClock(t) }}
                  </span>
                  <span class="dw-wait-unit">{{ waitUnit(t) }}</span>
                </div>

                <div class="dw-handoff-actions">
                  <v-btn size="x-small" variant="text" class="text-none" :to="`/clinics/triage/workspace/${t.id}`">
                    Chart
                  </v-btn>
                  <v-btn size="x-small" color="primary" rounded="lg" class="text-none"
                         @click="startFromTriage(t)">
                    Start
                  </v-btn>
                </div>
              </li>
            </ul>

            <div v-else-if="unassignedHandoffs.length" class="dw-empty">
              <v-icon size="28">mdi-account-question-outline</v-icon>
              <div>Nothing assigned to you</div>
              <div class="dw-empty-hint">
                {{ unassignedHandoffs.length }} triaged patient{{ unassignedHandoffs.length === 1 ? '' : 's' }}
                still need a clinician — pick one up from the waiting room.
              </div>
              <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none mt-1"
                     to="/clinics/triage">
                Open triage queue
              </v-btn>
            </div>
            <div v-else class="dw-empty dw-empty--ok">
              <v-icon size="28">mdi-check-circle-outline</v-icon>
              <div>Handoff queue is clear</div>
              <div v-if="othersHandoffs.length" class="dw-empty-hint">
                {{ othersHandoffs.length }} patient{{ othersHandoffs.length === 1 ? '' : 's' }}
                already routed to another clinician.
              </div>
            </div>
          </template>

          <!-- Unsigned notes -->
          <ul v-if="queueTab === 'drafts'" class="dw-list">
            <li v-for="c in draftConsults.slice(0, 8)" :key="c.id" class="dw-list-row" @click="openConsultation(c.id)">
              <v-avatar size="26" variant="tonal" color="warning"><v-icon size="13">mdi-file-document-edit</v-icon></v-avatar>
              <div class="dw-list-body">
                <div class="dw-list-name">{{ patientName(c) }}</div>
                <div class="dw-list-sub">{{ c.chief_complaint || 'Draft consultation' }} · {{ timeAgo(c.created_at) }}</div>
              </div>
              <v-btn size="x-small" variant="tonal" color="warning" rounded="lg" class="text-none"
                     @click.stop="openConsultation(c.id)">Continue</v-btn>
            </li>
            <li v-if="!draftConsults.length" class="dw-empty dw-empty--ok">
              <v-icon size="26">mdi-check-circle-outline</v-icon>
              <div>Every note is signed</div>
            </li>
          </ul>

          <!-- Returned lab reports -->
          <ul v-else-if="queueTab === 'results'" class="dw-list">
            <li v-for="o in returnedLabs.slice(0, 8)" :key="o.id" class="dw-list-row" @click="go('/clinics/lab-orders')">
              <v-avatar size="26" variant="tonal" :color="hasAbnormal(o) ? 'error' : 'success'">
                <v-icon size="13">mdi-flask</v-icon>
              </v-avatar>
              <div class="dw-list-body">
                <div class="dw-list-name">
                  {{ patientName(o) }}
                  <v-chip v-if="hasAbnormal(o)" size="x-small" variant="tonal" color="error" class="ml-2">Abnormal</v-chip>
                </div>
                <div class="dw-list-sub">
                  {{ (o.test_names || []).join(', ') || 'Lab order' }} · {{ formatDate(o.created_at) }}
                </div>
              </div>
              <v-icon size="15" class="dw-list-chevron">mdi-chevron-right</v-icon>
            </li>
            <li v-if="!returnedLabs.length" class="dw-empty">
              <v-icon size="26">mdi-flask-empty-outline</v-icon>
              <div>No reports returned yet</div>
            </li>
          </ul>

          <!-- Active prescriptions — explicit match, so the handoff tab does
               not fall through to this list. -->
          <ul v-else-if="queueTab === 'rx'" class="dw-list">
            <li v-for="rx in activeRx.slice(0, 8)" :key="rx.id" class="dw-list-row" @click="go('/clinics/prescriptions')">
              <v-avatar size="26" variant="tonal" color="teal"><v-icon size="13">mdi-pill</v-icon></v-avatar>
              <div class="dw-list-body">
                <div class="dw-list-name">{{ patientName(rx) }}</div>
                <div class="dw-list-sub">{{ rxMedNames(rx) }}</div>
              </div>
              <span class="dw-list-time">{{ formatDate(rx.created_at) }}</span>
            </li>
            <li v-if="!activeRx.length" class="dw-empty">
              <v-icon size="26">mdi-pill-off</v-icon>
              <div>No active prescriptions</div>
            </li>
          </ul>
        </section>
      </v-col>

      <!-- RIGHT COLUMN -->
      <v-col cols="12" lg="4">
        <!-- Waiting room -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico dw-panel-ico--danger">mdi-heart-pulse</v-icon>
              <span>Waiting room</span>
              <span class="dw-panel-count">{{ sortedTriage.length }}</span>
            </div>
            <v-btn size="x-small" variant="text" class="text-none" to="/clinics/triage" append-icon="mdi-arrow-right">
              All
            </v-btn>
          </header>

          <div v-if="urgentTriage.length" class="dw-alert">
            <v-icon size="14">mdi-alert-octagon-outline</v-icon>
            <span>{{ urgentTriage.length }} high-acuity patient{{ urgentTriage.length === 1 ? '' : 's' }} waiting</span>
          </div>

          <div v-if="loading" class="dw-loading">
            <v-progress-circular indeterminate size="20" color="error" />
          </div>
          <ul v-else class="dw-list">
            <li v-for="t in queueTriage.slice(0, 6)" :key="t.id" class="dw-queue-row"
                :class="`esi-${t.esi_level || 5}`" @click="openTriage(t)">
              <span class="dw-esi">{{ t.esi_level || '–' }}</span>
              <div class="dw-list-body">
                <div class="dw-list-name">
                  {{ patientName(t) }}
                  <v-chip v-if="t.doctor === doctorId" size="x-small" variant="tonal" color="primary" class="ml-2">Mine</v-chip>
                </div>
                <div class="dw-list-sub">{{ urgencyLabel(t.esi_level) }} · {{ t.chief_complaint || 'No complaint' }}</div>
              </div>
              <span class="dw-list-time">{{ timeAgo(t.created_at) }}</span>
            </li>
            <li v-if="!sortedTriage.length" class="dw-empty dw-empty--ok">
              <v-icon size="26">mdi-check-circle-outline</v-icon>
              <div>Waiting room is clear</div>
            </li>
          </ul>
        </section>

        <!-- Seven-day load -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico">mdi-chart-timeline-variant</v-icon>
              <span>7-day load</span>
            </div>
            <span class="dw-panel-hint">{{ weeklyTotal }} encounters</span>
          </header>
          <div class="dw-bars">
            <div v-for="d in weeklyLoad" :key="d.key" class="dw-bar-col">
              <span class="dw-bar-value">{{ d.count }}</span>
              <div class="dw-bar-track">
                <div class="dw-bar-fill" :class="{ 'is-today': d.isToday }" :style="{ height: barHeight(d.count) }" />
              </div>
              <span class="dw-bar-label" :class="{ 'is-today': d.isToday }">{{ d.label }}</span>
            </div>
          </div>
          <div class="dw-facts">
            <div><b>{{ weeklyAvg }}</b><span>avg / day</span></div>
            <div><b>{{ weeklyPeak }}</b><span>busiest</span></div>
            <div><b>{{ signedConsults.length }}</b><span>signed</span></div>
          </div>
        </section>

        <!-- Commission -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico">mdi-percent-outline</v-icon>
              <span>Commission</span>
            </div>
            <v-btn size="x-small" variant="text" class="text-none" to="/clinics/billing/commission"
                   append-icon="mdi-arrow-right">
              Details
            </v-btn>
          </header>
          <template v-if="earnings">
            <div class="dw-earn">
              <div class="dw-earn-main">
                <span class="dw-earn-label">This month</span>
                <span class="dw-earn-value">{{ money(monthCommission) }}</span>
              </div>
              <v-chip v-if="commissionDelta !== null" size="x-small" variant="tonal" :color="deltaTone"
                      :prepend-icon="deltaIcon">
                {{ deltaLabel }}
              </v-chip>
            </div>
            <div v-if="commissionHistory.length" class="dw-spark">
              <div v-for="h in commissionHistory" :key="h.label" class="dw-spark-col">
                <div class="dw-spark-track">
                  <div class="dw-spark-fill" :style="{ height: commissionBar(h.value) }" />
                </div>
                <span>{{ h.label }}</span>
              </div>
            </div>
            <div class="dw-facts">
              <div><b>{{ monthConsultations }}</b><span>encounters</span></div>
              <div><b>{{ money(prevCommission, true) }}</b><span>last month</span></div>
              <div><b>{{ currency }}</b><span>currency</span></div>
            </div>
          </template>
          <div v-else class="dw-empty">
            <v-icon size="26">mdi-percent-outline</v-icon>
            <div>No commission data yet</div>
            <div class="dw-empty-hint">
              A consultation fee on your profile is what commission is calculated from.
            </div>
          </div>
        </section>

        <!-- Profile readiness -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico">mdi-shield-check-outline</v-icon>
              <span>Profile readiness</span>
            </div>
            <span class="dw-panel-hint">{{ readinessDone }} / {{ readinessChecks.length }}</span>
          </header>
          <div class="dw-ready">
            <v-progress-circular :model-value="readinessPct" :size="54" :width="5" color="primary"
                                 bg-color="rgba(var(--v-theme-on-surface), 0.08)" rotate="-90">
              <span class="dw-ready-pct">{{ readinessPct }}<i>%</i></span>
            </v-progress-circular>
            <div class="dw-ready-body">
              <div class="dw-ready-title">
                {{ readinessPct === 100
                  ? 'Everything in place'
                  : `${readinessMissing.length} item${readinessMissing.length === 1 ? '' : 's'} left` }}
              </div>
              <div class="dw-ready-sub">Patients and payouts depend on these details.</div>
              <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none mt-1"
                     to="/clinics/doctor-profile">
                Open profile
              </v-btn>
            </div>
          </div>
          <ul class="dw-checks">
            <li v-for="c in readinessChecks" :key="c.key" :class="{ 'is-done': c.done }">
              <v-icon size="14">{{ c.done ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
              <span class="dw-check-label">{{ c.label }}</span>
              <span class="dw-check-hint">{{ c.hint }}</span>
            </li>
          </ul>
        </section>

        <!-- Messages -->
        <section class="dw-panel">
          <header class="dw-panel-head">
            <div class="dw-panel-title">
              <v-icon size="17" class="dw-panel-ico">mdi-message-text-outline</v-icon>
              <span>Messages</span>
              <span v-if="unreadMessages" class="dw-panel-count">{{ unreadMessages }}</span>
            </div>
            <v-btn size="x-small" variant="text" class="text-none" to="/clinics/messages"
                   append-icon="mdi-arrow-right">
              Inbox
            </v-btn>
          </header>
          <ul class="dw-list">
            <li v-for="m in conversations.slice(0, 4)" :key="m.id" class="dw-list-row" @click="go('/clinics/messages')">
              <v-avatar size="26" variant="tonal" color="info"><v-icon size="13">mdi-account</v-icon></v-avatar>
              <div class="dw-list-body">
                <div class="dw-list-name">
                  {{ m.patient_name || m.title || 'Conversation' }}
                  <span v-if="!m.last_read" class="dw-msg-dot" aria-hidden="true" />
                </div>
                <div class="dw-list-sub">{{ m.last_message || m.last_message_preview || 'No messages yet' }}</div>
              </div>
              <span class="dw-list-time">{{ timeAgo(m.updated_at) }}</span>
            </li>
            <li v-if="!conversations.length" class="dw-empty">
              <v-icon size="26">mdi-chat-outline</v-icon>
              <div>No conversations yet</div>
            </li>
          </ul>
        </section>
      </v-col>
    </v-row>
  </v-container>
</template>

<style scoped>
/* ─────────────────────────────────────────────────────────────────────────
   Doctor cockpit. There is no gradient hero on this page by design: the
   top panel is a flat surface with a slim brand spine, and every colour is
   derived from the tenant palette through the --dw-* custom properties that
   the root element publishes (so dark mode and re-branding both work).
   ───────────────────────────────────────────────────────────────────────── */
.dw-page { width: 100%; }

/* ══ Identity bar ══════════════════════════════════════════════════════ */
.dw-head {
  position: relative;
  overflow: hidden;
  padding: 15px 20px 15px 22px;
  border-radius: 18px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgb(var(--v-theme-surface));
}
.dw-head-spine {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  background: var(--dw-brand);
}
.dw-head-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  flex-wrap: wrap;
}
.dw-ident { display: flex; align-items: center; gap: 14px; min-width: 0; }
.dw-avatar-wrap { position: relative; flex: 0 0 auto; }
.dw-avatar {
  background: var(--dw-tint-10);
  box-shadow: 0 0 0 3px var(--dw-tint-06);
}
.dw-avatar img { width: 100%; height: 100%; object-fit: cover; }
.dw-avatar-initial { font-size: 1.2rem; font-weight: 800; color: var(--dw-ink); }
.dw-avatar-dot {
  position: absolute;
  right: 0;
  bottom: 0;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: rgb(var(--v-theme-success));
  border: 2.5px solid rgb(var(--v-theme-surface));
  box-shadow: 0 0 0 1px rgba(var(--v-theme-success), 0.35);
}
.dw-ident-body { min-width: 0; }
.dw-ident-line { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.dw-name {
  margin: 0;
  font-size: 1.14rem;
  font-weight: 800;
  letter-spacing: -0.4px;
  line-height: 1.25;
}
.dw-chip {
  background: var(--dw-tint-10) !important;
  color: var(--dw-ink) !important;
  font-weight: 700;
  letter-spacing: 0.2px;
}
.dw-ident-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  margin-top: 3px;
  font-size: 0.78rem;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.dw-sep { opacity: 0.45; }
.dw-head-actions { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.dw-clock { display: flex; flex-direction: column; align-items: flex-end; line-height: 1.1; }
.dw-clock-time {
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: -0.4px;
  font-variant-numeric: tabular-nums;
}
.dw-clock-time i {
  margin-left: 2px;
  font-style: normal;
  font-size: 0.68rem;
  font-weight: 700;
  opacity: 0.45;
}
.dw-clock-date {
  font-size: 0.64rem;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.dw-live {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  height: 34px;
  padding: 0 11px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.7);
  font-family: inherit;
  font-size: 11.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  cursor: pointer;
  /* Only the background animates: transitioning a border colour derived from a
     CSS variable makes Chrome keep the pre-theme-change value. */
  transition: background-color 0.2s ease;
}
.dw-live:hover { background: var(--dw-tint-06); }
.dw-live.is-syncing {
  border-color: rgba(var(--v-theme-success), 0.5);
  background: rgba(var(--v-theme-success), 0.07);
}
.dw-live-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgb(var(--v-theme-success));
  animation: dw-pulse 2s ease-out infinite;
}
@keyframes dw-pulse {
  0% { box-shadow: 0 0 0 0 rgba(var(--v-theme-success), 0.45); }
  70% { box-shadow: 0 0 0 6px rgba(var(--v-theme-success), 0); }
  100% { box-shadow: 0 0 0 0 rgba(var(--v-theme-success), 0); }
}
.dw-cta { font-weight: 700; }
.dw-issues {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 10px;
  font-size: 0.72rem;
  font-weight: 600;
  color: rgb(var(--v-theme-warning));
}

/* ══ Attention board ═══════════════════════════════════════════════════ */
.dw-attn {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin: 12px 0;
}
.dw-tile {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 13px 15px 12px;
  border-radius: 15px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgb(var(--v-theme-surface));
  transition: box-shadow 0.2s ease, transform 0.2s ease, border-color 0.2s ease;
}
.dw-tile:hover {
  transform: translateY(-1px);
  border-color: var(--dw-tint-34);
  box-shadow: 0 10px 26px rgba(0, 0, 0, 0.06);
}
.dw-tile--next { background: var(--dw-tint-03); border-color: var(--dw-tint-18); }
.dw-tile-head {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.55px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.dw-tile-ico { color: var(--dw-brand); }
.dw-tile--next .dw-tile-ico { color: var(--dw-brand); }
.dw-tile-rel {
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0;
  text-transform: none;
  color: var(--dw-brand);
}
.dw-tile-pill {
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 0.64rem;
  font-weight: 800;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.65);
}
.dw-tile-big {
  margin-top: 6px;
  font-size: 1.65rem;
  font-weight: 800;
  letter-spacing: -1px;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.dw-tile-big--muted { color: rgba(var(--v-theme-on-surface), 0.3); }
.dw-tile-name {
  font-size: 0.85rem;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-tile-sub {
  font-size: 0.74rem;
  color: rgba(var(--v-theme-on-surface), 0.55);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-tile-foot { display: flex; align-items: center; gap: 8px; margin-top: 9px; }

/* ══ Quick actions ═════════════════════════════════════════════════════ */
.dw-quick { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
.dw-quick .dw-quick-btn {
  height: 32px;
  padding-inline: 12px;
  border-radius: 10px;
  border-color: rgba(var(--v-theme-on-surface), 0.12) !important;
  background: rgb(var(--v-theme-surface));
  color: rgba(var(--v-theme-on-surface), 0.78);
  font-size: 0.74rem;
  font-weight: 700;
  letter-spacing: 0.1px;
  transition: background-color 0.16s ease, border-color 0.16s ease, color 0.16s ease;
}
.dw-quick .dw-quick-btn:hover {
  background: var(--dw-tint-06);
  border-color: var(--dw-tint-34) !important;
  color: var(--dw-ink);
}

/* ══ Metric rail ═══════════════════════════════════════════════════════ */
.dw-rail {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 6px;
  margin-bottom: 16px;
  scroll-snap-type: x proximity;
  scrollbar-width: thin;
  scrollbar-color: rgba(var(--v-theme-on-surface), 0.18) transparent;
}
.dw-rail::-webkit-scrollbar { height: 5px; }
.dw-rail::-webkit-scrollbar-track { background: transparent; }
.dw-rail::-webkit-scrollbar-thumb {
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.16);
}
.dw-metric {
  flex: 0 0 auto;
  min-width: 148px;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 13px 8px 8px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgb(var(--v-theme-surface));
  font-family: inherit;
  text-align: left;
  cursor: pointer;
  scroll-snap-align: start;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.dw-metric:hover {
  transform: translateY(-1px);
  border-color: var(--dw-tint-34);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.07);
}
.dw-metric-body { display: flex; flex-direction: column; line-height: 1.15; min-width: 0; }
.dw-metric-body b {
  font-size: 1rem;
  font-weight: 800;
  letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
}
.dw-metric-body span {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.35px;
  text-transform: uppercase;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.45);
}

/* ══ Panels ════════════════════════════════════════════════════════════ */
.dw-panel {
  overflow: hidden;
  margin-bottom: 12px;
  border-radius: 16px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgb(var(--v-theme-surface));
}
.dw-panel-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.dw-panel-title {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 0.8rem;
  font-weight: 800;
  letter-spacing: -0.1px;
}
.dw-panel-ico { color: var(--dw-brand); }
.dw-panel-ico--danger { color: rgb(var(--v-theme-error)); }
.dw-panel-count {
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 0.62rem;
  font-weight: 800;
  background: var(--dw-tint-10);
  color: var(--dw-ink);
}
.dw-panel-hint {
  margin-left: auto;
  font-size: 0.68rem;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.dw-toggle { margin-left: auto; }

/* ══ Agenda ════════════════════════════════════════════════════════════ */
.dw-agenda { list-style: none; margin: 0; padding: 0; }
.dw-agenda-row {
  display: grid;
  grid-template-columns: 58px 14px minmax(0, 1fr) auto 28px;
  align-items: center;
  gap: 10px;
  padding: 9px 12px 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  transition: background-color 0.15s ease;
}
.dw-agenda-row:last-child { border-bottom: 0; }
.dw-agenda-row:hover { background: var(--dw-tint-03); }
.dw-agenda-time { display: flex; flex-direction: column; line-height: 1.15; }
.dw-agenda-time b { font-size: 0.8rem; font-weight: 800; font-variant-numeric: tabular-nums; }
.dw-agenda-time span { font-size: 0.6rem; font-weight: 600; color: rgba(var(--v-theme-on-surface), 0.4); }
.dw-agenda-rail { position: relative; align-self: stretch; display: grid; place-items: center; }
.dw-agenda-rail::before {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  width: 1px;
  background: rgba(var(--v-theme-on-surface), 0.1);
}
.dw-agenda-rail span {
  position: relative;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--dw-brand);
  box-shadow: 0 0 0 3px var(--dw-tint-10);
}
.dw-agenda-row.is-completed .dw-agenda-rail span {
  background: rgb(var(--v-theme-success));
  box-shadow: 0 0 0 3px rgba(var(--v-theme-success), 0.12);
}
.dw-agenda-row.is-cancelled .dw-agenda-rail span,
.dw-agenda-row.is-no_show .dw-agenda-rail span {
  background: rgb(var(--v-theme-error));
  box-shadow: 0 0 0 3px rgba(var(--v-theme-error), 0.12);
}
.dw-agenda-body { min-width: 0; }
.dw-agenda-name {
  font-size: 0.82rem;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-agenda-sub {
  font-size: 0.72rem;
  color: rgba(var(--v-theme-on-surface), 0.5);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-agenda-side { display: flex; align-items: center; gap: 8px; }
.dw-rel {
  font-size: 0.64rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.dw-agenda-go { opacity: 0; transition: opacity 0.15s ease, background-color 0.15s ease; }
.dw-agenda-row:hover .dw-agenda-go { opacity: 1; background: var(--dw-tint-10); }

/* ══ Lists ═════════════════════════════════════════════════════════════ */
.dw-list { list-style: none; margin: 0; padding: 0; }
.dw-list-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  cursor: pointer;
  transition: background-color 0.15s ease;
}
.dw-list-row:last-child { border-bottom: 0; }
.dw-list-row:hover { background: var(--dw-tint-03); }
.dw-list-body { min-width: 0; flex: 1; }
.dw-list-name {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 0.78rem;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-list-sub {
  font-size: 0.7rem;
  color: rgba(var(--v-theme-on-surface), 0.5);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-list-time {
  font-size: 0.64rem;
  font-weight: 700;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.38);
}
.dw-list-chevron { color: rgba(var(--v-theme-on-surface), 0.3); }
.dw-msg-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgb(var(--v-theme-error));
}

/* ══ Waiting room ══════════════════════════════════════════════════════ */
.dw-queue-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  border-left: 3px solid transparent;
  cursor: pointer;
  transition: background-color 0.15s ease;
}
.dw-queue-row:last-child { border-bottom: 0; }
.dw-queue-row:hover { background: rgba(var(--v-theme-error), 0.04); }
.dw-queue-row.esi-1 { border-left-color: rgb(var(--v-theme-error)); }
.dw-queue-row.esi-2 { border-left-color: #f57c00; }
.dw-queue-row.esi-3 { border-left-color: #fbc02d; }
.dw-queue-row.esi-4 { border-left-color: #66bb6a; }
.dw-queue-row.esi-5 { border-left-color: #90a4ae; }
.dw-esi {
  flex: 0 0 auto;
  width: 22px;
  height: 22px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  font-size: 0.68rem;
  font-weight: 800;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.dw-alert {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 10px 14px 0;
  padding: 7px 10px;
  border-radius: 10px;
  font-size: 0.72rem;
  font-weight: 700;
  background: rgba(var(--v-theme-error), 0.08);
  color: rgb(var(--v-theme-error));
}

/* ══ Doctor handoff queue (assigned via triage) ════════════════════════ */
.dw-handoff { list-style: none; margin: 0; padding: 0; }
.dw-handoff-row {
  display: grid;
  grid-template-columns: 26px minmax(0, 1fr) auto auto;
  align-items: center;
  gap: 11px;
  padding: 10px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  border-left: 3px solid transparent;
  transition: background-color 0.15s ease;
}
.dw-handoff-row:last-child { border-bottom: 0; }
.dw-handoff-row:hover { background: var(--dw-tint-03); }
.dw-handoff-row.esi-1 { border-left-color: rgb(var(--v-theme-error)); }
.dw-handoff-row.esi-2 { border-left-color: #f57c00; }
.dw-handoff-row.esi-3 { border-left-color: #fbc02d; }
.dw-handoff-row.esi-4 { border-left-color: #66bb6a; }
.dw-handoff-row.esi-5 { border-left-color: #90a4ae; }

.dw-handoff-esi {
  display: grid;
  place-items: center;
  width: 26px;
  height: 26px;
  border-radius: 9px;
  font-size: 0.72rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.dw-handoff-esi.is-esi-1 { background: rgba(var(--v-theme-error), 0.16); color: rgb(var(--v-theme-error)); }
.dw-handoff-esi.is-esi-2 { background: rgba(245, 124, 0, 0.16); color: #ef6c00; }
.dw-handoff-esi.is-esi-3 { background: rgba(251, 192, 45, 0.2); color: #f9a825; }
.dw-handoff-esi.is-esi-4 { background: rgba(102, 187, 106, 0.16); color: #43a047; }
.dw-handoff-esi.is-esi-5 { background: rgba(144, 164, 174, 0.18); color: #607d8b; }

.dw-handoff-body { min-width: 0; }
.dw-handoff-name {
  display: flex;
  align-items: baseline;
  gap: 7px;
  font-size: 0.82rem;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-handoff-mrn {
  font-size: 0.62rem;
  font-weight: 700;
  letter-spacing: 0.3px;
  color: rgba(var(--v-theme-on-surface), 0.35);
}
.dw-handoff-sub {
  font-size: 0.72rem;
  color: rgba(var(--v-theme-on-surface), 0.55);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dw-handoff-meta {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-top: 2px;
  font-size: 0.62rem;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.dw-handoff-news {
  padding: 0 5px;
  border-radius: 5px;
  font-weight: 800;
  background: rgba(var(--v-theme-warning), 0.16);
  color: rgb(var(--v-theme-warning));
}

/* Live wait clock — ticks every second so the queue visibly ages. */
.dw-handoff-wait {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  line-height: 1.1;
  min-width: 62px;
}
.dw-wait-clock {
  font-size: 0.88rem;
  font-weight: 800;
  letter-spacing: -0.3px;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.dw-wait-clock.is-fresh { color: rgb(var(--v-theme-success)); }
.dw-wait-clock.is-warn { color: rgb(var(--v-theme-warning)); }
.dw-wait-clock.is-late {
  color: rgb(var(--v-theme-error));
  animation: dw-wait-pulse 2.4s ease-in-out infinite;
}
@keyframes dw-wait-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.55; }
}
.dw-wait-unit {
  font-size: 0.54rem;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.35);
}
.dw-handoff-actions { display: flex; align-items: center; gap: 4px; }

.dw-panel-count.is-live {
  background: rgba(var(--v-theme-error), 0.12);
  color: rgb(var(--v-theme-error));
}

@media (prefers-reduced-motion: reduce) {
  .dw-wait-clock.is-late { animation: none; }
}

/* ══ Charts ════════════════════════════════════════════════════════════ */
.dw-bars {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  height: 88px;
  padding: 12px 14px 0;
}
.dw-bar-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 3px;
  height: 100%;
}
.dw-bar-value {
  font-size: 0.6rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.dw-bar-track { width: 100%; flex: 1; display: flex; align-items: flex-end; }
.dw-bar-fill {
  width: 100%;
  border-radius: 5px 5px 2px 2px;
  background: var(--dw-tint-18);
  transition: height 0.35s cubic-bezier(0.4, 0, 0.2, 1), background-color 0.2s ease;
}
.dw-bar-fill.is-today { background: var(--dw-brand); }
.dw-bar-label {
  font-size: 0.58rem;
  font-weight: 800;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.35);
}
.dw-bar-label.is-today { color: var(--dw-ink); }

.dw-facts {
  display: flex;
  gap: 6px;
  padding: 10px 14px 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.dw-facts > div { flex: 1; display: flex; flex-direction: column; align-items: center; line-height: 1.2; }
.dw-facts b { font-size: 0.82rem; font-weight: 800; font-variant-numeric: tabular-nums; }
.dw-facts span {
  font-size: 0.56rem;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

/* ══ Commission ════════════════════════════════════════════════════════ */
.dw-earn {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 10px;
  padding: 12px 14px 4px;
}
.dw-earn-main { display: flex; flex-direction: column; line-height: 1.15; }
.dw-earn-label {
  font-size: 0.58rem;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.dw-earn-value { font-size: 1.35rem; font-weight: 800; letter-spacing: -1px; }
.dw-spark {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  height: 52px;
  padding: 4px 14px 0;
}
.dw-spark-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
  height: 100%;
}
.dw-spark-col > span {
  font-size: 0.54rem;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.35);
}
.dw-spark-track { width: 100%; flex: 1; display: flex; align-items: flex-end; }
.dw-spark-fill {
  width: 100%;
  border-radius: 3px 3px 1px 1px;
  background: var(--dw-accent-12);
}

/* ══ Profile readiness ═════════════════════════════════════════════════ */
.dw-ready { display: flex; align-items: center; gap: 14px; padding: 12px 14px; }
.dw-ready-pct { font-size: 0.82rem; font-weight: 800; letter-spacing: -0.4px; }
.dw-ready-pct i { font-style: normal; font-size: 0.56rem; opacity: 0.6; }
.dw-ready-body { min-width: 0; }
.dw-ready-title { font-size: 0.8rem; font-weight: 700; }
.dw-ready-sub { font-size: 0.7rem; color: rgba(var(--v-theme-on-surface), 0.5); }
.dw-checks {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 5px;
  margin: 0;
  padding: 0 14px 12px;
}
.dw-checks li {
  display: grid;
  grid-template-columns: 14px auto minmax(0, 1fr);
  align-items: center;
  gap: 7px;
  font-size: 0.72rem;
}
.dw-checks li .v-icon { color: rgba(var(--v-theme-on-surface), 0.25); }
.dw-checks li.is-done .v-icon { color: rgb(var(--v-theme-success)); }
.dw-check-label { font-weight: 700; color: rgba(var(--v-theme-on-surface), 0.72); }
.dw-checks li.is-done .dw-check-label { color: rgba(var(--v-theme-on-surface), 0.5); }
.dw-check-hint {
  text-align: right;
  font-size: 0.64rem;
  color: rgba(var(--v-theme-on-surface), 0.4);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ══ States ════════════════════════════════════════════════════════════ */
.dw-loading { display: grid; place-items: center; padding: 22px; }
.dw-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 22px 14px;
  font-size: 0.76rem;
  font-weight: 600;
  text-align: center;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.dw-empty .v-icon { color: rgba(var(--v-theme-on-surface), 0.28); }
.dw-empty-hint {
  max-width: 30ch;
  font-size: 0.68rem;
  font-weight: 500;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.38);
}
.dw-empty--ok { color: rgba(var(--v-theme-success), 0.9); }
.dw-empty--ok .v-icon { color: rgb(var(--v-theme-success)); }

/* ══ Entrance ══════════════════════════════════════════════════════════ */
.dw-head, .dw-attn, .dw-quick, .dw-rail, .dw-panel {
  animation: dw-in 0.32s ease both;
}
.dw-attn { animation-delay: 0.04s; }
.dw-quick { animation-delay: 0.07s; }
.dw-rail { animation-delay: 0.1s; }
@keyframes dw-in {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: none; }
}
@media (prefers-reduced-motion: reduce) {
  .dw-head, .dw-attn, .dw-quick, .dw-rail, .dw-panel { animation: none; }
  .dw-tile:hover, .dw-metric:hover { transform: none; }
}

/* ══ Responsive ════════════════════════════════════════════════════════ */
@media (max-width: 960px) {
  .dw-attn { grid-template-columns: 1fr; }
  .dw-head-actions { width: 100%; justify-content: space-between; }
}
@media (max-width: 600px) {
  .dw-agenda-row { grid-template-columns: 52px 12px minmax(0, 1fr) 26px; }
  .dw-agenda-side { display: none; }
  .dw-tile-big { font-size: 1.4rem; }
  .dw-handoff-row { grid-template-columns: 26px minmax(0, 1fr) auto; }
  .dw-handoff-actions { grid-column: 2 / -1; justify-content: flex-end; }
}
</style>
