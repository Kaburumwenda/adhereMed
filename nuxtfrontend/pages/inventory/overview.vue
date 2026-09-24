<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="teal" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-view-dashboard-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Inventory Overview</h1>
          <div class="text-body-2 text-medium-emphasis">
            Live snapshot of the whole warehouse — stock, expiry, procurement &amp; fulfilment
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn
          variant="tonal" color="primary" prepend-icon="mdi-refresh"
          rounded="lg" class="text-none" :loading="loading" @click="load"
        >
          Refresh
        </v-btn>
      </div>
    </div>

    <!-- Date filters -->
    <v-card flat rounded="xl" border class="pa-3 mb-4">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-chip-group v-model="datePreset" selected-class="text-primary" @update:model-value="applyPreset">
            <v-chip v-for="p in presets" :key="p.value" :value="p.value" size="small" variant="tonal">
              {{ p.label }}
            </v-chip>
          </v-chip-group>
        </v-col>
        <v-col cols="6" md="3">
          <v-text-field
            v-model="dateFrom"
            type="date"
            label="From"
            density="compact"
            variant="outlined"
            hide-details
            prepend-inner-icon="mdi-calendar-start"
            @update:model-value="onCustomChange"
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-text-field
            v-model="dateTo"
            type="date"
            label="To"
            density="compact"
            variant="outlined"
            hide-details
            prepend-inner-icon="mdi-calendar-end"
            @update:model-value="onCustomChange"
          />
        </v-col>
        <v-col cols="12" md="2" class="text-right">
          <v-btn
            v-if="hasActiveRange"
            size="small" variant="text" color="error" class="text-none"
            prepend-icon="mdi-close" @click="clearRange"
          >
            Clear
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3" lg="2">
        <v-card rounded="lg" elevation="0" class="pa-3 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-truncate">{{ k.title }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Stock health -->
    <v-row>
      <v-col cols="12" lg="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="primary" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-package-variant-closed</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Stock Health</h3>
          </div>
          <div class="d-flex align-center justify-center mb-4">
            <DonutRing
              :segments="[
                { value: overview.stock.healthy ?? 0, color: '#22c55e', label: 'Healthy' },
                { value: overview.stock.low_stock ?? 0, color: '#f59e0b', label: 'Low' },
                { value: overview.stock.out_of_stock ?? 0, color: '#ef4444', label: 'Out' }
              ]"
              :size="170"
            >
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ overview.stock.total_items ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex justify-space-around">
            <div class="text-center">
              <v-chip size="small" color="success" variant="tonal">{{ overview.stock.healthy ?? 0 }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Healthy</div>
            </div>
            <div class="text-center">
              <v-chip size="small" color="warning" variant="tonal">{{ overview.stock.low_stock ?? 0 }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Low</div>
            </div>
            <div class="text-center">
              <v-chip size="small" color="error" variant="tonal">{{ overview.stock.out_of_stock ?? 0 }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Out</div>
            </div>
          </div>
          <v-divider class="my-4" />
          <div class="d-flex justify-space-between text-body-2 mb-2">
            <span class="text-medium-emphasis">Units on hand</span>
            <span class="font-weight-bold">{{ (overview.stock.units_on_hand ?? 0).toLocaleString() }}</span>
          </div>
          <v-btn
            block variant="tonal" color="primary" rounded="lg" class="text-none mt-2"
            prepend-icon="mdi-package-variant" :to="p('/inventory')"
          >
            Manage stock items
          </v-btn>
        </v-card>
      </v-col>

      <!-- Expiry -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="deep-orange" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-clock-alert-outline</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Expiry</h3>
          </div>
          <v-list density="comfortable" class="bg-transparent py-0">
            <v-list-item :to="p('/inventory') + '?batchFilter=expiring'">
              <template #prepend>
                <v-avatar color="deep-orange" variant="tonal" size="36">
                  <v-icon size="18">mdi-clock-alert</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">
                {{ overview.expiry.expiring_30 ?? 0 }}
              </v-list-item-title>
              <v-list-item-subtitle>Expiring within 30 days</v-list-item-subtitle>
              <template #append>
                <v-icon size="18">mdi-chevron-right</v-icon>
              </template>
            </v-list-item>
            <v-divider inset />
            <v-list-item>
              <template #prepend>
                <v-avatar color="warning" variant="tonal" size="36">
                  <v-icon size="18">mdi-calendar-alert</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">
                {{ overview.expiry.expiring_90 ?? 0 }}
              </v-list-item-title>
              <v-list-item-subtitle>Expiring within 90 days</v-list-item-subtitle>
            </v-list-item>
            <v-divider inset />
            <v-list-item>
              <template #prepend>
                <v-avatar color="error" variant="tonal" size="36">
                  <v-icon size="18">mdi-alert-octagon</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold text-h6 text-error">
                {{ overview.expiry.expired ?? 0 }}
              </v-list-item-title>
              <v-list-item-subtitle>Expired batches</v-list-item-subtitle>
            </v-list-item>
          </v-list>
          <v-btn
            block variant="tonal" color="deep-orange" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-alert" :to="p('/alerts')"
          >
            Open stock alerts
          </v-btn>
        </v-card>
      </v-col>

      <!-- Fulfilment -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="indigo" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-truck-fast</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Outbound Fulfilment</h3>
          </div>
          <v-list density="comfortable" class="bg-transparent py-0">
            <v-list-item :to="p('/deliveries') + '?status=to_be_packed'">
              <template #prepend>
                <v-avatar color="teal" variant="tonal" size="36">
                  <v-icon size="18">mdi-package-variant-closed</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">
                {{ overview.deliveries.to_be_packed ?? 0 }}
              </v-list-item-title>
              <v-list-item-subtitle>To be packed</v-list-item-subtitle>
              <template #append>
                <v-icon size="18">mdi-chevron-right</v-icon>
              </template>
            </v-list-item>
            <v-divider inset />
            <v-list-item :to="p('/deliveries') + '?status=to_be_shipped'">
              <template #prepend>
                <v-avatar color="cyan" variant="tonal" size="36">
                  <v-icon size="18">mdi-package-up</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">
                {{ overview.deliveries.to_be_shipped ?? 0 }}
              </v-list-item-title>
              <v-list-item-subtitle>To be shipped / in transit</v-list-item-subtitle>
              <template #append>
                <v-icon size="18">mdi-chevron-right</v-icon>
              </template>
            </v-list-item>
          </v-list>
          <v-btn
            block variant="tonal" color="indigo" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-truck-outline" :to="p('/deliveries')"
          >
            Manage deliveries
          </v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- Procurement + Sales -->
    <v-row class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="success" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-cart-arrow-down</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Inbound (Procurement)</h3>
          </div>
          <v-row dense>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Items received</div>
              <div class="text-h5 font-weight-bold text-success">{{ (overview.procurement.items_received ?? 0).toLocaleString() }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Goods received notes</div>
              <div class="text-h5 font-weight-bold">{{ overview.procurement.received_grns ?? 0 }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Open POs</div>
              <div class="text-h5 font-weight-bold text-warning">{{ overview.procurement.open_purchase_orders ?? 0 }}</div>
            </v-col>
          </v-row>
          <v-btn
            block variant="tonal" color="success" rounded="lg" class="text-none mt-4"
            prepend-icon="mdi-cart" :to="p('/purchase-orders')"
          >
            Purchase orders
          </v-btn>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="purple" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-point-of-sale</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Sales (Outbound)</h3>
          </div>
          <v-row dense>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Units sold</div>
              <div class="text-h5 font-weight-bold">{{ (overview.sales.units_sold ?? 0).toLocaleString() }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Revenue</div>
              <div class="text-h5 font-weight-bold text-primary">{{ formatMoney(overview.sales.revenue ?? 0) }}</div>
            </v-col>
          </v-row>

          <div v-if="(overview.sales.recent || []).length" class="mt-4">
            <div class="text-caption text-medium-emphasis mb-2">Recent completed sales</div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>Transaction</th>
                  <th>Customer</th>
                  <th class="text-right">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="t in overview.sales.recent" :key="t.transaction_number">
                  <td class="text-caption font-weight-medium">{{ t.transaction_number }}</td>
                  <td class="text-caption text-medium-emphasis">{{ t.customer_name }}</td>
                  <td class="text-caption text-right font-weight-medium">{{ formatMoney(t.total) }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>

          <v-btn
            block variant="tonal" color="purple" rounded="lg" class="text-none mt-4"
            prepend-icon="mdi-receipt-text-plus" :to="p('/pos/history')"
          >
            Sales history
          </v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- Top moving + dead stock -->
    <v-row class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="primary" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-trending-up</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Top Moving Items</h3>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" color="primary">{{ overview.top_moving.length ?? 0 }}</v-chip>
          </div>
          <EmptyState
            v-if="!overview.top_moving.length"
            icon="mdi-trending-up" title="No movement yet"
            message="Items sold in the selected period will appear here."
          />
          <v-table v-else density="compact">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right">Sold</th>
                <th class="text-right">Revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(m, i) in overview.top_moving" :key="m.stock_id">
                <td>
                  <div class="d-flex align-center">
                    <span class="text-caption text-medium-emphasis mr-2">{{ i + 1 }}.</span>
                    <span class="text-body-2 text-truncate" style="max-width: 200px">{{ m.name }}</span>
                  </div>
                </td>
                <td class="text-right font-weight-medium">{{ m.qty }} {{ m.unit }}</td>
                <td class="text-right text-body-2">{{ formatMoney(m.revenue) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="grey" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-package-off</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Dead Stock</h3>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" color="grey">{{ overview.dead_stock.length ?? 0 }}</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis mb-2">
            On-hand items with no sale in the last 90 days
          </div>
          <EmptyState
            v-if="!overview.dead_stock.length"
            icon="mdi-package-check" title="No dead stock"
            message="Every item on hand has sold within the last 90 days."
          />
          <v-table v-else density="compact">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right">On Hand</th>
                <th>Idle</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="d in overview.dead_stock" :key="d.stock_id">
                <td class="text-body-2 text-truncate" style="max-width: 200px">{{ d.name }}</td>
                <td class="text-right font-weight-medium">{{ d.qty }} {{ d.unit }}</td>
                <td>
                  <v-chip size="x-small" :color="d.days_idle == null ? 'grey' : d.days_idle > 180 ? 'error' : 'warning'" variant="tonal">
                    {{ d.days_idle == null ? 'never' : `${d.days_idle}d` }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

    <!-- Recent stock movements -->
    <v-row class="mt-1">
      <v-col cols="12">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="info" variant="tonal" size="32" class="mr-2">
              <v-icon size="20">mdi-swap-vertical-bold</v-icon>
            </v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Recent Stock Movements</h3>
            <v-spacer />
            <v-btn variant="text" size="small" class="text-none" :to="p('/inventory/stock-movements')" append-icon="mdi-arrow-right">
              Full ledger
            </v-btn>
          </div>
          <EmptyState
            v-if="!movements.length && !movementsLoading"
            icon="mdi-swap-vertical" title="No movements recorded"
            message="Receipts, sales, adjustments and transfers will appear here."
          />
          <v-table v-else density="compact" :loading="movementsLoading">
            <thead>
              <tr>
                <th>Item</th>
                <th>Source</th>
                <th class="text-right">Qty Change</th>
                <th class="text-right">On Hand</th>
                <th>Reference</th>
                <th>When</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in movements.slice(0, 12)" :key="m.id">
                <td class="text-truncate" style="max-width: 180px">
                  <span class="font-weight-medium">{{ m.stock_name }}</span>
                  <div v-if="m.batch_number" class="text-caption text-medium-emphasis">Batch {{ m.batch_number }}</div>
                </td>
                <td>
                  <v-chip size="x-small" :color="sourceMeta(m).color" variant="tonal">
                    <v-icon start size="12">{{ sourceMeta(m).icon }}</v-icon>
                    {{ m.source }}
                  </v-chip>
                </td>
                <td class="text-right font-weight-medium" :class="m.direction === 'inflow' ? 'text-success' : m.direction === 'outflow' ? 'text-error' : 'text-info'">
                  {{ m.direction === 'outflow' ? '' : '+' }}{{ m.quantity_change }}
                </td>
                <td class="text-right text-body-2">{{ m.qty_after ?? '—' }}</td>
                <td class="text-caption text-medium-emphasis">{{ m.reference || '—' }}</td>
                <td class="text-caption text-medium-emphasis">{{ formatRelative(m.timestamp) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()

// Pharmacy tenants reuse this page under /pharmacy, inventory/warehouse
// tenants under /ims — the sub-paths are identical after the prefix.
const { isInventory } = useTenantEndpoints()
const base = computed(() => isInventory.value ? '/ims' : '/pharmacy')
// Build a tenant-namespaced path from a suffix (e.g. '/inventory').
const p = (suffix) => `${base.value}${suffix}`

const loading = ref(false)
const movementsLoading = ref(false)

const overview = reactive({
  stock: {},
  expiry: {},
  deliveries: {},
  procurement: {},
  sales: {},
  top_moving: [],
  dead_stock: [],
})

const movements = ref([])

const SOURCE_META = {
  'POS Sale': { color: 'success', icon: 'mdi-point-of-sale' },
  'Dispensing': { color: 'teal', icon: 'mdi-pill' },
  'Dispense Return': { color: 'orange', icon: 'mdi-undo' },
  'Stock Adjustment': { color: 'warning', icon: 'mdi-tune' },
  'Branch Transfer': { color: 'info', icon: 'mdi-truck-delivery-outline' },
}

function sourceMeta(m) {
  return SOURCE_META[m.source] || { color: 'grey', icon: 'mdi-swap-vertical' }
}

function formatRelative(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (isNaN(d)) return v
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

// ── Date filters ───────────────────────────────────────────────────────
const datePreset = ref('all')
const dateFrom = ref(null)
const dateTo = ref(null)

const presets = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'Last 7 days', value: '7d' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'This month', value: 'month' },
  { label: 'Custom', value: 'custom' },
]

const hasActiveRange = computed(() => !!(dateFrom.value || dateTo.value))

function iso(d) {
  return d.toISOString().slice(0, 10)
}

function applyPreset() {
  const now = new Date()
  switch (datePreset.value) {
    case 'today':
      dateFrom.value = iso(now)
      dateTo.value = iso(now)
      break
    case '7d': {
      const d = new Date(now.getTime() - 6 * 86400000)
      dateFrom.value = iso(d)
      dateTo.value = iso(now)
      break
    }
    case '30d': {
      const d = new Date(now.getTime() - 29 * 86400000)
      dateFrom.value = iso(d)
      dateTo.value = iso(now)
      break
    }
    case 'month': {
      const first = new Date(now.getFullYear(), now.getMonth(), 1)
      dateFrom.value = iso(first)
      dateTo.value = iso(now)
      break
    }
    case 'custom':
      break
    default:
      dateFrom.value = null
      dateTo.value = null
  }
  load()
}

function onCustomChange() {
  datePreset.value = 'custom'
}

function clearRange() {
  datePreset.value = 'all'
  dateFrom.value = null
  dateTo.value = null
  load()
}

const kpis = computed(() => [
  { title: 'Total SKUs', value: overview.stock.total_items ?? 0, icon: 'mdi-package-variant-closed', color: 'primary' },
  { title: 'Units on Hand', value: (overview.stock.units_on_hand ?? 0).toLocaleString(), icon: 'mdi-scale-balance', color: 'info' },
  { title: 'Low Stock', value: overview.stock.low_stock ?? 0, icon: 'mdi-alert', color: 'warning' },
  { title: 'Out of Stock', value: overview.stock.out_of_stock ?? 0, icon: 'mdi-package-variant-remove', color: 'error' },
  { title: 'Expiring ≤30d', value: overview.expiry.expiring_30 ?? 0, icon: 'mdi-clock-alert', color: 'deep-orange' },
  { title: 'To Be Packed', value: overview.deliveries.to_be_packed ?? 0, icon: 'mdi-package-variant-closed', color: 'teal' },
  { title: 'To Be Shipped', value: overview.deliveries.to_be_shipped ?? 0, icon: 'mdi-package-up', color: 'cyan' },
  { title: 'Items Received', value: (overview.procurement.items_received ?? 0).toLocaleString(), icon: 'mdi-cart-arrow-down', color: 'success' },
  { title: 'Open POs', value: overview.procurement.open_purchase_orders ?? 0, icon: 'mdi-cart', color: 'amber' },
  { title: 'Units Sold', value: (overview.sales.units_sold ?? 0).toLocaleString(), icon: 'mdi-sale', color: 'purple' },
  { title: 'Revenue', value: formatMoney(overview.sales.revenue ?? 0), icon: 'mdi-cash-multiple', color: 'green' },
])

async function load() {
  loading.value = true
  try {
    const params = {}
    if (dateFrom.value) params.date_from = dateFrom.value
    if (dateTo.value) params.date_to = dateTo.value
    const { data } = await $api.get('/inventory/overview/', { params })
    overview.stock = data.stock || {}
    overview.expiry = data.expiry || {}
    overview.deliveries = data.deliveries || {}
    overview.procurement = data.procurement || {}
    overview.sales = data.sales || {}
    overview.top_moving = data.top_moving || []
    overview.dead_stock = data.dead_stock || []
  } catch (e) {
    // Leave zeroed state on failure; the page still renders.
  } finally {
    loading.value = false
  }

  loadMovements()
}

async function loadMovements() {
  movementsLoading.value = true
  try {
    const params = {}
    if (dateFrom.value) params.date_from = dateFrom.value
    if (dateTo.value) params.date_to = dateTo.value
    const { data } = await $api.get('/inventory/stock-movements/', { params })
    movements.value = data.movements || []
  } catch (e) {
    movements.value = []
  } finally {
    movementsLoading.value = false
  }
}

onMounted(load)
</script>
