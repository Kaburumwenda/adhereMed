<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" :to="backPath">
        Back
      </v-btn>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil" :to="editPath">
        Edit
      </v-btn>
      <v-menu>
        <template #activator="{ props }">
          <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" />
        </template>
        <v-list density="compact">
          <v-list-item :to="editPath" prepend-icon="mdi-clipboard-edit-outline">
            <v-list-item-title>Edit Consultation</v-list-item-title>
          </v-list-item>
          <v-list-item v-if="patientLink" :to="patientLink" prepend-icon="mdi-account-eye">
            <v-list-item-title>View Patient</v-list-item-title>
          </v-list-item>
          <v-divider />
          <v-list-item @click="confirmDelete" prepend-icon="mdi-delete" base-color="error">
            <v-list-item-title>Delete Consultation</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </div>

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-4" />

    <!-- Banner -->
    <v-card v-if="item" rounded="lg" variant="outlined" class="mb-4">
      <v-card-text class="pa-4 pa-md-5">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar size="56" :color="avatarColor(item.patient_name)" variant="tonal">
            <span class="text-h6 font-weight-bold">{{ initials(item.patient_name) }}</span>
          </v-avatar>
          <div class="flex-grow-1">
            <div class="d-flex align-center ga-2 flex-wrap">
              <h2 class="text-h6 font-weight-bold mb-0">{{ item.patient_name || 'Unknown Patient' }}</h2>
            </div>
            <div class="text-body-2 text-medium-emphasis">
              <v-icon size="small" class="mr-1">mdi-doctor</v-icon>
              Dr. {{ item.doctor_name || 'Unassigned' }}
              <span class="mx-2">·</span>
              <v-icon size="small" class="mr-1">mdi-clock-outline</v-icon>
              {{ formatDateTime(item.created_at) }}
            </div>
          </div>
          <div v-if="item.diagnosis && item.diagnosis.length" class="d-flex flex-wrap ga-1">
            <v-chip v-for="(d, i) in item.diagnosis.slice(0, 4)" :key="i" size="small" variant="tonal" color="primary">
              <strong class="me-1" v-if="typeof d === 'object' && d.code">{{ d.code }}</strong>
              {{ typeof d === 'string' ? d : (d.description || '') }}
            </v-chip>
          </div>
        </div>
      </v-card-text>
    </v-card>

    <!-- Tabs -->
    <v-card v-if="item" rounded="lg" variant="outlined">
      <v-tabs v-model="tab" color="primary" density="compact">
        <v-tab value="overview" prepend-icon="mdi-information-outline">Overview</v-tab>
        <v-tab value="vitals" prepend-icon="mdi-heart-pulse">Vital Signs</v-tab>
        <v-tab value="patient" prepend-icon="mdi-account-outline">Patient</v-tab>
        <v-tab value="related" prepend-icon="mdi-link-variant" v-if="item.prescriptions?.length || item.lab_orders?.length || item.radiology_orders?.length">
          Related Orders
          <v-chip size="x-small" class="ml-2" color="primary" variant="tonal">
            {{ (item.prescriptions?.length || 0) + (item.lab_orders?.length || 0) + (item.radiology_orders?.length || 0) }}
          </v-chip>
        </v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4 pa-md-5">
        <!-- Overview Tab -->
        <v-window-item value="overview">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-comment-alert-outline</v-icon> Chief Complaint
                </div>
                <div class="text-body-1">{{ item.chief_complaint || '—' }}</div>
                <v-divider class="my-3" />
                <div class="text-subtitle-2 font-weight-bold mb-2">
                  <v-icon size="18" class="mr-1">mdi-clipboard-pulse</v-icon> Diagnosis
                </div>
                <div v-if="item.diagnosis && item.diagnosis.length" class="d-flex flex-wrap ga-2">
                  <v-chip v-for="(d, i) in displayDiagnosis" :key="i" size="small" variant="tonal" color="primary" label>
                    <v-icon start size="x-small">mdi-clipboard-pulse</v-icon>
                    <strong class="me-1" v-if="d.code">{{ d.code }}</strong>
                    {{ d.description }}
                  </v-chip>
                </div>
                <div v-else class="text-medium-emphasis">No diagnosis recorded</div>
              </v-card>
            </v-col>

            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-history</v-icon> History of Present Illness
                </div>
                <div class="text-body-2">{{ item.history_present_illness || '—' }}</div>
                <v-divider class="my-3" />
                <div class="text-subtitle-2 font-weight-bold mb-2">
                  <v-icon size="18" class="mr-1">mdi-stethoscope</v-icon> Examination Findings
                </div>
                <div class="text-body-2">{{ item.examination_findings || '—' }}</div>
              </v-card>
            </v-col>

            <v-col cols="12">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-clipboard-pulse-outline</v-icon> Treatment Plan
                </div>
                <div class="text-body-2">{{ item.treatment_plan || '—' }}</div>
                <v-divider class="my-3" />
                <div class="text-subtitle-2 font-weight-bold mb-2">
                  <v-icon size="18" class="mr-1">mdi-note-edit-outline</v-icon> Notes
                </div>
                <div class="text-body-2">{{ item.notes || '—' }}</div>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

        <!-- Vital Signs Tab -->
        <v-window-item value="vitals">
          <v-card flat rounded="lg" class="detail-section pa-4" v-if="hasVitals">
            <div class="text-subtitle-2 font-weight-bold mb-3">
              <v-icon size="18" class="mr-1">mdi-heart-pulse</v-icon> Vital Signs
            </div>
            <v-row dense>
              <v-col v-for="v in vitalsList" :key="v.key" cols="6" sm="4" md="3" lg="2">
                <v-card variant="outlined" rounded="lg" class="text-center pa-3" :color="v.color">
                  <v-icon :icon="v.icon" :color="v.color" size="24" class="mb-1" />
                  <div class="text-h6 font-weight-bold">{{ v.value }}</div>
                  <div class="text-caption text-medium-emphasis">{{ v.label }}</div>
                </v-card>
              </v-col>
            </v-row>
            <v-divider class="my-3" v-if="bmi" />
            <div v-if="bmi" class="d-flex align-center ga-3">
              <v-avatar size="40" rounded="lg" :color="bmiColor" variant="tonal">
                <v-icon :color="bmiColor">mdi-scale-bathroom</v-icon>
              </v-avatar>
              <div>
                <div class="text-body-2 font-weight-bold">BMI: {{ bmi }}</div>
                <div class="text-caption text-medium-emphasis">{{ bmiCategory }}</div>
              </div>
            </div>
          </v-card>
          <div v-else class="text-center py-8 text-medium-emphasis">
            <v-icon size="48" class="mb-2">mdi-heart-pulse</v-icon>
            <div class="text-body-2">No vital signs recorded for this consultation</div>
          </div>
        </v-window-item>

        <!-- Patient Tab -->
        <v-window-item value="patient">
          <v-card flat rounded="lg" class="detail-section pa-4" v-if="patientDetail">
            <div class="d-flex align-center ga-3 mb-4">
              <v-avatar size="48" :color="avatarColor(patientDetail.full_name || item.patient_name)" variant="tonal">
                <span class="text-h6 font-weight-bold">{{ initials(patientDetail.full_name || item.patient_name) }}</span>
              </v-avatar>
              <div>
                <div class="text-h6 font-weight-bold">{{ patientDetail.full_name || item.patient_name }}</div>
                <div class="text-body-2 text-medium-emphasis">{{ patientDetail.user_email || patientDetail.user?.email }}</div>
              </div>
              <v-spacer />
              <v-btn variant="tonal" color="primary" size="small" rounded="lg" class="text-none"
                :to="patientLink" prepend-icon="mdi-account-eye">
                View Patient
              </v-btn>
            </div>
            <v-row dense>
              <v-col cols="12" sm="6" md="4"><DetailField label="Gender" :value="patientDetail.gender" capitalize /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Date of Birth" :value="formatDate(patientDetail.date_of_birth)" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Blood Type" :value="patientDetail.blood_type" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Phone" :value="patientDetail.user?.phone" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="National ID" :value="patientDetail.national_id" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Insurance" :value="patientDetail.insurance_provider" /></v-col>
            </v-row>
            <v-divider class="my-3" />
            <DetailField label="Allergies" :value="(patientDetail.allergies || []).join(', ')" full />
            <DetailField label="Chronic Conditions" :value="(patientDetail.chronic_conditions || []).join(', ')" full />
          </v-card>
          <div v-else-if="patientLoading" class="text-center py-6">
            <v-progress-circular indeterminate color="primary" size="40" />
          </div>
          <div v-else class="text-center py-6 text-medium-emphasis">
            <v-icon size="40" class="mb-2">mdi-account-question-outline</v-icon>
            <div class="text-body-2">Patient details unavailable</div>
          </div>
        </v-window-item>

        <!-- Related Orders Tab -->
        <v-window-item value="related">
          <v-row dense>
            <!-- Prescriptions -->
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4" v-if="item.prescriptions?.length">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-pill</v-icon> Prescriptions ({{ item.prescriptions.length }})
                </div>
                <v-list density="compact">
                  <v-list-item v-for="rx in item.prescriptions" :key="rx.id">
                    <template #prepend>
                      <v-icon color="primary">mdi-pill</v-icon>
                    </template>
                    <v-list-item-title class="text-body-2">{{ rx.medication_name || rx.notes || 'Prescription' }}</v-list-item-title>
                    <v-list-item-subtitle class="text-caption">{{ formatDate(rx.created_at) }}</v-list-item-subtitle>
                  </v-list-item>
                </v-list>
              </v-card>
            </v-col>
            <!-- Lab Orders -->
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4" v-if="item.lab_orders?.length">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-microscope</v-icon> Lab Orders ({{ item.lab_orders.length }})
                </div>
                <v-list density="compact">
                  <v-list-item v-for="lab in item.lab_orders" :key="lab.id">
                    <template #prepend>
                      <v-icon color="info">mdi-test-tube</v-icon>
                    </template>
                    <v-list-item-title class="text-body-2">{{ lab.test_name || lab.notes || 'Lab order' }}</v-list-item-title>
                    <v-list-item-subtitle class="text-caption">{{ formatDate(lab.created_at) }}</v-list-item-subtitle>
                  </v-list-item>
                </v-list>
              </v-card>
            </v-col>
            <!-- Radiology Orders -->
            <v-col cols="12">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4" v-if="item.radiology_orders?.length">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-radiology-box</v-icon> Radiology Orders ({{ item.radiology_orders.length }})
                </div>
                <v-list density="compact">
                  <v-list-item v-for="rad in item.radiology_orders" :key="rad.id">
                    <template #prepend>
                      <v-icon color="purple">mdi-radiology-box</v-icon>
                    </template>
                    <v-list-item-title class="text-body-2">{{ rad.exam_type || rad.notes || 'Radiology order' }}</v-list-item-title>
                    <v-list-item-subtitle class="text-caption">{{ formatDate(rad.created_at) }}</v-list-item-subtitle>
                  </v-list-item>
                </v-list>
              </v-card>
            </v-col>
          </v-row>
          <div v-if="!item.prescriptions?.length && !item.lab_orders?.length && !item.radiology_orders?.length"
            class="text-center py-8 text-medium-emphasis">
            <v-icon size="48" class="mb-2">mdi-link-variant-remove</v-icon>
            <div class="text-body-2">No related orders for this consultation</div>
          </div>
        </v-window-item>
      </v-window>
    </v-card>

    <!-- Not found -->
    <div v-if="!loading && !item" class="text-center py-12">
      <v-icon size="64" color="medium-emphasis" class="mb-3">mdi-clipboard-text-off</v-icon>
      <h3 class="text-h6 text-medium-emphasis mb-2">Consultation not found</h3>
      <v-btn color="primary" variant="tonal" :to="backPath">Back to Consultations</v-btn>
    </div>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>

    <!-- Delete dialog -->
    <v-dialog v-model="deleteDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Consultation?</v-card-title>
        <v-card-text>
          Are you sure you want to delete this consultation for
          <strong>{{ item?.patient_name }}</strong>?
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="tonal" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime } from '~/utils/format'

