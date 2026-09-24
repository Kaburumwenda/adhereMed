<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">
          Welcome back, {{ auth.user?.first_name || 'there' }}
        </h1>
        <div class="text-body-2 text-medium-emphasis">
          {{ today }} · {{ auth.tenantName || 'Inventory' }} · live warehouse overview
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0">
        <v-btn
          variant="tonal" color="primary" rounded="lg" class="text-none mr-2"
          prepend-icon="mdi-clipboard-check" :to="{ path: '/ims/inventory/stock-take' }"
          v-if="canAccessRoute(auth.role, '/ims/inventory/stock-take')"
        >
          New Stock Take
        </v-btn>
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
      </div>
    </div>

    <!-- KPI tiles -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="4" lg="2">
        <v-card rounded="lg" class="pa-3 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <v-avatar size="36" :color="k.color" variant="tonal">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <v-chip v-if="k.chip" size="x-small" :color="k.chipColor" variant="tonal">{{ k.chip }}</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis text-truncate">{{ k.title }}</div>
          <div class="text-h6 text-md-h5 font-weight-bold mt-1">{{ k.value }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Stock flow trend + stock health -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="text-h6 font-weight-bold">Stock Flow — Last {{ trendDays }} Days</h3>
              <div class="text-caption text-medium-emphasis">Inflow vs outflow units across all warehouses</div>
            </div>
            <div class="d-flex ga-4">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">In</div>
                <div class="text-h6 font-weight-bold text-success">{{ flowKpis.total_in }}</div>
              </div>
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">Out</div>
                <div class="text-h6 font-weight-bold text-error">{{ flowKpis.total_out }}</div>
              </div>
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">Transferred</div>
                <div class="text-h6 font-weight-bold text-info">{{ flowKpis.total_transfer }}</div>
              </div>
            </div>
          </div>
          <div class="d-flex align-center mb-1">
            <v-chip size="x-small" color="success" variant="tonal" class="mr-2">Inflow</v-chip>
            <div class="text-caption text-medium-emphasis">units received</div>
          </div>
          <BarChart :values="inflowValues" :labels="trendLabels" color="#22c55e" :height="100" />
          <div class="d-flex align-center mt-2 mb-1">
            <v-chip size="x-small" color="error" variant="tonal" class="mr-2">Outflow</v-chip>
            <div class="text-caption text-medium-emphasis">units issued / adjusted out</div>
          </div>
          <BarChart :values="outflowValues" :labels="trendLabels" color="#ef4444" :height="100" />
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="lg" class="pa-4 h-100">
          <h3 class="text-h6 font-weight-bold mb-3">Stock Health</h3>
          <div class="d-flex align-center justify-center mb-3">
            <DonutRing
              :segments="[
                { value: stockHealth.healthy, color: '#22c55e', label: 'Healthy' },
                { value: stockHealth.low, color: '#f59e0b', label: 'Low' },
                { value: stockHealth.out, color: '#ef4444', label: 'Out' }
              ]"
              :size="180"
            >
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ kpis[0]?.value }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex justify-space-around">
            <div class="text-center">
              <v-chip size="small" color="success" variant="tonal">{{ stockHealth.healthy }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Healthy</div>
            </div>
            <div class="text-center">
              <v-chip size="small" color="warning" variant="tonal">{{ stockHealth.low }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Low</div>
            </div>
            <div class="text-center">
              <v-chip size="small" color="error" variant="tonal">{{ stockHealth.out }}</v-chip>
              <div class="text-caption text-medium-emphasis mt-1">Out</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Top value items + recent movements -->
    <v-row>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Top Items by Stock Value</h3>
            <v-btn variant="text" size="small" class="text-none" to="/ims/inventory/stock-analysis" append-icon="mdi-arrow-right">Analysis</v-btn>
          </div>
          <EmptyState v-if="!topValueItems.length" icon="mdi-package-variant-closed" title="No stock yet" />
          <div v-else>
            <div v-for="(p, i) in topValueItems" :key="p.name" class="mb-3">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span class="text-truncate">
                  <span class="text-medium-emphasis mr-2">{{ i + 1 }}.</span>{{ p.name }}
                  <span class="text-caption text-medium-emphasis ml-1">{{ p.qty }} {{ p.unit || 'units' }}</span>
                </span>
                <span class="font-weight-medium">{{ formatMoney(p.value) }}</span>
              </div>
              <v-progress-linear :model-value="p.pct" :color="barColors[i % barColors.length]" height="8" rounded />
            </div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Recent Stock Movements</h3>
            <v-btn variant="text" size="small" class="text-none" to="/ims/inventory/stock-movements" append-icon="mdi-arrow-right">Ledger</v-btn>
          </div>
          <EmptyState v-if="!recentMovements.length" icon="mdi-swap-vertical" title="No movements recorded yet" />
          <v-table v-else density="compact">
            <thead>
              <tr>
                <th>Item</th>
                <th>Source</th>
                <th class="text-right">Qty</th>
                <th>When</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in recentMovements" :key="m.id">
                <td class="text-truncate" style="max-width:150px">{{ m.stock_name }}</td>
                <td class="text-caption">{{ m.source }}</td>
                <td class="text-right font-weight-medium" :class="m.direction === 'inflow' ? 'text-success' : m.direction === 'outflow' ? 'text-error' : 'text-info'">
                  {{ m.direction === 'outflow' ? '' : '+' }}{{ m.quantity_change }}
                </td>
                <td class="text-caption text-medium-emphasis">{{ formatRelative(m.timestamp) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

    <!-- Alerts row: low stock + expiring + open POs -->
    <v-row>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="warning" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-alert</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Low / Out of Stock</h3>
            <v-spacer />
            <v-chip size="x-small" color="warning" variant="tonal">{{ lowStock.length }}</v-chip>
          </div>
          <EmptyState v-if="!lowStock.length" icon="mdi-check-circle" title="All items stocked" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="s in lowStock.slice(0, 5)" :key="s.id" :to="`/ims/inventory/stocks/${s.id}/edit`" class="px-0">
              <v-list-item-title class="text-body-2">{{ s.medication_name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ s.total_quantity }} on hand · reorder at {{ s.reorder_level }} · buy {{ s.reorder_quantity }}
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-clock-alert</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Expiring Batches</h3>
            <v-spacer />
            <v-chip size="x-small" color="error" variant="tonal">{{ expiring.length }}</v-chip>
          </div>
          <EmptyState v-if="!expiring.length" icon="mdi-check-circle" title="No batches expiring soon" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(b, i) in expiring.slice(0, 5)" :key="i" :to="`/ims/inventory/stocks/${b.stockId}/edit`" class="px-0">
              <v-list-item-title class="text-body-2">{{ b.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                Batch {{ b.batch_number || '—' }} · expires {{ formatDate(b.expiry_date) }} · {{ b.qty }} left
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="info" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-cart-arrow-down</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Open Purchase Orders</h3>
            <v-spacer />
            <v-chip size="x-small" color="info" variant="tonal">{{ openPOs.length }}</v-chip>
          </div>
          <EmptyState v-if="!openPOs.length" icon="mdi-check-circle" title="No open purchase orders" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="o in openPOs.slice(0, 5)" :key="o.id" :to="`/ims/purchase-orders/${o.id}`" class="px-0">
              <v-list-item-title class="text-body-2">{{ o.po_number || `PO #${o.id}` }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ o.supplier_name || 'Supplier' }} · {{ formatMoney(o.total_cost) }}
                <v-chip v-if="o.status" size="x-small" variant="tonal" class="ml-1">{{ o.status }}</v-chip>
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- In-transit transfers + active stock takes -->
    <v-row>
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="deep-purple" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-truck-delivery-outline</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Warehouse Transfers</h3>
            <v-spacer />
            <v-btn variant="text" size="small" class="text-none" to="/ims/inventory/transfers" append-icon="mdi-arrow-right">All</v-btn>
          </div>
          <EmptyState v-if="!recentTransfers.length" icon="mdi-truck-delivery" title="No transfers yet" />
          <v-table v-else density="compact">
            <thead>
              <tr>
                <th>Ref</th>
                <th>Route</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="tr in recentTransfers" :key="tr.id">
                <td class="font-weight-medium">{{ tr.reference }}</td>
                <td class="text-truncate" style="max-width:160px">{{ tr.source_branch_name }} → {{ tr.dest_branch_name }}</td>
                <td><StatusChip v-if="tr.status" :status="tr.status" /></td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-3">
            <v-avatar color="teal" variant="tonal" size="32" class="mr-2"><v-icon size="20">mdi-clipboard-list-outline</v-icon></v-avatar>
            <h3 class="text-subtitle-1 font-weight-bold">Stock Takes</h3>
            <v-spacer />
            <v-btn variant="text" size="small" class="text-none" to="/ims/inventory/stock-take" append-icon="mdi-arrow-right">All</v-btn>
          </div>
          <EmptyState v-if="!recentCounts.length" icon="mdi-clipboard-check-outline" title="No stock takes yet" />
          <v-table v-else density="compact">
            <thead>
              <tr>
                <th>Ref</th>
                <th>Name</th>
                <th class="text-right">Variance</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="c in recentCounts" :key="c.id">
                <td class="font-weight-medium">{{ c.reference }}</td>
                <td class="text-truncate" style="max-width:140px">{{ c.name }}</td>
                <td class="text-right" :class="(c.total_variance || 0) < 0 ? 'text-error' : 'text-success'">{{ c.total_variance ?? 0 }}</td>
                <td><StatusChip v-if="c.status" :status="c.status" /></td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

    <!-- Quick actions -->
    <v-card rounded="lg" class="pa-4 mt-2">
      <h3 class="text-subtitle-1 font-weight-bold mb-3">Quick Actions</h3>
      <v-row dense>
        <v-col v-for="a in actions" :key="a.label" cols="6" sm="4" md="3" lg="2">
          <v-btn block variant="tonal" rounded="lg" class="text-none justify-start" :prepend-icon="a.icon" :to="a.to" :color="a.color">
            {{ a.label }}
          </v-btn>
        </v-col>
      </v-row>
    </v-card>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatMoney, formatDate } from '~/utils/format'
import { canAccessRoute } from '~/utils/permissions'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const today = new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
const loading = ref(false)
const trendDays = 30

const analytics = ref(null)
const stocks = ref([])
const flowKpis = reactive({ total_in: 0, total_out: 0, total_transfer: 0, net_change: 0 })
const trendLabels = ref([])
const inflowValues = ref([])
const outflowValues = ref([])
const recentMovements = ref([])
const topValueItems = ref([])
const lowStock = ref([])
const expiring = ref([])
const openPOs = ref([])
const recentTransfers = ref([])
const recentCounts = ref([])

const stockHealth = reactive({ healthy: 0, low: 0, out: 0 })
const barColors = ['primary', 'info', 'success', 'warning', 'purple', 'teal']

const unitsOnHand = computed(() => stocks.value.reduce((s, x) => s + (Number(x.total_quantity) || 0), 0))

const kpis = computed(() => [
  { title: 'Total SKUs', value: analytics.value?.total_items ?? stocks.value.length, icon: 'mdi-package-variant-closed', color: 'primary', chip: null, chipColor: null },
  { title: 'Stock Value (Cost)', value: formatMoney(analytics.value?.total_cost_value ?? 0), icon: 'mdi-cash-multiple', color: 'success', chip: analytics.value?.potential_profit ? `+${formatMoney(analytics.value.potential_profit)}` : null, chipColor: 'success' },
  { title: 'Units on Hand', value: unitsOnHand.value, icon: 'mdi-scale-balance', color: 'info', chip: null, chipColor: null },
  { title: 'Low Stock', value: analytics.value?.low_stock_count ?? 0, icon: 'mdi-alert', color: 'warning', chip: null, chipColor: null },
  { title: 'Out of Stock', value: analytics.value?.out_of_stock ?? 0, icon: 'mdi-package-variant-remove', color: 'error', chip: null, chipColor: null },
  { title: 'Expiring ≤30 Days', value: analytics.value?.expiring_30_days ?? 0, icon: 'mdi-clock-alert', color: 'deep-orange', chip: analytics.value?.expired_batches ? `${analytics.value.expired_batches} expired` : null, chipColor: 'error' },
])

const actions = computed(() => [
  { icon: 'mdi-plus-circle', label: 'Add Stock Item', to: '/ims/inventory/stocks/new', color: 'primary' },
  { icon: 'mdi-clipboard-list-outline', label: 'Stock Take', to: '/ims/inventory/stock-take', color: 'teal' },
  { icon: 'mdi-cart', label: 'Purchase Orders', to: '/ims/purchase-orders', color: 'warning' },
  { icon: 'mdi-truck-delivery-outline', label: 'Transfers', to: '/ims/inventory/transfers', color: 'deep-purple' },
  { icon: 'mdi-swap-vertical-bold', label: 'Movements', to: '/ims/inventory/stock-movements', color: 'info' },
  { icon: 'mdi-chart-line', label: 'Stock Analysis', to: '/ims/inventory/stock-analysis', color: 'success' },
  { icon: 'mdi-file-excel', label: 'Excel Tools', to: '/ims/inventory/excel', color: 'green-darken-2' },
  { icon: 'mdi-clipboard-text', label: 'Reports', to: '/ims/reports', color: 'indigo' },
].filter(a => canAccessRoute(auth.role, a.to)))

function formatRelative(v) {
  if (!v) return ''
  const d = new Date(v)
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}

async function load() {
  loading.value = true
  const safeGet = (p) => $api.get(p).then(r => r.data).catch(() => null)
  const safeList = (p) => safeGet(p).then(d => d?.results || (Array.isArray(d) ? d : []))

  const end = new Date()
  const start = new Date(end.getTime() - (trendDays - 1) * 86400000)
  const iso = (d) => d.toISOString().slice(0, 10)

  const [an, st, mv, po, tr, cnt] = await Promise.all([
    safeGet('/inventory/analytics/'),
    safeList('/inventory/stocks/?page_size=1000'),
    safeGet(`/inventory/stock-movements/?date_from=${iso(start)}&date_to=${iso(end)}`),
    safeList('/purchase-orders/?page_size=100'),
    safeList('/inventory/transfers/?page_size=100'),
    safeList('/inventory/counts/?page_size=100'),
  ])

  analytics.value = an
  stocks.value = st

  // Stock health + low stock
  let healthy = 0, low = 0, out = 0
  const lowList = []
  for (const s of stocks.value) {
    const q = Number(s.total_quantity || 0)
    if (q <= 0) { out++; lowList.push(s) }
    else if (s.is_low_stock) { low++; lowList.push(s) }
    else healthy++
  }
  stockHealth.healthy = healthy
  stockHealth.low = low
  stockHealth.out = out
  lowStock.value = lowList.sort((a, b) => (Number(a.total_quantity) || 0) - (Number(b.total_quantity) || 0))

  // Expiring batches (next 90 days, from stock batches)
  const soon = new Date(); soon.setDate(soon.getDate() + 90)
  const expList = []
  for (const s of stocks.value) {
    for (const b of (s.batches || [])) {
      if (b.quantity_remaining > 0 && b.expiry_date && new Date(b.expiry_date) <= soon) {
        expList.push({
          stockId: s.id, name: s.medication_name, batch_number: b.batch_number,
          expiry_date: b.expiry_date, qty: b.quantity_remaining,
        })
      }
    }
  }
  expiring.value = expList.sort((a, b) => new Date(a.expiry_date) - new Date(b.expiry_date))

  // Top items by stock value (at cost)
  const byValue = stocks.value
    .map(s => ({
      name: s.medication_name,
      qty: Number(s.total_quantity || 0),
      unit: s.unit_abbreviation || s.unit_name,
      value: (Number(s.total_quantity) || 0) * (Number(s.cost_price) || 0),
    }))
    .filter(p => p.value > 0)
    .sort((a, b) => b.value - a.value)
    .slice(0, 6)
  const maxVal = byValue[0]?.value || 1
  topValueItems.value = byValue.map(p => ({ ...p, pct: (p.value / maxVal) * 100 }))

  // Stock flow trend
  if (mv) {
    Object.assign(flowKpis, mv.kpis || {})
    const trend = mv.trend || []
    trendLabels.value = trend.map(d => new Date(d.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }))
    inflowValues.value = trend.map(d => (d.inflow || 0) + (d.transfer || 0))
    outflowValues.value = trend.map(d => d.outflow || 0)
    recentMovements.value = (mv.movements || [])
      .slice()
      .sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0))
      .slice(0, 8)
  }

  // Open POs (draft / sent / partially received)
  openPOs.value = (po || []).filter(o => ['draft', 'sent', 'partial'].includes(o.status))

  // Transfers + counts
  recentTransfers.value = (tr || []).slice(0, 6)
  recentCounts.value = (cnt || []).slice(0, 6)

  loading.value = false
}

onMounted(load)
</script>
