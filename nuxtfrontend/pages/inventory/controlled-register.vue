<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="red-lighten-5" size="48" class="mr-3">
          <v-icon color="red-darken-2" size="28">mdi-shield-lock-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Controlled Substance Register</h1>
          <div class="text-body-2 text-medium-emphasis">Regulatory-grade audit trail for all controlled medications</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" @click="openCreate">{{ $t('controlled.manualEntry') }}</v-btn>
      <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-printer" @click="printRegister">{{ $t('common.print') }}</v-btn>
      <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">{{ $t('common.refresh') }}</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
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
        <v-col cols="12" md="3">
          <v-text-field v-model="filters.medication_name" prepend-inner-icon="mdi-pill"
                        label="Medication" density="comfortable" hide-details
                        variant="outlined" clearable @update:model-value="debouncedLoad" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="filters.action" :items="actionOptions" item-title="label" item-value="value"
                    label="Action" variant="outlined" density="comfortable" hide-details @update:model-value="load" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="filters.schedule" :items="scheduleOptions" label="Schedule"
                    variant="outlined" density="comfortable" hide-details clearable @update:model-value="load" />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="filters.date_from" type="date" label="From"
                        variant="outlined" density="comfortable" hide-details @update:model-value="load" />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="filters.date_to" type="date" label="To"
                        variant="outlined" density="comfortable" hide-details @update:model-value="load" />
        </v-col>
        <v-col cols="12" md="1">
          <v-btn block variant="text" @click="resetFilters">Reset</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="entries" :loading="loading" items-per-page="25" density="comfortable">
        <template #item.created_at="{ item }">
          <div class="text-caption">{{ formatDate(item.created_at) }}</div>
        </template>
        <template #item.medication_name="{ item }">
          <div class="font-weight-medium">{{ item.medication_name }}</div>
          <v-chip v-if="item.schedule" size="x-small" variant="tonal" color="red">{{ item.schedule }}</v-chip>
        </template>
        <template #item.action="{ item }">
          <v-chip size="small" variant="flat" :color="actionColor(item.action)">
            <v-icon start size="14">{{ actionIcon(item.action) }}</v-icon>
            {{ actionLabel(item.action) }}
          </v-chip>
        </template>
        <template #item.quantity="{ item }">
          <span :class="item.action === 'received' ? 'text-success' : 'text-error'" class="font-weight-bold">
            {{ item.action === 'received' ? '+' : '-' }}{{ item.quantity }}
          </span>
        </template>
        <template #item.balance_after="{ item }">
          <strong>{{ item.balance_after ?? '—' }}</strong>
        </template>
        <template #item.patient="{ item }">
          <div v-if="item.patient_name">{{ item.patient_name }}</div>
          <div v-if="item.patient_id_number" class="text-caption text-medium-emphasis">ID: {{ item.patient_id_number }}</div>
          <div v-if="!item.patient_name && !item.patient_id_number" class="text-medium-emphasis">—</div>
        </template>
        <template #item.prescriber="{ item }">
          <div>{{ item.prescriber_name || '—' }}</div>
          <div v-if="item.prescription_reference" class="text-caption text-medium-emphasis">{{ item.prescription_reference }}</div>
        </template>
        <template #no-data>
          <div class="text-center pa-6">
            <v-icon size="48" color="grey-lighten-1">mdi-shield-off-outline</v-icon>
            <div class="text-body-2 mt-2">No controlled-substance entries.</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Manual entry dialog -->
    <v-dialog v-model="createDialog" max-width="640" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-pencil-plus</v-icon>Manual Register Entry
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="createDialog = false" />
        </v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="8">
              <v-text-field v-model="form.medication_name" label="Medication name *" :rules="req"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.schedule" :items="scheduleOptions" label="Schedule"
                        variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.action" :items="actionOptions.filter(a => a.value !== 'all')"
                        item-title="label" item-value="value"
                        label="Action *" variant="outlined" density="comfortable" :rules="req" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.quantity" type="number" min="0" label="Quantity *"
                            :rules="req" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.batch_number" label="Batch number"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.balance_after" type="number" label="Balance after"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.patient_name" label="Patient name"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.patient_id_number" label="Patient ID"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.prescriber_name" label="Prescriber"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.prescription_reference" label="Prescription ref"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" :disabled="!canSave" @click="save">Record Entry</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const entries = ref([])
