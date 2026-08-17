<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ── Page header ───────────────────────────────────────────── -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-account-multiple</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Patients</div>
        <div class="text-body-2 text-medium-emphasis">
          Registered patient directory
        </div>
      </div>
      <v-spacer />
      <v-text-field
        v-if="$vuetify.display.xs"
        v-model="r.search.value"
        prepend-inner-icon="mdi-magnify"
        placeholder="Search…"
        variant="outlined" density="compact" hide-details clearable
        class="mb-2"
      />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             :disabled="!filteredPatients.length" @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
             :to="patientLink('new')">New Patient</v-btn>
    </div>

    <!-- ── KPI stat cards ─────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="44" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline text-medium-emphasis" style="line-height:1.1">
                {{ k.label }}
              </div>
              <div class="text-h5 font-weight-bold" style="line-height:1.2">
                {{ k.value }}
              </div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Analytics cards ─────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <!-- Gender distribution ── donut + legend -->
      <v-col cols="12" sm="6" md="3">
        <v-card flat rounded="lg" class="analytics-card h-100 pa-4">
          <div class="d-flex align-center mb-2">
            <v-icon size="18" color="indigo-darken-2" class="mr-2">mdi-gender-male-female</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Gender</span>
          </div>
          <div class="d-flex align-center justify-center ga-4">
            <v-progress-circular :size="84" :width="8" :model-value="100" color="info" rounded>
              <template #default>
                <div class="text-center">
                  <div class="text-h6 font-weight-bold">{{ genderDist.total }}</div>
                  <div class="text-caption text-medium-emphasis">Total</div>
                </div>
              </template>
            </v-progress-circular>
            <div class="d-flex flex-column ga-1 flex-grow-1">
              <div v-for="g in genderDist.items" :key="g.label"
                   class="d-flex align-center ga-2 cursor-pointer"
                   @click="g.filter ? g.filter() : null">
                <v-sheet :color="g.color" width="10" height="10" rounded="circle" />
                <span class="text-body-2 flex-grow-1">{{ g.label }}</span>
                <span class="text-body-2 font-weight-bold">{{ g.value }}</span>
                <span class="text-caption text-medium-emphasis"
                      style="min-width:36px;text-align:right">{{ g.pct }}</span>
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- Blood group distribution ── horizontal bars -->
      <v-col cols="12" sm="6" md="3">
        <v-card flat rounded="lg" class="analytics-card h-100 pa-4">
          <div class="d-flex align-center mb-2">
            <v-icon size="18" color="red-darken-2" class="mr-2">mdi-water</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Blood Groups</span>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="b in bloodDist" :key="b.label" class="d-flex align-center ga-2 cursor-pointer"
                 @click="bloodFilter = bloodFilter === b.label ? null : b.label">
              <span class="text-caption font-weight-bold" style="min-width:28px;text-align:center">
                {{ b.label }}
              </span>
              <div class="flex-grow-1 bg-grey-lighten-3 rounded" style="height:10px;overflow:hidden">
                <div :style="`width:${b.pctNum}%;height:100%`" 
                     class="bg-red-darken-2 rounded transition-all" />
              </div>
              <span class="text-caption text-medium-emphasis" style="min-width:20px;text-align:right">
                {{ b.value }}
              </span>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- Age distribution ── horizontal bars -->
      <v-col cols="12" sm="6" md="3">
        <v-card flat rounded="lg" class="analytics-card h-100 pa-4">
          <div class="d-flex align-center mb-2">
            <v-icon size="18" color="teal-darken-2" class="mr-2">mdi-chart-bar</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Age Distribution</span>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="a in ageDist" :key="a.label" class="d-flex align-center ga-2 cursor-pointer"
                 @click="ageFilter = ageFilter === a.value ? null : a.value">
              <span class="text-caption" style="min-width:50px">{{ a.short }}</span>
              <div class="flex-grow-1 bg-grey-lighten-3 rounded" style="height:10px;overflow:hidden">
                <div :style="`width:${a.pctNum}%;height:100%`" 
                     class="bg-teal-darken-2 rounded transition-all" />
              </div>
              <span class="text-caption text-medium-emphasis" style="min-width:20px;text-align:right">
                {{ a.count }}
              </span>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- Patient flags ── stat tiles -->
      <v-col cols="12" sm="6" md="3">
        <v-card flat rounded="lg" class="analytics-card h-100 pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon size="18" color="amber-darken-3" class="mr-2">mdi-flag-outline</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Patient Flags</span>
          </div>
          <v-row dense>
            <v-col v-for="f in flagStats" :key="f.label" cols="6">
              <div class="flag-tile pa-2 rounded-lg" :class="f.bg"
                   @click="f.action ? f.action() : null">
                <div class="d-flex align-center justify-center mb-1">
                  <v-icon :color="f.color" size="20">{{ f.icon }}</v-icon>
                </div>
                <div class="text-center">
                  <div class="text-h6 font-weight-bold" :class="f.textColor">
                    {{ f.value }}
                  </div>
                  <div class="text-caption text-medium-emphasis">{{ f.label }}</div>
                </div>
              </div>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, ID, phone, email…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="genderFilter" :items="genderOptions"
            label="Gender" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="bloodFilter" :items="bloodOptions"
            label="Blood type" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="ageFilter" :items="ageOptions"
            label="Age range" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" sm="3" md="1" class="d-flex align-center justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
          </v-btn-toggle>
        </v-col>
        <v-col cols="6" sm="3" md="1" class="d-flex justify-end">
          <v-btn
            size="small" variant="text" class="text-none"
            prepend-icon="mdi-filter-remove"
            :disabled="!activeFilters" @click="clearFilters"
          >Clear</v-btn>
        </v-col>
      </v-row>
      <div v-if="activeFilters" class="px-1 pt-2 d-flex flex-wrap ga-2">
        <v-chip v-if="genderFilter" size="small" closable @click:close="genderFilter = null"
                variant="tonal" color="info">
          <v-icon start size="14">mdi-gender-male-female</v-icon>
          Gender: {{ genderFilter }}
        </v-chip>
        <v-chip v-if="bloodFilter" size="small" closable @click:close="bloodFilter = null"
                variant="tonal" color="red">
          <v-icon start size="14">mdi-water</v-icon>
          Blood: {{ bloodFilter }}
        </v-chip>
        <v-chip v-if="ageFilter" size="small" closable @click:close="ageFilter = null"
                variant="tonal" color="teal">
          <v-icon start size="14">mdi-clock</v-icon>
          Age: {{ ageOptions.find(a => a.value === ageFilter)?.title || ageFilter }}
        </v-chip>
      </div>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <v-data-table
        v-if="view === 'table'"
        :headers="headers"
        :items="filteredPatients"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => goTo(item.id)"
        class="patients-table"
      >
        <template #loading><v-skeleton-loader type="table-row@6" /></template>
        <template #item.user="{ item }">
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
        <template #item.patient_number="{ item, value }">
          <div class="d-flex flex-column">
            <span class="font-monospace text-caption">{{ value || '—' }}</span>
            <span v-if="item?.patient_id" class="text-caption text-medium-emphasis">{{ item.patient_id }}</span>
          </div>
        </template>
        <template #item.age="{ item }">
          <div class="d-flex flex-column">
            <span>{{ ageOf(item.date_of_birth) ?? '—' }}</span>
            <span v-if="item.date_of_birth" class="text-caption text-medium-emphasis">
              {{ formatDate(item.date_of_birth) }}
            </span>
          </div>
        </template>
        <template #item.gender="{ value }">
          <v-chip size="x-small" variant="tonal"
                  :color="value === 'male' ? 'info' : value === 'female' ? 'pink' : 'grey'"
                  class="text-capitalize">
            {{ value || '—' }}
          </v-chip>
        </template>
        <template #item.blood_type="{ value }">
          <v-chip v-if="value" size="x-small" variant="flat" color="red-lighten-5"
                  class="text-red-darken-3 font-weight-bold">{{ value }}</v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.contact="{ item }">
          <div v-if="item.user?.phone" class="d-flex align-center">
            <v-icon size="14" class="mr-1" color="medium-emphasis">mdi-phone</v-icon>
            <span class="text-body-2">{{ item.user.phone }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.flags="{ item }">
          <div class="d-flex align-center">
            <v-tooltip v-if="(item.allergies || []).length"
                       :text="`Allergies: ${(item.allergies || []).join(', ')}`">
              <template #activator="{ props }">
                <v-icon v-bind="props" color="red-darken-2" size="18" class="mr-1">mdi-alert-circle</v-icon>
              </template>
            </v-tooltip>
            <v-tooltip v-if="(item.chronic_conditions || []).length"
                       :text="`Chronic: ${(item.chronic_conditions || []).join(', ')}`">
              <template #activator="{ props }">
                <v-icon v-bind="props" color="amber-darken-3" size="18" class="mr-1">mdi-pulse</v-icon>
              </template>
            </v-tooltip>
            <v-tooltip v-if="item.insurance_provider" :text="`Insured: ${item.insurance_provider}`">
              <template #activator="{ props }">
                <v-icon v-bind="props" color="green-darken-2" size="18">mdi-shield-check</v-icon>
              </template>
            </v-tooltip>
          </div>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
                   @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
                   @click="goToEdit(item.id)" />
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item :to="patientLink(item.id, 'edit')" prepend-icon="mdi-pencil">
                  <v-list-item-title>Edit</v-list-item-title>
                </v-list-item>
                <v-list-item :to="appointmentsLink(item.id)" prepend-icon="mdi-calendar-plus">
                  <v-list-item-title>New Appointment</v-list-item-title>
                </v-list-item>
                <v-list-item :to="consultationsLink(item.id)" prepend-icon="mdi-medical-bag">
                  <v-list-item-title>View Consultations</v-list-item-title>
                </v-list-item>
                <v-divider />
                <v-list-item @click="confirmDelete(item)" prepend-icon="mdi-delete" base-color="error">
                  <v-list-item-title>Delete</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-10 text-center">
            <v-icon size="64" color="grey-lighten-1">mdi-account-search</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No patients found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Try adjusting your filters or add a new patient.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
                   :to="patientLink('new')">New Patient</v-btn>
          </div>
        </template>
      </v-data-table>

      <!-- Grid view -->
      <div v-else class="pa-3">
        <div v-if="r.loading.value" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="primary" />
        </div>
        <div v-else-if="!filteredPatients.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-account-search</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No patients found</div>
          <div class="text-body-2 text-medium-emphasis mb-4">
            Try adjusting your filters or add a new patient.
          </div>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
                 :to="patientLink('new')">New Patient</v-btn>
        </div>
        <v-row v-else dense>
          <v-col v-for="p in filteredPatients" :key="p.id" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="patient-card pa-4 h-100" hover
                    @click="goTo(p.id)">
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
                        class="text-capitalize">
                  {{ p.gender || 'unknown' }}
                </v-chip>
                <v-chip size="x-small" variant="tonal" color="indigo">
                  <v-icon size="12" start>mdi-cake-variant</v-icon>
                  {{ ageOf(p.date_of_birth) ?? '—' }} yrs
                </v-chip>
                <v-chip v-if="p.insurance_provider" size="x-small" variant="tonal" color="green">
                  <v-icon size="12" start>mdi-shield-check</v-icon>
                  Insured
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
              <div v-if="(p.allergies || []).length || (p.chronic_conditions || []).length"
                   class="mt-2 d-flex ga-2">
                <v-tooltip v-if="(p.allergies || []).length"
                           :text="`Allergies: ${(p.allergies || []).join(', ')}`">
                  <template #activator="{ props }">
                    <v-icon v-bind="props" color="red-darken-2" size="18">mdi-alert-circle</v-icon>
                  </template>
                </v-tooltip>
                <v-tooltip v-if="(p.chronic_conditions || []).length"
                           :text="`Chronic: ${(p.chronic_conditions || []).join(', ')}`">
                  <template #activator="{ props }">
                    <v-icon v-bind="props" color="amber-darken-3" size="18">mdi-pulse</v-icon>
                  </template>
                </v-tooltip>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </div>
    </v-card>

    <!-- ── Delete confirmation dialog ────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Patient</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete
              <strong>{{ displayName(deleteTarget) }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">
                Patient #{{ deleteTarget?.patient_number || '—' }} — This action cannot be undone.
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

    <!-- ── Snackbar ───────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const route = useRoute()
const router = useRouter()

// Determine if we're in the /hos or /clinics namespace to generate correct internal links
const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')

function patientLink(id, sub) {
  const base = `${ns.value}/patients`
  if (id === 'new') return `${base}/new`
  if (sub === 'edit') return `${base}/${id}/edit`
  return `${base}/${id}`
}
function appointmentsLink(id) {
  return `${ns.value}/appointments?patient=${id}`
}
function consultationsLink(id) {
  return `${ns.value}/consultations?patient=${id}`
}

function goTo(id) { router.push(patientLink(id)) }
function goToEdit(id) { router.push(patientLink(id, 'edit')) }

const r = useResource('/patients/')
onMounted(() => r.list())

const view = ref('table')
const genderFilter = ref(null)
const bloodFilter = ref(null)
const ageFilter = ref(null)

// ── Delete flow ────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const deleting = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

function confirmDelete(p) {
  deleteTarget.value = p
  deleteDialog.value = true
}

async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Patient deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
  } catch {
    snack.text = 'Failed to delete patient'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}

// ── Filter helpers ─────────────────────────────────────────────────
const genderOptions = [
  { title: 'Male', value: 'male' },
  { title: 'Female', value: 'female' },
  { title: 'Other', value: 'other' },
]
const bloodOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
const ageOptions = [
  { title: '0-12 (Child)', value: 'child' },
  { title: '13-17 (Teen)', value: 'teen' },
  { title: '18-39 (Adult)', value: 'adult' },
  { title: '40-64 (Mid)', value: 'mid' },
  { title: '65+ (Senior)', value: 'senior' },
]

const activeFilters = computed(() =>
  genderFilter.value || bloodFilter.value || ageFilter.value || r.search.value
)

function clearFilters() {
  genderFilter.value = null
  bloodFilter.value = null
  ageFilter.value = null
  r.search.value = ''
}

const headers = [
  { title: 'Patient', key: 'user', sortable: false },
  { title: 'Patient #', key: 'patient_number', width: 130 },
  { title: 'Age', key: 'age', width: 80, sortable: false },
  { title: 'Gender', key: 'gender', width: 110 },
  { title: 'Blood', key: 'blood_type', width: 90 },
  { title: 'Contact', key: 'contact', sortable: false },
  { title: 'Flags', key: 'flags', sortable: false, width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

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
function ageBucket(dob) {
  const a = ageOf(dob)
  if (a == null) return null
  if (a <= 12) return 'child'
  if (a <= 17) return 'teen'
  if (a <= 39) return 'adult'
  if (a <= 64) return 'mid'
  return 'senior'
}
function displayName(p) {
  if (p.user_name) return p.user_name
  const fn = p.user?.first_name || ''
  const ln = p.user?.last_name || ''
  const full = `${fn} ${ln}`.trim()
  return full || p.user_email || p.user?.email || ''
}
function initials(p) {
  const n = displayName(p) || '?'
  const parts = n.split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return ((parts[0][0] || '') + (parts[1]?.[0] || '')).toUpperCase()
}
function avatarColor(p) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  const key = (p.id || 0) % colors.length
  return colors[key]
}

const filteredPatients = computed(() => {
  let list = r.filtered.value
  if (genderFilter.value) list = list.filter(p => p.gender === genderFilter.value)
  if (bloodFilter.value)  list = list.filter(p => p.blood_type === bloodFilter.value)
  if (ageFilter.value)    list = list.filter(p => ageBucket(p.date_of_birth) === ageFilter.value)
  return list
})

const kpis = computed(() => {
  const list = r.items.value
  const monthAgo = Date.now() - 30 * 24 * 3.6e6
  const newCount = list.filter(p => p.created_at && new Date(p.created_at).getTime() >= monthAgo).length
  const female = list.filter(p => p.gender === 'female').length
  const male = list.filter(p => p.gender === 'male').length
  const insured = list.filter(p => !!p.insurance_provider).length
  return [
    { label: 'Total Patients', value: list.length, icon: 'mdi-account-multiple', color: 'indigo' },
    { label: 'New (30 days)', value: newCount, icon: 'mdi-account-plus', color: 'teal' },
    { label: 'F / M', value: `${female} / ${male}`, icon: 'mdi-human-male-female', color: 'pink' },
    { label: 'Insured', value: insured, icon: 'mdi-shield-check', color: 'green' },
  ]
})

// ── Analytics: gender distribution ────────────────────────────────
const genderDist = computed(() => {
  const list = r.items.value
  const total = list.length
  const male = list.filter(p => p.gender === 'male').length
  const female = list.filter(p => p.gender === 'female').length
  const other = list.filter(p => p.gender && !['male','female'].includes(p.gender)).length
  const unknown = list.filter(p => !p.gender).length
  const pct = (n) => total ? Math.round(n / total * 100) + '%' : '0%'
  return {
    total,
    items: [
      { label: 'Male', value: male, pct: pct(male), color: 'info',
        filter: () => { genderFilter.value = genderFilter.value === 'male' ? null : 'male' } },
      { label: 'Female', value: female, pct: pct(female), color: 'pink',
        filter: () => { genderFilter.value = genderFilter.value === 'female' ? null : 'female' } },
      ...(other ? [{ label: 'Other', value: other, pct: pct(other), color: 'grey',
        filter: () => { genderFilter.value = genderFilter.value === 'other' ? null : 'other' } }] : []),
      ...(unknown ? [{ label: 'Unknown', value: unknown, pct: pct(unknown), color: 'grey-lighten-1' }] : []),
    ]
  }
})

// ── Analytics: blood group distribution ───────────────────────────
const bloodDist = computed(() => {
  const list = r.items.value
  const total = list.length || 1
  return ['A+','A-','B+','B-','AB+','AB-','O+','O-'].map(type => {
    const value = list.filter(p => p.blood_type === type).length
    return { label: type, value, pctNum: Math.round(value / total * 100) }
  })
})

// ── Analytics: age distribution ──────────────────────────────────
const ageDist = computed(() => {
  const list = r.items.value
  const total = list.length || 1
  const buckets = [
    { label: '0-12 (Child)', short: 'Child', value: 'child', count: 0 },
    { label: '13-17 (Teen)', short: 'Teen', value: 'teen', count: 0 },
    { label: '18-39 (Adult)', short: 'Adult', value: 'adult', count: 0 },
    { label: '40-64 (Mid)', short: 'Mid', value: 'mid', count: 0 },
    { label: '65+ (Senior)', short: 'Senior', value: 'senior', count: 0 },
  ]
  for (const p of list) {
    const bucket = ageBucket(p.date_of_birth)
    const found = buckets.find(b => b.value === bucket)
    if (found) found.count++
  }
  return buckets.map(b => ({
    label: b.label, short: b.short, value: b.value, count: b.count,
    pctNum: Math.round(b.count / total * 100),
  }))
})

// ── Analytics: patient flags ─────────────────────────────────────
const flagStats = computed(() => {
  const list = r.items.value
  const allergyCount = list.filter(p => (p.allergies || []).length > 0).length
  const chronicCount = list.filter(p => (p.chronic_conditions || []).length > 0).length
  const insuredCount = list.filter(p => !!p.insurance_provider).length
  const missingDob = list.filter(p => !p.date_of_birth).length
  return [
    { label: 'Allergies', value: allergyCount, icon: 'mdi-alert-circle',
      color: 'red-darken-2', textColor: 'text-red-darken-2', bg: 'bg-red-lighten-5' },
    { label: 'Chronic', value: chronicCount, icon: 'mdi-pulse',
      color: 'amber-darken-3', textColor: 'text-amber-darken-3', bg: 'bg-amber-lighten-5' },
    { label: 'Insured', value: insuredCount, icon: 'mdi-shield-check',
      color: 'green-darken-2', textColor: 'text-green-darken-2', bg: 'bg-green-lighten-5' },
    { label: 'Missing DOB', value: missingDob, icon: 'mdi-help-circle',
      color: 'grey-darken-1', textColor: 'text-medium-emphasis', bg: 'bg-grey-lighten-3' },
  ]
})

function exportCsv() {
  const rows = filteredPatients.value
  if (!rows.length) return
  const cols = ['patient_number', 'name', 'email', 'phone', 'date_of_birth', 'age', 'gender', 'blood_type', 'national_id', 'insurance_provider']
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
    p.national_id || '',
    `"${(p.insurance_provider || '').replace(/"/g, '""')}"`,
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `patients_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: box-shadow 150ms ease;
}
.analytics-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
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
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
}
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.cursor-pointer { cursor: pointer; }
.transition-all { transition: width 300ms ease; }
.flag-tile { transition: transform 100ms ease; cursor: default; }
.flag-tile:hover { transform: translateY(-1px); }
</style>
