<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Insurance Claims Analytics"
      subtitle="Claim volumes, approval rates, type distribution and pending value."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-shield-account-outline"
      :chips="[
        { icon: 'mdi-shield-file', label: `${d.total} claims` },
        { icon: 'mdi-clock-alert', label: `${d.pending_count} pending` },
        { icon: 'mdi-percent-check', label: `${d.approval_rate}% approval` },
        { icon: 'mdi-cash', label: money(d.total_approved) + ' approved`' }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- KPI strip -->
    <v-row dense>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Claims" :value="d.total || 0" icon="mdi-shield-file" color="#f97316" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Pending" :value="d.pending_count || 0" icon="mdi-clock-alert" color="#f59e0b" :hint="money(d.pending_value)" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Approval Rate" :value="(d.approval_rate || 0) + '%'" icon="mdi-percent-check" color="#10b981" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Requested" :value="money(d.total_requested)" icon="mdi-cash" color="#0d9488" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Claim status -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Claims by status" icon="mdi-clipboard-list-outline" color="#f97316">
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="statusSegments" :size="170" :thickness="20">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ d.total || 0 }}</div>
                <div class="text-caption text-medium-emphasis">claims</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="s in statusSegments" :key="s.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Claim type -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Claims by type" icon="mdi-shape" color="#6366f1">
          <BarChart :values="typeValues" :labels="typeLabels" :colors="typeColors" :height="220" />
        </HomecarePanel>
      </v-col>

      <!-- Amounts -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Amounts" subtitle="Requested vs approved" icon="mdi-cash-multiple" color="#10b981">
          <div class="d-flex flex-column ga-3 mt-2">
            <div class="an-amt pa-3 rounded-lg" style="background:rgba(13,148,136,0.08);">
              <div class="text-caption text-medium-emphasis">Total Requested</div>
              <div class="text-h5 font-weight-bold text-teal">{{ money(d.total_requested) }}</div>
            </div>
            <div class="an-amt pa-3 rounded-lg" style="background:rgba(16,185,129,0.08);">
              <div class="text-caption text-medium-emphasis">Total Approved</div>
              <div class="text-h5 font-weight-bold text-success">{{ money(d.total_approved) }}</div>
            </div>
            <div class="an-amt pa-3 rounded-lg" style="background:rgba(245,158,11,0.08);">
              <div class="text-caption text-medium-emphasis">Pending Value</div>
              <div class="text-h5 font-weight-bold text-warning">{{ money(d.pending_value) }}</div>
            </div>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Trend -->
    <v-row class="mt-3">
      <v-col cols="12">
        <HomecarePanel :title="`Claims trend (${trendRange})`" subtitle="New claims per day"
                       icon="mdi-chart-bar" color="#f97316">
          <template #actions>
            <v-select :model-value="trendRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('trend', val)" />
          </template>
          <BarChart :values="trendValues" :labels="trendLabels" color="#f97316" :height="200" />
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const d = ref({})
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })
const trendRange = ref('30d')

const rangeOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Yesterday', value: 'yesterday' },
  { title: 'Last 7 days', value: '7d' },
  { title: 'Last 30 days', value: '30d' },
  { title: 'Last 90 days', value: '90d' },
  { title: 'Last year', value: '1y' },
  { title: 'All time', value: 'all' },
]

function rangeLabel(range) {
  const map = {
    today: "Today's", yesterday: "Yesterday's",
    '7d': '7-day', '30d': '30-day', '90d': '90-day',
    '1y': '1-year', all: 'All-time',
  }
  return map[range] || '30-day'
}

const statusSegments = computed(() => {
  const s = d.value.by_status || {}
  return [
    { label: 'Draft', value: s.draft || 0, color: 'grey' },
    { label: 'Submitted', value: s.submitted || 0, color: 'info' },
    { label: 'Approved', value: s.approved || 0, color: 'success' },
    { label: 'Denied', value: s.denied || 0, color: 'error' },
    { label: 'Partial', value: s.partial || 0, color: 'warning' },
    { label: 'Paid', value: s.paid || 0, color: 'teal' },
  ]
})

const typeLabels = computed(() => ['Visit', 'Medication', 'Teleconsult', 'Procedure', 'Other'])
const typeValues = computed(() => {
  const t = d.value.by_type || {}
  return [t.visit || 0, t.medication || 0, t.teleconsult || 0, t.procedure || 0, t.other || 0]
})
const typeColors = computed(() => ['#0d9488', '#10b981', '#0ea5e9', '#7c3aed', '#94a3b8'])

const trendValues = computed(() => (d.value.trend || []).map(t => t.count))
const trendLabels = computed(() => (d.value.trend || []).map(t => t.date.slice(5)))

function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function onChartRangeChange(chart, val) {
  const ranges = { trend: trendRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { trend: trendRange }
  const dataKeys = { trend: ['trend'] }
  const range = ranges[chart].value
  const keys = dataKeys[chart]
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/insurance/', { params: { range } })
    if (data) {
      const updates = {}
      keys.forEach(k => { if (data[k] !== undefined) updates[k] = data[k] })
      d.value = { ...d.value, ...updates }
    }
  } catch {
    snack.text = 'Failed to load chart data'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/insurance/', { params: { range: '30d' } })
    d.value = data || {}
    trendRange.value = '30d'
  } catch {
    snack.text = 'Failed to load insurance analytics'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(load)
</script>

<style scoped>
.an-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.05) 0%, rgba(99,102,241,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.an-filter-bar { padding: 12px 16px; background: rgba(255,255,255,0.7); border: 1px solid rgba(15,23,42,0.06); border-radius: 16px; }
:global(.v-theme--dark .an-filter-bar) { background: rgba(30,41,59,0.6); border-color: rgba(255,255,255,0.08); }
</style>
