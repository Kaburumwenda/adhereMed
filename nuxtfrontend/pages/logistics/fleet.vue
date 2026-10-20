<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-truck-cargo-container"
      eyebrow="IMS · LOGISTICS · FLEET"
      title="Fleet & Vehicles"
      subtitle="Owned, leased and third-party capacity — availability, capacity, compliance and maintenance in one place."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          Add vehicle
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
          placeholder="Search plate, make, model…"
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
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value" label="Type" density="compact" variant="outlined" rounded="lg" hide-details clearable class="lg-select" @update:model-value="load" />
        <v-spacer />
        <v-btn variant="text" size="small" class="text-none" color="primary" prepend-icon="mdi-wrench-clock" @click="openMaintenance()">
          Log maintenance
        </v-btn>
      </div>
    </v-card>

    <v-row dense>
      <v-col v-for="v in vehicles" :key="v.id" cols="12" sm="6" lg="4" xl="3">
        <v-card rounded="xl" border class="lg-veh-card h-100" @click="openDetail(v)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <div class="lg-veh-icon" :class="`lg-veh--${v.status}`">
                <v-icon size="22">{{ typeIcon(v.vehicle_type) }}</v-icon>
              </div>
              <div>
                <div class="lg-veh-plate">{{ v.plate_number }}</div>
                <div class="text-caption text-medium-emphasis">{{ v.display_name }}</div>
              </div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="statusMeta(v.status).color" class="font-weight-bold">
              {{ statusMeta(v.status).label }}
            </v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="lg-veh-grid">
            <div>
              <div class="lg-veh-label">Capacity</div>
              <div class="lg-veh-value">{{ formatQty(v.capacity_kg) }} kg</div>
            </div>
            <div>
              <div class="lg-veh-label">Odometer</div>
              <div class="lg-veh-value">{{ formatQty(v.odometer_km) }} km</div>
            </div>
            <div>
              <div class="lg-veh-label">Ownership</div>
              <div class="lg-veh-value">{{ ownershipLabel(v.ownership) }}</div>
            </div>
            <div>
              <div class="lg-veh-label">Shipments</div>
              <div class="lg-veh-value">{{ v.shipment_count ?? 0 }}</div>
            </div>
          </div>

          <div v-if="v.carrier_name || v.home_branch_name" class="d-flex flex-wrap ga-1 mt-3">
            <v-chip v-if="v.carrier_name" size="x-small" variant="tonal" color="purple">{{ v.carrier_name }}</v-chip>
            <v-chip v-if="v.home_branch_name" size="x-small" variant="tonal" color="primary">{{ v.home_branch_name }}</v-chip>
          </div>

          <v-alert
            v-if="docWarning(v)"
            type="warning"
            variant="tonal"
            density="compact"
            rounded="lg"
            class="mt-3"
          >{{ docWarning(v) }}</v-alert>
        </v-card>
      </v-col>
      <v-col v-if="!vehicles.length" cols="12">
        <v-card rounded="xl" border>
          <div class="lg-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-truck-outline</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No vehicles registered</div>
            <div class="text-caption text-medium-emphasis">Add your first vehicle to start dispatching.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">Add vehicle</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- create / edit -->
    <v-dialog v-model="formDialog" max-width="820" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? `Edit ${form.plate_number}` : 'Add vehicle'"
          subtitle="Fleet asset, capacity and compliance"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="4"><v-text-field v-model="form.plate_number" label="Plate number *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.name" label="Friendly name" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.vehicle_type" :items="typeOptions" item-title="label" item-value="value" label="Type" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.make" label="Make" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.model" label="Model" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model.number="form.year" type="number" label="Year" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.capacity_kg" type="number" step="0.01" label="Capacity (kg)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.capacity_volume_m3" type="number" step="0.01" label="Volume (m³)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.ownership" :items="ownershipOptions" item-title="label" item-value="value" label="Ownership" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.status" :items="statusOptions" item-title="label" item-value="value" label="Status" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.home_branch" :items="branches" item-title="name" item-value="id" label="Home warehouse" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.carrier" :items="carriers" item-title="name" item-value="id" label="Carrier (if third party)" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.fuel_type" label="Fuel type" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.fuel_capacity_l" type="number" step="0.01" label="Fuel capacity (L)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.odometer_km" type="number" step="0.01" label="Odometer (km)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.insurance_expiry" type="date" label="Insurance expiry" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.inspection_expiry" type="date" label="Inspection expiry" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.last_service_at" type="date" label="Last service" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="removeVehicle">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveVehicle">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- detail -->
    <v-dialog v-model="detailDialog" max-width="760" scrollable>
      <v-card v-if="active" rounded="xl">
        <BrandDialogHeader
          :icon="typeIcon(active.vehicle_type)"
          :title="active.plate_number"
          :subtitle="`${statusMeta(active.status).label} · ${ownershipLabel(active.ownership)}`"
          @close="detailDialog = false"
        >
          <template #actions>
            <v-btn icon="mdi-pencil" size="small" variant="text" class="lg-hero-iconbtn" title="Edit vehicle" @click="editVehicle(active)" />
          </template>
        </BrandDialogHeader>
        <v-card-text>
          <v-row dense class="mb-2">
            <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-veh-label">Capacity</div><div class="lg-veh-value">{{ formatQty(active.capacity_kg) }} kg</div></div></v-col>
            <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-veh-label">Odometer</div><div class="lg-veh-value">{{ formatQty(active.odometer_km) }} km</div></div></v-col>
            <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-veh-label">Shipments</div><div class="lg-veh-value">{{ active.shipment_count ?? 0 }}</div></div></v-col>
            <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-veh-label">Ownership</div><div class="lg-veh-value">{{ ownershipLabel(active.ownership) }}</div></div></v-col>
          </v-row>

          <div class="text-subtitle-2 font-weight-bold mt-3 mb-1">Set status</div>
          <div class="d-flex flex-wrap ga-2 mb-4">
            <v-btn
              v-for="s in statusOptions"
              :key="s.value"
              size="small"
              rounded="lg"
              class="text-none"
              :variant="active.status === s.value ? 'flat' : 'tonal'"
              :color="statusMeta(s.value).color"
              @click="changeStatus(active, s.value)"
            >{{ s.label }}</v-btn>
          </div>

          <div class="d-flex align-center justify-space-between mb-2">
            <div class="text-subtitle-2 font-weight-bold">Maintenance history</div>
            <v-btn size="small" variant="text" class="text-none" color="primary" prepend-icon="mdi-plus" @click="openMaintenance(active)">Log</v-btn>
          </div>
          <v-table density="compact" v-if="maintenance.length">
            <thead>
              <tr><th>Date</th><th>Kind</th><th>Vendor</th><th class="text-right">Cost</th><th>Next due</th></tr>
            </thead>
            <tbody>
              <tr v-for="m in maintenance" :key="m.id">
                <td>{{ m.performed_at }}</td>
                <td>{{ titleCase(m.kind) }}</td>
                <td>{{ m.vendor || '—' }}</td>
                <td class="text-right">{{ formatMoney(m.cost) }}</td>
                <td>{{ m.next_due_at || '—' }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-caption text-medium-emphasis">No maintenance records yet.</div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- maintenance -->
    <v-dialog v-model="maintenanceDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-wrench-clock"
          title="Log maintenance"
          subtitle="Service, repair or compliance record"
          @close="maintenanceDialog = false"
        />
        <v-card-text>
          <v-select v-model="mForm.vehicle" :items="vehicles" item-title="plate_number" item-value="id" label="Vehicle" variant="outlined" density="comfortable" class="mb-2" />
          <v-select v-model="mForm.kind" :items="maintenanceKinds" item-title="label" item-value="value" label="Kind" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="mForm.performed_at" type="date" label="Performed on" variant="outlined" density="comfortable" class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-text-field v-model.number="mForm.odometer_km" type="number" step="0.01" label="Odometer (km)" variant="outlined" density="comfortable" />
            <v-text-field v-model.number="mForm.cost" type="number" step="0.01" label="Cost" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="mForm.vendor" label="Vendor" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="mForm.next_due_at" type="date" label="Next due" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="mForm.description" label="Description" rows="2" auto-grow variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="maintenanceDialog = false">Cancel</v-btn>
          <v-btn color="amber-darken-2" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveMaintenance">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { VEHICLE_STATUS_META, VEHICLE_TYPE_ICON, useLogistics } from '~/composables/useLogistics'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const L = useLogistics()

const loading = ref(false)
const saving = ref(false)
const vehicles = ref([])
const stats = ref({})
const branches = ref([])
const carriers = ref([])
const search = ref('')
const statusFilter = ref(null)
const typeFilter = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const detailDialog = ref(false)
const maintenanceDialog = ref(false)
const editing = ref(false)
const active = ref(null)
const maintenance = ref([])

const form = ref(blankForm())
const mForm = reactive({ vehicle: null, kind: 'service', performed_at: today(), odometer_km: 0, cost: 0, vendor: '', next_due_at: '', description: '' })

const statusOptions = Object.entries(VEHICLE_STATUS_META).map(([value, m]) => ({ value, label: m.label, color: m.color }))
const typeOptions = Object.entries(VEHICLE_TYPE_ICON).map(([value, icon]) => ({ value, label: titleCase(value), icon }))
const ownershipOptions = [
  { value: 'owned', label: 'Owned' },
  { value: 'leased', label: 'Leased' },
  { value: 'third_party', label: 'Third party' },
]
const maintenanceKinds = [
  { value: 'service', label: 'Routine service' },
  { value: 'repair', label: 'Repair' },
  { value: 'inspection', label: 'Inspection' },
  { value: 'tyres', label: 'Tyres' },
  { value: 'insurance', label: 'Insurance' },
  { value: 'other', label: 'Other' },
]

const facts = computed(() => [
  { value: stats.value.total ?? 0, label: 'vehicles' },
  { value: stats.value.available ?? 0, label: 'available' },
  { value: stats.value.in_use ?? 0, label: 'on the road' },
  { value: stats.value.maintenance ?? 0, label: 'in service' },
])

const kpis = computed(() => [
  { title: 'Total fleet', value: stats.value.total ?? 0, sub: 'registered vehicles', icon: 'mdi-truck-cargo-container', color: 'primary' },
  { title: 'Available', value: stats.value.available ?? 0, sub: 'ready to dispatch', icon: 'mdi-check-circle-outline', color: 'success' },
  { title: 'In use', value: stats.value.in_use ?? 0, sub: 'currently moving', icon: 'mdi-truck-fast-outline', color: 'blue' },
  { title: 'Maintenance', value: stats.value.maintenance ?? 0, sub: 'out of service', icon: 'mdi-wrench-clock', color: 'amber' },
  { title: 'Capacity', value: `${formatQty(stats.value.capacity_kg || 0)} kg`, sub: 'combined payload', icon: 'mdi-weight', color: 'teal' },
  { title: 'Docs expiring', value: stats.value.insurance_expiring ?? 0, sub: 'within 30 days', icon: 'mdi-shield-alert-outline', color: 'error' },
])

function today() {
  return new Date().toISOString().slice(0, 10)
}

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function formatQty(v) {
  return (Number(v) || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })
}

