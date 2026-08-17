<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Analytics" subtitle="Clinic performance and insights"
      icon="mdi-chart-box" color="deep-purple">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="loading" @click="loadAll">Refresh</v-btn>
      </template>
    </PageHeader>

    <!-- ── Stat cards ─────────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="4" lg="2">
        <v-card flat rounded="lg" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="44" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline text-medium-emphasis" style="line-height:1.1">
                {{ k.label }}
              </div>
              <div class="text-h5 font-weight-bold" style="line-height:1.2">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <!-- ── Appointments trend (sparkline) ─────────────────────── -->
      <v-col cols="12" md="6">
        <v-card flat rounded="lg" class="chart-card pa-4 mb-3 h-100">
          <div class="d-flex align-center mb-2">
            <v-icon color="primary" class="mr-2">mdi-chart-line</v-icon>
            <h3 class="text-h6 font-weight-bold">Appointments Trend (7 days)</h3>
          </div>
          <v-sparkline v-if="trendData.length" :model-value="trendData"
            :labels="trendLabels" :smooth="true" :fill="true"
            color="primary" type="bar" :padding="10" height="120" />
          <div v-else class="text-body-2 text-medium-emphasis pa-4 text-center">No data yet.</div>
        </v-card>
      </v-col>

      <!-- ── Revenue this month vs last ─────────────────────────── -->
      <v-col cols="12" md="6">
        <v-card flat rounded="lg" class="chart-card pa-4 mb-3 h-100">
          <div class="d-flex align-center mb-2">
            <v-icon color="success" class="mr-2">mdi-cash-multiple</v-icon>
            <h3 class="text-h6 font-weight-bold">Revenue (This vs Last Month)</h3>
          </div>
          <div class="mt-3">
            <div class="d-flex justify-space-between mb-1">
              <span class="text-body-2">This month</span>
              <span class="font-weight-bold">{{ formatMoney(revenueThis) }}</span>
            </div>
            <v-progress-linear :model-value="revenueProgress"
              color="success" height="14" rounded />
            <div class="d-flex justify-space-between mb-1 mt-3">
              <span class="text-body-2">Last month</span>
              <span class="font-weight-bold">{{ formatMoney(revenueLast) }}</span>
            </div>
            <v-progress-linear :model-value="revenueLastProgress"
              color="grey" height="14" rounded />
            <div class="text-caption text-medium-emphasis mt-2">{{ revenueDeltaPct }}% change</div>
          </div>
        </v-card>
      </v-col>

      <!-- ── Patient demographics by gender ─────────────────────── -->
      <v-col cols="12" md="6">
        <v-card flat rounded="lg" class="chart-card pa-4 mb-3 h-100">
          <div class="d-flex align-center mb-2">
            <v-icon color="pink" class="mr-2">mdi-gender-male-female</v-icon>
            <h3 class="text-h6 font-weight-bold">Patient Demographics</h3>
          </div>
          <div v-for="d in demographics" :key="d.label" class="mb-3">
            <div class="d-flex justify-space-between mb-1">
              <span class="text-body-2 text-capitalize">{{ d.label }}</span>
              <span class="font-weight-bold">{{ d.value }} ({{ d.pct }}%)</span>
            </div>
            <v-progress-linear :model-value="d.pct"
              :color="d.color" height="12" rounded />
          </div>
        </v-card>
      </v-col>

      <!-- ── Top departments by visits ──────────────────────────── -->
      <v-col cols="12" md="6">
        <v-card flat rounded="lg" class="chart-card pa-4 mb-3 h-100">
          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-domain</v-icon>
            <h3 class="text-h6 font-weight-bold">Top Departments by Visits</h3>
          </div>
          <div v-for="(d, i) in topDepartments" :key="d.label" class="mb-3">
            <div class="d-flex justify-space-between mb-1">
              <span class="text-body-2">#{{ i + 1 }} {{ d.label }}</span>
              <span class="font-weight-bold">{{ d.value }}</span>
            </div>
            <v-progress-linear :model-value="d.pct"
              color="indigo" height="12" rounded />
          </div>
          <div v-if="!topDepartments.length" class="text-body-2 text-medium-emphasis pa-4 text-center">
            No department visit data yet.
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const ns = '/clinics'

const loading = ref(false)
const patients = ref([])
const appointments = ref([])
const consultations = ref([])
const invoices = ref([])
const wards = ref([])

const snack = reactive({ show: false, color: 'success', text: '' })

