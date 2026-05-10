<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:1280px;">
    <PageHeader v-if="hasPageHeader" title="Clinical catalog" icon="mdi-book-cog"
                subtitle="Tenant-scoped diagnoses & allergies. Seeded from the platform catalog and editable here." />
    <div v-else class="d-flex align-center mb-4">
      <v-icon icon="mdi-book-cog" class="mr-2" color="teal" />
      <div>
        <div class="text-h5 font-weight-bold">Clinical catalog</div>
        <div class="text-caption text-medium-emphasis">
          Tenant-scoped diagnoses &amp; allergies. Seeded from the platform catalog and editable here.
        </div>
      </div>
    </div>

    <v-card rounded="xl" class="pa-2 pa-md-3" elevation="1">
      <v-tabs v-model="tab" color="teal" align-tabs="start" grow>
        <v-tab value="diagnoses">
          <v-icon icon="mdi-clipboard-pulse" class="mr-1" /> Diagnoses
          <v-chip class="ml-2" size="x-small" color="teal" variant="tonal">{{ diagTotal }}</v-chip>
        </v-tab>
        <v-tab value="allergies">
          <v-icon icon="mdi-alert-octagon" class="mr-1" /> Allergies
          <v-chip class="ml-2" size="x-small" color="error" variant="tonal">{{ alleTotal }}</v-chip>
        </v-tab>
      </v-tabs>

      <v-divider />

      <v-window v-model="tab" class="pa-3">
        <!-- ───── Diagnoses ───── -->
        <v-window-item value="diagnoses">
          <CatalogToolbar
            :search="diagSearch"
            :source="diagSource"
            :loading="diagLoading"
            :can-admin="isAdmin"
            search-placeholder="Search diagnoses or ICD code…"
            seed-label="Seed from platform catalog"
            add-label="Add diagnosis"
            @update:search="(v) => { diagSearch = v; debounceLoadDiag() }"
            @update:source="(v) => { diagSource = v; loadDiagnoses() }"
            @add="openDiagnosisDialog()"
            @seed="seedDiagnoses"
          />

          <v-data-table-server
            v-model:items-per-page="diagPerPage"
            v-model:page="diagPage"
            :items-length="diagTotal"
            :headers="diagHeaders"
            :items="diagItems"
            :loading="diagLoading"
            density="comfortable"
            class="rounded-lg"
            @update:options="onDiagOptions"
          >
            <template #[`item.source`]="{ item }">
              <v-chip size="x-small" :color="item.source === 'seed' ? 'teal' : 'purple'"
                      variant="tonal">{{ item.source }}</v-chip>
            </template>
            <template #[`item.is_active`]="{ item }">
              <v-icon :icon="item.is_active ? 'mdi-check-circle' : 'mdi-cancel'"
                      :color="item.is_active ? 'success' : 'grey'" size="18" />
            </template>
            <template #[`item.actions`]="{ item }">
              <v-btn v-if="isAdmin" icon="mdi-pencil" variant="text" size="small"
                     @click="openDiagnosisDialog(item)" />
              <v-btn v-if="isAdmin" icon="mdi-delete" variant="text" size="small" color="error"
                     @click="removeDiagnosis(item)" />
            </template>
          </v-data-table-server>
        </v-window-item>

        <!-- ───── Allergies ───── -->
        <v-window-item value="allergies">
          <CatalogToolbar
            :search="alleSearch"
            :source="alleSource"
            :loading="alleLoading"
            :can-admin="isAdmin"
            search-placeholder="Search allergies…"
            seed-label="Seed from platform catalog"
            add-label="Add allergy"
            @update:search="(v) => { alleSearch = v; debounceLoadAlle() }"
            @update:source="(v) => { alleSource = v; loadAllergies() }"
            @add="openAllergyDialog()"
            @seed="seedAllergies"
          />

          <v-data-table-server
            v-model:items-per-page="allePerPage"
            v-model:page="allePage"
            :items-length="alleTotal"
            :headers="alleHeaders"
            :items="alleItems"
            :loading="alleLoading"
            density="comfortable"
            class="rounded-lg"
            @update:options="onAlleOptions"
          >
            <template #[`item.source`]="{ item }">
              <v-chip size="x-small" :color="item.source === 'seed' ? 'teal' : 'purple'"
                      variant="tonal">{{ item.source }}</v-chip>
            </template>
            <template #[`item.is_active`]="{ item }">
              <v-icon :icon="item.is_active ? 'mdi-check-circle' : 'mdi-cancel'"
                      :color="item.is_active ? 'success' : 'grey'" size="18" />
            </template>
            <template #[`item.actions`]="{ item }">
              <v-btn v-if="isAdmin" icon="mdi-pencil" variant="text" size="small"
                     @click="openAllergyDialog(item)" />
              <v-btn v-if="isAdmin" icon="mdi-delete" variant="text" size="small" color="error"
                     @click="removeAllergy(item)" />
            </template>
          </v-data-table-server>
        </v-window-item>
      </v-window>
    </v-card>

    <!-- ───── Diagnosis dialog ───── -->
    <v-dialog v-model="diagDialog" max-width="640">
      <v-card rounded="xl">
        <v-card-title>{{ editingDiag?.id ? 'Edit diagnosis' : 'New diagnosis' }}</v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12"><v-text-field v-model="editingDiag.name" label="Name" required /></v-col>
            <v-col cols="6"><v-text-field v-model="editingDiag.icd_code" label="ICD-10 code" /></v-col>
            <v-col cols="6"><v-text-field v-model="editingDiag.category" label="Category" /></v-col>
            <v-col cols="12"><v-textarea v-model="editingDiag.description" label="Description" rows="3" auto-grow /></v-col>
            <v-col cols="12"><v-switch v-model="editingDiag.is_active" label="Active" color="teal" inset /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="diagDialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="savingDiag" @click="saveDiagnosis">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───── Allergy dialog ───── -->
    <v-dialog v-model="alleDialog" max-width="640">
      <v-card rounded="xl">
        <v-card-title>{{ editingAlle?.id ? 'Edit allergy' : 'New allergy' }}</v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12"><v-text-field v-model="editingAlle.name" label="Name" required /></v-col>
            <v-col cols="12"><v-text-field v-model="editingAlle.category" label="Category" /></v-col>
            <v-col cols="12"><v-textarea v-model="editingAlle.description" label="Description" rows="2" auto-grow /></v-col>
            <v-col cols="12"><v-textarea v-model="editingAlle.common_symptoms" label="Common symptoms" rows="2" auto-grow /></v-col>
            <v-col cols="12"><v-switch v-model="editingAlle.is_active" label="Active" color="teal" inset /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="alleDialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="savingAlle" @click="saveAllergy">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2800">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const auth = useAuthStore()
