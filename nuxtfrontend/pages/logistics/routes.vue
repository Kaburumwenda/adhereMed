<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-map-marker-path"
      eyebrow="IMS · LOGISTICS · ROUTE PLANNING"
      title="Route Planning"
      subtitle="Bundle shipments into a run, sequence the stops, then dispatch to a driver and vehicle."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New route
        </v-btn>
      </template>
    </LogiHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search route name…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable"
          variant="solo-filled"
          rounded="lg"
          flat
          bg-color="surface"
          hide-details
          clearable
          class="lg-search"
          @keyup.enter="load"
          @click:clear="load"
        />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value" label="Status" density="compact" variant="outlined" rounded="lg" hide-details clearable class="lg-select" @update:model-value="load" />
        <v-text-field v-model="dateFilter" type="date" label="Plan date" density="compact" variant="outlined" rounded="lg" hide-details clearable class="lg-select" @update:model-value="load" />
      </div>
    </v-card>

    <v-row dense>
      <v-col v-for="r in routes" :key="r.id" cols="12" md="6" xl="4">
        <v-card rounded="xl" border class="lg-route-card h-100">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <div class="lg-route-icon" :class="`lg-route--${r.status}`">
                <v-icon size="21">mdi-map-marker-path</v-icon>
              </div>
              <div>
                <div class="lg-route-name">{{ r.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ r.plan_date }}</div>
              </div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="statusMeta(r.status).color" class="font-weight-bold">
              {{ statusMeta(r.status).label }}
            </v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="lg-route-grid">
            <div>
              <div class="lg-route-label">Driver</div>
              <div class="lg-route-value">{{ r.driver_name || '—' }}</div>
            </div>
            <div>
              <div class="lg-route-label">Vehicle</div>
              <div class="lg-route-value">{{ r.vehicle_plate || '—' }}</div>
            </div>
            <div>
              <div class="lg-route-label">Stops</div>
              <div class="lg-route-value">{{ r.stop_count || 0 }}</div>
            </div>
            <div>
              <div class="lg-route-label">Distance</div>
              <div class="lg-route-value">{{ formatQty(r.planned_distance_km) }} km</div>
            </div>
          </div>

          <div v-if="r.shipment_refs && r.shipment_refs.length" class="d-flex flex-wrap ga-1 mt-3">
            <v-chip v-for="ref in r.shipment_refs.slice(0, 6)" :key="ref" size="x-small" variant="tonal" color="primary">{{ ref }}</v-chip>
            <v-chip v-if="r.shipment_refs.length > 6" size="x-small" variant="tonal" color="grey">+{{ r.shipment_refs.length - 6 }}</v-chip>
          </div>

          <v-divider class="my-3" />
          <div class="d-flex flex-wrap ga-2">
            <v-btn size="small" variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-auto-fix" :loading="working === r.id" @click="optimize(r)">Optimize</v-btn>
            <v-btn v-if="r.status === 'optimized' || r.status === 'draft'" size="small" variant="flat" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-send-outline" @click="dispatch(r)">Dispatch</v-btn>
            <v-btn v-if="r.status === 'dispatched' || r.status === 'in_progress'" size="small" variant="flat" color="success" rounded="lg" class="text-none" prepend-icon="mdi-check-decagram" @click="complete(r)">Complete</v-btn>
            <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-pencil" @click="editRoute(r)">Edit</v-btn>
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!routes.length" cols="12">
        <v-card rounded="xl" border>
          <div class="lg-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-map-marker-path</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No route plans</div>
            <div class="text-caption text-medium-emphasis">Group shipments into a run to plan a driver's day.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">New route</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- form -->
    <v-dialog v-model="formDialog" max-width="760" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? `Edit ${form.name}` : 'New route plan'"
          subtitle="Bundle shipments into a driver's run"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="8"><v-text-field v-model="form.name" label="Route name *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.plan_date" type="date" label="Plan date" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.driver" :items="drivers" item-title="full_name" item-value="id" label="Driver" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.vehicle" :items="vehicles" item-title="plate_number" item-value="id" label="Vehicle" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.carrier" :items="carriers" item-title="name" item-value="id" label="Carrier" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12">
              <v-select
                v-model="form.shipments"
                :items="shipmentOptions"
                item-title="label"
                item-value="id"
                label="Shipments in this run"
                variant="outlined"
                density="comfortable"
                multiple
                chips
                closable-chips
              />
            </v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="removeRoute">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveRoute">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- optimized sequence -->
    <v-dialog v-model="seqDialog" max-width="560">
      <v-card v-if="seqRoute" rounded="xl">
        <BrandDialogHeader
          icon="mdi-format-list-numbered"
          :title="`Optimized sequence · ${seqRoute.name}`"
          subtitle="Suggested stop order for this run"
          @close="seqDialog = false"
        />
        <v-card-text>
          <div v-for="s in seq" :key="s.sequence" class="lg-seq-row">
            <span class="lg-seq-num">{{ s.sequence }}</span>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-medium">{{ s.reference }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.dest_name || '—' }}</div>
            </div>
            <span class="text-caption text-medium-emphasis">{{ dt(s.scheduled_delivery) }}</span>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="seqDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const L = useLogistics()