async function loadAll() {
  loading.value = true
  const safe = (p) => $api.get(p, { params: { page_size: 1000 } })
    .then(r => r.data?.results || r.data || []).catch((e) => { console.warn(p, e); return [] })
  try {
    const [pat, appts, consults, inv, ws] = await Promise.all([
      safe('/patients/'),
      safe('/appointments/'),
      safe('/consultations/'),
      safe('/billing/invoices/'),
      safe('/wards/wards/'),
    ])
    patients.value = pat
    appointments.value = appts
    consultations.value = consults
    invoices.value = inv
    wards.value = ws
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

// ── KPIs ──────────────────────────────────────────────────────
const kpis = computed(() => {
  const appts = appointments.value
  const today = new Date().toISOString().slice(0, 10)
  // Avg consultations/day: total consultations / span of days covered
  const days = daySpan(consultations.value, 'consultation_date', 'created_at')
  const avg = days > 0 ? (consultations.value.length / days).toFixed(1) : '0'
  let totalBeds = 0
  let occupiedBeds = 0
  wards.value.forEach(w => {
    totalBeds += w.total_beds || 0
    occupiedBeds += (w.occupied_beds || (w.total_beds || 0) - (w.available_beds || 0)) || 0
  })
  const occRate = totalBeds > 0 ? Math.round((occupiedBeds / totalBeds) * 100) : 0
  return [
    { label: 'Total Patients', value: patients.value.length, icon: 'mdi-account-multiple', color: 'primary' },
    { label: 'Total Appointments', value: appts.length, icon: 'mdi-calendar', color: 'info' },
    { label: 'Total Consultations', value: consultations.value.length, icon: 'mdi-medical-bag', color: 'teal' },
    { label: 'Total Revenue', value: formatMoney(totalRevenue.value), icon: 'mdi-cash', color: 'success' },
    { label: 'Avg/day', value: avg, icon: 'mdi-chart-line', color: 'indigo' },
    { label: 'Bed Occupancy', value: occRate + '%', icon: 'mdi-bed', color: 'warning' },
  ]
})

const totalRevenue = computed(() =>
  invoices.value.reduce((s, i) =>
    s + (Number(i.total_amount ?? i.amount_due ?? i.amount ?? 0) || 0), 0),
)

// ── Appointments trend (last 7 days) ──────────────────────────────
const trendData = computed(() => {
  const days = []
  const now = new Date()
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now)
    d.setDate(now.getDate() - i)
    days.push(d.toISOString().slice(0, 10))
  }
  return days.map(d =>
    appointments.value.filter(a =>
      (a.appointment_date || '').slice(0, 10) === d,
    ).length,
  )
})

const trendLabels = computed(() => {
  const labels = []
  const now = new Date()
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now)
    d.setDate(now.getDate() - i)
    labels.push(d.toLocaleDateString(undefined, { weekday: 'short' }).slice(0, 2))
  }
  return labels
})

// ── Revenue this month vs last ─────────────────────────────────
const revenueThis = computed(() => monthRevenue(new Date(), false))
const revenueLast = computed(() => monthRevenue(new Date(), true))

function monthRevenue(d, previous) {
  const yr = d.getFullYear()
  const mo = previous ? d.getMonth() - 1 : d.getMonth()
  const date = new Date(yr, mo, 1)
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  return invoices.value.filter(i =>
    (i.invoice_date || i.date || '').slice(0, 7) === `${y}-${m}`,
  ).reduce((s, i) => s + (Number(i.total_amount ?? i.amount_due ?? i.amount ?? 0) || 0), 0)
}

const revenueProgress = computed(() => {
  const denom = Math.max(revenueThis.value, revenueLast.value, 1)
  return Math.round((revenueThis.value / denom) * 100)
})

const revenueLastProgress = computed(() => {
  const denom = Math.max(revenueThis.value, revenueLast.value, 1)
  return Math.round((revenueLast.value / denom) * 100)
})

const revenueDeltaPct = computed(() => {
  const last = revenueLast.value
  const cur = revenueThis.value
  if (!last) return cur > 0 ? '+100' : '0'
  const pct = Math.round(((cur - last) / last) * 100)
  return (pct >= 0 ? '+' : '') + pct
})

// ── Patient demographics ───────────────────────────────────────
const demographics = computed(() => {
  const counts = {}
  patients.value.forEach(p => {
    const g = (p.gender || 'unknown').toLowerCase()
    counts[g] = (counts[g] || 0) + 1
  })
  const total = patients.value.length || 1
  const colorMap = { male: 'blue', female: 'pink', other: 'teal', unknown: 'grey' }
  const labelMap = { male: 'Male', female: 'Female', other: 'Other', unknown: 'Unknown' }
  const keys = Object.keys(counts).sort((a, b) => counts[b] - counts[a])
  return keys.map(k => ({
    label: labelMap[k] || k,
    value: counts[k],
    pct: Math.round((counts[k] / total) * 100),
    color: colorMap[k] || 'grey',
  }))
})

// ── Top departments by visits ──────────────────────────────────
const topDepartments = computed(() => {
  // Count appointment occurrences per department
  const counts = {}
  appointments.value.forEach(a => {
    const d = a.department_name || (a.department && typeof a.department === 'object' ? a.department.name : '') || (a.staff_name && a.staff_name)
    const key = d || 'Unassigned'
    counts[key] = (counts[key] || 0) + 1
  })
  const arr = Object.entries(counts)
    .map(([label, value]) => ({ label, value }))
    .sort((a, b) => b.value - a.value)
    .slice(0, 5)
  const max = arr.length ? arr[0].value : 1
  return arr.map(d => ({ ...d, pct: Math.round((d.value / max) * 100) }))
})

// ── helpers ───────────────────────────────────────────────────
function daySpan(arr, ...dateKeys) {
  if (!arr.length) return 0
  const dates = arr.map(x => {
    for (const k of dateKeys) { if (x[k]) return String(x[k]).slice(0, 10) }
    return null
  }).filter(Boolean)
  if (!dates.length) return 1
  const s = dates.sort()
  const first = new Date(s[0])
  const last = new Date(s[s.length - 1])
  const diff = Math.max(1, Math.round((last - first) / (1000 * 60 * 60 * 24)) + 1)
  return diff
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.chart-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
