<template>
  <div class="bulk-page" :class="{ 'is-fullscreen': fullscreen }">
    <!-- Hero header -->
    <div v-if="!fullscreen" class="hero" :class="`hero-${mode}`">
      <v-container fluid class="pa-4 pa-md-6">
        <div class="d-flex align-center mb-3">
          <v-btn icon="mdi-arrow-left" variant="text" color="white" to="/inventory" class="mr-2" />
          <v-breadcrumbs density="compact" class="pa-0 text-white" :items="[
            { title: 'Inventory', to: '/inventory' },
            { title: mode === 'delete' ? 'Bulk Delete' : 'Bulk Edit' }
          ]" />
        </div>

        <div class="d-flex flex-wrap align-end justify-space-between" style="gap: 16px">
          <div class="d-flex align-center" style="gap: 18px">
            <v-avatar size="64" class="hero-icon">
              <v-icon size="36" color="white">{{ modeIcon }}</v-icon>
            </v-avatar>
            <div class="text-white">
              <div class="text-overline opacity-80">{{ mode === 'delete' ? 'Bulk Operation' : 'Spreadsheet Editor' }}</div>
              <h1 class="text-h4 text-md-h3 font-weight-bold mb-1" style="line-height: 1.1">
                {{ mode === 'delete' ? 'Bulk Delete' : 'Bulk Edit' }}
              </h1>
              <div class="text-body-2 opacity-90" style="max-width: 560px">
                {{ mode === 'delete'
                  ? 'Pick the rows you want gone and remove them in one shot. Selections persist while you filter.'
                  : 'Edit any cell directly. Changed rows are highlighted; one click saves them all.' }}
              </div>
            </div>
          </div>

          <!-- Mode switcher -->
          <div class="mode-switch">
            <button
              class="mode-pill"
              :class="{ active: mode === 'edit' }"
              @click="setMode('edit')"
            >
              <v-icon size="18">mdi-table-edit</v-icon>
              <span>Edit mode</span>
            </button>
            <button
              class="mode-pill"
              :class="{ active: mode === 'delete' }"
              @click="setMode('delete')"
            >
              <v-icon size="18">mdi-trash-can</v-icon>
              <span>Delete mode</span>
            </button>
          </div>
        </div>

        <!-- Stat strip -->
        <v-row dense class="mt-4">
          <v-col cols="6" md="3">
            <div class="stat">
              <div class="stat-label">Total items</div>
              <div class="stat-value">{{ rows.length.toLocaleString() }}</div>
            </div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="stat">
              <div class="stat-label">Visible</div>
              <div class="stat-value">{{ filteredRows.length.toLocaleString() }}</div>
            </div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="stat" :class="selectedIds.length ? 'stat-accent' : ''">
              <div class="stat-label">Selected</div>
              <div class="stat-value">{{ selectedIds.length.toLocaleString() }}</div>
            </div>
          </v-col>
          <v-col cols="6" md="3">
            <div v-if="mode === 'edit'" class="stat" :class="dirtyCount ? 'stat-warning' : ''">
              <div class="stat-label">Unsaved changes</div>
              <div class="stat-value">{{ dirtyCount.toLocaleString() }}</div>
            </div>
            <div v-else class="stat">
              <div class="stat-label">Will be removed</div>
              <div class="stat-value">{{ selectedIds.length.toLocaleString() }}</div>
            </div>
          </v-col>
        </v-row>
      </v-container>
    </div>

    <v-container fluid class="pa-4 pa-md-6 content-area">
      <!-- Sticky action / filter bar -->
      <v-card rounded="xl" elevation="0" class="action-bar mb-4">
        <div class="action-bar-inner">
          <v-text-field
            v-model="search"
            placeholder="Search by name, barcode, location…"
            prepend-inner-icon="mdi-magnify"
            density="comfortable" variant="solo-filled" rounded="lg" hide-details
            flat clearable
            class="search-field"
          />
          <v-select
            v-model="categoryFilter"
            :items="categoryOptions"
            item-title="label" item-value="value"
            density="comfortable" variant="solo-filled" rounded="lg" hide-details
            flat
            prepend-inner-icon="mdi-shape"
            class="filter-select"
          />

          <v-spacer />

          <template v-if="mode === 'edit'">
            <v-btn
              variant="text" color="warning"
              prepend-icon="mdi-restore" rounded="lg" class="text-none"
              :disabled="!dirtyCount"
              @click="discardChanges"
            >
              Discard
            </v-btn>
            <v-btn
              color="primary" size="large"
              prepend-icon="mdi-content-save-all" rounded="lg" class="text-none save-btn"
              :loading="saving"
              :disabled="!dirtyCount"
              @click="saveAll"
            >
              Save {{ dirtyCount }} change{{ dirtyCount === 1 ? '' : 's' }}
            </v-btn>
          </template>
          <template v-else>
            <v-btn
              variant="text"
              prepend-icon="mdi-checkbox-multiple-blank-outline"
              rounded="lg" class="text-none"
              :disabled="!selectedIds.length"
              @click="selectedIds = []"
            >
              Clear selection
            </v-btn>
            <v-btn
              color="error" size="large"
              prepend-icon="mdi-trash-can" rounded="lg" class="text-none save-btn"
              :disabled="!selectedIds.length"
              @click="confirmDelete = true"
            >
              Delete {{ selectedIds.length }} item{{ selectedIds.length === 1 ? '' : 's' }}
            </v-btn>
          </template>

          <v-tooltip :text="fullscreen ? 'Exit fullscreen' : 'Expand to fullscreen'" location="top">
            <template #activator="{ props }">
              <v-btn
                v-bind="props"
                :icon="fullscreen ? 'mdi-fullscreen-exit' : 'mdi-fullscreen'"
                variant="tonal" rounded="lg"
                @click="toggleFullscreen"
              />
            </template>
          </v-tooltip>
        </div>

        <div v-if="mode === 'edit'" class="helper-strip">
          <v-icon size="16" color="primary" class="mr-1">mdi-information-outline</v-icon>
          Click any cell to edit. Use <kbd>Tab</kbd> to move forward and
          <kbd>Shift</kbd>+<kbd>Tab</kbd> to move back. Changes are highlighted in
          <span class="dot dot-warning" /> amber until you save.
        </div>
        <div v-else class="helper-strip">
          <v-icon size="16" color="error" class="mr-1">mdi-alert-circle-outline</v-icon>
          Tick the rows you want to remove. Selections survive search and category filters so you can pick across the whole catalog.
        </div>
      </v-card>

      <!-- Spreadsheet -->
      <v-card rounded="xl" elevation="0" class="sheet-card">
        <v-progress-linear v-if="loading" color="primary" indeterminate height="3" />

        <div v-if="!loading && !filteredRows.length" class="empty-state">
          <v-avatar size="80" color="primary" variant="tonal" class="mb-3">
            <v-icon size="40">mdi-table-off</v-icon>
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
                <th class="text-right col-num">Disc%</th>
                <th class="text-right col-num">Reorder Lv</th>
                <th class="text-right col-num">Reorder Qty</th>
                <th class="col-loc">Location</th>
                <th class="col-bar">Barcode</th>
                <th class="col-rx">Rx</th>
                <th class="col-act">Active</th>
                <th class="text-right col-num">On hand</th>
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
          <v-btn variant="text" rounded="lg" class="text-none" block @click="confirmDelete = false">
            Cancel
          </v-btn>
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

