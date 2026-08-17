<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- ═══ Toolbar ════════════════════════════════════════════════ -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5 no-print">
      <v-avatar color="purple-lighten-5" size="48">
        <v-icon color="purple-darken-2" size="28">mdi-pill</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Prescription {{ prescription ? `#${prescription.id}` : '' }}</div>
        <div class="text-body-2 text-medium-emphasis">{{ prescription ? formatDateTime(prescription.created_at) : 'Loading…' }}</div>
      </div>
      <v-spacer />
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" @click="navigateTo(`${ns}/prescriptions`)">Back</v-btn>
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil" @click="navigateTo(`${ns}/prescriptions/${id}/edit`)">Edit</v-btn>
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-printer" @click="printPage">Print</v-btn>
      <v-btn v-if="prescription && (prescription.status || 'active') === 'active'" color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-send" :loading="sending" @click="sendToExchange">Send to Exchange</v-btn>
      <v-btn v-if="prescription && (prescription.status || 'active') === 'active'" color="success" rounded="lg" class="text-none" prepend-icon="mdi-check-circle" :loading="dispensing" @click="markDispensed">Mark Dispensed</v-btn>
    </div>

    <!-- ═══ Loading ═══════════════════════════════════════════════ -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="purple" size="48" />
    </div>
    <div v-else-if="!prescription" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-pill</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Prescription not found</div>
      <v-btn color="purple" rounded="lg" class="text-none mt-3" @click="navigateTo(`${ns}/prescriptions`)">Back to Prescriptions</v-btn>
    </div>

    <template v-else>
      <!-- ═══ Allergy / interaction banner ═══════════════════════ -->
      <v-slide-y-transition>
        <v-alert v-if="(prescription.patient_allergies || []).length" type="warning" variant="tonal" class="mb-4 no-print" prepend-icon="mdi-alert-circle">
          <div class="d-flex align-center ga-2">
            <strong>Patient Allergies:</strong>
            <v-chip v-for="a in prescription.patient_allergies" :key="a" size="small" color="error" variant="tonal">{{ a }}</v-chip>
          </div>
        </v-alert>
      </v-slide-y-transition>

      <!-- ═══ Status Workflow ═════════════════════════════════════ -->
      <v-card flat rounded="lg" class="rx-banner pa-5 mb-4">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar :color="statusInfo.color + '-lighten-5'" size="64" class="mr-2">
            <v-icon :color="statusInfo.color + '-darken-2'" size="36">{{ statusInfo.icon }}</v-icon>
          </v-avatar>
          <div class="flex-grow-1" style="min-width: 220px;">
            <div class="text-h5 font-weight-bold">Prescription {{ prescription.id }}</div>
            <div class="d-flex flex-wrap align-center ga-2 text-body-2 text-medium-emphasis mt-1">
              <v-icon size="16">mdi-account</v-icon>
              {{ prescription.patient_name || '—' }}
              <v-icon size="16" class="ml-1">mdi-doctor</v-icon>
              {{ prescription.doctor_name || '—' }}
              <v-icon size="16" class="ml-1">mdi-calendar</v-icon>
              {{ formatDateTime(prescription.created_at) }}
            </div>
          </div>
          <v-chip size="large" variant="tonal" :color="statusInfo.color" class="text-capitalize font-weight-bold" prepend-icon="mdi-circle-medium">
            {{ statusInfo.label }}
          </v-chip>
        </div>
        <!-- Workflow steps -->
        <div class="d-flex align-center mt-4 ga-2">
          <template v-for="(s, idx) in workflowSteps" :key="idx">
            <div class="d-flex align-center" :class="{ 'flex-grow-1': idx < workflowSteps.length - 1 }">
              <div class="d-flex align-center">
                <v-icon :color="s.reached ? 'success' : 'grey-lighten-2'" size="20">{{ s.reached ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                <span class="text-caption font-weight-medium ml-1" :class="s.reached ? 'text-success' : 'text-medium-emphasis'">{{ s.label }}</span>
              </div>
              <v-divider v-if="idx < workflowSteps.length - 1" class="flex-grow-1 ml-2" :color="s.reached ? 'success' : 'grey-lighten-2'" />
            </div>
          </template>
        </div>
      </v-card>

      <!-- ═══ Print Header (only visible when printing) ═════════ -->
      <div class="rx-print-header print-only">
        <div class="rx-print-clinic">Riverside Medical Clinic</div>
        <div class="rx-print-title">PRESCRIPTION</div>
        <div class="rx-print-meta">
          <div>Rx #: {{ prescription.id }}</div>
          <div>Date: {{ formatDate(prescription.created_at) }}</div>
        </div>
      </div>

      <!-- ═══ Patient & Doctor info ═════════════════════════════ -->
      <v-row dense class="mb-4">
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100 no-print">
            <div class="d-flex align-center mb-3">
              <v-avatar color="indigo-lighten-5" size="32" class="mr-2"><v-icon color="indigo-darken-2" size="20">mdi-account</v-icon></v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Patient</div>
            </div>
            <DetailField label="Name" :value="prescription.patient_name" />
            <DetailField label="Phone" :value="prescription.patient_phone" />
            <DetailField label="Email" :value="prescription.patient_email" />
            <DetailField label="National ID" :value="prescription.patient_national_id" :mono="true" />
            <DetailField label="Insurance" :value="prescription.patient_insurance_provider" />
            <DetailField label="Insurance #" :value="prescription.patient_insurance_number" :mono="true" />
            <div v-if="(prescription.patient_allergies || []).length" class="mt-2">
              <div class="field-label">Allergies</div>
              <div class="d-flex flex-wrap ga-1">
                <v-chip v-for="a in prescription.patient_allergies" :key="a" size="small" color="error" variant="tonal">{{ a }}</v-chip>
              </div>
            </div>
            <v-btn v-if="prescription.patient" size="small" variant="tonal" color="indigo" rounded="lg" class="text-none mt-3" prepend-icon="mdi-account-details" @click="navigateTo(`${ns}/patients/${prescription.patient}`)">View Patient</v-btn>
          </v-card>
          <!-- Print version -->
          <div class="rx-print-patient print-only">
            <div><strong>Patient:</strong> {{ prescription.patient_name }}</div>
            <div><strong>Phone:</strong> {{ prescription.patient_phone || '—' }}</div>
            <div><strong>Insurance:</strong> {{ prescription.patient_insurance_provider || '—' }} {{ prescription.patient_insurance_number ? '(' + prescription.patient_insurance_number + ')' : '' }}</div>
            <div v-if="(prescription.patient_allergies || []).length"><strong>Allergies:</strong> {{ prescription.patient_allergies.join(', ') }}</div>
          </div>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100 no-print">
            <div class="d-flex align-center mb-3">
              <v-avatar color="teal-lighten-5" size="32" class="mr-2"><v-icon color="teal-darken-2" size="20">mdi-doctor</v-icon></v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Prescriber</div>
            </div>
            <DetailField label="Name" :value="prescription.doctor_name" />
            <DetailField label="License #" :value="prescription.doctor_license_number" :mono="true" />
            <DetailField label="Practice Type" :value="prescription.doctor_practice_type" :capitalize="true" />
            <div class="section-title mt-4 mb-2">Details</div>
            <DetailField label="Date" :value="formatDateTime(prescription.created_at)" />
            <DetailField label="Status" :value="prescription.status" :capitalize="true" />
            <DetailField v-if="prescription.consultation" label="Consultation" :value="`#${prescription.consultation}`" :mono="true" />
          </v-card>
          <div class="rx-print-doctor print-only">
            <div><strong>Prescriber:</strong> {{ prescription.doctor_name }}</div>
            <div v-if="prescription.doctor_license_number"><strong>License:</strong> {{ prescription.doctor_license_number }}</div>
            <div v-if="prescription.doctor_practice_type"><strong>Practice:</strong> {{ prescription.doctor_practice_type }}</div>
          </div>
        </v-col>
      </v-row>

      <!-- ═══ Medication items ═══════════════════════════════════ -->
      <v-card flat rounded="lg" class="med-card mb-4 no-print">
        <div class="pa-4 pa-md-5">
          <div class="d-flex align-center mb-3">
            <v-avatar color="purple-lighten-5" size="32" class="mr-2"><v-icon color="purple-darken-2" size="20">mdi-pill-multiple</v-icon></v-avatar>
            <div class="text-subtitle-1 font-weight-bold">Medications ({{ (prescription.items || []).length }})</div>
          </div>
          <v-data-table :headers="medHeaders" :items="prescription.items || []" :items-per-page="-1" item-value="id" hide-default-footer class="med-table">
            <template #item.medication_name="{ item }">
              <div class="font-weight-medium">{{ medDisplayName(item) }}</div>
              <div v-if="item.is_custom" class="text-caption"><v-chip size="x-small" variant="tonal" color="warning">Custom</v-chip></div>
            </template>
            <template #item.quantity="{ value }">{{ value || 1 }}</template>
            <template #item.instructions="{ value }">{{ value || '—' }}</template>
            <template #item.refills="{ value }">
              <v-chip v-if="value" size="x-small" variant="tonal" color="info">{{ value }} refills</v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
          </v-data-table>
        </div>
      </v-card>

      <!-- Print version of meds -->
      <div class="rx-print-meds print-only">
        <div v-for="(m, idx) in (prescription.items || [])" :key="idx" class="rx-print-med-row">
          <div class="rx-print-med-name">{{ idx + 1 }}. {{ medDisplayName(m) }}</div>
          <div class="rx-print-med-details">
            {{ m.dosage }} · {{ m.frequency }} <span v-if="m.duration">· {{ m.duration }}</span> · Qty: {{ m.quantity || 1 }}
            <span v-if="m.refills">· Refills: {{ m.refills }}</span>
          </div>
          <div v-if="m.instructions" class="rx-print-med-instructions">Instructions: {{ m.instructions }}</div>
          <div v-if="m.schedule" class="rx-print-med-instructions">Schedule: {{ m.schedule }}</div>
        </div>
      </div>

      <!-- ═══ Notes ═════════════════════════════════════════════ -->
      <v-card v-if="prescription.notes" flat rounded="lg" class="notes-card pa-4 pa-md-5 mb-4 no-print">
        <div class="d-flex align-center mb-3">
          <v-avatar color="grey-lighten-4" size="32" class="mr-2"><v-icon color="grey-darken-2" size="20">mdi-note-text</v-icon></v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Notes</div>
        </div>
        <div class="text-body-1 pa-3 rounded-lg" style="white-space: pre-wrap; background: rgba(var(--v-theme-on-surface), 0.03);">{{ prescription.notes }}</div>
      </v-card>

      <div v-if="prescription.notes" class="rx-print-notes print-only">
        <strong>Notes:</strong> {{ prescription.notes }}
      </div>

      <!-- ═══ Signature block ════════════════════════════════════ -->
      <v-card flat rounded="lg" class="info-card pa-4 pa-md-5 no-print">
        <div class="d-flex align-center justify-space-between flex-wrap ga-3">
          <div>
            <div class="text-caption text-medium-emphasis mb-2">Prescriber signature</div>
            <div v-if="prescription.doctor_signature_url" class="mb-2">
              <img :src="prescription.doctor_signature_url" alt="Signature" style="max-height: 60px; max-width: 200px; object-fit: contain;" />
            </div>
            <div v-else class="text-body-2 text-medium-emphasis mb-2">No signature on file</div>
            <div class="text-body-1 font-weight-bold">{{ prescription.doctor_name || '—' }}</div>
            <div v-if="prescription.doctor_license_number" class="text-caption text-medium-emphasis">License: {{ prescription.doctor_license_number }}</div>
          </div>
          <div class="text-right">
            <DetailField label="Created" :value="formatDateTime(prescription.created_at)" />
          </div>
        </div>
      </v-card>

      <!-- Print signature -->
      <div class="rx-print-signature print-only">
        <div class="rx-print-sig-line"></div>
        <div>{{ prescription.doctor_name || '—' }}</div>
        <div v-if="prescription.doctor_license_number">License: {{ prescription.doctor_license_number }}</div>
      </div>
    </template>

    <!-- ═══ Snackbar ═══ -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDate, formatDateTime } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()
const { $api } = useNuxtApp()

const id = computed(() => route.params.id)
const loading = ref(false)
const prescription = ref(null)
const sending = ref(false)
const dispensing = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })
function showToast(t, c = 'success') { snack.text = t; snack.color = c; snack.show = true }