function typeIcon(t) {
  return VEHICLE_TYPE_ICON[t] || 'mdi-truck-outline'
}

function statusMeta(s) {
  return VEHICLE_STATUS_META[s] || { label: s, color: 'grey' }
}

function ownershipLabel(v) {
  const found = ownershipOptions.find((o) => o.value === v)
  return found ? found.label : titleCase(v)
}

function docWarning(v) {
  if (!v.insurance_expiry && !v.inspection_expiry) return ''
  const todayMs = Date.now()
  const soon = 30 * 24 * 3600 * 1000
  const ins = v.insurance_expiry ? new Date(v.insurance_expiry).getTime() : null
  const insp = v.inspection_expiry ? new Date(v.inspection_expiry).getTime() : null
  if (ins && ins < todayMs) return 'Insurance has expired — vehicle cannot be dispatched.'
  if (insp && insp < todayMs) return 'Inspection has expired — vehicle cannot be dispatched.'
  if (ins && ins - todayMs < soon) return 'Insurance expires within 30 days.'
  if (insp && insp - todayMs < soon) return 'Inspection expires within 30 days.'
  return ''
}

function blankForm() {
  return {
    plate_number: '', name: '', vehicle_type: 'van', make: '', model: '', year: null,
    capacity_kg: 0, capacity_volume_m3: 0, ownership: 'owned', status: 'available',
    home_branch: null, carrier: null, fuel_type: 'diesel', fuel_capacity_l: 0,
    odometer_km: 0, insurance_expiry: '', inspection_expiry: '', last_service_at: '',
    is_active: true, notes: '',
  }
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: 'plate_number' }
    if (search.value) params.search = search.value
    if (statusFilter.value) params.status = statusFilter.value
    if (typeFilter.value) params.vehicle_type = typeFilter.value
    const [list, st] = await Promise.all([L.vehicles(params), L.vehicleStats()])
    vehicles.value = list.data?.results || list.data || []
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load fleet' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const [b, c] = await Promise.all([
      $api.get(branchesApi.value, { params: { page_size: 200 } }),
      $api.get('/logistics/carriers/', { params: { page_size: 200 } }),
    ])
    branches.value = b.data?.results || b.data || []
    carriers.value = c.data?.results || c.data || []
  } catch { /* optional */ }
}

