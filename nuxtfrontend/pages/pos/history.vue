<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" variant="text" to="/pos" class="mr-2" />
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">Sales History</h1>
          <div class="text-body-2 text-medium-emphasis">
            {{ rangeLabel }} · {{ filteredTx.length }} transactions
            <v-chip v-if="!canViewAll" size="x-small" color="primary" variant="tonal" class="ml-2">
              <v-icon start size="14">mdi-account</v-icon>My sales only
            </v-chip>
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-select
          v-model="rangeKey"
          :items="rangeOptions"
          item-title="label"
          item-value="key"
          density="compact"
          variant="outlined"
          color="primary"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-calendar-range"
          style="min-width: 220px"
          @update:model-value="onRangeChange"
        />
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-download" @click="exportCsv">Export</v-btn>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-point-of-sale" to="/pos">New sale</v-btn>
      </div>
    </div>

    <!-- Custom range dialog -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom date range</v-card-title>
        <v-card-text>
          <v-text-field v-model="customStart" label="Start date" type="date" variant="outlined" density="compact" hide-details class="mb-3" />
          <v-text-field v-model="customEnd" label="End date" type="date" variant="outlined" density="compact" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" class="text-none" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- KPIs -->
    <v-row dense>
      <v-col cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">Transactions</div>
              <div class="text-h5 font-weight-bold mt-1">{{ kpis.count }}</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ kpis.completedCount }} completed · {{ kpis.voidedCount }} voided</div>
            </div>
            <v-avatar color="primary-lighten-1" variant="tonal" rounded="lg" size="40"><v-icon>mdi-receipt-text-outline</v-icon></v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">Net revenue</div>
              <div class="text-h5 font-weight-bold mt-1 text-primary">{{ formatMoney(kpis.revenue) }}</div>
              <div class="text-caption text-medium-emphasis mt-1">Gross {{ formatMoney(kpis.gross) }}</div>
            </div>
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cash-multiple</v-icon></v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">Items sold</div>
              <div class="text-h5 font-weight-bold mt-1">{{ kpis.itemsSold }}</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ kpis.uniqueProducts }} unique products</div>
            </div>
            <v-avatar color="info" variant="tonal" rounded="lg" size="40"><v-icon>mdi-package-variant-closed</v-icon></v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">Avg. order value</div>
              <div class="text-h5 font-weight-bold mt-1">{{ formatMoney(kpis.aov) }}</div>
              <div class="text-caption text-medium-emphasis mt-1">Discount {{ formatMoney(kpis.discount) }}</div>
            </div>
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40"><v-icon>mdi-trending-up</v-icon></v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Charts row -->
    <v-row class="mt-1">
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <div>
              <h3 class="text-h6 font-weight-bold">Revenue over time</h3>
              <div class="text-caption text-medium-emphasis">{{ rangeLabel }}</div>
            </div>
            <v-btn-toggle v-model="trendMetric" density="compact" mandatory variant="outlined" color="primary" rounded="lg">
              <v-btn value="revenue" class="text-none" size="small">Revenue</v-btn>
              <v-btn value="orders" class="text-none" size="small">Orders</v-btn>
              <v-btn value="items" class="text-none" size="small">Items</v-btn>
            </v-btn-toggle>
          </div>
          <SparkArea
            v-if="trend.values.length"
            :values="trend.values"
            :labels="trend.labels"
            :height="240"
            color="#3b82f6"
            :y-formatter="trendMetric === 'revenue' ? moneyFormat : null"
          />
          <EmptyState v-else icon="mdi-chart-line" title="No data" />
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-2">Payment methods</h3>
          <DonutRing v-if="paymentSegments.length" :segments="paymentSegments" :size="180" class="mx-auto">
            <div class="text-center">
              <div class="text-caption text-medium-emphasis">Transactions</div>
              <div class="text-h6 font-weight-bold">{{ kpis.count }}</div>
            </div>
          </DonutRing>
          <EmptyState v-else icon="mdi-credit-card-outline" title="No payments" />
          <div class="mt-3">
            <div v-for="p in paymentBreakdown" :key="p.method" class="d-flex align-center py-1">
              <span class="legend-dot mr-2" :style="{ background: PAYMENT_COLORS[p.method] || '#94a3b8' }"></span>
              <span class="text-body-2 flex-grow-1">{{ p.label }}</span>
              <span class="text-caption text-medium-emphasis mr-2">{{ p.count }}</span>
              <span class="text-body-2 font-weight-medium">{{ formatMoney(p.total) }}</span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Hour distribution + Top products in range -->
    <v-row>
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <div>
              <h3 class="text-h6 font-weight-bold">Hour of day</h3>
              <div class="text-caption text-medium-emphasis">When customers buy most</div>
            </div>
          </div>
          <HourHeatmap :counts="hourCounts" unit="sales" />
        </v-card>
      </v-col>
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <h3 class="text-h6 font-weight-bold">Top products</h3>
            <v-btn variant="text" class="text-none" size="small" to="/analytics/products" append-icon="mdi-arrow-right">View all</v-btn>
          </div>
          <EmptyState v-if="!topProducts.length" icon="mdi-package-variant-closed" title="No sales" />
          <div v-else>
            <div v-for="p in topProducts" :key="p.name" class="d-flex align-center py-2 border-b">
              <div class="flex-grow-1">
                <div class="text-body-2 font-weight-medium">{{ p.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ p.qty }} sold</div>
              </div>
              <div class="text-body-2 font-weight-medium">{{ formatMoney(p.revenue) }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters + transactions table -->
    <v-card rounded="lg" class="pa-4 mt-4">
      <div class="d-flex flex-wrap align-center mb-3" style="gap:8px">
        <v-text-field
          v-model="search"
          placeholder="Search by receipt #, customer, phone…"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          hide-details
          clearable
          style="min-width: 260px; max-width: 380px"
        />
        <v-select
          v-model="paymentFilter"
          :items="paymentFilterOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          hide-details
          style="min-width: 170px; max-width: 220px"
          prepend-inner-icon="mdi-credit-card-outline"
        />
        <v-select
          v-model="statusFilter"
          :items="statusFilterOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          hide-details
          style="min-width: 160px; max-width: 200px"
          prepend-inner-icon="mdi-flag-variant-outline"
        />
        <v-select
          v-if="canViewAll"
          v-model="cashierFilter"
          :items="cashierFilterOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          hide-details
          style="min-width: 180px; max-width: 240px"
          prepend-inner-icon="mdi-account-tie"
        />
        <v-spacer />
        <div class="text-body-2 text-medium-emphasis">{{ filteredTx.length }} of {{ inRange.length }}</div>
      </div>

      <div v-if="loading" class="text-center py-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <EmptyState v-else-if="!filteredTx.length" icon="mdi-receipt-text-outline" title="No transactions" message="Try adjusting filters or selecting a wider date range." />
      <div v-else>
        <v-table density="comfortable" hover class="bg-transparent sales-table">
          <thead>
            <tr>
              <th style="width:32px"></th>
              <th class="cursor-pointer" @click="setSort('created_at')">Date / Time <v-icon size="14" v-if="sortBy === 'created_at'">{{ sortDir === 'desc' ? 'mdi-arrow-down' : 'mdi-arrow-up' }}</v-icon></th>
              <th class="cursor-pointer" @click="setSort('transaction_number')">Receipt #</th>
              <th>Customer</th>
              <th>Cashier</th>
              <th>Payment</th>
              <th class="text-right cursor-pointer" @click="setSort('itemsCount')">Items</th>
              <th class="text-right cursor-pointer" @click="setSort('total')">Total <v-icon size="14" v-if="sortBy === 'total'">{{ sortDir === 'desc' ? 'mdi-arrow-down' : 'mdi-arrow-up' }}</v-icon></th>
              <th>Status</th>
              <th class="text-right" style="width:110px">Actions</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="t in pagedTx" :key="t.id">
              <tr class="row-main">
                <td>
                  <v-btn :icon="expanded[t.id] ? 'mdi-chevron-up' : 'mdi-chevron-down'" variant="text" size="x-small" @click="toggleExpand(t.id)" />
                </td>
                <td>
                  <div class="text-body-2">{{ formatDate(t.created_at) }}</div>
                  <div class="text-caption text-medium-emphasis">{{ formatTime(t.created_at) }}</div>
                </td>
                <td><span class="font-weight-medium">{{ t.transaction_number || `#${t.id}` }}</span></td>
                <td>
                  <div class="text-body-2">{{ t.customer_name || 'Walk-in' }}</div>
                  <div v-if="t.customer_phone" class="text-caption text-medium-emphasis">{{ t.customer_phone }}</div>
                </td>
                <td class="text-body-2">{{ t.cashier_name || '—' }}</td>
                <td>
                  <v-chip size="x-small" :color="paymentColor(t.payment_method)" variant="tonal" class="text-uppercase">
                    {{ formatPayment(t.payment_method) }}
                  </v-chip>
                </td>
                <td class="text-right">{{ itemsCount(t) }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(t.total || 0) }}</td>
                <td>
                  <v-chip size="x-small" :color="statusColor(t.status)" variant="tonal" class="text-uppercase">{{ t.status || 'completed' }}</v-chip>
                </td>
                <td class="text-right">
                  <v-btn icon="mdi-receipt-text" size="x-small" variant="text" @click="openReceipt(t)" />
                  <v-btn icon="mdi-printer" size="x-small" variant="text" @click="printReceipt(t)" />
                </td>
              </tr>
              <tr v-if="expanded[t.id]" class="row-detail">
                <td></td>
                <td colspan="9" class="pa-0">
                  <div class="pa-3 detail-panel">
                    <div class="d-flex flex-wrap" style="gap:24px">
                      <div class="flex-grow-1" style="min-width:280px">
                        <div class="text-overline text-medium-emphasis mb-1">Items</div>
                        <v-table density="compact" class="bg-transparent">
                          <thead>
                            <tr>
                              <th>Product</th>
                              <th class="text-right">Qty</th>
                              <th class="text-right">Unit</th>
                              <th class="text-right">Subtotal</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr v-for="it in (t.items || [])" :key="it.id">
                              <td>{{ it.medication_name || it.stock_name || 'Item' }}<span v-if="it.category_name" class="text-caption text-medium-emphasis"> · {{ it.category_name }}</span></td>
                              <td class="text-right">{{ it.quantity }}</td>
                              <td class="text-right">{{ formatMoney(it.unit_price) }}</td>
                              <td class="text-right">{{ formatMoney(it.total_price) }}</td>
                            </tr>
                            <tr v-if="!(t.items || []).length"><td colspan="4" class="text-center text-medium-emphasis py-2">No item details available</td></tr>
                          </tbody>
                        </v-table>
                      </div>
                      <div style="min-width:220px">
                        <div class="text-overline text-medium-emphasis mb-1">Summary</div>
                        <div class="d-flex justify-space-between py-1"><span>Subtotal</span><span>{{ formatMoney(t.subtotal || 0) }}</span></div>
                        <div class="d-flex justify-space-between py-1"><span>Tax</span><span>{{ formatMoney(t.tax || 0) }}</span></div>
                        <div class="d-flex justify-space-between py-1"><span>Discount</span><span>−{{ formatMoney(t.discount || 0) }}</span></div>
                        <v-divider class="my-1" />
                        <div class="d-flex justify-space-between py-1 font-weight-bold"><span>Total</span><span class="text-primary">{{ formatMoney(t.total || 0) }}</span></div>
                        <div v-if="t.payment_reference" class="text-caption text-medium-emphasis mt-2">Ref: {{ t.payment_reference }}</div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </v-table>

        <div class="d-flex align-center justify-space-between mt-3">
          <div class="text-caption text-medium-emphasis">
            Showing {{ ((page - 1) * pageSize) + 1 }}–{{ Math.min(page * pageSize, filteredTx.length) }} of {{ filteredTx.length }}
          </div>
          <v-pagination v-model="page" :length="totalPages" :total-visible="6" density="comfortable" />
        </div>
      </div>
    </v-card>

    <!-- Receipt dialog -->
    <v-dialog v-model="receiptDialog" max-width="420">
      <v-card v-if="receiptTx" rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-receipt-text</v-icon>
          Receipt
          <v-spacer />
          <v-btn icon="mdi-printer" variant="text" @click="printReceipt(receiptTx)" />
          <v-btn icon="mdi-close" variant="text" @click="receiptDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="receipt-body">
          <div class="text-center mb-2">
            <div class="text-h6 font-weight-bold">AfyaOne Pharmacy</div>
            <div class="text-caption text-medium-emphasis">{{ formatDateTime(receiptTx.created_at) }}</div>
            <div class="text-caption">Receipt #{{ receiptTx.transaction_number || receiptTx.id }}</div>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between text-caption">
            <div>Cashier: {{ receiptTx.cashier_name || '—' }}</div>
            <div>{{ formatPayment(receiptTx.payment_method) }}</div>
          </div>
          <div class="text-caption">Customer: {{ receiptTx.customer_name || 'Walk-in' }}</div>
          <v-divider class="my-2" />
          <div v-for="it in (receiptTx.items || [])" :key="it.id" class="receipt-line">
            <div class="d-flex justify-space-between">
              <span class="text-body-2">{{ it.medication_name || it.stock_name }}</span>
              <span class="text-body-2 font-weight-medium">{{ formatMoney(it.total_price) }}</span>
            </div>
            <div class="text-caption text-medium-emphasis">{{ it.quantity }} × {{ formatMoney(it.unit_price) }}</div>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between"><span>Subtotal</span><span>{{ formatMoney(receiptTx.subtotal || 0) }}</span></div>
          <div class="d-flex justify-space-between"><span>Tax</span><span>{{ formatMoney(receiptTx.tax || 0) }}</span></div>
          <div class="d-flex justify-space-between"><span>Discount</span><span>−{{ formatMoney(receiptTx.discount || 0) }}</span></div>
          <div class="d-flex justify-space-between text-h6 font-weight-bold mt-1">
            <span>Total</span><span class="text-primary">{{ formatMoney(receiptTx.total || 0) }}</span>
          </div>
          <div v-if="receiptTx.payment_reference" class="text-caption text-medium-emphasis mt-2">Reference: {{ receiptTx.payment_reference }}</div>
          <div class="text-center text-caption text-medium-emphasis mt-3">Thank you for your visit!</div>
        </v-card-text>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import EmptyState from '~/components/EmptyState.vue'
