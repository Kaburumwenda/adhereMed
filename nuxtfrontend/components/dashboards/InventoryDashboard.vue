<template>
  <v-container fluid class="pa-3 pa-md-5 ims-dash">
    <!-- ═══════════════ COMPACT HEADER ═══════════════ -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-3">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Warehouse Operations</h1>
        <div class="text-body-2 text-medium-emphasis">
          {{ today }}
          <span class="ml-1">· {{ auth.tenantName || 'Inventory' }}</span>
          <span v-if="branchLabel"> · {{ branchLabel }}</span>
        </div>
      </div>
      <div class="d-flex flex-wrap align-center ga-2 mt-2 mt-md-0">
        <v-btn icon="mdi-refresh" variant="tonal" color="primary" size="small" title="Refresh" :loading="loading" @click="load" />
        <v-btn
          v-if="canAccessRoute(auth.role, '/ims/inventory/stock-take')"
          variant="outlined" rounded="lg" class="text-none"
          prepend-icon="mdi-clipboard-check-outline" to="/ims/inventory/stock-take"
        >New Stock Take</v-btn>
        <v-btn
          v-if="canAccessRoute(auth.role, '/ims/inventory/stocks/new')"
          color="primary" rounded="lg" class="text-none"
          prepend-icon="mdi-plus" to="/ims/inventory/stocks/new"
        >Add Stock Item</v-btn>
      </div>
    </div>

    <!-- ═══════════════ KPI STRIP ═══════════════ -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.key" cols="6" md="4" lg="2">
        <component
          :is="linkOr(k.to)"
          :to="k.to || undefined"
          class="ims-kpi h-100"
          :class="[`ims-kpi-t-${k.key}`, k.to ? 'ims-kpi-link' : '']"
        >
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="ims-kpi-icon">
              <v-icon size="18">{{ k.icon }}</v-icon>
            </div>
            <v-chip
              v-if="k.chip"
              size="x-small"
              :color="k.chipColor"
              variant="tonal"
              class="font-weight-bold"
            >{{ k.chip }}</v-chip>
          </div>
          <div class="ims-kpi-label">{{ k.title }}</div>
          <div class="ims-kpi-value">{{ k.value }}</div>
          <div v-if="k.hint" class="ims-kpi-foot">{{ k.hint }}</div>
          <div v-if="k.share != null" class="ims-kpi-bars mt-2">
            <span :style="{ width: k.share + '%' }" />
          </div>
        </component>
      </v-col>
    </v-row>

    <!-- ═══════════════ OPS PULSE ═══════════════
         Derived observations rather than another row of raw counts: each tile
         says what the number means and links to the screen that acts on it. -->
    <div class="ims-pulse my-3">
      <div class="ims-pulse-head">
        <v-icon size="17">mdi-pulse</v-icon>
        <span>Operational pulse</span>
        <span class="ims-pulse-window">last {{ trendDays }} days</span>
      </div>
      <div class="ims-pulse-grid">
        <component
          :is="linkOr(p.to)"
          :to="p.to || undefined"
          v-for="p in pulse"
          :key="p.label"
          class="ims-pulse-tile"
          :class="{ 'ims-pulse-link': !!p.to }"
          :style="{ '--pulse-tone': p.tone }"
        >
          <div class="ims-pulse-icon"><v-icon size="17">{{ p.icon }}</v-icon></div>
          <div style="min-width:0">
            <div class="ims-pulse-label">{{ p.label }}</div>
            <div class="ims-pulse-value">{{ p.value }}</div>
            <div class="ims-pulse-hint">{{ p.hint }}</div>
          </div>
        </component>
      </div>
    </div>

    <!-- ═══════════════ FLOW + HEALTH ═══════════════ -->
    <v-row dense>
      <v-col cols="12" lg="8">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex flex-wrap align-center justify-space-between ga-2 mb-3">
            <div>
              <h3 class="ims-panel-title">Stock flow</h3>
              <div class="text-caption text-medium-emphasis">Inflow vs outflow across all warehouses</div>
            </div>
            <div class="d-flex align-center ga-2">
              <div class="ims-flowstat ims-flowstat-in">
                <span class="ims-flowstat-label">In</span>
                <span class="ims-flowstat-value">{{ num(flowKpis.total_in) }}</span>
              </div>
              <div class="ims-flowstat ims-flowstat-out">
                <span class="ims-flowstat-label">Out</span>
                <span class="ims-flowstat-value">{{ num(flowKpis.total_out) }}</span>
              </div>
              <div class="ims-flowstat ims-flowstat-net">
                <span class="ims-flowstat-label">Net</span>
                <span class="ims-flowstat-value">{{ netChange > 0 ? '+' : '' }}{{ num(netChange) }}</span>
              </div>
            </div>
          </div>

          <EmptyState
            v-if="!inflowValues.length"
            icon="mdi-chart-timeline-variant"
            title="No stock movement in this period"
            message="Movements appear here once goods are received, sold or transferred."
          />
          <template v-else>
            <div class="d-flex align-center ga-4 mb-1">
              <div class="d-flex align-center">
                <span class="ims-legend-dot" style="background:#22c55e" />
                <span class="text-caption text-medium-emphasis ml-1">Inflow</span>
              </div>
              <div class="d-flex align-center">
                <span class="ims-legend-dot" style="background:#ef4444" />
                <span class="text-caption text-medium-emphasis ml-1">Outflow</span>
              </div>
              <span class="text-caption text-medium-emphasis ml-auto" style="font-size: 11px">
                {{ trendLabels.length }} active day{{ trendLabels.length === 1 ? '' : 's' }}
              </span>
            </div>
            <StockFlowChart
              :inflow="inflowValues"
              :outflow="outflowValues"
              :labels="trendLabels"
              :height="220"
            />
          </template>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="ims-panel-title">Stock health</h3>
              <div class="text-caption text-medium-emphasis">Availability by item</div>
            </div>
            <v-chip size="small" :color="healthChipColor" variant="tonal" class="font-weight-bold">
              {{ healthPct }}% healthy
            </v-chip>
          </div>

          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="healthSegments" :size="176" :thickness="16">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ num(totalSkus) }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>

          <div v-for="h in healthLegend" :key="h.label" class="ims-legend">
            <span class="ims-legend-dot" :style="{ background: h.color }" />
            <span class="text-body-2 flex-grow-1">{{ h.label }}</span>
            <span class="text-body-2 font-weight-bold">{{ h.count }}</span>
            <span class="text-caption text-medium-emphasis ims-legend-pct">{{ h.pct }}%</span>
          </div>

          <v-btn
            block
            variant="tonal"
            color="primary"
            rounded="lg"
            class="text-none mt-3"
            prepend-icon="mdi-chart-line"
            to="/ims/inventory/stock-analysis"
          >Open stock analysis</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ VALUE + MOVEMENTS ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" lg="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="ims-panel-title">Top items by stock value</h3>
              <div class="text-caption text-medium-emphasis">Capital tied up, valued at cost</div>
            </div>
            <v-btn
              variant="text" size="small" class="text-none" color="primary"
              to="/ims/inventory/stock-analysis" append-icon="mdi-arrow-right"
            >Analysis</v-btn>
          </div>
          <EmptyState v-if="!topValueItems.length" icon="mdi-package-variant-closed" title="No stock yet" />
          <div v-else>
            <div v-for="(p, i) in topValueItems" :key="p.name" class="mb-3">
              <div class="d-flex justify-space-between align-center text-body-2 mb-1">
                <span class="text-truncate d-flex align-center" style="gap:8px; min-width:0">
                  <span class="ims-rank">{{ i + 1 }}</span>
                  <span class="text-truncate">{{ p.name }}</span>
                  <span class="text-caption text-medium-emphasis ims-nowrap">{{ p.qty }} {{ p.unit || 'units' }}</span>
                </span>
                <span class="font-weight-bold ims-nowrap ml-2">{{ formatMoney(p.value) }}</span>
              </div>
              <div class="ims-bar-track">
                <span :style="{ width: p.pct + '%', background: p.color }" />
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="ims-panel-title">Recent stock movements</h3>
              <div class="text-caption text-medium-emphasis">Latest postings to the ledger</div>
            </div>
            <v-btn
              variant="text" size="small" class="text-none" color="primary"
              to="/ims/inventory/stock-movements" append-icon="mdi-arrow-right"
            >Ledger</v-btn>
          </div>
          <EmptyState v-if="!recentMovements.length" icon="mdi-swap-vertical" title="No movements recorded yet" />
          <div v-else class="d-flex flex-column">
            <div v-for="m in recentMovements.slice(0, 7)" :key="m.id" class="ims-movement">
              <span class="ims-movement-dot" :class="`ims-mv-${m.direction}`">
                <v-icon size="14">{{ movementIcon(m.direction) }}</v-icon>
              </span>
              <div class="ims-row-main">
                <div class="ims-row-title text-truncate">{{ m.stock_name }}</div>
                <div class="ims-row-sub text-truncate">{{ m.source }} · {{ formatRelative(m.timestamp) }}</div>
              </div>
              <span class="ims-movement-qty" :class="`ims-mv-text-${m.direction}`">
                {{ m.direction === 'outflow' ? '' : '+' }}{{ num(m.quantity_change) }}
              </span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ NEEDS ATTENTION ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col v-for="q in queues" :key="q.key" cols="12" md="4">
        <v-card rounded="lg" border class="h-100 ims-panel ims-queue" :class="`ims-queue-${q.key}`">
          <div class="ims-queue-head">
            <div class="ims-queue-icon">
              <v-icon size="18">{{ q.icon }}</v-icon>
            </div>
            <div style="min-width:0">
              <div class="ims-panel-title">{{ q.title }}</div>
              <div class="text-caption text-medium-emphasis">{{ q.sub }}</div>
            </div>
            <span class="ims-queue-count">{{ q.count }}</span>
          </div>

          <div class="ims-queue-body">
            <EmptyState v-if="!q.items.length" :icon="q.emptyIcon" :title="q.emptyTitle" />
            <div v-else class="d-flex flex-column ga-1">
              <component
                :is="linkOr(q.linkOf ? q.linkOf(item) : null)"
                :to="q.linkOf ? q.linkOf(item) : undefined"
                v-for="(item, idx) in q.items.slice(0, 4)"
                :key="idx"
                class="ims-row"
                :class="{ 'ims-row-link': !!q.linkOf }"
              >
                <div class="ims-row-main">
                  <div class="ims-row-title text-truncate">{{ q.titleOf(item) }}</div>
                  <div class="ims-row-sub text-truncate">{{ q.subOf(item) }}</div>
                </div>
                <span v-if="q.badgeOf" class="ims-row-badge">{{ q.badgeOf(item) }}</span>
              </component>
              <NuxtLink v-if="q.items.length > 4" :to="q.moreTo" class="ims-row-more">
                +{{ q.items.length - 4 }} more
                <v-icon size="13">mdi-arrow-right</v-icon>
              </NuxtLink>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ TRANSFERS + STOCK TAKES ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#7c3aed">
                <v-icon size="17">mdi-truck-delivery-outline</v-icon>
              </div>
              <h3 class="ims-panel-title">Warehouse transfers</h3>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/inventory/transfers" append-icon="mdi-arrow-right">All</v-btn>
          </div>
          <EmptyState v-if="!recentTransfers.length" icon="mdi-truck-delivery" title="No transfers yet" />
          <table v-else class="ims-table">
            <thead>
              <tr><th>Ref</th><th>Route</th><th>Status</th></tr>
            </thead>
            <tbody>
              <tr v-for="tr in recentTransfers" :key="tr.id">
                <td class="font-weight-medium">{{ tr.reference }}</td>
                <td class="text-truncate" style="max-width:180px">
                  {{ tr.source_branch_name }}
                  <v-icon size="12" class="mx-1">mdi-arrow-right</v-icon>
                  {{ tr.dest_branch_name }}
                </td>
                <td><StatusChip v-if="tr.status" :status="tr.status" /></td>
              </tr>
            </tbody>
          </table>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#0d9488">
                <v-icon size="17">mdi-clipboard-list-outline</v-icon>
              </div>
              <h3 class="ims-panel-title">Stock takes</h3>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/inventory/stock-take" append-icon="mdi-arrow-right">All</v-btn>
          </div>
          <EmptyState v-if="!recentCounts.length" icon="mdi-clipboard-check-outline" title="No stock takes yet" />
          <table v-else class="ims-table">
            <thead>
              <tr><th>Ref</th><th>Name</th><th class="text-right">Variance</th><th>Status</th></tr>
            </thead>
            <tbody>
              <tr v-for="c in recentCounts" :key="c.id">
                <td class="font-weight-medium">{{ c.reference }}</td>
                <td class="text-truncate" style="max-width:150px">{{ c.name }}</td>
                <td class="text-right font-weight-bold" :class="varianceTone(c)">{{ varianceLabel(c) }}</td>
                <td><StatusChip v-if="c.status" :status="c.status" /></td>
              </tr>
            </tbody>
          </table>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ QUICK ACTIONS ═══════════════ -->
    <v-card rounded="lg" border class="pa-4 mt-3 ims-panel">
      <h3 class="ims-panel-title mb-3">Quick actions</h3>
      <div class="ims-actions">
        <NuxtLink
          v-for="a in actions"
          :key="a.label"
          :to="a.to"
          class="ims-action"
          :style="{ '--act-tone': a.tone }"
        >
          <v-icon size="19">{{ a.icon }}</v-icon>
          <span class="text-truncate">{{ a.label }}</span>
        </NuxtLink>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { NuxtLink } from '#components'
