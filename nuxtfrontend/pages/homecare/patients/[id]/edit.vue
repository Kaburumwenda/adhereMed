<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:1280px;">
    <!-- Top bar -->
    <div class="d-flex flex-wrap align-center mb-4 ga-2">
      <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
             class="text-none" :to="`/homecare/patients/${id}`">Back to patient</v-btn>
      <v-spacer />
      <v-btn variant="text" rounded="lg" class="text-none" :to="`/homecare/patients/${id}`">Cancel</v-btn>
      <v-btn color="teal" rounded="lg" prepend-icon="mdi-content-save"
             class="text-none" :loading="saving" :disabled="!loaded" @click="save">Save changes</v-btn>
    </div>

    <!-- Hero -->
    <v-card v-if="loaded" rounded="xl" class="hc-hero pa-4 pa-md-5 mb-4" elevation="0">
      <div class="d-flex align-center flex-wrap ga-3">
        <v-avatar size="64" :color="riskColor" variant="flat" class="hc-avatar">
          <span class="text-h5 font-weight-bold text-white">{{ initials }}</span>
        </v-avatar>
        <div class="flex-grow-1 min-w-0">
          <div class="text-overline text-medium-emphasis">HOMECARE · EDIT PATIENT</div>
          <h1 class="text-h5 font-weight-bold ma-0">{{ patientName }}</h1>
          <div class="text-caption text-medium-emphasis">
            <v-icon icon="mdi-identifier" size="12" class="mr-1" />
            {{ patient?.medical_record_number }}
            <span v-if="patient?.user?.email" class="mx-2">·
              <v-icon icon="mdi-email" size="12" class="mx-1" />{{ patient.user.email }}
            </span>
            <span v-if="patient?.user?.phone">·
              <v-icon icon="mdi-phone" size="12" class="mx-1" />{{ patient.user.phone }}
            </span>
          </div>
        </div>
        <v-chip size="small" :color="riskColor" variant="tonal">
          <v-icon icon="mdi-shield-account" size="14" class="mr-1" />
          {{ form.risk_level }}
        </v-chip>
      </div>
    </v-card>

    <v-skeleton-loader v-if="!loaded" type="card, article, article" />

    <v-form v-if="loaded" ref="formRef" @submit.prevent="save">
      <v-row>
        <!-- ── Demographics ── -->
        <v-col cols="12" md="6">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead title="Demographics" icon="mdi-card-account-details"
                         subtitle="Date of birth, gender, identification & nationality."
                         color="#0d9488" />
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.date_of_birth" label="Date of birth" type="date"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.gender" label="Gender"
                          :items="['Male','Female','Other','Prefer not to say']"
                          variant="outlined" density="comfortable" rounded="lg" clearable />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.id_type" label="Identification type"
                          :items="idTypes" item-title="label" item-value="value"
                          variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.id_number" :label="idNumberLabel"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12">
                <v-autocomplete v-model="form.nationality" label="Nationality"
                                :items="nationalities" item-title="name" item-value="code"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-flag">
                  <template #selection="{ item }">
                    <span class="mr-2" style="font-size:18px;">{{ item.raw.flag }}</span>
                    {{ item.raw.name }}
                  </template>
                  <template #item="{ item, props: ip }">
                    <v-list-item v-bind="ip" :title="item.raw.name">
                      <template #prepend>
                        <span class="mr-2" style="font-size:20px;">{{ item.raw.flag }}</span>
                      </template>
                    </v-list-item>
                  </template>
                </v-autocomplete>
              </v-col>
            </v-row>
          </v-card>
        </v-col>

        <!-- ── Address ── -->
        <v-col cols="12" md="6">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead title="Home address" icon="mdi-map-marker"
                         subtitle="Used for caregiver routing and home visits."
                         color="#0ea5e9" />
            <AddressAutocomplete v-model="form.address"
                                 label="Address"
                                 placeholder="Start typing the patient's home address…"
                                 @select="onPatientAddressSelect" />
            <div v-if="form.address_lat" class="text-caption text-medium-emphasis ml-3 mt-1">
              <v-icon icon="mdi-crosshairs-gps" size="12" color="teal" class="mr-1" />
              {{ Number(form.address_lat).toFixed(5) }}, {{ Number(form.address_lng).toFixed(5) }}
              <v-btn size="x-small" variant="text" class="ml-2 text-none" @click="clearCoords">Clear coords</v-btn>
            </div>
          </v-card>
        </v-col>

        <!-- ── Clinical ── -->
        <v-col cols="12">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead title="Clinical" icon="mdi-stethoscope"
                         subtitle="Diagnosis, allergies and risk profile."
                         color="#0891b2" />
            <v-row dense>
              <v-col cols="12" md="8">
                <v-combobox v-model="form.primary_diagnosis"
                            :items="diagnosisItems"
                            :loading="loadingDiagnoses"
                            item-title="name" item-value="name"
                            :return-object="false"
                            @update:search="onDiagnosisSearch"
                            hide-no-data
                            label="Primary diagnosis"
                            hint="Pick from the catalog or type your own"
                            persistent-hint
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-clipboard-pulse">
                  <template #item="{ item, props: ip }">
                    <v-list-item v-bind="ip" :title="item.raw.name">
                      <template #subtitle>
                        <span v-if="item.raw.icd_code" class="text-caption mr-2">{{ item.raw.icd_code }}</span>
                        <span class="text-caption text-medium-emphasis">{{ item.raw.category }}</span>
                      </template>
                    </v-list-item>
                  </template>
                </v-combobox>
              </v-col>
              <v-col cols="12" md="4">
                <v-select v-model="form.risk_level" label="Risk level"
                          :items="riskLevels" item-title="label" item-value="value"
                          variant="outlined" density="comfortable" rounded="lg">
                  <template #selection="{ item }">
                    <v-icon :icon="item.raw.icon" :color="item.raw.color" size="16" class="mr-1" />
                    {{ item.raw.label }}
                  </template>
                  <template #item="{ item, props: ip }">
                    <v-list-item v-bind="ip">
                      <template #prepend>
                        <v-icon :icon="item.raw.icon" :color="item.raw.color" />
                      </template>
                    </v-list-item>
                  </template>
                </v-select>
              </v-col>
              <v-col cols="12">
                <v-combobox v-model="form.allergiesList"
                            :items="allergyItems"
                            :loading="loadingAllergies"
                            item-title="name" item-value="name"
                            :return-object="false"
                            @update:search="onAllergySearch"
                            hide-no-data chips closable-chips multiple
                            label="Allergies"
                            placeholder="Pick from catalog or type & press enter"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-alert-octagon">
                  <template #chip="{ props: cp, item }">
                    <v-chip v-bind="cp" color="error" variant="tonal" size="small">
                      <v-icon icon="mdi-alert" size="14" class="mr-1" />
                      {{ item.title }}
                    </v-chip>
                  </template>
                </v-combobox>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.medical_history" label="Medical history"
                            rows="4" auto-grow variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-history"
                            hint="Comorbidities, past conditions, family history, etc."
                            persistent-hint />
              </v-col>
              <v-col cols="12" md="4">
                <v-switch v-model="form.is_active" color="success" inset
                          :label="form.is_active ? 'Active patient' : 'Discharged'"
                          density="comfortable" hide-details />
              </v-col>
            </v-row>
          </v-card>
        </v-col>

        <!-- ── Care team ── -->
        <v-col cols="12" md="6">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead title="Care team" icon="mdi-account-multiple-plus"
                         subtitle="Primary caregiver plus additional caregivers."
                         color="#7c3aed" />
            <v-autocomplete v-model="form.assigned_caregiver"
                            :items="caregivers" item-title="full_name" item-value="id"
                            label="Primary caregiver / nurse"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-account-star" clearable
                            :loading="loadingCaregivers" />
            <v-autocomplete v-model="form.additional_caregivers"
                            :items="additionalChoices" item-title="full_name" item-value="id"
                            label="Additional caregivers"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-account-group" multiple chips closable-chips
                            :loading="loadingCaregivers" />
          </v-card>
        </v-col>

        <!-- ── Doctor ── -->
        <v-col cols="12" md="6">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead title="Responsible doctor" icon="mdi-doctor"
                         subtitle="Physician overseeing this patient's care."
                         color="#1d4ed8" />
            <v-btn-toggle v-model="doctorMode" mandatory color="indigo"
                          density="comfortable" rounded="lg" class="mb-3">
              <v-btn value="directory" class="text-none" prepend-icon="mdi-account-search">Directory</v-btn>
              <v-btn value="manual" class="text-none" prepend-icon="mdi-pencil-plus">Manual</v-btn>
            </v-btn-toggle>
            <v-autocomplete v-if="doctorMode === 'directory'"
                            v-model="form.assigned_doctor_user_id"
                            :items="doctors" item-title="name" item-value="user"
                            label="Responsible doctor"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-doctor" clearable
                            :loading="loadingDoctors">
              <template #item="{ item, props: ip }">
                <v-list-item v-bind="ip" :title="item.raw.name"
                             :subtitle="`${item.raw.specialization || 'General'} · ${item.raw.qualification || ''}`">
                  <template #prepend>
                    <v-avatar size="32" color="indigo" variant="tonal">
                      <v-icon icon="mdi-doctor" />
                    </v-avatar>
                  </template>
                </v-list-item>
              </template>
            </v-autocomplete>
            <v-row v-else dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.manual_doctor.name" label="Doctor full name"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-doctor" />
              </v-col>
              <v-col cols="12" md="6">
                <v-combobox v-model="form.manual_doctor.specialization" label="Specialization"
                            :items="specializationOptions"
                            variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.manual_doctor.phone" label="Phone"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-phone" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.manual_doctor.email" label="Email" type="email"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-email" />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="form.manual_doctor.hospital" label="Hospital / clinic"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-hospital-building" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.manual_doctor.notes" label="Additional notes"
                            rows="2" auto-grow variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-note-text" />
              </v-col>
            </v-row>
          </v-card>
        </v-col>

        <!-- ── Emergency contacts ── -->
        <v-col cols="12">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead title="Next of kin & emergency contacts" icon="mdi-phone-alert"
                         subtitle="People to call in an emergency."
                         color="#ef4444" />
            <div v-for="(c, idx) in form.emergency_contacts" :key="idx"
                 class="hc-kin pa-3 pa-md-4 rounded-xl mb-3">
              <div class="d-flex align-center mb-2">
                <v-avatar size="32" color="red" variant="tonal" class="mr-2">
                  <v-icon icon="mdi-account-heart" />
                </v-avatar>
                <div class="text-subtitle-2 font-weight-bold flex-grow-1">Contact {{ idx + 1 }}</div>
                <v-btn icon="mdi-delete-outline" variant="text" size="small"
                       color="error" @click="removeContact(idx)" />
              </div>
              <v-row dense>
                <v-col cols="12" md="4">
                  <v-text-field v-model="c.name" label="Full name" variant="outlined"
                                density="comfortable" rounded="lg" />
                </v-col>
                <v-col cols="12" md="3">
                  <v-combobox v-model="c.relationship" label="Relationship"
                              :items="relationships" variant="outlined"
                              density="comfortable" rounded="lg" />
                </v-col>
                <v-col cols="12" md="3">
                  <v-text-field v-model="c.phone" label="Phone" variant="outlined"
                                density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-phone" />
                </v-col>
                <v-col cols="12" md="2">
                  <v-switch v-model="c.is_primary" label="Primary"
                            color="teal" density="comfortable" hide-details
                            @update:model-value="(v) => v && markPrimary(idx)" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="c.email" label="Email" type="email"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-email" />
                </v-col>
                <v-col cols="12" md="6">
                  <AddressAutocomplete v-model="c.address"
                                       label="Address (optional)"
                                       placeholder="Start typing an address…"
                                       @select="(p) => onContactAddressSelect(c, p)" />
                  <div v-if="c.address_lat" class="text-caption text-medium-emphasis ml-3 mt-1">
                    <v-icon icon="mdi-crosshairs-gps" size="12" color="teal" class="mr-1" />
                    {{ Number(c.address_lat).toFixed(5) }}, {{ Number(c.address_lng).toFixed(5) }}
                  </div>
                </v-col>
              </v-row>
            </div>
            <v-btn variant="tonal" color="teal" rounded="lg" prepend-icon="mdi-plus"
                   class="text-none" @click="addContact">Add contact</v-btn>
          </v-card>
        </v-col>
      </v-row>

      <v-alert v-if="topError" type="error" variant="tonal" density="compact"
               class="mt-4" icon="mdi-alert-circle">{{ topError }}</v-alert>

      <div class="d-flex flex-wrap ga-2 mt-5">
        <v-spacer />
        <v-btn variant="text" rounded="lg" class="text-none" :to="`/homecare/patients/${id}`">Cancel</v-btn>
        <v-btn type="submit" color="teal" rounded="lg" prepend-icon="mdi-content-save"
               class="text-none" :loading="saving">Save changes</v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const id = computed(() => route.params.id)

