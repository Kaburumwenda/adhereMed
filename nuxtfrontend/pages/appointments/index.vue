<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 font-weight-bold mb-1">
          <v-icon color="primary" class="mr-2">mdi-calendar-clock</v-icon>
          Appointments
        </h1>
        <p class="text-body-2 text-medium-emphasis mb-0">Manage and track all hospital appointments</p>
      </div>
      <div class="d-flex ga-2">
        <v-btn variant="text" icon="mdi-download" @click="exportCSV" :disabled="!filtered.length" />
        <v-btn variant="text" icon="mdi-refresh" :loading="loading" @click="list" />
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" :to="newPath">
          New Appointment
        </v-btn>
      </div>
    </div>

    <!-- KPI Cards -->
    <v-row class="mb-2" dense>
      <v-col v-for="kpi in kpis" :key="kpi.key" cols="12" sm="6" md="3" lg="2" xl="2">
        <v-card rounded="lg" variant="outlined" class="h-100" hover>
          <v-card-text class="d-flex align-center ga-3 py-3">
            <v-avatar :color="kpi.color" size="40" rounded="lg" variant="tonal">
              <v-icon :icon="kpi.icon" :color="kpi.color" size="22" />
            </v-avatar>
            <div>
              <div class="text-h6 font-weight-bold">{{ kpi.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ kpi.label }}</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Analytics Cards -->
    <v-row class="mb-2">
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="xl" variant="outlined" class="h-100 analytics-card">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">Status Distribution</div>
              <v-chip size="x-small" variant="tonal" color="primary">{{ items.length }} total</v-chip>
            </div>

            <!-- Donut-style legend with colored rows -->
            <div class="status-rows">
              <div
                v-for="s in statusCounts"
                :key="s.key"
                class="status-row"
                :class="{ 'status-row--dim': s.count === 0 }"
              >
                <div class="d-flex align-center ga-2 flex-grow-1">
                  <div class="status-dot" :class="`bg-${s.color}`" />
                  <span class="text-body-2 text-truncate">{{ s.label }}</span>
                </div>
                <div class="d-flex align-center ga-2 flex-shrink-0" style="width: 50%;">
                  <div class="status-bar-track flex-grow-1">
                    <div
                      class="status-bar-fill"
                      :class="`bg-${s.color}`"
                      :style="{ width: totalPct(s.count) + '%' }"
                    />
                  </div>
                  <span class="text-body-2 font-weight-bold" :class="`text-${s.color}`" style="min-width: 32px; text-align: right;">
                    {{ s.count }}
                  </span>
                </div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="6" lg="4">
        <v-card rounded="xl" variant="outlined" class="h-100 analytics-card">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">Appointments by Day</div>
              <v-chip size="x-small" variant="tonal" color="info">{{ busiestDay }}</v-chip>
            </div>

            <!-- Mini bar chart -->
            <div class="day-chart d-flex align-end justify-space-between ga-1">
              <div
                v-for="d in dayCounts"
                :key="d.key"
                class="day-bar-col"
              >
                <div class="day-bar-value text-caption font-weight-bold" :class="`text-${d.color}`">
                  {{ d.count || '' }}
                </div>
                <div class="day-bar-track">
                  <div
                    class="day-bar"
                    :class="`bg-${d.color}`"
                    :style="{ height: Math.max(dayPct(d.count), 2) + '%' }"
                  />
                </div>
                <div class="text-caption text-medium-emphasis text-center mt-1" :class="{ 'font-weight-bold text-dark': d.isToday }">
                  {{ d.label }}
                </div>
              </div>
            </div>

            <v-divider class="my-3" />

            <div class="d-flex justify-space-between text-caption text-medium-emphasis">
              <span><v-icon size="x-small" class="mr-1">mdi-calendar-range</v-icon> This week</span>
              <span>{{ dayCounts.reduce((a, b) => a + b.count, 0) }} appointments</span>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="12" lg="4">
        <v-card rounded="xl" variant="outlined" class="h-100 analytics-card">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">Department Breakdown</div>
            </div>

            <div v-for="d in deptCounts" :key="d.name" class="dept-row">
              <div class="text-body-2 text-truncate mb-1">{{ d.name }}</div>
              <div class="d-flex align-center ga-2">
                <div class="dept-bar-track flex-grow-1">
                  <div class="dept-bar-fill bg-primary" :style="{ width: deptPct(d.count) + '%' }" />
                </div>
                <span class="text-body-2 font-weight-bold text-primary" style="min-width: 24px; text-align: right;">{{ d.count }}</span>
              </div>
            </div>

            <div v-if="!deptCounts.length" class="text-center text-medium-emphasis py-4">
              <v-icon size="32" class="mb-1">mdi-office-building-outline</v-icon>
              <div class="text-caption">No department data</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters Bar -->
    <v-card rounded="lg" variant="outlined" class="mb-4">
      <v-card-text>
        <v-row dense>
          <v-col cols="12" md="3">
            <v-text-field
              v-model="search"
              prepend-inner-icon="mdi-magnify"
              placeholder="Search reason or patient…"
              variant="outlined"
              density="compact"
              hide-details
              clearable
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-select
              v-model="statusFilter"
              :items="statusOptions"
              item-title="label"
              item-value="value"
              placeholder="Status"
              variant="outlined"
              density="compact"
              hide-details
              clearable
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-text-field
              v-model="dateFilter"
              type="date"
              label="Date"
              variant="outlined"
              density="compact"
              hide-details
              clearable
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-autocomplete
              v-model="doctorFilter"
              :items="doctors"
              item-title="full_name"
              item-value="id"
              placeholder="Doctor"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              :loading="doctorsLoading"
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-autocomplete
              v-model="deptFilter"
              :items="departments"
              item-title="name"
              item-value="id"
              placeholder="Department"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              :loading="deptsLoading"
            />
          </v-col>
          <v-col cols="12" md="1" class="d-flex align-center ga-1">
            <v-btn-toggle v-model="viewMode" mandatory density="compact" variant="outlined">
              <v-btn value="table" icon="mdi-table" size="small" />
              <v-btn value="grid" icon="mdi-view-grid" size="small" />
            </v-btn-toggle>
          </v-col>
        </v-row>
        <div v-if="hasActiveFilters" class="mt-2 d-flex align-center">
          <v-btn variant="text" size="small" prepend-icon="mdi-filter-remove" @click="clearFilters">
            Clear all filters
          </v-btn>
          <span class="text-caption text-medium-emphasis ms-2">{{ filtered.length }} result(s)</span>
        </div>
      </v-card-text>
    </v-card>

    <!-- Table View -->
    <v-card v-if="viewMode === 'table'" rounded="lg" variant="outlined">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="loading"
        :items-per-page="20"
        item-value="id"
        class="elevation-0"
        @click:row="onRowClick"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template #item.patient_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="32" :color="avatarColor(item.patient_name)" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.patient_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis" v-if="item.patient">{{ item.patient }}</div>
            </div>
          </div>
        </template>

        <template #item.staff_name="{ item }">
          <div class="text-body-2">{{ item.staff_name || '—' }}</div>
        </template>

        <template #item.department_name="{ item }">
          <v-chip v-if="item.department_name" size="small" variant="tonal" color="primary" label>
            {{ item.department_name }}
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.appointment_date="{ item }">
          <div class="text-body-2 font-weight-medium">{{ formatDate(item.appointment_date) }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatTime(item.appointment_time) }}</div>
        </template>

        <template #item.duration_minutes="{ item }">
          <v-chip size="small" variant="tonal" label>
            <v-icon start size="x-small">mdi-timer-outline</v-icon>
            {{ item.duration_minutes || 30 }} min
          </v-chip>
        </template>

        <template #item.status="{ item }">
          <StatusChip :status="item.status" />
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-tooltip text="View" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-eye" variant="text" size="small" @click.stop="goDetail(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil" variant="text" size="small" @click.stop="goEdit(item)" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="canCheckIn(item)" text="Check In" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-login" variant="text" size="small" color="success"
                  :loading="actionLoading === item.id" @click.stop="quickStatus(item, 'in_progress')" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="canComplete(item)" text="Complete" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-check-circle" variant="text" size="small" color="success"
                  :loading="actionLoading === item.id" @click.stop="quickStatus(item, 'completed')" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="canCancel(item)" text="Cancel" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-cancel" variant="text" size="small" color="error"
                  :loading="actionLoading === item.id" @click.stop="quickStatus(item, 'cancelled')" />
              </template>
            </v-tooltip>
            <v-tooltip text="Delete" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-delete" variant="text" size="small" color="error"
                  @click.stop="confirmDelete(item)" />
              </template>
            </v-tooltip>
          </div>
        </template>

        <template #no-data>
          <div class="text-center py-8">
            <v-icon size="48" color="medium-emphasis" class="mb-2">mdi-calendar-remove-outline</v-icon>
            <div class="text-body-1 text-medium-emphasis mb-2">No appointments found</div>
            <v-btn color="primary" variant="tonal" size="small" :to="newPath">Create appointment</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Grid View -->
    <v-row v-else dense>
      <v-col v-for="item in filtered" :key="item.id" cols="12" sm="6" md="4" lg="3">
        <v-card rounded="lg" variant="outlined" hover class="h-100" @click="goDetail(item)">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <StatusChip :status="item.status" />
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                </template>
                <v-list density="compact">
                  <v-list-item prepend-icon="mdi-eye" title="View" @click="goDetail(item)" />
                  <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="goEdit(item)" />
                  <v-list-item v-if="canCheckIn(item)" prepend-icon="mdi-login" title="Check In"
                    @click="quickStatus(item, 'in_progress')" />
                  <v-list-item v-if="canComplete(item)" prepend-icon="mdi-check-circle" title="Complete"
                    @click="quickStatus(item, 'completed')" />
                  <v-list-item v-if="canCancel(item)" prepend-icon="mdi-cancel" title="Cancel"
                    @click="quickStatus(item, 'cancelled')" />
                </v-list>
              </v-menu>
            </div>

            <div class="d-flex align-center ga-2 mb-3">
              <v-avatar size="40" :color="avatarColor(item.patient_name)" variant="tonal">
                <span class="text-body-2 font-weight-bold">{{ initials(item.patient_name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 overflow-hidden">
                <div class="text-subtitle-2 font-weight-bold text-truncate">{{ item.patient_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ item.reason || 'No reason provided' }}</div>
              </div>
            </div>

            <v-divider class="mb-3" />

            <div class="d-flex flex-wrap ga-2 mb-3">
              <v-chip size="small" variant="tonal" color="primary">
                <v-icon start size="x-small">mdi-calendar</v-icon>
                {{ formatDate(item.appointment_date) }}
              </v-chip>
              <v-chip size="small" variant="tonal" color="secondary">
                <v-icon start size="x-small">mdi-clock-outline</v-icon>
                {{ formatTime(item.appointment_time) }}
              </v-chip>
              <v-chip size="small" variant="tonal" label color="grey-darken-1">
                <v-icon start size="x-small">mdi-timer-outline</v-icon>
                {{ item.duration_minutes || 30 }}m
              </v-chip>
            </div>

            <div class="d-flex align-center justify-space-between text-caption">
              <div class="d-flex align-center ga-1 text-medium-emphasis">
                <v-icon size="x-small">mdi-doctor</v-icon>
                {{ item.staff_name || 'Unassigned' }}
              </div>
              <div class="d-flex align-center ga-1 text-medium-emphasis">
                <v-icon size="x-small">mdi-office-building-outline</v-icon>
                {{ item.department_name || 'Any' }}
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col v-if="!loading && !filtered.length" cols="12">
        <div class="text-center py-8">
          <v-icon size="48" color="medium-emphasis" class="mb-2">mdi-calendar-remove-outline</v-icon>
          <div class="text-body-1 text-medium-emphasis mb-2">No appointments found</div>
          <v-btn color="primary" variant="tonal" size="small" :to="newPath">Create appointment</v-btn>
        </div>
      </v-col>
    </v-row>

    <!-- Delete Dialog -->
    <v-dialog v-model="deleteDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Appointment?</v-card-title>
        <v-card-text>
          Are you sure you want to delete the appointment for
          <strong>{{ deleteTarget?.patient_name }}</strong> on
          <strong>{{ formatDate(deleteTarget?.appointment_date) }}</strong>?
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="tonal" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const route = useRoute()
const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePath = computed(() => `${ns.value}/appointments`)
const newPath = computed(() => `${basePath.value}/new`)

const { items, loading, list, update, remove } = useResource('/appointments/')
const doctorsRes = useResource('/accounts/staff/')
const deptsRes = useResource('/departments/')

const search = ref('')
const doctors = ref([])
const doctorsLoading = ref(true)
const departments = ref([])
const deptsLoading = ref(true)

const statusFilter = ref(null)
const dateFilter = ref(null)
const doctorFilter = ref(null)
const deptFilter = ref(null)
const viewMode = ref('table')
const actionLoading = ref(null)
const deleteDialog = ref(false)
const deleteTarget = ref(null)

const statusMeta = {
  scheduled: { color: 'info', icon: 'mdi-calendar-clock', label: 'Scheduled' },
  confirmed: { color: 'success', icon: 'mdi-calendar-check', label: 'Confirmed' },
  in_progress: { color: 'blue', icon: 'mdi-progress-clock', label: 'In Progress' },
  completed: { color: 'success', icon: 'mdi-check-circle', label: 'Completed' },
  cancelled: { color: 'error', icon: 'mdi-cancel', label: 'Cancelled' },
  no_show: { color: 'warning', icon: 'mdi-calendar-remove', label: 'No Show' },
}

const statusOptions = Object.entries(statusMeta).map(([value, m]) => ({ label: m.label, value }))

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: true },
  { title: 'Doctor', key: 'staff_name', sortable: true },
  { title: 'Department', key: 'department_name', sortable: true },
  { title: 'Date / Time', key: 'appointment_date', sortable: true },
  { title: 'Duration', key: 'duration_minutes', sortable: false, align: 'center' },
  { title: 'Status', key: 'status', sortable: true },
  { title: 'Actions', key: 'actions', sortable: false, align: 'end' },
]

onMounted(async () => {
  await list()
  loadOptions()
})

async function loadOptions() {
  try {
    await doctorsRes.list()
    doctors.value = doctorsRes.items.value
  } catch { /* ignore */ } finally { doctorsLoading.value = false }
  try {
    await deptsRes.list()
    departments.value = deptsRes.items.value
  } catch { /* ignore */ } finally { deptsLoading.value = false }
}

/* ---- KPIs ---- */
const kpis = computed(() => {
  const all = items.value
  const today = new Date().toISOString().split('T')[0]
  return [
    { key: 'total', label: 'Total', value: all.length, color: 'primary', icon: 'mdi-calendar-multiple' },
    { key: 'today', label: 'Today', value: all.filter(a => a.appointment_date === today).length, color: 'info', icon: 'mdi-calendar-today' },
    { key: 'upcoming', label: 'Upcoming', value: all.filter(a => a.appointment_date && a.appointment_date >= today && ['scheduled', 'confirmed'].includes(a.status)).length, color: 'success', icon: 'mdi-calendar-clock' },
    { key: 'completed', label: 'Completed', value: all.filter(a => a.status === 'completed').length, color: 'success', icon: 'mdi-check-circle' },
    { key: 'cancelled', label: 'Cancelled', value: all.filter(a => a.status === 'cancelled').length, color: 'error', icon: 'mdi-cancel' },
    { key: 'no_show', label: 'No Show', value: all.filter(a => a.status === 'no_show').length, color: 'warning', icon: 'mdi-calendar-remove' },
  ]
})

/* ---- Analytics ---- */
const statusCounts = computed(() => {
  const all = items.value
  return Object.entries(statusMeta).map(([key, meta]) => ({
    key,
    label: meta.label,
    color: meta.color,
    icon: meta.icon,
    count: all.filter(a => a.status === key).length,
  })).filter(s => s.count > 0)
})

const dayCounts = computed(() => {
  const all = items.value
  const map = {}
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  const dayColors = ['error', 'primary', 'primary', 'primary', 'primary', 'primary', 'warning']
  all.forEach(a => {
    if (!a.appointment_date) return
    const d = new Date(a.appointment_date + 'T00:00:00')
    const dw = d.getDay()
    map[dw] = (map[dw] || 0) + 1
  })
  const today = new Date().getDay()
  return days.map((label, i) => ({
    key: i,
    label,
    color: dayColors[i],
    count: map[i] || 0,
    isToday: i === today,
  }))
})

const busiestDay = computed(() => {
  const max = dayCounts.value.reduce((a, b) => a.count >= b.count ? a : b)
  return max && max.count > 0 ? `${max.label} busiest` : 'No data'
})

const deptCounts = computed(() => {
  const all = items.value
  const map = {}
  all.forEach(a => {
    const n = a.department_name || 'Unassigned'
    map[n] = (map[n] || 0) + 1
  })
  return Object.entries(map).map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count).slice(0, 8)
})

function totalPct(count) {
  const t = items.value.length
  return t ? Math.round((count / t) * 100) : 0
}
function dayPct(count) {
  const max = Math.max(...dayCounts.value.map(d => d.count), 1)
  return Math.round((count / max) * 100)
}
function deptPct(count) {
  const max = Math.max(...deptCounts.value.map(d => d.count), 1)
  return Math.round((count / max) * 100)
}

/* ---- Filters ---- */
const hasActiveFilters = computed(() =>
  search.value || statusFilter.value || dateFilter.value || doctorFilter.value || deptFilter.value
)
function clearFilters() {
  search.value = ''
  statusFilter.value = null
  dateFilter.value = null
  doctorFilter.value = null
  deptFilter.value = null
}

const filtered = computed(() => {
  let r = items.value
  if (statusFilter.value) r = r.filter(a => a.status === statusFilter.value)
  if (dateFilter.value) r = r.filter(a => a.appointment_date === dateFilter.value)
  if (doctorFilter.value) r = r.filter(a => a.staff === doctorFilter.value)
  if (deptFilter.value) r = r.filter(a => a.department === deptFilter.value)
  if (search.value) {
    const q = search.value.toLowerCase()
    r = r.filter(a =>
      (a.reason || '').toLowerCase().includes(q) ||
      (a.patient_name || '').toLowerCase().includes(q) ||
      (a.staff_name || '').toLowerCase().includes(q)
    )
  }
  return r
})

/* ---- Navigation ---- */
function goDetail(item) { navigateTo(`${basePath.value}/${item.id}`) }
function goEdit(item) { navigateTo(`${basePath.value}/${item.id}/edit`) }
function onRowClick(_, { item }) { goDetail(item) }

/* ---- Quick Status Actions ---- */
function canCheckIn(item) { return ['scheduled', 'confirmed'].includes(item.status) }
function canComplete(item) { return ['in_progress', 'confirmed', 'scheduled'].includes(item.status) }
function canCancel(item) { return ['scheduled', 'confirmed', 'in_progress'].includes(item.status) }

async function quickStatus(item, status) {
  actionLoading.value = item.id
  try {
    await update(item.id, { status })
    await list()
  } catch { /* ignore */ } finally { actionLoading.value = null }
}

/* ---- Helpers ---- */
function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(s => s[0]).slice(0, 2).join('').toUpperCase()
}
function avatarColor(name) {
  const colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'orange']
  const h = (name || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0)
  return colors[h % colors.length]
}
function formatTime(t) {
  if (!t) return '—'
  return t.length === 5 ? t : new Date(`2000-01-01T${t}`).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

/* ---- CSV Export ---- */
function exportCSV() {
  const rows = [['Patient', 'Doctor', 'Department', 'Date', 'Time', 'Duration', 'Status', 'Reason']]
  filtered.value.forEach(a => {
    rows.push([a.patient_name, a.staff_name, a.department_name, a.appointment_date, a.appointment_time, a.duration_minutes, a.status, a.reason])
  })
  const csv = rows.map(r => r.map(c => `"${(c || '').replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'appointments.csv'
  a.click()
  URL.revokeObjectURL(url)
}

/* ---- Delete ---- */
async function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}
async function doDelete() {
  if (!deleteTarget.value) return
  await remove(deleteTarget.value.id)
  deleteDialog.value = false
  deleteTarget.value = null
}
</script>

<style scoped>
.cursor-pointer { cursor: pointer; }

.analytics-card {
  border-color: rgba(var(--v-theme-on-surface), 0.12);
  transition: box-shadow 0.2s ease, border-color 0.2s ease;
}
.analytics-card:hover {
  border-color: rgba(var(--v-theme-primary), 0.25);
  box-shadow: 0 4px 20px rgba(var(--v-theme-primary), 0.06);
}

/* ---- Status Distribution ---- */
.status-rows {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.status-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 0;
  transition: opacity 0.2s;
}
.status-row--dim {
  opacity: 0.4;
}
.status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.status-bar-track {
  height: 8px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 6px;
  overflow: hidden;
}
.status-bar-fill {
  height: 100%;
  border-radius: 6px;
  transition: width 0.4s ease;
}

/* ---- Day Chart ---- */
.day-chart {
  height: 120px;
  padding-top: 8px;
}
.day-bar-col {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  height: 100%;
}
.day-bar-value {
  font-size: 11px;
  line-height: 1;
  margin-bottom: 4px;
  min-height: 14px;
}
.day-bar-track {
  flex: 1;
  width: 100%;
  max-width: 36px;
  display: flex;
  align-items: flex-end;
  background: rgba(var(--v-theme-on-surface), 0.05);
  border-radius: 6px 6px 4px 4px;
  overflow: hidden;
}
.day-bar {
  width: 100%;
  border-radius: 4px 4px 2px 2px;
  transition: height 0.4s ease;
  min-height: 2px;
}

/* ---- Department Breakdown ---- */
.dept-row {
  margin-bottom: 10px;
}
.dept-bar-track {
  height: 8px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 6px;
  overflow: hidden;
}
.dept-bar-fill {
  height: 100%;
  border-radius: 6px;
  transition: width 0.4s ease;
}
</style>
