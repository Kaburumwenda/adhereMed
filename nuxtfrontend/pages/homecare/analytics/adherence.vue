<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Medication Adherence Analytics"
      subtitle="Dose-by-dose adherence tracking, trends and per-patient performance."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-pill-multiple"
      :chips="[
        { icon: 'mdi-percent', label: `${d.rate}% adherence` },
        { icon: 'mdi-pill', label: `${breakdown.total || 0} doses (30d)` },
        { icon: 'mdi-account-group', label: `${d.total_patients_tracked || 0} tracked` },
        { icon: 'mdi-syringe', label: `${d.caregiver_administered || 0} by caregiver` }
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
        <HomecareKpiCard label="Adherence Rate (30d)" :value="(d.rate || 0) + '%'" icon="mdi-percent" color="#10b981" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Doses (30d)" :value="breakdown.total || 0" icon="mdi-pill" color="#0d9488" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Doses Taken" :value="breakdown.taken || 0" icon="mdi-check-circle" color="#10b981" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Doses Missed" :value="breakdown.missed || 0" icon="mdi-alert-circle" color="#ef4444" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- 30-day trend -->
      <v-col cols="12" lg="8">
        <HomecarePanel :title="`${rangeLabel(trendRange)} adherence trend`" subtitle="Daily adherence % and volume"
                       icon="mdi-chart-line" color="#10b981">
          <template #actions>
            <v-select :model-value="trendRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('trend', val)" />
          </template>
          <LineChart :series="[{ label: 'Adherence %', color: '#10b981', values: trendRates }]"
                     :labels="trendLabels" :height="260" />
          <div class="d-flex flex-wrap ga-3 mt-3">
            <v-chip color="teal" variant="tonal"><v-icon start icon="mdi-trending-up" />Avg: {{ avgRate }}%</v-chip>
            <v-chip color="success" variant="tonal"><v-icon start icon="mdi-arrow-up" />Best: {{ bestRate }}%</v-chip>
            <v-chip color="error" variant="tonal"><v-icon start icon="mdi-arrow-down" />Worst: {{ worstRate }}%</v-chip>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Dose breakdown donut -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Dose outcomes" :subtitle="`All doses (${doseRange})`"
                       icon="mdi-pill-multiple" color="#0d9488">
          <template #actions>
            <v-select :model-value="doseRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('dose', val)" />
          </template>
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="doseSegments" :size="180" :thickness="20">
              <div class="text-center">
                <div class="text-h4 font-weight-bold text-success">{{ d.rate || 0 }}%</div>
                <div class="text-caption text-medium-emphasis">adherence</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="s in doseSegments" :key="s.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Best adherers -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Best adherers" subtitle="Top adherence (min 5 doses)"
                       icon="mdi-trophy-award" color="#10b981">
          <v-table v-if="(d.best_patients || []).length" density="compact">
            <thead>
              <tr><th>#</th><th>Patient</th><th>Doses</th><th>Rate</th></tr>
            </thead>
            <tbody>
              <tr v-for="(p, idx) in d.best_patients || []" :key="p.id">
                <td>
                  <v-avatar size="28" color="success" variant="tonal">
                    <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                  </v-avatar>
                </td>
                <td class="font-weight-medium">{{ p.name }}</td>
                <td>{{ p.total }}</td>
                <td>
                  <v-chip size="small" variant="tonal" :color="rateColor(p.rate)">
                    <v-icon start icon="mdi-percent" size="12" />{{ p.rate }}%
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-trophy-outline" title="No data" dense />
        </HomecarePanel>
      </v-col>

      <!-- Needs attention -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Needs attention" subtitle="Lowest adherence (min 5 doses)"
                       icon="mdi-alert-circle-outline" color="#ef4444">
          <v-table v-if="(d.worst_patients || []).length" density="compact">
            <thead>
              <tr><th>Patient</th><th>Doses</th><th>Missed</th><th>Rate</th></tr>
            </thead>
            <tbody>
              <tr v-for="p in d.worst_patients || []" :key="p.id">
                <td class="font-weight-medium">
                  <div class="d-flex align-center">
                    <v-icon icon="mdi-alert" color="error" size="16" class="mr-2" />
                    {{ p.name }}
                  </div>
                </td>
                <td>{{ p.total }}</td>
                <td class="text-error">{{ p.total - p.taken }}</td>
                <td>
                  <v-chip size="small" variant="tonal" :color="rateColor(p.rate)">
                    {{ p.rate }}%
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-check-circle" title="All on track" dense />
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
const doseRange = ref('30d')

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

const breakdown = computed(() => d.value.breakdown || {})

const trendRates = computed(() => (d.value.trend || []).map(t => t.rate))
const trendLabels = computed(() => (d.value.trend || []).map(t => t.date.slice(5)))
const avgRate = computed(() => {
  const v = trendRates.value
  return v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length) : 0
})
const bestRate = computed(() => trendRates.value.length ? Math.max(...trendRates.value) : 0)
const worstRate = computed(() => trendRates.value.length ? Math.min(...trendRates.value) : 0)

const doseSegments = computed(() => {
  const b = breakdown.value
  return [
    { label: 'Taken', value: b.taken || 0, color: 'success' },
    { label: 'Missed', value: b.missed || 0, color: 'error' },
    { label: 'Skipped', value: b.skipped || 0, color: 'warning' },
    { label: 'Refused', value: b.refused || 0, color: 'grey' },
    { label: 'Not Given', value: b.not_given || 0, color: 'deep-orange' },
    { label: 'Pending', value: b.pending || 0, color: 'info' },
  ]
})

function rateColor(rate) {
  if (rate >= 90) return 'success'
  if (rate >= 75) return 'warning'
  if (rate >= 50) return 'orange'
  return 'error'
}

function onChartRangeChange(chart, val) {
  const ranges = { trend: trendRange, dose: doseRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { trend: trendRange, dose: doseRange }
  const dataKeys = { trend: ['trend'], dose: ['breakdown'] }
  const range = ranges[chart].value
  const keys = dataKeys[chart]
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/adherence/', { params: { range } })
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
    const { data } = await $api.get('/homecare/analytics/adherence/', { params: { range: '30d' } })
    d.value = data || {}
    trendRange.value = '30d'
    doseRange.value = '30d'
  } catch {
    snack.text = 'Failed to load adherence analytics'; snack.color = 'error'; snack.show = true
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
