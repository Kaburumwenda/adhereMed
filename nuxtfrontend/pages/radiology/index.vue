<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">Radiology Dashboard</h1>
        <div class="text-body-2 text-medium-emphasis">Welcome back · {{ new Date().toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) }}</div>
      </div>
      <div class="d-flex mt-2 mt-md-0" style="gap:8px">
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/radiology/orders/new">New Order</v-btn>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="kpi in kpis" :key="kpi.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100" border>
          <div class="d-flex align-center mb-1">
            <v-avatar :color="kpi.color" variant="tonal" size="36" class="mr-3">
              <v-icon size="20">{{ kpi.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ kpi.label }}</div>
              <div class="text-h5 font-weight-bold">{{ kpi.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Today's workload -->
    <v-row class="mt-1" dense>
      <v-col v-for="s in statusTiles" :key="s.label" cols="6" sm="3" md="2">
        <v-card rounded="lg" class="pa-3 text-center h-100" :color="s.color" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ s.count }}</div>
          <div class="text-caption">{{ s.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-2">
      <!-- Recent orders table -->
      <v-col cols="12" lg="8">
        <v-card rounded="lg" class="pa-4" border>
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Recent Orders</h3>
            <v-btn variant="text" class="text-none" color="primary" to="/radiology/orders">View all</v-btn>
          </div>
          <v-table v-if="recentOrders.length" density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th>Patient</th>
                <th>Exam</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="o in recentOrders" :key="o.id">
                <td class="font-weight-medium">{{ o.patient_name }}</td>
                <td>{{ o.body_part }} ({{ o.imaging_type_display || o.imaging_type }})</td>
                <td><v-chip size="x-small" :color="o.priority === 'stat' ? 'error' : o.priority === 'urgent' ? 'warning' : 'info'" variant="tonal">{{ o.priority_display || o.priority }}</v-chip></td>
                <td><StatusChip :status="o.status" /></td>
                <td class="text-medium-emphasis">{{ formatDate(o.created_at) }}</td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-clipboard-text-clock" title="No orders yet" message="Create your first radiology order" />
        </v-card>
      </v-col>

      <!-- Sidebar -->
      <v-col cols="12" lg="4">
        <!-- STAT / urgent queue -->
        <v-card rounded="lg" class="pa-4 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon color="error" class="mr-1">mdi-alert-circle</v-icon>Priority Queue
          </h3>
          <div v-if="!statOrders.length" class="text-body-2 text-medium-emphasis">No STAT/urgent orders</div>
          <v-list v-else density="compact" class="bg-transparent">
            <v-list-item v-for="o in statOrders" :key="o.id" :to="`/radiology/orders/${o.id}`" class="px-0">
              <v-list-item-title class="text-body-2 font-weight-medium">{{ o.patient_name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ o.body_part }} · {{ o.imaging_type_display || o.imaging_type }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="o.priority === 'stat' ? 'error' : 'warning'" variant="flat">{{ o.priority }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-card>

        <!-- Modalities summary -->
        <v-card rounded="lg" class="pa-4 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon color="primary" class="mr-1">mdi-cog-transfer</v-icon>Equipment
          </h3>
          <div v-if="!modalities.length" class="text-body-2 text-medium-emphasis">No equipment configured</div>
          <v-list v-else density="compact" class="bg-transparent">
            <v-list-item v-for="m in modalities.slice(0, 6)" :key="m.id" class="px-0">
              <v-list-item-title class="text-body-2">{{ m.name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ m.modality_type_display }} · {{ m.room_location || '—' }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="m.is_active ? 'success' : 'error'" variant="tonal">{{ m.is_active ? 'Active' : 'Offline' }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-card>

        <!-- Revenue snapshot -->
        <v-card rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon color="success" class="mr-1">mdi-cash-multiple</v-icon>Revenue This Month
          </h3>
          <div class="text-h5 font-weight-bold text-success">{{ formatMoney(monthRevenue) }}</div>
          <div class="text-caption text-medium-emphasis">{{ invoices.length }} invoices</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Quick-access modules grid -->
    <h3 class="text-h6 font-weight-bold mt-6 mb-3">Modules</h3>
    <v-row dense>
      <v-col v-for="mod in modules" :key="mod.path" cols="6" sm="4" md="3" lg="2">
        <v-card :to="mod.path" rounded="lg" class="pa-4 text-center h-100 cursor-pointer" border hover>
          <v-icon :color="mod.color" size="32" class="mb-2">{{ mod.icon }}</v-icon>
          <div class="text-body-2 font-weight-medium">{{ mod.label }}</div>
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
const modalities = ref([])
const invoices = ref([])

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

const recentOrders = computed(() => orders.value.slice(0, 10))
const statOrders = computed(() =>
  orders.value.filter(o => ['stat', 'urgent'].includes(o.priority) && !['completed', 'cancelled'].includes(o.status)).slice(0, 8)
)

const kpis = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  const todayOrders = orders.value.filter(o => (o.created_at || '').startsWith(today))
  const pending = orders.value.filter(o => o.status === 'pending').length
  const completed = orders.value.filter(o => o.status === 'completed').length
  const critical = orders.value.filter(o => o.report?.critical_finding).length
  return [
    { label: "Today's Orders", value: todayOrders.length, icon: 'mdi-clipboard-text-clock', color: 'primary' },
    { label: 'Pending', value: pending, icon: 'mdi-clock-outline', color: 'warning' },
    { label: 'Completed', value: completed, icon: 'mdi-check-circle', color: 'success' },
    { label: 'Critical Findings', value: critical, icon: 'mdi-alert-circle', color: 'error' },
  ]
})

const statusTiles = computed(() => {
  const counts = { pending: 0, scheduled: 0, checked_in: 0, in_progress: 0, completed: 0, cancelled: 0 }
  orders.value.forEach(o => { if (counts[o.status] !== undefined) counts[o.status]++ })
  return [
    { label: 'Pending', count: counts.pending, color: 'warning' },
    { label: 'Scheduled', count: counts.scheduled, color: 'info' },
    { label: 'Checked In', count: counts.checked_in, color: 'purple' },
    { label: 'In Progress', count: counts.in_progress, color: 'primary' },
    { label: 'Completed', count: counts.completed, color: 'success' },
    { label: 'Cancelled', count: counts.cancelled, color: 'error' },
  ]
})

const monthRevenue = computed(() => {
  const now = new Date()
  const thisMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  return invoices.value
    .filter(i => (i.created_at || '').startsWith(thisMonth))
    .reduce((s, i) => s + Number(i.total || 0), 0)
})

const modules = [
  { icon: 'mdi-clipboard-text-clock', label: 'Orders', path: '/radiology/orders', color: 'primary' },
  { icon: 'mdi-test-tube', label: 'Worklist', path: '/radiology/worklist', color: 'teal' },
  { icon: 'mdi-calendar-clock', label: 'Scheduling', path: '/radiology/scheduling', color: 'indigo' },
  { icon: 'mdi-file-chart', label: 'Reports', path: '/radiology/reports', color: 'blue' },
  { icon: 'mdi-flask-outline', label: 'Exam Catalog', path: '/radiology/catalog', color: 'purple' },
  { icon: 'mdi-package-variant', label: 'Exam Panels', path: '/radiology/panels', color: 'pink' },
  { icon: 'mdi-cog-transfer', label: 'Equipment', path: '/radiology/equipment', color: 'orange' },
  { icon: 'mdi-chart-bell-curve-cumulative', label: 'Quality Control', path: '/radiology/qc', color: 'cyan' },
  { icon: 'mdi-receipt-text', label: 'Invoices', path: '/radiology/billing', color: 'green' },
  { icon: 'mdi-stethoscope', label: 'Referring', path: '/radiology/referring/doctors', color: 'brown' },
  { icon: 'mdi-alert-octagram', label: 'Critical Findings', path: '/radiology/critical-findings', color: 'red' },
  { icon: 'mdi-chart-bar', label: 'Analytics', path: '/radiology/analytics', color: 'blue-grey' },
]

async function load() {
  loading.value = true
  try {
    const [ordRes, modRes, invRes] = await Promise.allSettled([
      $api.get('/radiology/orders/?page_size=100&ordering=-created_at'),
      $api.get('/radiology/modalities/?page_size=100'),
      $api.get('/radiology/invoices/?page_size=200'),
    ])
    orders.value = ordRes.status === 'fulfilled' ? (ordRes.value.data?.results || ordRes.value.data || []) : []
    modalities.value = modRes.status === 'fulfilled' ? (modRes.value.data?.results || modRes.value.data || []) : []
    invoices.value = invRes.status === 'fulfilled' ? (invRes.value.data?.results || invRes.value.data || []) : []
  } catch {
    orders.value = []; modalities.value = []; invoices.value = []
  }
  loading.value = false
}
onMounted(load)
</script>

<style scoped>
.cursor-pointer { cursor: pointer; }
</style>
