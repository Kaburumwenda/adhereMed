<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-clipboard-text-clock</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Requisitions</div>
        <div class="text-body-2 text-medium-emphasis">
          All test requests received by the laboratory
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="r.list()">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
             to="/lab/requisitions/new">New Requisition</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-4">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.hint" class="text-caption text-medium-emphasis">{{ k.hint }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Status pills (quick filter) -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in statusFilters"
          :key="s.value || 'all'"
          :color="statusFilter === s.value ? 'primary' : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'tonal'"
          size="small"
          class="text-capitalize"
          @click="statusFilter = s.value"
        >
          {{ s.label }}
          <span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="p in priorityFilters"
          :key="p.value || 'all-pri'"
          :color="priorityFilter === p.value ? p.color : undefined"
          :variant="priorityFilter === p.value ? 'flat' : 'tonal'"
          size="small"
          class="text-capitalize"
          @click="priorityFilter = p.value"
        >
          <v-icon v-if="p.icon" size="14" start>{{ p.icon }}</v-icon>
          {{ p.label }}
        </v-chip>

        <v-spacer />

        <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
          <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by patient, test, accession, doctor…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-select
            v-model="dateFilter" :items="dateOptions"
            label="Date" variant="outlined" density="compact"
            prepend-inner-icon="mdi-calendar" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="collectionFilter" :items="collectionOptions"
            label="Collection" variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>Reset
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => $router.push(`/lab/requisitions/${item.id}`)"
        class="req-table"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.id="{ item }">
          <span class="font-monospace text-caption">REQ-{{ String(item.id).padStart(5, '0') }}</span>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="hashColor(item.patient || item.id)" size="32" class="mr-2">
              <span class="text-white text-caption font-weight-bold">
                {{ initials(item.patient_name) }}
              </span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.patient_name || '—' }}</div>
              <div v-if="item.ordered_by_name" class="text-caption text-medium-emphasis text-truncate">
                by {{ item.ordered_by_name }}
              </div>
            </div>
          </div>
        </template>
        <template #item.test_names="{ item }">
          <div class="d-flex flex-wrap ga-1" style="max-width: 380px">
            <v-chip
              v-for="(t, i) in (item.test_names || []).slice(0, 3)"
              :key="i" size="x-small" variant="tonal" color="indigo"
            >{{ t }}</v-chip>
            <v-chip
              v-if="(item.test_names || []).length > 3"
              size="x-small" variant="tonal"
            >+{{ item.test_names.length - 3 }}</v-chip>
            <span v-if="!item.test_names?.length" class="text-medium-emphasis text-caption">—</span>
          </div>
        </template>
        <template #item.priority="{ value }">
          <v-chip size="x-small" variant="flat"
                  :color="priorityColor(value)" class="text-capitalize text-white">
            <v-icon size="12" start>{{ priorityIcon(value) }}</v-icon>{{ value }}
          </v-chip>
        </template>
        <template #item.status="{ value }">
          <v-chip size="x-small" variant="tonal"
                  :color="statusColor(value)" class="text-capitalize">
            <v-icon size="12" start>{{ statusIcon(value) }}</v-icon>
            {{ statusLabel(value) }}
          </v-chip>
        </template>
        <template #item.is_home_collection="{ value }">
          <v-icon v-if="value" color="teal-darken-2" size="18">mdi-home-import-outline</v-icon>
          <v-icon v-else color="grey-lighten-1" size="18">mdi-hospital-building</v-icon>
        </template>
        <template #item.created_at="{ value }">
          <div class="text-caption">
            <div>{{ formatDate(value) }}</div>
            <div class="text-medium-emphasis">{{ relativeTime(value) }}</div>
          </div>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="View" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-eye-outline" variant="text" size="small"
                       @click="$router.push(`/lab/requisitions/${item.id}`)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-test-tube" title="Receive specimen"
                             @click="$router.push(`/lab/accessioning?order=${item.id}`)" />
                <v-list-item prepend-icon="mdi-flask-outline" title="Enter results"
                             @click="$router.push(`/lab/results?order=${item.id}`)" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print requisition"
                             @click="printRequisition(item)" />
                <v-list-item prepend-icon="mdi-cancel" title="Cancel" base-color="error"
                             @click="cancelOrder(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-clipboard-text-off-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No requisitions found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Adjust your filters or create a new lab request.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
                   to="/lab/requisitions/new">New Requisition</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Grid view -->
    <div v-else class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-clipboard-text-off-outline</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No requisitions found</div>
      </div>
      <v-row v-else dense>
        <v-col v-for="o in filtered" :key="o.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="req-card pa-3 h-100" hover
                  @click="$router.push(`/lab/requisitions/${o.id}`)">
            <div class="d-flex align-center mb-2">
              <span class="font-monospace text-caption text-medium-emphasis">
                REQ-{{ String(o.id).padStart(5, '0') }}
              </span>
              <v-spacer />
              <v-chip size="x-small" variant="flat"
                      :color="priorityColor(o.priority)" class="text-capitalize text-white">
                <v-icon size="12" start>{{ priorityIcon(o.priority) }}</v-icon>{{ o.priority }}
              </v-chip>
            </div>
            <div class="d-flex align-center">
              <v-avatar :color="hashColor(o.patient || o.id)" size="38" class="mr-3">
                <span class="text-white font-weight-bold">{{ initials(o.patient_name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ o.patient_name || '—' }}</div>
                <div v-if="o.ordered_by_name" class="text-caption text-medium-emphasis text-truncate">
                  by {{ o.ordered_by_name }}
                </div>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex flex-wrap ga-1 mb-2" style="min-height: 28px">
              <v-chip v-for="(t, i) in (o.test_names || []).slice(0, 3)"
                      :key="i" size="x-small" variant="tonal" color="indigo">{{ t }}</v-chip>
              <v-chip v-if="(o.test_names || []).length > 3" size="x-small" variant="tonal">
                +{{ o.test_names.length - 3 }}
              </v-chip>
            </div>
            <div class="d-flex align-center justify-space-between">
              <v-chip size="x-small" variant="tonal"
                      :color="statusColor(o.status)" class="text-capitalize">
                <v-icon size="12" start>{{ statusIcon(o.status) }}</v-icon>{{ statusLabel(o.status) }}
              </v-chip>
              <div class="text-caption text-medium-emphasis">
                <v-icon v-if="o.is_home_collection" size="14" color="teal-darken-2">mdi-home-import-outline</v-icon>
                {{ relativeTime(o.created_at) }}
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const { $api } = useNuxtApp()
const r = useResource('/lab/orders/')
onMounted(() => r.list())

const view = ref('table')
const statusFilter = ref(null)
const priorityFilter = ref(null)
const dateFilter = ref(null)
const collectionFilter = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const dateOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Last 7 days', value: 'week' },
  { title: 'Last 30 days', value: 'month' },
]
const collectionOptions = [
  { title: 'In-lab', value: 'lab' },
  { title: 'Home collection', value: 'home' },
]

