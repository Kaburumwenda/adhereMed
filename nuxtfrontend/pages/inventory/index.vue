<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="primary" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-package-variant</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ $t('inventory.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Stock items, categories, units &amp; adjustments</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="currentResource.loading.value" @click="reload">{{ $t('common.refresh') }}</v-btn>
        <v-btn v-if="tab === 'stocks'" variant="tonal" color="warning" prepend-icon="mdi-table-edit" rounded="lg" class="text-none" to="/inventory/bulk?mode=edit">Edit mode</v-btn>
        <v-btn v-if="tab === 'stocks'" variant="tonal" color="error" prepend-icon="mdi-trash-can" rounded="lg" class="text-none" to="/inventory/bulk?mode=delete">Delete mode</v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" :to="createPaths[tab]">{{ createLabels[tab] }}</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-blue">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cube-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">SKUs</div>
              <div class="text-h6 font-weight-bold">{{ kpis.skus.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-amber">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40"><v-icon>mdi-alert-circle-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Low / out of stock</div>
              <div class="text-h6 font-weight-bold">{{ kpis.low.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-red">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="40"><v-icon>mdi-clock-alert-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Expiring ≤90d</div>
              <div class="text-h6 font-weight-bold">{{ kpis.expiring.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-green">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cash-multiple</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Retail value</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(kpis.retail) }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-card rounded="lg" elevation="0" class="mb-3 pa-1" style="border:1px solid rgba(0,0,0,0.06)">
      <v-tabs v-model="tab" color="primary" density="compact" align-tabs="start" hide-slider>
        <v-tab v-for="t in tabs" :key="t.value" :value="t.value" class="text-none rounded-lg mx-1">
          <v-icon start size="18">{{ t.icon }}</v-icon>
          {{ t.label }}
          <v-chip v-if="t.count != null" size="x-small" class="ml-2" variant="tonal">{{ t.count }}</v-chip>
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Toolbar -->
    <v-card rounded="lg" elevation="0" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          :placeholder="$t('common.searchEllipsis')"
          prepend-inner-icon="mdi-magnify"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="min-width: 240px; max-width: 360px; flex:1"
        />
        <v-select
          v-if="tab === 'stocks'"
          v-model="categoryFilter"
          :items="categoryOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-shape" style="min-width: 180px"
        />
        <v-select
          v-if="tab === 'stocks'"
          v-model="statusFilter"
          :items="statusOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-filter-variant" style="min-width: 180px"
        />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ filteredItems.length }} of {{ currentItems.length }}</span>
      </div>
    </v-card>

    <!-- Table -->
    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="currentResource.loading.value" color="primary" indeterminate />

      <div v-if="!currentResource.loading.value && !filteredItems.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-inbox-outline</v-icon>
        <div class="text-h6 mt-3">No records found</div>
        <div class="text-body-2 mb-4">{{ search ? 'Try a different search.' : 'Get started by adding your first item.' }}</div>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" :to="createPaths[tab]">{{ createLabels[tab] }}</v-btn>
      </div>

      <div v-else class="table-wrap">
        <!-- STOCKS -->
        <table v-if="tab === 'stocks'" class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Item</th>
              <th>Category</th>
              <th class="text-right">On hand</th>
              <th class="text-right">Reorder</th>
              <th class="text-right">Cost</th>
              <th class="text-right">Price</th>
              <th class="text-right">Retail value</th>
              <th>{{ $t('common.status') }}</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="primary" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">mdi-pill</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.medication_name || row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">
                      <span v-if="row.barcode">{{ row.barcode }}</span>
                      <span v-else-if="row.location_in_store">{{ row.location_in_store }}</span>
                      <span v-else>SKU #{{ row.id }}</span>
                    </div>
                  </div>
                </div>
              </td>
              <td>{{ row.category_name || '—' }}</td>
              <td class="text-right font-weight-medium">{{ Number(row.total_quantity ?? 0).toLocaleString() }} <span class="text-caption text-medium-emphasis">{{ row.unit_abbreviation || '' }}</span></td>
              <td class="text-right">{{ Number(row.reorder_level ?? 0).toLocaleString() }}</td>
              <td class="text-right">{{ formatMoney(row.cost_price) }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(row.selling_price) }}</td>
              <td class="text-right">{{ formatMoney(Number(row.total_quantity || 0) * Number(row.selling_price || 0)) }}</td>
              <td>
                <span class="status-pill" :class="`status-${stockStatus(row).key}`">
                  <v-icon size="14">{{ stockStatus(row).icon }}</v-icon>
                  {{ stockStatus(row).label }}
                </span>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/inventory/stocks/${row.id}/edit`" />
              </td>
            </tr>
          </tbody>
        </table>

        <!-- CATEGORIES -->
        <table v-else-if="tab === 'categories'" class="inv-table">
          <thead><tr><th class="row-num">#</th><th>Category</th><th>Description</th><th class="text-right">SKUs</th><th class="text-right">Units on hand</th><th class="text-right">Retail value</th><th>Share</th><th class="text-right">{{ $t('common.actions') }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar :color="categoryColor(row.id)" variant="tonal" rounded="lg" size="34"><v-icon size="18">mdi-shape</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ row.id }}</div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis" style="max-width:280px">
                <div class="text-truncate">{{ row.description || '—' }}</div>
              </td>
              <td class="text-right font-weight-medium">{{ countByCategory(row.id).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByCategory(row.id).toLocaleString() }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(retailByCategory(row.id)) }}</td>
              <td style="min-width:140px">
                <v-progress-linear
                  :model-value="sharePctByCategory(row.id)"
                  :color="categoryColor(row.id)"
                  height="6" rounded
                />
                <div class="text-caption text-medium-emphasis mt-1">{{ sharePctByCategory(row.id) }}%</div>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/inventory/categories/${row.id}/edit`" />
              </td>
            </tr>
          </tbody>
        </table>

        <!-- UNITS -->
        <table v-else-if="tab === 'units'" class="inv-table">
          <thead><tr><th class="row-num">#</th><th>Unit</th><th>Abbreviation</th><th class="text-right">SKUs</th><th class="text-right">Total on hand</th><th class="text-right">{{ $t('common.actions') }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="success" variant="tonal" rounded="lg" size="34"><v-icon size="16">mdi-ruler</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ row.id }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="small" variant="tonal" color="success">{{ row.abbreviation || row.symbol || '—' }}</v-chip>
              </td>
              <td class="text-right font-weight-medium">{{ countByUnit(row.id).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByUnit(row.id).toLocaleString() }} <span class="text-caption text-medium-emphasis">{{ row.abbreviation || '' }}</span></td>
              <td class="text-right">
                <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/inventory/units/${row.id}/edit`" />
              </td>
            </tr>
          </tbody>
        </table>

        <!-- ADJUSTMENTS -->
        <table v-else class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Item</th>
              <th>Reason</th>
              <th class="text-right">Change</th>
              <th>{{ $t('common.notes') }}</th>
              <th>Adjusted by</th>
              <th>When</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar :color="(row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'success' : 'error'" variant="tonal" rounded="lg" size="32">
                    <v-icon size="16">{{ (row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'mdi-arrow-up-bold' : 'mdi-arrow-down-bold' }}</v-icon>
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
                <span class="qty-delta" :class="(row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'qty-pos' : 'qty-neg'">
                  {{ (row.quantity_change ?? row.quantity ?? 0) > 0 ? '+' : '' }}{{ Number(row.quantity_change ?? row.quantity ?? 0).toLocaleString() }}
                </span>
              </td>
              <td class="text-medium-emphasis" style="max-width:240px">
                <div class="text-truncate">{{ row.notes || row.reason_text || '—' }}</div>
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

      <!-- Pagination -->
      <div v-if="filteredItems.length" class="d-flex flex-wrap align-center pa-3 pagination-bar" style="gap:12px">
        <span class="text-caption text-medium-emphasis">
          Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filteredItems.length }}</strong>
        </span>
        <v-spacer />
        <div class="d-flex align-center" style="gap:6px">
          <span class="text-caption text-medium-emphasis">Rows per page</span>
          <v-select
            v-model="pageSize"
            :items="pageSizeOptions"
            density="compact" variant="outlined" rounded="lg" hide-details
            style="width: 92px"
          />
        </div>
        <v-pagination
          v-if="totalPages > 1"
          v-model="page"
          :length="totalPages"
          :total-visible="5"
          density="comfortable"
          rounded="lg"
          color="primary"
        />
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, watch, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatMoney, formatDateTime } from '~/utils/format'

const tab = ref('stocks')
const search = ref('')
const categoryFilter = ref('all')
const statusFilter = ref('all')
const page = ref(1)
const pageSize = ref(20)
const pageSizeOptions = [10, 20, 50, 100]

const stocks = useResource('/inventory/stocks/')
const categoriesRes = useResource('/inventory/categories/')
const units = useResource('/inventory/units/')
const adjustments = useResource('/inventory/adjustments/')

const resourceMap = { stocks, categories: categoriesRes, units, adjustments }
const currentResource = computed(() => resourceMap[tab.value])
const currentItems = computed(() => currentResource.value.items.value || [])

const createPaths = {
  stocks: '/inventory/stocks/new',
  categories: '/inventory/categories/new',
  units: '/inventory/units/new',
  adjustments: '/inventory/adjustments/new'
}
const createLabels = {
  stocks: 'Add Stock',
  categories: 'Add Category',
  units: 'Add Unit',
  adjustments: 'New Adjustment'
}

const tabs = computed(() => [
  { value: 'stocks', label: 'Stocks', icon: 'mdi-pill', count: stocks.items.value?.length },
  { value: 'categories', label: 'Categories', icon: 'mdi-shape', count: categoriesRes.items.value?.length },
  { value: 'units', label: 'Units', icon: 'mdi-ruler', count: units.items.value?.length },
  { value: 'adjustments', label: 'Adjustments', icon: 'mdi-tune-vertical', count: adjustments.items.value?.length }
])

// --- KPIs (always reflect stocks) ---
function stockStatus(s) {
  const qty = Number(s.total_quantity ?? s.quantity ?? 0)
  const reorder = Number(s.reorder_level ?? 0)
  if (qty <= 0) return { key: 'out', label: 'Out of stock', icon: 'mdi-alert-octagon' }
  if (qty <= reorder) return { key: 'low', label: 'Low', icon: 'mdi-alert' }
  return { key: 'ok', label: 'In stock', icon: 'mdi-check-circle' }
}

const kpis = computed(() => {
  const all = stocks.items.value || []
  const skus = all.length
  const low = all.filter(s => stockStatus(s).key !== 'ok').length
  const horizon = Date.now() + 90 * 86400000
  const expiring = all.reduce((acc, s) => {
    const batches = s.batches || []
    if (batches.some(b => b.expiry_date && new Date(b.expiry_date).getTime() <= horizon)) return acc + 1
    if (s.expiry_date && new Date(s.expiry_date).getTime() <= horizon) return acc + 1
    return acc
  }, 0)
  const retail = all.reduce((acc, s) => acc + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
  return { skus, low, expiring, retail }
})

// --- Filters ---
const categoryOptions = computed(() => {
  const opts = [{ label: 'All categories', value: 'all' }]
  for (const c of categoriesRes.items.value || []) opts.push({ label: c.name, value: c.id })
  return opts
})
const statusOptions = [
  { label: 'All status', value: 'all' },
  { label: 'In stock', value: 'ok' },
  { label: 'Low stock', value: 'low' },
  { label: 'Out of stock', value: 'out' }
]

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = currentItems.value.slice()
  if (tab.value === 'stocks') {
    if (categoryFilter.value !== 'all') arr = arr.filter(s => s.category === categoryFilter.value)
    if (statusFilter.value !== 'all') arr = arr.filter(s => stockStatus(s).key === statusFilter.value)
  }
  if (!q) return arr
  return arr.filter(row => Object.values(row).some(v => {
    if (v == null) return false
    if (typeof v === 'object') return false
    return String(v).toLowerCase().includes(q)
  }))
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredItems.value.length / pageSize.value)))
const pagedItems = computed(() => {
  const s = (page.value - 1) * pageSize.value
  return filteredItems.value.slice(s, s + pageSize.value)
})
const rangeStart = computed(() => filteredItems.value.length === 0 ? 0 : (page.value - 1) * pageSize.value + 1)
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, filteredItems.value.length))
function rowNumber(i) { return (page.value - 1) * pageSize.value + i + 1 }

watch([tab, search, categoryFilter, statusFilter, pageSize], () => { page.value = 1 })

function countByCategory(id) {
  return (stocks.items.value || []).filter(s => s.category === id).length
}
function unitsByCategory(id) {
  return (stocks.items.value || [])
    .filter(s => s.category === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
}
function retailByCategory(id) {
  return (stocks.items.value || [])
    .filter(s => s.category === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
}
const totalRetailAll = computed(() =>
  (stocks.items.value || []).reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
)
function sharePctByCategory(id) {
  const total = totalRetailAll.value
  if (!total) return 0
  return Math.round((retailByCategory(id) / total) * 100)
}
const _catColors = ['#3b82f6', '#22c55e', '#f59e0b', '#a855f7', '#ef4444', '#06b6d4', '#84cc16', '#ec4899', '#14b8a6', '#eab308']
function categoryColor(id) {
  return _catColors[(Number(id) || 0) % _catColors.length]
}

function countByUnit(id) {
  return (stocks.items.value || []).filter(s => s.unit === id).length
}
function unitsByUnit(id) {
  return (stocks.items.value || [])
    .filter(s => s.unit === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
}

const _reasonMeta = {
  damage:             { label: 'Damage',             color: 'error',   icon: 'mdi-alert-octagon' },
  theft:              { label: 'Theft',              color: 'error',   icon: 'mdi-shield-alert' },
  expiry:             { label: 'Expiry',             color: 'warning', icon: 'mdi-clock-alert' },
  count_correction:   { label: 'Count correction',   color: 'info',    icon: 'mdi-counter' },
  return_to_supplier: { label: 'Return to supplier', color: 'purple',  icon: 'mdi-truck-fast' },
  other:              { label: 'Other',              color: 'default', icon: 'mdi-dots-horizontal' },
}
function reasonLabel(r) { return _reasonMeta[r]?.label || (r ? r.replace(/_/g, ' ') : '\u2014') }
function reasonColor(r) { return _reasonMeta[r]?.color || 'default' }
function reasonIcon(r)  { return _reasonMeta[r]?.icon  || 'mdi-tag' }

function reload() { currentResource.value.list({ page_size: 2000 }) }

watch(tab, (t) => { resourceMap[t].list({ page_size: 2000 }) }, { immediate: true })
onMounted(() => {
  // Always load stocks + categories so KPIs and category filter populate even on other tabs
  if (!stocks.items.value?.length) stocks.list({ page_size: 2000 })
  if (!categoriesRes.items.value?.length) categoriesRes.list({ page_size: 2000 })
})
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(0,0,0,0.06); }
.kpi-blue { background: linear-gradient(135deg, rgba(59,130,246,0.06), rgba(59,130,246,0.01)); }
.kpi-amber { background: linear-gradient(135deg, rgba(245,158,11,0.07), rgba(245,158,11,0.01)); }
.kpi-red { background: linear-gradient(135deg, rgba(239,68,68,0.07), rgba(239,68,68,0.01)); }
.kpi-green { background: linear-gradient(135deg, rgba(34,197,94,0.07), rgba(34,197,94,0.01)); }

.table-wrap { overflow-x: auto; }
.inv-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.inv-table thead th {
  text-align: left;
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgb(var(--v-theme-on-surface));
  background: rgba(var(--v-theme-primary), 0.08);
  border-bottom: 2px solid rgba(var(--v-theme-primary), 0.25);
  padding: 10px 14px;
  white-space: nowrap;
}
.inv-table thead th.text-right { text-align: right; }
.inv-table tbody td { padding: 10px 14px; border-bottom: 1px solid rgba(0,0,0,0.05); vertical-align: middle; }
.inv-table tbody td.text-right { text-align: right; }
.inv-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.04); }

.status-pill {
  display: inline-flex; align-items: center;
  padding: 6px 12px; border-radius: 999px;
  font-size: 12px; font-weight: 700;
  letter-spacing: 0.04em; text-transform: uppercase;
  border: 1px solid transparent;
  box-shadow: 0 1px 2px rgba(0,0,0,0.06);
  white-space: nowrap;
}
.status-pill .v-icon { margin-right: 4px; font-size: 14px !important; }

.status-ok {
  background: rgb(220, 252, 231);
  color: rgb(22, 101, 52);
  border-color: rgb(134, 239, 172);
}
.status-low {
  background: rgb(254, 243, 199);
  color: rgb(120, 53, 15);
  border-color: rgb(252, 211, 77);
}
.status-out {
  background: rgb(254, 226, 226);
  color: rgb(153, 27, 27);
  border-color: rgb(252, 165, 165);
  animation: pulse-out 2s ease-in-out infinite;
}
@keyframes pulse-out {
  0%, 100% { box-shadow: 0 1px 2px rgba(239,68,68,0.2); }
  50% { box-shadow: 0 0 0 4px rgba(239,68,68,0.15); }
}

.row-num { width: 56px; text-align: center; font-variant-numeric: tabular-nums; }
.inv-table thead th.row-num { text-align: center; }
.pagination-bar { border-top: 1px solid rgba(0,0,0,0.06); background: rgba(0,0,0,0.015); }

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
