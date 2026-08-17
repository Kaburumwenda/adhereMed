<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ═════════ Header Row ═════════ -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">
          Welcome back, {{ auth.user?.first_name || 'there' }}
          <v-icon color="amber" size="28">mdi-hand-wave</v-icon>
        </h1>
        <div class="text-body-2 text-medium-emphasis">
          {{ todayStr }} · {{ auth.tenantName || 'Clinic' }} live overview
        </div>
      </div>
      <div class="d-flex align-center ga-2">
        <v-btn-toggle v-model="rangeKey" mandatory density="compact" variant="outlined" divided rounded="lg">
          <v-btn v-for="r in rangeOptions" :key="r.key" :value="r.key" size="small" class="text-none px-3">
            {{ r.label }}
          </v-btn>
        </v-btn-toggle>
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
      </div>
    </div>

    <!-- ═════════ KPI Tiles ═════════ -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="4" lg="3">
        <v-card rounded="lg" variant="outlined" class="kpi-card pa-4 h-100">
          <div class="d-flex align-start justify-space-between mb-2">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">{{ k.title }}</div>
              <div class="text-h4 font-weight-bold" :class="`text-${k.color}`">{{ k.value }}</div>
            </div>
            <v-avatar :color="k.color + '-lighten-5'" variant="tonal" size="40">
              <v-icon :color="k.color" size="22">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
          <div v-if="k.sub" class="d-flex align-center ga-1">
            <v-icon size="14" :color="k.subColor || 'grey'">{{ k.subIcon || 'mdi-circle-medium' }}</v-icon>
            <span class="text-caption text-medium-emphasis">{{ k.sub }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═════════ Charts Row ═════════ -->
    <v-row dense class="mb-2">
      <!-- Appointments trend chart -->
      <v-col cols="12" lg="8">
        <v-card rounded="lg" variant="outlined" class="chart-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <span class="text-subtitle-1 font-weight-bold">Appointments & Consultations</span>
              <div class="text-caption text-medium-emphasis">Daily activity for the last 7 days</div>
            </div>
            <div class="d-flex align-center ga-3">
              <div class="d-flex align-center ga-1">
                <v-icon size="12" color="primary">mdi-circle</v-icon>
                <span class="text-caption">Appointments</span>
              </div>
              <div class="d-flex align-center ga-1">
                <v-icon size="12" color="success">mdi-circle</v-icon>
                <span class="text-caption">Consultations</span>
              </div>
            </div>
          </div>
          <!-- Custom grouped bar chart -->
          <div v-if="trendData.length" class="trend-chart-wrap">
            <svg :viewBox="`0 0 ${chartW} ${chartH}`" preserveAspectRatio="none" width="100%" :height="chartH">
              <!-- Grid lines -->
              <g>
                <line v-for="i in 4" :key="i"
                  :x1="chartPadX" :x2="chartW - chartPadX"
                  :y1="chartPadY + ((i - 1) * (chartInnerH / 3))"
                  :y2="chartPadY + ((i - 1) * (chartInnerH / 3))"
                  stroke="currentColor" stroke-opacity="0.06" stroke-width="1" />
              </g>
              <!-- Bars: 2 series per day group -->
              <g>
                <template v-for="(d, i) in trendData" :key="i">
                  <rect
                    :x="groupX(i) + 2"
                    :y="barY(d.appts)"
                    :width="barW"
                    :height="barH(d.appts)"
                    :fill="seriesColors.appts"
                    rx="4" ry="4">
                    <title>{{ d.label }} — Appointments: {{ d.appts }}</title>
                  </rect>
                  <rect
                    :x="groupX(i) + barW + 4"
                    :y="barY(d.consults)"
                    :width="barW"
                    :height="barH(d.consults)"
                    :fill="seriesColors.consults"
                    rx="4" ry="4">
                    <title>{{ d.label }} — Consultations: {{ d.consults }}</title>
                  </rect>
                </template>
              </g>
            </svg>
            <div class="d-flex justify-space-between mt-1 px-1">
              <div v-for="(d, i) in trendData" :key="i" class="text-caption text-medium-emphasis" style="flex: 1; text-align: center">
                {{ d.label }}
              </div>
            </div>
          </div>
          <div v-else class="d-flex justify-center align-center" style="height: 280px">
            <v-progress-circular indeterminate color="primary" />
          </div>
        </v-card>
      </v-col>

      <!-- Appointment status donut -->
      <v-col cols="12" lg="4">
        <v-card rounded="lg" variant="outlined" class="chart-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-subtitle-1 font-weight-bold">Appointment Status</span>
            <v-icon size="18" color="medium-emphasis">mdi-chart-donut</v-icon>
          </div>
          <div class="d-flex justify-center mb-2">
            <DonutRing v-if="apptStatusSegments.length" :segments="apptStatusSegments" :size="180" :thickness="18">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ totalCounts.appointments }}</div>
                <div class="text-caption text-medium-emphasis">Total</div>
              </div>
            </DonutRing>
            <v-progress-circular v-else indeterminate color="primary" />
          </div>
          <div class="d-flex flex-wrap justify-center ga-2">
            <div v-for="s in apptStatusSegments" :key="s.label" class="d-flex align-center ga-1">
              <v-icon size="10" :color="s.color">mdi-circle</v-icon>
              <span class="text-caption text-capitalize">{{ s.label }}</span>
              <span class="text-caption font-weight-bold">{{ s.value }}</span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═════════ Revenue + Lab Status ═════════ -->
    <v-row dense class="mb-2">
      <!-- Revenue overview -->
      <v-col cols="12" lg="8">
        <v-card rounded="lg" variant="outlined" class="chart-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <span class="text-subtitle-1 font-weight-bold">Revenue Overview</span>
              <div class="text-caption text-medium-emphasis">Invoice totals, collected, and outstanding</div>
            </div>
            <v-chip size="small" variant="tonal" color="success" class="font-weight-bold">
              {{ formatMoney(totalAmount - outstandingAmount, 'KES') }}
            </v-chip>
          </div>
          <v-row dense>
            <v-col cols="12" sm="4">
              <div class="revenue-tile pa-3 rounded-lg stat-bar-success">
                <v-icon color="success" class="mb-1">mdi-cash-multiple</v-icon>
                <div class="text-caption text-medium-emphasis">Total Billed</div>
                <div class="text-h5 font-weight-bold text-success">{{ formatMoney(totalAmount) }}</div>
              </div>
            </v-col>
            <v-col cols="12" sm="4">
              <div class="revenue-tile pa-3 rounded-lg stat-bar-primary">
                <v-icon color="primary" class="mb-1">mdi-cash-check</v-icon>
                <div class="text-caption text-medium-emphasis">Collected</div>
                <div class="text-h5 font-weight-bold text-primary">{{ formatMoney(collectedAmount) }}</div>
              </div>
            </v-col>
            <v-col cols="12" sm="4">
              <div class="revenue-tile pa-3 rounded-lg stat-bar-error">
                <v-icon color="error" class="mb-1">mdi-cash-off</v-icon>
                <div class="text-caption text-medium-emphasis">Outstanding</div>
                <div class="text-h5 font-weight-bold text-error">{{ formatMoney(outstandingAmount) }}</div>
              </div>
            </v-col>
          </v-row>
          <!-- Invoice status distribution -->
          <div class="mt-3">
            <div class="text-caption text-medium-emphasis mb-2">Invoice Status Distribution</div>
            <div class="d-flex flex-column ga-1">
              <div v-for="inv in invoiceStatusDist" :key="inv.status" class="d-flex align-center ga-2">
                <span class="text-body-2 flex-shrink-0" style="width: 100px">{{ inv.status }}</span>
                <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                  <div class="status-bar-fill rounded-pill" :style="{ width: `${inv.pct}%`, background: inv.color }" />
                </div>
                <span class="text-body-2 font-weight-bold flex-shrink-0" style="width: 32px; text-align: right">{{ inv.count }}</span>
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- Lab + Prescription status -->
      <v-col cols="12" lg="4">
        <v-card rounded="lg" variant="outlined" class="chart-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-subtitle-1 font-weight-bold">Lab & Prescriptions</span>
            <v-icon size="18" color="medium-emphasis">mdi-flask</v-icon>
          </div>
          <!-- Lab status -->
          <div class="mb-3">
            <div class="text-caption text-medium-emphasis mb-2">Lab Orders by Status</div>
            <div class="d-flex flex-wrap ga-1">
              <v-chip v-for="s in labStatusDist" :key="s.status" size="small" variant="tonal"
                :color="labStatusColor(s.status)" class="text-capitalize">
                <v-icon start size="14">{{ labStatusIcon(s.status) }}</v-icon>
                {{ s.status.replace(/_/g, ' ') }}
                <span class="font-weight-bold ml-1">{{ s.count }}</span>
              </v-chip>
            </div>
          </div>
          <v-divider class="mb-3" />
          <!-- Prescription status -->
          <div>
            <div class="text-caption text-medium-emphasis mb-2">Prescriptions by Status</div>
            <div class="d-flex flex-wrap ga-1">
              <v-chip v-for="s in rxStatusDist" :key="s.status" size="small" variant="tonal"
                :color="rxStatusColor(s.status)" class="text-capitalize">
                <v-icon start size="14">{{ rxStatusIcon(s.status) }}</v-icon>
                {{ s.status.replace(/_/g, ' ') }}
                <span class="font-weight-bold ml-1">{{ s.count }}</span>
              </v-chip>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═════════ Lists Row ═════════ -->
    <v-row dense class="mb-2">
      <!-- Today's Appointments -->
      <v-col cols="12" lg="6">
        <v-card rounded="lg" variant="outlined" class="list-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center ga-2">
              <v-avatar color="primary-lighten-5" variant="tonal" size="36">
                <v-icon color="primary">mdi-calendar-clock</v-icon>
              </v-avatar>
              <span class="text-subtitle-1 font-weight-bold">Today's Appointments</span>
            </div>
            <v-chip size="small" variant="tonal" color="primary" class="font-weight-bold">
              {{ todayAppointments.length }}
            </v-chip>
          </div>
          <div v-if="todayAppointments.length" class="d-flex flex-column ga-1">
            <div v-for="apt in todayAppointments.slice(0, 6)" :key="apt.id"
              class="d-flex align-center ga-3 pa-2 rounded-lg appt-row">
              <div class="text-center flex-shrink-0" style="width: 56px">
                <div class="text-subtitle-2 font-weight-bold">{{ formatTime(apt.appointment_time) }}</div>
                <div class="text-caption text-medium-emphasis">today</div>
              </div>
              <v-divider vertical />
              <div class="flex-1">
                <div class="text-body-2 font-weight-medium">{{ apt.patient_name || 'Patient' }}</div>
                <div class="text-caption text-medium-emphasis">{{ apt.reason || 'No reason specified' }}</div>
              </div>
              <v-chip size="small" variant="tonal" :color="apptStatusColor(apt.status)" class="text-capitalize">
                {{ apt.status }}
              </v-chip>
            </div>
          </div>
          <EmptyState v-else icon="mdi-calendar-check" icon-color="grey-lighten-1" title="No appointments today"
            message="There are no appointments scheduled for today."
          />
        </v-card>
      </v-col>

      <!-- Recent Patients -->
      <v-col cols="12" lg="6">
        <v-card rounded="lg" variant="outlined" class="list-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center ga-2">
              <v-avatar color="teal-lighten-5" variant="tonal" size="36">
                <v-icon color="teal">mdi-account-plus</v-icon>
              </v-avatar>
              <span class="text-subtitle-1 font-weight-bold">Recent Patients</span>
            </div>
            <v-btn size="small" variant="text" class="text-none" append-icon="mdi-arrow-right"
              @click="navigateTo('/clinics/patients')">View all</v-btn>
          </div>
          <div v-if="recentPatients.length" class="d-flex flex-column ga-1">
            <div v-for="p in recentPatients.slice(0, 6)" :key="p.id"
              class="d-flex align-center ga-3 pa-2 rounded-lg patient-row">
              <v-avatar color="teal-lighten-5" variant="tonal" size="36">
                <v-icon color="teal">mdi-account</v-icon>
              </v-avatar>
              <div class="flex-1">
                <div class="text-body-2 font-weight-medium">{{ p.user_name || p.patient_number || 'Unknown' }}</div>
                <div class="text-caption text-medium-emphasis">{{ p.patient_number || '—' }} · {{ p.gender || '—' }}</div>
              </div>
              <span class="text-caption text-medium-emphasis">{{ formatDate(p.created_at) }}</span>
            </div>
          </div>
          <EmptyState v-else icon="mdi-account-search" icon-color="grey-lighten-1" title="No patients yet"
            message="Newly registered patients will appear here." />
        </v-card>
      </v-col>
    </v-row>

    <!-- ═════════ Quick Actions + Alerts ═════════ -->
    <v-row dense>
      <!-- Quick Actions -->
      <v-col cols="12" lg="8">
        <v-card rounded="lg" variant="outlined" class="action-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-subtitle-1 font-weight-bold">Quick Actions</span>
            <v-icon size="18" color="medium-emphasis">mdi-lightning-bolt</v-icon>
          </div>
          <v-row dense>
            <v-col v-for="a in actions" :key="a.label" cols="6" sm="4" md="3">
              <v-card variant="tonal" rounded="lg" class="action-tile pa-3 h-100" :color="a.color + '-lighten-5'"
                :to="a.to" hover>
                <div class="d-flex flex-column align-center text-center ga-1">
                  <v-avatar :color="a.color" variant="tonal" size="40">
                    <v-icon :color="a.color">{{ a.icon }}</v-icon>
                  </v-avatar>
                  <span class="text-caption font-weight-medium">{{ a.label }}</span>
                </div>
              </v-card>
            </v-col>
          </v-row>
        </v-card>
      </v-col>

      <!-- Open Escalations -->
      <v-col cols="12" lg="4">
        <v-card rounded="lg" variant="outlined" class="alerts-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center ga-2">
              <v-avatar color="error-lighten-5" variant="tonal" size="36">
                <v-icon color="error">mdi-bell-alert</v-icon>
              </v-avatar>
              <span class="text-subtitle-1 font-weight-bold">Open Escalations</span>
            </div>
            <v-chip v-if="openEscalations.length" size="small" variant="flat" color="error" class="font-weight-bold">
              {{ openEscalations.length }} open
            </v-chip>
          </div>
          <div v-if="openEscalations.length" class="d-flex flex-column ga-2">
            <div v-for="esc in openEscalations.slice(0, 5)" :key="esc.id"
              class="esc-item pa-2 rounded-lg" :class="`esc-border-${esc.severity || 'low'}`">
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 font-weight-medium">{{ esc.patient_name || 'Unknown' }}</span>
                <v-chip size="x-small" variant="tonal" :color="severityColor(esc.severity)" class="text-capitalize">
                  {{ esc.severity }}
                </v-chip>
              </div>
              <div class="text-caption text-medium-emphasis mt-1">{{ esc.reason || 'No reason' }}</div>
              <div class="text-caption text-medium-emphasis">{{ formatDateTime(esc.triggered_at) }}</div>
            </div>
          </div>
          <EmptyState v-else icon="mdi-check-circle" icon-color="success" title="No open escalations"
            message="All clear — no active alerts." />
        </v-card>
      </v-col>
    </v-row>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatDate, formatDateTime, formatMoney } from '~/utils/format'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const loading = ref(false)
