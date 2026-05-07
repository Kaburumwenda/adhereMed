<template>
  <v-container fluid class="pa-3 pa-md-5 analytics-page">
    <!-- HERO -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4 position-relative overflow-hidden">
      <div class="hero-glow"></div>
      <v-row align="center" no-gutters style="position:relative;z-index:1">
        <v-col cols="12" md="7">
          <div class="d-flex align-center">
            <v-avatar color="white" size="60" class="mr-4 elevation-4">
              <v-icon color="indigo-darken-3" size="34">mdi-chart-box-multiple</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline" style="opacity:0.85; letter-spacing:2px">ANALYTICS</div>
              <div class="text-h5 text-md-h4 font-weight-bold">Reports Dashboard</div>
              <div class="text-body-2 mt-1" style="opacity:0.9">
                {{ rangeLabel }} · Sales · Inventory · Cashiers · P&amp;L
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="5" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="outlined" prepend-icon="mdi-printer" @click="printPage">Print</v-btn>
          <v-btn color="white" variant="elevated" class="text-indigo-darken-3"
                 prepend-icon="mdi-refresh" :loading="loading" @click="reload">Refresh</v-btn>
        </v-col>
      </v-row>

      <!-- Hero KPI strip -->
      <v-row class="mt-5" dense style="position:relative;z-index:1">
        <v-col v-for="k in heroKpis" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-start">
              <v-avatar :color="k.color" size="40" class="mr-3 elevation-2">
                <v-icon color="white" size="22">{{ k.icon }}</v-icon>
              </v-avatar>
              <div class="flex-grow-1">
                <div class="text-caption" style="opacity:0.85">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
                <div v-if="k.sub" class="text-caption mt-1" style="opacity:0.75">{{ k.sub }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- PERIOD SELECTOR -->
    <v-card flat rounded="xl" border class="mb-4 pa-3">
      <div class="d-flex flex-wrap align-center" style="gap:12px">
        <v-icon color="indigo" class="ml-1">mdi-calendar-range</v-icon>
        <span class="text-subtitle-2 font-weight-bold mr-2">Period</span>
        <v-chip-group v-model="period" mandatory selected-class="bg-indigo text-white"
                      @update:model-value="onPeriodChange">
          <v-chip v-for="opt in periodOptions" :key="opt.value" :value="opt.value"
                  variant="outlined" size="small" class="font-weight-medium">
            {{ opt.title }}
          </v-chip>
          <v-chip value="custom" variant="outlined" size="small" class="font-weight-medium"
                  prepend-icon="mdi-calendar-edit">
            Custom
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <v-chip v-if="period === 'custom' && customFrom && customTo" color="indigo" variant="tonal" size="small">
          {{ customFrom }} → {{ customTo }}
        </v-chip>
      </div>
    </v-card>

    <!-- TABS -->
    <v-card flat rounded="xl" border class="mb-4">
      <v-tabs v-model="tab" color="indigo" align-tabs="start" show-arrows
              slider-color="indigo" density="comfortable">
        <v-tab v-for="t in tabs" :key="t.value" :value="t.value" class="text-none font-weight-medium">
          <v-icon start>{{ t.icon }}</v-icon>{{ t.label }}
        </v-tab>
      </v-tabs>
    </v-card>

    <v-window v-model="tab">
      <!-- SALES SUMMARY -->
      <v-window-item value="sales">
        <v-row dense>
          <v-col v-for="k in salesKpis" :key="k.label" cols="6" md="3">
            <v-card flat rounded="xl" border class="pa-4 stat-card" :class="`accent-${k.color}`">
              <div class="d-flex align-center justify-space-between mb-2">
                <v-avatar :color="k.color" size="36" variant="tonal">
                  <v-icon size="20">{{ k.icon }}</v-icon>
                </v-avatar>
              </div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold mt-1">{{ k.value }}</div>
            </v-card>
          </v-col>
        </v-row>

        <v-row dense class="mt-2">
          <v-col cols="12" md="6">
            <v-card flat rounded="xl" border>
              <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
                <v-icon color="green" class="mr-2">mdi-point-of-sale</v-icon>POS Payment Mix
              </v-card-title>
              <PaymentMixList :rows="data.sales?.payment_mix_pos || []" color="green" />
            </v-card>
          </v-col>
          <v-col cols="12" md="6">
            <v-card flat rounded="xl" border>
              <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
                <v-icon color="blue" class="mr-2">mdi-clipboard-check</v-icon>Dispensing Payment Mix
              </v-card-title>
              <PaymentMixList :rows="data.sales?.payment_mix_dispensing || []" color="blue" />
            </v-card>
          </v-col>
        </v-row>
      </v-window-item>

      <!-- TOP PRODUCTS -->
      <v-window-item value="top">
        <v-card flat rounded="xl" border>
          <v-card-title class="d-flex align-center">
            <v-icon color="amber-darken-2" class="mr-2">mdi-trophy</v-icon>
            <span class="font-weight-bold">Top Selling Medications</span>
            <v-spacer />
            <v-chip size="small" variant="tonal" color="amber">{{ rankedTop.length }} items</v-chip>
          </v-card-title>
          <v-data-table :headers="topHeaders" :items="rankedTop" :loading="loading" items-per-page="20" density="comfortable">
            <template #item.rank="{ item }">
              <v-avatar v-if="item.rank <= 3" :color="['amber', 'grey-lighten-1', 'orange-darken-2'][item.rank - 1]" size="28">
                <span class="text-caption font-weight-bold text-white">{{ item.rank }}</span>
              </v-avatar>
              <span v-else class="text-medium-emphasis">{{ item.rank }}</span>
            </template>
            <template #item.medication_name="{ item }">
              <div class="font-weight-medium">{{ item.medication_name }}</div>
            </template>
            <template #item.quantity="{ item }">{{ Number(item.quantity || 0).toLocaleString() }}</template>
            <template #item.revenue="{ item }"><strong>KSh {{ fmt(item.revenue) }}</strong></template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- CASHIERS -->
      <v-window-item value="cashiers">
        <v-card flat rounded="xl" border>
          <v-card-title class="d-flex align-center">
            <v-icon color="purple" class="mr-2">mdi-account-tie</v-icon>
            <span class="font-weight-bold">Cashier Performance</span>
          </v-card-title>
          <v-data-table :headers="cashierHeaders" :items="data.cashiers?.cashiers || []"
                        :loading="loading" density="comfortable">
            <template #item.name="{ item }">
              <div class="d-flex align-center">
                <v-avatar color="purple" variant="tonal" size="32" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
                </v-avatar>
                <span class="font-weight-medium">{{ item.name }}</span>
              </div>
            </template>
            <template #item.revenue="{ item }"><strong>KSh {{ fmt(item.revenue) }}</strong></template>
            <template #item.discount="{ item }">KSh {{ fmt(item.discount) }}</template>
            <template #item.avg_basket="{ item }">KSh {{ fmt(item.avg_basket) }}</template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- P&L -->
      <v-window-item value="pnl">
        <v-row dense>
          <v-col v-for="k in pnlKpis" :key="k.label" cols="6" md="3">
            <v-card flat rounded="xl" border class="pa-4 stat-card" :class="`accent-${k.accent}`">
              <div class="d-flex align-center justify-space-between mb-2">
                <v-avatar :color="k.accent" size="36" variant="tonal">
                  <v-icon size="20">{{ k.icon }}</v-icon>
                </v-avatar>
              </div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold mt-1" :class="k.color">{{ k.value }}</div>
            </v-card>
          </v-col>
        </v-row>

        <v-card flat rounded="xl" border class="mt-3 pa-5">
          <div class="d-flex align-center mb-4">
            <v-icon color="indigo" class="mr-2">mdi-file-chart</v-icon>
            <span class="text-h6 font-weight-bold">Income Statement</span>
            <v-spacer />
            <v-chip size="small" variant="tonal" color="indigo">{{ rangeLabel }}</v-chip>
          </div>

          <PnlRow label="POS Revenue" :value="data.pnl?.pos_revenue" />
          <PnlRow label="Dispensing Revenue" :value="data.pnl?.dispensing_revenue" />
          <v-divider class="my-2" />
          <PnlRow label="Total Revenue" :value="data.pnl?.revenue" bold />
          <PnlRow label="Cost of Goods Sold" :value="data.pnl?.cogs" negative />
          <v-divider class="my-2" />
          <PnlRow label="Gross Profit" :value="data.pnl?.gross_profit" bold positive />
          <div class="d-flex justify-end mb-2">
            <v-chip size="x-small" variant="tonal"
                    :color="(data.pnl?.gross_margin_pct || 0) >= 30 ? 'success' : 'orange'">
              Margin: {{ Number(data.pnl?.gross_margin_pct || 0).toFixed(1) }}%
            </v-chip>
          </div>
          <PnlRow label="Operating Expenses" :value="data.pnl?.expenses" negative />
          <v-divider class="my-3" thickness="2" />
          <div class="d-flex justify-space-between align-center pa-3 rounded-lg"
               :style="{ background: (data.pnl?.net_profit || 0) >= 0 ? '#e8f5e9' : '#ffebee' }">
            <span class="text-h6 font-weight-bold">Net Profit</span>
            <span class="text-h5 font-weight-bold" :class="(data.pnl?.net_profit || 0) >= 0 ? 'text-success' : 'text-error'">
              KSh {{ fmt(data.pnl?.net_profit) }}
            </span>
          </div>
        </v-card>
      </v-window-item>

      <!-- INVENTORY -->
      <v-window-item value="inventory">
        <v-row dense>
          <v-col cols="6" md="3">
            <v-card flat rounded="xl" border class="pa-4 stat-card accent-blue">
              <v-avatar color="blue" size="36" variant="tonal" class="mb-2"><v-icon>mdi-package-variant</v-icon></v-avatar>
              <div class="text-caption text-medium-emphasis">SKUs</div>
              <div class="text-h5 font-weight-bold">{{ data.inventory?.sku_count || 0 }}</div>
            </v-card>
          </v-col>
          <v-col cols="6" md="3">
            <v-card flat rounded="xl" border class="pa-4 stat-card accent-cyan">
              <v-avatar color="cyan" size="36" variant="tonal" class="mb-2"><v-icon>mdi-counter</v-icon></v-avatar>
              <div class="text-caption text-medium-emphasis">Units in Stock</div>
              <div class="text-h5 font-weight-bold">{{ Number(data.inventory?.unit_count || 0).toLocaleString() }}</div>
            </v-card>
          </v-col>
          <v-col cols="6" md="3">
            <v-card flat rounded="xl" border class="pa-4 stat-card accent-orange">
              <v-avatar color="orange" size="36" variant="tonal" class="mb-2"><v-icon>mdi-cash-multiple</v-icon></v-avatar>
              <div class="text-caption text-medium-emphasis">Cost Value</div>
              <div class="text-h5 font-weight-bold">KSh {{ fmt(data.inventory?.cost_value) }}</div>
            </v-card>
          </v-col>
          <v-col cols="6" md="3">
            <v-card flat rounded="xl" border class="pa-4 stat-card accent-success">
              <v-avatar color="success" size="36" variant="tonal" class="mb-2"><v-icon>mdi-trending-up</v-icon></v-avatar>
              <div class="text-caption text-medium-emphasis">Potential Margin</div>
              <div class="text-h5 font-weight-bold text-success">KSh {{ fmt(data.inventory?.potential_margin) }}</div>
            </v-card>
          </v-col>
        </v-row>

        <v-card flat rounded="xl" border class="mt-3">
          <v-card-title class="d-flex align-center">
            <v-icon color="blue" class="mr-2">mdi-shape</v-icon>
            <span class="font-weight-bold">Inventory by Category</span>
          </v-card-title>
          <v-data-table :headers="invHeaders" :items="data.inventory?.by_category || []"
                        :loading="loading" items-per-page="20" density="comfortable">
            <template #item.cost="{ item }">KSh {{ fmt(item.cost) }}</template>
            <template #item.sale="{ item }"><strong>KSh {{ fmt(item.sale) }}</strong></template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- EXPIRY -->
      <v-window-item value="expiry">
        <v-alert v-if="data.expiry" type="warning" variant="tonal" rounded="xl" class="mb-3" border="start">
          <div class="d-flex align-center justify-space-between flex-wrap" style="gap:8px">
            <div>
              <strong>{{ data.expiry.count }}</strong> batches expiring within
              <strong>{{ data.expiry.days_horizon }}</strong> days
            </div>
            <v-chip color="error" variant="flat" size="small" prepend-icon="mdi-cash-remove">
              Expired loss: KSh {{ fmt(data.expiry.expired_loss_value) }}
            </v-chip>
          </div>
        </v-alert>
        <v-card flat rounded="xl" border>
          <v-data-table :headers="expHeaders" :items="data.expiry?.batches || []"
                        :loading="loading" items-per-page="20" density="comfortable">
            <template #item.medication_name="{ item }">
              <div class="font-weight-medium">{{ item.medication_name }}</div>
            </template>
            <template #item.days_left="{ item }">
              <v-chip size="small" variant="flat"
                      :color="item.days_left < 0 ? 'red' : item.days_left < 30 ? 'orange' : 'amber'">
                {{ item.days_left < 0 ? 'EXPIRED' : item.days_left + 'd' }}
              </v-chip>
            </template>
            <template #item.cost_value="{ item }"><strong>KSh {{ fmt(item.cost_value) }}</strong></template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- LOW STOCK -->
      <v-window-item value="lowstock">
        <v-alert v-if="data.lowstock" type="info" variant="tonal" rounded="xl" class="mb-3" border="start">
          <div class="d-flex align-center justify-space-between flex-wrap" style="gap:8px">
            <div><strong>{{ data.lowstock.count }}</strong> items below reorder level</div>
            <v-chip color="primary" variant="flat" size="small" prepend-icon="mdi-cart-arrow-down">
              Reorder value: KSh {{ fmt(data.lowstock.estimated_reorder_value) }}
            </v-chip>
          </div>
        </v-alert>
        <v-card flat rounded="xl" border>
          <v-data-table :headers="lowHeaders" :items="data.lowstock?.items || []"
                        :loading="loading" items-per-page="20" density="comfortable">
            <template #item.medication_name="{ item }">
              <div class="font-weight-medium">{{ item.medication_name }}</div>
            </template>
            <template #item.quantity="{ item }">
              <v-chip size="small" variant="tonal" color="error">{{ item.quantity }}</v-chip>
            </template>
            <template #item.estimated_reorder_cost="{ item }"><strong>KSh {{ fmt(item.estimated_reorder_cost) }}</strong></template>
          </v-data-table>
        </v-card>
      </v-window-item>
    </v-window>

    <!-- CUSTOM RANGE DIALOG -->
    <v-dialog v-model="customDialog" max-width="420" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="indigo" class="mr-2">mdi-calendar-edit</v-icon>Custom Date Range
        </v-card-title>
        <v-card-text>
          <v-text-field v-model="customFrom" type="date" label="From"
                        variant="outlined" density="comfortable" prepend-inner-icon="mdi-calendar-start" />
          <v-text-field v-model="customTo" type="date" label="To" :min="customFrom"
                        variant="outlined" density="comfortable" prepend-inner-icon="mdi-calendar-end" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="cancelCustom">Cancel</v-btn>
          <v-btn color="indigo" :disabled="!customFrom || !customTo" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, h } from 'vue'
