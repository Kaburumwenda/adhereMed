<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Patients" subtitle="Registered patient directory"
      icon="mdi-account-multiple" color="indigo">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
          :disabled="!filteredPatients.length" @click="exportCsv">Export</v-btn>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
          @click="navigateTo('/clinics/patients/new')">New Patient</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, ID, phone, email…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="genderFilter" :items="genderOptions"
            label="Gender" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="bloodFilter" :items="bloodOptions"
            label="Blood group" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="1">
          <v-text-field v-model="dateFrom" type="date" label="From"
            variant="outlined" density="compact" hide-details @update:model-value="datePreset = ''" />
        </v-col>
        <v-col cols="6" md="1">
          <v-text-field v-model="dateTo" type="date" label="To"
            variant="outlined" density="compact" hide-details @update:model-value="datePreset = ''" />
        </v-col>
        <v-col cols="12" md="2" class="d-flex align-center justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
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
        <v-chip v-if="genderFilter" size="small" closable @click:close="genderFilter = null"
          variant="tonal" color="info">
          <v-icon start size="14">mdi-gender-male-female</v-icon>Gender: {{ genderFilter }}
        </v-chip>
        <v-chip v-if="bloodFilter" size="small" closable @click:close="bloodFilter = null"
          variant="tonal" color="red">
          <v-icon start size="14">mdi-water</v-icon>Blood: {{ bloodFilter }}
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
      <!-- Gender Distribution -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">GENDER DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-gender-male-female</v-icon>
          </div>
          <div class="d-flex flex-column ga-2 mb-2">
            <div v-for="g in genderDist" :key="g.key" class="d-flex align-center ga-2">
              <v-icon size="16" :color="g.color">{{ g.icon }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0" style="width: 80px">{{ g.label }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`gender-bar-${g.key}`" :style="{ width: `${g.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${g.color}`" style="width: 32px; text-align: right">{{ g.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ totalPatients }} patients total</div>
        </v-card>
      </v-col>

      <!-- Blood Group Distribution -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">BLOOD GROUP DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-water</v-icon>
          </div>
          <div class="blood-bars d-flex align-end ga-1 mb-3">
            <div v-for="b in bloodDist" :key="b.type" class="flex-1 d-flex flex-column align-center">
              <span class="text-caption font-weight-bold mb-1" :class="b.count ? 'text-red-darken-3' : 'text-medium-emphasis'">{{ b.count }}</span>
              <div class="blood-bar-fill rounded-top" :class="b.count ? 'blood-bar-active' : 'blood-bar-empty'" :style="{ height: `${b.barHeight}%` }" />
            </div>
          </div>
          <div class="d-flex ga-1">
            <span v-for="b in bloodDist" :key="b.type" class="flex-1 text-caption text-center font-weight-medium" :class="b.count ? 'text-red-darken-3' : 'text-medium-emphasis'">{{ b.type }}</span>
          </div>
        </v-card>
      </v-col>

      <!-- Patient Status / Activity -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">PATIENT STATUS</span>
            <v-icon size="16" color="medium-emphasis">mdi-chart-donut</v-icon>
          </div>
          <div class="d-flex flex-column ga-2 mb-2">
            <div v-for="s in statusDist" :key="s.label" class="d-flex align-center ga-2">
              <v-icon size="16" :color="s.color">{{ s.icon }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0" style="width: 110px">{{ s.label }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`status-bar-${s.key}`" :style="{ width: `${s.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${s.color}`" style="width: 32px; text-align: right">{{ s.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ totalPatients }} patients total</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" size="48" />
      </div>

      <!-- Empty state -->
      <div v-else-if="!filteredPatients.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-account-search</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No patients found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ activeFilters ? 'Try adjusting your filters.' : 'Create your first patient to get started.' }}
        </div>
        <v-btn v-if="!activeFilters" color="primary" rounded="lg" prepend-icon="mdi-plus"
          @click="navigateTo('/clinics/patients/new')">Create your first patient</v-btn>
        <v-btn v-else variant="text" rounded="lg" prepend-icon="mdi-filter-remove"
          @click="clearFilters">Clear filters</v-btn>
      </div>

      <!-- Table view -->
      <v-data-table v-else-if="view === 'table'"
        :headers="headers"
        :items="filteredPatients"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => goTo(item.id)"
        class="patients-table">
        <template #item.full_name="{ item }">
          <div class="d-flex align-center py-2">
            <v-avatar :color="avatarColor(item)" size="40" class="mr-3">
              <span class="text-white font-weight-bold text-body-2">{{ initials(item) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ displayName(item) || '—' }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ item.user_email || item.user?.email || '' }}
              </div>
            </div>
          </div>
        </template>
        <template #item.patient_number="{ value }">
          <span class="font-monospace text-caption">{{ value || '—' }}</span>
        </template>
        <template #item.gender="{ value }">
          <v-chip size="x-small" variant="tonal"
            :color="value === 'male' ? 'info' : value === 'female' ? 'pink' : 'grey'"
            class="text-capitalize">{{ value || '—' }}</v-chip>
        </template>
        <template #item.age="{ item }">
          <div class="d-flex flex-column">
            <span>{{ ageOf(item.date_of_birth) ?? '—' }}</span>
            <span v-if="item.date_of_birth" class="text-caption text-medium-emphasis">
              {{ formatDate(item.date_of_birth) }}
            </span>
          </div>
        </template>
        <template #item.phone="{ item }">
          <span v-if="item.user?.phone">{{ item.user.phone }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.email="{ item }">
          <span v-if="item.user_email || item.user?.email">
            {{ item.user_email || item.user?.email }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.created_at="{ value }">{{ formatDate(value) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
              @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
              @click="goToEdit(item.id)" />
          </div>
        </template>
      </v-data-table>

      <!-- Grid view -->
      <div v-else class="pa-3">
        <v-row dense>
          <v-col v-for="p in filteredPatients" :key="p.id" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="patient-card pa-4 h-100" hover @click="goTo(p.id)">
              <div class="d-flex align-center">
                <v-avatar :color="avatarColor(p)" size="48" class="mr-3">
                  <span class="text-white font-weight-bold">{{ initials(p) }}</span>
                </v-avatar>
                <div class="flex-grow-1" style="min-width:0">
                  <div class="font-weight-medium text-truncate">{{ displayName(p) || '—' }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    {{ p.patient_number || '—' }}
                  </div>
                </div>
                <v-chip v-if="p.blood_type" size="x-small" variant="flat" color="red-lighten-5"
                  class="text-red-darken-3 font-weight-bold">{{ p.blood_type }}</v-chip>
              </div>
              <v-divider class="my-3" />
              <div class="d-flex flex-wrap ga-2 mb-2">
                <v-chip size="x-small" variant="tonal"
                  :color="p.gender === 'male' ? 'info' : p.gender === 'female' ? 'pink' : 'grey'"
                  class="text-capitalize">{{ p.gender || 'unknown' }}</v-chip>
                <v-chip size="x-small" variant="tonal" color="indigo">
                  <v-icon size="12" start>mdi-cake-variant</v-icon>
                  {{ ageOf(p.date_of_birth) ?? '—' }} yrs
                </v-chip>
                <v-chip v-if="p.insurance_provider" size="x-small" variant="tonal" color="green">
                  <v-icon size="12" start>mdi-shield-check</v-icon>Insured
                </v-chip>
              </div>
              <div v-if="p.user?.phone" class="d-flex align-center text-caption text-medium-emphasis mb-1">
                <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ p.user.phone }}
              </div>
              <div v-if="p.user_email || p.user?.email"
                class="d-flex align-center text-caption text-medium-emphasis text-truncate">
                <v-icon size="14" class="mr-1">mdi-email</v-icon>
                <span class="text-truncate">{{ p.user_email || p.user?.email }}</span>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const ns = '/clinics'

const r = useResource('/patients/')
onMounted(() => r.list({ page_size: 1000 }))

const view = ref('table')
const genderFilter = ref(null)
const bloodFilter = ref(null)
const dateFrom = ref('')
const dateTo = ref('')
const datePreset = ref('')

// Quick date range presets
const datePresets = [
  { key: 'today', label: 'Today' },
  { key: 'this_week', label: 'This Week' },
  { key: 'this_month', label: 'This Month' },
  { key: 'last_month', label: 'Last Month' },
  { key: 'this_year', label: 'This Year' },
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
  } else if (key === 'this_week') {
    const day = now.getDay() === 0 ? 6 : now.getDay() - 1
    const monday = new Date(now); monday.setDate(now.getDate() - day)
    const sunday = new Date(monday); sunday.setDate(monday.getDate() + 6)
    dateFrom.value = fmtDate(monday)
    dateTo.value = fmtDate(sunday)
  } else if (key === 'this_month') {
    dateFrom.value = fmtDate(new Date(now.getFullYear(), now.getMonth(), 1))
    dateTo.value = fmtDate(new Date(now.getFullYear(), now.getMonth() + 1, 0))
  } else if (key === 'last_month') {
    dateFrom.value = fmtDate(new Date(now.getFullYear(), now.getMonth() - 1, 1))
    dateTo.value = fmtDate(new Date(now.getFullYear(), now.getMonth(), 0))
  } else if (key === 'this_year') {
    dateFrom.value = fmtDate(new Date(now.getFullYear(), 0, 1))
    dateTo.value = fmtDate(new Date(now.getFullYear(), 11, 31))
  } else {
    dateFrom.value = ''
    dateTo.value = ''
  }
}
const datePresetLabel = computed(() => datePresets.find(p => p.key === datePreset.value)?.label || '')

const genderOptions = [
  { title: 'Male', value: 'male' },
  { title: 'Female', value: 'female' },
  { title: 'Other', value: 'other' },
]
const bloodOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown']

const headers = [
  { title: 'Patient #', key: 'patient_number', width: 130 },
  { title: 'Full Name', key: 'full_name', sortable: false },
  { title: 'Gender', key: 'gender', width: 110 },
  { title: 'Age', key: 'age', width: 90, sortable: false },
  { title: 'Phone', key: 'phone', sortable: false, width: 140 },
  { title: 'Email', key: 'email', sortable: false },
  { title: 'Created', key: 'created_at', width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]

const activeFilters = computed(() =>
  genderFilter.value || bloodFilter.value || dateFrom.value || dateTo.value || r.search.value,
)

function clearFilters() {
  genderFilter.value = null
  bloodFilter.value = null
  dateFrom.value = ''
  dateTo.value = ''
  datePreset.value = ''
  r.search.value = ''
}

const filteredPatients = computed(() => {
  let list = r.filtered.value
  if (genderFilter.value) list = list.filter(p => p.gender === genderFilter.value)
  if (bloodFilter.value) {
    if (bloodFilter.value === 'Unknown') {
      list = list.filter(p => !p.blood_type)
    } else {
      list = list.filter(p => p.blood_type === bloodFilter.value)
    }
  }
  if (dateFrom.value) list = list.filter(p => {
    const d = (p.created_at || '').slice(0, 10)
    return d >= dateFrom.value
  })
  if (dateTo.value) list = list.filter(p => {
    const d = (p.created_at || '').slice(0, 10)
    return d <= dateTo.value
  })
  return list
})

const kpis = computed(() => {
  const list = filteredPatients.value
  const now = new Date()
  const monthAgo = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate())
  const newCount = list.filter(p => p.created_at && new Date(p.created_at) >= monthAgo).length
  const insured = list.filter(p => p.insurance_provider).length
  return [
    { label: 'Total Patients', value: list.length, icon: 'mdi-account-multiple', color: 'indigo' },
    { label: 'New this month', value: newCount, icon: 'mdi-account-plus', color: 'teal' },
    { label: 'Insured', value: insured, icon: 'mdi-shield-check', color: 'success' },
    { label: 'With Allergies', value: list.filter(p => p.allergies?.length).length, icon: 'mdi-alert', color: 'warning' },
  ]
})

const totalPatients = computed(() => filteredPatients.value.length)

// Gender distribution for bar chart
const genderDist = computed(() => {
  const list = filteredPatients.value
  const male = list.filter(p => p.gender === 'male').length
  const female = list.filter(p => p.gender === 'female').length
  const other = list.filter(p => p.gender && p.gender !== 'male' && p.gender !== 'female').length
  const total = list.length || 1
  return [
    { key: 'male', label: 'Male', icon: 'mdi-gender-male', color: 'info', count: male, pct: (male / total) * 100 },
    { key: 'female', label: 'Female', icon: 'mdi-gender-female', color: 'orange', count: female, pct: (female / total) * 100 },
    { key: 'other', label: 'Other', icon: 'mdi-gender-transgenic', color: 'grey', count: other, pct: (other / total) * 100 },
  ]
})

// Blood group distribution for bar chart
const bloodDist = computed(() => {
  const list = filteredPatients.value
  const types = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
  const counts = types.map(t => list.filter(p => p.blood_type === t).length)
  const max = Math.max(...counts, 1)
  return types.map((t, i) => ({
    type: t,
    count: counts[i],
    barHeight: Math.max(6, (counts[i] / max) * 100),
  }))
})

// Patient status distribution for horizontal bars
const statusDist = computed(() => {
  const list = filteredPatients.value
  const total = list.length || 1
  const withAllergies = list.filter(p => p.allergies?.length).length
  const withChronic = list.filter(p => p.chronic_conditions?.length).length
  const insured = list.filter(p => p.insurance_provider).length
  const uninsured = list.filter(p => !p.insurance_provider).length
  return [
    { key: 'insured', label: 'Insured', icon: 'mdi-shield-check', color: 'success', count: insured, pct: (insured / total) * 100 },
    { key: 'uninsured', label: 'Uninsured', icon: 'mdi-shield-off', color: 'grey', count: uninsured, pct: (uninsured / total) * 100 },
    { key: 'allergies', label: 'Allergies', icon: 'mdi-alert', color: 'error', count: withAllergies, pct: (withAllergies / total) * 100 },
    { key: 'chronic', label: 'Chronic', icon: 'mdi-heart', color: 'warning', count: withChronic, pct: (withChronic / total) * 100 },
  ]
})

// ── Helpers ────────────────────────────────────────────────────────
function ageOf(dob) {
  if (!dob) return null
  const d = new Date(dob)
  if (isNaN(d)) return null
  const t = new Date()
  let age = t.getFullYear() - d.getFullYear()
  const m = t.getMonth() - d.getMonth()
  if (m < 0 || (m === 0 && t.getDate() < d.getDate())) age--
  return age
}
function displayName(p) {
  if (p.user_name) return p.user_name
  const fn = p.user?.first_name || ''
  const ln = p.user?.last_name || ''
  return `${fn} ${ln}`.trim() || p.user_email || p.user?.email || ''
}
function initials(p) {
  const n = displayName(p) || '?'
  const parts = n.split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return ((parts[0][0] || '') + (parts[1]?.[0] || '')).toUpperCase()
}
function avatarColor(p) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(p.id || 0) % colors.length]
}

function goTo(id) { navigateTo(`${ns}/patients/${id}`) }
function goToEdit(id) { navigateTo(`${ns}/patients/${id}/edit`) }

function exportCsv() {
  const rows = filteredPatients.value
  if (!rows.length) return
  const cols = ['patient_number', 'name', 'email', 'phone', 'date_of_birth', 'age', 'gender', 'blood_type', 'insurance_provider']
  const header = cols.join(',')
  const body = rows.map(p => [
    p.patient_number || '',
    `"${(displayName(p) || '').replace(/"/g, '""')}"`,
    p.user_email || p.user?.email || '',
    p.user?.phone || '',
    p.date_of_birth || '',
    ageOf(p.date_of_birth) ?? '',
    p.gender || '',
    p.blood_type || '',
    `"${(p.insurance_provider || '').replace(/"/g, '""')}"`,
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `clinic_patients_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.patients-table :deep(tbody tr) { cursor: pointer; }
.patient-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.patient-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06);
}
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }

/* ── Distribution Cards ── */
.dist-card { overflow: hidden; }
.flex-1 { flex: 1; }

/* Gender horizontal bars (same style as status bars) */
.gender-bar-male { background: rgb(var(--v-theme-info)); }
.gender-bar-female { background: #ff9800; }
.gender-bar-other { background: rgb(var(--v-theme-grey)); }

/* Blood group bar chart */
.blood-bars { height: 70px; }
.blood-bar-fill {
  width: 100%;
  min-height: 4px;
  transition: height 0.3s ease, opacity 0.2s ease;
}
.blood-bar-active { background: #d32f2f; opacity: 0.7; }
.blood-bar-active:hover { opacity: 0.9; }
.blood-bar-empty { background: rgba(var(--v-theme-on-surface), 0.08); }

/* Status horizontal bars */
.status-bar-track {
  height: 10px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.status-bar-fill {
  height: 100%;
  min-height: 10px;
  transition: width 0.3s ease;
}
.status-bar-insured { background: rgb(var(--v-theme-success)); }
.status-bar-uninsured { background: rgba(128, 128, 128, 0.5); }
.status-bar-allergies { background: rgb(var(--v-theme-error)); }
.status-bar-chronic { background: rgb(var(--v-theme-warning)); }

.flex-shrink-0 { flex-shrink: 0; }
</style>
