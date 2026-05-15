<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-hospital-building</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Referring Facilities</div>
        <div class="text-body-2 text-medium-emphasis">Manage hospitals &amp; clinics that refer patients for imaging</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="openNew">Add Facility</v-btn>
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
        <v-col cols="12" sm="5" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search facilities…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterActive" :items="[{title:'Active',value:true},{title:'Inactive',value:false}]"
            label="Status" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="12" md="6" class="d-flex align-center justify-end ga-2">
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
        density="comfortable" hover items-per-page="25" class="facility-table"
        @click:row="(_, { item }) => edit(item)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>

        <template #item.rowNum="{ index }">
          <span class="text-caption font-weight-medium text-medium-emphasis">{{ index + 1 }}</span>
        </template>

        <template #item.name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar color="indigo" size="34" variant="tonal" class="mr-3">
              <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.name }}</div>
              <div v-if="item.address" class="text-caption text-medium-emphasis text-truncate" style="max-width:280px">
                <v-icon size="10" class="mr-1">mdi-map-marker-outline</v-icon>{{ item.address }}
              </div>
            </div>
          </div>
        </template>

        <template #item.phone="{ value }">
          <div v-if="value" class="d-flex align-center ga-1">
            <v-icon size="14" color="grey">mdi-phone-outline</v-icon>
            <span class="text-body-2">{{ value }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.email="{ value }">
          <div v-if="value" class="d-flex align-center ga-1">
            <v-icon size="14" color="grey">mdi-email-outline</v-icon>
            <span class="text-body-2">{{ value }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.contact_person="{ value }">
          <div v-if="value" class="d-flex align-center ga-1">
            <v-icon size="14" color="teal">mdi-account-outline</v-icon>
            <span class="text-body-2">{{ value }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.doctor_count="{ item }">
          <v-chip size="x-small" variant="tonal" color="teal">
            {{ doctorCount(item.id) }} doctor{{ doctorCount(item.id) !== 1 ? 's' : '' }}
          </v-chip>
        </template>

        <template #item.discount_percent="{ value }">
          <v-chip v-if="value > 0" size="x-small" variant="flat" color="green" label>{{ value }}%</v-chip>
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
      <v-col v-for="fac in filtered" :key="fac.id" cols="12" sm="6" md="4" lg="3">
        <v-card flat rounded="xl" class="facility-card h-100 d-flex flex-column" @click="edit(fac)">
          <v-card-text class="pa-4 flex-grow-1">
            <!-- Header -->
            <div class="d-flex align-center ga-3 mb-3">
              <v-avatar color="indigo" size="44" variant="tonal">
                <span class="text-subtitle-2 font-weight-bold">{{ initials(fac.name) }}</span>
              </v-avatar>
              <div style="min-width:0" class="flex-grow-1">
                <div class="text-subtitle-1 font-weight-bold text-truncate">{{ fac.name }}</div>
                <div v-if="fac.address" class="text-caption text-medium-emphasis text-truncate">
                  <v-icon size="10" class="mr-1">mdi-map-marker-outline</v-icon>{{ fac.address }}
                </div>
              </div>
              <v-chip size="x-small" :color="fac.is_active ? 'success' : 'grey'" variant="tonal">
                {{ fac.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>

            <!-- Details -->
            <div class="detail-list">
              <div v-if="fac.phone" class="detail-row">
                <v-icon size="14" color="grey">mdi-phone-outline</v-icon>
                <span>{{ fac.phone }}</span>
              </div>
              <div v-if="fac.email" class="detail-row">
                <v-icon size="14" color="grey">mdi-email-outline</v-icon>
                <span class="text-truncate">{{ fac.email }}</span>
              </div>
              <div v-if="fac.contact_person" class="detail-row">
                <v-icon size="14" color="teal">mdi-account-outline</v-icon>
                <span>{{ fac.contact_person }}</span>
              </div>
            </div>

            <!-- Stats row -->
            <div class="stats-row mt-3 d-flex ga-2">
              <div class="stat-chip pa-2 rounded-lg flex-grow-1 text-center">
                <div class="text-caption text-medium-emphasis">Doctors</div>
                <div class="text-subtitle-2 font-weight-bold text-teal">{{ doctorCount(fac.id) }}</div>
              </div>
              <div class="stat-chip pa-2 rounded-lg flex-grow-1 text-center">
                <div class="text-caption text-medium-emphasis">Discount</div>
                <div class="text-subtitle-2 font-weight-bold" :class="fac.discount_percent > 0 ? 'text-green' : 'text-medium-emphasis'">
                  {{ fac.discount_percent > 0 ? fac.discount_percent + '%' : '—' }}
                </div>
              </div>
            </div>
          </v-card-text>

          <v-divider />

          <v-card-actions class="px-4 py-2">
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-pencil" @click.stop="edit(fac)">Edit</v-btn>
            <v-spacer />
            <v-btn variant="text" size="small" color="error" class="text-none" icon="mdi-delete" @click.stop="del(fac)" />
          </v-card-actions>
        </v-card>
      </v-col>
    </v-row>

    <!-- Empty state -->
    <div v-if="!filtered.length && !loading" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-hospital-building</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No referring facilities found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">Add your first referring hospital or clinic.</div>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openNew">Add Facility</v-btn>
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
        <div class="dlg-header pa-5 pb-4">
          <div class="d-flex align-center ga-3">
            <v-avatar :color="editId ? 'indigo' : 'primary'" size="40" variant="tonal">
              <v-icon size="20">{{ editId ? 'mdi-pencil' : 'mdi-hospital-building' }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-h6 font-weight-bold">{{ editId ? 'Edit' : 'New' }} Referring Facility</div>
              <div class="text-caption text-medium-emphasis">{{ editId ? 'Update facility details' : 'Register a new referring facility' }}</div>
            </div>
            <v-spacer />
            <v-btn icon="mdi-close" variant="text" size="small" @click="dlg = false" />
          </div>
        </div>
        <v-divider />

        <v-form ref="dlgForm" @submit.prevent="save">
          <div class="pa-5">
            <div class="text-caption font-weight-bold text-uppercase text-medium-emphasis mb-2">
              <v-icon size="12" class="mr-1">mdi-domain</v-icon> Facility Information
            </div>
            <v-row dense>
              <v-col cols="12">
                <v-text-field v-model="form.name" label="Facility Name" :rules="req" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-hospital-building" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.address" label="Address" rows="2" auto-grow variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-map-marker-outline" />
              </v-col>
            </v-row>

            <div class="text-caption font-weight-bold text-uppercase text-medium-emphasis mb-2 mt-3">
              <v-icon size="12" class="mr-1">mdi-contacts</v-icon> Contact Details
            </div>
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-phone-outline" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.email" label="Email" type="email" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-email-outline" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.contact_person" label="Contact Person" variant="outlined"
                  density="compact" rounded="lg" prepend-inner-icon="mdi-account-outline" />
              </v-col>
            </v-row>

            <div class="text-caption font-weight-bold text-uppercase text-medium-emphasis mb-2 mt-3">
              <v-icon size="12" class="mr-1">mdi-cog</v-icon> Settings
            </div>
            <v-row dense align="center">
              <v-col cols="12" sm="6">
                <v-text-field v-model.number="form.discount_percent" label="Discount %" type="number"
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
          <div class="text-h6 font-weight-bold">Delete Facility</div>
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
const facilities = ref([])
const doctors = ref([])
const search = ref('')
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
const form = reactive({ name: '', address: '', phone: '', email: '', contact_person: '', discount_percent: 0, is_active: true })

const headers = [
  { title: '#', key: 'rowNum', width: 50, sortable: false },
  { title: 'Facility', key: 'name', width: 260 },
  { title: 'Phone', key: 'phone', width: 130 },
  { title: 'Email', key: 'email', width: 180 },
  { title: 'Contact', key: 'contact_person', width: 150 },
  { title: 'Doctors', key: 'doctor_count', align: 'center', width: 90 },
  { title: 'Discount', key: 'discount_percent', align: 'center', width: 90 },
  { title: 'Status', key: 'is_active', width: 90 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

const kpis = computed(() => {
  const all = facilities.value
  const withDiscount = all.filter(f => f.discount_percent > 0).length
  const totalDoctors = doctors.value.length
  return [
    { key: 'all', label: 'Total Facilities', count: all.length, color: 'indigo', icon: 'mdi-hospital-building' },
    { key: 'active', label: 'Active', count: all.filter(f => f.is_active).length, color: 'success', icon: 'mdi-check-circle' },
    { key: 'discount', label: 'With Discount', count: withDiscount, color: 'green', icon: 'mdi-sale' },
    { key: null, label: 'Total Doctors', count: totalDoctors, color: 'teal', icon: 'mdi-doctor' },
  ]
})

const hasFilters = computed(() => search.value || filterActive.value !== null && filterActive.value !== undefined)
function clearFilters() { search.value = ''; filterActive.value = null; activeFilter.value = null }

const filtered = computed(() => {
  let list = facilities.value
  if (activeFilter.value === 'active') list = list.filter(f => f.is_active)
  else if (activeFilter.value === 'discount') list = list.filter(f => f.discount_percent > 0)
  if (search.value) {
    const q = search.value.toLowerCase()
    list = list.filter(f => f.name.toLowerCase().includes(q) || f.contact_person?.toLowerCase().includes(q) || f.email?.toLowerCase().includes(q) || f.address?.toLowerCase().includes(q))
  }
  if (filterActive.value === true) list = list.filter(f => f.is_active)
  else if (filterActive.value === false) list = list.filter(f => !f.is_active)
  return list
})

function initials(name) {
  return name?.split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?'
}

function doctorCount(facilityId) {
  return doctors.value.filter(d => d.facility === facilityId).length
}

function openNew() {
  editId.value = null
  Object.assign(form, { name: '', address: '', phone: '', email: '', contact_person: '', discount_percent: 0, is_active: true })
  dlg.value = true
}

function edit(item) {
  editId.value = item.id
  Object.assign(form, { name: item.name, address: item.address, phone: item.phone, email: item.email, contact_person: item.contact_person, discount_percent: item.discount_percent, is_active: item.is_active })
  dlg.value = true
}

async function save() {
  const { valid } = await dlgForm.value.validate()
  if (!valid) return
  saving.value = true
  try {
    if (editId.value) await $api.patch(`/radiology/referring-facilities/${editId.value}/`, form)
    else await $api.post('/radiology/referring-facilities/', form)
    dlg.value = false
    snackMsg.value = editId.value ? 'Facility updated' : 'Facility created'; snackColor.value = 'success'; snack.value = true
    await load()
  } catch { snackMsg.value = 'Save failed'; snackColor.value = 'error'; snack.value = true }
  saving.value = false
}

function del(item) { delTarget.value = item; delDlg.value = true }
async function confirmDel() {
  deleting.value = true
  try {
    await $api.delete(`/radiology/referring-facilities/${delTarget.value.id}/`)
    snackMsg.value = `"${delTarget.value.name}" deleted`; snackColor.value = 'success'; snack.value = true
    delDlg.value = false; await load()
  } catch { snackMsg.value = 'Delete failed'; snackColor.value = 'error'; snack.value = true }
  deleting.value = false
}

async function load() {
  loading.value = true
  try {
    const [fRes, dRes] = await Promise.allSettled([
      $api.get('/radiology/referring-facilities/?page_size=200'),
      $api.get('/radiology/referring-doctors/?page_size=500'),
    ])
    facilities.value = fRes.status === 'fulfilled' ? fRes.value.data?.results || fRes.value.data || [] : []
    doctors.value = dRes.status === 'fulfilled' ? dRes.value.data?.results || dRes.value.data || [] : []
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
.facility-table :deep(tbody tr) { cursor: pointer; }
.facility-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); cursor: pointer; transition: all 0.18s ease; }
.facility-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.08); transform: translateY(-3px); }
.detail-list { display: flex; flex-direction: column; gap: 6px; }
.detail-row { display: flex; align-items: center; gap: 8px; font-size: 0.8125rem; color: rgba(var(--v-theme-on-surface), 0.7); }
.stat-chip { background: rgba(var(--v-theme-on-surface), 0.03); border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.dlg-header { background: rgba(var(--v-theme-on-surface), 0.02); }
</style>
