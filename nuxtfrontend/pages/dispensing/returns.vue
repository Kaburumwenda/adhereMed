<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="red-darken-3" size="32">mdi-package-variant-closed-remove</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">{{ $t('dispenseReturns.title') }}</div>
              <div class="text-body-2" style="opacity:0.9">
                Process refunds & restock returned medications.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-red-darken-3"
                 prepend-icon="mdi-plus" @click="openCreate">{{ $t('dispenseReturns.newReturn') }}</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">{{ $t('common.refresh') }}</v-btn>
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

    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by reference or receipt…" density="comfortable"
                        hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="reasonFilter" :items="reasonOptions" item-title="label" item-value="value"
                    label="Reason" variant="outlined" density="comfortable" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" items-per-page="15">
        <template #item.reference="{ item }">
          <div class="font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</div>
        </template>
        <template #item.original="{ item }">
          <div>{{ item.original_receipt }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.original_patient }}</div>
        </template>
        <template #item.refund_amount="{ item }">
          <span class="font-weight-bold text-red">KSh {{ Number(item.refund_amount).toLocaleString() }}</span>
        </template>
        <template #item.reason="{ item }">
          <v-chip size="small" variant="tonal" :color="reasonColor(item.reason)">{{ reasonLabel(item.reason) }}</v-chip>
        </template>
        <template #item.restock="{ item }">
          <v-icon :color="item.restock ? 'success' : 'grey'">
            {{ item.restock ? 'mdi-check-circle' : 'mdi-circle-outline' }}
          </v-icon>
        </template>
        <template #no-data>
          <div class="text-center pa-6">
            <v-icon size="48" color="grey-lighten-1">mdi-package-variant-remove</v-icon>
            <div class="text-body-2 mt-2">No returns recorded yet.</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create dialog -->
    <v-dialog v-model="createDialog" max-width="800" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-keyboard-return</v-icon>New Dispense Return
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="createDialog = false" />
        </v-card-title>
        <v-card-text>
          <v-autocomplete v-model="form.original" :items="receiptOptions" :loading="receiptLoading"
                          :search="receiptSearch" @update:search="onReceiptSearch"
                          item-title="receipt_number" item-value="id" return-object
                          label="Original receipt *" prepend-inner-icon="mdi-receipt-text"
                          variant="outlined" density="comfortable" hide-no-data
                          @update:model-value="onPickReceipt" />

          <div v-if="originalDetail" class="mt-2 pa-3 bg-grey-lighten-4 rounded">
            <div class="text-caption text-medium-emphasis">Patient</div>
            <div class="text-body-2 font-weight-medium">{{ originalDetail.patient_name }}</div>
            <div class="text-caption text-medium-emphasis mt-1">Total paid</div>
            <div class="text-body-2">KSh {{ Number(originalDetail.total_amount).toLocaleString() }}</div>
          </div>

          <div v-if="form.items_returned.length" class="mt-3">
            <div class="text-subtitle-2 font-weight-bold mb-2">Items to return</div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>Item</th>
                  <th class="text-right">Dispensed</th>
                  <th style="width:120px">Return qty</th>
                  <th class="text-right">Unit price</th>
                  <th class="text-right">{{ $t('dispenseReturns.refund') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(it, i) in form.items_returned" :key="i">
                  <td>{{ it.medication_name }}</td>
                  <td class="text-right">{{ it.dispensed_qty }}</td>
                  <td>
                    <v-text-field v-model.number="it.quantity" type="number" min="0"
                                  :max="it.dispensed_qty" density="compact" variant="outlined"
                                  hide-details @update:model-value="recalc" />
                  </td>
                  <td class="text-right">{{ Number(it.unit_price || 0).toLocaleString() }}</td>
                  <td class="text-right">{{ ((it.quantity || 0) * (it.unit_price || 0)).toLocaleString() }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>

          <v-row class="mt-3" dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.reason" :items="reasonOptions.filter(r => r.value !== 'all')"
                        item-title="label" item-value="value"
                        label="Reason *" variant="outlined" density="comfortable" :rules="req" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.refund_method" :items="refundMethods"
                        label="Refund method" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.refund_amount" type="number" min="0"
                            label="Refund amount (KSh) *" prefix="KSh"
                            variant="outlined" density="comfortable" :rules="req" />
            </v-col>
            <v-col cols="12" md="6" class="d-flex align-center">
              <v-switch v-model="form.restock" color="success" hide-details density="comfortable"
                        label="Restock returned items" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" :disabled="!canSave" @click="save">{{ $t('dispenseReturns.processReturn') }}</v-btn>
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
const items = ref([])
const stats = ref({})
const search = ref('')
const reasonFilter = ref('all')
const createDialog = ref(false)
const snack = ref({ show: false, color: 'success', text: '' })
const req = [v => v !== null && v !== undefined && v !== '' || 'Required']

const reasonOptions = [
  { label: 'All', value: 'all' },
  { label: 'Damaged', value: 'damaged' },
  { label: 'Wrong item', value: 'wrong_item' },
  { label: 'Patient request', value: 'patient_request' },
  { label: 'Expired', value: 'expired' },
  { label: 'Adverse reaction', value: 'adverse_reaction' },
  { label: 'Other', value: 'other' },
]
const refundMethods = ['Cash', 'Mobile Money', 'Bank Transfer', 'Store Credit', 'Card']

const headers = [
  { title: 'Reference', key: 'reference', width: 180 },
  { title: 'Original', key: 'original' },
  { title: 'Reason', key: 'reason', width: 150 },
  { title: 'Refund', key: 'refund_amount', width: 140, align: 'end' },
  { title: 'Restocked', key: 'restock', width: 100, align: 'center' },
  { title: 'Processed by', key: 'processed_by_name', width: 160 },
]

const form = ref(blankForm())
function blankForm() {
  return { original: null, items_returned: [], reason: 'patient_request', refund_amount: 0, refund_method: 'Cash', restock: true, notes: '' }
}

const originalDetail = ref(null)

const kpis = computed(() => [
  { label: 'Total Returns', value: stats.value.total_returns || 0, icon: 'mdi-keyboard-return', color: 'red' },
  { label: 'Total Refunded', value: 'KSh ' + Math.round(stats.value.total_refunded || 0).toLocaleString(), icon: 'mdi-cash-refund', color: 'orange' },
  { label: 'Restocked', value: items.value.filter(i => i.restock).length, icon: 'mdi-package-variant-plus', color: 'green' },
  { label: 'Top Reason', value: topReason.value, icon: 'mdi-help-circle', color: 'purple' },
])

const topReason = computed(() => {
  const counts = {}
  items.value.forEach(i => { counts[i.reason] = (counts[i.reason] || 0) + 1 })
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]
  return top ? reasonLabel(top[0]) : '—'
})

const filtered = computed(() => {
  const s = (search.value || '').toLowerCase()
  return items.value.filter(it => {
    if (reasonFilter.value !== 'all' && it.reason !== reasonFilter.value) return false
    if (!s) return true
    return [it.reference, it.original_receipt, it.original_patient].filter(Boolean)
      .some(v => v.toLowerCase().includes(s))
  })
})

const canSave = computed(() => form.value.original && form.value.reason &&
  form.value.items_returned.some(i => i.quantity > 0))

async function load() {
  loading.value = true
  try {
    const [list, st] = await Promise.all([
      $api.get('/dispensing/returns/').then(r => r.data?.results || r.data || []),
      $api.get('/dispensing/returns/stats/').then(r => r.data).catch(() => ({})),
    ])
    items.value = list
    stats.value = st
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

function openCreate() {
  form.value = blankForm()
  originalDetail.value = null
  receiptOptions.value = []
  createDialog.value = true
}

// Receipt search
const receiptOptions = ref([])
const receiptLoading = ref(false)
const receiptSearch = ref('')
let receiptTimer = null
function onReceiptSearch(q) {
  receiptSearch.value = q || ''
  clearTimeout(receiptTimer)
  receiptTimer = setTimeout(async () => {
    if (!q || q.length < 2) { receiptOptions.value = []; return }
    receiptLoading.value = true
    try {
      receiptOptions.value = await $api.get('/dispensing/', { params: { search: q, page_size: 20 } })
        .then(r => r.data?.results || r.data || [])
    } catch { receiptOptions.value = [] }
    finally { receiptLoading.value = false }
  }, 250)
}
async function onPickReceipt(r) {
  if (!r) return
  try {
    const det = await $api.get(`/dispensing/${r.id}/`).then(x => x.data)
    originalDetail.value = det
    form.value.items_returned = (det.items_dispensed || []).map(it => ({
      medication_id: it.medication_id || it.id,
      medication_name: it.medication_name || it.name,
      dispensed_qty: it.quantity_dispensed || it.quantity || 0,
      quantity: 0,
      unit_price: it.unit_price || 0,
    }))
    recalc()
  } catch { showSnack('Failed to load receipt', 'error') }
}

function recalc() {
  form.value.refund_amount = form.value.items_returned.reduce(
    (s, i) => s + (Number(i.quantity) || 0) * (Number(i.unit_price) || 0), 0)
}

async function save() {
  if (!canSave.value) return
  saving.value = true
  try {
    const payload = {
      original: form.value.original.id || form.value.original,
      items_returned: form.value.items_returned.filter(i => i.quantity > 0),
      reason: form.value.reason,
      refund_amount: form.value.refund_amount,
      refund_method: form.value.refund_method,
      restock: form.value.restock,
      notes: form.value.notes,
    }
    await $api.post('/dispensing/returns/', payload)
    showSnack('Return processed', 'success')
    createDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
  finally { saving.value = false }
}

function reasonLabel(r) { return ({ damaged: 'Damaged', wrong_item: 'Wrong Item', patient_request: 'Patient Request', expired: 'Expired', adverse_reaction: 'Adverse Reaction', other: 'Other' })[r] || r }
function reasonColor(r) { return ({ damaged: 'red', wrong_item: 'orange', patient_request: 'blue', expired: 'amber', adverse_reaction: 'purple', other: 'grey' })[r] || 'grey' }
function formatDate(d) { return d ? new Date(d).toLocaleString() : '' }
function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }

onMounted(load)
</script>

<style scoped>
.hero { background: linear-gradient(135deg, #7f1d1d 0%, #dc2626 50%, #f87171 100%); }
.kpi { background: rgba(255, 255, 255, 0.1) !important; backdrop-filter: blur(8px); border: 1px solid rgba(255, 255, 255, 0.15); }
.kpi :deep(.text-h6) { color: #fff; }
.kpi :deep(.text-medium-emphasis) { color: rgba(255, 255, 255, 0.85) !important; }
</style>
