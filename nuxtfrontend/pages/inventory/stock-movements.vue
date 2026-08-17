<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="cyan-lighten-5" size="48" class="mr-3">
          <v-icon color="cyan-darken-2" size="28">mdi-swap-vertical-bold</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Stock Movements</h1>
          <div class="text-body-2 text-medium-emphasis">Track every stock inflow, outflow, and transfer with full audit trail</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
               prepend-icon="mdi-download" @click="exportCsv">Export</v-btn>
      </div>
    </div>

    <!-- Date range chips -->
    <v-card flat rounded="xl" class="mb-4 pa-3" border>
      <div class="d-flex align-center flex-wrap ga-2">
        <v-icon size="20" color="primary" class="mr-1">mdi-calendar-filter</v-icon>
        <v-chip-group v-model="rangeKey" selected-class="text-primary" mandatory>
          <v-chip v-for="c in rangeChips" :key="c.key" :value="c.key" variant="text" size="small">
            <v-icon start size="16">mdi-circle-medium</v-icon>{{ c.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <v-icon size="18" color="primary">mdi-calendar-range</v-icon>
        <span class="text-caption text-medium-emphasis">{{ rangeLabel }}</span>
      </div>
    </v-card>

    <!-- KPI tiles -->
    <v-row dense class="mb-3">
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Total Inflow</div>
              <div class="text-h5 font-weight-bold mt-1 text-success">{{ smKpis.total_in ?? 0 }} units</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ formatMoney(smKpis.value_in ?? 0) }} value</div>
            </div>
            <v-avatar size="40" color="success" variant="tonal">
              <v-icon>mdi-trending-up</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Total Outflow</div>
              <div class="text-h5 font-weight-bold mt-1 text-error">{{ smKpis.total_out ?? 0 }} units</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ formatMoney(smKpis.value_out ?? 0) }} value</div>
            </div>
            <v-avatar size="40" color="error" variant="tonal">
              <v-icon>mdi-trending-down</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Net Change</div>
              <div class="text-h5 font-weight-bold mt-1"
                   :class="(smKpis.net_change ?? 0) >= 0 ? 'text-success' : 'text-error'">
                {{ smKpis.net_change ?? 0 }} units
              </div>
              <div class="text-caption text-medium-emphasis mt-1">{{ formatMoney(smKpis.net_value ?? 0) }} value</div>
            </div>
            <v-avatar size="40" :color="(smKpis.net_change ?? 0) >= 0 ? 'success' : 'error'" variant="tonal">
              <v-icon>{{ (smKpis.net_change ?? 0) >= 0 ? 'mdi-plus' : 'mdi-minus' }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Transfers</div>
              <div class="text-h5 font-weight-bold mt-1 text-info">{{ smKpis.total_transfer ?? 0 }} units</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ smKpis.count ?? 0 }} total movements</div>
            </div>
            <v-avatar size="40" color="info" variant="tonal">
              <v-icon>mdi-truck-fast</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Trend chart + Reason donut -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="8">
        <v-card flat rounded="xl" border class="pa-3 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="text-subtitle-2 font-weight-bold">
              <v-icon size="18" class="mr-1" color="primary">mdi-chart-line-variant</v-icon>
              Daily movement trend
            </div>
          </div>
          <div class="trend-chart">
            <SparkArea :values="smTrendNet" :labels="smTrendLabels" :height="240" color="#0ea5e9" />
          </div>
          <div class="text-caption text-medium-emphasis pa-2">Net units moved per day (inflow minus outflow). Positive bars indicate stock gains.</div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card flat rounded="xl" border class="pa-3 h-100">
          <div class="text-subtitle-2 font-weight-bold mb-2">
            <v-icon size="18" class="mr-1" color="primary">mdi-chart-donut</v-icon>
            Movement reasons
          </div>
          <div class="d-flex align-center justify-center my-2">
            <DonutRing :segments="reasonSegments" :size="200">
              <div class="text-caption text-medium-emphasis text-uppercase">Total</div>
              <div class="text-h6 font-weight-bold">{{ reasonTotal }}</div>
            </DonutRing>
          </div>
          <div v-for="s in reasonSegments" :key="s.label"
               class="d-flex align-center justify-space-between py-1">
            <div class="d-flex align-center">
              <span class="legend-dot" :style="{ background: s.color }"></span>
              <span class="text-caption font-weight-medium ml-2">{{ s.label }}</span>
            </div>
            <span class="text-caption font-weight-bold">{{ s.value }} units</span>
          </div>
          <div v-if="!reasonSegments.length" class="text-caption text-medium-emphasis pa-3 text-center">
            No movements in this range
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Inflow vs Outflow bars + Top movers -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="8">
        <v-card flat rounded="xl" border class="pa-3 h-100">
          <div class="text-subtitle-2 font-weight-bold mb-2">
            <v-icon size="18" class="mr-1" color="primary">mdi-chart-bar</v-icon>
            Inflow vs outflow by day
          </div>
          <BarChart :values="smBarsValues"
                     :labels="smBarsLabels"
                     :colors="smBarsColors"
                     :height="240"
                     :show-values="false" />
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card flat rounded="xl" border class="pa-3 h-100">
          <div class="text-subtitle-2 font-weight-bold mb-2">
            <v-icon size="18" class="mr-1" color="primary">mdi-account-star</v-icon>
            Top movers
          </div>
          <v-list density="compact" class="px-0">
            <v-list-item v-for="m in topMovers" :key="m.name" density="compact" class="px-1">
              <template #prepend>
                <v-avatar size="32" :color="avatarColor(m.name)" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ initials(m.name) }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2">{{ m.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption text-medium-emphasis">
                {{ m.count }} movements · net {{ m.net >= 0 ? '+' : '' }}{{ m.net }} units
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="m.net >= 0 ? 'success' : 'error'" variant="tonal">
                  {{ m.inflow }} in / {{ m.outflow }} out
                </v-chip>
              </template>
            </v-list-item>
            <v-list-item v-if="!topMovers.length" density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">
                No stock adjustments in this range
              </v-list-item-title>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- Movements table -->
    <v-card flat rounded="xl" border class="pa-3">
      <div class="d-flex align-center justify-space-between mb-2 flex-wrap ga-2">
        <div class="text-subtitle-2 font-weight-bold">
          <v-icon size="18" class="mr-1" color="primary">mdi-format-list-bulleted</v-icon>
          Movement ledger
        </div>
        <div class="d-flex align-center flex-wrap ga-2">
          <v-select v-model="typeFilter" :items="typeOptions" density="compact"
                    variant="outlined" hide-details single-line
                    prepend-inner-icon="mdi-swap-vertical"
                    style="max-width: 140px" />
          <v-select v-model="reasonFilter" :items="reasonOptions" density="compact"
                    variant="outlined" hide-details single-line
                    prepend-inner-icon="mdi-tag-outline"
                    style="max-width: 180px" />
          <v-text-field v-model="search" density="compact" variant="outlined"
                        placeholder="Search product or reference…" prepend-inner-icon="mdi-magnify"
                        hide-details single-line style="max-width: 280px" />
        </div>
      </div>
      <v-data-table :headers="headers" :items="filteredMovements" :items-per-page="10"
                     density="compact" class="elevation-0" :loading="loading" hover>
        <template #item.date="{ item }">
          <span class="text-caption">{{ (item.date || '').slice(5) }}</span>
        </template>
        <template #item.direction="{ item }">
          <v-chip size="x-small" :color="dirColor(item.direction)" variant="tonal">
            <v-icon size="12" start>{{ dirIcon(item.direction) }}</v-icon>
            {{ dirLabel(item.direction) }}
          </v-chip>
        </template>
        <template #item.reference="{ item }">
          <div class="text-body-2 font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.source }}</div>
        </template>
        <template #item.reason="{ item }">
          <v-chip size="x-small" :color="reasonColor(item.reason)" variant="tonal">
            {{ reasonLabel(item.reason) }}
          </v-chip>
        </template>
        <template #item.stock_name="{ item }">
          <div class="d-flex align-center">
            <v-avatar size="24" :color="dirColor(item.direction)" variant="tonal" class="mr-2">
              <v-icon size="14">{{ sourceIcon(item.source) }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.stock_name }}</div>
              <div v-if="item.batch_number" class="text-caption text-medium-emphasis">Batch {{ item.batch_number }}</div>
            </div>
          </div>
        </template>
        <template #item.quantity="{ item }">
          <span class="text-body-2 font-weight-bold"
                :class="item.quantity_change >= 0 ? 'text-success' : 'text-error'">
            {{ item.quantity_change >= 0 ? '+' : '−' }}{{ item.quantity }} units
          </span>
        </template>
        <template #item.value_change="{ item }">
          <span class="text-caption font-weight-medium">{{ formatMoney(item.value_change ?? 0) }}</span>
        </template>
        <template #item.adjusted_by="{ item }">
          <span class="text-caption">{{ item.user || '—' }}</span>
        </template>
        <template #item.notes="{ item }">
          <span class="text-caption text-medium-emphasis">{{ item.notes || '—' }}</span>
        </template>
        <template #no-data>
          <div class="text-center text-medium-emphasis pa-4">
            <v-icon size="32" color="grey-lighten-1">mdi-package-off</v-icon>
            <div class="text-caption mt-2">No stock movements in this range</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Custom date dialog -->
    <v-dialog v-model="customDialog" max-width="480">
      <v-card rounded="xl">
        <v-card-title>Custom date range</v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="customStart" type="date" label="From" density="compact" variant="outlined" /></v-col>
            <v-col cols="6"><v-text-field v-model="customEnd" type="date" label="To" density="compact" variant="outlined" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="cancelCustom">Cancel</v-btn>
          <v-btn color="primary" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useNuxtApp } from '#app'
