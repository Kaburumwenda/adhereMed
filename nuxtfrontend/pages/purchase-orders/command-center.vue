<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Procurement Command Center"
      subtitle="Live procure-to-pay health: spend, delivery, sourcing risk and savings pipeline"
      eyebrow="INSIGHTS · PROCUREMENT"
      icon="mdi-chart-timeline-variant-shimmer"
      color="indigo"
      :loading="loading"
      :stamp="stamp"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn variant="text" color="grey" rounded="lg" class="text-none" prepend-icon="mdi-history"
               to="/ims/purchase-orders/dashboard">Classic KPIs</v-btn>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-cart-plus"
               to="/ims/purchase-orders/new">New PO</v-btn>
        <v-btn variant="tonal" color="purple" rounded="lg" class="text-none" prepend-icon="mdi-file-document-plus"
               to="/ims/purchase-orders/rfqs/new">New RFQ</v-btn>
      </template>
    </ProcToolbar>

    <v-alert v-if="error" type="error" variant="tonal" rounded="lg" class="mb-4">{{ error }}</v-alert>

    <!-- Health banner -->
    <v-alert :color="health.color" variant="tonal" rounded="lg" border="start" prominent class="mb-4">
      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center">
          <v-icon size="30" class="mr-3">{{ health.icon }}</v-icon>
          <div>
            <div class="text-subtitle-1 font-weight-bold">{{ health.headline }}</div>
            <div class="text-body-2">{{ health.detail }}</div>
          </div>
        </div>
        <div class="d-flex align-center ga-2">
          <v-chip variant="flat" :color="health.color" class="font-weight-bold">{{ health.score }}/100</v-chip>
          <v-btn variant="text" class="text-none" append-icon="mdi-arrow-right" to="/ims/purchase-orders/spend">
            Spend analytics
          </v-btn>
        </div>
      </div>
    </v-alert>

    <!-- Horizon: committed / open / pipeline -->
    <v-row dense>
      <v-col cols="12" sm="6" md="3" xl="2">
        <KpiTile
          title="Committed spend"
          :value="formatMoney(totalSpend)"
          :value-num="totalSpend"
          icon="mdi-cash-multiple"
          color="primary"
          :delta="spendDelta"
          delta-label="vs last month"
          :spark="monthlySpendValues"
          :hint="`${committedOrders.length} committed orders`"
        />
      </v-col>
      <v-col cols="12" sm="6" md="3" xl="2">
        <KpiTile
          title="Open commitment"
          :value="formatMoney(committedSpend)"
          :value-num="committedSpend"
          icon="mdi-clock-fast"
          color="info"
          :hint="`${openOrders.length} orders in flight`"
        />
      </v-col>
      <v-col cols="12" sm="6" md="3" xl="2">
        <KpiTile
          title="Savings pipeline"
          :value="formatMoney(identifiedSavings)"
          :value-num="identifiedSavings"
          icon="mdi-piggy-bank-outline"
          color="success"
          :hint="`${awardedRfqs.length} awarded RFQs`"
        />
      </v-col>
      <v-col cols="12" sm="6" md="3" xl="2">
        <KpiTile
          title="Price opportunity"
          :value="formatMoney(priceSavingOpportunity)"
          :value-num="priceSavingOpportunity"
          icon="mdi-tag-search-outline"
          color="teal"
          :hint="`${multiSourced.length} dual-sourced items`"
        />
      </v-col>
      <v-col cols="12" sm="6" md="3" xl="2">
        <KpiTile
          title="Overdue deliveries"
          :value="String(overdueOrders.length)"
          :value-num="overdueOrders.length"
          icon="mdi-truck-alert"
          color="error"
          invert-delta
          :hint="`${formatMoney(overdueValue)} at risk`"
        />
      </v-col>
      <v-col cols="12" sm="6" md="3" xl="2">
        <KpiTile
          title="Awaiting approval"
          :value="String(approvalQueue.length)"
          :value-num="approvalQueue.length"
          icon="mdi-clipboard-check-outline"
          color="warning"
          invert-delta
          :hint="`${formatMoney(approvalValue)} pending`"
        />
      </v-col>
    </v-row>

    <!-- Spend trend + supplier concentration -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <BiPanel title="Spend trend" subtitle="Committed purchase value over the trailing twelve months" icon="mdi-chart-areaspline" color="indigo">
          <template #actions>
            <v-btn-toggle v-model="trendMode" density="compact" variant="outlined" color="indigo" rounded="lg" mandatory>
              <v-btn value="spend" size="small" class="text-none">Spend</v-btn>
              <v-btn value="orders" size="small" class="text-none">Orders</v-btn>
            </v-btn-toggle>
          </template>
          <BarChart
            :values="trendValues"
            :labels="monthlySpendLabels"
            :colors="monthlySpendLabels.map(() => '#6366f1')"
            :height="270"
            show-values
            :y-formatter="compactNumber"
          />
          <v-divider class="my-3" />
          <v-row dense>
            <v-col v-for="m in trendMetrics" :key="m.label" cols="6" md="3">
              <div class="text-caption text-medium-emphasis">{{ m.label }}</div>
              <div class="text-subtitle-2 font-weight-bold">{{ m.value }}</div>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="4">
        <BiPanel title="Sourcing risk" subtitle="Supply concentration and delivery reliability" icon="mdi-shield-alert-outline" color="deep-orange">
          <div class="d-flex justify-center mb-3">
            <v-progress-circular
              :model-value="supplyRiskIndex"
              :color="riskColor"
              :size="150"
              :width="14"
            >
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ supplyRiskIndex }}</div>
                <div class="text-caption text-medium-emphasis">risk index</div>
              </div>
            </v-progress-circular>
          </div>
          <div v-for="r in riskFactors" :key="r.label" class="mb-2">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span>{{ r.label }}</span>
              <span class="font-weight-medium" :class="r.tone">{{ r.value }}</span>
            </div>
            <v-progress-linear :model-value="r.pct" :color="r.color" height="6" rounded />
          </div>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Delivery + exceptions -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Delivery performance" subtitle="On-time, in-full and lead-time reliability" icon="mdi-truck-delivery-outline" color="teal">
          <v-row dense>
            <v-col v-for="d in deliveryMetrics" :key="d.label" cols="6">
              <v-card rounded="lg" class="pa-3 h-100" variant="tonal" :color="d.color">
                <div class="text-caption font-weight-medium">{{ d.label }}</div>
                <div class="text-h6 font-weight-bold">{{ d.value }}</div>
                <div class="text-caption">{{ d.hint }}</div>
              </v-card>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-1">Receipts per month</div>
          <SparkArea :values="grnMonthly.map((g) => g.receipts)" :labels="grnMonthly.map((g) => g.label)" :height="150" color="#0d9488" />
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Exceptions requiring action" subtitle="Ranked by financial and service impact" icon="mdi-alert-decagram-outline" color="red">
          <template #actions>
            <v-chip size="small" color="error" variant="tonal">{{ alerts.length }}</v-chip>
          </template>
          <EmptyState v-if="!alerts.length" icon="mdi-check-decagram" title="No exceptions" message="All procurement activity is within tolerance." />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(a, i) in alerts.slice(0, 7)" :key="i" class="px-0 align-start" :to="a.to">
              <template #prepend>
                <v-avatar size="32" :color="severityColor(a.severity)" variant="tonal">
                  <v-icon size="16">{{ a.icon }}</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ a.title }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ a.detail }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="severityColor(a.severity)" variant="tonal">{{ a.severity }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Pipeline stages -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Procure-to-pay pipeline" subtitle="Value and count at each stage of the cycle" icon="mdi-transit-connection-variant" color="purple">
          <v-row dense>
            <v-col v-for="stage in pipeline" :key="stage.label" cols="6" md="4" lg="2">
              <v-card rounded="lg" class="pa-3 h-100 pipeline-card" :class="`stage-${stage.key}`" @click="navigateTo(stage.to)">
                <div class="d-flex align-center mb-2">
                  <v-avatar size="30" :color="stage.color" variant="tonal" class="mr-2">
                    <v-icon size="16">{{ stage.icon }}</v-icon>
                  </v-avatar>
                  <span class="text-caption font-weight-medium text-uppercase" style="letter-spacing: .6px">{{ stage.label }}</span>
                </div>
                <div class="text-h6 font-weight-bold">{{ stage.count }}</div>
                <div class="text-caption text-medium-emphasis">{{ formatMoney(stage.value) }}</div>
                <v-progress-linear :model-value="stage.pct" :color="stage.color" height="4" rounded class="mt-2" />
              </v-card>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Suppliers + price benchmarking -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel title="Supplier scoreboard" subtitle="Spend, reliability and composite score" icon="mdi-truck-check-outline" color="teal">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" to="/ims/purchase-orders/scorecards">
              Scorecards
            </v-btn>
          </template>
          <EmptyState v-if="!supplierRows.length" icon="mdi-truck-off-outline" title="No supplier activity" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Supplier</th>
                <th class="text-right">Spend</th>
                <th class="text-right">Share</th>
                <th class="text-right">On-time</th>
                <th class="text-right">Fill rate</th>
                <th class="text-right">Score</th>
                <th class="text-center">Risk</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in supplierRows.slice(0, 10)" :key="s.name">
                <td class="font-weight-medium text-truncate" style="max-width: 190px">{{ s.name }}</td>
                <td class="text-right">{{ formatMoney(s.spend) }}</td>
                <td class="text-right">{{ s.share.toFixed(1) }}%</td>
                <td class="text-right">{{ s.onTimeRate == null ? '—' : `${s.onTimeRate.toFixed(0)}%` }}</td>
                <td class="text-right">{{ s.avgFillRate == null ? '—' : `${s.avgFillRate.toFixed(0)}%` }}</td>
                <td class="text-right font-weight-bold">{{ s.score == null ? '—' : s.score }}</td>
                <td class="text-center">
                  <v-chip size="x-small" :color="severityColor(s.risk)" variant="tonal">{{ s.risk }}</v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <BiPanel title="Best-price opportunities" subtitle="Items sourced from several suppliers" icon="mdi-tag-search-outline" color="amber">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" to="/ims/purchase-orders/price-agreements">
              All prices
            </v-btn>
          </template>
          <EmptyState v-if="!multiSourced.length" icon="mdi-tag-off-outline" title="No dual sourcing"
                      message="Add the same item to more than one supplier price list to unlock benchmarking." />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="p in multiSourced.slice(0, 7)" :key="p.item" class="px-0">
              <v-list-item-title class="text-body-2 font-weight-medium text-truncate">{{ p.item }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                Best {{ formatMoney(p.best) }} · {{ p.bestSupplier }} · {{ p.supplierCount }} suppliers
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" color="success" variant="tonal">save {{ formatMoney(p.savingPerUnit) }}/u</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Open orders + requisitions -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel title="Open orders in flight" subtitle="Awaiting delivery, with days remaining" icon="mdi-truck-fast-outline" color="blue">
          <EmptyState v-if="!openOrders.length" icon="mdi-truck-check-outline" title="Nothing outstanding" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>PO</th><th>Supplier</th><th class="text-right">Value</th>
                <th class="text-right">Expected</th><th class="text-right">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="o in openOrders.slice(0, 8)" :key="o.id">
                <td class="font-weight-medium text-primary" style="cursor:pointer" @click="navigateTo(`/ims/purchase-orders/${o.id}`)">
                  {{ o.po_number }}
                </td>
                <td class="text-truncate" style="max-width: 170px">{{ o.supplier_name || '—' }}</td>
                <td class="text-right">{{ formatMoney(o.landedCost) }}</td>
                <td class="text-right">
                  <span v-if="o.overdue" class="text-error font-weight-medium">{{ o.overdueDays }}d late</span>
                  <span v-else-if="o.daysToDelivery != null">{{ o.daysToDelivery }}d</span>
                  <span v-else class="text-medium-emphasis">—</span>
                </td>
                <td class="text-right"><StatusChip :status="o.status" /></td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <BiPanel title="Demand signals" subtitle="Requisitions raised from stock cover" icon="mdi-cart-arrow-down" color="orange">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" to="/ims/purchase-orders/requisitions">
              Requisitions
            </v-btn>
          </template>
          <v-row dense class="mb-2">
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Pending requisitions</div>
              <div class="text-h6 font-weight-bold">{{ pendingRequisitions.length }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Estimated value</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(requisitionValue) }}</div>
            </v-col>
          </v-row>
          <EmptyState v-if="!pendingRequisitions.length" icon="mdi-check-circle" title="All items covered" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="r in pendingRequisitions.slice(0, 6)" :key="r.id" class="px-0">
              <v-list-item-title class="text-body-2 text-truncate">{{ r.itemName }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                On hand {{ num(r.current_quantity) }} · reorder at {{ num(r.reorder_level) }}
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="urgencyColor(r.urgency)" variant="tonal">+{{ Math.round(r.qty) }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum, compactNumber, mean } from '~/utils/bi'

const {
  loading, error, lastLoaded,
  branchFilter, branchFilterItems, isBranchLocked,
  totalSpend, committedSpend, monthlySpendValues, monthlySpendLabels, spendDelta,
  committedOrders, openOrders, overdueOrders, approvalQueue, receivedOrders,
  identifiedSavings, awardedRfqs, priceSavingOpportunity, multiSourced, openRfqs,
  supplierRows, hhi, supplyRiskIndex, onTimeRate, otifRate, fillRate,
  avgLeadTime, medianLeadTime, leadTimeSpread, cycleTime,
  grnMonthly, alerts, pendingRequisitions, requisitionValue, monthlySpend,
  avgOrderValue, shippingShare, returnableOrders,
  statusMeta, load
} = useProcurement()

const trendMode = ref('spend')

const stamp = computed(() =>
  lastLoaded.value ? `Updated ${lastLoaded.value.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })}` : ''
)

const overdueValue = computed(() => sum(overdueOrders.value, (o) => o.landedCost))
const approvalValue = computed(() => sum(approvalQueue.value, (o) => o.landedCost))

const trendValues = computed(() =>
  trendMode.value === 'spend' ? monthlySpendValues.value : monthlySpend.value.map((b) => b.orders)
)

const trendMetrics = computed(() => [
  { label: 'Total (12m)', value: formatMoney(sum(monthlySpendValues.value)) },
  { label: 'Average order', value: formatMoney(avgOrderValue.value) },
  { label: 'Best month', value: formatMoney(Math.max(0, ...monthlySpendValues.value)) },
  { label: 'Freight share', value: `${shippingShare.value.toFixed(1)}%` }
])

// ── health verdict ───────────────────────────────────────────────────────
const healthScore = computed(() => {
  let score = 100
  if (onTimeRate.value) score -= Math.max(0, (95 - onTimeRate.value) * 1.6)
  if (fillRate.value) score -= Math.max(0, (98 - fillRate.value) * 1.4)
  score -= Math.min(20, overdueOrders.value.length * 2.5)
  score -= supplyRiskIndex.value * 0.2
  return Math.max(0, Math.round(score))
})

const health = computed(() => {
  const s = healthScore.value
  const color = s >= 80 ? 'success' : s >= 60 ? 'warning' : 'error'
  const icon = s >= 80 ? 'mdi-check-decagram' : s >= 60 ? 'mdi-alert-outline' : 'mdi-alert-decagram'
  const label = s >= 80 ? 'Healthy' : s >= 60 ? 'Needs attention' : 'At risk'
  return {
    color,
    icon,
    score: s,
    headline: `Procurement is ${label.toLowerCase()}`,
    detail: `${formatMoney(totalSpend.value)} committed · ${onTimeRate.value.toFixed(0)}% on-time · ${overdueOrders.value.length} overdue · ${approvalQueue.value.length} awaiting approval`
  }
})

const riskColor = computed(() => (supplyRiskIndex.value >= 60 ? 'error' : supplyRiskIndex.value >= 35 ? 'warning' : 'success'))

const riskFactors = computed(() => [
  {
    label: 'Supplier concentration (HHI)',
    value: Math.round(hhi.value),
    pct: Math.min(100, (hhi.value / 5000) * 100),
    color: hhi.value > 2500 ? 'error' : hhi.value > 1500 ? 'warning' : 'success',
    tone: hhi.value > 2500 ? 'text-error' : hhi.value > 1500 ? 'text-warning' : 'text-success'
  },
  {
    label: 'On-time delivery',
    value: `${onTimeRate.value.toFixed(0)}%`,
    pct: onTimeRate.value,
    color: onTimeRate.value >= 90 ? 'success' : onTimeRate.value >= 80 ? 'warning' : 'error',
    tone: onTimeRate.value >= 90 ? 'text-success' : 'text-error'
  },
  {
    label: 'Order fill rate',
    value: `${fillRate.value.toFixed(0)}%`,
    pct: Math.min(100, fillRate.value),
    color: fillRate.value >= 95 ? 'success' : fillRate.value >= 88 ? 'warning' : 'error',
    tone: fillRate.value >= 95 ? 'text-success' : 'text-warning'
  },
  {
    label: 'Dual-sourced catalogue',
    value: `${multiSourced.value.length} items`,
    pct: Math.min(100, (multiSourced.value.length / Math.max(1, multiSourced.value.length + 5)) * 100),
    color: multiSourced.value.length ? 'success' : 'warning',
    tone: multiSourced.value.length ? 'text-success' : 'text-warning'
  }
])

const deliveryMetrics = computed(() => [
  { label: 'On-time delivery', value: `${onTimeRate.value.toFixed(0)}%`, hint: 'Received by promise date', color: onTimeRate.value >= 90 ? 'success' : 'warning' },
  { label: 'OTIF', value: `${otifRate.value.toFixed(0)}%`, hint: 'On time and in full', color: otifRate.value >= 85 ? 'success' : 'warning' },
  { label: 'Average lead time', value: `${avgLeadTime.value.toFixed(0)}d`, hint: `Median ${medianLeadTime.value.toFixed(0)}d · σ ${leadTimeSpread.value.toFixed(1)}d`, color: 'info' },
  { label: 'Procurement cycle', value: cycleTime.value ? `${cycleTime.value.toFixed(0)}d` : '—', hint: 'RFQ to award', color: 'purple' }
])

// ── pipeline ─────────────────────────────────────────────────────────────
const pipeline = computed(() => {
  const stages = [
    { key: 'requisition', label: 'Requisition', icon: 'mdi-clipboard-list-outline', color: 'orange', count: pendingRequisitions.value.length, value: requisitionValue.value, to: '/ims/purchase-orders/requisitions' },
    { key: 'rfq', label: 'Sourcing (RFQ)', icon: 'mdi-file-document-multiple-outline', color: 'purple', count: openRfqs.value.length, value: sum(openRfqs.value, (r) => (r.quoteCount ? Math.min(...r.quotes.map((q) => num(q.total_cost)).filter((v) => v > 0)) : 0) || 0), to: '/ims/purchase-orders/rfqs' },
    { key: 'approval', label: 'Approval', icon: 'mdi-clipboard-check-outline', color: 'warning', count: approvalQueue.value.length, value: approvalValue.value, to: '/ims/purchase-orders/approvals' },
    { key: 'order', label: 'Order (open)', icon: 'mdi-cart-outline', color: 'info', count: openOrders.value.length, value: committedSpend.value, to: '/ims/purchase-orders' },
    { key: 'received', label: 'Received', icon: 'mdi-package-check', color: 'success', count: receivedOrders.value.length, value: totalSpend.value, to: '/ims/purchase-orders/grns' },
    { key: 'returns', label: 'Returns', icon: 'mdi-undo-variant', color: 'deep-orange', count: returnableOrders.value.length, value: sum(returnableOrders.value, (o) => o.landedCost), to: '/ims/purchase-orders/returns' }
  ]
  const max = Math.max(...stages.map((s) => s.count), 1)
  return stages.map((s) => ({ ...s, pct: (s.count / max) * 100 }))
})

function severityColor(s) {
  return s === 'high' ? 'error' : s === 'medium' ? 'warning' : s === 'low' ? 'success' : 'grey'
}
function urgencyColor(u) {
  return u === 'critical' ? 'error' : u === 'high' ? 'warning' : 'info'
}
</script>

<style scoped>
.pipeline-card {
  cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease;
}
.pipeline-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.09);
}
</style>
