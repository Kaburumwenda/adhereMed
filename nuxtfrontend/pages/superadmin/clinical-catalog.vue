<template>
  <v-container fluid class="pa-4 pa-md-6 catalog-shell">
    <!-- ───────────────────────── Hero ───────────────────────── -->
    <v-card flat rounded="xl" class="catalog-hero pa-5 pa-md-6 mb-5">
      <div class="d-flex flex-wrap align-center" style="gap:18px">
        <v-avatar size="56" class="hero-avatar">
          <v-icon size="32" color="white">mdi-hospital-box</v-icon>
        </v-avatar>
        <div class="flex-grow-1">
          <div class="text-overline text-white-emph">SUPER ADMIN · SHARED CATALOGS</div>
          <h1 class="text-h5 text-md-h4 font-weight-black text-white mb-1">Clinical Catalog Manager</h1>
          <div class="text-body-2 text-white-emph">
            Manage allergies, chronic conditions, medications and lab tests shared across every tenant.
          </div>
        </div>
        <div class="d-flex" style="gap:8px">
          <v-btn variant="flat" color="white" class="text-primary" prepend-icon="mdi-database-arrow-up"
                 to="/superadmin/seed">Run Seeders</v-btn>
          <v-btn variant="outlined" color="white" prepend-icon="mdi-refresh" @click="load()">Refresh</v-btn>
        </div>
      </div>
    </v-card>

    <!-- ───────────────────────── Stats strip ───────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="s in statCards" :key="s.key" cols="6" sm="3">
        <v-card flat rounded="lg" class="stat-card pa-3" :class="{ 'stat-active': tab === s.key }"
                @click="tab = s.key" hover>
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar size="36" :color="s.color" variant="tonal">
              <v-icon size="20" :color="s.color">{{ s.icon }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
              <div class="text-h6 font-weight-bold">{{ statTotals[s.key] ?? '—' }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ───────────────────────── Tabs ───────────────────────── -->
    <v-card flat rounded="xl" class="pa-0 mb-3">
      <v-tabs v-model="tab" color="primary" align-tabs="start" show-arrows>
        <v-tab v-for="t in tabs" :key="t.key" :value="t.key">
          <v-icon start>{{ t.icon }}</v-icon>{{ t.label }}
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- ───────────────────────── Toolbar ───────────────────────── -->
    <v-card flat rounded="xl" class="pa-3 mb-3 toolbar-card">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                      :placeholder="`Search ${currentTab.label.toLowerCase()}…`"
                      variant="outlined" density="compact" hide-details clearable
                      style="min-width:240px;max-width:360px" @update:model-value="debouncedLoad" />

        <v-select v-if="categoryOptions.length" v-model="filterCategory" :items="categoryOptions"
                  item-title="label" item-value="value" placeholder="All categories"
                  variant="outlined" density="compact" hide-details clearable
                  style="max-width:240px" @update:model-value="load()" />

        <v-select v-model="filterActive" :items="activeOptions" item-title="label" item-value="value"
                  variant="outlined" density="compact" hide-details
                  style="max-width:160px" @update:model-value="load()" />

        <v-spacer />

        <v-btn-toggle v-model="density" mandatory density="compact" divided variant="outlined">
          <v-btn value="comfortable" size="small"><v-icon>mdi-format-list-bulleted</v-icon></v-btn>
          <v-btn value="compact" size="small"><v-icon>mdi-view-headline</v-icon></v-btn>
        </v-btn-toggle>

        <v-menu>
          <template #activator="{ props }">
            <v-btn v-bind="props" variant="outlined" prepend-icon="mdi-dots-vertical">More</v-btn>
          </template>
          <v-list density="compact">
            <v-list-item prepend-icon="mdi-download" title="Export CSV" @click="exportCsv" />
            <v-list-item prepend-icon="mdi-upload" title="Import (JSON / CSV)" @click="importDialog = true" />
            <v-divider />
            <v-list-item prepend-icon="mdi-database-arrow-up" :title="`Seed ${currentTab.label}`"
                         @click="runSeed" />
          </v-list>
        </v-menu>

        <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreate">New {{ currentTab.singular }}</v-btn>
      </div>

      <!-- Bulk action bar -->
      <v-slide-y-transition>
        <div v-if="selected.length" class="bulk-bar mt-3 pa-2 d-flex align-center"
             style="gap:8px;border-radius:10px;background:rgba(var(--v-theme-primary),0.08)">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <v-spacer />
          <v-btn variant="text" color="success" prepend-icon="mdi-check-circle"
                 :loading="bulkBusy" @click="bulkSetActive(true)">Activate</v-btn>
          <v-btn variant="text" color="warning" prepend-icon="mdi-cancel"
                 :loading="bulkBusy" @click="bulkSetActive(false)">Deactivate</v-btn>
          <v-btn variant="text" color="error" prepend-icon="mdi-delete"
                 :loading="bulkBusy" @click="bulkDelete">Delete</v-btn>
          <v-btn variant="text" @click="selected = []">Clear</v-btn>
        </div>
      </v-slide-y-transition>
    </v-card>

    <!-- ───────────────────────── Table ───────────────────────── -->
    <v-card flat rounded="xl">
      <v-data-table-server v-model="selected" :headers="currentHeaders" :items="data"
                    :items-length="totalCount" :loading="loading"
                    :items-per-page="pageSize" :page="page"
                    :items-per-page-options="[25, 50, 100, 200, 500]"
                    :density="density" item-value="id" show-select
                    class="catalog-table" hover
                    @update:page="onPage" @update:items-per-page="onPageSize"
                    @update:sort-by="onSort">
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" size="x-small" variant="text" color="error"
                 @click="confirmDelete(item)" />
        </template>
        <template #item.is_active="{ item }">
          <v-switch :model-value="item.is_active" color="success" hide-details density="compact"
                    inset @update:model-value="(v) => toggleActive(item, v)" />
        </template>
        <template #item.brand_names="{ item }">
          <span class="text-caption">{{ (item.brand_names || []).join(', ') || '—' }}</span>
        </template>

        <template #item.abbreviation="{ item }">
          <v-chip v-if="item.abbreviation" size="x-small" color="primary" variant="tonal" class="font-weight-medium">
            {{ item.abbreviation }}
          </v-chip>
          <span v-else class="text-disabled">—</span>
        </template>
        <template #item.requires_prescription="{ item }">
          <v-chip size="x-small" :color="item.requires_prescription ? 'error' : 'success'" variant="tonal">
            {{ item.requires_prescription ? 'Rx' : 'OTC' }}
          </v-chip>
        </template>
        <template #item.price="{ item }">
          <span class="font-weight-medium">KES {{ Number(item.price || 0).toLocaleString() }}</span>
        </template>
        <template #item.category_display="{ item }">
          <v-chip size="x-small" variant="tonal" color="primary">{{ item.category_display || item.category || '—' }}</v-chip>
        </template>
        <template #no-data>
          <div class="text-center pa-6 text-medium-emphasis">
            <v-icon size="48" color="grey-lighten-1">mdi-inbox-outline</v-icon>
            <div class="mt-2">No {{ currentTab.label.toLowerCase() }} yet.</div>
            <v-btn class="mt-3" color="primary" variant="text" prepend-icon="mdi-database-arrow-up"
                   @click="runSeed">Seed defaults</v-btn>
          </div>
        </template>
      </v-data-table-server>
    </v-card>

    <!-- ───────────────────────── Create / Edit dialog ───────────────────────── -->
    <v-dialog v-model="formDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center" style="gap:10px">
          <v-icon :color="currentTab.color">{{ currentTab.icon }}</v-icon>
          {{ form.id ? 'Edit' : 'New' }} {{ currentTab.singular }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="py-4">
          <!-- Allergy form -->
          <template v-if="tab === 'allergies'">
            <v-text-field v-model="form.name" label="Name *" variant="outlined" density="comfortable" />
            <v-select v-model="form.category" :items="catalogConfig.allergies.categories"
                      item-title="label" item-value="value" label="Category *"
                      variant="outlined" density="comfortable" />
            <v-textarea v-model="form.description" label="Description" rows="2" variant="outlined" />
            <v-textarea v-model="form.common_symptoms" label="Common symptoms (comma-separated)"
                        rows="2" variant="outlined" />
            <v-switch v-model="form.is_active" color="success" inset label="Active" />
          </template>

          <!-- Chronic condition form -->
          <template v-if="tab === 'conditions'">
            <v-row dense>
              <v-col cols="12" md="8">
                <v-text-field v-model="form.name" label="Name *" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="form.icd_code" label="ICD-10 code" variant="outlined" density="comfortable" />
              </v-col>
            </v-row>
            <v-select v-model="form.category" :items="catalogConfig.conditions.categories"
                      item-title="label" item-value="value" label="Category *"
                      variant="outlined" density="comfortable" />
            <v-textarea v-model="form.description" label="Description" rows="3" variant="outlined" />
            <v-switch v-model="form.is_active" color="success" inset label="Active" />
          </template>

          <!-- Medication form -->
          <template v-if="tab === 'medications'">
            <v-row dense>
              <v-col cols="12" md="5">
                <v-text-field v-model="form.generic_name" label="Generic name *" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="2">
                <v-text-field v-model="form.abbreviation" label="Abbreviation" placeholder="e.g. PCM"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="5">
                <v-combobox v-model="form.brand_names" label="Brand names" multiple chips closable-chips
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.category" :items="catalogConfig.medications.categories"
                          item-title="label" item-value="value" label="Category *"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.subcategory" label="Subcategory" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.dosage_form" :items="catalogConfig.medications.dosageForms"
                          item-title="label" item-value="value" label="Dosage form *"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="form.strength" label="Strength" placeholder="e.g. 500mg"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="form.unit" label="Unit" placeholder="e.g. mg/ml"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.controlled_substance_class" label="Controlled class"
                              placeholder="e.g. Schedule II" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6" class="d-flex align-center">
                <v-switch v-model="form.requires_prescription" color="error" inset label="Requires prescription" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.description" label="Description" rows="2" variant="outlined" />
              </v-col>
              <v-col cols="12" md="6">
                <v-textarea v-model="form.side_effects" label="Side effects" rows="2" variant="outlined" />
              </v-col>
              <v-col cols="12" md="6">
                <v-textarea v-model="form.contraindications" label="Contraindications" rows="2" variant="outlined" />
              </v-col>
            </v-row>
            <v-switch v-model="form.is_active" color="success" inset label="Active" />
          </template>

          <!-- Lab test form -->
          <template v-if="tab === 'lab-tests'">
            <v-row dense>
              <v-col cols="12" md="8">
                <v-text-field v-model="form.name" label="Name *" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="form.code" label="Code *" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.department" label="Department" placeholder="e.g. Haematology"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.specimen_type" label="Specimen type *" placeholder="e.g. Blood, Urine"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="4">
                <v-text-field v-model.number="form.price" label="Price (KES)" type="number" min="0"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="4">
                <v-text-field v-model="form.turnaround_time" label="Turnaround time" placeholder="e.g. 2 hours"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4" class="d-flex align-center">
                <v-switch v-model="form.is_active" color="success" inset label="Active" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.instructions" label="Instructions" rows="2" variant="outlined" />
              </v-col>
            </v-row>
          </template>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">{{ form.id ? 'Save changes' : 'Create' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────────────────── Delete confirm ───────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center" style="gap:10px">
          <v-icon color="error">mdi-alert</v-icon> Delete {{ currentTab.singular }}?
        </v-card-title>
        <v-card-text>
          This will permanently delete <strong>{{ pendingDelete?.name || pendingDelete?.generic_name }}</strong>.
          This action cannot be undone.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" :loading="deleting" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────────────────── Import dialog ───────────────────────── -->
    <v-dialog v-model="importDialog" max-width="640" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center" style="gap:10px">
          <v-icon color="primary">mdi-upload</v-icon> Import {{ currentTab.label }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="importDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="py-4">
          <v-alert type="info" variant="tonal" density="compact" class="mb-3">
            Paste a JSON array of objects (one per row). Each object should match the catalog fields.
          </v-alert>
          <v-textarea v-model="importText" label="JSON" rows="10" variant="outlined" auto-grow />
          <v-file-input v-model="importFile" label="Or upload a .json file" accept=".json"
                        prepend-icon="mdi-paperclip" variant="outlined" density="compact"
                        @update:model-value="readImportFile" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="importDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="importing" @click="doImport">Import</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="3500">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()

// ───────────────────────── Catalog configuration ─────────────────────────
const catalogConfig = {
  allergies: {
    label: 'Allergies', singular: 'Allergy', icon: 'mdi-allergy', color: 'pink',
    endpoint: '/clinical-catalog/allergies/',
    seed: 'clinical_catalog',
    headers: [
      { title: 'Name', key: 'name', sortable: true },
      { title: 'Category', key: 'category_display', sortable: true, width: 200 },
      { title: 'Symptoms', key: 'common_symptoms' },
      { title: 'Active', key: 'is_active', width: 90, sortable: false },
      { title: '', key: 'actions', width: 100, sortable: false, align: 'end' },
    ],
    categories: [
      { value: 'drug', label: 'Drug / Medication' },
      { value: 'food', label: 'Food' },
      { value: 'environmental', label: 'Environmental' },
      { value: 'insect', label: 'Insect / Venom' },
      { value: 'latex', label: 'Latex' },
      { value: 'contrast', label: 'Contrast / Dye' },
      { value: 'chemical', label: 'Chemical' },
      { value: 'other', label: 'Other' },
    ],
    blank: () => ({ name: '', category: 'drug', description: '', common_symptoms: '', is_active: true }),
  },
  conditions: {
    label: 'Chronic Conditions', singular: 'Condition', icon: 'mdi-heart-pulse', color: 'deep-purple',
    endpoint: '/clinical-catalog/conditions/',
    seed: 'clinical_catalog',
    headers: [
      { title: 'Name', key: 'name', sortable: true },
      { title: 'ICD', key: 'icd_code', width: 110, sortable: true },
      { title: 'Category', key: 'category_display', sortable: true, width: 220 },
      { title: 'Active', key: 'is_active', width: 90, sortable: false },
      { title: '', key: 'actions', width: 100, sortable: false, align: 'end' },
    ],
    categories: [
      { value: 'cardiovascular', label: 'Cardiovascular' },
      { value: 'endocrine', label: 'Endocrine / Metabolic' },
      { value: 'respiratory', label: 'Respiratory' },
      { value: 'neurological', label: 'Neurological' },
      { value: 'musculoskeletal', label: 'Musculoskeletal' },
      { value: 'gastrointestinal', label: 'Gastrointestinal' },
      { value: 'renal', label: 'Renal / Urological' },
      { value: 'hematological', label: 'Hematological' },
      { value: 'immunological', label: 'Immunological / Infectious' },
      { value: 'mental_health', label: 'Mental Health' },
      { value: 'oncological', label: 'Oncological' },
      { value: 'dermatological', label: 'Dermatological' },
      { value: 'ophthalmological', label: 'Ophthalmological' },
      { value: 'other', label: 'Other' },
    ],
    blank: () => ({ name: '', category: 'cardiovascular', icd_code: '', description: '', is_active: true }),
  },
  medications: {
    label: 'Medications', singular: 'Medication', icon: 'mdi-pill', color: 'teal',
    endpoint: '/medications/',
    seed: 'medications',
    headers: [
      { title: 'Abbr', key: 'abbreviation', sortable: true, width: 90 },
      { title: 'Generic name', key: 'generic_name', sortable: true },
      { title: 'Brands', key: 'brand_names' },
      { title: 'Strength', key: 'strength', width: 110, sortable: true },
      { title: 'Form', key: 'dosage_form', width: 120, sortable: true },
      { title: 'Category', key: 'category', sortable: true, width: 170 },
      { title: 'Rx', key: 'requires_prescription', width: 70, sortable: false },
      { title: 'Active', key: 'is_active', width: 90, sortable: false },
      { title: '', key: 'actions', width: 100, sortable: false, align: 'end' },
    ],
    categories: [
      'analgesic', 'antibiotic', 'antifungal', 'antiviral', 'antiparasitic', 'antimalarial',
      'antihypertensive', 'antidiabetic', 'antihistamine', 'antacid', 'cardiovascular',
      'respiratory', 'cns', 'hormone', 'vitamin', 'vaccine', 'dermatological', 'ophthalmic',
      'oncology', 'immunosuppressant', 'nsaid', 'other',
    ].map(v => ({ value: v, label: v.charAt(0).toUpperCase() + v.slice(1) })),
    dosageForms: [
      'tablet', 'capsule', 'syrup', 'injection', 'cream', 'ointment', 'drops', 'inhaler',
      'suppository', 'suspension', 'powder', 'gel', 'patch', 'lozenge', 'spray', 'solution', 'other',
    ].map(v => ({ value: v, label: v.charAt(0).toUpperCase() + v.slice(1) })),
    blank: () => ({
      generic_name: '', abbreviation: '', brand_names: [], category: 'other', subcategory: '',
      dosage_form: 'tablet', strength: '', unit: '', description: '',
      requires_prescription: true, controlled_substance_class: '',
      side_effects: '', contraindications: '', is_active: true,
    }),
  },
  'lab-tests': {
    label: 'Lab Tests', singular: 'Lab Test', icon: 'mdi-microscope', color: 'indigo',
    endpoint: '/lab/catalog/',
    seed: 'lab_tests',
    headers: [
      { title: 'Code', key: 'code', width: 110, sortable: true },
      { title: 'Name', key: 'name', sortable: true },
      { title: 'Department', key: 'department', sortable: true, width: 160 },
      { title: 'Specimen', key: 'specimen_type', width: 130 },
      { title: 'TAT', key: 'turnaround_time', width: 110 },
      { title: 'Price', key: 'price', width: 130, sortable: true, align: 'end' },
      { title: 'Active', key: 'is_active', width: 90, sortable: false },
      { title: '', key: 'actions', width: 100, sortable: false, align: 'end' },
    ],
    categories: [], // dynamic — by department, populated from data
    blank: () => ({
      name: '', code: '', department: '', specimen_type: '',
      price: 0, turnaround_time: '', instructions: '', is_active: true,
    }),
  },
}

const tabs = [
  { key: 'allergies',   label: 'Allergies',          icon: 'mdi-allergy',     color: 'pink' },
  { key: 'conditions',  label: 'Chronic Conditions', icon: 'mdi-heart-pulse', color: 'deep-purple' },
  { key: 'medications', label: 'Medications',        icon: 'mdi-pill',        color: 'teal' },
  { key: 'lab-tests',   label: 'Lab Tests',          icon: 'mdi-microscope',  color: 'indigo' },
]

const statCards = tabs.map(t => ({ key: t.key, label: t.label, icon: t.icon, color: t.color }))

// ───────────────────────── State ─────────────────────────
const tab = ref('allergies')
const search = ref('')
const filterCategory = ref(null)
const filterActive = ref('all')
const density = ref('comfortable')
const pageSize = ref(50)
const page = ref(1)
const totalCount = ref(0)
const sortBy = ref([])
const loading = ref(false)
const data = ref([])
const selected = ref([])
const statTotals = reactive({ allergies: null, conditions: null, medications: null, 'lab-tests': null })

const formDialog = ref(false)
const form = ref({})
const saving = ref(false)
const deleteDialog = ref(false)
const pendingDelete = ref(null)
const deleting = ref(false)
const importDialog = ref(false)
const importText = ref('')
const importFile = ref(null)
const importing = ref(false)
const bulkBusy = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const activeOptions = [
  { label: 'All', value: 'all' },
  { label: 'Active', value: 'true' },
  { label: 'Inactive', value: 'false' },
]

const currentTab = computed(() => catalogConfig[tab.value])
const currentHeaders = computed(() => currentTab.value.headers)
const categoryOptions = computed(() => {
  if (tab.value === 'lab-tests') {
    const set = new Set(data.value.map(d => d.department).filter(Boolean))
    return [...set].map(d => ({ value: d, label: d }))
  }
  return currentTab.value.categories
})

// ───────────────────────── Loaders ─────────────────────────
let debTimer = null
function debouncedLoad() {
  clearTimeout(debTimer)
  debTimer = setTimeout(() => { page.value = 1; load() }, 350)
}

function onPage(p) { page.value = p; load() }
function onPageSize(n) { pageSize.value = n; page.value = 1; load() }
function onSort(s) { sortBy.value = s || []; page.value = 1; load() }

async function load() {
  loading.value = true
  selected.value = []
  try {
    const params = { page: page.value, page_size: pageSize.value }
    if (search.value) params.search = search.value
    if (filterCategory.value) {
      params[tab.value === 'lab-tests' ? 'department' : 'category'] = filterCategory.value
    }
    if (filterActive.value !== 'all') params.is_active = filterActive.value
    if (sortBy.value.length) {
      params.ordering = sortBy.value
        .map(s => (s.order === 'desc' ? '-' : '') + s.key.replace('_display', ''))
        .join(',')
    }
    const res = await $api.get(currentTab.value.endpoint, { params })
    const body = res.data
    if (body && Array.isArray(body.results)) {
      data.value = body.results
      totalCount.value = body.count ?? body.results.length
    } else {
      data.value = Array.isArray(body) ? body : []
      totalCount.value = data.value.length
    }
    statTotals[tab.value] = totalCount.value
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to load records', 'error')
    data.value = []
    totalCount.value = 0
  } finally {
    loading.value = false
  }
}

async function refreshAllStats() {
  await Promise.all(tabs.map(async t => {
    try {
      const r = await $api.get(catalogConfig[t.key].endpoint, { params: { page_size: 1 } })
      statTotals[t.key] = r.data?.count ?? (Array.isArray(r.data) ? r.data.length : (r.data?.results?.length ?? 0))
    } catch { statTotals[t.key] = '—' }
  }))
}

// ───────────────────────── CRUD ─────────────────────────
function openCreate() {
  form.value = currentTab.value.blank()
  formDialog.value = true
}

function openEdit(item) {
  form.value = JSON.parse(JSON.stringify(item))
  if (tab.value === 'medications' && !Array.isArray(form.value.brand_names)) {
    form.value.brand_names = []
  }
  formDialog.value = true
}

async function save() {
  saving.value = true
  try {
    const payload = { ...form.value }
    delete payload.category_display
    if (form.value.id) {
      await $api.patch(`${currentTab.value.endpoint}${form.value.id}/`, payload)
      notify('Updated successfully')
    } else {
      delete payload.id
      await $api.post(currentTab.value.endpoint, payload)
      notify('Created successfully')
    }
    formDialog.value = false
    await load()
  } catch (e) {
    notify(extractError(e), 'error')
  } finally {
    saving.value = false
  }
}

function confirmDelete(item) {
  pendingDelete.value = item
  deleteDialog.value = true
}

async function doDelete() {
  if (!pendingDelete.value) return
  deleting.value = true
  try {
    await $api.delete(`${currentTab.value.endpoint}${pendingDelete.value.id}/`)
    notify('Deleted')
    deleteDialog.value = false
    pendingDelete.value = null
    await load()
  } catch (e) {
    notify(extractError(e), 'error')
  } finally {
    deleting.value = false
  }
}

async function toggleActive(item, value) {
  try {
    await $api.patch(`${currentTab.value.endpoint}${item.id}/`, { is_active: value })
    item.is_active = value
    notify(value ? 'Activated' : 'Deactivated')
  } catch (e) {
    notify(extractError(e), 'error')
  }
}

// ───────────────────────── Bulk ─────────────────────────
async function bulkSetActive(value) {
  if (!selected.value.length) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id =>
      $api.patch(`${currentTab.value.endpoint}${id}/`, { is_active: value })
    ))
    notify(`${selected.value.length} record(s) ${value ? 'activated' : 'deactivated'}`)
    selected.value = []
    await load()
  } catch (e) {
    notify(extractError(e), 'error')
  } finally {
    bulkBusy.value = false
  }
}

async function bulkDelete() {
  if (!selected.value.length) return
  if (!confirm(`Delete ${selected.value.length} record(s)? This cannot be undone.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id =>
      $api.delete(`${currentTab.value.endpoint}${id}/`)
    ))
    notify(`${selected.value.length} record(s) deleted`)
    selected.value = []
    await load()
  } catch (e) {
    notify(extractError(e), 'error')
  } finally {
    bulkBusy.value = false
  }
}

// ───────────────────────── Import / Export ─────────────────────────
async function exportCsv() {
  notify('Preparing export…', 'info')
  let rows = []
  try {
    const params = { page: 1, page_size: 5000 }
    if (search.value) params.search = search.value
    if (filterCategory.value) {
      params[tab.value === 'lab-tests' ? 'department' : 'category'] = filterCategory.value
    }
    if (filterActive.value !== 'all') params.is_active = filterActive.value
    const res = await $api.get(currentTab.value.endpoint, { params })
    rows = res.data?.results || (Array.isArray(res.data) ? res.data : [])
  } catch (e) {
    notify(extractError(e) || 'Export failed', 'error'); return
  }
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const cols = currentTab.value.headers
    .filter(h => h.key !== 'actions' && h.key !== 'is_active')
    .map(h => h.key.replace('_display', ''))
  const escape = v => {
    if (v == null) return ''
    const s = Array.isArray(v) ? v.join('; ') : String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const out = [cols.join(','), ...rows.map(r => cols.map(c => escape(r[c])).join(','))]
  const blob = new Blob([out.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `${tab.value}-${new Date().toISOString().slice(0, 10)}.csv`
  a.click(); URL.revokeObjectURL(url)
  notify(`Exported ${rows.length} record(s)`)
}

async function readImportFile(file) {
  const f = Array.isArray(file) ? file[0] : file
  if (!f) return
  importText.value = await f.text()
}

async function doImport() {
  let rows
  try { rows = JSON.parse(importText.value || '[]') }
  catch { notify('Invalid JSON', 'error'); return }
  if (!Array.isArray(rows) || !rows.length) { notify('No records to import', 'warning'); return }
  importing.value = true
  let ok = 0, fail = 0
  for (const r of rows) {
    try { await $api.post(currentTab.value.endpoint, r); ok++ }
    catch { fail++ }
  }
  importing.value = false
  importDialog.value = false
  importText.value = ''
  notify(`Imported ${ok} record(s)${fail ? ` (${fail} failed)` : ''}`, fail ? 'warning' : 'success')
  await load()
}

async function runSeed() {
  const seedKey = currentTab.value.seed
  if (!seedKey) return
  if (!confirm(`Run the "${seedKey}" seeder now? Existing records will be preserved.`)) return
  try {
    await $api.post('/superadmin/seed/run/', { command: seedKey })
    notify('Seeder started — refreshing in a moment', 'info')
    setTimeout(() => { load(); refreshAllStats() }, 1500)
  } catch (e) {
    notify(extractError(e) || 'Seeder failed', 'error')
  }
}

// ───────────────────────── Helpers ─────────────────────────
function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || 'Request failed'
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join(' · ')
}

function notify(text, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true
}

watch(tab, () => {
  filterCategory.value = null
  selected.value = []
  page.value = 1
  sortBy.value = []
  load()
})

watch([filterCategory, filterActive], () => { page.value = 1 })

onMounted(() => {
  load()
  refreshAllStats()
})
</script>

<style scoped>
.catalog-shell { background: linear-gradient(180deg, rgba(99,102,241,0.04), transparent 220px); }

.catalog-hero {
  background: linear-gradient(120deg, #4f46e5 0%, #7c3aed 50%, #ec4899 100%);
  color: white;
  position: relative;
  overflow: hidden;
}
.catalog-hero::after {
  content: '';
  position: absolute; inset: 0;
  background: radial-gradient(circle at 90% 20%, rgba(255,255,255,0.18), transparent 50%);
  pointer-events: none;
}
.hero-avatar { background: rgba(255,255,255,0.18); backdrop-filter: blur(6px); }
.text-white-emph { color: rgba(255,255,255,0.85); }

.stat-card {
  cursor: pointer;
  transition: all 0.2s ease;
  border: 1px solid rgba(0,0,0,0.06);
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.08); }
.stat-card.stat-active {
  border-color: rgb(var(--v-theme-primary));
  box-shadow: 0 0 0 2px rgba(var(--v-theme-primary), 0.15);
}

.toolbar-card { border: 1px solid rgba(0,0,0,0.06); }
.bulk-bar { border: 1px dashed rgba(var(--v-theme-primary), 0.4); }

.catalog-table :deep(th) { font-weight: 600 !important; }
</style>
