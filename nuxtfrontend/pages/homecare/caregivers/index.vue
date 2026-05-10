<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- Hero -->
    <HomecareHero
      title="Caregivers"
      subtitle="Field nurses and health-care assistants delivering care in patients' homes."
      eyebrow="HOMECARE · TEAM"
      icon="mdi-account-heart"
      :chips="[
        { icon: 'mdi-account-multiple', label: `${all.length} caregivers` },
        { icon: 'mdi-medical-bag',      label: `${counts.nurse} nurses` },
        { icon: 'mdi-hand-heart',       label: `${counts.hca} HCAs` },
        { icon: 'mdi-check-circle',     label: `${counts.available} available` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-account-plus" class="text-none" to="/homecare/caregivers/new">
          <span class="text-teal-darken-2 font-weight-bold">Add caregiver</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Category tabs -->
    <v-card rounded="xl" elevation="0" class="mt-4 hc-card pa-2">
      <v-tabs v-model="categoryTab" align-tabs="start" color="teal"
              density="comfortable" class="hc-cat-tabs">
        <v-tab value="all">
          <v-icon icon="mdi-account-group" start /> All
          <v-chip size="x-small" variant="tonal" class="ml-2">{{ all.length }}</v-chip>
        </v-tab>
        <v-tab value="nurse">
          <v-icon icon="mdi-medical-bag" start /> Nurses
          <v-chip size="x-small" variant="tonal" color="indigo" class="ml-2">{{ counts.nurse }}</v-chip>
        </v-tab>
        <v-tab value="hca">
          <v-icon icon="mdi-hand-heart" start /> Health Care Assistants
          <v-chip size="x-small" variant="tonal" color="pink" class="ml-2">{{ counts.hca }}</v-chip>
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Filter bar -->
    <v-card rounded="xl" elevation="0" class="mt-3 pa-3 hc-card">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                      placeholder="Search by name, email, license…" density="comfortable"
                      variant="outlined" hide-details rounded="lg"
                      style="max-width:360px;" clearable />
        <v-select v-model="employmentFilter" :items="employmentOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Employment" style="max-width:200px;" />
        <v-select v-model="availabilityFilter"
                  :items="[{ title:'Available', value:true },{ title:'Off duty', value:false }]"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Availability" style="max-width:180px;" />
        <v-spacer />
        <v-btn-toggle v-model="view" mandatory color="teal" variant="outlined"
                      rounded="lg" density="comfortable">
          <v-btn :value="'cards'" size="small" class="text-none">
            <v-icon icon="mdi-view-grid" />
          </v-btn>
          <v-btn :value="'table'" size="small" class="text-none">
            <v-icon icon="mdi-table" />
          </v-btn>
        </v-btn-toggle>
        <v-btn variant="text" size="small" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </v-card>

    <!-- Cards view -->
    <div v-if="view === 'cards'" class="mt-3">
      <v-row v-if="filtered.length" dense>
        <v-col v-for="c in filtered" :key="c.id" cols="12" sm="6" md="4" lg="3">
          <v-card rounded="xl" elevation="0" class="hc-cg-card overflow-hidden h-100"
                  :to="`/homecare/caregivers/${c.id}`" hover>
            <div class="hc-cg-band" :style="{ background: catMeta(c.category).gradient }" />
            <div class="pa-4">
              <div class="d-flex align-center ga-3">
                <v-avatar size="56" :color="catMeta(c.category).color" variant="flat" class="hc-cg-avatar">
                  <span class="text-h6 font-weight-bold text-white">{{ initials(c) }}</span>
                </v-avatar>
                <div class="flex-grow-1 min-w-0">
                  <div class="text-subtitle-1 font-weight-bold text-truncate">
                    {{ c.user?.full_name || c.user?.email || 'Caregiver' }}
                  </div>
                  <v-chip size="x-small" :color="catMeta(c.category).color" variant="tonal">
                    <v-icon :icon="catMeta(c.category).icon" start size="12" />
                    {{ catMeta(c.category).label }}
                  </v-chip>
                </div>
              </div>

              <div class="text-caption text-medium-emphasis mt-3">
                <div v-if="c.user?.email">
                  <v-icon icon="mdi-email" size="12" class="mr-1" />{{ c.user.email }}
                </div>
                <div v-if="c.license_number">
                  <v-icon icon="mdi-card-account-details" size="12" class="mr-1" />
                  Lic. {{ c.license_number }}
                </div>
                <div v-if="c.hire_date">
                  <v-icon icon="mdi-calendar" size="12" class="mr-1" />
                  Hired {{ c.hire_date }}
                </div>
              </div>

              <div v-if="(c.specialties || []).length" class="mt-2 d-flex flex-wrap ga-1">
                <v-chip v-for="s in c.specialties.slice(0, 3)" :key="s" size="x-small"
                        color="grey-lighten-3" variant="flat" class="text-grey-darken-3">
                  {{ s }}
                </v-chip>
                <v-chip v-if="c.specialties.length > 3" size="x-small" variant="text">
                  +{{ c.specialties.length - 3 }}
                </v-chip>
              </div>

              <v-divider class="my-3" />

              <div class="d-flex text-center">
                <div class="flex-grow-1">
                  <div class="text-subtitle-2 font-weight-bold">
                    <v-icon icon="mdi-star" color="amber" size="14" />
                    {{ Number(c.rating || 0).toFixed(1) }}
                  </div>
                  <div class="text-caption text-medium-emphasis">Rating</div>
                </div>
                <v-divider vertical />
                <div class="flex-grow-1">
                  <div class="text-subtitle-2 font-weight-bold text-teal">
                    {{ c.active_patients_count || 0 }}
                  </div>
                  <div class="text-caption text-medium-emphasis">Patients</div>
                </div>
                <v-divider vertical />
                <div class="flex-grow-1">
                  <div class="text-subtitle-2 font-weight-bold text-indigo">
                    {{ c.total_visits || 0 }}
                  </div>
                  <div class="text-caption text-medium-emphasis">Visits</div>
                </div>
              </div>

              <div class="d-flex align-center justify-space-between mt-3">
                <v-chip size="x-small" :color="c.is_available ? 'success' : 'grey'"
                        variant="tonal">
                  <v-icon :icon="c.is_available ? 'mdi-check-circle' : 'mdi-pause-circle'"
                          start size="12" />
                  {{ c.is_available ? 'Available' : 'Off duty' }}
                </v-chip>
                <v-chip size="x-small" :color="employmentColor(c.employment_status)"
                        variant="tonal">{{ c.employment_status }}</v-chip>
              </div>

              <div class="d-flex ga-1 mt-3" @click.stop.prevent>
                <v-btn size="small" variant="tonal" color="teal" rounded="lg" class="text-none flex-grow-1"
                       prepend-icon="mdi-toggle-switch" @click="toggleAvail(c)">
                  {{ c.is_available ? 'Off duty' : 'Available' }}
                </v-btn>
                <v-btn size="small" variant="tonal" color="indigo" rounded="lg" class="text-none"
                       :to="`/homecare/caregivers/${c.id}`" icon="mdi-eye" />
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
      <v-card v-else rounded="xl" elevation="0" class="hc-card pa-6">
        <EmptyState icon="mdi-account-off" title="No caregivers match your filters"
                    message="Adjust filters or add a new caregiver." />
      </v-card>
    </div>

    <!-- Table view -->
    <v-card v-else rounded="xl" elevation="0" class="mt-3 hc-card">
      <v-data-table :items="filtered" :headers="tableHeaders" item-value="id"
                    :loading="loading" class="hc-table">
        <template #[`item.user`]="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="32" :color="catMeta(item.category).color" variant="flat">
              <span class="text-caption font-weight-bold text-white">{{ initials(item) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.user?.full_name || item.user?.email }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.user?.email }}</div>
            </div>
          </div>
        </template>
        <template #[`item.category`]="{ item }">
          <v-chip size="small" :color="catMeta(item.category).color" variant="tonal">
            <v-icon :icon="catMeta(item.category).icon" start size="14" />
            {{ catMeta(item.category).label }}
          </v-chip>
        </template>
        <template #[`item.rating`]="{ item }">
          <v-icon icon="mdi-star" color="amber" size="16" />
          {{ Number(item.rating || 0).toFixed(1) }}
        </template>
        <template #[`item.is_available`]="{ item }">
          <v-chip size="x-small" :color="item.is_available ? 'success' : 'grey'" variant="tonal">
            {{ item.is_available ? 'Available' : 'Off duty' }}
          </v-chip>
        </template>
        <template #[`item.employment_status`]="{ item }">
          <v-chip size="x-small" :color="employmentColor(item.employment_status)" variant="tonal">
            {{ item.employment_status }}
          </v-chip>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn icon="mdi-eye" variant="text" size="small" :to="`/homecare/caregivers/${item.id}`" />
          <v-btn icon="mdi-toggle-switch" variant="text" size="small" @click="toggleAvail(item)" />
        </template>
      </v-data-table>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const all = ref([])
