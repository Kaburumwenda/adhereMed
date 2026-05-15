<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center mb-2">
      <img src="~/assets/images/adhere_coin.png" alt="Adhere Coin" width="36" height="36" class="mr-3" />
      <div>
        <h1 class="text-h5 font-weight-bold">Referral Performance</h1>
        <p class="text-body-2 text-medium-emphasis">Track your Adhere Coin earnings &amp; referral trends</p>
      </div>
      <v-spacer />
      <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load" size="small">Refresh</v-btn>
    </div>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4" closable @click:close="error = ''">{{ error }}</v-alert>

    <!-- ── Date Filter ── -->
    <v-card rounded="lg" class="pa-3 mb-5">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-icon class="mr-1" size="20">mdi-calendar-range</v-icon>
        <span class="text-subtitle-2 mr-2">Period</span>
        <v-chip-group v-model="preset" mandatory selected-class="text-primary" @update:model-value="onPresetChange">
          <v-chip v-for="p in presets" :key="p.value" :value="p.value" size="small" variant="tonal">
            {{ p.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <template v-if="preset === 'custom'">
          <v-text-field
            v-model="customStart"
            label="Start"
            type="date"
            density="compact"
            hide-details
            style="max-width:160px"
            class="mr-2"
          />
          <v-text-field
            v-model="customEnd"
            label="End"
            type="date"
            density="compact"
            hide-details
            style="max-width:160px"
            class="mr-2"
          />
          <v-btn variant="tonal" color="primary" size="small" prepend-icon="mdi-magnify" @click="load">Apply</v-btn>
        </template>
      </div>
    </v-card>

    <!-- ── Summary Cards ── -->
    <v-row dense class="mb-5">
      <v-col v-for="card in summaryCards" :key="card.label" cols="6" sm="4" md="2">
        <v-card rounded="xl" class="pa-4 text-center fill-height" variant="tonal" :color="card.color">
          <v-icon :color="card.color" size="28" class="mb-2">{{ card.icon }}</v-icon>
          <div class="text-h5 font-weight-black">{{ card.value }}</div>
          <div class="text-caption text-medium-emphasis">{{ card.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Trend Charts Row ── -->
    <v-row class="mb-5">
      <!-- Coins Earned Trend -->
      <v-col cols="12" md="8">
        <v-card rounded="xl" class="fill-height">
          <v-card-title class="d-flex align-center ga-2 pb-0">
            <v-icon color="success" size="20">mdi-chart-line</v-icon>
            Coins Earned Over Time
          </v-card-title>
          <v-card-text>
            <div v-if="!earnedValues.length" class="text-center text-medium-emphasis py-8">
              No earning activity in this period
            </div>
            <template v-else>
              <v-sparkline
                :model-value="earnedValues"
                :gradient="['#4caf50', '#81c784']"
                :line-width="2"
                :padding="8"
                smooth
                auto-draw
                fill
                height="200"
              />
              <div class="d-flex justify-space-between text-caption text-medium-emphasis px-2 mt-1">
                <span>{{ earnedLabels[0] }}</span>
                <span>{{ earnedLabels[Math.floor(earnedLabels.length / 2)] }}</span>
                <span>{{ earnedLabels[earnedLabels.length - 1] }}</span>
              </div>
            </template>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- Transaction Type Breakdown -->
      <v-col cols="12" md="4">
        <v-card rounded="xl" class="fill-height">
          <v-card-title class="d-flex align-center ga-2 pb-0">
            <v-icon color="primary" size="20">mdi-chart-donut</v-icon>
            Coin Breakdown
          </v-card-title>
          <v-card-text>
            <div v-if="!typeBreakdown.length" class="text-center text-medium-emphasis py-8">
              No transactions in this period
            </div>
            <div v-else class="mt-4">
              <div v-for="item in typeBreakdown" :key="item.type" class="mb-4">
                <div class="d-flex justify-space-between text-body-2 mb-1">
                  <span class="d-flex align-center ga-2">
                    <v-icon :color="breakdownColor(item.type)" size="16">{{ breakdownIcon(item.type) }}</v-icon>
                    {{ item.type.charAt(0).toUpperCase() + item.type.slice(1) }}
                  </span>
                  <span class="font-weight-bold">{{ fmt(item.total) }} <span class="text-caption text-medium-emphasis">({{ item.count }}x)</span></span>
                </div>
                <v-progress-linear
                  :model-value="breakdownPct(item.total)"
                  :color="breakdownColor(item.type)"
                  height="8"
                  rounded
                />
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── New Referrals Trend ── -->
    <v-card rounded="xl" class="mb-5">
      <v-card-title class="d-flex align-center ga-2 pb-0">
        <v-icon color="primary" size="20">mdi-account-multiple-plus</v-icon>
        New Referrals Over Time
      </v-card-title>
      <v-card-text>
        <div v-if="!referralValues.length" class="text-center text-medium-emphasis py-8">
          No new referrals in this period
        </div>
        <template v-else>
          <v-sparkline
            :model-value="referralValues"
            :gradient="['#673ab7', '#b39ddb']"
            :line-width="2"
            :padding="8"
            smooth
            auto-draw
            type="bar"
            height="160"
          />
          <div class="d-flex justify-space-between text-caption text-medium-emphasis px-2 mt-1">
            <span>{{ referralLabels[0] }}</span>
            <span v-if="referralLabels.length > 2">{{ referralLabels[Math.floor(referralLabels.length / 2)] }}</span>
            <span>{{ referralLabels[referralLabels.length - 1] }}</span>
          </div>
        </template>
      </v-card-text>
    </v-card>

    <!-- ── Top Performing Referrals ── -->
    <v-card rounded="xl" class="mb-5">
      <v-card-title class="d-flex align-center ga-2">
        <v-icon color="warning" size="20">mdi-trophy</v-icon>
        Top Performing Referrals
      </v-card-title>
      <v-card-text v-if="!topReferrals.length">
        <v-empty-state
          icon="mdi-account-group"
          title="No referrals yet"
          text="Share your code to start building your referral network."
        />
      </v-card-text>
      <v-data-table
        v-else
        :items="topReferrals"
        :headers="topHeaders"
        density="comfortable"
        class="rounded-b-xl"
        :items-per-page="10"
      >
        <template #item.rank="{ index }">
          <v-chip :color="index < 3 ? 'warning' : 'default'" size="small" variant="tonal">
            #{{ index + 1 }}
          </v-chip>
        </template>
        <template #item.status="{ item }">
          <v-chip
            :color="item.status === 'active' ? 'success' : item.status === 'pending' ? 'warning' : 'default'"
            size="small" variant="tonal"
          >{{ item.status }}</v-chip>
        </template>
        <template #item.tracked_requests="{ item }">
          {{ Number(item.tracked_requests).toLocaleString() }}
        </template>
        <template #item.coins_from_usage="{ item }">
          <div class="d-flex align-center ga-1">
            <img src="~/assets/images/adhere_coin.png" width="16" height="16" />
            {{ fmt(item.coins_from_usage) }}
          </div>
        </template>
        <template #item.created_at="{ item }">
          {{ new Date(item.created_at).toLocaleDateString() }}
        </template>
      </v-data-table>
    </v-card>

    <!-- ── Recent Transactions in Range ── -->
    <v-card rounded="xl">
      <v-card-title class="d-flex align-center ga-2">
        <v-icon color="info" size="20">mdi-history</v-icon>
        Recent Transactions
        <v-chip size="x-small" variant="tonal" class="ml-1">{{ summary.transactions }}</v-chip>
      </v-card-title>
      <v-card-text v-if="!recentTransactions.length">
        <v-empty-state icon="mdi-swap-horizontal" title="No transactions" text="No coin transactions found in this period." />
      </v-card-text>
      <v-data-table
        v-else
        :items="recentTransactions"
        :headers="txHeaders"
        density="comfortable"
        class="rounded-b-xl"
        :items-per-page="10"
      >
        <template #item.type="{ item }">
          <v-chip
            :color="txColor(item.type)"
            size="small" variant="tonal"
            :prepend-icon="txIcon(item.type)"
          >{{ item.type }}</v-chip>
        </template>
        <template #item.amount="{ item }">
          <span :class="['earned','bonus'].includes(item.type) ? 'text-success' : 'text-error'">
            {{ ['earned','bonus'].includes(item.type) ? '+' : '-' }}{{ fmt(item.amount) }}
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

// ── Date presets ──
const presets = [
  { label: 'Today', value: 'today' },
  { label: 'Yesterday', value: 'yesterday' },
  { label: 'Last 7 days', value: '7d' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'Last 90 days', value: '90d' },
  { label: 'This Month', value: 'this_month' },
  { label: 'Last Month', value: 'last_month' },
  { label: 'Custom', value: 'custom' },
]
const preset = ref('30d')
const customStart = ref('')
const customEnd = ref('')

// ── Data ──
const summary = ref({ coins_earned: '0', coins_redeemed: '0', net_coins: '0', transactions: 0, new_referrals: 0, total_balance: '0' })
const trends = ref({ daily_earned: [], daily_redeemed: [], daily_referrals: [] })
const typeBreakdown = ref([])
const topReferrals = ref([])
const recentTransactions = ref([])

// ── Sparkline data ──
const earnedValues = computed(() => trends.value.daily_earned.map(d => Number(d.amount)))
const earnedLabels = computed(() => trends.value.daily_earned.map(d =>
  new Date(d.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
))
const referralValues = computed(() => trends.value.daily_referrals.map(d => d.count))
const referralLabels = computed(() => trends.value.daily_referrals.map(d =>
  new Date(d.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
))

const breakdownMax = computed(() => {
  if (!typeBreakdown.value.length) return 1
  return Math.max(...typeBreakdown.value.map(t => Number(t.total)), 1)
})

// ── Table headers ──
const topHeaders = [
  { title: '#', key: 'rank', sortable: false, width: 50 },
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

function fmt(val) {
  return Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}
function txColor(type) {
  return { earned: 'success', bonus: 'warning', redeemed: 'info', adjustment: 'secondary' }[type] || 'default'
}
function txIcon(type) {
  return { earned: 'mdi-arrow-down', bonus: 'mdi-star', redeemed: 'mdi-arrow-up', adjustment: 'mdi-tune' }[type] || 'mdi-swap-horizontal'
}
function breakdownColor(type) {
  return { earned: 'success', bonus: 'warning', redeemed: 'info', adjustment: 'secondary' }[type] || 'grey'
}
function breakdownIcon(type) {
  return { earned: 'mdi-arrow-down-bold', bonus: 'mdi-star', redeemed: 'mdi-arrow-up-bold', adjustment: 'mdi-tune' }[type] || 'mdi-circle'
}
function breakdownPct(total) {
  return (Number(total) / breakdownMax.value) * 100
}

const summaryCards = computed(() => [
  { label: 'Coins Earned', value: fmt(summary.value.coins_earned), icon: 'mdi-arrow-down-bold', color: 'success' },
  { label: 'Coins Redeemed', value: fmt(summary.value.coins_redeemed), icon: 'mdi-arrow-up-bold', color: 'info' },
  { label: 'Net Coins', value: fmt(summary.value.net_coins), icon: 'mdi-sigma', color: 'primary' },
  { label: 'Transactions', value: summary.value.transactions, icon: 'mdi-swap-horizontal', color: 'secondary' },
  { label: 'New Referrals', value: summary.value.new_referrals, icon: 'mdi-account-plus', color: 'warning' },
  { label: 'Total Balance', value: fmt(summary.value.total_balance), icon: 'mdi-wallet', color: 'success' },
])

function onPresetChange() {
  if (preset.value !== 'custom') load()
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const params = {}
    if (preset.value === 'custom') {
      if (customStart.value) params.start = customStart.value
      if (customEnd.value) params.end = customEnd.value
    } else {
      params.preset = preset.value
    }
    const { data } = await $api.get('/usage-billing/referral/performance/', { params })
    summary.value = data.summary || summary.value
    trends.value = data.trends || trends.value
    typeBreakdown.value = data.type_breakdown || []
    topReferrals.value = data.top_referrals || []
    recentTransactions.value = data.recent_transactions || []
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load performance data'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>
