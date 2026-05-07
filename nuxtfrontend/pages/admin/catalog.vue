<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Catalog Manager" icon="mdi-bookshelf" subtitle="Manage organisation-wide lookups and taxonomies">
      <template #actions>
        <v-btn
          color="primary" rounded="lg" prepend-icon="mdi-plus" class="text-none"
          :disabled="!tenantSchema"
          @click="openCreate"
        >
          New {{ activeCatalog.singular }}
        </v-btn>
      </template>
    </PageHeader>

    <!-- Tenant scope -->
    <v-card rounded="xl" elevation="0" class="mb-4 toolbar-card">
      <div class="d-flex flex-wrap align-center pa-3" style="gap: 12px">
        <v-icon color="primary">mdi-domain</v-icon>
        <div class="text-body-2">
          <div class="font-weight-medium">Tenant scope</div>
          <div class="text-caption text-medium-emphasis">Catalogs are tenant-scoped. Pick which hospital you're editing.</div>
        </div>
        <v-spacer />
        <v-select
          v-model="tenantSchema"
          :items="tenantOptions"
          item-title="label" item-value="value"
          :loading="tenantsLoading"
          density="comfortable" variant="solo-filled" rounded="lg" hide-details
          flat
          prepend-inner-icon="mdi-domain"
          placeholder="Select tenant…"
          style="min-width: 280px; max-width: 380px"
        />
      </div>
    </v-card>

    <!-- Catalog tabs -->
    <v-card rounded="xl" elevation="0" class="mb-4 catalog-tabs-card">
      <v-tabs
        v-model="activeKey"
        bg-color="transparent"
        color="primary"
        align-tabs="start"
        show-arrows
        density="comfortable"
      >
        <v-tab
          v-for="c in catalogs"
          :key="c.key"
          :value="c.key"
          class="text-none"
        >
          <v-icon size="18" class="mr-2">{{ c.icon }}</v-icon>
          {{ c.label }}
          <v-chip size="x-small" class="ml-2" variant="tonal" :color="c.color">
            {{ counts[c.key] ?? '—' }}
          </v-chip>
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Toolbar -->
    <v-card rounded="xl" elevation="0" class="mb-4 toolbar-card">
      <div class="d-flex flex-wrap align-center pa-3" style="gap: 12px">
        <v-text-field
          v-model="search"
          placeholder="Search…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable" variant="solo-filled" rounded="lg" hide-details
          flat clearable
          style="min-width: 240px; max-width: 360px; flex: 1"
        />
        <v-spacer />
        <v-btn
          variant="text" rounded="lg" class="text-none"
          prepend-icon="mdi-refresh"
          :loading="loading"
          @click="loadActive"
        >
          Refresh
        </v-btn>
      </div>
    </v-card>

    <!-- Data table -->
    <v-card rounded="xl" elevation="0">
      <v-progress-linear v-if="loading" color="primary" indeterminate height="3" />
      <div v-if="!tenantSchema" class="pa-10 text-center">
        <v-avatar size="72" color="primary" variant="tonal" class="mb-3">
          <v-icon size="36">mdi-domain</v-icon>
        </v-avatar>
        <div class="text-h6 mb-1">Pick a tenant to begin</div>
        <div class="text-body-2 text-medium-emphasis">
          These catalogs live inside each tenant's schema, so choose which one you want to manage above.
        </div>
      </div>
      <v-data-table
        v-else
        :headers="activeHeaders"
        :items="filteredItems"
        :items-per-page="25"
        :items-per-page-options="[10, 25, 50, 100]"
        density="comfortable"
        class="catalog-table"
        no-data-text="Nothing in this catalog yet."
      >
        <template #item.is_active="{ item }">
          <v-chip :color="item.is_active ? 'success' : 'grey'" size="small" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.created_at="{ item }">
          <span class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" style="gap: 4px">
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn
                  v-bind="props"
                  icon="mdi-pencil"
                  variant="text" size="small" color="primary"
                  @click="openEdit(item)"
                />
              </template>
            </v-tooltip>
            <v-tooltip text="Delete" location="top">
              <template #activator="{ props }">
                <v-btn
                  v-bind="props"
                  icon="mdi-trash-can"
                  variant="text" size="small" color="error"
                  @click="askDelete(item)"
                />
              </template>
            </v-tooltip>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create / edit dialog -->
    <v-dialog v-model="dialog" max-width="560" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-avatar :color="activeCatalog.color" variant="tonal" rounded="lg" size="40" class="mr-3">
            <v-icon>{{ activeCatalog.icon }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-subtitle-1 font-weight-bold">
              {{ editing ? `Edit ${activeCatalog.singular}` : `New ${activeCatalog.singular}` }}
            </div>
            <div class="text-caption text-medium-emphasis">{{ activeCatalog.label }}</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-form ref="formRef" v-model="formValid" @submit.prevent="save">
            <component
              :is="'div'"
              v-for="field in activeCatalog.fields"
              :key="field.key"
              class="mb-3"
            >
              <v-textarea
                v-if="field.type === 'textarea'"
                v-model="form[field.key]"
                :label="field.label"
                rows="2" auto-grow
                variant="outlined" density="comfortable" hide-details="auto"
              />
              <v-switch
                v-else-if="field.type === 'switch'"
                v-model="form[field.key]"
                :label="field.label"
                color="success" inset hide-details
              />
              <v-text-field
                v-else
                v-model="form[field.key]"
                :label="field.label"
                :type="field.type === 'email' ? 'email' : 'text'"
                :rules="field.required ? [v => !!v || `${field.label} is required`] : []"
                variant="outlined" density="comfortable" hide-details="auto"
              />
            </component>
          </v-form>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" :disabled="saving" @click="dialog = false">
            Cancel
          </v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving" @click="save">
            {{ editing ? 'Save changes' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="confirmDel" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete {{ activeCatalog.singular.toLowerCase() }}?</v-card-title>
        <v-card-text class="text-medium-emphasis">
          You're about to remove <strong>{{ deleteTarget?.[activeCatalog.titleKey || 'name'] }}</strong>.
          This cannot be undone.
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="confirmDel = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="deleting" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="3000" location="bottom right" rounded="pill">
      <v-icon class="mr-2">{{ snack.icon }}</v-icon>
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, reactive, watch, onMounted } from 'vue'

const { $api } = useNuxtApp()

const tenants = ref([])
const tenantsLoading = ref(false)
const tenantSchema = ref(null)

const tenantOptions = computed(() => tenants.value.map(t => ({
  label: `${t.name}${t.type ? ` · ${t.type}` : ''}`,
  value: t.schema_name
})))

function reqConfig(extra = {}) {
  const headers = { ...(extra.headers || {}) }
  if (tenantSchema.value) headers['X-Tenant-Schema'] = tenantSchema.value
  return { ...extra, headers }
}

const catalogs = [
  {
    key: 'departments', label: 'Departments', singular: 'Department',
    icon: 'mdi-domain', color: 'primary',
    endpoint: '/departments/',
    headers: [
      { title: 'Name', key: 'name' },
      { title: 'Description', key: 'description' },
      { title: 'Head', key: 'head_name' },
      { title: 'Status', key: 'is_active' },
      { title: 'Created', key: 'created_at' },
      { title: '', key: 'actions', sortable: false, align: 'end' }
    ],
    fields: [
      { key: 'name', label: 'Name', required: true },
      { key: 'description', label: 'Description', type: 'textarea' },
      { key: 'is_active', label: 'Active', type: 'switch' }
    ],
    defaults: { name: '', description: '', is_active: true }
  },
  {
    key: 'specializations', label: 'Specializations', singular: 'Specialization',
    icon: 'mdi-stethoscope', color: 'info',
    endpoint: '/staff/specializations/',
    headers: [
      { title: 'Name', key: 'name' },
      { title: 'Description', key: 'description' },
      { title: 'Status', key: 'is_active' },
      { title: 'Created', key: 'created_at' },
      { title: '', key: 'actions', sortable: false, align: 'end' }
    ],
    fields: [
      { key: 'name', label: 'Name', required: true },
      { key: 'description', label: 'Description', type: 'textarea' },
      { key: 'is_active', label: 'Active', type: 'switch' }
    ],
    defaults: { name: '', description: '', is_active: true }
  },
  {
    key: 'categories', label: 'Inventory Categories', singular: 'Category',
    icon: 'mdi-tag', color: 'success',
    endpoint: '/inventory/categories/',
    headers: [
      { title: 'Name', key: 'name' },
      { title: 'Description', key: 'description' },
      { title: 'Created', key: 'created_at' },
      { title: '', key: 'actions', sortable: false, align: 'end' }
    ],
    fields: [
      { key: 'name', label: 'Name', required: true },
      { key: 'description', label: 'Description', type: 'textarea' }
    ],
    defaults: { name: '', description: '' }
  },
  {
    key: 'units', label: 'Units of Measure', singular: 'Unit',
    icon: 'mdi-ruler', color: 'warning',
    endpoint: '/inventory/units/',
    headers: [
      { title: 'Name', key: 'name' },
      { title: 'Abbreviation', key: 'abbreviation' },
      { title: 'Created', key: 'created_at' },
      { title: '', key: 'actions', sortable: false, align: 'end' }
    ],
    fields: [
      { key: 'name', label: 'Name', required: true },
      { key: 'abbreviation', label: 'Abbreviation' }
    ],
    defaults: { name: '', abbreviation: '' }
  },
  {
    key: 'suppliers', label: 'Suppliers', singular: 'Supplier',
    icon: 'mdi-truck', color: 'purple',
    endpoint: '/suppliers/',
    headers: [
      { title: 'Name', key: 'name' },
      { title: 'Contact', key: 'contact_person' },
      { title: 'Phone', key: 'phone' },
      { title: 'Email', key: 'email' },
      { title: 'Status', key: 'is_active' },
      { title: '', key: 'actions', sortable: false, align: 'end' }
    ],
    fields: [
      { key: 'name', label: 'Name', required: true },
      { key: 'contact_person', label: 'Contact person' },
      { key: 'phone', label: 'Phone' },
      { key: 'email', label: 'Email', type: 'email' },
      { key: 'address', label: 'Address', type: 'textarea' },
      { key: 'payment_terms', label: 'Payment terms' },
      { key: 'is_active', label: 'Active', type: 'switch' }
    ],
    defaults: { name: '', contact_person: '', phone: '', email: '', address: '', payment_terms: '', is_active: true }
  }
]

const activeKey = ref('departments')
const items = ref([])
const counts = reactive({})
const loading = ref(false)
const search = ref('')

const dialog = ref(false)
const editing = ref(null)
const form = reactive({})
const formRef = ref(null)
const formValid = ref(true)
const saving = ref(false)

const confirmDel = ref(false)
const deleteTarget = ref(null)
const deleting = ref(false)

const snack = ref({ show: false, text: '', color: 'success', icon: 'mdi-check-circle' })

const activeCatalog = computed(() => catalogs.find(c => c.key === activeKey.value) || catalogs[0])
const activeHeaders = computed(() => activeCatalog.value.headers)

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  if (!q) return items.value
  return items.value.filter(it => Object.values(it).some(v =>
    v != null && String(v).toLowerCase().includes(q)
  ))
})

