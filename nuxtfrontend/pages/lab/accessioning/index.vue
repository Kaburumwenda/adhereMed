<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-barcode-scan</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Accessioning</div>
        <div class="text-body-2 text-medium-emphasis">
          Register, receive, and track specimens through the lab
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="r.list()">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew()">
        Register Specimen
      </v-btn>
    </div>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3" lg="2">
        <v-card flat rounded="lg" class="kpi pa-3"
                :class="{ 'is-active': statusFilter === k.statusValue }"
                @click="toggleStatus(k.statusValue)">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Scanner / quick receive -->
    <v-card flat rounded="lg" class="mt-4 pa-3 scan-card">
      <v-row dense align="center">
        <v-col cols="12" md="6">
          <div class="d-flex align-center">
            <v-avatar color="indigo-darken-2" size="34" class="mr-3">
              <v-icon color="white" size="20">mdi-barcode-scan</v-icon>
            </v-avatar>
            <v-text-field
              ref="scanInput"
              v-model="scanValue"
              placeholder="Scan or type accession # / barcode and press Enter"
              variant="outlined" density="compact" hide-details clearable autofocus
              prepend-inner-icon="mdi-magnify"
              @keyup.enter="processScan"
            />
          </div>
        </v-col>
        <v-col cols="12" md="6" class="text-md-right">
          <v-chip-group v-model="scanAction" mandatory selected-class="bg-primary">
            <v-chip value="receive" size="small" filter variant="tonal" color="primary">
              <v-icon start size="14">mdi-check</v-icon>Receive on scan
            </v-chip>
            <v-chip value="lookup" size="small" filter variant="tonal">
              <v-icon start size="14">mdi-magnify</v-icon>Lookup only
            </v-chip>
          </v-chip-group>
        </v-col>
      </v-row>
    </v-card>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by accession, barcode, patient…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="containerFilter" :items="containerOptions"
                    label="Container" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dateFilter" :items="dateOptions"
                    label="Date" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end ga-2">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>Reset
          </v-btn>
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="cards" icon="mdi-view-grid-outline" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- Status pills -->
    <div class="d-flex flex-wrap ga-2 mt-3">
      <v-chip
        v-for="s in statusPills" :key="s.value || 'all'"
        :color="statusFilter === s.value ? s.color : undefined"
        :variant="statusFilter === s.value ? 'flat' : 'tonal'"
        size="small" class="text-capitalize"
        @click="statusFilter = s.value"
      >
        <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
        {{ s.label }}
        <span class="ml-2 font-weight-bold">{{ s.count }}</span>
      </v-chip>
    </div>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        class="acc-table"
        @click:row="(_, { item }) => openEdit(item)"
      >
        <template #item.accession_number="{ value }">
          <span class="font-monospace text-caption font-weight-bold">{{ value || '—' }}</span>
        </template>
        <template #item.barcode="{ value }">
          <span v-if="value" class="font-monospace text-caption">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="hashColor(item.id)" size="30" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
          </div>
        </template>
        <template #item.container_type="{ value }">
          <v-chip size="x-small" variant="tonal" :color="containerColor(value)">
            <v-icon size="12" start>{{ containerIcon(value) }}</v-icon>
            {{ containerLabel(value) }}
          </v-chip>
        </template>
        <template #item.volume_ml="{ value }">
          <span v-if="value">{{ value }} <span class="text-caption text-medium-emphasis">ml</span></span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.status="{ value }">
          <v-chip size="x-small" variant="tonal" :color="statusColor(value)" class="text-capitalize">
            <v-icon size="12" start>{{ statusIcon(value) }}</v-icon>{{ statusLabel(value) }}
          </v-chip>
        </template>
        <template #item.collected_at="{ value }">
          <span v-if="value" class="text-caption">{{ formatDateTime(value) }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.received_at="{ value }">
          <span v-if="value" class="text-caption">{{ formatDateTime(value) }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Print label" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-printer-outline" variant="text" size="small"
                       @click="printLabel(item)" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="['registered','collected'].includes(item.status)"
                       text="Receive in lab" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-check" variant="text" size="small" color="success"
                       :loading="actingId === item.id" @click="receive(item)" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="['registered','collected','received'].includes(item.status)"
                       text="Reject" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-close-circle-outline" variant="text" size="small"
                       color="error" @click="openReject(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-pencil" title="Edit"
                             @click="openEdit(item)" />
                <v-list-item v-if="item.status === 'received'"
                             prepend-icon="mdi-cog-outline" title="Mark in process"
                             @click="setStatus(item, 'in_process')" />
                <v-list-item v-if="item.status === 'in_process'"
                             prepend-icon="mdi-delete-outline" title="Mark disposed"
                             base-color="warning" @click="setStatus(item, 'disposed')" />
                <v-list-item prepend-icon="mdi-clipboard-text"
                             title="Open lab order"
                             @click="$router.push(`/lab/requisitions/${item.lab_order}`)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-test-tube-empty</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No specimens found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Register a specimen for an existing requisition.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew()">
              Register Specimen
            </v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Cards view -->
    <div v-else class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-test-tube-empty</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No specimens found</div>
      </div>
      <v-row v-else dense>
        <v-col v-for="s in filtered" :key="s.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="spec-card pa-3 h-100" hover @click="openEdit(s)">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="hashColor(s.id)" size="36" class="mr-2">
                <v-icon color="white" size="20">{{ containerIcon(s.container_type) }}</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-monospace font-weight-bold text-body-2">{{ s.accession_number }}</div>
                <div class="text-caption text-medium-emphasis font-monospace">
                  {{ s.barcode || 'No barcode' }}
                </div>
              </div>
              <v-chip size="x-small" variant="tonal" :color="statusColor(s.status)" class="text-capitalize">
                {{ statusLabel(s.status) }}
              </v-chip>
            </div>
            <v-divider class="my-2" />
            <div class="text-body-2 font-weight-medium text-truncate">{{ s.patient_name || '—' }}</div>
            <div class="text-caption text-medium-emphasis">{{ containerLabel(s.container_type) }}
              <span v-if="s.volume_ml"> · {{ s.volume_ml }} ml</span>
              <span v-if="s.storage_location"> · {{ s.storage_location }}</span>
            </div>
            <div v-if="s.collected_at" class="text-caption text-medium-emphasis mt-1">
              <v-icon size="12">mdi-tray-arrow-down</v-icon>
              Collected {{ relativeTime(s.collected_at) }}
            </div>
            <div v-if="s.received_at" class="text-caption text-medium-emphasis">
              <v-icon size="12">mdi-check</v-icon>
              Received {{ relativeTime(s.received_at) }}
            </div>
            <v-divider class="my-2" />
            <div class="d-flex ga-1 justify-end" @click.stop>
              <v-btn size="x-small" variant="text" icon="mdi-printer-outline"
                     @click="printLabel(s)" />
              <v-btn v-if="['registered','collected'].includes(s.status)"
                     size="x-small" variant="text" color="success" icon="mdi-check"
                     :loading="actingId === s.id" @click="receive(s)" />
              <v-btn v-if="['registered','collected','received'].includes(s.status)"
                     size="x-small" variant="text" color="error" icon="mdi-close-circle-outline"
                     @click="openReject(s)" />
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Register / Edit dialog -->
    <v-dialog v-model="dialog" max-width="780" scrollable>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center">
          <v-icon class="mr-2" color="indigo-darken-2">
            {{ form.id ? 'mdi-pencil' : 'mdi-barcode-scan' }}
          </v-icon>
          {{ form.id ? 'Edit specimen' : 'Register specimen' }}
          <v-spacer />
          <v-chip v-if="form.id" size="small" variant="tonal"
                  :color="statusColor(form.status)" class="text-capitalize">
            {{ statusLabel(form.status) }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12">
              <v-autocomplete
                v-model="form.lab_order" :items="orderOptions"
                item-title="label" item-value="id"
                label="Lab order *" variant="outlined" density="comfortable"
                :loading="ord.loading.value"
                prepend-inner-icon="mdi-clipboard-text-clock"
                @update:model-value="onOrderPicked"
              >
                <template #item="{ props, item }">
                  <v-list-item v-bind="props" :title="item.raw.patient_name"
                               :subtitle="item.raw.subtitle">
                    <template #append>
                      <v-chip size="x-small" variant="flat"
                              :color="priorityColor(item.raw.priority)" class="text-capitalize text-white">
                        {{ item.raw.priority }}
                      </v-chip>
                    </template>
                  </v-list-item>
                </template>
              </v-autocomplete>
            </v-col>

            <v-col v-if="selectedOrder" cols="12">
              <v-card flat class="pa-3 selected-order">
                <div class="text-overline text-medium-emphasis">Order details</div>
                <div class="d-flex flex-wrap ga-1 mt-1">
                  <v-chip v-for="(t, i) in (selectedOrder.test_names || [])" :key="i"
                          size="x-small" variant="tonal" color="indigo">{{ t }}</v-chip>
                </div>
              </v-card>
            </v-col>

            <v-col cols="12" sm="6">
              <v-text-field v-model="form.accession_number"
                            label="Accession # (auto if blank)"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-tag-outline"
                            class="font-monospace" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.barcode" label="Barcode"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-barcode" class="font-monospace" />
            </v-col>

            <v-col cols="12" sm="6">
              <v-select v-model="form.container_type" :items="containerOptions" label="Container *"
                        variant="outlined" density="comfortable">
                <template #item="{ props, item }">
                  <v-list-item v-bind="props">
                    <template #prepend>
                      <v-icon :color="containerColor(item.value)">{{ containerIcon(item.value) }}</v-icon>
                    </template>
                  </v-list-item>
                </template>
              </v-select>
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.specimen_type" label="Specimen type"
                            placeholder="Blood, Urine, Stool…"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-test-tube" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.volume_ml" type="number" label="Volume (ml)"
                            variant="outlined" density="comfortable" suffix="ml" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.storage_location" label="Storage location"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-archive-outline"
                            placeholder="e.g., Fridge A-3" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.status" :items="statusOptions" label="Status"
                        variant="outlined" density="comfortable" />
            </v-col>

            <v-col cols="12" sm="6">
              <v-text-field v-model="form.collected_at" type="datetime-local"
                            label="Collected at"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-tray-arrow-down" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.received_at" type="datetime-local"
                            label="Received at"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-check" />
            </v-col>

            <v-col cols="12">
              <v-textarea v-model="form.notes" rows="2" auto-grow label="Notes"
                          variant="outlined" density="comfortable"
                          prepend-inner-icon="mdi-note-text-outline" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn v-if="form.id" variant="text" prepend-icon="mdi-printer-outline"
                 @click="printLabel(form)">Print label</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="saving"
                 prepend-icon="mdi-content-save" @click="save">
            {{ form.id ? 'Save changes' : 'Register' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Reject dialog -->
    <v-dialog v-model="rejectDialog" max-width="520">
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center">
          <v-icon class="mr-2" color="error">mdi-close-circle-outline</v-icon>
          Reject specimen
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <div v-if="rejectTarget" class="mb-3">
            <div class="font-weight-bold font-monospace">{{ rejectTarget.accession_number }}</div>
            <div class="text-caption text-medium-emphasis">{{ rejectTarget.patient_name }}</div>
          </div>
          <v-select v-model="rejectReasonPreset" :items="rejectReasons"
                    label="Common reason" variant="outlined" density="comfortable"
                    @update:model-value="rejectReason = $event" />
          <v-textarea v-model="rejectReason" rows="3" label="Detailed reason *"
                      variant="outlined" density="comfortable" class="mt-2" />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="rejectDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="saving"
                 prepend-icon="mdi-close-circle-outline"
                 :disabled="!rejectReason" @click="confirmReject">
            Reject specimen
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()

const r = useResource('/lab/specimens/')
const ord = useResource('/lab/orders/')

const view = ref('table')
const statusFilter = ref(null)
const containerFilter = ref(null)
const dateFilter = ref(null)
const dialog = ref(false)
const rejectDialog = ref(false)
const rejectTarget = ref(null)
const rejectReason = ref('')
const rejectReasonPreset = ref(null)
const saving = ref(false)
const actingId = ref(null)
const scanValue = ref('')
const scanAction = ref('receive')
const scanInput = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const STATUS_META = {
  registered: { label: 'Registered', color: 'amber-darken-2', icon: 'mdi-tag-outline' },
  collected: { label: 'Collected', color: 'cyan-darken-2', icon: 'mdi-tray-arrow-down' },
  received: { label: 'Received', color: 'teal-darken-2', icon: 'mdi-check' },
  in_process: { label: 'In process', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
  rejected: { label: 'Rejected', color: 'red-darken-2', icon: 'mdi-close-circle-outline' },
  disposed: { label: 'Disposed', color: 'grey-darken-1', icon: 'mdi-delete-outline' },
}
const CONTAINER_META = {
  edta: { label: 'EDTA Tube', icon: 'mdi-test-tube', color: 'purple' },
  sst: { label: 'SST / Serum', icon: 'mdi-test-tube', color: 'amber-darken-2' },
  citrate: { label: 'Citrate', icon: 'mdi-test-tube', color: 'blue' },
  fluoride: { label: 'Fluoride/Oxalate', icon: 'mdi-test-tube', color: 'grey' },
  urine: { label: 'Urine Cup', icon: 'mdi-cup-outline', color: 'amber' },
  stool: { label: 'Stool', icon: 'mdi-cup-outline', color: 'brown' },
  swab: { label: 'Swab', icon: 'mdi-cotton-swab', color: 'pink' },
  culture: { label: 'Blood Culture', icon: 'mdi-bottle-tonic-outline', color: 'red-darken-2' },
  other: { label: 'Other', icon: 'mdi-flask-outline', color: 'grey-darken-1' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1' },
  urgent: { color: 'orange-darken-2' },
  stat: { color: 'red-darken-2' },
}

const containerOptions = Object.entries(CONTAINER_META).map(([v, m]) => ({ title: m.label, value: v }))
const statusOptions = Object.entries(STATUS_META).map(([v, m]) => ({ title: m.label, value: v }))
const dateOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Last 7 days', value: 'week' },
  { title: 'Last 30 days', value: 'month' },
]
const rejectReasons = [
  'Hemolyzed sample',
  'Clotted sample',
  'Insufficient quantity',
  'Wrong container',
  'Mislabeled / unlabeled',
  'Contaminated',
  'Sample leaked in transit',
  'Expired transport time',
]

function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function containerColor(v) { return CONTAINER_META[v]?.color || 'grey' }
function containerIcon(v) { return CONTAINER_META[v]?.icon || 'mdi-flask-outline' }
function containerLabel(v) { return CONTAINER_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }

const headers = [
  { title: 'Accession', key: 'accession_number', width: 130 },
  { title: 'Barcode', key: 'barcode', width: 130 },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Container', key: 'container_type', width: 140 },
  { title: 'Volume', key: 'volume_ml', align: 'end', width: 100 },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Collected', key: 'collected_at', width: 170 },
  { title: 'Received', key: 'received_at', width: 170 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 180 },
]

const list = computed(() => r.items.value || [])

const filtered = computed(() => {
  let arr = r.filtered.value
  if (statusFilter.value) arr = arr.filter(s => s.status === statusFilter.value)
  if (containerFilter.value) arr = arr.filter(s => s.container_type === containerFilter.value)
  if (dateFilter.value) {
    const lim = dateFilter.value === 'today' ? 86400000
      : dateFilter.value === 'week' ? 7 * 86400000 : 30 * 86400000
    const now = Date.now()
    arr = arr.filter(s => s.created_at && (now - new Date(s.created_at).getTime()) <= lim)
  }
  return arr
})

const kpis = computed(() => {
  const arr = list.value
  const today = new Date().toDateString()
  return [
    { label: 'Total today', value: arr.filter(s => s.created_at && new Date(s.created_at).toDateString() === today).length,
      icon: 'mdi-calendar-today', color: 'indigo', statusValue: null },
    { label: 'Registered', value: arr.filter(s => s.status === 'registered').length,
      icon: 'mdi-tag-outline', color: 'amber', statusValue: 'registered' },
    { label: 'Collected', value: arr.filter(s => s.status === 'collected').length,
      icon: 'mdi-tray-arrow-down', color: 'cyan', statusValue: 'collected' },
    { label: 'Received', value: arr.filter(s => s.status === 'received').length,
      icon: 'mdi-check', color: 'teal', statusValue: 'received' },
    { label: 'In process', value: arr.filter(s => s.status === 'in_process').length,
      icon: 'mdi-cog-outline', color: 'blue', statusValue: 'in_process' },
    { label: 'Rejected', value: arr.filter(s => s.status === 'rejected').length,
      icon: 'mdi-close-circle-outline', color: 'red', statusValue: 'rejected' },
  ]
})

const statusPills = computed(() => {
  const counts = list.value.reduce((acc, s) => {
    acc[s.status] = (acc[s.status] || 0) + 1
    return acc
  }, {})
  return [
    { label: 'All', value: null, count: list.value.length, color: 'primary', icon: 'mdi-format-list-bulleted' },
    ...Object.entries(STATUS_META).map(([v, m]) => ({
      label: m.label, value: v, count: counts[v] || 0, color: m.color, icon: m.icon,
    })),
  ]
})

const orderOptions = computed(() => (ord.items.value || []).map(o => ({
  ...o,
  label: `${o.patient_name || 'Unknown'} — ${(o.test_names || []).slice(0, 3).join(', ')}`,
  subtitle: `REQ-${String(o.id).padStart(5, '0')} · ${(o.test_names || []).length} tests · ${o.priority}`,
})))

const selectedOrder = computed(() =>
  (ord.items.value || []).find(o => o.id === form.value.lab_order)
)

const form = ref(emptyForm())
function emptyForm() {
  return {
    id: null, lab_order: null, accession_number: '', barcode: '',
    container_type: 'edta', specimen_type: '', volume_ml: null,
    storage_location: '', status: 'registered',
    collected_at: '', received_at: '', notes: '',
  }
}

function toggleStatus(value) {
  statusFilter.value = statusFilter.value === value ? null : value
}
function resetFilters() {
  statusFilter.value = null
  containerFilter.value = null
  dateFilter.value = null
  r.search.value = ''
}

function openNew(presetOrderId = null) {
  form.value = emptyForm()
  if (presetOrderId) {
    form.value.lab_order = Number(presetOrderId)
    onOrderPicked(form.value.lab_order)
  }
  dialog.value = true
}
function openEdit(item) {
  form.value = {
    ...emptyForm(),
    ...item,
    collected_at: toLocalInput(item.collected_at),
    received_at: toLocalInput(item.received_at),
  }
  dialog.value = true
}
function onOrderPicked(orderId) {
  const o = (ord.items.value || []).find(x => x.id === orderId)
  if (o) {
    // Try to set specimen type from the first test
    const firstTest = (o.tests || [])[0]
    if (firstTest && typeof firstTest === 'object' && firstTest.specimen_type) {
      form.value.specimen_type = firstTest.specimen_type
    }
  }
}
function toLocalInput(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d)) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function save() {
  if (!form.value.lab_order) {
    snack.text = 'Please select a lab order'
    snack.color = 'error'
    snack.show = true
    return
  }
  saving.value = true
  try {
    const payload = { ...form.value }
    if (!payload.collected_at) delete payload.collected_at
    if (!payload.received_at) delete payload.received_at
    if (!payload.accession_number) delete payload.accession_number
    if (form.value.id) await r.update(form.value.id, payload)
    else await r.create(payload)
    dialog.value = false
    snack.text = form.value.id ? 'Specimen updated' : 'Specimen registered'
    snack.color = 'success'
    snack.show = true
    r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail
      || (typeof e?.response?.data === 'object'
          ? Object.values(e.response.data).flat().join(' ')
          : 'Failed to save')
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

async function receive(item) {
  actingId.value = item.id
  try {
    await $api.post(`/lab/specimens/${item.id}/receive/`)
    snack.text = `${item.accession_number} received`
    snack.color = 'success'
    snack.show = true
    r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to receive'
    snack.color = 'error'
    snack.show = true
  } finally {
    actingId.value = null
  }
}

async function setStatus(item, status) {
  try {
    await r.update(item.id, { ...item, status })
    snack.text = `Status updated to ${statusLabel(status)}`
    snack.color = 'success'
    snack.show = true
    r.list()
  } catch (e) {
    snack.text = 'Failed to update status'
    snack.color = 'error'
    snack.show = true
  }
}

function openReject(item) {
  rejectTarget.value = item
  rejectReason.value = ''
  rejectReasonPreset.value = null
  rejectDialog.value = true
}
async function confirmReject() {
  if (!rejectTarget.value || !rejectReason.value) return
  saving.value = true
  try {
    await $api.post(`/lab/specimens/${rejectTarget.value.id}/reject/`, { reason: rejectReason.value })
    snack.text = `${rejectTarget.value.accession_number} rejected`
    snack.color = 'warning'
    snack.show = true
    rejectDialog.value = false
    r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to reject'
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

async function processScan() {
  const value = (scanValue.value || '').trim()
  if (!value) return
  const found = list.value.find(s =>
    s.accession_number === value || s.barcode === value
  )
  scanValue.value = ''
  // Refocus scanner
  setTimeout(() => scanInput.value?.focus?.(), 50)

  if (!found) {
    snack.text = `No specimen matches "${value}"`
    snack.color = 'warning'
    snack.show = true
    return
  }
  if (scanAction.value === 'lookup') {
    openEdit(found)
    return
  }
  // Receive on scan
  if (['registered', 'collected'].includes(found.status)) {
    await receive(found)
  } else {
    snack.text = `${found.accession_number} already ${statusLabel(found.status).toLowerCase()}`
    snack.color = 'info'
    snack.show = true
  }
}

function initials(name) {
  if (!name) return '?'
  const parts = name.split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function hashColor(seed) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(seed) || 0) % colors.length]
}
function relativeTime(iso) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  const d = Math.floor(h / 24)
  if (d < 30) return `${d}d ago`
  const dt = new Date(iso)
  return dt.toLocaleDateString()
}

function printLabel(s) {
  const w = window.open('', '_blank', 'width=420,height=300')
  if (!w) return
  const acc = s.accession_number || '—'
  const barcode = s.barcode || acc
  w.document.write(`
    <html><head><title>${acc}</title>
    <style>
      body{font-family:Arial,sans-serif;margin:0;padding:12px;width:300px}
      .acc{font-size:24px;font-weight:bold;letter-spacing:2px;text-align:center;margin-bottom:6px}
      .name{font-size:14px;font-weight:600;margin-bottom:2px}
      .meta{font-size:11px;color:#444;margin-bottom:8px}
      .barcode{font-family:'Libre Barcode 39', 'Courier New', monospace;font-size:48px;text-align:center;letter-spacing:2px;background:repeating-linear-gradient(90deg,#000 0 2px,transparent 2px 4px,#000 4px 5px,transparent 5px 9px);color:transparent;-webkit-text-fill-color:transparent;border:1px solid #000;padding:4px 8px}
      .text{text-align:center;font-family:'Courier New',monospace;font-size:12px;letter-spacing:2px;margin-top:2px}
      .row{display:flex;justify-content:space-between;font-size:11px;margin-top:6px}
    </style></head><body>
      <div class="acc">${acc}</div>
      <div class="name">${s.patient_name || '—'}</div>
      <div class="meta">${containerLabel(s.container_type)}${s.volume_ml ? ' · ' + s.volume_ml + ' ml' : ''}</div>
      <div class="barcode">${barcode}</div>
      <div class="text">${barcode}</div>
      <div class="row"><span>${s.specimen_type || ''}</span><span>${new Date().toLocaleDateString()}</span></div>
    </body></html>`)
  w.document.close()
  setTimeout(() => w.print(), 200)
}

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['accession_number', 'barcode', 'patient', 'container', 'specimen_type',
                'volume_ml', 'status', 'collected_at', 'received_at', 'storage_location']
  const header = cols.join(',')
  const body = rows.map(s => [
    s.accession_number || '',
    s.barcode || '',
    `"${(s.patient_name || '').replace(/"/g, '""')}"`,
    s.container_type || '',
    s.specimen_type || '',
    s.volume_ml || '',
    s.status || '',
    s.collected_at || '',
    s.received_at || '',
    `"${(s.storage_location || '').replace(/"/g, '""')}"`,
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `specimens_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  await Promise.all([r.list(), ord.list()])
  // Deep-link: ?order=ID opens the register dialog with that order
  const orderId = route.query.order
  if (orderId) {
    openNew(orderId)
    // Clean the URL
    router.replace({ query: {} })
  }
})
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: all 120ms ease;
}
.kpi:hover { border-color: rgba(var(--v-theme-primary), 0.4); }
.kpi.is-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.05);
}
.scan-card {
  border: 1px solid rgba(var(--v-theme-primary), 0.16);
  background: rgba(var(--v-theme-primary), 0.03);
}
.spec-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.spec-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
}
.acc-table :deep(tbody tr) { cursor: pointer; }
.selected-order {
  background: rgba(var(--v-theme-primary), 0.04);
  border: 1px dashed rgba(var(--v-theme-primary), 0.3);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