const rangeKey = ref('today')
const rangeOptions = [
  { key: 'today', label: 'Today' },
  { key: '7d', label: '7 Days' },
  { key: '30d', label: '30 Days' },
  { key: 'all', label: 'All Time' },
]

const snack = reactive({ show: false, color: 'success', text: '' })

// ── Counts ────────────────────────────────────────────────────
const totalCounts = reactive({
  patients: 0, appointments: 0, consultations: 0, triage: 0,
  beds: 0, escalations: 0, caregivers: 0, labOrders: 0,
  prescriptions: 0, invoices: 0, departments: 0,
})

const todayCounts = reactive({
  appointments: 0, consultations: 0, triage: 0, escalations: 0, labOrders: 0, prescriptions: 0,
})

// ── Data holders ───────────────────────────────────────────────
const allAppointments = ref([])
const allConsultations = ref([])
const allInvoices = ref([])
const allLabOrders = ref([])
const allPrescriptions = ref([])
const allEscalations = ref([])
const recentPatients = ref([])
const allDepartments = ref([])

const today = new Date().toISOString().split('T')[0]
const todayStr = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })

// ── Helper: safely fetch list ──────────────────────────────────
async function fetchList(endpoint, params = {}) {
  try {
    const resp = await $api.get(endpoint, { params: { page_size: 1000, ...params } })
    return resp.data?.results || resp.data || []
  } catch { return [] }
}