import { useAuthStore } from '~/stores/auth'
import { useBranchStore } from '~/stores/branch'
import { formatMoney, formatDate } from '~/utils/format'
import { canAccessRoute } from '~/utils/permissions'
import { useBranding } from '~/composables/useBranding'

const auth = useAuthStore()
const branchStore = useBranchStore()
const { $api } = useNuxtApp()

/**
 * `<component :is>` needs a component *object*. The string `'NuxtLink'` is NOT
 * resolved by Nuxt's auto-import (it silently renders an inert custom element
 * named NUXTLINK), so pass the imported component instead.
 */
const linkOr = (to) => (to ? NuxtLink : 'div')

// Tenant palette configured at /ims/organization/branding. Same CSS-var bridge
// the inventory list / detail / form pages use, so the IMS screens match.
const brand = useBranding()

const today = new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
const loading = ref(false)
const trendDays = 30
const expiryWindow = 90

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
const barColors = ['#2563eb', '#0d9488', '#16a34a', '#d97706', '#7c3aed', '#0ea5e9']

const branchLabel = computed(() =>
  branchStore.currentBranch ? branchStore.currentBranch.name : 'All warehouses')

const unitsOnHand = computed(() => stocks.value.reduce((s, x) => s + (Number(x.total_quantity) || 0), 0))

