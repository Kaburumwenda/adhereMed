<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Hero banner -->
    <div class="hcd-hero pa-5 pa-md-7 mb-5">
      <div style="position:relative;z-index:2;">
        <div class="d-flex align-center flex-wrap ga-4">
          <div class="flex-grow-1">
            <div class="d-flex align-center mb-2">
              <v-avatar size="46" style="background:rgba(255,255,255,0.18);backdrop-filter:blur(12px);border:1px solid rgba(255,255,255,0.28);" class="mr-3">
                <v-icon icon="mdi-home-heart" color="white" />
              </v-avatar>
              <div>
                <div class="text-overline" style="color:rgba(255,255,255,0.82)">HOMECARE COMMAND CENTRE</div>
                <h1 class="text-h4 text-md-h3 font-weight-bold text-white ma-0">
                  Welcome back, {{ auth.user?.first_name || 'Care team' }}
                </h1>
              </div>
            </div>
            <p class="text-body-1 mb-4 mt-2" style="color:rgba(255,255,255,0.82)">
              Live operations across your homecare network · {{ activeCount }} patients in care
            </p>
            <div class="d-flex flex-wrap ga-2">
              <v-chip v-for="c in heroChips" :key="c.label" size="small"
                      color="rgba(255,255,255,0.18)" variant="flat" class="text-white">
                <v-icon :icon="c.icon" size="14" class="mr-1" />{{ c.label }}
              </v-chip>
            </div>
          </div>
          <div class="d-flex flex-column align-end ga-2">
            <div class="d-flex ga-2">
              <v-btn variant="flat" rounded="pill" prepend-icon="mdi-refresh" class="text-none"
                     color="rgba(255,255,255,0.18)" :loading="loading" @click="load">
                <span class="text-white">Refresh</span>
              </v-btn>
              <v-btn variant="flat" rounded="pill" prepend-icon="mdi-account-plus" class="text-none"
                     color="white" to="/homecare/patients/new">
                <span class="text-teal-darken-2 font-weight-bold">Enrol patient</span>
              </v-btn>
            </div>
            <div class="hcd-clock">
              <v-icon icon="mdi-clock-outline" size="14" class="mr-1" />{{ clock }}
            </div>
          </div>
        </div>
      </div>
      <div class="hcd-hero-decor"></div>
    </div>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="12" sm="6" md="4" lg>
        <v-card rounded="xl" class="pa-4" :to="k.to" hover>
          <div class="d-flex align-start">
            <v-avatar size="44" rounded="lg" :style="{ background: `linear-gradient(135deg,${k.color},${k.color}cc)` }">
              <v-icon :icon="k.icon" color="white" size="22" />
            </v-avatar>
            <div class="ml-3 flex-grow-1">
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">{{ k.label }}</div>
              <div class="d-flex align-baseline ga-2 mt-1">
                <span class="text-h4 font-weight-bold">{{ k.value }}</span>
                <span v-if="k.suffix" class="text-body-2 text-medium-emphasis">{{ k.suffix }}</span>
              </div>
              <div v-if="k.hint" class="text-caption text-medium-emphasis mt-1">{{ k.hint }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Charts row -->
    <v-row class="mt-3">
      <v-col cols="12" lg="8">
        <v-card rounded="xl" class="pa-5">
          <div class="d-flex align-center mb-4">
            <v-avatar size="36" rounded="lg" style="background:linear-gradient(135deg,#0d9488,#0d9488cc);" class="mr-3">
              <v-icon icon="mdi-chart-line" color="white" size="18" />
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold ma-0">7-day medication adherence</h3>
              <div class="text-caption text-medium-emphasis">Doses taken on time across all patients</div>
            </div>
            <v-chip size="small" color="teal" variant="tonal" class="font-weight-bold">
              {{ summary?.kpis?.adherence_today != null ? summary.kpis.adherence_today + '% today' : '—' }}
            </v-chip>
          </div>
          <BarChart :values="trendValues" :labels="trendLabels" color="#0d9488" :height="240" />
          <div class="d-flex flex-wrap ga-3 mt-4">
            <v-chip variant="tonal" size="small" color="success">Avg 7d: {{ avgAdherence }}%</v-chip>
            <v-chip variant="tonal" size="small" color="info">Best: {{ bestAdherence }}%</v-chip>
            <v-chip variant="tonal" size="small" color="warning">Worst: {{ worstAdherence }}%</v-chip>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" class="pa-5 h-100">
          <div class="d-flex align-center mb-4">
            <v-avatar size="36" rounded="lg" style="background:linear-gradient(135deg,#0ea5e9,#0ea5e9cc);" class="mr-3">
              <v-icon icon="mdi-pill" color="white" size="18" />
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Today's doses</h3>
              <div class="text-caption text-medium-emphasis">Live medication tracking</div>
            </div>
          </div>
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="doseSegments" :size="180" :thickness="20">
              <div class="text-center">
                <div class="text-h4 font-weight-bold">{{ summary?.today_doses?.total || 0 }}</div>
                <div class="text-caption text-medium-emphasis">doses</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-2">
            <div v-for="s in doseSegments" :key="s.label" class="d-flex align-center px-3 py-2 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="10" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Escalations + Visits -->
    <v-row class="mt-3">
      <v-col cols="12" md="6">
        <v-card rounded="xl" class="pa-5 h-100">
          <div class="d-flex align-center mb-4">
            <v-avatar size="36" rounded="lg" style="background:linear-gradient(135deg,#ef4444,#ef4444cc);" class="mr-3">
              <v-icon icon="mdi-alert-octagram" color="white" size="18" />
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Open escalations</h3>
              <div class="text-caption text-medium-emphasis">Patients flagged for review</div>
            </div>
            <v-btn size="small" variant="text" color="teal" to="/homecare/escalations" append-icon="mdi-arrow-right" class="text-none">View all</v-btn>
          </div>
          <div v-if="summary?.recent_escalations?.length" class="d-flex flex-column ga-2">
            <v-card v-for="e in summary.recent_escalations.slice(0, 5)" :key="e.id"
                    variant="tonal" rounded="lg" class="pa-3 cursor-pointer"
                    @click="$router.push('/homecare/escalations')">
              <div class="d-flex align-center ga-3">
                <v-avatar size="36" :color="severityColor(e.severity)" variant="tonal">
                  <v-icon icon="mdi-alert" size="18" />
                </v-avatar>
                <div class="flex-grow-1" style="min-width:0;">
                  <div class="text-body-2 font-weight-bold text-truncate">{{ e.reason }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">{{ e.patient_name }} · {{ formatRelative(e.triggered_at) }}</div>
                </div>
                <v-chip size="x-small" :color="severityColor(e.severity)" variant="flat">{{ e.severity }}</v-chip>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-shield-check" title="All clear" message="No active escalations." />
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="xl" class="pa-5 h-100">
          <div class="d-flex align-center mb-4">
            <v-avatar size="36" rounded="lg" style="background:linear-gradient(135deg,#0d9488,#0d9488cc);" class="mr-3">
              <v-icon icon="mdi-calendar-clock" color="white" size="18" />
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Upcoming visits</h3>
              <div class="text-caption text-medium-emphasis">Next caregiver shifts</div>
            </div>
            <v-btn size="small" variant="text" color="teal" to="/homecare/calendar" append-icon="mdi-arrow-right" class="text-none">Calendar</v-btn>
          </div>
          <div v-if="summary?.upcoming_visits?.length" class="d-flex flex-column ga-2">
            <v-card v-for="v in summary.upcoming_visits.slice(0, 5)" :key="v.id"
                    variant="tonal" rounded="lg" class="pa-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="36" color="teal" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ formatTime(v.start_at) }}</span>
                </v-avatar>
                <div class="flex-grow-1" style="min-width:0;">
                  <div class="text-body-2 font-weight-bold text-truncate">{{ v.patient_name }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">{{ v.caregiver_name }}</div>
                </div>
                <v-chip size="x-small" variant="tonal" color="teal">{{ v.status }}</v-chip>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-calendar-blank" title="No upcoming visits" />
        </v-card>
      </v-col>
    </v-row>

    <!-- Caregivers + Activity -->
    <v-row class="mt-3">
      <v-col cols="12" md="7">
        <v-card rounded="xl" class="pa-5 h-100">
          <div class="d-flex align-center mb-4">
            <v-avatar size="36" rounded="lg" style="background:linear-gradient(135deg,#6366f1,#6366f1cc);" class="mr-3">
              <v-icon icon="mdi-account-heart" color="white" size="18" />
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Caregiver workforce</h3>
              <div class="text-caption text-medium-emphasis">Field team status</div>
            </div>
            <v-btn size="small" variant="text" color="teal" to="/homecare/caregivers" append-icon="mdi-arrow-right" class="text-none">Manage</v-btn>
          </div>
          <v-row dense>
            <v-col cols="6" sm="3">
              <v-card variant="tonal" color="teal" rounded="xl" class="pa-3 text-center">
                <div class="text-h5 font-weight-bold">{{ summary?.kpis?.caregivers_on_duty ?? 0 }}</div>
                <div class="text-caption">On duty</div>
              </v-card>
            </v-col>
            <v-col cols="6" sm="3">
              <v-card variant="outlined" rounded="xl" class="pa-3 text-center">
                <div class="text-h5 font-weight-bold">{{ summary?.kpis?.caregivers_total ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">Total</div>
              </v-card>
            </v-col>
            <v-col cols="6" sm="3">
              <v-card variant="tonal" color="success" rounded="xl" class="pa-3 text-center">
                <div class="text-h5 font-weight-bold">{{ summary?.kpis?.visits_completed_today ?? 0 }}</div>
                <div class="text-caption">Done today</div>
              </v-card>
            </v-col>
            <v-col cols="6" sm="3">
              <v-card variant="tonal" color="warning" rounded="xl" class="pa-3 text-center">
                <div class="text-h5 font-weight-bold">{{ summary?.kpis?.avg_rating ?? '—' }}</div>
                <div class="text-caption">Rating</div>
              </v-card>
            </v-col>
          </v-row>
        </v-card>
      </v-col>

      <v-col cols="12" md="5">
        <v-card rounded="xl" class="pa-5 h-100">
          <div class="d-flex align-center mb-4">
            <v-avatar size="36" rounded="lg" style="background:linear-gradient(135deg,#8b5cf6,#8b5cf6cc);" class="mr-3">
              <v-icon icon="mdi-pulse" color="white" size="18" />
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Live activity</h3>
              <div class="text-caption text-medium-emphasis">Last 24 hours</div>
            </div>
          </div>
          <div v-if="activity.length" class="d-flex flex-column ga-2">
            <div v-for="a in activity.slice(0, 6)" :key="a.id" class="d-flex align-center ga-3 pa-2 rounded-lg hcd-row">
              <v-avatar size="34" :color="eventColor(a.type)" variant="tonal">
                <v-icon :icon="eventIcon(a.type)" size="16" />
              </v-avatar>
              <div class="flex-grow-1" style="min-width:0;">
                <div class="text-body-2 font-weight-medium text-truncate">{{ a.title }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ a.message }}</div>
              </div>
              <span class="text-caption text-medium-emphasis text-no-wrap">{{ formatRelative(a.created_at) }}</span>
            </div>
          </div>
          <EmptyState v-else icon="mdi-pulse" title="Quiet for now" message="Live events will appear here." />
        </v-card>
      </v-col>
    </v-row>

    <!-- Quick actions -->
    <h3 class="text-subtitle-1 font-weight-bold mt-6 mb-3">
      <v-icon icon="mdi-flash" color="teal" class="mr-1" />Quick actions
    </h3>
    <v-row dense>
      <v-col v-for="a in quickActions" :key="a.label" cols="6" sm="4" md="3" lg="2">
        <v-card :to="a.to" rounded="xl" class="pa-4 hcd-action" hover>
          <v-avatar size="40" rounded="lg" :style="{ background: `linear-gradient(135deg,${a.color},${a.color}aa)` }" class="mb-3">
            <v-icon :icon="a.icon" color="white" />
          </v-avatar>
          <div class="text-subtitle-2 font-weight-bold">{{ a.label }}</div>
          <div v-if="a.hint" class="text-caption text-medium-emphasis">{{ a.hint }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="4000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useHomecareEvents } from '~/composables/useHomecare'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const summary = ref(null)
const activity = ref([])
const loading = ref(false)
const snack = reactive({ show: false, color: 'info', text: '' })
const clock = ref('')
let clockTimer = null

const activeCount = computed(() => summary.value?.kpis?.active_patients || 0)

const heroChips = computed(() => {
  const k = summary.value?.kpis || {}
  return [
    { icon: 'mdi-pulse', label: `${k.caregivers_on_duty ?? 0} on duty` },
    { icon: 'mdi-pill', label: `${k.adherence_today ?? 0}% adherence` },
    { icon: 'mdi-alert', label: `${k.open_escalations ?? 0} alerts` }
  ]
})

const kpis = computed(() => {
  const k = summary.value?.kpis || {}
  return [
    { label: 'Active patients', value: k.active_patients ?? 0, icon: 'mdi-account-multiple', color: '#0d9488', to: '/homecare/patients', hint: 'In active care' },
    { label: 'Caregivers on duty', value: k.caregivers_on_duty ?? 0, suffix: `/ ${k.caregivers_total ?? 0}`, icon: 'mdi-account-heart', color: '#6366f1', to: '/homecare/caregivers' },
    { label: 'Adherence today', value: k.adherence_today != null ? k.adherence_today + '%' : '—', icon: 'mdi-pill', color: '#10b981' },
    { label: 'Open escalations', value: k.open_escalations ?? 0, icon: 'mdi-alert-octagram', color: '#ef4444', to: '/homecare/escalations', hint: 'Needs review' },
    { label: 'Insurance claims', value: k.open_claims ?? 0, icon: 'mdi-shield-account', color: '#f59e0b', to: '/homecare/insurance', hint: 'Pending' }
  ]
})

const trendValues = computed(() => (summary.value?.adherence_trend || []).map(d => d.rate))
const trendLabels = computed(() => (summary.value?.adherence_trend || []).map(d => d.date.slice(5)))
const avgAdherence = computed(() => { const v = trendValues.value; return v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length) : 0 })
const bestAdherence = computed(() => trendValues.value.length ? Math.max(...trendValues.value) : 0)
const worstAdherence = computed(() => trendValues.value.length ? Math.min(...trendValues.value) : 0)

const doseSegments = computed(() => {
  const t = summary.value?.today_doses || {}
  return [
    { label: 'Taken', value: t.taken || 0, color: 'success' },
    { label: 'Pending', value: t.pending || 0, color: 'info' },
    { label: 'Missed', value: t.missed || 0, color: 'error' },
    { label: 'Skipped', value: t.skipped || 0, color: 'grey' }
  ]
})

const quickActions = [
  { icon: 'mdi-account-plus', label: 'Enrol patient', hint: 'Onboard new', to: '/homecare/patients/new', color: '#0d9488' },
  { icon: 'mdi-calendar-plus', label: 'Schedule visit', hint: 'Assign caregiver', to: '/homecare/schedules', color: '#6366f1' },
  { icon: 'mdi-pill-multiple', label: "Today's doses", hint: 'Track meds', to: '/homecare/doses', color: '#10b981' },
  { icon: 'mdi-video-plus', label: 'Teleconsult', hint: 'Doctor visit', to: '/homecare/teleconsult', color: '#0ea5e9' },
  { icon: 'mdi-prescription', label: 'Prescriptions', hint: 'Pharmacy', to: '/homecare/prescriptions', color: '#8b5cf6' },
  { icon: 'mdi-heart-pulse', label: 'Vitals', hint: 'Observations', to: '/homecare/vitals', color: '#ef4444' },
  { icon: 'mdi-shield-plus', label: 'Insurance', hint: 'Claims', to: '/homecare/insurance', color: '#f59e0b' },
  { icon: 'mdi-file-document-plus', label: 'Consents', hint: 'Authorisation', to: '/homecare/consents', color: '#14b8a6' },
  { icon: 'mdi-cash-register', label: 'Billing', hint: 'Invoices', to: '/homecare/billing', color: '#0284c7' },
  { icon: 'mdi-medical-bag', label: 'Equipment', hint: 'Loan tracking', to: '/homecare/equipment', color: '#7c3aed' },
  { icon: 'mdi-clipboard-pulse', label: 'Care pathways', hint: 'Protocols', to: '/homecare/care-pathways', color: '#0d9488' },
  { icon: 'mdi-email-multiple', label: 'Mail', hint: 'Team mailbox', to: '/homecare/mail', color: '#0ea5e9' },
  { icon: 'mdi-chart-box', label: 'Reports', hint: 'Analytics', to: '/homecare/reports', color: '#475569' }
]

function severityColor(s) { return { critical: 'error', high: 'error', medium: 'warning', low: 'info' }[s] || 'grey' }
function eventColor(t) { return { dose_missed: 'error', escalation: 'error', dose_taken: 'success', visit_started: 'teal', visit_completed: 'info', vitals: 'purple' }[t] || 'grey' }
function eventIcon(t) { return { dose_missed: 'mdi-pill-off', escalation: 'mdi-alert-octagram', dose_taken: 'mdi-pill', visit_started: 'mdi-login', visit_completed: 'mdi-check-circle', vitals: 'mdi-heart-pulse' }[t] || 'mdi-bell' }
function formatTime(iso) { return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '' }
function formatRelative(iso) {
  if (!iso) return ''
  const diff = (Date.now() - new Date(iso).getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return `${Math.floor(diff / 86400)}d ago`
}
function tickClock() { clock.value = new Date().toLocaleString([], { weekday: 'short', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) }

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/dashboard/summary/')
    summary.value = data
  } catch {
    snack.text = 'Failed to load dashboard'
    snack.color = 'error'
    snack.show = true
  } finally { loading.value = false }
}

onMounted(() => { load(); tickClock(); clockTimer = setInterval(tickClock, 30000) })
onBeforeUnmount(() => { if (clockTimer) clearInterval(clockTimer) })

useHomecareEvents((evt) => {
  activity.value = [{ id: evt.id, title: evt.title, message: evt.message, type: evt.type, created_at: evt.created_at }, ...activity.value].slice(0, 50)
  snack.text = evt.title || 'New homecare event'
  snack.color = 'info'
  snack.show = true
  load()
})
</script>

<style scoped>
.hcd-hero {
  position: relative;
  border-radius: 24px;
  overflow: hidden;
  background:
    radial-gradient(circle at 0% 0%, rgba(255,255,255,0.18) 0%, transparent 45%),
    radial-gradient(circle at 100% 100%, rgba(255,255,255,0.08) 0%, transparent 50%),
    linear-gradient(135deg, #0d9488 0%, #0ea5a4 35%, #0284c7 100%);
  box-shadow: 0 18px 40px -18px rgba(13,148,136,0.55);
}
.hcd-clock {
  display: inline-flex; align-items: center;
  padding: 4px 10px; border-radius: 999px;
  background: rgba(255,255,255,0.16);
  color: white; font-size: 12px; font-weight: 500;
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,0.22);
}
.hcd-hero-decor {
  position: absolute; right: -120px; top: -120px;
  width: 360px; height: 360px; border-radius: 50%;
  background: radial-gradient(circle, rgba(255,255,255,0.12), transparent 70%);
  pointer-events: none;
}
.hcd-row { transition: background 0.15s ease; cursor: pointer; }
.hcd-row:hover { background: rgba(var(--v-theme-primary), 0.08); }
.hcd-action { transition: transform 0.18s ease; }
.hcd-action:hover { transform: translateY(-3px); }
.h-100 { height: 100%; }
.cursor-pointer { cursor: pointer; }
</style>
