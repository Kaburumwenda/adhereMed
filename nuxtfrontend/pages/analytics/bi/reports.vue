<template>
  <v-container fluid class="pa-3 pa-md-5">
    <BiToolbar
      title="Operational Reports"
      subtitle="Report library, scheduling and distribution for analytical operations"
      eyebrow="INSIGHTS · BI ANALYSIS"
      icon="mdi-file-chart"
      color="blue"
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
        <v-btn variant="tonal" color="blue" rounded="lg" class="text-none" prepend-icon="mdi-calendar-clock"
               @click="scheduleDialog = true">Schedule</v-btn>
      </template>
    </BiToolbar>

    <v-row>
      <!-- Report catalogue -->
      <v-col cols="12" lg="4">
        <BiPanel title="Report library" :subtitle="`${reports.length} analytical reports`" icon="mdi-bookshelf" color="blue">
          <template #actions>
            <v-text-field v-model="search" placeholder="Search…" prepend-inner-icon="mdi-magnify"
                          density="compact" variant="outlined" hide-details clearable style="max-width: 180px" />
          </template>
          <div v-for="grp in groupedReports" :key="grp.domain" class="mb-3">
            <div class="text-caption font-weight-bold text-uppercase mb-1" style="letter-spacing: .8px">{{ grp.domain }}</div>
            <v-list density="compact" class="bg-transparent pa-0">
              <v-list-item
                v-for="r in grp.items"
                :key="r.key"
                class="px-0 rounded"
                :class="{ 'bg-blue-lighten-5': activeReport === r.key }"
                @click="selectReport(r.key)"
              >
                <template #prepend>
                  <v-avatar size="30" :color="r.color" variant="tonal"><v-icon size="16">{{ r.icon }}</v-icon></v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">{{ r.title }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">{{ r.description }}</v-list-item-subtitle>
                <template #append>
                  <v-icon size="16" color="blue">mdi-chevron-right</v-icon>
                </template>
              </v-list-item>
            </v-list>
          </div>
        </BiPanel>
      </v-col>

      <!-- Preview -->
      <v-col cols="12" lg="8">
        <BiPanel :title="current.title" :subtitle="current.description" :icon="current.icon" :color="current.color">
          <template #actions>
            <v-chip size="small" variant="tonal" :color="current.color">{{ rangeLabel }}</v-chip>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportCurrent">CSV</v-btn>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-printer" @click="printPreview">Print</v-btn>
            <v-btn variant="tonal" size="small" color="blue" class="text-none" prepend-icon="mdi-send-outline"
                   @click="runReport">Run and deliver</v-btn>
          </template>

          <v-progress-linear v-if="running" indeterminate color="blue" height="3" rounded class="mb-2" />

          <v-alert v-if="preview.summary" type="info" variant="tonal" density="compact" class="mb-3">
            {{ preview.summary }}
          </v-alert>

          <EmptyState v-if="!preview.rows || !preview.rows.length" icon="mdi-table-off" title="No data for this report"
                      message="Adjust the date range or branch filter and try again." />

          <div v-else class="report-preview">
            <div style="overflow-x: auto">
              <v-table density="compact" class="bg-transparent">
                <thead>
                  <tr>
                    <th v-for="c in preview.columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">{{ c.title }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(row, i) in preview.rows" :key="i">
                    <td v-for="c in preview.columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">{{ row[c.key] }}</td>
                  </tr>
                </tbody>
                <tfoot v-if="preview.totals">
                  <tr class="font-weight-bold">
                    <td v-for="(c, i) in preview.columns" :key="c.key" :class="c.align ? `text-${c.align}` : ''">
                      {{ i === 0 ? 'Total' : (preview.totals[c.key] || '') }}
                    </td>
                  </tr>
                </tfoot>
              </v-table>
            </div>
          </div>

          <template #footer>
            <div class="d-flex flex-wrap align-center ga-3 text-caption text-medium-emphasis">
              <span><v-icon size="14" class="mr-1">mdi-clock-outline</v-icon>Generated {{ generatedAt }}</span>
              <span><v-icon size="14" class="mr-1">mdi-database</v-icon>{{ preview.rows ? preview.rows.length : 0 }} rows</span>
              <span><v-icon size="14" class="mr-1">mdi-account-circle-outline</v-icon>{{ operatorName }}</span>
            </div>
          </template>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Schedules + history -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel title="Scheduled deliveries" subtitle="Automated report runs and distribution" icon="mdi-calendar-clock" color="indigo">
          <template #actions>
            <v-btn variant="tonal" size="small" color="indigo" class="text-none" prepend-icon="mdi-plus"
                   @click="scheduleDialog = true">New schedule</v-btn>
          </template>
          <EmptyState v-if="!schedules.length" icon="mdi-calendar-plus" title="No schedules yet"
                      message="Schedule a report to deliver it to stakeholders automatically." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Report</th><th>Frequency</th><th>Format</th><th>Recipients</th>
                <th>Next run</th><th class="text-center">Active</th><th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in schedules" :key="s.id">
                <td class="font-weight-medium">{{ s.report }}</td>
                <td>{{ s.frequency }}</td>
                <td>{{ s.format }}</td>
                <td class="text-truncate" style="max-width: 180px">{{ s.recipients }}</td>
                <td>{{ s.nextRun }}</td>
                <td class="text-center">
                  <v-switch v-model="s.enabled" color="success" density="compact" hide-details inset @update:model-value="persistSchedules" />
                </td>
                <td>
                  <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click="removeSchedule(s.id)" />
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <BiPanel title="Recent runs" subtitle="Delivery history for this workspace" icon="mdi-history" color="teal">
          <EmptyState v-if="!runs.length" icon="mdi-tray-arrow-up" title="No runs yet"
                      message="Run a report to populate the delivery history." />
          <v-list v-else density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="r in runs" :key="r.id" class="px-0">
              <template #prepend>
                <v-avatar size="30" :color="r.color" variant="tonal"><v-icon size="16">{{ r.icon }}</v-icon></v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ r.report }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ r.when }} · {{ r.format }} · {{ r.rows }} rows</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="r.status === 'Delivered' ? 'success' : 'warning'" variant="tonal">{{ r.status }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Schedule dialog -->
    <v-dialog v-model="scheduleDialog" max-width="560">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Schedule a report</v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12">
              <v-select v-model="draftSchedule.report" :items="reports.map((r) => r.title)" label="Report"
                        density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="draftSchedule.frequency" :items="frequencies" label="Frequency"
                        density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="draftSchedule.format" :items="formats" label="Format"
                        density="compact" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="draftSchedule.recipients" label="Recipients (comma separated)"
                            density="compact" variant="outlined" hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="scheduleDialog = false">Cancel</v-btn>
          <v-btn color="indigo" variant="flat" class="text-none" @click="addSchedule">Create schedule</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
import { useBiData } from '~/composables/useBiData'
import { num, sum, mean, pctChange, downloadCsv } from '~/utils/bi'

const auth = useAuthStore()

const {
  loading, rangeKey, rangeLabel, BI_RANGE_OPTIONS,
  branchFilter, branchFilterItems, isBranchLocked, monthlyTarget, setMonthlyTarget,
  customDialog, customStart, customEnd, onRangeChange, applyCustom, load,
  inRange, inPrevRange, revenue, prevRevenue, orders, prevOrders, aov, unitsSold, customers,
  inventoryCost, unitsOnHand, lowStock, expiring, daysUntil,
  historyMonthly, historyValues, forecast,
  products, categories, branches, rfm, basket, drivers
} = useBiData({ defaultRange: '12m' })

const search = ref('')
const activeReport = ref('sales-variance')
const running = ref(false)
const generatedAt = ref(new Date().toLocaleString())
const operatorName = computed(() => auth.user?.full_name || auth.user?.name || auth.user?.email || 'Analyst')

// ── report builders ─────────────────────────────────────────────────────
function monthlyVsTarget() {
  const target = monthlyTarget.value || Math.round((mean(historyValues.value.slice(-3)) || 0) * 1.08)
  const rows = historyMonthly.value.map((b, i) => {
    const prior = i > 0 ? num(historyMonthly.value[i - 1].value) : 0
    const variance = num(b.value) - target
    return {
      period: b.label,
      actual: formatMoney(b.value),
      target: formatMoney(target),
      variance: formatMoney(variance),
      variancePct: target ? `${((variance / target) * 100).toFixed(1)}%` : '—',
      mom: prior ? `${pctChange(b.value, prior).toFixed(1)}%` : '—'
    }
  })
  const totalActual = sum(historyMonthly.value, (b) => b.value)
  return {
    columns: [
      { key: 'period', title: 'Period' },
      { key: 'actual', title: 'Actual', align: 'right' },
      { key: 'target', title: 'Target', align: 'right' },
      { key: 'variance', title: 'Variance', align: 'right' },
      { key: 'variancePct', title: 'Variance %', align: 'right' },
      { key: 'mom', title: 'MoM', align: 'right' }
    ],
    rows: rows.reverse(),
    totals: { actual: formatMoney(totalActual), target: formatMoney(target * rows.length), variance: formatMoney(totalActual - target * rows.length) },
    summary: `Trailing twelve periods delivered ${formatMoney(totalActual)} against a cumulative target of ${formatMoney(target * rows.length)}.`
  }
}

function productPerformance() {
  const rows = products.value.slice(0, 30).map((p) => ({
    name: p.name,
    category: p.category,
    abc: p.abc,
    xyz: p.xyz || '—',
    qty: num(p.qty).toLocaleString(),
    revenue: formatMoney(p.revenue),
    margin: p.marginPct ? `${p.marginPct.toFixed(1)}%` : '—'
  }))
  return {
    columns: [
      { key: 'name', title: 'Product' },
      { key: 'category', title: 'Category' },
      { key: 'abc', title: 'ABC', align: 'center' },
      { key: 'xyz', title: 'XYZ', align: 'center' },
      { key: 'qty', title: 'Qty', align: 'right' },
      { key: 'revenue', title: 'Revenue', align: 'right' },
      { key: 'margin', title: 'Margin', align: 'right' }
    ],
    rows,
    totals: { revenue: formatMoney(revenue.value), qty: unitsSold.value.toLocaleString() },
    summary: `${products.value.length} products sold in the period. The top 10 account for ${topShare.value.toFixed(0)}% of revenue.`
  }
}

function inventoryAgeing() {
  const buckets = [
    { label: 'Expired', filter: (d) => d < 0 },
    { label: '0–30 days', filter: (d) => d >= 0 && d <= 30 },
    { label: '31–60 days', filter: (d) => d > 30 && d <= 60 },
    { label: '61–90 days', filter: (d) => d > 60 && d <= 90 },
    { label: '91+ days / no expiry', filter: (d) => d > 90 }
  ]
  const rows = buckets.map((b) => {
    const items = expiring.value.filter((s) => b.filter(daysUntil(s.expiry_date)))
    const value = sum(items, (s) => num(s.cost_price) * num(s.total_quantity ?? s.quantity))
    return { bucket: b.label, items: items.length, value: formatMoney(value), share: inventoryCost.value ? `${((value / inventoryCost.value) * 100).toFixed(1)}%` : '—' }
  })
  return {
    columns: [
      { key: 'bucket', title: 'Age band' },
      { key: 'items', title: 'Items', align: 'right' },
      { key: 'value', title: 'Value at cost', align: 'right' },
      { key: 'share', title: 'Share of stock', align: 'right' }
    ],
    rows,
    totals: { value: formatMoney(inventoryCost.value) },
    summary: `${formatMoney(inventoryCost.value)} of stock at cost across ${unitsOnHand.value.toLocaleString()} units; expiry watch flags ${expiring.value.length} lines.`
  }
}

function stockoutImpact() {
  const rows = lowStock.value
    .map((s) => {
      const onHand = num(s.total_quantity ?? s.quantity)
      const reorder = num(s.reorder_level)
      const gap = Math.max(0, reorder - onHand)
      const lost = gap * num(s.selling_price || s.cost_price)
      return { name: s.medication_name || s.name, onHand, reorder, gap, lost, lostText: formatMoney(lost) }
    })
    .sort((a, b) => b.lost - a.lost)
    .map((r) => ({ name: r.name, onHand: r.onHand, reorder: r.reorder, gap: r.gap, lost: r.lostText }))
  const totalLost = sum(lowStock.value, (s) => {
    const gap = Math.max(0, num(s.reorder_level) - num(s.total_quantity ?? s.quantity))
    return gap * num(s.selling_price || s.cost_price)
  })
  return {
    columns: [
      { key: 'name', title: 'Item' },
      { key: 'onHand', title: 'On hand', align: 'right' },
      { key: 'reorder', title: 'Reorder level', align: 'right' },
      { key: 'gap', title: 'Shortfall', align: 'right' },
      { key: 'lost', title: 'Opportunity cost', align: 'right' }
    ],
    rows,
    totals: { lost: formatMoney(totalLost) },
    summary: `${rows.length} items sit at or below their reorder point, representing ${formatMoney(totalLost)} of muted revenue realisation.`
  }
}

function marginBridge() {
  const prevAov = prevOrders.value ? prevRevenue.value / prevOrders.value : 0
  const price = (aov.value - prevAov) * orders.value
  const volume = (orders.value - prevOrders.value) * prevAov
  const total = revenue.value - prevRevenue.value
  const mix = total - price - volume
  return {
    columns: [
      { key: 'component', title: 'Component' },
      { key: 'value', title: 'Impact', align: 'right' },
      { key: 'share', title: 'Share of movement', align: 'right' }
    ],
    rows: [
      { component: 'Opening revenue', value: formatMoney(prevRevenue.value), share: '—' },
      { component: 'Price effect', value: formatMoney(price), share: total ? `${((price / Math.abs(total)) * 100).toFixed(0)}%` : '—' },
      { component: 'Volume effect', value: formatMoney(volume), share: total ? `${((volume / Math.abs(total)) * 100).toFixed(0)}%` : '—' },
      { component: 'Mix effect', value: formatMoney(mix), share: total ? `${((mix / Math.abs(total)) * 100).toFixed(0)}%` : '—' },
      { component: 'Closing revenue', value: formatMoney(revenue.value), share: '100%' }
    ],
    totals: { value: `Net ${formatMoney(total)}` },
    summary: `Revenue moved ${formatMoney(total)} versus the previous comparable period; price, volume and mix reconcile the movement.`
  }
}

function forecastAccuracy() {
  const f = forecast.value
  const rows = historyMonthly.value.map((b, i) => ({
    period: b.label,
    actual: formatMoney(b.value),
    fitted: formatMoney(f.fitted[i] || 0),
    error: formatMoney(num(b.value) - num(f.fitted[i] || 0))
  }))
  return {
    columns: [
      { key: 'period', title: 'Period' },
      { key: 'actual', title: 'Actual', align: 'right' },
      { key: 'fitted', title: 'Model fit', align: 'right' },
      { key: 'error', title: 'Error', align: 'right' }
    ],
    rows,
    summary: `Holt's linear trend back-test: MAPE ${f.accuracy.mape.toFixed(1)}%, RMSE ${formatMoney(f.accuracy.rmse)}, bias ${formatMoney(f.accuracy.bias)}.`
  }
}

function customerSegmentation() {
  const rows = rfm.value.summary.map((s) => ({
    segment: s.segment,
    customers: s.customers,
    revenue: formatMoney(s.revenue),
    avgSpend: formatMoney(s.avgSpend),
    recency: `${s.avgRecency}d`
  }))
  return {
    columns: [
      { key: 'segment', title: 'Segment' },
      { key: 'customers', title: 'Customers', align: 'right' },
      { key: 'revenue', title: 'Revenue', align: 'right' },
      { key: 'avgSpend', title: 'Avg spend', align: 'right' },
      { key: 'recency', title: 'Avg recency', align: 'right' }
    ],
    rows,
    summary: `${customers.value} named customers segmented across ${rows.length} RFM groups.`
  }
}

function branchPerformance() {
  const total = sum(branches.value, (b) => b.value) || 1
  const rows = branches.value.map((b) => ({
    name: b.name,
    revenue: formatMoney(b.value),
    share: `${((b.value / total) * 100).toFixed(1)}%`,
    index: b.value > total / branches.value.length ? 'Above average' : 'Below average'
  }))
  return {
    columns: [
      { key: 'name', title: 'Branch' },
      { key: 'revenue', title: 'Revenue', align: 'right' },
      { key: 'share', title: 'Share', align: 'right' },
      { key: 'index', title: 'vs Network', align: 'right' }
    ],
    rows,
    totals: { revenue: formatMoney(total) },
    summary: `${rows.length} locations contributed ${formatMoney(total)} in the selected period.`
  }
}

function discountRealisation() {
  const rows = inRange.value.map((t) => {
    const gross = num(t.subtotal ?? t.total ?? t.total_amount)
    const discount = num(t.discount ?? t.discount_amount)
    return { gross, discount }
  })
  const grossTotal = sum(rows, (r) => r.gross)
  const discountTotal = sum(rows, (r) => r.discount)
  const table = historyMonthly.value.map((b, i) => {
    const bucket = inRange.value.filter((t) => {
      const d = new Date(t.created_at || t.date || 0)
      return d.getFullYear() === b.y && d.getMonth() === b.m
    })
    const gross = sum(bucket, (t) => num(t.subtotal ?? t.total ?? t.total_amount))
    const disc = sum(bucket, (t) => num(t.discount ?? t.discount_amount))
    return {
      period: b.label,
      gross: formatMoney(gross),
      discount: formatMoney(disc),
      rate: gross ? `${((disc / gross) * 100).toFixed(2)}%` : '—',
      net: formatMoney(gross - disc),
      index: i + 1
    }
  })
  return {
    columns: [
      { key: 'period', title: 'Period' },
      { key: 'gross', title: 'Gross', align: 'right' },
      { key: 'discount', title: 'Discount', align: 'right' },
      { key: 'rate', title: 'Discount rate', align: 'right' },
      { key: 'net', title: 'Net revenue', align: 'right' }
    ],
    rows: table.reverse(),
    totals: { gross: formatMoney(grossTotal), discount: formatMoney(discountTotal), net: formatMoney(grossTotal - discountTotal) },
    summary: grossTotal
      ? `Average realised discount of ${((discountTotal / grossTotal) * 100).toFixed(2)}% reduced gross revenue by ${formatMoney(discountTotal)}.`
      : 'No explicit discount fields are present on the sales feed — net revenue equals gross revenue.'
  }
}

function categoryContribution() {
  const total = sum(categories.value, (c) => c.revenue) || 1
  const rows = categories.value.map((c) => ({
    name: c.name,
    revenue: formatMoney(c.revenue),
    units: num(c.qty).toLocaleString(),
    share: `${((c.revenue / total) * 100).toFixed(1)}%`
  }))
  return {
    columns: [
      { key: 'name', title: 'Category' },
      { key: 'revenue', title: 'Revenue', align: 'right' },
      { key: 'units', title: 'Units', align: 'right' },
      { key: 'share', title: 'Share', align: 'right' }
    ],
    rows,
    totals: { revenue: formatMoney(total) },
    summary: `${rows.length} categories contributed ${formatMoney(total)}; the leading category is ${(categories.value[0] || {}).name || '—'}.`
  }
}

function crossSellReport() {
  const rows = basket.value.map((r) => ({
    antecedent: r.a,
    consequent: r.b,
    support: `${(r.support * 100).toFixed(1)}%`,
    confidence: `${(r.confidence * 100).toFixed(0)}%`,
    lift: `${r.lift.toFixed(2)}x`
  }))
  return {
    columns: [
      { key: 'antecedent', title: 'If bought' },
      { key: 'consequent', title: 'Then also' },
      { key: 'support', title: 'Support', align: 'right' },
      { key: 'confidence', title: 'Confidence', align: 'right' },
      { key: 'lift', title: 'Lift', align: 'right' }
    ],
    rows,
    summary: `${rows.length} association rules exceeded the support and confidence thresholds.`
  }
}

function movementDrivers() {
  const total = sum(drivers.value, (d) => Math.abs(d.impact)) || 1
  const rows = drivers.value.map((d) => ({
    name: d.label,
    impact: formatMoney(d.impact),
    weight: `${((Math.abs(d.impact) / total) * 100).toFixed(0)}%`,
    direction: d.impact >= 0 ? 'Favourable' : 'Adverse'
  }))
  return {
    columns: [
      { key: 'name', title: 'Category' },
      { key: 'impact', title: 'Impact', align: 'right' },
      { key: 'weight', title: 'Share of movement', align: 'right' },
      { key: 'direction', title: 'Direction', align: 'right' }
    ],
    rows,
    summary: `${rows.length} categories contributed to the period-over-period movement.`
  }
}

const reports = [
  { key: 'sales-variance', title: 'Sales variance vs target', domain: 'Commercial', icon: 'mdi-target', color: 'teal', description: 'Monthly actual versus target with variance and MoM', build: monthlyVsTarget },
  { key: 'product-performance', title: 'Product performance', domain: 'Commercial', icon: 'mdi-trophy-outline', color: 'amber', description: 'Revenue, quantity and margin by product with ABC/XYZ', build: productPerformance },
  { key: 'category-contribution', title: 'Category contribution', domain: 'Commercial', icon: 'mdi-shape-outline', color: 'indigo', description: 'Revenue and unit share by category', build: categoryContribution },
  { key: 'discount-realisation', title: 'Discount and price realisation', domain: 'Commercial', icon: 'mdi-sale-outline', color: 'pink', description: 'Gross-to-net bridge with realised discount rate', build: discountRealisation },
  { key: 'inventory-ageing', title: 'Inventory ageing and valuation', domain: 'Inventory', icon: 'mdi-calendar-range', color: 'orange', description: 'Stock valuation by expiry band', build: inventoryAgeing },
  { key: 'stockout-impact', title: 'Stockout impact', domain: 'Inventory', icon: 'mdi-package-variant-remove', color: 'red', description: 'Opportunity cost of unavailable stock', build: stockoutImpact },
  { key: 'margin-bridge', title: 'Revenue bridge (price, volume, mix)', domain: 'Finance', icon: 'mdi-waterfall', color: 'cyan', description: 'Decomposition of the revenue movement', build: marginBridge },
  { key: 'movement-drivers', title: 'Movement drivers', domain: 'Finance', icon: 'mdi-chart-waterfall', color: 'deep-purple', description: 'Category contribution to the period change', build: movementDrivers },
  { key: 'forecast-accuracy', title: 'Forecast accuracy', domain: 'Predictive', icon: 'mdi-chart-timeline-variant-shimmer', color: 'indigo', description: 'Back-tested fit and error statistics', build: forecastAccuracy },
  { key: 'customer-segmentation', title: 'Customer segmentation', domain: 'Customer', icon: 'mdi-account-group-outline', color: 'deep-purple', description: 'RFM segment distribution and value', build: customerSegmentation },
  { key: 'cross-sell', title: 'Cross-sell associations', domain: 'Customer', icon: 'mdi-vector-combine', color: 'teal', description: 'Market-basket rules ranked by lift', build: crossSellReport },
  { key: 'branch-performance', title: 'Branch performance', domain: 'Operations', icon: 'mdi-store-marker-outline', color: 'blue', description: 'Revenue, share and index versus network', build: branchPerformance }
]

const groupedReports = computed(() => {
  const q = search.value.toLowerCase()
  const filtered = q
    ? reports.filter((r) => r.title.toLowerCase().includes(q) || r.domain.toLowerCase().includes(q) || r.description.toLowerCase().includes(q))
    : reports
  const map = new Map()
  for (const r of filtered) {
    if (!map.has(r.domain)) map.set(r.domain, [])
    map.get(r.domain).push(r)
  }
  return [...map.entries()].map(([domain, items]) => ({ domain, items }))
})

const current = computed(() => reports.find((r) => r.key === activeReport.value) || reports[0])

const preview = computed(() => {
  const built = current.value.build()
  return { columns: built.columns || [], rows: built.rows || [], totals: built.totals || null, summary: built.summary || '' }
})

const topShare = computed(() => {
  const top = products.value.slice(0, 10)
  const total = sum(products.value, (p) => p.revenue) || 1
  return (sum(top, (p) => p.revenue) / total) * 100
})

function selectReport(key) {
  activeReport.value = key
  generatedAt.value = new Date().toLocaleString()
}

// ── runs / schedules ────────────────────────────────────────────────────
const runs = ref([])
const schedules = ref([])
if (import.meta.client) {
  try {
    const raw = localStorage.getItem('bi.schedules')
    if (raw) schedules.value = JSON.parse(raw)
    const rawRuns = localStorage.getItem('bi.runs')
    if (rawRuns) runs.value = JSON.parse(rawRuns)
  } catch { /* ignore */ }
}

const scheduleDialog = ref(false)
const frequencies = ['Daily', 'Weekly (Mon)', 'Fortnightly', 'Monthly (1st)', 'Quarterly']
const formats = ['PDF', 'Excel', 'CSV', 'Email body']
const draftSchedule = ref({ report: reports[0].title, frequency: 'Weekly (Mon)', format: 'PDF', recipients: '' })

function addSchedule() {
  const next = new Date()
  next.setDate(next.getDate() + 7)
  schedules.value.unshift({
    id: `sch-${Date.now()}`,
    report: draftSchedule.value.report,
    frequency: draftSchedule.value.frequency,
    format: draftSchedule.value.format,
    recipients: draftSchedule.value.recipients || '—',
    nextRun: next.toLocaleDateString(),
    enabled: true
  })
  persistSchedules()
  scheduleDialog.value = false
  draftSchedule.value = { report: reports[0].title, frequency: 'Weekly (Mon)', format: 'PDF', recipients: '' }
}
function removeSchedule(id) {
  schedules.value = schedules.value.filter((s) => s.id !== id)
  persistSchedules()
}
function persistSchedules() {
  if (import.meta.client) localStorage.setItem('bi.schedules', JSON.stringify(schedules.value))
}

async function runReport() {
  running.value = true
  await new Promise((resolve) => setTimeout(resolve, 650))
  runs.value.unshift({
    id: `run-${Date.now()}`,
    report: current.value.title,
    when: new Date().toLocaleString(undefined, { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }),
    format: 'PDF',
    rows: preview.value.rows.length,
    status: 'Delivered',
    color: current.value.color,
    icon: current.value.icon
  })
  running.value = false
  generatedAt.value = new Date().toLocaleString()
  if (import.meta.client) localStorage.setItem('bi.runs', JSON.stringify(runs.value.slice(0, 20)))
}

function exportCurrent() {
  downloadCsv(current.value.key, preview.value.columns.map((c) => c.key), preview.value.rows)
}
function printPreview() {
  if (import.meta.client) window.print()
}
</script>

<style scoped>
.report-preview {
  max-height: 620px;
  overflow: auto;
}
</style>
