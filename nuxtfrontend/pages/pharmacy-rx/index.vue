<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="purple-lighten-5" size="48" class="mr-3">
          <v-icon color="purple-darken-2" size="28">mdi-pill-multiple</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">{{ $t('pharmacyRx.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Issue &amp; track prescriptions for walk-in patients</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="loadAll">{{ $t('common.refresh') }}</v-btn>
      <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" @click="openCreate">New prescription</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="6">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by patient name or phone…"
                        density="comfortable" variant="solo-filled" flat hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="statusFilter" :items="statusItems" label="Status"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="6" md="3" class="text-right">
          <v-chip color="primary" variant="tonal">{{ filtered.length }} shown</v-chip>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading"
                    density="comfortable" hover :items-per-page="20">
        <template #item.patient_name="{ item }">
          <div class="font-weight-medium">{{ item.patient_name }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.patient_phone || '—' }}</div>
        </template>
        <template #item.items_count="{ item }">
          {{ (item.items || []).length }} item(s)
        </template>
        <template #item.status="{ item }">
          <v-chip :color="statusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
            {{ item.status }}
          </v-chip>
        </template>
        <template #item.created_at="{ item }">{{ formatDateTime(item.created_at) }}</template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" variant="text" size="small" @click="openView(item)" />
          <v-btn v-if="item.status === 'active'" icon="mdi-check" variant="text" size="small"
                 color="success" @click="updateStatus(item, 'dispensed')" />
          <v-btn v-if="item.status !== 'cancelled'" icon="mdi-cancel" variant="text" size="small"
                 color="error" @click="updateStatus(item, 'cancelled')" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-pill-multiple" title="No prescriptions yet"
                      message="Issue your first walk-in prescription." />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create dialog -->
    <v-dialog v-model="formDialog" max-width="780" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-pill-multiple</v-icon>
          New pharmacy prescription
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12" md="7">
              <v-text-field v-model="form.patient_name" label="Patient name *"
                            variant="outlined" density="comfortable" :error-messages="errors.patient_name" />
            </v-col>
            <v-col cols="12" md="5">
              <v-text-field v-model="form.patient_phone" label="Phone"
                            variant="outlined" density="comfortable" prepend-inner-icon="mdi-phone" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <div class="d-flex align-center mb-2">
                <div class="text-subtitle-2 font-weight-bold">Items</div>
                <v-spacer />
                <v-btn size="small" variant="tonal" prepend-icon="mdi-plus" @click="addItem">Add item</v-btn>
              </div>
              <v-card v-for="(it, i) in form.items" :key="i" variant="outlined" class="pa-3 mb-2" rounded="lg">
                <v-row dense>
                  <v-col cols="12" md="5">
                    <v-text-field v-model="it.medication_name" label="Medication *" density="compact"
                                  variant="outlined" :error-messages="itemErrors[i]?.medication_name" />
                  </v-col>
                  <v-col cols="6" md="2">
                    <v-text-field v-model="it.dosage" label="Dosage" density="compact" variant="outlined" />
                  </v-col>
                  <v-col cols="6" md="2">
                    <v-text-field v-model="it.frequency" label="Frequency" density="compact" variant="outlined" />
                  </v-col>
                  <v-col cols="6" md="2">
                    <v-text-field v-model.number="it.quantity" type="number" min="1" label="Qty"
                                  density="compact" variant="outlined" />
                  </v-col>
                  <v-col cols="6" md="1" class="text-right">
                    <v-btn icon="mdi-delete" variant="text" size="small" color="error"
                           :disabled="form.items.length === 1" @click="form.items.splice(i, 1)" />
                  </v-col>
                  <v-col cols="12">
                    <v-text-field v-model="it.instructions" label="Instructions"
                                  density="compact" variant="outlined" />
                  </v-col>
                </v-row>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">Create prescription</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- View dialog -->
    <v-dialog v-model="viewDialog" max-width="640" scrollable>
      <v-card v-if="viewing" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-pill-multiple</v-icon>
          Rx #{{ viewing.id }}
          <v-chip class="ml-2" size="small" :color="statusColor(viewing.status)" variant="tonal">
            {{ viewing.status }}
          </v-chip>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="viewDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <div class="d-flex justify-space-between mb-2">
            <span class="text-medium-emphasis">Patient</span>
            <span class="font-weight-medium">{{ viewing.patient_name }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-medium-emphasis">Phone</span>
            <span>{{ viewing.patient_phone || '—' }}</span>
          </div>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-medium-emphasis">Issued</span>
            <span>{{ formatDateTime(viewing.created_at) }}</span>
          </div>
          <v-divider class="mb-3" />
          <div class="text-subtitle-2 mb-2">Items</div>
          <v-list density="compact" class="pa-0">
            <v-list-item v-for="(it, i) in (viewing.items || [])" :key="i" class="px-0">
              <v-list-item-title class="font-weight-medium">{{ it.medication_name }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ [it.dosage, it.frequency, it.duration && `× ${it.duration}`].filter(Boolean).join(' · ') }}
                · Qty: {{ it.quantity }}
              </v-list-item-subtitle>
              <v-list-item-subtitle v-if="it.instructions" class="text-caption text-medium-emphasis">
                {{ it.instructions }}
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
          <v-alert v-if="viewing.notes" type="info" variant="tonal" class="mt-3">
            {{ viewing.notes }}
          </v-alert>
        </v-card-text>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, computed, onMounted } from 'vue'
