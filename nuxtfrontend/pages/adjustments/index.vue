<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="warning" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-swap-vertical-bold</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Stock Adjustments</h1>
          <div class="text-body-2 text-medium-emphasis">Track every change to your inventory · audit trail</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="reload">Refresh</v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" to="/inventory/adjustments/new">New Adjustment</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(59,130,246,0.06), rgba(59,130,246,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40"><v-icon>mdi-tune</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Total adjustments</div>
              <div class="text-h6 font-weight-bold">{{ adjustments.length.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(34,197,94,0.07), rgba(34,197,94,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-arrow-up-bold</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Stock added</div>
              <div class="text-h6 font-weight-bold text-success">+{{ totalIn.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(239,68,68,0.07), rgba(239,68,68,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="40"><v-icon>mdi-arrow-down-bold</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Stock removed</div>
              <div class="text-h6 font-weight-bold text-error">{{ totalOut.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(168,85,247,0.07), rgba(168,85,247,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="purple" variant="tonal" rounded="lg" size="40"><v-icon>mdi-scale-balance</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Net change</div>
              <div class="text-h6 font-weight-bold" :class="netChange >= 0 ? 'text-success' : 'text-error'">
                {{ netChange >= 0 ? '+' : '' }}{{ netChange.toLocaleString() }}
              </div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Reason breakdown chips -->
    <v-card rounded="lg" elevation="0" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:8px">
        <span class="text-caption text-medium-emphasis text-uppercase mr-2">By reason</span>
        <v-chip
          v-for="r in reasonBreakdown"
          :key="r.key"
          size="small"
          :color="r.color"
          :variant="reasonFilter === r.key ? 'flat' : 'tonal'"
          :prepend-icon="r.icon"
          class="cursor-pointer"
          @click="reasonFilter = (reasonFilter === r.key ? null : r.key)"
        >
          {{ r.label }} · {{ r.count }}
        </v-chip>
        <v-spacer />
        <v-btn v-if="reasonFilter" size="x-small" variant="text" class="text-none" prepend-icon="mdi-close" @click="reasonFilter = null">Clear filter</v-btn>
      </div>
    </v-card>

    <!-- Toolbar -->
    <v-card rounded="lg" elevation="0" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          placeholder="Search item, notes, user…"
          prepend-inner-icon="mdi-magnify"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="min-width: 240px; max-width: 360px; flex:1"
        />
        <v-select
          v-model="directionFilter"
          :items="directionOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-filter-variant" style="min-width: 180px"
        />
        <v-select
          v-model="periodFilter"
          :items="periodOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-calendar-range" style="min-width: 180px"
        />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ filtered.length }} of {{ adjustments.length }}</span>
      </div>
    </v-card>

    <div v-if="!loading && !filtered.length" class="pa-10 text-center text-medium-emphasis">
      <v-icon size="64" color="grey">mdi-inbox-outline</v-icon>
      <div class="text-h6 mt-3">No adjustments</div>
      <div class="text-body-2 mb-4">{{ hasFilter ? 'Try adjusting your filters.' : 'Record your first stock adjustment.' }}</div>
      <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/inventory/adjustments/new">New Adjustment</v-btn>
    </div>

    <!-- Table -->
    <v-card v-else rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />
      <div class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Item</th>
              <th>Reason</th>
              <th class="text-right">Change</th>
              <th>Notes</th>
              <th>Adjusted by</th>
              <th>When</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar :color="qty(row) >= 0 ? 'success' : 'error'" variant="tonal" rounded="lg" size="32">
                    <v-icon size="16">{{ qty(row) >= 0 ? 'mdi-arrow-up-bold' : 'mdi-arrow-down-bold' }}</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.stock_name || '—' }}</div>
                    <div v-if="row.batch" class="text-caption text-medium-emphasis">Batch #{{ row.batch }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="small" :color="reasonColor(row.reason)" variant="tonal" :prepend-icon="reasonIcon(row.reason)">{{ reasonLabel(row.reason) }}</v-chip>
              </td>
              <td class="text-right">
                <span class="qty-delta" :class="qty(row) >= 0 ? 'qty-pos' : 'qty-neg'">
                  {{ qty(row) > 0 ? '+' : '' }}{{ Number(qty(row)).toLocaleString() }}
                </span>
              </td>
              <td class="text-medium-emphasis" style="max-width:240px">
                <div class="text-truncate">{{ row.notes || '—' }}</div>
              </td>
              <td class="text-medium-emphasis">{{ row.adjusted_by_name || 'System' }}</td>
              <td class="text-medium-emphasis">{{ formatDateTime(row.created_at) }}</td>
              <td class="text-right">
                <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/inventory/adjustments/${row.id}/edit`" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>

    <div v-if="filtered.length" class="d-flex flex-wrap align-center mt-3" style="gap:12px">
      <span class="text-caption text-medium-emphasis">
        Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filtered.length }}</strong>
      </span>
      <v-spacer />
      <div class="d-flex align-center" style="gap:6px">
        <span class="text-caption text-medium-emphasis">Per page</span>
        <v-select v-model="pageSize" :items="[10, 25, 50, 100]" density="compact" variant="outlined" rounded="lg" hide-details style="width:92px" />
      </div>
      <v-pagination v-if="totalPages > 1" v-model="page" :length="totalPages" :total-visible="5" density="comfortable" rounded="lg" color="primary" />
    </div>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { formatDateTime } from '~/utils/format'
import { useResource } from '~/composables/useResource'

const adjRes = useResource('/inventory/adjustments/')
const adjustments = computed(() => adjRes.items.value || [])
const loading = computed(() => adjRes.loading.value)

const search = ref('')
const reasonFilter = ref(null)
const directionFilter = ref('all')
const periodFilter = ref('all')
const page = ref(1)
const pageSize = ref(25)

const directionOptions = [
  { value: 'all', label: 'All directions' },
  { value: 'in',  label: 'Stock added (+)' },
  { value: 'out', label: 'Stock removed (-)' },
]
const periodOptions = [
  { value: 'all',   label: 'All time' },
  { value: 'today', label: 'Today' },
  { value: '7d',    label: 'Last 7 days' },
  { value: '30d',   label: 'Last 30 days' },
  { value: '90d',   label: 'Last 90 days' },
]

function qty(row) { return Number(row.quantity_change ?? row.quantity ?? 0) }

const _reasonMeta = {
  damage:             { label: 'Damage',             color: 'error',   icon: 'mdi-alert-octagon' },
  theft:              { label: 'Theft',              color: 'error',   icon: 'mdi-shield-alert' },
  expiry:             { label: 'Expiry',             color: 'warning', icon: 'mdi-clock-alert' },
  count_correction:   { label: 'Count correction',   color: 'info',    icon: 'mdi-counter' },
  return_to_supplier: { label: 'Return to supplier', color: 'purple',  icon: 'mdi-truck-fast' },
  other:              { label: 'Other',              color: 'default', icon: 'mdi-dots-horizontal' },
}
function reasonLabel(r) { return _reasonMeta[r]?.label || (r ? r.replace(/_/g, ' ') : '—') }
function reasonColor(r) { return _reasonMeta[r]?.color || 'default' }
function reasonIcon(r)  { return _reasonMeta[r]?.icon  || 'mdi-tag' }

const reasonBreakdown = computed(() => {
  const counts = new Map()
  for (const a of adjustments.value) {
    const k = a.reason || 'other'
    counts.set(k, (counts.get(k) || 0) + 1)
  }
  return [...counts.entries()].map(([key, count]) => ({
    key, count,
    label: reasonLabel(key),
    color: reasonColor(key),
    icon:  reasonIcon(key),
  })).sort((a, b) => b.count - a.count)
})

function _periodCutoff() {
  if (periodFilter.value === 'all') return null
  const now = new Date()
  if (periodFilter.value === 'today') { now.setHours(0, 0, 0, 0); return now }
  const days = { '7d': 7, '30d': 30, '90d': 90 }[periodFilter.value] || 0
  return new Date(Date.now() - days * 86400000)
}

const filtered = computed(() => {
  const s = search.value.trim().toLowerCase()
  const cutoff = _periodCutoff()
  return adjustments.value.filter(a => {
    if (reasonFilter.value && a.reason !== reasonFilter.value) return false
    if (directionFilter.value === 'in' && qty(a) < 0) return false
    if (directionFilter.value === 'out' && qty(a) >= 0) return false
    if (cutoff && new Date(a.created_at) < cutoff) return false
    if (s) {
      const hay = [
        a.stock_name, a.notes, a.adjusted_by_name, a.reason
      ].filter(Boolean).join(' ').toLowerCase()
      if (!hay.includes(s)) return false
    }
    return true
  })
})

const hasFilter = computed(() =>
  !!search.value || !!reasonFilter.value || directionFilter.value !== 'all' || periodFilter.value !== 'all'
)

const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)))
const pagedItems = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})
const rangeStart = computed(() => filtered.value.length === 0 ? 0 : (page.value - 1) * pageSize.value + 1)
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, filtered.value.length))
function rowNumber(i) { return (page.value - 1) * pageSize.value + i + 1 }
watch([search, reasonFilter, directionFilter, periodFilter, pageSize], () => { page.value = 1 })

const totalIn = computed(() => filtered.value.filter(a => qty(a) > 0).reduce((s, a) => s + qty(a), 0))
const totalOut = computed(() => filtered.value.filter(a => qty(a) < 0).reduce((s, a) => s + qty(a), 0))
const netChange = computed(() => totalIn.value + totalOut.value)

function reload() { adjRes.list({ page_size: 5000 }) }
onMounted(reload)
</script>

<style scoped>
.cursor-pointer { cursor: pointer; }
.table-wrap { overflow-x: auto; }
.inv-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.inv-table thead th {
  text-align: left; font-size: 12px; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.06em;
  padding: 12px 14px; color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.04);
  border-bottom: 1px solid rgba(0,0,0,0.06);
}
.inv-table tbody td { padding: 12px 14px; border-bottom: 1px solid rgba(0,0,0,0.04); }
.inv-table tbody tr:hover { background: rgba(0,0,0,0.015); }
.row-num { width: 56px; text-align: center; font-variant-numeric: tabular-nums; }
.inv-table thead th.row-num { text-align: center; }

.qty-delta {
  display: inline-block;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 13px;
}
.qty-pos { background: rgb(220, 252, 231); color: rgb(22, 101, 52); }
.qty-neg { background: rgb(254, 226, 226); color: rgb(153, 27, 27); }
</style>
