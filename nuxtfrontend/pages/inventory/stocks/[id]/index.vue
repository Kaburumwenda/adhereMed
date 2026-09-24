<template>
  <v-container fluid class="pa-3 pa-md-5 sid-shell">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="primary" variant="tonal" rounded="lg" size="56">
          <v-icon size="30">mdi-pill</v-icon>
        </v-avatar>
        <div>
          <div class="d-flex align-center flex-wrap ga-2">
            <h1 class="text-h5 font-weight-bold mb-0">{{ stock.medication_name || 'Stock item' }}</h1>
            <v-chip v-if="stock.medication_id" size="small" variant="tonal" color="primary">{{ stock.medication_id }}</v-chip>
            <v-chip v-if="account.low_stock" size="small" variant="tonal" color="error" prepend-icon="mdi-alert">Low stock</v-chip>
          </div>
          <div class="d-flex align-center flex-wrap ga-2 mt-1">
            <v-chip v-if="stock.category_name" size="x-small" variant="tonal" prepend-icon="mdi-shape">{{ stock.category_name }}</v-chip>
            <v-chip v-if="stock.unit_name" size="x-small" variant="tonal" prepend-icon="mdi-ruler">{{ stock.unit_name }}</v-chip>
            <v-chip v-if="stock.branch_name" size="x-small" variant="tonal" prepend-icon="mdi-store">{{ stock.branch_name }}</v-chip>
            <v-chip v-if="stock.barcode" size="x-small" variant="tonal" prepend-icon="mdi-barcode">{{ stock.barcode }}</v-chip>
            <v-chip v-if="stock.prescription_required && stock.prescription_required !== 'none'" size="x-small" variant="tonal" color="purple" prepend-icon="mdi-script-text">Rx {{ stock.prescription_required }}</v-chip>
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="text" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" to="/inventory">Back</v-btn>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" variant="flat" prepend-icon="mdi-pencil" rounded="lg" class="text-none" :to="`/inventory/stocks/${id}/edit`">Edit</v-btn>
      </div>
    </div>

    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" size="40" />
    </div>

    <template v-else>
      <!-- Date filter bar -->
      <v-card flat rounded="xl" border class="pa-3 mb-4">
        <div class="d-flex align-center flex-wrap ga-2">
          <v-icon color="primary">mdi-calendar-range</v-icon>
          <div class="text-subtitle-2 font-weight-bold mr-2">Period</div>
          <v-select
            v-model="datePreset" :items="dateOptions" item-title="label" item-value="value"
            variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
            bg-color="surface" style="max-width: 190px"
            @update:model-value="onPeriodChange"
          />
          <template v-if="datePreset === 'custom'">
            <v-text-field
              v-model="dateFrom" type="date" label="From"
              variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
              bg-color="surface" style="max-width: 170px"
              @update:model-value="onPeriodChange"
            />
            <v-text-field
              v-model="dateTo" type="date" label="To"
              variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
              bg-color="surface" style="max-width: 170px"
              @update:model-value="onPeriodChange"
            />
          </template>
          <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-calendar">
            {{ periodLabel }}
          </v-chip>
          <v-spacer />
          <div class="text-caption text-medium-emphasis">
            Opening stock, sales stats and analytics follow this period
          </div>
        </div>
      </v-card>
      <!-- Account stock stat cards -->
      <v-row dense class="mb-4">
        <v-col cols="6" md="2" v-for="k in accountCards" :key="k.label">
          <v-card rounded="lg" elevation="0" class="pa-3 sid-kpi" :class="`sid-kpi-${k.key}`">
            <div class="d-flex align-center" style="gap:10px">
              <v-avatar :color="k.color" variant="tonal" rounded="lg" size="38">
                <v-icon size="19">{{ k.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis text-uppercase">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
                <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Tabs -->
      <v-card flat rounded="xl" border>
        <v-tabs v-model="tab" color="primary" density="comfortable">
          <v-tab value="overview" class="text-none"><v-icon start size="18">mdi-view-dashboard-outline</v-icon>Overview</v-tab>
          <v-tab value="transactions" class="text-none"><v-icon start size="18">mdi-swap-vertical</v-icon>Transactions</v-tab>
          <v-tab value="history" class="text-none"><v-icon start size="18">mdi-history</v-icon>History</v-tab>
          <v-tab value="analytics" class="text-none"><v-icon start size="18">mdi-chart-line</v-icon>Analytics</v-tab>
        </v-tabs>
        <v-divider />

        <v-tabs-window v-model="tab" class="pa-4 pa-md-5">
          <!-- ── OVERVIEW ─────────────────────────────────────────────── -->
          <v-tabs-window-item value="overview">
            <v-row dense>
              <!-- Purchase info -->
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="d-flex align-center mb-3">
                    <v-icon color="primary" class="mr-2">mdi-cart-outline</v-icon>
                    <div class="text-subtitle-1 font-weight-bold">Purchase info</div>
                    <v-spacer />
                    <v-chip size="x-small" variant="tonal" color="primary">
                      {{ purchase.recent.length }} lines
                    </v-chip>
                  </div>
                  <div class="d-flex flex-wrap ga-2 mb-3">
                    <v-chip size="small" variant="tonal" prepend-icon="mdi-cash">Cost {{ formatMoney(stock.cost_price) }}</v-chip>
                    <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-cash-plus">Sell {{ formatMoney(stock.selling_price) }}</v-chip>
                    <v-chip v-if="purchase.last_purchase" size="small" variant="tonal" color="info" prepend-icon="mdi-truck-delivery">
                      Last: {{ purchase.last_purchase.supplier || purchase.last_purchase.po_number }}
                    </v-chip>
                  </div>
                  <div class="text-overline text-medium-emphasis mb-1">Recent purchases</div>
                  <table v-if="purchase.recent.length" class="sid-mini-table">
                    <thead><tr><th>PO #</th><th>Date</th><th>Supplier</th><th class="text-right">Qty</th><th class="text-right">Unit cost</th></tr></thead>
                    <tbody>
                      <tr v-for="p in purchase.recent.slice(0, 8)" :key="p.po_number + p.date">
                        <td class="font-weight-medium text-primary">{{ p.po_number }}</td>
                        <td>{{ formatDate(p.date) }}</td>
                        <td>{{ p.supplier || '—' }}</td>
                        <td class="text-right">{{ p.qty }}</td>
                        <td class="text-right">{{ formatMoney(p.unit_cost) }}</td>
                      </tr>
                    </tbody>
                  </table>
                  <div v-else class="text-body-2 text-medium-emphasis">No purchase orders recorded for this item yet.</div>
                </v-card>
              </v-col>
              <!-- Sales info -->
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="d-flex align-center mb-3">
                    <v-icon color="success" class="mr-2">mdi-cash-register</v-icon>
                    <div class="text-subtitle-1 font-weight-bold">Sales info</div>
                    <v-spacer />
                    <v-chip size="x-small" variant="tonal" color="success">
                      Last {{ periodDays }}d
                    </v-chip>
                  </div>
                  <div class="d-flex flex-wrap ga-2 mb-3">
                    <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-pill-multiple">
                      {{ salesInfo.units_sold_period }} units sold
                    </v-chip>
                    <v-chip size="small" variant="tonal" color="info" prepend-icon="mdi-cash-multiple">
                      {{ formatMoney(salesInfo.revenue_period) }} revenue
                    </v-chip>
                    <v-chip v-if="salesInfo.last_sale_at" size="small" variant="tonal" prepend-icon="mdi-clock-outline">
                      Last sale {{ relativeTime(salesInfo.last_sale_at) }}
                    </v-chip>
                  </div>
                  <div class="text-overline text-medium-emphasis mb-1">Recent sales</div>
                  <table v-if="salesInfo.recent.length" class="sid-mini-table">
                    <thead><tr><th>Receipt</th><th>Date</th><th class="text-right">Qty</th><th class="text-right">Unit price</th><th class="text-right">Total</th></tr></thead>
                    <tbody>
                      <tr v-for="s in salesInfo.recent.slice(0, 8)" :key="s.transaction_number + s.date">
                        <td class="font-weight-medium text-primary">{{ s.transaction_number }}</td>
                        <td>{{ formatDate(s.date) }}</td>
                        <td class="text-right">{{ s.qty }}</td>
                        <td class="text-right">{{ formatMoney(s.unit_price) }}</td>
                        <td class="text-right font-weight-medium">{{ formatMoney(s.total) }}</td>
                      </tr>
                    </tbody>
                  </table>
                  <div v-else class="text-body-2 text-medium-emphasis">No sales recorded yet.</div>
                </v-card>
              </v-col>
            </v-row>
          </v-tabs-window-item>

          <!-- ── TRANSACTIONS ──────────────────────────────────────────── -->
          <v-tabs-window-item value="transactions">
            <div class="text-subtitle-2 text-medium-emphasis mb-2">
              {{ movements.length }} stock movements · running balance
            </div>
            <div class="table-wrap">
              <table class="inv-table">
                <thead>
                  <tr>
                    <th class="row-num">#</th>
                    <th>When</th>
                    <th>Type</th>
                    <th>Detail</th>
                    <th>Reference</th>
                    <th class="text-right">Before</th>
                    <th class="text-right">Change</th>
                    <th class="text-right">After</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(m, i) in movements" :key="i">
                    <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
                    <td>{{ formatDateTime(m.timestamp) }}</td>
                    <td>
                      <v-chip :color="movementMeta(m).color" size="x-small" variant="tonal">
                        <v-icon start size="12">{{ movementMeta(m).icon }}</v-icon>{{ movementMeta(m).label }}
                      </v-chip>
                    </td>
                    <td>{{ m.label }}</td>
                    <td class="text-caption text-medium-emphasis">{{ m.reference || '—' }}</td>
                    <td class="text-right text-medium-emphasis">{{ m.qty_before }}</td>
                    <td class="text-right font-weight-bold" :class="m.quantity_change > 0 ? 'text-success' : 'text-error'">
                      {{ m.quantity_change > 0 ? '+' : '' }}{{ m.quantity_change }}
                    </td>
                    <td class="text-right font-weight-medium">{{ m.qty_after }}</td>
                  </tr>
                  <tr v-if="!movements.length">
                    <td colspan="8" class="text-center text-medium-emphasis py-6">No stock movements recorded.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </v-tabs-window-item>

          <!-- ── HISTORY ──────────────────────────────────────────────── -->
          <v-tabs-window-item value="history">
            <v-row dense>
              <v-col cols="12" md="7">
                <div class="text-subtitle-2 font-weight-bold mb-2">Batch history</div>
                <div class="table-wrap">
                  <table class="inv-table">
                    <thead>
                      <tr>
                        <th class="row-num">#</th>
                        <th>Batch #</th>
                        <th>Received</th>
                        <th class="text-right">Received qty</th>
                        <th class="text-right">Remaining</th>
                        <th class="text-right">Cost/unit</th>
                        <th>Expiry</th>
                        <th>Supplier</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="(b, i) in batches" :key="b.id">
                        <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
                        <td class="font-weight-medium">{{ b.batch_number || '—' }}</td>
                        <td>{{ formatDate(b.received_date) }}</td>
                        <td class="text-right">{{ b.quantity_received }}</td>
                        <td class="text-right" :class="b.quantity_remaining > 0 ? '' : 'text-disabled'">{{ b.quantity_remaining }}</td>
                        <td class="text-right">{{ formatMoney(b.cost_price_per_unit) }}</td>
                        <td>
                          <span :class="expiryClass(b)">{{ formatDate(b.expiry_date) }}</span>
                        </td>
                        <td>{{ b.supplier_name || '—' }}</td>
                      </tr>
                      <tr v-if="!batches.length">
                        <td colspan="8" class="text-center text-medium-emphasis py-6">No batches recorded.</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </v-col>
              <v-col cols="12" md="5">
                <div class="text-subtitle-2 font-weight-bold mb-2">Purchase price history</div>
                <div v-if="priceHistory.length" class="d-flex flex-column ga-2">
                  <v-card v-for="(p, i) in priceHistory.slice().reverse()" :key="i" flat rounded="lg" border class="pa-3">
                    <div class="d-flex align-center justify-space-between">
                      <div>
                        <div class="text-caption text-medium-emphasis">{{ formatDate(p.date) || '—' }}</div>
                        <div class="text-body-2">{{ p.qty }} units @ <b>{{ formatMoney(p.unit_cost) }}</b></div>
                      </div>
                      <v-icon :color="trendIcon(p, i).color" size="20">{{ trendIcon(p, i).icon }}</v-icon>
                    </div>
                  </v-card>
                </div>
                <div v-else class="text-body-2 text-medium-emphasis">No purchase price history yet.</div>
              </v-col>
            </v-row>
          </v-tabs-window-item>

          <!-- ── ANALYTICS ─────────────────────────────────────────────── -->
          <v-tabs-window-item value="analytics">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="text-subtitle-2 font-weight-bold mb-3">Units sold per day</div>
                  <LineChart
                    :series="[{ label: 'Units sold', color: '#16a34a', values: trend.map(t => t.sold) }]"
                    :labels="trend.map(t => t.date.slice(5))"
                    :height="220"
                  />
                </v-card>
              </v-col>
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="text-subtitle-2 font-weight-bold mb-3">Stock received per day</div>
                  <BarChart
                    :values="trend.map(t => t.received)"
                    :labels="trend.map(t => t.date.slice(5))"
                    color="#0d9488"
                    :height="220"
                  />
                </v-card>
              </v-col>
              <v-col cols="12" md="3" v-for="a in analyticsCards" :key="a.label">
                <v-card flat rounded="lg" border class="pa-3">
                  <div class="text-caption text-medium-emphasis text-uppercase">{{ a.label }}</div>
                  <div class="text-h6 font-weight-bold">{{ a.value }}</div>
                  <div v-if="a.sub" class="text-caption text-medium-emphasis">{{ a.sub }}</div>
                </v-card>
              </v-col>
            </v-row>
          </v-tabs-window-item>
        </v-tabs-window>
      </v-card>
    </template>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const route = useRoute()
const { $api } = useNuxtApp()

const id = computed(() => route.params.id)
const loading = ref(true)
const tab = ref('overview')
const datePreset = ref('30')
const dateFrom = ref(null)
const dateTo = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const dateOptions = [
  { label: 'Last 7 days', value: '7' },
  { label: 'Last 30 days', value: '30' },
  { label: 'Last 90 days', value: '90' },
  { label: 'Last 365 days', value: '365' },
  { label: 'Custom range', value: 'custom' },
]

const periodDays = computed(() => {
  if (datePreset.value === 'custom') {
    const from = dateFrom.value ? new Date(dateFrom.value) : null
    const to = dateTo.value ? new Date(dateTo.value) : null
    if (from && to) return Math.max(1, Math.round((to - from) / 86400000) + 1)
    return 30
  }
  return Number(datePreset.value) || 30
})

function onPeriodChange() {
  if (datePreset.value === 'custom' && !(dateFrom.value && dateTo.value)) return
  load()
}

const stock = ref({})
const account = ref({ on_hand: 0, committed: 0, available_for_sale: 0, reorder_level: 0, low_stock: false })
const openingStock = ref(0)
const period = ref({ received: 0, sold: 0, returned: 0, adjusted: 0, transferred_out: 0, units_sold: 0, sales_revenue: 0 })
const purchase = ref({ current_cost: 0, recent: [], last_purchase: null, price_history: [] })
const salesInfo = ref({ units_sold_period: 0, revenue_period: 0, last_sale_at: null, recent: [] })
const movements = ref([])
const batches = ref([])
const trend = ref([])

const accountCards = computed(() => [
  { key: 'opening', label: 'Opening stock', icon: 'mdi-package-up', color: 'indigo',
    value: openingStock.value, sub: `as of ${formatDate(periodStart.value)}` },
  { key: 'onhand', label: 'Stock on hand', icon: 'mdi-cube-outline', color: 'primary',
    value: account.value.on_hand, sub: stock.value.unit_abbreviation || '' },
  { key: 'committed', label: 'Committed stock', icon: 'mdi-lock-outline', color: 'orange',
    value: account.value.committed, sub: 'reserved by SOs' },
  { key: 'available', label: 'Available for sale', icon: 'mdi-check-circle-outline', color: 'success',
    value: account.value.available_for_sale, sub: 'on hand − committed' },
  { key: 'sold', label: `Sold (${periodDays.value}d)`, icon: 'mdi-pill-multiple', color: 'teal',
    value: period.value.sold, sub: formatMoney(period.value.sales_revenue) },
  { key: 'reorder', label: 'Reorder level', icon: 'mdi-bell-outline', color: account.value.low_stock ? 'error' : 'grey',
    value: account.value.reorder_level, sub: account.value.low_stock ? 'Low — reorder now' : 'Healthy' },
])

const periodStart = ref('')
const periodEnd = ref('')

const periodLabel = computed(() => {
  const fmt = d => new Date(d).toLocaleDateString('en-KE', { day: 'numeric', month: 'short', year: 'numeric' })
  if (datePreset.value === 'custom' && periodStart.value && periodEnd.value) {
    return `${fmt(periodStart.value)} → ${fmt(periodEnd.value)}`
  }
  if (periodStart.value && periodEnd.value) {
    return `${fmt(periodStart.value)} → ${fmt(periodEnd.value)}`
  }
  return `Last ${periodDays.value} days`
})

const priceHistory = computed(() => purchase.value.price_history || [])

const analyticsCards = computed(() => {
  const days = trend.value.length || 1
  const totalSold = trend.value.reduce((s, t) => s + t.sold, 0)
  const totalReceived = trend.value.reduce((s, t) => s + t.received, 0)
  const best = trend.value.reduce((b, t) => (t.sold > b.sold ? t : b), { sold: 0, date: '—' })
  return [
    { label: 'Avg daily sales', value: (totalSold / days).toFixed(1), sub: 'units / day' },
    { label: 'Total sold', value: totalSold, sub: `in ${periodDays.value} days` },
    { label: 'Total received', value: totalReceived, sub: `${periodDays.value}-day window` },
    { label: 'Best sales day', value: `${best.sold}`, sub: best.date !== '—' ? formatDate(best.date) : 'No sales' },
  ]
})

const MOVEMENT_META = {
  receipt: { label: 'Received', color: 'success', icon: 'mdi-arrow-down-bold' },
  sale: { label: 'Sale', color: 'error', icon: 'mdi-arrow-up-bold' },
  return: { label: 'Return', color: 'info', icon: 'mdi-keyboard-return' },
  adjustment: { label: 'Adjustment', color: 'warning', icon: 'mdi-tune' },
  transfer_out: { label: 'Transfer out', color: 'purple', icon: 'mdi-swap-horizontal' },
  so_fulfillment: { label: 'SO delivered', color: 'teal', icon: 'mdi-package-variant-closed-check' },
}
function movementMeta(m) { return MOVEMENT_META[m.type] || { label: m.type, color: 'grey', icon: 'mdi-swap-vertical' } }

function trendIcon(p, i) {
  if (i <= 0) return { icon: 'mdi-trending-neutral', color: 'grey' }
  const list = priceHistory.value.slice().reverse()
  const older = list[i - 1]
  if (!older || older.unit_cost === p.unit_cost) return { icon: 'mdi-trending-neutral', color: 'grey' }
  return p.unit_cost > older.unit_cost
    ? { icon: 'mdi-trending-up', color: 'error' }
    : { icon: 'mdi-trending-down', color: 'success' }
}

function expiryClass(b) {
  if (!b.expiry_date || b.is_expired) return 'text-error font-weight-medium'
  const days = (new Date(b.expiry_date) - new Date()) / 86400000
  if (days < 90) return 'text-warning'
  return ''
}

async function load() {
  loading.value = true
  try {
    const params = {}
    if (datePreset.value === 'custom') {
      if (dateFrom.value) params.date_from = dateFrom.value
      if (dateTo.value) params.date_to = dateTo.value
    } else {
      params.days = periodDays.value
    }
    const { data } = await $api.get(`/inventory/stocks/${id.value}/insights/`, { params })
    stock.value = data.stock || {}
    account.value = data.account || {}
    openingStock.value = data.opening_stock ?? 0
    periodStart.value = data.period_start || ''
    periodEnd.value = data.period_end || ''
    period.value = data.period || {}
    purchase.value = data.purchase_info || {}
    salesInfo.value = data.sales_info || {}
    movements.value = data.movements || []
    batches.value = data.batches || []
    trend.value = data.trend || []
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to load item details.'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

function formatDate(d) {
  if (!d) return '—'
  const dt = new Date(d)
  return dt.toLocaleDateString('en-KE', { month: 'short', day: 'numeric', year: 'numeric' })
}

function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('en-KE', {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

function relativeTime(d) {
  if (!d) return ''
  const diff = Date.now() - new Date(d).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `${Math.max(1, mins)}m ago`
  const h = Math.floor(mins / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

onMounted(load)
</script>

<style scoped>
.sid-shell { max-width: 1500px; margin: 0 auto; }
.sid-kpi { border-left: 4px solid transparent; }
.sid-kpi-opening { border-left-color: #6366f1; }
.sid-kpi-onhand { border-left-color: #0d9488; }
.sid-kpi-committed { border-left-color: #f59e0b; }
.sid-kpi-available { border-left-color: #16a34a; }
.sid-kpi-sold { border-left-color: #0ea5e9; }
.sid-kpi-reorder { border-left-color: #dc2626; }

.table-wrap { overflow-x: auto; }
.inv-table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
.inv-table th {
  text-align: left; padding: 10px 10px; white-space: nowrap;
  border-bottom: 2px solid rgba(var(--v-border-color), var(--v-border-opacity));
  font-size: 11.5px; text-transform: uppercase; letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.inv-table td { padding: 9px 10px; border-bottom: 1px solid rgba(var(--v-border-color), 0.4); white-space: nowrap; }
.inv-table tbody tr:hover { background: rgba(99, 102, 241, 0.04); }
.row-num { width: 44px; color: rgba(var(--v-theme-on-surface), 0.45); }

.sid-mini-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.sid-mini-table th {
  text-align: left; padding: 6px 8px; font-size: 10.5px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
  border-bottom: 1px solid rgba(var(--v-border-color), 0.5);
}
.sid-mini-table td { padding: 7px 8px; border-bottom: 1px solid rgba(var(--v-border-color), 0.3); }
.sid-mini-table tbody tr:hover { background: rgba(99, 102, 241, 0.04); }
</style>
