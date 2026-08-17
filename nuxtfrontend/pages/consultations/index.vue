<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 font-weight-bold mb-1">
          <v-icon color="primary" class="mr-2">mdi-medical-bag</v-icon>
          Consultations
        </h1>
        <p class="text-body-2 text-medium-emphasis mb-0">Clinical consultations and patient encounters</p>
      </div>
      <div class="d-flex ga-2">
        <v-btn variant="text" icon="mdi-download" :disabled="!filtered.length" @click="exportCSV" />
        <v-btn variant="text" icon="mdi-refresh" :loading="loading" @click="list" />
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" :to="newPath">
          New Consultation
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
      <!-- Top Diagnoses -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="xl" variant="outlined" class="h-100 analytics-card">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">Top Diagnoses</div>
              <v-chip size="x-small" variant="tonal" color="primary">{{ diagnosisCounts.length }} types</v-chip>
            </div>
            <div v-for="d in diagnosisCounts" :key="d.name" class="dept-row">
              <div class="d-flex align-center justify-space-between mb-1">
                <div class="text-body-2 text-truncate">{{ d.name }}</div>
                <div class="text-body-2 font-weight-bold text-primary">{{ d.count }}</div>
              </div>
              <div class="dept-bar-track">
                <div class="dept-bar-fill bg-primary" :style="{ width: diagPct(d.count) + '%' }" />
              </div>
            </div>
            <div v-if="!diagnosisCounts.length" class="text-center text-medium-emphasis py-4">
              <v-icon size="32" class="mb-1">mdi-clipboard-text-outline</v-icon>
              <div class="text-caption">No diagnoses recorded</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- Consultations by Doctor -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="xl" variant="outlined" class="h-100 analytics-card">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">By Doctor</div>
              <v-chip size="x-small" variant="tonal" color="info">{{ doctorCounts.length }} doctors</v-chip>
            </div>
            <div v-for="d in doctorCounts" :key="d.name" class="dept-row">
              <div class="d-flex align-center justify-space-between mb-1">
                <div class="d-flex align-center ga-2 text-body-2 text-truncate">
                  <v-icon size="small" color="info">mdi-doctor</v-icon>
                  {{ d.name }}
                </div>
                <div class="text-body-2 font-weight-bold text-info">{{ d.count }}</div>
              </div>
              <div class="dept-bar-track">
                <div class="dept-bar-fill bg-info" :style="{ width: docPct(d.count) + '%' }" />
              </div>
            </div>
            <div v-if="!doctorCounts.length" class="text-center text-medium-emphasis py-4">
              <v-icon size="32" class="mb-1">mdi-account-group-outline</v-icon>
              <div class="text-caption">No doctor data</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- Consultations Timeline (last 7 days) -->
      <v-col cols="12" md="12" lg="4">
        <v-card rounded="xl" variant="outlined" class="h-100 analytics-card">
          <v-card-text class="pa-4">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">Recent Activity</div>
              <v-chip size="x-small" variant="tonal" color="success">{{ last7Days }} this week</v-chip>
            </div>
            <div class="day-chart d-flex align-end justify-space-between ga-1">
              <div v-for="d in dayCounts" :key="d.key" class="day-bar-col">
                <div class="day-bar-value text-caption font-weight-bold text-primary">
                  {{ d.count || '' }}
                </div>
                <div class="day-bar-track">
                  <div class="day-bar bg-primary" :class="{ 'bg-success': d.isToday }"
                    :style="{ height: Math.max(dayPct(d.count), 2) + '%' }" />
                </div>
                <div class="text-caption text-medium-emphasis text-center mt-1"
                  :class="{ 'font-weight-bold text-primary': d.isToday }">
                  {{ d.label }}
                </div>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex justify-space-between text-caption text-medium-emphasis">
              <span><v-icon size="x-small" class="mr-1">mdi-clock-outline</v-icon> Last 7 days</span>
              <span>{{ last30Days }} in last 30 days</span>
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
            <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
              placeholder="Search complaint or diagnosis..." variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-autocomplete v-model="doctorFilter" :items="doctors" item-title="full_name" item-value="id"
              placeholder="Doctor" variant="outlined" density="compact" hide-details clearable :loading="doctorsLoading" />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-autocomplete v-model="patientFilter" :items="patients" item-title="full_name" item-value="id"
              placeholder="Patient" variant="outlined" density="compact" hide-details clearable :loading="patientsLoading" />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-text-field v-model="dateFrom" type="date" label="From" variant="outlined"
              density="compact" hide-details clearable />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-text-field v-model="dateTo" type="date" label="To" variant="outlined"
              density="compact" hide-details clearable />
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
      <v-data-table :headers="headers" :items="filtered" :loading="loading" :items-per-page="20"
        item-value="id" class="elevation-0" @click:row="onRowClick">
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
            </div>
          </div>
        </template>

        <template #item.doctor_name="{ item }">
          <div class="d-flex align-center ga-1">
            <v-icon size="small" color="info">mdi-doctor</v-icon>
            <span class="text-body-2">{{ item.doctor_name || '—' }}</span>
          </div>
        </template>

        <template #item.chief_complaint="{ item }">
          <div class="text-body-2 text-truncate" style="max-width: 240px;">{{ item.chief_complaint || '—' }}</div>
        </template>

        <template #item.diagnosis="{ item }">
          <div v-if="item.diagnosis && item.diagnosis.length" class="d-flex flex-wrap ga-1">
            <v-chip v-for="(d, i) in item.diagnosis.slice(0, 3)" :key="i" size="x-small" variant="tonal" color="primary">
              {{ typeof d === 'string' ? d : d.code || d.description || JSON.stringify(d) }}
            </v-chip>
            <v-chip v-if="item.diagnosis.length > 3" size="x-small" variant="tonal">
              +{{ item.diagnosis.length - 3 }}
            </v-chip>
          </div>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>

        <template #item.created_at="{ item }">
          <div class="text-body-2">{{ formatDate(item.created_at) }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatTime(item.created_at) }}</div>
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
            <v-icon size="48" color="medium-emphasis" class="mb-2">mdi-clipboard-text-off-outline</v-icon>
            <div class="text-body-1 text-medium-emphasis mb-2">No consultations found</div>
            <v-btn color="primary" variant="tonal" size="small" :to="newPath">Record consultation</v-btn>
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
              <v-chip size="small" variant="tonal" color="primary" label>
                <v-icon start size="x-small">mdi-clipboard-text-outline</v-icon>
                {{ formatDate(item.created_at) }}
              </v-chip>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                </template>
                <v-list density="compact">
                  <v-list-item prepend-icon="mdi-eye" title="View" @click="goDetail(item)" />
                  <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="goEdit(item)" />
                  <v-list-item prepend-icon="mdi-delete" title="Delete" @click="confirmDelete(item)" />
                </v-list>
              </v-menu>
            </div>

            <div class="d-flex align-center ga-2 mb-3">
              <v-avatar size="40" :color="avatarColor(item.patient_name)" variant="tonal">
                <span class="text-body-2 font-weight-bold">{{ initials(item.patient_name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 overflow-hidden">
                <div class="text-subtitle-2 font-weight-bold text-truncate">{{ item.patient_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ item.doctor_name || '—' }}</div>
              </div>
            </div>

            <v-divider class="mb-3" />

            <div class="text-body-2 mb-2" style="min-height: 40px;">
              <span class="text-medium-emphasis">Chief Complaint:</span><br />
              <span class="text-truncate d-inline-block" style="max-width: 100%;">{{ item.chief_complaint || '—' }}</span>
            </div>

            <div v-if="item.diagnosis && item.diagnosis.length" class="d-flex flex-wrap ga-1 mb-2">
              <v-chip v-for="(d, i) in item.diagnosis.slice(0, 2)" :key="i" size="x-small" variant="tonal" color="primary">
                {{ typeof d === 'string' ? d : d.code || d.description || '' }}
              </v-chip>
              <v-chip v-if="item.diagnosis.length > 2" size="x-small" variant="tonal">
                +{{ item.diagnosis.length - 2 }}
              </v-chip>
            </div>

            <v-divider class="my-2" />

            <div class="d-flex align-center justify-space-between text-caption text-medium-emphasis">
              <div class="d-flex align-center ga-1">
                <v-icon size="x-small">mdi-clock-outline</v-icon>
                {{ formatTime(item.created_at) }}
              </div>
              <div class="d-flex align-center ga-1">
                <v-icon size="x-small">mdi-pill</v-icon>
                {{ item.prescriptions?.length || 0 }} Rx
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col v-if="!loading && !filtered.length" cols="12">
        <div class="text-center py-8">
          <v-icon size="48" color="medium-emphasis" class="mb-2">mdi-clipboard-text-off-outline</v-icon>
          <div class="text-body-1 text-medium-emphasis mb-2">No consultations found</div>
          <v-btn color="primary" variant="tonal" size="small" :to="newPath">Record consultation</v-btn>
        </div>
      </v-col>
    </v-row>

    <!-- Delete Dialog -->
    <v-dialog v-model="deleteDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Consultation?</v-card-title>
        <v-card-text>
          Are you sure you want to delete the consultation for
          <strong>{{ deleteTarget?.patient_name }}</strong>?
          This action cannot be undone.
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
import { formatDate, formatDateTime } from '~/utils/format'

const route = useRoute()
const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePath = computed(() => `${ns.value}/consultations`)
const newPath = computed(() => `${basePath.value}/new`)

const { items, loading, list, remove } = useResource('/consultations/')
const patientsRes = useResource('/patients/')
const doctorsRes = useResource('/accounts/staff/')

const search = ref('')
const patients = ref([])
const patientsLoading = ref(true)
const doctors = ref([])
const doctorsLoading = ref(true)

const doctorFilter = ref(null)
const patientFilter = ref(null)
const dateFrom = ref(null)
const dateTo = ref(null)
const viewMode = ref('table')
const deleteDialog = ref(false)
const deleteTarget = ref(null)

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: true },
  { title: 'Doctor', key: 'doctor_name', sortable: true },
  { title: 'Chief Complaint', key: 'chief_complaint', sortable: true },
  { title: 'Diagnosis', key: 'diagnosis', sortable: false },
  { title: 'Date', key: 'created_at', sortable: true },
  { title: 'Actions', key: 'actions', sortable: false, align: 'end' },
]

onMounted(async () => {
  await list()
  loadOptions()
})

async function loadOptions() {
  try {
    await patientsRes.list()
    patients.value = patientsRes.items.value.map(p => ({
      ...p,
      full_name: p.user?.full_name || p.user_email || 'Unknown',
    }))
  } catch { /* ignore */ } finally { patientsLoading.value = false }
  try {
    await doctorsRes.list()
    doctors.value = doctorsRes.items.value.map(s => ({
      ...s,
      full_name: s.full_name || s.user?.full_name || s.user_email || 'Unknown',
    }))
  } catch { /* ignore */ } finally { doctorsLoading.value = false }
}

/* ---- KPIs ---- */
const kpis = computed(() => {
  const all = items.value
  const today = new Date().toISOString().split('T')[0]
  const last30 = new Date(); last30.setDate(last30.getDate() - 30)
  return [
    { key: 'total', label: 'Total', value: all.length, color: 'primary', icon: 'mdi-clipboard-text-multiple' },
    { key: 'today', label: 'Today', value: all.filter(c => c.created_at?.startsWith(today)).length, color: 'info', icon: 'mdi-today' },
    { key: 'week', label: 'This Week', value: last7Days.value, color: 'success', icon: 'mdi-calendar-week' },
    { key: 'patients', label: 'Unique Patients', value: new Set(all.map(c => c.patient)).size, color: 'teal', icon: 'mdi-account-group' },
    { key: 'diagnoses', label: 'Diagnoses', value: diagnosisCounts.value.reduce((a, b) => a + b.count, 0), color: 'purple', icon: 'mdi-clipboard-pulse-outline' },
    { key: 'rx', label: 'With Prescriptions', value: all.filter(c => c.prescriptions?.length).length, color: 'orange', icon: 'mdi-pill' },
  ]
})

/* ---- Analytics ---- */
const diagnosisCounts = computed(() => {
  const all = items.value
  const map = {}
  all.forEach(c => {
    if (!c.diagnosis) return
    (Array.isArray(c.diagnosis) ? c.diagnosis : [c.diagnosis]).forEach(d => {
      const name = typeof d === 'string' ? d : (d.code || d.description || 'Unknown')
      map[name] = (map[name] || 0) + 1
    })
  })
  return Object.entries(map).map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count).slice(0, 6)
})

