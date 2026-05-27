<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center mb-6">
      <img src="~/assets/images/adhere_coin.png" alt="Adhere Coin" width="40" height="40" class="mr-3" />
      <div>
        <h1 class="text-h5 font-weight-bold">Adhere Coin Referral Program</h1>
        <p class="text-body-2 text-medium-emphasis">Invite pharmacies to earn Adhere Coins</p>
      </div>
      <v-spacer />
      <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load">{{ $t('common.refresh') }}</v-btn>
    </div>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4" closable @click:close="error = ''">{{ error }}</v-alert>

    <!-- ── Coin Balance Hero Card ── -->
    <v-card rounded="xl" class="mb-6 coin-hero-card overflow-hidden">
      <div class="coin-hero-bg" />
      <v-card-text class="d-flex flex-wrap align-center ga-6 pa-6 position-relative" style="z-index:1;">
        <div class="coin-icon-wrapper">
          <img src="~/assets/images/adhere_coin.png" alt="Adhere Coin" width="72" height="72" class="coin-spin" />
        </div>
        <div class="flex-grow-1">
          <div class="text-overline text-medium-emphasis mb-1">Your Balance</div>
          <div class="text-h3 font-weight-black">{{ formatCoins(profile.coin_balance) }}</div>
          <div class="text-body-2 text-medium-emphasis">Adhere Coins</div>
        </div>
        <div class="d-flex ga-4 flex-wrap">
          <div class="text-center">
            <div class="text-h6 font-weight-bold text-success">{{ formatCoins(profile.total_earned) }}</div>
            <div class="text-caption text-medium-emphasis">Total Earned</div>
          </div>
          <div class="text-center">
            <div class="text-h6 font-weight-bold text-info">{{ formatCoins(profile.total_redeemed) }}</div>
            <div class="text-caption text-medium-emphasis">Redeemed</div>
          </div>
          <div class="text-center">
            <div class="text-h6 font-weight-bold text-primary">{{ profile.referral_count }}</div>
            <div class="text-caption text-medium-emphasis">Referrals</div>
          </div>
        </div>
      </v-card-text>
    </v-card>

    <v-row>
      <!-- ── Referral Code & Share ── -->
      <v-col cols="12" md="5">
        <v-card rounded="xl" class="fill-height">
          <v-card-title class="d-flex align-center ga-2">
            <v-icon color="primary">mdi-link-variant</v-icon>
            Invite &amp; Earn
          </v-card-title>
          <v-card-text>
            <p class="text-body-2 text-medium-emphasis mb-4">
              Share your unique referral code or link. Earn <strong>100 Adhere Coins</strong> when a new pharmacy
              signs up with your code, plus <strong>1 coin per 1,000 API requests</strong> they make.
            </p>

            <!-- Code -->
            <div class="text-overline mb-1">Your Referral Code</div>
            <v-sheet rounded="lg" color="surface-variant" class="pa-3 mb-4 d-flex align-center">
              <span class="text-h5 font-weight-bold font-mono flex-grow-1 text-center letter-spaced">
                {{ profile.referral_code }}
              </span>
              <v-btn icon variant="text" size="small" @click="copyCode">
                <v-icon>{{ copied === 'code' ? 'mdi-check' : 'mdi-content-copy' }}</v-icon>
              </v-btn>
            </v-sheet>

            <!-- Link -->
            <div class="text-overline mb-1">Referral Link</div>
            <v-sheet rounded="lg" color="surface-variant" class="pa-3 mb-4 d-flex align-center">
              <span class="text-body-2 text-truncate flex-grow-1">{{ referralLink }}</span>
              <v-btn icon variant="text" size="small" @click="copyLink">
                <v-icon>{{ copied === 'link' ? 'mdi-check' : 'mdi-content-copy' }}</v-icon>
              </v-btn>
            </v-sheet>

            <!-- Share Buttons -->
            <div class="d-flex ga-2 flex-wrap">
              <v-btn
                variant="tonal"
                color="success"
                size="small"
                prepend-icon="mdi-whatsapp"
                @click="shareWhatsApp"
              >WhatsApp</v-btn>
              <v-btn
                variant="tonal"
                color="info"
                size="small"
                prepend-icon="mdi-email-outline"
                @click="shareEmail"
              >Email</v-btn>
              <v-btn
                variant="tonal"
                size="small"
                prepend-icon="mdi-share-variant"
                @click="shareNative"
              >Share</v-btn>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ── How It Works ── -->
      <v-col cols="12" md="7">
        <v-card rounded="xl" class="fill-height">
          <v-card-title class="d-flex align-center ga-2">
            <v-icon color="primary">mdi-rocket-launch</v-icon>
            How It Works
          </v-card-title>
          <v-card-text>
            <v-timeline side="end" density="compact" line-color="primary">
              <v-timeline-item dot-color="primary" icon="mdi-share-variant" size="small">
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Share Your Code</div>
                  <div class="text-body-2 text-medium-emphasis">Send your unique code or link to other pharmacies</div>
                </div>
              </v-timeline-item>
              <v-timeline-item dot-color="success" icon="mdi-account-plus" size="small">
                <div>
                  <div class="text-subtitle-2 font-weight-bold">They Sign Up</div>
                  <div class="text-body-2 text-medium-emphasis">The pharmacy enters your code during registration</div>
                </div>
              </v-timeline-item>
              <v-timeline-item dot-color="warning" icon="mdi-star-circle" size="small">
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Earn 100 Coins Instantly</div>
                  <div class="text-body-2 text-medium-emphasis">You receive 100 Adhere Coins as a referral bonus</div>
                </div>
              </v-timeline-item>
              <v-timeline-item dot-color="info" icon="mdi-chart-line" size="small">
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Keep Earning</div>
                  <div class="text-body-2 text-medium-emphasis">Earn 1 coin for every 1,000 API requests they make</div>
                </div>
              </v-timeline-item>
            </v-timeline>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Redeem Section ── -->
    <v-card rounded="xl" class="mt-6">
      <v-card-title class="d-flex align-center ga-2">
        <v-icon color="warning">mdi-cash-multiple</v-icon>
        Redeem Adhere Coins
      </v-card-title>
      <v-card-text>
        <v-row dense>
          <v-col cols="12" sm="6" md="3">
            <v-card variant="outlined" rounded="lg" class="pa-3 text-center">
              <v-icon size="32" color="warning" class="mb-2">mdi-cash</v-icon>
              <div class="text-subtitle-2">Cash Out</div>
              <div class="text-caption text-medium-emphasis mb-2">Convert coins to KSH</div>
              <v-btn size="small" color="warning" variant="tonal" disabled>Coming Soon</v-btn>
            </v-card>
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-card variant="outlined" rounded="lg" class="pa-3 text-center">
              <v-icon size="32" color="primary" class="mb-2">mdi-receipt-text</v-icon>
              <div class="text-subtitle-2">Pay API Bill</div>
              <div class="text-caption text-medium-emphasis mb-2">Settle usage billing</div>
              <v-btn size="small" color="primary" variant="tonal" @click="openPayBill">Apply</v-btn>
            </v-card>
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-card variant="outlined" rounded="lg" class="pa-3 text-center">
              <v-icon size="32" color="success" class="mb-2">mdi-gift</v-icon>
              <div class="text-subtitle-2">Gift Coins</div>
              <div class="text-caption text-medium-emphasis mb-2">Send to another pharmacy</div>
              <v-btn size="small" color="success" variant="tonal" @click="giftDialog = true">Send</v-btn>
            </v-card>
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-card variant="outlined" rounded="lg" class="pa-3 text-center">
              <v-icon size="32" color="secondary" class="mb-2">mdi-ticket-percent</v-icon>
              <div class="text-subtitle-2">Discounts</div>
              <div class="text-caption text-medium-emphasis mb-2">Unlock premium features</div>
              <v-btn size="small" color="secondary" variant="tonal" disabled>Coming Soon</v-btn>
            </v-card>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- ── Pay API Bill Dialog ── -->
    <v-dialog v-model="payBillDialog" max-width="500" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center ga-2">
          <v-icon color="primary">mdi-receipt-text</v-icon>
          Pay API Bill with Adhere Coins
        </v-card-title>
        <v-card-text>
          <v-alert v-if="payBillError" type="error" variant="tonal" density="compact" class="mb-3" closable @click:close="payBillError = ''">{{ payBillError }}</v-alert>
          <v-alert v-if="payBillSuccess" type="success" variant="tonal" density="compact" class="mb-3">{{ payBillSuccess }}</v-alert>

          <div v-if="!outstandingBills.length && !loadingBills" class="text-center py-4">
            <v-icon size="48" color="success" class="mb-2">mdi-check-circle</v-icon>
            <div class="text-body-1 font-weight-medium">No outstanding bills!</div>
            <div class="text-body-2 text-medium-emphasis">All your API usage bills are paid.</div>
          </div>

          <div v-if="loadingBills" class="text-center py-4">
            <v-progress-circular indeterminate color="primary" />
          </div>

          <template v-if="outstandingBills.length">
            <div class="text-body-2 text-medium-emphasis mb-3">
              Your balance: <strong>{{ formatCoins(profile.coin_balance) }} coins</strong> (1 coin = 1 KSH)
            </div>
            <v-radio-group v-model="selectedBillId" class="mb-3">
              <v-radio
                v-for="bill in outstandingBills"
                :key="bill.id"
                :value="bill.id"
                :label="`${bill.year}-${String(bill.month).padStart(2,'0')} — ${Number(bill.amount).toLocaleString()} KSH`"
              />
            </v-radio-group>
            <v-text-field
              v-model.number="payAmount"
              type="number"
              label="Coins to apply (leave empty for full amount)"
              variant="outlined"
              density="compact"
              rounded="lg"
              hide-details
              class="mb-2"
              :placeholder="selectedBillAmount"
            />
          </template>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="closePayBill">Cancel</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            :disabled="!selectedBillId || payBillLoading"
            :loading="payBillLoading"
            @click="submitPayBill"
          >Pay with Coins</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Gift Coins Dialog ── -->
    <v-dialog v-model="giftDialog" max-width="480" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center ga-2">
          <v-icon color="success">mdi-gift</v-icon>
          Gift Adhere Coins
        </v-card-title>
        <v-card-text>
          <v-alert v-if="giftError" type="error" variant="tonal" density="compact" class="mb-3" closable @click:close="giftError = ''">{{ giftError }}</v-alert>
          <v-alert v-if="giftSuccess" type="success" variant="tonal" density="compact" class="mb-3">{{ giftSuccess }}</v-alert>

          <div class="text-body-2 text-medium-emphasis mb-3">
            Your balance: <strong>{{ formatCoins(profile.coin_balance) }} coins</strong>
          </div>

          <v-text-field
            v-model="giftCode"
            label="Recipient's Referral Code"
            variant="outlined"
            density="compact"
            rounded="lg"
            prepend-inner-icon="mdi-store"
            class="mb-3"
            :hint="giftRecipientName ? `Pharmacy: ${giftRecipientName}` : ''"
            persistent-hint
            @blur="validateGiftCode"
          />
          <v-text-field
            v-model.number="giftAmount"
            type="number"
            label="Amount (coins)"
            variant="outlined"
            density="compact"
            rounded="lg"
            prepend-inner-icon="mdi-currency-usd"
            class="mb-3"
            :max="Number(profile.coin_balance)"
            :rules="[v => !v || v <= Number(profile.coin_balance) || `Max ${formatCoins(profile.coin_balance)} coins`]"
            :hint="`Available: ${formatCoins(profile.coin_balance)} coins`"
            persistent-hint
            @update:model-value="v => { if (v > Number(profile.coin_balance)) giftAmount = Number(profile.coin_balance) }"
          />
          <v-text-field
            v-model="giftMessage"
            label="Message (optional)"
            variant="outlined"
            density="compact"
            rounded="lg"
            prepend-inner-icon="mdi-message-text"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="closeGift">Cancel</v-btn>
          <v-btn
            color="success"
            variant="flat"
            :disabled="!giftCode || !giftAmount || giftAmount <= 0 || giftLoading"
            :loading="giftLoading"
            @click="submitGift"
          >Send Coins</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Referred Pharmacies Table ── -->
    <v-card rounded="xl" class="mt-6">
      <v-card-title class="d-flex align-center ga-2">
        <v-icon color="primary">mdi-account-group</v-icon>
        Your Referrals
        <v-chip size="small" color="primary" variant="tonal" class="ml-2">{{ referrals.length }}</v-chip>
      </v-card-title>
      <v-card-text v-if="referrals.length === 0">
        <v-empty-state
          icon="mdi-account-multiple-plus"
          title="No referrals yet"
          text="Share your referral code with other pharmacies to start earning Adhere Coins!"
        />
      </v-card-text>
      <v-data-table
        v-else
        :items="referrals"
        :headers="referralHeaders"
        density="comfortable"
        class="rounded-b-xl"
        :items-per-page="10"
      >
        <template #item.status="{ item }">
          <v-chip
            :color="item.status === 'active' ? 'success' : item.status === 'pending' ? 'warning' : 'default'"
            size="small"
            variant="tonal"
          >{{ item.status }}</v-chip>
        </template>
        <template #item.tracked_requests="{ item }">
          {{ Number(item.tracked_requests).toLocaleString() }}
        </template>
        <template #item.coins_from_usage="{ item }">
          <div class="d-flex align-center ga-1">
            <img src="~/assets/images/adhere_coin.png" width="16" height="16" />
            {{ formatCoins(item.coins_from_usage) }}
          </div>
        </template>
        <template #item.created_at="{ item }">
          {{ new Date(item.created_at).toLocaleDateString() }}
        </template>
      </v-data-table>
    </v-card>

    <!-- ── Transaction History ── -->
    <v-card rounded="xl" class="mt-6">
      <v-card-title class="d-flex align-center ga-2">
        <v-icon color="primary">mdi-history</v-icon>
        Transaction History
      </v-card-title>
      <v-card-text v-if="transactions.length === 0">
        <v-empty-state
          icon="mdi-swap-horizontal"
          title="No transactions yet"
          text="Your Adhere Coin transactions will appear here."
        />
      </v-card-text>
      <v-data-table
        v-else
        :items="transactions"
        :headers="txHeaders"
        density="comfortable"
        class="rounded-b-xl"
        :items-per-page="10"
      >
        <template #item.type="{ item }">
          <v-chip
            :color="txColor(item.type)"
            size="small"
            variant="tonal"
            :prepend-icon="txIcon(item.type)"
          >{{ item.type }}</v-chip>
        </template>
        <template #item.amount="{ item }">
          <span :class="['earned','bonus'].includes(item.type) ? 'text-success' : 'text-error'">
            {{ ['earned','bonus'].includes(item.type) ? '+' : '-' }}{{ formatCoins(item.amount) }}
          </span>
        </template>
        <template #item.created_at="{ item }">
          {{ new Date(item.created_at).toLocaleString() }}
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

