<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="detail ? `Bill — ${period}` : 'Bill details'"
      icon="mdi-receipt-text"
      subtitle="API usage bill breakdown & analysis"
    >
      <template #actions>
        <v-btn variant="text" prepend-icon="mdi-arrow-left" to="/pharmacy/billing/usage">Back</v-btn>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

    <div v-if="detail">
      <!-- Status banner -->
      <v-card
        rounded="lg"
        class="pa-4 mb-4"
        :color="bannerColor"
        variant="tonal"
      >
        <div class="d-flex flex-wrap align-center ga-3">
          <v-icon size="40">{{ bannerIcon }}</v-icon>
          <div>
            <div class="text-overline">Status</div>
            <div class="text-h5 font-weight-bold d-flex align-center ga-2">
              <StatusChip :status="effStatus" />
            </div>
          </div>
          <v-spacer />
          <div class="text-right">
            <div class="text-caption text-medium-emphasis">Amount due</div>
            <div class="text-h4 font-weight-bold">
              {{ formatMoney(bill.amount, bill.currency) }}
            </div>
            <div v-if="bill.due_date" class="text-caption" :class="{ 'text-error': bill.is_overdue }">
              Due {{ formatDate(bill.due_date) }}
            </div>
          </div>
          <v-btn
            v-if="isPayable"
            color="primary"
            size="large"
            prepend-icon="mdi-circle-multiple"
            class="ml-2"
            @click="payDialog = true"
          >
            Pay with Adhere Coins
          </v-btn>
        </div>
      </v-card>

      <v-row dense>
        <!-- Cost breakdown -->
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 h-100">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon class="mr-1" color="primary">mdi-calculator-variant</v-icon>
              Cost breakdown
            </div>
            <v-list density="compact" class="bg-transparent">
              <v-list-item class="px-0">
                <v-list-item-title>Total requests</v-list-item-title>
                <template #append><span class="font-weight-bold">{{ fmt(breakdown.total_requests) }}</span></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Requests per unit</v-list-item-title>
                <template #append><span class="font-weight-bold">{{ fmt(breakdown.requests_per_unit) }}</span></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Billable units</v-list-item-title>
                <template #append><span class="font-weight-bold">{{ fmt(breakdown.billable_units) }}</span></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Unit cost</v-list-item-title>
                <template #append><span class="font-weight-bold">{{ formatMoney(breakdown.unit_cost, breakdown.currency) }}</span></template>
              </v-list-item>
              <v-divider class="my-2" />
              <v-list-item class="px-0">
                <v-list-item-title class="font-weight-bold">Total amount</v-list-item-title>
                <template #append>
                  <span class="text-h6 font-weight-bold text-primary">
                    {{ formatMoney(breakdown.amount, breakdown.currency) }}
                  </span>
                </template>
              </v-list-item>
            </v-list>
            <div class="text-caption text-medium-emphasis mt-2">
              {{ fmt(breakdown.billable_units) }} units × {{ formatMoney(breakdown.unit_cost, breakdown.currency) }}
              = {{ formatMoney(breakdown.amount, breakdown.currency) }}
            </div>
          </v-card>
        </v-col>

        <!-- Usage analysis -->
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 h-100">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon class="mr-1" color="info">mdi-chart-timeline-variant</v-icon>
              Usage analysis
            </div>
            <v-row dense>
              <v-col cols="6">
                <div class="text-caption text-medium-emphasis">Days in month</div>
                <div class="text-h6 font-weight-bold">{{ analysis.days_in_month }}</div>
              </v-col>
              <v-col cols="6">
                <div class="text-caption text-medium-emphasis">Active days</div>
                <div class="text-h6 font-weight-bold">{{ analysis.active_days }}</div>
              </v-col>
              <v-col cols="6">
                <div class="text-caption text-medium-emphasis">Daily average</div>
                <div class="text-h6 font-weight-bold">{{ fmt(analysis.daily_average) }}</div>
              </v-col>
              <v-col cols="6">
                <div class="text-caption text-medium-emphasis">Active-day average</div>
                <div class="text-h6 font-weight-bold">{{ fmt(analysis.active_day_average) }}</div>
              </v-col>
              <v-col cols="12" v-if="analysis.peak_day">
                <v-divider class="my-2" />
                <div class="text-caption text-medium-emphasis">Peak day</div>
                <div class="text-subtitle-2 font-weight-bold">
                  {{ analysis.peak_day.date }} — {{ fmt(analysis.peak_day.request_count) }} requests
                </div>
              </v-col>
            </v-row>
          </v-card>
        </v-col>
      </v-row>

      <!-- Daily usage chart -->
      <v-card rounded="lg" class="pa-4 mt-3">
        <div class="text-subtitle-1 font-weight-bold mb-3">
          <v-icon class="mr-1" color="primary">mdi-chart-bar</v-icon>
          Daily requests — {{ period }}
        </div>
        <div v-if="detail.daily.length" class="usage-bars" style="height: 160px;">
          <div
            v-for="d in detail.daily"
            :key="d.date"
            class="usage-bar-wrap"
            :title="`${d.date}: ${d.request_count} requests`"
          >
            <div
              class="usage-bar"
              :class="{ 'is-peak': analysis.peak_day && d.request_count === analysis.peak_day.request_count && d.request_count > 0 }"
              :style="{ height: dayHeight(d.request_count) + '%' }"
            />
          </div>
        </div>
        <div v-else class="text-medium-emphasis text-center py-4 text-caption">No daily usage recorded.</div>
      </v-card>

      <!-- Weekday breakdown -->
      <v-card rounded="lg" class="pa-4 mt-3">
        <div class="text-subtitle-1 font-weight-bold mb-3">
          <v-icon class="mr-1" color="info">mdi-calendar-week</v-icon>
          Requests by weekday
        </div>
        <div v-for="w in detail.weekday_breakdown" :key="w.weekday" class="d-flex align-center mb-2">
          <div style="width: 44px;" class="text-caption text-medium-emphasis">{{ w.weekday }}</div>
          <div class="flex-grow-1 mx-2">
            <v-progress-linear
              :model-value="weekdayWidth(w.total)"
              color="primary"
              height="14"
              rounded
            />
          </div>
          <div style="width: 72px;" class="text-right text-caption font-weight-medium">{{ fmt(w.total) }}</div>
        </div>
      </v-card>

      <div v-if="bill.notes" class="mt-3">
        <v-card rounded="lg" class="pa-4">
          <div class="text-subtitle-2 font-weight-bold mb-1">Notes</div>
          <div class="text-body-2 text-medium-emphasis" style="white-space: pre-line;">{{ bill.notes }}</div>
        </v-card>
      </div>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="primary" />

    <!-- Pay dialog -->
    <v-dialog v-model="payDialog" max-width="460">
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-circle-multiple</v-icon>
          Pay with Adhere Coins
        </v-card-title>
        <v-card-text>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-medium-emphasis">Bill amount</span>
            <span class="font-weight-bold">{{ formatMoney(bill && bill.amount, bill && bill.currency) }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-medium-emphasis">Your coin balance</span>
            <span class="font-weight-bold">{{ fmt(coinBalance) }} coins</span>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            1 Adhere Coin = 1 {{ bill && bill.currency }}. The full bill amount will be deducted from your coin balance.
          </div>
          <v-alert
            v-if="bill && Number(coinBalance) < Number(bill.amount)"
            type="warning"
            variant="tonal"
            density="compact"
            class="mt-3"
          >
            Insufficient coins. You can earn more via referrals.
          </v-alert>
          <v-alert v-if="payError" type="error" variant="tonal" density="compact" class="mt-3">{{ payError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">Cancel</v-btn>
          <v-btn
            color="primary"
            :loading="paying"
            :disabled="bill && Number(coinBalance) < Number(bill.amount)"
            @click="payBill"
          >
            Confirm payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { formatDate, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const billId = route.params.id

const detail = ref(null)
const loading = ref(false)
const error = ref(null)

const payDialog = ref(false)
const paying = ref(false)
const payError = ref(null)

const bill = computed(() => detail.value?.bill || null)
const breakdown = computed(() => detail.value?.breakdown || {})
const analysis = computed(() => detail.value?.analysis || {})
const coinBalance = computed(() => detail.value?.coin_balance || 0)

const period = computed(() => bill.value?.period_label || (bill.value ? `${bill.value.year}-${String(bill.value.month).padStart(2, '0')}` : ''))
const effStatus = computed(() => bill.value?.effective_status || bill.value?.status || '')
const isPayable = computed(() => ['ISSUED', 'OVERDUE', 'DRAFT'].includes(effStatus.value))

const bannerColor = computed(() => {
  if (effStatus.value === 'PAID') return 'success'
  if (effStatus.value === 'OVERDUE') return 'error'
  return 'warning'
})
const bannerIcon = computed(() => {
  if (effStatus.value === 'PAID') return 'mdi-check-decagram'
  if (effStatus.value === 'OVERDUE') return 'mdi-alert-circle'
  return 'mdi-receipt-text-clock'
})

function fmt(v) {
  if (v == null) return '—'
  return Number(v).toLocaleString()
}

const peakValue = computed(() => detail.value?.analysis?.peak_day?.request_count || 0)
function dayHeight(v) {
  return Math.max(2, Math.round((v / Math.max(peakValue.value, 1)) * 100))
}
const weekdayMax = computed(() => {
  if (!detail.value?.weekday_breakdown) return 0
  return Math.max(...detail.value.weekday_breakdown.map((w) => w.total), 0)
})
function weekdayWidth(v) {
  return Math.max(2, Math.round((v / Math.max(weekdayMax.value, 1)) * 100))
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data } = await $api.get(`/usage-billing/bills/${billId}/`)
    detail.value = data
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load bill.'
  } finally {
    loading.value = false
  }
}

async function payBill() {
  paying.value = true
  payError.value = null
  try {
    await $api.post('/usage-billing/referral/redeem/pay-bill/', { bill_id: billId })
    payDialog.value = false
    await load()
  } catch (e) {
    payError.value = e?.response?.data?.detail || e.message || 'Payment failed.'
  } finally {
    paying.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.usage-bars {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  width: 100%;
}
.usage-bar-wrap {
  flex: 1 1 0;
  height: 100%;
  display: flex;
  align-items: flex-end;
}
.usage-bar {
  width: 100%;
  background: rgb(var(--v-theme-primary));
  border-radius: 3px 3px 0 0;
  opacity: 0.75;
  transition: opacity 0.15s ease;
}
.usage-bar:hover { opacity: 1; }
.usage-bar.is-peak { background: rgb(var(--v-theme-error)); opacity: 1; }
.h-100 { height: 100%; }
</style>