import SparkArea from '~/components/SparkArea.vue'
import DonutRing from '~/components/DonutRing.vue'
import HourHeatmap from '~/components/HourHeatmap.vue'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()

const auth = useAuthStore()
const ADMIN_ROLES = ['super_admin', 'tenant_admin', 'pharmacist']
const canViewAll = computed(() => ADMIN_ROLES.includes(auth.role))

const loading = ref(false)
const txAll = ref([])

const search = ref('')
const paymentFilter = ref('all')
const statusFilter = ref('all')
const cashierFilter = ref('all')
const sortBy = ref('created_at')
const sortDir = ref('desc')
const page = ref(1)
const pageSize = 20
const expanded = ref({})
const trendMetric = ref('revenue')
const receiptDialog = ref(false)
const receiptTx = ref(null)

// --- range picker ---
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
  { key: 'thisMonth', label: 'This month' },
  { key: 'lastMonth', label: 'Last month' },
  { key: 'thisYear', label: 'This year' },
  { key: 'lastYear', label: 'Last year' },
  { key: '1y', label: 'Last 365 days' },
  { key: 'custom', label: 'Custom range…' }
]

function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
function addDays(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x }

function resolveRange(key) {
  const t = startOfDay(new Date())
  const tomorrow = addDays(t, 1)
  switch (key) {
    case 'today': return { start: t, end: tomorrow, label: 'Today' }
    case 'yesterday': return { start: addDays(t, -1), end: t, label: 'Yesterday' }
    case '7d': return { start: addDays(t, -6), end: tomorrow, label: 'Last 7 days' }
    case '30d': return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
    case '90d': return { start: addDays(t, -89), end: tomorrow, label: 'Last 90 days' }
    case '1y': return { start: addDays(t, -364), end: tomorrow, label: 'Last 365 days' }
    case 'thisMonth': return { start: new Date(t.getFullYear(), t.getMonth(), 1), end: tomorrow, label: 'This month' }
    case 'lastMonth': return { start: new Date(t.getFullYear(), t.getMonth() - 1, 1), end: new Date(t.getFullYear(), t.getMonth(), 1), label: 'Last month' }
    case 'thisYear': return { start: new Date(t.getFullYear(), 0, 1), end: tomorrow, label: 'This year' }
    case 'lastYear': return { start: new Date(t.getFullYear() - 1, 0, 1), end: new Date(t.getFullYear(), 0, 1), label: 'Last year' }
    case 'custom': return customRange.value || { start: addDays(t, -29), end: tomorrow, label: 'Custom' }
    default: return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
  }
}

