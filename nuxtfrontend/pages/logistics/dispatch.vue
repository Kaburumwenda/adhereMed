<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-clipboard-text-outline"
      eyebrow="IMS · LOGISTICS · DISPATCH"
      title="Dispatch Board"
      subtitle="Assign drivers and vehicles, then move shipments through pickup, transit and delivery."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-glass" prepend-icon="mdi-account-multiple-check-outline" @click="assignAllVisible">
          Auto-assign ready
        </v-btn>
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" to="/ims/logistics/shipments?new=1">
          New Shipment
        </v-btn>
      </template>
    </LogiHero>

    <!-- resource strip -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="4">
        <v-card rounded="xl" border class="pa-3">
          <div class="d-flex align-center justify-space-between mb-1">
            <span class="text-caption text-uppercase text-medium-emphasis font-weight-bold">Drivers ready</span>
            <v-chip size="x-small" color="success" variant="tonal" class="font-weight-bold">{{ driverStats.available }}</v-chip>
          </div>
          <div class="d-flex flex-wrap ga-1">
            <v-chip
              v-for="d in availableDrivers.slice(0, 8)"
              :key="d.id"
              size="x-small"
              variant="tonal"
              color="teal"
              rounded="lg"
            >{{ d.full_name }}</v-chip>
            <span v-if="!availableDrivers.length" class="text-caption text-medium-emphasis">No drivers available</span>
          </div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="xl" border class="pa-3">
          <div class="d-flex align-center justify-space-between mb-1">
            <span class="text-caption text-uppercase text-medium-emphasis font-weight-bold">Vehicles ready</span>
            <v-chip size="x-small" color="success" variant="tonal" class="font-weight-bold">{{ vehicleStats.available }}</v-chip>
          </div>
          <div class="d-flex flex-wrap ga-1">
            <v-chip
              v-for="v in availableVehicles.slice(0, 8)"
              :key="v.id"
              size="x-small"
              variant="tonal"
              color="blue"
              rounded="lg"
            >{{ v.plate_number }}</v-chip>
            <span v-if="!availableVehicles.length" class="text-caption text-medium-emphasis">No vehicles available</span>
          </div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="xl" border class="pa-3">
          <div class="d-flex align-center justify-space-between mb-1">
            <span class="text-caption text-uppercase text-medium-emphasis font-weight-bold">Awaiting assignment</span>
            <v-chip size="x-small" color="amber" variant="tonal" class="font-weight-bold">{{ unassigned.length }}</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis">
            {{ unassigned.length ? 'Select a shipment below and assign a driver or carrier.' : 'Every open shipment has resources.' }}
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- filters -->
    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search reference, destination, driver…"
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
        <v-select
          v-model="driverFilter"
          :items="driverOptions"
          item-title="full_name"
          item-value="id"
          label="Driver"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          prepend-inner-icon="mdi-account-tie-hat-outline"
          class="lg-select"
          @update:model-value="load"
        />
        <v-switch v-model="onlyUnassigned" color="primary" density="compact" hide-details label="Unassigned only" @update:model-value="load" />
        <v-spacer />
        <v-btn variant="text" size="small" class="text-none" color="primary" prepend-icon="mdi-plus" @click="openCreate">Ad-hoc dispatch</v-btn>
      </div>
    </v-card>

    <!-- board -->
    <div class="lg-board">
      <div v-for="col in columns" :key="col.key" class="lg-board-col">
        <div class="lg-board-head">
          <div class="d-flex align-center ga-2">
            <v-icon size="16" :color="col.color">{{ col.icon }}</v-icon>
            <span class="font-weight-bold text-body-2">{{ col.label }}</span>
          </div>
          <v-chip size="x-small" variant="tonal" :color="col.color" class="font-weight-bold">{{ col.rows.length }}</v-chip>
        </div>
        <div class="lg-board-body">
          <div
            v-for="s in col.rows"
            :key="s.id"
            class="lg-card"
            :class="{ 'lg-card--late': s.is_late }"
            @click="openAssign(s)"
          >
            <div class="d-flex align-center justify-space-between">
              <span class="lg-card-ref">{{ s.reference }}</span>
              <v-chip size="x-small" variant="tonal" :color="priorityOf(s.priority).color">{{ priorityOf(s.priority).label }}</v-chip>
            </div>
            <div class="lg-card-route mt-1">
              {{ s.origin_name || '—' }} <v-icon size="12">mdi-arrow-right</v-icon> {{ s.dest_name || '—' }}
            </div>
            <div class="lg-card-meta mt-2">
              <span><v-icon size="13">mdi-account-outline</v-icon>{{ s.driver_name || 'Unassigned' }}</span>
              <span><v-icon size="13">mdi-truck-outline</v-icon>{{ s.vehicle_plate || '—' }}</span>
            </div>
            <div class="d-flex align-center justify-space-between mt-2">
              <span class="text-caption" :class="s.is_late ? 'text-error font-weight-medium' : 'text-medium-emphasis'">{{ etaLabel(s) }}</span>
              <v-btn size="x-small" variant="tonal" :color="col.color" class="text-none" @click.stop="quickAdvance(s)">
                {{ col.actionLabel }}
              </v-btn>
            </div>
          </div>
          <div v-if="!col.rows.length" class="lg-empty">
            <v-icon size="28" color="medium-emphasis">mdi-tray</v-icon>
            <div class="text-caption text-medium-emphasis mt-1">Nothing queued</div>
          </div>
        </div>
      </div>
    </div>

    <!-- assign dialog -->
    <v-dialog v-model="assignDialog" max-width="560">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-account-check-outline"
          :title="active ? `Dispatch ${active.reference}` : 'Dispatch shipment'"
          subtitle="Assign a driver, vehicle and schedule"
          @close="assignDialog = false"
        />
        <v-card-text v-if="active">
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mb-3">
            {{ active.origin_name || '—' }} → {{ active.dest_name || '—' }}
          </v-alert>
          <v-select v-model="form.carrier" :items="carrierOptions" item-title="name" item-value="id" label="Carrier" variant="outlined" density="comfortable" clearable class="mb-2" prepend-inner-icon="mdi-handshake-outline" />
          <v-select v-model="form.vehicle" :items="availableVehicles" item-title="display_name" item-value="id" label="Vehicle" variant="outlined" density="comfortable" clearable class="mb-2" prepend-inner-icon="mdi-truck-cargo-container" />
          <v-select v-model="form.driver" :items="availableDrivers" item-title="full_name" item-value="id" label="Driver" variant="outlined" density="comfortable" clearable class="mb-2" prepend-inner-icon="mdi-account-tie-hat-outline" />
          <v-text-field v-model="form.scheduled_pickup" type="datetime-local" label="Scheduled pickup" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="form.scheduled_delivery" type="datetime-local" label="Scheduled delivery" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="assignDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="doAssign">Assign</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const L = useLogistics()