async function fetchCount(endpoint, params = {}) {
  try {
    const resp = await $api.get(endpoint, { params: { page_size: 1, ...params } })
    return resp.data?.count ?? resp.data?.results?.length ?? 0
  } catch { return 0 }
}

// ── KPIs ──────────────────────────────────────────────────────
const kpis = computed(() => [
  {
    title: 'Total Patients', value: totalCounts.patients, icon: 'mdi-account-multiple', color: 'primary',
    sub: `${todayCounts.appointments} appts today`, subIcon: 'mdi-calendar', subColor: 'info',
  },
  {
    title: "Today's Appointments", value: todayCounts.appointments, icon: 'mdi-calendar-clock', color: 'info',
    sub: `${todayAppointments.value.filter(a => a.status === 'scheduled').length} scheduled`, subIcon: 'mdi-clock-outline', subColor: 'grey',
  },
  {
    title: 'Consultations', value: todayCounts.consultations, icon: 'mdi-medical-bag', color: 'success',
    sub: `${totalCounts.consultations} total`, subIcon: 'mdi-history', subColor: 'grey',
  },
  {
    title: 'Triage Entries', value: todayCounts.triage, icon: 'mdi-heart-pulse', color: 'red',
    sub: `${totalCounts.triage} total`, subIcon: 'mdi-history', subColor: 'grey',
  },
  {
    title: 'Open Escalations', value: openEscalations.value.length, icon: 'mdi-bell-alert', color: 'error',
    sub: `${criticalEscalations.value.length} critical`, subIcon: 'mdi-alert-octagon', subColor: 'error',
  },
  {
    title: 'Lab Orders', value: todayCounts.labOrders, icon: 'mdi-flask', color: 'amber',
    sub: `${pendingLabOrders.value.length} pending`, subIcon: 'mdi-clock-alert', subColor: 'warning',
  },
  {
    title: 'Outstanding', value: formatMoney(outstandingAmount.value, 'KES'), icon: 'mdi-cash-off', color: 'deep-orange',
    sub: `${overdueInvoices.value.length} overdue invoices`, subIcon: 'mdi-alert', subColor: 'error',
  },
  {
    title: 'Departments', value: allDepartments.value.length, icon: 'mdi-domain', color: 'indigo',
    sub: `${activeDepartments.value.length} active`, subIcon: 'mdi-check-circle', subColor: 'success',
  },
])