const activeRange = computed(() => resolveRange(rangeKey.value))
const rangeStart = computed(() => activeRange.value.start)
const rangeEnd = computed(() => activeRange.value.end)
const rangeLabel = computed(() => activeRange.value.label)

function onRangeChange(val) {
  if (val === 'custom') {
    if (!customStart.value) customStart.value = rangeStart.value.toISOString().slice(0, 10)
    if (!customEnd.value) customEnd.value = addDays(rangeEnd.value, -1).toISOString().slice(0, 10)
    customDialog.value = true
  }
}
function applyCustom() {
  if (!customStart.value || !customEnd.value) return
  const s = startOfDay(new Date(customStart.value))
  const e = addDays(startOfDay(new Date(customEnd.value)), 1)
  if (e <= s) return
  const fmt = (d) => d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
  customRange.value = { start: s, end: e, label: `${fmt(s)} – ${fmt(addDays(e, -1))}` }
  rangeKey.value = 'custom'
  customDialog.value = false
}

// --- filtering ---
const inRange = computed(() => txAll.value.filter(t => {
  const d = new Date(t.created_at || 0)
  return d >= rangeStart.value && d < rangeEnd.value
}))

function itemsCount(t) {
  return (t.items || []).reduce((s, it) => s + Number(it.quantity || 0), 0) || (t.items || []).length
}

