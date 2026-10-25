<template>
  <div class="bulk-page" :class="{ 'is-fullscreen': fullscreen }">
    <v-container fluid class="pa-4 pa-md-6">
      <!-- Header -->
      <div v-if="!fullscreen" class="d-flex align-center flex-wrap ga-3 mb-5">
        <v-btn icon="mdi-arrow-left" variant="text" :to="backRoute" size="small" class="mr-1" />
        <v-avatar :color="mode === 'delete' ? 'red-lighten-5' : 'teal-lighten-5'" size="48">
          <v-icon :color="mode === 'delete' ? 'red-darken-2' : 'teal-darken-2'" size="28">{{ modeIcon }}</v-icon>
        </v-avatar>
        <div>
          <div class="text-h5 font-weight-bold">{{ mode === 'delete' ? 'Bulk Delete' : 'Bulk Edit' }}</div>
          <div class="text-body-2 text-medium-emphasis">
            {{ mode === 'delete'
              ? 'Select medications to remove permanently from the catalog'
              : 'Edit cells directly · Save all changes at once' }}
          </div>
        </div>
        <v-spacer />

        <!-- Mode switcher -->
        <v-btn-toggle v-model="mode" mandatory density="comfortable" rounded="lg" color="primary" divided>
          <v-btn value="edit" size="small" class="text-none" prepend-icon="mdi-table-edit">Edit</v-btn>
          <v-btn value="delete" size="small" class="text-none" prepend-icon="mdi-trash-can">Delete</v-btn>
        </v-btn-toggle>

        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
               :loading="loading" @click="load" class="text-none">Refresh</v-btn>
      </div>

      <!-- KPIs -->
      <v-row v-if="!fullscreen" dense class="mb-4">
        <v-col cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar color="teal-lighten-5" size="36" class="mr-2">
                <v-icon color="teal-darken-2" size="20">mdi-pill</v-icon>
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
              <v-avatar color="blue-lighten-5" size="36" class="mr-2">
                <v-icon color="blue-darken-2" size="20">mdi-eye-outline</v-icon>
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
            placeholder="Search by name, abbreviation, brand…"
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
            Click any cell to edit · Changes highlighted until saved
          </template>
          <template v-else>
            Tick rows to remove · Selections persist across search/filter · Deletion is permanent
          </template>
        </div>

        <v-progress-linear v-if="loading" color="primary" indeterminate height="3" />

        <!-- Empty state -->
        <div v-if="!loading && !filteredRows.length" class="empty-state">
          <v-avatar size="72" color="primary" variant="tonal" class="mb-3">
            <v-icon size="36">mdi-table-off</v-icon>
          </v-avatar>
          <div class="text-h6 mb-1">Nothing to show</div>
          <div class="text-body-2 text-medium-emphasis mb-4">
            {{ search || categoryFilter ? 'Try clearing filters.' : 'Add some medications first.' }}
          </div>
          <v-btn v-if="search || categoryFilter" color="primary" variant="tonal" rounded="lg" class="text-none"
                 @click="search = ''; categoryFilter = null">
            Clear filters
          </v-btn>
        </div>

        <!-- Spreadsheet -->
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
                <th class="col-name">Generic Name</th>
                <th class="col-abbr">Abbr</th>
                <th class="col-cat">Category</th>
                <th class="col-form">Dosage Form</th>
                <th class="col-str">Strength</th>
                <th class="col-unit">Unit</th>
                <th class="col-rx">Rx</th>
                <th class="col-act">Active</th>
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
                      v-model="row.generic_name"
                      class="cell-input cell-name"
                      type="text"
                      @input="markDirty(row.id, 'generic_name', row.generic_name)"
                    />
                    <div v-else>
                      <div class="font-weight-medium">{{ row.generic_name }}</div>
                      <div v-if="row.brand_names?.length" class="text-caption text-medium-emphasis">
                        {{ row.brand_names.slice(0, 2).join(', ') }}{{ row.brand_names.length > 2 ? '…' : '' }}
                      </div>
                    </div>
                  </div>
                </td>

                <td>
                  <input
                    v-if="mode === 'edit'"
                    v-model="row.abbreviation"
                    class="cell-input"
                    type="text"
                    @input="markDirty(row.id, 'abbreviation', row.abbreviation)"
                  />
                  <span v-else class="cell-mono text-medium-emphasis">{{ row.abbreviation || '—' }}</span>
                </td>

                <td>
                  <select
                    v-if="mode === 'edit'"
                    v-model="row.category"
                    class="cell-input"
                    @change="markDirty(row.id, 'category', row.category)"
                  >
                    <option v-for="c in categoryList" :key="c" :value="c">{{ c.replace('_', ' ') }}</option>
                  </select>
                  <v-chip v-else size="x-small" variant="tonal" color="teal" class="text-capitalize">
                    {{ (row.category || '').replace('_', ' ') }}
                  </v-chip>
                </td>

                <td>
                  <select
                    v-if="mode === 'edit'"
                    v-model="row.dosage_form"
                    class="cell-input"
                    @change="markDirty(row.id, 'dosage_form', row.dosage_form)"
                  >
                    <option v-for="d in dosageList" :key="d" :value="d">{{ d[0].toUpperCase() + d.slice(1) }}</option>
                  </select>
                  <span v-else class="text-capitalize">{{ row.dosage_form }}</span>
                </td>

                <td>
                  <input
                    v-if="mode === 'edit'"
                    v-model="row.strength"
                    class="cell-input"
                    type="text"
                    placeholder="500mg"
                    @input="markDirty(row.id, 'strength', row.strength)"
                  />
                  <span v-else class="text-medium-emphasis">{{ row.strength || '—' }}</span>
                </td>

                <td>
                  <input
                    v-if="mode === 'edit'"
                    v-model="row.unit"
                    class="cell-input"
                    type="text"
                    placeholder="tab, ml…"
                    @input="markDirty(row.id, 'unit', row.unit)"
                  />
                  <span v-else class="text-medium-emphasis">{{ row.unit || '—' }}</span>
                </td>

                <td class="text-center">
                  <v-switch
                    v-if="mode === 'edit'"
                    :model-value="row.requires_prescription"
                    color="error" density="compact" hide-details inset
                    @update:model-value="(v) => { row.requires_prescription = v; markDirty(row.id, 'requires_prescription', v) }"
                  />
                  <v-chip v-else size="x-small" variant="tonal" :color="row.requires_prescription ? 'error' : 'success'">
                    {{ row.requires_prescription ? 'Rx' : 'OTC' }}
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
          Delete {{ selectedIds.length }} medication{{ selectedIds.length === 1 ? '' : 's' }}?
        </v-card-title>
        <v-card-text class="text-center text-medium-emphasis">
          This permanently removes the selected medications from your catalog.
          This action cannot be undone.
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-btn variant="text" rounded="lg" class="text-none" block @click="confirmDelete = false">Cancel</v-btn>
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

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()