const { $api } = useNuxtApp()

const tab = ref('sales')
const period = ref('month')
const previousPeriod = ref('month')
const loading = ref(false)
const data = ref({})
const customDialog = ref(false)
const customFrom = ref('')
const customTo = ref('')
const snack = ref({ show: false, color: 'success', text: '' })

const periodOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Yesterday', value: 'yesterday' },
  { title: 'Last 7 Days', value: 'last7' },
  { title: 'Last 30 Days', value: 'last30' },
  { title: 'Last 90 Days', value: 'last90' },
  { title: 'This Week', value: 'week' },
  { title: 'This Month', value: 'month' },
  { title: 'This Year', value: 'year' },
]

const tabs = [
  { value: 'sales', label: 'Sales', icon: 'mdi-cash-register' },
  { value: 'top', label: 'Top Products', icon: 'mdi-trophy' },
  { value: 'cashiers', label: 'Cashiers', icon: 'mdi-account-tie' },
  { value: 'pnl', label: 'Profit & Loss', icon: 'mdi-file-chart' },
  { value: 'inventory', label: 'Inventory', icon: 'mdi-package-variant' },
  { value: 'expiry', label: 'Expiry', icon: 'mdi-clock-alert' },
  { value: 'lowstock', label: 'Low Stock', icon: 'mdi-alert-octagon' },
]

