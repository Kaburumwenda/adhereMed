<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Visit Analytics"
      subtitle="Schedule completion, miss rates, visit duration and shift-type breakdown."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-calendar-clock"
      :chips="[
        { icon: 'mdi-calendar-month', label: `${d.total_30d} visits (30d)` },
        { icon: 'mdi-check-circle', label: `${d.completion_rate}% complete` },
        { icon: 'mdi-close-circle', label: `${d.miss_rate}% miss` },
        { icon: 'mdi-clock-outline', label: `${d.avg_duration_hours}h avg` }
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
        <HomecareKpiCard label="Visits (30d)" :value="d.total_30d || 0" icon="mdi-calendar-month" color="#7c3aed" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Completion Rate" :value="(d.completion_rate || 0) + '%'" icon="mdi-check-circle" color="#10b981" :hint="`${d.completed || 0} completed`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Miss Rate" :value="(d.miss_rate || 0) + '%'" icon="mdi-close-circle" color="#ef4444" :hint="`${d.missed || 0} missed`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Avg Duration" :value="(d.avg_duration_hours || 0) + 'h'" icon="mdi-timer" color="#0ea5e9" :hint="`${d.reassignments || 0} reassignments`" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Visit trend -->
      <v-col cols="12" lg="8">
        <HomecarePanel :title="`${rangeLabel(trendRange)} visit trend`" subtitle="Completed vs missed per day"
                       icon="mdi-chart-bar" color="#7c3aed">
          <template #actions>
            <v-select :model-value="trendRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('trend', val)" />
          </template>
          <BarChart :values="trendValues" :labels="trendLabels" :colors="trendColors" :height="240" />
          <div class="d-flex ga-3 mt-2">
            <div class="d-flex align-center ga-1">
              <v-icon icon="mdi-square" color="#10b981" size="12" />
              <span class="text-caption">Completed</span>
            </div>
            <div class="d-flex align-center ga-1">
              <v-icon icon="mdi-square" color="#ef4444" size="12" />
              <span class="text-caption">Missed</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Status distribution -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Visit status" icon="mdi-clipboard-list-outline" color="#6366f1">
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="statusSegments" :size="170" :thickness="20">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ d.total_30d || 0 }}</div>
                <div class="text-caption text-medium-emphasis">visits</div>
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
    </v-row>

    <v-row class="mt-3">
      <!-- Shift type breakdown -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Shift types" subtitle="Distribution by shift type"
                       icon="mdi-swap-horizontal" color="#0ea5e9">
          <div class="d-flex flex-column ga-3 mt-2">
            <div v-for="s in shiftBars" :key="s.label" class="d-flex align-center">
              <v-icon :icon="s.icon" :color="s.color" size="20" class="mr-3" />
              <span class="text-body-2 flex-grow-1">{{ s.label }}</span>
              <span class="font-weight-bold mr-2">{{ s.value }}</span>
              <v-progress-linear :model-value="s.pct" :color="s.color" rounded
                                 style="max-width:100px;" height="6" />
            </div>
            <EmptyState v-if="!shiftBars.length" icon="mdi-swap-horizontal" title="No data" dense />
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Summary tiles -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Visit summary" icon="mdi-clipboard-check" color="#10b981">
          <v-row dense>
            <v-col cols="6" sm="3">
              <div class="an-stat pa-3 rounded-lg text-center">
                <div class="text-h5 font-weight-bold text-success">{{ d.completed || 0 }}</div>
                <div class="text-caption text-medium-emphasis">Completed</div>
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="an-stat pa-3 rounded-lg text-center">
                <div class="text-h5 font-weight-bold text-error">{{ d.missed || 0 }}</div>
                <div class="text-caption text-medium-emphasis">Missed</div>
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="an-stat pa-3 rounded-lg text-center">
                <div class="text-h5 font-weight-bold text-warning">{{ d.cancelled || 0 }}</div>
                <div class="text-caption text-medium-emphasis">Cancelled</div>
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="an-stat pa-3 rounded-lg text-center">
                <div class="text-h5 font-weight-bold text-info">{{ d.reassignments || 0 }}</div>
                <div class="text-caption text-medium-emphasis">Reassigned</div>
              </div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="d-flex align-center justify-space-between pa-2">
            <span class="text-body-2 text-medium-emphasis">Average visit duration</span>
            <v-chip color="info" variant="tonal">
              <v-icon start icon="mdi-timer" />{{ d.avg_duration_hours || 0 }} hours
            </v-chip>
          </div>
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

const trendValues = computed(() => {
  const t = d.value.trend || []
  return t.flatMap(day => [day.completed, day.missed])
})
const trendLabels = computed(() => {
  const t = d.value.trend || []
  return t.flatMap(day => [day.date.slice(5), ''])
})
const trendColors = computed(() => (d.value.trend || []).flatMap(() => ['#10b981', '#ef4444']))

const statusSegments = computed(() => {
  const s = d.value.by_status || {}
  return [
    { label: 'Scheduled', value: s.scheduled || 0, color: 'info' },
    { label: 'Checked In', value: s.checked_in || 0, color: 'teal' },
    { label: 'Completed', value: s.completed || 0, color: 'success' },
    { label: 'Missed', value: s.missed || 0, color: 'error' },
    { label: 'Cancelled', value: s.cancelled || 0, color: 'grey' },
  ]
})

const shiftBars = computed(() => {
  const s = d.value.by_shift_type || {}
  const total = Object.values(s).reduce((a, b) => a + b, 0) || 1
  const entries = [
    { label: 'Single Visit', key: 'visit', icon: 'mdi-account-arrow-right', color: 'teal' },
    { label: 'Live-in', key: 'live_in', icon: 'mdi-home', color: 'purple' },
    { label: 'On Call', key: 'on_call', icon: 'mdi-phone', color: 'amber' },
  ]
  return entries.map(e => {
    const value = s[e.key] || 0
    return { ...e, value, pct: Math.round(value / total * 100) }
  })
})

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
    const { data } = await $api.get('/homecare/analytics/visits/', { params: { range } })
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
    const { data } = await $api.get('/homecare/analytics/visits/', { params: { range: '30d' } })
    d.value = data || {}
    trendRange.value = '30d'
  } catch {
    snack.text = 'Failed to load visit analytics'; snack.color = 'error'; snack.show = true
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
.an-stat { background: rgba(15,23,42,0.03); border: 1px solid rgba(15,23,42,0.05); }
</style>