const STATUS_META = {
  pending: { label: 'Pending', color: 'amber-darken-2', icon: 'mdi-clock-outline' },
  sample_collected: { label: 'Sample collected', color: 'cyan-darken-2', icon: 'mdi-test-tube' },
  processing: { label: 'Processing', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
  completed: { label: 'Completed', color: 'green-darken-2', icon: 'mdi-check-circle' },
  cancelled: { label: 'Cancelled', color: 'red-darken-2', icon: 'mdi-cancel' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1', icon: 'mdi-clock-outline' },
  urgent: { color: 'orange-darken-2', icon: 'mdi-alert' },
  stat: { color: 'red-darken-2', icon: 'mdi-flash' },
}

function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }
function priorityIcon(v) { return PRIORITY_META[v]?.icon || 'mdi-flag-outline' }

const headers = [
  { title: 'Req #', key: 'id', width: 110 },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Tests', key: 'test_names', sortable: false },
  { title: 'Priority', key: 'priority', width: 110 },
  { title: 'Status', key: 'status', width: 160 },
  { title: 'Site', key: 'is_home_collection', width: 70, sortable: false, align: 'center' },
  { title: 'Ordered', key: 'created_at', width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
]

const list = computed(() => r.items.value || [])

const statusFilters = computed(() => {
  const counts = list.value.reduce((acc, o) => {
    acc[o.status] = (acc[o.status] || 0) + 1
    return acc
  }, {})
  return [
    { label: 'All', value: null, count: list.value.length },
    ...Object.entries(STATUS_META).map(([v, m]) => ({
      label: m.label, value: v, count: counts[v] || 0,
    })),
  ]
})
const priorityFilters = [
  { label: 'Any priority', value: null },
  { label: 'STAT', value: 'stat', color: 'red-darken-2', icon: 'mdi-flash' },
  { label: 'Urgent', value: 'urgent', color: 'orange-darken-2', icon: 'mdi-alert' },
  { label: 'Routine', value: 'routine', color: 'grey-darken-1', icon: 'mdi-clock-outline' },
]

const filtered = computed(() => {
  let arr = r.filtered.value
  if (statusFilter.value) arr = arr.filter(o => o.status === statusFilter.value)
  if (priorityFilter.value) arr = arr.filter(o => o.priority === priorityFilter.value)
  if (collectionFilter.value === 'home') arr = arr.filter(o => o.is_home_collection)
  if (collectionFilter.value === 'lab') arr = arr.filter(o => !o.is_home_collection)
  if (dateFilter.value) {
    const now = Date.now()
    const lim = dateFilter.value === 'today' ? 86400000
      : dateFilter.value === 'week' ? 7 * 86400000
      : 30 * 86400000
    arr = arr.filter(o => o.created_at && (now - new Date(o.created_at).getTime()) <= lim)
  }
  return arr
})

const kpis = computed(() => {
  const arr = list.value
  const today = new Date().toDateString()
  const todayCount = arr.filter(o => o.created_at && new Date(o.created_at).toDateString() === today).length
  const pending = arr.filter(o => ['pending', 'sample_collected', 'processing'].includes(o.status)).length
  const stat = arr.filter(o => o.priority === 'stat' && o.status !== 'completed' && o.status !== 'cancelled').length
  const completed = arr.filter(o => o.status === 'completed').length
  return [
    { label: "Today", value: todayCount, icon: 'mdi-calendar-today', color: 'indigo', hint: 'New requisitions' },
    { label: 'In progress', value: pending, icon: 'mdi-progress-clock', color: 'blue', hint: 'Pending → processing' },
    { label: 'STAT queue', value: stat, icon: 'mdi-flash', color: 'red', hint: 'Urgent attention' },
    { label: 'Completed', value: completed, icon: 'mdi-check-circle', color: 'green', hint: 'All time' },
  ]
})

function resetFilters() {
  statusFilter.value = null
  priorityFilter.value = null
  dateFilter.value = null
  collectionFilter.value = null
  r.search.value = ''
}

function initials(name) {
  if (!name) return '?'
  const parts = name.split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function hashColor(seed) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(seed) || 0) % colors.length]
}
function relativeTime(iso) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  const d = Math.floor(h / 24)
  if (d < 30) return `${d}d ago`
  return formatDate(iso)
}

