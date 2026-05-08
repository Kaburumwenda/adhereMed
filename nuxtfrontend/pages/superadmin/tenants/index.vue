<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Tenants" icon="mdi-domain" :subtitle="subtitle">
      <template #actions>
        <v-btn
          color="primary"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-plus"
          to="/superadmin/tenants/new"
        >New Tenant</v-btn>
      </template>
    </PageHeader>

    <!-- Filters -->
    <v-card rounded="lg" class="mb-4">
      <v-card-text class="pb-2">
        <v-row dense>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="r.search.value"
              prepend-inner-icon="mdi-magnify"
              placeholder="Search by name, city, or email…"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              @update:model-value="onSearch"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-select
              v-model="typeFilter"
              :items="typeOptions"
              label="Type"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              @update:model-value="reload"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-select
              v-model="statusFilter"
              :items="statusOptions"
              label="Status"
              variant="outlined"
              density="compact"
              hide-details
              clearable
            />
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- Stats strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Total</div>
          <div class="text-h6 font-weight-bold">{{ totals.total }}</div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Active</div>
          <div class="text-h6 font-weight-bold text-success">{{ totals.active }}</div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Inactive</div>
          <div class="text-h6 font-weight-bold text-medium-emphasis">{{ totals.inactive }}</div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Users</div>
          <div class="text-h6 font-weight-bold">{{ totals.users }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Table -->
    <v-card rounded="lg">
      <v-data-table
        :headers="headers"
        :items="visibleItems"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        class="elevation-0"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template #item.name="{ item }">
          <div class="d-flex align-center ga-2 py-1">
            <v-avatar size="32" :color="typeColor(item.type)" variant="tonal">
              <v-icon size="18">{{ typeIcon(item.type) }}</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.slug }}</div>
            </div>
          </div>
        </template>

        <template #item.type="{ value }">
          <v-chip size="small" variant="tonal" :color="typeColor(value)" class="text-capitalize">
            {{ value }}
          </v-chip>
        </template>

        <template #item.domains="{ item }">
          <span class="text-caption">{{ primaryDomain(item) || '—' }}</span>
        </template>

        <template #item.user_count="{ value }">
          <v-chip size="x-small" variant="tonal">{{ value ?? 0 }}</v-chip>
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
              icon="mdi-chart-box-outline"
              variant="text"
              size="small"
              :title="`View stats for ${item.name}`"
              @click.stop="openStats(item)"
            />
            <v-btn
              icon="mdi-pencil"
              variant="text"
              size="small"
              title="Edit"
              :to="`/superadmin/tenants/${item.id}/edit`"
            />
            <v-btn
              :icon="item.is_active ? 'mdi-pause-circle-outline' : 'mdi-play-circle-outline'"
              variant="text"
              size="small"
              :color="item.is_active ? 'warning' : 'success'"
              :title="item.is_active ? 'Deactivate' : 'Activate'"
              :loading="toggling === item.id"
              @click.stop="toggleActive(item)"
            />
          </div>
        </template>

        <template #no-data>
          <EmptyState
            icon="mdi-domain-off"
            title="No tenants found"
            message="Adjust filters or create a new tenant to get started."
          />
        </template>
      </v-data-table>
    </v-card>

    <!-- Stats dialog -->
    <v-dialog v-model="statsDialog.show" max-width="520">
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-chart-box-outline" class="mr-2" color="primary" />
          {{ statsDialog.tenant?.name }} — Stats
        </v-card-title>
        <v-card-text>
          <div v-if="statsDialog.loading" class="d-flex justify-center py-6">
            <v-progress-circular indeterminate color="primary" />
          </div>
          <div v-else-if="statsDialog.error" class="text-error">{{ statsDialog.error }}</div>
          <div v-else-if="statsDialog.data">
            <v-row dense class="mb-2">
              <v-col cols="6">
                <v-card variant="outlined" class="pa-3">
                  <div class="text-caption text-medium-emphasis">Total Users</div>
                  <div class="text-h6 font-weight-bold">{{ statsDialog.data.users.total }}</div>
                </v-card>
              </v-col>
              <v-col cols="6">
                <v-card variant="outlined" class="pa-3">
                  <div class="text-caption text-medium-emphasis">Active Users</div>
                  <div class="text-h6 font-weight-bold text-success">{{ statsDialog.data.users.active }}</div>
                </v-card>
              </v-col>
            </v-row>
            <div class="text-subtitle-2 mt-3 mb-1">By Role</div>
            <v-list density="compact" class="pa-0">
              <v-list-item
                v-for="row in statsDialog.data.users.by_role"
                :key="row.role"
                class="px-0"
              >
                <template #prepend>
                  <v-icon size="16" class="mr-2">mdi-account</v-icon>
                </template>
                <v-list-item-title class="text-capitalize">
                  {{ String(row.role).replace(/_/g, ' ') }}
                </v-list-item-title>
                <template #append>
                  <v-chip size="x-small" variant="tonal">{{ row.count }}</v-chip>
                </template>
              </v-list-item>
              <v-list-item v-if="!statsDialog.data.users.by_role?.length" class="px-0">
                <v-list-item-title class="text-medium-emphasis text-caption">No users yet.</v-list-item-title>
              </v-list-item>
            </v-list>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="statsDialog.show = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'

