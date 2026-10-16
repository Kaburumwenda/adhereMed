<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Optimization and Actions"
      subtitle="Prescriptive analytics — pricing, discount guardrails, replenishment and markdown"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-tune-variant"
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
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-tune" @click="assumptionsDialog = true">
          Assumptions
        </v-btn>
        <v-btn variant="tonal" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-download" @click="exportPlan">
          Export plan
        </v-btn>
      </template>
    </BiToolbar>

    <!-- Opportunity summary -->
    <v-alert color="teal" variant="tonal" rounded="lg" border="start" prominent class="mb-4">
      <div class="d-flex flex-wrap align-center ga-3">
        <v-icon size="28">mdi-lightbulb-on-outline</v-icon>
        <div class="flex-grow-1">
          <div class="text-subtitle-1 font-weight-bold">
            {{ formatMoney(totalOpportunity) }} of identified upside across {{ actionCount }} actions
          </div>
          <div class="text-body-2">
            Recovered margin from pricing and discounts, avoided stockout loss, working capital released from overstock and
            markdown recovery on near-expiry stock. Assumptions are editable and applied to every calculation below.
          </div>
        </div>
        <v-chip variant="flat" color="teal" class="font-weight-bold">{{ marginRecoveryPct.toFixed(1) }}% margin uplift</v-chip>
      </div>
    </v-alert>

    <v-row dense>
      <v-col v-for="o in opportunityTiles" :key="o.title" cols="6" md="3">
        <KpiTile v-bind="o" flat />
      </v-col>
    </v-row>

    <!-- Pricing recommendations -->
    <v-row class="mt-1">
      <v-col cols="12" xl="7">
        <BiPanel title="Pricing recommendations" subtitle="Elasticity-informed price moves by ABC class" icon="mdi-currency-usd" color="teal">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportPricing">CSV</v-btn>
          </template>
          <EmptyState v-if="!pricing.length" icon="mdi-tag-off-outline" title="No priced products" message="Pricing recommendations need product cost and selling price." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Product</th><th class="text-center">ABC</th>
                <th class="text-right">Price</th><th class="text-right">Cost</th>
                <th class="text-right">Margin</th><th class="text-right">Recommended</th>
                <th class="text-right">Δ</th><th class="text-right">Impact</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in pricing" :key="p.name">
                <td class="text-truncate font-weight-medium" style="max-width: 210px">{{ p.name }}</td>
                <td class="text-center"><v-chip size="x-small" :color="abcColor(p.abc)" variant="tonal">{{ p.abc }}</v-chip></td>
                <td class="text-right">{{ formatMoney(p.price) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(p.cost) }}</td>
                <td class="text-right">{{ p.marginPct.toFixed(1) }}%</td>
                <td class="text-right font-weight-medium" :class="p.recommended > p.price ? 'text-success' : 'text-warning'">
                  {{ formatMoney(p.recommended) }}
                </td>
                <td class="text-right">
                  <v-chip size="x-small" :color="p.deltaPct >= 0 ? 'success' : 'warning'" variant="tonal">
                    {{ p.deltaPct >= 0 ? '+' : '' }}{{ p.deltaPct.toFixed(1) }}%
                  </v-chip>
                </td>
                <td class="text-right font-weight-medium text-success">{{ formatMoney(p.impact) }}</td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" xl="5">
        <BiPanel title="Discount guardrails" subtitle="Maximum discount before breaching the margin floor" icon="mdi-percent" color="pink">
          <v-alert type="info" variant="tonal" density="compact" class="text-caption mb-3">
            Margin floor is set to {{ assumptions.minMarginPct }}% in the assumptions panel.
          </v-alert>
          <EmptyState v-if="!guardrails.length" icon="mdi-shield-off-outline" title="No guardrails available" />
          <div v-for="g in guardrails" :key="g.name" class="mb-3">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-truncate" style="max-width: 55%">{{ g.name }}</span>
              <span class="font-weight-medium" :class="g.room < 5 ? 'text-error' : 'text-success'">
                {{ g.room.toFixed(1) }}% room
              </span>
            </div>
            <v-progress-linear :model-value="Math.min(g.room * 4, 100)" :color="g.room < 5 ? 'error' : g.room < 12 ? 'warning' : 'success'" height="7" rounded />
            <div class="text-caption text-medium-emphasis">{{ g.note }}</div>
          </div>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Replenishment optimization -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Replenishment optimization" subtitle="Economic order quantity, safety stock and reorder points per item" icon="mdi-cart-arrow-down" color="indigo">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportReplenishment">CSV</v-btn>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-tune" @click="assumptionsDialog = true">Tune</v-btn>
          </template>
          <EmptyState v-if="!replenishment.length" icon="mdi-package-check" title="Nothing to replenish" message="All items are above their reorder points." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right">On hand</th>
                <th class="text-right">Daily demand</th>
                <th class="text-right">Cover (days)</th>
                <th class="text-right">Safety stock</th>
                <th class="text-right">Reorder point</th>
                <th class="text-right">EOQ</th>
                <th class="text-right">Recommended order</th>
                <th class="text-right">Value</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in replenishment" :key="r.name">
                <td class="text-truncate font-weight-medium" style="max-width: 200px">{{ r.name }}</td>
                <td class="text-right">{{ r.onHand }}</td>
                <td class="text-right">{{ r.dailyDemand.toFixed(2) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="r.cover < assumptions.leadTimeDays ? 'error' : r.cover < assumptions.leadTimeDays * 1.5 ? 'warning' : 'success'" variant="tonal">
                    {{ r.cover === Infinity ? '∞' : r.cover.toFixed(0) }}
                  </v-chip>
                </td>
                <td class="text-right">{{ Math.round(r.safety) }}</td>
                <td class="text-right font-weight-medium">{{ Math.round(r.rop) }}</td>
                <td class="text-right">{{ Math.round(r.eoq) }}</td>
                <td class="text-right font-weight-bold text-primary">{{ Math.round(r.orderQty) }}</td>
                <td class="text-right">{{ formatMoney(r.orderValue) }}</td>
              </tr>
            </tbody>
          </v-table>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            Safety stock = z · σ<sub>demand</sub> · √lead time · Reorder point = (daily demand × lead time) + safety stock ·
            EOQ = √(2 · annual demand · order cost ÷ annual holding cost). Service level {{ assumptions.serviceLevel }}%,
            lead time {{ assumptions.leadTimeDays }} days, order cost {{ formatMoney(assumptions.orderCost) }},
            holding rate {{ assumptions.holdingRate }}% p.a.
          </div>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Markdown + allocation -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Markdown and clearance" subtitle="Near-expiry and slow-moving stock ranked by clearance score" icon="mdi-tag-minus-outline" color="orange">
          <EmptyState v-if="!markdown.length" icon="mdi-check-circle" title="No clearance required" message="No stock is at risk of expiry write-off." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Item</th><th class="text-right">Expires</th><th class="text-right">Value</th>
                <th class="text-right">Score</th><th class="text-right">Markdown</th><th class="text-right">Recovery</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in markdown" :key="m.name">
                <td class="text-truncate font-weight-medium" style="max-width: 190px">{{ m.name }}</td>
                <td class="text-right">{{ m.expires }}</td>
                <td class="text-right">{{ formatMoney(m.value) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="m.score > 65 ? 'error' : m.score > 40 ? 'warning' : 'grey'" variant="tonal">{{ m.score.toFixed(0) }}</v-chip>
                </td>
                <td class="text-right font-weight-medium">{{ m.markdownPct.toFixed(0) }}%</td>
                <td class="text-right font-weight-medium text-success">{{ formatMoney(m.recovery) }}</td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Stock allocation" subtitle="Rebalance cover between locations" icon="mdi-swap-horizontal-bold" color="cyan">
          <EmptyState v-if="!allocation.length" icon="mdi-store-off-outline" title="Single location" message="Branch rebalancing needs at least two locations with stock." />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="a in allocation" :key="a.name" class="px-0 align-start">
              <template #prepend>
                <v-avatar size="32" :color="a.color" variant="tonal"><v-icon size="16">{{ a.icon }}</v-icon></v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ a.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ a.detail }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="a.color" variant="tonal" class="font-weight-bold">{{ a.move }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Action plan -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Prioritised action plan" subtitle="Ranked by expected financial impact" icon="mdi-format-list-numbered" color="deep-purple">
          <v-timeline density="compact" side="end" truncate-line="start">
            <v-timeline-item v-for="(a, i) in actionPlan" :key="i" :dot-color="a.color" size="small" fill-dot>
              <div class="d-flex flex-wrap align-center ga-2 mb-1">
                <span class="text-body-2 font-weight-bold">{{ a.title }}</span>
                <v-chip size="x-small" :color="a.color" variant="tonal">{{ a.impact }}</v-chip>
                <v-chip size="x-small" variant="outlined">{{ a.effort }}</v-chip>
                <v-chip size="x-small" variant="outlined">{{ a.owner }}</v-chip>
              </div>
              <div class="text-body-2 text-medium-emphasis">{{ a.detail }}</div>
            </v-timeline-item>
          </v-timeline>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Assumptions dialog -->
    <v-dialog v-model="assumptionsDialog" max-width="560">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Optimisation assumptions</v-card-title>
        <v-card-subtitle>These parameters drive every recommendation on this page.</v-card-subtitle>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="assumptions.leadTimeDays" type="number" label="Supplier lead time (days)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="assumptions.orderCost" type="number" label="Cost per order"
                            density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="assumptions.holdingRate" type="number" label="Holding cost (% p.a.)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="assumptions.minMarginPct" type="number" label="Minimum margin floor (%)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="assumptions.serviceLevel" type="number" label="Service level (%)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="assumptions.targetMarginPct" type="number" label="Target margin (%)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="assumptions = { ...defaultAssumptions }">Reset</v-btn>
          <v-btn color="teal" variant="flat" class="text-none" @click="assumptionsDialog = false">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBiData } from '~/composables/useBiData'
import {
  num, sum, stdDev, clamp, downloadCsv,
  eoq, safetyStock, reorderPoint, maxDiscount, clearanceScore, zFor
} from '~/utils/bi'

const {
  loading, rangeKey, rangeLabel, rangeDays, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  products, stocks, lowStock, expiring, daysUntil, grossMargin, branches
} = useBiData({ defaultRange: '12m' })

const assumptionsDialog = ref(false)

const defaultAssumptions = {
  leadTimeDays: 14,
  orderCost: 2500,
  holdingRate: 22,
  minMarginPct: 15,
  serviceLevel: 95,
  targetMarginPct: 28
}
const assumptions = ref({ ...defaultAssumptions })
if (import.meta.client) {
  try {
    const raw = localStorage.getItem('bi.assumptions')
    if (raw) assumptions.value = { ...defaultAssumptions, ...JSON.parse(raw) }
  } catch { /* ignore */ }
}
watch(assumptions, (v) => {
  if (import.meta.client) localStorage.setItem('bi.assumptions', JSON.stringify(v))
}, { deep: true })

// ── stock lookup (for cost/price when the sales feed lacks it) ──────────
const stockByName = computed(() => {
  const m = new Map()
  for (const s of stocks.value) {
    m.set(String(s.medication_name || s.name || '').trim().toLowerCase(), s)
  }
  return m
})
function stockFor(name) {
  return stockByName.value.get(String(name || '').trim().toLowerCase()) || null
}

// ── demand model per product ────────────────────────────────────────────
const demandRows = computed(() => {
  const days = rangeDays.value || 30
  return products.value.map((p) => {
    const st = stockFor(p.name)
    const selling = num(st?.selling_price) || (p.qty ? p.revenue / p.qty : 0)
    const cost = num(st?.cost_price) || (p.qty ? (p.cost ? p.cost / p.qty : 0) : 0) || selling * 0.7
    const dailyDemand = num(p.qty) / days
    const onHand = num(st?.total_quantity ?? st?.quantity)
    return {
      ...p,
      selling,
      cost,
      dailyDemand,
      onHand,
      marginPct: selling ? ((selling - cost) / selling) * 100 : 0,
      cover: dailyDemand ? onHand / dailyDemand : Infinity
    }
  })
})

// ── pricing recommendations ─────────────────────────────────────────────
const pricing = computed(() =>
  demandRows.value
    .filter((r) => r.selling > 0 && r.cost > 0)
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 15)
    .map((r) => {
      // A-class items are inelastic (protect price); C-class are price-sensitive.
      const targetMargin = r.abc === 'A' ? assumptions.value.targetMarginPct : r.abc === 'B' ? assumptions.value.targetMarginPct - 3 : assumptions.value.minMarginPct
      let recommended = r.cost / (1 - targetMargin / 100)
      // Never recommend a jump beyond +/-15% of current price in one step.
      recommended = clamp(recommended, r.selling * 0.85, r.selling * 1.15)
      const deltaPct = ((recommended - r.selling) / r.selling) * 100
      // Revenue impact net of an assumed 1.2 own-price elasticity.
      const elasticity = -1.2
      const qtyFactor = 1 + elasticity * (deltaPct / 100)
      const impact = Math.max(0, recommended * r.qty * qtyFactor - r.revenue)
      return { ...r, price: r.selling, recommended, deltaPct, impact }
    })
)

const guardrails = computed(() =>
  demandRows.value
    .filter((r) => r.selling > 0 && r.cost > 0)
    .sort((a, b) => (a.selling - a.cost) / a.selling - (b.selling - b.cost) / b.selling)
    .slice(0, 10)
    .map((r) => {
      const room = maxDiscount({ price: r.selling, cost: r.cost, minMarginPct: assumptions.value.minMarginPct })
      return {
        name: r.name,
        room,
        note: room < 5
          ? `Only ${room.toFixed(1)}% headroom — protect this line from discounting.`
          : `Discounts above ${room.toFixed(1)}% breach the ${assumptions.value.minMarginPct}% floor.`
      }
    })
)

// ── replenishment ───────────────────────────────────────────────────────
const zService = computed(() => zFor(assumptions.value.serviceLevel))

const replenishment = computed(() => {
  const rows = []
  for (const r of demandRows.value) {
    if (!r.onHand && r.onHand !== 0) continue
    const rop = reorderPoint({ avgDailyDemand: r.dailyDemand, leadTimeDays: assumptions.value.leadTimeDays, safety: 0 })
    if (r.onHand > rop * 1.25 && r.cover > assumptions.value.leadTimeDays * 2) continue
    if (r.dailyDemand <= 0) continue
    const annualDemand = r.dailyDemand * 365
    const holdingCost = Math.max(0.01, r.cost * (assumptions.value.holdingRate / 100))
    const order = eoq({ annualDemand, orderCost: assumptions.value.orderCost, holdingCost })
    // demand variability proxy from the weekly series
    const weekly = r.series || []
    const safety = safetyStock({ stdDevDemand: stdDev(weekly.length ? weekly : [r.dailyDemand * 7]), avgLeadTime: assumptions.value.leadTimeDays, serviceZ: zService.value })
    const ropFinal = reorderPoint({ avgDailyDemand: r.dailyDemand, leadTimeDays: assumptions.value.leadTimeDays, safety })
    const orderQty = Math.max(order, ropFinal - r.onHand + order)
    rows.push({
      name: r.name,
      onHand: Math.round(r.onHand),
      dailyDemand: r.dailyDemand,
      cover: r.cover,
      eoq: order || Math.max(1, r.dailyDemand * 30),
      safety,
      rop: ropFinal,
      orderQty: Math.max(1, Math.round(orderQty)),
      orderValue: Math.max(1, Math.round(orderQty)) * r.cost
    })
  }
  return rows.sort((a, b) => a.cover - b.cover).slice(0, 18)
})

// ── markdown ────────────────────────────────────────────────────────────
const markdown = computed(() =>
  expiring.value
    .map((s) => {
      const qty = num(s.total_quantity ?? s.quantity)
      const cost = num(s.cost_price)
      const price = num(s.selling_price) || cost * 1.3
      const dte = daysUntil(s.expiry_date)
      const name = String(s.medication_name || s.name || '').trim()
      const demand = demandRows.value.find((d) => d.name.toLowerCase() === name.toLowerCase())
      const cover = demand ? demand.cover : 999
      const score = clearanceScore({ daysToExpiry: dte, daysOfCover: cover, sellThrough: clamp(1 - dte / 180, 0, 1) })
      // Deeper markdown the closer to expiry, but never below cost recovery.
      const markdownPct = clamp(score * 0.45, 0, Math.max(0, clamp(((price - cost) / price) * 100, 0, 60)))
      const recovery = qty * price * (1 - markdownPct / 100)
      return { name, expires: `${dte}d`, value: qty * cost, score, markdownPct, recovery }
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, 12)
)

// ── allocation ──────────────────────────────────────────────────────────
const allocation = computed(() => {
  if (branches.value.length < 2) return []
  const total = sum(branches.value, (b) => b.value) || 1
  const avg = total / branches.value.length
  return branches.value.map((b) => {
    const ratio = b.value / avg
    const surplus = ratio >= 1.15
    const deficit = ratio <= 0.85
    return {
      name: b.name,
      move: surplus ? 'Source' : deficit ? 'Receive' : 'Balanced',
      color: surplus ? 'orange' : deficit ? 'success' : 'grey',
      icon: surplus ? 'mdi-arrow-up-bold-box-outline' : deficit ? 'mdi-arrow-down-bold-box-outline' : 'mdi-scale-balance',
      detail: surplus
        ? `Trading ${((ratio - 1) * 100).toFixed(0)}% above the network average — move slow cover to under-performing sites.`
        : deficit
          ? `Trading ${((1 - ratio) * 100).toFixed(0)}% below the network average — prioritise replenishment here.`
          : 'Trading in line with the network average.'
    }
  })
})

// ── opportunities ───────────────────────────────────────────────────────
const pricingUpside = computed(() => sum(pricing.value, (p) => p.impact))
const stockoutRecovery = computed(() =>
  sum(lowStock.value, (s) => {
    const onHand = num(s.total_quantity ?? s.quantity)
    const gap = Math.max(0, num(s.reorder_level) - onHand)
    return gap * num(s.selling_price || s.cost_price)
  })
)
const markdownRecovery = computed(() => sum(markdown.value, (m) => m.recovery) * 0.35)
const workingCapitalRelease = computed(() => {
  // Overstocked lines: cover beyond 2× lead time is released.
  const excess = demandRows.value.filter((r) => r.cover > assumptions.value.leadTimeDays * 2 && r.onHand > 0)
  return sum(excess, (r) => Math.max(0, r.onHand - r.dailyDemand * assumptions.value.leadTimeDays * 2) * r.cost)
})

const totalOpportunity = computed(() => pricingUpside.value + stockoutRecovery.value + markdownRecovery.value + workingCapitalRelease.value)
const actionCount = computed(() => pricing.value.length + replenishment.value.length + markdown.value.length)
const marginRecoveryPct = computed(() => {
  const base = grossMargin.value.margin || 1
  return (pricingUpside.value / base) * 100
})

const opportunityTiles = computed(() => [
  { title: 'Pricing upside', value: formatMoney(pricingUpside.value), valueNum: pricingUpside.value, icon: 'mdi-currency-usd', color: 'teal', hint: `${pricing.value.length} price moves` },
  { title: 'Stockout recovery', value: formatMoney(stockoutRecovery.value), valueNum: stockoutRecovery.value, icon: 'mdi-package-variant-closed-plus', color: 'orange', hint: `${lowStock.value.length} items to replenish` },
  { title: 'Markdown recovery', value: formatMoney(markdownRecovery.value), valueNum: markdownRecovery.value, icon: 'mdi-tag-minus-outline', color: 'pink', hint: `${markdown.value.length} near-expiry lines` },
  { title: 'Working capital release', value: formatMoney(workingCapitalRelease.value), valueNum: workingCapitalRelease.value, icon: 'mdi-cash-refund', color: 'cyan', hint: 'From overstocked cover' }
])

const actionPlan = computed(() => {
  const plan = []
  if (replenishment.value.length) {
    plan.push({
      title: `Raise replenishment for ${replenishment.value.length} items`,
      detail: `Order ${Math.round(sum(replenishment.value, (r) => r.orderQty))} units to restore service levels; the largest gap is ${replenishment.value[0].name}.`,
      impact: `+${formatMoney(stockoutRecovery.value)}`,
      effort: 'Low effort',
      owner: 'Procurement',
      color: 'orange'
    })
  }
  if (pricing.value.length) {
    plan.push({
      title: 'Re-price the top revenue lines',
      detail: `Apply the recommended price to ${pricing.value.filter((p) => p.impact > 0).length} products; A-class items can absorb a rise, C-class need a defensive price.`,
      impact: `+${formatMoney(pricingUpside.value)}`,
      effort: 'Medium effort',
      owner: 'Commercial',
      color: 'teal'
    })
  }
  if (guardrails.value.some((g) => g.room < 5)) {
    plan.push({
      title: 'Lock discount guardrails on thin-margin lines',
      detail: `${guardrails.value.filter((g) => g.room < 5).length} products have under 5% discount headroom — enforce approval above the limit.`,
      impact: `+${formatMoney(grossMargin.value.revenue * 0.012)}`,
      effort: 'Low effort',
      owner: 'Finance',
      color: 'pink'
    })
  }
  if (markdown.value.length) {
    plan.push({
      title: 'Run a clearance programme',
      detail: `${markdown.value.length} lines score above the clearance threshold. A staged markdown protects more margin than a single deep cut.`,
      impact: `+${formatMoney(markdownRecovery.value)}`,
      effort: 'Medium effort',
      owner: 'Merchandising',
      color: 'amber'
    })
  }
  if (workingCapitalRelease.value > 0) {
    plan.push({
      title: 'Release overstocked working capital',
      detail: 'Reduce cover on lines holding more than twice the lead-time demand and redeploy the cash to A-class fast movers.',
      impact: `+${formatMoney(workingCapitalRelease.value)}`,
      effort: 'High effort',
      owner: 'Supply chain',
      color: 'cyan'
    })
  }
  if (!plan.length) {
    plan.push({
      title: 'No corrective action required',
      detail: 'All optimisation models are within tolerance for the selected period.',
      impact: 'On plan',
      effort: '—',
      owner: '—',
      color: 'success'
    })
  }
  return plan
})

function abcColor(k) {
  return k === 'A' ? 'success' : k === 'B' ? 'warning' : 'grey'
}

// ── exports ─────────────────────────────────────────────────────────────
function exportPricing() {
  downloadCsv('pricing-recommendations', ['name', 'abc', 'price', 'cost', 'marginPct', 'recommended', 'deltaPct', 'impact'], pricing.value)
}
function exportReplenishment() {
  downloadCsv('replenishment-plan', ['name', 'onHand', 'dailyDemand', 'cover', 'safety', 'rop', 'eoq', 'orderQty', 'orderValue'], replenishment.value)
}
function exportPlan() {
  downloadCsv('optimisation-plan', ['title', 'detail', 'impact', 'effort', 'owner'], actionPlan.value)
}
</script>
