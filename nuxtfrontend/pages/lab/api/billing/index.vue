<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Lab API Usage & Billing"
      icon="mdi-test-tube"
      subtitle="Per-tenant metering of /api/lab/* requests"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading || rangeLoading" @click="loadAll">
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4" closable @click:close="error=''">
      {{ error }}
    </v-alert>

    <!-- ── Range / Filter bar ─────────────────────────────────────────── -->
    <v-card rounded="lg" class="pa-3 mb-4">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-icon class="mr-1" color="primary">mdi-filter-variant</v-icon>
        <span class="text-subtitle-2 mr-2">Date range</span>
        <v-chip-group
          v-model="preset"
          mandatory
          selected-class="text-primary"
          @update:model-value="onPresetChange"
        >
          <v-chip
            v-for="p in presets"
            :key="p.value"
            :value="p.value"
            size="small"
            variant="tonal"
          >
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
            <v-btn
              block
              color="primary"
              size="small"
              :disabled="!customStart || !customEnd"
              @click="loadRange"
            >
              Apply
            </v-btn>
          </v-card>
        </v-menu>
      </div>

      <v-divider class="my-3" />

      <div v-if="rangeLoading" class="d-flex justify-center py-4">
        <v-progress-circular indeterminate size="28" color="primary" />
      </div>
      <div v-else-if="range">
        <v-row dense>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Range</div>
            <div class="text-subtitle-2 font-weight-bold">
              {{ range.start }} → {{ range.end }}
            </div>
            <div class="text-caption text-medium-emphasis">{{ range.days }} day(s)</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Lab requests</div>
            <div class="text-h6 font-weight-bold">{{ fmt(range.total_requests) }}</div>
            <div class="text-caption">of {{ fmt(range.all_requests) }} total · {{ range.share_pct }}%</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Avg / day</div>
            <div class="text-h6 font-weight-bold">{{ fmt(range.average_per_day) }}</div>
            <div class="text-caption">{{ range.active_days }} active day(s)</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Peak day</div>
            <div class="text-h6 font-weight-bold">
              {{ range.peak_day ? fmt(range.peak_day.request_count) : '—' }}
            </div>
            <div class="text-caption">{{ range.peak_day?.date || '—' }}</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Avg / active day</div>
            <div class="text-h6 font-weight-bold">{{ fmt(range.average_per_active_day) }}</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Cost</div>
            <div class="text-h6 font-weight-bold">{{ fmt(range.cost) }}</div>
            <div class="text-caption">
              {{ range.rate?.requests_per_unit }} req → {{ fmt(range.rate?.unit_cost) }}
            </div>
          </v-col>
        </v-row>

        <div v-if="(range.daily || []).length" class="usage-bars mt-4">
          <div
            v-for="d in range.daily"
            :key="d.date"
            class="usage-bar-wrap"
          >
            <div
              class="usage-bar"
              :class="{ 'is-peak': range.peak_day && d.date === range.peak_day.date }"
              :style="{ height: barHeight(d.request_count, rangeMax) + '%' }"
              :title="`${d.date}: ${d.request_count}`"
            />
            <div class="usage-bar-label">{{ shortDay(d.date) }}</div>
          </div>
        </div>
        <div v-else class="text-center text-medium-emphasis py-6">
          No lab requests in this range yet.
        </div>
      </div>
    </v-card>

    <div v-if="loading && !data" class="d-flex justify-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <template v-if="data">
      <!-- ── KPI row (current month) ──────────────────────────────────── -->
      <v-row dense class="mb-2">
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4 kpi" color="primary" variant="tonal">
            <div class="text-caption text-medium-emphasis">Lab requests this month</div>
            <div class="text-h5 font-weight-bold">{{ fmt(cm.total_requests) }}</div>
            <div class="text-caption mt-1">
              of {{ fmt(cm.all_requests) }} total · {{ cm.share_pct }}% share
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4 kpi" color="success" variant="tonal">
            <div class="text-caption text-medium-emphasis">Cost so far</div>
            <div class="text-h5 font-weight-bold">{{ fmt(cm.cost_so_far) }}</div>
            <div class="text-caption mt-1">Projected: {{ fmt(cm.projected_cost) }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4 kpi" color="info" variant="tonal">
            <div class="text-caption text-medium-emphasis">Daily average</div>
            <div class="text-h5 font-weight-bold">{{ fmt(cm.daily_average_so_far) }}</div>
            <div class="text-caption mt-1">{{ cm.days_elapsed }} of {{ cm.days_elapsed + cm.days_remaining }} days</div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4 kpi" color="warning" variant="tonal">
            <div class="text-caption text-medium-emphasis">Peak day this month</div>
            <div class="text-h5 font-weight-bold">
              {{ cm.peak_day ? fmt(cm.peak_day.request_count) : '—' }}
            </div>
            <div class="text-caption mt-1">
              {{ cm.peak_day ? cm.peak_day.date : 'No data yet' }}
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Comparison strip -->
      <v-card rounded="lg" class="pa-4 mb-3">
        <div class="d-flex flex-wrap ga-6 align-center">
          <div>
            <div class="text-caption text-medium-emphasis">Today</div>
            <div class="text-h6 font-weight-bold">{{ fmt(cmp.today_requests) }}</div>
          </div>
          <v-divider vertical />
          <div>
            <div class="text-caption text-medium-emphasis">Yesterday</div>
            <div class="text-h6 font-weight-bold">{{ fmt(cmp.yesterday_requests) }}</div>
          </div>
          <v-divider vertical />
          <div>
            <div class="text-caption text-medium-emphasis">7-day total</div>
            <div class="text-h6 font-weight-bold">{{ fmt(cmp.trailing_7d_total) }}</div>
            <div class="text-caption">Avg {{ fmt(cmp.trailing_7d_average) }}</div>
          </div>
          <v-divider vertical />
          <div>
            <div class="text-caption text-medium-emphasis">vs Previous month</div>
            <div class="text-h6 font-weight-bold">
              <span v-if="cmp.mom_change_pct === null" class="text-medium-emphasis">—</span>
              <span v-else :class="cmp.mom_change_pct >= 0 ? 'text-success' : 'text-error'">
                {{ cmp.mom_change_pct >= 0 ? '+' : '' }}{{ cmp.mom_change_pct }}%
              </span>
            </div>
            <div class="text-caption">Prev: {{ fmt(cmp.previous_month.total_requests) }}</div>
          </div>
          <v-spacer />
          <div class="text-right">
            <div class="text-caption text-medium-emphasis">Rate</div>
            <div class="text-body-2">
              {{ data.rate.requests_per_unit }} req → {{ fmt(data.rate.unit_cost) }}
            </div>
          </div>
        </div>
      </v-card>

      <!-- Daily chart current month -->
      <v-card rounded="lg" class="pa-4 mb-3">
        <div class="d-flex align-center mb-2">
          <v-icon class="mr-2" color="primary">mdi-chart-bar</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Daily lab requests · this month</div>
        </div>
        <div v-if="!(data.daily_current_month || []).length" class="text-medium-emphasis text-center py-6">
          No lab requests recorded yet this month.
        </div>
        <div v-else class="usage-bars">
          <div
            v-for="d in data.daily_current_month"
            :key="d.date"
            class="usage-bar-wrap"
          >
            <div
              class="usage-bar"
              :class="{ 'is-peak': cm.peak_day && d.date === cm.peak_day.date }"
              :style="{ height: barHeight(d.request_count, maxDaily) + '%' }"
              :title="`${d.date}: ${d.request_count}`"
            />
            <div class="usage-bar-label">{{ shortDay(d.date) }}</div>
          </div>
        </div>
      </v-card>

      <v-row dense>
        <!-- Monthly history -->
        <v-col cols="12" md="7">
          <v-card rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-2">
              <v-icon class="mr-2" color="info">mdi-calendar-month</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Last 6 months</div>
            </div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>Month</th>
                  <th class="text-right">Lab requests</th>
                  <th class="text-right">Cost</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="m in data.monthly_history" :key="m.label">
                  <td>{{ m.label }}</td>
                  <td class="text-right">{{ fmt(m.total_requests) }}</td>
                  <td class="text-right">{{ fmt(m.cost) }}</td>
                </tr>
              </tbody>
            </v-table>
          </v-card>
        </v-col>

        <!-- Weekday breakdown -->
        <v-col cols="12" md="5">
          <v-card rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-2">
              <v-icon class="mr-2" color="success">mdi-calendar-week</v-icon>
              <div class="text-subtitle-1 font-weight-bold">
                Weekday distribution
                <span class="text-caption text-medium-emphasis ml-1">
                  · {{ range ? activePresetLabel : 'last 30 days' }}
                </span>
              </div>
            </div>
            <div class="d-flex align-end ga-2 mt-3" style="height: 160px">
              <div
                v-for="w in weekdaySource"
                :key="w.weekday"
                class="flex-grow-1 d-flex flex-column align-center"
              >
                <div
                  class="weekday-bar"
                  :style="{ height: barHeight(w.total, maxWeekday) + '%' }"
                  :title="`${w.label}: ${w.total} (avg ${w.average})`"
                />
                <div class="text-caption mt-1">{{ w.label }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

const presets = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'last_7_days', label: 'Last 7 days' },
  { value: 'last_14_days', label: 'Last 14 days' },
  { value: 'last_30_days', label: 'Last 30 days' },
  { value: 'this_month', label: 'This month' },
  { value: 'last_month', label: 'Last month' },
  { value: 'this_year', label: 'This year' },
  { value: 'custom', label: 'Custom' },
]

