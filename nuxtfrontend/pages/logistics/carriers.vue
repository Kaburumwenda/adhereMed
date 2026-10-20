<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-handshake-outline"
      eyebrow="IMS · LOGISTICS · CARRIERS"
      title="Carriers & 3PL Partners"
      subtitle="Third-party hauliers, couriers and express partners with rates, service levels and performance."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          Add carrier
        </v-btn>
      </template>
    </LogiHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="3">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search name, contact, service area…"
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
        <v-select v-model="levelFilter" :items="levelOptions" item-title="label" item-value="value" label="Service level" density="compact" variant="outlined" rounded="lg" hide-details clearable class="lg-select" @update:model-value="load" />
      </div>
    </v-card>

    <v-row dense>
      <v-col v-for="c in carriers" :key="c.id" cols="12" sm="6" lg="4">
        <v-card rounded="xl" border class="lg-car-card h-100" @click="editCarrier(c)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <v-avatar size="42" color="purple" variant="tonal">
                <v-icon size="22">mdi-handshake-outline</v-icon>
              </v-avatar>
              <div>
                <div class="lg-car-name">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ c.code || 'No code' }}</div>
              </div>
            </div>
            <v-chip size="x-small" :color="c.is_active ? 'success' : 'grey'" variant="tonal" class="font-weight-bold">
              {{ c.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="lg-car-grid">
            <div>
              <div class="lg-car-label">Service level</div>
              <div class="lg-car-value">{{ titleCase(c.service_level) }}</div>
            </div>
            <div>
              <div class="lg-car-label">Rate / km</div>
              <div class="lg-car-value">{{ formatMoney(c.rate_per_km) }}</div>
            </div>
            <div>
              <div class="lg-car-label">Flat rate</div>
              <div class="lg-car-value">{{ formatMoney(c.flat_rate) }}</div>
            </div>
            <div>
              <div class="lg-car-label">On-time</div>
              <div class="lg-car-value">{{ Number(c.on_time_rate || 0).toFixed(0) }}%</div>
            </div>
          </div>

          <div class="d-flex align-center justify-space-between mt-3">
            <div class="text-caption text-medium-emphasis">
              <v-icon size="13" class="mr-1">mdi-phone-outline</v-icon>{{ c.phone || '—' }}
            </div>
            <div class="lg-car-rating">
              <v-icon size="14" color="amber-darken-2">mdi-star</v-icon>
              {{ Number(c.rating || 0).toFixed(1) }}
            </div>
          </div>
          <div v-if="c.service_area" class="text-caption text-medium-emphasis mt-1">
            <v-icon size="13" class="mr-1">mdi-map-marker-radius</v-icon>{{ c.service_area }}
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!carriers.length" cols="12">
        <v-card rounded="xl" border>
          <div class="lg-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-handshake-outline</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No carriers registered</div>
            <div class="text-caption text-medium-emphasis">Add a carrier to outsource transport.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">Add carrier</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="formDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? `Edit ${form.name}` : 'Add carrier'"
          subtitle="Third-party transport partner"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="8"><v-text-field v-model="form.name" label="Carrier name *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="form.code" label="Code" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.contact_person" label="Contact person" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.phone" label="Phone" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.email" label="Email" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.service_area" label="Service area" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.address" label="Address" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.service_level" :items="levelOptions" item-title="label" item-value="value" label="Service level" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.rate_per_km" type="number" step="0.01" label="Rate per km" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.flat_rate" type="number" step="0.01" label="Flat rate" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.rating" type="number" step="0.1" min="0" max="5" label="Rating" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.on_time_rate" type="number" step="0.1" min="0" max="100" label="On-time %" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model="form.currency" label="Currency" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-switch v-model="form.is_active" color="success" density="compact" hide-details label="Active" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="removeCarrier">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="purple" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveCarrier">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const L = useLogistics()

const loading = ref(false)
const saving = ref(false)
const carriers = ref([])
const stats = ref({})
const search = ref('')
const levelFilter = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const editing = ref(false)
const form = ref(blankForm())

const levelOptions = [
  { value: 'economy', label: 'Economy' },
  { value: 'standard', label: 'Standard' },
  { value: 'express', label: 'Express' },
  { value: 'same_day', label: 'Same day' },
]

const facts = computed(() => [
  { value: stats.value.total ?? 0, label: 'carriers' },
  { value: stats.value.active ?? 0, label: 'active' },
  { value: `${Number(stats.value.avg_rating || 0).toFixed(1)}`, label: 'avg rating' },
  { value: `${Number(stats.value.avg_on_time_rate || 0).toFixed(0)}%`, label: 'avg on-time' },
])

const kpis = computed(() => [
  { title: 'Total carriers', value: stats.value.total ?? 0, sub: 'in the network', icon: 'mdi-handshake-outline', color: 'purple' },
  { title: 'Active', value: stats.value.active ?? 0, sub: 'available for dispatch', icon: 'mdi-check-circle-outline', color: 'success' },
  { title: 'Avg rating', value: Number(stats.value.avg_rating || 0).toFixed(1), sub: 'out of 5', icon: 'mdi-star-outline', color: 'amber' },
  { title: 'Avg on-time', value: `${Number(stats.value.avg_on_time_rate || 0).toFixed(0)}%`, sub: 'delivery performance', icon: 'mdi-clock-check-outline', color: 'teal' },
])

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function blankForm() {
  return {
    name: '', code: '', contact_person: '', phone: '', email: '', address: '',
    service_area: '', service_level: 'standard', rate_per_km: 0, flat_rate: 0,
    currency: 'KES', rating: 0, on_time_rate: 0, is_active: true, notes: '',
  }
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 300, ordering: 'name' }
    if (search.value) params.search = search.value
    if (levelFilter.value) params.service_level = levelFilter.value
    const [list, st] = await Promise.all([L.carriers(params), L.carrierStats()])
    carriers.value = list.data?.results || list.data || []
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load carriers' }
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editing.value = false
  form.value = blankForm()
  formDialog.value = true
}

function editCarrier(c) {
  editing.value = true
  form.value = { ...blankForm(), ...c }
  formDialog.value = true
}

async function saveCarrier() {
  if (!form.value.name) {
    snack.value = { show: true, color: 'error', text: 'Carrier name is required' }
    return
  }
  saving.value = true
  try {
    if (editing.value && form.value.id) {
      await $api.patch(`/logistics/carriers/${form.value.id}/`, form.value)
      snack.value = { show: true, color: 'success', text: 'Carrier updated' }
    } else {
      await $api.post('/logistics/carriers/', form.value)
      snack.value = { show: true, color: 'success', text: 'Carrier added' }
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

async function removeCarrier() {
  if (!form.value.id) return
  saving.value = true
  try {
    await $api.delete(`/logistics/carriers/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Carrier deleted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Delete failed' }
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.lg-search { flex: 1 1 280px; max-width: 420px; }
.lg-select { width: 190px; }
.lg-car-card { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.lg-car-card:hover { box-shadow: 0 8px 22px rgba(0,0,0,.09); transform: translateY(-1px); }
.lg-car-name { font-size: 14px; font-weight: 800; }
.lg-car-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.lg-car-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-car-value { font-size: 13px; font-weight: 600; }
.lg-car-rating { display: inline-flex; align-items: center; gap: 3px; font-size: 13px; font-weight: 700; }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
