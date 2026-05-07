<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Usage Billing"
      icon="mdi-cash-multiple"
      subtitle="Per-tenant API request metering & monthly bills"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-tune" to="/superadmin/billing/rates">
          Manage rates
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-cash-register" :loading="generating" @click="openGenerate">
          Generate bills
        </v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

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
          <template #item.actions="{ item }">
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
              v-if="item.status !== 'PAID'"
              size="small"
              variant="tonal"
              color="success"
              @click="markPaid(item)"
            >
              Mark paid
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
const search = ref('')

const genDialog = ref(false)
const generating = ref(false)
const today = new Date()
const genYear = ref(today.getMonth() === 0 ? today.getFullYear() - 1 : today.getFullYear())
const genMonth = ref(today.getMonth() === 0 ? 12 : today.getMonth())

const tenantHeaders = [
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Type', key: 'tenant_type' },
  { title: 'Requests so far', key: 'requests_so_far' },
  { title: 'Cost so far', key: 'cost_so_far' },
  { title: 'Projected req.', key: 'projected_requests' },
  { title: 'Projected cost', key: 'projected_cost' },
  { title: 'Status', key: 'is_active' },
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

onMounted(() => {
  loadOverview()
  loadBills()
})
</script>
