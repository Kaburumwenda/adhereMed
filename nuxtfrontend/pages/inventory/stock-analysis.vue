<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="primary" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-chart-line</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Stock Analysis</h1>
          <div class="text-body-2 text-medium-emphasis">Inventory health · valuation · expiry &amp; movement</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/inventory">Inventory</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpis" :key="k.title" cols="12" sm="6" md="4" lg="">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center justify-space-between mb-2">
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon>{{ k.icon }}</v-icon>
            </v-avatar>
            <v-chip v-if="k.chip" size="x-small" :color="k.chipColor || 'default'" variant="tonal">{{ k.chip }}</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis text-uppercase">{{ k.title }}</div>
          <div class="font-weight-bold mt-1 kpi-value">{{ k.value }}</div>
          <div v-if="k.hint" class="text-caption text-medium-emphasis mt-1">{{ k.hint }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Stock health donut + Top categories by value -->
    <v-row>
      <v-col cols="12" lg="5">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <h3 class="text-h6 font-weight-bold mb-1">Stock health</h3>
          <div class="text-caption text-medium-emphasis mb-3">Distribution of items by status</div>
          <EmptyState v-if="!stocks.length" icon="mdi-package-variant-closed" title="No stock data" />
          <template v-else>
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="healthSegments" :size="220">
                <div class="text-center">
                  <div class="text-caption text-medium-emphasis">SKUs</div>
                  <div class="text-h5 font-weight-bold">{{ stocks.length }}</div>
                </div>
              </DonutRing>
            </div>
            <div>
              <div v-for="s in healthSegments" :key="s.label" class="d-flex align-center mb-2">
                <span class="legend-dot" :style="{ background: s.color }"></span>
                <span class="text-body-2 ml-2 flex-grow-1">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ s.value }}</span>
                <span class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
              </div>
            </div>
          </template>
        </v-card>
      </v-col>

      <v-col cols="12" lg="7">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <h3 class="text-h6 font-weight-bold mb-1">Inventory value by category</h3>
          <div class="text-caption text-medium-emphasis mb-3">Retail value of stock on hand</div>
          <EmptyState v-if="!categoryValueRows.length" icon="mdi-shape" title="No category data" />
          <BarChart
            v-else
            :values="categoryValueRows.map(c => c.value)"
            :labels="categoryValueRows.map(c => c.name)"
            :height="260"
            color="#3b82f6"
            rotate-labels
          />
        </v-card>
      </v-col>
    </v-row>

    <!-- Expiry risk + Cost vs Retail -->
    <v-row>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <h3 class="text-h6 font-weight-bold mb-1">Expiry risk timeline</h3>
          <div class="text-caption text-medium-emphasis mb-3">Batches grouped by months until expiry</div>
          <EmptyState v-if="!expiryBuckets.some(b => b.count > 0)" icon="mdi-clock-outline" title="No expiry data" />
          <template v-else>
            <BarChart
              :values="expiryBuckets.map(b => b.count)"
              :labels="expiryBuckets.map(b => b.label)"
              :height="220"
              color="#ef4444"
            />
            <div class="d-flex flex-wrap mt-3" style="gap:14px">
              <div v-for="b in expiryBuckets" :key="b.label" class="d-flex align-center">
                <span class="legend-dot" style="background:#ef4444"></span>
                <span class="text-caption ml-2">{{ b.label }}: <strong>{{ b.count }}</strong></span>
              </div>
            </div>
          </template>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <h3 class="text-h6 font-weight-bold mb-1">Valuation overview</h3>
          <div class="text-caption text-medium-emphasis mb-3">Cost basis vs. potential retail revenue</div>
          <div class="d-flex justify-space-around text-center mb-3">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Cost</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(totalCost) }}</div>
            </div>
            <v-divider vertical />
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Retail</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(totalRetail) }}</div>
            </div>
            <v-divider vertical />
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Potential profit</div>
              <div class="text-h6 font-weight-bold text-success">{{ formatMoney(totalRetail - totalCost) }}</div>
            </div>
          </div>
          <div v-if="categoryValueRows.length" class="valuation-scroll">
            <div class="valuation-scroll__inner" :style="{ minWidth: Math.max(categoryValueRows.length * 80, 320) + 'px' }">
              <SparkArea
                :values="categoryValueRows.map(c => c.value)"
                :labels="categoryValueRows.map(c => c.name)"
                :height="180"
                color="#22c55e"
              />
            </div>
          </div>
          <EmptyState v-else icon="mdi-cash-multiple" title="No valuation data" />
        </v-card>
      </v-col>
    </v-row>

    <!-- Adjustments trend + Reasons -->
    <v-row>
      <v-col cols="12" lg="8">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center justify-space-between mb-1">
            <div>
              <h3 class="text-h6 font-weight-bold">Stock movement (last 30 days)</h3>
              <div class="text-caption text-medium-emphasis">Net daily quantity changes from adjustments</div>
            </div>
            <div class="text-right">
              <div class="text-caption text-medium-emphasis">Net</div>
              <div class="text-h6 font-weight-bold" :class="netMovement >= 0 ? 'text-success' : 'text-error'">
                {{ netMovement >= 0 ? '+' : '' }}{{ netMovement.toLocaleString() }}
              </div>
            </div>
          </div>
          <EmptyState v-if="!movementSeries.some(v => v !== 0)" icon="mdi-tune-vertical" title="No adjustments in last 30 days" />
          <SparkArea
            v-else
            :values="movementSeries"
            :labels="movementLabels"
            :height="240"
            color="#8b5cf6"
          />
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <h3 class="text-h6 font-weight-bold mb-3">Adjustment reasons</h3>
          <EmptyState v-if="!reasonSegments.length" icon="mdi-clipboard-list-outline" title="No adjustments" />
          <template v-else>
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="reasonSegments" :size="200">
                <div class="text-center">
                  <div class="text-caption text-medium-emphasis">Records</div>
                  <div class="text-h6 font-weight-bold">{{ adjustments.length }}</div>
                </div>
              </DonutRing>
            </div>
            <div>
              <div v-for="s in reasonSegments" :key="s.label" class="d-flex align-center mb-2">
                <span class="legend-dot" :style="{ background: s.color }"></span>
                <span class="text-body-2 ml-2 flex-grow-1">{{ s.label }}</span>
                <span class="text-body-2 font-weight-medium">{{ s.value }}</span>
                <span class="text-caption text-medium-emphasis ml-2">{{ s.pct }}%</span>
              </div>
            </div>
          </template>
        </v-card>
      </v-col>
    </v-row>

    <!-- Reorder list + Top valuable items -->
    <v-row>
      <v-col cols="12" lg="6">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Reorder priority</h3>
            <v-chip size="small" color="warning" variant="tonal">{{ reorderRows.length }}</v-chip>
          </div>
          <EmptyState v-if="!reorderRows.length" icon="mdi-check-circle" title="All stock levels healthy" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right">On hand</th>
                <th class="text-right">Reorder</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in reorderRows" :key="row.id">
                <td class="font-weight-medium text-truncate" style="max-width:220px">{{ row.medication_name || '—' }}</td>
                <td class="text-right">{{ row.total_quantity }} <span class="text-caption text-medium-emphasis">{{ row.unit_abbreviation || '' }}</span></td>
                <td class="text-right">{{ row.reorder_level }}</td>
                <td>
                  <v-chip size="x-small" :color="row.total_quantity <= 0 ? 'error' : 'warning'" variant="tonal">
                    {{ row.total_quantity <= 0 ? 'Out of stock' : 'Low' }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Top items by retail value</h3>
            <v-chip size="small" color="primary" variant="tonal">Top 10</v-chip>
          </div>
          <EmptyState v-if="!topByValue.length" icon="mdi-trophy" title="No data" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th style="width:30px">#</th>
                <th>Item</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Value</th>
                <th style="width:30%">Share</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, i) in topByValue" :key="row.id">
                <td class="text-medium-emphasis">{{ i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:200px">{{ row.medication_name }}</td>
                <td class="text-right">{{ row.total_quantity }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(row.value) }}</td>
                <td>
                  <v-progress-linear
                    :model-value="row.pct"
                    :color="barColors[i % barColors.length]"
                    height="6" rounded
                  />
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

    <!-- Expiring soon list -->
    <v-row>
      <v-col cols="12">
        <v-card rounded="lg" elevation="0" class="pa-4" style="border:1px solid rgba(0,0,0,0.06)">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Expiring within 90 days</h3>
            <v-chip size="small" color="error" variant="tonal">{{ expiringRows.length }}</v-chip>
          </div>
          <EmptyState v-if="!expiringRows.length" icon="mdi-shield-check" title="No items expiring soon" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Item</th>
                <th>Batch</th>
                <th class="text-right">Quantity</th>
                <th class="text-right">Days left</th>
                <th>Expiry date</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in expiringRows" :key="`${row.stock_id}-${row.batch_id}`">
                <td class="font-weight-medium">{{ row.medication_name }}</td>
                <td class="text-medium-emphasis">{{ row.batch_number || '—' }}</td>
                <td class="text-right">{{ row.quantity_remaining }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="row.days <= 30 ? 'error' : row.days <= 60 ? 'warning' : 'info'" variant="tonal">
                    {{ row.days }}d
                  </v-chip>
                </td>
                <td>{{ formatDate(row.expiry_date) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatMoney, formatDate } from '~/utils/format'

const { $api } = useNuxtApp()

const loading = ref(false)
const stocks = ref([])
const adjustments = ref([])

const barColors = ['#3b82f6', '#22c55e', '#f59e0b', '#a855f7', '#ef4444', '#06b6d4', '#84cc16', '#ec4899', '#14b8a6', '#eab308']
const reasonColors = {
  damage: '#ef4444',
  theft: '#f97316',
  expiry: '#eab308',
  count_correction: '#3b82f6',
  return_to_supplier: '#a855f7',
  other: '#64748b'
}

async function load() {
  loading.value = true
  try {
    const [s, a] = await Promise.all([
      $api.get('/inventory/stocks/', { params: { page_size: 5000 } }).then(r => r.data?.results || r.data || []).catch(() => []),
      $api.get('/inventory/adjustments/', { params: { page_size: 5000 } }).then(r => r.data?.results || r.data || []).catch(() => [])
    ])
    stocks.value = Array.isArray(s) ? s : []
    adjustments.value = Array.isArray(a) ? a : []
  } finally {
    loading.value = false
  }
}
onMounted(load)

// ---------- KPIs ----------
const totalCost = computed(() =>
  stocks.value.reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.cost_price || 0), 0)
)
const totalRetail = computed(() =>
  stocks.value.reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
)
const totalUnits = computed(() =>
  stocks.value.reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
)
const lowCount = computed(() => stocks.value.filter(s => {
  const q = Number(s.total_quantity || 0); const r = Number(s.reorder_level || 0)
  return q > 0 && q <= r
}).length)
const outCount = computed(() => stocks.value.filter(s => Number(s.total_quantity || 0) <= 0).length)
const expiringCount = computed(() => expiringRows.value.length)

const VAT_RATE = 0.16
const totalRetailExVat = computed(() => totalRetail.value / (1 + VAT_RATE))
const totalVat = computed(() => totalRetail.value - totalRetailExVat.value)
const profitExVat = computed(() => totalRetailExVat.value - totalCost.value)

const kpis = computed(() => [
  { title: 'Total SKUs', value: stocks.value.length.toLocaleString(), icon: 'mdi-cube-outline', color: 'primary', hint: `${totalUnits.value.toLocaleString()} units on hand` },
  { title: 'Inventory cost (Before Tax)', value: formatMoney(totalCost.value), icon: 'mdi-cash', color: 'info', hint: 'Cost basis' },
  { title: 'Retail value (Inc. Tax)', value: formatMoney(totalRetail.value), icon: 'mdi-cash-multiple', color: 'success', hint: `Profit potential ${formatMoney(totalRetail.value - totalCost.value)}` },
  { title: 'Retail value (Exc. Tax)', value: formatMoney(totalRetailExVat.value), icon: 'mdi-cash-check', color: 'teal', hint: `VAT (${Math.round(VAT_RATE * 100)}%): ${formatMoney(totalVat.value)} · Expected profit: ${formatMoney(profitExVat.value)}` },
  {
    title: 'Needs attention', value: (lowCount.value + outCount.value).toLocaleString(),
    icon: 'mdi-alert-circle', color: 'warning',
    chip: outCount.value ? `${outCount.value} OOS` : null, chipColor: 'error',
    hint: `${lowCount.value} low · ${expiringCount.value} expiring`
  }
])

// ---------- Stock health ----------
const healthSegments = computed(() => {
  const out = outCount.value
  const low = lowCount.value
  const ok = stocks.value.length - out - low
  const segs = []
  if (ok)  segs.push({ label: 'In stock',     value: ok,  color: '#22c55e' })
  if (low) segs.push({ label: 'Low stock',    value: low, color: '#f59e0b' })
  if (out) segs.push({ label: 'Out of stock', value: out, color: '#ef4444' })
  const total = segs.reduce((s, x) => s + x.value, 0) || 1
  return segs.map(s => ({ ...s, pct: Math.round((s.value / total) * 100) }))
})

// ---------- Category value ----------
const categoryValueRows = computed(() => {
  const m = new Map()
  for (const s of stocks.value) {
    const key = s.category_name || 'Uncategorised'
    const v = Number(s.total_quantity || 0) * Number(s.selling_price || 0)
    m.set(key, (m.get(key) || 0) + v)
  }
  return [...m.entries()]
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value)
    .slice(0, 10)
})

