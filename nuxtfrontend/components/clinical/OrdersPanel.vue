<template>
  <div class="orders-panel">
    <div class="d-flex align-center justify-space-between mb-2">
      <div class="d-flex align-center">
        <v-icon color="primary" class="mr-2">mdi-clipboard-list</v-icon>
        <span class="text-subtitle-2 font-weight-bold">Orders &amp; Plan</span>
      </div>
      <v-chip size="x-small" variant="tonal" color="info">{{ placedOrders.length }} placed</v-chip>
    </div>

    <!-- Allergy CDS banner for pharmacy -->
    <v-alert
      v-if="allergies?.length && activeTab === 'pharmacy'"
      type="warning"
      variant="tonal"
      density="compact"
      class="mb-2"
      icon="mdi-alert"
    >
      <span class="text-body-2 font-weight-bold">Patient allergies:</span>
      <v-chip v-for="a in allergies" :key="a" size="x-small" color="error" variant="flat" label class="mx-1">{{ a }}</v-chip>
    </v-alert>

    <!-- Order Type Tabs -->
    <v-tabs v-model="activeTab" density="compact" color="primary" class="mb-3" show-arrows>
      <v-tab value="lab"><v-icon start size="16">mdi-microscope</v-icon>Lab</v-tab>
      <v-tab value="radiology"><v-icon start size="16">mdi-x-ray</v-icon>Radiology</v-tab>
      <v-tab value="pharmacy"><v-icon start size="16">mdi-pill</v-icon>Pharmacy</v-tab>
      <v-tab value="referral"><v-icon start size="16">mdi-share</v-icon>Referral</v-tab>
      <v-tab value="procedure"><v-icon start size="16">mdi-screwdriver</v-icon>Procedure</v-tab>
    </v-tabs>

    <v-window v-model="activeTab">
      <!-- ═══ Lab Orders ═══ -->
      <v-window-item value="lab" data-order="lab">
        <v-autocomplete
          v-model="labForm.test_ids"
          :items="labCatalog"
          item-title="name"
          item-value="id"
          label="Search lab tests"
          placeholder="Type to search CBC, LFT, Lipid…"
          variant="outlined"
          density="compact"
          multiple
          chips
          closable-chips
          class="mb-2"
          :loading="labLoading"
          :disabled="readonly"
        />
        <div class="d-flex flex-wrap ga-1 mb-2">
          <v-chip
            v-for="q in quickLabTests"
            :key="q.id"
            size="x-small"
            variant="outlined"
            :color="labForm.test_ids.includes(q.id) ? 'teal' : 'default'"
            @click="toggleLabQuick(q.id)"
            class="cursor-pointer"
          >{{ q.code }}</v-chip>
        </div>
        <div class="d-flex ga-2 mb-2">
          <v-select v-model="labForm.priority" :items="priorityOptions" item-title="title" item-value="value" label="Priority" variant="outlined" density="compact" hide-details :disabled="readonly" />
          <v-checkbox v-model="labForm.is_home_collection" label="Home" density="compact" hide-details :disabled="readonly" />
        </div>
        <v-textarea v-model="labForm.notes" label="Clinical Notes" variant="outlined" density="compact" rows="2" hide-details :disabled="readonly" />
        <v-btn block color="teal" prepend-icon="mdi-microscope-plus" :loading="placing" :disabled="readonly || !labForm.test_ids.length" @click="placeLabOrder" class="mt-2">Order Lab</v-btn>
      </v-window-item>

      <!-- ═══ Radiology ═══ -->
      <v-window-item value="radiology" data-order="radiology">
        <v-select v-model="radForm.imaging_type" :items="imagingOptions" label="Imaging Type" variant="outlined" density="compact" class="mb-2" item-title="title" item-value="value" :disabled="readonly" />
        <v-autocomplete
          v-model="radForm.exam_ids"
          :items="radCatalog"
          item-title="name"
          item-value="id"
          label="Exam"
          placeholder="e.g. Chest X-Ray, Knee MRI…"
          variant="outlined"
          density="compact"
          class="mb-2"
          :loading="radLoading"
          :disabled="readonly"
        />
        <v-text-field v-model="radForm.body_part" label="Body Part" variant="outlined" density="compact" class="mb-2" hide-details :disabled="readonly" />
        <v-select v-model="radForm.priority" :items="priorityOptions" item-title="title" item-value="value" label="Priority" variant="outlined" density="compact" class="mb-2" hide-details :disabled="readonly" />
        <v-textarea v-model="radForm.clinical_indication" label="Clinical Indication" variant="outlined" density="compact" rows="2" hide-details :disabled="readonly" />
        <v-btn block color="blue" prepend-icon="mdi-x-ray" :loading="placing" :disabled="readonly || !radForm.imaging_type" @click="placeRadOrder" class="mt-2">Order Imaging</v-btn>
      </v-window-item>

      <!-- ═══ Pharmacy ═══ -->
      <v-window-item value="pharmacy" data-order="pharmacy">
        <div v-for="(m, i) in pharmForm.medications" :key="i" class="mb-2 rx-item">
          <div class="d-flex align-center ga-2 mb-1">
            <v-autocomplete
              v-model="m.medication_id"
              :items="medResults"
              item-title="label"
              item-value="id"
              :search="m._search"
              @update:search="searchMedications"
              placeholder="Search medication…"
              variant="outlined"
              density="compact"
              hide-details
              :disabled="readonly"
              return-object
              class="flex-grow-1"
              @update:model-value="onMedSelect(m, $event)"
            />
            <v-btn v-if="!readonly" icon="mdi-delete" size="small" variant="text" color="error" @click="pharmForm.medications.splice(i, 1)" />
          </div>
          <div class="d-flex ga-2">
            <v-text-field v-model="m.dosage" placeholder="Dose" variant="outlined" density="compact" hide-details :disabled="readonly" />
            <v-text-field v-model="m.frequency" placeholder="Freq" variant="outlined" density="compact" hide-details :disabled="readonly" />
            <v-text-field v-model="m.duration" placeholder="Duration" variant="outlined" density="compact" hide-details :disabled="readonly" />
          </div>
          <v-text-field v-model="m.instructions" placeholder="Instructions (e.g. after meals)" variant="outlined" density="compact" hide-details class="mt-1" :disabled="readonly" />
        </div>
        <v-btn v-if="!readonly" block variant="text" prepend-icon="mdi-plus" @click="addMedication">Add Medication</v-btn>
        <v-textarea v-model="pharmForm.notes" label="Pharmacy Notes" variant="outlined" density="compact" rows="2" class="mt-2" hide-details :disabled="readonly" />
        <v-btn block color="purple" prepend-icon="mdi-pill-plus" :loading="placing" :disabled="readonly || !validMedications.length" @click="placePharmOrder" class="mt-2">Send Prescription</v-btn>
      </v-window-item>

      <!-- ═══ Referral ═══ -->
      <v-window-item value="referral">
        <v-text-field v-model="referralForm.specialty" label="Refer To (Specialty)" variant="outlined" density="compact" class="mb-2" hide-details :disabled="readonly" />
        <v-text-field v-model="referralForm.facility" label="Facility" variant="outlined" density="compact" class="mb-2" hide-details :disabled="readonly" />
        <v-textarea v-model="referralForm.reason" label="Reason for Referral" variant="outlined" density="compact" rows="3" hide-details :disabled="readonly" />
        <v-btn block color="indigo" prepend-icon="mdi-share" :disabled="readonly || !referralForm.specialty" @click="placeReferral" class="mt-2">Send Referral</v-btn>
      </v-window-item>

      <!-- ═══ Procedure ═══ -->
      <v-window-item value="procedure">
        <v-text-field v-model="procForm.name" label="Procedure" variant="outlined" density="compact" class="mb-2" hide-details :disabled="readonly" />
        <v-textarea v-model="procForm.notes" label="Procedure Notes" variant="outlined" density="compact" rows="3" hide-details :disabled="readonly" />
        <v-btn block color="orange" prepend-icon="mdi-screwdriver" :disabled="readonly || !procForm.name" @click="placeProcedure" class="mt-2">Schedule Procedure</v-btn>
      </v-window-item>
    </v-window>

    <!-- Placed Orders -->
    <v-divider class="my-3" />
    <div class="d-flex align-center justify-space-between mb-2">
      <span class="text-caption font-weight-bold">Placed Orders</span>
      <v-btn v-if="placedOrders.length" size="x-small" variant="text" @click="$emit('refresh-orders')">Refresh</v-btn>
    </div>
    <div v-if="placedOrders.length" class="d-flex flex-column ga-2">
      <v-card v-for="(o, i) in placedOrders" :key="i" variant="outlined" density="compact" class="pa-2 placed-order">
        <div class="d-flex align-center justify-space-between">
          <div class="d-flex align-center ga-2">
            <v-avatar :color="orderTypeColor(o.type) + '-lighten-5'" size="30" rounded>
              <v-icon :color="orderTypeColor(o.type)" size="16">{{ orderTypeIcon(o.type) }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-bold">{{ o.name }}</div>
              <div v-if="o.detail" class="text-caption text-medium-emphasis">{{ o.detail }}</div>
            </div>
          </div>
          <v-chip :color="orderStatusColor(o.status)" size="x-small" variant="tonal">{{ o.status }}</v-chip>
        </div>
        <!-- Lab results inline -->
        <div v-if="o.results?.length" class="mt-2 pt-2 border-t">
          <div v-for="r in o.results" :key="r.id" class="d-flex align-center ga-2 text-caption mb-1">
            <v-icon size="12" :color="r.is_abnormal ? 'error' : 'success'">mdi-circle-medium</v-icon>
            <span class="font-weight-bold">{{ r.test_name }}</span>
            <span :class="r.is_abnormal ? 'text-error font-weight-bold' : ''">{{ r.result_value }} {{ r.unit }}</span>
            <v-chip v-if="r.is_abnormal" size="x-small" color="error" variant="flat">ABNORMAL</v-chip>
          </div>
        </div>
      </v-card>
    </div>
    <div v-else class="text-body-2 text-medium-emphasis text-center py-4">
      <v-icon class="mb-1" color="grey-lighten-1">mdi-clipboard-text-off-outline</v-icon>
      <div>No orders yet — create one above</div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  consultationId: { type: [String, Number], default: null },
  patientId: { type: [String, Number], default: null },
  readonly: { type: Boolean, default: false },
  orders: { type: Array, default: () => [] },
  allergies: { type: Array, default: () => [] },
})
const emit = defineEmits(['order-placed', 'refresh-orders'])
const { $api } = useNuxtApp()

