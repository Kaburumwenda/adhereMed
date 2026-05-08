<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      :title="`Welcome back, ${auth.user?.first_name || 'Care team'}`"
      :subtitle="`Live operations across your homecare network · ${activeCount} patients in care`"
      eyebrow="HOMECARE COMMAND CENTRE"
      icon="mdi-home-heart"
      :chips="heroChips"
    >
      <template #actions>
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
      </template>
    </HomecareHero>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="12" sm="6" md="4" lg>
        <HomecareKpiCard v-bind="k" />
      </v-col>
    </v-row>

    <!-- Main grid -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <HomecarePanel
          title="7-day medication adherence"
          subtitle="Doses taken on time across all patients"
          icon="mdi-chart-line"
          color="#0d9488"
        >
          <template #actions>
            <v-chip size="small" color="teal" variant="tonal" class="font-weight-bold">
              {{ summary?.kpis?.adherence_today != null ? summary.kpis.adherence_today + '% today' : '—' }}
            </v-chip>
          </template>
          <BarChart :values="trendValues" :labels="trendLabels" color="#0d9488" :height="240" />
          <div class="d-flex flex-wrap ga-3 mt-4">
            <div class="hc-mini-stat">
              <span class="hc-dot" style="background:#10b981"></span>
              <span class="text-caption text-medium-emphasis">Avg 7d</span>
              <span class="text-body-2 font-weight-bold ml-1">{{ avgAdherence }}%</span>
            </div>
            <div class="hc-mini-stat">
              <span class="hc-dot" style="background:#0ea5e9"></span>
              <span class="text-caption text-medium-emphasis">Best day</span>
              <span class="text-body-2 font-weight-bold ml-1">{{ bestAdherence }}%</span>
            </div>
            <div class="hc-mini-stat">
              <span class="hc-dot" style="background:#f59e0b"></span>
              <span class="text-caption text-medium-emphasis">Worst day</span>
              <span class="text-body-2 font-weight-bold ml-1">{{ worstAdherence }}%</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel
          title="Today's doses"
          subtitle="Live medication tracking"
          icon="mdi-pill"
          color="#0ea5e9"
        >
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="doseSegments" :size="200" :thickness="22">
              <div class="text-center">
                <div class="text-h3 font-weight-bold">{{ summary?.today_doses?.total || 0 }}</div>
                <div class="text-caption text-medium-emphasis">doses</div>
              </div>
            </DonutRing>
          </div>
          <div class="hc-dose-legend">
            <div v-for="s in doseSegments" :key="s.label" class="hc-dose-row">
              <span class="hc-dot" :style="`background:${dotHex(s.color)}`"></span>
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <v-col cols="12" md="6">
        <HomecarePanel
          title="Open escalations"
          subtitle="Patients flagged for clinical review"
          icon="mdi-alert-octagram"
          color="#ef4444"
        >
          <template #actions>
            <v-btn size="small" variant="text" color="teal" to="/homecare/escalations" append-icon="mdi-arrow-right">
              View all
            </v-btn>
          </template>
          <div v-if="summary?.recent_escalations?.length" class="hc-list">
            <div v-for="e in summary.recent_escalations.slice(0, 5)" :key="e.id"
                 class="hc-list-row" @click="$router.push('/homecare/escalations')">
              <div class="hc-list-leading" :style="`background: ${severityColor(e.severity)}1a; color: ${severityColor(e.severity)}`">
                <v-icon icon="mdi-alert" size="18" />
              </div>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-bold text-truncate">{{ e.reason }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ e.patient_name }} · {{ formatRelative(e.triggered_at) }}
                </div>
              </div>
              <StatusChip :status="e.severity" />
            </div>
          </div>
          <EmptyState v-else icon="mdi-shield-check" title="All clear"
                      message="No active escalations. Your patients are stable." />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="6">
        <HomecarePanel
          title="Upcoming visits"
          subtitle="Next caregiver shifts"
          icon="mdi-calendar-clock"
          color="#0d9488"
        >
          <template #actions>
            <v-btn size="small" variant="text" color="teal" to="/homecare/calendar" append-icon="mdi-arrow-right">
              Calendar
            </v-btn>
          </template>
          <div v-if="summary?.upcoming_visits?.length" class="hc-list">
            <div v-for="v in summary.upcoming_visits.slice(0, 5)" :key="v.id" class="hc-list-row">
              <div class="hc-list-leading" style="background:#0d948814;color:#0d9488;">
                <span class="text-caption font-weight-bold">{{ formatTime(v.start_at) }}</span>
              </div>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-bold text-truncate">{{ v.patient_name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ v.caregiver_name }}</div>
              </div>
              <StatusChip :status="v.status" />
            </div>
          </div>
          <EmptyState v-else icon="mdi-calendar-blank" title="No upcoming visits" />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Caregivers + activity -->
    <v-row class="mt-1">
      <v-col cols="12" md="7">
        <HomecarePanel
          title="Caregiver workforce"
          subtitle="Field team status"
          icon="mdi-account-heart"
          color="#6366f1"
        >
          <template #actions>
            <v-btn size="small" variant="text" color="teal" to="/homecare/caregivers" append-icon="mdi-arrow-right">
              Manage
            </v-btn>
          </template>
          <v-row dense>
            <v-col cols="6" sm="3">
              <div class="hc-cg-stat">
                <div class="text-h5 font-weight-bold text-teal">{{ summary?.kpis?.caregivers_on_duty ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">On duty</div>
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="hc-cg-stat">
                <div class="text-h5 font-weight-bold">{{ summary?.kpis?.caregivers_total ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">Total team</div>
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="hc-cg-stat">
                <div class="text-h5 font-weight-bold text-success">{{ summary?.kpis?.visits_completed_today ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">Visits done</div>
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="hc-cg-stat">
                <div class="text-h5 font-weight-bold text-amber">{{ summary?.kpis?.avg_rating ?? '—' }}</div>
                <div class="text-caption text-medium-emphasis">Avg rating</div>
              </div>
            </v-col>
          </v-row>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="5">
        <HomecarePanel
          title="Live activity"
          subtitle="Last 24 hours"
          icon="mdi-pulse"
          color="#8b5cf6"
        >
          <div v-if="activity.length" class="hc-list">
            <div v-for="a in activity.slice(0, 6)" :key="a.id" class="hc-list-row">
              <div class="hc-list-leading" :style="`background:${eventColor(a.type)}1a;color:${eventColor(a.type)}`">
                <v-icon :icon="eventIcon(a.type)" size="18" />
              </div>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ a.title }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ a.message }}</div>
              </div>
              <span class="text-caption text-medium-emphasis">{{ formatRelative(a.created_at) }}</span>
            </div>
          </div>
          <EmptyState v-else icon="mdi-pulse" title="Quiet for now" message="Live events will appear here." />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Quick actions grid -->
    <h3 class="text-subtitle-1 font-weight-bold mt-6 mb-3">
      <v-icon icon="mdi-flash" color="teal" class="mr-1" />
      Quick actions
    </h3>
    <v-row dense>
      <v-col v-for="a in quickActions" :key="a.label" cols="6" sm="4" md="3" lg="2">
        <QuickActionTile v-bind="a" />
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="4000">
      {{ snack.text }}
    </v-snackbar>
  </div>
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
  const trend = summary.value?.adherence_trend || []
  return [
    { label: 'Active patients', value: k.active_patients ?? 0, icon: 'mdi-account-multiple',
      color: '#0d9488', to: '/homecare/patients', hint: 'In active care' },
    { label: 'Caregivers on duty', value: k.caregivers_on_duty ?? 0, suffix: `/ ${k.caregivers_total ?? 0}`,
      icon: 'mdi-account-heart', color: '#6366f1', to: '/homecare/caregivers' },
    { label: 'Adherence today', value: k.adherence_today != null ? k.adherence_today + '%' : '—',
      icon: 'mdi-pill', color: '#10b981', spark: trend.map(d => d.rate),
      trend: adherenceDelta.value, trendLabel: 'vs yesterday' },
    { label: 'Open escalations', value: k.open_escalations ?? 0, icon: 'mdi-alert-octagram',
      color: '#ef4444', to: '/homecare/escalations', hint: 'Needs review' },
    { label: 'Insurance claims', value: k.open_claims ?? 0, icon: 'mdi-shield-account',
      color: '#f59e0b', to: '/homecare/insurance', hint: 'Pending submission' }
  ]
})

const trendValues = computed(() => (summary.value?.adherence_trend || []).map(d => d.rate))
const trendLabels = computed(() => (summary.value?.adherence_trend || []).map(d => d.date.slice(5)))
const avgAdherence = computed(() => {
  const v = trendValues.value
  return v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length) : 0
})
const bestAdherence = computed(() => trendValues.value.length ? Math.max(...trendValues.value) : 0)
const worstAdherence = computed(() => trendValues.value.length ? Math.min(...trendValues.value) : 0)
const adherenceDelta = computed(() => {
  const v = trendValues.value
  if (v.length < 2) return null
  return v[v.length - 1] - v[v.length - 2]
})

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
  { icon: 'mdi-account-plus', label: 'Enrol patient', hint: 'Onboard new patient', to: '/homecare/patients/new', color: '#0d9488' },
  { icon: 'mdi-calendar-plus', label: 'Schedule visit', hint: 'Assign caregiver', to: '/homecare/schedules', color: '#6366f1' },
  { icon: 'mdi-pill-multiple', label: "Today's doses", hint: 'Track medication', to: '/homecare/doses', color: '#10b981' },
  { icon: 'mdi-video-plus', label: 'Teleconsult', hint: 'Doctor visit', to: '/homecare/teleconsult', color: '#0ea5e9' },
  { icon: 'mdi-prescription', label: 'Prescriptions', hint: 'Forward to pharmacy', to: '/homecare/prescriptions', color: '#8b5cf6' },
  { icon: 'mdi-heart-pulse', label: 'Vitals', hint: 'Record observations', to: '/homecare/vitals', color: '#ef4444' },
  { icon: 'mdi-shield-plus', label: 'Insurance', hint: 'Claims & policies', to: '/homecare/insurance', color: '#f59e0b' },
  { icon: 'mdi-file-document-plus', label: 'Consents', hint: 'Capture authorisation', to: '/homecare/consents', color: '#14b8a6' },
  { icon: 'mdi-account-multiple-plus', label: 'Family portal', hint: 'Invite family', to: '/homecare/family', color: '#ec4899' },
  { icon: 'mdi-cash-register', label: 'Billing', hint: 'Invoices & payments', to: '/homecare/billing', color: '#0284c7' },
  { icon: 'mdi-medical-bag', label: 'Equipment', hint: 'Loan tracking', to: '/homecare/equipment', color: '#7c3aed' },
  { icon: 'mdi-chart-box', label: 'Reports', hint: 'Analytics', to: '/homecare/reports', color: '#475569' }
]