// ---------- Expiry buckets ----------
const expiryBuckets = computed(() => {
  const now = Date.now()
  const buckets = [
    { label: 'Expired',   max: 0,   count: 0 },
    { label: '< 30d',     max: 30,  count: 0 },
    { label: '30–90d',    max: 90,  count: 0 },
    { label: '90–180d',   max: 180, count: 0 },
    { label: '6–12mo',    max: 365, count: 0 },
    { label: '> 1yr',     max: Infinity, count: 0 }
  ]
  for (const s of stocks.value) {
    for (const b of (s.batches || [])) {
      if (!b.expiry_date) continue
      const days = Math.floor((new Date(b.expiry_date).getTime() - now) / 86400000)
      if (days < 0) buckets[0].count++
      else if (days <= 30) buckets[1].count++
      else if (days <= 90) buckets[2].count++
      else if (days <= 180) buckets[3].count++
      else if (days <= 365) buckets[4].count++
      else buckets[5].count++
    }
  }
  return buckets
})

const expiringRows = computed(() => {
  const now = Date.now()
  const rows = []
  for (const s of stocks.value) {
    for (const b of (s.batches || [])) {
      if (!b.expiry_date || !b.quantity_remaining) continue
      const days = Math.floor((new Date(b.expiry_date).getTime() - now) / 86400000)
      if (days >= 0 && days <= 90) {
        rows.push({
          stock_id: s.id, batch_id: b.id,
          medication_name: s.medication_name,
          batch_number: b.batch_number,
          quantity_remaining: b.quantity_remaining,
          expiry_date: b.expiry_date,
          days
        })
      }
    }
  }
  return rows.sort((a, b) => a.days - b.days)
})

