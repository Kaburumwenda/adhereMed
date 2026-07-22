<template>
  <div class="an-bg pa-4 pa-md-6">
    <HomecareHero
      title="Financial Analytics"
      subtitle="Revenue, outstanding balances, payment methods and billing category breakdown."
      eyebrow="ADMIN & MANAGEMENT · ANALYTICS"
      icon="mdi-cash-multiple"
      :chips="[
        { icon: 'mdi-cash', label: money(d.total_collected) + ' collected' },
        { icon: 'mdi-cash-clock', label: money(d.outstanding) + ' outstanding' },
        { icon: 'mdi-percent', label: (d.collection_rate || 0) + '% collection' },
        { icon: 'mdi-cash-fast', label: money(d.monthly_revenue) + ' this month' }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- KPI strip -->
    <v-row dense>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Billed" :value="money(d.total_billed)" icon="mdi-receipt-text" color="#0d9488" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Collected" :value="money(d.total_collected)" icon="mdi-cash" color="#10b981" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Outstanding" :value="money(d.outstanding)" icon="mdi-cash-clock" color="#ef4444" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Collection Rate" :value="(d.collection_rate || 0) + '%'" icon="mdi-percent" color="#f59e0b" />
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Revenue trend -->
      <v-col cols="12" lg="8">
        <HomecarePanel :title="`Revenue trend (${revenueRange})`" subtitle="Daily billed vs collected"
                       icon="mdi-chart-areaspline" color="#f59e0b">
          <template #actions>
            <v-select :model-value="revenueRange" :items="rangeOptions" density="compact" variant="outlined"
                      hide-details flat style="max-width: 140px;"
                      @update:model-value="val => onChartRangeChange('revenue', val)" />
          </template>
          <LineChart :series="[
              { label: 'Collected', color: '#10b981', values: collectedValues },
              { label: 'Billed', color: '#f59e0b', values: billedValues }
            ]"
            :labels="trendLabels" :height="260" />
        </HomecarePanel>
      </v-col>

      <!-- Bill status -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Bill status" subtitle="Bills by status"
                       icon="mdi-clipboard-list-outline" color="#6366f1">
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="statusSegments" :size="170" :thickness="20">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ billTotal }}</div>
                <div class="text-caption text-medium-emphasis">bills</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="s in statusSegments" :key="s.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Payment methods -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Payment methods" subtitle="Revenue by payment method"
                       icon="mdi-credit-card-multiple" color="#0ea5e9">
          <div class="d-flex flex-column ga-2 mt-2">
            <div v-for="m in methodBars" :key="m.label" class="d-flex align-center">
              <v-icon :icon="m.icon" :color="m.color" size="20" class="mr-3" />
              <span class="text-body-2 flex-grow-1">{{ m.label }}</span>
              <span class="font-weight-bold mr-2">{{ m.count }}</span>
              <span class="text-caption text-medium-emphasis mr-2">{{ money(m.total) }}</span>
              <v-progress-linear :model-value="m.pct" :color="m.color" rounded
                                 style="max-width:80px;" height="6" />
            </div>
            <EmptyState v-if="!methodBars.length" icon="mdi-credit-card-off" title="No payments yet" dense />
          </div>
        </HomecarePanel>
      </v-col>

      <!-- Category totals -->
      <v-col cols="12" md="6">
        <HomecarePanel title="Billing categories" subtitle="Revenue by charge type"
                       icon="mdi-shape" color="#7c3aed">
          <BarChart :values="catValues" :labels="catLabels" :colors="catColors" :height="220" />
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-3">
      <!-- Per-patient revenue analysis (expandable rows) -->
      <v-col cols="12">
        <HomecarePanel title="Revenue analysis" subtitle="Per-patient billed, collected, overdue — expand a patient to see their bills"
                       icon="mdi-account-cash" color="#0d9488">
          <template #actions>
            <v-text-field v-model="revSearch" density="compact" variant="outlined" flat
                          hide-details single-line placeholder="Search patients…"
                          prepend-inner-icon="mdi-magnify" style="max-width: 240px;" />
          </template>
          <v-table density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th style="width: 40px;"></th>
                <th class="text-left">#</th>
                <th class="text-left">Patient</th>
                <th class="text-left">MRN</th>
                <th class="text-right">Bills</th>
                <th class="text-right">Billed</th>
                <th class="text-right">Paid</th>
                <th class="text-right">Outstanding</th>
                <th class="text-center">Overdue</th>
                <th class="text-left">Last bill</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="(p, idx) in pagedRev" :key="p.id">
                <tr :class="{ 'an-row-open': expandedRev.includes(p.id) }" hover
                    style="cursor: pointer;" @click="toggleRev(p.id)">
                  <td class="text-center">
                    <v-icon size="18" :icon="expandedRev.includes(p.id) ? 'mdi-chevron-down' : 'mdi-chevron-right'" />
                  </td>
                  <td class="text-medium-emphasis">{{ revOffset + idx + 1 }}</td>
                  <td class="font-weight-medium">{{ p.name }}</td>
                  <td class="text-body-2 text-medium-emphasis">{{ p.mrn }}</td>
                  <td class="text-right">{{ p.bill_count }}</td>
                  <td class="text-right">{{ money(p.total_billed) }}</td>
                  <td class="text-right text-success">{{ money(p.amount_paid) }}</td>
                  <td class="text-right font-weight-bold" :class="p.outstanding > 0 ? 'text-error' : 'text-medium-emphasis'">
                    {{ money(p.outstanding) }}
                  </td>
                  <td class="text-center">
                    <v-chip v-if="p.overdue_count" size="small" variant="tonal" color="error">{{ p.overdue_count }}</v-chip>
                    <span v-else class="text-medium-emphasis">—</span>
                  </td>
                  <td class="text-body-2 text-medium-emphasis">{{ fmtDate(p.last_bill_date) }}</td>
                </tr>
                <tr v-if="expandedRev.includes(p.id)">
                  <td colspan="10" class="pa-0">
                    <div class="an-expand">
                      <div class="d-flex align-center ga-2 mb-2">
                        <v-icon icon="mdi-receipt-text" size="18" color="primary" />
                        <span class="text-subtitle-2 font-weight-bold">{{ p.bills.length }} bill(s) for {{ p.name }}</span>
                      </div>
                      <v-table density="compact" class="bg-transparent an-sub">
                        <thead>
                          <tr>
                            <th class="text-left">Bill #</th>
                            <th class="text-right">Total</th>
                            <th class="text-right">Paid</th>
                            <th class="text-right">Balance</th>
                            <th class="text-left">Status</th>
                            <th class="text-left">Issued</th>
                            <th class="text-left">Payments</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr v-for="b in p.bills" :key="b.id">
                            <td class="font-weight-medium">{{ b.bill_number }}</td>
                            <td class="text-right">{{ money(b.total) }}</td>
                            <td class="text-right text-success">{{ money(b.amount_paid) }}</td>
                            <td class="text-right" :class="b.balance > 0 ? 'text-error font-weight-bold' : 'text-medium-emphasis'">
                              {{ money(b.balance) }}
                            </td>
                            <td><v-chip size="small" variant="tonal" :color="billStatusColor(b.status)">{{ b.status }}</v-chip></td>
                            <td class="text-body-2 text-medium-emphasis">{{ fmtDate(b.created_at) }}</td>
                            <td>
                              <div v-if="b.payments.length" class="d-flex flex-wrap ga-1">
                                <v-chip v-for="(pay, pi) in b.payments" :key="pi" size="x-small" variant="tonal"
                                        :color="methodColor(pay.method)">
                                  {{ methodLabel(pay.method) }} · {{ money(pay.amount) }}
                                </v-chip>
                              </div>
                              <span v-else class="text-medium-emphasis text-body-2">No payments</span>
                            </td>
                          </tr>
                        </tbody>
                      </v-table>
                      <EmptyState v-if="!p.bills.length" icon="mdi-receipt-text-outline" title="No bills" dense />
                    </div>
                  </td>
                </tr>
              </template>
            </tbody>
          </v-table>
          <EmptyState v-if="!pagedRev.length" icon="mdi-account-cash" title="No patient revenue data" dense />
          <div v-if="filteredRev.length > revPageSize" class="d-flex align-center justify-center ga-2 mt-3">
            <v-btn size="small" variant="tonal" icon="mdi-chevron-left" :disabled="revPage === 1" @click="revPage--" />
            <span class="text-body-2 text-medium-emphasis">
              {{ revPage }} / {{ revPageCount }} of {{ filteredRev.length }}
            </span>
            <v-btn size="small" variant="tonal" icon="mdi-chevron-right" :disabled="revPage === revPageCount" @click="revPage++" />
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const d = ref({})
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })
const revenueRange = ref('30d')

const rangeOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Yesterday', value: 'yesterday' },
  { title: 'Last 7 days', value: '7d' },
  { title: 'Last 30 days', value: '30d' },
  { title: 'Last 90 days', value: '90d' },
  { title: 'Last year', value: '1y' },
  { title: 'All time', value: 'all' },
]

function rangeLabel(range) {
  const map = {
    today: "Today's", yesterday: "Yesterday's",
    '7d': '7-day', '30d': '30-day', '90d': '90-day',
    '1y': '1-year', all: 'All-time',
  }
  return map[range] || '30-day'
}

const trendLabels = computed(() => (d.value.revenue_trend || []).map(t => t.date.slice(5)))
const collectedValues = computed(() => (d.value.revenue_trend || []).map(t => t.collected))
const billedValues = computed(() => (d.value.revenue_trend || []).map(t => t.billed))

const statusSegments = computed(() => {
  const s = d.value.by_status || {}
  return [
    { label: 'Draft', value: s.draft || 0, color: 'grey' },
    { label: 'Issued', value: s.issued || 0, color: 'info' },
    { label: 'Partial', value: s.partial || 0, color: 'warning' },
    { label: 'Paid', value: s.paid || 0, color: 'success' },
    { label: 'Void', value: s.void || 0, color: 'error' },
  ]
})
const billTotal = computed(() => Object.values(d.value.by_status || {}).reduce((a, b) => a + b, 0))

