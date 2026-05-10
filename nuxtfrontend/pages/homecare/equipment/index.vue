<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Medical Equipment"
      subtitle="Track devices, schedule maintenance and manage patient assignments."
      eyebrow="ASSETS"
      icon="mdi-medical-bag"
      :chips="[
        { icon: 'mdi-cube', label: `${items.length} items` },
        { icon: 'mdi-truck', label: `${assignedCount} assigned` },
        { icon: 'mdi-wrench', label: `${maintenanceDue} due soon` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus"
               class="text-none" @click="openAdd">
          <span class="text-teal-darken-2 font-weight-bold">Add device</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Available" :value="availableCount" icon="mdi-check-circle" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Assigned" :value="assignedCount" icon="mdi-truck-delivery" color="#0ea5e9" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="In maintenance" :value="maintenanceCount" icon="mdi-wrench" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Retired" :value="retiredCount" icon="mdi-archive" color="#94a3b8" /></v-col>
    </v-row>

    <HomecarePanel title="Equipment inventory" subtitle="All trackable assets" icon="mdi-cube"
                   color="#7c3aed" class="mt-3">
      <v-row dense>
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search name, serial, asset tag…"
                        density="compact" variant="outlined" hide-details clearable />
        </v-col>
        <v-col cols="12" md="4">
          <v-select v-model="filterType" :items="typeOptions" item-title="label" item-value="value"
                    label="Type" density="compact" variant="outlined" hide-details clearable />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filterStatus" :items="statusOptions" item-title="label" item-value="value"
                    label="Status" density="compact" variant="outlined" hide-details clearable />
        </v-col>
      </v-row>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id" class="mt-2">
        <template #[`item.device_type`]="{ item }">
          <v-chip size="small" variant="tonal" color="purple">{{ item.device_type_label || item.device_type }}</v-chip>
        </template>
        <template #[`item.status`]="{ item }">
          <StatusChip :status="item.status || 'available'" />
        </template>
        <template #[`item.assigned_to_name`]="{ item }">
          <span v-if="item.assigned_to_name" class="text-body-2">
            <v-icon icon="mdi-account" size="14" /> {{ item.assigned_to_name }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #[`item.next_maintenance_due`]="{ item }">
          <span v-if="item.next_maintenance_due" :class="dueClass(item.next_maintenance_due)">
            {{ formatDate(item.next_maintenance_due) }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn v-if="item.status === 'available'" size="small" variant="text" color="teal"
                 prepend-icon="mdi-account-arrow-right" @click="openAssign(item)">Assign</v-btn>
          <v-btn v-if="item.status === 'assigned'" size="small" variant="text" color="success"
                 prepend-icon="mdi-keyboard-return" @click="returnItem(item)">Return</v-btn>
          <v-btn size="small" variant="text" color="warning"
                 prepend-icon="mdi-wrench" @click="openMaintenance(item)">Service</v-btn>
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- Add device -->
    <v-dialog v-model="dialog" max-width="560">
      <v-card rounded="xl">
        <v-card-title class="text-h6">Add device</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.name" label="Name *" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.device_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Type *" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.serial_number" label="Serial number" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.asset_tag" label="Asset tag" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.manufacturer" label="Manufacturer" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.model_number" label="Model #" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.location" label="Storage location" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.purchase_date" label="Purchased" type="date" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.purchase_cost" label="Cost (KSh)" type="number" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.warranty_expiry" label="Warranty expiry" type="date" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.next_maintenance_due" label="Next maintenance" type="date" />
            </v-col>
          </v-row>
          <v-textarea v-model="form.notes" label="Notes" rows="2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Assign -->
    <v-dialog v-model="assignDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title>Assign to patient</v-card-title>
        <v-card-text>
          <v-select v-model="assignForm.patient" :items="patients"
                    :item-title="patientLabel" item-value="id" label="Patient *" />
          <v-text-field v-model="assignForm.expected_return_at" label="Expected return"
                        type="datetime-local" />
          <v-textarea v-model="assignForm.notes" label="Notes" rows="2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="assignDialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="confirmAssign">Assign</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Schedule maintenance -->
    <v-dialog v-model="maintDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title>Schedule maintenance</v-card-title>
        <v-card-text>
          <v-select v-model="maintForm.kind" :items="maintenanceKinds" item-title="label" item-value="value"
                    label="Kind" />
          <v-text-field v-model="maintForm.scheduled_at" label="Scheduled *" type="datetime-local" />
          <v-textarea v-model="maintForm.notes" label="Notes" rows="2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="maintDialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="scheduleMaintenance">Schedule</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const items = ref([])
const patients = ref([])
const summary = ref({})
const search = ref('')
const filterType = ref(null)
const filterStatus = ref(null)
const loading = ref(false)
const saving = ref(false)

const dialog = ref(false)
const assignDialog = ref(false)
const maintDialog = ref(false)
const target = ref(null)

const form = reactive({
  name: '', device_type: 'oximeter', serial_number: '', asset_tag: '',
  manufacturer: '', model_number: '', location: '',
  purchase_date: '', purchase_cost: null, warranty_expiry: '',
  next_maintenance_due: '', notes: '',
})
const assignForm = reactive({ patient: null, expected_return_at: '', notes: '' })
const maintForm = reactive({ kind: 'routine', scheduled_at: '', notes: '' })

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const typeOptions = [
  { value: 'oximeter', label: 'Pulse Oximeter' },
  { value: 'bp_monitor', label: 'BP Monitor' },
  { value: 'glucometer', label: 'Glucometer' },
  { value: 'thermometer', label: 'Thermometer' },
  { value: 'oxygen', label: 'Oxygen Concentrator' },
  { value: 'nebulizer', label: 'Nebulizer' },
  { value: 'bed', label: 'Hospital Bed' },
  { value: 'wheelchair', label: 'Wheelchair' },
  { value: 'walker', label: 'Walker / Crutches' },
  { value: 'suction', label: 'Suction Machine' },
  { value: 'ventilator', label: 'Ventilator' },
  { value: 'infusion_pump', label: 'Infusion Pump' },
  { value: 'ecg', label: 'ECG Monitor' },
  { value: 'other', label: 'Other' },
]
const statusOptions = [
  { value: 'available', label: 'Available' },
  { value: 'assigned', label: 'Assigned' },
  { value: 'maintenance', label: 'In Maintenance' },
  { value: 'repair', label: 'Needs Repair' },
  { value: 'retired', label: 'Retired' },
  { value: 'lost', label: 'Lost / Missing' },
]
const maintenanceKinds = [
  { value: 'routine', label: 'Routine Service' },
  { value: 'calibration', label: 'Calibration' },
  { value: 'repair', label: 'Repair' },
  { value: 'inspection', label: 'Safety Inspection' },
]

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Type', key: 'device_type' },
  { title: 'Serial', key: 'serial_number' },
  { title: 'Assigned to', key: 'assigned_to_name' },
  { title: 'Next service', key: 'next_maintenance_due' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const filtered = computed(() => {
  const q = (search.value || '').toLowerCase()
  return items.value.filter(i => {
    if (filterType.value && i.device_type !== filterType.value) return false
    if (filterStatus.value && i.status !== filterStatus.value) return false
    if (q && !`${i.name} ${i.serial_number || ''} ${i.asset_tag || ''}`.toLowerCase().includes(q)) return false
    return true
  })
})
const availableCount = computed(() => summary.value.available ?? items.value.filter(i => i.status === 'available').length)
const assignedCount = computed(() => summary.value.assigned ?? items.value.filter(i => i.status === 'assigned').length)
const maintenanceCount = computed(() => summary.value.maintenance ?? items.value.filter(i => i.status === 'maintenance').length)
const retiredCount = computed(() => summary.value.retired ?? items.value.filter(i => i.status === 'retired').length)
const maintenanceDue = computed(() => summary.value.maintenance_due_soon ?? 0)

function patientLabel(p) {
  return p?.user?.full_name || p?.patient_name || `#${p?.id}`
}
function formatDate(d) {
  if (!d) return ''
  try { return new Date(d).toLocaleDateString() } catch { return d }
}
function dueClass(d) {
  if (!d) return ''
  const days = (new Date(d).getTime() - Date.now()) / 86400000
  if (days < 0) return 'text-red font-weight-bold'
  if (days < 14) return 'text-orange font-weight-medium'
  return ''
}

async function load() {
  loading.value = true
  try {
    const [{ data }, { data: s }] = await Promise.all([
      $api.get('/homecare/devices/'),
      $api.get('/homecare/devices/summary/').catch(() => ({ data: {} })),
    ])
    items.value = data?.results || data || []
    summary.value = s || {}
  } catch (e) {
    console.warn('load devices failed', e)
    items.value = []
  } finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}

function openAdd() {
  Object.assign(form, {
    name: '', device_type: 'oximeter', serial_number: '', asset_tag: '',
    manufacturer: '', model_number: '', location: '',
    purchase_date: '', purchase_cost: null, warranty_expiry: '',
    next_maintenance_due: '', notes: '',
  })
  dialog.value = true
}
async function save() {
  if (!form.name) { notify('Name is required.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...form }
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    await $api.post('/homecare/devices/', payload)
    notify('Device added.')
    dialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save device.', 'error')
  } finally { saving.value = false }
}

function openAssign(item) {
  target.value = item
  Object.assign(assignForm, { patient: null, expected_return_at: '', notes: '' })
  assignDialog.value = true
}
async function confirmAssign() {
  if (!assignForm.patient) { notify('Pick a patient.', 'error'); return }
  saving.value = true
  try {
    await $api.post(`/homecare/devices/${target.value.id}/assign/`, assignForm)
    notify('Device assigned.')
    assignDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to assign.', 'error')
  } finally { saving.value = false }
}
async function returnItem(item) {
  try {
    await $api.post(`/homecare/devices/${item.id}/return_device/`, {})
    notify('Device returned.')
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to return.', 'error')
  }
}

function openMaintenance(item) {
  target.value = item
  Object.assign(maintForm, { kind: 'routine', scheduled_at: '', notes: '' })
  maintDialog.value = true
}
async function scheduleMaintenance() {
  if (!maintForm.scheduled_at) { notify('Pick a date.', 'error'); return }
  saving.value = true
  try {
    await $api.post(`/homecare/devices/${target.value.id}/schedule_maintenance/`, maintForm)
    notify('Maintenance scheduled.')
    maintDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to schedule.', 'error')
  } finally { saving.value = false }
}

onMounted(() => { load(); loadPatients() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
</style>
