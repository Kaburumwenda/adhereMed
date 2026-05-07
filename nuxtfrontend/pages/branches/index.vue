<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="7">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="blue-darken-3" size="32">mdi-store</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Branches</div>
              <div class="text-body-2" style="opacity:0.9">
                Manage your pharmacy locations &amp; contact details.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="5" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn variant="flat" color="white" prepend-icon="mdi-refresh" class="text-blue-darken-3"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
          <v-btn color="white" variant="flat" class="text-blue-darken-3"
                 prepend-icon="mdi-plus" @click="openCreate">New branch</v-btn>
        </v-col>
      </v-row>
      <v-row class="mt-4" dense>
        <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="40" class="mr-3">
                <v-icon color="white" size="22">{{ k.icon }}</v-icon>
              </v-avatar>
              <div class="min-width-0">
                <div class="text-caption text-medium-emphasis text-uppercase">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="6">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name or address…"
                        density="comfortable" variant="solo-filled" flat hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="activeFilter" :items="activeItems" label="Status"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="6" md="3" class="text-right">
          <v-chip color="primary" variant="tonal">{{ filtered.length }} shown</v-chip>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading"
                    density="comfortable" hover :items-per-page="25">
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="item.is_main ? 'amber-darken-2' : 'blue'" size="32" class="mr-2">
              <v-icon color="white" size="18">{{ item.is_main ? 'mdi-star' : 'mdi-store' }}</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <v-chip v-if="item.is_main" size="x-small" color="amber-darken-2" variant="tonal">Main</v-chip>
            </div>
          </div>
        </template>
        <template #item.address="{ item }">
          <span class="text-body-2">{{ item.address || '—' }}</span>
        </template>
        <template #item.phone="{ item }">{{ item.phone || '—' }}</template>
        <template #item.email="{ item }">{{ item.email || '—' }}</template>
        <template #item.is_active="{ item }">
          <v-icon :color="item.is_active ? 'success' : 'grey'" size="18">
            {{ item.is_active ? 'mdi-check-circle' : 'mdi-pause-circle' }}
          </v-icon>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-store-off" title="No branches yet"
                      message="Add your first branch to get started." />
        </template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="formDialog" max-width="640" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-store</v-icon>
          {{ form.id ? 'Edit branch' : 'New branch' }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12">
              <v-text-field v-model="form.name" label="Branch name *"
                            variant="outlined" density="comfortable" :error-messages="errors.name" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.address" label="Address" rows="2" auto-grow
                          variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.phone" label="Phone" prepend-inner-icon="mdi-phone"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.email" label="Email" type="email"
                            prepend-inner-icon="mdi-email" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="form.is_main" label="Main branch" color="amber-darken-2"
                        density="comfortable" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="form.is_active" label="Active" color="success"
                        density="comfortable" hide-details />
            </v-col>
          </v-row>
          <v-alert v-if="form.is_main && hasOtherMain" type="warning" variant="tonal" class="mt-3">
            Another branch is already marked as main. Only one branch should be the main location.
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">
            {{ form.id ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card v-if="deleteTarget" rounded="xl">
        <v-card-title>Delete branch?</v-card-title>
        <v-card-text>
          This will remove <strong>{{ deleteTarget.name }}</strong>.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const branches = ref([])

async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/pharmacy-profile/branches/', { params: { page_size: 200 } })
    branches.value = data?.results || data || []
  } catch { notify('Failed to load branches', 'error') }
  finally { loading.value = false }
}
onMounted(loadAll)

const search = ref('')
const activeFilter = ref('all')
const activeItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return branches.value.filter(b => {
    if (activeFilter.value === 'active' && !b.is_active) return false
    if (activeFilter.value === 'inactive' && b.is_active) return false
    if (!q) return true
    return [b.name, b.address, b.phone, b.email].some(v => (v || '').toLowerCase().includes(q))
  })
})

const kpiTiles = computed(() => [
  { label: 'Total', value: branches.value.length, icon: 'mdi-store', color: 'blue' },
  { label: 'Active', value: branches.value.filter(b => b.is_active).length,
    icon: 'mdi-check-circle', color: 'success' },
  { label: 'Main', value: branches.value.filter(b => b.is_main).length,
    icon: 'mdi-star', color: 'amber-darken-2' },
  { label: 'Inactive', value: branches.value.filter(b => !b.is_active).length,
    icon: 'mdi-pause-circle', color: 'grey' },
])

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Address', key: 'address' },
  { title: 'Phone', key: 'phone' },
  { title: 'Email', key: 'email' },
  { title: 'Active', key: 'is_active', sortable: false, align: 'center' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 120 },
]

const formDialog = ref(false)
const form = reactive(blankForm())
const errors = reactive({})
function blankForm() { return { id: null, name: '', address: '', phone: '', email: '', is_main: false, is_active: true } }
function openCreate() { Object.assign(form, blankForm()); clearErrors(); formDialog.value = true }
function openEdit(b) { Object.assign(form, blankForm(), b); clearErrors(); formDialog.value = true }
function clearErrors() { Object.keys(errors).forEach(k => delete errors[k]) }

const hasOtherMain = computed(() =>
  branches.value.some(b => b.is_main && b.id !== form.id),
)

async function save() {
  clearErrors()
  if (!form.name) { errors.name = 'Required'; return }
  saving.value = true
  try {
    const payload = { ...form }; delete payload.id
    if (form.id) await $api.put(`/pharmacy-profile/branches/${form.id}/`, payload)
    else await $api.post('/pharmacy-profile/branches/', payload)
    notify(form.id ? 'Branch updated' : 'Branch created')
    formDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Save failed', 'error') }
  finally { saving.value = false }
}

const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(b) { deleteTarget.value = b; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/pharmacy-profile/branches/${deleteTarget.value.id}/`)
    notify('Deleted')
    deleteDialog.value = false
    await loadAll()
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
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 50%, #38bdf8 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(37, 99, 235, 0.25);
}
.kpi {
  background: rgba(255, 255, 255, 0.97);
  color: rgba(0, 0, 0, 0.87);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.kpi:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.1); }
.kpi :deep(.text-h6) { color: rgba(0, 0, 0, 0.87) !important; }
.kpi :deep(.text-medium-emphasis) { color: rgba(0, 0, 0, 0.62) !important; }
</style>