const topHeaders = [
  { title: '#', key: 'rank', width: 70 },
  { title: 'Medication', key: 'medication_name' },
  { title: 'Quantity', key: 'quantity', align: 'end' },
  { title: 'Orders', key: 'orders', align: 'end' },
  { title: 'Revenue', key: 'revenue', align: 'end' },
]
const cashierHeaders = [
  { title: 'Cashier', key: 'name' },
  { title: 'Transactions', key: 'transactions', align: 'end' },
  { title: 'Revenue', key: 'revenue', align: 'end' },
  { title: 'Discounts', key: 'discount', align: 'end' },
  { title: 'Avg Basket', key: 'avg_basket', align: 'end' },
]
const invHeaders = [
  { title: 'Category', key: 'category' },
  { title: 'Units', key: 'units', align: 'end' },
  { title: 'Cost', key: 'cost', align: 'end' },
  { title: 'Sale Value', key: 'sale', align: 'end' },
]
const expHeaders = [
  { title: 'Medication', key: 'medication_name' },
  { title: 'Batch', key: 'batch_number' },
  { title: 'Expires', key: 'expiry_date' },
  { title: 'Days Left', key: 'days_left', align: 'end' },
  { title: 'Qty', key: 'quantity_remaining', align: 'end' },
  { title: 'Value at Risk', key: 'cost_value', align: 'end' },
]
const lowHeaders = [
  { title: 'Medication', key: 'medication_name' },
  { title: 'Category', key: 'category' },
  { title: 'On Hand', key: 'quantity', align: 'end' },
  { title: 'Reorder Level', key: 'reorder_level', align: 'end' },
  { title: 'Reorder Qty', key: 'reorder_quantity', align: 'end' },
  { title: 'Est. Reorder Cost', key: 'estimated_reorder_cost', align: 'end' },
]