import { formatMoney, formatDate } from '~/utils/format'
import SparkArea from '~/components/SparkArea.vue'
import BarChart from '~/components/BarChart.vue'
import DonutRing from '~/components/DonutRing.vue'

const { $api } = useNuxtApp()

const loading = ref(false)
const smData = ref(null)

// ── Date range ──────────────────────────────────────────────
const rangeKey = ref('30d')
const rangeChips = [
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'ytd', label: 'Year to date' },
  { key: 'custom', label: 'Custom' },
]
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')

function resolveRange() {
  const today = new Date()
  const iso = (d) => d.toISOString().slice(0, 10)
  const sub = (n) => { const d = new Date(today); d.setDate(d.getDate() - n); return d }
  const yearStart = new Date(today.getFullYear(), 0, 1)
  switch (rangeKey.value) {
    case '7d': return { start: iso(sub(6)), end: iso(today), label: 'Last 7 days' }
    case '90d': return { start: iso(sub(89)), end: iso(today), label: 'Last 90 days' }
    case 'ytd': return { start: iso(yearStart), end: iso(today), label: 'Year to date' }
    case 'custom':
      if (customStart.value && customEnd.value)
        return { start: customStart.value, end: customEnd.value, label: `${customStart.value} → ${customEnd.value}` }
      return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
    case '30d':
    default: return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
  }
}

