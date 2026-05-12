<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-swap-horizontal-bold</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Exchange</div>
        <div class="text-body-2 text-medium-emphasis">
          {{ isLab
            ? 'Inbound test requests from referring hospitals and doctors'
            : 'Send test requests to partner laboratories' }}
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="load()">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn v-if="!isLab" color="primary" rounded="lg"
             prepend-icon="mdi-plus" to="/lab-exchange/new">
        New Request
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
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.hint" class="text-caption text-medium-emphasis">{{ k.hint }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs (Inbox / Accepted / Completed / All) -->
    <v-card flat rounded="lg" class="mt-4">
      <v-tabs v-model="tab" color="primary" align-tabs="start" show-arrows>
        <v-tab v-for="t in tabs" :key="t.value" :value="t.value">
          <v-icon start size="18">{{ t.icon }}</v-icon>
          {{ t.label }}
          <v-chip v-if="t.count > 0" size="x-small" class="ml-2"
                  :color="tab === t.value ? 'primary' : undefined" variant="tonal">
            {{ t.count }}
          </v-chip>
        </v-tab>
      </v-tabs>
      <v-divider />

      <!-- Filter bar -->
      <div class="pa-3">
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field
              v-model="search"
              prepend-inner-icon="mdi-magnify"
              placeholder="Search by patient, doctor, source…"
              variant="outlined" density="compact" hide-details clearable
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="priorityFilter" :items="priorityOpts"
                      label="Priority" variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="dateFilter" :items="dateOpts"
                      label="Date" variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="12" md="2" class="d-flex justify-end">
            <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
              <v-btn value="cards" icon="mdi-view-grid-outline" size="small" />
              <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            </v-btn-toggle>
          </v-col>
        </v-row>
      </div>
      <v-divider />

      <!-- Cards view -->
      <div v-if="view === 'cards'" class="pa-3">
        <div v-if="loading" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="primary" />
        </div>
        <div v-else-if="!filtered.length" class="pa-8 text-center">
          <v-icon size="56" color="grey-lighten-1">mdi-inbox-outline</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-2">Nothing here yet</div>
          <div class="text-body-2 text-medium-emphasis">
            {{ isLab
              ? 'No inbound requests match the current filters.'
              : 'You haven\u2019t sent any lab requests yet.' }}
          </div>
        </div>
        <v-row v-else dense>
          <v-col v-for="x in filtered" :key="x.id" cols="12" sm="6" lg="4" xl="3">
            <v-card flat rounded="lg" class="ex-card pa-4 h-100" hover
                    @click="$router.push(`/lab-exchange/${x.id}`)">
              <div class="d-flex align-center mb-2">
                <span class="font-monospace text-caption text-medium-emphasis">
                  LX-{{ String(x.id).padStart(5, '0') }}
                </span>
                <v-spacer />
                <v-chip size="x-small" variant="flat"
                        :color="priorityColor(x.priority)" class="text-capitalize text-white">
                  <v-icon size="12" start>{{ priorityIcon(x.priority) }}</v-icon>{{ x.priority }}
                </v-chip>
              </div>
              <div class="d-flex align-center">
                <v-avatar :color="hashColor(x.patient_user_id || x.id)" size="40" class="mr-3">
                  <span class="text-white font-weight-bold">{{ initials(x.patient_name) }}</span>
                </v-avatar>
                <div class="min-width-0 flex-grow-1">
                  <div class="font-weight-medium text-truncate">{{ x.patient_name || '—' }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    <v-icon size="12">mdi-phone</v-icon> {{ x.patient_phone || 'No phone' }}
                  </div>
                </div>
              </div>
              <v-divider class="my-3" />
              <div class="text-caption text-medium-emphasis mb-1">
                <v-icon size="12">mdi-hospital-building</v-icon>
                {{ isLab ? `From ${x.source_tenant_name || '—'}` : `To ${x.lab_tenant_name || 'Unassigned'}` }}
              </div>
              <div v-if="x.ordering_doctor_name" class="text-caption text-medium-emphasis mb-2">
                <v-icon size="12">mdi-doctor</v-icon> Dr. {{ x.ordering_doctor_name }}
              </div>
              <div class="d-flex flex-wrap ga-1 mb-2" style="min-height: 26px">
                <v-chip v-for="(t, i) in (x.tests || []).slice(0, 3)" :key="i"
                        size="x-small" variant="tonal" color="indigo">
                  {{ t.test_name || t.name || t }}
                </v-chip>
                <v-chip v-if="(x.tests || []).length > 3" size="x-small" variant="tonal">
                  +{{ x.tests.length - 3 }}
                </v-chip>
              </div>
              <div class="d-flex align-center justify-space-between mt-2">
                <v-chip size="x-small" variant="tonal" :color="statusColor(x.status)" class="text-capitalize">
                  <v-icon size="12" start>{{ statusIcon(x.status) }}</v-icon>{{ statusLabel(x.status) }}
                </v-chip>
                <div class="text-caption text-medium-emphasis">
                  <v-icon v-if="x.is_home_collection" size="14" color="teal-darken-2"
                          title="Home collection">mdi-home-import-outline</v-icon>
                  {{ relativeTime(x.created_at) }}
                </div>
              </div>
              <v-divider v-if="isLab && x.status === 'pending'" class="my-3" />
              <div v-if="isLab && x.status === 'pending'" class="d-flex justify-end" @click.stop>
                <v-btn size="small" color="primary" rounded="lg" :loading="actingId === x.id"
                       prepend-icon="mdi-check" @click="acceptOne(x)">
                  Accept
                </v-btn>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </div>

      <!-- Table view -->
      <v-data-table
        v-else
        :headers="headers"
        :items="filtered"
        :loading="loading"
        :items-per-page="20"
        item-value="id"
        hover
        class="ex-table"
        @click:row="(_, { item }) => $router.push(`/lab-exchange/${item.id}`)"
      >
        <template #item.id="{ item }">
          <span class="font-monospace text-caption">LX-{{ String(item.id).padStart(5, '0') }}</span>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="hashColor(item.patient_user_id || item.id)" size="32" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.patient_name || '—' }}</div>
              <div v-if="item.patient_phone" class="text-caption text-medium-emphasis">{{ item.patient_phone }}</div>
            </div>
          </div>
        </template>
        <template #item.partner="{ item }">
          <div class="text-body-2">
            {{ isLab ? item.source_tenant_name : (item.lab_tenant_name || 'Unassigned') }}
          </div>
          <div v-if="item.ordering_doctor_name" class="text-caption text-medium-emphasis">
            Dr. {{ item.ordering_doctor_name }}
          </div>
        </template>
        <template #item.tests="{ item }">
          <div class="d-flex flex-wrap ga-1" style="max-width: 280px">
            <v-chip v-for="(t, i) in (item.tests || []).slice(0, 2)" :key="i"
                    size="x-small" variant="tonal" color="indigo">
              {{ t.test_name || t.name || t }}
            </v-chip>
            <v-chip v-if="(item.tests || []).length > 2" size="x-small" variant="tonal">
              +{{ item.tests.length - 2 }}
            </v-chip>
          </div>
        </template>
        <template #item.priority="{ value }">
          <v-chip size="x-small" variant="flat"
                  :color="priorityColor(value)" class="text-capitalize text-white">
            <v-icon size="12" start>{{ priorityIcon(value) }}</v-icon>{{ value }}
          </v-chip>
        </template>
        <template #item.status="{ value }">
          <v-chip size="x-small" variant="tonal" :color="statusColor(value)" class="text-capitalize">
            <v-icon size="12" start>{{ statusIcon(value) }}</v-icon>{{ statusLabel(value) }}
          </v-chip>
        </template>
        <template #item.created_at="{ value }">
          <div class="text-caption">
            <div>{{ formatDate(value) }}</div>
            <div class="text-medium-emphasis">{{ relativeTime(value) }}</div>
          </div>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye-outline" variant="text" size="small"
                   @click="$router.push(`/lab-exchange/${item.id}`)" />
            <v-btn v-if="isLab && item.status === 'pending'"
                   icon="mdi-check" variant="text" size="small" color="primary"
                   :loading="actingId === item.id" @click="acceptOne(item)" />
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-inbox-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No requests found</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatDate } from '~/utils/format'

