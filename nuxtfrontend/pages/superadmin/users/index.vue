<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Users" icon="mdi-account-multiple" :subtitle="`${r.count.value} users`">
      <template #actions>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/superadmin/users/new">
          New User
        </v-btn>
      </template>
    </PageHeader>

    <!-- Filters -->
    <v-card rounded="lg" class="mb-4">
      <v-card-text class="pb-2">
        <v-row dense>
          <v-col cols="12" md="4">
            <v-text-field
              v-model="searchQuery"
              prepend-inner-icon="mdi-magnify"
              placeholder="Search by name, email, or phone…"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              @update:model-value="onSearch"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-select
              v-model="roleFilter"
              :items="roleOptions"
              label="Role"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              @update:model-value="reload"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-autocomplete
              v-model="tenantFilter"
              :items="tenants"
              item-title="name"
              item-value="id"
              label="Tenant"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              @update:model-value="reload"
            />
          </v-col>
          <v-col cols="6" md="2">
            <v-select
              v-model="statusFilter"
              :items="statusOptions"
              label="Status"
              variant="outlined"
              density="compact"
              hide-details
              clearable
              @update:model-value="reload"
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
          <div class="text-h6 font-weight-bold">{{ stats.total }}</div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Active</div>
          <div class="text-h6 font-weight-bold text-success">{{ stats.active }}</div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Inactive</div>
          <div class="text-h6 font-weight-bold text-medium-emphasis">{{ stats.inactive }}</div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="pa-3">
          <div class="text-caption text-medium-emphasis">Tenants</div>
          <div class="text-h6 font-weight-bold">{{ stats.tenants }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Table -->
    <v-card rounded="lg">
      <v-data-table
        :headers="headers"
        :items="r.items.value"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        class="elevation-0"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template #item.email="{ item }">
          <div class="d-flex align-center ga-2 py-1">
            <v-avatar size="32" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(item) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.first_name }} {{ item.last_name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.email }}</div>
            </div>
          </div>
        </template>

        <template #item.role="{ value }">
          <v-chip size="small" variant="tonal" :color="roleColor(value)" class="text-capitalize">
            {{ formatRole(value) }}
          </v-chip>
        </template>

        <template #item.tenant_name="{ value }">
          <span class="text-caption">{{ value || '—' }}</span>
        </template>

        <template #item.is_active="{ item }">
          <v-chip size="small" :color="item.is_active ? 'success' : 'grey'" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>

        <template #item.date_joined="{ value }">
          <span class="text-caption">{{ formatDate(value) }}</span>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn
              icon="mdi-pencil"
              variant="text"
              size="small"
              title="Edit"
              :to="`/superadmin/users/${item.id}/edit`"
            />
            <v-btn
              icon="mdi-lock-reset"
              variant="text"
              size="small"
              color="info"
              title="Reset Password"
              @click.stop="openResetDialog(item)"
            />
            <v-btn
              :icon="item.is_active ? 'mdi-account-off' : 'mdi-account-check'"
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
            icon="mdi-account-off"
            title="No users found"
            message="Adjust filters or create a new user to get started."
          />
        </template>
      </v-data-table>
    </v-card>

    <!-- Reset Password Dialog -->
    <v-dialog v-model="resetDialog.show" max-width="440">
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-lock-reset" class="mr-2" color="info" />
          Reset Password
        </v-card-title>
        <v-card-text>
          <p class="mb-3">Reset password for <strong>{{ resetDialog.user?.email }}</strong></p>
          <v-text-field
            v-model="resetDialog.password"
            label="New Password (leave blank to auto-generate)"
            variant="outlined"
            density="compact"
            type="password"
          />
          <v-alert v-if="resetDialog.result" type="success" variant="tonal" class="mt-2" density="compact">
            Password reset successfully.
            <span v-if="resetDialog.result.generated_password">
              Generated: <code>{{ resetDialog.result.generated_password }}</code>
            </span>
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="resetDialog.show = false">Close</v-btn>
          <v-btn
            color="info"
            rounded="lg"
            class="text-none"
            :loading="resetDialog.loading"
            :disabled="!!resetDialog.result"
            @click="resetPassword"
          >
            Reset
          </v-btn>
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
import { formatRole, formatDate } from '~/utils/format'

