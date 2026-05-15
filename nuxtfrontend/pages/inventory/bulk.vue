<template>
  <div class="bulk-page" :class="{ 'is-fullscreen': fullscreen }">
    <v-container fluid class="pa-4 pa-md-6">
      <!-- Header -->
      <div v-if="!fullscreen" class="d-flex align-center flex-wrap ga-3 mb-5">
        <v-btn icon="mdi-arrow-left" variant="text" to="/inventory" size="small" class="mr-1" />
        <v-avatar :color="mode === 'delete' ? 'red-lighten-5' : 'blue-lighten-5'" size="48">
          <v-icon :color="mode === 'delete' ? 'red-darken-2' : 'blue-darken-2'" size="28">{{ modeIcon }}</v-icon>
        </v-avatar>
        <div>
          <div class="text-h5 font-weight-bold">{{ mode === 'delete' ? 'Bulk Delete' : 'Bulk Edit' }}</div>
          <div class="text-body-2 text-medium-emphasis">
            {{ mode === 'delete'
              ? 'Select items to remove permanently from inventory'
              : 'Edit cells directly · Save all changes at once' }}
          </div>
        </div>
        <v-spacer />

        <!-- Mode switcher -->
        <v-btn-toggle v-model="mode" mandatory density="comfortable" rounded="lg" color="primary" divided>
          <v-btn value="edit" size="small" class="text-none" prepend-icon="mdi-table-edit">{{ $t('common.edit') }}</v-btn>
          <v-btn value="delete" size="small" class="text-none" prepend-icon="mdi-trash-can">{{ $t('common.delete') }}</v-btn>
        </v-btn-toggle>

        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
               :loading="loading" @click="load" class="text-none">{{ $t('common.refresh') }}</v-btn>
      </div>

      <!-- KPIs -->
      <v-row v-if="!fullscreen" dense class="mb-4">
        <v-col cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar color="blue-lighten-5" size="36" class="mr-2">
                <v-icon color="blue-darken-2" size="20">mdi-package-variant</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">Total Items</div>
                <div class="text-h6 font-weight-bold">{{ rows.length.toLocaleString() }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar color="teal-lighten-5" size="36" class="mr-2">
                <v-icon color="teal-darken-2" size="20">mdi-eye-outline</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">Visible</div>
                <div class="text-h6 font-weight-bold">{{ filteredRows.length.toLocaleString() }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3" :class="{ 'kpi-accent': selectedIds.length }">
            <div class="d-flex align-center">
              <v-avatar :color="selectedIds.length ? 'primary' : 'grey-lighten-4'" size="36" class="mr-2">
                <v-icon :color="selectedIds.length ? 'white' : 'grey-darken-1'" size="20">mdi-checkbox-marked-outline</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">Selected</div>
                <div class="text-h6 font-weight-bold">{{ selectedIds.length.toLocaleString() }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3" :class="{ 'kpi-warning': mode === 'edit' && dirtyCount }">
            <div class="d-flex align-center">
              <v-avatar :color="mode === 'edit' && dirtyCount ? 'amber-lighten-4' : 'grey-lighten-4'" size="36" class="mr-2">
                <v-icon :color="mode === 'edit' && dirtyCount ? 'amber-darken-3' : 'grey-darken-1'" size="20">
                  {{ mode === 'edit' ? 'mdi-pencil-outline' : 'mdi-trash-can-outline' }}
                </v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ mode === 'edit' ? 'Unsaved' : 'To Remove' }}</div>
                <div class="text-h6 font-weight-bold">{{ mode === 'edit' ? dirtyCount.toLocaleString() : selectedIds.length.toLocaleString() }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Table card -->
      <v-card flat rounded="lg" class="table-card">
        <!-- Filter / action bar -->
        <div class="d-flex align-center flex-wrap ga-3 pa-3">
          <v-text-field
            v-model="search"
            placeholder="Search by name, barcode, location…"
            prepend-inner-icon="mdi-magnify"
            density="compact" variant="outlined" rounded="lg" hide-details
            clearable style="max-width:320px; min-width:200px"
          />
          <v-select
            v-model="categoryFilter"
            :items="categoryOptions"
            item-title="label" item-value="value"
            density="compact" variant="outlined" rounded="lg" hide-details
            prepend-inner-icon="mdi-shape"
            style="max-width:220px; min-width:160px"
          />
          <v-spacer />

          <template v-if="mode === 'edit'">
            <v-btn variant="text" color="warning" prepend-icon="mdi-restore" rounded="lg"
                   class="text-none" :disabled="!dirtyCount" @click="discardChanges" size="small">
              Discard
            </v-btn>
            <v-btn color="primary" prepend-icon="mdi-content-save-all" rounded="lg"
                   class="text-none" :loading="saving" :disabled="!dirtyCount" @click="saveAll">
              Save {{ dirtyCount }} change{{ dirtyCount === 1 ? '' : 's' }}
            </v-btn>
          </template>
          <template v-else>
            <v-btn variant="text" prepend-icon="mdi-checkbox-multiple-blank-outline"
                   rounded="lg" class="text-none" :disabled="!selectedIds.length" @click="selectedIds = []" size="small">
              Clear
            </v-btn>
            <v-btn color="error" prepend-icon="mdi-trash-can" rounded="lg"
                   class="text-none" :disabled="!selectedIds.length" @click="confirmDelete = true">
              Delete {{ selectedIds.length }} item{{ selectedIds.length === 1 ? '' : 's' }}
            </v-btn>
          </template>

          <v-tooltip :text="fullscreen ? 'Exit fullscreen' : 'Fullscreen'" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" :icon="fullscreen ? 'mdi-fullscreen-exit' : 'mdi-fullscreen'"
                     variant="tonal" rounded="lg" size="small" @click="toggleFullscreen" />
            </template>
          </v-tooltip>
        </div>

        <!-- Helper strip -->
        <div class="helper-strip">
          <v-icon size="14" :color="mode === 'edit' ? 'primary' : 'error'" class="mr-1">
            {{ mode === 'edit' ? 'mdi-information-outline' : 'mdi-alert-circle-outline' }}
          </v-icon>
          <template v-if="mode === 'edit'">
            Click any cell to edit · <kbd>Tab</kbd> forward · <kbd>Shift+Tab</kbd> back · Changes highlighted until saved
          </template>
          <template v-else>
            Tick rows to remove · Selections persist across search/filter · Deletion is permanent
          </template>
        </div>

        <!-- Spreadsheet -->
        <v-progress-linear v-if="loading" color="primary" indeterminate height="3" />

        <div v-if="!loading && !filteredRows.length" class="empty-state">
          <v-avatar size="72" color="primary" variant="tonal" class="mb-3">
            <v-icon size="36">mdi-table-off</v-icon>
          </v-avatar>
          <div class="text-h6 mb-1">Nothing to show</div>
          <div class="text-body-2 text-medium-emphasis mb-4">
            {{ search || categoryFilter ? 'Try clearing filters.' : 'Add some stock items first.' }}
          </div>
          <v-btn v-if="search || categoryFilter" color="primary" variant="tonal" rounded="lg" class="text-none" @click="search = ''; categoryFilter = null">
            Clear filters
          </v-btn>
        </div>

        <div v-else class="sheet-wrap">
          <table class="sheet" :class="`sheet-${mode}`">
            <thead>
              <tr>
                <th class="sticky-col col-check">
                  <v-checkbox
                    :model-value="allSelected"
                    :indeterminate="someSelected"
                    density="compact" hide-details color="primary"
                    @update:model-value="toggleAll"
                  />
                </th>
                <th class="col-id">#</th>
                <th class="col-name">Medication</th>
                <th class="col-cat">Category</th>
                <th class="col-unit">Unit</th>
                <th class="text-right col-num col-price">Cost</th>
                <th class="text-right col-num col-price">Price</th>
                <th class="text-right col-num">On hand</th>
                <th class="col-act">Active</th>
                <th class="text-right col-num">Disc%</th>
                <th class="text-right col-num">Reorder Lv</th>
                <th class="text-right col-num">Reorder Qty</th>
                <th class="col-loc">Location</th>
                <th class="col-bar">Barcode</th>
                <th class="col-rx">Rx</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(row, i) in pagedRows"
                :key="row.id"
                :class="{
                  'row-dirty': mode === 'edit' && isDirty(row.id),
                  'row-selected': selectedIds.includes(row.id)
                }"
              >
                <td class="sticky-col col-check">
                  <v-checkbox
                    :model-value="selectedIds.includes(row.id)"
                    density="compact" hide-details
                    :color="mode === 'delete' ? 'error' : 'primary'"
                    @update:model-value="toggleOne(row.id, $event)"
                  />
                </td>
                <td class="row-num">{{ rangeStart + i }}</td>

                <td>
                  <div class="d-flex align-center" style="gap: 10px">
                    <v-avatar :color="rowColor(row.id)" variant="tonal" rounded="lg" size="32">
                      <v-icon size="16">mdi-pill</v-icon>
                    </v-avatar>
                    <input
                      v-if="mode === 'edit'"
                      v-model="row.medication_name"
                      class="cell-input cell-name"
                      type="text"
                      @input="markDirty(row.id, 'medication_name', row.medication_name)"
                    />
                    <div v-else>
                      <div class="font-weight-medium">{{ row.medication_name }}</div>
                      <div class="text-caption text-medium-emphasis">{{ row.medication_id }}</div>
                    </div>
                  </div>
                </td>

                <td>
                  <select
                    v-if="mode === 'edit'"
                    v-model="row.category"
                    class="cell-input"
                    @change="markDirty(row.id, 'category', row.category)"
                  >
                    <option :value="null">—</option>
                    <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
                  </select>
                  <span v-else class="text-medium-emphasis">{{ row.category_name || '—' }}</span>
                </td>

                <td>
                  <select
                    v-if="mode === 'edit'"
                    v-model="row.unit"
                    class="cell-input"
                    @change="markDirty(row.id, 'unit', row.unit)"
                  >
                    <option :value="null">—</option>
                    <option v-for="u in units" :key="u.id" :value="u.id">
                      {{ u.name }}{{ u.abbreviation ? ` (${u.abbreviation})` : '' }}
                    </option>
                  </select>
                  <v-chip v-else size="x-small" variant="tonal" color="success">
                    {{ row.unit_abbreviation || row.unit_name || '—' }}
                  </v-chip>
                </td>

                <td class="text-right">
                  <input
                    v-if="mode === 'edit'"
                    v-model.number="row.cost_price"
                    class="cell-input num"
                    type="number" step="0.01" min="0"
                    @input="markDirty(row.id, 'cost_price', row.cost_price)"
                  />
                  <span v-else>{{ formatMoney(row.cost_price) }}</span>
                </td>
                <td class="text-right">
                  <input
                    v-if="mode === 'edit'"
                    v-model.number="row.selling_price"
                    class="cell-input num cell-price"
                    type="number" step="0.01" min="0"
                    @input="markDirty(row.id, 'selling_price', row.selling_price)"
                  />
                  <span v-else class="font-weight-medium">{{ formatMoney(row.selling_price) }}</span>
                </td>

                <td class="text-right">
                  <input
                    v-if="mode === 'edit'"
                    :value="row.set_quantity ?? row.total_quantity ?? 0"
                    class="cell-input num cell-qty"
                    :class="{ 'qty-low-input': (row.set_quantity ?? row.total_quantity ?? 0) <= row.reorder_level }"
                    type="number" min="0" step="1"
                    @input="e => onQtyInput(row, e.target.value)"
                  />
                  <span v-else class="qty-pill" :class="row.total_quantity <= row.reorder_level ? 'qty-low' : ''">
                    {{ Number(row.total_quantity ?? 0).toLocaleString() }}
                  </span>
                </td>

                <td class="text-center">
                  <v-switch
                    v-if="mode === 'edit'"
                    :model-value="row.is_active"
                    color="success" density="compact" hide-details inset
                    @update:model-value="(v) => { row.is_active = v; markDirty(row.id, 'is_active', v) }"
                  />
                  <v-icon v-else :color="row.is_active ? 'success' : 'grey'" size="20">
                    {{ row.is_active ? 'mdi-check-circle' : 'mdi-close-circle' }}
                  </v-icon>
                </td>

                <td class="text-right">
                  <input
                    v-if="mode === 'edit'"
                    v-model.number="row.discount_percent"
                    class="cell-input num"
                    type="number" step="0.01" min="0" max="100"
                    @input="markDirty(row.id, 'discount_percent', row.discount_percent)"
                  />
                  <span v-else>{{ row.discount_percent }}%</span>
                </td>
                <td class="text-right">
                  <input
                    v-if="mode === 'edit'"
                    v-model.number="row.reorder_level"
                    class="cell-input num"
                    type="number" min="0"
                    @input="markDirty(row.id, 'reorder_level', row.reorder_level)"
                  />
                  <span v-else>{{ row.reorder_level }}</span>
                </td>
                <td class="text-right">
                  <input
                    v-if="mode === 'edit'"
                    v-model.number="row.reorder_quantity"
                    class="cell-input num"
                    type="number" min="0"
                    @input="markDirty(row.id, 'reorder_quantity', row.reorder_quantity)"
                  />
                  <span v-else>{{ row.reorder_quantity }}</span>
                </td>

                <td>
                  <input
                    v-if="mode === 'edit'"
                    v-model="row.location_in_store"
                    class="cell-input"
                    type="text"
                    @input="markDirty(row.id, 'location_in_store', row.location_in_store)"
                  />
                  <span v-else class="text-medium-emphasis">{{ row.location_in_store || '—' }}</span>
                </td>

                <td>
                  <input
                    v-if="mode === 'edit'"
                    v-model="row.barcode"
                    class="cell-input cell-mono"
                    type="text"
                    @input="markDirty(row.id, 'barcode', row.barcode)"
                  />
                  <span v-else class="cell-mono text-medium-emphasis">{{ row.barcode || '—' }}</span>
                </td>

                <td>
                  <select
                    v-if="mode === 'edit'"
                    v-model="row.prescription_required"
                    class="cell-input"
                    @change="markDirty(row.id, 'prescription_required', row.prescription_required)"
                  >
                    <option value="none">None</option>
                    <option value="recommended">Recommended</option>
                    <option value="required">Required</option>
                  </select>
                  <v-chip v-else size="x-small" variant="tonal" :color="rxColor(row.prescription_required)">
                    {{ row.prescription_required }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="filteredRows.length" class="pagination-bar">
          <span class="text-caption text-medium-emphasis">
            <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filteredRows.length }}</strong>
          </span>
          <v-spacer />
          <div class="d-flex align-center" style="gap: 8px">
            <span class="text-caption text-medium-emphasis">Rows</span>
            <v-select
              v-model="pageSize"
              :items="[25, 50, 100, 200]"
              density="compact" variant="outlined" rounded="lg" hide-details
              style="width: 90px"
            />
          </div>
          <v-pagination v-model="page" :length="totalPages" :total-visible="5" density="comfortable" />
        </div>
      </v-card>
    </v-container>

    <!-- Floating action (mobile) -->
    <v-btn
      v-if="mode === 'edit' && dirtyCount"
      class="floating-save d-md-none"
      color="primary" size="large" rounded="pill"
      prepend-icon="mdi-content-save-all"
      :loading="saving"
      @click="saveAll"
    >
      Save {{ dirtyCount }}
    </v-btn>
    <v-btn
      v-if="mode === 'delete' && selectedIds.length"
      class="floating-save d-md-none"
      color="error" size="large" rounded="pill"
      prepend-icon="mdi-trash-can"
      @click="confirmDelete = true"
    >
      Delete {{ selectedIds.length }}
    </v-btn>

    <!-- Confirm delete -->
    <v-dialog v-model="confirmDelete" max-width="440">
      <v-card rounded="xl">
        <div class="confirm-banner">
          <v-avatar size="64" color="error" variant="tonal">
            <v-icon size="32">mdi-trash-can</v-icon>
          </v-avatar>
        </div>
        <v-card-title class="text-center pt-2">
          Delete {{ selectedIds.length }} item{{ selectedIds.length === 1 ? '' : 's' }}?
        </v-card-title>
        <v-card-text class="text-center text-medium-emphasis">
          This permanently removes the selected stock items from your inventory.
          This action cannot be undone.
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-btn variant="text" rounded="lg" class="text-none" block @click="confirmDelete = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" block :loading="deleting" @click="doDelete">
            Yes, delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="3500" location="bottom right" rounded="pill">
      <v-icon class="mr-2">{{ snack.icon }}</v-icon>
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted, watch } from 'vue'
import { formatMoney } from '~/utils/format'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()