const { $api } = useNuxtApp()
const r = useResource('/superadmin/tenants/')

const headers = [
  { title: 'Tenant', key: 'name' },
  { title: 'Type', key: 'type' },
  { title: 'Domain', key: 'domains', sortable: false },
  { title: 'Users', key: 'user_count', align: 'center' },
  { title: 'Status', key: 'is_active' },
  { title: 'Created', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 }
]

const typeOptions = [
  { title: 'Hospital', value: 'hospital' },
  { title: 'Pharmacy', value: 'pharmacy' },
  { title: 'Lab', value: 'lab' },
  { title: 'Homecare', value: 'homecare' }
]

const statusOptions = [
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' }
]

const typeFilter = ref(null)
const statusFilter = ref(null)
const toggling = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })
const statsDialog = reactive({ show: false, tenant: null, loading: false, error: '', data: null })

let searchTimer = null
function onSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(reload, 250)
}

async function reload() {
  const params = {}
  if (r.search.value) params.q = r.search.value
  if (typeFilter.value) params.type = typeFilter.value
  await r.list(params)
}

const visibleItems = computed(() => {
  const base = r.filtered.value
  if (!statusFilter.value) return base
  const want = statusFilter.value === 'active'
  return base.filter((t) => !!t.is_active === want)
})

const totals = computed(() => {
  const items = r.items.value
  const active = items.filter((t) => t.is_active).length
  const users = items.reduce((s, t) => s + (t.user_count || 0), 0)
  return {
    total: items.length,
    active,
    inactive: items.length - active,
    users
  }
})

const subtitle = computed(() => `${totals.value.total} tenant${totals.value.total === 1 ? '' : 's'}`)

function primaryDomain(t) {
  const list = t.domains || []
  const primary = list.find((d) => d.is_primary) || list[0]
  return primary?.domain || ''
}

function typeIcon(type) {
  return type === 'pharmacy' ? 'mdi-pill' : type === 'lab' ? 'mdi-test-tube' : type === 'homecare' ? 'mdi-home-heart' : 'mdi-hospital-building'
}

function typeColor(type) {
  return type === 'pharmacy' ? 'secondary' : type === 'lab' ? 'warning' : type === 'homecare' ? 'teal' : 'primary'
}

function formatDate(v) {
  if (!v) return '—'
  try {
    return new Date(v).toLocaleDateString()
  } catch {
    return String(v)
  }
}

async function toggleActive(item) {
  toggling.value = item.id
  try {
    const { data } = await $api.post(`/superadmin/tenants/${item.id}/toggle-active/`)
    item.is_active = data.is_active
    snack.text = `${item.name} is now ${data.is_active ? 'active' : 'inactive'}`
    snack.color = data.is_active ? 'success' : 'warning'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to update tenant status'
    snack.color = 'error'
    snack.show = true
  } finally {
    toggling.value = null
  }
}

async function openStats(tenant) {
  statsDialog.tenant = tenant
  statsDialog.show = true
  statsDialog.loading = true
  statsDialog.error = ''
  statsDialog.data = null
  try {
    const { data } = await $api.get(`/superadmin/tenants/${tenant.id}/stats/`)
    statsDialog.data = data
  } catch (e) {
    statsDialog.error = e?.response?.data?.detail || 'Failed to load tenant stats.'
  } finally {
    statsDialog.loading = false
  }
}

onMounted(reload)
</script>
