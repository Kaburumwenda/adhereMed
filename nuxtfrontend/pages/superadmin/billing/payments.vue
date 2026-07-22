<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Payments & Gateway"
      icon="mdi-cash-fast"
      subtitle="M-Pesa transactions, collections & gateway configuration"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-receipt-text-outline" to="/superadmin/billing">Bills</v-btn>
        <v-btn variant="tonal" prepend-icon="mdi-cog" @click="openConfig">Gateway settings</v-btn>
        <v-btn color="primary" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>
    <v-alert v-if="toast" type="success" variant="tonal" class="mb-4" closable @click:close="toast = null">{{ toast }}</v-alert>

    <div v-if="payload">
      <v-row dense>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4" color="success" variant="tonal">
            <div class="text-caption text-medium-emphasis">Total collected</div>
            <div class="text-h5 font-weight-bold">{{ formatMoney(payload.totals.collected, 'KSH') }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Successful</div>
            <div class="text-h5 font-weight-bold text-success">{{ payload.totals.success }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Pending</div>
            <div class="text-h5 font-weight-bold text-warning">{{ payload.totals.pending }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Failed</div>
            <div class="text-h5 font-weight-bold text-error">{{ payload.totals.failed }}</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Gateway status banner -->
      <v-card rounded="lg" class="mt-4 pa-4" :color="config?.is_active ? 'primary' : 'error'" variant="tonal">
        <div class="d-flex align-center flex-wrap" style="gap: 12px">
          <img src="~/assets/images/mpesa-logo.png" alt="M-Pesa" height="30" />
          <div>
            <div class="font-weight-bold">{{ config?.name || 'M-Pesa' }} gateway</div>
            <div class="text-caption text-medium-emphasis">
              {{ config?.is_active ? 'Active — accepting payments' : 'Inactive — payments disabled' }}
            </div>
          </div>
          <v-spacer />
          <v-btn variant="flat" size="small" color="primary" @click="openConfig">Edit configuration</v-btn>
        </div>
      </v-card>

      <v-card rounded="lg" class="mt-4">
        <v-card-title class="d-flex align-center flex-wrap">
          <v-icon class="mr-2">mdi-format-list-bulleted</v-icon>
          M-Pesa transactions
          <v-spacer />
          <v-select
            v-model="statusFilter"
            :items="statusOptions"
            density="compact"
            variant="outlined"
            hide-details
            label="Status"
            style="max-width: 180px"
            class="mr-2"
            @update:model-value="load"
          />
          <v-text-field
            v-model="search"
            density="compact"
            variant="outlined"
            hide-details
            placeholder="Search tenant / phone"
            prepend-inner-icon="mdi-magnify"
            style="max-width: 260px"
          />
        </v-card-title>
        <v-data-table
          :headers="headers"
          :items="payload.transactions"
          :search="search"
          density="comfortable"
          :items-per-page="25"
        >
          <template #item.created_at="{ item }">{{ formatDateTime(item.created_at) }}</template>
          <template #item.tenant_name="{ item }">{{ item.tenant_name }}</template>
          <template #item.purpose="{ item }">
            <v-chip size="small" variant="tonal" :color="item.purpose === 'wallet' ? 'success' : 'primary'">
              {{ item.purpose_display }}
            </v-chip>
          </template>
          <template #item.amount="{ item }">{{ formatMoney(item.amount, item.currency) }}</template>
          <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
          <template #item.checkout_request_id="{ item }">
            <span class="text-caption text-medium-emphasis">{{ item.checkout_request_id || '—' }}</span>
          </template>
        </v-data-table>
      </v-card>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="primary" />

    <!-- Gateway config dialog -->
    <v-dialog v-model="configDialog" max-width="560" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-cog</v-icon>
          Payment gateway configuration
        </v-card-title>
        <v-card-text v-if="configForm">
          <v-text-field v-model="configForm.name" label="Gateway name" variant="outlined" density="comfortable" class="mb-1" />
          <v-text-field
            v-model="configForm.stk_push_url"
            label="STK push URL (initiate)"
            variant="outlined"
            density="comfortable"
            prepend-inner-icon="mdi-link-variant"
            class="mb-1"
          />
          <v-text-field
            v-model="configForm.confirm_url"
            label="Confirmation URL (poll)"
            variant="outlined"
            density="comfortable"
            prepend-inner-icon="mdi-link-variant"
            class="mb-1"
          />
          <v-text-field v-model="configForm.source" label="Source identifier" variant="outlined" density="comfortable" class="mb-1" />
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model.number="configForm.request_timeout_seconds" type="number" label="Timeout (seconds)" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="configForm.poll_interval_seconds" type="number" label="Poll interval (seconds)" variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <v-switch v-model="configForm.is_active" color="primary" label="Gateway active" hide-details inset />
          <v-alert v-if="configError" type="error" variant="tonal" density="compact" class="mt-2">{{ configError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="configDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="savingConfig" @click="saveConfig">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { formatDateTime, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const payload = ref(null)
const config = ref(null)
const loading = ref(false)
const error = ref(null)
const toast = ref(null)
const search = ref('')
const statusFilter = ref('')

const configDialog = ref(false)
const configForm = ref(null)
const savingConfig = ref(false)
const configError = ref(null)

const statusOptions = [
  { title: 'All', value: '' },
  { title: 'Success', value: 'success' },
  { title: 'Pending', value: 'pending' },
  { title: 'Failed', value: 'failed' }
]

const headers = [
  { title: 'Date', key: 'created_at' },
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Purpose', key: 'purpose' },
  { title: 'Phone', key: 'phone' },
  { title: 'Amount', key: 'amount' },
  { title: 'Status', key: 'status' },
  { title: 'Checkout ID', key: 'checkout_request_id' }
]

async function load() {
  loading.value = true
  error.value = null
  try {
    const params = statusFilter.value ? { status: statusFilter.value } : {}
    const [{ data: txns }, { data: cfg }] = await Promise.all([
      $api.get('/usage-billing/admin/payments/', { params }),
      $api.get('/usage-billing/admin/payment-config/')
    ])
    payload.value = txns
    config.value = cfg
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load payments.'
  } finally {
    loading.value = false
  }
}

function openConfig() {
  configError.value = null
  configForm.value = { ...(config.value || {}) }
  configDialog.value = true
}

async function saveConfig() {
  savingConfig.value = true
  configError.value = null
  try {
    const { data } = await $api.put('/usage-billing/admin/payment-config/', configForm.value)
    config.value = data
    configDialog.value = false
    toast.value = 'Gateway configuration saved.'
  } catch (e) {
    configError.value = e?.response?.data?.detail || e.message || 'Failed to save configuration.'
  } finally {
    savingConfig.value = false
  }
}

onMounted(load)
</script>
