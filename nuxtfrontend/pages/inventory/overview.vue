<template>
  <v-container fluid class="pa-3 pa-md-5 iov-page">

    <!-- ═══════════════ COMPACT HEADER ═══════════════ -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-3">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Inventory Overview</h1>
        <div class="text-body-2 text-medium-emphasis">
          Stock, expiry, procurement &amp; fulfilment at a glance
          <span v-if="branchStore.currentBranch"> · {{ branchStore.currentBranch.name }}</span>
        </div>
      </div>
      <div class="d-flex flex-wrap align-center ga-2 mt-2 mt-md-0">
        <v-btn
          icon="mdi-refresh"
          variant="tonal"
          color="primary"
          size="small"
          title="Refresh"
          :loading="loading"
          @click="load"
        />
        <v-btn
          variant="tonal" color="primary" rounded="lg" class="text-none"
          prepend-icon="mdi-package-variant" :to="p('/inventory')"
        >Stock list</v-btn>
        <v-btn
          variant="tonal" color="primary" rounded="lg" class="text-none"
          prepend-icon="mdi-clipboard-text-search-outline" :to="p('/inventory/stock-movements')"
        >Movement ledger</v-btn>
      </div>
    </div>

    <!-- ═══════════════ DATE BAR ═══════════════ -->
    <div class="iov-datebar mb-3">
      <v-chip-group v-model="datePreset" selected-class="text-primary" @update:model-value="applyPreset" class="iov-date-chips">
        <v-chip v-for="pr in presets" :key="pr.value" :value="pr.value" size="small" variant="tonal">
          {{ pr.label }}
        </v-chip>
      </v-chip-group>
      <div class="d-flex align-center ga-2">
        <v-text-field
          v-model="dateFrom"
          type="date"
          label="From"
          density="compact"
          variant="outlined"
          hide-details
          prepend-inner-icon="mdi-calendar-start"
          class="iov-date-field"
          @update:model-value="onCustomChange"
        />
        <v-text-field
          v-model="dateTo"
          type="date"
          label="To"
          density="compact"
          variant="outlined"
          hide-details
          prepend-inner-icon="mdi-calendar-end"
          class="iov-date-field"
          @update:model-value="onCustomChange"
        />
        <v-btn
          v-if="hasActiveRange"
          size="small" variant="text" color="error" class="text-none"
          prepend-icon="mdi-close" @click="clearRange"
        >Clear</v-btn>
      </div>
    </div>

    <!-- ═══════════════ KPI STRIP ═══════════════
         Six focused, linkable metrics tone-railed by currentColor. -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="4" xl="2">
        <component
          :is="linkOr(k.to)"
          :to="k.to || undefined"
          class="iov-kpi h-100"
          :class="[`iov-kpi-t-${k.tone}`, k.to ? 'iov-kpi-link' : '']"
        >
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="iov-kpi-icon">
              <v-icon size="18">{{ k.icon }}</v-icon>
            </div>
            <v-chip
              v-if="k.chip"
              size="x-small"
              :color="k.chipColor || k.tone"
              variant="tonal"
              class="font-weight-bold"
            >{{ k.chip }}</v-chip>
          </div>
          <div class="iov-kpi-label">{{ k.title }}</div>
          <div class="iov-kpi-value">{{ k.value }}</div>
          <div v-if="k.hint" class="iov-kpi-foot">{{ k.hint }}</div>
        </component>
      </v-col>
    </v-row>

    <!-- ═══════════════ HEALTH + EXPIRY + FULFILMENT ═══════════════ -->
    <v-row dense class="mt-1">
      <!-- Stock health -->
      <v-col cols="12" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center">
              <div class="iov-panel-icon" style="--panel-tone:#2563eb">
                <v-icon size="18">mdi-package-variant-closed</v-icon>
              </div>
              <div>
                <div class="text-subtitle-2 font-weight-bold">Stock health</div>
                <div class="text-caption text-medium-emphasis">Availability by item</div>
              </div>
            </div>
            <v-chip size="small" :color="healthChipColor" variant="tonal" class="font-weight-bold">
              {{ healthPct }}% healthy
            </v-chip>
          </div>

          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="healthSegments" :size="176" :thickness="16">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ overview.stock.total_items ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>

          <div v-for="h in healthLegend" :key="h.label" class="iov-legend">
            <span class="iov-legend-dot" :style="{ background: h.color }" />
            <span class="text-body-2 flex-grow-1">{{ h.label }}</span>
            <span class="text-body-2 font-weight-bold">{{ h.count }}</span>
            <span class="text-caption text-medium-emphasis iov-legend-pct">{{ h.pct }}%</span>
          </div>

          <div class="iov-metric-row mt-2">
            <span class="text-body-2 text-medium-emphasis">Units on hand</span>
            <span class="text-body-2 font-weight-bold">{{ (overview.stock.units_on_hand ?? 0).toLocaleString() }}</span>
          </div>

          <v-btn
            block variant="tonal" color="primary" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-package-variant" :to="p('/inventory')"
          >Manage stock items</v-btn>
        </v-card>
      </v-col>

      <!-- Expiry pipeline -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#ea580c">
              <v-icon size="18">mdi-clock-alert-outline</v-icon>
            </div>
            <div>
              <div class="text-subtitle-2 font-weight-bold">Expiry pipeline</div>
              <div class="text-caption text-medium-emphasis">Batches expiring or already expired</div>
            </div>
          </div>

          <v-list density="comfortable" class="bg-transparent py-0">
            <v-list-item :to="p('/inventory') + '?batchFilter=expiring'" class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#ea580c"><v-icon size="18">mdi-clock-alert</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.expiry.expiring_30 ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>Expiring within 30 days</v-list-item-subtitle>
              <template #append><v-icon size="18">mdi-chevron-right</v-icon></template>
            </v-list-item>
            <v-divider inset />
            <v-list-item class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#f59e0b"><v-icon size="18">mdi-calendar-alert</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.expiry.expiring_90 ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>Expiring within 90 days</v-list-item-subtitle>
            </v-list-item>
            <v-divider inset />
            <v-list-item class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#ef4444"><v-icon size="18">mdi-alert-octagon</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6 text-error">{{ overview.expiry.expired ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>Expired batches</v-list-item-subtitle>
            </v-list-item>
          </v-list>

          <v-btn
            block variant="tonal" color="deep-orange" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-alert" :to="p('/alerts')"
          >Open stock alerts</v-btn>
        </v-card>
      </v-col>

      <!-- Outbound fulfilment -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#4f46e5">
              <v-icon size="18">mdi-truck-fast</v-icon>
            </div>
            <div>
              <div class="text-subtitle-2 font-weight-bold">Outbound fulfilment</div>
              <div class="text-caption text-medium-emphasis">Pipeline of pending deliveries</div>
            </div>
          </div>

          <v-list density="comfortable" class="bg-transparent py-0">
            <v-list-item :to="p('/deliveries') + '?status=to_be_packed'" class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#14b8a6"><v-icon size="18">mdi-package-variant-closed</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.deliveries.to_be_packed ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>To be packed</v-list-item-subtitle>
              <template #append><v-icon size="18">mdi-chevron-right</v-icon></template>
            </v-list-item>
            <v-divider inset />
            <v-list-item :to="p('/deliveries') + '?status=to_be_shipped'" class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#0891b2"><v-icon size="18">mdi-package-up</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.deliveries.to_be_shipped ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>To be shipped / in transit</v-list-item-subtitle>
              <template #append><v-icon size="18">mdi-chevron-right</v-icon></template>
            </v-list-item>
          </v-list>

          <v-btn
            block variant="tonal" color="indigo" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-truck-outline" :to="p('/deliveries')"
          >Manage deliveries</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ PROCUREMENT + SALES ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#16a34a">
              <v-icon size="18">mdi-cart-arrow-down</v-icon>
            </div>
            <div>
              <div class="text-subtitle-2 font-weight-bold">Inbound (Procurement)</div>
              <div class="text-caption text-medium-emphasis">Items received and open purchase orders</div>
            </div>
          </div>

          <div class="iov-mini-grid">
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Items received</div>
              <div class="text-h5 font-weight-bold text-success">{{ (overview.procurement.items_received ?? 0).toLocaleString() }}</div>
            </div>
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Goods received notes</div>
              <div class="text-h5 font-weight-bold">{{ overview.procurement.received_grns ?? 0 }}</div>
            </div>
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Open POs</div>
              <div class="text-h5 font-weight-bold text-warning">{{ overview.procurement.open_purchase_orders ?? 0 }}</div>
            </div>
          </div>

          <v-btn
            block variant="tonal" color="success" rounded="lg" class="text-none mt-4"
            prepend-icon="mdi-cart" :to="p('/purchase-orders')"
          >Purchase orders</v-btn>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#9333ea">
              <v-icon size="18">mdi-point-of-sale</v-icon>
            </div>
            <div>
              <div class="text-subtitle-2 font-weight-bold">Sales (Outbound)</div>
              <div class="text-caption text-medium-emphasis">Units sold and revenue in period</div>
            </div>
          </div>

          <div class="iov-mini-grid">
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Units sold</div>
              <div class="text-h5 font-weight-bold">{{ (overview.sales.units_sold ?? 0).toLocaleString() }}</div>
            </div>
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Revenue</div>
              <div class="text-h5 font-weight-bold text-primary">{{ formatMoney(overview.sales.revenue ?? 0) }}</div>
            </div>
          </div>

          <div v-if="(overview.sales.recent || []).length" class="mt-4">
            <div class="text-caption text-medium-emphasis mb-2">Recent completed sales</div>
            <v-table density="compact" class="iov-table">
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
          >Sales history</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ TOP MOVING + DEAD STOCK ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#2563eb">
              <v-icon size="18">mdi-trending-up</v-icon>
            </div>
            <div class="text-subtitle-2 font-weight-bold">Top moving items</div>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" color="primary" class="font-weight-bold">{{ overview.top_moving.length ?? 0 }}</v-chip>
          </div>

          <EmptyState
            v-if="!overview.top_moving.length"
            icon="mdi-trending-up" title="No movement yet"
            message="Items sold in the selected period will appear here."
          />
          <v-table v-else density="compact" class="iov-table">
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
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#64748b">
              <v-icon size="18">mdi-package-off</v-icon>
            </div>
            <div class="text-subtitle-2 font-weight-bold">Dead stock</div>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" color="grey" class="font-weight-bold">{{ overview.dead_stock.length ?? 0 }}</v-chip>
          </div>

          <div class="text-caption text-medium-emphasis mb-2">
            On-hand items with no sale in the last 90 days
          </div>

          <EmptyState
            v-if="!overview.dead_stock.length"
            icon="mdi-package-check" title="No dead stock"
            message="Every item on hand has sold within the last 90 days."
          />
          <v-table v-else density="compact" class="iov-table">
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

    <!-- ═══════════════ RECENT MOVEMENTS ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#0284c7">
              <v-icon size="18">mdi-swap-vertical-bold</v-icon>
            </div>
            <div>
              <div class="text-subtitle-2 font-weight-bold">Recent stock movements</div>
              <div class="text-caption text-medium-emphasis">Last 12 receipts, sales, adjustments and transfers</div>
            </div>
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
          <v-table v-else density="compact" :loading="movementsLoading" class="iov-table">
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
import { useBranchStore } from '~/stores/branch'
import { NuxtLink } from '#components'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()

