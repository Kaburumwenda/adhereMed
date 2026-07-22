<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="My Profile" icon="mdi-account-circle" subtitle="View and update your account and health details" />

    <!-- Patient ID banner -->
    <v-card v-if="patient" rounded="lg" class="pa-4 mb-4" color="primary" variant="tonal">
      <div class="d-flex align-center flex-wrap ga-4">
        <v-avatar size="56" color="primary" variant="flat">
          <span class="text-h6">{{ initials }}</span>
        </v-avatar>
        <div>
          <div class="text-h6">{{ fullName }}</div>
          <div class="text-body-2 text-medium-emphasis">{{ account.email }}</div>
        </div>
        <v-spacer />
        <div class="text-sm-right">
          <div class="text-caption text-medium-emphasis">Patient ID</div>
          <v-chip color="primary" size="large" variant="flat" class="font-weight-bold text-h6">
            {{ patient.patient_id || '—' }}
          </v-chip>
        </div>
      </div>
      <div class="text-caption text-medium-emphasis mt-2">
        Use your Patient ID to access AdhereMed services everywhere.
      </div>
    </v-card>

    <!-- Account details -->
    <v-card rounded="lg" class="pa-4 mb-4">
      <div class="text-subtitle-1 font-weight-bold mb-3">
        <v-icon size="20" class="mr-1">mdi-account</v-icon> Account details
      </div>
      <v-form @submit.prevent="saveAccount">
        <v-row dense>
          <v-col cols="12" sm="6"><v-text-field v-model="account.first_name" label="First name" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="account.last_name" label="Last name" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="account.email" label="Email" type="email" variant="outlined" density="comfortable" disabled hint="Email cannot be changed" persistent-hint /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="account.phone" label="Phone" variant="outlined" density="comfortable" /></v-col>
        </v-row>
        <div class="d-flex justify-end mt-2">
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingAccount" type="submit">Save account</v-btn>
        </div>
      </v-form>
    </v-card>

    <!-- Health details -->
    <v-card v-if="patient" rounded="lg" class="pa-4 mb-4">
      <div class="text-subtitle-1 font-weight-bold mb-3">
        <v-icon size="20" class="mr-1">mdi-heart-pulse</v-icon> Health details
      </div>
      <v-form @submit.prevent="savePatient">
        <v-row dense>
          <v-col cols="12" sm="6"><v-text-field v-model="patient.date_of_birth" label="Date of birth" type="date" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="patient.gender" :items="genderOptions" label="Gender" variant="outlined" density="comfortable" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="patient.blood_type" :items="bloodTypes" label="Blood type" variant="outlined" density="comfortable" clearable />
          </v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="patient.national_id" label="National ID" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12"><v-text-field v-model="patient.address" label="Address" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="6">
            <v-combobox v-model="patient.allergies" :items="allergyOptions" label="Allergies"
              variant="outlined" density="comfortable" multiple chips closable-chips clearable
              hint="Select or type to add your own" persistent-hint />
          </v-col>
          <v-col cols="12" sm="6">
            <v-combobox v-model="patient.chronic_conditions" :items="conditionOptions" label="Chronic conditions"
              variant="outlined" density="comfortable" multiple chips closable-chips clearable
              hint="Select or type to add your own" persistent-hint />
          </v-col>
        </v-row>

        <div class="text-subtitle-2 font-weight-bold mt-2 mb-2">Emergency contact</div>
        <v-row dense>
          <v-col cols="12" sm="4"><v-text-field v-model="patient.emergency_contact_name" label="Name" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="4"><v-text-field v-model="patient.emergency_contact_phone" label="Phone" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="4"><v-text-field v-model="patient.emergency_contact_relation" label="Relationship" variant="outlined" density="comfortable" /></v-col>
        </v-row>

        <div class="text-subtitle-2 font-weight-bold mt-2 mb-2">Insurance</div>
        <v-row dense>
          <v-col cols="12" sm="6"><v-text-field v-model="patient.insurance_provider" label="Provider" variant="outlined" density="comfortable" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="patient.insurance_number" label="Member number" variant="outlined" density="comfortable" /></v-col>
        </v-row>

        <div class="d-flex justify-end mt-2">
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingPatient" type="submit">Save health details</v-btn>
        </div>
      </v-form>
    </v-card>

    <!-- Change password -->
    <v-card rounded="lg" class="pa-4 mb-4">
      <div class="text-subtitle-1 font-weight-bold mb-3">
        <v-icon size="20" class="mr-1">mdi-lock</v-icon> Change password
      </div>
      <v-form @submit.prevent="changePassword">
        <v-row dense>
          <v-col cols="12" sm="4">
            <v-text-field v-model="pw.old_password" label="Current password" :type="showPw ? 'text' : 'password'"
              variant="outlined" density="comfortable"
              :append-inner-icon="showPw ? 'mdi-eye-off' : 'mdi-eye'" @click:append-inner="showPw = !showPw" />
          </v-col>
          <v-col cols="12" sm="4">
            <v-text-field v-model="pw.new_password" label="New password" :type="showPw ? 'text' : 'password'"
              variant="outlined" density="comfortable" hint="At least 8 characters" persistent-hint />
          </v-col>
          <v-col cols="12" sm="4">
            <v-text-field v-model="pw.confirm" label="Confirm new password" :type="showPw ? 'text' : 'password'"
              variant="outlined" density="comfortable" :error-messages="pwMismatch ? 'Passwords do not match' : ''" />
          </v-col>
        </v-row>
        <div class="d-flex justify-end mt-2">
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingPw" type="submit"
            :disabled="!pw.old_password || !pw.new_password || pwMismatch">Update password</v-btn>
        </div>
      </v-form>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const account = ref({ ...(auth.user || {}) })
