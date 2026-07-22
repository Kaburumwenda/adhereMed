<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Usage Billing"
      icon="mdi-cash-multiple"
      subtitle="Per-tenant API request metering & monthly bills"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-ticket-percent" to="/superadmin/billing/coupons">
          Coupons
        </v-btn>
        <v-btn variant="tonal" prepend-icon="mdi-cash-fast" to="/superadmin/billing/payments">
          Payments
        </v-btn>
        <v-btn variant="tonal" prepend-icon="mdi-tune" to="/superadmin/billing/rates">
          Manage rates
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-cash-register" :loading="generating" @click="openGenerate">
          Generate bills
        </v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4" closable @click:close="error = null">{{ error }}</v-alert>
    <v-alert v-if="toast" type="success" variant="tonal" class="mb-4" closable @click:close="toast = null">{{ toast }}</v-alert>

    <div v-if="overview">
      <v-row dense>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Active tenants</div>
            <div class="text-h4 font-weight-bold">{{ overview.totals.tenants }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Requests (this month)</div>
            <div class="text-h4 font-weight-bold">
              {{ Number(overview.totals.requests_so_far).toLocaleString() }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4" color="primary" variant="tonal">
            <div class="text-caption text-medium-emphasis">Projected month-end revenue</div>
            <div class="text-h4 font-weight-bold">
              {{ formatMoney(overview.totals.projected_cost, overview.rate.currency) }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Current rate</div>
            <div class="text-h6 font-weight-bold">
              {{ Number(overview.rate.requests_per_unit).toLocaleString() }} req
              = {{ formatMoney(overview.rate.unit_cost, overview.rate.currency) }}
            </div>
          </v-card>
        </v-col>
      </v-row>

      <v-card rounded="lg" class="mt-4">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-domain</v-icon>
          Tenant usage — {{ overview.period.year }}-{{ String(overview.period.month).padStart(2, '0') }}
          <v-spacer />
          <v-text-field
            v-model="search"
            density="compact"
            variant="outlined"
            hide-details
            placeholder="Search tenant"
            prepend-inner-icon="mdi-magnify"
            style="max-width: 280px"
          />
        </v-card-title>
        <v-data-table
          :headers="tenantHeaders"
          :items="filteredTenants"
          :search="search"
          density="comfortable"
          :items-per-page="25"
        >
          <template #item.requests_so_far="{ item }">
            {{ Number(item.requests_so_far).toLocaleString() }}
          </template>
          <template #item.projected_requests="{ item }">
            {{ Number(item.projected_requests).toLocaleString() }}
          </template>
          <template #item.cost_so_far="{ item }">
            {{ formatMoney(item.cost_so_far, overview.rate.currency) }}
          </template>
          <template #item.projected_cost="{ item }">
            <strong>{{ formatMoney(item.projected_cost, overview.rate.currency) }}</strong>
          </template>
          <template #item.is_active="{ item }">
            <v-chip :color="item.is_active ? 'success' : 'default'" size="small" variant="tonal">
              {{ item.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </template>
          <template #item.billing_locked="{ item }">
            <v-chip v-if="item.billing_suspended" color="error" size="small" variant="tonal" label>
              <v-icon start size="14">mdi-lock</v-icon>Suspended
            </v-chip>
            <v-chip v-else-if="item.billing_locked" color="error" size="small" variant="tonal" label>
              <v-icon start size="14">mdi-alert</v-icon>Locked ({{ item.overdue_count }})
            </v-chip>
            <v-chip v-else-if="item.billing_grace_until" color="warning" size="small" variant="tonal" label>
              <v-icon start size="14">mdi-clock-outline</v-icon>Grace to {{ item.billing_grace_until }}
            </v-chip>
            <v-chip v-else-if="Number(item.total_overdue) > 0" color="warning" size="small" variant="tonal" label>
              <v-icon start size="14">mdi-cash-clock</v-icon>Overdue
            </v-chip>
            <v-chip v-else color="success" size="small" variant="tonal" label>
              <v-icon start size="14">mdi-check</v-icon>OK
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <v-btn
              icon="mdi-cog"
              variant="text"
              size="small"
              @click="openManage(item)"
            />
            <v-btn
              icon="mdi-eye"
              variant="text"
              size="small"
              :to="`/superadmin/billing/${item.tenant_id}`"
            />
          </template>
        </v-data-table>
      </v-card>

      <v-card rounded="lg" class="mt-4">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-receipt-text-outline</v-icon>
          Recent monthly bills
        </v-card-title>
        <v-data-table
          :headers="billHeaders"
          :items="bills"
          :loading="billsLoading"
          density="comfortable"
          :items-per-page="20"
        >
          <template #item.period="{ item }">
            {{ item.year }}-{{ String(item.month).padStart(2, '0') }}
          </template>
          <template #item.tenant_name="{ item }">{{ item.tenant_name }}</template>
          <template #item.total_requests="{ item }">
            {{ Number(item.total_requests).toLocaleString() }}
          </template>
          <template #item.amount="{ item }">
            {{ formatMoney(item.amount, item.currency) }}
          </template>
          <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
          <template #item.actions="{ item }">
            <v-btn
              v-if="item.status !== 'PAID' && item.status !== 'WAIVED'"
              size="small"
              variant="tonal"
              color="success"
              class="mr-1"
              @click="markPaid(item)"
            >
              Mark paid
            </v-btn>
            <v-btn
              v-if="item.status !== 'PAID' && item.status !== 'WAIVED'"
              size="small"
              variant="text"
              color="warning"
              @click="openWaive(item)"
            >
              Waive
            </v-btn>
          </template>
        </v-data-table>
      </v-card>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="primary" />

    <!-- Generate dialog -->
    <v-dialog v-model="genDialog" max-width="420">
      <v-card>
        <v-card-title>Generate monthly bills</v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-4">
            Aggregates request counts for the selected period and creates / refreshes bills
            for every tenant. Bills already marked PAID are not overwritten.
          </p>
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model.number="genYear" type="number" label="Year" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="genMonth" type="number" label="Month (1-12)" min="1" max="12" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="genDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="generating" @click="runGenerate">Generate</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Manage tenant billing dialog -->
    <v-dialog v-model="manageDialog" max-width="480">
      <v-card v-if="manageTarget">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-domain</v-icon>
          {{ manageTarget.tenant_name }}
        </v-card-title>
        <v-card-text>
          <div class="d-flex flex-wrap ga-2 mb-4">
            <v-chip v-if="manageTarget.billing_suspended" color="error" variant="tonal" label>
              <v-icon start size="14">mdi-lock</v-icon>Suspended
            </v-chip>
            <v-chip v-else-if="manageTarget.billing_locked" color="error" variant="tonal" label>
              <v-icon start size="14">mdi-alert</v-icon>Locked
            </v-chip>
            <v-chip v-else color="success" variant="tonal" label>
              <v-icon start size="14">mdi-check</v-icon>Not locked
            </v-chip>
            <v-chip v-if="manageTarget.billing_grace_until" color="warning" variant="tonal" label>
              Grace until {{ manageTarget.billing_grace_until }}
            </v-chip>
            <v-chip v-if="Number(manageTarget.total_overdue) > 0" color="warning" variant="tonal" label>
              Overdue {{ formatMoney(manageTarget.total_overdue, 'KSH') }}
            </v-chip>
          </div>

          <v-tabs v-model="manageTab" color="primary" density="compact" class="mb-3">
            <v-tab value="suspend">Suspend</v-tab>
            <v-tab value="grace">Grace period</v-tab>
          </v-tabs>

          <div v-if="manageTab === 'suspend'">
            <p class="text-body-2 text-medium-emphasis mb-3">
              Suspending immediately blocks API access for this tenant, regardless of
              overdue status, until you unsuspend them.
            </p>
            <v-text-field v-model="suspendReason" label="Reason" variant="outlined" density="comfortable" class="mb-2" />
            <div class="d-flex ga-2">
              <v-btn
                v-if="!manageTarget.billing_suspended"
                color="error" variant="flat" :loading="manageBusy" @click="doSuspend"
              >
                Suspend now
              </v-btn>
              <v-btn
                v-else
                color="success" variant="flat" :loading="manageBusy" @click="doUnsuspend"
              >
                Lift suspension
              </v-btn>
            </div>
          </div>

          <div v-else>
            <p class="text-body-2 text-medium-emphasis mb-3">
              Grant continued access despite overdue bills until a specific date
              (e.g. while a payment is being processed).
            </p>
            <v-text-field v-model="graceUntil" type="date" label="Grace until" variant="outlined" density="comfortable" class="mb-2" />
            <v-text-field v-model="graceReason" label="Reason (optional)" variant="outlined" density="comfortable" class="mb-2" />
            <v-btn color="warning" variant="flat" :loading="manageBusy" :disabled="!graceUntil" @click="doExtendGrace">
              Grant grace period
            </v-btn>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="manageDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Waive bill dialog -->
    <v-dialog v-model="waiveDialog" max-width="420">
      <v-card v-if="waiveTarget">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="warning">mdi-cash-remove</v-icon>
          Waive bill
        </v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-3">
            This writes off <strong>{{ waiveTarget.tenant_name }}</strong>'s
            {{ waiveTarget.year }}-{{ String(waiveTarget.month).padStart(2, '0') }} bill
            ({{ formatMoney(waiveTarget.amount, waiveTarget.currency) }}) entirely. This cannot be undone.
          </p>
          <v-text-field v-model="waiveReason" label="Reason" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="waiveDialog = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" :loading="waiveBusy" @click="confirmWaive">Waive bill</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatMoney } from '~/utils/format'

definePageMeta({ middleware: [] })

const { $api } = useNuxtApp()
const overview = ref(null)
const bills = ref([])
const loading = ref(false)
const billsLoading = ref(false)
const error = ref(null)
const toast = ref(null)
const search = ref('')

const genDialog = ref(false)
const generating = ref(false)
const today = new Date()
const genYear = ref(today.getMonth() === 0 ? today.getFullYear() - 1 : today.getFullYear())
const genMonth = ref(today.getMonth() === 0 ? 12 : today.getMonth())

// Manage tenant billing (suspend / unsuspend / grace)
const manageDialog = ref(false)
const manageTarget = ref(null)
const manageTab = ref('suspend')
const manageBusy = ref(false)
const suspendReason = ref('')
const graceUntil = ref('')
const graceReason = ref('')

// Waive bill
const waiveDialog = ref(false)
const waiveTarget = ref(null)
const waiveReason = ref('')
const waiveBusy = ref(false)

const tenantHeaders = [
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Type', key: 'tenant_type' },
  { title: 'Requests so far', key: 'requests_so_far' },
  { title: 'Cost so far', key: 'cost_so_far' },
  { title: 'Projected req.', key: 'projected_requests' },
  { title: 'Projected cost', key: 'projected_cost' },
  { title: 'Status', key: 'is_active' },
  { title: 'Billing', key: 'billing_locked', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]

const billHeaders = [
  { title: 'Period', key: 'period' },
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Requests', key: 'total_requests' },
  { title: 'Amount', key: 'amount' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]

const filteredTenants = computed(() => overview.value?.tenants || [])

async function loadOverview() {
  loading.value = true
  error.value = null
  try {
    const { data } = await $api.get('/usage-billing/admin/usage/')
    overview.value = data
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load.'
  } finally {
    loading.value = false
  }
}

async function loadBills() {
  billsLoading.value = true
  try {
    const { data } = await $api.get('/usage-billing/admin/bills/')
    bills.value = Array.isArray(data) ? data : data.results || []
  } finally {
    billsLoading.value = false
  }
}

function openGenerate() {
  genDialog.value = true
}

async function runGenerate() {
  generating.value = true
  try {
    await $api.post('/usage-billing/admin/generate-bills/', {
      year: genYear.value,
      month: genMonth.value
    })
    genDialog.value = false
    await loadBills()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to generate bills.'
  } finally {
    generating.value = false
  }
}

async function markPaid(bill) {
  try {
    await $api.post(`/usage-billing/admin/bills/${bill.id}/mark-paid/`)
    await loadBills()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to update bill.'
  }
}

function openManage(row) {
  manageTarget.value = row
  manageTab.value = 'suspend'
  suspendReason.value = row.billing_suspended ? '' : 'Overdue billing.'
  graceUntil.value = ''
  graceReason.value = ''
  manageDialog.value = true
}

async function refreshManageTarget(data) {
  // Merge fresh lock/summary info back into the table row + dialog target.
  const idx = overview.value?.tenants?.findIndex(t => t.tenant_id === data.tenant_id)
  const merged = {
    ...manageTarget.value,
    billing_suspended: data.billing_suspended,
    billing_grace_until: data.billing_grace_until,
    billing_locked: data.lock?.locked,
    overdue_count: data.lock?.overdue_count,
    total_overdue: data.lock?.total_overdue,
  }
  manageTarget.value = merged
  if (idx != null && idx !== -1) overview.value.tenants[idx] = merged
}

async function doSuspend() {
  manageBusy.value = true
  try {
    const { data } = await $api.post(`/usage-billing/admin/tenants/${manageTarget.value.tenant_id}/suspend/`, {
      reason: suspendReason.value,
    })
    await refreshManageTarget(data)
    toast.value = `${data.tenant_name} suspended.`
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to suspend tenant.'
  } finally {
    manageBusy.value = false
  }
}

async function doUnsuspend() {
  manageBusy.value = true
  try {
    const { data } = await $api.post(`/usage-billing/admin/tenants/${manageTarget.value.tenant_id}/unsuspend/`)
    await refreshManageTarget(data)
    toast.value = `${data.tenant_name} unsuspended.`
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to unsuspend tenant.'
  } finally {
    manageBusy.value = false
  }
}

async function doExtendGrace() {
  if (!graceUntil.value) return
  manageBusy.value = true
  try {
    const { data } = await $api.post(`/usage-billing/admin/tenants/${manageTarget.value.tenant_id}/extend-grace/`, {
      until: graceUntil.value,
      reason: graceReason.value,
    })
    await refreshManageTarget(data)
    toast.value = `Grace period granted until ${graceUntil.value}.`
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to extend grace period.'
  } finally {
    manageBusy.value = false
  }
}

function openWaive(bill) {
  waiveTarget.value = bill
  waiveReason.value = ''
  waiveDialog.value = true
}

async function confirmWaive() {
  waiveBusy.value = true
  try {
    await $api.post(`/usage-billing/admin/bills/${waiveTarget.value.id}/waive/`, { reason: waiveReason.value })
    waiveDialog.value = false
    toast.value = 'Bill waived.'
    await loadBills()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to waive bill.'
  } finally {
    waiveBusy.value = false
  }
}

onMounted(() => {
  loadOverview()
  loadBills()
})
</script>