// ── Today's Appointments ──────────────────────────────────────
const todayAppointments = computed(() =>
  allAppointments.value.filter(a => a.appointment_date === today || a.appointment_date?.startsWith(today)),
)

function formatTime(t) {
  if (!t) return '--:--'
  const [h, m] = String(t).split(':')
  const hh = parseInt(h, 10)
  const ampm = hh >= 12 ? 'PM' : 'AM'
  const hh12 = hh % 12 || 12
  return `${hh12}:${m || '00'} ${ampm}`
}

function apptStatusColor(s) {
  return {
    scheduled: 'info', confirmed: 'primary', in_progress: 'warning',
    completed: 'success', cancelled: 'error', no_show: 'grey',
  }[s] || 'grey'
}

// ── Trend data (7 days) ──────────────────────────────────────
const trendData = computed(() => {
  const days = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    const ds = d.toISOString().split('T')[0]
    const dayLabel = d.toLocaleDateString('en-US', { weekday: 'short' })
    days.push({
      date: ds,
      label: dayLabel,
      appts: allAppointments.value.filter(a => a.appointment_date === ds).length,
      consults: allConsultations.value.filter(c => c.created_at?.startsWith(ds)).length,
    })
  }
  return days
})

// ── Chart constants ────────────────────────────────────────
const chartW = 800
const chartH = 280
const chartPadX = 16
const chartPadY = 12
const chartInnerH = computed(() => chartH - chartPadY * 2)
const seriesColors = { appts: '#1976d2', consults: '#4caf50' }
const trendMax = computed(() => Math.max(1, ...trendData.value.map(d => Math.max(d.appts, d.consults))))
const groupSlot = computed(() => (chartW - chartPadX * 2) / trendData.value.length)
const barW = computed(() => Math.max(6, groupSlot.value * 0.32))
function groupX(i) { return chartPadX + groupSlot.value * i + (groupSlot.value - barW.value * 2 - 4) / 2 }
function barY(v) { return chartPadY + (chartInnerH.value - (v / trendMax.value) * chartInnerH.value) }
function barH(v) { return (v / trendMax.value) * chartInnerH.value }