const loading = ref(false)
const categoryTab = ref('all')
const search = ref('')
const employmentFilter = ref(null)
const availabilityFilter = ref(null)
const view = ref('cards')
const snack = reactive({ show: false, text: '', color: 'info' })

const employmentOptions = [
  { title: 'Active',     value: 'active' },
  { title: 'Suspended',  value: 'suspended' },
  { title: 'Terminated', value: 'terminated' },
  { title: 'On leave',   value: 'on_leave' },
]

const tableHeaders = [
  { title: 'Caregiver',  key: 'user',         sortable: false },
  { title: 'Category',   key: 'category' },
  { title: 'License',    key: 'license_number' },
  { title: 'Patients',   key: 'active_patients_count' },
  { title: 'Visits',     key: 'total_visits' },
  { title: 'Rating',     key: 'rating' },
  { title: 'Available',  key: 'is_available' },
  { title: 'Status',     key: 'employment_status' },
  { title: '',           key: 'actions',      sortable: false, align: 'end' },
]

const CAT_META = {
  nurse: {
    label: 'Nurse', icon: 'mdi-medical-bag', color: 'indigo',
    gradient: 'linear-gradient(135deg, #4f46e5 0%, #6366f1 100%)',
  },
  hca: {
    label: 'HCA', icon: 'mdi-hand-heart', color: 'pink',
    gradient: 'linear-gradient(135deg, #db2777 0%, #f472b6 100%)',
  },
}
function catMeta(c) {
  return CAT_META[c] || { label: 'Caregiver', icon: 'mdi-account-heart', color: 'teal',
    gradient: 'linear-gradient(135deg, #0d9488 0%, #14b8a6 100%)' }
}