const { $api } = useNuxtApp()
const r = useResource('/superadmin/users/')

const headers = [
  { title: 'User', key: 'email' },
  { title: 'Role', key: 'role' },
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Status', key: 'is_active' },
  { title: 'Joined', key: 'date_joined' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 }
]

const roleOptions = [
  { title: 'Super Admin', value: 'super_admin' },
  { title: 'Tenant Admin', value: 'tenant_admin' },
  { title: 'Doctor', value: 'doctor' },
  { title: 'Clinical Officer', value: 'clinical_officer' },
  { title: 'Dentist', value: 'dentist' },
  { title: 'Nurse', value: 'nurse' },
  { title: 'Midwife', value: 'midwife' },
  { title: 'Lab Tech', value: 'lab_tech' },
  { title: 'Radiologist', value: 'radiologist' },
  { title: 'Pharmacist', value: 'pharmacist' },
  { title: 'Pharmacy Tech', value: 'pharmacy_tech' },
  { title: 'Cashier', value: 'cashier' },
  { title: 'Receptionist', value: 'receptionist' },
  { title: 'Homecare Admin', value: 'homecare_admin' },
  { title: 'Caregiver', value: 'caregiver' },
  { title: 'Patient', value: 'patient' },
]

const statusOptions = [
  { title: 'Active', value: 'true' },
  { title: 'Inactive', value: 'false' },
]

const searchQuery = ref('')
const roleFilter = ref(null)
const tenantFilter = ref(null)
const statusFilter = ref(null)
const tenants = ref([])
const toggling = ref(null)
const snack = reactive({ show: false, text: '', color: 'success' })

const stats = computed(() => {
  const items = r.items.value
  const active = items.filter(u => u.is_active).length
  const tenantSet = new Set(items.map(u => u.tenant).filter(Boolean))
  return { total: r.count.value, active, inactive: r.count.value - active, tenants: tenantSet.size }
})

// Search with debounce
let searchTimeout = null
function onSearch(val) {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => reload(), 350)
}

function reload() {
  const params = {}
  if (searchQuery.value) params.q = searchQuery.value
  if (roleFilter.value) params.role = roleFilter.value
  if (tenantFilter.value) params.tenant_id = tenantFilter.value
  if (statusFilter.value) params.is_active = statusFilter.value
  r.list(params)
}

// Toggle active
async function toggleActive(user) {
  toggling.value = user.id
  try {
    await $api.post(`/superadmin/users/${user.id}/toggle-active/`)
    user.is_active = !user.is_active
    showSnack(`${user.email} ${user.is_active ? 'activated' : 'deactivated'}`)
  } catch (e) {
    showSnack(e.response?.data?.detail || 'Action failed', 'error')
  } finally {
    toggling.value = null
  }
}

// Reset password
const resetDialog = reactive({ show: false, user: null, password: '', loading: false, result: null })

function openResetDialog(user) {
  resetDialog.user = user
  resetDialog.password = ''
  resetDialog.loading = false
  resetDialog.result = null
  resetDialog.show = true
}

async function resetPassword() {
  resetDialog.loading = true
  try {
    const payload = resetDialog.password ? { new_password: resetDialog.password } : {}
    const { data } = await $api.post(`/superadmin/users/${resetDialog.user.id}/reset-password/`, payload)
    resetDialog.result = data
    showSnack('Password reset successfully')
  } catch (e) {
    showSnack(e.response?.data?.detail || 'Reset failed', 'error')
  } finally {
    resetDialog.loading = false
  }
}

// Helpers
function initials(user) {
  return ((user.first_name?.[0] || '') + (user.last_name?.[0] || '')).toUpperCase() || '?'
}

function roleColor(role) {
  const map = { super_admin: 'error', tenant_admin: 'purple', doctor: 'blue', nurse: 'teal', pharmacist: 'green', lab_tech: 'orange', radiologist: 'indigo', cashier: 'brown', receptionist: 'cyan', patient: 'grey' }
  return map[role] || 'primary'
}

function showSnack(text, color = 'success') {
  snack.text = text
  snack.color = color
  snack.show = true
}

onMounted(async () => {
  reload()
  tenants.value = await $api.get('/superadmin/tenants/').then(r => r.data?.results || r.data || []).catch(() => [])
})
</script>