function dotHex(c) {
  return { success: '#10b981', info: '#0ea5e9', error: '#ef4444', grey: '#94a3b8' }[c] || c
}
function severityColor(s) {
  return { critical: '#dc2626', high: '#ef4444', medium: '#f59e0b', low: '#0ea5e9' }[s] || '#64748b'
}
function eventColor(t) {
  return { dose_missed: '#ef4444', escalation: '#dc2626', dose_taken: '#10b981',
    visit_started: '#0d9488', visit_completed: '#0ea5e9', vitals: '#8b5cf6' }[t] || '#64748b'
}
function eventIcon(t) {
  return { dose_missed: 'mdi-pill-off', escalation: 'mdi-alert-octagram',
    dose_taken: 'mdi-pill', visit_started: 'mdi-login', visit_completed: 'mdi-check-circle',
    vitals: 'mdi-heart-pulse' }[t] || 'mdi-bell'
}
function formatTime(iso) {
  return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''
}
function formatRelative(iso) {
  if (!iso) return ''
  const diff = (Date.now() - new Date(iso).getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return `${Math.floor(diff / 86400)}d ago`
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/dashboard/summary/')
    summary.value = data
  } catch {
    snack.text = 'Failed to load dashboard'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

onMounted(load)

useHomecareEvents((evt) => {
  activity.value = [{ id: evt.id, title: evt.title, message: evt.message,
                      type: evt.type, created_at: evt.created_at }, ...activity.value].slice(0, 50)
  snack.text = evt.title || 'New homecare event'
  snack.color = 'info'
  snack.show = true
  load()
})
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: calc(100vh - 64px);
}
.hc-mini-stat {
  display: inline-flex; align-items: center;
  padding: 4px 10px; border-radius: 999px;
  background: rgba(15,23,42,0.04);
}
.hc-dot {
  display: inline-block; width: 8px; height: 8px;
  border-radius: 50%; margin-right: 6px;
}
.hc-dose-legend { display: flex; flex-direction: column; gap: 8px; }
.hc-dose-row {
  display: flex; align-items: center;
  padding: 8px 12px; border-radius: 10px;
  background: rgba(15,23,42,0.03);
}
.hc-list { display: flex; flex-direction: column; gap: 8px; }
.hc-list-row {
  display: flex; align-items: center; gap: 12px;
  padding: 10px 12px; border-radius: 12px;
  background: rgba(15,23,42,0.025);
  transition: background 0.15s ease;
  cursor: pointer;
}
.hc-list-row:hover { background: rgba(13,148,136,0.07); }
.hc-list-leading {
  width: 38px; height: 38px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.hc-cg-stat {
  text-align: center; padding: 12px;
  background: rgba(15,23,42,0.025); border-radius: 12px;
}
.min-w-0 { min-width: 0; }
</style>