function formatDate(s) {
  if (!s) return '—'
  try { return new Date(s).toLocaleDateString() } catch { return s }
}

function notify(text, color = 'success', icon = 'mdi-check-circle') {
  snack.value = { show: true, text, color, icon }
}

async function loadActive() {
  if (!tenantSchema.value) {
    items.value = []
    return
  }
  loading.value = true
  try {
    const { data } = await $api.get(activeCatalog.value.endpoint, reqConfig({ params: { page_size: 1000 } }))
    const list = data?.results ?? data ?? []
    items.value = list
    counts[activeKey.value] = list.length
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to load', 'error', 'mdi-alert')
    items.value = []
  } finally {
    loading.value = false
  }
}

async function loadCounts() {
  if (!tenantSchema.value) {
    catalogs.forEach(c => { counts[c.key] = '—' })
    return
  }
  await Promise.all(catalogs.map(async c => {
    try {
      const { data } = await $api.get(c.endpoint, reqConfig({ params: { page_size: 1 } }))
      counts[c.key] = data?.count ?? (Array.isArray(data) ? data.length : (data?.results?.length ?? 0))
    } catch {
      counts[c.key] = 0
    }
  }))
}

async function loadTenants() {
  tenantsLoading.value = true
  try {
    const { data } = await $api.get('/tenants/', { params: { page_size: 200 } })
    const list = data?.results ?? data ?? []
    tenants.value = list.filter(t => t.schema_name && t.schema_name !== 'public')
    if (!tenantSchema.value && tenants.value.length === 1) {
      tenantSchema.value = tenants.value[0].schema_name
    }
  } catch (e) {
    notify('Failed to load tenants', 'error', 'mdi-alert')
  } finally {
    tenantsLoading.value = false
  }
}