const filteredTx = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = inRange.value
  if (paymentFilter.value !== 'all') arr = arr.filter(t => (t.payment_method || '').toLowerCase() === paymentFilter.value)
  if (statusFilter.value !== 'all') arr = arr.filter(t => (t.status || 'completed').toLowerCase() === statusFilter.value)
  if (cashierFilter.value !== 'all') arr = arr.filter(t => String(t.cashier || '') === cashierFilter.value)
  if (q) {
    arr = arr.filter(t => {
      const blob = `${t.transaction_number || ''} ${t.customer_name || ''} ${t.customer_phone || ''}`.toLowerCase()
      return blob.includes(q)
    })
  }
  const dir = sortDir.value === 'desc' ? -1 : 1
  return [...arr].sort((a, b) => {
    let av, bv
    if (sortBy.value === 'created_at') { av = new Date(a.created_at || 0).getTime(); bv = new Date(b.created_at || 0).getTime() }
    else if (sortBy.value === 'total') { av = Number(a.total || 0); bv = Number(b.total || 0) }
    else if (sortBy.value === 'itemsCount') { av = itemsCount(a); bv = itemsCount(b) }
    else { av = String(a[sortBy.value] || ''); bv = String(b[sortBy.value] || '') }
    if (av < bv) return -1 * dir
    if (av > bv) return 1 * dir
    return 0
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredTx.value.length / pageSize)))
const pagedTx = computed(() => {
  const start = (page.value - 1) * pageSize
  return filteredTx.value.slice(start, start + pageSize)
})

