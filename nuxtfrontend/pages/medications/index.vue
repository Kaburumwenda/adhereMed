<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="teal-lighten-5" size="48" class="mr-3">
          <v-icon color="teal-darken-2" size="28">mdi-pill</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Medication Catalog</h1>
          <div class="text-body-2 text-medium-emphasis">Master list of medications used across the pharmacy</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="loadMeds">{{ $t('common.refresh') }}</v-btn>
      <!-- <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" disabled @click="openCreate">New medication</v-btn> -->
      <v-btn rounded="lg" color="success" variant="tonal" class="text-none"
                 prepend-icon="mdi-microsoft-excel" @click="navigateTo(`${excelBase}`)">Import / Export</v-btn>
      <v-btn rounded="lg" color="warning" variant="tonal" class="text-none"
                 prepend-icon="mdi-table-edit" @click="navigateTo(`${bulkBase}?mode=edit`)">Edit mode</v-btn>
      <v-btn rounded="lg" color="error" variant="tonal" class="text-none"
                 prepend-icon="mdi-trash-can" @click="navigateTo(`${bulkBase}?mode=delete`)">Delete mode</v-btn>
      <v-btn rounded="lg" color="teal-darken-1" variant="tonal" class="text-none"
                 prepend-icon="mdi-tag-multiple" :loading="brandUpdating"
                 @click="brandUpdateDialog = true">Update brand names</v-btn>
      <v-btn rounded="lg" color="error" variant="tonal" class="text-none"
                 prepend-icon="mdi-delete-sweep" @click="deleteAllDialog = true">Delete all</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

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
          <v-chip color="primary" variant="tonal">{{ totalCount }} total</v-chip>
        </v-col>
      </v-row>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
      <v-data-table-server
        :headers="headers" :items="meds" :loading="loading"
        :items-length="totalCount"
        density="comfortable" hover
        :items-per-page="itemsPerPage"
        :page="currentPage"
        @update:page="onPageChange"
        @update:items-per-page="onPerPageChange"
        @update:sort-by="onSortChange"
      >
        <template #item.row_num="{ index }">
          <span class="text-medium-emphasis text-caption">{{ (currentPage - 1) * itemsPerPage + index + 1 }}</span>
        </template>
        <template #item.brand_names="{ item }">
          <div class="font-weight-medium">
            {{ medDisplayName(item) }}
          </div>
        </template>
        <template #item.generic_name="{ item }">
          <div class="font-weight-medium">{{ item.generic_name }}</div>
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
          <v-chip v-if="item.requires_prescription" size="x-small" color="error" variant="tonal">{{ $t('medications.rx') }}</v-chip>
          <v-chip v-else size="x-small" color="success" variant="tonal">{{ $t('medications.otc') }}</v-chip>
        </template>
        <template #item.is_active="{ item }">
          <v-icon :color="item.is_active ? 'success' : 'grey'" size="18">
            {{ item.is_active ? 'mdi-check-circle' : 'mdi-pause-circle' }}
          </v-icon>
        </template>
        <template #item.created_at="{ item }">
          <span class="text-caption text-medium-emphasis">{{ item.created_at ? new Date(item.created_at).toLocaleDateString() : '-' }}</span>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-pill" title="No medications yet"
                      message="Add your first medication to start building your catalog." />
        </template>
      </v-data-table-server>
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
            <v-col cols="12">
              <v-text-field v-model="form.strength" label="Strength" placeholder="500mg, 10mg/5ml"
                            variant="outlined" density="comfortable" />
              <div class="d-flex flex-wrap ga-1 mt-2">
                <v-chip v-for="s in strengthSuggestions" :key="s"
                        size="x-small" variant="outlined" color="primary" label
                        @click="form.strength = s">
                  {{ s }}
                </v-chip>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <v-autocomplete
                v-model="form.unit"
                :items="units"
                item-title="name"
                item-value="name"
                label="Unit of Measure"
                placeholder="tab, ml, vial…"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                clearable
                prepend-inner-icon="mdi-ruler-square-compass"
              >
                <template #append-item>
                  <v-divider />
                  <v-list-item @click="unitDialog = true" class="bg-blue-lighten-5" base-color="primary">
                    <template #prepend>
                      <v-icon size="18" color="primary">mdi-plus-circle-outline</v-icon>
                    </template>
                    <v-list-item-title class="font-weight-medium text-primary">Manage Units</v-list-item-title>
                  </v-list-item>
                </template>
              </v-autocomplete>
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
          <v-btn variant="text" @click="formDialog = false">{{ $t('common.cancel') }}</v-btn>
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
          <v-btn variant="text" @click="deleteDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">{{ $t('common.delete') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete All warning dialog -->
    <v-dialog v-model="deleteAllDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="error" variant="tonal" size="44">
              <v-icon>mdi-alert</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Delete entire medication catalog?</v-card-title>
        </v-card-item>
        <v-card-text>
          <v-alert type="warning" variant="tonal" rounded="lg" class="mb-3">
            <strong>This action cannot be undone.</strong> All {{ totalCount }} medications will be permanently
            removed from the catalog. Drug interactions referencing these medications will also be deleted.
          </v-alert>
          <div class="text-body-2 text-medium-emphasis">
            To confirm, type <strong>DELETE</strong> in the field below:
          </div>
          <v-text-field v-model="deleteAllConfirm" class="mt-2" variant="outlined" density="comfortable"
                        placeholder="Type DELETE to confirm" hide-details />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="deleteAllDialog = false; deleteAllConfirm = ''">Cancel</v-btn>
          <v-btn color="error" variant="flat" prepend-icon="mdi-delete-sweep"
                 :disabled="deleteAllConfirm !== 'DELETE'" :loading="deletingAll"
                 @click="doDeleteAll">
            Delete all medications
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Update Brand Names dialog -->
    <v-dialog v-model="brandUpdateDialog" max-width="540">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="teal" variant="tonal" size="44">
              <v-icon>mdi-tag-multiple</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Update brand names?</v-card-title>
        </v-card-item>
        <v-card-text>
          <p class="text-body-2 mb-3">
            This will scan all medications and fill in known brand names from the built-in
            dictionary (350+ active ingredients mapped to Kenyan market brands).
          </p>
          <v-alert type="info" variant="tonal" rounded="lg" class="mb-3" density="comfortable">
            By default only medications with <strong>empty brand names</strong> are updated.
            Enable "Overwrite" to replace existing brand names too.
          </v-alert>
          <v-switch v-model="brandUpdateForce" label="Overwrite existing brand names" color="warning" density="comfortable" hide-details />
          <v-switch v-if="false" v-model="brandUpdateDryRun" label="Dry run (preview only)" density="comfortable" hide-details />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="brandUpdateDialog = false">Cancel</v-btn>
          <v-btn color="teal-darken-1" variant="flat" prepend-icon="mdi-tag-multiple"
                 :loading="brandUpdating" @click="doUpdateBrandNames">
            {{ brandUpdateDryRun ? 'Preview' : 'Update brand names' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Brand update result dialog -->
    <v-dialog v-model="brandResultDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar :color="brandResultColor" variant="tonal" size="44">
              <v-icon>{{ brandResultColor === 'success' ? 'mdi-check-circle' : 'mdi-tag-check' }}</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Brand name update complete</v-card-title>
        </v-card-item>
        <v-card-text v-if="brandUpdateResult">
          <v-list density="comfortable">
            <v-list-item prepend-icon="mdi-pill" title="Total scanned" :subtitle="String(brandUpdateResult.total)" />
            <v-list-item prepend-icon="mdi-tag-check" title="Updated" :subtitle="String(brandUpdateResult.updated)" />
            <v-list-item prepend-icon="mdi-skip-next" title="Skipped (no generic name)" :subtitle="String(brandUpdateResult.skipped)" />
            <v-list-item prepend-icon="mdi-equal" title="Unchanged (already set)" :subtitle="String(brandUpdateResult.unchanged)" />
          </v-list>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" @click="brandResultDialog = false; loadMeds()">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Manage Units dialog -->
    <v-dialog v-model="unitDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-ruler-square-compass</v-icon>
          Manage Units of Measure
        </v-card-title>
        <v-card-subtitle>Create a new unit (e.g. tablets, capsules, ml, mg)</v-card-subtitle>
        <v-card-text>
          <v-text-field
            v-model="unitForm.name"
            label="Unit Name *"
            placeholder="e.g. tablets, capsules, ml"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            class="mb-1"
          />
          <!-- Quick-pick suggestion chips -->
          <div class="d-flex flex-wrap ga-1 mb-3">
            <v-chip
              v-for="s in unitSuggestions"
              :key="s"
              size="x-small"
              variant="outlined"
              color="primary"
              label
              @click="pickUnitSuggestion(s)"
            >
              {{ s }}
            </v-chip>
          </div>
          <v-text-field
            v-model="unitForm.abbreviation"
            label="Abbreviation"
            placeholder="e.g. tab, cap, ml"
            variant="outlined"
            density="comfortable"
            rounded="lg"
          />
          <!-- List existing units -->
          <div class="text-caption text-medium-emphasis mb-1 mt-3">Existing Units</div>
          <v-chip-group column>
            <v-chip v-for="u in units" :key="u.id" size="small" variant="tonal" label>
              {{ u.name }}<span v-if="u.abbreviation" class="text-medium-emphasis ms-1">({{ u.abbreviation }})</span>
            </v-chip>
          </v-chip-group>
        </v-card-text>
        <v-card-actions class="pb-4 px-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="closeUnitDialog">Cancel</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-check"
            :loading="unitSaving"
            :disabled="!unitForm.name.trim()"
            @click="saveUnit"
          >
            Create Unit
          </v-btn>
        </v-card-actions>
        <v-snackbar
          v-model="unitSnackbar.show"
          :color="unitSnackbar.color"
          location="top right"
          timeout="3000"
        >
          {{ unitSnackbar.text }}
        </v-snackbar>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, computed, onMounted, watch } from 'vue'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()

// Detect namespace from current route for bulk page navigation
const route = useRoute()
const bulkBase = computed(() => {
  const p = route.path
  if (p.includes('/ims/')) return '/ims/medications/bulk'
  if (p.includes('/clinics/')) return '/clinics/catalog/medications/bulk'
  return '/pharmacy/medications/bulk'
})
const excelBase = computed(() => {
  const p = route.path
  if (p.includes('/ims/')) return '/ims/medications/excel'
  if (p.includes('/clinics/')) return '/clinics/catalog/medications/excel'
  return '/pharmacy/medications/excel'
})

const loading = ref(false)
const saving = ref(false)
const meds = ref([])

// ── Units of Measure (loaded from inventory API)
const units = ref([])
const unitDialog = ref(false)
const unitSaving = ref(false)
const unitForm = reactive({ name: '', abbreviation: '' })
const unitSnackbar = reactive({ show: false, text: '', color: 'success' })
const unitSuggestions = [
  'tablets', 'capsules', 'ml', 'mg', 'g', 'vials', 'ampoules',
  'sachets', 'puffs', 'drops', 'units', 'pieces', 'patches', 'lozenges',
]

function pickUnitSuggestion(name) {
  unitForm.name = name
  const abbrevs = { tablets: 'tab', capsules: 'cap', pieces: 'pc', drops: 'gtt', lozenges: 'loz', puffs: 'pf', units: 'U' }
  unitForm.abbreviation = abbrevs[name] || ''
}

function closeUnitDialog() {
  unitDialog.value = false
  unitForm.name = ''
  unitForm.abbreviation = ''
}

async function saveUnit() {
  const name = unitForm.name.trim()
  if (!name) return
  unitSaving.value = true
  try {
    const { data } = await $api.post('/inventory/units/', {
      name,
      abbreviation: unitForm.abbreviation.trim(),
    })
    units.value.push(data)
    units.value.sort((a, b) => a.name.localeCompare(b.name))
    form.unit = data.name
    unitSnackbar.show = true
    unitSnackbar.text = `Unit "${data.name}" created`
    unitSnackbar.color = 'success'
    closeUnitDialog()
  } catch (e) {
    const msg = e?.response?.data?.name?.[0] || e?.response?.data?.detail || 'Failed to create unit'
    unitSnackbar.show = true
    unitSnackbar.text = msg
    unitSnackbar.color = 'error'
  } finally {
    unitSaving.value = false
  }
}

async function loadUnits() {
  try {
    const { data } = await $api.get('/inventory/units/', { params: { page_size: 1000 } })
    units.value = data?.results ?? data ?? []
  } catch { /* non-critical */ }
}
const totalCount = ref(0)
const currentPage = ref(1)
const itemsPerPage = ref(100)
const sortBy = ref([{ key: 'created_at', order: 'desc' }])

let searchDebounceTimer = null

async function loadMeds() {
  loading.value = true
  try {
    const params = {
      page_size: itemsPerPage.value,
      page: currentPage.value,
    }
    if (search.value?.trim()) params.search = search.value.trim()
    if (categoryFilter.value && categoryFilter.value !== 'all') params.category = categoryFilter.value
    if (dosageFilter.value && dosageFilter.value !== 'all') params.dosage_form = dosageFilter.value
    if (sortBy.value?.length) {
      const s = sortBy.value[0]
      params.ordering = s.order === 'desc' ? `-${s.key}` : s.key
    } else {
      params.ordering = '-created_at'
    }
    const { data } = await $api.get('/medications/', { params })
    meds.value = data?.results || data || []
    totalCount.value = data?.count ?? meds.value.length
  } catch { notify('Failed to load medications', 'error') }
  finally { loading.value = false }
}

function onPageChange(page) { currentPage.value = page; loadMeds() }
function onPerPageChange(size) { itemsPerPage.value = size; currentPage.value = 1; loadMeds() }
function onSortChange(sort) { sortBy.value = sort; loadMeds() }

function debouncedSearch() {
  clearTimeout(searchDebounceTimer)
  searchDebounceTimer = setTimeout(() => { currentPage.value = 1; loadMeds() }, 400)
}

onMounted(() => {
  loadMeds()
  loadUnits()
})

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

const strengthSuggestions = [
  '1mg', '2mg', '5mg', '10mg', '15mg', '20mg', '25mg', '30mg', '40mg',
  '50mg', '75mg', '100mg', '150mg', '200mg', '250mg', '300mg', '400mg', '500mg',
  '600mg', '750mg', '1000mg', '1g', '2g', '5g',
  '0.5ml', '1ml', '2.5ml', '5ml', '10ml', '15ml', '20ml', '30ml', '50ml', '100ml',
  '100IU', '500IU', '1000IU',
  '5mg/5ml', '10mg/5ml', '125mg/5ml', '200mg/5ml', '250mg/5ml',
  '100mcg', '200mcg', '250mcg', '500mcg',
  '50mg/ml', '100mg/ml',
  '20mg/2ml', '40mg/2ml', '80mg/2ml',
  '75mcg/1hr', '100mcg/hr',
]

const categoryItems = computed(() => [{ title: 'All categories', value: 'all' }, ...categoryOptions])
const dosageItems = computed(() => [{ title: 'All forms', value: 'all' }, ...dosageOptions])

const search = ref('')
const categoryFilter = ref('all')
const dosageFilter = ref('all')

watch(search, debouncedSearch)
watch(categoryFilter, () => { currentPage.value = 1; loadMeds() })
watch(dosageFilter, () => { currentPage.value = 1; loadMeds() })

const kpiTiles = computed(() => [
  { label: 'Total', value: totalCount.value, icon: 'mdi-pill', color: 'teal' },
  { label: 'Active', value: meds.value.filter(m => m.is_active).length, icon: 'mdi-check-circle', color: 'success' },
  { label: 'Prescription only', value: meds.value.filter(m => m.requires_prescription).length, icon: 'mdi-prescription', color: 'error' },
  { label: 'OTC', value: meds.value.filter(m => !m.requires_prescription).length, icon: 'mdi-cart-check', color: 'info' },
])

const headers = [
  { title: '#', key: 'row_num', sortable: false, width: 60 },
  { title: 'Medication Name', key: 'brand_names', sortable: false },
  { title: 'Generic Name', key: 'generic_name', sortable: true },
  { title: 'Category', key: 'category', sortable: true },
  { title: 'Form', key: 'dosage_form', sortable: true },
  { title: 'Strength', key: 'strength', sortable: true },
  { title: 'Added', key: 'created_at', sortable: true, width: 120 },
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

const DOSAGE_FORM_LABELS = {
  tablet: 'Tablet', capsule: 'Capsule', syrup: 'Syrup', injection: 'Injection',
  cream: 'Cream', ointment: 'Ointment', drops: 'Drops', inhaler: 'Inhaler',
  suppository: 'Suppository', suspension: 'Suspension', powder: 'Powder',
  gel: 'Gel', patch: 'Patch', lozenge: 'Lozenge', spray: 'Spray',
  solution: 'Solution', other: 'Other',
}

function medDisplayName(item) {
  const parts = []
  if (item.brand_names && item.brand_names.length) {
    parts.push(item.brand_names[0])
  } else if (item.generic_name) {
    parts.push(item.generic_name)
  }
  if (item.strength) parts.push(item.strength)
  if (item.dosage_form) {
    parts.push(DOSAGE_FORM_LABELS[item.dosage_form] || item.dosage_form)
  }
  return parts.join(' ')
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
    await loadMeds()
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
    await loadMeds()
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
// ── Delete all
const deleteAllDialog = ref(false)
const deleteAllConfirm = ref('')
const deletingAll = ref(false)
async function doDeleteAll() {
  deletingAll.value = true
  try {
    const { data } = await $api.delete('/medications/delete-all/')
    notify(data.detail || 'All medications deleted')
    deleteAllDialog.value = false
    deleteAllConfirm.value = ''
    await loadMeds()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { deletingAll.value = false }
}

// ── Update Brand Names
const brandUpdateDialog = ref(false)
const brandUpdateForce = ref(false)
const brandUpdateDryRun = ref(false)
const brandUpdating = ref(false)
const brandResultDialog = ref(false)
const brandResultColor = ref('success')
const brandUpdateResult = ref(null)

async function doUpdateBrandNames() {
  brandUpdating.value = true
  try {
    const params = {}
    if (brandUpdateForce.value) params.force = 'true'
    if (brandUpdateDryRun.value) params.dry_run = 'true'
    const { data } = await $api.post('/medications/update-brand-names/', null, { params })
    brandUpdateResult.value = data
    brandResultColor.value = data.updated > 0 ? 'success' : 'info'
    brandUpdateDialog.value = false
    brandResultDialog.value = true
    if (!brandUpdateDryRun.value && data.updated > 0) notify(`${data.updated} medication(s) updated with brand names`)
  } catch (e) { notify(extractError(e) || 'Brand update failed', 'error') }
  finally { brandUpdating.value = false }
}

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

</style>
