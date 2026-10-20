<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-cog-outline"
      eyebrow="IMS · LOGISTICS · ZONES & RATES"
      title="Delivery Zones & Rates"
      subtitle="Define geographic zones, base fees, per-kilometre charges and promised delivery windows."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          Add zone
        </v-btn>
      </template>
    </LogiHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="3">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense>
      <v-col v-for="z in zones" :key="z.id" cols="12" sm="6" lg="4" xl="3">
        <v-card rounded="xl" border class="lg-zone-card h-100" @click="editZone(z)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <div class="lg-zone-icon">
                <v-icon size="20">mdi-map-marker-radius</v-icon>
              </div>
              <div>
                <div class="lg-zone-name">{{ z.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ z.code || titleCase(z.zone_type) }}</div>
              </div>
            </div>
            <v-chip size="x-small" :color="z.is_active ? 'success' : 'grey'" variant="tonal" class="font-weight-bold">
              {{ z.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="lg-zone-grid">
            <div>
              <div class="lg-zone-label">Base fee</div>
              <div class="lg-zone-value">{{ formatMoney(z.base_fee) }}</div>
            </div>
            <div>
              <div class="lg-zone-label">Per km</div>
              <div class="lg-zone-value">{{ formatMoney(z.per_km_fee) }}</div>
            </div>
            <div>
              <div class="lg-zone-label">Free above</div>
              <div class="lg-zone-value">{{ formatMoney(z.free_above) }}</div>
            </div>
            <div>
              <div class="lg-zone-label">ETA</div>
              <div class="lg-zone-value">{{ z.eta_hours }}h</div>
            </div>
          </div>

          <div v-if="z.areas && z.areas.length" class="d-flex flex-wrap ga-1 mt-3">
            <v-chip v-for="a in z.areas.slice(0, 5)" :key="a" size="x-small" variant="tonal" color="primary">{{ a }}</v-chip>
            <v-chip v-if="z.areas.length > 5" size="x-small" variant="tonal" color="grey">+{{ z.areas.length - 5 }}</v-chip>
          </div>
          <div v-if="z.branch_name" class="text-caption text-medium-emphasis mt-2">
            <v-icon size="13" class="mr-1">mdi-warehouse</v-icon>{{ z.branch_name }}
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!zones.length" cols="12">
        <v-card rounded="xl" border>
          <div class="lg-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-map-marker-radius</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No delivery zones</div>
            <div class="text-caption text-medium-emphasis">Create a zone to standardise delivery pricing.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">Add zone</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="formDialog" max-width="680" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? `Edit ${form.name}` : 'Add delivery zone'"
          subtitle="Geography, fees and promised delivery window"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="8"><v-text-field v-model="form.name" label="Zone name *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.code" label="Code" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.zone_type" :items="zoneTypes" item-title="label" item-value="value" label="Zone type" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.branch" :items="branches" item-title="name" item-value="id" label="Warehouse" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.base_fee" type="number" step="0.01" label="Base fee" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.per_km_fee" type="number" step="0.01" label="Per km" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.free_above" type="number" step="0.01" label="Free above" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.eta_hours" type="number" label="ETA (hours)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12">
              <v-combobox
                v-model="form.areas"
                label="Areas / towns covered"
                variant="outlined"
                density="comfortable"
                multiple
                chips
                closable-chips
                hint="Type an area and press Enter"
                persistent-hint
              />
            </v-col>
            <v-col cols="12"><v-switch v-model="form.is_active" color="success" density="compact" hide-details label="Active" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="removeZone">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveZone">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useLogistics } from '~/composables/useLogistics'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const L = useLogistics()

const loading = ref(false)
const saving = ref(false)
const zones = ref([])
const branches = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const editing = ref(false)
const form = ref(blankForm())

const zoneTypes = [
  { value: 'local', label: 'Local' },
  { value: 'regional', label: 'Regional' },
  { value: 'national', label: 'National' },
  { value: 'international', label: 'International' },
]

const facts = computed(() => [
  { value: zones.value.length, label: 'zones' },
  { value: zones.value.filter((z) => z.is_active).length, label: 'active' },
  { value: averageEta.value, label: 'avg ETA' },
  { value: formatMoney(averageBase.value), label: 'avg base fee' },
])

const kpis = computed(() => [
  { title: 'Zones', value: zones.value.length, sub: 'all zones', icon: 'mdi-map-marker-radius', color: 'primary' },
  { title: 'Active', value: zones.value.filter((z) => z.is_active).length, sub: 'priced and live', icon: 'mdi-check-circle-outline', color: 'success' },
  { title: 'Avg ETA', value: averageEta.value, sub: 'delivery window', icon: 'mdi-clock-outline', color: 'teal' },
  { title: 'Avg base fee', value: formatMoney(averageBase.value), sub: 'per delivery', icon: 'mdi-cash', color: 'deep-purple' },
])

const averageEta = computed(() => {
  if (!zones.value.length) return '—'
  const sum = zones.value.reduce((a, z) => a + (Number(z.eta_hours) || 0), 0)
  return `${Math.round(sum / zones.value.length)}h`
})

const averageBase = computed(() => {
  if (!zones.value.length) return 0
  const sum = zones.value.reduce((a, z) => a + (Number(z.base_fee) || 0), 0)
  return sum / zones.value.length
})

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function blankForm() {
  return {
    name: '', code: '', zone_type: 'local', branch: null, areas: [],
    base_fee: 0, per_km_fee: 0, free_above: 0, eta_hours: 24, is_active: true,
  }
}

async function load() {
  loading.value = true
  try {
    const { data } = await L.zones({ page_size: 300, ordering: 'name' })
    zones.value = data?.results || data || []
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load zones' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const { data } = await $api.get(branchesApi.value, { params: { page_size: 200 } })
    branches.value = data?.results || data || []
  } catch { /* optional */ }
}

function openCreate() {
  editing.value = false
  form.value = blankForm()
  formDialog.value = true
}

function editZone(z) {
  editing.value = true
  form.value = { ...blankForm(), ...z, areas: Array.isArray(z.areas) ? [...z.areas] : [] }
  formDialog.value = true
}

async function saveZone() {
  if (!form.value.name) {
    snack.value = { show: true, color: 'error', text: 'Zone name is required' }
    return
  }
  saving.value = true
  try {
    const body = { ...form.value }
    if (!body.branch) body.branch = null
    if (editing.value && form.value.id) {
      await $api.patch(`/logistics/zones/${form.value.id}/`, body)
      snack.value = { show: true, color: 'success', text: 'Zone updated' }
    } else {
      await $api.post('/logistics/zones/', body)
      snack.value = { show: true, color: 'success', text: 'Zone created' }
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

async function removeZone() {
  if (!form.value.id) return
  saving.value = true
  try {
    await $api.delete(`/logistics/zones/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Zone deleted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Delete failed' }
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
.lg-zone-card { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.lg-zone-card:hover { box-shadow: 0 8px 22px rgba(0,0,0,.09); transform: translateY(-1px); }
.lg-zone-icon { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; background: rgba(var(--v-theme-primary), .1); color: rgb(var(--v-theme-primary)); }
.lg-zone-name { font-size: 14px; font-weight: 800; }
.lg-zone-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.lg-zone-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-zone-value { font-size: 13px; font-weight: 600; }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