const route = useRoute()
const router = useRouter()

const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePath = computed(() => `${ns.value}/consultations`)
const patientBase = computed(() => `${ns.value}/patients`)
const backPath = computed(() => basePath.value)
const editPath = computed(() => `${basePath.value}/${route.params.id}/edit`)
const patientLink = computed(() => item.value?.patient ? `${patientBase.value}/${item.value.patient}` : null)

const r = useResource('/consultations/')
const patientsRes = useResource('/patients/')

const item = ref(null)
const loading = ref(true)
const tab = ref('overview')
const patientDetail = ref(null)
const patientLoading = ref(false)
const deleteDialog = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

onMounted(async () => {
  await load()
})

async function load() {
  loading.value = true
  try {
    const data = await r.get(route.params.id)
    item.value = data
    if (data?.patient) {
      loadPatient(data.patient)
    }
  } catch { /* ignore */ } finally {
    loading.value = false
  }
}

async function loadPatient(id) {
  patientLoading.value = true
  try {
    patientDetail.value = await patientsRes.get(id)
  } catch { /* ignore */ } finally { patientLoading.value = false }
}

/* Diagnosis normalized */
const displayDiagnosis = computed(() => {
  if (!item.value?.diagnosis) return []
  return item.value.diagnosis.map(d => {
    if (typeof d === 'string') return { code: '', description: d }
    return { code: d.code || '', description: d.description || '' }
  })
})