const loaded = ref(false)
const saving = ref(false)
const topError = ref('')
const formRef = ref(null)
const patient = ref(null)
const doctorMode = ref('directory')

const form = reactive({
  date_of_birth: '', gender: '', address: '', address_lat: null, address_lng: null,
  id_type: 'national_id', id_number: '', nationality: 'KE',
  primary_diagnosis: '', medical_history: '',
  allergiesList: [],
  risk_level: 'low', is_active: true,
  assigned_caregiver: null,
  additional_caregivers: [],
  assigned_doctor_user_id: null,
  manual_doctor: { name: '', specialization: '', phone: '', email: '', hospital: '', notes: '' },
  emergency_contacts: [],
})

const caregivers = ref([])
const loadingCaregivers = ref(false)
const doctors = ref([])
const loadingDoctors = ref(false)
const diagnosisItems = ref([])
const loadingDiagnoses = ref(false)
const allergyItems = ref([])
const loadingAllergies = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

const riskLevels = [
  { value: 'low',      label: 'Low',      color: 'success', icon: 'mdi-shield-check' },
  { value: 'medium',   label: 'Medium',   color: 'warning', icon: 'mdi-shield-alert-outline' },
  { value: 'high',     label: 'High',     color: 'orange',  icon: 'mdi-shield-alert' },
  { value: 'critical', label: 'Critical', color: 'error',   icon: 'mdi-shield-off' },
]
const relationships = ['Spouse','Parent','Child','Sibling','Guardian','Friend','Other']
const idTypes = [
  { value: 'national_id',     label: 'National ID' },
  { value: 'alien_id',        label: 'Alien ID' },
  { value: 'passport',        label: 'Passport' },
  { value: 'driving_license', label: 'Driving licence' },
  { value: 'birth_cert',      label: 'Birth certificate' },
  { value: 'military_id',     label: 'Military ID' },
  { value: 'other',           label: 'Other' },
]
const idNumberLabels = {
  national_id: 'ID number', alien_id: 'Alien ID number',
  passport: 'Passport number', driving_license: 'Driving licence number',
  birth_cert: 'Birth certificate number', military_id: 'Military ID number',
  other: 'Identification number',
}
const idNumberLabel = computed(() => idNumberLabels[form.id_type] || 'Identification number')