const mode = ref(route.query.mode === 'delete' ? 'delete' : 'edit')
const loading = ref(false)
const saving = ref(false)
const deleting = ref(false)
const fullscreen = ref(false)

function toggleFullscreen() {
  fullscreen.value = !fullscreen.value
}

function onQtyInput(row, raw) {
  const n = raw === '' || raw == null ? null : Math.max(0, Math.floor(Number(raw)))
  row.set_quantity = Number.isFinite(n) ? n : null
  markDirty(row.id, 'set_quantity', row.set_quantity)
}

const rows = ref([])
const original = ref({})
const dirty = ref({})
const selectedIds = ref([])

const categories = ref([])
const units = ref([])

const search = ref('')
const categoryFilter = ref(null)
const page = ref(1)
const pageSize = ref(50)
const confirmDelete = ref(false)

const snack = ref({ show: false, text: '', color: 'success', icon: 'mdi-check-circle' })

const modeIcon = computed(() => mode.value === 'delete' ? 'mdi-trash-can' : 'mdi-table-edit')

function setMode(m) {
  if (m === mode.value) return
  if (mode.value === 'edit' && dirtyCount.value) {
    if (!confirm('Discard unsaved changes?')) return
    discardChanges()
  }
  mode.value = m
  selectedIds.value = []
  router.replace({ query: { ...route.query, mode: m } })
}