const isAdmin = computed(() => {
  const r = auth?.user?.role
  return ['tenant_admin', 'homecare_admin', 'admin', 'super_admin'].includes(r)
})

const hasPageHeader = computed(() => {
  // PageHeader is a global component in this project; this is just a defensive flag.
  return true
})

const tab = ref('diagnoses')
const snack = reactive({ show: false, text: '', color: 'info' })

// ─── Diagnoses state ───
const diagItems = ref([])
const diagTotal = ref(0)
const diagLoading = ref(false)
const diagSearch = ref('')
const diagSource = ref('')   // '' | 'seed' | 'custom'
const diagPage = ref(1)
const diagPerPage = ref(25)
const diagOrdering = ref('name')
const diagHeaders = [
  { title: 'Name',     key: 'name',     sortable: true },
  { title: 'ICD',      key: 'icd_code', sortable: true, width: 110 },
  { title: 'Category', key: 'category', sortable: true, width: 180 },
  { title: 'Source',   key: 'source',   sortable: true, width: 110, align: 'center' },
  { title: 'Active',   key: 'is_active', sortable: true, width: 90, align: 'center' },
  { title: '',         key: 'actions',  sortable: false, width: 110, align: 'end' }
]

// ─── Allergies state ───
const alleItems = ref([])
const alleTotal = ref(0)
const alleLoading = ref(false)
const alleSearch = ref('')
const alleSource = ref('')
const allePage = ref(1)
const allePerPage = ref(25)
const alleOrdering = ref('name')
const alleHeaders = [
  { title: 'Name',     key: 'name',     sortable: true },
  { title: 'Category', key: 'category', sortable: true, width: 200 },
  { title: 'Source',   key: 'source',   sortable: true, width: 110, align: 'center' },
  { title: 'Active',   key: 'is_active', sortable: true, width: 90, align: 'center' },
  { title: '',         key: 'actions',  sortable: false, width: 110, align: 'end' }
]

// ─── Loaders ───
async function loadDiagnoses() {
  diagLoading.value = true
  try {
    const params = {
      search: diagSearch.value || undefined,
      source: diagSource.value || undefined,
      ordering: diagOrdering.value,
      page: diagPage.value,
      page_size: diagPerPage.value,
    }
    const { data } = await $api.get('/homecare/diagnoses/', { params })
    if (Array.isArray(data)) {
      diagItems.value = data
      diagTotal.value = data.length
    } else {
      diagItems.value = data?.results || []
      diagTotal.value = data?.count ?? diagItems.value.length
    }
  } catch (e) {
    notify('Failed to load diagnoses', 'error')
  } finally { diagLoading.value = false }
}
async function loadAllergies() {
  alleLoading.value = true
  try {
    const params = {
      search: alleSearch.value || undefined,
      source: alleSource.value || undefined,
      ordering: alleOrdering.value,
      page: allePage.value,
      page_size: allePerPage.value,
    }
    const { data } = await $api.get('/homecare/allergies/', { params })
    if (Array.isArray(data)) {
      alleItems.value = data
      alleTotal.value = data.length
    } else {
      alleItems.value = data?.results || []
      alleTotal.value = data?.count ?? alleItems.value.length
    }
  } catch (e) {
    notify('Failed to load allergies', 'error')
  } finally { alleLoading.value = false }
}