const doctorCounts = computed(() => {
  const all = items.value
  const map = {}
  all.forEach(c => {
    const n = c.doctor_name || 'Unassigned'
    map[n] = (map[n] || 0) + 1
  })
  return Object.entries(map).map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count).slice(0, 6)
})

const dayCounts = computed(() => {
  const all = items.value
  const map = {}
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  const today = new Date()
  for (let i = 6; i >= 0; i--) {
    const d = new Date(today); d.setDate(d.getDate() - i)
    const dw = d.getDay()
    const ds = d.toISOString().split('T')[0]
    map[dw] = { count: 0, isToday: i === 0 }
  }
  all.forEach(c => {
    if (!c.created_at) return
    const ds = c.created_at.split('T')[0]
    const d = new Date(ds + 'T00:00:00')
    const diff = Math.floor((today - d) / 86400000)
    if (diff >= 0 && diff <= 6) {
      const dw = d.getDay()
      if (map[dw]) map[dw].count++
    }
  })
  return days.map((label, i) => ({ key: i, label, count: map[i]?.count || 0, isToday: map[i]?.isToday || false }))
})

const last7Days = computed(() => dayCounts.value.reduce((a, b) => a + b.count, 0))
const last30Days = computed(() => {
  const today = new Date()
  return items.value.filter(c => {
    if (!c.created_at) return false
    const d = new Date(c.created_at)
    return (today - d) / 86400000 <= 30
  }).length
})

