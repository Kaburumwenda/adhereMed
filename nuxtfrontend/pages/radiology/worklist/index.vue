<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="teal-lighten-5" size="48">
        <v-icon color="teal-darken-2" size="28">mdi-clipboard-list-outline</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Radiology Worklist</div>
        <div class="text-body-2 text-medium-emphasis">
          Today's active imaging queue &middot;
          <span class="font-weight-medium">{{ todayLabel }}</span>
          <span v-if="autoRefreshOn" class="ml-2 text-success"><v-icon size="12" color="success" class="mr-1 pulse">mdi-circle</v-icon>Live</span>
        </div>
      </div>
      <v-spacer />
      <v-btn-toggle v-model="autoRefreshOn" density="compact" rounded="lg" color="success" class="mr-2">
        <v-btn :value="true" size="small" class="text-none" prepend-icon="mdi-autorenew">Auto</v-btn>
      </v-btn-toggle>
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             to="/radiology/orders/new">New Order</v-btn>
    </div>

    <!-- KPI strip -->
    <div class="kpi-strip mb-4">
      <div v-for="k in kpis" :key="k.key" class="kpi-item pa-3 rounded-lg cursor-pointer"
           :class="{ 'kpi-item--active': activeFilter === k.key }"
           @click="activeFilter = activeFilter === k.key ? null : k.key">
        <div class="d-flex align-center ga-2">
          <v-avatar :color="k.color" size="36" variant="tonal">
            <v-icon size="18">{{ k.icon }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6 font-weight-bold lh-1">{{ k.count }}</div>
            <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- STAT alert banner -->
    <v-slide-y-transition>
      <v-alert v-if="statOrders.length" type="error" variant="tonal" rounded="lg" class="mb-4" density="compact" prominent>
        <template #prepend><v-icon class="blink">mdi-alert-octagon</v-icon></template>
        <strong>{{ statOrders.length }} STAT order{{ statOrders.length > 1 ? 's' : '' }}</strong> requiring immediate attention
        <template #append>
          <v-btn variant="flat" color="error" size="small" rounded="lg" class="text-none"
                 @click="activeFilter = activeFilter === 'stat' ? null : 'stat'">
            {{ activeFilter === 'stat' ? 'Show All' : 'View STAT' }}
          </v-btn>
        </template>
      </v-alert>
    </v-slide-y-transition>

    <!-- Filters & view controls -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search patient, body part…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterImaging" :items="imagingOptions" label="Imaging" variant="outlined"
            density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterModality" :items="modalityList" item-title="name" item-value="id"
            label="Equipment" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="2" md="2">
          <v-select v-model="filterPriority" :items="priorityOptions" label="Priority" variant="outlined"
            density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="12" md="3" class="d-flex align-center justify-end ga-2">
          <v-btn v-if="hasFilters" variant="text" size="small" class="text-none"
                 prepend-icon="mdi-filter-off" @click="clearFilters">Clear</v-btn>
          <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="swimlane" icon="mdi-view-column" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- TABLE VIEW -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="overflow-hidden worklist-card">
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading"
        density="comfortable" hover items-per-page="50" class="worklist-table"
        @click:row="(_, { item }) => $router.push(`/radiology/orders/${item.id}`)">
        <template #loading><v-skeleton-loader type="table-row@8" /></template>

        <!-- Urgency indicator + patient -->
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-2">
            <div class="urgency-bar mr-3" :class="`urgency-${item.priority}`" />
            <v-avatar :color="avatarColor(item.patient)" size="34" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ initials(item) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium text-body-2">{{ item.patient_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis">ID: {{ item.patient }}</div>
            </div>
          </div>
        </template>

        <template #item.imaging_type_display="{ item }">
          <v-chip size="x-small" variant="tonal" :color="imagingColor(item.imaging_type)" class="font-weight-medium">
            <v-icon size="12" start>{{ imagingIcon(item.imaging_type) }}</v-icon>
            {{ item.imaging_type_display }}
          </v-chip>
        </template>

        <template #item.priority="{ item }">
          <v-chip size="x-small" :variant="item.priority === 'stat' ? 'flat' : 'tonal'" :color="priorityColor(item.priority)">
            <v-icon v-if="item.priority === 'stat'" size="12" start class="blink">mdi-alert</v-icon>
            {{ item.priority_display }}
          </v-chip>
        </template>

        <template #item.status="{ item }">
          <StatusChip :status="item.status" />
        </template>

        <template #item.modality_name="{ value }">
          <span class="text-body-2">{{ value || '—' }}</span>
        </template>

        <template #item.wait_time="{ item }">
          <div class="d-flex align-center ga-1">
            <v-icon size="14" :color="waitColor(item)">mdi-clock-outline</v-icon>
            <span class="text-body-2" :class="waitColor(item) === 'error' ? 'text-error font-weight-bold' : ''">{{ waitTime(item) }}</span>
          </div>
        </template>

        <template #item.report_badge="{ item }">
          <v-chip v-if="item.report" size="x-small" variant="tonal"
                  :color="item.report.report_status === 'final' ? 'success' : item.report.report_status === 'draft' ? 'grey' : 'warning'">
            <v-icon size="10" start>mdi-file-document</v-icon>
            {{ item.report.report_status }}
          </v-chip>
          <span v-else class="text-caption text-medium-emphasis">—</span>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1" @click.stop>
            <!-- Quick workflow actions -->
            <v-tooltip v-if="item.status === 'pending'" text="Schedule" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-calendar-clock" size="x-small" variant="tonal" color="info"
                       @click="quickStatus(item, 'scheduled')" :loading="item._busy" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="item.status === 'scheduled'" text="Check In" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-account-check" size="x-small" variant="tonal" color="indigo"
                       @click="quickStatus(item, 'checked_in')" :loading="item._busy" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="item.status === 'checked_in'" text="Start Imaging" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-play" size="x-small" variant="tonal" color="orange"
                       @click="quickStatus(item, 'in_progress')" :loading="item._busy" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="item.status === 'in_progress'" text="Complete" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-check-circle" size="x-small" variant="tonal" color="success"
                       @click="quickStatus(item, 'completed')" :loading="item._busy" />
              </template>
            </v-tooltip>
            <v-tooltip text="View" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-eye" size="x-small" variant="text"
                       :to="`/radiology/orders/${item.id}`" />
              </template>
            </v-tooltip>
          </div>
        </template>

        <template #no-data>
          <div class="pa-10 text-center">
            <v-icon size="64" color="grey-lighten-1">mdi-clipboard-check</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">Worklist is empty</div>
            <div class="text-body-2 text-medium-emphasis mb-4">No active orders for today.</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- SWIMLANE VIEW -->
    <div v-else class="swimlane-container">
      <div v-for="lane in swimlanes" :key="lane.value" class="swimlane-col">
        <div class="swimlane-header pa-3 mb-2 rounded-xl" :style="{ borderTop: `3px solid ${lane.hc}` }">
          <div class="d-flex align-center">
            <v-icon :color="lane.hc" size="18" class="mr-2">{{ lane.icon }}</v-icon>
            <span class="text-subtitle-2 font-weight-bold">{{ lane.title }}</span>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" :color="lane.hc">{{ swimlaneItems(lane.value).length }}</v-chip>
          </div>
        </div>
        <div class="swimlane-cards">
          <v-card v-for="o in swimlaneItems(lane.value)" :key="o.id" flat rounded="lg"
            class="swimlane-card pa-3 mb-2 cursor-pointer" @click="$router.push(`/radiology/orders/${o.id}`)">
            <!-- Urgency indicator -->
            <div class="d-flex align-center mb-2">
              <div class="urgency-dot mr-2" :class="`urgency-dot-${o.priority}`" />
              <v-avatar :color="avatarColor(o.patient)" size="26" class="mr-2">
                <span class="text-white" style="font-size:10px;font-weight:700">{{ initials(o) }}</span>
              </v-avatar>
              <div class="text-body-2 font-weight-medium text-truncate flex-grow-1">{{ o.patient_name }}</div>
            </div>
            <div class="text-caption text-medium-emphasis mb-1">
              <v-icon size="12" class="mr-1">{{ imagingIcon(o.imaging_type) }}</v-icon>
              {{ o.imaging_type_display }} &middot; {{ o.body_part }}
            </div>
            <div class="d-flex align-center justify-space-between mt-2">
              <div class="d-flex align-center ga-1">
                <v-icon size="12" :color="waitColor(o)">mdi-clock-outline</v-icon>
                <span class="text-caption" :class="waitColor(o) === 'error' ? 'text-error' : 'text-medium-emphasis'">{{ waitTime(o) }}</span>
              </div>
              <v-chip size="x-small" :variant="o.priority==='stat'?'flat':'tonal'" :color="priorityColor(o.priority)">{{ o.priority_display }}</v-chip>
            </div>
            <!-- Quick action -->
            <div class="mt-2" @click.stop>
              <v-btn v-if="nextAction(o)" block size="small" variant="tonal" rounded="lg" class="text-none"
                     :color="nextAction(o).color" :prepend-icon="nextAction(o).icon"
                     :loading="o._busy" @click="quickStatus(o, nextAction(o).status)">
                {{ nextAction(o).label }}
              </v-btn>
            </div>
          </v-card>
          <div v-if="!swimlaneItems(lane.value).length" class="text-center pa-4 text-caption text-medium-emphasis">
            No orders
          </div>
        </div>
      </div>
    </div>

    <!-- Snackbar for quick actions -->
    <v-snackbar v-model="snack" :color="snackColor" rounded="lg" timeout="2500" location="bottom right">
      {{ snackMsg }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()

const loading = ref(false)
const orders = ref([])
const modalityList = ref([])
const search = ref('')
const activeFilter = ref(null)
const filterImaging = ref(null)
const filterModality = ref(null)
const filterPriority = ref(null)
const viewMode = ref('table')
const autoRefreshOn = ref(true)
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')
let refreshTimer = null

const todayLabel = new Date().toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })

