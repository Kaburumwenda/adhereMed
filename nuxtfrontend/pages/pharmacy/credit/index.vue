<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="warning" variant="tonal" size="48" rounded="lg">
        <v-icon size="26">mdi-account-cash-outline</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Credit Management</div>
        <div class="text-body-2 text-medium-emphasis">
          Track outstanding balances, record payments, manage overdue accounts
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="loading" @click="load" size="small">{{ $t('common.refresh') }}</v-btn>
    </div>

    <!-- KPI Cards -->
    <v-row dense class="mb-5">
      <v-col cols="6" sm="3">
        <v-card flat rounded="xl" class="kpi-card pa-4 text-center">
          <v-icon color="primary" size="28" class="mb-1">mdi-receipt-text-outline</v-icon>
          <div class="text-h5 font-weight-bold mt-1">{{ summary.count }}</div>
          <div class="text-caption text-medium-emphasis">Credit Sales</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card flat rounded="xl" class="kpi-card pa-4 text-center">
          <v-icon color="info" size="28" class="mb-1">mdi-cash-multiple</v-icon>
          <div class="text-h5 font-weight-bold mt-1">{{ formatMoney(summary.total_credit) }}</div>
          <div class="text-caption text-medium-emphasis">Total Credit</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card flat rounded="xl" class="kpi-card pa-4 text-center">
          <v-icon color="success" size="28" class="mb-1">mdi-cash-check</v-icon>
          <div class="text-h5 font-weight-bold mt-1 text-success">{{ formatMoney(summary.total_paid) }}</div>
          <div class="text-caption text-medium-emphasis">Collected</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card flat rounded="xl" class="kpi-card pa-4 text-center" :class="summary.overdue_count ? 'kpi-danger' : ''">
          <v-icon color="error" size="28" class="mb-1">mdi-alert-circle-outline</v-icon>
          <div class="text-h5 font-weight-bold mt-1 text-error">{{ formatMoney(summary.total_balance) }}</div>
          <div class="text-caption text-medium-emphasis">Outstanding</div>
          <v-chip v-if="summary.overdue_count" size="x-small" color="error" variant="flat" class="mt-1">
            {{ summary.overdue_count }} overdue
          </v-chip>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters Bar -->
    <v-card flat rounded="xl" class="mb-4 filter-card">
      <div class="d-flex align-center flex-wrap ga-2 pa-3">
        <!-- Date preset chips -->
        <v-chip-group v-model="datePreset" selected-class="text-primary" mandatory column>
          <v-chip v-for="dp in datePresets" :key="dp.value" :value="dp.value" variant="outlined" size="small" rounded="lg" filter>
            {{ dp.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <!-- Custom date range summary -->
        <v-chip
          v-if="datePreset === 'custom' && customFrom && customTo"
          size="small" variant="tonal" color="primary" rounded="lg"
          prepend-icon="mdi-calendar-range" closable
          @click="customDateDialog = true"
          @click:close="resetCustomDate"
        >
          {{ customFrom }} — {{ customTo }}
        </v-chip>
      </div>
      <v-divider />
      <div class="d-flex align-center flex-wrap ga-2 pa-3">
        <v-text-field
          v-model="search"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search customer, phone, receipt..."
          density="compact"
          variant="solo-filled"
          flat
          rounded="lg"
          hide-details
          clearable
          style="max-width: 320px"
        />
        <v-select
          v-model="statusFilter"
          :items="statusOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="solo-filled"
          flat
          rounded="lg"
          hide-details
          style="max-width: 180px"
        />
      </div>
    </v-card>

    <!-- Data Table -->
    <v-card flat rounded="xl" class="table-card">
      <v-data-table
        :headers="headers"
        :items="filteredCredits"
        :loading="loading"
        :items-per-page="20"
        density="comfortable"
        item-value="id"
        hover
        class="credit-table"
      >
        <template #item.transaction_number="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar :color="statusColor(item.status)" variant="tonal" size="32" rounded="lg">
              <v-icon size="16">{{ statusIcon(item.status) }}</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium text-body-2">{{ item.transaction_number }}</div>
              <div class="text-caption text-medium-emphasis">{{ formatDateShort(item.created_at) }}</div>
            </div>
          </div>
        </template>
        <template #item.customer="{ item }">
          <div class="font-weight-medium">{{ item.customer_name }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.customer_phone || '—' }}</div>
        </template>
        <template #item.total_amount="{ item }">
          <span class="font-weight-medium">{{ formatMoney(item.total_amount) }}</span>
        </template>
        <template #item.partial_paid_amount="{ item }">
          <span class="text-success font-weight-medium">{{ formatMoney(item.partial_paid_amount) }}</span>
        </template>
        <template #item.balance_amount="{ item }">
          <v-chip
            :color="item.balance_amount > 0 ? 'error' : 'success'"
            variant="tonal"
            size="small"
            class="font-weight-bold"
          >
            {{ formatMoney(item.balance_amount) }}
          </v-chip>
        </template>
        <template #item.due_date="{ item }">
          <span :class="isOverdue(item) ? 'text-error font-weight-bold' : ''">
            {{ item.due_date || '—' }}
          </span>
          <v-icon v-if="isOverdue(item)" size="14" color="error" class="ml-1">mdi-clock-alert-outline</v-icon>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="flat" :color="statusColor(item.status)">
            {{ statusLabel(item.status) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex ga-1">
            <v-btn icon variant="text" size="x-small" color="primary" @click="openDetail(item)">
              <v-icon size="18">mdi-eye-outline</v-icon>
              <v-tooltip activator="parent" location="top">View details</v-tooltip>
            </v-btn>
            <v-btn
              icon variant="text" size="x-small" color="success"
              :disabled="item.balance_amount <= 0"
              @click="openPaymentDialog(item)"
            >
              <v-icon size="18">mdi-cash-plus</v-icon>
              <v-tooltip activator="parent" location="top">Record payment</v-tooltip>
            </v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Detail Dialog -->
    <v-dialog v-model="detailDialog" max-width="640" scrollable>
      <v-card rounded="xl" v-if="selectedCredit">
        <v-card-title class="d-flex align-center ga-2 pa-4 pb-2">
          <v-avatar :color="statusColor(selectedCredit.status)" variant="tonal" size="40" rounded="lg">
            <v-icon>{{ statusIcon(selectedCredit.status) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6">{{ selectedCredit.transaction_number }}</div>
            <div class="text-caption text-medium-emphasis">{{ formatDateFull(selectedCredit.created_at) }}</div>
          </div>
          <v-spacer />
          <v-chip :color="statusColor(selectedCredit.status)" variant="flat" size="small">
            {{ statusLabel(selectedCredit.status) }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Customer</div>
              <div class="font-weight-medium">{{ selectedCredit.customer_name }}</div>
              <div class="text-body-2 text-medium-emphasis">{{ selectedCredit.customer_phone || '—' }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Due Date</div>
              <div class="font-weight-medium" :class="isOverdue(selectedCredit) ? 'text-error' : ''">
                {{ selectedCredit.due_date || 'Not set' }}
                <v-icon v-if="isOverdue(selectedCredit)" size="14" color="error">mdi-clock-alert</v-icon>
              </div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <v-row dense>
            <v-col cols="4" class="text-center">
              <div class="text-caption text-medium-emphasis">{{ $t('common.total') }}</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(selectedCredit.total_amount) }}</div>
            </v-col>
            <v-col cols="4" class="text-center">
              <div class="text-caption text-medium-emphasis">Paid</div>
              <div class="text-h6 font-weight-bold text-success">{{ formatMoney(selectedCredit.partial_paid_amount) }}</div>
            </v-col>
            <v-col cols="4" class="text-center">
              <div class="text-caption text-medium-emphasis">Balance</div>
              <div class="text-h6 font-weight-bold text-error">{{ formatMoney(selectedCredit.balance_amount) }}</div>
            </v-col>
          </v-row>

          <template v-if="selectedCredit.notes">
            <v-divider class="my-3" />
            <div class="text-caption text-medium-emphasis mb-1">{{ $t('common.notes') }}</div>
            <div class="text-body-2">{{ selectedCredit.notes }}</div>
          </template>

          <!-- Payment History -->
          <v-divider class="my-3" />
          <div class="d-flex align-center mb-2">
            <div class="text-subtitle-2 font-weight-bold">Payment History</div>
            <v-spacer />
            <v-btn
              v-if="selectedCredit.balance_amount > 0"
              size="small" color="success" variant="tonal" rounded="lg"
              prepend-icon="mdi-cash-plus"
              @click="openPaymentDialog(selectedCredit)"
            >
              Record Payment
            </v-btn>
          </div>
          <div v-if="paymentsLoading" class="text-center pa-4">
            <v-progress-circular indeterminate size="24" />
          </div>
          <v-list v-else-if="paymentHistory.length" density="compact" class="rounded-lg border-thin">
            <v-list-item v-for="p in paymentHistory" :key="p.id" class="px-3">
              <template #prepend>
                <v-avatar color="success" variant="tonal" size="32">
                  <v-icon size="16">mdi-cash-check</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">
                {{ formatMoney(p.amount) }}
                <v-chip size="x-small" variant="outlined" class="ml-2">{{ methodLabel(p.payment_method) }}</v-chip>
              </v-list-item-title>
              <v-list-item-subtitle>
                {{ formatDateFull(p.paid_at) }}
                <span v-if="p.recorded_by_name"> · by {{ p.recorded_by_name }}</span>
                <span v-if="p.reference"> · Ref: {{ p.reference }}</span>
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
          <div v-else class="text-center text-medium-emphasis pa-4 border-thin rounded-lg">
            <v-icon size="32" class="mb-1">mdi-cash-remove</v-icon>
            <div class="text-caption">No payments recorded yet</div>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">{{ $t('common.close') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Record Payment Dialog -->
    <v-dialog v-model="payDialog" max-width="440" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center ga-2 pa-4 pb-2">
          <v-avatar color="success" variant="tonal" size="40" rounded="lg">
            <v-icon>mdi-cash-plus</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6">{{ $t('credit.recordPayment') }}</div>
            <div class="text-caption text-medium-emphasis" v-if="payTarget">
              {{ payTarget.customer_name }} · Balance: {{ formatMoney(payTarget.balance_amount) }}
            </div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12">
              <v-text-field
                v-model.number="payForm.amount"
                label="Amount *"
                type="number"
                min="0.01"
                :max="payTarget?.balance_amount"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-cash"
                suffix="KES"
                :rules="[v => v > 0 || 'Enter amount', v => v <= (payTarget?.balance_amount || 0) || 'Exceeds balance']"
                hide-details="auto"
                class="mb-3"
              />
            </v-col>
            <v-col cols="12">
              <v-select
                v-model="payForm.payment_method"
                :items="paymentMethods"
                item-title="label"
                item-value="value"
                label="Payment Method *"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-credit-card-outline"
                hide-details="auto"
                class="mb-3"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="payForm.reference"
                label="Reference (optional)"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-pound"
                placeholder="M-Pesa code, receipt #, etc."
                hide-details
                class="mb-3"
              />
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="payForm.notes"
                label="Notes (optional)"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                rows="2"
                auto-grow
                hide-details
              />
            </v-col>
          </v-row>

          <!-- Quick amount buttons -->
          <div class="d-flex flex-wrap ga-2 mt-3" v-if="payTarget">
            <v-chip
              v-for="pct in [25, 50, 75, 100]"
              :key="pct"
              size="small"
              variant="outlined"
              color="success"
              rounded="lg"
              @click="payForm.amount = Math.round((payTarget.balance_amount * pct / 100) * 100) / 100"
              style="cursor:pointer"
            >
              {{ pct }}% ({{ formatMoney(Math.round(payTarget.balance_amount * pct / 100 * 100) / 100) }})
            </v-chip>
          </div>

          <!-- Balance preview -->
          <v-alert v-if="payForm.amount > 0 && payTarget" type="info" variant="tonal" density="compact" class="mt-3" rounded="lg">
            After this payment, remaining balance:
            <strong>{{ formatMoney(Math.max(0, payTarget.balance_amount - payForm.amount)) }}</strong>
            <span v-if="payForm.amount >= payTarget.balance_amount" class="text-success ml-1">(Fully settled!)</span>
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" @click="closePayDialog">{{ $t('common.cancel') }}</v-btn>
          <v-spacer />
          <v-btn
            color="success"
            variant="flat"
            rounded="lg"
            prepend-icon="mdi-check"
            :loading="paySubmitting"
            :disabled="!canSubmitPayment"
            @click="submitPayment"
          >
            Confirm Payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Custom Date Range Dialog -->
    <v-dialog v-model="customDateDialog" max-width="380" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center ga-2 pa-4 pb-2">
          <v-avatar color="primary" variant="tonal" size="40" rounded="lg">
            <v-icon>mdi-calendar-range</v-icon>
          </v-avatar>
          <div class="text-h6">Custom Date Range</div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field
            v-model="tempFrom"
            label="From *"
            type="date"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            prepend-inner-icon="mdi-calendar-start"
            hide-details="auto"
            class="mb-3"
          />
          <v-text-field
            v-model="tempTo"
            label="To *"
            type="date"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            prepend-inner-icon="mdi-calendar-end"
            hide-details="auto"
            :min="tempFrom"
          />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" @click="cancelCustomDate">{{ $t('common.cancel') }}</v-btn>
          <v-spacer />
          <v-btn
            color="primary" variant="flat" rounded="lg"
            prepend-icon="mdi-check"
            :disabled="!tempFrom || !tempTo"
            @click="applyCustomDate"
          >
            Apply
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" timeout="3500" location="top right" rounded="lg">
      <div class="d-flex align-center ga-2">
        <v-icon>{{ snack.color === 'success' ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon>
        {{ snack.text }}
      </div>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { formatMoney } from '~/utils/format'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const loading = ref(false)
const credits = ref([])
const summary = reactive({ count: 0, total_credit: 0, total_paid: 0, total_balance: 0, overdue_count: 0 })
const search = ref('')
const statusFilter = ref('')
const snack = reactive({ show: false, text: '', color: 'success' })

// Date Filters
const datePreset = ref('all')
const customFrom = ref('')
const customTo = ref('')
const customDateDialog = ref(false)
const tempFrom = ref('')
const tempTo = ref('')

const datePresets = [
  { label: 'All Time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'This Week', value: 'week' },
  { label: 'This Month', value: 'month' },
  { label: 'Last Month', value: 'last_month' },
  { label: 'Custom', value: 'custom' },
]

const statusOptions = [
  { label: 'All statuses', value: '' },
  { label: 'Open', value: 'open' },
  { label: 'Partially Paid', value: 'partial' },
  { label: 'Settled', value: 'settled' },
  { label: 'Overdue', value: 'overdue' },
]

const headers = [
  { title: 'Transaction', key: 'transaction_number', sortable: false },
  { title: 'Customer', key: 'customer', sortable: false },
  { title: 'Total', key: 'total_amount', align: 'end' },
  { title: 'Paid', key: 'partial_paid_amount', align: 'end' },
  { title: 'Balance', key: 'balance_amount', align: 'end' },
  { title: 'Due Date', key: 'due_date' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, width: 90 },
]

const paymentMethods = [
  { value: 'cash', label: 'Cash' },
  { value: 'mpesa', label: 'M-Pesa' },
  { value: 'card', label: 'Card' },
  { value: 'insurance', label: 'Insurance' },
]

// Detail dialog
const detailDialog = ref(false)
const selectedCredit = ref(null)
const paymentHistory = ref([])
const paymentsLoading = ref(false)

// Payment dialog
const payDialog = ref(false)
const payTarget = ref(null)
const paySubmitting = ref(false)
const payForm = reactive({ amount: 0, payment_method: 'cash', reference: '', notes: '' })

const canSubmitPayment = computed(() => {
  if (!payTarget.value) return false
  if (payForm.amount <= 0) return false
  if (payForm.amount > payTarget.value.balance_amount) return false
  if (!payForm.payment_method) return false
  return true
})

// Filtered credits (client-side search on loaded data)
const filteredCredits = computed(() => {
  if (!search.value) return credits.value
  const q = search.value.toLowerCase()
  return credits.value.filter(c =>
    (c.customer_name || '').toLowerCase().includes(q) ||
    (c.customer_phone || '').toLowerCase().includes(q) ||
    (c.transaction_number || '').toLowerCase().includes(q)
  )
})

// Helpers
function statusLabel(s) {
  return ({ open: 'Open', partial: 'Partial', settled: 'Settled', overdue: 'Overdue' })[s] || s
}
function statusColor(s) {
  return ({ open: 'warning', partial: 'info', settled: 'success', overdue: 'error' })[s] || 'grey'
}
function statusIcon(s) {
  return ({
    open: 'mdi-clock-outline',
    partial: 'mdi-progress-check',
    settled: 'mdi-check-circle-outline',
    overdue: 'mdi-alert-outline',
  })[s] || 'mdi-help-circle-outline'
}
function methodLabel(m) {
  return ({ none: 'None', cash: 'Cash', mpesa: 'M-Pesa', card: 'Card', insurance: 'Insurance' })[m] || m
}
function formatDateShort(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}
function formatDateFull(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
function isOverdue(item) {
  if (!item?.due_date || Number(item?.balance_amount || 0) <= 0) return false
  return item.due_date < new Date().toISOString().slice(0, 10)
}
function flash(text, color = 'success') {
  snack.text = text
  snack.color = color
  snack.show = true
}

// Data loading
async function load() {
  loading.value = true
  try {
    const params = { page_size: 500 }
    if (statusFilter.value) params.status = statusFilter.value
    if (datePreset.value && datePreset.value !== 'all' && datePreset.value !== 'custom') {
      params.period = datePreset.value
    }
    if (datePreset.value === 'custom' && customFrom.value && customTo.value) {
      params.date_from = customFrom.value
      params.date_to = customTo.value
    }

    const summaryParams = { ...params }
    delete summaryParams.page_size

    const [sumRes, listRes] = await Promise.all([
      $api.get('/pos/credits/summary/', { params: summaryParams }),
      $api.get('/pos/credits/', { params }),
    ])

    Object.assign(summary, {
      count: Number(sumRes.data?.count || 0),
      total_credit: Number(sumRes.data?.total_credit || 0),
      total_paid: Number(sumRes.data?.total_paid || 0),
      total_balance: Number(sumRes.data?.total_balance || 0),
      overdue_count: Number(sumRes.data?.overdue_count || 0),
    })
    credits.value = listRes.data?.results || listRes.data || []
  } catch (e) {
    flash(e?.response?.data?.detail || 'Failed to load credits', 'error')
  } finally {
    loading.value = false
  }
}

// Detail
async function openDetail(item) {
  selectedCredit.value = item
  detailDialog.value = true
  await loadPayments(item.id)
}

async function loadPayments(creditId) {
  paymentsLoading.value = true
  try {
    const res = await $api.get(`/pos/credits/${creditId}/payments/`)
    paymentHistory.value = res.data || []
  } catch {
    paymentHistory.value = []
  } finally {
    paymentsLoading.value = false
  }
}

// Payment Dialog
function openPaymentDialog(item) {
  payTarget.value = item
  payForm.amount = 0
  payForm.payment_method = 'cash'
  payForm.reference = ''
  payForm.notes = ''
  payDialog.value = true
}

function closePayDialog() {
  payDialog.value = false
  payTarget.value = null
}

async function submitPayment() {
  if (!canSubmitPayment.value) return
  paySubmitting.value = true
  try {
    const res = await $api.post(`/pos/credits/${payTarget.value.id}/record_payment/`, {
      amount: payForm.amount,
      payment_method: payForm.payment_method,
      reference: payForm.reference,
      notes: payForm.notes,
    })
    flash(`Payment of ${formatMoney(payForm.amount)} recorded successfully`)

    // Update the local credit record
    const updatedCredit = res.data?.credit
    if (updatedCredit) {
      const idx = credits.value.findIndex(c => c.id === updatedCredit.id)
      if (idx >= 0) credits.value[idx] = updatedCredit
      if (selectedCredit.value?.id === updatedCredit.id) {
        selectedCredit.value = updatedCredit
      }
    }

    // Reload payments if detail is open
    if (detailDialog.value && selectedCredit.value) {
      await loadPayments(selectedCredit.value.id)
    }

    closePayDialog()
    // Refresh summary
    loadSummary()
  } catch (e) {
    flash(e?.response?.data?.detail || 'Payment failed', 'error')
  } finally {
    paySubmitting.value = false
  }
}

async function loadSummary() {
  try {
    const params = {}
    if (statusFilter.value) params.status = statusFilter.value
    if (datePreset.value && datePreset.value !== 'all' && datePreset.value !== 'custom') {
      params.period = datePreset.value
    }
    if (datePreset.value === 'custom' && customFrom.value && customTo.value) {
      params.date_from = customFrom.value
      params.date_to = customTo.value
    }
    const res = await $api.get('/pos/credits/summary/', { params })
    Object.assign(summary, {
      count: Number(res.data?.count || 0),
      total_credit: Number(res.data?.total_credit || 0),
      total_paid: Number(res.data?.total_paid || 0),
      total_balance: Number(res.data?.total_balance || 0),
      overdue_count: Number(res.data?.overdue_count || 0),
    })
  } catch {}
}

// Custom date dialog helpers
function openCustomDateDialog() {
  tempFrom.value = customFrom.value || ''
  tempTo.value = customTo.value || ''
  customDateDialog.value = true
}
function applyCustomDate() {
  customFrom.value = tempFrom.value
  customTo.value = tempTo.value
  customDateDialog.value = false
}
function cancelCustomDate() {
  customDateDialog.value = false
  if (!customFrom.value || !customTo.value) {
    datePreset.value = 'all'
  }
}
function resetCustomDate() {
  customFrom.value = ''
  customTo.value = ''
  datePreset.value = 'all'
}

// Watchers
watch([statusFilter, datePreset, customFrom, customTo], () => {
  load()
})
watch(datePreset, (val) => {
  if (val === 'custom') openCustomDateDialog()
})

onMounted(load)
</script>

<style scoped>
.kpi-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 0.15s, box-shadow 0.15s;
}
.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}
.kpi-danger {
  border-color: rgba(var(--v-theme-error), 0.3);
  background: rgba(var(--v-theme-error), 0.03);
}
.filter-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.table-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.credit-table :deep(.v-data-table__tr:hover) {
  background: rgba(var(--v-theme-primary), 0.03) !important;
}
.border-thin {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
</style>