async function cancelOrder(item) {
  if (!confirm(`Cancel requisition REQ-${String(item.id).padStart(5, '0')}?`)) return
  try {
    await $api.patch(`/lab/orders/${item.id}/`, { status: 'cancelled' })
    snack.text = 'Requisition cancelled'
    snack.color = 'success'
    snack.show = true
    r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to cancel'
    snack.color = 'error'
    snack.show = true
  }
}

function printRequisition(item) {
  const w = window.open('', '_blank')
  if (!w) return
  const tests = (item.test_names || []).map(t => `<li>${t}</li>`).join('')
  w.document.write(`
    <html><head><title>REQ-${String(item.id).padStart(5, '0')}</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222}
      h1{margin:0 0 4px;font-size:22px}
      .muted{color:#666;font-size:13px}
      .row{display:flex;justify-content:space-between;margin:12px 0}
      ul{padding-left:20px}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;background:#eef;color:#225;font-size:12px}
    </style></head>
    <body>
      <h1>Lab Requisition</h1>
      <div class="muted">REQ-${String(item.id).padStart(5, '0')} · ${new Date(item.created_at).toLocaleString()}</div>
      <div class="row"><div><b>Patient:</b> ${item.patient_name || '—'}</div>
        <div><span class="badge">${item.priority?.toUpperCase()}</span></div></div>
      <div class="row"><div><b>Ordered by:</b> ${item.ordered_by_name || '—'}</div>
        <div><b>Status:</b> ${statusLabel(item.status)}</div></div>
      <h3>Tests</h3>
      <ul>${tests || '<li>—</li>'}</ul>
      ${item.clinical_notes ? `<h3>Clinical notes</h3><p>${item.clinical_notes}</p>` : ''}
    </body></html>
  `)
  w.document.close()
  w.print()
}

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['id', 'patient', 'ordered_by', 'tests', 'priority', 'status', 'home_collection', 'created_at']
  const header = cols.join(',')
  const body = rows.map(o => [
    `REQ-${String(o.id).padStart(5, '0')}`,
    `"${(o.patient_name || '').replace(/"/g, '""')}"`,
    `"${(o.ordered_by_name || '').replace(/"/g, '""')}"`,
    `"${(o.test_names || []).join('; ').replace(/"/g, '""')}"`,
    o.priority || '',
    o.status || '',
    o.is_home_collection ? 'yes' : 'no',
    o.created_at || '',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `requisitions_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.req-table :deep(tbody tr) { cursor: pointer; }
.req-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.req-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