const stats = ref({})
const createDialog = ref(false)
const snack = ref({ show: false, color: 'success', text: '' })
const req = [v => v !== null && v !== undefined && v !== '' || 'Required']

const filters = ref({ medication_name: '', action: 'all', schedule: null, date_from: '', date_to: '' })

const actionOptions = [
  { label: 'All', value: 'all' },
  { label: 'Dispensed', value: 'dispensed' },
  { label: 'Received', value: 'received' },
  { label: 'Adjusted', value: 'adjusted' },
  { label: 'Destroyed', value: 'destroyed' },
  { label: 'Transferred', value: 'transferred' },
  { label: 'Returned', value: 'returned' },
]
const scheduleOptions = ['Schedule I', 'Schedule II', 'Schedule III', 'Schedule IV', 'Schedule V']

const headers = [
  { title: 'Date / Time', key: 'created_at', width: 160 },
  { title: 'Medication', key: 'medication_name' },
  { title: 'Action', key: 'action', width: 140 },
  { title: 'Qty', key: 'quantity', width: 90, align: 'end' },
  { title: 'Balance', key: 'balance_after', width: 100, align: 'end' },
  { title: 'Batch', key: 'batch_number', width: 120 },
  { title: 'Patient', key: 'patient' },
  { title: 'Prescriber', key: 'prescriber' },
  { title: 'Recorded by', key: 'recorded_by_name', width: 150 },
]

const form = ref(blank())
function blank() {
  return { medication_name: '', schedule: null, action: 'adjusted', quantity: 0, balance_after: null,
           batch_number: '', patient_name: '', patient_id_number: '', prescriber_name: '', prescription_reference: '', notes: '' }
}
const canSave = computed(() => form.value.medication_name && form.value.action && form.value.quantity > 0)

const kpis = computed(() => {
  const byA = stats.value.by_action || {}
  return [
    { label: 'Total Entries', value: stats.value.total || entries.value.length, icon: 'mdi-shield-check', color: 'red' },
    { label: 'Dispensed', value: byA.dispensed || 0, icon: 'mdi-pill', color: 'blue' },
    { label: 'Received', value: byA.received || 0, icon: 'mdi-package-down', color: 'green' },
    { label: 'Destroyed', value: byA.destroyed || 0, icon: 'mdi-fire', color: 'deep-orange' },
  ]
})

let loadTimer = null
function debouncedLoad() {
  clearTimeout(loadTimer)
  loadTimer = setTimeout(load, 350)
}

async function load() {
  loading.value = true
  try {
    const params = {}
    if (filters.value.action && filters.value.action !== 'all') params.action = filters.value.action
    if (filters.value.medication_name) params.medication_name = filters.value.medication_name
    if (filters.value.schedule) params.schedule = filters.value.schedule
    if (filters.value.date_from) params.date_from = filters.value.date_from
    if (filters.value.date_to) params.date_to = filters.value.date_to

    const [list, st] = await Promise.all([
      $api.get('/inventory/controlled-register/', { params }).then(r => r.data?.results || r.data || []),
      $api.get('/inventory/controlled-register/stats/', { params }).then(r => r.data).catch(() => ({})),
    ])
    entries.value = list
    stats.value = st
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

function resetFilters() {
  filters.value = { medication_name: '', action: 'all', schedule: null, date_from: '', date_to: '' }
  load()
}

function openCreate() { form.value = blank(); createDialog.value = true }

async function save() {
  if (!canSave.value) return
  saving.value = true
  try {
    await $api.post('/inventory/controlled-register/', form.value)
    showSnack('Entry recorded', 'success')
    createDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
  finally { saving.value = false }
}

function printRegister() { window.print() }

function actionLabel(a) { return ({ dispensed: 'Dispensed', received: 'Received', adjusted: 'Adjusted', destroyed: 'Destroyed', transferred: 'Transferred', returned: 'Returned' })[a] || a }
function actionColor(a) { return ({ dispensed: 'blue', received: 'green', adjusted: 'amber', destroyed: 'deep-orange', transferred: 'purple', returned: 'cyan' })[a] || 'grey' }
function actionIcon(a) { return ({ dispensed: 'mdi-pill', received: 'mdi-package-down', adjusted: 'mdi-pencil', destroyed: 'mdi-fire', transferred: 'mdi-truck', returned: 'mdi-keyboard-return' })[a] || 'mdi-circle' }
function formatDate(d) { return d ? new Date(d).toLocaleString() : '' }
function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }

onMounted(load)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

@media print {  }
</style>
