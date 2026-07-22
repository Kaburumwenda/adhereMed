<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Escalation Analytics"
      subtitle="Alert severity, resolution times, trends and recurring triggers."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-alert-octagram"
      :chips="[
        { icon: 'mdi-alert', label: `${d.open} open` },
        { icon: 'mdi-bell-ring', label: `${d.acknowledged} acknowledged` },
        { icon: 'mdi-chart-bell-curve', label: `${d.total_30d} in 30d` },
        { icon: 'mdi-clock-fast', label: `${d.avg_resolution_hours}h avg resolve` }
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
        <HomecareKpiCard label="Open Escalations" :value="d.open || 0" icon="mdi-alert" color="#ef4444" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Acknowledged" :value="d.acknowledged || 0" icon="mdi-bell-ring" color="#f59e0b" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total (30d)" :value="d.total_30d || 0" icon="mdi-chart-bell-curve" color="#7c3aed" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Avg Resolution" :value="(d.avg_resolution_hours || 0) + 'h'" icon="mdi-clock-fast" color="#10b981" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Severity distribution -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Severity distribution" :subtitle="`Escalations by severity (${severityRange})`"
                       icon="mdi-alert-circle" color="#ef4444">
          <template #actions>
            <v-select :model-value="severityRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('severity', val)" />
          </template>
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="severitySegments" :size="170" :thickness="20">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ d.total_30d || 0 }}</div>
                <div class="text-caption text-medium-emphasis">alerts</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="s in severitySegments" :key="s.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Status distribution -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Status breakdown" icon="mdi-clipboard-list-outline" color="#6366f1">
          <div class="d-flex flex-column ga-3 mt-2">
            <div v-for="s in statusBars" :key="s.label" class="d-flex align-center">
              <v-icon :icon="s.icon" :color="s.color" size="20" class="mr-3" />
              <span class="text-body-2 flex-grow-1">{{ s.label }}</span>
              <span class="font-weight-bold mr-2">{{ s.value }}</span>
              <v-progress-linear :model-value="s.pct" :color="s.color" rounded
                                 style="max-width:90px;" height="6" />
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Top reasons -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Top triggers" subtitle="Most common escalation reasons"
                       icon="mdi-bell-alert" color="#f97316">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(r, idx) in d.top_reasons || []" :key="idx" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" color="deep-orange" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium text-truncate">{{ r.reason }}</v-list-item-title>
              <v-list-item-subtitle>{{ r.count }} occurrences</v-list-item-subtitle>
              <template #append>
                <v-chip size="small" variant="tonal" color="deep-orange">{{ r.count }}</v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!(d.top_reasons || []).length" icon="mdi-bell-off" title="No triggers" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Trend -->
    <v-row class="mt-3">
      <v-col cols="12">
        <HomecarePanel :title="`Escalation trend (${trendRange})`" subtitle="Triggered vs resolved per day"
                       icon="mdi-chart-timeline-variant" color="#ef4444">
          <template #actions>
            <v-select :model-value="trendRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('trend', val)" />
          </template>
          <BarChart :values="trendValues" :labels="trendLabels" :colors="trendColors" :height="220" />
          <div class="d-flex ga-3 mt-2">
            <div class="d-flex align-center ga-1">
              <v-icon icon="mdi-square" color="#ef4444" size="12" />
              <span class="text-caption">Triggered</span>
            </div>
            <div class="d-flex align-center ga-1">
              <v-icon icon="mdi-square" color="#10b981" size="12" />
              <span class="text-caption">Resolved</span>
            </div>
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
const severityRange = ref('30d')
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

const severitySegments = computed(() => {
  const s = d.value.by_severity || {}
  return [
    { label: 'Low', value: s.low || 0, color: 'info' },
    { label: 'Medium', value: s.medium || 0, color: 'warning' },
    { label: 'High', value: s.high || 0, color: 'error' },
    { label: 'Critical', value: s.critical || 0, color: 'deep-orange' },
  ]
})

const statusBars = computed(() => {
  const s = d.value.by_status || {}
  const total = Object.values(s).reduce((a, b) => a + b, 0) || 1
  const entries = [
    { label: 'Open', key: 'open', icon: 'mdi-alert', color: 'error' },
    { label: 'Acknowledged', key: 'acknowledged', icon: 'mdi-bell-ring', color: 'warning' },
    { label: 'Resolved', key: 'resolved', icon: 'mdi-check-circle', color: 'success' },
  ]
  return entries.map(e => {
    const value = s[e.key] || 0
    return { ...e, value, pct: Math.round(value / total * 100) }
  })
})

const trendValues = computed(() => {
  const t = d.value.trend || []
  return t.flatMap(day => [day.triggered, day.resolved])
})
const trendLabels = computed(() => {
  const t = d.value.trend || []
  return t.flatMap(day => [day.date.slice(5), ''])
})
const trendColors = computed(() => (d.value.trend || []).flatMap(() => ['#ef4444', '#10b981']))

function onChartRangeChange(chart, val) {
  const ranges = { severity: severityRange, trend: trendRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { severity: severityRange, trend: trendRange }
  const dataKeys = { severity: ['by_severity', 'total_30d'], trend: ['trend'] }
  const range = ranges[chart].value
  const keys = dataKeys[chart]
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/escalations/', { params: { range } })
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
    const { data } = await $api.get('/homecare/analytics/escalations/', { params: { range: '30d' } })
    d.value = data || {}
    severityRange.value = '30d'
    trendRange.value = '30d'
  } catch {
    snack.text = 'Failed to load escalation analytics'; snack.color = 'error'; snack.show = true
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