const { shipments, assign, depart } = L
const statusOf = L.shipmentStatus
const priorityOf = L.priorityMeta

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const search = ref('')
const driverFilter = ref(null)
const onlyUnassigned = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const vehicleStatsData = ref({})
const driverStatsData = ref({})
const availableDrivers = ref([])
const availableVehicles = ref([])
const carrierOptions = ref([])
const driverOptions = ref([])

const assignDialog = ref(false)
const active = ref(null)
const form = reactive({ carrier: null, vehicle: null, driver: null, scheduled_pickup: '', scheduled_delivery: '' })

// Template-friendly summaries of the resource stats payloads.
const vehicleStats = computed(() => vehicleStatsData.value || {})
const driverStats = computed(() => driverStatsData.value || {})

const facts = computed(() => [
  { value: rows.value.length, label: 'shipments in view' },
  { value: unassigned.value.length, label: 'awaiting dispatch' },
  { value: driverStatsData.value.available ?? 0, label: 'drivers ready' },
  { value: vehicleStatsData.value.available ?? 0, label: 'vehicles ready' },
])

const unassigned = computed(() => rows.value.filter((r) => !r.driver && !r.carrier && ['draft', 'planned', 'assigned'].includes(r.status)))

const columns = computed(() => {
  const buckets = [
    { key: 'ready', label: 'Ready to dispatch', color: 'indigo', icon: 'mdi-package-variant', actionLabel: 'Dispatch',
      test: (r) => ['draft', 'planned', 'assigned'].includes(r.status) && !r.actual_pickup },
    { key: 'picked', label: 'Picked up', color: 'cyan', icon: 'mdi-package-variant-closed-check', actionLabel: 'Depart',
      test: (r) => r.status === 'picked_up' },
    { key: 'transit', label: 'On the road', color: 'teal', icon: 'mdi-truck-fast-outline', actionLabel: 'Out for delivery',
      test: (r) => r.status === 'in_transit' },
    { key: 'delivery', label: 'Out for delivery', color: 'amber', icon: 'mdi-map-marker-path', actionLabel: 'Deliver',
      test: (r) => r.status === 'out_for_delivery' },
  ]
  return buckets.map((b) => ({ ...b, rows: rows.value.filter(b.test) }))
})