watch([search, paymentFilter, statusFilter, cashierFilter, rangeKey], () => { page.value = 1; expanded.value = {} })

function setSort(key) {
  if (sortBy.value === key) sortDir.value = sortDir.value === 'desc' ? 'asc' : 'desc'
  else { sortBy.value = key; sortDir.value = 'desc' }
}

function toggleExpand(id) { expanded.value = { ...expanded.value, [id]: !expanded.value[id] } }

// --- KPIs ---
const kpis = computed(() => {
  const list = filteredTx.value
  const completed = list.filter(t => (t.status || 'completed').toLowerCase() === 'completed')
  const voided = list.filter(t => ['voided', 'cancelled', 'refunded'].includes((t.status || '').toLowerCase()))
  const revenue = completed.reduce((s, t) => s + Number(t.total || 0), 0)
  const gross = completed.reduce((s, t) => s + Number(t.subtotal || t.total || 0), 0)
  const discount = completed.reduce((s, t) => s + Number(t.discount || 0), 0)
  let itemsSold = 0
  const productSet = new Set()
  for (const t of completed) {
    for (const it of (t.items || [])) {
      itemsSold += Number(it.quantity || 0)
      productSet.add(it.medication_name || it.stock_name || it.stock)
    }
  }
  return {
    count: list.length,
    completedCount: completed.length,
    voidedCount: voided.length,
    revenue, gross, discount,
    itemsSold,
    uniqueProducts: productSet.size,
    aov: completed.length ? revenue / completed.length : 0
  }
})