watch(mode, (newMode, oldMode) => {
  if (newMode === oldMode) return
  if (oldMode === 'edit' && dirtyCount.value) {
    if (!confirm('Discard unsaved changes?')) { mode.value = oldMode; return }
    discardChanges()
  }
  selectedIds.value = []
  router.replace({ query: { ...route.query, mode: newMode } })
})

const categoryOptions = computed(() => [
  { label: 'All categories', value: null },
  ...categories.value.map(c => ({ label: c.name, value: c.id }))
])

const filteredRows = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  return rows.value.filter(r => {
    if (categoryFilter.value && r.category !== categoryFilter.value) return false
    if (!q) return true
    return (r.medication_name || '').toLowerCase().includes(q) ||
           (r.barcode || '').toLowerCase().includes(q) ||
           (r.location_in_store || '').toLowerCase().includes(q)
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredRows.value.length / pageSize.value)))
const rangeStart = computed(() => filteredRows.value.length ? (page.value - 1) * pageSize.value + 1 : 0)
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, filteredRows.value.length))
const pagedRows = computed(() => filteredRows.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value))

const dirtyCount = computed(() => Object.keys(dirty.value).length)
const allSelected = computed(() => filteredRows.value.length > 0 && filteredRows.value.every(r => selectedIds.value.includes(r.id)))
const someSelected = computed(() => selectedIds.value.length > 0 && !allSelected.value)

