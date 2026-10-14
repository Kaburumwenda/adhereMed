<template>
  <v-container fluid class="pa-3 pa-md-5 procurement-dashboard">
    <!-- Hero header -->
    <div class="hero-header mb-5">
      <div class="d-flex flex-wrap align-center justify-space-between">
        <div class="d-flex align-center" style="gap:16px">
          <v-avatar color="primary" variant="tonal" rounded="xl" size="56">
            <v-icon size="30">mdi-chart-timeline-variant-shimmer</v-icon>
          </v-avatar>
          <div>
            <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Procurement Dashboard</h1>
            <div class="text-body-2 text-medium-emphasis">Purchase orders, RFQs, supplier performance &amp; spend analytics</div>
          </div>
        </div>
        <div class="d-flex align-center flex-wrap mt-3 mt-md-0" style="gap:8px">
          <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="loadAll">Refresh</v-btn>
          <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" @click="navigateTo('/purchase-orders/new')">New PO</v-btn>
          <v-btn color="purple" prepend-icon="mdi-file-document-plus" rounded="lg" class="text-none" @click="navigateTo('/purchase-orders/rfqs/new')">New RFQ</v-btn>
        </div>
      </div>
    </div>

    <v-progress-linear v-if="loading && !kpis.total_pos" color="primary" indeterminate class="mb-4" />

    <!-- Primary KPI strip — 4 gradient cards -->
    <v-row dense class="mb-3">
      <v-col cols="6" md="3">
        <div class="kpi-gradient-card kpi-indigo">
          <div class="kpi-glow"></div>
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="kpi-label">Total POs</div>
              <div class="kpi-value">{{ (kpis.total_pos ?? 0).toLocaleString() }}</div>
              <div class="kpi-sub">
                <v-icon size="12" class="mr-1">mdi-trending-up</v-icon>
                Avg {{ formatMoney(kpis.avg_po_value) }}
              </div>
            </div>
            <v-icon class="kpi-icon-bg">mdi-cart-outline</v-icon>
          </div>
        </div>
      </v-col>
      <v-col cols="6" md="3">
        <div class="kpi-gradient-card kpi-amber">
          <div class="kpi-glow"></div>
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="kpi-label">Pending / Sent</div>
              <div class="kpi-value">{{ (kpis.pending_orders ?? 0).toLocaleString() }}</div>
              <div class="kpi-sub">
                <v-icon size="12" class="mr-1" :color="overdueHighlight">mdi-truck-alert</v-icon>
                {{ kpis.overdue_deliveries ?? 0 }} overdue
              </div>
            </div>
            <v-icon class="kpi-icon-bg">mdi-clock-outline</v-icon>
          </div>
        </div>
      </v-col>
      <v-col cols="6" md="3">
        <div class="kpi-gradient-card kpi-emerald">
          <div class="kpi-glow"></div>
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="kpi-label">Total Spend</div>
              <div class="kpi-value">{{ formatMoney(kpis.total_spend) }}</div>
              <div class="kpi-sub">
                <v-icon size="12" class="mr-1">mdi-package-variant-closed-check</v-icon>
                {{ kpis.received_orders ?? 0 }} received
              </div>
            </div>
            <v-icon class="kpi-icon-bg">mdi-cash-multiple</v-icon>
          </div>
        </div>
      </v-col>
      <v-col cols="6" md="3">
        <div class="kpi-gradient-card kpi-violet">
          <div class="kpi-glow"></div>
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="kpi-label">Open RFQs</div>
              <div class="kpi-value">{{ (kpis.open_rfqs ?? 0).toLocaleString() }}</div>
              <div class="kpi-sub">
                <v-icon size="12" class="mr-1">mdi-trophy-variant</v-icon>
                {{ kpis.awarded_rfqs ?? 0 }} awarded
              </div>
            </div>
            <v-icon class="kpi-icon-bg">mdi-file-document-multiple</v-icon>
          </div>
        </div>
      </v-col>
    </v-row>

    <!-- Secondary KPI strip -->
    <v-row dense class="mb-4">
      <v-col cols="6" sm="3" md="3">
        <v-card rounded="lg" elevation="0" class="kpi-mini kpi-mini-red">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="36"><v-icon size="18">mdi-truck-clock</v-icon></v-avatar>
            <div>
              <div class="kpi-mini-label">Pending Delivery</div>
              <div class="kpi-mini-value">{{ (kpis.pending_delivery ?? 0).toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3" md="3">
        <v-card rounded="lg" elevation="0" class="kpi-mini kpi-mini-blue">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="info" variant="tonal" rounded="lg" size="36"><v-icon size="18">mdi-package-variant-closed</v-icon></v-avatar>
            <div>
              <div class="kpi-mini-label">Reorder Suggestions</div>
              <div class="kpi-mini-value">{{ (kpis.pending_suggestions ?? 0).toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3" md="3">
        <v-card rounded="lg" elevation="0" class="kpi-mini kpi-mini-teal">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="teal" variant="tonal" rounded="lg" size="36"><v-icon size="18">mdi-format-list-bulleted</v-icon></v-avatar>
            <div>
              <div class="kpi-mini-label">PO Status Types</div>
              <div class="kpi-mini-value">{{ (kpis.status_breakdown || []).length }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3" md="3">
        <v-card rounded="lg" elevation="0" class="kpi-mini kpi-mini-orange">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="orange" variant="tonal" rounded="lg" size="36"><v-icon size="18">mdi-star-circle-outline</v-icon></v-avatar>
            <div>
              <div class="kpi-mini-label">Avg Supplier Rating</div>
              <div class="kpi-mini-value">{{ kpis.avg_supplier_rating ?? '—' }}<span class="text-caption text-medium-emphasis">/5</span></div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Charts row: Monthly spend trend + PO status donut -->
    <v-row class="mb-4">
      <v-col cols="12" lg="8">
        <v-card rounded="xl" elevation="0" class="chart-card pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center mb-3">
            <v-icon start color="primary">mdi-chart-line-variant</v-icon>
            <span class="text-subtitle-1 font-weight-bold">Monthly Spend Trend</span>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" color="primary">Last 6 months</v-chip>
          </div>
          <div v-if="(kpis.monthly_spend || []).length" class="spend-chart-wrap">
            <svg :viewBox="`0 0 ${chartW} ${chartH}`" preserveAspectRatio="none" width="100%" :height="chartH" class="spend-chart">
              <defs>
                <linearGradient id="spendGrad" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0%" stop-color="#6366f1" stop-opacity="0.4" />
                  <stop offset="100%" stop-color="#6366f1" stop-opacity="0.02" />
                </linearGradient>
              </defs>
              <!-- Grid lines -->
              <g v-for="i in 4" :key="'g'+i">
                <line :x1="40" :x2="chartW - 10" :y1="20 + (i-1) * ((chartH - 40) / 3)" :y2="20 + (i-1) * ((chartH - 40) / 3)" stroke="currentColor" stroke-opacity="0.06" stroke-width="1" stroke-dasharray="4,4" />
                <text :x="32" :y="24 + (i-1) * ((chartH - 40) / 3)" text-anchor="end" font-size="10" fill="currentColor" fill-opacity="0.45">{{ formatShort(maxSpend) }}</text>
              </g>
              <!-- Area + line -->
              <path :d="areaPath" fill="url(#spendGrad)" />
              <path :d="linePath" fill="none" stroke="#6366f1" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" />
              <!-- Bars -->
              <g v-for="(p, i) in chartPoints" :key="'b'+i">
                <rect :x="p.x - 6" :y="p.y" width="12" :height="chartH - 28 - p.y" rx="3" fill="#6366f1" fill-opacity="0.15" />
              </g>
              <!-- Dots -->
              <g v-for="(p, i) in chartPoints" :key="'d'+i">
                <circle :cx="p.x" :cy="p.y" r="4" fill="#6366f1" stroke="white" stroke-width="2" />
                <text :x="p.x" :y="p.y - 8" text-anchor="middle" font-size="10" fill="#6366f1" font-weight="600">{{ formatShort(p.value) }}</text>
              </g>
              <!-- X-axis labels -->
              <g v-for="(m, i) in (kpis.monthly_spend || [])" :key="'l'+i">
                <text :x="chartPoints[i]?.x" :y="chartH - 6" text-anchor="middle" font-size="10" fill="currentColor" fill-opacity="0.5">{{ m.month.split(' ')[0] }}</text>
              </g>
            </svg>
          </div>
          <div v-else class="text-center text-medium-emphasis py-8">
            <v-icon size="48" color="grey">mdi-chart-line-variant</v-icon>
            <div class="text-body-2 mt-2">No spend data yet</div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" elevation="0" class="chart-card pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center mb-3">
            <v-icon start color="info">mdi-chart-donut</v-icon>
            <span class="text-subtitle-1 font-weight-bold">PO Status Breakdown</span>
          </div>
          <div v-if="(kpis.status_breakdown || []).length" class="d-flex flex-column align-center">
            <!-- SVG Donut -->
            <svg width="160" height="160" viewBox="0 0 160 160" class="mb-3">
              <circle cx="80" cy="80" r="60" fill="none" stroke="currentColor" stroke-opacity="0.06" stroke-width="16" />
              <circle v-for="(s, i) in donutSegments" :key="i"
                cx="80" cy="80" r="60" fill="none"
                :stroke="s.color" stroke-width="16"
                :stroke-dasharray="`${s.dash} ${circumference - s.dash}`"
                :stroke-dashoffset="s.offset"
                transform="rotate(-90 80 80)"
                style="transition: stroke-dasharray 0.5s ease;"
              />
              <text x="80" y="74" text-anchor="middle" font-size="28" font-weight="700" fill="currentColor">{{ kpis.total_pos ?? 0 }}</text>
              <text x="80" y="92" text-anchor="middle" font-size="11" fill="currentColor" fill-opacity="0.5">Total POs</text>
            </svg>
            <!-- Legend -->
            <div class="w-100">
              <div v-for="(s, i) in donutSegments" :key="'donut-'+i" class="d-flex align-center justify-space-between py-1">
                <div class="d-flex align-center" style="gap:8px">
                  <span class="donut-dot" :style="{ background: s.color }"></span>
                  <span class="text-body-2 text-capitalize">{{ s.status }}</span>
                </div>
                <span class="text-body-2 font-weight-medium">{{ s.count }}</span>
              </div>
            </div>
          </div>
          <div v-else class="text-center text-medium-emphasis py-8">
            <v-icon size="48" color="grey">mdi-chart-donut</v-icon>
            <div class="text-body-2 mt-2">No PO data</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Quick action tiles -->
    <v-row dense class="mb-4">
      <v-col cols="6" sm="3">
        <v-card rounded="lg" elevation="0" class="quick-action-tile pa-3" @click="navigateTo('/purchase-orders')">
          <v-icon color="primary" size="28">mdi-cart</v-icon>
          <div class="text-body-2 font-weight-medium mt-1">Purchase Orders</div>
          <div class="text-caption text-medium-emphasis">{{ kpis.total_pos ?? 0 }} total</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" elevation="0" class="quick-action-tile pa-3" @click="navigateTo('/purchase-orders/rfqs')">
          <v-icon color="purple" size="28">mdi-file-document-multiple</v-icon>
          <div class="text-body-2 font-weight-medium mt-1">RFQs</div>
          <div class="text-caption text-medium-emphasis">{{ kpis.total_rfqs ?? 0 }} total</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" elevation="0" class="quick-action-tile pa-3" @click="navigateTo('/purchase-orders/reorder-suggestions')">
          <v-icon color="info" size="28">mdi-cart-arrow-down</v-icon>
          <div class="text-body-2 font-weight-medium mt-1">Reorder Suggestions</div>
          <div class="text-caption text-medium-emphasis">{{ kpis.pending_suggestions ?? 0 }} pending</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" elevation="0" class="quick-action-tile pa-3" @click="navigateTo('/evaluations')">
          <v-icon color="warning" size="28">mdi-star-check-outline</v-icon>
          <div class="text-body-2 font-weight-medium mt-1">Supplier Eval</div>
          <div class="text-caption text-medium-emphasis">{{ kpis.total_evaluations ?? 0 }} evaluations</div>
        </v-card>
      </v-col>
    </v-row>

    <v-row>
      <!-- Recent orders -->
      <v-col cols="12" lg="8">
        <v-card rounded="xl" elevation="0" class="pa-4 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center mb-3">
            <v-icon start color="primary">mdi-history</v-icon>
            <span class="text-subtitle-1 font-weight-bold">Recent Purchase Orders</span>
            <v-spacer />
            <v-btn size="small" variant="text" class="text-none" append-icon="mdi-arrow-right" @click="navigateTo('/purchase-orders')">View all</v-btn>
          </div>
          <div class="table-wrap">
            <table class="inv-table">
              <thead>
                <tr><th class="row-num">#</th><th>PO #</th><th>Supplier</th><th>Status</th><th class="text-right">Total</th><th>Date</th></tr>
              </thead>
              <tbody>
                <tr v-for="(po, i) in (kpis.recent_orders || [])" :key="po.id" class="inv-row-click" @click="navigateTo(`/purchase-orders/${po.id}`)">
                  <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
                  <td class="font-weight-medium text-primary">{{ po.po_number }}</td>
                  <td>
                    <div class="d-flex align-center" style="gap:6px">
                      <v-avatar size="24" color="primary" variant="tonal"><span class="text-caption">{{ initials(po.supplier_name) }}</span></v-avatar>
                      {{ po.supplier_name }}
                    </div>
                  </td>
                  <td><v-chip size="x-small" variant="tonal" :color="poStatusColor(po.status)">{{ po.status }}</v-chip></td>
                  <td class="text-right font-weight-medium">{{ formatMoney(po.total_cost) }}</td>
                  <td class="text-medium-emphasis">{{ formatDate(po.order_date || po.created_at) }}</td>
                </tr>
                <tr v-if="!(kpis.recent_orders || []).length"><td colspan="6" class="text-center text-medium-emphasis py-4">No recent orders.</td></tr>
              </tbody>
            </table>
          </div>
        </v-card>
      </v-col>

      <!-- Right column: Top suppliers + Top rated -->
      <v-col cols="12" lg="4">
        <!-- Top suppliers by spend -->
        <v-card rounded="xl" elevation="0" class="pa-4 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center mb-3">
            <v-icon start color="teal">mdi-trophy-outline</v-icon>
            <span class="text-subtitle-1 font-weight-bold">Top Suppliers by Spend</span>
          </div>
          <div v-for="(s, i) in (kpis.top_suppliers || [])" :key="'ts-'+i" class="mb-2">
            <div class="d-flex align-center justify-space-between mb-1">
              <div class="d-flex align-center" style="gap:8px">
                <v-avatar size="28" :color="rankColor(i)" variant="tonal"><span class="text-caption font-weight-bold">{{ i + 1 }}</span></v-avatar>
                <div>
                  <div class="text-body-2 font-weight-medium">{{ s.supplier__name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ s.order_count }} orders</div>
                </div>
              </div>
              <div class="text-body-2 font-weight-bold">{{ formatMoney(s.total_spend) }}</div>
            </div>
            <!-- Spend bar -->
            <v-progress-linear
              :model-value="supplierPct(s.total_spend)"
              :color="rankColor(i)"
              height="4"
              rounded
              class="ml-9"
            />
          </div>
          <div v-if="!(kpis.top_suppliers || []).length" class="text-center text-medium-emphasis pa-3">No supplier data yet.</div>
        </v-card>

        <!-- Top rated suppliers -->
        <v-card rounded="xl" elevation="0" class="pa-4" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center mb-3">
            <v-icon start color="warning">mdi-star-circle-outline</v-icon>
            <span class="text-subtitle-1 font-weight-bold">Top Rated Suppliers</span>
          </div>
          <div v-for="(s, i) in (kpis.top_rated_suppliers || [])" :key="'tr-'+i" class="d-flex align-center justify-space-between py-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-avatar color="warning" variant="tonal" size="32"><v-icon size="16">mdi-truck</v-icon></v-avatar>
              <span class="text-body-2 font-weight-medium">{{ s.supplier_name }}</span>
            </div>
            <div class="d-flex align-center" style="gap:4px">
              <v-rating :model-value="s.overall_rating" length="5" density="compact" size="small" readonly color="warning" />
              <span class="text-body-2 font-weight-bold ml-1">{{ Number(s.overall_rating).toFixed(1) }}</span>
            </div>
          </div>
          <div v-if="!(kpis.top_rated_suppliers || []).length" class="text-center text-medium-emphasis pa-3">
            <v-icon size="36" color="grey">mdi-star-off</v-icon>
            <div class="text-body-2 mt-1">No evaluations yet.</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Reorder cost estimate banner -->
    <v-card v-if="kpis.estimated_reorder_cost > 0" rounded="xl" elevation="0" class="pa-4 mt-3 reorder-banner" @click="navigateTo('/purchase-orders/reorder-suggestions')">
      <div class="d-flex flex-wrap align-center justify-space-between">
        <div class="d-flex align-center" style="gap:14px">
          <v-avatar color="info" variant="tonal" rounded="lg" size="44">
            <v-icon size="22">mdi-cart-arrow-down</v-icon>
          </v-avatar>
          <div>
            <div class="text-subtitle-1 font-weight-bold">Reorder Suggestions Ready</div>
            <div class="text-body-2 text-medium-emphasis">{{ kpis.pending_suggestions }} items suggested • Estimated cost: {{ formatMoney(kpis.estimated_reorder_cost) }}</div>
          </div>
        </div>
        <v-btn color="info" variant="flat" rounded="lg" class="text-none" append-icon="mdi-arrow-right">Review &amp; Order</v-btn>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatMoney, formatDate } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const loading = ref(false)
const kpis = ref({})

const overdueHighlight = computed(() => (kpis.value.overdue_deliveries > 0 ? 'error' : 'success'))

function poStatusColor(s) {
  return { draft: 'grey', sent: 'info', received: 'success', partial: 'warning', cancelled: 'error', returned: 'purple' }[s] || 'grey'
}

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase()
}

function rankColor(i) {
  return ['warning', 'info', 'teal', 'primary', 'purple'][i] || 'primary'
}

function formatShort(v) {
  const n = Number(v || 0)
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M'
  if (n >= 1_000) return (n / 1_000).toFixed(0) + 'K'
  return n.toFixed(0)
}

// ── Chart computations ──
const chartW = 560
const chartH = 220
const padX = 40
const padY = 20

const maxSpend = computed(() => {
  const vals = (kpis.value.monthly_spend || []).map(m => m.spend)
  return vals.length ? Math.max(...vals, 1) : 1
})

const chartPoints = computed(() => {
  const data = kpis.value.monthly_spend || []
  if (!data.length) return []
  const w = chartW - padX - 10
  const h = chartH - padY - 28
  const stepX = data.length > 1 ? w / (data.length - 1) : 0
  return data.map((m, i) => ({
    x: padX + (data.length === 1 ? w / 2 : i * stepX),
    y: padY + h - (m.spend / maxSpend.value) * h,
    value: m.spend,
    label: m.month,
    orders: m.orders,
  }))
})

const linePath = computed(() => {
  const pts = chartPoints.value
  if (pts.length < 2) return ''
  return pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`).join(' ')
})

const areaPath = computed(() => {
  const pts = chartPoints.value
  if (pts.length < 2) return ''
  const baseY = chartH - 28
  return `M ${pts[0].x} ${baseY} ` + pts.map(p => `L ${p.x} ${p.y}`).join(' ') + ` L ${pts[pts.length - 1].x} ${baseY} Z`
})

// ── Donut chart ──
const circumference = 2 * Math.PI * 60

const donutSegments = computed(() => {
  const data = kpis.value.status_breakdown || []
  if (!data.length) return []
  const total = data.reduce((s, d) => s + d.count, 0) || 1
  let offset = 0
  const colors = { draft: '#9e9e9e', sent: '#2196f3', received: '#4caf50', partial: '#ff9800', cancelled: '#f44336', returned: '#9c27b0' }
  return data.map(d => {
    const dash = (d.count / total) * circumference
    const seg = { status: d.status, count: d.count, color: colors[d.status] || '#757575', dash, offset: -offset }
    offset += dash
    return seg
  })
})

function supplierPct(val) {
  const top = kpis.value.top_suppliers?.[0]?.total_spend || 1
  return Math.min(100, (Number(val || 0) / Number(top)) * 100)
}

async function loadAll() {
  loading.value = true
  try {
    const params = {}
    if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
    const { data } = await $api.get('/purchase-orders/dashboard/', { params })
    kpis.value = data
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await branchStore.load()
  loadAll()
})
</script>

<style scoped>
.procurement-dashboard { max-width: 1600px; margin: 0 auto; }

.hero-header {
  border-radius: 16px;
  padding: 20px 24px;
  background: linear-gradient(135deg, rgba(99,102,241,0.04), rgba(168,85,247,0.03));
  border: 1px solid rgba(99,102,241,0.08);
}

/* Gradient KPI cards */
.kpi-gradient-card {
  position: relative;
  border-radius: 16px;
  padding: 18px 20px;
  overflow: hidden;
  border: 1px solid rgba(0,0,0,0.06);
  background: #fff;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  height: 100%;
}
.kpi-gradient-card:hover { transform: translateY(-3px); box-shadow: 0 12px 28px rgba(0,0,0,0.08); }
.kpi-glow {
  position: absolute;
  top: -30px; right: -20px;
  width: 100px; height: 100px;
  border-radius: 50%;
  filter: blur(40px);
  opacity: 0.15;
}
.kpi-indigo .kpi-glow { background: #6366f1; }
.kpi-amber .kpi-glow { background: #f59e0b; }
.kpi-emerald .kpi-glow { background: #10b981; }
.kpi-violet .kpi-glow { background: #8b5cf6; }

.kpi-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(0,0,0,0.5); font-weight: 600; }
.kpi-value { font-size: 28px; font-weight: 800; line-height: 1.2; margin: 2px 0; }
.kpi-sub { font-size: 12px; color: rgba(0,0,0,0.45); display: flex; align-items: center; }
.kpi-icon-bg { font-size: 40px !important; opacity: 0.08; position: absolute; bottom: 8px; right: 12px; }

/* Mini KPI cards */
.kpi-mini {
  border: 1px solid rgba(0,0,0,0.06);
  padding: 12px 14px;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  cursor: default;
}
.kpi-mini:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }
.kpi-mini-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.4px; color: rgba(0,0,0,0.5); font-weight: 600; }
.kpi-mini-value { font-size: 20px; font-weight: 700; line-height: 1.3; }

/* Chart cards */
.chart-card { background: #fff; transition: box-shadow 0.2s ease; }
.chart-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.04); }
.spend-chart { color: rgba(0,0,0,0.8); }

/* Donut */
.donut-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }

/* Quick action tiles */
.quick-action-tile {
  border: 1px solid rgba(0,0,0,0.06);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.quick-action-tile:hover { transform: translateY(-3px); box-shadow: 0 8px 20px rgba(99,102,241,0.1); border-color: rgba(99,102,241,0.3); }

/* Table */
.table-wrap { overflow-x: auto; }
.inv-table { border-collapse: collapse; font-size: 13px; width: 100%; }
.inv-table thead th {
  text-align: left; padding: 8px 10px; font-weight: 600;
  border-bottom: 1px solid rgba(0,0,0,0.08);
  white-space: nowrap; color: rgba(0,0,0,0.5); font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px;
}
.inv-table tbody td { padding: 10px; border-bottom: 1px solid rgba(0,0,0,0.04); vertical-align: middle; }
.inv-table tbody tr { transition: background 0.1s; }
.inv-table tbody tr:hover { background: rgba(99,102,241,0.03); }
.inv-row-click { cursor: pointer; }
.row-num { width: 36px; text-align: center; }

/* Reorder banner */
.reorder-banner {
  background: linear-gradient(135deg, rgba(0,184,212,0.06), rgba(99,102,241,0.04));
  border: 1px solid rgba(0,184,212,0.15);
  cursor: pointer;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}
.reorder-banner:hover { box-shadow: 0 8px 24px rgba(0,184,212,0.12); transform: translateY(-2px); }
</style>
