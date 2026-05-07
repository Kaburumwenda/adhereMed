<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="hero-card pa-4 pa-md-6 mb-4">
      <div class="d-flex flex-wrap align-center">
        <div class="d-flex align-center mr-auto">
          <v-avatar color="white" variant="tonal" size="56" class="mr-4 elevation-2">
            <v-icon size="32" color="amber-lighten-1">mdi-trophy-variant</v-icon>
          </v-avatar>
          <div>
            <h1 class="text-h5 text-md-h4 font-weight-bold text-white mb-1">Staff Performance</h1>
            <div class="text-body-2 text-white" style="opacity:0.85">
              {{ data?.range?.label || 'Loading…' }}
              <template v-if="data?.totals">
                · {{ data.totals.active_staff }}/{{ data.totals.staff_count }} active staff
                · {{ formatMoney(data.totals.revenue) }} total revenue
              </template>
            </div>
          </div>
        </div>
        <div class="d-flex align-center mt-3 mt-md-0" style="gap:8px">
          <v-select
            v-model="rangeKey"
            :items="rangeOptions"
            item-title="label"
            item-value="key"
            density="compact"
            variant="solo-filled"
            hide-details
            bg-color="white"
            base-color="grey-darken-3"
            prepend-inner-icon="mdi-calendar-range"
            style="min-width: 220px"
            @update:model-value="onRangeChange"
          />
          <v-btn variant="flat" color="white" prepend-icon="mdi-download" class="text-none" @click="exportCsv">
            Export CSV
          </v-btn>
        </div>
      </div>
    </div>

    <!-- KPI tiles -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="12" sm="6" md="3">
        <v-card class="kpi-tile pa-4" rounded="xl" border>
          <div class="d-flex align-center mb-2">
            <v-avatar :color="k.color" variant="tonal" size="40" class="mr-3">
              <v-icon :icon="k.icon" />
            </v-avatar>
            <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
          </div>
          <div class="text-h4 font-weight-bold">{{ k.value }}</div>
          <div class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense class="mb-2">
      <!-- Trend -->
      <v-col cols="12" md="8">
        <v-card class="pa-4" rounded="xl" border>
          <div class="d-flex align-center mb-2">
            <v-icon color="primary" class="mr-2">mdi-chart-line-variant</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Daily revenue trend</div>
            <v-spacer />
            <v-chip size="small" color="primary" variant="tonal">{{ data?.range?.label }}</v-chip>
          </div>
          <div v-if="!data?.daily?.length" class="text-center text-medium-emphasis py-8">
            No sales recorded in this range.
          </div>
          <SparkArea
            v-else
            :values="data.daily.map(d => d.revenue)"
            :height="180"
            color="#6366f1"
          />
          <div v-if="data?.daily?.length" class="d-flex justify-space-between text-caption text-medium-emphasis mt-2">
            <span>{{ data.daily[0].date }}</span>
            <span>{{ data.daily[data.daily.length - 1].date }}</span>
          </div>
        </v-card>
      </v-col>

      <!-- Payment breakdown -->
      <v-col cols="12" md="4">
        <v-card class="pa-4 h-100" rounded="xl" border>
          <div class="d-flex align-center mb-3">
            <v-icon color="teal" class="mr-2">mdi-cash-multiple</v-icon>
            <div class="text-subtitle-1 font-weight-medium">By payment method</div>
          </div>
          <div v-if="!data?.by_payment?.length" class="text-center text-medium-emphasis py-6">No data</div>
          <div v-else>
            <div v-for="p in data.by_payment" :key="p.payment_method" class="mb-3">
              <div class="d-flex align-center mb-1">
                <v-icon size="18" :color="paymentColor(p.payment_method)" class="mr-2">{{ paymentIcon(p.payment_method) }}</v-icon>
                <span class="text-body-2 font-weight-medium text-capitalize">{{ p.payment_method || '—' }}</span>
                <v-spacer />
                <span class="text-body-2 font-weight-bold">{{ formatMoney(p.revenue) }}</span>
              </div>
              <v-progress-linear
                :model-value="paymentPct(p.revenue)"
                :color="paymentColor(p.payment_method)"
                height="8" rounded
              />
              <div class="text-caption text-medium-emphasis mt-1">{{ p.count }} transactions</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Podium -->
    <v-card v-if="topThree.length" class="pa-4 mb-3" rounded="xl" border>
      <div class="d-flex align-center mb-3">
        <v-icon color="amber" class="mr-2">mdi-medal</v-icon>
        <div class="text-subtitle-1 font-weight-medium">Top performers</div>
      </div>
      <v-row dense>
        <v-col v-for="(s, i) in topThree" :key="s.user_id" cols="12" md="4">
          <v-card variant="tonal" :color="podiumColor(i)" rounded="xl" class="pa-4 h-100">
            <div class="d-flex align-center">
              <v-avatar :color="podiumColor(i)" size="56" class="mr-3 elevation-2">
                <span class="text-h6 font-weight-bold text-white">{{ initials(s.name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="d-flex align-center">
                  <v-icon size="20" :color="podiumColor(i)" class="mr-1">{{ podiumIcon(i) }}</v-icon>
                  <span class="text-overline font-weight-bold">#{{ i + 1 }}</span>
                </div>
                <div class="text-subtitle-1 font-weight-bold text-truncate">{{ s.name }}</div>
                <div class="text-caption text-medium-emphasis text-capitalize">
                  {{ (s.role || '').replace('_', ' ') }}
                  <span v-if="s.branch_name"> · {{ s.branch_name }}</span>
                </div>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex justify-space-between text-body-2">
              <div>
                <div class="text-caption text-medium-emphasis">REVENUE</div>
                <div class="font-weight-bold">{{ formatMoney(s.revenue) }}</div>
              </div>
              <div>
                <div class="text-caption text-medium-emphasis">TXNS</div>
                <div class="font-weight-bold">{{ s.transactions }}</div>
              </div>
              <div>
                <div class="text-caption text-medium-emphasis">ITEMS</div>
                <div class="font-weight-bold">{{ s.items_sold }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Leaderboard table -->
    <v-card class="pa-0" rounded="xl" border>
      <div class="d-flex align-center pa-4">
        <v-icon color="indigo" class="mr-2">mdi-format-list-numbered</v-icon>
        <div class="text-subtitle-1 font-weight-medium">Leaderboard</div>
        <v-spacer />
        <v-text-field
          v-model="search"
          placeholder="Filter staff…"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          hide-details
          clearable
          style="max-width: 280px"
        />
      </div>
      <v-divider />
      <div v-if="loading" class="text-center py-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <EmptyState
        v-else-if="!filteredRows.length"
        icon="mdi-account-search"
        title="No staff data"
        message="Try selecting a wider date range or check that POS sales have been recorded."
      />
      <v-table v-else density="comfortable" class="leaderboard-table">
        <thead>
          <tr>
            <th class="text-left">Rank</th>
            <th class="text-left">Staff</th>
            <th class="text-left">Role</th>
            <th class="text-right">Revenue</th>
            <th class="text-right">Txns</th>
            <th class="text-right">Items</th>
            <th class="text-right">Avg / Txn</th>
            <th class="text-right">Discounts</th>
            <th class="text-right">Voids</th>
            <th class="text-right">Active days</th>
            <th class="text-right">Last sale</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(s, i) in filteredRows" :key="`${s.user_id}-${i}`" :class="{ 'top-row': i < 3 }">
            <td>
              <v-chip
                v-if="i < 3"
                size="small"
                :color="podiumColor(i)"
                variant="flat"
                class="font-weight-bold"
              >#{{ i + 1 }}</v-chip>
              <span v-else class="text-medium-emphasis">#{{ i + 1 }}</span>
            </td>
            <td>
              <div class="d-flex align-center">
                <v-avatar :color="avatarColor(s.name)" size="32" class="mr-2">
                  <span class="text-caption font-weight-bold text-white">{{ initials(s.name) }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ s.name }}</div>
                  <div class="text-caption text-medium-emphasis">
                    {{ s.email }}
                    <span v-if="s.branch_name"> · {{ s.branch_name }}</span>
                  </div>
                </div>
              </div>
            </td>
            <td>
              <v-chip size="x-small" variant="tonal" :color="roleColor(s.role)" class="text-capitalize">
                {{ (s.role || '').replace('_', ' ') }}
              </v-chip>
            </td>
            <td class="text-right font-weight-bold">{{ formatMoney(s.revenue) }}</td>
            <td class="text-right">{{ s.transactions }}</td>
            <td class="text-right">{{ s.items_sold }}</td>
            <td class="text-right">{{ formatMoney(s.avg_transaction) }}</td>
            <td class="text-right text-medium-emphasis">{{ formatMoney(s.discount_given) }}</td>
            <td class="text-right">
              <v-chip v-if="s.voided_count" size="x-small" color="error" variant="tonal">{{ s.voided_count }}</v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </td>
            <td class="text-right">{{ s.active_days }}</td>
            <td class="text-right text-caption text-medium-emphasis">
              {{ s.last_sale ? formatDateTime(s.last_sale) : '—' }}
            </td>
          </tr>
        </tbody>
      </v-table>
    </v-card>

    <!-- Custom range dialog -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Custom date range</v-card-title>
        <v-card-text>
          <v-text-field v-model="customStart" type="date" label="Start" variant="outlined" density="comfortable" />
          <v-text-field v-model="customEnd" type="date" label="End" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="customDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { formatMoney, formatDateTime } from '~/utils/format'
import EmptyState from '~/components/EmptyState.vue'
import SparkArea from '~/components/SparkArea.vue'

const { $api } = useNuxtApp()

const loading = ref(false)
const data = ref(null)
const search = ref('')

const rangeKey = ref('30d')
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')
const customRange = ref(null)

const rangeOptions = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 90 days' },
  { key: '1y', label: 'Last 365 days' },
  { key: 'custom', label: 'Custom range…' },
]

function onRangeChange(val) {
  if (val === 'custom') {
    customDialog.value = true
  } else {
    customRange.value = null
    load()
  }
}

function applyCustom() {
  if (!customStart.value || !customEnd.value) return
  customRange.value = { from: customStart.value, to: customEnd.value }
  rangeKey.value = 'custom'
  customDialog.value = false
  load()
}

async function load() {
  loading.value = true
  try {
    const params = {}
    if (rangeKey.value === 'custom' && customRange.value) {
      params.date_from = customRange.value.from
      params.date_to = customRange.value.to
    } else if (rangeKey.value !== 'custom') {
      params.period = rangeKey.value
    }
    const r = await $api.get('/staff/performance/', { params })
    data.value = r.data
  } catch (e) {
    data.value = null
  } finally {
    loading.value = false
  }
}

onMounted(load)

const filteredRows = computed(() => {
  const rows = data.value?.leaderboard || []
  const q = (search.value || '').toLowerCase().trim()
  if (!q) return rows
  return rows.filter(s =>
    (s.name || '').toLowerCase().includes(q) ||
    (s.email || '').toLowerCase().includes(q) ||
    (s.role || '').toLowerCase().includes(q) ||
    (s.branch_name || '').toLowerCase().includes(q)
  )
})

const topThree = computed(() => (data.value?.leaderboard || []).filter(s => s.transactions > 0).slice(0, 3))

const kpiTiles = computed(() => {
  const t = data.value?.totals || {}
  return [
    { label: 'Total revenue', value: formatMoney(t.revenue || 0), icon: 'mdi-cash-100', color: 'success', sub: `${t.transactions || 0} transactions` },
    { label: 'Items sold', value: (t.items_sold || 0).toLocaleString(), icon: 'mdi-package-variant', color: 'primary', sub: `${formatMoney(t.avg_transaction || 0)} avg / txn` },
    { label: 'Active staff', value: `${t.active_staff || 0}/${t.staff_count || 0}`, icon: 'mdi-account-multiple-check', color: 'indigo', sub: 'Made at least 1 sale' },
    { label: 'Voided sales', value: (t.voided_count || 0).toLocaleString(), icon: 'mdi-cancel', color: 'error', sub: `${formatMoney(t.discount_given || 0)} discounts given` },
  ]
})

const paymentTotal = computed(() =>
  (data.value?.by_payment || []).reduce((s, p) => s + Number(p.revenue || 0), 0) || 1
)
function paymentPct(v) { return Math.round((Number(v || 0) / paymentTotal.value) * 100) }
function paymentColor(m) {
  const map = { cash: 'success', mpesa: 'green', card: 'indigo', credit: 'orange', insurance: 'purple', bank: 'blue' }
  return map[(m || '').toLowerCase()] || 'grey'
}
function paymentIcon(m) {
  const map = { cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card-outline', credit: 'mdi-account-credit-card-outline', insurance: 'mdi-shield-account', bank: 'mdi-bank' }
  return map[(m || '').toLowerCase()] || 'mdi-cash'
}

function podiumColor(i) { return ['amber', 'blue-grey', 'orange'][i] || 'grey' }
function podiumIcon(i) { return ['mdi-trophy', 'mdi-medal', 'mdi-medal-outline'][i] || 'mdi-star' }

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('')
}
function avatarColor(name) {
  const palette = ['primary', 'indigo', 'teal', 'deep-purple', 'pink', 'orange', 'cyan', 'green']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function roleColor(role) {
  const map = {
    super_admin: 'purple', tenant_admin: 'indigo', pharmacy_admin: 'indigo',
    pharmacist: 'blue', pharmacy_tech: 'cyan', cashier: 'teal',
    doctor: 'green', nurse: 'pink',
  }
  return map[role] || 'grey'
}

function exportCsv() {
  const rows = filteredRows.value
  if (!rows.length) return
  const header = ['Rank', 'Name', 'Email', 'Role', 'Branch', 'Revenue', 'Transactions', 'Items', 'Avg per Txn', 'Discounts', 'Voids', 'Active days', 'First sale', 'Last sale']
  const lines = [header.join(',')]
  rows.forEach((s, i) => {
    lines.push([
      i + 1,
      JSON.stringify(s.name || ''),
      JSON.stringify(s.email || ''),
      s.role || '',
      JSON.stringify(s.branch_name || ''),
      s.revenue, s.transactions, s.items_sold, s.avg_transaction,
      s.discount_given, s.voided_count, s.active_days,
      s.first_sale || '', s.last_sale || '',
    ].join(','))
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `staff-performance-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.hero-card {
  border-radius: 20px;
  background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 50%, #ec4899 100%);
  color: white;
  box-shadow: 0 12px 32px rgba(79, 70, 229, 0.3);
}
.kpi-tile { transition: transform 0.15s ease, box-shadow 0.15s ease; }
.kpi-tile:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0,0,0,0.07); }

.leaderboard-table :deep(thead th) {
  font-weight: 600;
  background: rgba(99, 102, 241, 0.04);
  color: rgba(0,0,0,0.65);
}
.leaderboard-table :deep(tbody tr.top-row) {
  background: linear-gradient(90deg, rgba(255, 215, 0, 0.06), transparent 60%);
}
.leaderboard-table :deep(tbody tr:hover) { background: rgba(99, 102, 241, 0.05); }
</style>