// ── Appointment status donut ─────────────────────────────────
const apptStatusSegments = computed(() => {
  const statuses = {}
  allAppointments.value.forEach(a => {
    const s = a.status || 'unknown'
    statuses[s] = (statuses[s] || 0) + 1
  })
  const colors = {
    scheduled: '#2196f3', confirmed: '#1976d2', in_progress: '#ff9800',
    completed: '#4caf50', cancelled: '#f44336', no_show: '#9e9e9e',
  }
  return Object.entries(statuses).map(([label, value]) => ({
    label, value, color: colors[label] || '#757575',
  })).sort((a, b) => b.value - a.value)
})

// ── Revenue ──────────────────────────────────────────────────
const totalAmount = computed(() =>
  allInvoices.value.reduce((sum, inv) => sum + (parseFloat(inv.total) || 0), 0),
)
const collectedAmount = computed(() =>
  allInvoices.value.reduce((sum, inv) => sum + (parseFloat(inv.amount_paid) || 0), 0),
)
const outstandingAmount = computed(() =>
  allInvoices.value.reduce((sum, inv) => sum + (parseFloat(inv.balance) || 0), 0),
)
const overdueInvoices = computed(() =>
  allInvoices.value.filter(inv => inv.status === 'overdue' || inv.status === 'partially_paid'),
)