/* ── Hero ─────────────────────────────────────────────────────────── */
.hero {
  background: linear-gradient(135deg, #1565c0 0%, #283593 100%);
  color: white;
  padding-bottom: 16px;
}
.hero-delete {
  background: linear-gradient(135deg, #c62828 0%, #6a1b9a 100%);
}
.hero-icon {
  background: rgba(255, 255, 255, 0.18);
  backdrop-filter: blur(6px);
  border: 1px solid rgba(255, 255, 255, 0.25);
}
.hero :deep(.v-breadcrumbs-item),
.hero :deep(.v-breadcrumbs-divider) {
  color: rgba(255, 255, 255, 0.85) !important;
}

.mode-switch {
  display: inline-flex;
  background: rgba(255, 255, 255, 0.14);
  padding: 4px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  backdrop-filter: blur(6px);
}
.mode-pill {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 18px;
  border-radius: 999px;
  border: none;
  background: transparent;
  color: rgba(255, 255, 255, 0.85);
  font-weight: 500;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.18s ease;
}
.mode-pill:hover { color: white; }
.mode-pill.active {
  background: white;
  color: rgb(var(--v-theme-primary));
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.18);
}
.hero-delete .mode-pill.active { color: rgb(var(--v-theme-error)); }

.stat {
  background: rgba(255, 255, 255, 0.12);
  border: 1px solid rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(6px);
  border-radius: 14px;
  padding: 12px 16px;
  color: white;
}
.stat-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  opacity: 0.8;
}
.stat-value {
  font-size: 22px;
  font-weight: 700;
  line-height: 1.1;
  margin-top: 2px;
}
.stat-accent { background: rgba(255, 255, 255, 0.22); }
.stat-warning {
  background: rgba(255, 193, 7, 0.25);
  border-color: rgba(255, 193, 7, 0.5);
}