const rangeLabel = computed(() => resolveRange().label)

watch(rangeKey, (v) => {
  if (v === 'custom') { customDialog.value = true; return }
  load()
})

function applyCustom() {
  if (!customStart.value || !customEnd.value) return
  customDialog.value = false
  load()
}
function cancelCustom() {
  customDialog.value = false
  if (!customStart.value || !customEnd.value) rangeKey.value = '30d'
}

// ── Filters ─────────────────────────────────────────────────
const search = ref('')
const typeFilter = ref('all')
const reasonFilter = ref('all')
const typeOptions = [
  { title: 'All types', value: 'all' },
  { title: 'Inflow', value: 'inflow' },
  { title: 'Outflow', value: 'outflow' },
  { title: 'Transfer', value: 'transfer' },
]
const reasonOptions = computed(() => {
  const set = new Set((smData.value?.movements || []).map(m => m.reason).filter(Boolean))
  return [
    { title: 'All reasons', value: 'all' },
    ...[...set].map(r => ({ title: reasonLabel(r), value: r })),
  ]
})

// ── Computeds ───────────────────────────────────────────────
const smKpis = computed(() => smData.value?.kpis || {})
const smTrend = computed(() => smData.value?.trend || [])
const smTrendNet = computed(() => smTrend.value.map(d => d.net))
const smTrendLabels = computed(() => smTrend.value.map(d => (d.date || '').slice(5)))
const reasonSegments = computed(() => smData.value?.reason_segments || [])
const reasonTotal = computed(() => reasonSegments.value.reduce((s, x) => s + x.value, 0))
const topMovers = computed(() => smData.value?.top_movers || [])

const smBars = computed(() => smData.value?.trend || [])
const smBarsValues = computed(() => [
  ...smBars.value.map(r => r.inflow),
  ...smBars.value.map(r => r.outflow),
])
const smBarsLabels = computed(() => [
  ...smBars.value.map(r => (r.date || '').slice(5)),
  ...smBars.value.map(r => (r.date || '').slice(5)),
])
const smBarsColors = computed(() => [
  ...smBars.value.map(() => '#16a34a'),
  ...smBars.value.map(() => '#dc2626'),
])

const movements = computed(() => smData.value?.movements || [])

const headers = [
  { title: 'Date', key: 'date', sortable: true, width: '90px' },
  { title: 'Type', key: 'direction', sortable: true, width: '90px' },
  { title: 'Reference', key: 'reference', sortable: true, width: '140px' },
  { title: 'Product', key: 'stock_name', sortable: true },
  { title: 'Reason', key: 'reason', sortable: true, width: '140px' },
  { title: 'Qty', key: 'quantity', sortable: true, align: 'end', width: '110px' },
  { title: 'Value', key: 'value_change', sortable: true, align: 'end', width: '120px' },
  { title: 'By', key: 'adjusted_by', sortable: true, width: '120px' },
  { title: 'Notes', key: 'notes', sortable: false, width: '160px' },
]

