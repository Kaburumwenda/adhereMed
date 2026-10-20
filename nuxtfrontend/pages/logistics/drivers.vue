<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-account-tie-hat-outline"
      eyebrow="IMS · LOGISTICS · DRIVERS"
      title="Drivers"
      subtitle="Licensed operators, duty status and performance across every warehouse run."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          Add driver
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
          placeholder="Search name, phone, licence…"
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
      </div>
    </v-card>

    <v-row dense>
      <v-col v-for="d in drivers" :key="d.id" cols="12" sm="6" lg="4" xl="3">
        <v-card rounded="xl" border class="lg-drv-card h-100" @click="openDetail(d)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <v-avatar size="42" :color="statusMeta(d.status).color" variant="tonal">
                <v-icon size="22">mdi-account-tie-hat-outline</v-icon>
              </v-avatar>
              <div>
                <div class="lg-drv-name">{{ d.full_name }}</div>
                <div class="text-caption text-medium-emphasis">{{ d.phone || 'No phone' }}</div>
              </div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="statusMeta(d.status).color" class="font-weight-bold">{{ statusMeta(d.status).label }}</v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="lg-drv-grid">
            <div>
              <div class="lg-drv-label">Licence</div>
              <div class="lg-drv-value">{{ d.license_number || '—' }}</div>
            </div>
            <div>
              <div class="lg-drv-label">Expiry</div>
              <div class="lg-drv-value" :class="licenseTone(d)">{{ d.license_expiry || '—' }}</div>
            </div>
            <div>
              <div class="lg-drv-label">Trips</div>
              <div class="lg-drv-value">{{ d.total_trips ?? 0 }}</div>
            </div>
            <div>
              <div class="lg-drv-label">Rating</div>
              <div class="lg-drv-value">{{ Number(d.rating || 0).toFixed(1) }} ★</div>
            </div>
          </div>

          <div class="d-flex flex-wrap ga-1 mt-3">
            <v-chip v-if="d.assigned_vehicle_plate" size="x-small" variant="tonal" color="blue">
              <v-icon start size="11">mdi-truck-outline</v-icon>{{ d.assigned_vehicle_plate }}
            </v-chip>
            <v-chip v-if="d.home_branch_name" size="x-small" variant="tonal" color="primary">{{ d.home_branch_name }}</v-chip>
            <v-chip v-if="!d.license_valid" size="x-small" variant="tonal" color="error">Licence expired</v-chip>
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!drivers.length" cols="12">
        <v-card rounded="xl" border>
          <div class="lg-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-account-tie-hat-outline</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No drivers yet</div>
            <div class="text-caption text-medium-emphasis">Add drivers to assign them to shipments.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">Add driver</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- form -->
    <v-dialog v-model="formDialog" max-width="760" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? `Edit ${form.full_name}` : 'Add driver'"
          subtitle="Licensed operator details"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6"><v-text-field v-model="form.full_name" label="Full name *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.phone" label="Phone" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.email" label="Email" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.national_id" label="National ID" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.license_number" label="Licence number" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.license_class" label="Licence class" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.license_expiry" type="date" label="Licence expiry" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.status" :items="statusOptions" item-title="label" item-value="value" label="Status" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.assigned_vehicle" :items="vehicles" item-title="plate_number" item-value="id" label="Assigned vehicle" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.home_branch" :items="branches" item-title="name" item-value="id" label="Home warehouse" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.medical_check_expiry" type="date" label="Medical check expiry" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.rating" type="number" step="0.1" min="0" max="5" label="Rating" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model.number="form.total_trips" type="number" label="Total trips" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="removeDriver">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveDriver">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- detail -->
    <v-dialog v-model="detailDialog" max-width="640">
      <v-card v-if="active" rounded="xl">
        <BrandDialogHeader
          icon="mdi-account-tie-hat-outline"
          :title="active.full_name"
          :subtitle="statusMeta(active.status).label"
          @close="detailDialog = false"
        >
          <template #actions>
            <v-btn icon="mdi-pencil" size="small" variant="text" class="lg-hero-iconbtn" title="Edit driver" @click="editDriver(active)" />
          </template>
        </BrandDialogHeader>
        <v-card-text>
          <div class="lg-kv"><span>Phone</span><strong>{{ active.phone || '—' }}</strong></div>
          <div class="lg-kv"><span>Email</span><strong>{{ active.email || '—' }}</strong></div>
          <div class="lg-kv"><span>Licence</span><strong>{{ active.license_number || '—' }} · {{ active.license_class || '—' }}</strong></div>
          <div class="lg-kv"><span>Licence expiry</span><strong>{{ active.license_expiry || '—' }}</strong></div>
          <div class="lg-kv"><span>Vehicle</span><strong>{{ active.assigned_vehicle_plate || '—' }}</strong></div>
          <div class="lg-kv"><span>Total trips</span><strong>{{ active.total_trips ?? 0 }}</strong></div>
          <div class="lg-kv"><span>Distance</span><strong>{{ Number(active.total_distance_km || 0).toLocaleString() }} km</strong></div>

          <div class="text-subtitle-2 font-weight-bold mt-4 mb-2">Duty status</div>
          <div class="d-flex flex-wrap ga-2">
            <v-btn
              v-for="s in statusOptions"
              :key="s.value"
              size="small" rounded="lg" class="text-none"
              :variant="active.status === s.value ? 'flat' : 'tonal'"
              :color="statusMeta(s.value).color"
              @click="changeStatus(active, s.value)"
            >{{ s.label }}</v-btn>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { DRIVER_STATUS_META, useLogistics } from '~/composables/useLogistics'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const L = useLogistics()