const heroKpis = computed(() => {
  const s = data.value.sales || {}
  const p = data.value.pnl || {}
  const inv = data.value.inventory || {}
  const exp = data.value.expiry || {}
  return [
    { label: 'Revenue', value: 'KSh ' + fmt(s.combined_revenue), sub: (s.combined_count || 0) + ' transactions',
      icon: 'mdi-cash', color: 'green' },
    { label: 'Net Profit', value: 'KSh ' + fmt(p.net_profit), sub: 'Margin ' + Number(p.gross_margin_pct || 0).toFixed(1) + '%',
      icon: 'mdi-trending-up', color: (p.net_profit || 0) >= 0 ? 'success' : 'red' },
    { label: 'Inventory Value', value: 'KSh ' + fmt(inv.cost_value), sub: (inv.sku_count || 0) + ' SKUs',
      icon: 'mdi-package-variant', color: 'blue' },
    { label: 'Expiring Soon', value: exp.count || 0, sub: 'within ' + (exp.days_horizon || 90) + ' days',
      icon: 'mdi-clock-alert', color: 'orange' },
  ]
})

const salesKpis = computed(() => {
  const s = data.value.sales || {}
  return [
    { label: 'Transactions', value: s.combined_count || 0, icon: 'mdi-receipt', color: 'indigo' },
    { label: 'Combined Revenue', value: 'KSh ' + fmt(s.combined_revenue), icon: 'mdi-cash-multiple', color: 'green' },
    { label: 'POS Revenue', value: 'KSh ' + fmt(s.pos?.revenue), icon: 'mdi-point-of-sale', color: 'teal' },
    { label: 'Dispensing Revenue', value: 'KSh ' + fmt(s.dispensing?.revenue), icon: 'mdi-clipboard-check', color: 'blue' },
  ]
})

