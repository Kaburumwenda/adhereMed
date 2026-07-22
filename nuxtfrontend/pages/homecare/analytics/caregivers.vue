<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Workforce Analytics"
      subtitle="Caregiver composition, availability, ratings and visit performance."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-account-heart"
      :chips="[
        { icon: 'mdi-account-group', label: `${d.total} caregivers` },
        { icon: 'mdi-account-check', label: `${d.active} active` },
        { icon: 'mdi-star', label: `${d.avg_rating} avg rating` },
        { icon: 'mdi-login', label: `${d.on_duty} on duty` }
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
        <HomecareKpiCard label="Total Caregivers" :value="d.total || 0" icon="mdi-account-group" color="#6366f1" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Active" :value="d.active || 0" icon="mdi-account-check" color="#10b981" :hint="`${d.on_leave || 0} on leave`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="On Duty Now" :value="d.on_duty || 0" icon="mdi-login" color="#0ea5e9" :hint="`${d.available || 0} available`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Avg Rating" :value="d.avg_rating || 0" icon="mdi-star" color="#f59e0b" :hint="`${d.total_visits || 0} total visits`" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Category breakdown -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="By category" subtitle="Nurse vs Health Care Assistant"
                       icon="mdi-account-cog" color="#6366f1">
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="categorySegments" :size="170" :thickness="20">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ d.total || 0 }}</div>
                <div class="text-caption text-medium-emphasis">staff</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="c in categorySegments" :key="c.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="c.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ c.label }}</span>
              <span class="font-weight-bold text-body-2">{{ c.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Employment status -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Employment status" icon="mdi-badge-account" color="#10b981">
          <div class="d-flex flex-column ga-2 mt-2">
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

      <!-- Availability -->
      <v-col cols="12" md="6" lg="4">
        <HomecarePanel title="Availability" icon="mdi-calendar-check" color="#0ea5e9">
          <div class="text-center pa-3">
            <div class="text-h3 font-weight-bold text-teal">{{ d.available || 0 }}</div>
            <div class="text-caption text-medium-emphasis">available caregivers</div>
          </div>
          <v-progress-linear :model-value="availabilityPct" color="teal" height="8" rounded class="mt-2" />
          <div class="d-flex justify-space-between mt-2">
            <span class="text-caption text-medium-emphasis">{{ d.available || 0 }} available</span>
            <span class="text-caption text-medium-emphasis">{{ (d.total || 0) - (d.available || 0) }} unavailable</span>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Top caregivers -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Top caregivers by visits" subtitle="All-time visit leaders"
                       icon="mdi-trophy" color="#f59e0b">
          <v-table v-if="(d.top_caregivers || []).length" density="compact">
            <thead>
              <tr><th>#</th><th>Name</th><th>Category</th><th>Rating</th><th>Visits</th></tr>
            </thead>
            <tbody>
              <tr v-for="(c, idx) in d.top_caregivers || []" :key="c.id">
                <td>
                  <v-avatar size="28" color="amber" variant="tonal">
                    <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                  </v-avatar>
                </td>
                <td class="font-weight-medium">{{ c.name }}</td>
                <td>
                  <v-chip size="x-small" variant="tonal" :color="c.category === 'nurse' ? 'teal' : 'info'">
                    {{ c.category === 'nurse' ? 'Nurse' : 'HCA' }}
                  </v-chip>
                </td>
                <td>
                  <v-icon icon="mdi-star" color="amber" size="14" class="mr-1" />{{ c.rating }}
                </td>
                <td class="font-weight-bold">{{ c.total_visits }}</td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-trophy-outline" title="No data yet" dense />
        </HomecarePanel>
      </v-col>

      <!-- Visit leaders (30d) -->
      <v-col cols="12" md="6">
        <HomecarePanel :title="`Visit leaders (${leadersRange})`" :subtitle="`Most visits — last ${leadersRange}`"
                       icon="mdi-medal" color="#8b5cf6">
          <template #actions>
            <v-select :model-value="leadersRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('leaders', val)" />
          </template>
          <div v-if="(d.visit_leaders || []).length" class="d-flex flex-column ga-2">
            <div v-for="(l, idx) in d.visit_leaders" :key="idx"
                 class="d-flex align-center pa-3 rounded-lg an-row">
              <v-avatar size="36" :color="leaderColor(idx)" variant="tonal">
                <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
              </v-avatar>
              <div class="flex-grow-1 ml-3">
                <div class="text-body-2 font-weight-bold text-truncate">{{ l.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ l.visits }} visits completed</div>
              </div>
              <v-progress-linear :model-value="leaderPct(l.visits)" color="purple" rounded
                                 style="max-width:80px;" height="6" />
              <span class="text-h6 font-weight-bold ml-3">{{ l.visits }}</span>
            </div>
          </div>
          <EmptyState v-else icon="mdi-medal-outline" title="No visits recorded" dense />
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
const leadersRange = ref('30d')

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

const categorySegments = computed(() => {
  const c = d.value.by_category || {}
  return [
    { label: 'Nurse', value: c.nurse || 0, color: 'teal' },
    { label: 'Health Care Assistant', value: c.hca || 0, color: 'info' },
  ]
})

const statusBars = computed(() => {
  const s = d.value.by_status || {}
  const total = Object.values(s).reduce((a, b) => a + b, 0) || 1
  const entries = [
    { label: 'Active', key: 'active', icon: 'mdi-account-check', color: 'success' },
    { label: 'On Leave', key: 'on_leave', icon: 'mdi-calendar-blank', color: 'warning' },
    { label: 'Suspended', key: 'suspended', icon: 'mdi-account-cancel', color: 'error' },
    { label: 'Terminated', key: 'terminated', icon: 'mdi-account-remove', color: 'grey' },
  ]
  return entries.map(e => {
    const value = s[e.key] || 0
    return { ...e, value, pct: Math.round(value / total * 100) }
  })
})

const availabilityPct = computed(() => {
  const total = d.value.total || 0
  return total ? Math.round((d.value.available || 0) / total * 100) : 0
})

function leaderColor(idx) {
  const colors = ['amber', 'purple', 'teal', 'info', 'blue', 'pink', 'indigo', 'green', 'cyan', 'orange']
  return colors[idx % colors.length]
}
function leaderPct(visits) {
  const max = Math.max(...(d.value.visit_leaders || []).map(l => l.visits), 1)
  return Math.round(visits / max * 100)
}

function onChartRangeChange(chart, val) {
  const ranges = { leaders: leadersRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { leaders: leadersRange }
  const dataKeys = { leaders: ['visit_leaders'] }
  const range = ranges[chart].value
  const keys = dataKeys[chart]
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/workforce/', { params: { range } })
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
    const { data } = await $api.get('/homecare/analytics/workforce/', { params: { range: '30d' } })
    d.value = data || {}
    leadersRange.value = '30d'
  } catch {
    snack.text = 'Failed to load workforce analytics'; snack.color = 'error'; snack.show = true
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
.an-row { transition: background 0.15s ease; }
.an-row:hover { background: rgba(99,102,241,0.06); }
</style>