function openCreate() {
  editing.value = false
  form.value = blankForm()
  formDialog.value = true
}

function editVehicle(v) {
  editing.value = true
  form.value = { ...blankForm(), ...v }
  detailDialog.value = false
  formDialog.value = true
}

async function openDetail(v) {
  active.value = v
  detailDialog.value = true
  try {
    const { data } = await $api.get(`/logistics/vehicles/${v.id}/maintenance/`)
    maintenance.value = data || []
  } catch { maintenance.value = [] }
}

function payload() {
  const f = form.value
  const body = { ...f }
  for (const key of ['insurance_expiry', 'inspection_expiry', 'last_service_at']) {
    if (!body[key]) body[key] = null
  }
  if (!body.year) body.year = null
  return body
}

async function saveVehicle() {
  if (!form.value.plate_number) {
    snack.value = { show: true, color: 'error', text: 'Plate number is required' }
    return
  }
  saving.value = true
  try {
    if (editing.value && form.value.id) {
      await $api.patch(`/logistics/vehicles/${form.value.id}/`, payload())
      snack.value = { show: true, color: 'success', text: 'Vehicle updated' }
    } else {
      await $api.post('/logistics/vehicles/', payload())
      snack.value = { show: true, color: 'success', text: 'Vehicle added' }
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

async function removeVehicle() {
  if (!form.value.id) return
  saving.value = true
  try {
    await $api.delete(`/logistics/vehicles/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Vehicle deleted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Delete failed' }
  } finally {
    saving.value = false
  }
}

async function changeStatus(v, status) {
  try {
    await L.setVehicleStatus(v.id, status)
    active.value = { ...v, status }
    snack.value = { show: true, color: 'success', text: `Status set to ${statusMeta(status).label}` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Status update failed' }
  }
}

function openMaintenance(v) {
  mForm.vehicle = v?.id || null
  mForm.kind = 'service'
  mForm.performed_at = today()
  mForm.odometer_km = v?.odometer_km || 0
  mForm.cost = 0
  mForm.vendor = ''
  mForm.next_due_at = ''
  mForm.description = ''
  maintenanceDialog.value = true
}

async function saveMaintenance() {
  if (!mForm.vehicle) {
    snack.value = { show: true, color: 'error', text: 'Select a vehicle' }
    return
  }
  saving.value = true
  try {
    const body = { ...mForm }
    if (!body.next_due_at) body.next_due_at = null
    await $api.post(`/logistics/vehicles/${mForm.vehicle}/maintenance/`, body)
    maintenanceDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Maintenance logged' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Save failed' }
  } finally {
    saving.value = false
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
.lg-search { flex: 1 1 280px; max-width: 420px; }
.lg-select { width: 170px; }
.lg-veh-card { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.lg-veh-card:hover { box-shadow: 0 8px 22px rgba(0, 0, 0, .09); transform: translateY(-1px); }
.lg-veh-icon { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; background: rgba(var(--v-theme-primary), .1); color: rgb(var(--v-theme-primary)); }
.lg-veh--available { background: rgba(16,185,129,.14); color: #0f766e; }
.lg-veh--in_use { background: rgba(59,130,246,.14); color: #1d4ed8; }
.lg-veh--maintenance { background: rgba(245,158,11,.16); color: #b45309; }
.lg-veh--retired { background: rgba(107,114,128,.16); color: #4b5563; }
.lg-veh-plate { font-size: 14px; font-weight: 800; letter-spacing: .2px; }
.lg-veh-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.lg-veh-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-veh-value { font-size: 13px; font-weight: 600; }
.lg-stat { border: 1px solid rgba(var(--v-border-color), .16); border-radius: 12px; padding: 10px 12px; }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