const pnlKpis = computed(() => {
  const p = data.value.pnl || {}
  const np = Number(p.net_profit || 0)
  return [
    { label: 'Total Revenue', value: 'KSh ' + fmt(p.revenue), color: '', accent: 'indigo', icon: 'mdi-cash-multiple' },
    { label: 'COGS', value: 'KSh ' + fmt(p.cogs), color: 'text-error', accent: 'red', icon: 'mdi-cart-minus' },
    { label: 'Gross Profit', value: 'KSh ' + fmt(p.gross_profit), color: 'text-success', accent: 'success', icon: 'mdi-trending-up' },
    { label: 'Net Profit', value: 'KSh ' + fmt(np), color: np >= 0 ? 'text-success' : 'text-error',
      accent: np >= 0 ? 'success' : 'red', icon: np >= 0 ? 'mdi-finance' : 'mdi-trending-down' },
  ]
})

const rankedTop = computed(() => (data.value.top?.items || []).map((r, i) => ({ ...r, rank: i + 1 })))

const rangeLabel = computed(() => {
  if (period.value === 'custom' && customFrom.value && customTo.value) {
    return `${customFrom.value} to ${customTo.value}`
  }
  return periodOptions.find(o => o.value === period.value)?.title || 'This Month'
})

function fmt(v) { return Math.round(Number(v || 0)).toLocaleString() }
function initials(name) {
  return (name || '').split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase() || '?'
}
function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
function printPage() { window.print() }