const loading = ref(false)
const saving = ref(false)
const working = ref(null)
const routes = ref([])
const stats = ref({})
const search = ref('')
const statusFilter = ref(null)
const dateFilter = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const seqDialog = ref(false)
const seqRoute = ref(null)
const editing = ref(false)
const form = ref(blankForm())

const drivers = ref([])
const vehicles = ref([])
const carriers = ref([])
const shipmentOptions = ref([])

const statusOptions = [
  { value: 'draft', label: 'Draft' },
  { value: 'optimized', label: 'Optimized' },
  { value: 'dispatched', label: 'Dispatched' },
  { value: 'in_progress', label: 'In progress' },
  { value: 'completed', label: 'Completed' },
]

const statusMetaMap = {
  draft: { label: 'Draft', color: 'grey' },
  optimized: { label: 'Optimized', color: 'teal' },
  dispatched: { label: 'Dispatched', color: 'blue' },
  in_progress: { label: 'In progress', color: 'amber' },
  completed: { label: 'Completed', color: 'success' },
  cancelled: { label: 'Cancelled', color: 'grey-darken-2' },
}

const seq = computed(() => seqRoute.value?.optimized_sequence || [])

const facts = computed(() => [
  { value: stats.value.total ?? 0, label: 'route plans' },
  { value: stats.value.optimized ?? 0, label: 'optimized' },
  { value: stats.value.dispatched ?? 0, label: 'dispatched' },
  { value: `${formatQty(stats.value.planned_distance_km || 0)}`, label: 'km planned' },
])

const kpis = computed(() => [
  { title: 'Total plans', value: stats.value.total ?? 0, sub: 'all routes', icon: 'mdi-map-marker-path', color: 'primary' },
  { title: 'Draft', value: stats.value.draft ?? 0, sub: 'not optimized', icon: 'mdi-file-outline', color: 'grey' },
  { title: 'Optimized', value: stats.value.optimized ?? 0, sub: 'ready to dispatch', icon: 'mdi-auto-fix', color: 'teal' },
  { title: 'Dispatched', value: stats.value.dispatched ?? 0, sub: 'on the road', icon: 'mdi-send-outline', color: 'blue' },
  { title: 'In progress', value: stats.value.in_progress ?? 0, sub: 'executing', icon: 'mdi-progress-clock', color: 'amber' },
  { title: 'Completed', value: stats.value.completed ?? 0, sub: 'closed runs', icon: 'mdi-check-decagram', color: 'success' },
])

function statusMeta(s) {
  return statusMetaMap[s] || { label: s, color: 'grey' }
}

