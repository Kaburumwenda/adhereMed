<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1000px;">
    <!-- ═══ Header ════════════════════════════════════════════════ -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="purple-lighten-5" size="48">
        <v-icon color="purple-darken-2" size="28">mdi-pill-edit</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Edit Prescription</div>
        <div class="text-body-2 text-medium-emphasis">
          {{ prescription ? `#${prescription.id} — ${prescription.patient_name || ''}` : 'Loading…' }}
        </div>
      </div>
      <v-spacer />
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
        @click="navigateTo(`${ns}/prescriptions/${id}`)">Back</v-btn>
      <v-btn color="purple" rounded="lg" class="text-none" prepend-icon="mdi-content-save"
        :loading="saving" @click="save">Save Changes</v-btn>
    </div>

    <v-progress-linear v-if="loading" indeterminate color="purple" class="mb-4" />

    <v-form v-else ref="formRef" @submit.prevent="save">
      <!-- ═══ Patient & Doctor ═════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="purple-lighten-5" size="36" class="mr-3">
            <v-icon color="purple-darken-2" size="20">mdi-account-group</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Patient &amp; Doctor</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-select v-model="form.patient" :items="patientOptions" label="Patient" variant="outlined" density="compact"
              :rules="req" prepend-inner-icon="mdi-account" :loading="patientLoading" return-object />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.status" :items="statusOptions" item-title="title" item-value="value"
              label="Status" variant="outlined" density="compact" prepend-inner-icon="mdi-list-status" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.consultation" :items="consultationOptions" label="Linked Consultation" variant="outlined"
              density="compact" prepend-inner-icon="mdi-stethoscope" clearable />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Allergy banner ══════════════════════════════════════ -->
      <v-alert v-if="selectedPatientAllergies.length" type="warning" variant="tonal" class="mb-4" prepend-icon="mdi-alert">
        <strong>Patient Allergies:</strong>
        <v-chip v-for="a in selectedPatientAllergies" :key="a" size="small" color="error" variant="tonal" class="ml-2">{{ a }}</v-chip>
      </v-alert>

      <!-- ═══ Medication Items ═══════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center justify-space-between mb-4">
          <div class="d-flex align-center">
            <v-avatar color="indigo-lighten-5" size="36" class="mr-3">
              <v-icon color="indigo-darken-2" size="20">mdi-pill-multiple</v-icon>
            </v-avatar>
            <div class="text-h6 font-weight-bold">Medication Items ({{ medications.length }})</div>
          </div>
          <v-btn color="indigo" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" size="small" @click="addMedication">Add medication</v-btn>
        </div>

        <div v-for="(m, i) in medications" :key="i" class="med-row pa-3 mb-3 rounded-lg">
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="text-subtitle-2 font-weight-bold text-medium-emphasis">Drug #{{ i + 1 }}</div>
            <v-btn icon="mdi-close" variant="text" size="small" color="error" @click="removeMedication(i)" />
          </div>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-autocomplete
                v-model="m.selectedMed" :items="medSearchResults" :loading="medSearching" :search="m.search"
                @update:search="onMedSearch" @update:model-value="onMedSelect($event, i)"
                item-title="label" item-value="id" return-object
                label="Medication" variant="outlined" density="compact" hide-details
                prepend-inner-icon="mdi-pill" placeholder="Search medication…" clearable />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model="m.dosage" label="Dosage" variant="outlined" density="compact" hide-details placeholder="e.g. 500mg" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="m.frequency" :items="frequencyOptions" label="Frequency" variant="outlined" density="compact" hide-details />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model="m.duration" label="Duration" variant="outlined" density="compact" hide-details placeholder="e.g. 7 days" />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="m.quantity" type="number" min="1" label="Quantity" variant="outlined" density="compact" hide-details />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="m.schedule" :items="scheduleOptions" label="Schedule" variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="m.refills" type="number" min="0" label="Refills" variant="outlined" density="compact" hide-details />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="m.instructions" label="Instructions" variant="outlined" density="compact" hide-details placeholder="e.g. Take after meals" />
            </v-col>
          </v-row>
        </div>
      </v-card>

      <!-- ═══ Notes ═══════════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="grey-lighten-4" size="36" class="mr-3">
            <v-icon color="grey-darken-2" size="20">mdi-note-text</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Notes</div>
        </div>
        <v-textarea v-model="form.notes" label="General notes" rows="2" auto-grow variant="outlined" />
      </v-card>

      <!-- ═══ Action bar ══════════════════════════════════════════ -->
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none" @click="navigateTo(`${ns}/prescriptions/${id}`)">Cancel</v-btn>
        <v-btn type="submit" color="purple" rounded="lg" class="text-none" :loading="saving" prepend-icon="mdi-content-save">Save Changes</v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDate } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()
const { $api } = useNuxtApp()

