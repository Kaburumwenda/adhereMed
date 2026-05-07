<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="API Usage & Billing"
      icon="mdi-chart-line"
      subtitle="Monthly request metering for your account"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load">
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

    <!-- Range filter -->
    <v-card rounded="lg" class="pa-3 mb-4">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-icon class="mr-1">mdi-filter-variant</v-icon>
        <span class="text-subtitle-2 mr-2">Date range</span>
        <v-chip-group
          v-model="preset"
          mandatory
          selected-class="text-primary"
          @update:model-value="loadRange"
        >
          <v-chip v-for="p in presets" :key="p.value" :value="p.value" size="small" variant="tonal">
            {{ p.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <v-menu v-if="preset === 'custom'" :close-on-content-click="false">
          <template #activator="{ props }">
            <v-btn v-bind="props" size="small" variant="tonal" prepend-icon="mdi-calendar">
              {{ customLabel }}
            </v-btn>
          </template>
          <v-card class="pa-3" min-width="280">
            <v-text-field
              v-model="customStart"
              label="Start"
              type="date"
              density="compact"
              hide-details
              class="mb-2"
            />
            <v-text-field
              v-model="customEnd"
              label="End"
              type="date"
              density="compact"
              hide-details
              class="mb-2"
            />
            <v-btn block color="primary" size="small" :disabled="!customStart || !customEnd" @click="loadRange">
              Apply
            </v-btn>
          </v-card>
        </v-menu>
      </div>

      <v-divider class="my-3" />

      <div v-if="rangeLoading" class="d-flex justify-center py-4">
        <v-progress-circular indeterminate size="24" />
      </div>
      <div v-else-if="range">
        <v-row dense>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Range</div>
            <div class="text-subtitle-2 font-weight-bold">
              {{ range.start }} → {{ range.end }}
            </div>
            <div class="text-caption text-medium-emphasis">{{ range.days }} day(s)</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Total requests</div>
            <div class="text-h6 font-weight-bold">{{ fmt(range.total_requests) }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Daily average</div>
            <div class="text-h6 font-weight-bold">{{ fmt(range.daily_average) }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Cost</div>
            <div class="text-h6 font-weight-bold">
              {{ formatMoney(range.cost, range.rate.currency) }}
            </div>
            <div v-if="range.peak_day" class="text-caption text-medium-emphasis">
              Peak: {{ range.peak_day.date }} ({{ fmt(range.peak_day.request_count) }})
            </div>
          </v-col>
        </v-row>

        <div v-if="range.daily.length" class="usage-bars mt-3" style="height: 120px;">
          <div
            v-for="d in range.daily"
            :key="d.date"
            class="usage-bar-wrap"
            :title="`${d.date}: ${d.request_count} requests`"
          >
            <div
              class="usage-bar"
              :class="{ 'is-peak': range.peak_day && d.request_count === range.peak_day.request_count && d.request_count > 0 }"
              :style="{ height: rangeBarHeight(d.request_count) + '%' }"
            />
          </div>
        </div>
        <div v-else class="text-medium-emphasis text-center py-3 text-caption">
          No requests in this range.
        </div>
      </div>
    </v-card>

    <div v-if="data">
      <!-- KPI cards row 1 -->
      <v-row dense>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Requests this month</div>
              <v-icon size="20" color="primary">mdi-pulse</v-icon>
            </div>
            <div class="text-h4 font-weight-bold mt-1">
              {{ fmt(data.current_month.total_requests) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              Day {{ data.current_month.days_elapsed }} of
              {{ data.current_month.days_elapsed + data.current_month.days_remaining }}
            </div>
            <v-progress-linear
              :model-value="monthProgress"
              color="primary"
              height="6"
              rounded
              class="mt-2"
            />
          </v-card>
        </v-col>

        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Cost so far</div>
              <v-icon size="20" color="info">mdi-cash</v-icon>
            </div>
            <div class="text-h4 font-weight-bold mt-1">
              {{ formatMoney(data.current_month.cost_so_far, data.rate.currency) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">At current rate</div>
          </v-card>
        </v-col>

        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4" color="primary" variant="tonal">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Projected month-end cost</div>
              <v-icon size="20">mdi-trending-up</v-icon>
            </div>
            <div class="text-h4 font-weight-bold mt-1">
              {{ formatMoney(data.current_month.projected_cost, data.rate.currency) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              ~{{ fmt(data.current_month.projected_requests) }} requests
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Current rate</div>
              <v-icon size="20" color="success">mdi-tag</v-icon>
            </div>
            <div class="text-h6 font-weight-bold mt-1">
              {{ fmt(data.rate.requests_per_unit) }} req
              = {{ formatMoney(data.rate.unit_cost, data.rate.currency) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              Effective {{ formatDate(data.rate.effective_from) }}
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- KPI row 2: comparisons -->
      <v-row dense class="mt-1">
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Today</div>
            <div class="text-h5 font-weight-bold mt-1">
              {{ fmt(data.comparison.today_requests) }}
            </div>
            <div class="text-caption mt-1" :class="todayDelta.color">
              <v-icon size="14">{{ todayDelta.icon }}</v-icon>
              {{ todayDelta.text }} vs yesterday
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">7-day average</div>
            <div class="text-h5 font-weight-bold mt-1">
              {{ fmt(data.comparison.trailing_7d_average) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ fmt(data.comparison.trailing_7d_total) }} req in last 7 days
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Daily average (this month)</div>
            <div class="text-h5 font-weight-bold mt-1">
              {{ fmt(data.current_month.daily_average_so_far) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              over {{ data.current_month.days_elapsed }} day(s)
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Month-over-month</div>
            <div class="text-h5 font-weight-bold mt-1" :class="momDelta.color">
              <v-icon size="20">{{ momDelta.icon }}</v-icon>
              {{ momDelta.text }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              vs same period last month
              ({{ fmt(data.comparison.previous_same_period_total) }})
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Charts row -->
      <v-row dense class="mt-1">
        <v-col cols="12" md="8">
          <v-card rounded="lg" class="pa-4">
            <div class="d-flex align-center mb-3">
              <v-icon class="mr-2">mdi-chart-bar</v-icon>
              <h3 class="text-h6 font-weight-bold">Daily requests (last 30 days)</h3>
              <v-spacer />
              <v-chip size="x-small" variant="tonal" color="primary">
                Peak: {{ fmt(peakValue) }}
              </v-chip>
            </div>
            <div v-if="!data.daily_last_30_days.length" class="text-medium-emphasis py-6 text-center">
              No requests recorded yet.
            </div>
            <div v-else class="usage-bars">
              <div
                v-for="d in data.daily_last_30_days"
                :key="d.date"
                class="usage-bar-wrap"
                :title="`${d.date}: ${d.request_count} requests`"
              >
                <div
                  class="usage-bar"
                  :class="{ 'is-peak': d.request_count === peakValue && peakValue > 0 }"
                  :style="{ height: barHeight(d.request_count) + '%' }"
                />
                <div class="usage-bar-label">{{ String(d.date).slice(8) }}</div>
              </div>
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" md="4">
          <v-card rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-icon class="mr-2">mdi-calendar-week</v-icon>
              <h3 class="text-h6 font-weight-bold">By day of week</h3>
            </div>
            <div v-if="weekdayMax === 0" class="text-medium-emphasis py-6 text-center">
              No data yet.
            </div>
            <div v-else>
              <div
                v-for="w in data.weekday_breakdown"
                :key="w.weekday"
                class="d-flex align-center mb-2"
              >
                <div class="weekday-label">{{ w.label }}</div>
                <div class="weekday-bar-wrap">
                  <div class="weekday-bar" :style="{ width: weekdayWidth(w.total) + '%' }" />
                </div>
                <div class="weekday-val">{{ fmt(w.total) }}</div>
              </div>
              <div class="text-caption text-medium-emphasis mt-2">
                Last 30 days
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Monthly trend + highlights -->
      <v-row dense class="mt-1">
        <v-col cols="12" md="8">
          <v-card rounded="lg" class="pa-4">
            <div class="d-flex align-center mb-3">
              <v-icon class="mr-2">mdi-chart-timeline-variant</v-icon>
              <h3 class="text-h6 font-weight-bold">Last 6 months</h3>
            </div>
            <div class="monthly-bars">
              <div
                v-for="m in data.monthly_history"
                :key="m.label"
                class="monthly-bar-wrap"
              >
                <div class="monthly-bar-value">{{ fmt(m.total_requests) }}</div>
                <div
                  class="monthly-bar"
                  :class="{ 'is-current': m.year === data.current_month.year && m.month === data.current_month.month }"
                  :style="{ height: monthlyHeight(m.total_requests) + '%' }"
                />
                <div class="monthly-bar-label">{{ m.label }}</div>
                <div class="monthly-bar-cost">{{ formatMoney(m.cost, data.rate.currency) }}</div>
              </div>
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" md="4">
          <v-card rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-icon class="mr-2">mdi-information-outline</v-icon>
              <h3 class="text-h6 font-weight-bold">Highlights</h3>
            </div>
            <v-list density="compact" class="pa-0 bg-transparent">
              <v-list-item v-if="data.current_month.peak_day" class="px-0">
                <template #prepend><v-icon color="warning">mdi-fire</v-icon></template>
                <v-list-item-title>
                  Peak day: {{ data.current_month.peak_day.date }}
                </v-list-item-title>
                <v-list-item-subtitle>
                  {{ fmt(data.current_month.peak_day.request_count) }} requests
                </v-list-item-subtitle>
              </v-list-item>
              <v-list-item class="px-0">
                <template #prepend><v-icon color="info">mdi-history</v-icon></template>
                <v-list-item-title>Previous month total</v-list-item-title>
                <v-list-item-subtitle>
                  {{ fmt(data.comparison.previous_month.total_requests) }} req ·
                  {{ formatMoney(data.comparison.previous_month.cost, data.rate.currency) }}
                </v-list-item-subtitle>
              </v-list-item>
              <v-list-item class="px-0">
                <template #prepend><v-icon color="success">mdi-clock-outline</v-icon></template>
                <v-list-item-title>Days remaining</v-list-item-title>
                <v-list-item-subtitle>
                  {{ data.current_month.days_remaining }} days until next bill
                </v-list-item-subtitle>
              </v-list-item>
              <v-list-item class="px-0">
                <template #prepend><v-icon color="primary">mdi-target</v-icon></template>
                <v-list-item-title>Burn rate</v-list-item-title>
                <v-list-item-subtitle>
                  {{ formatMoney(burnRatePerDay, data.rate.currency) }} / day
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <!-- Recent bills -->
      <v-card rounded="lg" class="mt-4">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-receipt</v-icon>
          Recent monthly bills
        </v-card-title>
        <v-data-table
          :headers="billHeaders"
          :items="data.recent_bills"
          density="comfortable"
          :items-per-page="6"
          hide-default-footer
        >
          <template #item.period="{ item }">
            {{ item.year }}-{{ String(item.month).padStart(2, '0') }}
          </template>
          <template #item.total_requests="{ item }">{{ fmt(item.total_requests) }}</template>
          <template #item.amount="{ item }">{{ formatMoney(item.amount, item.currency) }}</template>
          <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
          <template #no-data>
            <div class="text-medium-emphasis py-4 text-center">No bills issued yet.</div>
          </template>
        </v-data-table>
      </v-card>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="primary" />
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatDate, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const data = ref(null)
const loading = ref(false)
const error = ref(null)

const presets = [
  { label: 'Today', value: 'today' },
  { label: 'Yesterday', value: 'yesterday' },
  { label: 'Last 7 days', value: 'last_7_days' },
  { label: 'Last 14 days', value: 'last_14_days' },
  { label: 'Last 30 days', value: 'last_30_days' },
  { label: 'This month', value: 'this_month' },
  { label: 'Last month', value: 'last_month' },
  { label: 'This year', value: 'this_year' },
  { label: 'Custom', value: 'custom' }
]
const preset = ref('last_7_days')
const customStart = ref('')
const customEnd = ref('')
const range = ref(null)
const rangeLoading = ref(false)

const customLabel = computed(() => {
  if (customStart.value && customEnd.value) return `${customStart.value} → ${customEnd.value}`
  return 'Pick dates'
})

const rangePeak = computed(() => range.value?.peak_day?.request_count || 0)
function rangeBarHeight(v) {
  return Math.max(2, Math.round((v / Math.max(rangePeak.value, 1)) * 100))
}

async function loadRange() {
  rangeLoading.value = true
  try {
    const params = { preset: preset.value }
    if (preset.value === 'custom') {
      if (!customStart.value || !customEnd.value) { rangeLoading.value = false; return }
      params.start = customStart.value
      params.end = customEnd.value
    }
    const { data: res } = await $api.get('/usage-billing/range/', { params })
    range.value = res
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load range data.'
  } finally {
    rangeLoading.value = false
  }
}

const billHeaders = [
  { title: 'Period', key: 'period' },
  { title: 'Requests', key: 'total_requests' },
  { title: 'Amount', key: 'amount' },
  { title: 'Status', key: 'status' }
]

function fmt(v) {
  if (v == null) return '—'
  return Number(v).toLocaleString()
}

const peakValue = computed(() => {
  if (!data.value?.daily_last_30_days?.length) return 0
  return Math.max(...data.value.daily_last_30_days.map((d) => d.request_count), 0)
})

function barHeight(v) {
  return Math.max(2, Math.round((v / Math.max(peakValue.value, 1)) * 100))
}

const weekdayMax = computed(() => {
  if (!data.value?.weekday_breakdown) return 0
  return Math.max(...data.value.weekday_breakdown.map((w) => w.total), 0)
})
function weekdayWidth(v) {
  return Math.max(2, Math.round((v / Math.max(weekdayMax.value, 1)) * 100))
}

const monthlyMax = computed(() => {
  if (!data.value?.monthly_history) return 0
  return Math.max(...data.value.monthly_history.map((m) => m.total_requests), 0)
})
function monthlyHeight(v) {
  return Math.max(4, Math.round((v / Math.max(monthlyMax.value, 1)) * 100))
}

const monthProgress = computed(() => {
  if (!data.value) return 0
  const e = data.value.current_month.days_elapsed
  const total = e + data.value.current_month.days_remaining
  return total ? Math.round((e / total) * 100) : 0
})

const todayDelta = computed(() => {
  const t = data.value?.comparison?.today_requests || 0
  const y = data.value?.comparison?.yesterday_requests || 0
  if (!y) return { text: t ? '+∞%' : '—', color: 'text-medium-emphasis', icon: 'mdi-minus' }
  const pct = ((t - y) / y) * 100
  if (pct > 0) return { text: `+${pct.toFixed(1)}%`, color: 'text-success', icon: 'mdi-trending-up' }
  if (pct < 0) return { text: `${pct.toFixed(1)}%`, color: 'text-error', icon: 'mdi-trending-down' }
  return { text: '0%', color: 'text-medium-emphasis', icon: 'mdi-minus' }
})

const momDelta = computed(() => {
  const v = data.value?.comparison?.mom_change_pct
  if (v == null) return { text: '—', color: 'text-medium-emphasis', icon: 'mdi-minus' }
  if (v > 0) return { text: `+${v}%`, color: 'text-success', icon: 'mdi-trending-up' }
  if (v < 0) return { text: `${v}%`, color: 'text-error', icon: 'mdi-trending-down' }
  return { text: '0%', color: 'text-medium-emphasis', icon: 'mdi-minus' }
})

const burnRatePerDay = computed(() => {
  if (!data.value) return 0
  const d = data.value.current_month.days_elapsed || 1
  return Number(data.value.current_month.cost_so_far) / d
})

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data: res } = await $api.get('/usage-billing/dashboard/')
    data.value = res
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load usage data.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  load()
  loadRange()
})
</script>

<style scoped>
.h-100 { height: 100%; }

/* Daily bars */
.usage-bars {
  display: flex;
  align-items: flex-end;
  gap: 4px;
  height: 200px;
  padding: 8px 0;
  overflow-x: auto;
}
.usage-bar-wrap {
  flex: 1 0 18px;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  min-width: 18px;
}
.usage-bar {
  width: 100%;
  background: linear-gradient(180deg, rgb(var(--v-theme-primary)) 0%, rgba(var(--v-theme-primary), 0.5) 100%);
  border-radius: 4px 4px 0 0;
  transition: height 0.2s;
}
.usage-bar.is-peak {
  background: linear-gradient(180deg, rgb(var(--v-theme-warning)) 0%, rgba(var(--v-theme-warning), 0.5) 100%);
}
.usage-bar-label {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  margin-top: 4px;
}

/* Weekday rows */
.weekday-label {
  width: 36px;
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.weekday-bar-wrap {
  flex: 1;
  height: 10px;
  background: rgba(var(--v-theme-on-surface), 0.06);
  border-radius: 4px;
  overflow: hidden;
  margin: 0 8px;
}
.weekday-bar {
  height: 100%;
  background: rgb(var(--v-theme-primary));
  border-radius: 4px;
  transition: width 0.3s;
}
.weekday-val {
  width: 60px;
  text-align: right;
  font-size: 12px;
  font-weight: 600;
}

/* Monthly bars */
.monthly-bars {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  height: 200px;
  padding: 24px 0 0;
}
.monthly-bar-wrap {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  position: relative;
}
.monthly-bar-value {
  font-size: 11px;
  font-weight: 600;
  margin-bottom: 4px;
}
.monthly-bar {
  width: 60%;
  background: rgba(var(--v-theme-primary), 0.4);
  border-radius: 4px 4px 0 0;
  transition: height 0.3s;
}
.monthly-bar.is-current {
  background: linear-gradient(180deg, rgb(var(--v-theme-primary)) 0%, rgba(var(--v-theme-primary), 0.6) 100%);
}
.monthly-bar-label {
  font-size: 11px;
  margin-top: 4px;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.monthly-bar-cost {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
</style>
