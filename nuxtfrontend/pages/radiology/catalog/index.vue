<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-book-open-page-variant</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Exam Catalog</div>
        <div class="text-body-2 text-medium-emphasis">Manage imaging exams, pricing &amp; protocols</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             to="/radiology/catalog/new">New Exam</v-btn>
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

    <!-- Filters -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search exams…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterModality" :items="modalityTypes" label="Modality" variant="outlined"
            density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterContrast" :items="[{title:'Contrast',value:true},{title:'No Contrast',value:false}]"
            label="Contrast" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="2" md="2">
          <v-select v-model="filterActive" :items="[{title:'Active',value:true},{title:'Inactive',value:false}]"
            label="Status" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="12" md="3" class="d-flex align-center justify-end ga-2">
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
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="overflow-hidden catalog-card">
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading"
        density="comfortable" hover items-per-page="25" class="catalog-table"
        @click:row="(_, { item }) => $router.push(`/radiology/catalog/${item.id}/edit`)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>

        <template #item.rowNum="{ index }">
          <span class="text-caption font-weight-medium text-medium-emphasis">{{ index + 1 }}</span>
        </template>

        <template #item.code="{ value }">
          <code class="exam-code px-2 py-1 rounded font-weight-bold">{{ value }}</code>
        </template>

        <template #item.name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="modalityColor(item.modality_type)" size="32" variant="tonal" class="mr-2">
              <v-icon size="16">{{ modalityIcon(item.modality_type) }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.body_region || '—' }}</div>
            </div>
          </div>
        </template>

        <template #item.modality_type_display="{ value }">
          <span class="text-body-2">{{ value }}</span>
        </template>

        <template #item.estimated_duration_minutes="{ value }">
          <div class="d-flex align-center ga-1">
            <v-icon size="14" color="grey">mdi-clock-outline</v-icon>
            <span class="text-body-2">{{ value }}m</span>
          </div>
        </template>

        <template #item.price="{ value }">
          <span class="text-body-2 font-weight-medium">{{ fmtMoney(value) }}</span>
        </template>

        <template #item.contrast_required="{ value }">
          <v-icon v-if="value" color="warning" size="18">mdi-water</v-icon>
          <span v-else class="text-medium-emphasis">—</span>
        </template>

        <template #item.is_active="{ value }">
          <v-chip size="x-small" :color="value ? 'success' : 'grey'" variant="tonal">{{ value ? 'Active' : 'Inactive' }}</v-chip>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1" @click.stop>
            <v-btn icon="mdi-pencil" size="x-small" variant="text" :to="`/radiology/catalog/${item.id}/edit`" />
            <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="del(item)" />
          </div>
        </template>

        <template #no-data>
          <div class="pa-10 text-center">
            <v-icon size="64" color="grey-lighten-1">mdi-book-open-page-variant</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No exams in catalog</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Add your first imaging exam.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/radiology/catalog/new" class="text-none">New Exam</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- GRID VIEW -->
    <v-row v-else dense>
      <v-col v-for="exam in filtered" :key="exam.id" cols="12" sm="6" md="4" lg="3">
        <v-card flat rounded="xl" class="exam-card pa-4 h-100 cursor-pointer d-flex flex-column"
                @click="$router.push(`/radiology/catalog/${exam.id}/edit`)">
          <div class="d-flex align-center mb-3">
            <v-avatar :color="modalityColor(exam.modality_type)" size="40" variant="tonal" class="mr-3">
              <v-icon size="20">{{ modalityIcon(exam.modality_type) }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1 overflow-hidden">
              <div class="text-body-2 font-weight-bold text-truncate">{{ exam.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ exam.code }}</div>
            </div>
            <v-chip size="x-small" :color="exam.is_active ? 'success' : 'grey'" variant="tonal">
              {{ exam.is_active ? 'Active' : 'Off' }}
            </v-chip>
          </div>

          <div class="d-flex flex-wrap ga-2 mb-3">
            <v-chip size="x-small" variant="outlined">{{ exam.modality_type_display }}</v-chip>
            <v-chip v-if="exam.body_region" size="x-small" variant="outlined">{{ exam.body_region }}</v-chip>
            <v-chip v-if="exam.contrast_required" size="x-small" variant="tonal" color="warning" prepend-icon="mdi-water">Contrast</v-chip>
          </div>

          <v-spacer />

          <div class="d-flex align-center justify-space-between mt-auto">
            <div class="d-flex align-center ga-1 text-caption text-medium-emphasis">
              <v-icon size="14">mdi-clock-outline</v-icon>{{ exam.estimated_duration_minutes }}m
            </div>
            <div class="text-body-2 font-weight-bold">{{ fmtMoney(exam.price) }}</div>
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!filtered.length && !loading" cols="12">
        <div class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-book-open-page-variant</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No exams found</div>
        </div>
      </v-col>
    </v-row>

    <!-- Delete confirm dialog -->
    <v-dialog v-model="delDlg" max-width="400">
      <v-card rounded="xl" class="pa-5">
        <div class="text-h6 font-weight-bold mb-2">Delete Exam</div>
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
const exams = ref([])
const search = ref('')
const filterModality = ref(null)
const filterContrast = ref(null)
const filterActive = ref(null)
const activeFilter = ref(null)
const viewMode = ref('table')
const delDlg = ref(false)
const delTarget = ref(null)
const deleting = ref(false)
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')

const modalityTypes = [
  { title: 'X-Ray', value: 'xray' }, { title: 'CT Scan', value: 'ct' }, { title: 'MRI', value: 'mri' },
  { title: 'Ultrasound', value: 'ultrasound' }, { title: 'Mammography', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' }, { title: 'PET-CT', value: 'pet_ct' },
  { title: 'DEXA', value: 'dexa' }, { title: 'Other', value: 'other' },
]

const headers = [
  { title: '#', key: 'rowNum', width: 50, sortable: false },
  { title: 'Code', key: 'code', width: 120 },
  { title: 'Exam Name', key: 'name', width: 250 },
  { title: 'Modality', key: 'modality_type_display', width: 120 },
  { title: 'Duration', key: 'estimated_duration_minutes', width: 100 },
  { title: 'Price', key: 'price', align: 'end', width: 110 },
  { title: 'Contrast', key: 'contrast_required', align: 'center', width: 90 },
  { title: 'Status', key: 'is_active', width: 90 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

const kpis = computed(() => {
  const all = exams.value
  return [
    { key: 'all', label: 'Total Exams', count: all.length, color: 'indigo', icon: 'mdi-book-open-page-variant' },
    { key: 'active', label: 'Active', count: all.filter(e => e.is_active).length, color: 'success', icon: 'mdi-check-circle' },
    { key: 'contrast', label: 'Contrast', count: all.filter(e => e.contrast_required).length, color: 'warning', icon: 'mdi-water' },
    { key: 'inactive', label: 'Inactive', count: all.filter(e => !e.is_active).length, color: 'grey', icon: 'mdi-pause-circle' },
  ]
})

const hasFilters = computed(() => search.value || filterModality.value || filterContrast.value !== null && filterContrast.value !== undefined || filterActive.value !== null && filterActive.value !== undefined)
function clearFilters() { search.value = ''; filterModality.value = null; filterContrast.value = null; filterActive.value = null; activeFilter.value = null }

const filtered = computed(() => {
  let list = exams.value
  if (activeFilter.value === 'active') list = list.filter(e => e.is_active)
  else if (activeFilter.value === 'inactive') list = list.filter(e => !e.is_active)
  else if (activeFilter.value === 'contrast') list = list.filter(e => e.contrast_required)
  if (filterModality.value) list = list.filter(e => e.modality_type === filterModality.value)
  if (filterContrast.value === true) list = list.filter(e => e.contrast_required)
  else if (filterContrast.value === false) list = list.filter(e => !e.contrast_required)
  if (filterActive.value === true) list = list.filter(e => e.is_active)
  else if (filterActive.value === false) list = list.filter(e => !e.is_active)
  return list
})

function fmtMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }
function modalityColor(t) { return { xray:'blue-grey',ct:'indigo',mri:'deep-purple',ultrasound:'teal',mammogram:'pink',fluoroscopy:'amber-darken-2',pet_ct:'orange',dexa:'cyan',other:'grey' }[t] || 'grey' }
function modalityIcon(t) { return { xray:'mdi-radiology',ct:'mdi-rotate-3d-variant',mri:'mdi-magnet',ultrasound:'mdi-waveform',mammogram:'mdi-radiology',fluoroscopy:'mdi-movie-open',pet_ct:'mdi-atom',dexa:'mdi-bone',other:'mdi-image' }[t] || 'mdi-radiology' }

function del(item) { delTarget.value = item; delDlg.value = true }
async function confirmDel() {
  deleting.value = true
  try {
    await $api.delete(`/radiology/exam-catalog/${delTarget.value.id}/`)
    snackMsg.value = `"${delTarget.value.name}" deleted`; snackColor.value = 'success'; snack.value = true
    delDlg.value = false
    await load()
  } catch { snackMsg.value = 'Delete failed'; snackColor.value = 'error'; snack.value = true }
  deleting.value = false
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/exam-catalog/?page_size=500&ordering=name')
    exams.value = res.data?.results || res.data || []
  } catch { exams.value = [] }
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
.catalog-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.catalog-table :deep(tbody tr) { cursor: pointer; }
.exam-code { background: rgba(var(--v-theme-primary), 0.08); color: rgb(var(--v-theme-primary)); font-size: 0.75rem; letter-spacing: 0.5px; white-space: nowrap; }
.exam-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); transition: all 0.15s ease; }
.exam-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.07); transform: translateY(-2px); }
</style>
