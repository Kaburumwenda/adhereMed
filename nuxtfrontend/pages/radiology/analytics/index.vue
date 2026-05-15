<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold"><v-icon class="mr-1">mdi-chart-bar</v-icon>Radiology Analytics</h1>
      <div class="d-flex" style="gap:8px">
        <v-select v-model="period" :items="periods" density="compact" variant="outlined" rounded="lg" hide-details style="max-width:180px" />
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </div>

    <!-- Top-level KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="kpi in kpis" :key="kpi.label" cols="6" sm="3">
        <v-card rounded="lg" class="pa-4 text-center" :color="kpi.color" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ kpi.value }}</div>
          <div class="text-caption">{{ kpi.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-row>
      <!-- Orders by modality -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Orders by Imaging Type</h3>
          <v-table density="compact" class="bg-transparent">
            <thead><tr><th>Type</th><th class="text-end">Count</th><th class="text-end">%</th></tr></thead>
            <tbody>
              <tr v-for="r in modalityBreakdown" :key="r.type">
                <td>{{ r.type }}</td>
                <td class="text-end font-weight-medium">{{ r.count }}</td>
                <td class="text-end">{{ r.pct }}%</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <!-- Status breakdown -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Orders by Status</h3>
          <v-table density="compact" class="bg-transparent">
            <thead><tr><th>Status</th><th class="text-end">Count</th></tr></thead>
            <tbody>
              <tr v-for="r in statusBreakdown" :key="r.status">
                <td>{{ r.status }}</td>
                <td class="text-end font-weight-medium">{{ r.count }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <!-- Revenue by payer -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Revenue by Payer Type</h3>
          <v-table density="compact" class="bg-transparent">
            <thead><tr><th>Payer</th><th class="text-end">Amount</th></tr></thead>
            <tbody>
              <tr v-for="r in payerBreakdown" :key="r.payer">
                <td>{{ r.payer }}</td>
                <td class="text-end font-weight-medium">{{ formatMoney(r.amount) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <!-- Top exams -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Top Referring Doctors</h3>
          <v-list v-if="topDoctors.length" density="compact" class="bg-transparent">
            <v-list-item v-for="d in topDoctors" :key="d.name" class="px-0">
              <v-list-item-title class="text-body-2">{{ d.name }}</v-list-item-title>
              <template #append><span class="font-weight-medium">{{ d.count }} orders</span></template>
            </v-list-item>
          </v-list>
          <div v-else class="text-body-2 text-medium-emphasis">No referring doctor data</div>
        </v-card>
      </v-col>

      <!-- QC summary -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">QC Summary</h3>
          <v-row dense>
            <v-col cols="4">
              <div class="text-center"><div class="text-h5 font-weight-bold text-success">{{ qcStats.pass }}</div><div class="text-caption">Pass</div></div>
            </v-col>
            <v-col cols="4">
              <div class="text-center"><div class="text-h5 font-weight-bold text-warning">{{ qcStats.warn }}</div><div class="text-caption">Warning</div></div>
            </v-col>
            <v-col cols="4">
              <div class="text-center"><div class="text-h5 font-weight-bold text-error">{{ qcStats.fail }}</div><div class="text-caption">Fail</div></div>
            </v-col>
          </v-row>
        </v-card>
      </v-col>

      <!-- Equipment utilization -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Equipment Utilization</h3>
          <v-table v-if="equipUtil.length" density="compact" class="bg-transparent">
            <thead><tr><th>Equipment</th><th class="text-end">Orders</th><th class="text-end">Max Slots</th></tr></thead>
            <tbody>
              <tr v-for="e in equipUtil" :key="e.name">
                <td>{{ e.name }}</td>
                <td class="text-end">{{ e.orderCount }}</td>
                <td class="text-end">{{ e.maxSlots }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-body-2 text-medium-emphasis">No equipment data</div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const loading = ref(false)
const orders = ref([])
const invoices = ref([])
const qcRecords = ref([])
const modalities = ref([])
const period = ref('this_month')
const periods = [
  { title: 'This Month', value: 'this_month' }, { title: 'Last Month', value: 'last_month' },
  { title: 'This Year', value: 'this_year' }, { title: 'All Time', value: 'all' },
]

const kpis = computed(() => {
  const totalOrders = orders.value.length
  const completedOrders = orders.value.filter(o => o.status === 'completed').length
  const totalRevenue = invoices.value.reduce((s, i) => s + Number(i.amount_paid || 0), 0)
  const criticals = orders.value.filter(o => o.report?.critical_finding).length
  return [
    { label: 'Total Orders', value: totalOrders, color: 'primary' },
    { label: 'Completed', value: completedOrders, color: 'success' },
    { label: 'Revenue Collected', value: formatMoney(totalRevenue), color: 'green' },
    { label: 'Critical Findings', value: criticals, color: 'error' },
  ]
})

const modalityBreakdown = computed(() => {
  const map = {}
  orders.value.forEach(o => { const t = o.imaging_type_display || o.imaging_type; map[t] = (map[t] || 0) + 1 })
  const total = orders.value.length || 1
  return Object.entries(map).map(([type, count]) => ({ type, count, pct: Math.round(count / total * 100) })).sort((a, b) => b.count - a.count)
})

const statusBreakdown = computed(() => {
  const map = {}
  orders.value.forEach(o => { const s = o.status_display || o.status; map[s] = (map[s] || 0) + 1 })
  return Object.entries(map).map(([status, count]) => ({ status, count })).sort((a, b) => b.count - a.count)
})

const payerBreakdown = computed(() => {
  const map = {}
  invoices.value.forEach(i => { const p = i.payer_type_display || i.payer_type; map[p] = (map[p] || 0) + Number(i.amount_paid || 0) })
  return Object.entries(map).map(([payer, amount]) => ({ payer, amount })).sort((a, b) => b.amount - a.amount)
})

const topDoctors = computed(() => {
  // Not available from order data alone; would need order-extras join
  return []
})

const qcStats = computed(() => {
  const pass = qcRecords.value.filter(r => r.status === 'pass').length
  const warn = qcRecords.value.filter(r => r.status === 'warn').length
  const fail = qcRecords.value.filter(r => r.status === 'fail').length
  return { pass, warn, fail }
})

const equipUtil = computed(() => {
  const ordersByModality = {}
  orders.value.forEach(o => { if (o.modality) ordersByModality[o.modality] = (ordersByModality[o.modality] || 0) + 1 })
  return modalities.value.map(m => ({ name: m.name, orderCount: ordersByModality[m.id] || 0, maxSlots: m.max_daily_slots }))
})

async function load() {
  loading.value = true
  try {
    const [oRes, iRes, qRes, mRes] = await Promise.allSettled([
      $api.get('/radiology/orders/?page_size=1000'),
      $api.get('/radiology/invoices/?page_size=1000'),
      $api.get('/radiology/qc/?page_size=500'),
      $api.get('/radiology/modalities/?page_size=200'),
    ])
    orders.value = oRes.status === 'fulfilled' ? oRes.value.data?.results || oRes.value.data || [] : []
    invoices.value = iRes.status === 'fulfilled' ? iRes.value.data?.results || iRes.value.data || [] : []
    qcRecords.value = qRes.status === 'fulfilled' ? qRes.value.data?.results || qRes.value.data || [] : []
    modalities.value = mRes.status === 'fulfilled' ? mRes.value.data?.results || mRes.value.data || [] : []
  } catch { }
  loading.value = false
}
onMounted(load)
</script>
