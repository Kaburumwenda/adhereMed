<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Medical Equipment"
      subtitle="Track devices, set hire rates, schedule maintenance and manage patient assignments."
      eyebrow="ASSETS & RENTALS"
      icon="mdi-medical-bag"
      :chips="[
        { icon: 'mdi-cube', label: `${items.length} items` },
        { icon: 'mdi-truck', label: `${assignedCount} on hire` },
        { icon: 'mdi-wrench', label: `${maintenanceDue} service due` },
        { icon: 'mdi-cash', label: `${money(summary.realized_revenue)} earned` },
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
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="On hire" :value="assignedCount" icon="mdi-truck-delivery" color="#0ea5e9" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="In maintenance" :value="maintenanceCount" icon="mdi-wrench" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Deposits held" :value="money(summary.deposits_held)" icon="mdi-safe" color="#8b5cf6" /></v-col>
    </v-row>

    <HomecarePanel title="Equipment inventory" subtitle="All trackable assets & hire pricing" icon="mdi-cube"
                   color="#7c3aed" class="mt-3">
      <v-tabs v-model="tab" color="teal" density="compact" class="mb-2">
        <v-tab value="all">All <v-chip size="x-small" class="ml-1" variant="tonal">{{ counts.all }}</v-chip></v-tab>
        <v-tab value="available">Available <v-chip size="x-small" class="ml-1" variant="tonal" color="success">{{ counts.available }}</v-chip></v-tab>
        <v-tab value="on_hire">On hire <v-chip size="x-small" class="ml-1" variant="tonal" color="info">{{ counts.on_hire }}</v-chip></v-tab>
        <v-tab value="almost_out">Almost out <v-chip size="x-small" class="ml-1" variant="tonal" color="warning">{{ counts.almost_out }}</v-chip></v-tab>
      </v-tabs>
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
      <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id" class="mt-2 hc-table">
        <template #[`item.name`]="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar size="34" :color="typeColor(item.device_type)" variant="tonal" class="mr-2">
              <v-icon :icon="typeIcon(item.device_type)" size="18" />
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ item.manufacturer || '—' }}<span v-if="item.model_number"> · {{ item.model_number }}</span>
              </div>
            </div>
          </div>
        </template>
        <template #[`item.device_type`]="{ item }">
          <v-chip size="small" variant="tonal" color="purple">{{ item.device_type_label || item.device_type }}</v-chip>
        </template>
        <template #[`item.stock`]="{ item }">
          <v-chip size="small" variant="tonal" :color="stockColor(item)">
            {{ item.quantity_available ?? 0 }} / {{ item.quantity ?? 0 }}
          </v-chip>
          <div v-if="item.quantity_on_hire" class="text-caption text-medium-emphasis mt-1">
            {{ item.quantity_on_hire }} on hire
          </div>
        </template>
        <template #[`item.hire`]="{ item }">
          <div v-if="item.is_rentable" class="text-body-2">
            <span class="font-weight-bold">{{ money(primaryRate(item), item.currency) }}</span>
            <span class="text-medium-emphasis"> / {{ periodShort(item.default_hire_period) }}</span>
          </div>
          <v-chip v-else size="x-small" variant="tonal" color="grey">Not for hire</v-chip>
        </template>
        <template #[`item.status`]="{ item }">
          <StatusChip :status="item.status || 'available'" />
        </template>
        <template #[`item.next_maintenance_due`]="{ item }">
          <span v-if="item.next_maintenance_due" :class="dueClass(item.next_maintenance_due)">
            {{ formatDate(item.next_maintenance_due) }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-menu location="bottom end">
            <template #activator="{ props }">
              <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
            </template>
            <v-list density="compact" min-width="200">
              <v-list-item prepend-icon="mdi-history" title="History & details" @click="openHistory(item)" />
              <v-list-item v-if="(item.quantity_available ?? 0) > 0 && !['maintenance','repair','retired','lost'].includes(item.status)"
                           prepend-icon="mdi-account-arrow-right"
                           title="Assign / hire out" @click="openAssign(item)" />
              <v-list-item v-if="(item.quantity_on_hire ?? 0) > 0" prepend-icon="mdi-keyboard-return"
                           title="Return device" @click="openReturn(item)" />
              <v-list-item prepend-icon="mdi-wrench" title="Schedule maintenance" @click="openMaintenance(item)" />
              <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="openEdit(item)" />
              <v-divider />
              <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error" @click="confirmDelete(item)" />
            </v-list>
          </v-menu>
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- Add / edit device -->
    <v-dialog v-model="dialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon :icon="editingId ? 'mdi-pencil' : 'mdi-plus'" class="mr-2" />
          {{ editingId ? 'Edit device' : 'Add device' }}
        </v-card-title>
        <v-divider />
        <v-card-text style="max-height:70vh">
          <div class="text-overline text-medium-emphasis mt-1">Identity</div>
          <v-text-field v-model="form.name" label="Name *" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.device_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Type *" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.status" :items="statusOptions" item-title="label" item-value="value"
                        label="Status" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.serial_number" label="Serial number" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.asset_tag" label="Asset tag" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.manufacturer" label="Manufacturer" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.model_number" label="Model #" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.location" label="Storage location" density="comfortable" variant="outlined" /></v-col>
          </v-row>

          <div class="text-overline text-medium-emphasis mt-3">Stock</div>
          <v-row dense>
            <v-col cols="12" sm="4"><v-text-field v-model.number="form.quantity" label="Total quantity *" type="number" min="1" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="4"><v-text-field v-model.number="form.quantity_available" label="Available now" type="number" min="0" density="comfortable" variant="outlined" :hint="editingId ? '' : 'Defaults to total'" persistent-hint /></v-col>
            <v-col cols="12" sm="4"><v-text-field v-model.number="form.low_stock_threshold" label="Low-stock alert at ≤" type="number" min="0" density="comfortable" variant="outlined" /></v-col>
          </v-row>

          <div class="text-overline text-medium-emphasis mt-3">Hire pricing ({{ form.currency }})</div>
          <v-switch v-model="form.is_rentable" color="teal" label="Available for hire" density="compact" hide-details class="mb-2" />
          <template v-if="form.is_rentable">
            <v-row dense>
              <v-col cols="6" sm="3"><v-text-field v-model.number="form.hourly_rate" label="Hourly" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
              <v-col cols="6" sm="3"><v-text-field v-model.number="form.daily_rate" label="Daily" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
              <v-col cols="6" sm="3"><v-text-field v-model.number="form.weekly_rate" label="Weekly" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
              <v-col cols="6" sm="3"><v-text-field v-model.number="form.monthly_rate" label="Monthly" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
              <v-col cols="12" sm="6">
                <v-select v-model="form.default_hire_period" :items="periodOptions" item-title="label" item-value="value"
                          label="Default billing period" density="comfortable" variant="outlined" />
              </v-col>
              <v-col cols="12" sm="6"><v-text-field v-model.number="form.deposit" label="Refundable deposit" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
            </v-row>
          </template>

          <div class="text-overline text-medium-emphasis mt-3">Asset & maintenance</div>
          <v-row dense>
            <v-col cols="12" sm="6"><v-text-field v-model="form.purchase_date" label="Purchased" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model.number="form.purchase_cost" label="Purchase cost" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.warranty_expiry" label="Warranty expiry" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.next_maintenance_due" label="Next maintenance" type="date" density="comfortable" variant="outlined" /></v-col>
          </v-row>
          <v-textarea v-model="form.notes" label="Notes" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Assign / hire -->
    <v-dialog v-model="assignDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-account-arrow-right" class="mr-2" />Hire out device</v-card-title>
        <v-divider />
        <v-card-text>
          <div v-if="target" class="d-flex align-center justify-space-between mb-3">
            <span class="text-body-2 text-medium-emphasis">{{ target.name }}</span>
            <v-chip size="small" variant="tonal" :color="stockColor(target)">
              {{ target.quantity_available ?? 0 }} available
            </v-chip>
          </div>
          <v-btn-toggle v-model="assignForm.hire_to_type" mandatory density="comfortable"
                        color="teal" variant="outlined" class="mb-3" divided>
            <v-btn value="patient" prepend-icon="mdi-account">Patient</v-btn>
            <v-btn value="facility" prepend-icon="mdi-hospital-building">Facility / Homecare</v-btn>
          </v-btn-toggle>
          <v-select v-if="assignForm.hire_to_type === 'patient'" v-model="assignForm.patient" :items="patients"
                    :item-title="patientLabel" item-value="id" label="Patient *"
                    density="comfortable" variant="outlined" />
          <v-text-field v-else v-model="assignForm.facility_name"
                        label="Facility / homecare name *" prepend-inner-icon="mdi-hospital-building"
                        density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="assignForm.hire_period" :items="periodOptions" item-title="label" item-value="value"
                        label="Billing period" density="comfortable" variant="outlined" @update:model-value="syncRate" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="assignForm.hire_rate" label="Rate" type="number"
                            density="comfortable" variant="outlined" prefix="KSh"
                            :suffix="`/ ${periodShort(assignForm.hire_period)}`" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="assignForm.assigned_at" label="Start date *"
                            type="datetime-local" density="comfortable" variant="outlined" />
            </v-col>
            <v-col v-if="assignForm.hire_period === 'hourly'" cols="12" sm="6">
              <v-text-field v-model.number="assignForm.hours" label="Number of hours *" type="number"
                            min="1" density="comfortable" variant="outlined" suffix="hrs" />
            </v-col>
            <v-col v-else cols="12" sm="6">
              <v-text-field v-model="assignForm.expected_return_at" label="Expected return *"
                            type="datetime-local" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="assignForm.deposit" label="Deposit (refundable)" type="number"
                            density="comfortable" variant="outlined" prefix="KSh" />
            </v-col>
          </v-row>

          <v-sheet rounded="lg" color="teal-lighten-5" class="pa-3 my-2">
            <div class="d-flex align-center justify-space-between">
              <div class="text-body-2">
                <v-icon icon="mdi-calculator-variant" size="16" class="mr-1" />
                {{ hireUnits }} {{ unitLabel }} × {{ money(assignForm.hire_rate) }}
              </div>
              <div class="text-h6 font-weight-bold text-teal-darken-3">{{ money(estimatedTotal) }}</div>
            </div>
            <div v-if="assignForm.deposit" class="text-caption text-medium-emphasis mt-1">
              + {{ money(assignForm.deposit) }} refundable deposit ·
              collect {{ money(estimatedTotal + Number(assignForm.deposit || 0)) }} up front
            </div>
            <div v-if="assignForm.hire_period !== 'hourly' && computedReturn" class="text-caption text-medium-emphasis mt-1">
              <v-icon icon="mdi-calendar-end" size="14" /> Ends {{ formatDateTime(assignForm.expected_return_at) }}
            </div>
          </v-sheet>

          <v-textarea v-model="assignForm.notes" label="Notes" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="assignDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="confirmAssign">Hire out</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Return -->
    <v-dialog v-model="returnDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-keyboard-return" class="mr-2" />Return device</v-card-title>
        <v-divider />
        <v-card-text>
          <div v-if="target" class="text-body-2 text-medium-emphasis mb-3">{{ target.name }}</div>
          <v-select v-model="returnForm.condition" :items="conditionOptions"
                    label="Return condition" density="comfortable" variant="outlined" />
          <v-text-field v-model.number="returnForm.total_charged" label="Total hire charge (KSh)"
                        type="number" density="comfortable" variant="outlined"
                        hint="Leave blank to auto-calculate from duration × rate" persistent-hint />
          <v-textarea v-model="returnForm.notes" label="Notes" rows="2" density="comfortable" variant="outlined" class="mt-2" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="returnDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" :loading="saving" @click="confirmReturn">Confirm return</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Schedule maintenance -->
    <v-dialog v-model="maintDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-wrench" class="mr-2" />Schedule maintenance</v-card-title>
        <v-divider />
        <v-card-text>
          <div v-if="target" class="text-body-2 text-medium-emphasis mb-3">{{ target.name }}</div>
          <v-select v-model="maintForm.kind" :items="maintenanceKinds" item-title="label" item-value="value"
                    label="Kind" density="comfortable" variant="outlined" />
          <v-text-field v-model="maintForm.scheduled_at" label="Scheduled *" type="datetime-local"
                        density="comfortable" variant="outlined" />
          <v-textarea v-model="maintForm.notes" label="Notes" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="maintDialog = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" :loading="saving" @click="scheduleMaintenance">Schedule</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- History drawer -->
    <v-dialog v-model="historyDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-history" class="mr-2" />
          {{ target?.name }} — history
        </v-card-title>
        <v-divider />
        <v-card-text style="max-height:70vh">
          <div class="text-overline text-medium-emphasis">Hire assignments</div>
          <v-table v-if="history.assignments?.length" density="compact">
            <thead>
              <tr><th>Hired to</th><th>From</th><th>Returned</th><th>Rate</th><th class="text-right">Charge</th></tr>
            </thead>
            <tbody>
              <tr v-for="a in history.assignments" :key="a.id">
                <td>
                  <v-icon :icon="a.hire_to_type === 'facility' ? 'mdi-hospital-building' : 'mdi-account'" size="14" class="mr-1" />
                  {{ a.hire_to_name || a.patient_name || a.facility_name || '—' }}
                </td>
                <td>{{ formatDate(a.assigned_at) }}</td>
                <td>{{ a.returned_at ? formatDate(a.returned_at) : '— on hire —' }}</td>
                <td><span v-if="a.hire_rate">{{ money(a.hire_rate) }}/{{ periodShort(a.hire_period) }}</span><span v-else>—</span></td>
                <td class="text-right">{{ money(a.total_charged ?? a.estimated_charge) }}</td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-truck" title="No hires yet" />

          <div class="text-overline text-medium-emphasis mt-4">Maintenance</div>
          <v-table v-if="history.maintenance?.length" density="compact">
            <thead>
              <tr><th>Kind</th><th>Scheduled</th><th>Status</th><th class="text-right">Cost</th></tr>
            </thead>
            <tbody>
              <tr v-for="m in history.maintenance" :key="m.id">
                <td>{{ m.kind_label || m.kind }}</td>
                <td>{{ formatDate(m.scheduled_at) }}</td>
                <td><v-chip size="x-small" variant="tonal">{{ m.status_label || m.status }}</v-chip></td>
                <td class="text-right">{{ money(m.cost) }}</td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-wrench" title="No maintenance recorded" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="historyDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete device?</v-card-title>
        <v-card-text>This permanently removes <b>{{ target?.name }}</b> and its history.</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">Delete</v-btn>
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
const tab = ref('all')
const loading = ref(false)
const saving = ref(false)

const dialog = ref(false)
const assignDialog = ref(false)
const returnDialog = ref(false)
const maintDialog = ref(false)
const historyDialog = ref(false)
const deleteDialog = ref(false)
const target = ref(null)
const editingId = ref(null)
const history = ref({ assignments: [], maintenance: [] })

const blankForm = () => ({
  name: '', device_type: 'oximeter', status: 'available', serial_number: '', asset_tag: '',
  manufacturer: '', model_number: '', location: '', currency: 'KES',
  quantity: 1, quantity_available: null, low_stock_threshold: 1,
  is_rentable: true, hourly_rate: null, daily_rate: null, weekly_rate: null,
  monthly_rate: null, deposit: null, default_hire_period: 'daily',
  purchase_date: '', purchase_cost: null, warranty_expiry: '',
  next_maintenance_due: '', notes: '',
})
const form = reactive(blankForm())
const assignForm = reactive({ patient: null, hire_to_type: 'patient', facility_name: '', hire_period: 'daily', hire_rate: null, deposit: null, assigned_at: '', expected_return_at: '', hours: 1, notes: '' })
const returnForm = reactive({ condition: 'Good', total_charged: null, notes: '' })
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
const periodOptions = [
  { value: 'hourly', label: 'Per Hour' },
  { value: 'daily', label: 'Per Day' },
  { value: 'weekly', label: 'Per Week' },
  { value: 'monthly', label: 'Per Month' },
]
const maintenanceKinds = [
  { value: 'routine', label: 'Routine Service' },
  { value: 'calibration', label: 'Calibration' },
  { value: 'repair', label: 'Repair' },
  { value: 'inspection', label: 'Safety Inspection' },
]
const conditionOptions = ['Good', 'Fair', 'Damaged', 'Needs repair', 'Lost']

const typeMeta = {
  oximeter: ['mdi-heart-pulse', '#ef4444'], bp_monitor: ['mdi-gauge', '#0ea5e9'],
  glucometer: ['mdi-water', '#f59e0b'], thermometer: ['mdi-thermometer', '#f97316'],
  oxygen: ['mdi-scuba-tank', '#06b6d4'], nebulizer: ['mdi-air-humidifier', '#14b8a6'],
  bed: ['mdi-bed', '#8b5cf6'], wheelchair: ['mdi-wheelchair-accessibility', '#6366f1'],
  walker: ['mdi-walk', '#0d9488'], suction: ['mdi-pump', '#64748b'],
  ventilator: ['mdi-lungs', '#dc2626'], infusion_pump: ['mdi-iv-bag', '#3b82f6'],
  ecg: ['mdi-chart-line-variant', '#e11d48'], other: ['mdi-medical-bag', '#7c3aed'],
}
function typeIcon(t) { return (typeMeta[t] || typeMeta.other)[0] }
function typeColor(t) { return (typeMeta[t] || typeMeta.other)[1] }
function stockColor(item) {
  const status = item?.stock_status
  if (status === 'out' || (item?.quantity_available ?? 0) <= 0) return 'error'
  if (status === 'low' || (item?.quantity_available ?? 0) <= (item?.low_stock_threshold ?? 1)) return 'warning'
  return 'success'
}

const headers = [
  { title: 'Device', key: 'name' },
  { title: 'Type', key: 'device_type' },
  { title: 'Stock', key: 'stock', sortable: false },
  { title: 'Hire rate', key: 'hire', sortable: false },
  { title: 'Next service', key: 'next_maintenance_due' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

function isAvailable(i) {
  return (i.quantity_available ?? 0) > 0 && !['maintenance', 'repair', 'retired', 'lost'].includes(i.status)
}
function isOnHire(i) { return (i.quantity_on_hire ?? 0) > 0 }
function isAlmostOut(i) {
  const avail = i.quantity_available ?? 0
  return avail > 0 && avail <= (i.low_stock_threshold ?? 1)
}
function matchesTab(i) {
  if (tab.value === 'available') return isAvailable(i)
  if (tab.value === 'on_hire') return isOnHire(i)
  if (tab.value === 'almost_out') return isAlmostOut(i)
  return true
}

const counts = computed(() => ({
  all: items.value.length,
  available: items.value.filter(isAvailable).length,
  on_hire: items.value.filter(isOnHire).length,
  almost_out: items.value.filter(isAlmostOut).length,
}))

const filtered = computed(() => {
  const q = (search.value || '').toLowerCase()
  return items.value.filter(i => {
    if (!matchesTab(i)) return false
    if (filterType.value && i.device_type !== filterType.value) return false
    if (filterStatus.value && i.status !== filterStatus.value) return false
    if (q && !`${i.name} ${i.serial_number || ''} ${i.asset_tag || ''} ${i.manufacturer || ''}`.toLowerCase().includes(q)) return false
    return true
  })
})
const availableCount = computed(() => summary.value.available ?? items.value.filter(i => i.status === 'available').length)
const assignedCount = computed(() => summary.value.assigned ?? items.value.filter(i => i.status === 'assigned').length)
const maintenanceCount = computed(() => summary.value.maintenance ?? items.value.filter(i => i.status === 'maintenance').length)
const maintenanceDue = computed(() => summary.value.maintenance_due_soon ?? 0)

function primaryRate(item) {
  return item[`${item.default_hire_period}_rate`] ?? item.daily_rate ?? item.hourly_rate ?? item.weekly_rate ?? item.monthly_rate
}
function periodShort(p) {
  return { hourly: 'hr', daily: 'day', weekly: 'wk', monthly: 'mo' }[p] || p || 'day'
}
function money(v, currency = 'KES') {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  const prefix = currency === 'KES' ? 'KSh ' : ''
  return prefix + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}
function patientLabel(p) {
  const name = p?.patient_name || p?.user?.full_name || p?.medical_record_number || `#${p?.id}`
  const adId = p?.adheremed_patient_id || p?.medical_record_number
  return adId ? `${name} · ${adId}` : name
}
function formatDate(d) {
  if (!d) return ''
  try { return new Date(d).toLocaleDateString() } catch { return d }
}
function formatDateTime(d) {
  if (!d) return ''
  try { return new Date(d).toLocaleString() } catch { return d }
}
function nowLocal() {
  const d = new Date()
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset())
  return d.toISOString().slice(0, 16)
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
      $api.get('/homecare/devices/', { params: { page_size: 500 } }),
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
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 500 } })
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}