function onPeriodChange(v) {
  if (v === 'custom') {
    customDialog.value = true
    if (!customFrom.value) {
      const t = new Date()
      const from = new Date(t.getTime() - 7 * 86400000)
      customFrom.value = from.toISOString().slice(0, 10)
      customTo.value = t.toISOString().slice(0, 10)
    }
  } else {
    previousPeriod.value = v
    reload()
  }
}

function applyCustom() {
  customDialog.value = false
  previousPeriod.value = 'custom'
  reload()
}
function cancelCustom() {
  customDialog.value = false
  period.value = previousPeriod.value === 'custom' ? 'month' : previousPeriod.value
}

function buildQuery() {
  if (period.value === 'custom' && customFrom.value && customTo.value) {
    return `?date_from=${customFrom.value}&date_to=${customTo.value}`
  }
  return `?period=${period.value}`
}

async function reload() {
  loading.value = true
  try {
    const q = buildQuery()
    const [sales, top, cashiers, inv, exp, low, pnl] = await Promise.all([
      $api.get(`/reports/sales-summary/${q}`).then(r => r.data).catch(() => null),
      $api.get(`/reports/top-products/${q}`).then(r => r.data).catch(() => null),
      $api.get(`/reports/cashier-performance/${q}`).then(r => r.data).catch(() => null),
      $api.get(`/reports/inventory-valuation/`).then(r => r.data).catch(() => null),
      $api.get(`/reports/expiry/`).then(r => r.data).catch(() => null),
      $api.get(`/reports/low-stock/`).then(r => r.data).catch(() => null),
      $api.get(`/reports/profit-loss/${q}`).then(r => r.data).catch(() => null),
    ])
    data.value = { sales, top, cashiers, inventory: inv, expiry: exp, lowstock: low, pnl }
  } catch { showSnack('Failed to load reports', 'error') }
  finally { loading.value = false }
}