watch([search, categoryFilter], () => { page.value = 1 })

function isDirty(id) { return !!dirty.value[id] }

function markDirty(id, field, value) {
  const orig = original.value[id]
  if (!orig) return
  if (!dirty.value[id]) dirty.value[id] = {}
  const clean = value === undefined ? null : value
  if (clean === orig[field]) {
    delete dirty.value[id][field]
    if (!Object.keys(dirty.value[id]).length) delete dirty.value[id]
  } else {
    dirty.value[id][field] = clean
  }
  dirty.value = { ...dirty.value }
}

function toggleOne(id, checked) {
  if (checked) {
    if (!selectedIds.value.includes(id)) selectedIds.value.push(id)
  } else {
    selectedIds.value = selectedIds.value.filter(x => x !== id)
  }
}

function toggleAll(checked) {
  const ids = filteredRows.value.map(r => r.id)
  if (checked) {
    selectedIds.value = [...new Set([...selectedIds.value, ...ids])]
  } else {
    selectedIds.value = selectedIds.value.filter(id => !ids.includes(id))
  }
}

const palette = ['primary', 'success', 'warning', 'info', 'purple', 'teal', 'pink', 'indigo']
function rowColor(id) { return palette[id % palette.length] }
function rxColor(rx) {
  if (rx === 'required') return 'error'
  if (rx === 'recommended') return 'warning'
  return 'grey'
}

