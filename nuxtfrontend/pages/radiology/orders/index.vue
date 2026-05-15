<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="deep-purple-lighten-5" size="48">
        <v-icon color="deep-purple-darken-2" size="28">mdi-clipboard-text-clock</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Radiology Orders</div>
        <div class="text-body-2 text-medium-emphasis">Manage imaging orders, track status &amp; priority</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             to="/radiology/orders/new">New Order</v-btn>
    </div>

    <!-- KPI cards -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" sm="4" md="2">
        <v-card flat rounded="lg" class="kpi-card pa-4 text-center cursor-pointer"
                :class="{ 'kpi-card--active': tabStatus === k.filter }"
                @click="tabStatus = tabStatus === k.filter ? '' : k.filter">
          <v-avatar :color="k.color" size="40" class="mb-2" variant="tonal">
            <v-icon size="22">{{ k.icon }}</v-icon>
          </v-avatar>
          <div class="text-h5 font-weight-bold">{{ k.value }}</div>
          <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
            placeholder="Search patient, body part…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterPriority" :items="priorityOptions" label="Priority"
                    variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterImaging" :items="imagingOptions" label="Imaging Type"
                    variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="2" md="2">
          <v-select v-model="filterModality" :items="modalityOptions" item-title="name" item-value="id"
                    label="Equipment" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="12" md="3" class="d-flex align-center justify-end ga-2">
          <v-btn v-if="hasFilters" variant="text" size="small" class="text-none"
                 prepend-icon="mdi-filter-off" @click="clearFilters">Clear</v-btn>
          <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="kanban" icon="mdi-view-column" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- Status tabs -->
    <v-tabs v-model="tabStatus" class="mb-3" density="compact" color="primary" show-arrows>
      <v-tab value="">All ({{ orders.length }})</v-tab>
      <v-tab v-for="s in statusOptions" :key="s.value" :value="s.value">
        {{ s.title }} ({{ orders.filter(o => o.status === s.value).length }})
      </v-tab>
    </v-tabs>

    <!-- TABLE VIEW -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="overflow-hidden">
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading"
        density="comfortable" hover items-per-page="25" class="orders-table"
        @click:row="(_, { item }) => $router.push(`/radiology/orders/${item.id}`)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-2">
            <v-avatar :color="avatarColor(item.patient)" size="34" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ patientInitials(item) }}</span>
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
        <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
        <template #item.exam_count="{ item }">
          <v-chip v-if="item.exam_names?.length" size="x-small" variant="tonal" color="indigo">
            {{ item.exam_names.length }} exam{{ item.exam_names.length > 1 ? 's' : '' }}
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.report_status="{ item }">
          <v-chip v-if="item.report" size="x-small" variant="tonal"
                  :color="item.report.report_status === 'final' ? 'success' : item.report.report_status === 'draft' ? 'grey' : 'warning'">
            {{ item.report.report_status_display || item.report.report_status }}
          </v-chip>
          <span v-else class="text-caption text-medium-emphasis">—</span>
        </template>
        <template #item.created_at="{ value }">
          <div class="text-body-2">{{ fmtDate(value) }}</div>
          <div class="text-caption text-medium-emphasis">{{ timeAgo(value) }}</div>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1" @click.stop>
            <v-btn icon="mdi-eye" size="x-small" variant="text" :to="`/radiology/orders/${item.id}`" />
            <v-btn icon="mdi-pencil" size="x-small" variant="text" :to="`/radiology/orders/${item.id}/edit`" />
          </div>
        </template>
        <template #no-data>
          <div class="pa-10 text-center">
            <v-icon size="64" color="grey-lighten-1">mdi-clipboard-text-search</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No orders found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Create your first imaging order.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/radiology/orders/new">New Order</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- KANBAN VIEW -->
    <div v-else class="kanban-container">
      <div v-for="col in kanbanCols" :key="col.value" class="kanban-col">
        <div class="kanban-col-header pa-3 mb-2 rounded-xl" :style="{ borderTop: `3px solid ${col.hc}` }">
          <div class="d-flex align-center">
            <v-icon :color="col.hc" size="18" class="mr-2">{{ col.icon }}</v-icon>
            <span class="text-subtitle-2 font-weight-bold">{{ col.title }}</span>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" :color="col.hc">{{ kanbanItems(col.value).length }}</v-chip>
          </div>
        </div>
        <div class="kanban-cards">
          <v-card v-for="o in kanbanItems(col.value)" :key="o.id" flat rounded="lg"
            class="kanban-card pa-3 mb-2 cursor-pointer" @click="$router.push(`/radiology/orders/${o.id}`)">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="avatarColor(o.patient)" size="28" class="mr-2">
                <span class="text-white" style="font-size:10px;font-weight:700">{{ patientInitials(o) }}</span>
              </v-avatar>
              <div class="text-body-2 font-weight-medium text-truncate flex-grow-1">{{ o.patient_name }}</div>
              <v-chip size="x-small" :variant="o.priority==='stat'?'flat':'tonal'" :color="priorityColor(o.priority)" class="ml-1">{{ o.priority_display }}</v-chip>
            </div>
            <div class="text-caption text-medium-emphasis mb-1">
              <v-icon size="12" class="mr-1">{{ imagingIcon(o.imaging_type) }}</v-icon>
              {{ o.imaging_type_display }} · {{ o.body_part }}
            </div>
            <div v-if="o.exam_names?.length" class="d-flex flex-wrap ga-1 mb-1">
              <v-chip v-for="e in o.exam_names.slice(0,2)" :key="e" size="x-small" variant="outlined" color="indigo">{{ e }}</v-chip>
              <v-chip v-if="o.exam_names.length > 2" size="x-small" variant="outlined">+{{ o.exam_names.length - 2 }}</v-chip>
            </div>
            <div class="d-flex align-center justify-space-between mt-2">
              <span class="text-caption text-medium-emphasis">{{ timeAgo(o.created_at) }}</span>
              <v-chip v-if="o.report" size="x-small" variant="tonal" :color="o.report.report_status==='final'?'success':'grey'">
                <v-icon size="10" start>mdi-file-document</v-icon>{{ o.report.report_status }}
              </v-chip>
            </div>
          </v-card>
          <div v-if="!kanbanItems(col.value).length" class="text-center pa-4 text-caption text-medium-emphasis">No orders</div>
        </div>
      </div>
    </div>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const orders = ref([])