/* ── Action bar ────────────────────────────────────────────────────── */
.content-area { margin-top: -36px; position: relative; z-index: 2; }

.action-bar {
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: 0 6px 24px rgba(15, 23, 42, 0.06) !important;
  overflow: hidden;
}
.action-bar-inner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
}
.search-field { min-width: 240px; max-width: 360px; flex: 1; }
.filter-select { min-width: 200px; }
.save-btn { min-width: 180px; font-weight: 600; }

.helper-strip {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 8px 18px;
  font-size: 12.5px;
  color: rgba(0, 0, 0, 0.65);
  background: rgba(var(--v-theme-primary), 0.04);
  border-top: 1px solid rgba(0, 0, 0, 0.05);
  flex-wrap: wrap;
}
.helper-strip kbd {
  background: white;
  border: 1px solid rgba(0, 0, 0, 0.15);
  border-radius: 4px;
  padding: 1px 6px;
  font-family: ui-monospace, monospace;
  font-size: 11px;
  margin: 0 3px;
}
.dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin: 0 4px;
  vertical-align: middle;
}
.dot-warning { background: rgb(var(--v-theme-warning)); }

/* ── Sheet ─────────────────────────────────────────────────────────── */
.sheet-card {
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: 0 6px 24px rgba(15, 23, 42, 0.06) !important;
  overflow: hidden;
}
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
  height: calc(100vh - 220px);
}
.is-fullscreen { background: rgb(var(--v-theme-background)); }
.is-fullscreen .content-area { margin-top: 0; padding-top: 12px !important; }
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
  border-bottom: 2px solid rgba(0, 0, 0, 0.08);
  padding: 10px 12px;
  font-weight: 600;
  font-size: 11.5px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(0, 0, 0, 0.65);
  text-align: left;
  white-space: nowrap;
  z-index: 2;
}
.sheet tbody td {
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
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
.col-id { width: 56px; color: rgba(0, 0, 0, 0.45); }
.col-name { min-width: 260px; }
.col-cat, .col-unit { min-width: 140px; }
.col-num { width: 130px; min-width: 130px; }
.col-num.col-price { width: 150px; min-width: 150px; }
.col-loc, .col-bar { min-width: 130px; }
.col-rx { min-width: 130px; }
.col-act { width: 80px; text-align: center; }
.row-num {
  color: rgba(0, 0, 0, 0.4);
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
.cell-input:hover { border-color: rgba(0, 0, 0, 0.12); }
.cell-input:focus {
  border-color: rgb(var(--v-theme-primary));
  background: white;
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.18);
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
  border-top: 1px solid rgba(0, 0, 0, 0.06);
  background: rgba(var(--v-theme-primary), 0.02);
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

/* ── Dark theme tweaks ─────────────────────────────────────────────── */
:deep(.v-theme--dark) .helper-strip { background: rgba(255, 255, 255, 0.04); color: rgba(255, 255, 255, 0.7); }
:deep(.v-theme--dark) .helper-strip kbd { background: rgba(255, 255, 255, 0.08); color: white; border-color: rgba(255, 255, 255, 0.2); }
:deep(.v-theme--dark) .cell-input:focus { background: rgba(255, 255, 255, 0.04); }
:deep(.v-theme--dark) .sheet thead th { color: rgba(255, 255, 255, 0.75); }
</style>