const { $api } = useNuxtApp()
const auth = useAuthStore()
const isLab = computed(() => auth.tenantType === 'lab')

const items = ref([])
const loading = ref(false)
const actingId = ref(null)
const search = ref('')
const tab = ref('inbox')
const priorityFilter = ref(null)
const dateFilter = ref(null)
const view = ref('cards')
const snack = reactive({ show: false, color: 'success', text: '' })

const STATUS_META = {
  pending: { label: 'Pending', color: 'amber-darken-2', icon: 'mdi-clock-outline' },
  accepted: { label: 'Accepted', color: 'cyan-darken-2', icon: 'mdi-check' },
  sample_collected: { label: 'Collected', color: 'teal-darken-2', icon: 'mdi-test-tube' },
  processing: { label: 'Processing', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
  completed: { label: 'Completed', color: 'green-darken-2', icon: 'mdi-check-circle' },
  cancelled: { label: 'Cancelled', color: 'red-darken-2', icon: 'mdi-cancel' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1', icon: 'mdi-clock-outline' },
  urgent: { color: 'orange-darken-2', icon: 'mdi-alert' },
  stat: { color: 'red-darken-2', icon: 'mdi-flash' },
}
const priorityOpts = [
  { title: 'STAT', value: 'stat' },
  { title: 'Urgent', value: 'urgent' },
  { title: 'Routine', value: 'routine' },
]
const dateOpts = [
  { title: 'Today', value: 'today' },
  { title: 'Last 7 days', value: 'week' },
  { title: 'Last 30 days', value: 'month' },
]

function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }
function priorityIcon(v) { return PRIORITY_META[v]?.icon || 'mdi-flag-outline' }

const headers = computed(() => [
  { title: 'Ref', key: 'id', width: 100 },
  { title: 'Patient', key: 'patient_name' },
  { title: isLab.value ? 'From' : 'To', key: 'partner', sortable: false },
  { title: 'Tests', key: 'tests', sortable: false },
  { title: 'Priority', key: 'priority', width: 110 },
  { title: 'Status', key: 'status', width: 140 },
  { title: 'Created', key: 'created_at', width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
])

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/exchange/lab/')
    items.value = data.results || data || []
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to load lab exchange'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}
onMounted(load)

const tabs = computed(() => {
  const counts = items.value.reduce((acc, x) => {
    acc[x.status] = (acc[x.status] || 0) + 1
    return acc
  }, {})
  const inbox = (counts.pending || 0)
  const inProgress = (counts.accepted || 0) + (counts.sample_collected || 0) + (counts.processing || 0)
  return [
    { label: 'Inbox', value: 'inbox', icon: 'mdi-inbox', count: inbox },
    { label: 'In progress', value: 'in_progress', icon: 'mdi-progress-clock', count: inProgress },
    { label: 'Completed', value: 'completed', icon: 'mdi-check-circle', count: counts.completed || 0 },
    { label: 'Cancelled', value: 'cancelled', icon: 'mdi-cancel', count: counts.cancelled || 0 },
    { label: 'All', value: 'all', icon: 'mdi-format-list-bulleted', count: items.value.length },
  ]
})

const filtered = computed(() => {
  let arr = items.value
  if (tab.value === 'inbox') arr = arr.filter(x => x.status === 'pending')
  else if (tab.value === 'in_progress') arr = arr.filter(x => ['accepted', 'sample_collected', 'processing'].includes(x.status))
  else if (tab.value === 'completed') arr = arr.filter(x => x.status === 'completed')
  else if (tab.value === 'cancelled') arr = arr.filter(x => x.status === 'cancelled')

  if (priorityFilter.value) arr = arr.filter(x => x.priority === priorityFilter.value)

  if (dateFilter.value) {
    const lim = dateFilter.value === 'today' ? 86400000
      : dateFilter.value === 'week' ? 7 * 86400000
      : 30 * 86400000
    const now = Date.now()
    arr = arr.filter(x => x.created_at && (now - new Date(x.created_at).getTime()) <= lim)
  }

  const q = (search.value || '').toLowerCase().trim()
  if (q) {
    arr = arr.filter(x =>
      (x.patient_name || '').toLowerCase().includes(q)
      || (x.ordering_doctor_name || '').toLowerCase().includes(q)
      || (x.source_tenant_name || '').toLowerCase().includes(q)
      || (x.lab_tenant_name || '').toLowerCase().includes(q)
      || (x.tests || []).some(t => (t.test_name || t.name || '').toLowerCase().includes(q))
    )
  }
  // Sort: STAT first within view
  return [...arr].sort((a, b) => {
    const ord = { stat: 0, urgent: 1, routine: 2 }
    const da = ord[a.priority] ?? 9
    const db = ord[b.priority] ?? 9
    if (da !== db) return da - db
    return new Date(b.created_at) - new Date(a.created_at)
  })
})

const kpis = computed(() => {
  const arr = items.value
  const today = new Date().toDateString()
  const todayCount = arr.filter(x => x.created_at && new Date(x.created_at).toDateString() === today).length
  const pending = arr.filter(x => x.status === 'pending').length
  const stat = arr.filter(x => x.priority === 'stat' && !['completed', 'cancelled'].includes(x.status)).length
  const completed = arr.filter(x => x.status === 'completed').length
  return [
    { label: isLab.value ? 'Inbox' : 'Sent today', value: isLab.value ? pending : todayCount,
      icon: isLab.value ? 'mdi-inbox' : 'mdi-send', color: 'indigo',
      hint: isLab.value ? 'Awaiting acceptance' : 'New requests today' },
    { label: 'STAT queue', value: stat, icon: 'mdi-flash', color: 'red', hint: 'Urgent attention' },
    { label: 'Today', value: todayCount, icon: 'mdi-calendar-today', color: 'teal',
      hint: 'New requests today' },
    { label: 'Completed', value: completed, icon: 'mdi-check-circle', color: 'green',
      hint: 'All time' },
  ]
})

async function acceptOne(item) {
  actingId.value = item.id
  try {
    await $api.post(`/exchange/lab/${item.id}/accept/`)
    snack.text = `Accepted LX-${String(item.id).padStart(5, '0')}`
    snack.color = 'success'
    snack.show = true
    load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to accept'
    snack.color = 'error'
    snack.show = true
  } finally {
    actingId.value = null
  }
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

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['ref', 'patient', 'phone', 'partner', 'doctor', 'tests', 'priority', 'status', 'created_at']
  const header = cols.join(',')
  const body = rows.map(x => [
    `LX-${String(x.id).padStart(5, '0')}`,
    `"${(x.patient_name || '').replace(/"/g, '""')}"`,
    x.patient_phone || '',
    `"${(isLab.value ? x.source_tenant_name : x.lab_tenant_name || '').replace(/"/g, '""')}"`,
    `"${(x.ordering_doctor_name || '').replace(/"/g, '""')}"`,
    `"${((x.tests || []).map(t => t.test_name || t.name || t)).join('; ').replace(/"/g, '""')}"`,
    x.priority || '',
    x.status || '',
    x.created_at || '',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-exchange_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.ex-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.ex-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.ex-table :deep(tbody tr) { cursor: pointer; }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
