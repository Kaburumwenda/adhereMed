<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="API Billing — Payments"
      subtitle="Pay outstanding bills, top up your wallet & redeem Adhere Coins"
      eyebrow="API BILLING"
      icon="mdi-credit-card-outline"
      :chips="data ? [
        { icon: 'mdi-cash-clock', label: `${formatMoney(summary.total_outstanding, summary.currency)} outstanding` },
        { icon: 'mdi-wallet', label: `${formatMoney(data.wallet_balance, data.currency)} wallet` },
      ] : []"
    >
      <template #actions>
        <v-btn variant="text" rounded="pill" color="white" prepend-icon="mdi-chart-box"
               class="text-none mr-2" to="/homecare/billing/usage">
          <span class="font-weight-medium">Usage &amp; Bills</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-wallet-plus"
               class="text-none mr-2" @click="openAddFunds">
          <span class="text-teal-darken-2 font-weight-bold">Add funds</span>
        </v-btn>
        <v-btn variant="text" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">
          <span class="font-weight-medium">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>
    <v-alert v-if="toast" type="success" variant="tonal" class="mb-4" closable @click:close="toast = null">{{ toast }}</v-alert>

    <div v-if="data">
      <!-- Summary + coin balance -->
      <v-row dense>
        <v-col cols="12" md="3" sm="6">
          <v-card rounded="lg" class="pa-4">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Outstanding</div>
              <v-icon size="20" color="warning">mdi-cash-clock</v-icon>
            </div>
            <div class="text-h5 font-weight-bold mt-1">{{ formatMoney(summary.total_outstanding, summary.currency) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">{{ summary.outstanding_count }} unpaid</div>
          </v-card>
        </v-col>
        <v-col cols="12" md="3" sm="6">
          <v-card
            rounded="lg"
            class="pa-4"
            :color="Number(summary.total_overdue) > 0 ? 'error' : undefined"
            :variant="Number(summary.total_overdue) > 0 ? 'tonal' : undefined"
          >
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Overdue</div>
              <v-icon size="20" color="error">mdi-alert-circle</v-icon>
            </div>
            <div class="text-h5 font-weight-bold mt-1">{{ formatMoney(summary.total_overdue, summary.currency) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">{{ summary.overdue_count }} overdue</div>
          </v-card>
        </v-col>
        <v-col cols="12" md="3" sm="6">
          <v-card rounded="lg" class="pa-4" color="success" variant="tonal">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Wallet balance</div>
              <v-icon size="20">mdi-wallet</v-icon>
            </div>
            <div class="text-h5 font-weight-bold mt-1">{{ formatMoney(data.wallet_balance, data.currency) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">Pre-funded credit</div>
          </v-card>
        </v-col>
        <v-col cols="12" md="3" sm="6">
          <v-card rounded="lg" class="pa-4" color="teal" variant="tonal">
            <div class="d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Adhere Coins</div>
              <v-icon size="20">mdi-circle-multiple</v-icon>
            </div>
            <div class="text-h5 font-weight-bold mt-1">{{ fmt(data.coin_balance) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">1 coin = 1 {{ data.currency }}</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Tabs -->
      <v-card rounded="lg" class="mt-4">
        <v-tabs v-model="activeTab" color="teal" align-tabs="start">
          <v-tab value="outstanding" prepend-icon="mdi-receipt-text-clock">
            Outstanding bills
            <v-badge
              v-if="data.outstanding_bills.length"
              :content="data.outstanding_bills.length"
              color="warning"
              inline
              class="ml-2"
            />
          </v-tab>
          <v-tab value="history" prepend-icon="mdi-history">Payment history</v-tab>
          <v-tab value="mpesa" prepend-icon="mdi-cellphone-nfc">M-Pesa transactions</v-tab>
          <v-tab value="wallet" prepend-icon="mdi-wallet-outline">Wallet activity</v-tab>
        </v-tabs>
        <v-divider />

        <v-tabs-window v-model="activeTab">
          <!-- Outstanding bills -->
          <v-tabs-window-item value="outstanding">
            <v-data-table
              :headers="outHeaders"
              :items="data.outstanding_bills"
              density="comfortable"
              :items-per-page="10"
              hide-default-footer
            >
              <template #item.period="{ item }">
                {{ item.period_label || (item.year + '-' + String(item.month).padStart(2, '0')) }}
              </template>
              <template #item.amount="{ item }">{{ formatMoney(item.amount, item.currency) }}</template>
              <template #item.balance="{ item }">
                <span class="font-weight-medium">{{ formatMoney(item.balance ?? item.amount, item.currency) }}</span>
              </template>
              <template #item.due_date="{ item }">
                <span :class="{ 'text-error font-weight-medium': item.is_overdue }">
                  {{ item.due_date ? formatDate(item.due_date) : '—' }}
                </span>
              </template>
              <template #item.status="{ item }">
                <StatusChip :status="item.effective_status || item.status" />
              </template>
              <template #item.actions="{ item }">
                <v-btn size="small" variant="text" :to="`/homecare/billing/bills/${item.id}`">View</v-btn>
                <v-btn
                  size="small"
                  color="teal"
                  variant="flat"
                  prepend-icon="mdi-cash-fast"
                  class="ml-1"
                  @click="openPay(item)"
                >
                  Pay
                </v-btn>
              </template>
              <template #no-data>
                <div class="text-medium-emphasis py-6 text-center">No outstanding bills. You're all caught up.</div>
              </template>
            </v-data-table>
          </v-tabs-window-item>

          <!-- Payment history -->
          <v-tabs-window-item value="history">
            <v-data-table
              :headers="paidHeaders"
              :items="data.paid_bills"
              density="comfortable"
              :items-per-page="10"
              hide-default-footer
            >
              <template #item.period="{ item }">
                {{ item.period_label || (item.year + '-' + String(item.month).padStart(2, '0')) }}
              </template>
              <template #item.amount="{ item }">{{ formatMoney(item.amount, item.currency) }}</template>
              <template #item.paid_at="{ item }">{{ item.paid_at ? formatDateTime(item.paid_at) : '—' }}</template>
              <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
              <template #item.actions="{ item }">
                <v-btn size="small" variant="text" :to="`/homecare/billing/bills/${item.id}`">View</v-btn>
              </template>
              <template #no-data>
                <div class="text-medium-emphasis py-6 text-center">No payments yet.</div>
              </template>
            </v-data-table>
          </v-tabs-window-item>

          <!-- M-Pesa transactions -->
          <v-tabs-window-item value="mpesa">
            <div class="d-flex align-center px-4 pt-3 pb-1">
              <img src="~/assets/images/mpesa-logo.png" alt="M-Pesa" height="20" class="mr-2" />
              <span class="text-caption text-medium-emphasis">All M-Pesa STK push requests</span>
            </div>
            <v-data-table
              :headers="mpesaHeaders"
              :items="data.mpesa_transactions"
              density="comfortable"
              :items-per-page="10"
              hide-default-footer
            >
              <template #item.created_at="{ item }">{{ formatDateTime(item.created_at) }}</template>
              <template #item.purpose="{ item }">{{ item.purpose_display }}</template>
              <template #item.amount="{ item }">{{ formatMoney(item.amount, item.currency) }}</template>
              <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
              <template #no-data>
                <div class="text-medium-emphasis py-6 text-center">No M-Pesa payments yet.</div>
              </template>
            </v-data-table>
          </v-tabs-window-item>

          <!-- Wallet activity -->
          <v-tabs-window-item value="wallet">
            <v-data-table
              :headers="walletHeaders"
              :items="data.wallet_transactions"
              density="comfortable"
              :items-per-page="10"
              hide-default-footer
            >
              <template #item.created_at="{ item }">{{ formatDateTime(item.created_at) }}</template>
              <template #item.amount="{ item }">
                <span :class="item.type === 'credit' ? 'text-success' : 'text-error'">
                  {{ item.type === 'credit' ? '+' : '-' }} {{ formatMoney(item.amount, data.currency) }}
                </span>
              </template>
              <template #item.balance_after="{ item }">{{ formatMoney(item.balance_after, data.currency) }}</template>
              <template #no-data>
                <div class="text-medium-emphasis py-6 text-center">No wallet activity yet.</div>
              </template>
            </v-data-table>
          </v-tabs-window-item>
        </v-tabs-window>
      </v-card>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="teal" />

    <!-- Pay dialog -->
    <v-dialog v-model="payDialog" max-width="520" persistent>
      <v-card rounded="lg" v-if="payTarget">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="teal">mdi-cash-fast</v-icon>
          Pay bill — {{ payTarget.period_label }}
        </v-card-title>
        <v-card-text>
          <div class="d-flex justify-space-between mb-1">
            <span class="text-medium-emphasis">Bill amount</span>
            <span class="font-weight-bold">{{ formatMoney(payTarget.amount, payTarget.currency) }}</span>
          </div>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-medium-emphasis">Balance due</span>
            <span class="font-weight-bold text-warning">{{ formatMoney(billBalance, payTarget.currency) }}</span>
          </div>

          <div class="text-caption text-medium-emphasis mb-1">Payment method</div>
          <v-item-group v-model="payMethod" mandatory class="mb-4">
            <v-row dense>
              <v-col cols="4">
                <v-item v-slot="{ isSelected, toggle }" value="mpesa">
                  <v-card
                    rounded="lg" variant="outlined" class="pa-2 text-center method-card"
                    :class="{ 'method-card--active': isSelected }" @click="toggle"
                  >
                    <img src="~/assets/images/mpesa-logo.png" alt="M-Pesa" height="26" />
                    <div class="text-caption mt-1">M-Pesa</div>
                  </v-card>
                </v-item>
              </v-col>
              <v-col cols="4">
                <v-item v-slot="{ isSelected, toggle }" value="wallet">
                  <v-card
                    rounded="lg" variant="outlined" class="pa-2 text-center method-card"
                    :class="{ 'method-card--active': isSelected }" @click="toggle"
                  >
                    <v-icon size="26" color="success">mdi-wallet</v-icon>
                    <div class="text-caption mt-1">Wallet</div>
                    <div class="text-caption text-medium-emphasis">{{ formatMoney(data.wallet_balance, data.currency) }}</div>
                  </v-card>
                </v-item>
              </v-col>
              <v-col cols="4">
                <v-item v-slot="{ isSelected, toggle }" value="coins">
                  <v-card
                    rounded="lg" variant="outlined" class="pa-2 text-center method-card"
                    :class="{ 'method-card--active': isSelected }" @click="toggle"
                  >
                    <v-icon size="26" color="teal">mdi-circle-multiple</v-icon>
                    <div class="text-caption mt-1">Coins</div>
                    <div class="text-caption text-medium-emphasis">{{ fmt(data.coin_balance) }}</div>
                  </v-card>
                </v-item>
              </v-col>
            </v-row>
          </v-item-group>

          <v-text-field
            v-if="payMethod !== 'coins'"
            v-model.number="payAmount"
            type="number"
            label="Amount to pay"
            variant="outlined"
            density="comfortable"
            :prefix="payTarget.currency"
            :hint="`You can pay part of the balance (max ${formatMoney(billBalance, payTarget.currency)})`"
            persistent-hint
            class="mb-2"
          />
          <v-alert v-else type="info" variant="tonal" density="compact" class="mb-2">
            The full bill balance will be settled from your coin balance.
          </v-alert>

          <v-text-field
            v-if="payMethod === 'mpesa'"
            v-model="payPhone"
            label="M-Pesa phone number"
            variant="outlined"
            density="comfortable"
            placeholder="07XXXXXXXX"
            prepend-inner-icon="mdi-cellphone"
          />

          <v-alert
            v-if="payMethod === 'wallet' && Number(data.wallet_balance) < Number(payAmount || 0)"
            type="warning" variant="tonal" density="compact" class="mt-1"
          >
            Insufficient wallet balance. Add funds or choose another method.
          </v-alert>
          <v-alert
            v-if="payMethod === 'coins' && Number(data.coin_balance) < Number(billBalance)"
            type="warning" variant="tonal" density="compact" class="mt-1"
          >
            Insufficient coins. Earn more Adhere Coins by referring other facilities.
          </v-alert>
          <v-alert v-if="payError" type="error" variant="tonal" density="compact" class="mt-3">{{ payError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="paying" :disabled="!canPay" @click="confirmPay">
            {{ payMethod === 'mpesa' ? 'Send M-Pesa request' : 'Confirm payment' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Add funds dialog -->
    <v-dialog v-model="fundsDialog" max-width="460" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="success">mdi-wallet-plus</v-icon>
          Add funds to wallet
        </v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-3">
            Top up your AdhereMed wallet via M-Pesa and use the balance to pay future bills.
          </p>
          <div class="d-flex align-center mb-4">
            <img src="~/assets/images/mpesa-logo.png" alt="M-Pesa" height="28" class="mr-2" />
            <span class="text-body-2">Lipa na M-Pesa</span>
          </div>
          <v-text-field
            v-model.number="fundsAmount"
            type="number"
            label="Amount"
            variant="outlined"
            density="comfortable"
            :prefix="data?.currency || 'KSH'"
            class="mb-2"
          />
          <v-text-field
            v-model="fundsPhone"
            label="M-Pesa phone number"
            variant="outlined"
            density="comfortable"
            placeholder="07XXXXXXXX"
            prepend-inner-icon="mdi-cellphone"
          />
          <v-alert v-if="fundsError" type="error" variant="tonal" density="compact" class="mt-2">{{ fundsError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="fundsDialog = false">Cancel</v-btn>
          <v-btn color="success" :loading="paying" :disabled="!(fundsAmount > 0 && fundsPhone)" @click="confirmAddFunds">
            Send M-Pesa request
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- M-Pesa processing overlay -->
    <v-dialog v-model="mpesa.dialog" max-width="440" persistent>
      <v-card rounded="lg" class="text-center pa-2">
        <v-card-text class="pa-6">
          <img src="~/assets/images/mpesa-logo.png" alt="M-Pesa" height="40" class="mb-4" />

          <template v-if="mpesa.state === 'processing'">
            <v-progress-circular indeterminate color="success" size="64" width="5" class="mb-4" />
            <div class="text-h6 font-weight-bold mb-1">Awaiting your confirmation</div>
            <p class="text-body-2 text-medium-emphasis mb-2">
              Check your phone and enter your M-Pesa PIN to authorise the payment.
            </p>
            <v-chip color="warning" variant="tonal" size="small" class="mb-3">
              <v-icon start size="16">mdi-alert</v-icon>
              Please do not close or leave this page
            </v-chip>
            <v-progress-linear :model-value="(mpesa.elapsed / mpesa.timeout) * 100" color="success" height="6" rounded class="mb-1" />
            <div class="text-caption text-medium-emphasis">{{ mpesa.timeout - mpesa.elapsed }}s remaining</div>
          </template>

          <template v-else-if="mpesa.state === 'success'">
            <v-icon color="success" size="72" class="mb-3">mdi-check-circle</v-icon>
            <div class="text-h6 font-weight-bold mb-1">Payment successful</div>
            <p class="text-body-2 text-medium-emphasis">{{ mpesa.message }}</p>
          </template>

          <template v-else-if="mpesa.state === 'failed'">
            <v-icon color="error" size="72" class="mb-3">mdi-close-circle</v-icon>
            <div class="text-h6 font-weight-bold mb-1">Payment not completed</div>
            <p class="text-body-2 text-medium-emphasis">{{ mpesa.message }}</p>
          </template>
        </v-card-text>
        <v-card-actions v-if="mpesa.state !== 'processing'">
          <v-spacer />
          <v-btn color="teal" variant="flat" @click="closeMpesa">Done</v-btn>
          <v-spacer />
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { formatDate, formatDateTime, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const data = ref(null)
const loading = ref(false)
const error = ref(null)
const toast = ref(null)

// Pay dialog
const payDialog = ref(false)
const payTarget = ref(null)
const payMethod = ref('mpesa')
const payAmount = ref(0)
const payPhone = ref('')
const paying = ref(false)
const payError = ref(null)

// Add funds dialog
const fundsDialog = ref(false)
const fundsAmount = ref(0)
const fundsPhone = ref('')
const fundsError = ref(null)

// M-Pesa processing state
const mpesa = reactive({
  dialog: false,
  state: 'processing', // processing | success | failed
  message: '',
  txnId: null,
  elapsed: 0,
  timeout: 60,
  interval: 6,
})
let pollTimer = null
let tickTimer = null
let pollCancelled = false

const summary = computed(() => data.value?.summary || {})
const billBalance = computed(() => Number(payTarget.value?.balance ?? payTarget.value?.amount ?? 0))
const activeTab = ref('outstanding')

const canPay = computed(() => {
  if (payMethod.value === 'coins') return Number(data.value?.coin_balance) >= billBalance.value
  if (!(payAmount.value > 0)) return false
  if (payMethod.value === 'wallet') return Number(data.value?.wallet_balance) >= Number(payAmount.value)
  if (payMethod.value === 'mpesa') return !!payPhone.value
  return false
})

const outHeaders = [
  { title: 'Period', key: 'period' },
  { title: 'Amount', key: 'amount' },
  { title: 'Balance', key: 'balance' },
  { title: 'Due date', key: 'due_date' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
const paidHeaders = [
  { title: 'Period', key: 'period' },
  { title: 'Amount', key: 'amount' },
  { title: 'Paid on', key: 'paid_at' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
const mpesaHeaders = [
  { title: 'Date', key: 'created_at' },
  { title: 'Purpose', key: 'purpose' },
  { title: 'Phone', key: 'phone' },
  { title: 'Amount', key: 'amount' },
  { title: 'Status', key: 'status' }
]
const walletHeaders = [
  { title: 'Date', key: 'created_at' },
  { title: 'Reason', key: 'reason' },
  { title: 'Amount', key: 'amount', align: 'end' },
  { title: 'Balance', key: 'balance_after', align: 'end' }
]

function fmt(v) {
  if (v == null) return '—'
  return Number(v).toLocaleString()
}

function openPay(bill) {
  payTarget.value = bill
  payError.value = null
  payMethod.value = 'mpesa'
  payAmount.value = Number(bill.balance ?? bill.amount ?? 0)
  payPhone.value = data.value?.phone || ''
  payDialog.value = true
}

function openAddFunds() {
  fundsError.value = null
  fundsAmount.value = 0
  fundsPhone.value = data.value?.phone || ''
  fundsDialog.value = true
}

async function confirmPay() {
  paying.value = true
  payError.value = null
  try {
    if (payMethod.value === 'coins') {
      const { data: res } = await $api.post('/usage-billing/referral/redeem/pay-bill/', { bill_id: payTarget.value.id })
      payDialog.value = false
      toast.value = res?.detail || 'Bill paid successfully.'
      await load()
    } else if (payMethod.value === 'wallet') {
      const { data: res } = await $api.post('/usage-billing/payments/wallet/pay-bill/', {
        bill_id: payTarget.value.id,
        amount: payAmount.value,
      })
      payDialog.value = false
      toast.value = res?.detail || 'Bill paid from wallet.'
      await load()
    } else {
      // M-Pesa
      await startMpesa({
        purpose: 'bill',
        bill_id: payTarget.value.id,
        amount: payAmount.value,
        phone: payPhone.value,
      })
      payDialog.value = false
    }
  } catch (e) {
    payError.value = e?.response?.data?.detail || e.message || 'Payment failed.'
  } finally {
    paying.value = false
  }
}

async function confirmAddFunds() {
  paying.value = true
  fundsError.value = null
  try {
    await startMpesa({
      purpose: 'wallet',
      amount: fundsAmount.value,
      phone: fundsPhone.value,
    })
    fundsDialog.value = false
  } catch (e) {
    fundsError.value = e?.response?.data?.detail || e.message || 'Could not start payment.'
  } finally {
    paying.value = false
  }
}

async function startMpesa({ purpose, bill_id, amount, phone }) {
  // Initiate STK push
  const { data: res } = await $api.post('/usage-billing/payments/mpesa/initiate/', {
    purpose, bill_id, amount, phone,
  })
  mpesa.txnId = res.transaction_id
  mpesa.timeout = res.timeout_seconds || 60
  mpesa.interval = res.poll_interval_seconds || 6
  mpesa.elapsed = 0
  mpesa.state = 'processing'
  mpesa.message = res.detail || ''
  mpesa.dialog = true
  pollCancelled = false
  startTicker()
  schedulePoll(mpesa.interval * 1000)
}

function startTicker() {
  clearInterval(tickTimer)
  tickTimer = setInterval(() => {
    if (mpesa.state === 'processing') mpesa.elapsed = Math.min(mpesa.elapsed + 1, mpesa.timeout)
  }, 1000)
}

function schedulePoll(delay) {
  clearTimeout(pollTimer)
  pollTimer = setTimeout(pollMpesa, delay)
}

async function pollMpesa() {
  if (pollCancelled) return
  try {
    const { data: res } = await $api.post('/usage-billing/payments/mpesa/confirm/', {
      transaction_id: mpesa.txnId,
    })
    if (res.status === 'success') {
      mpesa.state = 'success'
      mpesa.message = res.detail || 'Payment confirmed.'
      stopTimers()
      await load()
      return
    }
    if (res.status === 'failed') {
      mpesa.state = 'failed'
      mpesa.message = res.detail || 'Payment failed.'
      stopTimers()
      return
    }
    // pending — keep polling until timeout
    if (mpesa.elapsed >= mpesa.timeout) {
      mpesa.state = 'failed'
      mpesa.message = 'Payment timed out. If you were charged, it will reflect shortly — please refresh.'
      stopTimers()
      return
    }
    schedulePoll(mpesa.interval * 1000)
  } catch (e) {
    if (mpesa.elapsed >= mpesa.timeout) {
      mpesa.state = 'failed'
      mpesa.message = e?.response?.data?.detail || 'Payment timed out.'
      stopTimers()
      return
    }
    schedulePoll(mpesa.interval * 1000)
  }
}

function stopTimers() {
  pollCancelled = true
  clearTimeout(pollTimer)
  clearInterval(tickTimer)
}

function closeMpesa() {
  stopTimers()
  mpesa.dialog = false
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data: res } = await $api.get('/usage-billing/payments/')
    data.value = res
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load payments.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
onBeforeUnmount(stopTimers)
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: calc(100vh - 64px);
}
:global(.v-theme--dark .hc-bg) {
  background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
}
.method-card {
  cursor: pointer;
  transition: border-color 0.15s ease, background-color 0.15s ease;
}
.method-card--active {
  border-color: rgb(var(--v-theme-primary));
  background-color: rgba(var(--v-theme-primary), 0.06);
}
</style>