async function load() {
  loading.value = true
  try {
    const [stocksRes, catsRes, unitsRes] = await Promise.all([
      $api.get('/inventory/stocks/', { params: { page_size: 1000 } }),
      $api.get('/inventory/categories/', { params: { page_size: 1000 } }),
      $api.get('/inventory/units/', { params: { page_size: 1000 } })
    ])
    const stockList = stocksRes.data?.results ?? stocksRes.data
    rows.value = stockList.map(s => ({ ...s }))
    original.value = Object.fromEntries(stockList.map(s => [s.id, { ...s }]))
    dirty.value = {}
    selectedIds.value = []
    categories.value = catsRes.data?.results ?? catsRes.data
    units.value = unitsRes.data?.results ?? unitsRes.data
  } catch (e) {
    snack.value = { show: true, text: e?.response?.data?.detail || 'Failed to load inventory', color: 'error', icon: 'mdi-alert' }
  } finally {
    loading.value = false
  }
}

function discardChanges() {
  rows.value = rows.value.map(r => {
    const orig = original.value[r.id]
    return orig ? { ...orig } : r
  })
  dirty.value = {}
  snack.value = { show: true, text: 'Changes discarded.', color: 'info', icon: 'mdi-restore' }
}

async function saveAll() {
  if (!dirtyCount.value) return
  saving.value = true
  try {
    const payload = Object.entries(dirty.value).map(([id, fields]) => {
      const out = { id: Number(id), ...fields }
      if ('set_quantity' in out && out.set_quantity == null) delete out.set_quantity
      return out
    })
    const { data: res } = await $api.post('/inventory/stocks/bulk-update/', { items: payload })
    snack.value = {
      show: true,
      color: res.errors?.length ? 'warning' : 'success',
      icon: res.errors?.length ? 'mdi-alert' : 'mdi-check-circle',
      text: `Updated ${res.updated} item(s)${res.errors?.length ? ` · ${res.errors.length} error(s)` : ''}.`
    }
    await load()
  } catch (e) {
    snack.value = { show: true, text: e?.response?.data?.detail || 'Bulk update failed', color: 'error', icon: 'mdi-alert' }
  } finally {
    saving.value = false
  }
}

