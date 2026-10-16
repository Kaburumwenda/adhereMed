<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Delivery Performance"
      subtitle="Lead-time reliability, on-time delivery and receiving throughput"
      eyebrow="PROCUREMENT · SUPPLIER DELIVERY"
      icon="mdi-truck-delivery-outline"
      color="teal"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportDelivery">Export</v-btn>
      </template>
    </ProcToolbar>

    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3" xl="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- Lead time + throughput -->
    <v-row class="mt-1">
      <v-col cols="12" lg="7">
        <BiPanel title="Lead-time reliability" subtitle="Distribution of days from order to complete receipt" icon="mdi-timer-sand-complete" color="teal">
          <EmptyState v-if="!leadTimeBuckets.some((b) => b.count)" icon="mdi-timer-off-outline" title="No receipt history"
                      message="Lead times appear once purchase orders have been fully received." />
          <template v-else>
            <BarChart
              :values="leadTimeBuckets.map((b) => b.count)"
              :labels="leadTimeBuckets.map((b) => b.label)"
              :colors="leadTimeBuckets.map((b) => b.color)"
              :height="230"
              show-values
              :y-formatter="(v) => String(Math.round(num(v)))"
            />
            <v-divider class="my-3" />
            <v-row dense>
              <v-col v-for="m in leadTimeStats" :key="m.label" cols="6" md="3">
                <div class="text-caption text-medium-emphasis">{{ m.label }}</div>
                <div class="text-subtitle-2 font-weight-bold">{{ m.value }}</div>
              </v-col>
            </v-row>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <BiPanel title="Receiving throughput" subtitle="Goods received notes and quantities over time" icon="mdi-package-variant-closed-check" color="indigo">
          <div class="d-flex flex-wrap gap-3 mb-3 ga-4">
            <div>
              <div class="text-caption text-medium-emphasis">Total receipts</div>
              <div class="text-h6 font-weight-bold">{{ grnRows.length }}</div>
            </div>
            <div>
              <div class="text-caption text-medium-emphasis">Units received</div>
              <div class="text-h6 font-weight-bold">{{ totalGrnUnits.toLocaleString() }}</div>
            </div>
            <div>
              <div class="text-caption text-medium-emphasis">Receipt lines</div>
              <div class="text-h6 font-weight-bold">{{ totalGrnLines.toLocaleString() }}</div>
            </div>
          </div>
          <SparkArea :values="grnMonthly.map((g) => g.receipts)" :labels="grnMonthly.map((g) => g.label)" :height="160" color="#0d9488" />
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">Units received per month</div>
          <BarChart :values="grnMonthly.map((g) => g.qty)" :labels="grnMonthly.map((g) => g.label)" color="#6366f1" :height="150" :y-formatter="compactNumber" />
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Overdue + supplier reliability -->
    <v-row class="mt-1">
      <v-col cols="12" lg="5">
        <BiPanel title="Overdue by supplier" subtitle="Shipments past their promised date" icon="mdi-truck-alert" color="deep-orange">
          <template #actions>
            <v-chip size="small" color="error" variant="tonal">{{ overdueOrders.length }} overdue</v-chip>
          </template>
          <EmptyState v-if="!overdueBySupplier.length" icon="mdi-truck-check-outline" title="No overdue deliveries" />
          <v-expansion-panels v-else variant="accordion">
            <v-expansion-panel v-for="s in overdueBySupplier" :key="s.name">
              <v-expansion-panel-title>
                <div class="d-flex align-center ga-2">
                  <v-avatar size="28" color="error" variant="tonal">
                    <span class="text-caption font-weight-bold">{{ s.count }}</span>
                  </v-avatar>
                  <span class="font-weight-medium">{{ s.name }}</span>
                  <v-spacer />
                  <span class="text-caption text-medium-emphasis">{{ formatMoney(s.value) }}</span>
                  <v-chip size="x-small" color="error" variant="tonal" class="ml-2">max {{ s.maxDays }}d late</v-chip>
                </div>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <tbody>
                    <tr v-for="o in s.orders" :key="o.id">
                      <td class="text-primary font-weight-medium" style="cursor:pointer"
                          @click="navigateTo(`/ims/purchase-orders/${o.id}`)">{{ o.poNumber }}</td>
                      <td class="text-right text-error">{{ o.days }}d late</td>
                      <td class="text-right">{{ formatMoney(o.value) }}</td>
                    </tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>
          </v-expansion-panels>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="7">
        <BiPanel title="Supplier delivery reliability" subtitle="On-time percentage, lateness and lead-time consistency" icon="mdi-truck-check-outline" color="teal">
          <template #actions>
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportReliability">CSV</v-btn>
          </template>
          <EmptyState v-if="!reliabilityRows.length" icon="mdi-truck-off-outline" title="No delivery history" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Supplier</th>
                <th class="text-right">Delivered</th>
                <th class="text-right">On-time</th>
                <th class="text-right">Avg variance</th>
                <th class="text-right">Avg lead time</th>
                <th class="text-right">Consistency</th>
                <th style="width: 16%">Reliability</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in reliabilityRows" :key="s.name">
                <td class="font-weight-medium text-truncate" style="max-width: 180px">{{ s.name }}</td>
                <td class="text-right">{{ s.delivered }}</td>
                <td class="text-right">
                  <span :class="s.onTimeRate >= 90 ? 'text-success' : s.onTimeRate >= 75 ? 'text-warning' : 'text-error'" class="font-weight-medium">
                    {{ s.onTimeRate.toFixed(0) }}%
                  </span>
                </td>
                <td class="text-right" :class="s.avgVariance > 0 ? 'text-error' : 'text-success'">
                  {{ s.avgVariance > 0 ? '+' : '' }}{{ s.avgVariance.toFixed(1) }}d
                </td>
                <td class="text-right">{{ s.avgLeadTime == null ? '—' : `${s.avgLeadTime.toFixed(0)}d` }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="s.consistency >= 80 ? 'success' : s.consistency >= 60 ? 'warning' : 'error'" variant="tonal">
                    {{ s.consistency.toFixed(0) }}%
                  </v-chip>
                </td>
                <td>
                  <v-progress-linear :model-value="s.onTimeRate" :color="s.onTimeRate >= 90 ? 'success' : s.onTimeRate >= 75 ? 'warning' : 'error'" height="7" rounded />
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Delivery log -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Delivery log" subtitle="Every dated order with its actual versus promised receipt" icon="mdi-format-list-bulleted" color="primary">
          <template #actions>
            <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                      variant="solo-filled" density="compact" hide-details flat rounded="lg" bg-color="surface"
                      style="max-width: 190px" />
          </template>
          <EmptyState v-if="!filteredDelivery.length" icon="mdi-calendar-remove-outline" title="No records" />
          <v-data-table
            v-else
            :headers="deliveryHeaders"
            :items="filteredDelivery"
            :items-per-page="25"
            density="comfortable"
            hover
          >
            <template #item.po_number="{ item }">
              <span class="font-weight-bold text-primary" style="cursor:pointer"
                    @click="navigateTo(`/ims/purchase-orders/${item.id}`)">{{ item.po_number }}</span>
            </template>
            <template #item.supplier_name="{ item }">
              <span class="text-truncate" style="max-width: 170px">{{ item.supplier_name || '—' }}</span>
            </template>
            <template #item.landedCost="{ item }">{{ formatMoney(item.landedCost) }}</template>
            <template #item.order_date="{ item }">{{ formatDate(item.order_date) }}</template>
            <template #item.expected_delivery="{ item }">{{ formatDate(item.expected_delivery) }}</template>
            <template #item.receivedDate="{ item }">
              <span v-if="item.receivedDate">{{ formatDate(item.receivedDate) }}</span>
              <span v-else class="text-medium-emphasis">outstanding</span>
            </template>
            <template #item.varianceDays="{ item }">
              <span v-if="item.varianceDays == null" class="text-medium-emphasis">—</span>
              <v-chip v-else size="x-small" :color="item.onTime ? 'success' : 'error'" variant="tonal">
                {{ item.varianceDays > 0 ? '+' : '' }}{{ item.varianceDays }}d
              </v-chip>
            </template>
            <template #item.status="{ item }">
              <v-chip size="x-small" :color="deliveryStatusColor(item.status)" variant="tonal" class="text-capitalize">
                {{ item.status.replace('_', ' ') }}
              </v-chip>
            </template>
          </v-data-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- GRN log -->
    <v-row class="mt-1">
      <v-col cols="12">
        <BiPanel title="Goods received log" subtitle="Receipt events with linked purchase order" icon="mdi-clipboard-check-outline" color="cyan">
          <EmptyState v-if="!grnRows.length" icon="mdi-package-variant-remove" title="No receipts recorded" />
          <v-data-table
            v-else
            :headers="grnHeaders"
            :items="grnRows"
            :items-per-page="15"
            density="comfortable"
            hover
          >
            <template #item.grn_number="{ item }">
              <span class="font-weight-bold">{{ item.grn_number }}</span>
            </template>
            <template #item.poNumber="{ item }">
              <span class="text-primary font-weight-medium" style="cursor:pointer"
                    @click="navigateTo(`/ims/purchase-orders/${item.purchase_order}`)">{{ item.poNumber }}</span>
            </template>
            <template #item.received_date="{ item }">{{ formatDate(item.received_date) }}</template>
            <template #item.qty="{ item }">{{ num(item.qty).toLocaleString() }}</template>
            <template #item.notes="{ item }">
              <span class="text-medium-emphasis text-truncate" style="max-width: 280px">{{ item.notes || '—' }}</span>
            </template>
          </v-data-table>
        </BiPanel>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum, mean, stdDev, compactNumber, downloadCsv, round } from '~/utils/bi'