function initials(c) {
  const n = (c.user?.full_name || c.user?.email || '').trim()
  if (!n) return '?'
  const parts = n.split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || n[0].toUpperCase()
}

function employmentColor(s) {
  return ({ active: 'success', suspended: 'warning',
            terminated: 'error', on_leave: 'info' })[s] || 'grey'
}

const counts = computed(() => ({
  nurse: all.value.filter(c => c.category === 'nurse').length,
  hca: all.value.filter(c => c.category === 'hca').length,
  available: all.value.filter(c => c.is_available).length,
}))

const filtered = computed(() => {
  const q = search.value?.trim().toLowerCase()
  return all.value.filter(c => {
    if (categoryTab.value !== 'all' && c.category !== categoryTab.value) return false
    if (employmentFilter.value && c.employment_status !== employmentFilter.value) return false
    if (availabilityFilter.value !== null && c.is_available !== availabilityFilter.value) return false
    if (q) {
      const blob = [
        c.user?.full_name, c.user?.email, c.license_number,
        ...(c.specialties || []),
      ].filter(Boolean).join(' ').toLowerCase()
      if (!blob.includes(q)) return false
    }
    return true
  })
})

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/caregivers/', { params: { page_size: 500 } })
    all.value = data?.results || data || []
  } catch (e) {
    Object.assign(snack, { show: true, text: 'Failed to load caregivers', color: 'error' })
  } finally {
    loading.value = false
  }
}

async function toggleAvail(c) {
  try {
    const { data } = await $api.post(`/homecare/caregivers/${c.id}/toggle_availability/`)
    const i = all.value.findIndex(x => x.id === data.id)
    if (i >= 0) all.value.splice(i, 1, data)
    Object.assign(snack, { show: true, text: data.is_available ? 'Marked available' : 'Set off duty', color: 'success' })
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to update', color: 'error' })
  }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); }

.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}

.hc-cg-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.hc-cg-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 24px -10px rgba(15,23,42,0.18);
}
:global(.v-theme--dark) .hc-cg-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
.hc-cg-band { height: 6px; }
.hc-cg-avatar { box-shadow: 0 4px 14px rgba(0,0,0,0.18); }

.hc-cat-tabs :deep(.v-tab) { text-transform: none; font-weight: 600; }

.hc-table :deep(th) {
  background: rgba(0,0,0,0.025);
  font-weight: 600;
}
.min-w-0 { min-width: 0; }
.h-100 { height: 100%; }
</style>