const search = ref('')
const filterPriority = ref(null)
const filterImaging = ref(null)
const filterModality = ref(null)
const tabStatus = ref('')
const viewMode = ref('table')
const modalityOptions = ref([])

const statusOptions = [
  { title: 'Pending', value: 'pending' }, { title: 'Scheduled', value: 'scheduled' },
  { title: 'Checked In', value: 'checked_in' }, { title: 'In Progress', value: 'in_progress' },
  { title: 'Completed', value: 'completed' }, { title: 'Cancelled', value: 'cancelled' },
]
const priorityOptions = [
  { title: 'Routine', value: 'routine' }, { title: 'Urgent', value: 'urgent' }, { title: 'STAT', value: 'stat' },
]
const imagingOptions = [
  { title: 'X-Ray', value: 'xray' }, { title: 'CT Scan', value: 'ct' }, { title: 'MRI', value: 'mri' },
  { title: 'Ultrasound', value: 'ultrasound' }, { title: 'Mammogram', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' }, { title: 'Other', value: 'other' },
]
const headers = [
  { title: 'Patient', key: 'patient_name', width: 200 },
  { title: 'Imaging', key: 'imaging_type_display', width: 140 },
  { title: 'Body Part', key: 'body_part', width: 140 },
  { title: 'Priority', key: 'priority', align: 'center', width: 110 },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Equipment', key: 'modality_name', width: 140 },
  { title: 'Exams', key: 'exam_count', sortable: false, width: 100 },
  { title: 'Report', key: 'report_status', sortable: false, width: 110 },
  { title: 'Created', key: 'created_at', width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 90 },
]
const kanbanCols = [
  { value: 'pending', title: 'Pending', hc: '#F59E0B', icon: 'mdi-clock-outline' },
  { value: 'scheduled', title: 'Scheduled', hc: '#3B82F6', icon: 'mdi-calendar-clock' },
  { value: 'checked_in', title: 'Checked In', hc: '#6366F1', icon: 'mdi-account-check' },
  { value: 'in_progress', title: 'In Progress', hc: '#F97316', icon: 'mdi-progress-clock' },
  { value: 'completed', title: 'Completed', hc: '#10B981', icon: 'mdi-check-circle' },
]

const hasFilters = computed(() => filterPriority.value || filterImaging.value || filterModality.value || search.value)
function clearFilters() { search.value = ''; filterPriority.value = null; filterImaging.value = null; filterModality.value = null }

const filtered = computed(() => {
  let list = orders.value
  if (tabStatus.value) list = list.filter(o => o.status === tabStatus.value)
  if (filterPriority.value) list = list.filter(o => o.priority === filterPriority.value)
  if (filterImaging.value) list = list.filter(o => o.imaging_type === filterImaging.value)
  if (filterModality.value) list = list.filter(o => o.modality === filterModality.value)
  return list
})
function kanbanItems(status) { return filtered.value.filter(o => o.status === status) }

const kpis = computed(() => {
  const all = orders.value
  const today = new Date().toDateString()
  return [
    { label: 'Total', value: all.length, color: 'indigo', icon: 'mdi-clipboard-text-multiple', filter: '' },
    { label: 'Pending', value: all.filter(o => o.status === 'pending').length, color: 'warning', icon: 'mdi-clock-outline', filter: 'pending' },
    { label: 'In Progress', value: all.filter(o => o.status === 'in_progress').length, color: 'info', icon: 'mdi-progress-clock', filter: 'in_progress' },
    { label: 'Completed', value: all.filter(o => o.status === 'completed').length, color: 'success', icon: 'mdi-check-circle', filter: 'completed' },
    { label: 'STAT', value: all.filter(o => o.priority === 'stat').length, color: 'error', icon: 'mdi-alert', filter: '' },
    { label: 'Today', value: all.filter(o => new Date(o.created_at).toDateString() === today).length, color: 'deep-purple', icon: 'mdi-calendar-today', filter: '' },
  ]
})

function fmtDate(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) }
function timeAgo(d) { if (!d) return ''; const m = Math.floor((Date.now() - new Date(d).getTime()) / 60000); if (m < 1) return 'just now'; if (m < 60) return `${m}m ago`; const h = Math.floor(m / 60); if (h < 24) return `${h}h ago`; return `${Math.floor(h / 24)}d ago` }
function patientInitials(o) { const p = (o.patient_name || '').split(/\s+/).filter(Boolean); return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '?' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }
function priorityColor(p) { return p === 'stat' ? 'error' : p === 'urgent' ? 'warning' : 'info' }
function imagingColor(t) { return { xray:'blue-grey',ct:'indigo',mri:'deep-purple',ultrasound:'teal',mammogram:'pink',fluoroscopy:'amber-darken-2',other:'grey' }[t] || 'grey' }
function imagingIcon(t) { return { xray:'mdi-radiology',ct:'mdi-rotate-3d-variant',mri:'mdi-magnet',ultrasound:'mdi-waveform',mammogram:'mdi-radiology',fluoroscopy:'mdi-movie-open',other:'mdi-image' }[t] || 'mdi-radiology' }