const imagingOptions = [
  { title: 'X-Ray', value: 'xray' }, { title: 'CT', value: 'ct' }, { title: 'MRI', value: 'mri' },
  { title: 'Ultrasound', value: 'ultrasound' }, { title: 'Mammogram', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' }, { title: 'Other', value: 'other' },
]
const priorityOptions = [
  { title: 'Routine', value: 'routine' }, { title: 'Urgent', value: 'urgent' }, { title: 'STAT', value: 'stat' },
]

const headers = [
  { title: 'Patient', key: 'patient_name', width: 200 },
  { title: 'Imaging', key: 'imaging_type_display', width: 130 },
  { title: 'Body Part', key: 'body_part', width: 130 },
  { title: 'Priority', key: 'priority', align: 'center', width: 100 },
  { title: 'Status', key: 'status', width: 120 },
  { title: 'Equipment', key: 'modality_name', width: 130 },
  { title: 'Wait', key: 'wait_time', width: 100 },
  { title: 'Report', key: 'report_badge', sortable: false, width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

const swimlanes = [
  { value: 'pending', title: 'Pending', hc: '#F59E0B', icon: 'mdi-clock-outline' },
  { value: 'scheduled', title: 'Scheduled', hc: '#3B82F6', icon: 'mdi-calendar-clock' },
  { value: 'checked_in', title: 'Checked In', hc: '#6366F1', icon: 'mdi-account-check' },
  { value: 'in_progress', title: 'In Progress', hc: '#F97316', icon: 'mdi-progress-clock' },
  { value: 'completed', title: 'Completed', hc: '#10B981', icon: 'mdi-check-circle' },
]

// Active orders = not cancelled, primarily today's
const activeOrders = computed(() =>
  orders.value.filter(o => o.status !== 'cancelled')
)

const statOrders = computed(() =>
  activeOrders.value.filter(o => o.priority === 'stat' && !['completed', 'cancelled'].includes(o.status))
)

const kpis = computed(() => {
  const a = activeOrders.value
  return [
    { key: 'all', label: 'Total Active', count: a.length, color: 'indigo', icon: 'mdi-clipboard-text-multiple' },
    { key: 'pending', label: 'Pending', count: a.filter(o => o.status === 'pending').length, color: 'warning', icon: 'mdi-clock-outline' },
    { key: 'scheduled', label: 'Scheduled', count: a.filter(o => o.status === 'scheduled').length, color: 'blue', icon: 'mdi-calendar-clock' },
    { key: 'in_progress', label: 'In Progress', count: a.filter(o => o.status === 'in_progress').length, color: 'orange', icon: 'mdi-progress-clock' },
    { key: 'completed', label: 'Completed', count: a.filter(o => o.status === 'completed').length, color: 'success', icon: 'mdi-check-circle' },
    { key: 'stat', label: 'STAT', count: statOrders.value.length, color: 'error', icon: 'mdi-alert' },
  ]
})

const hasFilters = computed(() => search.value || filterImaging.value || filterModality.value || filterPriority.value)
function clearFilters() { search.value = ''; filterImaging.value = null; filterModality.value = null; filterPriority.value = null; activeFilter.value = null }

const filtered = computed(() => {
  let list = activeOrders.value
  if (activeFilter.value === 'stat') list = list.filter(o => o.priority === 'stat' && !['completed', 'cancelled'].includes(o.status))
  else if (activeFilter.value === 'all') { /* no further filtering */ }
  else if (activeFilter.value) list = list.filter(o => o.status === activeFilter.value)
  if (filterImaging.value) list = list.filter(o => o.imaging_type === filterImaging.value)
  if (filterModality.value) list = list.filter(o => o.modality === filterModality.value)
  if (filterPriority.value) list = list.filter(o => o.priority === filterPriority.value)
  // Sort: STAT first, then by created_at
  return [...list].sort((a, b) => {
    if (a.priority === 'stat' && b.priority !== 'stat') return -1
    if (b.priority === 'stat' && a.priority !== 'stat') return 1
    if (a.priority === 'urgent' && b.priority === 'routine') return -1
    if (b.priority === 'urgent' && a.priority === 'routine') return 1
    return new Date(a.created_at) - new Date(b.created_at)
  })
})

function swimlaneItems(status) { return filtered.value.filter(o => o.status === status) }

// Helpers
function initials(o) { const p = (o.patient_name || '').split(/\s+/).filter(Boolean); return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '?' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }
function priorityColor(p) { return p === 'stat' ? 'error' : p === 'urgent' ? 'warning' : 'info' }
function imagingColor(t) { return { xray:'blue-grey',ct:'indigo',mri:'deep-purple',ultrasound:'teal',mammogram:'pink',fluoroscopy:'amber-darken-2',other:'grey' }[t] || 'grey' }
function imagingIcon(t) { return { xray:'mdi-radiology',ct:'mdi-rotate-3d-variant',mri:'mdi-magnet',ultrasound:'mdi-waveform',mammogram:'mdi-radiology',fluoroscopy:'mdi-movie-open',other:'mdi-image' }[t] || 'mdi-radiology' }

function waitTime(o) {
  const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m`
  const h = Math.floor(mins / 60)
  if (h < 24) return `${h}h ${mins % 60}m`
  return `${Math.floor(h / 24)}d`
}
function waitColor(o) {
  if (['completed', 'cancelled'].includes(o.status)) return 'grey'
  const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000)
  if (o.priority === 'stat') return mins > 15 ? 'error' : 'warning'
  if (o.priority === 'urgent') return mins > 60 ? 'error' : mins > 30 ? 'warning' : 'grey'
  return mins > 120 ? 'error' : mins > 60 ? 'warning' : 'grey'
}

function nextAction(o) {
  const map = {
    pending: { label: 'Schedule', status: 'scheduled', icon: 'mdi-calendar-clock', color: 'info' },
    scheduled: { label: 'Check In', status: 'checked_in', icon: 'mdi-account-check', color: 'indigo' },
    checked_in: { label: 'Start Imaging', status: 'in_progress', icon: 'mdi-play', color: 'orange' },
    in_progress: { label: 'Complete', status: 'completed', icon: 'mdi-check-circle', color: 'success' },
  }
  return map[o.status] || null
}

async function quickStatus(item, status) {
  item._busy = true
  try {
    await $api.patch(`/radiology/orders/${item.id}/`, { status })
    item.status = status
    snackMsg.value = `Order #${item.id} → ${status.replace(/_/g, ' ')}`
    snackColor.value = 'success'
    snack.value = true
  } catch {
    snackMsg.value = 'Failed to update status'
    snackColor.value = 'error'
    snack.value = true
  }
  item._busy = false
}

async function load() {
  loading.value = true
  try {
    const [oRes, mRes] = await Promise.allSettled([
      $api.get('/radiology/orders/?page_size=500&ordering=-created_at'),
      $api.get('/radiology/modalities/?page_size=200'),
    ])
    orders.value = (oRes.status === 'fulfilled' ? (oRes.value.data?.results || oRes.value.data || []) : [])
      .map(o => ({ ...o, _busy: false }))
    modalityList.value = mRes.status === 'fulfilled' ? (mRes.value.data?.results || mRes.value.data || []) : []
  } catch { orders.value = [] }
  loading.value = false
}

// Auto-refresh every 30s
watch(autoRefreshOn, (val) => {
  if (val) {
    refreshTimer = setInterval(load, 30000)
  } else {
    clearInterval(refreshTimer)
    refreshTimer = null
  }
}, { immediate: true })

onMounted(load)
onUnmounted(() => { clearInterval(refreshTimer) })
</script>

<style scoped>
.kpi-strip { display: flex; gap: 10px; overflow-x: auto; padding-bottom: 4px; }
.kpi-item { flex: 1; min-width: 140px; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s ease; }
.kpi-item:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
.kpi-item--active { border-color: rgb(var(--v-theme-primary)); background: rgba(var(--v-theme-primary), 0.04); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.worklist-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.worklist-table :deep(tbody tr) { cursor: pointer; }

/* Urgency bar in table rows */
.urgency-bar { width: 4px; height: 32px; border-radius: 4px; flex-shrink: 0; }
.urgency-stat { background: #EF4444; animation: urgency-pulse 1.5s infinite; }
.urgency-urgent { background: #F59E0B; }
.urgency-routine { background: #94A3B8; }

/* Urgency dot in swimlane cards */
.urgency-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.urgency-dot-stat { background: #EF4444; animation: urgency-pulse 1.5s infinite; }
.urgency-dot-urgent { background: #F59E0B; }
.urgency-dot-routine { background: #94A3B8; }

/* Swimlane */
.swimlane-container { display: flex; gap: 12px; overflow-x: auto; padding-bottom: 8px; }
.swimlane-col { flex: 1; min-width: 260px; }
.swimlane-header { background: rgba(var(--v-theme-on-surface), 0.03); border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.swimlane-cards { max-height: calc(100vh - 380px); overflow-y: auto; }
.swimlane-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); transition: all 0.15s ease; }
.swimlane-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08); transform: translateY(-1px); }

/* Animations */
@keyframes blink { 0%,100% { opacity:1 } 50% { opacity:0.3 } }
.blink { animation: blink 1.2s infinite; }
@keyframes urgency-pulse { 0%,100% { opacity:1 } 50% { opacity:0.4 } }
.pulse { animation: urgency-pulse 2s infinite; }
.lh-1 { line-height: 1; }
</style>