/** 1,234 — explicit locale so grouping can't drift between renders. */
function num(v) {
  return Number(v || 0).toLocaleString('en-US')
}

// ── KPI strip ────────────────────────────────────────────────────────────
const kpis = computed(() => {
  const a = analytics.value || {}
  const total = Math.max(stocks.value.length, 1)
  return [
    {
      key: 'skus', title: 'Total SKUs', icon: 'mdi-package-variant-closed',
      value: num(a.total_items ?? stocks.value.length),
      hint: `${num(stocks.value.filter(s => s.is_active !== false).length)} active`,
      chip: null, share: null,
      to: '/ims/inventory'
    },
    {
      key: 'value', title: 'Stock value (cost)', icon: 'mdi-cash-multiple',
      value: formatMoney(a.total_cost_value ?? 0),
      hint: a.potential_profit ? `${formatMoney(a.potential_profit)} profit potential` : 'Capital tied up',
      chip: null, share: null
    },
    {
      key: 'units', title: 'Units on hand', icon: 'mdi-scale-balance',
      value: num(unitsOnHand.value),
      hint: `across ${num(stocks.value.length)} line items`,
      chip: null, share: null
    },
    {
      key: 'low', title: 'Low stock', icon: 'mdi-alert-outline',
      value: num(a.low_stock_count ?? stockHealth.low),
      hint: 'below reorder level',
      chip: null, share: Math.round((stockHealth.low / total) * 100),
      to: '/ims/inventory'
    },
    {
      key: 'out', title: 'Out of stock', icon: 'mdi-package-variant-remove',
      value: num(a.out_of_stock ?? stockHealth.out),
      hint: 'unavailable to sell',
      chip: null, share: Math.round((stockHealth.out / total) * 100),
      to: '/ims/inventory'
    },
    {
      key: 'expiring', title: `Expiring ≤${expiryWindow}d`, icon: 'mdi-clock-alert-outline',
      // Deliberately the 90-day list, not analytics.expiring_30_days — the
      // label says 90d and the two windows would otherwise disagree.
      value: num(expiring.value.length),
      hint: a.expired_batches ? `${a.expired_batches} already expired` : 'within the window',
      chip: a.expired_batches ? `${a.expired_batches} expired` : null,
      chipColor: 'error', share: null
    }
  ]
})

