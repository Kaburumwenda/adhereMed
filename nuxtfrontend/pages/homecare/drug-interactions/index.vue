<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:1400px;">
    <HomecareHero
      title="Drug interactions"
      subtitle="Tenant-curated catalog of drug-drug interaction rules used by prescribe-time safety checks."
      icon="mdi-pill-multiple"
      color="#dc2626"
    />

    <v-card rounded="xl" class="pa-3 mt-4" elevation="0">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search" prepend-inner-icon="mdi-magnify"
          placeholder="Search drug name or summary..."
          density="comfortable" variant="outlined" rounded="lg"
          hide-details clearable style="max-width:380px;"
          @update:model-value="debouncedReload"
        />
        <v-select
          v-model="severityFilter" :items="severityOptions"
          density="comfortable" variant="outlined" rounded="lg"
          hide-details clearable placeholder="Severity"
          style="max-width:200px;" @update:model-value="reload"
        />
        <v-checkbox v-model="onlyActive" density="comfortable" hide-details
                    label="Active only" @update:model-value="reload" />
        <v-spacer />
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
               class="text-none" @click="openCreate">New rule</v-btn>
      </div>
    </v-card>

    <v-card rounded="xl" class="mt-4" elevation="0">
      <v-data-table-server
        v-model:items-per-page="pageSize"
        v-model:page="page"
        :items-length="totalItems"
        :items="rows"
        :loading="loading"
        :headers="headers"
        item-value="id"
        class="hc-table"
        @update:options="onTableChange"
      >
        <template #[`item.severity`]="{ item }">
          <v-chip size="small" :color="severityColor(item.severity)" variant="tonal">
            {{ item.severity }}
          </v-chip>
        </template>
        <template #[`item.is_active`]="{ item }">
          <v-icon :icon="item.is_active ? 'mdi-check-circle' : 'mdi-close-circle'"
                  :color="item.is_active ? 'success' : 'grey'" />
        </template>
        <template #[`item.references`]="{ item }">
          <span class="text-caption text-medium-emphasis">
            {{ item.references?.length || 0 }} ref(s)
          </span>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn icon variant="text" size="small" @click="openEdit(item)">
            <v-icon icon="mdi-pencil" />
          </v-btn>
          <v-btn icon variant="text" size="small" color="error" @click="confirmDelete(item)">
            <v-icon icon="mdi-delete" />
          </v-btn>
        </template>
        <template #no-data>
          <EmptyState icon="mdi-pill-off" title="No drug interactions match your filters" />
        </template>
      </v-data-table-server>
    </v-card>

    <!-- Editor dialog -->
    <v-dialog v-model="editor.show" max-width="640" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-pill-multiple" color="error" class="mr-2" />
          {{ editor.form.id ? 'Edit interaction' : 'New interaction' }}
          <v-spacer />
          <v-btn icon variant="text" @click="editor.show = false">
            <v-icon icon="mdi-close" />
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="editor.form.drug_a" label="Drug A *"
                            variant="outlined" rounded="lg" density="comfortable"
                            :rules="[v => !!v || 'Required']" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="editor.form.drug_b" label="Drug B *"
                            variant="outlined" rounded="lg" density="comfortable"
                            :rules="[v => !!v || 'Required']" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="editor.form.severity" :items="severityOptions"
                        label="Severity *" variant="outlined" rounded="lg"
                        density="comfortable" />
            </v-col>
            <v-col cols="12" md="6" class="d-flex align-center">
              <v-switch v-model="editor.form.is_active" label="Active"
                        color="success" density="comfortable" hide-details />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="editor.form.summary" label="Summary *"
                            variant="outlined" rounded="lg" density="comfortable"
                            :rules="[v => !!v || 'Required']" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="editor.form.detail" label="Detail / mechanism"
                          variant="outlined" rounded="lg" density="comfortable"
                          rows="3" auto-grow />
            </v-col>
            <v-col cols="12">
              <div class="d-flex align-center mb-2">
                <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">References</h4>
                <v-btn size="small" variant="text" prepend-icon="mdi-plus"
                       class="text-none" @click="addRef">Add reference</v-btn>
              </div>
              <div v-for="(r, i) in editor.form.references" :key="i"
                   class="d-flex align-center ga-2 mb-2">
                <v-text-field v-model="r.label" label="Label" density="compact"
                              variant="outlined" rounded="lg" hide-details />
                <v-text-field v-model="r.url" label="URL" density="compact"
                              variant="outlined" rounded="lg" hide-details />
                <v-btn icon variant="text" size="small" color="error"
                       @click="editor.form.references.splice(i, 1)">
                  <v-icon icon="mdi-delete" />
                </v-btn>
              </div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="editor.show = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none"
                 :loading="editor.saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="del.show" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete interaction?</v-card-title>
        <v-card-text>
          <p class="text-body-2">
            <strong>{{ del.row?.drug_a }}</strong> &rlarr;
            <strong>{{ del.row?.drug_b }}</strong> ({{ del.row?.severity }})
          </p>
          <p class="text-caption text-medium-emphasis">
            This will remove the rule from prescribe-time safety checks for this tenant.
          </p>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="del.show = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none"
                 :loading="del.busy" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