function openAdd() {
  editingId.value = null
  Object.assign(form, blankForm())
  dialog.value = true
}
function openEdit(item) {
  editingId.value = item.id
  Object.assign(form, blankForm(), {
    ...item,
    purchase_date: item.purchase_date || '',
    warranty_expiry: item.warranty_expiry || '',
    next_maintenance_due: item.next_maintenance_due || '',
  })
  dialog.value = true
}
async function save() {
  if (!form.name) { notify('Name is required.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...form }
    delete payload.id
    if (!payload.quantity || payload.quantity < 1) payload.quantity = 1
    if (payload.quantity_available === null || payload.quantity_available === '') {
      payload.quantity_available = payload.quantity
    }
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    if (editingId.value) {
      await $api.patch(`/homecare/devices/${editingId.value}/`, payload)
      notify('Device updated.')
    } else {
      await $api.post('/homecare/devices/', payload)
      notify('Device added.')
    }
    dialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save device.', 'error')
  } finally { saving.value = false }
}

function openAssign(item) {
  target.value = item
  Object.assign(assignForm, {
    patient: null, hire_to_type: 'patient', facility_name: '',
    hire_period: item.default_hire_period || 'daily',
    hire_rate: primaryRate(item) ?? null, deposit: item.deposit ?? null,
    assigned_at: nowLocal(), expected_return_at: '', hours: 1, notes: '',
  })
  assignDialog.value = true
}
function syncRate(period) {
  if (target.value) assignForm.hire_rate = target.value[`${period}_rate`] ?? assignForm.hire_rate
}
const unitLabel = computed(() => {
  const map = { hourly: 'hour', daily: 'day', weekly: 'week', monthly: 'month' }
  const base = map[assignForm.hire_period] || 'unit'
  return hireUnits.value === 1 ? base : base + 's'
})
const hireUnits = computed(() => {
  if (assignForm.hire_period === 'hourly') return Math.max(Number(assignForm.hours) || 0, 0)
  const start = assignForm.assigned_at ? new Date(assignForm.assigned_at) : null
  const end = assignForm.expected_return_at ? new Date(assignForm.expected_return_at) : null
  if (!start || !end || end <= start) return 0
  const secs = (end - start) / 1000
  const per = { daily: 86400, weekly: 604800, monthly: 2592000 }[assignForm.hire_period] || 86400
  return Math.max(Math.ceil(secs / per), 1)
})
const estimatedTotal = computed(() => (Number(assignForm.hire_rate) || 0) * hireUnits.value)
const computedReturn = computed(() => hireUnits.value > 0)
async function confirmAssign() {
  if (assignForm.hire_to_type === 'patient' && !assignForm.patient) { notify('Pick a patient.', 'error'); return }
  if (assignForm.hire_to_type === 'facility' && !assignForm.facility_name) { notify('Enter the facility name.', 'error'); return }
  if (!assignForm.assigned_at) { notify('Pick a start date.', 'error'); return }
  const payload = {
    hire_to_type: assignForm.hire_to_type,
    patient: assignForm.hire_to_type === 'patient' ? assignForm.patient : null,
    facility_name: assignForm.hire_to_type === 'facility' ? assignForm.facility_name : '',
    hire_period: assignForm.hire_period,
    hire_rate: assignForm.hire_rate,
    deposit: assignForm.deposit,
    assigned_at: new Date(assignForm.assigned_at).toISOString(),
    notes: assignForm.notes,
  }
  if (assignForm.hire_period === 'hourly') {
    const hrs = Math.max(Number(assignForm.hours) || 0, 1)
    payload.expected_return_at = new Date(new Date(assignForm.assigned_at).getTime() + hrs * 3600000).toISOString()
  } else if (assignForm.expected_return_at) {
    payload.expected_return_at = new Date(assignForm.expected_return_at).toISOString()
  }
  saving.value = true
  try {
    await $api.post(`/homecare/devices/${target.value.id}/assign/`, payload)
    notify('Device hired out.')
    assignDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to assign.', 'error')
  } finally { saving.value = false }
}

function openReturn(item) {
  target.value = item
  Object.assign(returnForm, { condition: 'Good', total_charged: null, notes: '' })
  returnDialog.value = true
}
async function confirmReturn() {
  saving.value = true
  try {
    const payload = { condition: returnForm.condition, notes: returnForm.notes }
    if (returnForm.total_charged !== null && returnForm.total_charged !== '') payload.total_charged = returnForm.total_charged
    await $api.post(`/homecare/devices/${target.value.id}/return_device/`, payload)
    notify('Device returned.')
    returnDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to return.', 'error')
  } finally { saving.value = false }
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

async function openHistory(item) {
  target.value = item
  history.value = { assignments: [], maintenance: [] }
  historyDialog.value = true
  try {
    const { data } = await $api.get(`/homecare/devices/${item.id}/history/`)
    history.value = data || { assignments: [], maintenance: [] }
  } catch { /* keep empty */ }
}

function confirmDelete(item) {
  target.value = item
  deleteDialog.value = true
}
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/homecare/devices/${target.value.id}/`)
    notify('Device deleted.')
    deleteDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to delete.', 'error')
  } finally { saving.value = false }
}

onMounted(() => { load(); loadPatients() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