const medHeaders = [
  { title: 'Medication', key: 'medication_name', sortable: false },
  { title: 'Dosage', key: 'dosage', width: 100 },
  { title: 'Frequency', key: 'frequency', width: 130 },
  { title: 'Duration', key: 'duration', width: 100 },
  { title: 'Qty', key: 'quantity', width: 70 },
  { title: 'Refills', key: 'refills', width: 90 },
  { title: 'Instructions', key: 'instructions', sortable: false },
]

const statusInfo = computed(() => {
  const s = prescription.value?.status || 'active'
  return ({
    active: { label: 'Active', color: 'info', icon: 'mdi-pill' },
    sent_to_exchange: { label: 'Sent to Exchange', color: 'indigo', icon: 'mdi-send' },
    dispensed: { label: 'Dispensed', color: 'success', icon: 'mdi-check-circle' },
    cancelled: { label: 'Cancelled', color: 'error', icon: 'mdi-close-circle' },
    pending: { label: 'Pending', color: 'warning', icon: 'mdi-clock-outline' },
    expired: { label: 'Expired', color: 'grey', icon: 'mdi-alert-circle' },
  })[s] || { label: s, color: 'grey', icon: 'mdi-pill' }
})

const workflowSteps = computed(() => {
  const status = prescription.value?.status || 'active'
  return [
    { label: 'Created', reached: true },
    { label: 'Active', reached: ['active', 'sent_to_exchange', 'dispensed'].includes(status) },
    { label: 'Sent to Exchange', reached: ['sent_to_exchange', 'dispensed'].includes(status) },
    { label: 'Dispensed', reached: status === 'dispensed' },
  ]
})