// ── Hero health ──────────────────────────────────────────────────────────
const totalSkus = computed(() => stockHealth.healthy + stockHealth.low + stockHealth.out)
const healthPct = computed(() =>
  totalSkus.value ? Math.round((stockHealth.healthy / totalSkus.value) * 100) : 0)
const healthChipColor = computed(() =>
  healthPct.value >= 85 ? 'success' : healthPct.value >= 60 ? 'warning' : 'error')

const health = computed(() => {
  if (!totalSkus.value) return { tone: 'ok', label: 'No stock loaded', icon: 'mdi-information-outline' }
  if (healthPct.value >= 85) return { tone: 'ok', label: `Healthy · ${healthPct.value}%`, icon: 'mdi-check-circle' }
  if (healthPct.value >= 60) return { tone: 'low', label: `Needs review · ${healthPct.value}%`, icon: 'mdi-alert' }
  return { tone: 'out', label: `Critical · ${healthPct.value}%`, icon: 'mdi-alert-octagon' }
})

const healthSegments = computed(() => [
  { value: stockHealth.healthy, color: '#22c55e', label: 'Healthy' },
  { value: stockHealth.low, color: '#f59e0b', label: 'Low' },
  { value: stockHealth.out, color: '#ef4444', label: 'Out' }
])