const data = ref(null)
const range = ref(null)
const loading = ref(false)
const rangeLoading = ref(false)
const error = ref('')

const preset = ref('last_7_days')
const customStart = ref('')
const customEnd = ref('')

const cm = computed(() => data.value?.current_month || {})
const cmp = computed(() => data.value?.comparison || {})

const maxDaily = computed(() =>
  Math.max(1, ...(data.value?.daily_current_month || []).map(d => d.request_count))
)
const rangeMax = computed(() =>
  Math.max(1, ...(range.value?.daily || []).map(d => d.request_count))
)

const weekdaySource = computed(() =>
  range.value?.weekday_breakdown?.length
    ? range.value.weekday_breakdown
    : (data.value?.weekday_breakdown || [])
)
const maxWeekday = computed(() =>
  Math.max(1, ...weekdaySource.value.map(w => w.total))
)

const activePresetLabel = computed(
  () => presets.find(p => p.value === preset.value)?.label || 'range'
)
const customLabel = computed(() => {
  if (customStart.value && customEnd.value) return `${customStart.value} → ${customEnd.value}`
  return 'Pick dates'
})

function fmt(v) {
  if (v === null || v === undefined || v === '') return '0'
  const n = Number(v)
  if (Number.isNaN(n)) return v
  return n.toLocaleString(undefined, { maximumFractionDigits: 2 })
}