function resetForm() {
  Object.keys(form).forEach(k => delete form[k])
  Object.assign(form, JSON.parse(JSON.stringify(activeCatalog.value.defaults)))
}

function openCreate() {
  editing.value = null
  resetForm()
  dialog.value = true
}

function openEdit(item) {
  editing.value = item
  resetForm()
  activeCatalog.value.fields.forEach(f => {
    form[f.key] = item[f.key] ?? activeCatalog.value.defaults[f.key]
  })
  dialog.value = true
}

async function save() {
  if (formRef.value) {
    const { valid } = await formRef.value.validate()
    if (!valid) return
  }
  saving.value = true
  try {
    const payload = {}
    activeCatalog.value.fields.forEach(f => { payload[f.key] = form[f.key] })
    if (editing.value) {
      await $api.patch(`${activeCatalog.value.endpoint}${editing.value.id}/`, payload, reqConfig())
      notify(`${activeCatalog.value.singular} updated.`)
    } else {
      await $api.post(activeCatalog.value.endpoint, payload, reqConfig())
      notify(`${activeCatalog.value.singular} created.`)
    }
    dialog.value = false
    await loadActive()
  } catch (e) {
    const msg = e?.response?.data
      ? (typeof e.response.data === 'string' ? e.response.data : JSON.stringify(e.response.data))
      : 'Save failed'
    notify(msg, 'error', 'mdi-alert')
  } finally {
    saving.value = false
  }
}

function askDelete(item) {
  deleteTarget.value = item
  confirmDel.value = true
}

async function doDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await $api.delete(`${activeCatalog.value.endpoint}${deleteTarget.value.id}/`, reqConfig())
    notify(`${activeCatalog.value.singular} deleted.`)
    confirmDel.value = false
    deleteTarget.value = null
    await loadActive()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Delete failed', 'error', 'mdi-alert')
  } finally {
    deleting.value = false
  }
}

watch(activeKey, () => {
  search.value = ''
  loadActive()
})

watch(tenantSchema, () => {
  if (tenantSchema.value) {
    loadActive()
    loadCounts()
  } else {
    items.value = []
  }
})

onMounted(async () => {
  await loadTenants()
  if (tenantSchema.value) {
    await loadActive()
    loadCounts()
  }
})
</script>

<style scoped>
.catalog-tabs-card,
.toolbar-card {
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.04) !important;
}
:deep(.catalog-table .v-data-table__td) {
  padding-top: 10px;
  padding-bottom: 10px;
}
</style>