const methodBars = computed(() => {
  const m = d.value.by_method || {}
  const maxTotal = Math.max(...Object.values(m).map(v => v.total), 1)
  const entries = [
    { label: 'Cash', key: 'cash', icon: 'mdi-cash', color: 'success' },
    { label: 'M-Pesa', key: 'mpesa', icon: 'mdi-cellphone', color: 'green' },
    { label: 'Card', key: 'card', icon: 'mdi-credit-card', color: 'blue' },
    { label: 'Bank', key: 'bank', icon: 'mdi-bank', color: 'indigo' },
    { label: 'Insurance', key: 'insurance', icon: 'mdi-shield-account', color: 'deep-orange' },
    { label: 'Other', key: 'other', icon: 'mdi-help-circle', color: 'grey' },
  ]
  return entries.map(e => {
    const v = m[e.key]
    return {
      ...e,
      count: v?.count || 0,
      total: v?.total || 0,
      pct: Math.round((v?.total || 0) / maxTotal * 100),
    }
  }).filter(e => e.count > 0)
})

const catLabels = computed(() => ['Care', 'Equipment', 'Supplies', 'Medication'])
const catValues = computed(() => {
  const c = d.value.category_totals || {}
  return [c.care || 0, c.equipment || 0, c.supplies || 0, c.medication || 0]
})
const catColors = computed(() => ['#0d9488', '#06b6d4', '#8b5cf6', '#10b981'])

function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}

// ── Per-patient revenue analysis (expandable rows) ──
const revSearch = ref('')
const revPage = ref(1)
const revPageSize = 15
const expandedRev = ref([])

function toggleRev(id) {
  const i = expandedRev.value.indexOf(id)
  if (i >= 0) expandedRev.value.splice(i, 1)
  else expandedRev.value.push(id)
}

function fmtDate(iso) {
  if (!iso) return '—'
  const dt = new Date(iso)
  return isNaN(dt) ? '—' : dt.toLocaleDateString()
}

const billStatusColorMap = { draft: 'grey', issued: 'info', partial: 'warning', paid: 'success', void: 'error' }
function billStatusColor(s) { return billStatusColorMap[s] || 'grey' }

const methodMap = {
  cash: { label: 'Cash', color: 'success' },
  mpesa: { label: 'M-Pesa', color: 'green' },
  card: { label: 'Card', color: 'blue' },
  bank: { label: 'Bank', color: 'indigo' },
  insurance: { label: 'Insurance', color: 'deep-orange' },
  other: { label: 'Other', color: 'grey' },
}
function methodLabel(m) { return methodMap[m]?.label || m }
function methodColor(m) { return methodMap[m]?.color || 'grey' }

const filteredRev = computed(() => {
  const list = d.value.patient_revenue || []
  const q = revSearch.value.trim().toLowerCase()
  if (!q) return list
  return list.filter(p =>
    (p.name || '').toLowerCase().includes(q) ||
    (p.mrn || '').toLowerCase().includes(q)
  )
})

const revPageCount = computed(() => Math.max(1, Math.ceil(filteredRev.value.length / revPageSize)))
const revOffset = computed(() => (revPage.value - 1) * revPageSize)
const pagedRev = computed(() => filteredRev.value.slice(revOffset.value, revOffset.value + revPageSize))

watch(revSearch, () => { revPage.value = 1 })

function onChartRangeChange(chart, val) {
  const ranges = { revenue: revenueRange }
  ranges[chart].value = val
  loadChart(chart)
}

async function loadChart(chart) {
  const ranges = { revenue: revenueRange }
  const dataKeys = { revenue: ['revenue_trend'] }
  const range = ranges[chart].value
  const keys = dataKeys[chart]
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/financials/', { params: { range } })
    if (data) {
      const updates = {}
      keys.forEach(k => { if (data[k] !== undefined) updates[k] = data[k] })
      d.value = { ...d.value, ...updates }
    }
  } catch {
    snack.text = 'Failed to load chart data'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/analytics/financials/', { params: { range: '30d' } })
    d.value = data || {}
    revenueRange.value = '30d'
  } catch {
    snack.text = 'Failed to load financial analytics'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(load)
</script>

<style scoped>
.an-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.05) 0%, rgba(99,102,241,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.an-filter-bar { padding: 12px 16px; background: rgba(255,255,255,0.7); border: 1px solid rgba(15,23,42,0.06); border-radius: 16px; }
:global(.v-theme--dark .an-filter-bar) { background: rgba(30,41,59,0.6); border-color: rgba(255,255,255,0.08); }
.an-row-open { background: rgba(13,148,136,0.06); }
.an-expand { padding: 16px 20px; background: rgba(15,23,42,0.025); border-left: 3px solid #0d9488; border-radius: 0 12px 12px 0; }
:global(.v-theme--dark .an-expand) { background: rgba(255,255,255,0.04); }
.an-sub { border-radius: 8px; overflow: hidden; }
</style>