// Reuse the same NuxtLink import for linkable KPI cards; falls back to a plain
// div when no `to` is set so the code paths below stay declarative.
function linkOr(to) {
  return to ? NuxtLink : 'div'
}

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

// ── Derived health signals ──────────────────────────────────────────────
const healthCount = computed(() =>
  (overview.stock.healthy ?? 0)
  + (overview.stock.low_stock ?? 0)
  + (overview.stock.out_of_stock ?? 0)
)

const healthSegments = computed(() => [
  { value: overview.stock.healthy ?? 0, color: '#22c55e', label: 'Healthy' },
  { value: overview.stock.low_stock ?? 0, color: '#f59e0b', label: 'Low' },
  { value: overview.stock.out_of_stock ?? 0, color: '#ef4444', label: 'Out' },
])

const healthPct = computed(() => {
  const total = overview.stock.total_items ?? 0
  return total ? Math.round(((overview.stock.healthy ?? 0) / total) * 100) : 0
})

const healthChipColor = computed(() =>
  healthPct.value >= 80 ? 'success' : healthPct.value >= 50 ? 'warning' : 'error'
)

const healthLegend = computed(() => {
  const total = healthCount.value || 1
  return [
    { label: 'Healthy', count: overview.stock.healthy ?? 0, color: '#22c55e', pct: Math.round(((overview.stock.healthy ?? 0) / total) * 100) },
    { label: 'Low stock', count: overview.stock.low_stock ?? 0, color: '#f59e0b', pct: Math.round(((overview.stock.low_stock ?? 0) / total) * 100) },
    { label: 'Out of stock', count: overview.stock.out_of_stock ?? 0, color: '#ef4444', pct: Math.round(((overview.stock.out_of_stock ?? 0) / total) * 100) },
  ]
})