// Detect namespace from current route path (e.g. /ims/medications/bulk or /pharmacy/medications/bulk)
const ns = computed(() => {
  const p = route.path
  if (p.includes('/ims/')) return '/ims'
  if (p.includes('/clinics/')) return '/clinics/catalog'
  return '/pharmacy'
})
const backRoute = computed(() => `${ns.value}/medications`)

const mode = ref(route.query.mode === 'delete' ? 'delete' : 'edit')
const loading = ref(false)
const saving = ref(false)
const deleting = ref(false)
const fullscreen = ref(false)

function toggleFullscreen() { fullscreen.value = !fullscreen.value }

const rows = ref([])
const original = ref({})
const dirty = ref({})
const selectedIds = ref([])

const search = ref('')
const categoryFilter = ref(null)
const page = ref(1)
const pageSize = ref(50)
const confirmDelete = ref(false)

const snack = ref({ show: false, text: '', color: 'success', icon: 'mdi-check-circle' })

const modeIcon = computed(() => mode.value === 'delete' ? 'mdi-trash-can' : 'mdi-table-edit')

watch(mode, (newMode, oldMode) => {
  if (newMode === oldMode) return
  if (oldMode === 'edit' && dirtyCount.value) {
    if (!confirm('Discard unsaved changes?')) { mode.value = oldMode; return }
    discardChanges()
  }
  selectedIds.value = []
  router.replace({ query: { ...route.query, mode: newMode } })
})