const patient = ref(null)

const savingAccount = ref(false)
const savingPatient = ref(false)
const savingPw = ref(false)
const showPw = ref(false)
const pw = reactive({ old_password: '', new_password: '', confirm: '' })
const snack = reactive({ show: false, text: '', color: 'success' })

const genderOptions = [
  { title: 'Male', value: 'male' },
  { title: 'Female', value: 'female' },
  { title: 'Other', value: 'other' },
]
const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
const allergyOptions = [
  'Penicillin', 'Aspirin', 'Ibuprofen', 'Sulfa drugs', 'Peanuts', 'Tree nuts',
  'Shellfish', 'Eggs', 'Milk', 'Soy', 'Latex', 'Pollen', 'Dust mites',
  'Bee stings', 'Iodine',
]
const conditionOptions = [
  'Hypertension', 'Diabetes (Type 1)', 'Diabetes (Type 2)', 'Asthma', 'COPD',
  'Heart disease', 'Chronic kidney disease', 'Arthritis', 'Epilepsy',
  'HIV/AIDS', 'Cancer', 'Thyroid disorder', 'Depression', 'Anxiety',
  'Sickle cell disease', 'Tuberculosis',
]

function toList(v) {
  if (Array.isArray(v)) return v
  if (typeof v === 'string' && v.trim()) return v.split(',').map((s) => s.trim()).filter(Boolean)
  return []
}

const fullName = computed(() =>
  [account.value.first_name, account.value.last_name].filter(Boolean).join(' ') || account.value.email || 'Patient')
const initials = computed(() => {
  const f = (account.value.first_name || account.value.email || 'P')[0] || 'P'
  const l = (account.value.last_name || '')[0] || ''
  return (f + l).toUpperCase()
})
const pwMismatch = computed(() => !!pw.confirm && pw.new_password !== pw.confirm)

function notify(text, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true
}
function firstError(data, fallback) {
  if (!data) return fallback
  if (typeof data === 'string') return data
  if (data.detail) return data.detail
  for (const v of Object.values(data)) {
    const m = Array.isArray(v) ? v[0] : v
    if (m) return String(m)
  }
  return fallback
}

async function loadPatient() {
  try {
    const { data } = await $api.get('/patients/me/')
    data.allergies = toList(data.allergies)
    data.chronic_conditions = toList(data.chronic_conditions)
    patient.value = data
  } catch (e) {
    // Non-patient users (or missing profile) simply won't see the health section
    patient.value = null
  }
}

async function saveAccount() {
  savingAccount.value = true
  try {
    const { data } = await $api.patch('/auth/me/', {
      first_name: account.value.first_name,
      last_name: account.value.last_name,
      phone: account.value.phone,
    })
    auth.user = data
    account.value = { ...data }
    notify('Account updated')
  } catch (e) {
    notify(firstError(e?.response?.data, 'Failed to update account'), 'error')
  } finally { savingAccount.value = false }
}

async function savePatient() {
  savingPatient.value = true
  try {
    const payload = {
      date_of_birth: patient.value.date_of_birth || null,
      gender: patient.value.gender,
      blood_type: patient.value.blood_type || '',
      national_id: patient.value.national_id || null,
      address: patient.value.address || '',
      allergies: toList(patient.value.allergies),
      chronic_conditions: toList(patient.value.chronic_conditions),
      emergency_contact_name: patient.value.emergency_contact_name || '',
      emergency_contact_phone: patient.value.emergency_contact_phone || '',
      emergency_contact_relation: patient.value.emergency_contact_relation || '',
      insurance_provider: patient.value.insurance_provider || '',
      insurance_number: patient.value.insurance_number || '',
    }
    const { data } = await $api.patch('/patients/me/', payload)
    data.allergies = toList(data.allergies)
    data.chronic_conditions = toList(data.chronic_conditions)
    patient.value = data
    notify('Health details updated')
  } catch (e) {
    notify(firstError(e?.response?.data, 'Failed to update health details'), 'error')
  } finally { savingPatient.value = false }
}

async function changePassword() {
  if (pwMismatch.value) return
  savingPw.value = true
  try {
    await $api.post('/auth/change-password/', {
      old_password: pw.old_password,
      new_password: pw.new_password,
    })
    pw.old_password = ''; pw.new_password = ''; pw.confirm = ''
    notify('Password updated successfully')
  } catch (e) {
    notify(firstError(e?.response?.data, 'Failed to update password'), 'error')
  } finally { savingPw.value = false }
}

onMounted(loadPatient)
</script>
