<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Organizations" icon="mdi-sitemap" :subtitle="subtitle">
      <template #actions>
        <v-btn
          color="primary"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-plus"
          to="/superadmin/organizations/new"
        >New Organization</v-btn>
      </template>
    </PageHeader>

    <!-- Search -->
    <v-card rounded="lg" class="mb-4">
      <v-card-text class="pb-2">
        <v-text-field
          v-model="search"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search by name…"
          variant="outlined"
          density="compact"
          hide-details
          clearable
          @update:model-value="onSearch"
        />
      </v-card-text>
    </v-card>

    <!-- Table -->
    <v-card rounded="lg">
      <v-data-table
        :headers="headers"
        :items="orgs"
        :loading="loading"
        :items-per-page="20"
        item-value="id"
        class="elevation-0"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template #item.name="{ item }">
          <div class="d-flex align-center ga-2 py-1">
            <v-avatar size="36" color="primary" variant="tonal">
              <v-icon size="20">mdi-sitemap</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.slug }}</div>
            </div>
          </div>
        </template>

        <template #item.tenant_count="{ value }">
          <v-chip size="small" variant="tonal" color="info">{{ value }} linked</v-chip>
        </template>

        <template #item.linked_tenants="{ value }">
          <div class="d-flex flex-wrap ga-1">
            <v-chip
              v-for="t in (value || []).slice(0, 3)"
              :key="t.id"
              size="x-small"
              variant="flat"
              :color="typeColor(t.type)"
            >
              <v-icon start size="12">{{ typeIcon(t.type) }}</v-icon>
              {{ t.name }}
            </v-chip>
            <v-chip v-if="(value || []).length > 3" size="x-small" variant="tonal">
              +{{ value.length - 3 }}
            </v-chip>
          </div>
        </template>

        <template #item.admin_users="{ value }">
          <div v-if="value && value.length" class="text-caption">
            <div v-for="u in value" :key="u.id">{{ u.email }}</div>
          </div>
          <span v-else class="text-caption text-medium-emphasis">—</span>
        </template>

        <template #item.is_active="{ item }">
          <v-chip
            size="small"
            :color="item.is_active ? 'success' : 'grey'"
            variant="tonal"
          >
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>

        <template #item.created_at="{ value }">
          <span class="text-caption">{{ formatDate(value) }}</span>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn
              icon="mdi-eye-outline"
              variant="text"
              size="small"
              title="View & manage"
              :to="`/superadmin/organizations/${item.id}`"
            />
            <v-btn
              icon="mdi-delete-outline"
              variant="text"
              size="small"
              color="error"
              title="Delete"
              :loading="deleting === item.id"
              @click.stop="confirmDelete(item)"
            />
          </div>
        </template>

        <template #no-data>
          <div class="text-center pa-8">
            <v-icon size="48" color="grey-lighten-1">mdi-sitemap-outline</v-icon>
            <p class="text-body-1 text-medium-emphasis mt-2">No organizations yet.</p>
            <v-btn color="primary" rounded="lg" class="text-none mt-3" prepend-icon="mdi-plus" to="/superadmin/organizations/new">
              Create First Organization
            </v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Delete dialog -->
    <v-dialog v-model="deleteDialog.show" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert</v-icon>
          Delete Organization
        </v-card-title>
        <v-card-text>
          Are you sure you want to delete <strong>{{ deleteDialog.org?.name }}</strong>?
          This will unlink all tenants and remove org admin flags from users. The tenants themselves will not be deleted.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

const headers = [
  { title: 'Organization', key: 'name' },
  { title: 'Tenants', key: 'tenant_count', align: 'center' },
  { title: 'Linked', key: 'linked_tenants', sortable: false },
  { title: 'Admins', key: 'admin_users', sortable: false },
  { title: 'Status', key: 'is_active' },
  { title: 'Created', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 120 },
]

const orgs = ref([])
const loading = ref(false)
const search = ref('')
const deleting = ref(null)
const deleteDialog = reactive({ show: false, org: null })
const snack = reactive({ show: false, color: 'success', text: '' })

let searchTimer = null
function onSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(load, 300)
}

const subtitle = computed(() => `${orgs.value.length} organization${orgs.value.length === 1 ? '' : 's'}`)

async function load() {
  loading.value = true
  try {
    const params = {}
    if (search.value) params.q = search.value
    const { data } = await $api.get('/organizations/admin/', { params })
    orgs.value = Array.isArray(data) ? data : (data.results || [])
  } catch (e) {
    snack.text = 'Failed to load organizations'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

function confirmDelete(item) {
  deleteDialog.org = item
  deleteDialog.show = true
}

async function doDelete() {
  const org = deleteDialog.org
  if (!org) return
  deleting.value = org.id
  try {
    await $api.delete(`/organizations/admin/${org.id}/`)
    orgs.value = orgs.value.filter(o => o.id !== org.id)
    snack.text = `${org.name} deleted`
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to delete'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = null
    deleteDialog.show = false
  }
}

function typeIcon(type) {
  return {
    pharmacy: 'mdi-pill', lab: 'mdi-test-tube', homecare: 'mdi-home-heart',
    clinic: 'mdi-stethoscope', radiology_center: 'mdi-radiology',
    inventory: 'mdi-warehouse', hospital: 'mdi-hospital-building',
  }[type] || 'mdi-domain'
}

function typeColor(type) {
  return {
    pharmacy: 'green', lab: 'purple', homecare: 'pink', inventory: 'amber-darken-2',
    clinic: 'teal', hospital: 'red', radiology_center: 'indigo',
  }[type] || 'primary'
}

function formatDate(v) {
  if (!v) return '—'
  try { return new Date(v).toLocaleDateString() } catch { return String(v) }
}

onMounted(load)
</script>