function medDisplayName(m) {
  if (m.is_custom) return m.custom_medication_name || m.medication_name || '—'
  return m.medication_name || '—'
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await $api.get(`/prescriptions/${id.value}/`)
    prescription.value = data
  } catch (e) { console.error(e); showToast('Failed to load prescription', 'error') }
  finally { loading.value = false }
})

function printPage() { window.print() }
async function sendToExchange() {
  sending.value = true
  try {
    await $api.post(`/prescriptions/${prescription.value.id}/send_to_exchange/`)
    showToast('Sent to exchange', 'indigo')
    await reload()
  } catch (e) { showToast(e?.response?.data?.detail || 'Failed', 'error') }
  finally { sending.value = false }
}
async function markDispensed() {
  dispensing.value = true
  try {
    await $api.patch(`/prescriptions/${prescription.value.id}/`, { status: 'dispensed' })
    showToast('Marked dispensed', 'success')
    await reload()
  } catch (e) { showToast('Failed', 'error') }
  finally { dispensing.value = false }
}
async function reload() {
  const { data } = await $api.get(`/prescriptions/${id.value}/`)
  prescription.value = data
}
</script>

<style scoped>
.rx-banner, .info-card, .med-card, .notes-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.info-card { background: rgba(var(--v-theme-on-surface), 0.03); }
.section-title { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(var(--v-theme-on-surface), 0.5); }
.field-label { font-size: 0.7rem; font-weight: 600; letter-spacing: 0.5px; text-transform: uppercase; color: rgba(var(--v-theme-on-surface), 0.5); margin-bottom: 2px; }
.field-value { font-size: 0.95rem; line-height: 1.4; }

