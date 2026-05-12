<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-microscope</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Laboratory Dashboard</div>
        <div class="text-body-2 text-medium-emphasis">
          {{ today }} · {{ auth.tenantName || 'Lab' }}
        </div>
      </div>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg"
             @click="$router.push('/lab/requisitions/new')">
        New Requisition
      </v-btn>
      <v-btn variant="outlined" prepend-icon="mdi-barcode-scan" rounded="lg"
             @click="$router.push('/lab/accessioning')">
        Accession
      </v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-4">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Workload by status -->
    <v-row class="mt-2">
      <v-col cols="12" md="7">
        <v-card flat rounded="lg" class="pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="indigo">mdi-clipboard-pulse</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Today's workload</div>
            <v-spacer />
            <v-btn size="small" variant="text" color="primary"
                   @click="$router.push('/lab/worklist')">
              Open worklist
            </v-btn>
          </div>
          <v-row dense>
            <v-col v-for="s in statusBreakdown" :key="s.label" cols="6" sm="3">
              <div class="status-tile pa-3 rounded-lg text-center">
                <div :class="`text-h5 font-weight-bold ${s.colorClass}`">{{ s.count }}</div>
                <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
              </div>
            </v-col>
          </v-row>
        </v-card>
      </v-col>

      <v-col cols="12" md="5">
        <v-card flat rounded="lg" class="pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="amber-darken-2">mdi-alert-decagram</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Quality &amp; Equipment</div>
            <v-spacer />
            <v-btn size="small" variant="text" color="primary"
                   @click="$router.push('/lab/qc')">View QC</v-btn>
          </div>
          <v-list density="compact" class="bg-transparent">
            <v-list-item prepend-icon="mdi-flask-outline" :title="`${qcToday} QC runs today`"
                         :subtitle="`${qcFails} fails / ${qcWarns} warns`" />
            <v-list-item prepend-icon="mdi-cog-transfer"
                         :title="`${instrumentsActive} instruments active`"
                         :subtitle="`${instrumentsDown} offline / maintenance`"
                         @click="$router.push('/lab/instruments')" style="cursor:pointer" />
            <v-list-item prepend-icon="mdi-cancel"
                         :title="`${rejectedCount} rejected specimens`"
                         subtitle="Review rejection reasons"
                         @click="$router.push('/lab/accessioning?status=rejected')"
                         style="cursor:pointer" />
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- Recent requisitions -->
    <v-card flat rounded="lg" class="mt-4 pa-4">
      <div class="d-flex align-center mb-3">
        <v-icon class="mr-2" color="primary">mdi-clipboard-text-clock</v-icon>
        <div class="text-subtitle-1 font-weight-medium">Recent requisitions</div>
        <v-spacer />
        <v-btn size="small" variant="text" color="primary"
               @click="$router.push('/lab/requisitions')">View all</v-btn>
      </div>
      <v-data-table :items="recentOrders" :headers="orderHeaders" density="compact"
                    :loading="loading" hide-default-footer>
        <template #item.priority="{ value }"><StatusChip :status="value" /></template>
        <template #item.status="{ value }"><StatusChip :status="value" /></template>
        <template #item.created_at="{ value }">{{ formatDateTime(value) }}</template>
      </v-data-table>
    </v-card>

    <!-- Performance snapshot -->
    <v-row class="mt-2" dense>
      <v-col cols="12" md="4">
        <v-card flat rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="deep-purple">mdi-timer-sand</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Turnaround Time</div>
          </div>
          <div class="d-flex align-end ga-2">
            <div class="text-h3 font-weight-bold">{{ tatHours }}</div>
            <div class="text-body-2 text-medium-emphasis pb-2">hrs avg</div>
          </div>
          <div class="text-caption text-medium-emphasis mt-1">
            Across {{ completedToday }} completed today
          </div>
          <v-divider class="my-3" />
          <div class="d-flex justify-space-between text-caption">
            <span class="text-medium-emphasis">STAT</span><span class="font-weight-medium">{{ statTatHours }} hrs</span>
          </div>
          <div class="d-flex justify-space-between text-caption mt-1">
            <span class="text-medium-emphasis">Routine</span><span class="font-weight-medium">{{ routineTatHours }} hrs</span>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card flat rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="green-darken-2">mdi-chart-donut</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Top tests this week</div>
          </div>
          <template v-if="topTests.length">
            <div v-for="t in topTests" :key="t.name" class="mb-2">
              <div class="d-flex justify-space-between text-body-2">
                <span class="text-truncate" style="max-width:65%">{{ t.name }}</span>
                <span class="font-weight-medium">{{ t.count }}</span>
              </div>
              <v-progress-linear :model-value="(t.count / topTestMax) * 100"
                                 height="6" rounded color="teal" class="mt-1" />
            </div>
          </template>
          <v-alert v-else type="info" variant="tonal" density="compact">
            No completed tests yet.
          </v-alert>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card flat rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="green">mdi-cash-multiple</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Revenue snapshot</div>
            <v-spacer />
            <v-btn size="small" variant="text" color="primary"
                   @click="$router.push('/lab/billing')">Billing</v-btn>
          </div>
          <div class="text-overline text-medium-emphasis">Today</div>
          <div class="text-h5 font-weight-bold">{{ formatMoney(revenueToday) }}</div>
          <v-divider class="my-3" />
          <div class="d-flex justify-space-between text-caption">
            <span class="text-medium-emphasis">This week</span>
            <span class="font-weight-medium">{{ formatMoney(revenueWeek) }}</span>
          </div>
          <div class="d-flex justify-space-between text-caption mt-1">
            <span class="text-medium-emphasis">Outstanding</span>
            <span class="font-weight-medium text-amber-darken-3">{{ formatMoney(revenueOutstanding) }}</span>
          </div>
          <div class="d-flex justify-space-between text-caption mt-1">
            <span class="text-medium-emphasis">Invoices issued</span>
            <span class="font-weight-medium">{{ invoices.length }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Modules / quick access -->
    <v-card flat rounded="lg" class="mt-4 pa-4">
      <div class="d-flex align-center mb-3">
        <v-icon class="mr-2" color="indigo">mdi-view-grid-plus</v-icon>
        <div class="text-subtitle-1 font-weight-medium">Lab modules</div>
        <v-spacer />
        <span class="text-caption text-medium-emphasis">Quick access to every workspace</span>
      </div>
      <v-row dense>
        <v-col v-for="m in modules" :key="m.path" cols="6" sm="4" md="3" lg="2">
          <v-card flat rounded="lg" class="module-tile pa-3 h-100"
                  :ripple="true" hover @click="$router.push(m.path)">
            <v-avatar :color="m.color + '-lighten-5'" size="40" class="mb-2">
              <v-icon :color="m.color + '-darken-2'">{{ m.icon }}</v-icon>
            </v-avatar>
            <div class="text-body-2 font-weight-medium">{{ m.label }}</div>
            <div class="text-caption text-medium-emphasis">{{ m.desc }}</div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Today at a glance -->
    <v-row class="mt-2" dense>
      <v-col cols="12" md="6">
        <v-card flat rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="orange-darken-2">mdi-priority-high</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Priority queue</div>
            <v-spacer />
            <v-chip size="x-small" color="red" variant="flat">{{ statQueue.length }} STAT</v-chip>
          </div>
          <template v-if="statQueue.length">
            <v-list density="compact" class="bg-transparent">
              <v-list-item v-for="o in statQueue.slice(0, 5)" :key="o.id"
                           :title="o.patient_name"
                           :subtitle="(o.test_names || []).join(', ')"
                           prepend-icon="mdi-flash"
                           @click="$router.push('/lab/requisitions/' + o.id)" style="cursor:pointer">
                <template #append>
                  <StatusChip :status="o.status" />
                </template>
              </v-list-item>
            </v-list>
          </template>
          <v-alert v-else type="success" variant="tonal" density="compact">
            No STAT orders pending. Great work!
          </v-alert>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card flat rounded="lg" class="pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="blue-darken-2">mdi-account-group</v-icon>
            <div class="text-subtitle-1 font-weight-medium">Referring partners</div>
            <v-spacer />
            <v-btn size="small" variant="text" color="primary"
                   @click="$router.push('/lab/referring/doctors')">Manage</v-btn>
          </div>
          <v-row dense>
            <v-col cols="6">
              <div class="text-overline text-medium-emphasis">Doctors</div>
              <div class="text-h5 font-weight-bold">{{ referringDoctors.length }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-overline text-medium-emphasis">Facilities</div>
              <div class="text-h5 font-weight-bold">{{ referringFacilities.length }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-overline text-medium-emphasis">Test catalog</div>
              <div class="text-h5 font-weight-bold">{{ catalogCount }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-overline text-medium-emphasis">Panels</div>
              <div class="text-h5 font-weight-bold">{{ panelCount }}</div>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatDateTime, formatMoney } from '~/utils/format'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const today = new Date().toLocaleDateString(undefined, {
  weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
})

const loading = ref(false)
const orders = ref([])
const specimens = ref([])
const qcRuns = ref([])
const instruments = ref([])
const invoices = ref([])
const catalog = ref([])
const panels = ref([])
const referringDoctors = ref([])
const referringFacilities = ref([])

async function safeGet(url) {
  try { const r = await $api.get(url); return r.data?.results || r.data || [] }
  catch { return [] }
}

async function loadAll() {
  loading.value = true
  try {
    const [o, s, q, i, inv, c, p, rd, rf] = await Promise.all([
      safeGet('/lab/orders/?ordering=-created_at'),
      safeGet('/lab/specimens/'),
      safeGet('/lab/qc/'),
      safeGet('/lab/instruments/'),
      safeGet('/lab/invoices/'),
      safeGet('/lab/catalog/'),
      safeGet('/lab/panels/'),
      safeGet('/lab/referring/doctors/'),
      safeGet('/lab/referring/facilities/'),
    ])
    orders.value = o
    specimens.value = s
    qcRuns.value = q
    instruments.value = i
    invoices.value = inv
    catalog.value = c
    panels.value = p
    referringDoctors.value = rd
    referringFacilities.value = rf
  } finally {
    loading.value = false
  }
}
onMounted(loadAll)

const kpis = computed(() => [
  { label: 'Open Orders', value: orders.value.filter(o => ['pending', 'sample_collected', 'processing'].includes(o.status)).length, icon: 'mdi-clipboard-text-clock', color: 'indigo' },
  { label: 'Specimens Today', value: specimens.value.filter(isToday).length, icon: 'mdi-test-tube', color: 'teal' },
  { label: 'Pending Verification', value: orders.value.filter(o => o.status === 'processing').length, icon: 'mdi-check-decagram', color: 'amber' },
  { label: 'STAT Orders', value: orders.value.filter(o => o.priority === 'stat').length, icon: 'mdi-flash', color: 'red' },
])

const statusBreakdown = computed(() => [
  { label: 'Pending', count: orders.value.filter(o => o.status === 'pending').length, colorClass: 'text-grey-darken-1' },
  { label: 'Collected', count: orders.value.filter(o => o.status === 'sample_collected').length, colorClass: 'text-blue-darken-2' },
  { label: 'Processing', count: orders.value.filter(o => o.status === 'processing').length, colorClass: 'text-amber-darken-2' },
  { label: 'Completed', count: orders.value.filter(o => o.status === 'completed').length, colorClass: 'text-green-darken-2' },
])

const qcToday = computed(() => qcRuns.value.filter(isTodayBy('run_at')).length)
const qcFails = computed(() => qcRuns.value.filter(r => r.result === 'fail').length)
const qcWarns = computed(() => qcRuns.value.filter(r => r.result === 'warn').length)
const instrumentsActive = computed(() => instruments.value.filter(i => i.status === 'active').length)
const instrumentsDown = computed(() => instruments.value.filter(i => ['maintenance', 'offline'].includes(i.status)).length)
const rejectedCount = computed(() => specimens.value.filter(s => s.status === 'rejected').length)

const recentOrders = computed(() => orders.value.slice(0, 8))
const orderHeaders = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Tests', key: 'test_names', value: r => (r.test_names || []).join(', ') },
  { title: 'Priority', key: 'priority' },
  { title: 'Status', key: 'status' },
  { title: 'Ordered', key: 'created_at' },
]

// --- New: TAT, top tests, revenue, queues, modules
function hoursBetween(a, b) {
  if (!a || !b) return null
  const ms = new Date(b) - new Date(a)
  return ms > 0 ? ms / 3.6e6 : null
}
const completedOrders = computed(() => orders.value.filter(o => o.status === 'completed'))
const completedToday = computed(() => completedOrders.value.filter(o => isTodayBy('completed_at')(o) || isToday(o)).length)
function avgTat(list) {
  const vals = list.map(o => hoursBetween(o.created_at, o.completed_at || o.updated_at)).filter(v => v != null)
  if (!vals.length) return '—'
  return (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1)
}
const tatHours = computed(() => avgTat(completedOrders.value))
const statTatHours = computed(() => avgTat(completedOrders.value.filter(o => o.priority === 'stat')))
const routineTatHours = computed(() => avgTat(completedOrders.value.filter(o => o.priority !== 'stat')))

const topTests = computed(() => {
  const counts = {}
  const since = Date.now() - 7 * 24 * 3.6e6
  for (const o of orders.value) {
    if (new Date(o.created_at).getTime() < since) continue
    for (const n of (o.test_names || [])) counts[n] = (counts[n] || 0) + 1
  }
  return Object.entries(counts)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5)
})
const topTestMax = computed(() => Math.max(1, ...topTests.value.map(t => t.count)))

const revenueToday = computed(() =>
  invoices.value.filter(isTodayBy('issued_at'))
    .reduce((s, i) => s + Number(i.total_amount || 0), 0))
const revenueWeek = computed(() => {
  const since = Date.now() - 7 * 24 * 3.6e6
  return invoices.value
    .filter(i => i.issued_at && new Date(i.issued_at).getTime() >= since)
    .reduce((s, i) => s + Number(i.total_amount || 0), 0)
})
const revenueOutstanding = computed(() =>
  invoices.value.reduce((s, i) => s + Number(i.balance || 0), 0))

const statQueue = computed(() => orders.value.filter(o => o.priority === 'stat' && o.status !== 'completed' && o.status !== 'cancelled'))

const catalogCount = computed(() => catalog.value.length)
const panelCount = computed(() => panels.value.length)

const modules = [
  { label: 'Requisitions', desc: 'Create & track', path: '/lab/requisitions', icon: 'mdi-clipboard-text-clock', color: 'indigo' },
  { label: 'Accessioning', desc: 'Receive samples', path: '/lab/accessioning', icon: 'mdi-barcode-scan', color: 'teal' },
  { label: 'Worklist', desc: 'Run & verify', path: '/lab/worklist', icon: 'mdi-test-tube', color: 'amber' },
  { label: 'Results', desc: 'Reports & PDFs', path: '/lab/results', icon: 'mdi-file-chart', color: 'green' },
  { label: 'Tests', desc: 'Catalog', path: '/lab/catalog', icon: 'mdi-flask-outline', color: 'blue' },
  { label: 'Panels', desc: 'Bundles', path: '/lab/panels', icon: 'mdi-package-variant', color: 'cyan' },
  { label: 'Quality Control', desc: 'QC runs', path: '/lab/qc', icon: 'mdi-chart-bell-curve-cumulative', color: 'deep-purple' },
  { label: 'Instruments', desc: 'Analyzers', path: '/lab/instruments', icon: 'mdi-cog-transfer', color: 'blue-grey' },
  { label: 'Billing', desc: 'Invoices', path: '/lab/billing', icon: 'mdi-cash-multiple', color: 'green' },
  { label: 'Home Visits', desc: 'Phlebotomy', path: '/lab/home-visits', icon: 'mdi-home-import-outline', color: 'orange' },
  { label: 'Referring Doctors', desc: 'Partners', path: '/lab/referring/doctors', icon: 'mdi-stethoscope', color: 'pink' },
  { label: 'Report Templates', desc: 'Layouts', path: '/lab/report-templates', icon: 'mdi-file-document-edit', color: 'brown' },
]

function isToday(o) {
  const d = new Date(o.created_at)
  const t = new Date()
  return d.toDateString() === t.toDateString()
}
function isTodayBy(field) {
  return (o) => {
    if (!o[field]) return false
    const d = new Date(o[field])
    return d.toDateString() === new Date().toDateString()
  }
}
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.status-tile { background: rgba(var(--v-theme-on-surface), 0.04); }
.module-tile {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.module-tile:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
}
</style>
