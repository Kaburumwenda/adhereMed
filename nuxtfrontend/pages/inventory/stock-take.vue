<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="indigo-darken-3" size="32">mdi-clipboard-list-outline</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Stock Take</div>
              <div class="text-body-2" style="opacity:0.9">
                Cycle counts, variance reports &amp; auto-reconciliation.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-indigo-darken-3"
                 prepend-icon="mdi-plus" @click="openCreate">New Count</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">Refresh</v-btn>
        </v-col>
      </v-row>
      <v-row class="mt-4" dense>
        <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="36" class="mr-3">
                <v-icon color="white" size="20">{{ k.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Filter -->
    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by reference or name…" density="comfortable"
                        hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                    label="Status" variant="outlined" density="comfortable" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading"
                    items-per-page="15" density="comfortable">
        <template #item.reference="{ item }">
          <div class="font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</div>
        </template>
        <template #item.name="{ item }">
          <div class="font-weight-medium">{{ item.name }}</div>
          <div class="text-caption text-medium-emphasis">
            {{ item.branch_name || 'All branches' }} · {{ item.category_name || 'All categories' }}
          </div>
        </template>
        <template #item.progress="{ item }">
          <v-chip size="small" variant="tonal" color="indigo">
            {{ item.counted_lines || 0 }} / {{ item.total_lines || 0 }} counted
          </v-chip>
        </template>
        <template #item.total_variance="{ item }">
          <span :class="varianceColor(item.total_variance)">
            {{ item.total_variance > 0 ? '+' : '' }}{{ item.total_variance || 0 }}
          </span>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="flat" :color="statusColor(item.status)">
            {{ statusLabel(item.status) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" variant="text" size="small" @click="openCount(item)" />
        </template>
        <template #no-data>
          <div class="text-center pa-6">
            <v-icon size="48" color="grey-lighten-1">mdi-clipboard-text-off</v-icon>
            <div class="text-body-2 mt-2">No stock takes yet.</div>
            <v-btn color="primary" class="mt-3" prepend-icon="mdi-plus" @click="openCreate">Create first count</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create dialog -->
    <v-dialog v-model="createDialog" max-width="540" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-plus-circle</v-icon>New Stock Take
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="createDialog = false" />
        </v-card-title>
        <v-card-text>
          <v-text-field v-model="newCount.name" label="Count name *" :rules="req"
                        variant="outlined" density="comfortable" />
          <v-select v-model="newCount.branch" :items="branches" item-title="name" item-value="id"
                    label="Branch (optional, all if blank)" variant="outlined" density="comfortable" clearable />
          <v-select v-model="newCount.category" :items="categories" item-title="name" item-value="id"
                    label="Category (optional, all if blank)" variant="outlined" density="comfortable" clearable />
          <v-textarea v-model="newCount.notes" label="Notes" rows="2" auto-grow
                      variant="outlined" density="comfortable" />
          <v-alert type="info" variant="tonal" density="compact" class="mt-2">
            A count sheet will be generated with current system quantities for all matching items.
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving" @click="createCount">Create &amp; Generate Sheet</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Count detail dialog (full-screen counting) -->
    <v-dialog v-model="detailDialog" fullscreen transition="dialog-bottom-transition">
      <v-card v-if="active" tile class="d-flex flex-column" style="height:100vh">
        <v-toolbar color="indigo-darken-3" dark>
          <v-btn icon="mdi-close" @click="detailDialog = false" />
          <v-toolbar-title>
            {{ active.reference }} · {{ active.name }}
            <v-chip size="small" class="ml-2" :color="statusColor(active.status)" variant="elevated">
              {{ statusLabel(active.status) }}
            </v-chip>
          </v-toolbar-title>
          <v-spacer />
          <v-btn v-if="active.status !== 'completed'" variant="text" prepend-icon="mdi-content-save"
                 :loading="savingLines" @click="saveLines">Save Counts</v-btn>
          <v-btn v-if="active.status !== 'completed'" color="success" variant="elevated" class="ml-2"
                 prepend-icon="mdi-check-bold" :loading="completing" @click="completeCount">
            Complete &amp; Reconcile
          </v-btn>
        </v-toolbar>

        <v-row no-gutters class="flex-grow-1">
          <v-col cols="12" md="9" class="pa-4" style="overflow:auto">
            <v-text-field v-model="lineSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Filter items…" density="comfortable" hide-details
                          variant="outlined" class="mb-3" clearable />
            <v-table density="comfortable">
              <thead>
                <tr>
                  <th>Medication</th>
                  <th style="width:100px" class="text-right">Expected</th>
                  <th style="width:140px">Counted</th>
                  <th style="width:100px" class="text-right">Variance</th>
                  <th style="width:100px" class="text-right">Value</th>
                  <th style="width:200px">Notes</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="l in filteredLines" :key="l.id">
                  <td>
                    <div class="font-weight-medium">{{ l.stock_name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ l.stock_unit }}</div>
                  </td>
                  <td class="text-right">{{ l.expected_quantity }}</td>
                  <td>
                    <v-text-field v-model.number="l.counted_quantity" type="number" min="0"
                                  :disabled="active.status === 'completed'"
                                  density="compact" variant="outlined" hide-details />
                  </td>
                  <td class="text-right" :class="varianceColor(l.variance)">
                    <strong>{{ l.variance > 0 ? '+' : '' }}{{ l.variance }}</strong>
                  </td>
                  <td class="text-right" :class="varianceColor(Number(l.variance_value))">
                    KSh {{ Number(l.variance_value || 0).toLocaleString() }}
                  </td>
                  <td>
                    <v-text-field v-model="l.notes" :disabled="active.status === 'completed'"
                                  density="compact" variant="plain" hide-details placeholder="—" />
                  </td>
                </tr>
              </tbody>
            </v-table>
          </v-col>

          <v-col cols="12" md="3" class="pa-4 bg-grey-lighten-4 d-none d-md-block" style="overflow:auto">
            <div class="text-subtitle-1 font-weight-bold mb-3">Summary</div>
            <v-card flat class="pa-3 mb-2" border>
              <div class="text-caption text-medium-emphasis">Total items</div>
              <div class="text-h6 font-weight-bold">{{ active.total_lines }}</div>
            </v-card>
            <v-card flat class="pa-3 mb-2" border>
              <div class="text-caption text-medium-emphasis">Counted</div>
              <div class="text-h6 font-weight-bold">
                {{ countedNow }} / {{ active.total_lines }}
              </div>
              <v-progress-linear :model-value="(countedNow / Math.max(1, active.total_lines)) * 100"
                                 color="indigo" rounded class="mt-2" />
            </v-card>
            <v-card flat class="pa-3 mb-2" border>
              <div class="text-caption text-medium-emphasis">Total Variance</div>
              <div class="text-h6 font-weight-bold" :class="varianceColor(varianceNow)">
                {{ varianceNow > 0 ? '+' : '' }}{{ varianceNow }}
              </div>
              <div class="text-caption" :class="varianceColor(varianceValueNow)">
                KSh {{ Number(varianceValueNow).toLocaleString() }}
              </div>
            </v-card>
            <v-divider class="my-3" />
            <div class="text-caption text-medium-emphasis mb-1">Created by</div>
            <div class="text-body-2 mb-2">{{ active.created_by_name || '—' }}</div>
            <div v-if="active.completed_by_name" class="text-caption text-medium-emphasis mb-1">Completed by</div>
            <div v-if="active.completed_by_name" class="text-body-2">{{ active.completed_by_name }}</div>
          </v-col>
        </v-row>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const savingLines = ref(false)
const completing = ref(false)
const counts = ref([])
const branches = ref([])
const categories = ref([])
const search = ref('')
const lineSearch = ref('')
const statusFilter = ref('all')
const createDialog = ref(false)
const detailDialog = ref(false)
const active = ref(null)
const newCount = ref({ name: '', branch: null, category: null, notes: '' })
const snack = ref({ show: false, color: 'success', text: '' })
const req = [v => !!v || 'Required']

const statusOptions = [
  { label: 'All', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'In progress', value: 'in_progress' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]

const headers = [
  { title: 'Reference', key: 'reference', width: 180 },
  { title: 'Name', key: 'name' },
  { title: 'Progress', key: 'progress', width: 160 },
  { title: 'Variance', key: 'total_variance', width: 110, align: 'end' },
  { title: 'Status', key: 'status', width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

const kpis = computed(() => {
  const inProg = counts.value.filter(c => c.status === 'in_progress').length
  const done = counts.value.filter(c => c.status === 'completed').length
  const totalVar = counts.value.reduce((s, c) => s + Number(c.total_variance_value || 0), 0)
  return [
    { label: 'Total Counts', value: counts.value.length, icon: 'mdi-clipboard-list', color: 'indigo' },
    { label: 'In Progress', value: inProg, icon: 'mdi-progress-clock', color: 'amber' },
    { label: 'Completed', value: done, icon: 'mdi-check-circle', color: 'green' },
    { label: 'Variance Value', value: 'KSh ' + Math.round(totalVar).toLocaleString(), icon: 'mdi-cash-sync', color: 'purple' },
  ]
})

const filtered = computed(() => {
  const s = (search.value || '').toLowerCase()
  return counts.value.filter(c => {
    if (statusFilter.value !== 'all' && c.status !== statusFilter.value) return false
    if (!s) return true
    return [c.reference, c.name].filter(Boolean).some(v => v.toLowerCase().includes(s))
  })
})

const filteredLines = computed(() => {
  if (!active.value?.lines) return []
  const s = (lineSearch.value || '').toLowerCase()
  if (!s) return active.value.lines
  return active.value.lines.filter(l => (l.stock_name || '').toLowerCase().includes(s))
})

const countedNow = computed(() => (active.value?.lines || []).filter(l => l.counted_quantity != null && l.counted_quantity !== '').length)
const varianceNow = computed(() => (active.value?.lines || []).reduce((s, l) => s + (Number(l.counted_quantity ?? l.expected_quantity) - l.expected_quantity), 0))
const varianceValueNow = computed(() => (active.value?.lines || []).reduce((s, l) => {
  const v = Number(l.counted_quantity ?? l.expected_quantity) - l.expected_quantity
  return s + v * Number(l.cost_price || 0)
}, 0))

async function load() {
  loading.value = true
  try {
    const [c, b, cat] = await Promise.all([
      $api.get('/inventory/counts/').then(r => r.data?.results || r.data || []),
      $api.get('/pharmacy-profile/branches/').then(r => r.data?.results || r.data || []).catch(() => []),
      $api.get('/inventory/categories/').then(r => r.data?.results || r.data || []).catch(() => []),
    ])
    counts.value = c
    branches.value = b
    categories.value = cat
  } catch (e) { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

function openCreate() {
  newCount.value = { name: `Count ${new Date().toLocaleDateString()}`, branch: null, category: null, notes: '' }
  createDialog.value = true
}

async function createCount() {
  if (!newCount.value.name) return
  saving.value = true
  try {
    const created = await $api.post('/inventory/counts/', newCount.value).then(r => r.data)
    await $api.post(`/inventory/counts/${created.id}/generate-sheet/`)
    createDialog.value = false
    showSnack('Count sheet generated', 'success')
    await load()
    const fresh = await $api.get(`/inventory/counts/${created.id}/`).then(r => r.data)
    active.value = fresh
    detailDialog.value = true
  } catch (e) { showSnack('Failed to create', 'error') }
  finally { saving.value = false }
}

async function openCount(c) {
  try {
    active.value = await $api.get(`/inventory/counts/${c.id}/`).then(r => r.data)
    detailDialog.value = true
  } catch { showSnack('Failed to load count', 'error') }
}

async function saveLines() {
  if (!active.value) return
  savingLines.value = true
  try {
    await $api.post(`/inventory/counts/${active.value.id}/save-counts/`, {
      lines: active.value.lines.map(l => ({
        id: l.id,
        counted_quantity: l.counted_quantity === '' ? null : l.counted_quantity,
        notes: l.notes,
      })),
    })
    showSnack('Counts saved', 'success')
    active.value = await $api.get(`/inventory/counts/${active.value.id}/`).then(r => r.data)
  } catch (e) { showSnack('Failed to save', 'error') }
  finally { savingLines.value = false }
}

async function completeCount() {
  if (!active.value) return
  if (!confirm(`Complete this count and create variance adjustments? This cannot be undone.`)) return
  completing.value = true
  try {
    await saveLines()
    const res = await $api.post(`/inventory/counts/${active.value.id}/complete/`).then(r => r.data)
    showSnack(`Reconciled — ${res.adjustments_created} adjustments created`, 'success')
    active.value = res
    await load()
  } catch (e) { showSnack('Failed to complete', 'error') }
  finally { completing.value = false }
}

function statusLabel(s) { return ({ draft: 'Draft', in_progress: 'In Progress', completed: 'Completed', cancelled: 'Cancelled' })[s] || s }
function statusColor(s) { return ({ draft: 'grey', in_progress: 'amber', completed: 'success', cancelled: 'error' })[s] || 'grey' }
function varianceColor(v) {
  if (!v) return 'text-medium-emphasis'
  return v > 0 ? 'text-success' : 'text-error'
}
function formatDate(d) { return d ? new Date(d).toLocaleString() : '' }
function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }

onMounted(load)
</script>

<style scoped>
.hero { background: linear-gradient(135deg, #312e81 0%, #4f46e5 50%, #818cf8 100%); }
.kpi { background: rgba(255, 255, 255, 0.1) !important; backdrop-filter: blur(8px); border: 1px solid rgba(255, 255, 255, 0.15); }
.kpi :deep(.text-h6) { color: #fff; }
.kpi :deep(.text-medium-emphasis) { color: rgba(255, 255, 255, 0.85) !important; }
</style>