const id = computed(() => route.params.id)
const loading = ref(false)
const saving = ref(false)
const prescription = ref(null)
const formRef = ref(null)
const req = [v => (v != null && v !== '') || 'Required']

const statusOptions = [
  { title: 'Active', value: 'active' },
  { title: 'Sent to Exchange', value: 'sent_to_exchange' },
  { title: 'Dispensed', value: 'dispensed' },
  { title: 'Cancelled', value: 'cancelled' },
]
const frequencyOptions = ['OD (once daily)', 'BID (twice daily)', 'TID (3x daily)', 'QID (4x daily)', 'PRN (as needed)', 'Every 4 hours', 'Every 6 hours', 'Every 8 hours', 'Once weekly']
const scheduleOptions = ['Morning', 'Afternoon', 'Night', 'Morning & Night', 'Morning, Afternoon & Night', 'Before meals', 'After meals', 'With food', 'At bedtime']

const form = reactive({ patient: null, status: 'active', consultation: null, notes: '' })
const medications = reactive([])
const patientOptions = ref([])
const patientLoading = ref(false)
const consultationOptions = ref([])
const medSearchResults = ref([])
const medSearching = ref(false)
let medSearchTimer = null

const selectedPatientAllergies = computed(() => {
  if (!form.patient) return prescription.value?.patient_allergies || []
  const p = patientOptions.value.find(x => x.value === form.patient?.id || x.value === form.patient)
  return p?.allergies || []
})

const snack = reactive({ show: false, color: 'success', text: '' })
function showToast(t, c = 'success') { snack.text = t; snack.color = c; snack.show = true }

onMounted(async () => {
  loading.value = true
  try {
    // Load prescription
    const { data } = await $api.get(`/prescriptions/${id.value}/`)
    prescription.value = data
    form.patient = data.patient
    form.status = data.status || 'active'
    form.consultation = data.consultation
    form.notes = data.notes || ''
    medications.splice(0, medications.length, ...(data.items || []).map(m => ({
      selectedMed: m.medication_id ? { id: m.medication_id, generic_name: m.medication_name, label: m.medication_name } : null,
      search: m.medication_name || '',
      dosage: m.dosage || '',
      frequency: m.frequency || '',
      duration: m.duration || '',
      quantity: m.quantity || 1,
      instructions: m.instructions || '',
      schedule: m.schedule || '',
      refills: m.refills || 0,
      is_custom: m.is_custom,
      customName: m.custom_medication_name || '',
      _existing: { id: m.id, medication_id: m.medication_id, medication_name: m.medication_name, custom_medication_name: m.custom_medication_name, is_custom: m.is_custom },
    })))
    // Load patient list
    patientLoading.value = true
    try {
      const { data: pat } = await $api.get('/patients/', { params: { page_size: 1000 } })
      patientOptions.value = (pat.results || pat).map(p => ({ title: `${p.patient_number || ''} — ${p.user_name || 'Unknown'}`.trim(), value: p.id, allergies: p.allergies || [] }))
    } catch (e) { console.error(e) }
    finally { patientLoading.value = false }
  } catch (e) { console.error(e); showToast('Failed to load', 'error') }
  finally { loading.value = false }
})

function addMedication() {
  medications.push({ selectedMed: null, search: '', dosage: '', frequency: '', duration: '', quantity: 1, instructions: '', schedule: '', refills: 0 })
}
function removeMedication(i) { medications.splice(i, 1) }

function onMedSearch(q) {
  medications.forEach(m => { if (m.search !== q) m.search = q })
  if (medSearchTimer) clearTimeout(medSearchTimer)
  if (!q || q.length < 2) { medSearchResults.value = []; return }
  medSearching.value = true
  medSearchTimer = setTimeout(async () => {
    try {
      const { data } = await $api.get('/medications/search/', { params: { q } })
      medSearchResults.value = data
    } catch (e) { console.error(e) }
    finally { medSearching.value = false }
  }, 300)
}
function onMedSelect(val, idx) {
  if (!val) return
  const m = medications[idx]
  m.selectedMed = val
  if (!m.dosage && val.strength) m.dosage = val.strength
}

async function save() {
  saving.value = true
  try {
    const payload = {
      patient: form.patient?.id || form.patient,
      status: form.status,
      consultation: form.consultation || null,
      notes: form.notes,
      // Note: PATCH doesn't support items update through current serializer; status/notes/patient only
    }
    await $api.patch(`/prescriptions/${id.value}/`, payload)
    showToast('Prescription updated', 'success')
    navigateTo(`${ns}/prescriptions/${id.value}`)
  } catch (e) {
    console.error(e)
    showToast(e?.response?.data?.detail || 'Failed to update', 'error')
  } finally { saving.value = false }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.med-row { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); background: rgba(var(--v-theme-on-surface), 0.02); }
</style>
