<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Business Intelligence"
      subtitle="Executive overview · KPIs, performance drivers and prescriptive actions"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-brain"
      color="teal"
      :range-key="rangeKey"
      :range-options="BI_RANGE_OPTIONS"
      :range-label="rangeLabel"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      :loading="loading"
      :target="monthlyTarget"
      :custom-dialog="customDialog"
      :custom-start="customStart"
      :custom-end="customEnd"
      @update:range-key="onRangeChange"
      @update:branch-filter="(v) => (branchFilter = v)"
      @update:target="setMonthlyTarget"
      @update:custom-dialog="(v) => (customDialog = v)"
      @update:custom-start="(v) => (customStart = v)"
      @update:custom-end="(v) => (customEnd = v)"
      @refresh="load"
      @apply-custom="applyCustom"
    >
      <template #actions>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-chart-timeline-variant"
               :to="`${biBase}/forecast`">Forecast</v-btn>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-file-chart"
               :to="`${biBase}/reports`">Reports</v-btn>
      </template>
    </BiToolbar>

    <!-- ── Monthly sales vs target banner (the classic BI headline) ─────── -->
    <v-alert
      v-if="targetGap"
      :color="gapAlert.color"
      variant="tonal"
      rounded="lg"
      class="mb-4"
      border="start"
      prominent
    >
      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center">
          <v-icon size="28" class="mr-3">{{ gapAlert.icon }}</v-icon>
          <div>
            <div class="text-subtitle-1 font-weight-bold">{{ gapAlert.headline }}</div>
            <div class="text-body-2">{{ gapAlert.detail }}</div>
          </div>
        </div>
        <div class="d-flex align-center ga-2">
          <v-chip variant="flat" :color="gapAlert.color" class="font-weight-bold">
            {{ gapAlert.gapText }}
          </v-chip>
          <v-btn variant="text" class="text-none" append-icon="mdi-arrow-right" :to="`${biBase}/root-cause`">Root cause</v-btn>
        </div>
      </div>
    </v-alert>

    <!-- ── KPI scorecard ────────────────────────────────────────────────── -->
    <div class="text-subtitle-2 font-weight-bold text-uppercase mb-2" style="letter-spacing: 1px">Key performance indicators</div>
    <v-row dense>
      <v-col v-for="k in kpiTiles" :key="k.title" cols="12" sm="6" md="3" xl="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- ── Past / present / future timeline ─────────────────────────────── -->
    <div class="text-subtitle-2 font-weight-bold text-uppercase mt-5 mb-2" style="letter-spacing: 1px">
      Past · present · future
    </div>
    <v-row dense>
      <v-col v-for="p in horizonCards" :key="p.title" cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100 bi-horizon" border>
          <div class="d-flex align-center mb-2">
            <v-avatar size="34" :color="p.color" variant="tonal" class="mr-2">
              <v-icon size="18">{{ p.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase" style="letter-spacing: .8px">{{ p.when }}</div>
              <div class="text-subtitle-2 font-weight-bold">{{ p.title }}</div>
            </div>
          </div>
          <div class="text-h6 font-weight-bold" :class="p.tone">{{ p.value }}</div>
          <div class="text-caption text-medium-emphasis mb-2">{{ p.caption }}</div>
          <ul class="bi-ul">
            <li v-for="(l, i) in p.points" :key="i">{{ l }}</li>
          </ul>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Revenue trend + forecast ─────────────────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <BiPanel
          title="Revenue trajectory"
          :subtitle="`Trailing 12 months actuals with ${forecastHorizon}-period projection · ${rangeLabel}`"
          icon="mdi-chart-timeline-variant-shimmer"
          color="teal"
        >
          <template #actions>
            <v-btn-toggle v-model="trendMode" density="compact" variant="outlined" color="teal" rounded="lg" mandatory>
              <v-btn value="value" size="small" class="text-none">Value</v-btn>
              <v-btn value="orders" size="small" class="text-none">Orders</v-btn>
            </v-btn-toggle>
          </template>
          <LineChart :series="trajectorySeries" :labels="trajectoryLabels" :height="280" :y-formatter="trajectoryFormatter" />
          <div class="d-flex flex-wrap ga-4 mt-3">
            <div v-for="s in trajectorySeries" :key="s.label" class="d-flex align-center">
              <span class="legend-dot" :style="{ background: s.color }" />
              <span class="text-caption ml-2">{{ s.label }}</span>
            </div>
          </div>
          <v-divider class="my-3" />
          <v-row dense>
            <v-col v-for="m in forecastMetrics" :key="m.label" cols="6" md="3">
              <div class="text-caption text-medium-emphasis">{{ m.label }}</div>
              <div class="text-subtitle-2 font-weight-bold">{{ m.value }}</div>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="4">
        <InsightNarrative
          title="Automated insight"
          subtitle="Descriptive and diagnostic narrative"
          :tone="narrativeTone"
          :headline="narrativeHeadline"
          :points="narrativePoints"
          :loading="loading"
          footer="Insights are recomputed from live POS, stock and procurement data every time the filters change."
        />
      </v-col>
    </v-row>

    <!-- ── What happened (descriptive) ──────────────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="What happened" subtitle="Actuals vs the previous comparable period" icon="mdi-history" color="blue">
          <v-table density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Measure</th>
                <th class="text-right">Current</th>
                <th class="text-right">Previous</th>
                <th class="text-right">Change</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in whatsHappened" :key="row.label">
                <td class="font-weight-medium">{{ row.label }}</td>
                <td class="text-right">{{ row.current }}</td>
                <td class="text-right text-medium-emphasis">{{ row.previous }}</td>
                <td class="text-right">
                  <v-chip v-if="row.delta != null" size="x-small" :color="row.good ? 'success' : 'error'" variant="tonal">
                    <v-icon start size="12">{{ row.up ? 'mdi-arrow-up' : 'mdi-arrow-down' }}</v-icon>{{ Math.abs(row.delta).toFixed(1) }}%
                  </v-chip>
                  <span v-else class="text-medium-emphasis">—</span>
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="What is happening" subtitle="Live operational pulse right now" icon="mdi-access-point" color="green">
          <v-row dense>
            <v-col v-for="s in livePulse" :key="s.label" cols="6">
              <div class="d-flex align-center mb-1">
                <v-avatar size="30" :color="s.color" variant="tonal" class="mr-2">
                  <v-icon size="16">{{ s.icon }}</v-icon>
                </v-avatar>
                <span class="text-caption text-medium-emphasis">{{ s.label }}</span>
              </div>
              <div class="text-subtitle-1 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.hint }}</div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-1">Hour-of-day demand</div>
          <HourHeatmap :counts="hourCounts" unit="sales" color="#0d9488" />
        </BiPanel>
      </v-col>
    </v-row>

    <!-- ── Why it happened (drivers) ────────────────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel title="Why it happened" subtitle="Contribution of each category to the period-over-period movement" icon="mdi-magnify-scan" color="deep-purple">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" :to="`${biBase}/root-cause`">Full analysis</v-btn>
          </template>
          <EmptyState v-if="!drivers.length" icon="mdi-chart-waterfall" title="Not enough movement to attribute" />
          <template v-else>
            <div v-for="d in drivers.slice(0, 8)" :key="d.label" class="mb-3">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span class="text-truncate" style="max-width: 60%">{{ d.label }}</span>
                <span :class="d.impact >= 0 ? 'text-success' : 'text-error'" class="font-weight-medium">
                  {{ d.impact >= 0 ? '+' : '' }}{{ formatMoney(d.impact) }}
                </span>
              </div>
              <v-progress-linear
                :model-value="Math.min(Math.abs(d.weight), 100)"
                :color="d.impact >= 0 ? 'success' : 'error'"
                height="7"
                rounded
              />
            </div>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <BiPanel title="Recommended actions" subtitle="Prescriptive next steps ranked by impact" icon="mdi-lightbulb-on-outline" color="amber">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" :to="`${biBase}/optimization`">Optimiser</v-btn>
          </template>
          <EmptyState v-if="!recommendations.length" icon="mdi-check-decagram" title="No actions required" message="Operations are within tolerance." />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="r in recommendations" :key="r.title" class="px-0 align-start">
              <template #prepend>
                <v-avatar size="32" :color="r.color" variant="tonal">
                  <v-icon size="16">{{ r.icon }}</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ r.title }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ r.detail }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="r.color" variant="tonal" class="font-weight-bold">{{ r.impact }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- ── Portfolio: category, branch, product ─────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12" lg="5">
        <BiPanel title="Revenue by category" subtitle="Distribution over the selected period" icon="mdi-shape" color="indigo">
          <EmptyState v-if="!categorySegments.length" icon="mdi-tag-multiple" title="No category data" />
          <div v-else class="d-flex flex-column align-center">
            <DonutRing :segments="categorySegments" :size="230">
              <div class="text-center">
                <div class="text-caption text-medium-emphasis">Total</div>
                <div class="text-subtitle-1 font-weight-bold">{{ formatMoney(categoryTotal) }}</div>
              </div>
            </DonutRing>
            <div class="mt-3 w-100">
              <div v-for="s in categorySegments" :key="s.label" class="d-flex align-center mb-1">
                <span class="legend-dot" :style="{ background: s.color }" />
                <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ formatMoney(s.value) }}</span>
                <span class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
              </div>
            </div>
          </div>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="7">
        <BiPanel title="Branch performance" subtitle="Revenue comparison across locations" icon="mdi-store-marker-outline" color="cyan">
          <EmptyState v-if="!branches.length" icon="mdi-store-off" title="No branch data" />
          <template v-else>
            <BarChart
              :values="branches.map((b) => b.value)"
              :labels="branches.map((b) => b.name)"
              :colors="branches.map((_, i) => palette[i % palette.length])"
              :height="260"
              rotate-labels
              show-values
              :y-formatter="compactMoney"
            />
            <v-divider class="my-3" />
            <div class="text-caption text-medium-emphasis mb-2">Share of total revenue</div>
            <div v-for="b in branches.slice(0, 6)" :key="b.name" class="mb-2">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span class="text-truncate" style="max-width: 60%">{{ b.name }}</span>
                <span>{{ formatMoney(b.value) }}</span>
              </div>
              <v-progress-linear :model-value="branchShare(b.value)" color="cyan" height="6" rounded />
            </div>
          </template>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- ── ABC portfolio + cross-sell ───────────────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="ABC portfolio concentration" subtitle="Pareto view of revenue contribution" icon="mdi-sort-alphabetical-variant" color="purple">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" :to="`${biBase}/dashboards`">Widgets</v-btn>
          </template>
          <EmptyState v-if="!abcSummary.length" icon="mdi-package-variant-closed" title="No product data" />
          <template v-else>
            <v-row dense>
              <v-col v-for="s in abcSummary" :key="s.class" cols="4">
                <v-card rounded="lg" class="pa-3 text-center" variant="tonal" :color="abcColor(s.class)">
                  <div class="text-h6 font-weight-bold">{{ s.class }}</div>
                  <div class="text-caption">{{ s.count }} SKUs</div>
                  <div class="text-body-2 font-weight-medium">{{ Math.round(s.share) }}% of value</div>
                </v-card>
              </v-col>
            </v-row>
            <v-divider class="my-3" />
            <v-table density="compact" class="bg-transparent">
              <thead>
                <tr>
                  <th>Product</th><th class="text-center">ABC</th><th class="text-center">XYZ</th>
                  <th class="text-right">Revenue</th><th class="text-right">Margin</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="p in products.slice(0, 8)" :key="p.name">
                  <td class="text-truncate font-weight-medium" style="max-width: 200px">{{ p.name }}</td>
                  <td class="text-center"><v-chip size="x-small" :color="abcColor(p.abc)" variant="tonal">{{ p.abc }}</v-chip></td>
                  <td class="text-center"><v-chip size="x-small" :color="xyzColor(p.xyz)" variant="tonal">{{ p.xyz }}</v-chip></td>
                  <td class="text-right">{{ formatMoney(p.revenue) }}</td>
                  <td class="text-right">{{ p.marginPct.toFixed(1) }}%</td>
                </tr>
              </tbody>
            </v-table>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Cross-sell opportunities" subtitle="Market-basket association rules from POS baskets" icon="mdi-vector-combine" color="teal">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" :to="`${biBase}/models`">Models</v-btn>
          </template>
          <EmptyState v-if="!basket.length" icon="mdi-basket-outline" title="Not enough baskets yet" message="Association rules appear once customers buy more than one item together." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>If a customer buys</th><th>They also buy</th>
                <th class="text-right">Confidence</th><th class="text-right">Lift</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in basket.slice(0, 8)" :key="i">
                <td class="text-truncate" style="max-width: 170px">{{ r.a }}</td>
                <td class="text-truncate font-weight-medium" style="max-width: 170px">{{ r.b }}</td>
                <td class="text-right">{{ (r.confidence * 100).toFixed(0) }}%</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="r.lift >= 1.5 ? 'success' : 'grey'" variant="tonal">{{ r.lift.toFixed(2) }}x</v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- ── Inventory health / risk ──────────────────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12" md="4">
        <BiPanel title="Inventory health" subtitle="Valuation and coverage" icon="mdi-package-variant" color="teal">
          <div class="text-caption text-medium-emphasis">Stock value at cost</div>
          <div class="text-h5 font-weight-bold text-teal mb-2">{{ formatMoney(inventoryCost) }}</div>
          <div class="d-flex justify-space-between text-body-2 mb-1">
            <span class="text-medium-emphasis">Retail value</span>
            <span class="font-weight-medium">{{ formatMoney(inventoryRetail) }}</span>
          </div>
          <div class="d-flex justify-space-between text-body-2 mb-1">
            <span class="text-medium-emphasis">Unrealised margin</span>
            <span class="font-weight-medium text-success">{{ formatMoney(inventoryRetail - inventoryCost) }}</span>
          </div>
          <div class="d-flex justify-space-between text-body-2 mb-1">
            <span class="text-medium-emphasis">Units on hand</span>
            <span class="font-weight-medium">{{ unitsOnHand.toLocaleString() }}</span>
          </div>
          <div class="d-flex justify-space-between text-body-2">
            <span class="text-medium-emphasis">Days of cover</span>
            <span class="font-weight-medium">{{ daysOfCover }}</span>
          </div>
        </BiPanel>
      </v-col>

      <v-col cols="12" md="4">
        <BiPanel title="Stockout and reorder risk" subtitle="Items at or below reorder level" icon="mdi-bell-alert" color="orange">
          <template #actions>
            <v-chip size="small" color="warning" variant="tonal">{{ lowStock.length }}</v-chip>
          </template>
          <EmptyState v-if="!lowStock.length" icon="mdi-check-circle" title="All stocked" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="s in lowStock.slice(0, 7)" :key="s.id" class="px-0">
              <v-list-item-title class="text-body-2 text-truncate">{{ s.medication_name || s.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">Reorder at {{ s.reorder_level }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="Number(s.total_quantity ?? s.quantity) <= 0 ? 'error' : 'warning'" variant="tonal">
                  {{ s.total_quantity ?? s.quantity ?? 0 }}
                </v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>

      <v-col cols="12" md="4">
        <BiPanel title="Expiry risk" subtitle="Batches expiring within 90 days" icon="mdi-calendar-alert" color="red">
          <template #actions>
            <v-chip size="small" color="error" variant="tonal">{{ expiring.length }}</v-chip>
          </template>
          <EmptyState v-if="!expiring.length" icon="mdi-check-circle" title="No items expiring" />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="s in expiring.slice(0, 7)" :key="s.id" class="px-0">
              <v-list-item-title class="text-body-2 text-truncate">{{ s.medication_name || s.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">Expires {{ formatDate(s.expiry_date) }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" color="error" variant="tonal">{{ daysUntil(s.expiry_date) }}d</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- ── Customer intelligence ────────────────────────────────────────── -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Customer intelligence" subtitle="RFM segmentation across the selected period" icon="mdi-account-group-outline" color="deep-purple">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" :to="`${biBase}/models`">Segmentation model</v-btn>
          </template>
          <EmptyState v-if="!rfm.summary.length" icon="mdi-account-off-outline" title="No named customers yet" />
          <v-row v-else dense>
            <v-col v-for="s in rfm.summary.slice(0, 6)" :key="s.segment" cols="6" md="4" lg="2">
              <v-card rounded="lg" class="pa-3 h-100" variant="tonal" color="deep-purple">
                <div class="text-caption font-weight-medium">{{ s.segment }}</div>
                <div class="text-h6 font-weight-bold">{{ s.customers }}</div>
                <div class="text-caption">{{ formatMoney(s.revenue) }}</div>
                <div class="text-caption text-medium-emphasis">avg {{ formatMoney(s.avgSpend) }}</div>
              </v-card>
            </v-col>
          </v-row>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import { BI_PALETTE, num, sum, pctChange, abcClass, trendForecast } from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, rangeDays, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  transactions, stocks, overview,
  revenue, prevRevenue, revenueDelta, orders, prevOrders, ordersDelta,
  aov, aovDelta, unitsSold, customers, inRange, inPrevRange,
  inventoryCost, inventoryRetail, unitsOnHand, lowStock, expiring, daysUntil,
  grossMargin, historyMonthly, historyValues, historyLabels, forecast,
  products, categories, branches, hourCounts, rfm, basket, drivers,
  biBase
} = useBiData({ defaultRange: '12m' })

const palette = BI_PALETTE
const trendMode = ref('value')
const forecastHorizon = 3

function compactMoney(v) {
  const n = num(v)
  if (Math.abs(n) >= 1e6) return `${(n / 1e6).toFixed(1)}M`
  if (Math.abs(n) >= 1e3) return `${(n / 1e3).toFixed(0)}K`
  return String(Math.round(n))
}

// ── target gap (the "monthly sales fell 8% vs target" headline) ──────────
const lastMonth = computed(() => historyMonthly.value[historyMonthly.value.length - 1] || { value: 0, label: 'This month' })
const prevMonth = computed(() => historyMonthly.value[historyMonthly.value.length - 2] || { value: 0 })

const derivedTarget = computed(() => {
  const last3 = historyValues.value.slice(-3)
  const avg = last3.length ? sum(last3) / last3.length : 0
  return Math.round(avg * 1.08)
})
const effectiveTarget = computed(() => monthlyTarget.value || derivedTarget.value)

const targetGap = computed(() => {
  const target = effectiveTarget.value
  if (!target) return null
  const actual = lastMonth.value.value
  const gapPct = pctChange(actual, target)
  if (gapPct == null) return null
  return { actual, target, gapPct, gap: actual - target }
})

// ── discount + stockout explanation for the gap ─────────────────────────
const discountTotal = computed(() => sum(transactions.value, (t) => t.discount ?? t.discount_amount ?? 0))
const stockoutItems = computed(() => lowStock.value.filter((s) => num(s.total_quantity ?? s.quantity) <= 0).length)
const oosFromOverview = computed(() => num(overview.value.out_of_stock))

const gapAlert = computed(() => {
  const g = targetGap.value
  if (!g) return { color: 'info', icon: 'mdi-information', headline: '', detail: '', gapText: '' }
  const missed = g.gapPct < 0
  const reasons = []
  if (discountTotal.value > 0) reasons.push('discounting')
  if (stockoutItems.value + oosFromOverview.value > 0) reasons.push('stockouts')
  if (!reasons.length) reasons.push('volume and mix shifts')
  const reasonText = reasons.length > 1
    ? `${reasons.slice(0, -1).join(', ')} and ${reasons[reasons.length - 1]}`
    : reasons[0]
  return {
    color: missed ? 'error' : 'success',
    icon: missed ? 'mdi-trending-down' : 'mdi-trending-up',
    headline: missed
      ? `${lastMonth.value.label} sales fell ${Math.abs(g.gapPct).toFixed(1)}% versus target`
      : `${lastMonth.value.label} sales beat target by ${Math.abs(g.gapPct).toFixed(1)}%`,
    detail: missed
      ? `${reasonText.charAt(0).toUpperCase()}${reasonText.slice(1)} explain the decline. Forecast the next quarter and review the recommended pricing actions.`
      : `Momentum is ahead of plan. Protect margin by reviewing discount depth and replenishing fast movers.`,
    gapText: `${g.gap >= 0 ? '+' : '-'}${formatMoney(Math.abs(g.gap))}`
  }
})

// ── KPI tiles ────────────────────────────────────────────────────────────
const sparkValues = computed(() => historyValues.value.slice(-12))

const gmoroi = computed(() => {
  const gm = grossMargin.value.margin
  return inventoryCost.value ? gm / inventoryCost.value : 0
})
const sellThrough = computed(() => {
  const available = unitsOnHand.value + unitsSold.value
  return available ? (unitsSold.value / available) * 100 : 0
})
const daysOfCover = computed(() => {
  const dailyUnits = rangeDays.value ? unitsSold.value / rangeDays.value : 0
  return dailyUnits ? Math.round(unitsOnHand.value / dailyUnits) : '—'
})
const stockTurn = computed(() => {
  const annual = rangeDays.value ? (grossMargin.value.cost / rangeDays.value) * 365 : 0
  return inventoryCost.value ? (annual / inventoryCost.value).toFixed(2) : '—'
})
const nextPeriodForecast = computed(() => forecast.value.forecast[0] || 0)

const kpiTiles = computed(() => [
  {
    title: 'Revenue',
    value: formatMoney(revenue.value),
    valueNum: revenue.value,
    icon: 'mdi-cash-multiple',
    color: 'primary',
    delta: revenueDelta.value,
    deltaLabel: `vs prev. ${rangeDays.value}d`,
    spark: sparkValues.value,
    hint: `${orders.value.toLocaleString()} orders · ${rangeLabel.value}`
  },
  {
    title: 'Gross margin',
    value: `${grossMargin.value.marginPct.toFixed(1)}%`,
    icon: 'mdi-percent-circle-outline',
    color: 'teal',
    delta: null,
    spark: sparkValues.value,
    hint: `${formatMoney(grossMargin.value.margin)} gross profit`
  },
  {
    title: 'Avg order value',
    value: formatMoney(aov.value),
    icon: 'mdi-receipt-text-outline',
    color: 'indigo',
    delta: aovDelta.value,
    spark: sparkValues.value,
    hint: 'Basket size per transaction'
  },
  {
    title: 'Units sold',
    value: unitsSold.value.toLocaleString(),
    icon: 'mdi-cube-outline',
    color: 'cyan',
    delta: ordersDelta.value,
    spark: sparkValues.value,
    hint: `${customers.value} named customers`
  },
  {
    title: 'Inventory value',
    value: formatMoney(inventoryCost.value),
    icon: 'mdi-warehouse',
    color: 'deep-purple',
    delta: null,
    hint: `${unitsOnHand.value.toLocaleString()} units · ${stocks.length} SKUs`
  },
  {
    title: 'Stock turns',
    value: stockTurn.value,
    icon: 'mdi-rotate-3d-variant',
    color: 'amber',
    delta: null,
    hint: `Annualised · cover ${daysOfCover.value} days`
  },
  {
    title: 'GMROI',
    value: `${gmoroi.value.toFixed(2)}x`,
    icon: 'mdi-chart-bell-curve',
    color: 'green',
    delta: null,
    hint: 'Gross margin return on inventory'
  },
  {
    title: 'Sell-through',
    value: `${sellThrough.value.toFixed(1)}%`,
    icon: 'mdi-package-check',
    color: 'light-green',
    delta: null,
    hint: 'Units sold vs available'
  },
  {
    title: 'Stockout items',
    value: (stockoutItems.value + oosFromOverview.value).toLocaleString(),
    valueNum: stockoutItems.value + oosFromOverview.value,
    icon: 'mdi-package-variant-remove',
    color: 'error',
    delta: null,
    invertDelta: true,
    hint: `${lowStock.value.length} below reorder point`
  },
  {
    title: 'Expiry exposure',
    value: expiring.value.length.toLocaleString(),
    valueNum: expiring.value.length,
    icon: 'mdi-calendar-alert',
    color: 'orange',
    delta: null,
    invertDelta: true,
    hint: 'Batches expiring within 90 days'
  },
  {
    title: 'Next period forecast',
    value: formatMoney(nextPeriodForecast.value),
    valueNum: nextPeriodForecast.value,
    icon: 'mdi-chart-timeline-variant-shimmer',
    color: 'pink',
    delta: pctChange(nextPeriodForecast.value, lastMonth.value.value),
    spark: forecast.value.forecast,
    hint: `Holt trend · MAPE ${forecast.value.accuracy.mape.toFixed(1)}%`
  },
  {
    title: 'Month vs target',
    value: targetGap.value ? `${Math.abs(targetGap.value.gapPct).toFixed(1)}%` : 'Set target',
    icon: 'mdi-target',
    color: 'purple',
    delta: targetGap.value ? targetGap.value.gapPct : null,
    hint: `Target ${formatMoney(effectiveTarget.value)}`
  }
])

// ── past / present / future ─────────────────────────────────────────────
const horizonCards = computed(() => [
  {
    when: 'Past',
    title: 'Trailing performance',
    icon: 'mdi-history',
    color: 'blue',
    value: formatMoney(prevRevenue.value),
    tone: '',
    caption: `Previous ${rangeDays.value} days`,
    points: [
      `${prevOrders.value.toLocaleString()} orders at ${formatMoney(prevOrders.value ? prevRevenue.value / prevOrders.value : 0)} AOV`,
      `Best month ${bestMonth.value.label} at ${formatMoney(bestMonth.value.value)}`,
      `Weakest month ${worstMonth.value.label} at ${formatMoney(worstMonth.value.value)}`
    ]
  },
  {
    when: 'Present',
    title: 'Current performance',
    icon: 'mdi-access-point',
    color: 'teal',
    value: formatMoney(revenue.value),
    tone: revenueDelta.value != null && revenueDelta.value < 0 ? 'text-error' : 'text-success',
    caption: `${rangeLabel.value} · ${revenueDelta.value == null ? 'no prior data' : `${revenueDelta.value >= 0 ? '+' : ''}${revenueDelta.value.toFixed(1)}% vs prior`}`,
    points: [
      `${orders.value.toLocaleString()} orders · ${customers.value} customers`,
      `Gross margin ${grossMargin.value.marginPct.toFixed(1)}%`,
      `${lowStock.value.length} items need replenishment`
    ]
  },
  {
    when: 'Future',
    title: 'Projected outlook',
    icon: 'mdi-crystal-ball',
    color: 'deep-purple',
    value: formatMoney(sum(forecast.value.forecast)),
    tone: '',
    caption: `Next ${forecastHorizon} periods · ${forecast.value.method} model`,
    points: [
      `Next period ${formatMoney(nextPeriodForecast.value)}`,
      `Forecast accuracy MAPE ${forecast.value.accuracy.mape.toFixed(1)}%`,
      `Confidence band ±${formatMoney(forecast.value.residualStd * 1.96)}`
    ]
  }
])

const bestMonth = computed(() => historyMonthly.value.reduce((a, b) => (num(b.value) > num(a.value) ? b : a), historyMonthly.value[0] || { label: '—', value: 0 }))
const worstMonth = computed(() => historyMonthly.value.reduce((a, b) => (num(b.value) < num(a.value) ? b : a), historyMonthly.value[0] || { label: '—', value: 0 }))

// ── narrative ────────────────────────────────────────────────────────────
const narrativeTone = computed(() => {
  const d = revenueDelta.value
  if (d == null) return 'neutral'
  if (d >= 5) return 'positive'
  if (d >= -2) return 'neutral'
  if (d >= -10) return 'warning'
  return 'negative'
})

const narrativeHeadline = computed(() => {
  const g = targetGap.value
  if (g && g.gapPct < 0) {
    return `Revenue is <b>${Math.abs(g.gapPct).toFixed(1)}% below</b> the ${lastMonth.value.label} target of ${formatMoney(g.target)}.`
  }
  if (revenueDelta.value == null) return 'Insufficient history to compute a trend — keep capturing sales data.'
  return `Revenue moved <b>${revenueDelta.value >= 0 ? '+' : ''}${revenueDelta.value.toFixed(1)}%</b> versus the previous comparable period.`
})

const narrativePoints = computed(() => {
  const pts = []
  const topDriver = drivers.value[0]
  if (topDriver) {
    pts.push(
      topDriver.impact >= 0
        ? `+ <b>${topDriver.label}</b> added ${formatMoney(topDriver.impact)} (${topDriver.weight.toFixed(0)}% of the movement).`
        : `- <b>${topDriver.label}</b> removed ${formatMoney(Math.abs(topDriver.impact))} (${topDriver.weight.toFixed(0)}% of the movement).`
    )
  }
  if (lowStock.value.length) {
    pts.push(`! ${lowStock.value.length} line items are at or below reorder level — stockouts suppress sell-through and revenue.`)
  }
  if (expiring.value.length) {
    pts.push(`! ${expiring.value.length} batches expire within 90 days — consider markdown before write-off.`)
  }
  if (grossMargin.value.marginPct > 0) {
    pts.push(
      grossMargin.value.marginPct >= 25
        ? `+ Gross margin is healthy at ${grossMargin.value.marginPct.toFixed(1)}%.`
        : `- Gross margin at ${grossMargin.value.marginPct.toFixed(1)}% is below the 25% guardrail — review discounting.`
    )
  }
  const nextForecast = nextPeriodForecast.value
  if (nextForecast) {
    pts.push(`+ The ${forecast.value.method} model projects ${formatMoney(nextForecast)} next period (MAPE ${forecast.value.accuracy.mape.toFixed(1)}%).`)
  }
  return pts.slice(0, 6)
})

// ── descriptive table ───────────────────────────────────────────────────
function deltaRow(label, cur, prev, { invert = false, money = true, suffix = '' } = {}) {
  const d = pctChange(cur, prev)
  const up = d != null && d >= 0
  return {
    label,
    current: money ? formatMoney(cur) : `${num(cur).toLocaleString(undefined, { maximumFractionDigits: 2 })}${suffix}`,
    previous: money ? formatMoney(prev) : `${num(prev).toLocaleString(undefined, { maximumFractionDigits: 2 })}${suffix}`,
    delta: d,
    up,
    good: d == null ? true : invert ? !up : up
  }
}

const prevUnitsSold = computed(() => sum(inPrevRange.value.flatMap((t) => t.items || []), (it) => it.quantity || 1))
const prevGrossMarginPct = computed(() => {
  let rev = 0
  let cost = 0
  for (const t of inPrevRange.value) {
    for (const it of t.items || []) {
      const q = num(it.quantity || 1)
      rev += num(it.total ?? it.subtotal ?? num(it.unit_price) * q)
      cost += num(it.cost_price ?? it.unit_cost) * q
    }
    if (!(t.items || []).length) rev += num(t.total ?? t.total_amount)
  }
  return rev ? ((rev - cost) / rev) * 100 : 0
})

const whatsHappened = computed(() => [
  deltaRow('Revenue', revenue.value, prevRevenue.value),
  deltaRow('Orders', orders.value, prevOrders.value, { money: false }),
  deltaRow('Average order value', aov.value, prevOrders.value ? prevRevenue.value / prevOrders.value : 0),
  deltaRow('Units sold', unitsSold.value, prevUnitsSold.value, { money: false }),
  deltaRow('Gross margin %', grossMargin.value.marginPct, prevGrossMarginPct.value, { money: false, suffix: '%' })
])

// ── live pulse ──────────────────────────────────────────────────────────
const livePulse = computed(() => [
  { label: 'Open deliveries', value: num(overview.value.pending_deliveries ?? overview.value.to_be_packed), icon: 'mdi-truck-fast-outline', color: 'blue', hint: 'Awaiting dispatch' },
  { label: 'Items out of stock', value: stockoutItems.value + oosFromOverview.value, icon: 'mdi-package-variant-remove', color: 'error', hint: 'Cannot fulfil demand' },
  { label: 'Below reorder point', value: lowStock.value.length, icon: 'mdi-bell-alert', color: 'warning', hint: 'Replenish soon' },
  { label: 'Active SKUs', value: stocks.value.length, icon: 'mdi-cube-scan', color: 'teal', hint: 'In the catalogue' }
])

// ── recommendations ─────────────────────────────────────────────────────
const recommendations = computed(() => {
  const out = []
  if (lowStock.value.length) {
    out.push({
      title: `Replenish ${Math.min(lowStock.value.length, 12)} fast-moving items`,
      detail: 'Stockouts are the largest single suppressant of sell-through this period.',
      icon: 'mdi-cart-arrow-down', color: 'warning', impact: `+${formatMoney(estimatedStockoutLoss.value)}`
    })
  }
  if (expiring.value.length) {
    out.push({
      title: `Clear ${expiring.value.length} near-expiry batches`,
      detail: 'Run a targeted markdown to recover cash and avoid write-off.',
      icon: 'mdi-tag-minus', color: 'error', impact: `+${formatMoney(expiryValueAtRisk.value)}`
    })
  }
  if (grossMargin.value.marginPct > 0 && grossMargin.value.marginPct < 25) {
    out.push({
      title: 'Tighten discount guardrails',
      detail: 'Margin is below the 25% floor. Cap discounts on A-class items.',
      icon: 'mdi-percent', color: 'warning', impact: `+${formatMoney(grossMargin.value.revenue * 0.015)}`
    })
  }
  const topCross = basket.value[0]
  if (topCross) {
    out.push({
      title: `Bundle “${topCross.a}” with “${topCross.b}”`,
      detail: `Buyers of the first item add the second ${(topCross.confidence * 100).toFixed(0)}% of the time (${topCross.lift.toFixed(2)}x lift).`,
      icon: 'mdi-gift-outline', color: 'teal', impact: `+${formatMoney(topCross.support * revenue.value)}`
    })
  }
  if (!out.length) {
    out.push({
      title: 'Maintain the current plan',
      detail: 'No material risks detected — continue monitoring the KPI scorecard.',
      icon: 'mdi-check-decagram', color: 'success', impact: 'On track'
    })
  }
  return out.slice(0, 5)
})

const estimatedStockoutLoss = computed(() => {
  const items = lowStock.value.length || 0
  const perItem = orders.value ? revenue.value / Math.max(orders.value, 1) : 0
  return Math.round(items * perItem * 0.6)
})
const expiryValueAtRisk = computed(() =>
  sum(expiring.value, (s) => num(s.cost_price) * num(s.total_quantity ?? s.quantity))
)

// ── segments / charts ───────────────────────────────────────────────────
const categorySegments = computed(() =>
  categories.value.slice(0, 8).map((c, i) => ({ label: c.name, value: c.revenue, color: palette[i % palette.length], pct: revenue.value ? Math.round((c.revenue / revenue.value) * 100) : 0 }))
)
const categoryTotal = computed(() => sum(categorySegments.value, (s) => s.value))
function branchShare(v) {
  const total = sum(branches.value, (b) => b.value) || 1
  return (num(v) / total) * 100
}

const abcData = computed(() => abcClass(products.value, { valueKey: 'revenue' }))
const abcSummary = computed(() => abcData.value.summary)

function abcColor(k) {
  return k === 'A' ? 'success' : k === 'B' ? 'warning' : 'grey'
}
function xyzColor(k) {
  return k === 'X' ? 'success' : k === 'Y' ? 'warning' : 'error'
}

// ── trajectory chart ────────────────────────────────────────────────────
const ordersSeries = computed(() => historyMonthly.value.map((b) => num(b.orders)))
const activeSeries = computed(() => (trendMode.value === 'value' ? historyValues.value : ordersSeries.value))
const activeForecast = computed(() => trendForecast(activeSeries.value, { horizon: forecastHorizon, method: 'holt' }))

const trajectoryLabels = computed(() => {
  const future = Array.from({ length: forecastHorizon }, (_, i) => `P+${i + 1}`)
  return [...historyLabels.value, ...future]
})

// The projection line replays the actuals (so both lines coincide for the
// historical span) then extends into the forecast periods — no nulls, which
// the shared LineChart component does not support.
const trajectorySeries = computed(() => {
  const actual = activeSeries.value
  const fitted = activeForecast.value.fitted.map((v, i) => (i === 0 ? num(actual[0]) : num(v)))
  const projection = [...actual, ...activeForecast.value.forecast]
  return [
    { label: 'Actual', color: '#0d9488', values: actual },
    { label: 'Model fit', color: '#cbd5e1', values: fitted },
    { label: 'Projection', color: '#8b5cf6', values: projection }
  ]
})

const trajectoryFormatter = computed(() => (trendMode.value === 'value' ? compactMoney : (v) => String(Math.round(num(v)))))

const forecastMetrics = computed(() => [
  { label: 'Method', value: "Holt's linear trend" },
  { label: 'MAPE', value: `${activeForecast.value.accuracy.mape.toFixed(1)}%` },
  { label: 'RMSE', value: trendMode.value === 'value' ? formatMoney(activeForecast.value.accuracy.rmse) : Math.round(activeForecast.value.accuracy.rmse) },
  { label: 'R² (fit)', value: activeForecast.value.accuracy.r2.toFixed(3) }
])
</script>

<style scoped>
.legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}
.w-100 {
  width: 100%;
}
.bi-ul {
  margin: 0;
  padding-left: 16px;
  font-size: 12.5px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.78);
}
.bi-ul li {
  margin-bottom: 2px;
}
.bi-horizon {
  background-image: linear-gradient(160deg, rgba(var(--v-theme-primary), 0.045), transparent 60%);
}
</style>
