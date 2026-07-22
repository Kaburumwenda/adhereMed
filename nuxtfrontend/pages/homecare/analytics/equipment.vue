<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Equipment Hire Analytics"
      subtitle="Equipment rental performance, top performers and ABC (Pareto) classification by hire revenue."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-truck-delivery"
      :chips="[
        { icon: 'mdi-cash-multiple', label: `${money(d.total_hire_revenue)} revenue` },
        { icon: 'mdi-counter', label: `${d.total_hires} hires` },
        { icon: 'mdi-truck', label: `${d.active_hires} active` },
        { icon: 'mdi-cube', label: `${d.devices_with_hires} devices hired` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Date range + insight bar -->
    <div class="d-flex flex-wrap align-center justify-space-between mt-4 mb-2 ga-2">
      <AnalyticsDateFilter
        :model-value="range"
        :from="customFrom"
        :to="customTo"
        @change="onRangeChange"
      />
      <div class="text-body-2 text-medium-emphasis">
        <v-icon icon="mdi-information-outline" size="14" class="mr-1" />
        ABC classifies devices by cumulative hire revenue: <strong>A</strong> ≤80% · <strong>B</strong> ≤95% · <strong>C</strong> &gt;95%
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Hire Revenue" :value="money(d.total_hire_revenue)" icon="mdi-cash-multiple" color="#0d9488" :hint="rangeLabel" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Hires" :value="d.total_hires || 0" icon="mdi-counter" color="#0ea5e9" :hint="`${d.devices_with_hires || 0} devices`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Active Hires" :value="d.active_hires || 0" icon="mdi-truck" color="#7c3aed" :hint="`${money(d.deposits_held)} deposits`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Avg / Hire" :value="money(d.avg_revenue_per_hire)" icon="mdi-chart-timeline-variant" color="#f59e0b" :hint="`${d.rentable_devices || 0} rentable`" />
      </v-col>
    </v-row>

    <!-- ABC summary cards -->
    <v-row class="mt-3">
      <v-col v-for="g in d.abc_summary || []" :key="g.grade" cols="12" md="4">
        <v-card
          rounded="lg" border class="pa-4 cursor-pointer h-100"
          :variant="abcFilter === g.grade ? 'tonal' : 'flat'"
          :color="abcFilter === g.grade ? gradeColor(g.grade) : undefined"
          @click="abcFilter = abcFilter === g.grade ? null : g.grade; abcPage = 1"
        >
          <div class="d-flex align-center mb-2">
            <v-avatar :color="gradeColor(g.grade)" size="40" class="mr-3">
              <span class="text-h6 font-weight-bold text-white">{{ g.grade }}</span>
            </v-avatar>
            <div>
              <div class="text-subtitle-2 font-weight-bold">Class {{ g.grade }} — {{ gradeLabel(g.grade) }}</div>
              <div class="text-caption text-medium-emphasis">{{ gradeDesc(g.grade) }}</div>
            </div>
            <v-spacer />
            <v-icon v-if="abcFilter === g.grade" :color="gradeColor(g.grade)" size="20">mdi-filter-check</v-icon>
          </div>
          <v-row dense>
            <v-col cols="4" class="text-center">
              <div class="text-h6 font-weight-bold">{{ g.count }}</div>
              <div class="text-caption text-medium-emphasis">Devices</div>
            </v-col>
            <v-col cols="4" class="text-center">
              <div class="text-h6 font-weight-bold">{{ money(g.revenue) }}</div>
              <div class="text-caption text-medium-emphasis">Revenue</div>
            </v-col>
            <v-col cols="4" class="text-center">
              <div class="text-h6 font-weight-bold">{{ g.pct.toFixed(1) }}%</div>
              <div class="text-caption text-medium-emphasis">of total</div>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>

    <!-- Equipment performance — ABC Analysis (Pareto) -->
    <v-row class="mt-3">
      <v-col cols="12">
        <HomecarePanel title="Equipment performance — ABC Analysis (Pareto)"
                       subtitle="Devices ranked by hire revenue with cumulative classification"
                       icon="mdi-sort-alphabetical-variant" color="#0d9488">
          <template #actions>
            <v-text-field v-model="search" placeholder="Search device…"
                          prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                          hide-details clearable style="max-width: 200px;" />
          </template>

          <v-chip v-if="abcFilter" closable :color="gradeColor(abcFilter)" variant="tonal"
                  class="mb-3" @click:close="abcFilter = null; abcPage = 1">
            Showing Class {{ abcFilter }} only
          </v-chip>

          <EmptyState v-if="!abcFiltered.length" icon="mdi-truck" title="No hire data" message="No equipment generated hire revenue in this period." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:40px">#</th>
                <th>Device</th>
                <th>Type</th>
                <th class="text-right">Hires</th>
                <th class="text-right">Active</th>
                <th class="text-right">Revenue</th>
                <th style="width:22%">Cumulative %</th>
                <th style="width:70px" class="text-center">Grade</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in abcPaged" :key="p.id">
                <td class="text-medium-emphasis">{{ (abcPage - 1) * pageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:200px">{{ p.name }}</td>
                <td><v-chip size="x-small" variant="tonal" color="purple">{{ p.device_type_label }}</v-chip></td>
                <td class="text-right">{{ p.hire_count }}</td>
                <td class="text-right">
                  <v-chip v-if="p.active_hires" size="x-small" variant="tonal" color="info">{{ p.active_hires }}</v-chip>
                  <span v-else class="text-medium-emphasis">—</span>
                </td>
                <td class="text-right font-weight-medium">{{ money(p.revenue) }}</td>
                <td>
                  <div class="d-flex align-center" style="gap:8px">
                    <v-progress-linear :model-value="p.cumulative_pct" :color="gradeColor(p.grade)"
                                       height="6" rounded style="flex:1" />
                    <span class="text-caption text-medium-emphasis" style="min-width:42px; text-align:right">{{ p.cumulative_pct.toFixed(1) }}%</span>
                  </div>
                </td>
                <td class="text-center"><v-chip :color="gradeColor(p.grade)" size="small" variant="flat">{{ p.grade }}</v-chip></td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="abcFiltered.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="abcPage" :length="Math.ceil(abcFiltered.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Revenue by type (pie on left, analysis on right) -->
    <v-row class="mt-3">
      <v-col cols="12">
        <HomecarePanel title="Revenue by type" subtitle="Hire earnings per device category"
                       icon="mdi-shape" color="#7c3aed">
          <v-row dense align="center">
            <v-col cols="12" md="5" class="d-flex justify-center">
              <DonutRing v-if="typeSegments.length" :segments="typeSegments" :size="200" :thickness="24">
                <div class="text-center">
                  <div class="text-h6 font-weight-bold text-purple">{{ money(d.total_hire_revenue) }}</div>
                  <div class="text-caption text-medium-emphasis">total</div>
                </div>
              </DonutRing>
              <EmptyState v-else icon="mdi-shape" title="No data" dense />
            </v-col>
            <v-col cols="12" md="7">
              <v-table v-if="(d.by_type || []).length" density="comfortable" hover class="bg-transparent">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th class="text-right">Devices</th>
                    <th class="text-right">Hires</th>
                    <th style="width:30%">Revenue share</th>
                    <th class="text-right">Revenue</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="t in d.by_type || []" :key="t.type">
                    <td class="font-weight-medium">
                      <v-icon icon="mdi-circle" :color="typeColor(t.type)" size="9" class="mr-2" />
                      {{ t.label }}
                    </td>
                    <td class="text-right text-medium-emphasis">{{ t.devices }}</td>
                    <td class="text-right">{{ t.hires }}</td>
                    <td>
                      <div class="d-flex align-center" style="gap:8px">
                        <v-progress-linear :model-value="typeShare(t)" :color="typeColor(t.type)"
                                           height="6" rounded style="flex:1" />
                        <span class="text-caption text-medium-emphasis" style="min-width:42px; text-align:right">{{ typeShare(t).toFixed(1) }}%</span>
                      </div>
                    </td>
                    <td class="text-right font-weight-bold">{{ money(t.revenue) }}</td>
                  </tr>
                </tbody>
              </v-table>
              <EmptyState v-else icon="mdi-shape" title="No data" dense />
            </v-col>
          </v-row>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Charts row -->
    <v-row class="mt-3">
      <!-- Top performers bar chart -->
      <v-col cols="12" lg="8">
        <HomecarePanel title="Top 7 equipment by hire revenue"
                       subtitle="Highest-earning devices in the selected period"
                       icon="mdi-trophy-variant" color="#0d9488">
          <BarChart v-if="topChart.values.length" :values="topChart.values" :labels="topChart.labels"
                    :colors="topChart.colors" :height="260" rotate-labels show-values
                    :y-formatter="moneyFmt" />
          <EmptyState v-else icon="mdi-truck" title="No hires in this period" message="No equipment was hired out in the selected date range." />
        </HomecarePanel>
      </v-col>

      <!-- Hire trend -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Hire activity" subtitle="Hires started per day"
                       icon="mdi-chart-line" color="#0ea5e9">
          <LineChart v-if="(d.hire_trend?.values || []).some(v => v > 0)"
                     :series="[{ label: 'Hires', color: '#0ea5e9', values: d.hire_trend.values }]"
                     :labels="d.hire_trend.labels" :height="260" />
          <EmptyState v-else icon="mdi-chart-line" title="No activity" dense />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Hire records / history -->
    <v-row class="mt-3">
      <v-col cols="12">
        <HomecarePanel title="Hire records" subtitle="Complete device hire history for the selected period"
                       icon="mdi-clipboard-text-clock" color="#0ea5e9">
          <template #actions>
            <div class="d-flex align-center ga-2">
              <v-text-field v-model="recordsSearch" placeholder="Search device, patient, facility…"
                            prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                            hide-details clearable style="max-width: 260px;" @update:model-value="debouncedLoadRecords" />
              <v-select v-model="recordsStatus" :items="statusFilterOptions" item-title="label" item-value="value"
                        density="compact" variant="outlined" hide-details clearable
                        prepend-inner-icon="mdi-filter-variant" style="max-width: 160px;"
                        @update:model-value="loadRecords" />
            </div>
          </template>

          <EmptyState v-if="!recordsLoading && !records.length" icon="mdi-truck" title="No hire records" message="No device assignments in this period." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:40px">#</th>
                <th>Device</th>
                <th>Hired to</th>
                <th>Period</th>
                <th class="text-right">Rate</th>
                <th class="text-right">Charge</th>
                <th class="text-right">Deposit</th>
                <th>Started</th>
                <th>Returned</th>
                <th class="text-center">Status</th>
                <th class="text-center" style="width:48px"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in records" :key="r.id">
                <td class="text-medium-emphasis">{{ (recordsPage - 1) * recordsPageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:180px">{{ r.device_name }}</td>
                <td>
                  <div class="d-flex align-center">
                    <v-icon :icon="r.hire_to_type === 'facility' ? 'mdi-hospital-building' : 'mdi-account'" size="14" class="mr-1" />
                    <span class="text-body-2">{{ r.hire_to_name || r.patient_name || r.facility_name || '—' }}</span>
                  </div>
                </td>
                <td><span v-if="r.hire_period_label" class="text-body-2 text-medium-emphasis">{{ r.hire_period_label }}</span><span v-else class="text-medium-emphasis">—</span></td>
                <td class="text-right text-medium-emphasis">
                  <span v-if="r.hire_rate">{{ money(r.hire_rate) }}<span class="text-caption">/{{ periodShort(r.hire_period) }}</span></span>
                  <span v-else>—</span>
                </td>
                <td class="text-right font-weight-medium">
                  <span v-if="r.total_charged != null">{{ money(r.total_charged) }}</span>
                  <span v-else-if="r.estimated_charge != null" class="text-medium-emphasis">{{ money(r.estimated_charge) }}<v-icon size="11" class="ml-1">mdi-tilde</v-icon></span>
                  <span v-else>—</span>
                </td>
                <td class="text-right text-medium-emphasis">{{ r.deposit ? money(r.deposit) : '—' }}</td>
                <td class="text-body-2">{{ fmtDate(r.assigned_at) }}</td>
                <td>
                  <span v-if="r.returned_at" class="text-body-2">{{ fmtDate(r.returned_at) }}</span>
                  <v-chip v-else size="x-small" variant="tonal" color="info">On hire</v-chip>
                </td>
                <td class="text-center">
                  <v-chip v-if="r.returned_at" size="x-small" variant="tonal" :color="returnColor(r.return_condition)">{{ r.return_condition || 'Returned' }}</v-chip>
                  <v-chip v-else size="x-small" variant="flat" color="info">Active</v-chip>
                </td>
                <td class="text-center">
                  <v-btn icon="mdi-eye-outline" variant="text" size="small" color="teal" @click="openRecord(r)" />
                </td>
              </tr>
            </tbody>
          </v-table>

          <div v-if="recordsLoading" class="text-center pa-4">
            <v-progress-circular indeterminate color="teal" />
          </div>

          <div v-if="recordsCount > recordsPageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="recordsPage" :length="Math.ceil(recordsCount / recordsPageSize)"
                          rounded="lg" density="compact" @update:model-value="loadRecords" />
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Hire record details dialog -->
    <v-dialog v-model="recordDialog" max-width="640" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center text-h6">
          <v-icon icon="mdi-clipboard-text-outline" color="teal" class="mr-2" />
          Hire record details
          <v-spacer />
          <v-chip v-if="recordDetail" size="small" variant="tonal"
                  :color="recordDetail.returned_at ? returnColor(recordDetail.return_condition) : 'info'">
            {{ recordDetail.returned_at ? (recordDetail.return_condition || 'Returned') : 'Active' }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text v-if="recordDetail" class="pt-4">
          <div class="d-flex align-center mb-4">
            <v-avatar color="teal" variant="tonal" size="44" class="mr-3">
              <v-icon :icon="recordDetail.hire_to_type === 'facility' ? 'mdi-hospital-building' : 'mdi-account'" />
            </v-avatar>
            <div>
              <div class="text-subtitle-1 font-weight-bold">{{ recordDetail.device_name }}</div>
              <div class="text-body-2 text-medium-emphasis">
                Hired to {{ recordDetail.hire_to_name || recordDetail.patient_name || recordDetail.facility_name || '—' }}
                · {{ recordDetail.hire_to_type_label }}
              </div>
            </div>
          </div>

          <v-row dense>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Billing period</div>
              <div class="text-body-2 font-weight-medium">{{ recordDetail.hire_period_label || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Hire rate</div>
              <div class="text-body-2 font-weight-medium">
                <span v-if="recordDetail.hire_rate">{{ money(recordDetail.hire_rate) }} / {{ periodShort(recordDetail.hire_period) }}</span>
                <span v-else>—</span>
              </div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Refundable deposit</div>
              <div class="text-body-2 font-weight-medium">{{ recordDetail.deposit ? money(recordDetail.deposit) : '—' }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Total charged</div>
              <div class="text-body-2 font-weight-bold text-teal-darken-2">
                <span v-if="recordDetail.total_charged != null">{{ money(recordDetail.total_charged) }}</span>
                <span v-else>—</span>
              </div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Estimated charge</div>
              <div class="text-body-2 font-weight-medium">
                <span v-if="recordDetail.estimated_charge != null">{{ money(recordDetail.estimated_charge) }}</span>
                <span v-else>—</span>
              </div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Assigned by</div>
              <div class="text-body-2 font-weight-medium">{{ recordDetail.assigned_by_name || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Started</div>
              <div class="text-body-2 font-weight-medium">{{ fmtDateTime(recordDetail.assigned_at) }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Expected return</div>
              <div class="text-body-2 font-weight-medium">{{ fmtDateTime(recordDetail.expected_return_at) }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Returned</div>
              <div class="text-body-2 font-weight-medium">{{ fmtDateTime(recordDetail.returned_at) }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Return condition</div>
              <div class="text-body-2 font-weight-medium">{{ recordDetail.return_condition || '—' }}</div>
            </v-col>
          </v-row>

          <div v-if="recordDetail.notes" class="mt-4">
            <div class="text-caption text-medium-emphasis mb-1">Notes</div>
            <v-sheet rounded="lg" color="grey-lighten-4" class="pa-3 text-body-2">
              {{ recordDetail.notes }}
            </v-sheet>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="recordDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()

const d = ref({})
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

const range = ref('30d')
const customFrom = ref('')
const customTo = ref('')

const search = ref('')
const abcFilter = ref(null)
const abcPage = ref(1)
const pageSize = 15

// Hire records / history
const records = ref([])
const recordsCount = ref(0)
const recordsPage = ref(1)
const recordsPageSize = 15
const recordsLoading = ref(false)
const recordsSearch = ref('')
const recordsStatus = ref(null)
let recordsTimer = null
const statusFilterOptions = [
  { label: 'Active', value: 'active' },
  { label: 'Returned', value: 'returned' },
]

const barColors = ['#0d9488', '#0ea5e9', '#7c3aed', '#f59e0b', '#ec4899', '#14b8a6', '#6366f1', '#10b981']

const rangeLabel = computed(() => {
  if (range.value === 'custom' && customFrom.value && customTo.value) return `${customFrom.value} – ${customTo.value}`
  const map = { today: 'Today', yesterday: 'Yesterday', '7d': 'Last 7 days', '30d': 'Last 30 days', '90d': 'Last 90 days', '1y': 'Last year', all: 'All time' }
  return map[range.value] || 'Last 30 days'
})

function money(v) {
  if (v === null || v === undefined || v === '') return 'KSh 0'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function gradeColor(g) { return { A: 'success', B: 'warning', C: 'error' }[g] || 'grey' }
function gradeHex(g) { return { A: '#0d9488', B: '#f59e0b', C: '#94a3b8' }[g] || '#0d9488' }
function moneyFmt(v) {
  const prefix = 'KSh '
  if (v >= 1_000_000) return prefix + (v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1) + 'M'
  if (v >= 1_000) return prefix + (v / 1_000).toFixed(v >= 10_000 ? 0 : 1) + 'k'
  return prefix + Math.round(v)
}
function gradeLabel(g) { return { A: 'Vital few', B: 'Useful many', C: 'Trivial many' }[g] || '' }
function gradeDesc(g) {
  return {
    A: 'Top 80% of hire revenue',
    B: 'Next 15% of hire revenue',
    C: 'Bottom 5% of hire revenue',
  }[g] || ''
}

const typeColorMap = {
  oximeter: '#ef4444', bp_monitor: '#0ea5e9', glucometer: '#f59e0b', thermometer: '#f97316',
  oxygen: '#06b6d4', nebulizer: '#14b8a6', bed: '#8b5cf6', wheelchair: '#6366f1',
  walker: '#0d9488', suction: '#64748b', ventilator: '#dc2626', infusion_pump: '#3b82f6',
  ecg: '#e11d48', other: '#7c3aed',
}
function typeColor(t) { return typeColorMap[t] || '#7c3aed' }

function typeShare(t) {
  const total = (d.value.by_type || []).reduce((s, r) => s + (Number(r.revenue) || 0), 0) || 1
  return (Number(t.revenue) || 0) / total * 100
}

const typeSegments = computed(() => {
  const rows = d.value.by_type || []
  const total = rows.reduce((s, r) => s + r.revenue, 0) || 1
  return rows
    .filter(r => r.revenue > 0)
    .map(r => ({ label: r.label, value: r.revenue, color: typeColor(r.type) }))
    .sort((a, b) => b.value - a.value)
    .slice(0, 8)
})

const topChart = computed(() => {
  const top = [...(d.value.top_equipment || [])].sort((a, b) => b.revenue - a.revenue).slice(0, 7)
  return {
    values: top.map(p => p.revenue),
    labels: top.map(p => p.name.length > 18 ? p.name.slice(0, 18) + '…' : p.name),
    colors: top.map((p) => gradeHex(p.grade)),
  }
})

const abcFiltered = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = d.value.top_equipment || []
  if (abcFilter.value) arr = arr.filter(p => p.grade === abcFilter.value)
  if (q) arr = arr.filter(p => p.name.toLowerCase().includes(q) || (p.device_type_label || '').toLowerCase().includes(q))
  return arr
})

const abcPaged = computed(() => {
  const start = (abcPage.value - 1) * pageSize
  return abcFiltered.value.slice(start, start + pageSize)
})

watch([search, range], () => { abcPage.value = 1 })

function periodShort(p) { return { hourly: 'hr', daily: 'day', weekly: 'wk', monthly: 'mo' }[p] || p || 'day' }
function fmtDate(v) {
  if (!v) return '—'
  try { return new Date(v).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) } catch { return v }
}
function fmtDateTime(v) {
  if (!v) return '—'
  try { return new Date(v).toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) } catch { return v }
}
function returnColor(c) {
  if (!c) return 'grey'
  const s = c.toLowerCase()
  if (s.includes('good')) return 'success'
  if (s.includes('fair')) return 'info'
  if (s.includes('damage') || s.includes('repair') || s.includes('lost')) return 'error'
  return 'grey'
}

const recordDialog = ref(false)
const recordDetail = ref(null)
function openRecord(r) { recordDetail.value = r; recordDialog.value = true }

async function loadRecords() {
  recordsLoading.value = true
  try {
    const params = {
      page: recordsPage.value,
      page_size: recordsPageSize,
      ordering: '-assigned_at',
      range: range.value,
    }
    if (range.value === 'custom') { params.from = customFrom.value; params.to = customTo.value }
    if (recordsSearch.value) params.search = recordsSearch.value
    if (recordsStatus.value) params.status = recordsStatus.value
    const { data } = await $api.get('/homecare/device-assignments/', { params })
    records.value = data?.results || []
    recordsCount.value = data?.count || 0
  } catch {
    records.value = []
    recordsCount.value = 0
  } finally { recordsLoading.value = false }
}

function debouncedLoadRecords() {
  if (recordsTimer) clearTimeout(recordsTimer)
  recordsTimer = setTimeout(() => { recordsPage.value = 1; loadRecords() }, 350)
}

function onRangeChange({ range: r, from, to }) {
  range.value = r
  customFrom.value = from || ''
  customTo.value = to || ''
  load()
  recordsPage.value = 1
  loadRecords()
}

async function load() {
  loading.value = true
  try {
    const params = { range: range.value }
    if (range.value === 'custom') { params.from = customFrom.value; params.to = customTo.value }
    const { data } = await $api.get('/homecare/analytics/equipment-hire/', { params })
    d.value = data || {}
  } catch {
    snack.text = 'Failed to load equipment hire analytics'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(() => { load(); loadRecords() })
</script>

<style scoped>
.an-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.05) 0%, rgba(99,102,241,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.cursor-pointer { cursor: pointer; }
</style>
