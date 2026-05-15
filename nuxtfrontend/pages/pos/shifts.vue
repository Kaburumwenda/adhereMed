<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="green-lighten-5" size="48">
        <v-icon color="green-darken-2" size="28">mdi-cash-register</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">{{ $t('posShifts.title') }}</div>
        <div class="text-body-2 text-medium-emphasis">
          Open / close drawer · Z-Report · Cash variance reconciliation
        </div>
      </div>
      <v-spacer />
      <v-btn v-if="!current" variant="elevated" rounded="lg" color="success"
             prepend-icon="mdi-cash-plus" @click="openShift">{{ $t('posShifts.openShift') }}</v-btn>
      <v-btn v-else variant="elevated" rounded="lg" color="amber-darken-2"
             prepend-icon="mdi-cash-minus" @click="openCloseDialog">{{ $t('posShifts.closeShift') }}</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">{{ $t('common.refresh') }}</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Live shift card -->
    <v-card v-if="current" flat rounded="lg" class="live-shift-card mb-4 pa-4">
      <div class="d-flex align-center mb-3">
        <v-icon color="success" class="mr-2">mdi-circle-medium</v-icon>
        <div class="text-subtitle-1 font-weight-bold">Live Shift · {{ current.reference }}</div>
        <v-spacer />
        <v-chip color="success" variant="flat" size="small">OPEN</v-chip>
      </div>
      <v-row dense>
        <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Opened</div>
          <div class="font-weight-medium">{{ formatDate(current.opened_at) }}</div></v-col>
        <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Branch</div>
          <div class="font-weight-medium">{{ current.branch_name || '—' }}</div></v-col>
        <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">{{ $t('posShifts.openingFloat') }}</div>
          <div class="font-weight-medium">KSh {{ Number(current.opening_float).toLocaleString() }}</div></v-col>
        <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">{{ $t('posShifts.cashier') }}</div>
          <div class="font-weight-medium">{{ current.cashier_name }}</div></v-col>
      </v-row>
      <v-divider class="my-3" />
      <div v-if="liveZ" class="text-body-2">
        <div class="d-flex justify-space-between mb-1"><span>{{ $t('posShifts.transactions') }}</span><strong>{{ liveZ.transactions }}</strong></div>
        <div class="d-flex justify-space-between mb-1"><span>Gross revenue</span><strong>KSh {{ Number(liveZ.gross_revenue || 0).toLocaleString() }}</strong></div>
        <div class="d-flex justify-space-between mb-1"><span>Cash sales</span><strong>KSh {{ Number(liveZ.cash_sales || 0).toLocaleString() }}</strong></div>
        <div class="d-flex justify-space-between"><span>Expected cash</span><strong>KSh {{ Number(liveZ.expected_cash || 0).toLocaleString() }}</strong></div>
      </div>
    </v-card>

    <!-- Shifts table -->
    <v-card flat rounded="lg" class="shifts-table-card">
      <div class="d-flex align-center pa-3">
        <div class="text-subtitle-2 font-weight-bold">All shifts</div>
        <v-spacer />
        <v-text-field v-model="shiftSearch" prepend-inner-icon="mdi-magnify"
                      placeholder="Search shifts…" variant="outlined" density="compact"
                      hide-details clearable style="max-width:280px" />
        <v-btn-toggle v-model="shiftStatusFilter" mandatory density="compact" rounded="lg"
                      color="primary" class="ml-2">
          <v-btn value="all" size="small">All</v-btn>
          <v-btn value="open" size="small">Open</v-btn>
          <v-btn value="closed" size="small">Closed</v-btn>
        </v-btn-toggle>
      </div>
      <v-data-table :headers="headers" :items="filteredShifts" :loading="loading"
                    :items-per-page="15" density="comfortable" item-value="id">
        <template #item.reference="{ item }">
          <div class="font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatDate(item.opened_at) }}</div>
        </template>
        <template #item.cashier_name="{ item }">{{ item.cashier_name }}</template>
        <template #item.duration="{ item }">{{ duration(item) }}</template>
        <template #item.opening_float="{ item }">KSh {{ Number(item.opening_float).toLocaleString() }}</template>
        <template #item.expected_cash="{ item }">{{ item.expected_cash != null ? 'KSh ' + Number(item.expected_cash).toLocaleString() : '—' }}</template>
        <template #item.cash_variance="{ item }">
          <span v-if="item.cash_variance != null" :class="varianceColor(item.cash_variance)">
            {{ item.cash_variance > 0 ? '+' : '' }}KSh {{ Number(item.cash_variance).toLocaleString() }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.status="{ item }">
          <v-chip size="x-small" variant="tonal" :color="item.status === 'open' ? 'success' : 'grey'">
            <v-icon size="12" start>{{ item.status === 'open' ? 'mdi-circle-medium' : 'mdi-check' }}</v-icon>
            {{ item.status === 'open' ? 'Open' : 'Closed' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-receipt-text" variant="text" size="small" @click="viewZ(item)" />
        </template>
      </v-data-table>
    </v-card>

    <!-- Open shift dialog -->
    <v-dialog v-model="openDialog" max-width="480" persistent>
      <v-card rounded="lg">
        <v-card-title>
          <v-icon class="mr-2" color="success">mdi-cash-plus</v-icon>Open Shift
        </v-card-title>
        <v-card-text>
          <v-text-field v-model.number="openForm.opening_float" type="number" min="0"
                        label="Opening cash float (KSh) *" prefix="KSh"
                        variant="outlined" density="comfortable" />
          <v-select v-model="openForm.branch" :items="branches" item-title="name" item-value="id"
                    label="Branch" variant="outlined" density="comfortable" clearable />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="openDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="success" :loading="saving" @click="confirmOpen">{{ $t('posShifts.openShift') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Close shift dialog -->
    <v-dialog v-model="closeDialog" max-width="540" persistent>
      <v-card rounded="lg">
        <v-card-title><v-icon class="mr-2" color="warning">mdi-cash-minus</v-icon>{{ $t('posShifts.closeShift') }}</v-card-title>
        <v-card-text>
          <v-alert v-if="liveZ" type="info" variant="tonal" density="compact" class="mb-3">
            Expected cash in drawer: <strong>KSh {{ Number(liveZ.expected_cash).toLocaleString() }}</strong>
            <div class="text-caption">({{ liveZ.transactions }} txns · KSh {{ Number(liveZ.cash_sales).toLocaleString() }} cash sales + KSh {{ Number(liveZ.opening_float).toLocaleString() }} float)</div>
          </v-alert>
          <v-text-field v-model.number="closeForm.closing_actual_cash" type="number" min="0"
                        label="Cash counted in drawer *" prefix="KSh"
                        variant="outlined" density="comfortable" />
          <v-textarea v-model="closeForm.closing_notes" label="Notes (variance explanation, etc.)"
                      rows="2" auto-grow variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="closeDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="warning" :loading="saving" @click="confirmClose">Close &amp; Print Z-Report</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Z-Report dialog -->
    <v-dialog v-model="zDialog" max-width="600">
      <v-card v-if="zShift" rounded="lg">
        <v-card-title>
          <v-icon class="mr-2">mdi-receipt-text</v-icon>Z-Report · {{ zShift.reference }}
        </v-card-title>
        <v-card-text id="z-report-print">
          <div class="text-center mb-3">
            <div class="text-subtitle-2 font-weight-bold">{{ $t('posShifts.zReport') }}</div>
            <div class="text-caption">{{ zShift.reference }} · {{ zShift.cashier_name }}</div>
            <div class="text-caption">{{ formatDate(zShift.opened_at) }} → {{ zShift.closed_at ? formatDate(zShift.closed_at) : 'OPEN' }}</div>
          </div>
          <v-divider />
          <div class="py-2">
            <div class="d-flex justify-space-between"><span>Opening float</span><strong>KSh {{ fmt(zShift.z_report?.opening_float) }}</strong></div>
            <div class="d-flex justify-space-between"><span>{{ $t('posShifts.transactions') }}</span><strong>{{ zShift.z_report?.transactions || 0 }}</strong></div>
            <div class="d-flex justify-space-between"><span>Gross revenue</span><strong>KSh {{ fmt(zShift.z_report?.gross_revenue) }}</strong></div>
            <div class="d-flex justify-space-between"><span>Discounts</span><strong>KSh {{ fmt(zShift.z_report?.discount) }}</strong></div>
            <div class="d-flex justify-space-between"><span>{{ $t('common.tax') }}</span><strong>KSh {{ fmt(zShift.z_report?.tax) }}</strong></div>
          </div>
          <v-divider />
          <div class="py-2">
            <div class="text-caption font-weight-bold mb-1">By payment method</div>
            <div v-for="r in (zShift.z_report?.by_payment_method || [])" :key="r.method"
                 class="d-flex justify-space-between">
              <span class="text-capitalize">{{ r.method }} ({{ r.count }})</span>
              <strong>KSh {{ fmt(r.amount) }}</strong>
            </div>
          </div>
          <v-divider />
          <div class="py-2">
            <div class="d-flex justify-space-between"><span>Expected cash</span><strong>KSh {{ fmt(zShift.z_report?.expected_cash) }}</strong></div>
            <div class="d-flex justify-space-between"><span>Actual cash</span><strong>KSh {{ fmt(zShift.z_report?.actual_cash) }}</strong></div>
            <div class="d-flex justify-space-between" :class="varianceColor(zShift.z_report?.variance || 0)">
              <span>{{ $t('posShifts.variance') }}</span>
              <strong>{{ (zShift.z_report?.variance || 0) > 0 ? '+' : '' }}KSh {{ fmt(zShift.z_report?.variance) }}</strong>
            </div>
          </div>
          <v-divider />
          <div v-if="zShift.closing_notes" class="pt-2 text-caption">
            <strong>Notes:</strong> {{ zShift.closing_notes }}
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="zDialog = false">{{ $t('common.close') }}</v-btn>
          <v-btn color="primary" prepend-icon="mdi-printer" @click="printZ">{{ $t('common.print') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted, onUnmounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const shifts = ref([])
const branches = ref([])
const current = ref(null)
const liveZ = ref(null)
const openDialog = ref(false)
const closeDialog = ref(false)
const zDialog = ref(false)
const zShift = ref(null)
const openForm = ref({ opening_float: 0, branch: null })
const closeForm = ref({ closing_actual_cash: 0, closing_notes: '' })
const snack = ref({ show: false, color: 'success', text: '' })
const shiftSearch = ref('')
const shiftStatusFilter = ref('all')

const headers = [
  { title: 'Reference', key: 'reference', width: 170 },
  { title: 'Cashier', key: 'cashier_name' },
  { title: 'Duration', key: 'duration', width: 120 },
  { title: 'Float', key: 'opening_float', width: 120, align: 'end' },
  { title: 'Expected', key: 'expected_cash', width: 130, align: 'end' },
  { title: 'Variance', key: 'cash_variance', width: 130, align: 'end' },
  { title: 'Status', key: 'status', width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

const kpis = computed(() => {
  const closed = shifts.value.filter(s => s.status === 'closed')
  const totalRev = closed.reduce((s, x) => s + Number(x.z_report?.gross_revenue || 0), 0)
  const totalVar = closed.reduce((s, x) => s + Number(x.cash_variance || 0), 0)
  return [
    { label: 'Total Shifts', value: shifts.value.length, icon: 'mdi-cash-register', color: 'green' },
    { label: 'Open Now', value: shifts.value.filter(s => s.status === 'open').length, icon: 'mdi-cash-multiple', color: 'amber' },
    { label: 'Total Revenue', value: 'KSh ' + Math.round(totalRev).toLocaleString(), icon: 'mdi-cash-fast', color: 'blue' },
    { label: 'Net Variance', value: (totalVar >= 0 ? '+' : '') + 'KSh ' + Math.round(totalVar).toLocaleString(), icon: 'mdi-scale-balance', color: totalVar >= 0 ? 'success' : 'red' },
  ]
})

const filteredShifts = computed(() => {
  let arr = shifts.value
  if (shiftStatusFilter.value !== 'all') {
    arr = arr.filter(s => s.status === shiftStatusFilter.value)
  }
  if (shiftSearch.value) {
    const q = shiftSearch.value.toLowerCase()
    arr = arr.filter(s =>
      (s.reference || '').toLowerCase().includes(q) ||
      (s.cashier_name || '').toLowerCase().includes(q) ||
      (s.branch_name || '').toLowerCase().includes(q)
    )
  }
  return arr
})

let pollTimer = null

async function load() {
  loading.value = true
  try {
    const [list, cur, br] = await Promise.all([
      $api.get('/pos/shifts/').then(r => r.data?.results || r.data || []),
      $api.get('/pos/shifts/current/').then(r => r.data).catch(() => null),
      $api.get('/pharmacy-profile/branches/').then(r => r.data?.results || r.data || []).catch(() => []),
    ])
    shifts.value = list
    current.value = cur
    branches.value = br
    if (cur) await loadLiveZ(cur.id)
    else liveZ.value = null
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

async function loadLiveZ(id) {
  try {
    liveZ.value = await $api.get(`/pos/shifts/${id}/z-report/`).then(r => r.data)
  } catch { liveZ.value = null }
}

function openShift() { openForm.value = { opening_float: 0, branch: null }; openDialog.value = true }

async function confirmOpen() {
  saving.value = true
  try {
    await $api.post('/pos/shifts/', { opening_float: openForm.value.opening_float, branch: openForm.value.branch })
    showSnack('Shift opened', 'success')
    openDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
  finally { saving.value = false }
}

async function openCloseDialog() {
  if (!current.value) return
  await loadLiveZ(current.value.id)
  closeForm.value = { closing_actual_cash: liveZ.value?.expected_cash || 0, closing_notes: '' }
  closeDialog.value = true
}

async function confirmClose() {
  if (!current.value) return
  saving.value = true
  try {
    const closed = await $api.post(`/pos/shifts/${current.value.id}/close/`, closeForm.value).then(r => r.data)
    showSnack('Shift closed', 'success')
    closeDialog.value = false
    zShift.value = closed
    zDialog.value = true
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed to close', 'error') }
  finally { saving.value = false }
}

function viewZ(s) { zShift.value = s; zDialog.value = true }

function printZ() {
  const html = document.getElementById('z-report-print')?.innerHTML || ''
  const w = window.open('', '_blank', 'width=400,height=600')
  if (!w) return
  w.document.write(`<html><head><title>Z-Report ${zShift.value?.reference || ''}</title>
    <style>body{font-family:monospace;padding:10px;font-size:12px;}div{margin:2px 0;}strong{font-weight:bold;}.d-flex{display:flex;justify-content:space-between;}</style>
    </head><body>${html}</body></html>`)
  w.document.close(); w.focus(); w.print()
}

function duration(s) {
  if (!s.opened_at) return '—'
  const start = new Date(s.opened_at)
  const end = s.closed_at ? new Date(s.closed_at) : new Date()
  const ms = end - start
  const h = Math.floor(ms / 3600000)
  const m = Math.floor((ms % 3600000) / 60000)
  return `${h}h ${m}m`
}
function varianceColor(v) { return !v ? 'text-medium-emphasis' : v > 0 ? 'text-success' : 'text-error' }
function fmt(v) { return Number(v || 0).toLocaleString() }
function formatDate(d) { return d ? new Date(d).toLocaleString() : '—' }
function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }

onMounted(() => {
  load()
  pollTimer = setInterval(() => { if (current.value) loadLiveZ(current.value.id) }, 30000)
})
onUnmounted(() => { if (pollTimer) clearInterval(pollTimer) })
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.live-shift-card {
  border: 1px solid rgba(var(--v-theme-success), 0.25);
  background: rgba(var(--v-theme-success), 0.03);
}
.shifts-table-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
</style>