const loading = ref(false)
const error = ref('')
const copied = ref('')
const profile = ref({
  referral_code: '',
  coin_balance: '0.00',
  total_earned: '0.00',
  total_redeemed: '0.00',
  referral_count: 0,
})
const referrals = ref([])
const transactions = ref([])
const referralLink = ref('')

const referralHeaders = [
  { title: 'Pharmacy', key: 'referred_name' },
  { title: 'Status', key: 'status' },
  { title: 'API Requests', key: 'tracked_requests' },
  { title: 'Coins Earned', key: 'coins_from_usage' },
  { title: 'Joined', key: 'created_at' },
]

const txHeaders = [
  { title: 'Type', key: 'type' },
  { title: 'Amount', key: 'amount' },
  { title: 'Reason', key: 'reason' },
  { title: 'Related', key: 'related_tenant_name' },
  { title: 'Date', key: 'created_at' },
]

function formatCoins(val) {
  return Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}

function txColor(type) {
  return { earned: 'success', bonus: 'warning', redeemed: 'info', adjustment: 'secondary' }[type] || 'default'
}

function txIcon(type) {
  return { earned: 'mdi-arrow-down', bonus: 'mdi-star', redeemed: 'mdi-arrow-up', adjustment: 'mdi-tune' }[type] || 'mdi-swap-horizontal'
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data } = await $api.get('/usage-billing/referral/dashboard/')
    profile.value = data.profile || profile.value
    referrals.value = data.referrals || []
    transactions.value = data.transactions || []
    referralLink.value = data.referral_link || ''
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load referral data'
  } finally {
    loading.value = false
  }
}