// --- trend (revenue / orders / items per bucket) ---
function bucketLabel(d, weekly) {
  if (weekly) return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
}
const trend = computed(() => {
  const start = rangeStart.value
  const end = rangeEnd.value
  const dayMs = 86400000
  const days = Math.max(1, Math.round((end - start) / dayMs))
  const weekly = days > 90
  const stepDays = weekly ? 7 : 1
  const buckets = Math.max(1, Math.ceil(days / stepDays))
  const values = new Array(buckets).fill(0)
  const labels = []
  for (let i = 0; i < buckets; i++) {
    labels.push(bucketLabel(addDays(start, i * stepDays), weekly))
  }
  for (const t of filteredTx.value) {
    if ((t.status || 'completed').toLowerCase() !== 'completed') continue
    const d = new Date(t.created_at || 0)
    const idx = Math.floor((d - start) / dayMs / stepDays)
    if (idx < 0 || idx >= buckets) continue
    if (trendMetric.value === 'revenue') values[idx] += Number(t.total || 0)
    else if (trendMetric.value === 'orders') values[idx] += 1
    else values[idx] += itemsCount(t)
  }
  return { values, labels }
})

function moneyFormat(v) {
  if (v >= 1_000_000) return 'KES ' + (v / 1_000_000).toFixed(1) + 'M'
  if (v >= 1_000) return 'KES ' + (v / 1_000).toFixed(1) + 'k'
  return 'KES ' + Math.round(v)
}

// --- payment method breakdown ---
const PAYMENT_COLORS = {
  cash: '#22c55e', mpesa: '#16a34a', card: '#3b82f6', bank: '#8b5cf6',
  insurance: '#f59e0b', credit: '#ec4899', other: '#64748b'
}
function formatPayment(m) {
  if (!m) return 'Other'
  const map = { cash: 'Cash', mpesa: 'M-Pesa', card: 'Card', bank: 'Bank', insurance: 'Insurance', credit: 'Credit' }
  const k = String(m).toLowerCase()
  return map[k] || (k.charAt(0).toUpperCase() + k.slice(1))
}
function paymentColor(m) {
  return PAYMENT_COLORS[String(m || '').toLowerCase()] ? undefined : 'default'
}