// ---------- Movement series (last 30 days) ----------
const movementLabels = computed(() => {
  const arr = []
  for (let i = 29; i >= 0; i--) {
    const d = new Date(); d.setDate(d.getDate() - i)
    arr.push(`${d.getMonth() + 1}/${d.getDate()}`)
  }
  return arr
})
const movementSeries = computed(() => {
  const map = new Map()
  for (let i = 29; i >= 0; i--) {
    const d = new Date(); d.setDate(d.getDate() - i)
    map.set(d.toISOString().slice(0, 10), 0)
  }
  for (const a of adjustments.value) {
    const k = (a.created_at || '').slice(0, 10)
    if (map.has(k)) map.set(k, map.get(k) + Number(a.quantity_change || 0))
  }
  return [...map.values()]
})
const netMovement = computed(() => movementSeries.value.reduce((s, v) => s + v, 0))

// ---------- Adjustment reasons ----------
const reasonSegments = computed(() => {
  const m = new Map()
  for (const a of adjustments.value) {
    const k = a.reason || 'other'
    m.set(k, (m.get(k) || 0) + 1)
  }
  const total = adjustments.value.length || 1
  return [...m.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([key, value]) => ({
      label: key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
      value,
      color: reasonColors[key] || '#94a3b8',
      pct: Math.round((value / total) * 100)
    }))
})