const invoiceStatusDist = computed(() => {
  const map = {}
  allInvoices.value.forEach(inv => {
    const s = inv.status || 'unknown'
    map[s] = (map[s] || 0) + 1
  })
  const colors = {
    draft: '#9e9e9e', sent: '#2196f3', paid: '#4caf50',
    partially_paid: '#ff9800', overdue: '#f44336', cancelled: '#e0e0e0',
  }
  const total = allInvoices.value.length || 1
  return Object.entries(map).map(([status, count]) => ({
    status: status.replace(/_/g, ' '),
    count,
    pct: (count / total) * 100,
    color: colors[status] || '#757575',
  })).sort((a, b) => b.count - a.count)
})

// ── Lab status ──────────────────────────────────────────────
const labStatusDist = computed(() => {
  const map = {}
  allLabOrders.value.forEach(o => {
    const s = o.status || 'unknown'
    map[s] = (map[s] || 0) + 1
  })
  return Object.entries(map).map(([status, count]) => ({
    status, count,
  })).sort((a, b) => b.count - a.count)
})
const pendingLabOrders = computed(() =>
  allLabOrders.value.filter(o => o.status === 'pending' || o.status === 'sample_collected'),
)
function labStatusColor(s) {
  return {
    pending: 'warning', sample_collected: 'info', processing: 'primary',
    completed: 'success', cancelled: 'error',
  }[s] || 'grey'
}
function labStatusIcon(s) {
  return {
    pending: 'mdi-clock-outline', sample_collected: 'mdi-test-tube',
    processing: 'mdi-flask-outline', completed: 'mdi-check-circle', cancelled: 'mdi-close-circle',
  }[s] || 'mdi-circle-medium'
}

