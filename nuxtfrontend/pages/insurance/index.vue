<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="cyan-lighten-5" size="48" class="mr-3">
          <v-icon color="cyan-darken-2" size="28">mdi-shield-account</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">{{ $t('insuranceClaims.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Capture, submit, approve &amp; settle insurance claims</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" @click="openCreate">{{ $t('insuranceClaims.newClaim') }}</v-btn>
      <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-domain"
                 to="/insurance/providers">Providers</v-btn>
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

    <v-card flat rounded="xl" border class="mb-3">
      <v-card-text class="d-flex flex-wrap" style="gap:12px">
        <v-text-field v-model="search" label="Search ref / member" prepend-inner-icon="mdi-magnify"
                      variant="outlined" density="comfortable" hide-details style="min-width:240px"
                      @update:model-value="reload" />
        <v-select v-model="statusFilter" :items="statusOptions" label="Status"
                  variant="outlined" density="comfortable" hide-details clearable
                  style="min-width:180px" @update:model-value="reload" />
        <v-select v-model="providerFilter" :items="providers" label="Provider"
                  item-title="name" item-value="id" variant="outlined" density="comfortable"
                  hide-details clearable style="min-width:200px" @update:model-value="reload" />
      </v-card-text>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="items" :loading="loading" items-per-page="15">
        <template #item.reference="{ item }">
          <div class="font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ new Date(item.created_at).toLocaleDateString() }}</div>
        </template>
        <template #item.member="{ item }">
          <div>{{ item.member_name }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.member_number }}</div>
        </template>
        <template #item.provider_name="{ item }">{{ item.provider_name || '—' }}</template>
        <template #item.claim_amount="{ item }">KSh {{ Number(item.claim_amount).toLocaleString() }}</template>
        <template #item.approved_amount="{ item }">
          <span :class="Number(item.approved_amount) < Number(item.claim_amount) ? 'text-warning' : ''">
            KSh {{ Number(item.approved_amount).toLocaleString() }}
          </span>
        </template>
        <template #item.outstanding="{ item }">
          <strong :class="Number(item.outstanding) > 0 ? 'text-error' : 'text-success'">
            KSh {{ Number(item.outstanding).toLocaleString() }}
          </strong>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="flat" :color="statusColor(item.status)" class="text-capitalize">
            {{ (item.status || '').replace('_', ' ') }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-menu>
            <template #activator="{ props }">
              <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
            </template>
            <v-list density="compact">
              <v-list-item prepend-icon="mdi-eye" @click="openView(item)">View</v-list-item>
              <v-list-item v-if="item.status === 'draft'" prepend-icon="mdi-send"
                           @click="doAction(item, 'submit')">Submit</v-list-item>
              <v-list-item v-if="['submitted','under_review'].includes(item.status)"
                           prepend-icon="mdi-check" @click="openApprove(item)">Approve</v-list-item>
              <v-list-item v-if="['submitted','under_review','approved','partially_approved'].includes(item.status)"
                           prepend-icon="mdi-close" @click="openReject(item)">Reject</v-list-item>
              <v-list-item v-if="['approved','partially_approved'].includes(item.status)"
                           prepend-icon="mdi-cash" @click="openPay(item)">Record Payment</v-list-item>
            </v-list>
          </v-menu>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create/Edit Claim -->
    <v-dialog v-model="formDialog" max-width="780" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title>
          <v-icon class="mr-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          {{ form.id ? 'Edit' : 'New' }} Insurance Claim
        </v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.provider" :items="providers" item-title="name" item-value="id"
                        label="Provider *" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.member_name" label="Member name *"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.member_number" label="Member number *"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.scheme_name" label="Scheme"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.invoice_number" label="Invoice / receipt #"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.claim_amount" type="number" min="0" prefix="KSh"
                            label="Claim amount *" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.diagnosis" label="Diagnosis"
                          rows="2" auto-grow variant="outlined" density="comfortable" />
            </v-col>

            <v-col cols="12">
              <div class="d-flex align-center mb-2">
                <strong>Line items</strong>
                <v-spacer />
                <v-btn size="small" variant="text" prepend-icon="mdi-plus" @click="addItem">Add line</v-btn>
              </div>
              <v-card v-for="(li, i) in form.items" :key="i" flat border rounded="lg" class="pa-2 mb-2">
                <v-row dense>
                  <v-col cols="12" md="5">
                    <v-text-field v-model="li.description" label="Description"
                                  density="compact" variant="outlined" hide-details />
                  </v-col>
                  <v-col cols="4" md="2">
                    <v-text-field v-model.number="li.quantity" type="number" min="1" label="Qty"
                                  density="compact" variant="outlined" hide-details
                                  @update:model-value="recalcItem(li)" />
                  </v-col>
                  <v-col cols="4" md="2">
                    <v-text-field v-model.number="li.unit_price" type="number" min="0" label="Unit"
                                  density="compact" variant="outlined" hide-details
                                  @update:model-value="recalcItem(li)" />
                  </v-col>
                  <v-col cols="4" md="2">
                    <v-text-field v-model.number="li.total" type="number" min="0" label="Total"
                                  density="compact" variant="outlined" hide-details readonly />
                  </v-col>
                  <v-col cols="12" md="1" class="text-right">
                    <v-btn icon="mdi-close" variant="text" size="small" @click="form.items.splice(i,1)" />
                  </v-col>
                </v-row>
              </v-card>
              <div class="text-caption text-medium-emphasis text-right">
                Items total: KSh {{ Number(itemsTotal).toLocaleString() }}
              </div>
            </v-col>

            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">{{ $t('common.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Approve dialog -->
    <v-dialog v-model="approveDialog" max-width="500" persistent>
      <v-card rounded="xl">
        <v-card-title><v-icon color="success" class="mr-2">mdi-check</v-icon>Approve Claim</v-card-title>
        <v-card-text>
          <div class="mb-2">Claim total: <strong>KSh {{ Number(actionTarget?.claim_amount || 0).toLocaleString() }}</strong></div>
          <v-text-field v-model.number="approveAmount" type="number" min="0" prefix="KSh"
                        label="Approved amount *" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="approveDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="success" :loading="saving" @click="confirmApprove">Approve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Reject dialog -->
    <v-dialog v-model="rejectDialog" max-width="500" persistent>
      <v-card rounded="xl">
        <v-card-title><v-icon color="error" class="mr-2">mdi-close</v-icon>Reject Claim</v-card-title>
        <v-card-text>
          <v-textarea v-model="rejectReason" label="Reason *" rows="3" auto-grow
                      variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="rejectDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="error" :loading="saving" @click="confirmReject">Reject</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Payment dialog -->
    <v-dialog v-model="payDialog" max-width="500" persistent>
      <v-card rounded="xl">
        <v-card-title><v-icon color="primary" class="mr-2">mdi-cash</v-icon>Record Payment</v-card-title>
        <v-card-text>
          <div class="mb-2">Outstanding: <strong>KSh {{ Number(actionTarget?.outstanding || 0).toLocaleString() }}</strong></div>
          <v-text-field v-model.number="payAmount" type="number" min="0" prefix="KSh"
                        label="Payment amount *" variant="outlined" density="comfortable" />
          <v-text-field v-model="payRef" label="Payment reference / method"
                        variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="confirmPay">Record</v-btn>
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
const providers = ref([])
const stats = ref(null)
const search = ref('')
const statusFilter = ref(null)
const providerFilter = ref(null)
const formDialog = ref(false)
const approveDialog = ref(false)
const rejectDialog = ref(false)
const payDialog = ref(false)
const actionTarget = ref(null)
const form = ref({})
const approveAmount = ref(0)
const rejectReason = ref('')
const payAmount = ref(0)
const payRef = ref('')
const snack = ref({ show: false, color: 'success', text: '' })

const statusOptions = [
  { title: 'Draft', value: 'draft' },
  { title: 'Submitted', value: 'submitted' },
  { title: 'Under Review', value: 'under_review' },
  { title: 'Approved', value: 'approved' },
  { title: 'Partially Approved', value: 'partially_approved' },
  { title: 'Rejected', value: 'rejected' },
  { title: 'Paid', value: 'paid' },
]

const headers = [
  { title: 'Reference', key: 'reference', width: 160 },
  { title: 'Member', key: 'member' },
  { title: 'Provider', key: 'provider_name' },
  { title: 'Claim', key: 'claim_amount', align: 'end', width: 130 },
  { title: 'Approved', key: 'approved_amount', align: 'end', width: 130 },
  { title: 'Outstanding', key: 'outstanding', align: 'end', width: 140 },
  { title: 'Status', key: 'status', width: 150 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]

const itemsTotal = computed(() =>
  (form.value?.items || []).reduce((s, l) => s + Number(l.total || 0), 0)
)

const submittedCount = computed(() =>
  (stats.value?.by_status || []).find(s => s.status === 'submitted')?.count || 0
)
const kpis = computed(() => {
  const t = stats.value?.totals || {}
  return [
    { label: 'Total Claims', value: t.count || 0, icon: 'mdi-file-document', color: 'cyan' },
    { label: 'Submitted', value: submittedCount.value, icon: 'mdi-send', color: 'blue' },
    { label: 'Approved Value', value: 'KSh ' + Math.round(t.approved || 0).toLocaleString(), icon: 'mdi-check-circle', color: 'success' },
    { label: 'Outstanding', value: 'KSh ' + Math.round(t.outstanding || 0).toLocaleString(), icon: 'mdi-cash-clock', color: 'orange' },
  ]
})

function statusColor(s) {
  return ({
    draft: 'grey', submitted: 'blue', under_review: 'amber',
    approved: 'success', partially_approved: 'teal', rejected: 'red', paid: 'green-darken-2',
  })[s] || 'grey'
}

function recalcItem(li) {
  li.total = Number(li.quantity || 0) * Number(li.unit_price || 0)
}
function addItem() { form.value.items.push({ description: '', quantity: 1, unit_price: 0, total: 0 }) }

async function load() {
  loading.value = true
  try {
    const [provs, st] = await Promise.all([
      $api.get('/insurance/providers/').then(r => r.data?.results || r.data || []),
      $api.get('/insurance/claims/stats/').then(r => r.data).catch(() => null),
    ])
    providers.value = provs
    stats.value = st
    await reload()
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

async function reload() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (search.value) params.set('search', search.value)
    if (statusFilter.value) params.set('status', statusFilter.value)
    if (providerFilter.value) params.set('provider', providerFilter.value)
    const r = await $api.get(`/insurance/claims/?${params.toString()}`)
    items.value = r.data?.results || r.data || []
  } catch { showSnack('Failed to load claims', 'error') }
  finally { loading.value = false }
}

function openCreate() {
  form.value = {
    provider: null, member_name: '', member_number: '', scheme_name: '',
    invoice_number: '', diagnosis: '', notes: '', items: [], claim_amount: 0,
  }
  formDialog.value = true
}
function openView(item) { form.value = { ...item, items: item.items || [] }; formDialog.value = true }

async function save() {
  saving.value = true
  try {
    const payload = { ...form.value }
    if (!payload.claim_amount && itemsTotal.value) payload.claim_amount = itemsTotal.value
    if (form.value.id) await $api.patch(`/insurance/claims/${form.value.id}/`, payload)
    else await $api.post('/insurance/claims/', payload)
    showSnack('Saved', 'success')
    formDialog.value = false
    await load()
  } catch (e) { showSnack(JSON.stringify(e?.response?.data || 'Failed'), 'error') }
  finally { saving.value = false }
}

async function doAction(item, action) {
  try {
    await $api.post(`/insurance/claims/${item.id}/${action}/`)
    showSnack('Done', 'success'); await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
}

function openApprove(item) { actionTarget.value = item; approveAmount.value = item.claim_amount; approveDialog.value = true }
async function confirmApprove() {
  saving.value = true
  try {
    await $api.post(`/insurance/claims/${actionTarget.value.id}/approve/`, { approved_amount: approveAmount.value })
    approveDialog.value = false; showSnack('Approved'); await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
  finally { saving.value = false }
}

function openReject(item) { actionTarget.value = item; rejectReason.value = ''; rejectDialog.value = true }
async function confirmReject() {
  saving.value = true
  try {
    await $api.post(`/insurance/claims/${actionTarget.value.id}/reject/`, { reason: rejectReason.value })
    rejectDialog.value = false; showSnack('Rejected'); await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
  finally { saving.value = false }
}

function openPay(item) {
  actionTarget.value = item; payAmount.value = item.outstanding || 0; payRef.value = ''; payDialog.value = true
}
async function confirmPay() {
  saving.value = true
  try {
    await $api.post(`/insurance/claims/${actionTarget.value.id}/record-payment/`,
                    { amount: payAmount.value, reference: payRef.value })
    payDialog.value = false; showSnack('Payment recorded'); await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
  finally { saving.value = false }
}

function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
onMounted(load)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

</style>
