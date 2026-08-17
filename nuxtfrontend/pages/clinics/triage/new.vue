<script setup>
// New Triage page — premium patient picker with expandable detail panels
// Creates a draft triage record and redirects to the triage workspace.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from '#app'
import { useNuxtApp } from '#app'
import { formatDate, formatDateTime } from '~/utils/format'
import { esiColor } from '~/composables/useClinicalScoring'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()

const loading = ref(true)
const error = ref(null)
const patients = ref([])
const search = ref('')
const selectedPatient = ref(null)
const creating = ref(false)
const expanded = ref([])        // expanded patient ids (v-list-group v-model:opened)
const detailCache = ref({})     // id -> { loading, meds, lastVisit, priorTriage }

// ESI legend data
const esiLevels = [
  { level: 1, label: 'Resuscitation', desc: 'Immediate life-saving intervention' },
  { level: 2, label: 'Emergent', desc: 'High-risk situation, rapid intervention' },
  { level: 3, label: 'Urgent', desc: 'Multiple resources expected, stable vitals' },
  { level: 4, label: 'Less Urgent', desc: 'One resource expected, stable' },
  { level: 5, label: 'Non-Urgent', desc: 'No resources expected' },
]

// If patient query param provided, auto-start
const autoPatientId = computed(() => route.query.patient)

onMounted(async () => {
  if (autoPatientId.value) {
    await autoStart(Number(autoPatientId.value))
  } else {
    await loadPatients()
  }
})

async function loadPatients() {
  loading.value = true
  try {
    const { data } = await $api.get('/patients/', { params: { page_size: 1000 } })
    patients.value = data.results || []
  } catch (e) {
    error.value = 'Failed to load patient list'
  } finally {
    loading.value = false
  }
}

async function autoStart(patientId) {
  creating.value = true
  try {
    const { data } = await $api.post('/triage/', {
      patient: patientId, chief_complaint: '', vital_signs: {}, status: 'draft', esi_level: null,
    })
    router.replace(`/clinics/triage/workspace/${data.id}`)
  } catch (e) {
    error.value = e?.response?.data?.detail || e?.response?.data || 'Failed to start triage'
    creating.value = false
    loading.value = false
    if (!patients.value.length) await loadPatients()
  }
}

