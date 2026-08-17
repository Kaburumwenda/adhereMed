<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Appointments" subtitle="Manage and track all clinic appointments"
      icon="mdi-calendar-clock" color="primary">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
          :disabled="!filteredAppointments.length" @click="exportCsv">Export</v-btn>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="r.list(isDoctor ? { staff: auth.user?.id, page_size: 1000 } : { page_size: 1000 })">Refresh</v-btn>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
          @click="navigateTo(`${ns}/appointments/new`)">New Appointment</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search by patient, doctor, reason…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact"
            hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="dateFrom" type="date" label="From"
            variant="outlined" density="compact" hide-details @update:model-value="datePreset = ''" />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="dateTo" type="date" label="To"
            variant="outlined" density="compact" hide-details @update:model-value="datePreset = ''" />
        </v-col>
        <v-col cols="12" md="1" class="d-flex align-center justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="board" icon="mdi-view-column" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
      <!-- Date preset quick buttons -->
      <div class="px-1 pt-2 pb-1 d-flex flex-wrap align-center ga-2">
        <span class="text-caption text-medium-emphasis font-weight-medium" style="white-space: nowrap">Quick range:</span>
        <v-btn-group density="compact" variant="outlined" rounded>
          <v-btn v-for="p in datePresets" :key="p.key" size="x-small" :color="datePreset === p.key ? 'primary' : 'default'"
            :variant="datePreset === p.key ? 'flat' : 'outlined'" class="text-none" @click="applyPreset(p.key)">
            {{ p.label }}
          </v-btn>
        </v-btn-group>
      </div>
      <div v-if="activeFilters" class="px-1 pt-2 d-flex flex-wrap ga-2">
        <v-chip v-if="statusFilter" size="small" closable
          @click:close="statusFilter = null" variant="tonal"
          :color="statusColor(statusFilter)" class="text-capitalize">
          <v-icon start size="14">mdi-circle-medium</v-icon>Status: {{ statusFilter.replace('_', ' ') }}
        </v-chip>
        <v-chip v-if="datePreset" size="small" closable variant="flat" color="primary"
          @click:close="applyPreset('all')">
          <v-icon start size="14">mdi-calendar-filter</v-icon>{{ datePresetLabel }}
        </v-chip>
        <template v-if="!datePreset">
          <v-chip v-if="dateFrom" size="small" closable @click:close="dateFrom = ''"
            variant="tonal" color="info">
            <v-icon start size="14">mdi-calendar-arrow-left</v-icon>From: {{ dateFrom }}
          </v-chip>
          <v-chip v-if="dateTo" size="small" closable @click:close="dateTo = ''"
            variant="tonal" color="info">
            <v-icon start size="14">mdi-calendar-arrow-right</v-icon>To: {{ dateTo }}
          </v-chip>
        </template>
        <v-btn size="small" variant="text" class="text-none"
          prepend-icon="mdi-filter-remove" @click="clearFilters">Clear all</v-btn>
      </div>
    </v-card>

    <!-- ── Quick KPI Cards ──────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">{{ k.label }}</div>
              <div class="text-h4 font-weight-bold" :class="`text-${k.color}`">{{ k.value }}</div>
            </div>
            <v-avatar :color="k.color + '-lighten-5'" variant="tonal" size="48">
              <v-icon :color="k.color" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Distribution Stat Cards (with bars) ──────────────────── -->
    <v-row dense class="mb-3">
      <!-- Status Distribution -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">STATUS DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-chart-donut</v-icon>
          </div>
          <div class="d-flex flex-column ga-2 mb-2">
            <div v-for="s in statusDist" :key="s.key" class="d-flex align-center ga-2">
              <v-icon size="16" :color="s.color">{{ s.icon }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0" style="width: 100px">{{ s.label }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`status-bar-${s.key}`" :style="{ width: `${s.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${s.color}`" style="width: 28px; text-align: right">{{ s.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ totalAppointments }} appointments total</div>
        </v-card>
      </v-col>

      <!-- Appointments by Day (this week) -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">THIS WEEK BY DAY</span>
            <v-icon size="16" color="medium-emphasis">mdi-calendar-week</v-icon>
          </div>
          <div class="d-flex align-end ga-1 mb-2 weekday-bar-chart">
            <div v-for="(d, i) in weekDays" :key="i" class="weekday-bar-col flex-1 d-flex flex-column align-center">
              <span class="text-caption font-weight-bold mb-1" :class="isToday(i) ? 'text-primary' : 'text-medium-emphasis'">
                {{ weekdayCount(i) }}
              </span>
              <div class="weekday-bar-fill rounded-top" :class="{ 'weekday-bar-today': isToday(i) }" :style="{ height: `${weekdayBarHeight(i)}%` }" />
            </div>
          </div>
          <div class="d-flex ga-1 mt-1">
            <span v-for="(d, i) in weekDays" :key="i" class="text-caption flex-1 text-center"
              :class="isToday(i) ? 'font-weight-bold text-primary' : 'text-medium-emphasis'">{{ d }}</span>
          </div>
        </v-card>
      </v-col>

      <!-- Today's Upcoming Schedule -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">TODAY'S SCHEDULE</span>
            <v-icon size="16" color="medium-emphasis">mdi-timetable</v-icon>
          </div>
          <div v-if="todayAppointments.length" class="d-flex flex-column ga-2" style="max-height: 160px; overflow-y: auto">
            <div v-for="a in todayAppointments" :key="a.id" class="d-flex align-center ga-2 today-item pa-2 rounded-lg" @click="goTo(a.id)">
              <div class="today-time text-caption font-weight-bold text-primary flex-shrink-0" style="width: 48px">{{ formatTime(a.appointment_time) }}</div>
              <v-avatar :color="statusColor(a.status)" variant="tonal" size="32">
                <v-icon size="16" :color="statusColor(a.status)">{{ statusIcon(a.status) }}</v-icon>
              </v-avatar>
              <div class="flex-1" style="min-width: 0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ a.patient_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ a.reason || a.staff_name || '—' }}</div>
              </div>
              <v-chip size="x-small" variant="tonal" :color="statusColor(a.status)" class="text-capitalize flex-shrink-0">{{ (a.status || '').replace('_', ' ') }}</v-chip>
            </div>
          </div>
          <div v-else class="text-center text-caption text-medium-emphasis py-6">
            <v-icon size="40" color="grey-lighten-2">mdi-calendar-blank</v-icon>
            <div class="mt-2">No appointments today</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <div v-if="r.loading.value" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <!-- Empty state -->
    <div v-else-if="!filteredAppointments.length" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-calendar-blank</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No appointments found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">
        {{ activeFilters ? 'Try adjusting your filters.' : 'Schedule your first appointment to get started.' }}
      </div>
      <v-btn v-if="!activeFilters" color="primary" rounded="lg" prepend-icon="mdi-plus"
        @click="navigateTo(`${ns}/appointments/new`)">New Appointment</v-btn>
      <v-btn v-else variant="text" rounded="lg" prepend-icon="mdi-filter-remove"
        @click="clearFilters">Clear filters</v-btn>
    </div>

    <!-- Table view -->
    <v-card v-else-if="view === 'table'" flat rounded="lg" class="results-card">
      <v-data-table
        :headers="headers"
        :items="filteredAppointments"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => goTo(item.id)"
        class="appointments-table">
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar color="primary-lighten-5" size="36" class="mr-3">
              <v-icon color="primary-darken-2" size="20">mdi-account</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
            </div>
          </div>
        </template>
        <template #item.staff_name="{ value }">
          <span v-if="value" class="font-weight-medium">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.appointment_date="{ item }">
          <div class="d-flex flex-column">
            <span>{{ formatDateTime(apptDateTime(item)) }}</span>
          </div>
        </template>
        <template #item.status="{ value }">
          <v-chip size="small" variant="tonal" :color="statusColor(value)"
            class="text-capitalize font-weight-medium">
            <v-icon start size="14">{{ statusIcon(value) }}</v-icon>
            {{ value ? value.replace('_', ' ') : '—' }}
          </v-chip>
        </template>
        <template #item.reason="{ value }">
          <span v-if="value" class="text-truncate d-inline-block"
            style="max-width: 220px">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
              @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
              @click="goToEdit(item.id)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Board view (Kanban-style columns by status) -->
    <div v-else class="appt-board d-flex ga-3 overflow-x-auto pb-2">
      <div v-for="col in boardColumns" :key="col.key" class="board-column flex-1" style="min-width: 280px">
        <div class="board-col-header d-flex align-center justify-space-between px-3 py-2 rounded-t-lg" :class="`board-col-${col.key}`">
          <div class="d-flex align-center ga-2">
            <v-icon size="18" :color="col.color">{{ col.icon }}</v-icon>
            <span class="text-subtitle-2 font-weight-bold">{{ col.label }}</span>
          </div>
          <v-chip size="x-small" variant="flat" :color="col.color">{{ boardColumnItems(col.key).length }}</v-chip>
        </div>
        <div class="board-col-body pa-2 ga-2 d-flex flex-column">
          <div
            v-for="item in boardColumnItems(col.key)" :key="item.id"
            class="board-card pa-3 rounded-lg"
            @click="goTo(item.id)"
          >
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-body-2 font-weight-bold text-truncate">{{ item.patient_name || '—' }}</span>
            </div>
            <div class="text-caption text-medium-emphasis mb-2 text-truncate">
              {{ item.reason || 'No reason specified' }}
            </div>
            <div class="d-flex align-center justify-space-between">
              <div class="d-flex align-center ga-1 text-caption text-medium-emphasis">
                <v-icon size="12">mdi-clock-outline</v-icon>
                {{ formatDateTime(apptDateTime(item)) }}
              </div>
              <span v-if="item.staff_name" class="text-caption font-weight-medium text-medium-emphasis text-truncate" style="max-width: 100px">
                {{ item.staff_name }}
              </span>
            </div>
          </div>
          <div v-if="!boardColumnItems(col.key).length" class="text-center text-caption text-medium-emphasis py-4">
            No appointments
          </div>
        </div>
      </div>
    </div>

    <!-- ── Delete confirmation dialog ────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Appointment</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete the appointment for
              <strong>{{ deleteTarget?.patient_name || 'this patient' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">
                {{ formatDateTime(apptDateTime(deleteTarget)) }} — This action cannot be undone.
              </div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">
            Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'

const ns = '/clinics'
const auth = useAuthStore()

// Doctors / clinical officers / dentists only see their own appointments
const isDoctor = ['doctor', 'clinical_officer', 'dentist'].includes(auth.role)

const r = useResource('/appointments/')
onMounted(() => r.list(isDoctor ? { staff: auth.user?.id, page_size: 1000 } : { page_size: 1000 }))

const view = ref('table')
const statusFilter = ref(null)
const dateFrom = ref('')
const dateTo = ref('')
const datePreset = ref('')

// Quick date range presets
const datePresets = [
  { key: 'today', label: 'Today' },
  { key: 'tomorrow', label: 'Tomorrow' },
  { key: 'this_week', label: 'This Week' },
  { key: 'next_week', label: 'Next Week' },
  { key: 'this_month', label: 'This Month' },
  { key: 'all', label: 'All' },
]

function fmtDate(d) {
  return d.toISOString().slice(0, 10)
}
function applyPreset(key) {
  datePreset.value = key
  const now = new Date()
  if (key === 'today') {
    dateFrom.value = fmtDate(now)
    dateTo.value = fmtDate(now)
  } else if (key === 'tomorrow') {
    const tmr = new Date(now); tmr.setDate(now.getDate() + 1)
    dateFrom.value = fmtDate(tmr)
    dateTo.value = fmtDate(tmr)
  } else if (key === 'this_week') {
    const day = now.getDay() === 0 ? 6 : now.getDay() - 1 // Mon=0..Sun=6
    const monday = new Date(now); monday.setDate(now.getDate() - day)
    const sunday = new Date(monday); sunday.setDate(monday.getDate() + 6)
    dateFrom.value = fmtDate(monday)
    dateTo.value = fmtDate(sunday)
  } else if (key === 'next_week') {
    const day = now.getDay() === 0 ? 6 : now.getDay() - 1
    const monday = new Date(now); monday.setDate(now.getDate() - day + 7)
    const sunday = new Date(monday); sunday.setDate(monday.getDate() + 6)
    dateFrom.value = fmtDate(monday)
    dateTo.value = fmtDate(sunday)
  } else if (key === 'this_month') {
    dateFrom.value = fmtDate(new Date(now.getFullYear(), now.getMonth(), 1))
    dateTo.value = fmtDate(new Date(now.getFullYear(), now.getMonth() + 1, 0))
  } else {
    dateFrom.value = ''
    dateTo.value = ''
  }
}
const datePresetLabel = computed(() => datePresets.find(p => p.key === datePreset.value)?.label || '')

const statusOptions = [
  { title: 'Scheduled', value: 'scheduled' },
  { title: 'Confirmed', value: 'confirmed' },
  { title: 'In Progress', value: 'in_progress' },
  { title: 'Completed', value: 'completed' },
  { title: 'Cancelled', value: 'cancelled' },
  { title: 'No Show', value: 'no_show' },
]

const boardColumns = [
  { key: 'scheduled', label: 'Scheduled', icon: 'mdi-clock-outline', color: 'info' },
  { key: 'confirmed', label: 'Confirmed', icon: 'mdi-check-outline', color: 'success' },
  { key: 'in_progress', label: 'In Progress', icon: 'mdi-progress-clock', color: 'secondary' },
  { key: 'completed', label: 'Completed', icon: 'mdi-check-circle', color: 'primary' },
  { key: 'cancelled', label: 'Cancelled', icon: 'mdi-close', color: 'error' },
  { key: 'no_show', label: 'No Show', icon: 'mdi-alert-circle-outline', color: 'warning' },
]

function boardColumnItems(statusKey) {
  return filteredAppointments.value.filter(a => a.status === statusKey)
}

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Doctor', key: 'staff_name', sortable: false },
  { title: 'Date / Time', key: 'appointment_date', width: 180 },
  { title: 'Status', key: 'status', width: 140 },
  { title: 'Reason', key: 'reason', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

const activeFilters = computed(() =>
  statusFilter.value || dateFrom.value || dateTo.value || r.search.value,
)

function clearFilters() {
  statusFilter.value = null
  dateFrom.value = ''
  dateTo.value = ''
  datePreset.value = ''
  r.search.value = ''
}

const filteredAppointments = computed(() => {
  let list = r.filtered.value
  if (statusFilter.value) list = list.filter(a => a.status === statusFilter.value)
  if (dateFrom.value) list = list.filter(a => (a.appointment_date || '') >= dateFrom.value)
  if (dateTo.value) list = list.filter(a => (a.appointment_date || '') <= dateTo.value)
  return list
})

const kpis = computed(() => {
  const list = filteredAppointments.value
  const today = new Date().toISOString().slice(0, 10)
  return [
    { label: 'Total', value: list.length, icon: 'mdi-calendar-multiple', color: 'primary' },
    { label: 'Today', value: list.filter(a => a.appointment_date === today).length, icon: 'mdi_calendar-today', color: 'info' },
    { label: 'Scheduled', value: list.filter(a => a.status === 'scheduled').length, icon: 'mdi-clock-outline', color: 'teal' },
    { label: 'Completed', value: list.filter(a => a.status === 'completed').length, icon: 'mdi-check-circle', color: 'success' },
  ]
})

const totalAppointments = computed(() => filteredAppointments.value.length)

// Status distribution for horizontal bars
const statusDist = computed(() => {
  const list = filteredAppointments.value
  const total = list.length || 1
  const counts = {
    scheduled: list.filter(a => a.status === 'scheduled').length,
    confirmed: list.filter(a => a.status === 'confirmed').length,
    in_progress: list.filter(a => a.status === 'in_progress').length,
    completed: list.filter(a => a.status === 'completed').length,
    cancelled: list.filter(a => a.status === 'cancelled').length,
    no_show: list.filter(a => a.status === 'no_show').length,
  }
  return [
    { key: 'scheduled', label: 'Scheduled', icon: 'mdi-clock-outline', color: 'info', count: counts.scheduled, pct: (counts.scheduled / total) * 100 },
    { key: 'confirmed', label: 'Confirmed', icon: 'mdi-check-outline', color: 'success', count: counts.confirmed, pct: (counts.confirmed / total) * 100 },
    { key: 'in_progress', label: 'In Progress', icon: 'mdi-progress-clock', color: 'secondary', count: counts.in_progress, pct: (counts.in_progress / total) * 100 },
    { key: 'completed', label: 'Completed', icon: 'mdi-check-circle', color: 'primary', count: counts.completed, pct: (counts.completed / total) * 100 },
    { key: 'cancelled', label: 'Cancelled', icon: 'mdi-close', color: 'error', count: counts.cancelled, pct: (counts.cancelled / total) * 100 },
    { key: 'no_show', label: 'No Show', icon: 'mdi-alert-circle-outline', color: 'warning', count: counts.no_show, pct: (counts.no_show / total) * 100 },
  ]
})

// Weekday volume
const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
function getDayIndex(dateStr) {
  if (!dateStr) return -1
  const d = new Date(dateStr)
  return d.getDay() === 0 ? 6 : d.getDay() - 1
}
function isToday(dayIdx) {
  let today = new Date().getDay()
  today = today === 0 ? 6 : today - 1
  return today === dayIdx
}
function weekdayCount(dayIdx) {
  const now = new Date()
  const weekStart = new Date(now)
  const currentDay = now.getDay() === 0 ? 6 : now.getDay() - 1
  weekStart.setDate(now.getDate() - currentDay)
  weekStart.setHours(0, 0, 0, 0)
  return filteredAppointments.value.filter(a => {
    if (!a.appointment_date) return false
    const d = new Date(a.appointment_date)
    if (d < weekStart) return false
    return getDayIndex(a.appointment_date) === dayIdx
  }).length
}
function weekdayBarHeight(dayIdx) {
  const max = Math.max(...[0, 1, 2, 3, 4, 5, 6].map(weekdayCount), 1)
  return Math.max(6, (weekdayCount(dayIdx) / max) * 100)
}

// Today's appointments (sorted by time)
const todayAppointments = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return filteredAppointments.value
    .filter(a => a.appointment_date === today)
    .sort((a, b) => (a.appointment_time || '').localeCompare(b.appointment_time || ''))
})
function formatTime(t) {
  if (!t) return '—'
  return t.substring(0, 5)
}

// ── Helpers ────────────────────────────────────────────────────────
function apptDateTime(a) {
  if (!a) return ''
  const d = a.appointment_date || ''
  const t = a.appointment_time || ''
  if (d && t) {
    const dt = new Date(`${d}T${t}`)
    if (!isNaN(dt)) return dt.toISOString()
    return `${d} ${t}`
  }
  return d || ''
}

function statusColor(s) {
  return {
    scheduled: 'info',
    confirmed: 'success',
    completed: 'primary',
    cancelled: 'error',
    no_show: 'warning',
    in_progress: 'secondary',
  }[s] || 'grey'
}
function statusIcon(s) {
  return {
    scheduled: 'mdi-clock-outline',
    confirmed: 'mdi-check-outline',
    completed: 'mdi-check-circle',
    cancelled: 'mdi-close',
    no_show: 'mdi-alert-circle-outline',
    in_progress: 'mdi-progress-clock',
  }[s] || 'mdi-circle-medium'
}

function goTo(id) { navigateTo(`${ns}/appointments/${id}`) }
function goToEdit(id) { navigateTo(`${ns}/appointments/${id}/edit`) }

// ── Delete ──────────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const deleting = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}

async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Appointment deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
  } catch {
    snack.text = r.error.value || 'Failed to delete appointment'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}

// ── Export ──────────────────────────────────────────────────────────
function exportCsv() {
  const rows = filteredAppointments.value
  if (!rows.length) return
  const cols = ['patient_name', 'staff_name', 'appointment_date', 'appointment_time', 'status', 'reason']
  const header = cols.join(',')
  const body = rows.map(a => [
    `"${(a.patient_name || '').replace(/"/g, '""')}"`,
    `"${(a.staff_name || '').replace(/"/g, '""')}"`,
    a.appointment_date || '',
    a.appointment_time || '',
    a.status || '',
    `"${(a.reason || '').replace(/"/g, '""')}"`,
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `clinic_appointments_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.appointments-table :deep(tbody tr) { cursor: pointer; }

/* ── Distribution Cards ── */
.dist-card { overflow: hidden; }
.flex-1 { flex: 1; }
.flex-shrink-0 { flex-shrink: 0; }

/* Status horizontal bars */
.status-bar-track {
  height: 10px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.status-bar-fill {
  height: 100%;
  min-width: 4px;
  transition: width 0.3s ease;
}
.status-bar-scheduled { background: rgb(var(--v-theme-info)); }
.status-bar-confirmed { background: rgb(var(--v-theme-success)); }
.status-bar-in_progress { background: rgb(var(--v-theme-secondary)); }
.status-bar-completed { background: rgb(var(--v-theme-primary)); }
.status-bar-cancelled { background: rgb(var(--v-theme-error)); }
.status-bar-no_show { background: #ff9800; }

/* Weekday bar chart */
.weekday-bar-chart {
  height: 70px;
  align-items: flex-end;
}
.weekday-bar-col {
  height: 100%;
  justify-content: flex-end;
}
.weekday-bar-fill {
  width: 100%;
  min-height: 4px;
  border-radius: 6px 6px 0 0;
  background: rgba(var(--v-theme-primary), 0.35);
  opacity: 0.6;
  transition: height 0.3s ease, opacity 0.2s ease;
}
.weekday-bar-fill:hover { opacity: 0.85; }
.weekday-bar-today {
  background: rgb(var(--v-theme-primary));
  opacity: 0.8;
}
.rounded-top { border-radius: 6px 6px 0 0; }

/* Today's schedule */
.today-item {
  cursor: pointer;
  transition: background 0.15s;
}
.today-item:hover {
  background: rgba(var(--v-theme-primary), 0.06);
}

/* ── Board View (Kanban) ── */
.appt-board {
  min-height: 400px;
}
.board-column {
  background: rgba(var(--v-theme-on-surface), 0.03);
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  display: flex;
  flex-direction: column;
}
.board-col-body {
  flex: 1;
  min-height: 200px;
  max-height: 60vh;
  overflow-y: auto;
}
.board-card {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  cursor: pointer;
  transition: box-shadow 0.2s, transform 0.15s;
}
.board-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-1px);
}

/* Column header colors */
.board-col-scheduled { border-bottom: 2px solid #2196f3; background: rgba(33, 150, 243, 0.06); }
.board-col-confirmed { border-bottom: 2px solid #4caf50; background: rgba(76, 175, 80, 0.06); }
.board-col-in_progress { border-bottom: 2px solid #9c27b0; background: rgba(156, 39, 176, 0.06); }
.board-col-completed { border-bottom: 2px solid #1976d2; background: rgba(25, 118, 210, 0.06); }
.board-col-cancelled { border-bottom: 2px solid #f44336; background: rgba(244, 67, 54, 0.06); }
.board-col-no_show { border-bottom: 2px solid #ff9800; background: rgba(255, 152, 0, 0.06); }
</style>