import EmptyState from '~/components/EmptyState.vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const items = ref([])

async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/prescriptions/pharmacy-rx/', { params: { page_size: 200 } })
    items.value = data?.results || data || []
  } catch { notify('Failed to load prescriptions', 'error') }
  finally { loading.value = false }
}
onMounted(loadAll)

const search = ref('')
const statusFilter = ref('all')
const statusItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Dispensed', value: 'dispensed' },
  { title: 'Cancelled', value: 'cancelled' },
]
function statusColor(s) {
  return ({ active: 'info', dispensed: 'success', cancelled: 'grey' })[s] || 'grey'
}

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return items.value.filter(rx => {
    if (statusFilter.value !== 'all' && rx.status !== statusFilter.value) return false
    if (!q) return true
    return (rx.patient_name || '').toLowerCase().includes(q)
        || (rx.patient_phone || '').toLowerCase().includes(q)
  })
})

const todayKey = () => new Date().toISOString().slice(0, 10)
const kpiTiles = computed(() => [
  { label: 'Total', value: items.value.length, icon: 'mdi-pill-multiple', color: 'purple' },
  { label: 'Active', value: items.value.filter(r => r.status === 'active').length,
    icon: 'mdi-clock-outline', color: 'info' },
  { label: 'Dispensed', value: items.value.filter(r => r.status === 'dispensed').length,
    icon: 'mdi-check-circle', color: 'success' },
  { label: 'Today', value: items.value.filter(r => (r.created_at || '').slice(0, 10) === todayKey()).length,
    icon: 'mdi-calendar-today', color: 'amber-darken-2' },
])

const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Items', key: 'items_count', sortable: false },
  { title: 'Status', key: 'status' },
  { title: 'Created', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

// ── form
const formDialog = ref(false)
const form = reactive(blankForm())
const errors = reactive({})
const itemErrors = reactive({})
function blankItem() { return { medication_name: '', dosage: '', frequency: '', duration: '', quantity: 1, instructions: '' } }
function blankForm() { return { patient_name: '', patient_phone: '', notes: '', items: [blankItem()] } }
function openCreate() {
  Object.assign(form, blankForm())
  Object.keys(errors).forEach(k => delete errors[k])
  Object.keys(itemErrors).forEach(k => delete itemErrors[k])
  formDialog.value = true
}
function addItem() { form.items.push(blankItem()) }

async function save() {
  Object.keys(errors).forEach(k => delete errors[k])
  Object.keys(itemErrors).forEach(k => delete itemErrors[k])
  if (!form.patient_name) { errors.patient_name = 'Required'; return }
  let ok = true
  form.items.forEach((it, i) => {
    if (!it.medication_name) { itemErrors[i] = { medication_name: 'Required' }; ok = false }
  })
  if (!ok) return
  saving.value = true
  try {
    await $api.post('/prescriptions/pharmacy-rx/', form)
    notify('Prescription created')
    formDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Save failed', 'error') }
  finally { saving.value = false }
}

const viewDialog = ref(false)
const viewing = ref(null)
async function openView(rx) {
  viewing.value = rx
  viewDialog.value = true
  try {
    const { data } = await $api.get(`/prescriptions/pharmacy-rx/${rx.id}/`)
    viewing.value = data
  } catch { /* keep summary */ }
}

async function updateStatus(rx, status) {
  saving.value = true
  try {
    await $api.patch(`/prescriptions/pharmacy-rx/${rx.id}/`, { status })
    notify(`Marked as ${status}`)
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
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
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

</style>