const paymentBreakdown = computed(() => {
  const m = new Map()
  for (const t of filteredTx.value) {
    if ((t.status || 'completed').toLowerCase() !== 'completed') continue
    const k = String(t.payment_method || 'other').toLowerCase()
    const cur = m.get(k) || { method: k, label: formatPayment(k), count: 0, total: 0 }
    cur.count += 1
    cur.total += Number(t.total || 0)
    m.set(k, cur)
  }
  return [...m.values()].sort((a, b) => b.total - a.total)
})

const paymentSegments = computed(() => paymentBreakdown.value.map(p => ({
  value: p.total,
  color: PAYMENT_COLORS[p.method] || '#94a3b8',
  label: p.label
})))

// --- hour distribution ---
const hourCounts = computed(() => {
  const arr = new Array(24).fill(0)
  for (const t of filteredTx.value) {
    const d = new Date(t.created_at || 0)
    arr[d.getHours()] += 1
  }
  return arr
})

// --- top products ---
const topProducts = computed(() => {
  const m = new Map()
  for (const t of filteredTx.value) {
    if ((t.status || 'completed').toLowerCase() !== 'completed') continue
    for (const it of (t.items || [])) {
      const name = it.medication_name || it.stock_name || 'Item'
      const cur = m.get(name) || { name, qty: 0, revenue: 0 }
      cur.qty += Number(it.quantity || 0)
      cur.revenue += Number(it.total_price || 0)
      m.set(name, cur)
    }
  }
  return [...m.values()].sort((a, b) => b.revenue - a.revenue).slice(0, 8)
})

// --- filter option lists ---
const paymentFilterOptions = computed(() => {
  const set = new Set(inRange.value.map(t => String(t.payment_method || '').toLowerCase()).filter(Boolean))
  return [{ label: 'All payments', value: 'all' }, ...[...set].map(v => ({ label: formatPayment(v), value: v }))]
})
const statusFilterOptions = computed(() => {
  const set = new Set(inRange.value.map(t => String(t.status || 'completed').toLowerCase()))
  return [{ label: 'All statuses', value: 'all' }, ...[...set].map(v => ({ label: v.charAt(0).toUpperCase() + v.slice(1), value: v }))]
})
const cashierFilterOptions = computed(() => {
  const m = new Map()
  for (const t of inRange.value) {
    if (t.cashier == null) continue
    if (!m.has(String(t.cashier))) m.set(String(t.cashier), t.cashier_name || `Cashier #${t.cashier}`)
  }
  return [{ label: 'All cashiers', value: 'all' }, ...[...m.entries()].map(([value, label]) => ({ label, value }))]
})

function statusColor(s) {
  const k = String(s || 'completed').toLowerCase()
  if (k === 'completed') return 'success'
  if (k === 'pending') return 'warning'
  if (['voided', 'cancelled', 'refunded'].includes(k)) return 'error'
  return 'default'
}

function formatTime(v) {
  if (!v) return ''
  try { return new Date(v).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }) }
  catch { return '' }
}

// --- receipt / print / export ---
function openReceipt(t) { receiptTx.value = t; receiptDialog.value = true }