const loading = ref(false)
const saving = ref(false)
const drivers = ref([])
const stats = ref({})
const branches = ref([])
const vehicles = ref([])
const search = ref('')
const statusFilter = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const detailDialog = ref(false)
const editing = ref(false)
const active = ref(null)
const form = ref(blankForm())

const statusOptions = Object.entries(DRIVER_STATUS_META).map(([value, m]) => ({ value, label: m.label, color: m.color }))

const facts = computed(() => [
  { value: stats.value.total ?? 0, label: 'drivers' },
  { value: stats.value.available ?? 0, label: 'available' },
  { value: stats.value.on_trip ?? 0, label: 'on trip' },
  { value: stats.value.off_duty ?? 0, label: 'off duty' },
])

const kpis = computed(() => [
  { title: 'Total drivers', value: stats.value.total ?? 0, sub: 'on the roster', icon: 'mdi-account-group-outline', color: 'primary' },
  { title: 'Available', value: stats.value.available ?? 0, sub: 'ready to dispatch', icon: 'mdi-account-check-outline', color: 'success' },
  { title: 'On trip', value: stats.value.on_trip ?? 0, sub: 'currently driving', icon: 'mdi-truck-fast-outline', color: 'blue' },
  { title: 'Off duty', value: stats.value.off_duty ?? 0, sub: 'not scheduled', icon: 'mdi-account-clock-outline', color: 'grey' },
  { title: 'Licences expiring', value: stats.value.license_expiring ?? 0, sub: 'within 30 days', icon: 'mdi-card-account-details-outline', color: 'amber' },
  { title: 'Total trips', value: stats.value.total_trips ?? 0, sub: 'all time', icon: 'mdi-road-variant', color: 'teal' },
])

function statusMeta(s) {
  return DRIVER_STATUS_META[s] || { label: s, color: 'grey' }
}

function licenseTone(d) {
  if (!d.license_expiry) return ''
  const t = new Date(d.license_expiry).getTime()
  if (Number.isNaN(t)) return ''
  if (t < Date.now()) return 'text-error font-weight-bold'
  if (t - Date.now() < 30 * 24 * 3600 * 1000) return 'text-amber-darken-2 font-weight-medium'
  return ''
}

function blankForm() {
  return {
    full_name: '', phone: '', email: '', national_id: '',
    license_number: '', license_class: '', license_expiry: '', medical_check_expiry: '',
    status: 'available', home_branch: null, assigned_vehicle: null,
    rating: 0, total_trips: 0, is_active: true, notes: '',
  }
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: 'full_name' }
    if (search.value) params.search = search.value
    if (statusFilter.value) params.status = statusFilter.value
    const [list, st] = await Promise.all([L.drivers(params), L.driverStats()])
    drivers.value = list.data?.results || list.data || []
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load drivers' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const [b, v] = await Promise.all([
      $api.get(branchesApi.value, { params: { page_size: 200 } }),
      $api.get('/logistics/vehicles/', { params: { page_size: 300, is_active: true } }),
    ])
    branches.value = b.data?.results || b.data || []
    vehicles.value = v.data?.results || v.data || []
  } catch { /* optional */ }
}

function openCreate() {
  editing.value = false
  form.value = blankForm()
  formDialog.value = true
}

function editDriver(d) {
  editing.value = true
  form.value = { ...blankForm(), ...d }
  detailDialog.value = false
  formDialog.value = true
}

function openDetail(d) {
  active.value = d
  detailDialog.value = true
}

function payload() {
  const f = form.value
  const body = { ...f }
  for (const key of ['license_expiry', 'medical_check_expiry']) {
    if (!body[key]) body[key] = null
  }
  return body
}

async function saveDriver() {
  if (!form.value.full_name) {
    snack.value = { show: true, color: 'error', text: 'Full name is required' }
    return
  }
  saving.value = true
  try {
    if (editing.value && form.value.id) {
      await $api.patch(`/logistics/drivers/${form.value.id}/`, payload())
      snack.value = { show: true, color: 'success', text: 'Driver updated' }
    } else {
      await $api.post('/logistics/drivers/', payload())
      snack.value = { show: true, color: 'success', text: 'Driver added' }
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

async function removeDriver() {
  if (!form.value.id) return
  saving.value = true
  try {
    await $api.delete(`/logistics/drivers/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Driver deleted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Delete failed' }
  } finally {
    saving.value = false
  }
}

async function changeStatus(d, status) {
  try {
    await L.setDriverStatus(d.id, status)
    active.value = { ...d, status }
    snack.value = { show: true, color: 'success', text: `Status set to ${statusMeta(status).label}` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Status update failed' }
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
.lg-drv-card { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.lg-drv-card:hover { box-shadow: 0 8px 22px rgba(0,0,0,.09); transform: translateY(-1px); }
.lg-drv-name { font-size: 14px; font-weight: 800; }
.lg-drv-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.lg-drv-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-drv-value { font-size: 13px; font-weight: 600; }
.lg-kv { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 5px 0; font-size: 13px; }
.lg-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
