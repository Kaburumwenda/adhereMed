<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="indigo-darken-3" size="32">mdi-school</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Specializations</div>
              <div class="text-body-2" style="opacity:0.9">
                Define clinical &amp; pharmacy specializations that staff can be assigned to.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-indigo-darken-3"
                 prepend-icon="mdi-plus" @click="openDialog()">New Specialization</v-btn>
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
        <v-col cols="12" md="6">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search specializations…" density="comfortable"
                        hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="filterStatus" :items="statusItems" label="Status"
                    density="comfortable" hide-details variant="outlined" />
        </v-col>
        <v-col cols="6" md="3" class="d-flex justify-end">
          <v-btn variant="text" prepend-icon="mdi-download" @click="exportCsv">Export CSV</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
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
            <div class="font-weight-medium">{{ item.name }}</div>
          </div>
        </template>
        <template #item.description="{ item }">
          <span class="text-body-2 text-medium-emphasis">{{ item.description || '—' }}</span>
        </template>
        <template #item.is_active="{ item }">
          <v-chip :color="item.is_active ? 'success' : 'grey'" size="small" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.created_at="{ item }">
          <span class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</span>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openDialog(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-school-outline" title="No specializations yet"
                      message="Create your first specialization to get started." />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create / Edit dialog -->
    <v-dialog v-model="dialog" max-width="540" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="indigo" class="mr-2">mdi-school</v-icon>
          {{ editing ? 'Edit Specialization' : 'New Specialization' }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-text-field v-model="form.name" label="Name *" variant="outlined" density="comfortable"
                        :error-messages="formErrors.name" autofocus />
          <v-textarea v-model="form.description" label="Description" variant="outlined"
                      density="comfortable" rows="3" auto-grow />
          <v-switch v-model="form.is_active" color="success" label="Active" hide-details inset />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">
            {{ editing ? 'Save changes' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete specialization?</v-card-title>
        <v-card-text>
          <strong>{{ target?.name }}</strong> will be removed. Staff currently assigned will be unlinked.
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
import { formatDate } from '~/utils/format'
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

const headers = [
  { title: 'Name', key: 'name', sortable: true },
  { title: 'Description', key: 'description', sortable: false },
  { title: 'Status', key: 'is_active', sortable: true, align: 'start' },
  { title: 'Created', key: 'created_at', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
]

const dialog = ref(false)
const editing = ref(null)
const form = reactive({ name: '', description: '', is_active: true })
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
    return (s.name || '').toLowerCase().includes(q) ||
           (s.description || '').toLowerCase().includes(q)
  })
})

const kpis = computed(() => [
  { label: 'Total', value: items.value.length, icon: 'mdi-school', color: 'indigo' },
  { label: 'Active', value: items.value.filter(s => s.is_active).length, icon: 'mdi-check-circle', color: 'success' },
  { label: 'Inactive', value: items.value.filter(s => !s.is_active).length, icon: 'mdi-pause-circle', color: 'grey' },
  { label: 'Showing', value: filteredItems.value.length, icon: 'mdi-filter', color: 'teal' },
])

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/staff/specializations/', { params: { ordering: 'name', page_size: 200 } })
    items.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify(extractError(e) || 'Failed to load specializations', 'error')
    items.value = []
  } finally {
    loading.value = false
  }
}

function openDialog(s = null) {
  editing.value = s
  Object.assign(form, s
    ? { name: s.name, description: s.description || '', is_active: s.is_active }
    : { name: '', description: '', is_active: true })
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  dialog.value = true
}

async function save() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  if (!form.name?.trim()) {
    formErrors.name = 'Name is required'
    return
  }
  saving.value = true
  try {
    if (editing.value) {
      await $api.patch(`/staff/specializations/${editing.value.id}/`, form)
      notify('Specialization updated')
    } else {
      await $api.post('/staff/specializations/', form)
      notify('Specialization created')
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
    await $api.delete(`/staff/specializations/${target.value.id}/`)
    notify('Specialization deleted')
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
  const lines = ['Name,Description,Status,Created']
  rows.forEach(s => {
    lines.push([
      JSON.stringify(s.name || ''),
      JSON.stringify(s.description || ''),
      s.is_active ? 'Active' : 'Inactive',
      s.created_at || '',
    ].join(','))
  })
  download(lines.join('\n'), `specializations-${new Date().toISOString().slice(0,10)}.csv`)
}

function download(text, name) {
  const blob = new Blob([text], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = name; a.click()
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
  const palette = ['indigo', 'teal', 'deep-purple', 'pink', 'orange', 'cyan', 'green', 'blue']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}

onMounted(load)
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(79, 70, 229, 0.25);
}
.stat-card {
  background: rgba(255, 255, 255, 0.95);
  color: rgba(0, 0, 0, 0.85);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0,0,0,0.12); }
</style>