// ── KPI cards ───────────────────────────────────────────────────────────
// Six focused metrics, each tone-railed by currentColor and linkable to the
// screen that acts on it. `tone` drives the top accent bar + icon chip so the
// tile stays visually coherent across palettes.
const kpis = computed(() => [
  {
    title: 'Total SKUs',
    value: overview.stock.total_items ?? 0,
    icon: 'mdi-package-variant-closed',
    tone: 'blue',
    to: p('/inventory'),
    hint: `${overview.stock.healthy ?? 0} healthy items`,
  },
  {
    title: 'Units on Hand',
    value: (overview.stock.units_on_hand ?? 0).toLocaleString(),
    icon: 'mdi-scale-balance',
    tone: 'teal',
  },
  {
    title: 'Low Stock',
    value: overview.stock.low_stock ?? 0,
    icon: 'mdi-alert',
    tone: 'amber',
    to: p('/inventory') + '?statusFilter=low',
    hint: 'Needs restocking',
  },
  {
    title: 'Out of Stock',
    value: overview.stock.out_of_stock ?? 0,
    icon: 'mdi-package-variant-remove',
    tone: 'red',
    to: p('/inventory') + '?statusFilter=out',
    hint: 'Reorder required',
  },
  {
    title: 'Expiring ≤30d',
    value: overview.expiry.expiring_30 ?? 0,
    icon: 'mdi-clock-alert',
    tone: 'purple',
    to: p('/inventory') + '?batchFilter=expiring',
    hint: `${overview.expiry.expired ?? 0} already expired`,
  },
  {
    title: 'Open POs',
    value: overview.procurement.open_purchase_orders ?? 0,
    icon: 'mdi-cart',
    tone: 'orange',
    to: p('/purchase-orders'),
    hint: `${(overview.procurement.items_received ?? 0).toLocaleString()} units received`,
  },
])