/* Vital Signs */
const hasVitals = computed(() => {
  const vs = item.value?.vital_signs
  if (!vs || typeof vs !== 'object') return false
  return Object.values(vs).some(v => v !== null && v !== undefined && v !== '')
})

const vitalsList = computed(() => {
  const vs = item.value?.vital_signs || {}
  const bpSys = vs.blood_pressure_systolic
  const bpDia = vs.blood_pressure_diastolic
  return [
    { key: 'temp', label: 'Temperature', value: vs.temperature ? `${vs.temperature}°C` : '—', icon: 'mdi-thermometer', color: 'orange' },
    { key: 'hr', label: 'Heart Rate', value: vs.heart_rate ? `${vs.heart_rate} bpm` : '—', icon: 'mdi-heart-pulse', color: 'red' },
    { key: 'bp', label: 'Blood Pressure', value: (bpSys || bpDia) ? `${bpSys || '—'}/${bpDia || '—'} mmHg` : '—', icon: 'mdi-gauge', color: 'error' },
    { key: 'rr', label: 'Resp Rate', value: vs.respiratory_rate ? `${vs.respiratory_rate}/min` : '—', icon: 'mdi-lungs', color: 'teal' },
    { key: 'spo2', label: 'SpO2', value: vs.oxygen_saturation ? `${vs.oxygen_saturation}%` : '—', icon: 'mdi-water-percent', color: 'info' },
    { key: 'wt', label: 'Weight', value: vs.weight ? `${vs.weight} kg` : '—', icon: 'mdi-scale', color: 'primary' },
    { key: 'ht', label: 'Height', value: vs.height ? `${vs.height} cm` : '—', icon: 'mdi-human-male-height', color: 'secondary' },
  ]
})

