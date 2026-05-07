<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="7">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="teal-darken-2" size="32">mdi-pill</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Medication Catalog</div>
              <div class="text-body-2" style="opacity:0.9">
                Master list of medications used across the pharmacy.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="5" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn variant="flat" color="white" prepend-icon="mdi-refresh" class="text-teal-darken-3"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
          <v-btn color="white" variant="flat" class="text-teal-darken-3"
                 prepend-icon="mdi-plus" @click="openCreate">New medication</v-btn>
        </v-col>
      </v-row>

      <v-row class="mt-4" dense>
        <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="40" class="mr-3">
                <v-icon color="white" size="22">{{ k.icon }}</v-icon>
              </v-avatar>
              <div class="min-width-0">
                <div class="text-caption text-medium-emphasis text-uppercase">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Filters -->
    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name, brand, abbreviation…"
                        density="comfortable" variant="solo-filled" flat hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="categoryFilter" :items="categoryItems" label="Category"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dosageFilter" :items="dosageItems" label="Dosage form"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="12" md="2" class="text-right">
          <v-chip color="primary" variant="tonal">{{ filtered.length }} shown</v-chip>
        </v-col>
      </v-row>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
      <v-data-table
        :headers="headers" :items="filtered" :loading="loading"
        density="comfortable" hover :items-per-page="25"
      >
        <template #item.generic_name="{ item }">
          <div class="font-weight-medium">{{ item.generic_name }}</div>
          <div v-if="item.brand_names?.length" class="text-caption text-medium-emphasis">
            {{ item.brand_names.slice(0, 3).join(', ') }}
          </div>
        </template>
        <template #item.category="{ item }">
          <v-chip size="x-small" color="teal" variant="tonal" class="text-capitalize">
            {{ (item.category || '').replace('_', ' ') }}
          </v-chip>
        </template>
        <template #item.dosage_form="{ item }">
          <span class="text-capitalize">{{ item.dosage_form }}</span>
        </template>
        <template #item.requires_prescription="{ item }">
          <v-chip v-if="item.requires_prescription" size="x-small" color="error" variant="tonal">Rx</v-chip>
          <v-chip v-else size="x-small" color="success" variant="tonal">OTC</v-chip>
        </template>
        <template #item.is_active="{ item }">
          <v-icon :color="item.is_active ? 'success' : 'grey'" size="18">
            {{ item.is_active ? 'mdi-check-circle' : 'mdi-pause-circle' }}
          </v-icon>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-pill" title="No medications yet"
                      message="Add your first medication to start building your catalog." />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create/Edit dialog -->
    <v-dialog v-model="formDialog" max-width="780" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-pill</v-icon>
          {{ form.id ? 'Edit medication' : 'New medication' }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.generic_name" label="Generic name *"
                            variant="outlined" density="comfortable" :error-messages="errors.generic_name" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.abbreviation" label="Abbreviation"
                            variant="outlined" density="comfortable" placeholder="PCM, AMOX, RHZE…" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.category" :items="categoryOptions" label="Category *"
                        variant="outlined" density="comfortable" :error-messages="errors.category" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.subcategory" label="Subcategory"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.dosage_form" :items="dosageOptions" label="Dosage form *"
                        variant="outlined" density="comfortable" :error-messages="errors.dosage_form" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.strength" label="Strength" placeholder="500mg, 10mg/5ml"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.unit" label="Unit" placeholder="tab, ml, vial"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.controlled_substance_class" label="Controlled-substance class"
                            placeholder="e.g. Schedule II" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-combobox v-model="form.brand_names" label="Brand names" multiple chips closable-chips
                          variant="outlined" density="comfortable" placeholder="Press enter after each" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="Description"
                          variant="outlined" density="comfortable" rows="2" auto-grow />
            </v-col>
            <v-col cols="12" md="6">
              <v-textarea v-model="form.side_effects" label="Side effects"
                          variant="outlined" density="comfortable" rows="2" auto-grow />
            </v-col>
            <v-col cols="12" md="6">
              <v-textarea v-model="form.contraindications" label="Contraindications"
                          variant="outlined" density="comfortable" rows="2" auto-grow />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="form.requires_prescription" label="Requires prescription" color="error"
                        density="comfortable" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="form.is_active" label="Active" color="success"
                        density="comfortable" hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">
            {{ form.id ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card v-if="deleteTarget" rounded="xl">
        <v-card-title>Delete medication?</v-card-title>
        <v-card-text>
          This will remove <strong>{{ deleteTarget.generic_name }}</strong> from the catalog.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const meds = ref([])

async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/medications/', { params: { page_size: 1000 } })
    meds.value = data?.results || data || []
  } catch { notify('Failed to load medications', 'error') }
  finally { loading.value = false }
}
onMounted(loadAll)

const categoryOptions = [
  'analgesic','antibiotic','antifungal','antiviral','antiparasitic','antimalarial',
  'antihypertensive','antidiabetic','antihistamine','antacid','cardiovascular',
  'respiratory','cns','hormone','vitamin','vaccine','dermatological','ophthalmic',
  'oncology','immunosuppressant','nsaid','other',
].map(v => ({ title: v.replace('_', ' '), value: v }))

const dosageOptions = [
  'tablet','capsule','syrup','injection','cream','ointment','drops','inhaler',
  'suppository','suspension','powder','gel','patch','lozenge','spray','solution','other',
].map(v => ({ title: v[0].toUpperCase() + v.slice(1), value: v }))

const categoryItems = computed(() => [{ title: 'All categories', value: 'all' }, ...categoryOptions])
const dosageItems = computed(() => [{ title: 'All forms', value: 'all' }, ...dosageOptions])

const search = ref('')
const categoryFilter = ref('all')
const dosageFilter = ref('all')

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return meds.value.filter(m => {
    if (categoryFilter.value !== 'all' && m.category !== categoryFilter.value) return false
    if (dosageFilter.value !== 'all' && m.dosage_form !== dosageFilter.value) return false
    if (!q) return true
    const hay = [m.generic_name, m.abbreviation, m.subcategory, m.strength,
                 ...(m.brand_names || [])].join(' ').toLowerCase()
    return hay.includes(q)
  })
})