// ── Prescription status ──────────────────────────────────────
const rxStatusDist = computed(() => {
  const map = {}
  allPrescriptions.value.forEach(p => {
    const s = p.status || 'unknown'
    map[s] = (map[s] || 0) + 1
  })
  return Object.entries(map).map(([status, count]) => ({
    status, count,
  })).sort((a, b) => b.count - a.count)
})
function rxStatusColor(s) {
  return {
    active: 'success', sent_to_exchange: 'info',
    dispensed: 'primary', cancelled: 'error',
  }[s] || 'grey'
}
function rxStatusIcon(s) {
  return {
    active: 'mdi-pill', sent_to_exchange: 'mdi-send',
    dispensed: 'mdi-check-circle', cancelled: 'mdi-close-circle',
  }[s] || 'mdi-circle-medium'
}

// ── Escalations ──────────────────────────────────────────────
const openEscalations = computed(() =>
  allEscalations.value.filter(e => e.status === 'open' || e.status === 'acknowledged'),
)
const criticalEscalations = computed(() =>
  allEscalations.value.filter(e => e.severity === 'critical' && e.status !== 'resolved'),
)
function severityColor(s) {
  return { low: 'info', medium: 'warning', high: 'error', critical: 'deep-orange' }[s] || 'grey'
}

// ── Departments ──────────────────────────────────────────────
const activeDepartments = computed(() => allDepartments.value.filter(d => d.is_active))

// ── Quick Actions ─────────────────────────────────────────────
const actions = [
  { icon: 'mdi-account-plus', label: 'New Patient', to: '/clinics/patients', color: 'primary' },
  { icon: 'mdi-calendar-plus', label: 'New Appointment', to: '/clinics/appointments', color: 'info' },
  { icon: 'mdi-medical-bag', label: 'New Consultation', to: '/clinics/consultations', color: 'success' },
  { icon: 'mdi-pill', label: 'Write Prescription', to: '/clinics/prescriptions', color: 'purple' },
  { icon: 'mdi-microscope', label: 'Order Lab Test', to: '/clinics/lab-orders', color: 'amber' },
  { icon: 'mdi-receipt-text', label: 'Create Invoice', to: '/clinics/invoices', color: 'teal' },
  { icon: 'mdi-heart-pulse', label: 'Triage / Vitals', to: '/clinics/triage', color: 'red' },
  { icon: 'mdi-home-heart', label: 'Patient Care', to: '/clinics/patient-care', color: 'pink' },
  { icon: 'mdi-notebook-edit', label: 'Care Notes', to: '/clinics/care-notes', color: 'indigo' },
  { icon: 'mdi-domain', label: 'Departments', to: '/clinics/departments', color: 'deep-orange' },
  { icon: 'mdi-chart-arc', label: 'Analytics', to: '/clinics/analytics', color: 'cyan' },
  { icon: 'mdi-bell-ring', label: 'View Alerts', to: '/clinics/alerts', color: 'error' },
]