const healthLegend = computed(() => {
  const t = Math.max(totalSkus.value, 1)
  const pct = n => `${Math.round((n / t) * 100)}%`
  return [
    { label: 'Healthy', count: stockHealth.healthy, color: '#22c55e', pct: pct(stockHealth.healthy) },
    { label: 'Low stock', count: stockHealth.low, color: '#f59e0b', pct: pct(stockHealth.low) },
    { label: 'Out of stock', count: stockHealth.out, color: '#ef4444', pct: pct(stockHealth.out) }
  ]
})

// ── Net flow ─────────────────────────────────────────────────────────────
const netChange = computed(() =>
  Number(flowKpis.net_change ?? (Number(flowKpis.total_in || 0) - Number(flowKpis.total_out || 0))))

// ── Ops pulse ────────────────────────────────────────────────────────────
// Shortfall = units needed to lift every flagged item back over its reorder
// level (an out-of-stock item is short a full reorder quantity).
const shortfall = computed(() => {
  let units = 0
  for (const s of lowStock.value) {
    const q = Number(s.total_quantity || 0)
    if (q <= 0) units += Number(s.reorder_quantity || s.reorder_level || 0)
    else units += Math.max(0, Number(s.reorder_level || 0) - q)
  }
  return units
})

const expiringUnits = computed(() => expiring.value.reduce((s, b) => s + (Number(b.qty) || 0), 0))
const expiringValue = computed(() =>
  expiring.value.reduce((s, b) => s + (Number(b.qty) || 0) * (Number(b.cost_price) || 0), 0))

const pulse = computed(() => [
  {
    icon: health.value.icon,
    tone: healthPct.value >= 85 ? '#16a34a' : healthPct.value >= 60 ? '#d97706' : '#dc2626',
    label: 'Availability',
    value: `${healthPct.value}%`,
    hint: `${num(stockHealth.healthy)} of ${num(totalSkus.value)} SKUs at healthy levels`,
    to: '/ims/inventory/stock-analysis'
  },
  {
    icon: 'mdi-cart-arrow-down',
    tone: stockHealth.low + stockHealth.out ? '#d97706' : '#16a34a',
    label: 'Replenishment',
    value: num(stockHealth.low + stockHealth.out),
    hint: stockHealth.low + stockHealth.out
      ? `${num(shortfall.value)} units short of reorder level`
      : 'every item above its reorder level',
    to: stockHealth.low + stockHealth.out ? '/ims/inventory' : null
  },
  {
    icon: 'mdi-timer-sand',
    tone: expiring.value.length ? '#dc2626' : '#16a34a',
    label: `Expiring ≤${expiryWindow}d`,
    value: num(expiringUnits.value),
    hint: expiring.value.length
      ? `${num(expiring.value.length)} batch${expiring.value.length === 1 ? '' : 'es'} · ${formatMoney(expiringValue.value)} at risk`
      : 'no batches approaching expiry',
    to: expiring.value.length ? '/ims/inventory' : null
  },
  {
    icon: netChange.value >= 0 ? 'mdi-trending-up' : 'mdi-trending-down',
    tone: netChange.value >= 0 ? '#2563eb' : '#dc2626',
    label: 'Net movement',
    value: `${netChange.value > 0 ? '+' : ''}${num(netChange.value)}`,
    hint: `${num(flowKpis.total_in)} in · ${num(flowKpis.total_out)} out`,
    to: '/ims/inventory/stock-movements'
  }
])

