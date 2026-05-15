<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="deep-purple-lighten-5" size="48">
        <v-icon color="deep-purple-darken-2" size="28">mdi-package-variant</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Exam Panels</div>
        <div class="text-body-2 text-medium-emphasis">Bundled exam packages with combined pricing</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             to="/radiology/panels/new">New Panel</v-btn>
    </div>

    <!-- KPI strip -->
    <div class="kpi-strip mb-4">
      <div v-for="k in kpis" :key="k.label" class="kpi-item pa-3 rounded-lg cursor-pointer"
           :class="{ 'kpi-item--active': activeKpi === k.filter }" @click="toggleKpi(k.filter)">
        <div class="d-flex align-center ga-2">
          <v-avatar :color="k.color" size="36" variant="tonal">
            <v-icon size="18">{{ k.icon }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6 font-weight-bold" style="line-height:1">{{ k.value }}</div>
            <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Search -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <v-col cols="12" sm="5" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search panels or exams…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterActive" :items="[{title:'Active',value:true},{title:'Inactive',value:false}]"
            label="Status" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-spacer />
        <v-col cols="auto">
          <v-btn-toggle v-model="viewMode" density="compact" rounded="lg" mandatory>
            <v-btn value="grid" icon="mdi-view-grid" size="small" />
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- Grid view -->
    <v-row v-if="viewMode === 'grid'" dense>
      <v-col v-for="panel in filtered" :key="panel.id" cols="12" sm="6" md="4">
        <v-card flat rounded="xl" class="panel-card h-100 d-flex flex-column" @click="$router.push(`/radiology/panels/${panel.id}/edit`)">
          <v-card-text class="pa-4 flex-grow-1">
            <div class="d-flex align-center justify-space-between mb-2">
              <div class="d-flex align-center ga-2" style="min-width:0">
                <v-avatar size="32" color="deep-purple" variant="tonal">
                  <v-icon size="16">mdi-package-variant</v-icon>
                </v-avatar>
                <div class="text-subtitle-1 font-weight-bold text-truncate">{{ panel.name }}</div>
              </div>
              <v-chip size="x-small" :color="panel.is_active ? 'success' : 'grey'" variant="tonal">
                {{ panel.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>
            <div v-if="panel.description" class="text-body-2 text-medium-emphasis mb-3 two-line">{{ panel.description }}</div>

            <!-- Exams -->
            <div class="text-caption font-weight-bold text-uppercase mb-1">
              <v-icon size="12" class="mr-1">mdi-flask-outline</v-icon>
              Included Exams ({{ (panel.exam_names || []).length }})
            </div>
            <div class="d-flex flex-wrap ga-1 mb-3">
              <v-chip v-for="e in (panel.exam_names || []).slice(0, 5)" :key="e" size="small" variant="flat" color="indigo"
                      label prepend-icon="mdi-flask-outline" class="font-weight-medium">{{ e }}</v-chip>
              <v-chip v-if="(panel.exam_names || []).length > 5" size="small" variant="tonal" color="indigo" label>
                +{{ panel.exam_names.length - 5 }} more
              </v-chip>
            </div>

            <!-- Price row -->
            <div class="price-bar pa-2 rounded-lg d-flex align-center justify-space-between">
              <div class="text-caption text-medium-emphasis">Bundle Price</div>
              <div class="text-body-1 font-weight-bold text-primary">{{ fmtMoney(panel.price) }}</div>
            </div>
          </v-card-text>

          <v-divider />

          <v-card-actions class="px-4 py-2">
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-pencil"
                   :to="`/radiology/panels/${panel.id}/edit`" @click.stop>Edit</v-btn>
            <v-spacer />
            <v-btn variant="text" size="small" color="error" class="text-none" icon="mdi-delete"
                   @click.stop="del(panel)" />
          </v-card-actions>
        </v-card>
      </v-col>
    </v-row>

    <!-- Table view -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="section-card">
      <v-data-table :headers="headers" :items="filtered" :items-per-page="20" hover
        class="rounded-xl" @click:row="(_, { item }) => $router.push(`/radiology/panels/${item.id}/edit`)">
        <template #item.index="{ index }">
          <span class="text-caption text-medium-emphasis">{{ index + 1 }}</span>
        </template>
        <template #item.name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="deep-purple" variant="tonal">
              <v-icon size="14">mdi-package-variant</v-icon>
            </v-avatar>
            <span class="font-weight-medium">{{ item.name }}</span>
          </div>
        </template>
        <template #item.exam_count="{ item }">
          <v-chip size="x-small" variant="tonal" color="indigo">{{ (item.exam_names || []).length }} exams</v-chip>
        </template>
        <template #item.price="{ item }">
          <span class="font-weight-bold">{{ fmtMoney(item.price) }}</span>
        </template>
        <template #item.is_active="{ item }">
          <v-chip size="x-small" :color="item.is_active ? 'success' : 'grey'" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="x-small" :to="`/radiology/panels/${item.id}/edit`" @click.stop />
          <v-btn icon="mdi-delete" variant="text" size="x-small" color="error" @click.stop="del(item)" />
        </template>
      </v-data-table>
    </v-card>

    <!-- Empty state -->
    <div v-if="!filtered.length && !loading" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-package-variant</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No panels found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">Create your first exam panel bundle.</div>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/radiology/panels/new" class="text-none">New Panel</v-btn>
    </div>

    <!-- Loading -->
    <v-row v-if="loading" dense>
      <v-col v-for="n in 6" :key="n" cols="12" sm="6" md="4">
        <v-skeleton-loader type="card" rounded="xl" />
      </v-col>
    </v-row>

    <!-- Delete dialog -->
    <v-dialog v-model="delDlg" max-width="420">
      <v-card rounded="xl" class="pa-5">
        <div class="d-flex align-center ga-2 mb-3">
          <v-avatar color="error" variant="tonal" size="36">
            <v-icon size="18">mdi-alert</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Delete Panel</div>
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
const panels = ref([])
const search = ref('')
const filterActive = ref(null)
const activeKpi = ref(null)
const viewMode = ref('grid')
const delDlg = ref(false)
const delTarget = ref(null)
const deleting = ref(false)
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')

const headers = [
  { title: '#', key: 'index', sortable: false, width: 40 },
  { title: 'Panel Name', key: 'name' },
  { title: 'Exams', key: 'exam_count', sortable: false },
  { title: 'Bundle Price', key: 'price' },
  { title: 'Status', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, width: 80 },
]

const kpis = computed(() => {
  const all = panels.value
  const totalExams = all.reduce((s, p) => s + (p.exam_names?.length || 0), 0)
  return [
    { label: 'Total Panels', value: all.length, color: 'deep-purple', icon: 'mdi-package-variant', filter: 'all' },
    { label: 'Active', value: all.filter(p => p.is_active).length, color: 'success', icon: 'mdi-check-circle', filter: 'active' },
    { label: 'Total Exams', value: totalExams, color: 'indigo', icon: 'mdi-flask-outline', filter: null },
    { label: 'Avg Exams/Panel', value: all.length ? (totalExams / all.length).toFixed(1) : '0', color: 'teal', icon: 'mdi-chart-bar', filter: null },
  ]
})

function toggleKpi(f) {
  if (!f) return
  if (activeKpi.value === f) { activeKpi.value = null; filterActive.value = null; return }
  activeKpi.value = f
  filterActive.value = f === 'active' ? true : null
}

const filtered = computed(() => {
  let list = panels.value
  if (search.value) {
    const q = search.value.toLowerCase()
    list = list.filter(p => p.name.toLowerCase().includes(q) || p.exam_names?.some(e => e.toLowerCase().includes(q)))
  }
  if (filterActive.value === true) list = list.filter(p => p.is_active)
  else if (filterActive.value === false) list = list.filter(p => !p.is_active)
  return list
})

function fmtMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }

function del(item) { delTarget.value = item; delDlg.value = true }
async function confirmDel() {
  deleting.value = true
  try {
    await $api.delete(`/radiology/exam-panels/${delTarget.value.id}/`)
    snackMsg.value = `"${delTarget.value.name}" deleted`; snackColor.value = 'success'; snack.value = true
    delDlg.value = false
    await load()
  } catch { snackMsg.value = 'Delete failed'; snackColor.value = 'error'; snack.value = true }
  deleting.value = false
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/exam-panels/?page_size=200&ordering=name')
    panels.value = res.data?.results || res.data || []
  } catch { panels.value = [] }
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
.section-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.panel-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); cursor: pointer; transition: all 0.18s ease; }
.panel-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.08); transform: translateY(-3px); }
.price-bar { background: rgba(var(--v-theme-primary), 0.04); }
.two-line { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
</style>