async function load() {
  loading.value = true
  try {
    const params = {}
    if (dateFrom.value) params.date_from = dateFrom.value
    if (dateTo.value) params.date_to = dateTo.value
    if (branchStore.currentBranchId) params.branch_id = branchStore.currentBranchId
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
    if (branchStore.currentBranchId) params.branch_id = branchStore.currentBranchId
    const { data } = await $api.get('/inventory/stock-movements/', { params })
    movements.value = data.movements || []
  } catch (e) {
    movements.value = []
  } finally {
    movementsLoading.value = false
  }
}

onMounted(load)

watch(() => branchStore.currentBranchId, () => {
  load()
})
</script>

<style scoped>
/* ─────────────── Page ─────────────── */
.iov-page { background: transparent; }

/* ─────────────── Date bar ─────────────── */
.iov-datebar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 8px 14px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgba(var(--v-theme-surface-variant), 0.18);
}
.iov-date-chips { flex: 1 1 auto; min-width: 280px; }
.iov-date-field { max-width: 170px; }

/* ─────────────── KPI cards ───────────────
   Tone travels via `color`, so the top rail, the icon chip and the link
   underline can all derive from currentColor. Hover gives a small lift. */
.iov-kpi {
  position: relative;
  overflow: hidden;
  display: block;
  border-radius: 14px;
  padding: 14px 16px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgb(var(--v-theme-surface));
  color: inherit;
  text-decoration: none;
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.iov-kpi::after {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 3px;
  background: currentColor;
  opacity: 0.85;
}
.iov-kpi:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.1); }
.iov-kpi-link { cursor: pointer; }
.iov-kpi-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: currentColor;
  background: color-mix(in srgb, currentColor 14%, transparent);
}
.iov-kpi-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
}
.iov-kpi-value {
  font-size: 22px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  margin-top: 1px;
}
.iov-kpi-foot {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
  margin-top: 2px;
}

/* Per-KPI hues drive the top accent bar + icon chip via currentColor. */
.iov-kpi-t-blue { color: #2563eb; }
.iov-kpi-t-teal { color: #0d9488; }
.iov-kpi-t-amber { color: #d97706; }
.iov-kpi-t-red { color: #dc2626; }
.iov-kpi-t-purple { color: #7c3aed; }
.iov-kpi-t-orange { color: #ea580c; }

/* ─────────────── Panels ─────────────── */
.iov-panel { transition: box-shadow 0.18s ease; }
.iov-panel:hover { box-shadow: 0 6px 20px rgba(15, 23, 42, 0.07); }
.iov-panel-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 10px;
  flex-shrink: 0;
  color: var(--panel-tone, #2563eb);
  background: color-mix(in srgb, var(--panel-tone, #2563eb) 14%, transparent);
}

/* Legend rows (stock health) */
.iov-legend { display: flex; align-items: center; gap: 8px; padding: 5px 0; }
.iov-legend-dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.iov-legend-pct { min-width: 34px; text-align: right; }

/* Inline metric row (units on hand) */
.iov-metric-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 0;
  border-top: 1px solid rgba(15, 23, 42, 0.06);
}

/* List items (expiry, fulfilment) */
.iov-list-item {
  border-radius: 10px;
  transition: background 0.16s ease;
  margin: 2px 0;
}
.iov-list-item:hover {
  background: rgba(var(--v-theme-surface-variant), 0.3);
}
.iov-list-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--tone, #2563eb);
  background: color-mix(in srgb, var(--tone, #2563eb) 14%, transparent);
}

/* Mini grid (procurement / sales tiles) */
.iov-mini-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 10px;
}
.iov-mini-tile {
  padding: 10px 14px;
  border-radius: 10px;
  border: 1px solid rgba(15, 23, 42, 0.06);
  background: rgba(var(--v-theme-surface-variant), 0.18);
}

/* Tables */
.iov-table { border-radius: 10px; overflow: hidden; }
.iov-table :deep(th) {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
</style>