function etaLabel(s) {
  if (!s.scheduled_delivery) return 'No ETA'
  const d = new Date(s.scheduled_delivery)
  if (Number.isNaN(d.getTime())) return 'No ETA'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function toLocalInput(v) {
  if (!v) return ''
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: 'scheduled_delivery' }
    if (search.value) params.search = search.value
    if (driverFilter.value) params.driver = driverFilter.value
    const [list, vs, ds, vres, dres, cres] = await Promise.all([
      shipments(params),
      L.vehicleStats(),
      L.driverStats(),
      $api.get('/logistics/vehicles/', { params: { page_size: 300, is_active: true } }),
      $api.get('/logistics/drivers/', { params: { page_size: 300, is_active: true } }),
      $api.get('/logistics/carriers/', { params: { page_size: 200, is_active: true } }),
    ])
    const unpack = (r) => r.data?.results || r.data || []
    let rowsData = list.data?.results || list.data || []
    if (onlyUnassigned.value) rowsData = rowsData.filter((r) => !r.driver && !r.carrier)
    rows.value = rowsData.filter((r) => !['delivered', 'cancelled', 'returned', 'failed'].includes(r.status))
    vehicleStatsData.value = vs.data || {}
    driverStatsData.value = ds.data || {}
    const veh = unpack(vres)
    const drv = unpack(dres)
    availableVehicles.value = veh.filter((v) => v.status === 'available').map((v) => ({ ...v, display_name: v.display_name || v.plate_number }))
    availableDrivers.value = drv.filter((d) => d.status === 'available')
    driverOptions.value = drv
    carrierOptions.value = unpack(cres)
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load dispatch board' }
  } finally {
    loading.value = false
  }
}

function openAssign(s) {
  active.value = s
  form.carrier = s.carrier || null
  form.vehicle = s.vehicle || null
  form.driver = s.driver || null
  form.scheduled_pickup = toLocalInput(s.scheduled_pickup)
  form.scheduled_delivery = toLocalInput(s.scheduled_delivery)
  assignDialog.value = true
}

function openCreate() {
  navigateTo('/ims/logistics/shipments?new=1')
}

async function doAssign() {
  if (!active.value) return
  saving.value = true
  try {
    const body = { carrier: form.carrier || null, vehicle: form.vehicle || null, driver: form.driver || null }
    if (form.scheduled_pickup) body.scheduled_pickup = new Date(form.scheduled_pickup).toISOString()
    if (form.scheduled_delivery) body.scheduled_delivery = new Date(form.scheduled_delivery).toISOString()
    await assign(active.value.id, body)
    assignDialog.value = false
    snack.value = { show: true, color: 'success', text: `${active.value.reference} dispatched` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Assignment failed' }
  } finally {
    saving.value = false
  }
}

async function quickAdvance(s) {
  try {
    if (!s.actual_pickup) {
      openAssign(s)
      return
    }
    if (s.status === 'picked_up') await depart(s.id)
    else if (s.status === 'in_transit') await L.outForDelivery(s.id)
    else if (s.status === 'out_for_delivery') navigateTo(`/ims/logistics/shipments?focus=${s.id}`)
    snack.value = { show: true, color: 'success', text: `${s.reference} advanced` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Action failed' }
  }
}

async function assignAllVisible() {
  const targets = columns.value[0].rows.filter((r) => !r.driver && !r.carrier)
  if (!targets.length) {
    snack.value = { show: true, color: 'info', text: 'Nothing to auto-assign' }
    return
  }
  let assigned = 0
  for (const r of targets) {
    const drv = availableDrivers.value[assigned]
    const veh = availableVehicles.value[assigned]
    if (!drv && !veh) break
    try {
      await assign(r.id, { driver: drv?.id || null, vehicle: veh?.id || null })
      assigned += 1
    } catch { /* keep going */ }
  }
  snack.value = { show: true, color: assigned ? 'success' : 'info', text: assigned ? `${assigned} shipment(s) assigned` : 'No resources available' }
  await load()
}

onMounted(load)
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
}
.lg-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.lg-search { flex: 1 1 300px; max-width: 420px; }
.lg-select { width: 200px; }
.lg-board { display: grid; grid-template-columns: repeat(auto-fit, minmax(270px, 1fr)); gap: 14px; align-items: start; }
.lg-board-col {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-border-color), 0.16);
  border-radius: 16px; overflow: hidden; display: flex; flex-direction: column;
}
.lg-board-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px; border-bottom: 1px solid rgba(var(--v-border-color), 0.14);
  background: rgba(var(--v-theme-surface-variant), 0.4);
}
.lg-board-body { padding: 10px; display: flex; flex-direction: column; gap: 10px; }
.lg-empty { text-align: center; padding: 22px 0; }
.lg-card {
  border: 1px solid rgba(var(--v-border-color), 0.18);
  border-radius: 13px; padding: 12px; cursor: pointer;
  transition: box-shadow .16s, transform .16s;
}
.lg-card:hover { box-shadow: 0 6px 18px rgba(0, 0, 0, .09); transform: translateY(-1px); }
.lg-card--late { border-color: rgba(239, 68, 68, 0.42); }
.lg-card-ref { font-size: 12.5px; font-weight: 800; }
.lg-card-route { font-size: 12px; color: rgba(var(--v-theme-on-surface), .72); }
.lg-card-meta { display: flex; flex-wrap: wrap; gap: 10px; font-size: 11.5px; color: rgba(var(--v-theme-on-surface), .66); }
.lg-card-meta span { display: inline-flex; align-items: center; gap: 4px; }
</style>
