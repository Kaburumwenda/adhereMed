<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="deep-purple-lighten-5" size="48">
        <v-icon color="deep-purple-darken-2" size="28">mdi-account-multiple</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Patients</div>
        <div class="text-body-2 text-medium-emphasis">Radiology patient directory</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/radiology/patients/new">
        New Patient
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
            <div>
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, ID, phone, email…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="genderFilter" :items="genderOptions"
            label="Gender" variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="bloodFilter" :items="bloodOptions"
            label="Blood type" variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="ageFilter" :items="ageOptions"
            label="Age range" variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="1" class="d-flex justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- Results -->
    <v-card flat rounded="lg" class="mt-3">
      <v-data-table
        v-if="view === 'table'"
        :headers="headers"
        :items="filteredPatients"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => $router.push(`/radiology/patients/${item.id}`)"
        class="patients-table"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.user="{ item }">
          <div class="d-flex align-center py-2">
            <v-avatar :color="avatarColor(item)" size="36" class="mr-3">
              <span class="text-white font-weight-bold">{{ initials(item) }}</span>
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
        <template #item.age="{ item }">
          <span>{{ ageOf(item.date_of_birth) ?? '—' }}</span>
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
          <v-tooltip v-if="(item.allergies || []).length" text="Has allergies">
            <template #activator="{ props }">
              <v-icon v-bind="props" color="red-darken-2" size="18" class="mr-1">mdi-alert-circle</v-icon>
            </template>
          </v-tooltip>
          <v-tooltip v-if="(item.chronic_conditions || []).length" text="Chronic condition(s)">
            <template #activator="{ props }">
              <v-icon v-bind="props" color="amber-darken-3" size="18" class="mr-1">mdi-pulse</v-icon>
            </template>
          </v-tooltip>
          <v-tooltip v-if="item.insurance_provider" text="Insured">
            <template #activator="{ props }">
              <v-icon v-bind="props" color="green-darken-2" size="18" class="mr-1">mdi-shield-check</v-icon>
            </template>
          </v-tooltip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
                   @click="$router.push(`/radiology/patients/${item.id}`)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
                   @click="$router.push(`/radiology/patients/${item.id}/edit`)" />
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-account-search</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No patients found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Try adjusting your filters or add a new patient.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/radiology/patients/new">
              New Patient
            </v-btn>
          </div>
        </template>
      </v-data-table>

      <!-- Grid view -->
      <div v-else class="pa-3">
        <div v-if="r.loading.value" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="primary" />
        </div>
        <div v-else-if="!filteredPatients.length" class="pa-8 text-center">
          <v-icon size="56" color="grey-lighten-1">mdi-account-search</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-2">No patients found</div>
        </div>
        <v-row v-else dense>
          <v-col v-for="p in filteredPatients" :key="p.id" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="patient-card pa-3 h-100" hover
                    @click="$router.push(`/radiology/patients/${p.id}`)">
              <div class="d-flex align-center">
                <v-avatar :color="avatarColor(p)" size="44" class="mr-3">
                  <span class="text-white font-weight-bold">{{ initials(p) }}</span>
                </v-avatar>
                <div class="flex-grow-1 min-width-0">
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
              <div v-if="p.user?.phone" class="d-flex align-center text-caption text-medium-emphasis">
                <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ p.user.phone }}
              </div>
              <div v-if="p.user_email || p.user?.email" class="d-flex align-center text-caption text-medium-emphasis text-truncate">
                <v-icon size="14" class="mr-1">mdi-email</v-icon>
                <span class="text-truncate">{{ p.user_email || p.user?.email }}</span>
              </div>
              <div v-if="(p.allergies || []).length || (p.chronic_conditions || []).length"
                   class="mt-2 d-flex ga-1">
                <v-tooltip v-if="(p.allergies || []).length"
                           :text="`Allergies: ${(p.allergies || []).join(', ')}`">
                  <template #activator="{ props }">
                    <v-icon v-bind="props" color="red-darken-2" size="16">mdi-alert-circle</v-icon>
                  </template>
                </v-tooltip>
                <v-tooltip v-if="(p.chronic_conditions || []).length"
                           :text="`Chronic: ${(p.chronic_conditions || []).join(', ')}`">
                  <template #activator="{ props }">
                    <v-icon v-bind="props" color="amber-darken-3" size="16">mdi-pulse</v-icon>
                  </template>
                </v-tooltip>
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

const r = useResource('/patients/')
onMounted(() => r.list())

const view = ref('table')
const genderFilter = ref(null)
const bloodFilter = ref(null)
const ageFilter = ref(null)

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

const headers = [
  { title: 'Patient', key: 'user', sortable: false },
  { title: 'Patient #', key: 'patient_number', width: 130 },
  { title: 'Age', key: 'age', width: 70, sortable: false },
  { title: 'Gender', key: 'gender', width: 110 },
  { title: 'Blood', key: 'blood_type', width: 90 },
  { title: 'Contact', key: 'contact', sortable: false },
  { title: 'Flags', key: 'flags', sortable: false, width: 110 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
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
  const colors = ['deep-purple', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'indigo', 'green-darken-1', 'orange-darken-2']
  return colors[(p.id || 0) % colors.length]
}

const filteredPatients = computed(() => {
  let list = r.filtered.value
  if (genderFilter.value) list = list.filter(p => p.gender === genderFilter.value)
  if (bloodFilter.value) list = list.filter(p => p.blood_type === bloodFilter.value)
  if (ageFilter.value) list = list.filter(p => ageBucket(p.date_of_birth) === ageFilter.value)
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
    { label: 'Total Patients', value: list.length, icon: 'mdi-account-multiple', color: 'deep-purple' },
    { label: 'New (30 days)', value: newCount, icon: 'mdi-account-plus', color: 'teal' },
    { label: 'Female / Male', value: `${female} / ${male}`, icon: 'mdi-human-male-female', color: 'pink' },
    { label: 'Insured', value: insured, icon: 'mdi-shield-check', color: 'green' },
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
  a.download = `radiology_patients_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
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
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