.print-only { display: none; }

@media print {
  .no-print { display: none !important; }
  .print-only { display: block !important; }
  .v-container { max-width: 100% !important; padding: 0 !important; }
  .rx-print-header { text-align: center; margin-bottom: 24px; border-bottom: 2px solid #333; padding-bottom: 12px; }
  .rx-print-clinic { font-size: 24px; font-weight: bold; }
  .rx-print-title { font-size: 20px; font-weight: bold; margin: 8px 0; letter-spacing: 2px; }
  .rx-print-meta { display: flex; justify-content: space-between; font-size: 12px; max-width: 400px; margin: 0 auto; }
  .rx-print-patient, .rx-print-doctor { font-size: 13px; line-height: 1.6; margin-bottom: 16px; padding: 12px; border: 1px solid #ddd; }
  .rx-print-meds { margin: 16px 0; border: 1px solid #333; }
  .rx-print-med-row { padding: 10px 12px; border-bottom: 1px solid #ddd; }
  .rx-print-med-row:last-child { border-bottom: none; }
  .rx-print-med-name { font-weight: bold; font-size: 14px; }
  .rx-print-med-details { font-size: 12px; color: #555; margin-top: 2px; }
  .rx-print-med-instructions { font-size: 11px; color: #666; margin-top: 2px; font-style: italic; }
  .rx-print-notes { margin: 16px 0; padding: 12px; border: 1px solid #ddd; font-size: 12px; }
  .rx-print-signature { margin-top: 40px; padding-top: 12px; }
  .rx-print-sig-line { border-top: 1px solid #333; width: 300px; margin-bottom: 8px; }
}
</style>
