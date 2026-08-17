<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Consultations" subtitle="Patient consultation records"
      icon="mdi-medical-bag" color="success">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="loadList">Refresh</v-btn>
        <v-btn color="success" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="navigateTo(`${ns}/consultations/new`)">New Consultation</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search by complaint, diagnosis…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dispositionFilter" :items="dispositionOptions"
            label="Disposition" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="1">
          <v-text-field v-model="dateFrom" type="date" label="From"
            variant="outlined" density="compact" hide-details @update:model-value="datePreset = ''" />
        </v-col>
        <v-col cols="6" md="1">
          <v-text-field v-model="dateTo" type="date" label="To"
            variant="outlined" density="compact" hide-details @update:model-value="datePreset = ''" />
        </v-col>
        <v-col cols="12" md="1" class="d-flex align-center justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="success">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="board" icon="mdi-view-column" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
      <!-- Date preset quick buttons -->
      <div class="px-1 pt-2 pb-1 d-flex flex-wrap align-center ga-2">
        <span class="text-caption text-medium-emphasis font-weight-medium" style="white-space: nowrap">Quick range:</span>
        <v-btn-group density="compact" variant="outlined" rounded>
          <v-btn v-for="p in datePresets" :key="p.key" size="x-small" :color="datePreset === p.key ? 'success' : 'default'"
            :variant="datePreset === p.key ? 'flat' : 'outlined'" class="text-none" @click="applyPreset(p.key)">
            {{ p.label }}
          </v-btn>
        </v-btn-group>
      </div>
      <div v-if="activeFilters" class="px-1 pt-2 d-flex flex-wrap ga-2">
        <v-chip v-if="statusFilter" size="small" closable @click:close="statusFilter = null"
          variant="tonal" :color="statusColor(statusFilter)" class="text-capitalize">
          <v-icon start size="14">mdi-circle-medium</v-icon>Status: {{ statusFilter }}
        </v-chip>
        <v-chip v-if="dispositionFilter" size="small" closable @click:close="dispositionFilter = null"
          variant="tonal" color="secondary" class="text-capitalize">
          <v-icon start size="14">mdi-clipboard-pulse</v-icon>Disposition: {{ dispositionFilter.replace('_', ' ') }}
        </v-chip>
        <v-chip v-if="datePreset" size="small" closable variant="flat" color="success"
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
              <span class="text-body-2 font-weight-medium flex-shrink-0" style="width: 80px">{{ s.label }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`status-bar-${s.key}`" :style="{ width: `${s.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${s.color}`" style="width: 28px; text-align: right">{{ s.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ totalConsultations }} consultations total</div>
        </v-card>
      </v-col>

      <!-- Consultations by Day (this week) -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">THIS WEEK BY DAY</span>
            <v-icon size="16" color="medium-emphasis">mdi-calendar-week</v-icon>
          </div>
          <div class="d-flex align-end ga-1 mb-2 weekday-bar-chart">
            <div v-for="(d, i) in weekDays" :key="i" class="weekday-bar-col flex-1 d-flex flex-column align-center">
              <span class="text-caption font-weight-bold mb-1" :class="isToday(i) ? 'text-success' : 'text-medium-emphasis'">
                {{ weekdayCount(i) }}
              </span>
              <div class="weekday-bar-fill rounded-top" :class="{ 'weekday-bar-today': isToday(i) }" :style="{ height: `${weekdayBarHeight(i)}%` }" />
            </div>
          </div>
          <div class="d-flex ga-1 mt-1">
            <span v-for="(d, i) in weekDays" :key="i" class="text-caption flex-1 text-center"
              :class="isToday(i) ? 'font-weight-bold text-success' : 'text-medium-emphasis'">{{ d }}</span>
          </div>
        </v-card>
      </v-col>

      <!-- Disposition Breakdown -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">DISPOSITION BREAKDOWN</span>
            <v-icon size="16" color="medium-emphasis">mdi-clipboard-pulse</v-icon>
          </div>
          <div class="d-flex flex-column ga-2 mb-2">
            <div v-for="d in dispositionDist" :key="d.key" class="d-flex align-center ga-2">
              <v-icon size="16" :color="d.color">{{ d.icon }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0" style="width: 100px">{{ d.label }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`disposition-bar-${d.key}`" :style="{ width: `${d.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${d.color}`" style="width: 28px; text-align: right">{{ d.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">Patient disposition outcomes</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <div v-if="r.loading.value" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="success" size="48" />
    </div>

    <!-- Empty state -->
    <div v-else-if="!filteredConsultations.length" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-medical-bag</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No consultations found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">
        {{ statusFilter || dispositionFilter || dateFrom || dateTo || r.search.value ? 'Try adjusting your filters.' : 'Create your first consultation to get started.' }}
      </div>
      <v-btn v-if="!statusFilter && !dispositionFilter && !dateFrom && !dateTo && !r.search.value" color="success" rounded="lg"
        prepend-icon="mdi-plus" class="text-none"
        @click="navigateTo(`${ns}/consultations/new`)">Create your first consultation</v-btn>
      <v-btn v-else variant="text" rounded="lg" class="text-none"
        prepend-icon="mdi-filter-remove" @click="clearFilters">Clear filters</v-btn>
    </div>

    <!-- Table view -->
    <v-card v-else-if="view === 'table'" flat rounded="lg" class="results-card">
      <v-data-table
        :headers="headers"
        :items="filteredConsultations"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => goTo(item.id)"
        class="consultations-table">
        <template #item.patient_name="{ item }">
          <span class="font-weight-medium">{{ item.patient_name || '—' }}</span>
        </template>
        <template #item.doctor_name="{ item }">
          <span>{{ item.doctor_name || '—' }}</span>
        </template>
        <template #item.created_at="{ value }">{{ formatDateTime(value) }}</template>
        <template #item.chief_complaint="{ value }">
          <span class="text-truncate d-inline-block" style="max-width: 220px;">
            {{ value || '—' }}
          </span>
        </template>
        <template #item.diagnosis="{ value }">
          <span class="text-truncate d-inline-block" style="max-width: 200px;">
            {{ diagnosisText(value) || '—' }}
          </span>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="tonal" :color="statusColor(statusOf(item))"
            class="text-capitalize font-weight-medium">
            <v-icon start size="14">{{ statusIcon(statusOf(item)) }}</v-icon>
            {{ statusOf(item) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
              @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
              @click="navigateTo(`${ns}/consultations/workspace/${item.id}`)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Board view (Kanban by status) -->
    <div v-else class="consult-board d-flex ga-3 overflow-x-auto pb-2">
      <div v-for="col in boardColumns" :key="col.key" class="board-column" style="min-width: 300px; flex: 1;">
        <div class="board-col-header d-flex align-center justify-space-between px-3 py-2" :class="`board-col-${col.key}`">
          <div class="d-flex align-center ga-2">
            <v-icon size="18" :color="col.color">{{ col.icon }}</v-icon>
            <span class="text-subtitle-2 font-weight-bold">{{ col.label }}</span>
          </div>
          <v-chip size="x-small" variant="flat" :color="col.color">{{ boardColumnItems(col.key).length }}</v-chip>
        </div>
        <div class="board-col-body pa-2 d-flex flex-column ga-2">
          <div
            v-for="item in boardColumnItems(col.key)" :key="item.id"
            class="board-card pa-3 rounded-lg"
            @click="goTo(item.id)"
          >
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-body-2 font-weight-bold text-truncate">{{ item.patient_name || '—' }}</span>
              <v-avatar :color="statusColor(statusOf(item))" variant="tonal" size="24" class="flex-shrink-0 ml-2">
                <v-icon size="14" :color="statusColor(statusOf(item))">{{ statusIcon(statusOf(item)) }}</v-icon>
              </v-avatar>
            </div>
            <div class="text-caption text-medium-emphasis mb-2 text-truncate">
              {{ item.chief_complaint || 'No complaint recorded' }}
            </div>
            <div class="d-flex align-center justify-space-between">
              <div class="d-flex align-center ga-1 text-caption text-medium-emphasis">
                <v-icon size="12">mdi-clock-outline</v-icon>
                {{ formatDateTime(item.created_at) }}
              </div>
              <span v-if="item.doctor_name" class="text-caption font-weight-medium text-medium-emphasis text-truncate" style="max-width: 100px">
                {{ item.doctor_name }}
              </span>
            </div>
          </div>
          <div v-if="!boardColumnItems(col.key).length" class="text-center text-caption text-medium-emphasis py-4">
            No consultations
          </div>
        </div>
      </div>
    </div>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Consultation</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete this consultation for
              <strong>{{ deleteTarget?.patient_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
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

// Doctors / clinical officers / dentists only see their own consultations
const isDoctor = ['doctor', 'clinical_officer', 'dentist'].includes(auth.role)
function loadList() {
  r.list(isDoctor ? { doctor: auth.user?.id, page_size: 1000 } : { page_size: 1000 })
}

const r = useResource('/consultations/')
onMounted(() => loadList())

const view = ref('table')
const statusOptions = ['draft', 'signed', 'locked']
const statusFilter = ref(null)
const dispositionFilter = ref(null)
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
    const day = now.getDay() === 0 ? 6 : now.getDay() - 1
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

const activeFilters = computed(() =>
  statusFilter.value || dispositionFilter.value || dateFrom.value || dateTo.value || r.search.value,
)
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)

const dispositionOptions = [
  'discharge', 'referral', 'admission', 'observation', 'transfer', 'left_ama', 'pending',
]

const boardColumns = [
  { key: 'draft', label: 'Draft', icon: 'mdi-file-edit', color: 'info' },
  { key: 'signed', label: 'Signed', icon: 'mdi-draw', color: 'primary' },
  { key: 'locked', label: 'Locked', icon: 'mdi-lock', color: 'error' },
  { key: 'completed', label: 'Completed', icon: 'mdi-check-circle', color: 'success' },
]

function boardColumnItems(statusKey) {
  return filteredConsultations.value.filter(c => statusOf(c) === statusKey)
}

const snack = reactive({ show: false, color: 'success', text: '' })

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Doctor', key: 'doctor_name', sortable: false },
  { title: 'Date', key: 'created_at', width: 160 },
  { title: 'Chief Complaint', key: 'chief_complaint', sortable: false },
  { title: 'Diagnosis', key: 'diagnosis', sortable: false },
  { title: 'Status', key: 'status', sortable: false, width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

function clearFilters() {
  statusFilter.value = null
  dispositionFilter.value = null
  dateFrom.value = ''
  dateTo.value = ''
  datePreset.value = ''
  r.search.value = ''
}

const filteredConsultations = computed(() => {
  let list = r.filtered.value
  if (statusFilter.value) list = list.filter(c => statusOf(c) === statusFilter.value)
  if (dispositionFilter.value) list = list.filter(c => (c.disposition || 'pending') === dispositionFilter.value)
  if (dateFrom.value) list = list.filter(c => {
    const d = (c.created_at || '').slice(0, 10)
    return d >= dateFrom.value
  })
  if (dateTo.value) list = list.filter(c => {
    const d = (c.created_at || '').slice(0, 10)
    return d <= dateTo.value
  })
  return list
})

function statusOf(item) {
  return item.vital_signs?.status || item.status || 'completed'
}

function diagnosisText(value) {
  if (!value) return ''
  if (Array.isArray(value)) return value.map(d => typeof d === 'string' ? d : d.description || d.code || '').filter(Boolean).join('; ')
  if (typeof value === 'object') return value.description || value.code || ''
  return String(value)
}

function statusColor(s) {
  const map = {
    draft: 'info',
    signed: 'primary',
    locked: 'error',
    completed: 'success',
    pending: 'warning',
    in_progress: 'info',
  }
  return map[s] || 'grey'
}
function statusIcon(s) {
  const map = {
    draft: 'mdi-file-edit',
    signed: 'mdi-draw',
    locked: 'mdi-lock',
    completed: 'mdi-check-circle',
    pending: 'mdi-clock',
  }
  return map[s] || 'mdi-circle-medium'
}

const totalConsultations = computed(() => filteredConsultations.value.length)

// Status distribution for horizontal bars
const statusDist = computed(() => {
  const list = filteredConsultations.value
  const total = list.length || 1
  const counts = {
    draft: list.filter(c => statusOf(c) === 'draft').length,
    signed: list.filter(c => statusOf(c) === 'signed').length,
    locked: list.filter(c => statusOf(c) === 'locked').length,
    completed: list.filter(c => statusOf(c) === 'completed').length,
  }
  return [
    { key: 'draft', label: 'Draft', icon: 'mdi-file-edit', color: 'info', count: counts.draft, pct: (counts.draft / total) * 100 },
    { key: 'signed', label: 'Signed', icon: 'mdi-draw', color: 'primary', count: counts.signed, pct: (counts.signed / total) * 100 },
    { key: 'locked', label: 'Locked', icon: 'mdi-lock', color: 'error', count: counts.locked, pct: (counts.locked / total) * 100 },
    { key: 'completed', label: 'Completed', icon: 'mdi-check-circle', color: 'success', count: counts.completed, pct: (counts.completed / total) * 100 },
  ]
})

// Disposition distribution
const dispositionDist = computed(() => {
  const list = filteredConsultations.value
  const total = list.length || 1
  const counts = {
    discharge: list.filter(c => (c.disposition || 'pending') === 'discharge').length,
    referral: list.filter(c => (c.disposition || 'pending') === 'referral').length,
    admission: list.filter(c => (c.disposition || 'pending') === 'admission').length,
    observation: list.filter(c => (c.disposition || 'pending') === 'observation').length,
    transfer: list.filter(c => (c.disposition || 'pending') === 'transfer').length,
    left_ama: list.filter(c => (c.disposition || 'pending') === 'left_ama').length,
    pending: list.filter(c => !c.disposition || c.disposition === 'pending').length,
  }
  return [
    { key: 'discharge', label: 'Discharge', icon: 'mdi-home', color: 'success', count: counts.discharge, pct: (counts.discharge / total) * 100 },
    { key: 'referral', label: 'Referral', icon: 'mdi-arrow-right', color: 'info', count: counts.referral, pct: (counts.referral / total) * 100 },
    { key: 'admission', label: 'Admission', icon: 'mdi-bed', color: 'warning', count: counts.admission, pct: (counts.admission / total) * 100 },
    { key: 'observation', label: 'Observation', icon: 'mdi-eye', color: 'secondary', count: counts.observation, pct: (counts.observation / total) * 100 },
    { key: 'transfer', label: 'Transfer', icon: 'mdi-swap-horizontal', color: 'purple', count: counts.transfer, pct: (counts.transfer / total) * 100 },
    { key: 'pending', label: 'Pending', icon: 'mdi-clock', color: 'grey', count: counts.pending, pct: (counts.pending / total) * 100 },
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
  return filteredConsultations.value.filter(c => {
    if (!c.created_at) return false
    const d = new Date(c.created_at)
    if (d < weekStart) return false
    return getDayIndex(c.created_at) === dayIdx
  }).length
}
function weekdayBarHeight(dayIdx) {
  const max = Math.max(...[0, 1, 2, 3, 4, 5, 6].map(weekdayCount), 1)
  return Math.max(6, (weekdayCount(dayIdx) / max) * 100)
}

const kpis = computed(() => {
  const list = filteredConsultations.value
  const now = new Date()
  const todayStr = now.toISOString().slice(0, 10)
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
  const today = list.filter(c => c.created_at && c.created_at.slice(0, 10) === todayStr).length
  const thisWeek = list.filter(c => c.created_at && new Date(c.created_at) >= weekAgo).length
  const followups = list.filter(c => c.vital_signs?.follow_up_date).length
  return [
    { label: 'Total', value: list.length, icon: 'mdi-medical-bag', color: 'success' },
    { label: 'Today', value: today, icon: 'mdi-calendar-today', color: 'info' },
    { label: 'This Week', value: thisWeek, icon: 'mdi-calendar-week', color: 'teal' },
    { label: 'Follow-ups Needed', value: followups, icon: 'mdi-calendar-refresh', color: 'amber' },
  ]
})

function goTo(id) { navigateTo(`${ns}/consultations/workspace/${id}`) }

function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}

async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Consultation deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    deleteTarget.value = null
  } catch {
    snack.text = r.error.value || 'Failed to delete consultation'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.consultations-table :deep(tbody tr) { cursor: pointer; }

/* ── Distribution Cards ── */
.dist-card { overflow: hidden; }
.flex-1 { flex: 1; }
.flex-shrink-0 { flex-shrink: 0; }

/* Status horizontal bars */
.status-bar-track { height: 10px; background: rgba(var(--v-theme-on-surface), 0.06); }
.status-bar-fill { height: 100%; min-width: 4px; transition: width 0.3s ease; }
.status-bar-draft { background: rgb(var(--v-theme-info)); }
.status-bar-signed { background: rgb(var(--v-theme-primary)); }
.status-bar-locked { background: rgb(var(--v-theme-error)); }
.status-bar-completed { background: rgb(var(--v-theme-success)); }

/* Disposition bars */
.disposition-bar-discharge { background: rgb(var(--v-theme-success)); }
.disposition-bar-referral { background: rgb(var(--v-theme-info)); }
.disposition-bar-admission { background: #ff9800; }
.disposition-bar-observation { background: rgb(var(--v-theme-secondary)); }
.disposition-bar-transfer { background: rgb(var(--v-theme-purple)); }
.disposition-bar-left_ama { background: #f44336; }
.disposition-bar-pending { background: #9e9e9e; }

/* Weekday bar chart */
.weekday-bar-chart { height: 70px; align-items: flex-end; }
.weekday-bar-col { height: 100%; justify-content: flex-end; }
.weekday-bar-fill {
  width: 100%; min-height: 4px; border-radius: 6px 6px 0 0;
  background: rgba(var(--v-theme-success), 0.35);
  opacity: 0.6;
  transition: height 0.3s ease, opacity 0.2s ease;
}
.weekday-bar-fill:hover { opacity: 0.85; }
.weekday-bar-today { background: rgb(var(--v-theme-success)); opacity: 0.8; }
.rounded-top { border-radius: 6px 6px 0 0; }

/* ── Board View (Kanban) ── */
.consult-board { min-height: 400px; }
.board-column {
  background: rgba(var(--v-theme-on-surface), 0.03);
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  display: flex; flex-direction: column;
}
.board-col-body { flex: 1; min-height: 200px; max-height: 60vh; overflow-y: auto; }
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
.board-col-draft { border-bottom: 2px solid #2196f3; background: rgba(33, 150, 243, 0.06); }
.board-col-signed { border-bottom: 2px solid #1976d2; background: rgba(25, 118, 210, 0.06); }
.board-col-locked { border-bottom: 2px solid #f44336; background: rgba(244, 67, 54, 0.06); }
.board-col-completed { border-bottom: 2px solid #4caf50; background: rgba(76, 175, 80, 0.06); }
</style>
