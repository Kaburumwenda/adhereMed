<template>
  <v-container fluid class="pa-3 pa-md-5 iam-roles">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="indigo-lighten-5" variant="tonal" rounded="lg" size="52">
          <v-icon size="28" color="indigo-darken-2">mdi-shield-key</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ $t('nav.rolesPermissions') }}</h1>
          <div class="text-body-2 text-medium-emphasis">
            Manage security roles and the permissions granted to each role within your pharmacy
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg"
               class="text-none" :loading="loading" @click="loadRoles">{{ $t('common.refresh') }}</v-btn>
        <v-btn color="primary" prepend-icon="mdi-shield-plus" rounded="lg"
               class="text-none" @click="openCreate">{{ $t('roles.newRole') }}</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <v-card rounded="lg" flat class="pa-4 h-100 kpi-card">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Total Roles</div>
              <div class="text-h6 font-weight-bold mt-1">{{ roles.length }}</div>
            </div>
            <v-avatar color="indigo" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-shield-account-outline</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" flat class="pa-4 h-100 kpi-card">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Assigned Users</div>
              <div class="text-h6 font-weight-bold mt-1">{{ totalUsers }}</div>
            </div>
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-account-group</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" flat class="pa-4 h-100 kpi-card">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Permissions Granted</div>
              <div class="text-h6 font-weight-bold mt-1">{{ totalGranted }}</div>
            </div>
            <v-avatar color="success" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-shield-check</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" flat class="pa-4 h-100 kpi-card">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Available Permissions</div>
              <div class="text-h6 font-weight-bold mt-1">{{ permissions.length }}</div>
            </div>
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-key-variant</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Toolbar -->
    <v-card flat rounded="xl" class="pa-3 mb-3">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search roles…"
          density="comfortable" variant="solo-filled" flat hide-details clearable
          style="min-width: 240px; max-width: 360px; flex:1"
        />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">
          {{ filtered.length }} of {{ roles.length }}
        </span>
      </div>
    </v-card>

    <!-- Roles table -->
    <v-card flat rounded="xl" border>
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="loading"
        :items-per-page="20"
        density="comfortable"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar color="indigo-lighten-4" variant="tonal" size="32" class="mr-3">
              <v-icon size="18" color="indigo-darken-2">mdi-shield-account</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ (item.permission_details || item.permissions || []).length }} permission{{ (item.permission_details || item.permissions || []).length === 1 ? '' : 's' }}
              </div>
            </div>
          </div>
        </template>

        <template #item.user_count="{ item }">
          <v-chip size="small" variant="tonal" color="primary">
            <v-icon start size="14">mdi-account</v-icon>
            {{ item.user_count || 0 }} user{{ (item.user_count || 0) === 1 ? '' : 's' }}
          </v-chip>
        </template>

        <template #item.permissions_preview="{ item }">
          <div class="d-flex flex-wrap ga-1">
            <v-chip v-for="p in (item.permission_details || item.permissions || []).slice(0, 3)" :key="p.id || p" size="x-small" variant="outlined" color="success">
              {{ p.name || p.codename || `#${p}` }}
            </v-chip>
            <v-chip v-if="(item.permission_details || item.permissions || []).length > 3" size="x-small" variant="tonal" color="grey">
              +{{ (item.permission_details || item.permissions || []).length - 3 }} more
            </v-chip>
            <span v-if="!(item.permission_details || item.permissions || []).length" class="text-caption text-medium-emphasis">No permissions</span>
          </div>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end">
            <v-tooltip text="Edit">
              <template #activator="{ props }">
                <v-btn icon="mdi-pencil" variant="text" size="small" v-bind="props" @click.stop="openEdit(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Manage permissions">
              <template #activator="{ props }">
                <v-btn icon="mdi-shield-key" variant="text" size="small" color="success"
                       v-bind="props" @click.stop="openPermissions(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Delete">
              <template #activator="{ props }">
                <v-btn icon="mdi-delete" variant="text" size="small" color="error"
                       v-bind="props" @click.stop="confirmDelete(item)" />
              </template>
            </v-tooltip>
          </div>
        </template>

        <template #no-data>
          <EmptyState
            icon="mdi-shield-plus-outline"
            title="No roles yet"
            message="Create your first role to control what your team can access."
          />
        </template>
      </v-data-table>
    </v-card>

    <!-- ───────────────────────────────────────────────────────────── -->
    <!-- Create / Edit dialog                                            -->
    <!-- ───────────────────────────────────────────────────────────── -->
    <v-dialog v-model="formDialog" max-width="560" persistent>
      <v-card rounded="xl" class="pa-1">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">{{ formMode === 'create' ? 'mdi-shield-plus' : 'mdi-shield-edit' }}</v-icon>
          {{ formMode === 'create' ? $t('roles.newRole') : $t('roles.editRole') }}
        </v-card-title>
        <v-card-text>
          <v-form ref="formRef" @submit.prevent="saveRole">
            <v-text-field
              v-model="form.name"
              :label="$t('roles.roleName')"
              prepend-inner-icon="mdi-shield-account"
              variant="outlined"
              density="comfortable"
              :rules="[v => !!v || 'Role name is required', v => (v && v.length >= 3) || 'At least 3 characters']"
              :error-messages="formError"
            />
            <v-alert v-if="formError" type="error" variant="tonal" density="compact" class="mt-2">
              {{ formError }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="formDialog = false">
            {{ $t('common.cancel') }}
          </v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving" @click="saveRole">
            <v-icon start>mdi-content-save</v-icon>
            {{ $t('common.save') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────────────────────────────────────────────────────── -->
    <!-- Permissions assignment dialog                                   -->
    <!-- ───────────────────────────────────────────────────────────── -->
    <v-dialog v-model="permDialog" max-width="900" persistent>
      <v-card rounded="xl" class="pa-1">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="success">mdi-shield-key</v-icon>
          {{ $t('roles.managePermissions') }} — {{ editingRole?.name }}
        </v-card-title>
        <v-card-text>
          <v-text-field
            v-model="permSearch"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search permissions…"
            variant="outlined" density="compact" hide-details clearable
            class="mb-3"
          />
          <div class="d-flex align-center mb-3" style="gap:10px">
            <v-btn size="small" variant="tonal" color="primary" prepend-icon="mdi-check-all"
                   @click="selectAllFiltered">Select visible</v-btn>
            <v-btn size="small" variant="tonal" color="grey" prepend-icon="mdi-close"
                   @click="clearSelection">Clear</v-btn>
            <v-spacer />
            <span class="text-caption text-medium-emphasis">
              {{ selectedPermIds.length }} selected
            </span>
          </div>

          <div class="perm-scroll">
            <template v-for="group in groupedPermissions" :key="group.app">
              <div class="d-flex align-center mb-1 mt-2">
                <v-btn size="x-small" variant="text" prepend-icon="mdi-chevron-down"
                       @click="toggleGroup(group.app)">
                  <span class="text-subtitle-2 font-weight-bold">{{ group.app }}</span>
                  <span class="text-caption ml-2 text-medium-emphasis">
                    ({{ countSelectedInGroup(group.app) }}/{{ group.items.length }})
                  </span>
                </v-btn>
              </div>
              <v-data-table
                v-if="expandedGroups.has(group.app)"
                :headers="permHeaders"
                :items="group.items"
                :items-per-page="-1"
                density="compact"
                hide-default-header
                hide-default-footer
                class="mb-2"
              >
                <template #item.selected="{ item }">
                  <v-checkbox-btn v-model="selectedPermSet" :value="item.id" />
                </template>
                <template #item.name="{ item }">
                  <span class="text-body-2">{{ item.name }}</span>
                  <span class="text-caption text-medium-emphasis ml-2">[{{ item.codename }}]</span>
                </template>
                <template #item.model="{ item }">
                  <v-chip size="x-small" variant="tonal" color="info">{{ item.model }}</v-chip>
                </template>
              </v-data-table>
            </template>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="permDialog = false">
            {{ $t('common.cancel') }}
          </v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingPermissions"
                 @click="savePermissions">
            <v-icon start>mdi-content-save</v-icon>
            {{ $t('common.save') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────────────────────────────────────────────────────── -->
    <!-- Delete confirm                                                  -->
    <!-- ───────────────────────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="440">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="error">mdi-alert</v-icon>
          {{ $t('common.delete') }} {{ deleteTarget?.name }}?
        </v-card-title>
        <v-card-text>
          {{ $t('roles.deleteConfirm') }}
          <div v-if="deleteTarget && (deleteTarget.user_count || 0) > 0" class="mt-3">
            <v-alert type="warning" variant="tonal" density="compact">
              {{ deleteTarget.user_count }} user{{ deleteTarget.user_count === 1 ? '' : 's' }} currently assigned to this role will lose these permissions.
            </v-alert>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteDialog = false">
            {{ $t('common.cancel') }}
          </v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="saving" @click="doDelete">
            <v-icon start>mdi-delete</v-icon>
            {{ $t('common.delete') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { computed, ref, reactive, onMounted } from 'vue'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()

// ── state ───────────────────────────────────────────────────────────
const roles = ref([])
const permissions = ref([])
const loading = ref(false)
const saving = ref(false)
const savingPermissions = ref(false)
const search = ref('')

const headers = [
  { title: 'Role', key: 'name', sortable: true },
  { title: 'Users', key: 'user_count', sortable: true, width: 120 },
  { title: 'Permissions', key: 'permissions_preview', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

const permHeaders = [
  { title: '', key: 'selected', sortable: false, width: 50 },
  { title: 'Permission', key: 'name', sortable: false },
  { title: 'Model', key: 'model', sortable: false, width: 140 },
]

// dialogs
const formDialog = ref(false)
const formMode = ref('create')
const form = reactive({ id: null, name: '' })
const formError = ref('')
const formRef = ref(null)

const permDialog = ref(false)
const permSearch = ref('')
const editingRole = ref(null)
const selectedPermIds = ref([])
const selectedPermSet = ref([])
const expandedGroups = ref(new Set(['accounts']))

const deleteDialog = ref(false)
const deleteTarget = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })
function showSnack(text, color = 'success') {
  snack.text = text
  snack.color = color
  snack.show = true
}

// ── computed ────────────────────────────────────────────────────────
const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return roles.value
  return roles.value.filter(r => (r.name || '').toLowerCase().includes(q))
})

const totalUsers = computed(() =>
  roles.value.reduce((sum, r) => sum + (r.user_count || 0), 0)
)

const totalGranted = computed(() =>
  roles.value.reduce((sum, r) => sum + (r.permissions || []).length, 0)
)

const filteredPermissions = computed(() => {
  const q = permSearch.value.trim().toLowerCase()
  if (!q) return permissions.value
  return permissions.value.filter(p =>
    (p.name || '').toLowerCase().includes(q) ||
    (p.codename || '').toLowerCase().includes(q) ||
    (p.model || '').toLowerCase().includes(q) ||
    (p.app_label || '').toLowerCase().includes(q)
  )
})

const groupedPermissions = computed(() => {
  const groups = {}
  for (const p of filteredPermissions.value) {
    const app = p.app_label || 'other'
    if (!groups[app]) groups[app] = { app, items: [] }
    groups[app].items.push(p)
  }
  return Object.values(groups).sort((a, b) => a.app.localeCompare(b.app))
})

function countSelectedInGroup(app) {
  return (groupedPermissions.value.find(g => g.app === app)?.items || [])
    .filter(i => selectedPermSet.value.includes(i.id)).length
}

function toggleGroup(app) {
  const s = new Set(expandedGroups.value)
  if (s.has(app)) s.delete(app)
  else s.add(app)
  expandedGroups.value = s
}

// ── permissions map ─────────────────────────────────────────────────

// ── API ──────────────────────────────────────────────────────────────
async function loadRoles() {
  loading.value = true
  try {
    const { data } = await $api.get('/auth/roles/', { params: { page_size: 500 } })
    roles.value = data?.results || data || []
    // hydrate permission ids -> objects for preview if they come as objects
    for (const r of roles.value) {
      if (!r.permissions) r.permissions = []
    }
  } catch {
    roles.value = []
    showSnack('Failed to load roles', 'error')
  } finally {
    loading.value = false
  }
}

async function loadPermissions() {
  try {
    const { data } = await $api.get('/auth/permissions/')
    permissions.value = data?.results || data || []
  } catch {
    permissions.value = []
  }
}

// ── create/edit ────────────────────────────────────────────────────
function openCreate() {
  formMode.value = 'create'
  form.id = null
  form.name = ''
  formError.value = ''
  formDialog.value = true
}

function openEdit(item) {
  formMode.value = 'edit'
  form.id = item.id
  form.name = item.name
  formError.value = ''
  formDialog.value = true
}

async function saveRole() {
  if (!form.name || form.name.trim().length < 3) {
    formError.value = 'Role name must be at least 3 characters'
    return
  }
  saving.value = true
  formError.value = ''
  try {
    if (formMode.value === 'create') {
      const { data } = await $api.post('/auth/roles/', { name: form.name.trim() })
      roles.value.push({ ...data, permissions: [], user_count: 0 })
      showSnack(`Role "${data.name}" created`)
    } else {
      const { data } = await $api.patch(`/auth/roles/${form.id}/`, { name: form.name.trim() })
      const idx = roles.value.findIndex(r => r.id === form.id)
      if (idx >= 0) roles.value[idx] = { ...roles.value[idx], name: data.name }
      showSnack('Role updated')
    }
    formDialog.value = false
  } catch (e) {
    formError.value = e?.response?.data?.name?.[0]
      || e?.response?.data?.detail
      || 'Failed to save role'
  } finally {
    saving.value = false
  }
}

// ── permissions dialog ────────────────────────────────────────────
function openPermissions(item) {
  editingRole.value = item
  permSearch.value = ''
  // Ensure we have full permission list
  loadPermissions().then(() => {
    const perms = item.permission_details?.length ? item.permission_details : (item.permissions || [])
    selectedPermSet.value = perms.map(p => (typeof p === 'object' ? p.id : p))
    selectedPermIds.value = [...selectedPermSet.value]
    expandedGroups.value = new Set(groupedPermissions.value.slice(0, 5).map(g => g.app))
    permDialog.value = true
  })
}

function selectAllVisible() {
  const set = new Set(selectedPermSet.value)
  for (const p of filteredPermissions.value) set.add(p.id)
  selectedPermSet.value = Array.from(set)
}

function clearSelection() {
  selectedPermSet.value = []
}

async function savePermissions() {
  savingPermissions.value = true
  try {
    const { data } = await $api.patch(`/auth/roles/${editingRole.value.id}/`, {
      permissions: selectedPermSet.value,
    })
    const idx = roles.value.findIndex(r => r.id === editingRole.value.id)
    if (idx >= 0) {
      roles.value[idx].permissions = data.permissions || selectedPermSet.value
      roles.value[idx].permission_details = data.permission_details || []
    }
    showSnack(`${data.name || 'Role'} permissions updated`)
    permDialog.value = false
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to update permissions', 'error')
  } finally {
    savingPermissions.value = false
  }
}

// ── delete ────────────────────────────────────────────────────────
function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}

async function doDelete() {
  if (!deleteTarget.value) return
  saving.value = true
  try {
    await $api.delete(`/auth/roles/${deleteTarget.value.id}/`)
    roles.value = roles.value.filter(r => r.id !== deleteTarget.value.id)
    showSnack(`Role "${deleteTarget.value.name}" deleted`)
    deleteDialog.value = false
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to delete role', 'error')
  } finally {
    saving.value = false
  }
}

// ── lifecycle ────────────────────────────────────────────────────
onMounted(() => {
  loadRoles()
  loadPermissions()
})
</script>

<style scoped>
.kpi-card {
  border: 1px solid rgba(0, 0, 0, 0.06);
}
.perm-scroll {
  max-height: 480px;
  overflow-y: auto;
  padding-right: 4px;
}
</style>