const nationalities = [
  { code: 'KE', name: 'Kenya', flag: '🇰🇪' },
  { code: 'UG', name: 'Uganda', flag: '🇺🇬' },
  { code: 'TZ', name: 'Tanzania', flag: '🇹🇿' },
  { code: 'RW', name: 'Rwanda', flag: '🇷🇼' },
  { code: 'BI', name: 'Burundi', flag: '🇧🇮' },
  { code: 'SS', name: 'South Sudan', flag: '🇸🇸' },
  { code: 'ET', name: 'Ethiopia', flag: '🇪🇹' },
  { code: 'SO', name: 'Somalia', flag: '🇸🇴' },
  { code: 'SD', name: 'Sudan', flag: '🇸🇩' },
  { code: 'EG', name: 'Egypt', flag: '🇪🇬' },
  { code: 'NG', name: 'Nigeria', flag: '🇳🇬' },
  { code: 'GH', name: 'Ghana', flag: '🇬🇭' },
  { code: 'ZA', name: 'South Africa', flag: '🇿🇦' },
  { code: 'GB', name: 'United Kingdom', flag: '🇬🇧' },
  { code: 'US', name: 'United States', flag: '🇺🇸' },
  { code: 'CA', name: 'Canada', flag: '🇨🇦' },
  { code: 'IN', name: 'India', flag: '🇮🇳' },
  { code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪' },
  { code: 'OTHER', name: 'Other', flag: '🌐' },
]

const specializationOptions = [
  'General Practitioner', 'Family Medicine', 'Internal Medicine', 'Paediatrics',
  'Obstetrics & Gynaecology', 'Surgery', 'Orthopaedics', 'Cardiology',
  'Neurology', 'Psychiatry', 'Dermatology', 'Oncology', 'Endocrinology',
  'Gastroenterology', 'Nephrology', 'Pulmonology', 'Rheumatology',
  'Urology', 'ENT', 'Ophthalmology', 'Anaesthesiology', 'Radiology',
  'Pathology', 'Emergency Medicine', 'Geriatrics', 'Palliative Care', 'Other',
]

const additionalChoices = computed(() =>
  caregivers.value.filter(c => c.id !== form.assigned_caregiver))

const patientName = computed(() =>
  patient.value?.user?.full_name
  || [patient.value?.user?.first_name, patient.value?.user?.last_name].filter(Boolean).join(' ')
  || 'Patient')

const initials = computed(() => {
  const n = (patientName.value || '').trim()
  if (!n) return '?'
  const parts = n.split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || n[0].toUpperCase()
})

const riskColor = computed(() => ({
  low: 'success', medium: 'warning', high: 'orange', critical: 'error',
}[form.risk_level] || 'teal'))

let diagSearchTimer = null, alleSearchTimer = null
async function fetchDiagnoses(q = '') {
  loadingDiagnoses.value = true
  try {
    const { data } = await $api.get('/homecare/diagnoses/search/', { params: { q } })
    diagnosisItems.value = Array.isArray(data) ? data : (data?.results || [])
  } catch {} finally { loadingDiagnoses.value = false }
}
async function fetchAllergies(q = '') {
  loadingAllergies.value = true
  try {
    const { data } = await $api.get('/homecare/allergies/search/', { params: { q } })
    allergyItems.value = Array.isArray(data) ? data : (data?.results || [])
  } catch {} finally { loadingAllergies.value = false }
}
function onDiagnosisSearch(q) {
  clearTimeout(diagSearchTimer)
  diagSearchTimer = setTimeout(() => fetchDiagnoses(q || ''), 220)
}
function onAllergySearch(q) {
  clearTimeout(alleSearchTimer)
  alleSearchTimer = setTimeout(() => fetchAllergies(q || ''), 220)
}

function onPatientAddressSelect(place) {
  form.address_lat = place.lat ?? null
  form.address_lng = place.lon ?? null
}
function onContactAddressSelect(contact, place) {
  contact.address_lat = place.lat ?? null
  contact.address_lng = place.lon ?? null
}
function clearCoords() {
  form.address_lat = null
  form.address_lng = null
}

function addContact() {
  form.emergency_contacts.push({
    name: '', relationship: '', phone: '', email: '', address: '',
    address_lat: null, address_lng: null,
    is_primary: form.emergency_contacts.length === 0,
  })
}
function removeContact(i) { form.emergency_contacts.splice(i, 1) }
function markPrimary(i) {
  form.emergency_contacts.forEach((c, idx) => { c.is_primary = idx === i })
}

async function loadAll() {
  loadingCaregivers.value = true
  loadingDoctors.value = true
  try {
    const [pRes, cRes, dRes] = await Promise.all([
      $api.get(`/homecare/patients/${id.value}/`),
      $api.get('/homecare/caregivers/', { params: { page_size: 200 } }).catch(() => ({ data: [] })),
      $api.get('/doctors/directory/', { params: { page_size: 200 } }).catch(() => ({ data: [] })),
    ])
    patient.value = pRes.data

    caregivers.value = (cRes.data?.results || cRes.data || []).map(c => ({
      id: c.id,
      full_name: c.user?.full_name || c.user?.email || `Caregiver #${c.id}`,
      role: (c.specialties || []).join(', ') || 'Caregiver',
    }))
    doctors.value = (dRes.data?.results || dRes.data || []).map(d => ({
      id: d.id, user: d.user,
      name: d.name || d.email || `Doctor #${d.id}`,
      email: d.email, phone: d.phone,
      specialization: d.specialization, qualification: d.qualification,
    }))

    // Hydrate form
    const p = patient.value
    form.date_of_birth = (p.date_of_birth || '').slice(0, 10)
    form.gender = p.gender || ''
    form.address = p.address || ''
    form.address_lat = p.address_lat ?? null
    form.address_lng = p.address_lng ?? null
    form.id_type = p.id_type || 'national_id'
    form.id_number = p.id_number || ''
    form.nationality = p.nationality || 'KE'
    form.primary_diagnosis = p.primary_diagnosis || ''
    form.medical_history = p.medical_history || ''
    form.allergiesList = (p.allergies || '').split(/[,;\n]/).map(s => s.trim()).filter(Boolean)
    form.risk_level = p.risk_level || 'low'
    form.is_active = p.is_active !== false
    form.assigned_caregiver = p.assigned_caregiver ?? null
    form.additional_caregivers = (p.additional_caregivers_detail || []).map(c => c.id)
    form.assigned_doctor_user_id = p.assigned_doctor_user_id ?? null
    const di = p.assigned_doctor_info || {}
    form.manual_doctor = {
      name: di.name || '',
      specialization: di.specialization || '',
      phone: di.phone || '',
      email: di.email || '',
      hospital: di.hospital || '',
      notes: di.notes || '',
    }
    doctorMode.value = (!form.assigned_doctor_user_id && form.manual_doctor.name) ? 'manual' : 'directory'
    form.emergency_contacts = Array.isArray(p.emergency_contacts) ? p.emergency_contacts.map(c => ({
      name: c.name || '', relationship: c.relationship || '',
      phone: c.phone || '', email: c.email || '',
      address: c.address || '',
      address_lat: c.address_lat ?? null, address_lng: c.address_lng ?? null,
      is_primary: !!c.is_primary,
    })) : []

    fetchDiagnoses()
    fetchAllergies()
    loaded.value = true
  } catch (e) {
    topError.value = e?.response?.data?.detail || 'Failed to load patient.'
  } finally {
    loadingCaregivers.value = false
    loadingDoctors.value = false
  }
}

async function save() {
  topError.value = ''
  saving.value = true
  try {
    const payload = {
      date_of_birth: form.date_of_birth || null,
      gender: form.gender || '',
      address: form.address || '',
      address_lat: form.address_lat,
      address_lng: form.address_lng,
      id_type: form.id_type,
      id_number: form.id_number,
      nationality: form.nationality,
      primary_diagnosis: form.primary_diagnosis,
      medical_history: form.medical_history,
      allergies: (form.allergiesList || []).join(', '),
      risk_level: form.risk_level,
      is_active: form.is_active,
      assigned_caregiver: form.assigned_caregiver,
      additional_caregivers: form.additional_caregivers,
      assigned_doctor_user_id: doctorMode.value === 'directory' ? (form.assigned_doctor_user_id || null) : null,
      assigned_doctor_info: doctorMode.value === 'manual' && form.manual_doctor.name
        ? { ...form.manual_doctor } : {},
      emergency_contacts: (form.emergency_contacts || [])
        .filter(c => c.name || c.phone)
        .map(c => ({
          name: c.name, relationship: c.relationship || '',
          phone: c.phone || '', email: c.email || '',
          address: c.address || '',
          address_lat: c.address_lat ?? null, address_lng: c.address_lng ?? null,
          is_primary: !!c.is_primary,
        })),
    }
    await $api.patch(`/homecare/patients/${id.value}/`, payload)
    Object.assign(snack, { show: true, text: 'Patient updated', color: 'success' })
    setTimeout(() => router.push(`/homecare/patients/${id.value}`), 600)
  } catch (e) {
    const data = e?.response?.data
    topError.value = data?.detail
      || (typeof data === 'object' ? JSON.stringify(data) : (typeof data === 'string' ? data : 'Failed to save changes.'))
    Object.assign(snack, { show: true, text: 'Failed to save', color: 'error' })
  } finally {
    saving.value = false
  }
}

onMounted(loadAll)
</script>

<style scoped>
.hc-hero {
  background: linear-gradient(135deg, rgba(13,148,136,0.10) 0%, rgba(99,102,241,0.10) 100%);
  border: 1px solid rgba(13,148,136,0.18);
}
:global(.v-theme--dark) .hc-hero {
  background: linear-gradient(135deg, rgba(13,148,136,0.18) 0%, rgba(99,102,241,0.18) 100%);
  border-color: rgba(13,148,136,0.3);
}
.hc-avatar { box-shadow: 0 6px 20px rgba(0,0,0,0.18); }
.hc-card { background: white; border: 1px solid rgba(15,23,42,0.06); }
:global(.v-theme--dark) .hc-card { background: rgb(30,41,59); border-color: rgba(255,255,255,0.08); }
.hc-kin {
  background: rgba(239,68,68,0.04);
  border: 1px dashed rgba(239,68,68,0.35);
}
:global(.v-theme--dark) .hc-kin {
  background: rgba(239,68,68,0.10);
  border-color: rgba(239,68,68,0.45);
}
.min-w-0 { min-width: 0; }
</style>