function diagPct(count) {
  const max = Math.max(...diagnosisCounts.value.map(d => d.count), 1)
  return Math.round((count / max) * 100)
}
function docPct(count) {
  const max = Math.max(...doctorCounts.value.map(d => d.count), 1)
  return Math.round((count / max) * 100)
}
function dayPct(count) {
  const max = Math.max(...dayCounts.value.map(d => d.count), 1)
  return Math.round((count / max) * 100)
}

/* ---- Filters ---- */
const hasActiveFilters = computed(() =>
  search.value || doctorFilter.value || patientFilter.value || dateFrom.value || dateTo.value
)
function clearFilters() {
  search.value = ''
  doctorFilter.value = null
  patientFilter.value = null
  dateFrom.value = null
  dateTo.value = null
}

const filtered = computed(() => {
  let r = items.value
  if (doctorFilter.value) r = r.filter(c => c.doctor === doctorFilter.value)
  if (patientFilter.value) r = r.filter(c => c.patient === patientFilter.value)
  if (dateFrom.value) r = r.filter(c => c.created_at && c.created_at.split('T')[0] >= dateFrom.value)
  if (dateTo.value) r = r.filter(c => c.created_at && c.created_at.split('T')[0] <= dateTo.value)
  if (search.value) {
    const q = search.value.toLowerCase()
    r = r.filter(c =>
      (c.chief_complaint || '').toLowerCase().includes(q) ||
      (c.doctor_name || '').toLowerCase().includes(q) ||
      (c.patient_name || '').toLowerCase().includes(q) ||
      (Array.isArray(c.diagnosis) ? c.diagnosis.join(' ') : JSON.stringify(c.diagnosis || '')).toLowerCase().includes(q)
    )
  }
  return r
})

/* ---- Navigation ---- */
function goDetail(item) { navigateTo(`${basePath.value}/${item.id}`) }
function goEdit(item) { navigateTo(`${basePath.value}/${item.id}/edit`) }
function onRowClick(_, { item }) { goDetail(item) }

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
  try { return new Date(t).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) } catch { return '' }
}

/* ---- CSV Export ---- */
function exportCSV() {
  const rows = [['Patient', 'Doctor', 'Chief Complaint', 'Diagnosis', 'Treatment Plan', 'Date']]
  filtered.value.forEach(c => {
    const diag = Array.isArray(c.diagnosis) ? c.diagnosis.map(d => typeof d === 'string' ? d : (d.code || d.description || '')).join('; ') : ''
    rows.push([c.patient_name, c.doctor_name, c.chief_complaint, diag, c.treatment_plan, c.created_at])
  })
  const csv = rows.map(r => r.map(c => `"${(c || '').replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'consultations.csv'
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
  await list()
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

.dept-row { margin-bottom: 10px; }
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

.day-chart { height: 120px; padding-top: 8px; }
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
</style>