async function doDelete() {
  if (!selectedIds.value.length) return
  deleting.value = true
  try {
    const { data: res } = await $api.post('/inventory/stocks/bulk-delete/', { ids: selectedIds.value })
    snack.value = { show: true, text: `Deleted ${res.deleted} item(s).`, color: 'success', icon: 'mdi-check-circle' }
    confirmDelete.value = false
    await load()
  } catch (e) {
    snack.value = { show: true, text: e?.response?.data?.detail || 'Bulk delete failed', color: 'error', icon: 'mdi-alert' }
  } finally {
    deleting.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.bulk-page {
  min-height: 100vh;
  background: rgb(var(--v-theme-background));
}

/* ── KPI cards ─────────────────────────────────────────────────────── */
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.kpi-accent {
  border-color: rgba(var(--v-theme-primary), 0.25);
  background: rgba(var(--v-theme-primary), 0.03);
}
.kpi-warning {
  border-color: rgba(var(--v-theme-warning), 0.3);
  background: rgba(var(--v-theme-warning), 0.04);
}

/* ── Table card ────────────────────────────────────────────────────── */
.table-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  overflow: hidden;
}

.helper-strip {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 8px 16px;
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-primary), 0.03);
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.04);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.04);
  flex-wrap: wrap;
}
.helper-strip kbd {
  background: rgba(var(--v-theme-on-surface), 0.06);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  border-radius: 4px;
  padding: 1px 5px;
  font-family: ui-monospace, monospace;
  font-size: 11px;
  margin: 0 3px;
}

