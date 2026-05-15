<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="cyan-lighten-5" size="48" class="mr-3">
          <v-icon color="cyan-darken-2" size="28">mdi-truck-delivery-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">{{ $t('transfers.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Move inventory between branches with full audit trail</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" @click="openCreate">{{ $t('transfers.newTransfer') }}</v-btn>
      <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">{{ $t('common.refresh') }}</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by reference…" density="comfortable"
                        hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                    label="Status" variant="outlined" density="comfortable" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" items-per-page="15">
        <template #item.reference="{ item }">
          <div class="font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatDate(item.requested_at) }}</div>
        </template>
        <template #item.route="{ item }">
          <div class="d-flex align-center">
            <v-chip size="small" variant="tonal" color="blue">{{ item.source_branch_name }}</v-chip>
            <v-icon class="mx-2" size="20" color="grey">mdi-arrow-right</v-icon>
            <v-chip size="small" variant="tonal" color="green">{{ item.dest_branch_name }}</v-chip>
          </div>
        </template>
        <template #item.totals="{ item }">
          <v-chip size="small" variant="tonal" color="indigo">
            {{ item.total_items }} items · {{ item.total_quantity }} units
          </v-chip>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="flat" :color="statusColor(item.status)">
            <v-icon start size="14">{{ statusIcon(item.status) }}</v-icon>
            {{ statusLabel(item.status) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" variant="text" size="small" @click="openDetail(item)" />
          <v-btn v-if="item.status === 'requested'" icon="mdi-check-bold" color="success"
                 variant="text" size="small" @click="approve(item)" />
          <v-btn v-if="item.status === 'in_transit'" icon="mdi-package-down" color="primary"
                 variant="text" size="small" @click="openReceive(item)" />
        </template>
        <template #no-data>
          <div class="text-center pa-6">
            <v-icon size="48" color="grey-lighten-1">mdi-truck-off-outline</v-icon>
            <div class="text-body-2 mt-2">No transfers yet.</div>
            <v-btn color="primary" class="mt-3" prepend-icon="mdi-plus" @click="openCreate">Create transfer</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create transfer dialog -->
    <v-dialog v-model="createDialog" max-width="800" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-swap-horizontal</v-icon>New Stock Transfer
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="createDialog = false" />
        </v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.source_branch" :items="branches" item-title="name" item-value="id"
                        label="From branch *" variant="outlined" density="comfortable" :rules="req" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.dest_branch" :items="destBranches" item-title="name" item-value="id"
                        label="To branch *" variant="outlined" density="comfortable" :rules="req" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" hide-details />
            </v-col>
          </v-row>

          <div class="text-subtitle-2 font-weight-bold mt-4 mb-2">Items</div>
          <v-autocomplete v-model="picker" :items="stockOptions" :loading="stockLoading"
                          :search="stockSearch" @update:search="onStockSearch"
                          item-title="medication_name" item-value="id" return-object
                          label="Search & add medication" prepend-inner-icon="mdi-magnify"
                          variant="outlined" density="comfortable" clearable hide-no-data
                          @update:model-value="onAddStock" />
          <v-table v-if="form.lines.length" density="compact" class="mt-2">
            <thead>
              <tr><th>Item</th><th style="width:120px">Qty</th><th style="width:60px"></th></tr>
            </thead>
            <tbody>
              <tr v-for="(l, i) in form.lines" :key="i">
                <td>{{ l._name }}</td>
                <td><v-text-field v-model.number="l.quantity" type="number" min="1" density="compact" variant="outlined" hide-details /></td>
                <td><v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="form.lines.splice(i, 1)" /></td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-caption text-medium-emphasis text-center py-3">No items added.</div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" :disabled="!canSave" @click="saveTransfer(false)">{{ $t('transfers.saveDraft') }}</v-btn>
          <v-btn color="success" :loading="saving" :disabled="!canSave" @click="saveTransfer(true)">{{ $t('transfers.submitRequest') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="720">
      <v-card v-if="active" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-truck-delivery</v-icon>{{ active.reference }}
          <v-chip class="ml-2" size="small" :color="statusColor(active.status)">{{ statusLabel(active.status) }}</v-chip>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="detailDialog = false" />
        </v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="6"><strong>From:</strong> {{ active.source_branch_name }}</v-col>
            <v-col cols="6"><strong>To:</strong> {{ active.dest_branch_name }}</v-col>
            <v-col cols="6"><strong>Requested by:</strong> {{ active.requested_by_name || '—' }}</v-col>
            <v-col cols="6"><strong>Approved by:</strong> {{ active.approved_by_name || '—' }}</v-col>
            <v-col cols="6"><strong>Shipped:</strong> {{ formatDate(active.shipped_at) || '—' }}</v-col>
            <v-col cols="6"><strong>Received:</strong> {{ formatDate(active.received_at) || '—' }}</v-col>
          </v-row>
          <v-divider class="my-3" />
          <v-table density="compact">
            <thead>
              <tr><th>Item</th><th class="text-right">Sent</th><th class="text-right">Received</th></tr>
            </thead>
            <tbody>
              <tr v-for="l in active.lines" :key="l.id">
                <td>{{ l.stock_name }}</td>
                <td class="text-right">{{ l.quantity }}</td>
                <td class="text-right">{{ l.quantity_received || 0 }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="active.notes" class="mt-3 pa-2 rounded bg-grey-lighten-4">
            <div class="text-caption text-medium-emphasis">{{ $t('common.notes') }}</div>
            <div class="text-body-2">{{ active.notes }}</div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn v-if="active.status === 'draft'" color="primary" @click="submitTransfer(active)">Submit</v-btn>
          <v-btn v-if="active.status === 'requested'" color="success" @click="approve(active)">Approve &amp; Ship</v-btn>
          <v-btn v-if="active.status === 'in_transit'" color="primary" @click="openReceive(active)">Receive</v-btn>
          <v-btn v-if="!['completed', 'cancelled'].includes(active.status)" color="error" variant="text" @click="cancelTransfer(active)">{{ $t('common.cancel') }}</v-btn>
          <v-btn variant="text" @click="detailDialog = false">{{ $t('common.close') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Receive dialog -->
    <v-dialog v-model="receiveDialog" max-width="600">
      <v-card v-if="active" rounded="xl">
        <v-card-title>Receive {{ active.reference }}</v-card-title>
        <v-card-text>
          <p class="text-caption text-medium-emphasis mb-3">Adjust received quantities if any short / damaged.</p>
          <v-table density="compact">
            <thead>
              <tr><th>Item</th><th class="text-right">Sent</th><th>Received</th></tr>
            </thead>
            <tbody>
              <tr v-for="l in receiveLines" :key="l.id">
                <td>{{ l.stock_name }}</td>
                <td class="text-right">{{ l.quantity }}</td>
                <td><v-text-field v-model.number="l.quantity_received" type="number" min="0" density="compact" variant="outlined" hide-details /></td>
              </tr>
            </tbody>
          </v-table>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="receiveDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="success" :loading="saving" @click="confirmReceive">Confirm Receipt</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const transfers = ref([])
const branches = ref([])
const search = ref('')
const statusFilter = ref('all')
const createDialog = ref(false)
const detailDialog = ref(false)
const receiveDialog = ref(false)
const active = ref(null)
const receiveLines = ref([])
const snack = ref({ show: false, color: 'success', text: '' })
const req = [v => !!v || 'Required']

const form = ref({ source_branch: null, dest_branch: null, notes: '', lines: [] })

const statusOptions = [
  { label: 'All', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'Requested', value: 'requested' },
  { label: 'In transit', value: 'in_transit' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]

const headers = [
  { title: 'Reference', key: 'reference', width: 180 },
  { title: 'Route', key: 'route', sortable: false },
  { title: 'Items', key: 'totals', width: 200 },
  { title: 'Status', key: 'status', width: 150 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

const kpis = computed(() => {
  const inT = transfers.value.filter(t => t.status === 'in_transit').length
  const pend = transfers.value.filter(t => t.status === 'requested').length
  const done = transfers.value.filter(t => t.status === 'completed').length
  return [
    { label: 'Total Transfers', value: transfers.value.length, icon: 'mdi-swap-horizontal', color: 'cyan' },
    { label: 'Pending Approval', value: pend, icon: 'mdi-clock-alert', color: 'amber' },
    { label: 'In Transit', value: inT, icon: 'mdi-truck-fast', color: 'blue' },
    { label: 'Completed', value: done, icon: 'mdi-check-all', color: 'green' },
  ]
})

const filtered = computed(() => {
  const s = (search.value || '').toLowerCase()
  return transfers.value.filter(t => {
    if (statusFilter.value !== 'all' && t.status !== statusFilter.value) return false
    if (!s) return true
    return [t.reference, t.source_branch_name, t.dest_branch_name].filter(Boolean)
      .some(v => v.toLowerCase().includes(s))
  })
})

const destBranches = computed(() => branches.value.filter(b => b.id !== form.value.source_branch))
const canSave = computed(() => form.value.source_branch && form.value.dest_branch &&
  form.value.source_branch !== form.value.dest_branch && form.value.lines.length > 0)

// Stock search
const picker = ref(null)
const stockOptions = ref([])
const stockLoading = ref(false)
const stockSearch = ref('')
let stockTimer = null
function onStockSearch(q) {
  stockSearch.value = q || ''
  clearTimeout(stockTimer)
  stockTimer = setTimeout(async () => {
    if (!q || q.length < 1) { stockOptions.value = []; return }
    stockLoading.value = true
    try {
      stockOptions.value = await $api.get('/inventory/stocks/', { params: { search: q, page_size: 20 } })
        .then(r => r.data?.results || r.data || [])
    } catch { stockOptions.value = [] }
    finally { stockLoading.value = false }
  }, 250)
}
function onAddStock(s) {
  if (!s) return
  if (form.value.lines.find(l => l.stock === s.id)) return
  form.value.lines.push({ stock: s.id, _name: s.medication_name, quantity: 1 })
  picker.value = null
  stockOptions.value = []
}

async function load() {
  loading.value = true
  try {
    const [t, b] = await Promise.all([
      $api.get('/inventory/transfers/').then(r => r.data?.results || r.data || []),
      $api.get('/pharmacy-profile/branches/').then(r => r.data?.results || r.data || []).catch(() => []),
    ])
    transfers.value = t
    branches.value = b
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

function openCreate() {
  form.value = { source_branch: null, dest_branch: null, notes: '', lines: [] }
  createDialog.value = true
}

async function saveTransfer(submit) {
  if (!canSave.value) return
  saving.value = true
  try {
    const payload = {
      source_branch: form.value.source_branch,
      dest_branch: form.value.dest_branch,
      notes: form.value.notes,
      lines: form.value.lines.map(l => ({ stock: l.stock, quantity: l.quantity })),
    }
    const created = await $api.post('/inventory/transfers/', payload).then(r => r.data)
    if (submit) await $api.post(`/inventory/transfers/${created.id}/submit/`)
    showSnack(submit ? 'Transfer submitted' : 'Draft saved', 'success')
    createDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.dest_branch?.[0] || 'Failed to save', 'error') }
  finally { saving.value = false }
}

async function openDetail(t) {
  try {
    active.value = await $api.get(`/inventory/transfers/${t.id}/`).then(r => r.data)
    detailDialog.value = true
  } catch { showSnack('Failed to load', 'error') }
}

async function submitTransfer(t) {
  try { await $api.post(`/inventory/transfers/${t.id}/submit/`); showSnack('Submitted', 'success'); detailDialog.value = false; await load() }
  catch { showSnack('Failed', 'error') }
}
async function approve(t) {
  if (!confirm(`Approve ${t.reference}? Stock will be deducted from ${t.source_branch_name} immediately.`)) return
  try { await $api.post(`/inventory/transfers/${t.id}/approve/`); showSnack('Approved & shipped', 'success'); detailDialog.value = false; await load() }
  catch { showSnack('Failed', 'error') }
}
function openReceive(t) {
  active.value = t
  receiveLines.value = (t.lines || []).map(l => ({ id: l.id, stock_name: l.stock_name, quantity: l.quantity, quantity_received: l.quantity }))
  detailDialog.value = false
  receiveDialog.value = true
}
async function confirmReceive() {
  if (!active.value) return
  saving.value = true
  try {
    await $api.post(`/inventory/transfers/${active.value.id}/receive/`, {
      lines: receiveLines.value.map(l => ({ id: l.id, quantity_received: l.quantity_received })),
    })
    showSnack('Transfer received', 'success')
    receiveDialog.value = false
    await load()
  } catch { showSnack('Failed', 'error') }
  finally { saving.value = false }
}
async function cancelTransfer(t) {
  if (!confirm(`Cancel transfer ${t.reference}?`)) return
  try { await $api.post(`/inventory/transfers/${t.id}/cancel/`); showSnack('Cancelled', 'success'); detailDialog.value = false; await load() }
  catch { showSnack('Failed', 'error') }
}

function statusLabel(s) { return ({ draft: 'Draft', requested: 'Requested', approved: 'Approved', in_transit: 'In Transit', completed: 'Completed', cancelled: 'Cancelled' })[s] || s }
function statusColor(s) { return ({ draft: 'grey', requested: 'amber', approved: 'blue', in_transit: 'cyan', completed: 'success', cancelled: 'error' })[s] || 'grey' }
function statusIcon(s) { return ({ draft: 'mdi-pencil', requested: 'mdi-clock', approved: 'mdi-check', in_transit: 'mdi-truck-fast', completed: 'mdi-check-all', cancelled: 'mdi-close' })[s] || 'mdi-circle' }
function formatDate(d) { return d ? new Date(d).toLocaleString() : '' }
function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }

onMounted(load)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

</style>