const {
  loading, deliveryRows, overdueOrders, overdueBySupplier, grnRows, grnMonthly,
  onTimeRate, otifRate, avgLeadTime, medianLeadTime, leadTimeSpread, fillRate,
  branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const statusFilter = ref('all')

const statusOptions = [
  { label: 'All deliveries', value: 'all' },
  { label: 'On time', value: 'on_time' },
  { label: 'Late', value: 'late' },
  { label: 'Outstanding', value: 'in_transit' },
  { label: 'Overdue', value: 'overdue' }
]

const deliveryHeaders = [
  { title: 'PO', key: 'po_number' },
  { title: 'Supplier', key: 'supplier_name' },
  { title: 'Value', key: 'landedCost', align: 'end' },
  { title: 'Ordered', key: 'order_date', align: 'end' },
  { title: 'Promised', key: 'expected_delivery', align: 'end' },
  { title: 'Received', key: 'receivedDate', align: 'end' },
  { title: 'Variance', key: 'varianceDays', align: 'center', sortable: false },
  { title: 'Status', key: 'status', align: 'center', sortable: false }
]

const grnHeaders = [
  { title: 'GRN', key: 'grn_number' },
  { title: 'Purchase order', key: 'poNumber' },
  { title: 'Supplier', key: 'supplierName' },
  { title: 'Lines', key: 'lineCount', align: 'end' },
  { title: 'Quantity', key: 'qty', align: 'end' },
  { title: 'Received', key: 'received_date', align: 'end' },
  { title: 'Notes', key: 'notes', sortable: false }
]

const filteredDelivery = computed(() =>
  statusFilter.value === 'all' ? deliveryRows.value : deliveryRows.value.filter((d) => d.status === statusFilter.value)
)

const totalGrnUnits = computed(() => sum(grnRows.value, (g) => g.qty))
const totalGrnLines = computed(() => sum(grnRows.value, (g) => g.lineCount))

// ── lead time distribution ──────────────────────────────────────────────
const leadTimeBuckets = computed(() => {
  const defs = [
    { label: '0–7d', min: 0, max: 7, color: '#22c55e' },
    { label: '8–14d', min: 8, max: 14, color: '#84cc16' },
    { label: '15–21d', min: 15, max: 21, color: '#eab308' },
    { label: '22–30d', min: 22, max: 30, color: '#f59e0b' },
    { label: '31–45d', min: 31, max: 45, color: '#f97316' },
    { label: '45d+', min: 46, max: Infinity, color: '#ef4444' }
  ]
  return defs.map((d) => ({
    ...d,
    count: deliveryRows.value.filter((r) => {
      if (r.varianceDays == null && !r.receivedDate) return false
      const lead = r.leadTimeDays
      return lead != null && lead >= d.min && lead <= d.max
    }).length
  }))
})

const leadTimeStats = computed(() => [
  { label: 'Average lead time', value: `${avgLeadTime.value.toFixed(1)} days` },
  { label: 'Median lead time', value: `${medianLeadTime.value.toFixed(0)} days` },
  { label: 'Standard deviation', value: `${leadTimeSpread.value.toFixed(1)} days` },
  { label: 'Longest observed', value: `${maxLeadTime.value} days` }
])

const maxLeadTime = computed(() => {
  const leads = deliveryRows.value.map((r) => r.leadTimeDays).filter((d) => d != null)
  return leads.length ? Math.max(...leads) : 0
})

// ── supplier reliability ────────────────────────────────────────────────
const reliabilityRows = computed(() => {
  const map = new Map()
  for (const d of deliveryRows.value) {
    const key = d.supplier_name || 'Unassigned'
    if (!map.has(key)) map.set(key, { name: key, delivered: 0, onTime: 0, variances: [], leads: [] })
    const row = map.get(key)
    if (d.receivedDate) {
      row.delivered += 1
      if (d.onTime) row.onTime += 1
      if (d.varianceDays != null) row.variances.push(d.varianceDays)
    }
    if (d.leadTimeDays != null) row.leads.push(d.leadTimeDays)
  }
  return [...map.values()]
    .filter((r) => r.delivered > 0)
    .map((r) => {
      const sd = r.leads.length > 1 ? stdDev(r.leads) : 0
      const avgLead = r.leads.length ? mean(r.leads) : null
      // Consistency = how tight the lead-time distribution is around its mean.
      const consistency = avgLead ? Math.max(0, 100 - (sd / Math.max(1, avgLead)) * 100) : 0
      return {
        ...r,
        onTimeRate: (r.onTime / r.delivered) * 100,
        avgVariance: r.variances.length ? mean(r.variances) : 0,
        avgLeadTime: avgLead,
        consistency
      }
    })
    .sort((a, b) => b.delivered - a.delivered)
})

const kpis = computed(() => [
  { title: 'On-time delivery', value: `${onTimeRate.value.toFixed(0)}%`, valueNum: onTimeRate.value, icon: 'mdi-truck-check-outline', color: onTimeRate.value >= 90 ? 'success' : 'warning', hint: 'By promised date' },
  { title: 'OTIF', value: `${otifRate.value.toFixed(0)}%`, valueNum: otifRate.value, icon: 'mdi-check-decagram-outline', color: otifRate.value >= 85 ? 'success' : 'warning', hint: 'On time and in full' },
  { title: 'Average lead time', value: `${avgLeadTime.value.toFixed(0)}d`, valueNum: avgLeadTime.value, icon: 'mdi-timer-sand-complete', color: 'indigo', invertDelta: true, hint: `Median ${medianLeadTime.value.toFixed(0)}d` },
  { title: 'Overdue now', value: String(overdueOrders.value.length), valueNum: overdueOrders.value.length, icon: 'mdi-truck-alert', color: 'error', invertDelta: true, hint: `${formatMoney(overdueValue.value)} at risk` },
  { title: 'Receipts logged', value: String(grnRows.value.length), valueNum: grnRows.value.length, icon: 'mdi-clipboard-check-outline', color: 'teal', hint: `${totalGrnUnits.value.toLocaleString()} units` },
  { title: 'Fill rate', value: `${fillRate.value.toFixed(0)}%`, valueNum: fillRate.value, icon: 'mdi-package-variant-closed-check', color: fillRate.value >= 95 ? 'success' : 'warning', hint: 'Ordered vs received' }
])

const overdueValue = computed(() => sum(overdueOrders.value, (o) => o.landedCost))

function deliveryStatusColor(s) {
  return s === 'on_time' ? 'success' : s === 'late' ? 'error' : s === 'overdue' ? 'deep-orange' : 'info'
}

function exportDelivery() {
  downloadCsv(
    'delivery-log',
    ['po_number', 'supplier_name', 'landedCost', 'order_date', 'expected_delivery', 'receivedDate', 'varianceDays', 'leadTimeDays', 'status'],
    filteredDelivery.value
  )
}

function exportReliability() {
  downloadCsv(
    'supplier-reliability',
    ['name', 'delivered', 'onTimeRate', 'avgVariance', 'avgLeadTime', 'consistency'],
    reliabilityRows.value.map((r) => ({
      ...r,
      onTimeRate: round(r.onTimeRate, 1),
      avgVariance: round(r.avgVariance, 2),
      avgLeadTime: r.avgLeadTime == null ? '' : round(r.avgLeadTime, 1),
      consistency: round(r.consistency, 1)
    }))
  )
}

void num
void compactNumber
</script>