const categoryList = [
  'analgesic','antibiotic','antifungal','antiviral','antiparasitic','antimalarial',
  'antihypertensive','antidiabetic','antihistamine','antacid','cardiovascular',
  'respiratory','cns','hormone','vitamin','vaccine','dermatological','ophthalmic',
  'oncology','immunosuppressant','nsaid','other',
]
const dosageList = [
  'tablet','capsule','syrup','injection','cream','ointment','drops','inhaler',
  'suppository','suspension','powder','gel','patch','lozenge','spray','solution','other',
]

const categoryOptions = computed(() => [
  { label: 'All categories', value: null },
  ...categoryList.map(c => ({ label: c.replace('_', ' '), value: c }))
])

const filteredRows = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  return rows.value.filter(r => {
    if (categoryFilter.value && r.category !== categoryFilter.value) return false
    if (!q) return true
    return (r.generic_name || '').toLowerCase().includes(q) ||
           (r.abbreviation || '').toLowerCase().includes(q) ||
           (r.brand_names || []).some(b => b.toLowerCase().includes(q))
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

const palette = ['teal', 'success', 'warning', 'info', 'purple', 'primary', 'pink', 'indigo']
function rowColor(id) { return palette[id % palette.length] }

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/medications/', { params: { page_size: 2000 } })
    const list = data?.results ?? data ?? []
    rows.value = list.map(s => ({ ...s }))
    original.value = Object.fromEntries(list.map(s => [s.id, { ...s }]))
    dirty.value = {}
    selectedIds.value = []
  } catch (e) {
    snack.value = { show: true, text: e?.response?.data?.detail || 'Failed to load medications', color: 'error', icon: 'mdi-alert' }
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
    const payload = Object.entries(dirty.value).map(([id, fields]) => ({
      id: Number(id), ...fields
    }))
    const { data: res } = await $api.post('/medications/bulk-update/', { items: payload })
    snack.value = {
      show: true,
      color: res.errors?.length ? 'warning' : 'success',
      icon: res.errors?.length ? 'mdi-alert' : 'mdi-check-circle',
      text: `Updated ${res.updated} medication(s)${res.errors?.length ? ` · ${res.errors.length} error(s)` : ''}.`
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
    const { data: res } = await $api.post('/medications/bulk-delete/', { ids: selectedIds.value })
    snack.value = { show: true, text: `Deleted ${res.deleted} medication(s).`, color: 'success', icon: 'mdi-check-circle' }
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

/* ── KPI cards ── */
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-accent {
  border-color: rgba(var(--v-theme-primary), 0.25);
  background: rgba(var(--v-theme-primary), 0.03);
}
.kpi-warning {
  border-color: rgba(var(--v-theme-warning), 0.3);
  background: rgba(var(--v-theme-warning), 0.04);
}

/* ── Table card ── */
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

/* ── Sheet ── */
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
.is-fullscreen .sheet-wrap { height: calc(100vh - 140px); }
.is-fullscreen .bulk-page > .v-container { padding-top: 12px !important; }

.sheet {
  min-width: 100%;
  width: max-content;
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

.row-dirty td { background: rgba(var(--v-theme-warning), 0.10) !important; }
.row-dirty td:first-child { box-shadow: inset 3px 0 0 0 rgb(var(--v-theme-warning)); }

.sheet-delete .row-selected td { background: rgba(var(--v-theme-error), 0.08) !important; }
.sheet-edit .row-selected td { background: rgba(var(--v-theme-primary), 0.08) !important; }

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
.col-name { min-width: 320px; }
.sheet-edit .col-name { min-width: 360px; }
.col-abbr { min-width: 80px; }
.col-cat, .col-form { min-width: 130px; }
.col-str { min-width: 100px; }
.col-unit { min-width: 90px; }
.col-rx { min-width: 80px; text-align: center; }
.col-act { width: 80px; text-align: center; }
.row-num { color: rgba(var(--v-theme-on-surface), 0.4); font-variant-numeric: tabular-nums; }

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
.cell-mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 12px; }
.cell-input.cell-name { font-weight: 500; min-width: 280px; }
.sheet-edit .cell-input.cell-name { min-width: 320px; }

/* ── Pagination ── */
.pagination-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}

/* ── Confirm dialog ── */
.confirm-banner { display: flex; justify-content: center; padding-top: 24px; }

/* ── Floating mobile save ── */
.floating-save {
  position: fixed;
  bottom: 18px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 100;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.25);
}
</style>