// --- Tiny inline render components ---
const PaymentMixList = {
  props: ['rows', 'color'],
  setup(props) {
    return () => {
      const rows = props.rows || []
      const total = rows.reduce((s, r) => s + Number(r.revenue || 0), 0) || 1
      if (!rows.length) {
        return h('div', { class: 'pa-4 text-center text-medium-emphasis' }, 'No transactions')
      }
      return h('div', { class: 'pa-4' }, rows.map(r => {
        const pct = (Number(r.revenue || 0) / total) * 100
        return h('div', { class: 'mb-3' }, [
          h('div', { class: 'd-flex justify-space-between mb-1' }, [
            h('span', { class: 'text-capitalize font-weight-medium' }, r.payment_method || 'Other'),
            h('span', { class: 'font-weight-bold' }, `KSh ${Math.round(Number(r.revenue || 0)).toLocaleString()}`),
          ]),
          h('div', { class: 'd-flex align-center', style: 'gap:8px' }, [
            h('div', { class: 'flex-grow-1 bg-grey-lighten-3 rounded', style: 'height:8px;overflow:hidden' }, [
              h('div', { class: `bg-${props.color}`, style: `height:8px;width:${pct.toFixed(1)}%;transition:width .4s` }),
            ]),
            h('span', { class: 'text-caption text-medium-emphasis', style: 'min-width:80px;text-align:right' },
              `${pct.toFixed(1)}% · ${r.count || 0}`),
          ]),
        ])
      }))
    }
  },
}

const PnlRow = {
  props: ['label', 'value', 'bold', 'positive', 'negative'],
  setup(props) {
    return () => h('div', { class: 'd-flex justify-space-between align-center py-2' }, [
      h('span', { class: props.bold ? 'font-weight-bold' : '' }, props.label),
      h('span', {
        class: [
          props.bold ? 'font-weight-bold' : 'font-weight-medium',
          props.positive ? 'text-success' : '',
          props.negative ? 'text-error' : '',
        ],
      }, `${props.negative ? '(' : ''}KSh ${Math.round(Number(props.value || 0)).toLocaleString()}${props.negative ? ')' : ''}`),
    ])
  },
}

onMounted(reload)
</script>

<style scoped>
.analytics-page {
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: 100vh;
}
.hero {
  background: linear-gradient(135deg, #1e1b4b 0%, #4f46e5 50%, #7c3aed 100%);
  box-shadow: 0 20px 40px -12px rgba(79, 70, 229, 0.35) !important;
}
.hero-glow {
  position: absolute;
  top: -50%;
  right: -20%;
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, rgba(255,255,255,0.15) 0%, transparent 70%);
  pointer-events: none;
}
.kpi {
  background: rgba(255, 255, 255, 0.12) !important;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  transition: transform .2s, background .2s;
}
.kpi:hover { transform: translateY(-2px); background: rgba(255,255,255,0.18) !important; }
.kpi :deep(.text-h6) { color: #fff; }
.kpi :deep(.text-caption) { color: rgba(255, 255, 255, 0.9) !important; }

.stat-card {
  position: relative;
  overflow: hidden;
  transition: transform .2s, box-shadow .2s;
}
.stat-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 24px -8px rgba(0,0,0,0.15) !important;
}
.stat-card::before {
  content: '';
  position: absolute;
  top: 0; left: 0;
  width: 4px; height: 100%;
}
.accent-green::before { background: rgb(76, 175, 80); }
.accent-blue::before { background: rgb(33, 150, 243); }
.accent-cyan::before { background: rgb(0, 188, 212); }
.accent-teal::before { background: rgb(0, 150, 136); }
.accent-indigo::before { background: rgb(63, 81, 181); }
.accent-orange::before { background: rgb(255, 152, 0); }
.accent-red::before { background: rgb(244, 67, 54); }
.accent-success::before { background: rgb(76, 175, 80); }
.accent-purple::before { background: rgb(156, 39, 176); }
.accent-amber::before { background: rgb(255, 193, 7); }

@media print {
  .v-tabs, .v-chip-group, .v-btn { display: none !important; }
  .hero { background: #4f46e5 !important; -webkit-print-color-adjust: exact; }
}
</style>