let diagTimer = null, alleTimer = null
function debounceLoadDiag() {
  clearTimeout(diagTimer); diagTimer = setTimeout(() => { diagPage.value = 1; loadDiagnoses() }, 250)
}
function debounceLoadAlle() {
  clearTimeout(alleTimer); alleTimer = setTimeout(() => { allePage.value = 1; loadAllergies() }, 250)
}

function onDiagOptions({ page, itemsPerPage, sortBy }) {
  diagPage.value = page
  diagPerPage.value = itemsPerPage
  if (sortBy?.length) {
    diagOrdering.value = (sortBy[0].order === 'desc' ? '-' : '') + sortBy[0].key
  }
  loadDiagnoses()
}
function onAlleOptions({ page, itemsPerPage, sortBy }) {
  allePage.value = page
  allePerPage.value = itemsPerPage
  if (sortBy?.length) {
    alleOrdering.value = (sortBy[0].order === 'desc' ? '-' : '') + sortBy[0].key
  }
  loadAllergies()
}

// ─── Dialogs ───
const diagDialog = ref(false)
const editingDiag = ref({})
const savingDiag = ref(false)
function openDiagnosisDialog(row = null) {
  editingDiag.value = row ? { ...row } : { name: '', icd_code: '', category: '', description: '', is_active: true }
  diagDialog.value = true
}
async function saveDiagnosis() {
  if (!editingDiag.value.name?.trim()) {
    notify('Name is required', 'warning'); return
  }
  savingDiag.value = true
  try {
    if (editingDiag.value.id) {
      await $api.patch(`/homecare/diagnoses/${editingDiag.value.id}/`, editingDiag.value)
      notify('Diagnosis updated', 'success')
    } else {
      await $api.post('/homecare/diagnoses/', editingDiag.value)
      notify('Diagnosis created', 'success')
    }
    diagDialog.value = false
    loadDiagnoses()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save', 'error')
  } finally { savingDiag.value = false }
}
async function removeDiagnosis(row) {
  if (!confirm(`Delete diagnosis "${row.name}"?`)) return
  try {
    await $api.delete(`/homecare/diagnoses/${row.id}/`)
    notify('Diagnosis deleted', 'success')
    loadDiagnoses()
  } catch (e) { notify('Delete failed', 'error') }
}

const alleDialog = ref(false)
const editingAlle = ref({})
const savingAlle = ref(false)
function openAllergyDialog(row = null) {
  editingAlle.value = row ? { ...row } : { name: '', category: '', description: '', common_symptoms: '', is_active: true }
  alleDialog.value = true
}
async function saveAllergy() {
  if (!editingAlle.value.name?.trim()) {
    notify('Name is required', 'warning'); return
  }
  savingAlle.value = true
  try {
    if (editingAlle.value.id) {
      await $api.patch(`/homecare/allergies/${editingAlle.value.id}/`, editingAlle.value)
      notify('Allergy updated', 'success')
    } else {
      await $api.post('/homecare/allergies/', editingAlle.value)
      notify('Allergy created', 'success')
    }
    alleDialog.value = false
    loadAllergies()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save', 'error')
  } finally { savingAlle.value = false }
}
async function removeAllergy(row) {
  if (!confirm(`Delete allergy "${row.name}"?`)) return
  try {
    await $api.delete(`/homecare/allergies/${row.id}/`)
    notify('Allergy deleted', 'success')
    loadAllergies()
  } catch (e) { notify('Delete failed', 'error') }
}

// ─── Seeding ───
async function seedDiagnoses() {
  if (!confirm('Import all diagnoses from the platform catalog into this tenant? Existing names are kept untouched.')) return
  diagLoading.value = true
  try {
    const { data } = await $api.post('/homecare/diagnoses/seed/')
    notify(data?.detail || 'Seeded.', 'success')
    loadDiagnoses()
  } catch (e) { notify(e?.response?.data?.detail || 'Seed failed (admin only)', 'error') }
  finally { diagLoading.value = false }
}
async function seedAllergies() {
  if (!confirm('Import all allergies from the platform catalog into this tenant? Existing names are kept untouched.')) return
  alleLoading.value = true
  try {
    const { data } = await $api.post('/homecare/allergies/seed/')
    notify(data?.detail || 'Seeded.', 'success')
    loadAllergies()
  } catch (e) { notify(e?.response?.data?.detail || 'Seed failed (admin only)', 'error') }
  finally { alleLoading.value = false }
}

function notify(text, color = 'info') {
  Object.assign(snack, { show: true, text, color })
}

onMounted(() => {
  loadDiagnoses()
  loadAllergies()
})
</script>