const kpiTiles = computed(() => [
  { label: 'Total', value: meds.value.length, icon: 'mdi-pill', color: 'teal' },
  { label: 'Active', value: meds.value.filter(m => m.is_active).length, icon: 'mdi-check-circle', color: 'success' },
  { label: 'Prescription only', value: meds.value.filter(m => m.requires_prescription).length, icon: 'mdi-prescription', color: 'error' },
  { label: 'OTC', value: meds.value.filter(m => !m.requires_prescription).length, icon: 'mdi-cart-check', color: 'info' },
])

const headers = [
  { title: 'Name', key: 'generic_name' },
  { title: 'Category', key: 'category' },
  { title: 'Form', key: 'dosage_form' },
  { title: 'Strength', key: 'strength' },
  { title: 'Type', key: 'requires_prescription', sortable: false },
  { title: 'Active', key: 'is_active', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 120 },
]

// ── form
const formDialog = ref(false)
const form = reactive(blankForm())
const errors = reactive({})
function blankForm() {
  return { id: null, generic_name: '', abbreviation: '', brand_names: [],
    category: 'other', subcategory: '', dosage_form: 'tablet', strength: '', unit: '',
    description: '', requires_prescription: true, controlled_substance_class: '',
    side_effects: '', contraindications: '', is_active: true }
}
function openCreate() { Object.assign(form, blankForm()); clearErrors(); formDialog.value = true }
function openEdit(m) { Object.assign(form, blankForm(), m); clearErrors(); formDialog.value = true }
function clearErrors() { Object.keys(errors).forEach(k => delete errors[k]) }

async function save() {
  clearErrors()
  if (!form.generic_name) { errors.generic_name = 'Required'; return }
  if (!form.category) { errors.category = 'Required'; return }
  if (!form.dosage_form) { errors.dosage_form = 'Required'; return }
  saving.value = true
  try {
    const payload = { ...form }; delete payload.id
    if (form.id) await $api.put(`/medications/${form.id}/`, payload)
    else await $api.post('/medications/', payload)
    notify(form.id ? 'Medication updated' : 'Medication created')
    formDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Save failed', 'error') }
  finally { saving.value = false }
}

const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(m) { deleteTarget.value = m; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/medications/${deleteTarget.value.id}/`)
    notify('Deleted')
    deleteDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { saving.value = false }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #0f766e 0%, #14b8a6 50%, #06b6d4 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(20, 184, 166, 0.25);
}
.kpi {
  background: rgba(255, 255, 255, 0.97);
  color: rgba(0, 0, 0, 0.87);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.kpi:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.1); }
.kpi :deep(.text-h6) { color: rgba(0, 0, 0, 0.87) !important; }
.kpi :deep(.text-medium-emphasis) { color: rgba(0, 0, 0, 0.62) !important; }
</style>