const activeTab = ref('lab')
const placedOrders = computed(() => props.orders)
const placing = ref(false)

const priorityOptions = [
  { title: 'Routine', value: 'routine' },
  { title: 'Urgent', value: 'urgent' },
  { title: 'STAT', value: 'stat' },
]
const imagingOptions = [
  { title: 'X-Ray', value: 'xray' },
  { title: 'Ultrasound', value: 'ultrasound' },
  { title: 'CT Scan', value: 'ct' },
  { title: 'MRI', value: 'mri' },
  { title: 'Mammogram', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' },
  { title: 'Other', value: 'other' },
]

// ── Lab catalog from API ──
const labCatalog = ref([])
const labLoading = ref(false)
async function loadLabCatalog() {
  labLoading.value = true
  try {
    const { data } = await $api.get('/lab/catalog/', { params: { page_size: 1000, is_active: true, ordering: 'name' } })
    labCatalog.value = data?.results || data || []
  } catch { labCatalog.value = [] }
  labLoading.value = false
}
const quickLabTests = computed(() => labCatalog.value.filter(t => ['CBC', 'FBS', 'HBA1C', 'LFT', 'RFT', 'LIPID', 'TSH', 'UA', 'CRP', 'HIV', 'HBSAG', 'BG'].includes(t.code)).slice(0, 12))
function toggleLabQuick(id) {
  const i = labForm.test_ids.indexOf(id)
  if (i >= 0) labForm.test_ids.splice(i, 1)
  else labForm.test_ids.push(id)
}

// ── Radiology exam catalog ──
const radCatalog = ref([])
const radLoading = ref(false)
async function loadRadCatalog() {
  radLoading.value = true
  try {
    const { data } = await $api.get('/radiology/exam-catalog/', { params: { page_size: 500 } })
    radCatalog.value = data?.results || data || []
  } catch { radCatalog.value = [] }
  radLoading.value = false
}

// ── Medication search ──
const medResults = ref([])
let medSearchTimer = null
async function searchMedications(q) {
  if (medSearchTimer) clearTimeout(medSearchTimer)
  if (!q || q.length < 2) { medResults.value = []; return }
  medSearchTimer = setTimeout(async () => {
    try {
      const { data } = await $api.get('/medications/search/', { params: { q } })
      medResults.value = data?.results || data || []
    } catch { medResults.value = [] }
  }, 300)
}
function onMedSelect(m, val) {
  if (val && typeof val === 'object') {
    m.medication_id = val.id
    m.medication_name = val.generic_name
  }
}

const labForm = reactive({ test_ids: [], priority: 'routine', notes: '', is_home_collection: false })
const radForm = reactive({ imaging_type: '', exam_ids: [], body_part: '', clinical_indication: '', priority: 'routine' })
const pharmForm = reactive({ medications: [], notes: '' })
const referralForm = reactive({ specialty: '', facility: '', reason: '' })
const procForm = reactive({ name: '', notes: '' })

function addMedication() {
  pharmForm.medications.push({ medication_id: null, medication_name: '', _search: '', dosage: '', frequency: '', duration: '', instructions: '' })
}
onMounted(() => {
  if (!pharmForm.medications.length) addMedication()
  loadLabCatalog()
  loadRadCatalog()
})

const validMedications = computed(() => pharmForm.medications.filter(m => m.medication_name))

async function placeLabOrder() {
  placing.value = true
  try {
    if (!props.consultationId) return
    const selectedTests = labForm.test_ids.map(id => labCatalog.value.find(t => t.id === id)).filter(Boolean)
    await $api.post('/lab/orders/', {
      consultation: props.consultationId,
      patient: props.patientId,
      test_ids: labForm.test_ids,
      priority: labForm.priority,
      clinical_notes: labForm.notes,
      is_home_collection: labForm.is_home_collection,
    })
    emit('order-placed', {
      id: Date.now(), type: 'lab',
      name: `${selectedTests.length} Lab Test(s)`,
      detail: selectedTests.map(t => t.code).join(', '),
      status: 'ordered', results: [],
    })
    labForm.test_ids = []; labForm.notes = ''; labForm.is_home_collection = false
  } catch (e) {
    emit('order-placed', { id: 'error', type: 'error', name: 'Lab order failed', detail: e?.response?.data?.detail || '', status: 'error' })
  }
  placing.value = false
}

async function placeRadOrder() {
  placing.value = true
  try {
    if (!props.consultationId) return
    await $api.post('/radiology/orders/', {
      consultation: props.consultationId,
      patient: props.patientId,
      exam_ids: radForm.exam_ids,
      imaging_type: radForm.imaging_type,
      body_part: radForm.body_part,
      clinical_indication: radForm.clinical_indication,
      priority: radForm.priority,
    })
    emit('order-placed', {
      id: Date.now(), type: 'radiology',
      name: `${imagingOptions.find(i => i.value === radForm.imaging_type)?.title || radForm.imaging_type}${radForm.body_part ? ' — ' + radForm.body_part : ''}`,
      detail: radForm.clinical_indication, status: 'ordered', results: [],
    })
    radForm.imaging_type = ''; radForm.exam_ids = []; radForm.body_part = ''; radForm.clinical_indication = ''
  } catch (e) {
    emit('order-placed', { id: 'error', type: 'error', name: 'Imaging order failed', detail: e?.response?.data?.detail || '', status: 'error' })
  }
  placing.value = false
}

async function placePharmOrder() {
  placing.value = true
  try {
    if (!props.consultationId) return
    const valid = validMedications.value
    await $api.post('/prescriptions/', {
      consultation: props.consultationId,
      patient: props.patientId,
      items: valid.map(m => ({
        medication_id: m.medication_id,
        medication_name: m.medication_name,
        custom_medication_name: m.medication_id ? '' : m.medication_name,
        is_custom: !m.medication_id,
        dosage: m.dosage, frequency: m.frequency, duration: m.duration,
        instructions: m.instructions, quantity: 1,
      })),
      notes: pharmForm.notes,
    })
    emit('order-placed', {
      id: Date.now(), type: 'pharmacy',
      name: `${valid.length} Medication(s)`,
      detail: valid.map(m => m.medication_name).join(', '),
      status: 'active',
    })
    pharmForm.medications = [{ medication_id: null, medication_name: '', dosage: '', frequency: '', duration: '', instructions: '' }]
    pharmForm.notes = ''
  } catch (e) {
    emit('order-placed', { id: 'error', type: 'error', name: 'Prescription failed', detail: e?.response?.data?.detail || '', status: 'error' })
  }
  placing.value = false
}

function placeReferral() {
  emit('order-placed', { id: Date.now(), type: 'referral', name: `Refer to ${referralForm.specialty}`, status: 'sent', detail: referralForm.reason })
  referralForm.specialty = ''; referralForm.facility = ''; referralForm.reason = ''
}
function placeProcedure() {
  emit('order-placed', { id: Date.now(), type: 'procedure', name: procForm.name, status: 'scheduled', detail: procForm.notes })
  procForm.name = ''; procForm.notes = ''
}

function orderTypeIcon(t) { return { lab: 'mdi-microscope', radiology: 'mdi-x-ray', pharmacy: 'mdi-pill', referral: 'mdi-share', procedure: 'mdi-screwdriver', error: 'mdi-alert' }[t] || 'mdi-clipboard' }
function orderTypeColor(t) { return { lab: 'teal', radiology: 'blue', pharmacy: 'purple', referral: 'indigo', procedure: 'orange', error: 'error' }[t] || 'grey' }
function orderStatusColor(s) { return { ordered: 'info', active: 'success', sent: 'info', scheduled: 'warning', completed: 'success', in_progress: 'warning', verified: 'success', pending: 'warning', error: 'error' }[s] || 'grey' }
</script>

<style scoped>
.cursor-pointer { cursor: pointer; }
.placed-order { border-radius: 8px; }
.rx-item { padding: 8px; border-radius: 8px; background: rgba(var(--v-theme-on-surface), 0.03); }
.border-t { border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
</style>