// ── Attention queues ─────────────────────────────────────────────────────
const queues = computed(() => [
  {
    key: 'low', title: 'Low / out of stock', sub: 'Below reorder level',
    icon: 'mdi-alert-outline', count: lowStock.value.length,
    emptyIcon: 'mdi-check-circle', emptyTitle: 'All items stocked',
    items: lowStock.value,
    moreTo: '/ims/inventory',
    titleOf: s => s.medication_name,
    subOf: s => `${num(s.total_quantity)} on hand · reorder at ${num(s.reorder_level)}`,
    linkOf: s => `/ims/inventory/stocks/${s.id}/edit`,
    badgeOf: s => (Number(s.total_quantity || 0) <= 0 ? 'OUT' : 'LOW')
  },
  {
    key: 'expiring', title: 'Expiring batches', sub: `Within ${expiryWindow} days`,
    icon: 'mdi-clock-alert-outline', count: expiring.value.length,
    emptyIcon: 'mdi-check-circle', emptyTitle: 'No batches expiring soon',
    items: expiring.value,
    moreTo: '/ims/inventory',
    titleOf: b => b.name,
    subOf: b => `Batch ${b.batch_number || '—'} · expires ${formatDate(b.expiry_date)}`,
    linkOf: b => `/ims/inventory/stocks/${b.stockId}/edit`,
    badgeOf: b => `${num(b.qty)} left`
  },
  {
    key: 'po', title: 'Open purchase orders', sub: 'Draft, sent or partially received',
    icon: 'mdi-cart-arrow-down', count: openPOs.value.length,
    emptyIcon: 'mdi-check-circle', emptyTitle: 'No open purchase orders',
    items: openPOs.value,
    moreTo: '/ims/purchase-orders',
    titleOf: o => o.po_number || `PO #${o.id}`,
    subOf: o => `${o.supplier_name || 'Supplier'} · ${formatMoney(o.total_cost)}`,
    linkOf: o => `/ims/purchase-orders/${o.id}`,
    badgeOf: o => o.status || ''
  }
])

const actions = computed(() => [
  { icon: 'mdi-plus-circle', label: 'Add Stock Item', to: '/ims/inventory/stocks/new', tone: '#2563eb' },
  { icon: 'mdi-clipboard-list-outline', label: 'Stock Take', to: '/ims/inventory/stock-take', tone: '#0d9488' },
  { icon: 'mdi-cart', label: 'Purchase Orders', to: '/ims/purchase-orders', tone: '#d97706' },
  { icon: 'mdi-truck-delivery-outline', label: 'Transfers', to: '/ims/inventory/transfers', tone: '#7c3aed' },
  { icon: 'mdi-swap-vertical-bold', label: 'Movements', to: '/ims/inventory/stock-movements', tone: '#0ea5e9' },
  { icon: 'mdi-chart-line', label: 'Stock Analysis', to: '/ims/inventory/stock-analysis', tone: '#16a34a' },
  { icon: 'mdi-file-excel', label: 'Excel Tools', to: '/ims/inventory/excel', tone: '#15803d' },
  { icon: 'mdi-file-chart', label: 'Reports', to: '/ims/reports', tone: '#4f46e5' }
].filter(a => canAccessRoute(auth.role, a.to)))

// ── Helpers ──────────────────────────────────────────────────────────────
function formatRelative(v) {
  if (!v) return ''
  const d = new Date(v)
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}

function movementIcon(direction) {
  if (direction === 'inflow') return 'mdi-arrow-down'
  if (direction === 'outflow') return 'mdi-arrow-up'
  return 'mdi-swap-horizontal'
}

// `>=` cannot appear in a template binding, so the comparison lives here.
function varianceTone(c) {
  const v = Number(c.total_variance || 0)
  if (v === 0) return 'text-medium-emphasis'
  return v < 0 ? 'text-error' : 'text-success'
}
function varianceLabel(c) {
  const v = Number(c.total_variance || 0)
  return v > 0 ? `+${num(v)}` : num(v)
}