async function load() {
  loading.value = true
  try {
    const [oRes, mRes] = await Promise.allSettled([
      $api.get('/radiology/orders/?page_size=500&ordering=-created_at'),
      $api.get('/radiology/modalities/?page_size=200'),
    ])
    orders.value = oRes.status === 'fulfilled' ? (oRes.value.data?.results || oRes.value.data || []) : []
    modalityOptions.value = mRes.status === 'fulfilled' ? (mRes.value.data?.results || mRes.value.data || []) : []
  } catch { orders.value = [] }
  loading.value = false
}
onMounted(load)
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s ease; }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
.kpi-card--active { border-color: rgb(var(--v-theme-primary)); background: rgba(var(--v-theme-primary), 0.04); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.orders-table :deep(tbody tr) { cursor: pointer; }
.kanban-container { display: flex; gap: 12px; overflow-x: auto; padding-bottom: 8px; }
.kanban-col { flex: 0 0 260px; min-width: 260px; }
.kanban-col-header { background: rgba(var(--v-theme-on-surface), 0.03); border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kanban-cards { max-height: calc(100vh - 420px); overflow-y: auto; }
.kanban-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); transition: all 0.15s ease; }
.kanban-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08); transform: translateY(-1px); }
@keyframes blink { 0%,100% { opacity: 1 } 50% { opacity: 0.3 } }
.blink { animation: blink 1.2s infinite; }
</style>