function printReceipt(t) {
  const w = window.open('', '_blank', 'width=420,height=640')
  if (!w) return
  const items = (t.items || []).map(it => `
    <tr>
      <td>${escapeHtml(it.medication_name || it.stock_name || 'Item')}<br><small>${it.quantity} × ${formatMoney(it.unit_price)}</small></td>
      <td style="text-align:right">${formatMoney(it.total_price)}</td>
    </tr>`).join('')
  w.document.write(`
    <html><head><title>Receipt ${t.transaction_number || t.id}</title>
    <style>
      body { font-family: monospace; font-size: 12px; padding: 12px; }
      h2 { margin: 0 0 4px; text-align:center; }
      table { width: 100%; border-collapse: collapse; }
      td { padding: 4px 0; vertical-align: top; }
      hr { border: none; border-top: 1px dashed #aaa; margin: 8px 0; }
      .row { display:flex; justify-content:space-between; padding: 2px 0; }
      .total { font-weight: bold; font-size: 14px; }
      .center { text-align:center; }
    </style></head><body>
      <h2>AfyaOne Pharmacy</h2>
      <div class="center"><small>${formatDateTime(t.created_at)}</small><br>
      <small>Receipt #${escapeHtml(t.transaction_number || String(t.id))}</small></div>
      <hr>
      <div class="row"><span>Cashier</span><span>${escapeHtml(t.cashier_name || '—')}</span></div>
      <div class="row"><span>Customer</span><span>${escapeHtml(t.customer_name || 'Walk-in')}</span></div>
      <div class="row"><span>Payment</span><span>${escapeHtml(formatPayment(t.payment_method))}</span></div>
      <hr>
      <table>${items}</table>
      <hr>
      <div class="row"><span>Subtotal</span><span>${formatMoney(t.subtotal || 0)}</span></div>
      <div class="row"><span>Tax</span><span>${formatMoney(t.tax || 0)}</span></div>
      <div class="row"><span>Discount</span><span>−${formatMoney(t.discount || 0)}</span></div>
      <div class="row total"><span>TOTAL</span><span>${formatMoney(t.total || 0)}</span></div>
      ${t.payment_reference ? `<div class="row"><span>Ref</span><span>${escapeHtml(t.payment_reference)}</span></div>` : ''}
      <hr>
      <div class="center"><small>Thank you for your visit!</small></div>
      <script>window.onload = () => { window.print(); }</` + `script>
    </body></html>`)
  w.document.close()
}

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}

function exportCsv() {
  const rows = [['Date', 'Receipt', 'Customer', 'Phone', 'Cashier', 'Payment', 'Items', 'Subtotal', 'Tax', 'Discount', 'Total', 'Status']]
  filteredTx.value.forEach(t => {
    rows.push([
      new Date(t.created_at || '').toISOString(),
      t.transaction_number || t.id,
      t.customer_name || '',
      t.customer_phone || '',
      t.cashier_name || '',
      formatPayment(t.payment_method),
      itemsCount(t),
      Number(t.subtotal || 0).toFixed(2),
      Number(t.tax || 0).toFixed(2),
      Number(t.discount || 0).toFixed(2),
      Number(t.total || 0).toFixed(2),
      t.status || 'completed'
    ])
  })
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `sales-history-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

async function load() {
  loading.value = true
  try {
    const r = await $api.get('/pos/transactions/?page_size=2000')
    txAll.value = r.data?.results || (Array.isArray(r.data) ? r.data : [])
  } catch { txAll.value = [] }
  loading.value = false
}

onMounted(load)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

.cursor-pointer { cursor: pointer; user-select: none; }
.legend-dot { display:inline-block; width:10px; height:10px; border-radius:50%; }

.sales-table thead th {
  font-weight: 700 !important;
  font-size: 13px !important;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgb(var(--v-theme-on-surface)) !important;
  background: rgba(var(--v-theme-primary), 0.08) !important;
  border-bottom: 2px solid rgba(var(--v-theme-primary), 0.35) !important;
  padding-top: 12px !important;
  padding-bottom: 12px !important;
  white-space: nowrap;
}
.sales-table thead th .v-icon { opacity: 0.85; }
.row-main td { border-bottom: 1px solid rgba(0,0,0,0.05); }
.row-detail td { background: rgba(0,0,0,0.015); }
.detail-panel { border-radius: 8px; }
.border-b { border-bottom: 1px solid rgba(0,0,0,0.06); }

.hour-grid { display: none; }

.receipt-body { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.receipt-line { padding: 2px 0; }
</style>
