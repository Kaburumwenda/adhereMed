<template>
  <div class="lock-bg pa-4 pa-md-6">
    <div class="mx-auto" style="max-width: 960px;">
      <!-- Restricted banner -->
      <v-card rounded="xl" color="error" variant="flat" class="pa-5 mb-4 text-white">
        <div class="d-flex align-center flex-wrap ga-3">
          <v-icon icon="mdi-lock-alert" size="44" />
          <div class="flex-grow-1" style="min-width: 220px;">
            <div class="text-overline" style="opacity:.85">Service restricted</div>
            <h1 class="text-h5 font-weight-bold ma-0">Clear your bills to continue</h1>
            <div class="text-body-2 mt-1" style="opacity:.9">
              {{ statusReason || 'Your account has overdue API usage bills. Settle them to restore access for your team.' }}
            </div>
          </div>
          <div class="text-right">
            <div class="text-caption" style="opacity:.85">Overdue balance</div>
            <div class="text-h4 font-weight-bold">{{ money(summary.total_overdue || overdueTotal) }}</div>
          </div>
        </div>
      </v-card>

      <v-alert v-if="toast" type="success" variant="tonal" class="mb-4" closable @click:close="toast = null">{{ toast }}</v-alert>
      <v-alert v-if="error" type="error" variant="tonal" class="mb-4" closable @click:close="error = null">{{ error }}</v-alert>

      <div v-if="data">
        <!-- Balances -->
        <v-row dense class="mb-1">
          <v-col cols="6" md="3">
            <v-card rounded="lg" class="pa-3">
              <div class="text-caption text-medium-emphasis">Outstanding</div>
              <div class="text-h6 font-weight-bold">{{ money(summary.total_outstanding) }}</div>
              <div class="text-caption text-medium-emphasis">{{ summary.outstanding_count }} bill(s)</div>
            </v-card>
          </v-col>
          <v-col cols="6" md="3">
            <v-card rounded="lg" class="pa-3" color="error" variant="tonal">
              <div class="text-caption text-medium-emphasis">Overdue</div>
              <div class="text-h6 font-weight-bold">{{ money(summary.total_overdue) }}</div>
              <div class="text-caption text-medium-emphasis">{{ summary.overdue_count }} overdue</div>
            </v-card>
          </v-col>
          <v-col cols="6" md="3">
            <v-card rounded="lg" class="pa-3" color="success" variant="tonal">
              <div class="text-caption text-medium-emphasis">Wallet</div>
              <div class="text-h6 font-weight-bold">{{ money(data.wallet_balance) }}</div>
            </v-card>
          </v-col>
          <v-col cols="6" md="3">
            <v-card rounded="lg" class="pa-3" color="primary" variant="tonal">
              <div class="text-caption text-medium-emphasis">Adhere Coins</div>
              <div class="text-h6 font-weight-bold">{{ fmt(data.coin_balance) }}</div>
            </v-card>
          </v-col>
        </v-row>

        <!-- Bills to clear -->
        <v-card rounded="xl" class="mb-4">
          <v-card-title class="d-flex align-center">
            <v-icon class="mr-2" color="error">mdi-receipt-text-alert</v-icon>
            Bills to clear
            <v-spacer />
            <v-btn size="small" variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="reload">Refresh</v-btn>
          </v-card-title>
          <v-divider />
          <v-list v-if="billsToClear.length" lines="two">
            <template v-for="(b, i) in billsToClear" :key="b.id">
              <v-list-item>
                <template #prepend>
                  <v-avatar :color="b.is_overdue ? 'error' : 'warning'" variant="tonal">
                    <v-icon :icon="b.is_overdue ? 'mdi-alert' : 'mdi-clock-outline'" />
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">
                  {{ b.period_label || (b.year + '-' + String(b.month).padStart(2,'0')) }}
                  <v-chip size="x-small" variant="tonal" class="ml-1"
                          :color="b.is_overdue ? 'error' : 'warning'">
                    {{ b.effective_status || b.status }}
                  </v-chip>
                </v-list-item-title>
                <v-list-item-subtitle>
                  Balance <strong>{{ money(b.balance ?? b.amount) }}</strong>
                  <span v-if="b.due_date"> · due {{ formatDate(b.due_date) }}</span>
                  <span v-if="Number(b.discount_amount) > 0"> · {{ money(b.discount_amount) }} discount applied</span>
                </v-list-item-subtitle>
                <template #append>
                  <div class="d-flex ga-1">
                    <v-btn size="small" variant="text" prepend-icon="mdi-ticket-percent"
                           @click="openCoupon(b)">Coupon</v-btn>
                    <v-btn size="small" color="primary" variant="flat" prepend-icon="mdi-cash-fast"
                           @click="openPay(b)">Pay</v-btn>
                  </div>
                </template>
              </v-list-item>
              <v-divider v-if="i < billsToClear.length - 1" />
            </template>
          </v-list>
          <div v-else class="text-center py-8">
            <v-icon icon="mdi-check-decagram" color="success" size="48" class="mb-2" />
            <div class="text-h6 font-weight-bold">All bills settled</div>
            <div class="text-medium-emphasis text-body-2">Re-check access to continue.</div>
            <v-btn class="mt-3" color="success" variant="flat" :loading="checking"
                   prepend-icon="mdi-arrow-right" @click="recheck">Continue to app</v-btn>
          </div>
        </v-card>

        <div class="d-flex justify-space-between flex-wrap ga-2">
          <v-btn variant="text" prepend-icon="mdi-refresh" :loading="checking" @click="recheck">
            Re-check access
          </v-btn>
          <v-btn variant="text" prepend-icon="mdi-logout" @click="doLogout">Sign out</v-btn>
        </div>
      </div>

      <v-progress-linear v-else-if="loading" indeterminate color="primary" />
    </div>

    <!-- Pay dialog -->
    <v-dialog v-model="payDialog" max-width="520" persistent>
      <v-card rounded="lg" v-if="payTarget">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-cash-fast</v-icon>
          Pay bill — {{ payTarget.period_label }}
        </v-card-title>
        <v-card-text>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-medium-emphasis">Balance due</span>
            <span class="font-weight-bold text-warning">{{ money(billBalance) }}</span>
          </div>

          <div class="text-caption text-medium-emphasis mb-1">Payment method</div>
          <v-item-group v-model="payMethod" mandatory class="mb-4">
            <v-row dense>
              <v-col cols="4">
                <v-item v-slot="{ isSelected, toggle }" value="mpesa">
                  <v-card rounded="lg" variant="outlined" class="pa-2 text-center method-card"
                          :class="{ 'method-card--active': isSelected }" @click="toggle">
                    <img src="~/assets/images/mpesa-logo.png" alt="M-Pesa" height="26" />
                    <div class="text-caption mt-1">M-Pesa</div>
                  </v-card>
                </v-item>
              </v-col>
              <v-col cols="4">
                <v-item v-slot="{ isSelected, toggle }" value="wallet">
                  <v-card rounded="lg" variant="outlined" class="pa-2 text-center method-card"
                          :class="{ 'method-card--active': isSelected }" @click="toggle">
                    <v-icon size="26" color="success">mdi-wallet</v-icon>
                    <div class="text-caption mt-1">Wallet</div>
                    <div class="text-caption text-medium-emphasis">{{ money(data.wallet_balance) }}</div>
                  </v-card>
                </v-item>
              </v-col>
              <v-col cols="4">
                <v-item v-slot="{ isSelected, toggle }" value="coins">
                  <v-card rounded="lg" variant="outlined" class="pa-2 text-center method-card"
                          :class="{ 'method-card--active': isSelected }" @click="toggle">
                    <v-icon size="26" color="primary">mdi-circle-multiple</v-icon>
                    <div class="text-caption mt-1">Coins</div>
                    <div class="text-caption text-medium-emphasis">{{ fmt(data.coin_balance) }}</div>
                  </v-card>
                </v-item>
              </v-col>
            </v-row>
          </v-item-group>

          <v-text-field v-if="payMethod !== 'coins'" v-model.number="payAmount" type="number" min="0"
                        label="Amount to pay" variant="outlined" density="comfortable" prefix="KSh"
                        :hint="`Max ${money(billBalance)}`" persistent-hint class="mb-2" />
          <v-alert v-else type="info" variant="tonal" density="compact" class="mb-2">
            The full bill balance will be settled from your coin balance.
          </v-alert>

          <v-text-field v-if="payMethod === 'mpesa'" v-model="payPhone" label="M-Pesa phone number"
                        variant="outlined" density="comfortable" placeholder="07XXXXXXXX"
                        prepend-inner-icon="mdi-cellphone" />

          <v-alert v-if="payMethod === 'wallet' && Number(data.wallet_balance) < Number(payAmount || 0)"
                   type="warning" variant="tonal" density="compact" class="mt-1">
            Insufficient wallet balance.
          </v-alert>
          <v-alert v-if="payMethod === 'coins' && Number(data.coin_balance) < Number(billBalance)"
                   type="warning" variant="tonal" density="compact" class="mt-1">
            Insufficient coins.
          </v-alert>
          <v-alert v-if="payError" type="error" variant="tonal" density="compact" class="mt-3">{{ payError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="paying" :disabled="!canPay" @click="confirmPay">
            {{ payMethod === 'mpesa' ? 'Send M-Pesa request' : 'Confirm payment' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Coupon dialog -->
    <v-dialog v-model="couponDialog" max-width="440">
      <v-card rounded="lg" v-if="couponTarget">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-ticket-percent</v-icon>
          Apply coupon / offer
        </v-card-title>
        <v-card-text>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-medium-emphasis">Bill balance</span>
            <span class="font-weight-bold">{{ money(couponTarget.balance ?? couponTarget.amount) }}</span>
          </div>
          <v-text-field v-model="couponCode" label="Coupon code" variant="outlined"
                        density="comfortable" placeholder="e.g. WELCOME20"
                        prepend-inner-icon="mdi-tag" @keyup.enter="applyCoupon" />
          <v-alert v-if="couponError" type="error" variant="tonal" density="compact" class="mt-1">{{ couponError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="couponDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="couponBusy" :disabled="!couponCode" @click="applyCoupon">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- M-Pesa overlay -->
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
          <v-btn color="primary" variant="flat" @click="closeMpesa">Done</v-btn>
          <v-spacer />
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { formatDate } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const auth = useAuthStore()

const data = ref(null)
const statusInfo = ref(null)
const loading = ref(false)
const checking = ref(false)
const error = ref(null)
const toast = ref(null)

const summary = computed(() => data.value?.summary || {})
const statusReason = computed(() => statusInfo.value?.reason || auth.billing?.reason || '')
const overdueTotal = computed(() => auth.overdueTotal)

const billsToClear = computed(() => {
  const out = data.value?.outstanding_bills || []
  // Overdue first, then by oldest period.
  return [...out].sort((a, b) => (b.is_overdue - a.is_overdue)
    || (a.year - b.year) || (a.month - b.month))
})

// ── Pay dialog ──
const payDialog = ref(false)
const payTarget = ref(null)
const payMethod = ref('mpesa')
const payAmount = ref(0)
const payPhone = ref('')
const paying = ref(false)
const payError = ref(null)
const billBalance = computed(() => Number(payTarget.value?.balance ?? payTarget.value?.amount ?? 0))
const canPay = computed(() => {
  if (payMethod.value === 'coins') return Number(data.value?.coin_balance) >= billBalance.value
  if (!(payAmount.value > 0)) return false
  if (payMethod.value === 'wallet') return Number(data.value?.wallet_balance) >= Number(payAmount.value)
  if (payMethod.value === 'mpesa') return !!payPhone.value
  return false
})

// ── Coupon dialog ──
const couponDialog = ref(false)
const couponTarget = ref(null)
const couponCode = ref('')
const couponBusy = ref(false)
const couponError = ref(null)

// ── M-Pesa ──
const mpesa = reactive({ dialog: false, state: 'processing', message: '', txnId: null, elapsed: 0, timeout: 60, interval: 6 })
let pollTimer = null, tickTimer = null, pollCancelled = false

function fmt(v) { return v == null ? '—' : Number(v).toLocaleString() }
function money(v) {
  const n = Number(v || 0)
  return 'KSh ' + n.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}
function homePath() {
  if (auth.tenantType === 'pharmacy') return '/pharmacy'
  if (auth.tenantType === 'lab') return '/lab'
  if (auth.tenantType === 'radiology_center') return '/radiology'
  if (auth.tenantType === 'hospital') return '/hos'
  if (auth.tenantType === 'clinic') return '/clinics'
  if (auth.tenantType === 'inventory') return '/ims'
  return '/dashboard'
}

function openPay(bill) {
  payTarget.value = bill
  payError.value = null
  payMethod.value = 'mpesa'
  payAmount.value = Number(bill.balance ?? bill.amount ?? 0)
  payPhone.value = data.value?.phone || ''
  payDialog.value = true
}
function openCoupon(bill) {
  couponTarget.value = bill
  couponCode.value = ''
  couponError.value = null
  couponDialog.value = true
}

async function applyCoupon() {
  if (!couponCode.value) return
  couponBusy.value = true
  couponError.value = null
  try {
    const { data: res } = await $api.post('/usage-billing/payments/coupon/apply/', {
      bill_id: couponTarget.value.id, code: couponCode.value.trim(),
    })
    couponDialog.value = false
    toast.value = res?.detail || 'Coupon applied.'
    await afterPayment()
  } catch (e) {
    couponError.value = e?.response?.data?.detail || 'Could not apply coupon.'
  } finally {
    couponBusy.value = false
  }
}

async function confirmPay() {
  paying.value = true
  payError.value = null
  try {
    if (payMethod.value === 'coins') {
      const { data: res } = await $api.post('/usage-billing/referral/redeem/pay-bill/', { bill_id: payTarget.value.id })
      payDialog.value = false
      toast.value = res?.detail || 'Bill paid from coins.'
      await afterPayment()
    } else if (payMethod.value === 'wallet') {
      const { data: res } = await $api.post('/usage-billing/payments/wallet/pay-bill/', {
        bill_id: payTarget.value.id, amount: payAmount.value,
      })
      payDialog.value = false
      toast.value = res?.detail || 'Bill paid from wallet.'
      await afterPayment()
    } else {
      await startMpesa({ purpose: 'bill', bill_id: payTarget.value.id, amount: payAmount.value, phone: payPhone.value })
      payDialog.value = false
    }
  } catch (e) {
    payError.value = e?.response?.data?.detail || e.message || 'Payment failed.'
  } finally {
    paying.value = false
  }
}

async function startMpesa({ purpose, bill_id, amount, phone }) {
  const { data: res } = await $api.post('/usage-billing/payments/mpesa/initiate/', { purpose, bill_id, amount, phone })
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
function schedulePoll(delay) { clearTimeout(pollTimer); pollTimer = setTimeout(pollMpesa, delay) }
async function pollMpesa() {
  if (pollCancelled) return
  try {
    const { data: res } = await $api.post('/usage-billing/payments/mpesa/confirm/', { transaction_id: mpesa.txnId })
    if (res.status === 'success') {
      mpesa.state = 'success'; mpesa.message = res.detail || 'Payment confirmed.'
      stopTimers(); await afterPayment(); return
    }
    if (res.status === 'failed') {
      mpesa.state = 'failed'; mpesa.message = res.detail || 'Payment failed.'; stopTimers(); return
    }
    if (mpesa.elapsed >= mpesa.timeout) {
      mpesa.state = 'failed'
      mpesa.message = 'Payment timed out. If you were charged it will reflect shortly — please refresh.'
      stopTimers(); return
    }
    schedulePoll(mpesa.interval * 1000)
  } catch (e) {
    if (mpesa.elapsed >= mpesa.timeout) {
      mpesa.state = 'failed'; mpesa.message = e?.response?.data?.detail || 'Payment timed out.'; stopTimers(); return
    }
    schedulePoll(mpesa.interval * 1000)
  }
}
function stopTimers() { pollCancelled = true; clearTimeout(pollTimer); clearInterval(tickTimer) }
function closeMpesa() { stopTimers(); mpesa.dialog = false }

async function afterPayment() {
  await reload()
  const me = await auth.refresh()
  if (me && !me.billing?.locked) {
    // Access restored — bounce home shortly.
    setTimeout(() => navigateTo(homePath()), 900)
  }
}

async function reload() {
  loading.value = true
  try {
    const [pay, st] = await Promise.all([
      $api.get('/usage-billing/payments/'),
      $api.get('/usage-billing/billing-status/'),
    ])
    data.value = pay.data
    statusInfo.value = st.data
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load billing data.'
  } finally {
    loading.value = false
  }
}

async function recheck() {
  checking.value = true
  try {
    const me = await auth.refresh()
    if (me && !me.billing?.locked) await navigateTo(homePath())
    else { await reload(); toast.value = 'Still restricted — please clear the remaining balance.' }
  } finally {
    checking.value = false
  }
}

async function doLogout() {
  try { await auth.logout?.() } catch {}
  await navigateTo('/welcome')
}

onMounted(reload)
onBeforeUnmount(stopTimers)
</script>

<style scoped>
.lock-bg {
  min-height: 100vh;
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
}
:global(.v-theme--dark) .lock-bg {
  background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
}
.method-card { cursor: pointer; transition: border-color .15s ease, background-color .15s ease; }
.method-card--active { border-color: rgb(var(--v-theme-primary)); background-color: rgba(var(--v-theme-primary), 0.06); }
</style>