function copyCode() {
  navigator.clipboard.writeText(profile.value.referral_code)
  copied.value = 'code'
  setTimeout(() => (copied.value = ''), 2000)
}

function copyLink() {
  navigator.clipboard.writeText(referralLink.value)
  copied.value = 'link'
  setTimeout(() => (copied.value = ''), 2000)
}

function shareWhatsApp() {
  const msg = encodeURIComponent(
    `Join AdhereMed using my referral code: ${profile.value.referral_code}\n\n${referralLink.value}`
  )
  window.open(`https://wa.me/?text=${msg}`, '_blank')
}

function shareEmail() {
  const subject = encodeURIComponent('Join AdhereMed — Pharmacy Management Platform')
  const body = encodeURIComponent(
    `I'd like to invite you to AdhereMed!\n\nUse my referral code: ${profile.value.referral_code}\n\nSign up here: ${referralLink.value}`
  )
  window.open(`mailto:?subject=${subject}&body=${body}`)
}

async function shareNative() {
  if (navigator.share) {
    try {
      await navigator.share({
        title: 'Join AdhereMed',
        text: `Use my referral code: ${profile.value.referral_code}`,
        url: referralLink.value,
      })
    } catch { /* user cancelled */ }
  } else {
    copyLink()
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Pay API Bill
// ═══════════════════════════════════════════════════════════════════════
const payBillDialog = ref(false)
const loadingBills = ref(false)
const outstandingBills = ref([])
const selectedBillId = ref(null)
const payAmount = ref(null)
const payBillLoading = ref(false)
const payBillError = ref('')
const payBillSuccess = ref('')

const selectedBillAmount = computed(() => {
  const b = outstandingBills.value.find(x => x.id === selectedBillId.value)
  return b ? String(Math.ceil(Number(b.amount))) : ''
})

async function openPayBill() {
  payBillDialog.value = true
  payBillError.value = ''
  payBillSuccess.value = ''
  selectedBillId.value = null
  payAmount.value = null
  loadingBills.value = true
  try {
    const { data } = await $api.get('/usage-billing/dashboard/')
    outstandingBills.value = (data.bills || []).filter(b => b.status === 'ISSUED')
  } catch {
    outstandingBills.value = []
  } finally {
    loadingBills.value = false
  }
}

function closePayBill() {
  payBillDialog.value = false
  payBillError.value = ''
  payBillSuccess.value = ''
}

async function submitPayBill() {
  payBillLoading.value = true
  payBillError.value = ''
  payBillSuccess.value = ''
  try {
    const payload = { bill_id: selectedBillId.value }
    if (payAmount.value) payload.amount = payAmount.value
    const { data } = await $api.post('/usage-billing/referral/redeem/pay-bill/', payload)
    payBillSuccess.value = data.detail
    profile.value.coin_balance = data.remaining_balance
    // Remove paid bill from list
    outstandingBills.value = outstandingBills.value.filter(b => b.id !== selectedBillId.value)
    selectedBillId.value = null
    payAmount.value = null
    load() // refresh transactions
  } catch (e) {
    payBillError.value = e?.response?.data?.detail || 'Payment failed'
  } finally {
    payBillLoading.value = false
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Gift Coins
// ═══════════════════════════════════════════════════════════════════════
const giftDialog = ref(false)
const giftCode = ref('')
const giftAmount = ref(null)
const giftMessage = ref('')
const giftRecipientName = ref('')
const giftLoading = ref(false)
const giftError = ref('')
const giftSuccess = ref('')

async function validateGiftCode() {
  giftRecipientName.value = ''
  const code = (giftCode.value || '').trim()
  if (code.length < 4) return
  try {
    const { data } = await $api.get(`/usage-billing/referral/validate/${code}/`)
    if (data.valid) giftRecipientName.value = data.referrer_name
  } catch { /* silent */ }
}

function closeGift() {
  giftDialog.value = false
  giftError.value = ''
  giftSuccess.value = ''
  giftCode.value = ''
  giftAmount.value = null
  giftMessage.value = ''
  giftRecipientName.value = ''
}

async function submitGift() {
  giftLoading.value = true
  giftError.value = ''
  giftSuccess.value = ''
  try {
    const { data } = await $api.post('/usage-billing/referral/redeem/gift/', {
      recipient_code: giftCode.value.trim(),
      amount: giftAmount.value,
      message: giftMessage.value,
    })
    giftSuccess.value = data.detail
    profile.value.coin_balance = data.remaining_balance
    giftCode.value = ''
    giftAmount.value = null
    giftMessage.value = ''
    giftRecipientName.value = ''
    load() // refresh transactions
  } catch (e) {
    giftError.value = e?.response?.data?.detail || 'Gift failed'
  } finally {
    giftLoading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.coin-hero-card {
  position: relative;
  background: linear-gradient(135deg, rgb(var(--v-theme-primary), 0.08), rgb(var(--v-theme-warning), 0.08));
}
.coin-hero-bg {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at 90% 20%, rgba(255,193,7,0.15) 0%, transparent 50%);
  pointer-events: none;
}
.coin-icon-wrapper {
  background: rgba(255,193,7,0.12);
  border-radius: 50%;
  padding: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
}
@keyframes coinSpin {
  0% { transform: rotateY(0deg); }
  100% { transform: rotateY(360deg); }
}
.coin-spin {
  animation: coinSpin 3s ease-in-out infinite;
}
.letter-spaced {
  letter-spacing: 0.3em;
}
.font-mono {
  font-family: 'JetBrains Mono', 'Fira Code', monospace;
}
</style>