// ---------- Reorder priority ----------
const reorderRows = computed(() =>
  stocks.value
    .filter(s => Number(s.total_quantity || 0) <= Number(s.reorder_level || 0))
    .sort((a, b) => Number(a.total_quantity || 0) - Number(b.total_quantity || 0))
    .slice(0, 12)
)

// ---------- Top by value ----------
const topByValue = computed(() => {
  const rows = stocks.value.map(s => ({
    ...s,
    value: Number(s.total_quantity || 0) * Number(s.selling_price || 0)
  })).filter(r => r.value > 0).sort((a, b) => b.value - a.value).slice(0, 10)
  const max = rows[0]?.value || 1
  return rows.map(r => ({ ...r, pct: Math.round((r.value / max) * 100) }))
})
</script>

<style scoped>
.legend-dot { width: 10px; height: 10px; border-radius: 999px; display: inline-block; }
.kpi-value { font-size: 1.05rem; line-height: 1.25; }
@media (min-width: 960px) {
  .kpi-value { font-size: 1.49rem; line-height: 1.2; }
}
.valuation-scroll { overflow-x: auto; overflow-y: visible; padding-bottom: 28px; }
.valuation-scroll__inner { display: block; }
.valuation-scroll::-webkit-scrollbar { height: 8px; }
.valuation-scroll::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.18); border-radius: 4px; }
.valuation-scroll::-webkit-scrollbar-thumb:hover { background: rgba(0,0,0,0.32); }
</style>