function formatQty(v) {
  return (Number(v) || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function blankForm() {
  return {
    name: '', plan_date: new Date().toISOString().slice(0, 10),
    status: 'draft', driver: null, vehicle: null, carrier: null,
    shipments: [], notes: '',
  }
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 300, ordering: '-plan_date' }
    if (search.value) params.search = search.value
    if (statusFilter.value) params.status = statusFilter.value
    if (dateFilter.value) params.plan_date = dateFilter.value
    const [list, st] = await Promise.all([L.routes(params), L.routeStats()])
    routes.value = list.data?.results || list.data || []
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load routes' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const [d, v, c, s] = await Promise.all([
      $api.get('/logistics/drivers/', { params: { page_size: 300, is_active: true } }),
      $api.get('/logistics/vehicles/', { params: { page_size: 300, is_active: true } }),
      $api.get('/logistics/carriers/', { params: { page_size: 200, is_active: true } }),
      $api.get('/logistics/shipments/', { params: { page_size: 300, ordering: 'scheduled_delivery' } }),
    ])
    const unpack = (r) => r.data?.results || r.data || []
    drivers.value = unpack(d)
    vehicles.value = unpack(v)
    carriers.value = unpack(c)
    shipmentOptions.value = unpack(s)
      .filter((x) => !['delivered', 'cancelled', 'returned', 'failed'].includes(x.status))
      .map((x) => ({ ...x, label: `${x.reference} · ${x.dest_name || '—'}` }))
  } catch { /* optional */ }
}

function openCreate() {
  editing.value = false
  form.value = blankForm()
  formDialog.value = true
}

function editRoute(r) {
  editing.value = true
  form.value = {
    ...blankForm(),
    ...r,
    shipments: (r.shipment_refs || []).length
      ? shipmentOptions.value.filter((s) => (r.shipment_refs || []).includes(s.reference)).map((s) => s.id)
      : [],
  }
  formDialog.value = true
}

async function saveRoute() {
  if (!form.value.name) {
    snack.value = { show: true, color: 'error', text: 'Route name is required' }
    return
  }
  saving.value = true
  try {
    const body = { ...form.value }
    if (!body.driver) body.driver = null
    if (!body.vehicle) body.vehicle = null
    if (!body.carrier) body.carrier = null
    if (editing.value && form.value.id) {
      await $api.patch(`/logistics/routes/${form.value.id}/`, body)
      snack.value = { show: true, color: 'success', text: 'Route updated' }
    } else {
      await $api.post('/logistics/routes/', body)
      snack.value = { show: true, color: 'success', text: 'Route created' }
    }
    formDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Save failed' }
  } finally {
    saving.value = false
  }
}

async function removeRoute() {
  if (!form.value.id) return
  saving.value = true
  try {
    await $api.delete(`/logistics/routes/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Route deleted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Delete failed' }
  } finally {
    saving.value = false
  }
}

async function optimize(r) {
  working.value = r.id
  try {
    const { data } = await L.optimizeRoute(r.id)
    seqRoute.value = data
    seqDialog.value = true
    snack.value = { show: true, color: 'success', text: 'Route optimized' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Optimization failed' }
  } finally {
    working.value = null
  }
}

async function dispatch(r) {
  try {
    await L.dispatchRoute(r.id)
    snack.value = { show: true, color: 'success', text: `${r.name} dispatched` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Dispatch failed' }
  }
}

async function complete(r) {
  try {
    await L.completeRoute(r.id)
    snack.value = { show: true, color: 'success', text: `${r.name} completed` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Complete failed' }
  }
}

onMounted(async () => {
  await loadLookups()
  await load()
})
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.lg-search { flex: 1 1 260px; max-width: 400px; }
.lg-select { width: 170px; }
.lg-route-card { padding: 14px; }
.lg-route-icon { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; background: rgba(var(--v-theme-primary), .1); color: rgb(var(--v-theme-primary)); }
.lg-route--optimized { background: rgba(13,148,136,.14); color: #0f766e; }
.lg-route--dispatched { background: rgba(59,130,246,.14); color: #1d4ed8; }
.lg-route--in_progress { background: rgba(245,158,11,.16); color: #b45309; }
.lg-route--completed { background: rgba(16,185,129,.14); color: #0f766e; }
.lg-route--draft { background: rgba(107,114,128,.14); color: #4b5563; }
.lg-route-name { font-size: 14px; font-weight: 800; }
.lg-route-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.lg-route-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-route-value { font-size: 13px; font-weight: 600; }
.lg-seq-row { display: flex; align-items: center; gap: 12px; padding: 8px 0; border-bottom: 1px solid rgba(var(--v-border-color), .12); }
.lg-seq-num { width: 26px; height: 26px; border-radius: 50%; background: rgba(var(--v-theme-primary), .12); color: rgb(var(--v-theme-primary)); display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 800; flex-shrink: 0; }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