const filteredPatients = computed(() => {
  if (!search.value) return patients.value
  const q = search.value.toLowerCase()
  return patients.value.filter(p => {
    const name = (p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`).toLowerCase()
    const pid = (p.patient_number || p.patient_id || '').toLowerCase()
    const nid = (p.national_id || '').toLowerCase()
    return name.includes(q) || pid.includes(q) || nid.includes(q)
  })
})

// Summary stats
const withAllergies = computed(() => patients.value.filter(p => (p.allergies || []).length > 0).length)
const withChronic = computed(() => patients.value.filter(p => (p.chronic_conditions || []).length > 0).length)

function age(dob) {
  if (!dob) return '—'
  const d = new Date(dob)
  return Math.floor((Date.now() - d) / 315576000000)
}

function genderIcon(g) {
  if (g === 'female') return 'mdi-gender-female'
  if (g === 'male') return 'mdi-gender-male'
  return 'mdi-gender-male-female'
}

function detailFor(id) {
  return detailCache.value[id] || null
}

// Load clinical detail when a patient group is expanded
watch(expanded, (opened) => {
  for (const id of opened) {
    if (!detailCache.value[id]) loadDetail(id)
  }
})

async function loadDetail(id) {
  detailCache.value[id] = { loading: true, meds: [], lastVisit: null, priorTriage: null }
  try {
    const [medsRes, visitRes, triageRes] = await Promise.allSettled([
      $api.get('/prescriptions/', { params: { patient: id, status: 'active', ordering: '-created_at', page_size: 50 } }),
      $api.get('/appointments/', { params: { patient: id, status: 'completed', ordering: '-appointment_date', page_size: 1 } }),
      $api.get('/triage/', { params: { patient: id, status: 'completed', ordering: '-triage_time', page_size: 5 } }),
    ])
    const d = { loading: false, meds: [], lastVisit: null, priorTriage: null }
    if (medsRes.status === 'fulfilled') d.meds = medsRes.value.data.results || []
    if (visitRes.status === 'fulfilled') d.lastVisit = (visitRes.value.data.results || [])[0] || null
    if (triageRes.status === 'fulfilled') d.priorTriage = {
      count: triageRes.value.data.count,
      latest: (triageRes.value.data.results || [])[0] || null,
    }
    detailCache.value[id] = d
  } catch (e) {
    detailCache.value[id] = { loading: false, error: 'Failed to load detail' }
  }
}

function medName(prescription) {
  const items = prescription.items || []
  if (!items.length) return prescription.medication_name || '—'
  return items.map(i => i.is_custom ? (i.custom_medication_name || 'Custom med') : (i.medication_name || '—')).join(', ')
}

function medDosage(prescription) {
  const items = (prescription.items || [])
  if (!items.length) return ''
  return items.map(i => [i.dosage, i.frequency].filter(Boolean).join(' · ')).join(' / ')
}

async function startTriage(patient) {
  selectedPatient.value = patient
  creating.value = true
  try {
    const { data } = await $api.post('/triage/', {
      patient: patient.id, chief_complaint: '', vital_signs: {}, status: 'draft', esi_level: null,
    })
    router.replace(`/clinics/triage/workspace/${data.id}`)
  } catch (e) {
    error.value = e?.response?.data?.detail || e?.response?.data || 'Failed to start triage'
    creating.value = false
    selectedPatient.value = null
  }
}
</script>

<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center mb-4">
      <v-btn icon variant="text" to="/clinics/triage" class="mr-2"><v-icon>mdi-arrow-left</v-icon></v-btn>
      <div>
        <div class="text-h5 font-weight-bold">New Triage Assessment</div>
        <div class="text-body-2 text-medium-emphasis">Select a patient to begin the triage workflow · click a row to expand clinical details</div>
      </div>
      <v-spacer />
      <v-btn variant="tonal" color="primary" prepend-icon="mdi-view-dashboard-outline" to="/clinics/triage">
        Triage Dashboard
      </v-btn>
    </div>

    <!-- Auto-start loading overlay -->
    <div v-if="creating" class="d-flex align-center justify-center" style="min-height: 50vh">
      <div class="text-center">
        <v-progress-circular indeterminate color="error" size="56" width="4" />
        <div class="text-h6 mt-4 font-weight-medium">
          {{ selectedPatient ? `Starting triage for ${selectedPatient.user_name}…` : 'Starting triage workspace…' }}
        </div>
        <div class="text-body-2 text-medium-emphasis mt-1">Creating draft triage record</div>
      </div>
    </div>

    <!-- Error -->
    <v-alert v-else-if="error" type="error" variant="tonal" rounded="lg" class="mb-4">
      <div class="font-weight-bold">{{ error }}</div>
      <v-btn to="/clinics/triage" class="mt-2" variant="text" prepend-icon="mdi-arrow-left">Back to Triage</v-btn>
    </v-alert>

    <template v-else>
      <!-- ESI Legend Card -->
      <v-card rounded="lg" variant="outlined" class="mb-4">
        <v-card-text class="pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon color="error" class="mr-2">mdi-stethoscope</v-icon>
            <span class="text-subtitle-1 font-weight-bold">Emergency Severity Index (ESI) Reference</span>
            <v-spacer />
            <span class="text-caption text-medium-emphasis d-none d-md-inline">Used to prioritize the triage queue</span>
          </div>
          <v-row dense>
            <v-col v-for="e in esiLevels" :key="e.level" cols="12" sm="6" md="4" lg="2">
              <div class="esi-chip" :class="'esi-level-' + e.level">
                <div class="d-flex align-center">
                  <v-avatar size="32" :color="esiColor(e.level)" variant="tonal" class="mr-2">
                    <span class="text-subtitle-2 font-weight-bold">{{ e.level }}</span>
                  </v-avatar>
                  <div>
                    <div class="text-body-2 font-weight-bold">{{ e.label }}</div>
                    <div class="text-caption text-medium-emphasis">{{ e.desc }}</div>
                  </div>
                </div>
              </div>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <!-- Summary stats -->
      <v-row dense class="mb-4">
        <v-col cols="6" md="3">
          <v-card rounded="lg" variant="tonal" color="primary" class="stat-card h-100">
            <v-card-text class="pa-3">
              <div class="text-overline">Total Patients</div>
              <div class="text-h4 font-weight-bold">{{ patients.length }}</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card rounded="lg" variant="tonal" color="error" class="stat-card h-100">
            <v-card-text class="pa-3">
              <div class="text-overline">With Allergies</div>
              <div class="text-h4 font-weight-bold">{{ withAllergies }}</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card rounded="lg" variant="tonal" color="warning" class="stat-card h-100">
            <v-card-text class="pa-3">
              <div class="text-overline">Chronic Conditions</div>
              <div class="text-h4 font-weight-bold">{{ withChronic }}</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card rounded="lg" variant="tonal" color="info" class="stat-card h-100">
            <v-card-text class="pa-3">
              <div class="text-overline">Filtered</div>
              <div class="text-h4 font-weight-bold">{{ filteredPatients.length }}</div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- Search -->
      <v-card rounded="lg" variant="outlined" class="mb-4">
        <v-card-text class="pa-4">
          <v-text-field
            v-model="search"
            prepend-inner-icon="mdi-magnify"
            label="Search by name, patient ID, or national ID…"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            autofocus
          />
          <div class="text-caption text-medium-emphasis mt-2 d-flex align-center">
            <v-icon size="14" class="mr-1">mdi-account-group</v-icon>
            {{ filteredPatients.length }} patient(s) available
            <v-spacer />
            <v-icon size="14" class="mr-1">mdi-information-outline</v-icon>
            Click a row to expand clinical details
          </div>
        </v-card-text>
      </v-card>

      <div v-if="loading" class="d-flex justify-center pa-8">
        <v-progress-circular indeterminate color="error" size="40" />
      </div>

      <div v-else-if="!filteredPatients.length" class="text-center pa-8">
        <v-icon size="64" color="grey-lighten-2">mdi-account-search-outline</v-icon>
        <div class="text-h6 mt-2 text-medium-emphasis">No patients found</div>
        <div class="text-body-2 text-medium-emphasis">{{ search ? 'Try a different search term' : 'Register a patient first' }}</div>
      </div>

      <!-- Patient List with expandable details -->
      <v-card v-else rounded="lg" variant="outlined">
        <v-list v-model:opened="expanded" lines="three" class="py-0">
          <template v-for="(p, i) in filteredPatients" :key="p.id">
            <v-list-group :value="p.id">
              <template #activator="{ props: activatorProps }">
                <v-list-item
                  v-bind="activatorProps"
                  class="px-3 py-3 patient-row"
                >
                  <template #prepend>
                    <div class="row-number mr-1 text-subtitle-2 font-weight-bold">{{ i + 1 }}</div>
                    <div class="patient-avatar-wrapper mr-3">
                      <v-avatar
                        :color="p.gender === 'female' ? 'pink-lighten-4' : 'blue-lighten-4'"
                        size="52" variant="tonal"
                      >
                        <span class="text-h6 font-weight-bold">{{ (p.user_name || '?').charAt(0) }}</span>
                      </v-avatar>
                      <div v-if="p.allergies?.length" class="allergy-dot" />
                    </div>
                  </template>

                  <v-list-item-title class="text-subtitle-1 font-weight-bold">
                    {{ p.user_name || `${p.user?.first_name} ${p.user?.last_name}` }}
                    <v-chip size="x-small" variant="outlined" class="ml-2 font-weight-medium" color="grey">
                      {{ p.patient_number || p.patient_id || '—' }}
                    </v-chip>
                    <v-chip v-if="p.allergies?.length" size="x-small" color="error" variant="tonal" class="ml-1">
                      <v-icon size="12" start>mdi-alert</v-icon>{{ p.allergies.length }} allergy
                    </v-chip>
                    <v-chip v-if="p.chronic_conditions?.length" size="x-small" color="warning" variant="tonal" class="ml-1">
                      <v-icon size="12" start>mdi-heart-pulse</v-icon>{{ p.chronic_conditions.length }} chronic
                    </v-chip>
                  </v-list-item-title>

                  <v-list-item-subtitle class="text-body-2 mt-1">
                    <v-icon size="14" class="mr-1">{{ genderIcon(p.gender) }}</v-icon>
                    {{ p.gender || '—' }} · {{ age(p.date_of_birth) }}y
                    <span v-if="p.blood_type" class="ml-2">· 🩸 {{ p.blood_type }}</span>
                    <span v-if="p.insurance_provider" class="ml-2">· {{ p.insurance_provider }}</span>
                    <span class="ml-2 text-medium-emphasis">· Registered {{ formatDate(p.created_at) }}</span>
                  </v-list-item-subtitle>

                  <template #append>
                    <v-btn
                      color="error"
                      variant="tonal"
                      rounded="lg"
                      size="small"
                      class="text-none font-weight-bold mr-2"
                      :loading="creating && selectedPatient?.id === p.id"
                      prepend-icon="mdi-heart-pulse"
                      @click.stop="startTriage(p)"
                    >
                      Start Triage
                    </v-btn>
                  </template>
                </v-list-item>
              </template>

              <!-- Expanded detail panel -->
              <div class="detail-panel px-3 pb-3 pt-1">
                <v-progress-linear
                  v-if="detailFor(p.id)?.loading"
                  indeterminate
                  color="error"
                  height="3"
                  class="mb-2"
                />

                <template v-if="!detailFor(p.id)?.loading">
                  <v-row dense>
                    <!-- Demographics -->
                    <v-col cols="12" md="6">
                      <v-card variant="outlined" rounded="lg" class="h-100">
                        <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                          <v-icon size="16" class="mr-1" color="primary">mdi-account-details</v-icon>
                          Demographics
                        </v-card-title>
                        <v-card-text class="pt-1">
                          <div class="detail-row"><span>Date of Birth</span><span>{{ formatDate(p.date_of_birth) }} ({{ age(p.date_of_birth) }}y)</span></div>
                          <div class="detail-row"><span>Gender</span><span class="text-capitalize">{{ p.gender || '—' }}</span></div>
                          <div class="detail-row"><span>Blood Type</span><span>{{ p.blood_type || '—' }}</span></div>
                          <div class="detail-row"><span>National ID</span><span>{{ p.national_id || '—' }}</span></div>
                          <div class="detail-row"><span>Address</span><span class="text-right">{{ p.address || '—' }}</span></div>
                        </v-card-text>
                      </v-card>
                    </v-col>

                    <!-- Contact & Insurance -->
                    <v-col cols="12" md="6">
                      <v-card variant="outlined" rounded="lg" class="h-100">
                        <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                          <v-icon size="16" class="mr-1" color="info">mdi-phone</v-icon>
                          Emergency Contact and Insurance
                        </v-card-title>
                        <v-card-text class="pt-1">
                          <div class="detail-row"><span>Emergency Contact</span><span>{{ p.emergency_contact_name || '—' }}</span></div>
                          <div class="detail-row"><span>Relationship</span><span>{{ p.emergency_contact_relation || '—' }}</span></div>
                          <div class="detail-row"><span>Phone</span><span>{{ p.emergency_contact_phone || '—' }}</span></div>
                          <div class="detail-row"><span>Insurance Provider</span><span class="text-right">{{ p.insurance_provider || '—' }}</span></div>
                          <div class="detail-row"><span>Policy Number</span><span>{{ p.insurance_number || '—' }}</span></div>
                        </v-card-text>
                      </v-card>
                    </v-col>
                  </v-row>

                  <!-- Allergies & Chronic Conditions -->
                  <v-row dense class="mt-1">
                    <v-col cols="12" md="6">
                      <v-card variant="outlined" rounded="lg" class="h-100">
                        <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                          <v-icon size="16" class="mr-1" color="error">mdi-alert-circle</v-icon>
                          Allergies
                        </v-card-title>
                        <v-card-text class="pt-1">
                          <div v-if="(p.allergies || []).length" class="d-flex flex-wrap ga-1">
                            <v-chip v-for="a in p.allergies" :key="'a-' + a" size="small" color="error" variant="tonal" prepend-icon="mdi-alert">
                              {{ a }}
                            </v-chip>
                          </div>
                          <div v-else class="text-body-2 text-medium-emphasis">No known allergies</div>
                        </v-card-text>
                      </v-card>
                    </v-col>
                    <v-col cols="12" md="6">
                      <v-card variant="outlined" rounded="lg" class="h-100">
                        <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                          <v-icon size="16" class="mr-1" color="warning">mdi-heart-pulse</v-icon>
                          Chronic Conditions
                        </v-card-title>
                        <v-card-text class="pt-1">
                          <div v-if="(p.chronic_conditions || []).length" class="d-flex flex-wrap ga-1">
                            <v-chip v-for="c in p.chronic_conditions" :key="'c-' + c" size="small" color="warning" variant="tonal">
                              {{ c }}
                            </v-chip>
                          </div>
                          <div v-else class="text-body-2 text-medium-emphasis">No chronic conditions on file</div>
                        </v-card-text>
                      </v-card>
                    </v-col>
                  </v-row>

                  <!-- Fetched clinical data -->
                  <template v-if="detailFor(p.id)">
                    <v-row dense class="mt-1">
                      <!-- Active Medications -->
                      <v-col cols="12" md="6">
                        <v-card variant="outlined" rounded="lg" class="h-100">
                          <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                            <v-icon size="16" class="mr-1" color="success">mdi-pill-multiple</v-icon>
                            Active Medications
                            <v-chip size="x-small" variant="tonal" class="ml-2" color="success">{{ detailFor(p.id).meds.length }}</v-chip>
                          </v-card-title>
                          <v-card-text class="pt-1">
                            <div v-if="detailFor(p.id).meds.length">
                              <v-list density="compact" class="px-0 bg-transparent">
                                <v-list-item v-for="m in detailFor(p.id).meds" :key="m.id" class="px-0">
                                  <v-list-item-title class="text-body-2 font-weight-medium">
                                    {{ medName(m) }}
                                  </v-list-item-title>
                                  <v-list-item-subtitle class="text-caption">
                                    {{ medDosage(m) }}
                                    <span v-if="m.doctor_name"> · Prescribed by {{ m.doctor_name }}</span>
                                    <span v-if="m.created_at"> · {{ formatDate(m.created_at) }}</span>
                                  </v-list-item-subtitle>
                                </v-list-item>
                              </v-list>
                            </div>
                            <div v-else class="text-body-2 text-medium-emphasis">No active prescriptions</div>
                          </v-card-text>
                        </v-card>
                      </v-col>

                      <!-- Last Visit & Prior Triage -->
                      <v-col cols="12" md="6">
                        <v-card variant="outlined" rounded="lg" class="h-100">
                          <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                            <v-icon size="16" class="mr-1" color="primary">mdi-history</v-icon>
                            Visit History
                          </v-card-title>
                          <v-card-text class="pt-1">
                            <div class="detail-row align-start">
                              <span>Last Visit Date</span>
                              <span>
                                <template v-if="detailFor(p.id).lastVisit">
                                  {{ formatDate(detailFor(p.id).lastVisit.appointment_date) }}
                                  <div class="text-caption text-medium-emphasis">
                                    <span v-if="detailFor(p.id).lastVisit.reason">"{{ detailFor(p.id).lastVisit.reason }}"</span>
                                    <span v-if="detailFor(p.id).lastVisit.staff_name"> · {{ detailFor(p.id).lastVisit.staff_name }}</span>
                                  </div>
                                </template>
                                <template v-else>No completed visits on record</template>
                              </span>
                            </div>
                            <div class="detail-row align-start">
                              <span>Prior Triage Assessments</span>
                              <span>
                                <template v-if="detailFor(p.id).priorTriage">
                                  <v-chip size="small" variant="tonal" color="error">{{ detailFor(p.id).priorTriage.count }}</v-chip>
                                  <span v-if="detailFor(p.id).priorTriage.latest" class="ml-2 text-caption text-medium-emphasis">
                                    last: {{ formatDateTime(detailFor(p.id).priorTriage.latest.triage_time) }}
                                  </span>
                                  <div v-if="detailFor(p.id).priorTriage.latest" class="text-caption text-medium-emphasis mt-1">
                                    ESI {{ detailFor(p.id).priorTriage.latest.esi_level || '—' }} ·
                                    "{{ detailFor(p.id).priorTriage.latest.chief_complaint || 'no complaint recorded' }}"
                                  </div>
                                </template>
                                <template v-else>First triage for this patient</template>
                              </span>
                            </div>
                          </v-card-text>
                        </v-card>
                      </v-col>
                    </v-row>
                  </template>

                  <!-- Patient notes -->
                  <v-row dense v-if="p.notes" class="mt-1">
                    <v-col cols="12">
                      <v-card variant="outlined" rounded="lg" color="grey-lighten-2">
                        <v-card-title class="text-subtitle-2 font-weight-bold pa-3 pb-1">
                          <v-icon size="16" class="mr-1" color="grey-darken-1">mdi-note-text</v-icon>
                          Patient Notes
                        </v-card-title>
                        <v-card-text class="pt-1 text-body-2">{{ p.notes }}</v-card-text>
                      </v-card>
                    </v-col>
                  </v-row>

                  <!-- Action bar -->
                  <div class="d-flex justify-end ga-2 mt-2 px-1">
                    <v-btn variant="text" prepend-icon="mdi-account-eye" :to="`/clinics/patients/${p.id}`">
                      View Full Profile
                    </v-btn>
                    <v-btn
                      color="error"
                      variant="tonal"
                      rounded="lg"
                      class="text-none font-weight-bold"
                      :loading="creating && selectedPatient?.id === p.id"
                      prepend-icon="mdi-heart-pulse"
                      @click.stop="startTriage(p)"
                    >
                      Start Triage
                    </v-btn>
                  </div>
                </template>
              </div>
            </v-list-group>
            <v-divider v-if="i < filteredPatients.length - 1" />
          </template>
        </v-list>
      </v-card>
    </template>
  </v-container>
</template>

<style scoped>
.patient-avatar-wrapper { position: relative; }
.row-number {
  width: 28px;
  min-width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(var(--v-theme-surface-variant), 0.5);
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.allergy-dot {
  position: absolute; top: -2px; right: -2px;
  width: 14px; height: 14px; border-radius: 50%;
  background: #d32f2f; border: 2px solid rgb(var(--v-theme-surface));
}
.patient-row { cursor: pointer; transition: background 0.15s; }
.patient-row:hover { background: rgba(var(--v-theme-error), 0.04); }

.stat-card { transition: transform 0.15s; }
.stat-card:hover { transform: translateY(-2px); }

.esi-chip {
  border-left: 4px solid transparent;
  border-radius: 8px;
  padding: 8px 10px;
  background: rgba(var(--v-theme-surface-variant), 0.3);
  height: 100%;
}
.esi-level-1 { border-left-color: #b71c1c; }
.esi-level-2 { border-left-color: #d32f2f; }
.esi-level-3 { border-left-color: #ff9800; }
.esi-level-4 { border-left-color: #4caf50; }
.esi-level-5 { border-left-color: #2196f3; }

.detail-panel {
  background: rgba(var(--v-theme-surface-variant), 0.18);
  border-radius: 0 0 12px 12px;
}
.detail-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 4px 0;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.08);
  font-size: 0.875rem;
}
.detail-row:last-child { border-bottom: none; }
.detail-row.align-start { align-items: flex-start; }
.detail-row span:first-child {
  color: rgba(var(--v-theme-on-surface), 0.6);
  font-weight: 500;
  white-space: nowrap;
}
.detail-row span:last-child {
  font-weight: 500;
  text-align: right;
}
</style>