const filteredMovements = computed(() => {
  let items = movements.value
  if (typeFilter.value !== 'all') {
    items = items.filter(m => m.direction === typeFilter.value)
  }
  if (reasonFilter.value !== 'all') {
    items = items.filter(m => m.reason === reasonFilter.value)
  }
  const q = search.value.trim().toLowerCase()
  if (q) {
    items = items.filter(m =>
      (m.stock_name || '').toLowerCase().includes(q)
      || (m.reference || '').toLowerCase().includes(q)
      || (m.notes || '').toLowerCase().includes(q)
    )
  }
  return items
})

// ── Helpers ─────────────────────────────────────────────────
function dirColor(d) {
  return { inflow: 'success', outflow: 'error', transfer: 'info' }[d] || 'grey'
}
function dirIcon(d) {
  return { inflow: 'mdi-arrow-down', outflow: 'mdi-arrow-up', transfer: 'mdi-swap-horizontal' }[d] || 'mdi-arrow-all'
}
function dirLabel(d) {
  return { inflow: 'In', outflow: 'Out', transfer: 'Transfer' }[d] || '—'
}
const REASON_MAP = {
  damage: { label: 'Damage', color: '#ef4444', icon: 'mdi-broken-variant' },
  theft: { label: 'Theft', color: '#dc2626', icon: 'mdi-lock-open' },
  expiry: { label: 'Expiry', color: '#f59e0b', icon: 'mdi-clock-alert' },
  count_correction: { label: 'Count Correction', color: '#3b82f6', icon: 'mdi-clipboard-check' },
  return_to_supplier: { label: 'Return to Supplier', color: '#8b5cf6', icon: 'mdi-undo' },
  other: { label: 'Other', color: '#64748b', icon: 'mdi-dots-horizontal' },
  branch_transfer: { label: 'Branch Transfer', color: '#0ea5e9', icon: 'mdi-truck-fast' },
  pos_sale: { label: 'POS Sale', color: '#10b981', icon: 'mdi-cart' },
  dispensing: { label: 'Dispensing', color: '#14b8a6', icon: 'mdi-pill' },
  return: { label: 'Dispense Return', color: '#f97316', icon: 'mdi-keyboard-return' },
}
function reasonLabel(r) { return REASON_MAP[r]?.label || (r || '—').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()) }
function reasonColor(r) { return REASON_MAP[r]?.color || '#64748b' }
function sourceIcon(src) {
  const map = {
    'Stock Adjustment': 'mdi-tune',
    'Branch Transfer': 'mdi-truck-fast',
    'POS Sale': 'mdi-cart',
    'Dispensing': 'mdi-pill',
    'Dispense Return': 'mdi-keyboard-return',
  }
  return map[src] || 'mdi-package-variant'
}
function avatarColor(name) {
  const colors = ['primary', 'secondary', 'success', 'info', 'warning', 'error', 'indigo', 'teal']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function initials(name) {
  return (name || '?').split(' ').slice(0, 2).map(w => w[0]?.toUpperCase() || '').join('')
}

// ── Load ───────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { start, end } = resolveRange()
    const { data: d } = await $api.get('/inventory/stock-movements/', {
      params: { date_from: start, date_to: end },
    })
    smData.value = d
  } catch {
    smData.value = null
  } finally {
    loading.value = false
  }
}

// ── Export ──────────────────────────────────────────────────
function exportCsv() {
  const k = smKpis.value
  const rows = [
    ['Total Inflow (units)', k.total_in],
    ['Total Outflow (units)', k.total_out],
    ['Net Change (units)', k.net_change],
    ['Total Transfers (units)', k.total_transfer],
    ['Inflow Value', k.value_in],
    ['Outflow Value', k.value_out],
    ['Net Value', k.net_value],
    ['Total Movements', k.count],
    ['', ''],
    ['Reason Breakdown', ''],
    ...reasonSegments.value.map(s => [s.label, s.value]),
    ['', ''],
    ['Top Movers', 'In', 'Out', 'Net', 'Count'],
    ...topMovers.value.map(m => [m.name, m.inflow, m.outflow, m.net, m.count]),
    ['', ''],
    ['Date', 'Type', 'Reference', 'Source', 'Product', 'Reason', 'Quantity', 'Value', 'User', 'Notes'],
    ...filteredMovements.value.map(m => [m.date, m.direction, m.reference, m.source, m.stock_name, m.reason, m.quantity, m.value_change, m.user, m.notes]),
  ]
  downloadCsv('stock-movements', rows[0].map(String), rows)
}

function downloadCsv(name, headers, rows) {
  const escape = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(escape).join(','), ...rows.map(r => r.map(escape).join(','))].join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${name}-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(() => load())
</script>

<style scoped>
.kpi-card { transition: box-shadow 0.2s; }
.kpi-card:hover { box-shadow: 0 4px 12px rgb(0 0 0 / 8%); }
.legend-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; }
.trend-chart { min-height: 220px; }
</style>
