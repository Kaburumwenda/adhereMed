<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="teal-lighten-5" size="48">
        <v-icon color="teal-darken-2" size="28">mdi-doctor</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Referring Doctors</div>
        <div class="text-body-2 text-medium-emphasis">Manage external physicians who refer patients for imaging</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="openNew">Add Doctor</v-btn>
    </div>

    <!-- KPI strip -->
    <div class="kpi-strip mb-4">
      <div v-for="k in kpis" :key="k.label" class="kpi-item pa-3 rounded-lg cursor-pointer"
           :class="{ 'kpi-item--active': activeFilter === k.key }"
           @click="activeFilter = activeFilter === k.key ? null : k.key">
        <div class="d-flex align-center ga-2">
          <v-avatar :color="k.color" size="36" variant="tonal">
            <v-icon size="18">{{ k.icon }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6 font-weight-bold" style="line-height:1">{{ k.count }}</div>
            <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Filter bar -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search doctors…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterFacility" :items="facilityItems" label="Facility" variant="outlined"
            density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterActive" :items="[{title:'Active',value:true},{title:'Inactive',value:false}]"
            label="Status" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="12" md="5" class="d-flex align-center justify-end ga-2">
          <v-btn v-if="hasFilters" variant="text" size="small" class="text-none"
                 prepend-icon="mdi-filter-off" @click="clearFilters">Clear</v-btn>
          <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="grid" icon="mdi-view-grid" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- TABLE VIEW -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="overflow-hidden table-card">
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading"
        density="comfortable" hover items-per-page="25" class="doctor-table"
        @click:row="(_, { item }) => edit(item)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>

        <template #item.rowNum="{ index }">
          <span class="text-caption font-weight-medium text-medium-emphasis">{{ index + 1 }}</span>
        </template>

        <template #item.name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="specialtyColor(item.specialty)" size="34" variant="tonal" class="mr-3">
              <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.name }}</div>
              <div v-if="item.license_number" class="text-caption text-medium-emphasis">
                <v-icon size="10" class="mr-1">mdi-card-account-details-outline</v-icon>{{ item.license_number }}
              </div>
            </div>
          </div>
        </template>

        <template #item.specialty="{ value }">
          <v-chip v-if="value" size="x-small" variant="tonal" :color="specialtyColor(value)" label>{{ value }}</v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.phone="{ value }">
          <div v-if="value" class="d-flex align-center ga-1">
            <v-icon size="14" color="grey">mdi-phone-outline</v-icon>
            <span class="text-body-2">{{ value }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.facility_name="{ value }">
          <div v-if="value" class="d-flex align-center ga-1">
            <v-icon size="14" color="indigo">mdi-hospital-building</v-icon>
            <span class="text-body-2">{{ value }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.commission_percent="{ value }">
          <v-chip v-if="value > 0" size="x-small" variant="flat" color="amber-darken-1" label>
            {{ value }}%
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.is_active="{ value }">
          <v-chip size="x-small" :color="value ? 'success' : 'grey'" variant="tonal">{{ value ? 'Active' : 'Inactive' }}</v-chip>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1" @click.stop>
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="edit(item)" />
            <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="del(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- GRID VIEW -->
    <v-row v-if="viewMode === 'grid'" dense>
      <v-col v-for="doc in filtered" :key="doc.id" cols="12" sm="6" md="4" lg="3">
        <v-card flat rounded="xl" class="doctor-card h-100 d-flex flex-column" @click="edit(doc)">
          <v-card-text class="pa-4 flex-grow-1">
            <!-- Avatar & name -->
            <div class="d-flex align-center ga-3 mb-3">
              <v-avatar :color="specialtyColor(doc.specialty)" size="44" variant="tonal">
                <span class="text-subtitle-2 font-weight-bold">{{ initials(doc.name) }}</span>
              </v-avatar>
              <div style="min-width:0" class="flex-grow-1">
                <div class="text-subtitle-1 font-weight-bold text-truncate">{{ doc.name }}</div>
                <v-chip v-if="doc.specialty" size="x-small" variant="tonal" :color="specialtyColor(doc.specialty)" label class="mt-1">{{ doc.specialty }}</v-chip>
              </div>
              <v-chip size="x-small" :color="doc.is_active ? 'success' : 'grey'" variant="tonal">
                {{ doc.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>

            <!-- Details -->
            <div class="detail-list">
              <div v-if="doc.phone" class="detail-row">
                <v-icon size="14" color="grey">mdi-phone-outline</v-icon>
                <span>{{ doc.phone }}</span>
              </div>
              <div v-if="doc.email" class="detail-row">
                <v-icon size="14" color="grey">mdi-email-outline</v-icon>
                <span class="text-truncate">{{ doc.email }}</span>
              </div>
              <div v-if="doc.facility_name" class="detail-row">
                <v-icon size="14" color="indigo">mdi-hospital-building</v-icon>
                <span>{{ doc.facility_name }}</span>
              </div>
              <div v-if="doc.license_number" class="detail-row">
                <v-icon size="14" color="grey">mdi-card-account-details-outline</v-icon>
                <span>{{ doc.license_number }}</span>
              </div>
            </div>

            <!-- Commission bar -->
            <div v-if="doc.commission_percent > 0" class="commission-bar pa-2 rounded-lg mt-3 d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Commission</div>
              <v-chip size="x-small" variant="flat" color="amber-darken-1" label>{{ doc.commission_percent }}%</v-chip>
            </div>
          </v-card-text>

          <v-divider />

          <v-card-actions class="px-4 py-2">
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-pencil" @click.stop="edit(doc)">Edit</v-btn>
            <v-spacer />
            <v-btn variant="text" size="small" color="error" class="text-none" icon="mdi-delete" @click.stop="del(doc)" />
          </v-card-actions>
        </v-card>
      </v-col>
    </v-row>

    <!-- Empty state -->
    <div v-if="!filtered.length && !loading" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-doctor</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No referring doctors found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">Add your first referring physician.</div>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openNew">Add Doctor</v-btn>
    </div>

    <!-- Loading skeleton -->
    <v-row v-if="loading && viewMode === 'grid'" dense>
      <v-col v-for="n in 8" :key="n" cols="12" sm="6" md="4" lg="3">
        <v-skeleton-loader type="card" rounded="xl" />
      </v-col>
    </v-row>

    <!-- Add/Edit Dialog -->
    <v-dialog v-model="dlg" max-width="560" persistent>
      <v-card rounded="xl" class="pa-0 overflow-hidden">
        <!-- Dialog header -->
        <div class="dlg-header pa-5 pb-4">
          <div class="d-flex align-center ga-3">
            <v-avatar :color="editId ? 'teal' : 'primary'" size="40" variant="tonal">
              <v-icon size="20">{{ editId ? 'mdi-pencil' : 'mdi-account-plus' }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-h6 font-weight-bold">{{ editId ? 'Edit' : 'New' }} Referring Doctor</div>
              <div class="text-caption text-medium-emphasis">{{ editId ? 'Update doctor details' : 'Register a new referring physician' }}</div>
            </div>
            <v-spacer />
            <v-btn icon="mdi-close" variant="text" size="small" @click="dlg = false" />
          </div>
        </div>
        <v-divider />

        <v-form ref="dlgForm" @submit.prevent="save">
          <div class="pa-5">
            <div class="text-caption font-weight-bold text-uppercase text-medium-emphasis mb-2">
              <v-icon size="12" class="mr-1">mdi-account</v-icon> Personal Information
            </div>
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.name" label="Full Name" :rules="req" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-account-outline" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.specialty" label="Specialty" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-stethoscope" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-phone-outline" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.email" label="Email" type="email" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-email-outline" />
              </v-col>
            </v-row>

            <div class="text-caption font-weight-bold text-uppercase text-medium-emphasis mb-2 mt-3">
              <v-icon size="12" class="mr-1">mdi-hospital-building</v-icon> Professional Details
            </div>
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.license_number" label="License Number" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-card-account-details-outline" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-autocomplete v-model="form.facility" :items="facilities" item-title="name" item-value="id"
                  label="Facility" clearable variant="outlined" density="compact" rounded="lg"
                  prepend-inner-icon="mdi-hospital-building" />
              </v-col>
            </v-row>

            <div class="text-caption font-weight-bold text-uppercase text-medium-emphasis mb-2 mt-3">
              <v-icon size="12" class="mr-1">mdi-cog</v-icon> Settings
            </div>
            <v-row dense align="center">
              <v-col cols="12" sm="6">
                <v-text-field v-model.number="form.commission_percent" label="Commission %" type="number"
                  variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-percent"
                  suffix="%" min="0" max="100" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-switch v-model="form.is_active" label="Active" color="success" density="compact" hide-details />
              </v-col>
            </v-row>
          </div>

          <v-divider />
          <div class="d-flex justify-end ga-2 pa-4">
            <v-btn variant="tonal" rounded="lg" class="text-none" @click="dlg = false">Cancel</v-btn>
            <v-btn type="submit" color="primary" rounded="lg" class="text-none" :loading="saving"
                   prepend-icon="mdi-check">{{ editId ? 'Update' : 'Create' }}</v-btn>
          </div>
        </v-form>
      </v-card>
    </v-dialog>

    <!-- Delete dialog -->
    <v-dialog v-model="delDlg" max-width="420">
      <v-card rounded="xl" class="pa-5">
        <div class="d-flex align-center ga-2 mb-3">
          <v-avatar color="error" variant="tonal" size="36">
            <v-icon size="18">mdi-alert</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Delete Doctor</div>
        </div>
        <div class="text-body-2 mb-4">Are you sure you want to delete <strong>{{ delTarget?.name }}</strong>? This action cannot be undone.</div>
        <div class="d-flex justify-end ga-2">
          <v-btn variant="text" rounded="lg" class="text-none" @click="delDlg = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="deleting" @click="confirmDel">Delete</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack" :color="snackColor" rounded="lg" timeout="2500" location="bottom right">{{ snackMsg }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const saving = ref(false)
const doctors = ref([])
const facilities = ref([])
const search = ref('')
const filterFacility = ref(null)
const filterActive = ref(null)
const activeFilter = ref(null)
const viewMode = ref('table')
const dlg = ref(false)
const dlgForm = ref(null)
const editId = ref(null)
const delDlg = ref(false)
const delTarget = ref(null)
const deleting = ref(false)
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')
const req = [v => !!v || 'Required']
const form = reactive({ name: '', specialty: '', phone: '', email: '', license_number: '', facility: null, commission_percent: 0, is_active: true })

const headers = [
  { title: '#', key: 'rowNum', width: 50, sortable: false },
  { title: 'Doctor', key: 'name', width: 220 },
  { title: 'Specialty', key: 'specialty', width: 140 },
  { title: 'Phone', key: 'phone', width: 130 },
  { title: 'Facility', key: 'facility_name', width: 180 },
  { title: 'Commission', key: 'commission_percent', align: 'center', width: 100 },
  { title: 'Status', key: 'is_active', width: 90 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

const kpis = computed(() => {
  const all = doctors.value
  const specialties = new Set(all.map(d => d.specialty).filter(Boolean))
  const withFacility = all.filter(d => d.facility_name).length
  return [
    { key: 'all', label: 'Total Doctors', count: all.length, color: 'teal', icon: 'mdi-doctor' },
    { key: 'active', label: 'Active', count: all.filter(d => d.is_active).length, color: 'success', icon: 'mdi-check-circle' },
    { key: null, label: 'Specialties', count: specialties.size, color: 'indigo', icon: 'mdi-stethoscope' },
    { key: 'affiliated', label: 'Affiliated', count: withFacility, color: 'deep-purple', icon: 'mdi-hospital-building' },
  ]
})

const facilityItems = computed(() => facilities.value.map(f => ({ title: f.name, value: f.id })))

const hasFilters = computed(() => search.value || filterFacility.value || filterActive.value !== null && filterActive.value !== undefined)
function clearFilters() { search.value = ''; filterFacility.value = null; filterActive.value = null; activeFilter.value = null }

const filtered = computed(() => {
  let list = doctors.value
  if (activeFilter.value === 'active') list = list.filter(d => d.is_active)
  else if (activeFilter.value === 'affiliated') list = list.filter(d => d.facility_name)
  if (search.value) {
    const q = search.value.toLowerCase()
    list = list.filter(d => d.name.toLowerCase().includes(q) || d.specialty?.toLowerCase().includes(q) || d.facility_name?.toLowerCase().includes(q) || d.license_number?.toLowerCase().includes(q))
  }
  if (filterFacility.value) list = list.filter(d => d.facility === filterFacility.value)
  if (filterActive.value === true) list = list.filter(d => d.is_active)
  else if (filterActive.value === false) list = list.filter(d => !d.is_active)
  return list
})

function initials(name) {
  return name?.split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?'
}

function specialtyColor(s) {
  if (!s) return 'grey'
  const map = { cardiol: 'red', neurol: 'deep-purple', ortho: 'blue', pediatr: 'pink', surgeon: 'indigo', surg: 'indigo', internal: 'teal', general: 'blue-grey', oncol: 'orange', gastro: 'green', pulmon: 'cyan', radiol: 'amber', uro: 'brown', gyn: 'pink-darken-1', obstet: 'pink-darken-1', dermat: 'lime-darken-2', ophthal: 'light-blue', ent: 'deep-orange' }
  const lower = s.toLowerCase()
  for (const [key, color] of Object.entries(map)) { if (lower.includes(key)) return color }
  return 'teal'
}

function openNew() {
  editId.value = null
  Object.assign(form, { name: '', specialty: '', phone: '', email: '', license_number: '', facility: null, commission_percent: 0, is_active: true })
  dlg.value = true
}

function edit(item) {
  editId.value = item.id
  Object.assign(form, { name: item.name, specialty: item.specialty, phone: item.phone, email: item.email, license_number: item.license_number, facility: item.facility, commission_percent: item.commission_percent, is_active: item.is_active })
  dlg.value = true
}

async function save() {
  const { valid } = await dlgForm.value.validate()
  if (!valid) return
  saving.value = true
  try {
    if (editId.value) await $api.patch(`/radiology/referring-doctors/${editId.value}/`, form)
    else await $api.post('/radiology/referring-doctors/', form)
    dlg.value = false
    snackMsg.value = editId.value ? 'Doctor updated' : 'Doctor created'; snackColor.value = 'success'; snack.value = true
    await load()
  } catch { snackMsg.value = 'Save failed'; snackColor.value = 'error'; snack.value = true }
  saving.value = false
}

function del(item) { delTarget.value = item; delDlg.value = true }
async function confirmDel() {
  deleting.value = true
  try {
    await $api.delete(`/radiology/referring-doctors/${delTarget.value.id}/`)
    snackMsg.value = `"${delTarget.value.name}" deleted`; snackColor.value = 'success'; snack.value = true
    delDlg.value = false; await load()
  } catch { snackMsg.value = 'Delete failed'; snackColor.value = 'error'; snack.value = true }
  deleting.value = false
}

async function load() {
  loading.value = true
  try {
    const [dRes, fRes] = await Promise.allSettled([
      $api.get('/radiology/referring-doctors/?page_size=500'),
      $api.get('/radiology/referring-facilities/?page_size=200'),
    ])
    doctors.value = dRes.status === 'fulfilled' ? dRes.value.data?.results || dRes.value.data || [] : []
    facilities.value = fRes.status === 'fulfilled' ? fRes.value.data?.results || fRes.value.data || [] : []
  } catch { }
  loading.value = false
}
onMounted(load)
</script>

<style scoped>
.kpi-strip { display: flex; gap: 10px; overflow-x: auto; padding-bottom: 4px; }
.kpi-item { flex: 1; min-width: 130px; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s ease; }
.kpi-item:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
.kpi-item--active { border-color: rgb(var(--v-theme-primary)); background: rgba(var(--v-theme-primary), 0.04); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.table-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.doctor-table :deep(tbody tr) { cursor: pointer; }
.doctor-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); cursor: pointer; transition: all 0.18s ease; }
.doctor-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.08); transform: translateY(-3px); }
.detail-list { display: flex; flex-direction: column; gap: 6px; }
.detail-row { display: flex; align-items: center; gap: 8px; font-size: 0.8125rem; color: rgba(var(--v-theme-on-surface), 0.7); }
.commission-bar { background: rgba(var(--v-theme-warning), 0.06); }
.dlg-header { background: rgba(var(--v-theme-on-surface), 0.02); }
</style>
