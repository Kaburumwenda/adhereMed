<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Departments" subtitle="Clinic department management"
      icon="mdi-domain" color="indigo">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="load">Refresh</v-btn>
        <v-btn color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNew">New Department</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, description…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="headFilter" :items="headOptions"
            label="Department Head" variant="outlined" density="compact"
            hide-details clearable :loading="staffR.loading.value" />
        </v-col>
        <v-col cols="12" md="1" class="d-flex align-center justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="indigo">
            <v-btn value="grid" icon="mdi-view-grid" size="small" />
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
      <div v-if="activeFilters" class="px-1 pt-2 d-flex flex-wrap ga-2">
        <v-chip v-if="statusFilter" size="small" closable @click:close="statusFilter = null"
          variant="tonal" :color="statusFilter === 'active' ? 'success' : 'error'" class="text-capitalize">
          <v-icon start size="14">{{ statusFilter === 'active' ? 'mdi-check-circle' : 'mdi-close-circle' }}</v-icon>
          Status: {{ statusFilter }}
        </v-chip>
        <v-chip v-if="headFilter" size="small" closable @click:close="headFilter = null"
          variant="tonal" color="indigo">
          <v-icon start size="14">mdi-account-tie</v-icon>Head: {{ headFilterLabel }}
        </v-chip>
        <v-btn size="small" variant="text" class="text-none"
          prepend-icon="mdi-filter-remove" @click="clearFilters">Clear all</v-btn>
      </div>
    </v-card>

    <!-- ── Quick KPI Cards ──────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">{{ k.label }}</div>
              <div class="text-h4 font-weight-bold" :class="`text-${k.color}`">{{ k.value }}</div>
            </div>
            <v-avatar :color="k.color + '-lighten-5'" variant="tonal" size="48">
              <v-icon :color="k.color" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Distribution Stat Cards ──────────────────────────────── -->
    <v-row dense class="mb-3">
      <!-- Active vs Inactive -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">ACTIVE VS INACTIVE</span>
            <v-icon size="16" color="medium-emphasis">mdi-toggle-switch</v-icon>
          </div>
          <div class="d-flex align-center ga-4 mb-2">
            <div class="flex-1 text-center">
              <v-icon color="success" size="32" class="mb-1">mdi-check-circle</v-icon>
              <div class="text-h5 font-weight-bold text-success">{{ activeCount }}</div>
              <div class="text-caption text-medium-emphasis">Active</div>
            </div>
            <v-divider vertical />
            <div class="flex-1 text-center">
              <v-icon color="error" size="32" class="mb-1">mdi-close-circle</v-icon>
              <div class="text-h5 font-weight-bold text-error">{{ inactiveCount }}</div>
              <div class="text-caption text-medium-emphasis">Inactive</div>
            </div>
          </div>
          <v-progress-linear :model-value="activePct" color="success" height="8" rounded />
          <div class="text-caption text-medium-emphasis mt-2">{{ activePct.toFixed(0) }}% of departments active</div>
        </v-card>
      </v-col>

      <!-- Headcount Distribution -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">HEADCOUNT DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-account-group</v-icon>
          </div>
          <div v-if="headDist.length" class="d-flex flex-column ga-2 mb-2">
            <div v-for="h in headDist" :key="h.name" class="d-flex align-center ga-2">
              <v-icon size="16" color="indigo">mdi-account-tie</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0 text-truncate" style="width: 140px" :title="h.name">{{ h.name }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill head-bar" :style="{ width: `${h.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold text-indigo" style="width: 28px; text-align: right">{{ h.count }}</span>
            </div>
          </div>
          <div v-else class="text-center text-caption text-medium-emphasis py-4">
            No department heads assigned
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ unassignedCount }} unassigned</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <div v-if="r.loading.value" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="indigo" size="48" />
    </div>

    <!-- Empty state -->
    <div v-else-if="!filteredDepartments.length" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-domain</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No departments found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">
        {{ activeFilters ? 'Try adjusting your filters.' : 'Create your first department to get started.' }}
      </div>
      <v-btn v-if="!activeFilters" color="indigo" rounded="lg"
        prepend-icon="mdi-plus" class="text-none" @click="openNew">New Department</v-btn>
      <v-btn v-else variant="text" rounded="lg" class="text-none"
        prepend-icon="mdi-filter-remove" @click="clearFilters">Clear filters</v-btn>
    </div>

    <!-- Grid view (premium cards) -->
    <div v-else-if="view === 'grid'" class="dept-grid">
      <v-row dense>
        <v-col v-for="dept in filteredDepartments" :key="dept.id" cols="12" sm="6" md="4" lg="3">
          <v-card rounded="lg" variant="outlined" class="dept-card h-100"
            :class="{ 'dept-card-inactive': !dept.is_active }"
            @click="openEdit(dept)">
            <div class="dept-card-banner" :class="dept.is_active ? 'dept-banner-active' : 'dept-banner-inactive'">
              <div class="d-flex align-center justify-space-between pa-3">
                <v-avatar :color="dept.is_active ? 'indigo' : 'grey'" variant="tonal" size="40">
                  <v-icon :color="dept.is_active ? 'indigo' : 'grey'" size="20">{{ deptIcon(dept) }}</v-icon>
                </v-avatar>
                <v-chip size="x-small" variant="flat"
                  :color="dept.is_active ? 'success' : 'error'">
                  <v-icon start size="10">{{ dept.is_active ? 'mdi-check' : 'mdi-close' }}</v-icon>
                  {{ dept.is_active ? 'Active' : 'Inactive' }}
                </v-chip>
              </div>
            </div>
            <v-card-text class="pa-3 pt-2">
              <div class="text-subtitle-1 font-weight-bold mb-1 text-truncate">{{ dept.name }}</div>
              <div class="text-caption text-medium-emphasis mb-2 text-truncate-2" style="min-height: 32px">
                {{ dept.description || 'No description provided' }}
              </div>
              <v-divider class="mb-2" />
              <div class="d-flex align-center ga-2 mb-1">
                <v-icon size="14" color="indigo">mdi-account-tie</v-icon>
                <span class="text-body-2 font-weight-medium">{{ headName(dept) || 'Unassigned' }}</span>
              </div>
              <div class="d-flex align-center ga-2">
                <v-icon size="14" color="medium-emphasis">mdi-calendar-plus</v-icon>
                <span class="text-caption text-medium-emphasis">{{ formatDate(dept.created_at) }}</span>
              </div>
            </v-card-text>
            <v-card-actions class="px-3 pb-3 pt-0" @click.stop>
              <v-btn icon="mdi-pencil" variant="text" size="small" color="indigo"
                @click="openEdit(dept)" />
              <v-btn icon="mdi-delete" variant="text" size="small" color="error"
                @click="confirmDelete(dept)" />
              <v-spacer />
              <v-btn icon variant="text" size="small"
                @click="toggleActive(dept)">
                <v-icon>{{ dept.is_active ? 'mdi-toggle-switch-off' : 'mdi-toggle-switch' }}</v-icon>
                <v-tooltip activator="parent" location="top">
                  {{ dept.is_active ? 'Deactivate' : 'Activate' }}
                </v-tooltip>
              </v-btn>
            </v-card-actions>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Table view -->
    <v-card v-else flat rounded="lg" class="results-card">
      <v-data-table
        :headers="headers"
        :items="filteredDepartments"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => openEdit(item)"
        class="departments-table">
        <template #item.name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar :color="item.is_active ? 'indigo-lighten-5' : 'grey-lighten-4'" variant="tonal" size="32">
              <v-icon :color="item.is_active ? 'indigo' : 'grey'" size="16">{{ deptIcon(item) }}</v-icon>
            </v-avatar>
            <span class="font-weight-medium">{{ item.name }}</span>
          </div>
        </template>
        <template #item.head="{ item }">
          <div class="d-flex align-center ga-1">
            <v-icon size="14" color="indigo">mdi-account-tie</v-icon>
            <span>{{ headName(item) || '—' }}</span>
          </div>
        </template>
        <template #item.description="{ value }">
          <span v-if="value" class="text-truncate d-inline-block" style="max-width: 240px">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.is_active="{ item }">
          <v-chip size="small" variant="tonal"
            :color="item.is_active ? 'success' : 'error'"
            class="font-weight-medium">
            <v-icon start size="14">{{ item.is_active ? 'mdi-check-circle' : 'mdi-close-circle' }}</v-icon>
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.created_at="{ value }">{{ formatDate(value) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-pencil" variant="text" size="small" color="indigo"
              @click="openEdit(item)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
            <v-btn icon variant="text" size="small"
              @click="toggleActive(item)">
              <v-icon>{{ item.is_active ? 'mdi-toggle-switch-off' : 'mdi-toggle-switch' }}</v-icon>
              <v-tooltip activator="parent" location="top">
                {{ item.is_active ? 'Deactivate' : 'Activate' }}
              </v-tooltip>
            </v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ New/Edit department dialog ═══════════════════════════════ -->
    <v-dialog v-model="dialog" max-width="640" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar :color="editing ? 'indigo-lighten-5' : 'indigo'" variant="tonal" size="36" class="mr-3">
            <v-icon :color="editing ? 'indigo' : 'white'">{{ editing ? 'mdi-domain-edit' : 'mdi-domain-plus' }}</v-icon>
          </v-avatar>
          {{ editing ? 'Edit Department' : 'New Department' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-form ref="formRef" @submit.prevent="save">
            <v-text-field v-model="form.name" label="Department Name" required
              variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-domain"
              placeholder="e.g. Cardiology, Pediatrics, Radiology"
              :rules="req" />
            <v-select v-model="form.head" :items="staffOptions"
              label="Department Head" variant="outlined" density="compact"
              class="mb-3" clearable prepend-inner-icon="mdi-account-tie"
              placeholder="Select a department head"
              :loading="staffR.loading.value" />
            <v-textarea v-model="form.description" label="Description"
              variant="outlined" density="compact" rows="3" auto-grow
              prepend-inner-icon="mdi-text"
              placeholder="Brief description of the department's purpose and scope" />
            <v-switch v-model="form.is_active" label="Active"
              color="success" class="mt-1" density="compact" hide-details />
            <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mt-3">
              {{ r.error.value }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="indigo" rounded="lg" class="text-none" :loading="r.saving.value"
            prepend-icon="mdi-content-save" @click="save">
            {{ editing ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Delete confirmation dialog ═══════════════════════════════ -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Department</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3" variant="tonal">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete
              <strong>{{ deleteTarget?.name || 'this department' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="r.saving.value" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const ns = '/clinics'
const r = useResource('/departments/')
const staffR = useResource('/auth/staff/')

const req = [v => !!v || 'Required']

const view = ref('grid')
const statusFilter = ref(null)
const headFilter = ref(null)

const statusOptions = [
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]

const headers = [
  { title: 'Name', key: 'name', sortable: false },
  { title: 'Head', key: 'head', width: 180, sortable: false },
  { title: 'Description', key: 'description', sortable: false },
  { title: 'Status', key: 'is_active', width: 130, sortable: false },
  { title: 'Created', key: 'created_at', width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 150 },
]

// ── Computed / derived ──────────────────────────────────────────
const activeFilters = computed(() =>
  statusFilter.value || headFilter.value || r.search.value,
)

function clearFilters() {
  statusFilter.value = null
  headFilter.value = null
  r.search.value = ''
}

const filteredDepartments = computed(() => {
  let list = r.filtered.value
  if (statusFilter.value === 'active') list = list.filter(d => d.is_active)
  if (statusFilter.value === 'inactive') list = list.filter(d => !d.is_active)
  if (headFilter.value) list = list.filter(d => {
    const hid = d.head && typeof d.head === 'object' ? d.head.id : d.head
    return hid === headFilter.value
  })
  return list
})

function headName(d) {
  if (!d) return ''
  if (d.head_name) return d.head_name
  if (d.head && typeof d.head === 'object') return d.head.full_name || d.head.email || ''
  return ''
}

function deptIcon(d) {
  const name = (d.name || '').toLowerCase()
  if (name.includes('card')) return 'mdi-heart-pulse'
  if (name.includes('ped')) return 'mdi-baby-carriage'
  if (name.includes('radio') || name.includes('imag')) return 'mdi-x-ray'
  if (name.includes('lab')) return 'mdi-microscope'
  if (name.includes('emerg') || name.includes('triage')) return 'mdi-alert-circle'
  if (name.includes('surg')) return 'mdi-scissors-cutting'
  if (name.includes('pharm') || name.includes('med')) return 'mdi-pill'
  if (name.includes('ward')) return 'mdi-bed'
  if (name.includes('dental') || name.includes('dent')) return 'mdi-tooth'
  if (name.includes('neuro')) return 'mdi-brain'
  if (name.includes('orth')) return 'mdi-bone'
  if (name.includes('opht')) return 'mdi-eye'
  return 'mdi-domain'
}

// ── KPIs ────────────────────────────────────────────────────────
const kpis = computed(() => {
  const list = r.items.value
  return [
    { label: 'Total', value: list.length, icon: 'mdi-domain', color: 'indigo' },
    { label: 'Active', value: list.filter(d => d.is_active).length, icon: 'mdi-check-circle', color: 'success' },
    { label: 'Inactive', value: list.filter(d => !d.is_active).length, icon: 'mdi-close-circle', color: 'error' },
    { label: 'With Head', value: list.filter(d => headName(d)).length, icon: 'mdi-account-tie', color: 'teal' },
  ]
})

// ── Stat distributions ───────────────────────────────────────────
const activeCount = computed(() => filteredDepartments.value.filter(d => d.is_active).length)
const inactiveCount = computed(() => filteredDepartments.value.filter(d => !d.is_active).length)
const activePct = computed(() => {
  const total = filteredDepartments.value.length || 1
  return (activeCount.value / total) * 100
})

const unassignedCount = computed(() => filteredDepartments.value.filter(d => !headName(d)).length)

const headDist = computed(() => {
  const list = filteredDepartments.value
  const map = new Map()
  list.forEach(d => {
    const name = headName(d)
    if (!name) return
    map.set(name, (map.get(name) || 0) + 1)
  })
  const arr = [...map.entries()].map(([name, count]) => ({ name, count }))
  const max = Math.max(...arr.map(a => a.count), 1)
  arr.forEach(a => { a.pct = (a.count / max) * 100 })
  arr.sort((a, b) => b.count - a.count)
  return arr.slice(0, 6)
})

const headOptions = computed(() => {
  const seen = new Map()
  r.items.value.forEach(d => {
    const name = headName(d)
    const id = d.head && typeof d.head === 'object' ? d.head.id : d.head
    if (name && id && !seen.has(id)) seen.set(id, { title: name, value: id })
  })
  return [...seen.values()]
})

const headFilterLabel = computed(() =>
  headOptions.value.find(o => o.value === headFilter.value)?.title || '',
)

// ── Staff options ───────────────────────────────────────────────
const staffOptions = computed(() =>
  staffR.items.value.map(s => ({
    title: s.full_name || s.email,
    value: s.id,
  })),
)

// ── New / Edit dialog ──────────────────────────────────────────
const dialog = ref(false)
const editing = ref(null)
const formRef = ref(null)
const blankForm = () => ({ name: '', head: null, description: '', is_active: true })
const form = reactive(blankForm())

function openNew() {
  editing.value = null
  Object.assign(form, blankForm())
  dialog.value = true
}

function openEdit(item) {
  editing.value = item.id
  Object.assign(form, {
    name: item.name || '',
    head: item.head && typeof item.head === 'object' ? item.head.id : item.head,
    description: item.description || '',
    is_active: item.is_active !== false,
  })
  dialog.value = true
}

async function save() {
  const v = await formRef.value?.validate()
  if (v?.valid === false) return
  try {
    if (editing.value) {
      await r.update(editing.value, form)
      snack.text = 'Department updated successfully'
    } else {
      await r.create(form)
      snack.text = 'Department created successfully'
    }
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    await load()
  } catch {}
}

// ── Toggle active ───────────────────────────────────────────────
async function toggleActive(dept) {
  try {
    await r.update(dept.id, { is_active: !dept.is_active })
    snack.text = `${dept.name} ${!dept.is_active ? 'activated' : 'deactivated'}`
    snack.color = 'success'
    snack.show = true
    await load()
  } catch {
    snack.text = r.error.value || 'Failed to update department.'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Delete ────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)

function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}

async function performDelete() {
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Department deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    await load()
  } catch {
    snack.text = r.error.value || 'Failed to delete department.'
    snack.color = 'error'
    snack.show = true
  }
}

const snack = reactive({ show: false, color: 'success', text: '' })

function load() {
  r.list({ page_size: 1000 })
}

onMounted(() => {
  load()
  staffR.list({ page_size: 1000 })
})
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.departments-table :deep(tbody tr) { cursor: pointer; }

/* ── Distribution Cards ── */
.dist-card { overflow: hidden; }
.flex-1 { flex: 1; }
.flex-shrink-0 { flex-shrink: 0; }

/* Status / head bars */
.status-bar-track { height: 10px; background: rgba(var(--v-theme-on-surface), 0.06); }
.status-bar-fill { height: 100%; min-width: 4px; transition: width 0.3s ease; }
.head-bar { background: rgb(var(--v-theme-indigo)); }

/* ── Department Cards ── */
.dept-grid { min-height: 200px; }
.dept-card {
  cursor: pointer;
  transition: box-shadow 0.2s, transform 0.15s;
  overflow: hidden;
}
.dept-card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  transform: translateY(-2px);
}
.dept-card-inactive { opacity: 0.75; }
.dept-card-banner { padding: 0; }
.dept-banner-active {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(99, 102, 241, 0.02));
  border-bottom: 1px solid rgba(99, 102, 241, 0.08);
}
.dept-banner-inactive {
  background: linear-gradient(135deg, rgba(158, 158, 158, 0.08), rgba(158, 158, 158, 0.02));
  border-bottom: 1px solid rgba(158, 158, 158, 0.08);
}

/* Text truncation helpers */
.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
