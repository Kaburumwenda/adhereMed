<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Staff" subtitle="Clinic staff and user management"
      icon="mdi-account-group" color="primary">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNew">New Staff</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="7">
          <v-text-field v-model="searchLocal" prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, email, role…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="5">
          <v-select v-model="roleFilter" :items="roleOptions"
            label="Role" variant="outlined" density="compact"
            hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="loading" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" size="48" />
      </div>

      <div v-else-if="!filteredStaff.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-account-group</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No staff found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ roleFilter || searchLocal ? 'Try adjusting your filters.' : 'Add your first staff member to get started.' }}
        </div>
        <v-btn v-if="!roleFilter && !searchLocal" color="primary" rounded="lg"
          prepend-icon="mdi-plus" @click="openNew">New Staff</v-btn>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredStaff"
        :items-per-page="20"
        item-value="id"
        hover
        class="staff-table">
        <template #item.full_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar color="primary-lighten-5" size="36" class="mr-3">
              <v-icon color="primary-darken-2" size="20">mdi-account</v-icon>
            </v-avatar>
            <div class="font-weight-medium">{{ item.full_name || `${item.first_name || ''} ${item.last_name || ''}`.trim() || '—' }}</div>
          </div>
        </template>
        <template #item.email="{ value }">
          <span v-if="value" class="text-body-2">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.role="{ value }">
          <v-chip size="small" variant="tonal" color="primary" class="text-capitalize">
            {{ formatRole(value) }}
          </v-chip>
        </template>
        <template #item.phone="{ value }">
          <span v-if="value" class="text-body-2">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.is_active="{ value }">
          <v-chip size="small" :color="value ? 'success' : 'grey'" variant="tonal">
            {{ value ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.date_joined="{ value }">{{ formatDate(value) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ New/Edit staff dialog ═══════════════════════════════════ -->
    <v-dialog v-model="dialog" max-width="640" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon :color="editing ? 'primary' : 'primary'" class="mr-2">
            {{ editing ? 'mdi-account-edit' : 'mdi-account-plus' }}
          </v-icon>
          {{ editing ? 'Edit Staff' : 'New Staff' }}
        </v-card-title>
        <v-card-text>
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.first_name" label="First Name" required
                  variant="outlined" density="compact" prepend-inner-icon="mdi-account"
                  :rules="req" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.last_name" label="Last Name" required
                  variant="outlined" density="compact" prepend-inner-icon="mdi-account"
                  :rules="req" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.email" label="Email" required type="email"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-email"
                  :rules="emailRules" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-select v-model="form.role" :items="roleOptions"
                  label="Role" required variant="outlined" density="compact"
                  prepend-inner-icon="mdi-shield-account" :rules="req" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.phone" label="Phone" type="tel"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-phone" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.password" label="Password" type="password"
                  :required="!editing" variant="outlined" density="compact"
                  prepend-inner-icon="mdi-lock"
                  :hint="editing ? 'Leave blank to keep current password.' : ''"
                  persistent-hint
                  :rules="editing ? [] : req" />
              </v-col>
              <v-col cols="12" class="pt-2">
                <v-switch v-model="form.is_active" label="Active account"
                  color="success" hide-details density="compact" />
              </v-col>
            </v-row>
            <v-alert v-if="pageError" type="error" variant="tonal" density="compact" class="mt-3">
              {{ pageError }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
            prepend-icon="mdi-content-save" @click="save">
            {{ editing ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Delete confirmation dialog ═══════════════════════════════ -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Staff</v-card-title>
        <v-card-text>
          Are you sure you want to delete
          <strong>{{ deleteTarget?.full_name || 'this staff member' }}</strong>?
          <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="saving" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDate, formatRole } from '~/utils/format'

const ns = '/clinics'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const items = ref([])
const searchLocal = ref('')
const roleFilter = ref(null)
const pageError = ref('')

const roleOptions = [
  { title: 'Tenant Admin', value: 'tenant_admin' },
  { title: 'Clinic Admin', value: 'clinic_admin' },
  { title: 'Doctor', value: 'doctor' },
  { title: 'Clinical Officer', value: 'clinical_officer' },
  { title: 'Dentist', value: 'dentist' },
  { title: 'Nurse', value: 'nurse' },
  { title: 'Midwife', value: 'midwife' },
  { title: 'Receptionist', value: 'receptionist' },
  { title: 'Lab Tech', value: 'lab_tech' },
  { title: 'Radiologist', value: 'radiologist' },
  { title: 'Pharmacist', value: 'pharmacist' },
  { title: 'Cashier', value: 'cashier' },
]

const headers = [
  { title: 'Name', key: 'full_name' },
  { title: 'Email', key: 'email' },
  { title: 'Role', key: 'role', width: 160 },
  { title: 'Phone', key: 'phone', width: 140 },
  { title: 'Status', key: 'is_active', width: 110 },
  { title: 'Date Joined', key: 'date_joined', width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
]

const req = [v => !!v || 'Required']
const emailRules = [
  v => !!v || 'Email is required',
  v => /.+@.+\..+/.test(v) || 'Enter a valid email',
]

const filteredStaff = computed(() => {
  let list = items.value
  if (roleFilter.value) list = list.filter(s => s.role === roleFilter.value)
  const q = (searchLocal.value || '').toLowerCase()
  if (q) {
    list = list.filter(s =>
      (s.full_name || '').toLowerCase().includes(q) ||
      (s.email || '').toLowerCase().includes(q) ||
      (s.role || '').toLowerCase().includes(q) ||
      JSON.stringify(s).toLowerCase().includes(q),
    )
  }
  return list
})

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/auth/users/', { params: { page_size: 1000 } })
    const data = res.data
    items.value = Array.isArray(data) ? data : (data?.results || [])
  } catch (e) {
    pageError.value = e?.response?.data?.detail || e?.message || 'Failed to load staff.'
    items.value = []
  } finally {
    loading.value = false
  }
}

// ── New / Edit dialog ──────────────────────────────────────────
const dialog = ref(false)
const editing = ref(null)
const formRef = ref(null)
const blankForm = () => ({
  first_name: '', last_name: '', email: '', role: 'doctor',
  phone: '', password: '', is_active: true,
})
const form = reactive(blankForm())

function openNew() {
  editing.value = null
  Object.assign(form, blankForm())
  pageError.value = ''
  dialog.value = true
}

function openEdit(item) {
  editing.value = item.id
  Object.assign(form, {
    first_name: item.first_name || '',
    last_name: item.last_name || '',
    email: item.email || '',
    role: item.role || 'doctor',
    phone: item.phone || '',
    password: '',
    is_active: item.is_active !== false,
  })
  pageError.value = ''
  dialog.value = true
}

async function save() {
  const v = await formRef.value?.validate()
  if (v?.valid === false) return
  saving.value = true
  pageError.value = ''
  try {
    const payload = { ...form }
    if (editing.value && !payload.password) delete payload.password
    if (editing.value) {
      await $api.patch(`/auth/users/${editing.value}/`, payload)
      snack.text = 'Staff updated successfully'
    } else {
      await $api.post('/auth/users/', payload)
      snack.text = 'Staff created successfully'
    }
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    await load()
  } catch (e) {
    pageError.value = e?.response?.data?.detail
      || (typeof e?.response?.data === 'string' ? e.response.data : null)
      || e?.message || 'Failed to save staff.'
  } finally {
    saving.value = false
  }
}

// ── Delete ────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)

function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}

async function performDelete() {
  saving.value = true
  try {
    await $api.delete(`/auth/users/${deleteTarget.value.id}/`)
    snack.text = 'Staff deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to delete staff.'
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

const snack = reactive({ show: false, color: 'success', text: '' })

onMounted(load)
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