const headers = [
  { title: 'Drug A',     key: 'drug_a',     sortable: true },
  { title: 'Drug B',     key: 'drug_b',     sortable: true },
  { title: 'Severity',   key: 'severity',   sortable: true },
  { title: 'Summary',    key: 'summary',    sortable: false },
  { title: 'Refs',       key: 'references', sortable: false, width: 80 },
  { title: 'Active',     key: 'is_active',  sortable: true,  width: 80 },
  { title: '',           key: 'actions',    sortable: false, width: 110 },
]

const severityOptions = [
  { title: 'Minor',           value: 'minor' },
  { title: 'Moderate',        value: 'moderate' },
  { title: 'Major',           value: 'major' },
  { title: 'Contraindicated', value: 'contraindicated' },
]

const search = ref('')
const severityFilter = ref(null)
const onlyActive = ref(false)
const rows = ref([])
const totalItems = ref(0)
const loading = ref(false)
const page = ref(1)
const pageSize = ref(25)
const ordering = ref('drug_a')

const editor = reactive({
  show: false,
  saving: false,
  form: emptyForm(),
})
const del = reactive({ show: false, row: null, busy: false })
const snack = reactive({ show: false, text: '', color: 'info' })

function emptyForm() {
  return {
    id: null, drug_a: '', drug_b: '',
    severity: 'moderate', summary: '', detail: '',
    references: [], is_active: true,
  }
}

function severityColor(s) {
  return ({
    minor: 'grey', moderate: 'warning',
    major: 'orange', contraindicated: 'error',
  })[s] || 'grey'
}

let searchTimer = null
function debouncedReload() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(reload, 300)
}

function onTableChange(opts) {
  if (opts?.page) page.value = opts.page
  if (opts?.itemsPerPage) pageSize.value = opts.itemsPerPage
  if (opts?.sortBy?.length) {
    const s = opts.sortBy[0]
    ordering.value = (s.order === 'desc' ? '-' : '') + s.key
  }
  reload()
}

async function reload() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    params.set('page', page.value)
    params.set('page_size', pageSize.value)
    if (ordering.value) params.set('ordering', ordering.value)
    if (search.value) params.set('search', search.value)
    if (severityFilter.value) params.set('severity', severityFilter.value)
    if (onlyActive.value) params.set('is_active', 'true')
    const { data } = await $api.get(`/homecare/drug-interactions/?${params.toString()}`)
    if (Array.isArray(data)) {
      rows.value = data
      totalItems.value = data.length
    } else {
      rows.value = data.results || []
      totalItems.value = data.count ?? rows.value.length
    }
  } catch (e) {
    Object.assign(snack, { show: true, text: 'Failed to load interactions', color: 'error' })
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editor.form = emptyForm()
  editor.show = true
}
function openEdit(row) {
  editor.form = {
    id: row.id,
    drug_a: row.drug_a,
    drug_b: row.drug_b,
    severity: row.severity,
    summary: row.summary,
    detail: row.detail || '',
    references: Array.isArray(row.references) ? JSON.parse(JSON.stringify(row.references)) : [],
    is_active: !!row.is_active,
  }
  editor.show = true
}
function addRef() {
  editor.form.references.push({ label: '', url: '' })
}
function confirmDelete(row) {
  del.row = row
  del.show = true
}

async function save() {
  if (!editor.form.drug_a || !editor.form.drug_b || !editor.form.summary) {
    Object.assign(snack, { show: true, text: 'Drug A, Drug B and summary are required', color: 'warning' })
    return
  }
  editor.saving = true
  try {
    const body = {
      drug_a: editor.form.drug_a,
      drug_b: editor.form.drug_b,
      severity: editor.form.severity,
      summary: editor.form.summary,
      detail: editor.form.detail,
      references: (editor.form.references || []).filter(r => r.label || r.url),
      is_active: editor.form.is_active,
    }
    if (editor.form.id) {
      await $api.put(`/homecare/drug-interactions/${editor.form.id}/`, body)
    } else {
      await $api.post(`/homecare/drug-interactions/`, body)
    }
    editor.show = false
    Object.assign(snack, { show: true, text: 'Saved', color: 'success' })
    reload()
  } catch (e) {
    const msg = e?.response?.data?.detail
      || (typeof e?.response?.data === 'object' ? JSON.stringify(e.response.data) : 'Failed to save')
    Object.assign(snack, { show: true, text: msg, color: 'error' })
  } finally {
    editor.saving = false
  }
}

async function doDelete() {
  if (!del.row?.id) return
  del.busy = true
  try {
    await $api.delete(`/homecare/drug-interactions/${del.row.id}/`)
    del.show = false
    Object.assign(snack, { show: true, text: 'Deleted', color: 'success' })
    reload()
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to delete', color: 'error' })
  } finally {
    del.busy = false
  }
}

onMounted(reload)
</script>

<style scoped>
.hc-table :deep(th) {
  background: rgba(0,0,0,0.025);
  font-weight: 600;
}
</style>