// ── Load ─────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const [
      patients, appts, consults, triage, escs, labOrders,
      rxs, invoices, depts, beds, caregivers,
    ] = await Promise.all([
      fetchList('/patients/'),
      fetchList('/appointments/', { ordering: '-appointment_date,-appointment_time' }),
      fetchList('/consultations/', { ordering: '-created_at' }),
      fetchList('/triage/', { ordering: '-triage_time' }),
      fetchList('/homecare/escalations/'),
      fetchList('/lab/lab-orders/', { ordering: '-created_at' }),
      fetchList('/prescriptions/prescriptions/', { ordering: '-created_at' }),
      fetchList('/billing/invoices/', { ordering: '-created_at' }),
      fetchList('/departments/'),
      fetchCount('/wards/beds/'),
      fetchCount('/homecare/caregivers/'),
    ])

    totalCounts.patients = patients.length
    totalCounts.appointments = appts.length
    totalCounts.consultations = consults.length
    totalCounts.triage = triage.length
    totalCounts.escalations = escs.length
    totalCounts.labOrders = labOrders.length
    totalCounts.prescriptions = rxs.length
    totalCounts.invoices = invoices.length
    totalCounts.beds = beds
    totalCounts.caregivers = caregivers
    totalCounts.departments = depts.length

    allAppointments.value = appts
    allConsultations.value = consults
    allInvoices.value = invoices
    allLabOrders.value = labOrders
    allPrescriptions.value = rxs
    allEscalations.value = escs
    allDepartments.value = depts
    recentPatients.value = [...patients].sort((a, b) =>
      new Date(b.created_at || 0) - new Date(a.created_at || 0),
    ).slice(0, 8)

    // Today counts
    const todayApts = appts.filter(a => a.appointment_date === today || a.appointment_date?.startsWith(today))
    todayCounts.appointments = todayApts.length
    todayCounts.consultations = consults.filter(c => c.created_at?.startsWith(today)).length
    todayCounts.triage = triage.filter(t => t.triage_time?.startsWith(today) || t.created_at?.startsWith(today)).length
    todayCounts.escalations = escs.filter(e => e.triggered_at?.startsWith(today)).length
    todayCounts.labOrders = labOrders.filter(l => l.created_at?.startsWith(today)).length
    todayCounts.prescriptions = rxs.filter(r => r.created_at?.startsWith(today)).length
  } catch (e) {
    snack.text = 'Failed to load dashboard data'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: box-shadow 0.2s; }
.kpi-card:hover { box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06); }

.chart-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.list-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.action-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.alerts-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }

.flex-1 { flex: 1; }
.flex-shrink-0 { flex-shrink: 0; }

.trend-chart-wrap { width: 100%; }
.trend-chart-wrap svg { display: block; }

.appt-row { transition: background 0.15s; }
.appt-row:hover { background: rgba(var(--v-theme-primary), 0.04); }
.patient-row { transition: background 0.15s; }
.patient-row:hover { background: rgba(var(--v-theme-teal), 0.04); }

.action-tile { cursor: pointer; transition: transform 0.15s, box-shadow 0.15s; }
.action-tile:hover { transform: translateY(-2px); box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08); }

.revenue-tile { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }

/* Status bars */
.status-bar-track { height: 8px; background: rgba(var(--v-theme-on-surface), 0.06); }
.status-bar-fill { height: 100%; min-width: 3px; transition: width 0.3s ease; }

/* Escalation items */
.esc-item { border-left: 3px solid; }
.esc-border-low { border-left-color: rgb(var(--v-theme-info)); }
.esc-border-medium { border-left-color: rgb(var(--v-theme-warning)); }
.esc-border-high { border-left-color: rgb(var(--v-theme-error)); }
.esc-border-critical { border-left-color: rgb(var(--v-theme-deep-orange)); }
</style>
