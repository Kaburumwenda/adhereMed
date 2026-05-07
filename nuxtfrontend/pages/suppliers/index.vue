<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="teal-darken-3" size="32">mdi-truck-delivery</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Suppliers</div>
              <div class="text-body-2" style="opacity:0.9">
                Manage vendors who supply medications, equipment &amp; consumables.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-teal-darken-3"
                 prepend-icon="mdi-plus" :to="'/suppliers/new'">New Supplier</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">Refresh</v-btn>
        </v-col>
      </v-row>

      <v-row class="mt-4" dense>
        <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="stat-card pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="36" class="mr-3">
                <v-icon color="white" size="20">{{ k.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Filters -->
    <v-card flat rounded="xl" class="pa-3 mb-3" border>
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name, contact, phone, email…" density="comfortable"
                        hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="filterStatus" :items="statusItems" label="Status"
                    density="comfortable" hide-details variant="outlined" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="viewMode" :items="viewItems" label="View"
                    density="comfortable" hide-details variant="outlined"
                    prepend-inner-icon="mdi-view-grid-outline" />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" prepend-icon="mdi-download" @click="exportCsv">CSV</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Card / grid view -->
    <div v-if="viewMode === 'grid'">
      <div v-if="loading" class="text-center py-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <EmptyState v-else-if="!filteredItems.length"
                  icon="mdi-truck-outline" title="No suppliers found"
                  message="Add your first supplier to start tracking purchase orders." />
      <v-row v-else dense>
        <v-col v-for="s in filteredItems" :key="s.id" cols="12" sm="6" md="4" lg="3">
          <v-card class="supplier-card pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-avatar :color="avatarColor(s.name)" size="44" class="mr-3">
                <span class="text-subtitle-2 font-weight-bold text-white">{{ initials(s.name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-width-0">
                <div class="text-subtitle-1 font-weight-bold text-truncate">{{ s.name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ s.contact_person || 'No contact person' }}
                </div>
              </div>
              <v-chip :color="s.is_active ? 'success' : 'grey'" size="x-small" variant="tonal">
                {{ s.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>
            <v-divider class="mb-2" />
            <div class="text-caption text-medium-emphasis mb-1">
              <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ s.phone || '—' }}
            </div>
            <div class="text-caption text-medium-emphasis mb-1 text-truncate">
              <v-icon size="14" class="mr-1">mdi-email</v-icon>{{ s.email || '—' }}
            </div>
            <div class="text-caption text-medium-emphasis mb-2 text-truncate">
              <v-icon size="14" class="mr-1">mdi-map-marker</v-icon>{{ s.address || '—' }}
            </div>
            <v-chip v-if="s.payment_terms" size="x-small" color="primary" variant="tonal" class="mb-2">
              <v-icon start size="12">mdi-credit-card-outline</v-icon>{{ s.payment_terms }}
            </v-chip>
            <div class="d-flex justify-end mt-2">
              <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/suppliers/${s.id}/edit`" />
              <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(s)" />
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Table view -->
    <v-card v-else flat rounded="xl" border>
      <v-data-table
        :headers="headers"
        :items="filteredItems"
        :loading="loading"
        :items-per-page="20"
        item-value="id"
        density="comfortable"
        hover
      >
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="avatarColor(item.name)" size="34" class="mr-3">
              <span class="text-caption font-weight-bold text-white">{{ initials(item.name) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.contact_person || '—' }}</div>
            </div>
          </div>
        </template>
        <template #item.phone="{ item }">
          <span class="text-body-2">{{ item.phone || '—' }}</span>
        </template>
        <template #item.email="{ item }">
          <a v-if="item.email" :href="`mailto:${item.email}`" class="text-decoration-none">{{ item.email }}</a>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.payment_terms="{ item }">
          <v-chip v-if="item.payment_terms" size="x-small" color="primary" variant="tonal">
            {{ item.payment_terms }}
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.is_active="{ item }">
          <v-chip :color="item.is_active ? 'success' : 'grey'" size="small" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/suppliers/${item.id}/edit`" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-truck-outline" title="No suppliers found"
                      message="Add your first supplier to start tracking purchase orders." />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create / Edit dialog -->
    <v-dialog v-model="dialog" max-width="640" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="teal" class="mr-2">mdi-truck-delivery</v-icon>
          {{ editing ? 'Edit Supplier' : 'New Supplier' }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.name" label="Supplier name *" variant="outlined"
                            density="comfortable" :error-messages="formErrors.name" autofocus />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.contact_person" label="Contact person" variant="outlined"
                            density="comfortable" :error-messages="formErrors.contact_person" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                            density="comfortable" prepend-inner-icon="mdi-phone"
                            :error-messages="formErrors.phone" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.email" label="Email" variant="outlined"
                            density="comfortable" prepend-inner-icon="mdi-email"
                            :error-messages="formErrors.email" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.address" label="Address" variant="outlined"
                          density="comfortable" rows="2" auto-grow
                          :error-messages="formErrors.address" />
            </v-col>
            <v-col cols="12" md="6">
              <v-combobox v-model="form.payment_terms" label="Payment terms"
                          :items="paymentTermSuggestions" variant="outlined" density="comfortable"
                          prepend-inner-icon="mdi-credit-card-outline" hide-no-data
                          :error-messages="formErrors.payment_terms" />
            </v-col>
            <v-col cols="12" md="6" class="d-flex align-center">
              <v-switch v-model="form.is_active" color="success" label="Active supplier"
                        hide-details inset />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">
            {{ editing ? 'Save changes' : 'Create supplier' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete supplier?</v-card-title>
        <v-card-text>
          <strong>{{ target?.name }}</strong> will be removed. Existing purchase orders will keep their reference.
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

const items = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const filterStatus = ref('all')
const statusItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]
const viewMode = ref('grid')
const viewItems = [
  { title: 'Grid', value: 'grid' },
  { title: 'Table', value: 'table' },
]

const headers = [
  { title: 'Supplier', key: 'name', sortable: true },
  { title: 'Phone', key: 'phone', sortable: false },
  { title: 'Email', key: 'email', sortable: false },
  { title: 'Payment terms', key: 'payment_terms', sortable: true },
  { title: 'Status', key: 'is_active', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
]

const paymentTermSuggestions = ['Cash on delivery', 'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60', 'Prepaid']

const dialog = ref(false)
const editing = ref(null)
const form = reactive({
  name: '', contact_person: '', phone: '', email: '',
  address: '', payment_terms: '', is_active: true,
})
const formErrors = reactive({})

const deleteDialog = ref(false)
const target = ref(null)

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  return items.value.filter(s => {
    if (filterStatus.value === 'active' && !s.is_active) return false
    if (filterStatus.value === 'inactive' && s.is_active) return false
    if (!q) return true
    return ['name', 'contact_person', 'phone', 'email', 'address']
      .some(k => (s[k] || '').toLowerCase().includes(q))
  })
})

const kpis = computed(() => [
  { label: 'Total', value: items.value.length, icon: 'mdi-truck', color: 'teal' },
  { label: 'Active', value: items.value.filter(s => s.is_active).length, icon: 'mdi-check-circle', color: 'success' },
  { label: 'Inactive', value: items.value.filter(s => !s.is_active).length, icon: 'mdi-pause-circle', color: 'grey' },
  { label: 'Showing', value: filteredItems.value.length, icon: 'mdi-filter', color: 'indigo' },
])

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/suppliers/', { params: { ordering: 'name', page_size: 200 } })
    items.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify(extractError(e) || 'Failed to load suppliers', 'error')
    items.value = []
  } finally {
    loading.value = false
  }
}

function openDialog(s = null) {
  editing.value = s
  Object.assign(form, s ? {
    name: s.name, contact_person: s.contact_person || '', phone: s.phone || '',
    email: s.email || '', address: s.address || '',
    payment_terms: s.payment_terms || '', is_active: s.is_active,
  } : {
    name: '', contact_person: '', phone: '', email: '',
    address: '', payment_terms: '', is_active: true,
  })
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  dialog.value = true
}

async function save() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  if (!form.name?.trim()) {
    formErrors.name = 'Supplier name is required'
    return
  }
  saving.value = true
  try {
    const payload = { ...form }
    if (editing.value) {
      await $api.patch(`/suppliers/${editing.value.id}/`, payload)
      notify('Supplier updated')
    } else {
      await $api.post('/suppliers/', payload)
      notify('Supplier created')
    }
    dialog.value = false
    await load()
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) {
        formErrors[k] = Array.isArray(v) ? v.join(' ') : String(v)
      }
    }
    notify(extractError(e) || 'Save failed', 'error')
  } finally {
    saving.value = false
  }
}

function confirmDelete(s) { target.value = s; deleteDialog.value = true }
async function doDelete() {
  if (!target.value) return
  saving.value = true
  try {
    await $api.delete(`/suppliers/${target.value.id}/`)
    notify('Supplier deleted')
    deleteDialog.value = false
    await load()
  } catch (e) {
    notify(extractError(e) || 'Delete failed', 'error')
  } finally {
    saving.value = false
  }
}

function exportCsv() {
  const rows = filteredItems.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const lines = ['Name,Contact,Phone,Email,Address,Payment terms,Status']
  rows.forEach(s => {
    lines.push([
      JSON.stringify(s.name || ''),
      JSON.stringify(s.contact_person || ''),
      JSON.stringify(s.phone || ''),
      JSON.stringify(s.email || ''),
      JSON.stringify(s.address || ''),
      JSON.stringify(s.payment_terms || ''),
      s.is_active ? 'Active' : 'Inactive',
    ].join(','))
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `suppliers-${new Date().toISOString().slice(0,10)}.csv`; a.click()
  URL.revokeObjectURL(url)
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('')
}
function avatarColor(name) {
  const palette = ['teal', 'indigo', 'deep-purple', 'pink', 'orange', 'cyan', 'green', 'blue']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}

onMounted(load)
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #0f766e 0%, #14b8a6 50%, #06b6d4 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(15, 118, 110, 0.25);
}
.stat-card {
  background: rgba(255, 255, 255, 0.95);
  color: rgba(0, 0, 0, 0.85);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0,0,0,0.12); }
.supplier-card { transition: transform 0.15s ease, box-shadow 0.15s ease; }
.supplier-card:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(20, 184, 166, 0.15); }
</style>