/* ── Sheet ─────────────────────────────────────────────────────────── */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 56px 16px;
  text-align: center;
}
.sheet-wrap {
  overflow: auto;
  height: 70vh;
  min-height: 360px;
}
.is-fullscreen .sheet-wrap {
  height: calc(100vh - 140px);
}
.is-fullscreen .bulk-page > .v-container { padding-top: 12px !important; }

.cell-input.cell-qty {
  font-weight: 600;
  color: rgb(var(--v-theme-success));
}
.cell-input.cell-qty.qty-low-input {
  color: rgb(var(--v-theme-error));
}
.sheet {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 13px;
}
.sheet thead th {
  position: sticky;
  top: 0;
  background: rgb(var(--v-theme-surface));
  border-bottom: 2px solid rgba(var(--v-theme-on-surface), 0.08);
  padding: 10px 12px;
  font-weight: 600;
  font-size: 11.5px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  text-align: left;
  white-space: nowrap;
  z-index: 2;
}
.sheet tbody td {
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  padding: 6px 8px;
  white-space: nowrap;
  vertical-align: middle;
  background: rgb(var(--v-theme-surface));
}
.sheet tbody tr { transition: background-color 0.12s ease; }
.sheet tbody tr:hover td { background: rgba(var(--v-theme-primary), 0.035); }

.row-dirty td {
  background: rgba(var(--v-theme-warning), 0.10) !important;
}
.row-dirty td:first-child {
  box-shadow: inset 3px 0 0 0 rgb(var(--v-theme-warning));
}

.sheet-delete .row-selected td {
  background: rgba(var(--v-theme-error), 0.08) !important;
}
.sheet-edit .row-selected td {
  background: rgba(var(--v-theme-primary), 0.08) !important;
}

.sticky-col {
  position: sticky;
  left: 0;
  z-index: 1;
  box-shadow: 2px 0 4px rgba(0, 0, 0, 0.04);
}
.sheet thead .sticky-col { z-index: 3; }
.sheet tbody .sticky-col { background: inherit; }

.col-check { width: 48px; text-align: center; }
.col-id { width: 56px; color: rgba(var(--v-theme-on-surface), 0.4); }
.col-name { min-width: 260px; }
.col-cat, .col-unit { min-width: 140px; }
.col-num { width: 130px; min-width: 130px; }
.col-num.col-price { width: 150px; min-width: 150px; }
.col-loc, .col-bar { min-width: 130px; }
.col-rx { min-width: 130px; }
.col-act { width: 80px; text-align: center; }
.row-num {
  color: rgba(var(--v-theme-on-surface), 0.4);
  font-variant-numeric: tabular-nums;
}

.cell-input {
  width: 100%;
  border: 1px solid transparent;
  background: transparent;
  padding: 6px 8px;
  border-radius: 8px;
  font-size: 13px;
  color: inherit;
  outline: none;
  transition: all 0.12s ease;
}
.cell-input:hover { border-color: rgba(var(--v-theme-on-surface), 0.12); }
.cell-input:focus {
  border-color: rgb(var(--v-theme-primary));
  background: rgb(var(--v-theme-surface));
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.18);
}
select.cell-input {
  background-color: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
  color-scheme: light dark;
  appearance: auto;
}
select.cell-input option {
  background-color: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
}
.cell-input.num { text-align: right; font-variant-numeric: tabular-nums; }
.cell-input.cell-name { font-weight: 500; }
.cell-input.cell-price { font-weight: 600; }
.cell-mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 12px; }

.qty-pill {
  display: inline-block;
  padding: 3px 10px;
  border-radius: 999px;
  background: rgba(var(--v-theme-success), 0.12);
  color: rgb(var(--v-theme-success));
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  font-size: 12px;
}
.qty-low {
  background: rgba(var(--v-theme-error), 0.12);
  color: rgb(var(--v-theme-error));
}

/* ── Pagination ────────────────────────────────────────────────────── */
.pagination-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}

/* ── Confirm dialog ────────────────────────────────────────────────── */
.confirm-banner {
  display: flex;
  justify-content: center;
  padding-top: 24px;
}

/* ── Floating mobile save ──────────────────────────────────────────── */
.floating-save {
  position: fixed;
  bottom: 18px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 100;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.25);
}
</style>
