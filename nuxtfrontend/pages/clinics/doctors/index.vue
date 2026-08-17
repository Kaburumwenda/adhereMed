<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ═══ Header ════════════════════════════════════════════════ -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="blue-lighten-5" size="48">
        <v-icon color="blue-darken-2" size="28">mdi-doctor</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Doctors</div>
        <div class="text-body-2 text-medium-emphasis">Manage doctor profiles, specializations, availability and verification</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="blue" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openCreate">Add Doctor</v-btn>
    </div>

    <!-- ═══ KPI cards ═════════════════════════════════════════════ -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" sm="4" md="2">
        <v-card flat rounded="lg" class="kpi-card pa-4 text-center cursor-pointer"
          :class="{ 'kpi-card--active': activeFilter === k.filter }" @click="k.filter && k.filter !== 'pending' && toggleKpiFilter(k.filter)">
          <v-avatar :color="k.color" size="40" class="mb-2" variant="tonal">
            <v-icon size="22">{{ k.icon }}</v-icon>
          </v-avatar>
          <div class="text-h5 font-weight-bold">{{ k.value }}</div>
          <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══ Stats analytics row ═══════════════════════════════════ -->
    <v-row dense class="mb-4">
      <v-col v-if="!doctors.length" cols="12">
        <v-card flat rounded="xl" class="stat-card pa-4 text-center">
          <v-icon color="blue" size="32" class="mb-2">mdi-chart-box</v-icon>
          <div class="text-subtitle-2 font-weight-bold mb-1">Doctor Analytics</div>
          <div class="text-caption text-medium-emphasis">Specialization distribution, availability schedule and verification stats will appear here once doctors are added.</div>
        </v-card>
      </v-col>
      <template v-else>
        <v-col cols="12" md="4">
          <v-card flat rounded="lg" class="stat-card pa-3 h-100">
            <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="blue">mdi-medical-bag</v-icon>Specialization Distribution</div>
            <div v-for="s in specStats" :key="s.label" class="d-flex align-center ga-2 mb-1">
              <v-chip color="blue" variant="tonal" size="x-small" class="font-weight-medium text-truncate" style="max-width: 120px">{{ s.label }}</v-chip>
              <v-progress-linear :model-value="s.pct" height="8" rounded color="blue" class="flex-grow-1" />
              <span class="text-caption text-medium-emphasis" style="min-width: 24px; text-align: right">{{ s.count }}</span>
            </div>
            <div v-if="!specStats.length" class="text-center text-caption text-medium-emphasis py-2">No specializations set</div>
          </v-card>
        </v-col>
        <v-col cols="12" md="4">
          <v-card flat rounded="lg" class="stat-card pa-3 h-100">
            <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="teal">mdi-calendar-check</v-icon>Availability (Days)</div>
            <div v-for="d in dayStats" :key="d.label" class="d-flex align-center ga-2 mb-1">
              <v-chip :color="d.count > 0 ? 'teal' : 'grey'" variant="tonal" size="x-small" class="font-weight-medium" style="min-width: 36px">{{ d.short }}</v-chip>
              <v-progress-linear :model-value="dayMax ? (d.count / dayMax * 100) : 0" height="8" rounded color="teal" class="flex-grow-1" />
              <span class="text-caption text-medium-emphasis" style="min-width: 24px; text-align: right">{{ d.count }}</span>
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="4">
          <v-card flat rounded="lg" class="stat-card pa-3 h-100">
            <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="orange">mdi-cash-multiple</v-icon>Consultation Fees (Top 5)</div>
            <div v-for="d in topFeeDoctors" :key="d.id" class="d-flex align-center ga-2 mb-1">
              <v-chip color="orange" variant="tonal" size="x-small" class="font-weight-medium text-truncate" style="max-width: 110px">{{ d.name }}</v-chip>
              <v-progress-linear :model-value="feeMax ? (Number(d.consultation_fee) / feeMax * 100) : 0" height="8" rounded color="orange" class="flex-grow-1" />
              <span class="text-caption text-medium-emphasis" style="min-width: 60px; text-align: right">{{ formatMoney(d.consultation_fee) }}</span>
            </div>
            <div v-if="!topFeeDoctors.length" class="text-center text-caption text-medium-emphasis py-2">No fees set</div>
          </v-card>
        </v-col>
      </template>
    </v-row>

    <!-- ═══ Filter bar ════════════════════════════════════════════ -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="searchText" prepend-inner-icon="mdi-magnify" placeholder="Search name, email, specialization, license..." variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="specFilter" :items="specializationOptions" label="Specialization" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusOptions" label="Availability" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="verifiedFilter" :items="verifiedOptions" label="Verification" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2" class="d-flex align-center justify-end">
          <v-btn v-if="hasFilters" size="small" variant="text" class="text-none" prepend-icon="mdi-filter-remove" @click="clearFilters">Clear</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- ═══ Results ═══════════════════════════════════════════════ -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="loading" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="blue" size="48" />
      </div>
      <div v-else-if="!filteredDoctors.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-doctor</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No doctors found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">{{ hasFilters ? 'Try adjusting your filters.' : 'Add your first doctor to get started.' }}</div>
        <v-btn v-if="!hasFilters" color="blue" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openCreate">Add Doctor</v-btn>
        <v-btn v-else variant="text" rounded="lg" class="text-none" prepend-icon="mdi-filter-remove" @click="clearFilters">Clear filters</v-btn>
      </div>
      <v-data-table v-else :headers="headers" :items="filteredDoctors" :items-per-page="20" item-value="id" hover @click:row="(_, { item }) => goTo(item.id)" class="doctors-table">
        <template #item.doctor="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar :color="avatarColor(item.user_name)" size="40" variant="tonal">
              <v-img v-if="item.profile_picture_url" :src="item.profile_picture_url" />
              <span class="text-caption font-weight-bold">{{ initials(item.user_name) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">Dr. {{ item.user_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.user_email || '' }}</div>
            </div>
          </div>
        </template>
        <template #item.specialization="{ item }">
          <v-chip size="small" variant="tonal" color="blue" class="font-weight-medium">{{ item.specialization || '—' }}</v-chip>
        </template>
        <template #item.license_number="{ item }">
          <span class="text-body-2">{{ item.license_number || '—' }}</span>
        </template>
        <template #item.years_of_experience="{ value }">
          <span class="text-body-2">{{ value }} yrs</span>
        </template>
        <template #item.consultation_fee="{ value }">
          <v-chip v-if="value" size="small" variant="tonal" color="teal">{{ formatMoney(value) }}</v-chip>
          <span v-else class="text-caption text-medium-emphasis">—</span>
        </template>
        <template #item.is_accepting_patients="{ item }">
          <v-chip size="small" :variant="item.is_accepting_patients ? 'flat' : 'outlined'" :color="item.is_accepting_patients ? 'success' : 'grey'" prepend-icon="mdi-circle-medium">
            {{ item.is_accepting_patients ? 'Available' : 'Unavailable' }}
          </v-chip>
        </template>
        <template #item.is_verified="{ item }">
          <v-chip size="small" :variant="item.is_verified ? 'flat' : 'outlined'" :color="item.is_verified ? 'green' : 'warning'" :prepend-icon="item.is_verified ? 'mdi-check-decagram' : 'mdi-clock-outline'">
            {{ item.is_verified ? 'Verified' : 'Pending' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small" @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small" @click="navigateTo(`${ns}/doctors/${item.id}/edit`)" />
            <v-menu location="bottom left">
              <template #activator="{ props }">
                <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-check-decagram" :title="item.is_verified ? 'Unverify' : 'Verify'" @click="toggleVerified(item)" />
                <v-list-item prepend-icon="mdi-calendar-clock" :title="item.is_accepting_patients ? 'Set Unavailable' : 'Set Available'" @click="toggleAccepting(item)" />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error" @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ Create dialog ══════════════════════════════════════════ -->
    <v-dialog v-model="createDialog" max-width="700" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="blue-lighten-5" size="36" class="mr-3"><v-icon color="blue-darken-2">mdi-doctor-plus</v-icon></v-avatar>
          <span class="text-h6 font-weight-bold">Add Doctor Profile</span>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="closeCreate" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-alert type="info" variant="tonal" density="compact" class="mb-3" prepend-icon="mdi-information">
            Select an existing staff user to create a doctor profile for.
          </v-alert>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="createForm.user" :items="staffOptions" item-title="title" item-value="value" label="Staff User *" variant="outlined" density="compact" :loading="staffLoading" prepend-inner-icon="mdi-account" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="createForm.specialization" label="Specialization *" variant="outlined" density="compact" prepend-inner-icon="mdi-medical-bag" placeholder="e.g. Cardiology" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="createForm.license_number" label="License Number *" variant="outlined" density="compact" prepend-inner-icon="mdi-card-account-details" placeholder="e.g. KMPDB/A/12345" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="createForm.qualification" label="Qualification" variant="outlined" density="compact" prepend-inner-icon="mdi-school" placeholder="e.g. MBChB, MD" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="createForm.practice_type" :items="practiceTypeOptions" label="Practice Type" variant="outlined" density="compact" prepend-inner-icon="mdi-hospital-building" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="createForm.years_of_experience" type="number" min="0" label="Years of Experience" variant="outlined" density="compact" prepend-inner-icon="mdi-timer-sand" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="createForm.consultation_fee" type="number" min="0" label="Consultation Fee" variant="outlined" density="compact" prepend-inner-icon="mdi-cash" placeholder="0.00" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="createForm.bio" label="Bio" rows="2" auto-grow variant="outlined" density="compact" prepend-inner-icon="mdi-text-account" placeholder="Brief professional bio..." />
            </v-col>
            <v-col cols="12">
              <div class="text-caption text-medium-emphasis mb-1 d-flex align-center"><v-icon size="14" class="mr-1">mdi-translate</v-icon>Languages</div>
              <div class="d-flex flex-wrap ga-1">
                <v-chip v-for="lang in languageOptions" :key="lang" size="small" :variant="createForm.languages.includes(lang) ? 'flat' : 'outlined'" :color="createForm.languages.includes(lang) ? 'blue' : undefined" @click="toggleLang(lang)">
                  {{ lang }}
                </v-chip>
              </div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="closeCreate">Cancel</v-btn>
          <v-btn color="blue" rounded="lg" class="text-none" prepend-icon="mdi-content-save" :loading="saving" :disabled="!canSaveCreate" @click="saveCreate">Create Profile</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Delete dialog ══════════════════════════════════════════ -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Doctor Profile</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3"><v-icon color="error">mdi-delete-alert</v-icon></v-avatar>
            <div>
              Delete profile for <strong>Dr. {{ deleteTarget?.user_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This will remove the doctor profile. The user account remains.</div>
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

    <!-- ═══ Snackbar ═══════════════════════════════════════════════ -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const ns = '/clinics'

const loading = ref(false)
const doctors = ref([])
const searchText = ref('')
const specFilter = ref('')
const statusFilter = ref('')
const verifiedFilter = ref('')
const activeFilter = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })
function showToast(t, c = 'success') { snack.text = t; snack.color = c; snack.show = true }

const headers = [
  { title: 'Doctor', key: 'doctor', sortable: false },
  { title: 'Specialization', key: 'specialization', sortable: false, width: 160 },
  { title: 'License #', key: 'license_number', sortable: false, width: 130 },
  { title: 'Exp.', key: 'years_of_experience', width: 80 },
  { title: 'Fee', key: 'consultation_fee', width: 130 },
  { title: 'Availability', key: 'is_accepting_patients', sortable: false, width: 130 },
  { title: 'Status', key: 'is_verified', sortable: false, width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]

const statusOptions = [
  { title: 'Available', value: 'true' },
  { title: 'Unavailable', value: 'false' },
]
const verifiedOptions = [
  { title: 'Verified', value: 'true' },
  { title: 'Pending', value: 'false' },
]
const practiceTypeOptions = [
  { title: 'Independent', value: 'independent' },
  { title: 'Hospital-Affiliated', value: 'hospital' },
]
const languageOptions = ['English', 'Swahili', 'French', 'Arabic', 'Spanish', 'Portuguese', 'Amharic', 'Hausa', 'German', 'Hindi']

function toggleLang(lang) {
  const idx = createForm.languages.indexOf(lang)
  if (idx >= 0) createForm.languages.splice(idx, 1)
  else createForm.languages.push(lang)
}

function avatarColor(name) {
  if (!name) return 'grey'
  const colors = ['blue', 'teal', 'indigo', 'green', 'orange', 'pink', 'cyan', 'purple']
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function initials(name) {
  if (!name) return '?'
  return name.split(' ').filter(s => s).slice(0, 2).map(s => s[0]).join('').toUpperCase()
}

const specializationOptions = computed(() => {
  const set = new Set(doctors.value.map(d => d.specialization).filter(Boolean))
  return Array.from(set).sort()
})
const hasFilters = computed(() => searchText.value || specFilter.value || statusFilter.value || verifiedFilter.value || activeFilter.value)

const filteredDoctors = computed(() => {
  let list = doctors.value
  if (activeFilter.value === 'verified') list = list.filter(d => d.is_verified)
  else if (activeFilter.value === 'available') list = list.filter(d => d.is_accepting_patients)
  else if (activeFilter.value === 'pending') list = list.filter(d => !d.is_verified)
  if (specFilter.value) list = list.filter(d => d.specialization === specFilter.value)
  if (statusFilter.value === 'true') list = list.filter(d => d.is_accepting_patients)
  if (statusFilter.value === 'false') list = list.filter(d => !d.is_accepting_patients)
  if (verifiedFilter.value === 'true') list = list.filter(d => d.is_verified)
  if (verifiedFilter.value === 'false') list = list.filter(d => !d.is_verified)
  if (searchText.value) {
    const q = searchText.value.toLowerCase()
    list = list.filter(d =>
      (d.user_name || '').toLowerCase().includes(q) ||
      (d.user_email || '').toLowerCase().includes(q) ||
      (d.specialization || '').toLowerCase().includes(q) ||
      (d.license_number || '').toLowerCase().includes(q),
    )
  }
  return list
})

function toggleKpiFilter(f) {
  activeFilter.value = activeFilter.value === f ? '' : f
}

const kpis = computed(() => {
  const list = doctors.value
  return [
    { label: 'Total Doctors', value: list.length, icon: 'mdi-doctor', color: 'blue', filter: '' },
    { label: 'Available', value: list.filter(d => d.is_accepting_patients).length, icon: 'mdi-calendar-check', color: 'success', filter: 'available' },
    { label: 'Verified', value: list.filter(d => d.is_verified).length, icon: 'mdi-check-decagram', color: 'green', filter: 'verified' },
    { label: 'Pending', value: list.filter(d => !d.is_verified).length, icon: 'mdi-clock-outline', color: 'warning', filter: 'pending' },
    { label: 'Specialties', value: specializationOptions.value.length, icon: 'mdi-medical-bag', color: 'indigo', filter: '' },
    { label: 'Avg. Exp.', value: list.length ? Math.round(list.reduce((a, d) => a + (d.years_of_experience || 0), 0) / list.length) + ' yrs' : '0 yrs', icon: 'mdi-timer-sand', color: 'teal', filter: '' },
  ]
})

// Stats
const specStats = computed(() => {
  const map = {}
  doctors.value.forEach(d => {
    if (d.specialization) map[d.specialization] = (map[d.specialization] || 0) + 1
  })
  const entries = Object.entries(map).map(([label, count]) => ({ label, count, pct: 0 }))
    .sort((a, b) => b.count - a.count).slice(0, 6)
  const max = entries.length ? entries[0].count : 1
  entries.forEach(e => { e.pct = Math.round(e.count / max * 100) })
  return entries
})
const dayStats = computed(() => {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
  const short = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
  const counts = [0, 0, 0, 0, 0, 0, 0]
  doctors.value.forEach(d => {
    (d.available_days || []).forEach(day => {
      const idx = days.indexOf(day)
      if (idx >= 0) counts[idx]++
    })
  })
  return days.map((label, i) => ({ label, short: short[i], count: counts[i] }))
})
const dayMax = computed(() => Math.max(1, ...dayStats.value.map(d => d.count)))
const topFeeDoctors = computed(() => {
  return doctors.value.filter(d => d.consultation_fee && Number(d.consultation_fee) > 0)
    .map(d => ({ ...d, name: d.user_name || '—' }))
    .sort((a, b) => Number(b.consultation_fee) - Number(a.consultation_fee))
    .slice(0, 5)
})
const feeMax = computed(() => topFeeDoctors.value.length ? Math.max(...topFeeDoctors.value.map(d => Number(d.consultation_fee))) : 1)

function clearFilters() {
  searchText.value = ''; specFilter.value = ''; statusFilter.value = ''; verifiedFilter.value = ''; activeFilter.value = ''
}

// =========================
// REST actions
// =========================
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/doctors/', { params: { page_size: 1000 } })
    doctors.value = data.results || data
  } catch (e) {
    console.error(e); showToast('Failed to load doctors', 'error')
  } finally { loading.value = false }
}
function goTo(id) { navigateTo(`${ns}/doctors/${id}`) }

async function toggleVerified(item) {
  try {
    const { data } = await $api.patch(`/doctors/${item.id}/toggle_verified/`)
    Object.assign(item, data)
    showToast(`Dr. ${item.user_name} ${item.is_verified ? 'verified' : 'unverified'}`, item.is_verified ? 'success' : 'warning')
  } catch (e) { showToast('Failed to update', 'error') }
}
async function toggleAccepting(item) {
  try {
    const { data } = await $api.patch(`/doctors/${item.id}/toggle_accepting/`)
    Object.assign(item, data)
    showToast(`Dr. ${item.user_name} ${item.is_accepting_patients ? 'now available' : 'now unavailable'}`, item.is_accepting_patients ? 'success' : 'warning')
  } catch (e) { showToast('Failed to update', 'error') }
}

// =========================
// Create dialog
// =========================
const createDialog = ref(false)
const createForm = reactive({
  user: null, specialization: '', license_number: '', qualification: '',
  practice_type: 'independent', years_of_experience: 0, consultation_fee: 0,
  bio: '', languages: [],
})
const staffOptions = ref([])
const staffLoading = ref(false)
const saving = ref(false)

const canSaveCreate = computed(() => createForm.user && createForm.specialization && createForm.license_number)

function openCreate() {
  createDialog.value = true
  Object.assign(createForm, { user: null, specialization: '', license_number: '', qualification: '', practice_type: 'independent', years_of_experience: 0, consultation_fee: 0, bio: '', languages: [] })
  if (!staffOptions.value.length) loadStaff()
}
function closeCreate() { createDialog.value = false }

async function loadStaff() {
  staffLoading.value = true
  try {
    const { data } = await $api.get('/auth/staff/', { params: { page_size: 1000 } })
    const list = data.results || data
    staffOptions.value = list
      .filter(u => ['doctor', 'clinical_officer', 'admin', 'superadmin'].includes(u.role))
      .map(u => ({ title: `${u.first_name || ''} ${u.last_name || ''} — ${u.email}`.trim(), value: u.id }))
  } catch (e) { console.error(e) }
  finally { staffLoading.value = false }
}

async function saveCreate() {
  if (!canSaveCreate.value) return
  saving.value = true
  try {
    const payload = {
      user: createForm.user,
      specialization: createForm.specialization,
      license_number: createForm.license_number,
      qualification: createForm.qualification,
      practice_type: createForm.practice_type,
      years_of_experience: createForm.years_of_experience || 0,
      consultation_fee: createForm.consultation_fee || 0,
      bio: createForm.bio,
      languages: createForm.languages,
      is_accepting_patients: true,
    }
    const { data } = await $api.post('/doctors/', payload)
    showToast(`Doctor profile created for Dr. ${data.user_name || '—'}`, 'success')
    createDialog.value = false
    await load()
  } catch (e) { showToast(e?.response?.data?.detail || 'Failed to create', 'error') }
  finally { saving.value = false }
}

// =========================
// Delete
// =========================
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const deleting = ref(false)
function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }
async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await $api.delete(`/doctors/${deleteTarget.value.id}/`)
    showToast('Doctor profile deleted')
    deleteDialog.value = false; deleteTarget.value = null
    await load()
  } catch (e) { showToast('Failed to delete', 'error') }
  finally { deleting.value = false }
}

onMounted(load)
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s; }
.kpi-card--active { border-color: rgb(var(--v-theme-blue)); background: rgba(0, 130, 255, 0.06); }
.kpi-card:hover { background: rgba(var(--v-theme-on-surface), 0.03); }
.stat-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.doctors-table :deep(tbody tr) { cursor: pointer; }
.cursor-pointer { cursor: pointer; }
</style>