const bmi = computed(() => {
  const vs = item.value?.vital_signs || {}
  const w = parseFloat(vs.weight)
  const h = parseFloat(vs.height)
  if (!w || !h) return null
  const m = h / 100
  const val = w / (m * m)
  return val.toFixed(1)
})

const bmiCategory = computed(() => {
  const v = parseFloat(bmi.value)
  if (!v) return ''
  if (v < 18.5) return 'Underweight'
  if (v < 25) return 'Normal weight'
  if (v < 30) return 'Overweight'
  return 'Obese'
})

const bmiColor = computed(() => {
  const v = parseFloat(bmi.value)
  if (!v) return 'grey'
  if (v < 18.5 || v >= 30) return 'error'
  if (v < 25) return 'success'
  return 'warning'
})

/* Delete */
function confirmDelete() { deleteDialog.value = true }
async function doDelete() {
  try {
    await r.remove(item.value.id)
    snack.text = 'Consultation deleted'
    snack.show = true
    setTimeout(() => router.push(basePath.value), 500)
  } catch {
    snack.text = 'Failed to delete'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleteDialog.value = false
  }
}

/* Helpers */
function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(s => s[0]).slice(0, 2).join('').toUpperCase()
}
function avatarColor(name) {
  const colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'orange']
  const h = (name || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0)
  return colors[h % colors.length]
}
</script>

<style scoped>
.detail-section {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
</style>