async function load() {
  loading.value = true
  const safeGet = (p) => $api.get(p).then(r => r.data).catch(() => null)
  const safeList = (p) => safeGet(p).then(d => d?.results || (Array.isArray(d) ? d : []))

  const bid = branchStore.currentBranchId
  const bp = bid ? `&branch_id=${bid}` : ''
  const bpStocks = bid ? `&branch=${bid}` : ''

  const end = new Date()
  const start = new Date(end.getTime() - (trendDays - 1) * 86400000)
  const iso = (d) => d.toISOString().slice(0, 10)

  const [an, st, mv, po, tr, cnt] = await Promise.all([
    safeGet(`/inventory/analytics/${bid ? `?branch_id=${bid}` : ''}`),
    safeList(`/inventory/stocks/?page_size=1000${bpStocks}`),
    safeGet(`/inventory/stock-movements/?date_from=${iso(start)}&date_to=${iso(end)}${bp}`),
    safeList(`/purchase-orders/?page_size=100${bid ? `&branch=${bid}` : ''}`),
    safeList(`/inventory/transfers/?page_size=100${bid ? `&branch=${bid}` : ''}`),
    safeList(`/inventory/counts/?page_size=100${bid ? `&branch=${bid}` : ''}`),
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
  const soon = new Date(); soon.setDate(soon.getDate() + expiryWindow)
  const expList = []
  for (const s of stocks.value) {
    for (const b of (s.batches || [])) {
      if (b.quantity_remaining > 0 && b.expiry_date && new Date(b.expiry_date) <= soon) {
        expList.push({
          stockId: s.id, name: s.medication_name, batch_number: b.batch_number,
          expiry_date: b.expiry_date, qty: b.quantity_remaining,
          cost_price: s.cost_price,
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
  topValueItems.value = byValue.map((p, i) => ({
    ...p,
    pct: (p.value / maxVal) * 100,
    color: barColors[i % barColors.length]
  }))

  // Stock flow trend
  if (mv) {
    Object.assign(flowKpis, mv.kpis || {})
    const trend = mv.trend || []
    const active = trend
      .map(d => ({
        label: new Date(d.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }),
        inflow: (d.inflow || 0) + (d.transfer || 0),
        outflow: d.outflow || 0,
      }))
      .filter(d => d.inflow > 0 || d.outflow > 0)
    trendLabels.value = active.map(d => d.label)
    inflowValues.value = active.map(d => d.inflow)
    outflowValues.value = active.map(d => d.outflow)
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

onMounted(() => {
  // Deep-linking straight to /ims means nothing has fetched the tenant palette
  // yet (useBranding caches in shared state, so this is a no-op when the
  // inventory list already loaded it).
  brand.load()
  load()
})

watch(() => branchStore.currentBranchId, () => {
  load()
})
</script>

<style scoped>
.ims-dash { max-width: 1600px; margin: 0 auto; }
.ims-nowrap { white-space: nowrap; }

/* ═══════════════ KPI cards ═══════════════
   Tone travels via `color`, so the top rail, the icon chip and the mini share
   bar can all derive from currentColor. */
.ims-kpi {
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
.ims-kpi::after {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 3px;
  background: currentColor;
  opacity: 0.85;
}
.ims-kpi:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.1); }
.ims-kpi-link { cursor: pointer; }
.ims-kpi-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: currentColor;
  background: color-mix(in srgb, currentColor 14%, transparent);
}
.ims-kpi-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
}
.ims-kpi-value {
  font-size: 21px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  margin-top: 1px;
}
.ims-kpi-foot {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
  margin-top: 2px;
}
.ims-kpi-bars { height: 4px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.ims-kpi-bars span { display: block; height: 100%; border-radius: 999px; background: currentColor; }

/* Per-KPI hues. The `t-` infix keeps these distinct from `.ims-kpi-value`,
   which is the inner value *text* class — without it every KPI number picks up
   the green tone rule. */
.ims-kpi-t-skus { color: #2563eb; }
.ims-kpi-t-value { color: #16a34a; }
.ims-kpi-t-units { color: #0d9488; }
.ims-kpi-t-low { color: #d97706; }
.ims-kpi-t-out { color: #dc2626; }
.ims-kpi-t-expiring { color: #7c3aed; }

/* ═══════════════ Ops pulse ═══════════════ */
.ims-pulse {
  border-radius: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  overflow: hidden;
}
.ims-pulse-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 16px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.9px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  border-bottom: 1px solid rgba(15, 23, 42, 0.07);
}
.ims-pulse-window {
  margin-left: auto;
  font-weight: 600;
  letter-spacing: 0.3px;
  text-transform: none;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.ims-pulse-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
.ims-pulse-tile {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
  color: inherit;
  text-decoration: none;
  border-left: 1px solid rgba(15, 23, 42, 0.07);
  transition: background 0.16s ease;
}
.ims-pulse-tile:first-child { border-left: none; }
.ims-pulse-link { cursor: pointer; }
.ims-pulse-link:hover { background: rgba(var(--v-theme-primary), 0.045); }
.ims-pulse-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--pulse-tone, #2563eb);
  background: color-mix(in srgb, var(--pulse-tone, #2563eb) 14%, transparent);
}
.ims-pulse-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.ims-pulse-value {
  font-size: 20px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  color: var(--pulse-tone, #2563eb);
}
.ims-pulse-hint {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.35;
  margin-top: 1px;
}

/* ═══════════════ Panels ═══════════════ */
.ims-panel { transition: box-shadow 0.18s ease; }
.ims-panel:hover { box-shadow: 0 6px 20px rgba(15, 23, 42, 0.07); }
.ims-panel-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: -0.1px;
}
.ims-panel-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--panel-tone, #2563eb);
  background: color-mix(in srgb, var(--panel-tone, #2563eb) 14%, transparent);
}

/* Flow stats */
.ims-flowstat {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 66px;
  padding: 5px 10px;
  border-radius: 10px;
  line-height: 1.2;
}
.ims-flowstat-label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  opacity: 0.7;
}
.ims-flowstat-value { font-size: 15px; font-weight: 800; }
.ims-flowstat-in { background: rgba(34, 197, 94, 0.12); color: #15803d; }
.ims-flowstat-out { background: rgba(239, 68, 68, 0.12); color: #b91c1c; }
.ims-flowstat-net { background: rgba(14, 165, 233, 0.12); color: #0369a1; }

/* Shared legend */
.ims-legend { display: flex; align-items: center; gap: 8px; padding: 5px 0; }
.ims-legend-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}
.ims-legend-pct { min-width: 34px; text-align: right; }

/* Ranked bars */
.ims-rank {
  width: 20px;
  height: 20px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 10.5px;
  font-weight: 800;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.ims-bar-track { height: 7px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.ims-bar-track span { display: block; height: 100%; border-radius: 999px; }

/* ═══════════════ Attention queues ═══════════════ */
.ims-queue { position: relative; overflow: hidden; border-color: rgba(15, 23, 42, 0.08); }
.ims-queue::after {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: var(--queue-tone, #2563eb);
}
.ims-queue-low { --queue-tone: #d97706; }
.ims-queue-expiring { --queue-tone: #dc2626; }
.ims-queue-po { --queue-tone: #4f46e5; }

.ims-queue-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.07);
}
.ims-queue-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--queue-tone, #2563eb);
  background: color-mix(in srgb, var(--queue-tone, #2563eb) 14%, transparent);
}
.ims-queue-count {
  margin-left: auto;
  height: 24px;
  padding: 0 10px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 12.5px;
  font-weight: 800;
  color: var(--queue-tone, #2563eb);
  background: color-mix(in srgb, var(--queue-tone, #2563eb) 13%, transparent);
}
.ims-queue-body { padding: 12px 16px 16px; }

/* Generic list row — used by the queues. */
.ims-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  border-radius: 10px;
  color: inherit;
  text-decoration: none;
  transition: background 0.14s ease;
}
.ims-row-link { cursor: pointer; }
.ims-row-link:hover { background: rgba(var(--v-theme-primary), 0.06); }
.ims-row-main { min-width: 0; flex: 1 1 auto; }
.ims-row-title { font-size: 13.5px; font-weight: 600; line-height: 1.3; }
.ims-row-sub { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), 0.6); line-height: 1.3; }
.ims-row-badge {
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.5px;
  padding: 2px 8px;
  border-radius: 999px;
  color: var(--queue-tone, #2563eb);
  background: color-mix(in srgb, var(--queue-tone, #2563eb) 13%, transparent);
}
.ims-row-more {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  font-weight: 600;
  color: rgb(var(--v-theme-primary));
  text-decoration: none;
  padding: 2px 10px;
}
.ims-row-more:hover { text-decoration: underline; }

/* Movements */
.ims-movement {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 7px 4px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.055);
}
.ims-movement:last-child { border-bottom: none; }
.ims-movement-dot {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.ims-mv-inflow { background: rgba(34, 197, 94, 0.14); color: #15803d; }
.ims-mv-outflow { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }
.ims-mv-transfer { background: rgba(14, 165, 233, 0.14); color: #0369a1; }
.ims-movement-qty { font-size: 13.5px; font-weight: 800; white-space: nowrap; }
.ims-mv-text-inflow { color: #15803d; }
.ims-mv-text-outflow { color: #b91c1c; }
.ims-mv-text-transfer { color: #0369a1; }

/* ═══════════════ Compact tables ═══════════════ */
.ims-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13.5px; }
.ims-table th {
  text-align: left;
  padding: 8px 10px;
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  border-bottom: 1px solid rgba(15, 23, 42, 0.1);
  white-space: nowrap;
}
.ims-table td {
  padding: 9px 10px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  white-space: nowrap;
}
.ims-table tbody tr:last-child td { border-bottom: none; }
.ims-table tbody tr { transition: background 0.14s ease; }
.ims-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.045); }

/* ═══════════════ Quick actions ═══════════════ */
.ims-actions { display: grid; grid-template-columns: repeat(auto-fit, minmax(175px, 1fr)); gap: 10px; }
.ims-action {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  color: rgba(var(--v-theme-on-surface), 0.87);
  font-size: 13.5px;
  font-weight: 600;
  text-decoration: none;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.ims-action :deep(.v-icon) { color: var(--act-tone, #2563eb); flex-shrink: 0; }
.ims-action:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--act-tone, #2563eb) 45%, transparent);
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.09);
}
</style>