function barHeight(v, max) {
  if (!max) return 0
  return Math.max(2, Math.round((v / max) * 100))
}

function shortDay(d) {
  if (!d) return ''
  const parts = String(d).split('-')
  return parts.length >= 3 ? parts[2] : d
}

async function loadDashboard() {
  loading.value = true
  error.value = ''
  try {
    const res = await $api.get('/usage-billing/lab/dashboard/')
    data.value = res.data ?? res
  } catch (e) {
    error.value = e?.response?.data?.detail || e?.message || 'Failed to load lab usage.'
  } finally {
    loading.value = false
  }
}

async function loadRange() {
  rangeLoading.value = true
  error.value = ''
  try {
    const params = {}
    if (preset.value === 'custom') {
      if (!customStart.value || !customEnd.value) {
        rangeLoading.value = false
        return
      }
      params.preset = 'custom'
      params.start = customStart.value
      params.end = customEnd.value
    } else {
      params.preset = preset.value
    }
    const res = await $api.get('/usage-billing/lab/range/', { params })
    range.value = res.data ?? res
  } catch (e) {
    error.value = e?.response?.data?.detail || e?.message || 'Failed to load range data.'
  } finally {
    rangeLoading.value = false
  }
}

function onPresetChange() {
  if (preset.value !== 'custom') loadRange()
}

async function loadAll() {
  await Promise.all([loadDashboard(), loadRange()])
}

onMounted(loadAll)
</script>

<style scoped>
.kpi { min-height: 110px; }
.usage-bars {
  display: flex;
  align-items: flex-end;
  gap: 4px;
  height: 180px;
  padding-top: 8px;
  overflow-x: auto;
}
.usage-bar-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 22px;
  height: 100%;
}
.usage-bar {
  width: 16px;
  background: linear-gradient(180deg, rgb(var(--v-theme-primary)) 0%, rgba(var(--v-theme-primary), 0.6) 100%);
  border-radius: 3px 3px 0 0;
  transition: height 0.3s ease;
}
.usage-bar.is-peak {
  background: linear-gradient(180deg, rgb(var(--v-theme-warning)) 0%, rgba(var(--v-theme-warning), 0.7) 100%);
}
.usage-bar-label {
  font-size: 10px;
  margin-top: 2px;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.weekday-bar {
  width: 100%;
  max-width: 36px;
  background: linear-gradient(180deg, rgb(var(--v-theme-success)) 0%, rgba(var(--v-theme-success), 0.6) 100%);
  border-radius: 3px 3px 0 0;
  transition: height 0.3s ease;
}
</style>
