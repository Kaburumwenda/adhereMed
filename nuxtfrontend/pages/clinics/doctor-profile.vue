<template>
  <v-container fluid class="pa-4 pa-md-6 doctor-profile">
    <!-- ===== HERO BANNER ===== -->
    <v-card rounded="xl" flat class="hero-card mb-5 overflow-hidden position-relative">
      <div class="hero-blob blob-1" />
      <div class="hero-blob blob-2" />
      <v-card-text class="pa-5 pa-md-6 position-relative" style="z-index: 1">
        <div class="d-flex align-center flex-wrap ga-4">
          <!-- Avatar with upload -->
          <div class="position-relative">
            <v-avatar size="96" color="white" variant="flat" class="elevation-4">
              <v-img v-if="profile.profile_picture_url" :src="profile.profile_picture_url" cover />
              <span v-else class="text-h3 font-weight-black" style="color: rgb(var(--v-theme-primary))">{{ initial }}</span>
            </v-avatar>
            <v-btn
              icon
              size="small"
              color="primary"
              variant="flat"
              class="avatar-upload-btn"
              :loading="uploadingPicture"
              @click="triggerPictureUpload"
            >
              <v-icon size="16">mdi-camera</v-icon>
            </v-btn>
            <input ref="pictureInput" type="file" accept="image/*" class="d-none" @change="onPictureSelected" />
          </div>

          <div class="flex-grow-1">
            <div class="d-flex align-center ga-2 flex-wrap mb-1">
              <h2 class="text-h5 font-weight-bold text-white" style="letter-spacing: -0.5px">
                Dr. {{ auth.fullName || 'Doctor' }}
              </h2>
              <v-chip v-if="profile.is_verified" size="small" color="white" variant="flat" prepend-icon="mdi-check-decagram" class="font-weight-bold">
                Verified
              </v-chip>
              <v-chip v-else size="small" color="amber-accent-2" variant="flat" prepend-icon="mdi-clock-outline" class="font-weight-bold">
                Pending Verification
              </v-chip>
            </div>
            <div class="text-body-2 text-white" style="opacity: 0.78">
              {{ formatRole(auth.role) }}<span v-if="profile.specialization"> · {{ profile.specialization }}</span>
              <span v-if="profile.qualification"> · {{ profile.qualification }}</span>
            </div>
            <div class="text-caption text-white mt-1" style="opacity: 0.6">
              <v-icon size="14" class="mr-1">mdi-email-outline</v-icon>{{ profile.user_email || auth.user?.email }}
              <span v-if="profile.user_phone" class="ml-3"><v-icon size="14" class="mr-1">mdi-phone-outline</v-icon>{{ profile.user_phone }}</span>
              <span v-if="profile.years_of_experience" class="ml-3"><v-icon size="14" class="mr-1">mdi-medal</v-icon>{{ profile.years_of_experience }} yrs exp</span>
            </div>
          </div>

          <div class="d-flex flex-column align-end ga-2">
            <v-btn color="white" variant="flat" prepend-icon="mdi-content-save" :loading="saving" @click="saveProfile" class="font-weight-bold">
              Save Changes
            </v-btn>
            <v-btn color="white" variant="outlined" size="small" prepend-icon="mdi-lock-reset" @click="passwordDialog = true">
              Change Password
            </v-btn>
          </div>
        </div>
      </v-card-text>
    </v-card>

    <!-- ===== ALERTS ===== -->
    <v-alert v-if="error" type="error" variant="tonal" closable class="mb-4 rounded-lg" @click:close="error = null">{{ error }}</v-alert>
    <v-alert v-if="success" type="success" variant="tonal" closable class="mb-4 rounded-lg" @click:close="success = null">{{ success }}</v-alert>
    <v-alert v-if="!profile.id && !loading" type="warning" variant="tonal" class="mb-4 rounded-lg">
      No doctor profile found. Fill in your details below and save to create your profile.
    </v-alert>

    <!-- ===== LOADING ===== -->
    <div v-if="loading" class="d-flex justify-center pa-10">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <!-- ===== MAIN CONTENT ===== -->
    <v-row v-else dense>
      <!-- LEFT: Profile summary + status cards -->
      <v-col cols="12" lg="4">
        <!-- Summary Card -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-text class="pa-4">
            <div class="text-subtitle-2 font-weight-bold mb-3 d-flex align-center">
              <v-icon size="18" color="primary" class="mr-2">mdi-card-account-details</v-icon>
              At a Glance
            </div>
            <div class="d-flex flex-column ga-2">
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 text-medium-emphasis">Specialization</span>
                <span class="text-body-2 font-weight-medium">{{ profile.specialization || '—' }}</span>
              </div>
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 text-medium-emphasis">License</span>
                <span class="text-body-2 font-weight-medium">{{ profile.license_number || '—' }}</span>
              </div>
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 text-medium-emphasis">Qualification</span>
                <span class="text-body-2 font-weight-medium">{{ profile.qualification || '—' }}</span>
              </div>
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 text-medium-emphasis">Experience</span>
                <span class="text-body-2 font-weight-medium">{{ profile.years_of_experience ? `${profile.years_of_experience} years` : '—' }}</span>
              </div>
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 text-medium-emphasis">Consult Fee</span>
                <span class="text-body-2 font-weight-medium">{{ profile.consultation_fee ? formatMoney(profile.consultation_fee) : '—' }}</span>
              </div>
              <div class="d-flex align-center justify-space-between">
                <span class="text-body-2 text-medium-emphasis">Practice Type</span>
                <v-chip size="x-small" variant="tonal" :color="profile.practice_type === 'hospital' ? 'info' : 'primary'">
                  {{ profile.practice_type === 'hospital' ? 'Hospital' : 'Independent' }}
                </v-chip>
              </div>
            </div>
          </v-card-text>
        </v-card>

        <!-- Status toggles -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-text class="pa-4">
            <div class="text-subtitle-2 font-weight-bold mb-3 d-flex align-center">
              <v-icon size="18" color="success" class="mr-2">mdi-toggle-switch</v-icon>
              Status
            </div>
            <div class="d-flex flex-column ga-3">
              <div class="d-flex align-center justify-space-between">
                <div>
                  <div class="text-body-2 font-weight-medium">Accepting Patients</div>
                  <div class="text-caption text-medium-emphasis">Allow new patient bookings</div>
                </div>
                <v-switch v-model="form.is_accepting_patients" color="success" hide-details density="compact" />
              </div>
              <v-divider />
              <div class="d-flex align-center justify-space-between">
                <div>
                  <div class="text-body-2 font-weight-medium">Verification</div>
                  <div class="text-caption text-medium-emphasis">Admin-verified badge</div>
                </div>
                <v-chip :color="profile.is_verified ? 'success' : 'warning'" size="small" variant="tonal">
                  {{ profile.is_verified ? 'Verified' : 'Pending' }}
                </v-chip>
              </div>
              <v-divider />
              <div class="d-flex align-center justify-space-between">
                <div>
                  <div class="text-body-2 font-weight-medium">PIN</div>
                  <div class="text-caption text-medium-emphasis">Quick login code</div>
                </div>
                <div class="d-flex align-center ga-1">
                  <span class="text-body-2 font-weight-bold font-mono">{{ auth.user?.pin || '—' }}</span>
                  <v-btn icon="mdi-refresh" size="x-small" variant="text" color="primary" :loading="regeneratingPin" @click="regeneratePin" />
                </div>
              </div>
            </div>
          </v-card-text>
        </v-card>

        <!-- Digital Signature -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-text class="pa-4">
            <div class="text-subtitle-2 font-weight-bold mb-3 d-flex align-center">
              <v-icon size="18" color="purple" class="mr-2">mdi-draw</v-icon>
              Digital Signature
            </div>
            <div v-if="profile.signature_url" class="text-center mb-3">
              <v-img :src="profile.signature_url" max-height="80" contain class="rounded-lg mb-2" style="background: rgba(var(--v-theme-purple), 0.05); border: 1px dashed rgba(var(--v-theme-purple), 0.3); border-radius: 8px" />
              <v-btn variant="text" color="error" size="small" prepend-icon="mdi-delete" :loading="deletingSig" @click="deleteSignature">
                Remove Signature
              </v-btn>
            </div>
            <div v-else class="text-center text-medium-emphasis mb-3">
              <v-icon size="40" class="mb-1" color="grey-lighten-1">mdi-draw</v-icon>
              <div class="text-caption">No signature uploaded</div>
            </div>
            <input ref="sigInput" type="file" accept="image/*" class="d-none" @change="onSignatureSelected" />
            <v-btn block variant="tonal" color="purple" prepend-icon="mdi-upload" :loading="uploadingSig" @click="triggerSigUpload">
              Upload Signature
            </v-btn>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- RIGHT: Editable forms -->
      <v-col cols="12" lg="8">
        <!-- Personal Information -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="primary" class="mr-2" size="20">mdi-account-circle</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Personal Information</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-4">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.first_name" label="First Name" variant="outlined" density="compact" prepend-inner-icon="mdi-account" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.last_name" label="Last Name" variant="outlined" density="compact" prepend-inner-icon="mdi-account" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field :model-value="profile.user_email || auth.user?.email" label="Email" variant="outlined" density="compact" readonly prepend-inner-icon="mdi-email" hint="Contact admin to change" persistent-hint />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.phone" label="Phone" variant="outlined" density="compact" prepend-inner-icon="mdi-phone" />
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>

        <!-- Professional Details -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="warning" class="mr-2" size="20">mdi-stethoscope</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Professional Details</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-4">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.specialization" label="Specialization" variant="outlined" density="compact" prepend-inner-icon="mdi-tooth" placeholder="e.g. Cardiology" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.license_number" label="License Number" variant="outlined" density="compact" prepend-inner-icon="mdi-card-text" placeholder="e.g. KMPDB-00123" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.qualification" label="Qualification" variant="outlined" density="compact" prepend-inner-icon="mdi-school" placeholder="e.g. MBChB, MD" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model.number="form.years_of_experience" label="Years of Experience" type="number" variant="outlined" density="compact" prepend-inner-icon="mdi-medal" min="0" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.consultation_fee" label="Consultation Fee (KES)" type="number" variant="outlined" density="compact" prepend-inner-icon="mdi-cash" min="0" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.practice_type" :items="practiceTypes" item-title="label" item-value="value" label="Practice Type" variant="outlined" density="compact" prepend-inner-icon="mdi-hospital-building" />
              </v-col>
            </v-row>
            <v-textarea v-model="form.bio" label="Bio / About Me" variant="outlined" density="compact" rows="3" prepend-inner-icon="mdi-text" placeholder="Tell patients about your expertise and approach to care..." class="mt-2" />
          </v-card-text>
        </v-card>

        <!-- Availability Schedule -->
        <v-card rounded="xl" variant="outlined" class="mb-4">
          <v-card-title class="d-flex align-center pa-4 pb-2">
            <v-icon color="success" class="mr-2" size="20">mdi-calendar-clock</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Availability Schedule</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-4">
            <div class="text-caption text-medium-emphasis mb-2">Select the days you are available for appointments</div>
            <div class="d-flex flex-wrap ga-2 mb-4">
              <v-chip
                v-for="(day, i) in fullDays"
                :key="day"
                :color="availableDays.includes(day) ? 'success' : 'default'"
                :variant="availableDays.includes(day) ? 'flat' : 'outlined'"
                size="large"
                class="font-weight-bold"
                style="cursor: pointer; min-width: 44px"
                @click="toggleDay(day)"
              >
                {{ dayShort[i] }}
              </v-chip>
            </div>
            <v-divider class="mb-4" />
            <div class="text-caption text-medium-emphasis mb-2">Working Hours</div>
            <v-row dense>
              <v-col cols="6" sm="4">
                <v-text-field v-model="form.available_hours.start" label="Start Time" type="time" variant="outlined" density="compact" prepend-inner-icon="mdi-clock-start" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model="form.available_hours.end" label="End Time" type="time" variant="outlined" density="compact" prepend-inner-icon="mdi-clock-end" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field v-model="languagesInput" label="Languages (comma-separated)" variant="outlined" density="compact" prepend-inner-icon="mdi-translate" hint="e.g. English, Swahili, French" persistent-hint @keyup.enter="updateLanguages" @blur="updateLanguages" />
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>

        <!-- Save button bottom -->
        <div class="d-flex justify-end ga-2 mb-4">
          <v-btn variant="text" @click="resetForm">Reset</v-btn>
          <v-btn color="primary" variant="flat" prepend-icon="mdi-content-save" :loading="saving" @click="saveProfile" class="font-weight-bold px-6">
            Save Changes
          </v-btn>
        </div>
      </v-col>
    </v-row>

    <!-- ===== PASSWORD DIALOG ===== -->
    <v-dialog v-model="passwordDialog" max-width="480">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="primary" class="mr-2">mdi-lock-reset</v-icon>
          Change Password
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field v-model="pwForm.old_password" label="Current Password" type="password" variant="outlined" density="compact" class="mb-3" prepend-inner-icon="mdi-lock" />
          <v-text-field v-model="pwForm.new_password" label="New Password" type="password" variant="outlined" density="compact" class="mb-3" prepend-inner-icon="mdi-lock-open" :hint="pwForm.new_password && pwForm.new_password.length < 8 ? 'Minimum 8 characters' : ''" persistent-hint />
          <v-text-field v-model="pwForm.confirm_password" label="Confirm New Password" type="password" variant="outlined" density="compact" prepend-inner-icon="mdi-lock-check"
            :error="pwForm.confirm_password && pwForm.confirm_password !== pwForm.new_password"
            :error-messages="pwForm.confirm_password && pwForm.confirm_password !== pwForm.new_password ? 'Passwords do not match' : ''" />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="passwordDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="changingPassword" :disabled="!pwValid" @click="changePassword">Change Password</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ===== SNACKBAR ===== -->
    <v-snackbar v-model="snackbar.show" :color="snackbar.color" :timeout="3000" location="top right">
      {{ snackbar.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useNuxtApp } from '#app'
import { useAuthStore } from '~/stores/auth'
import { formatRole, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const auth = useAuthStore()

// ---- state ----
const loading = ref(true)
const saving = ref(false)
const error = ref(null)
const success = ref(null)
const uploadingPicture = ref(false)
const uploadingSig = ref(false)
const deletingSig = ref(false)
const regeneratingPin = ref(false)
const changingPassword = ref(false)
const passwordDialog = ref(false)

const profile = ref({})  // original fetched profile
const form = reactive({
  first_name: '',
  last_name: '',
  phone: '',
  specialization: '',
  license_number: '',
  qualification: '',
  years_of_experience: 0,
  bio: '',
  consultation_fee: 0,
  practice_type: 'independent',
  is_accepting_patients: true,
  available_days: [],
  available_hours: { start: '08:00', end: '17:00' },
  languages: [],
})
const availableDays = ref([])
const languagesInput = ref('')

const fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const practiceTypes = [
  { label: 'Independent Practice', value: 'independent' },
  { label: 'Hospital-based', value: 'hospital' },
]

const pictureInput = ref(null)
const sigInput = ref(null)

const initial = computed(() => (auth.fullName || 'D').charAt(0).toUpperCase())

const snackbar = reactive({ show: false, text: '', color: 'success' })
function showSnack(text, color = 'success') {
  snackbar.text = text
  snackbar.color = color
  snackbar.show = true
}

// ---- password ----
const pwForm = reactive({ old_password: '', new_password: '', confirm_password: '' })
const pwValid = computed(() =>
  pwForm.old_password && pwForm.new_password && pwForm.new_password.length >= 8 && pwForm.new_password === pwForm.confirm_password
)

// ---- helpers ----
function toggleDay(day) {
  const idx = availableDays.value.indexOf(day)
  if (idx >= 0) availableDays.value.splice(idx, 1)
  else availableDays.value.push(day)
}

function updateLanguages() {
  form.languages = languagesInput.value
    .split(',')
    .map(l => l.trim())
    .filter(Boolean)
}

function applyProfileToForm(data) {
  profile.value = data || {}
  form.first_name = data?.first_name || auth.user?.first_name || ''
  form.last_name = data?.last_name || auth.user?.last_name || ''
  form.phone = data?.phone || data?.user_phone || auth.user?.phone || ''
  form.specialization = data?.specialization || ''
  form.license_number = data?.license_number || ''
  form.qualification = data?.qualification || ''
  form.years_of_experience = data?.years_of_experience || 0
  form.bio = data?.bio || ''
  form.consultation_fee = data?.consultation_fee || 0
  form.practice_type = data?.practice_type || 'independent'
  form.is_accepting_patients = data?.is_accepting_patients ?? true
  form.available_hours = data?.available_hours || { start: '08:00', end: '17:00' }
  form.languages = data?.languages || []
  availableDays.value = [...(data?.available_days || [])]
  languagesInput.value = form.languages.join(', ')
}

function resetForm() {
  applyProfileToForm(profile.value)
  showSnack('Form reset to last saved state', 'info')
}

// ---- load ----
async function loadProfile() {
  loading.value = true
  error.value = null
  try {
    const { data } = await $api.get('/doctors/me/')
    applyProfileToForm(data)
  } catch (e) {
    if (e?.response?.status === 404) {
      // No profile yet — leave defaults
      applyProfileToForm(null)
    } else {
      error.value = 'Failed to load profile'
    }
  } finally {
    loading.value = false
  }
}

// ---- save ----
async function saveProfile() {
  saving.value = true
  error.value = null
  success.value = null
  try {
    updateLanguages()
    const payload = {
      ...form,
      available_days: availableDays.value,
      available_hours: { ...form.available_hours },
      languages: [...form.languages],
    }
    // Ensure numeric fields are numbers
    payload.years_of_experience = Number(payload.years_of_experience) || 0
    payload.consultation_fee = Number(payload.consultation_fee) || 0

    const { data } = await $api.patch('/doctors/me/', payload)
    applyProfileToForm(data)
    success.value = 'Profile saved successfully'
    showSnack('Profile saved!', 'success')
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to save profile'
    showSnack('Save failed', 'error')
  } finally {
    saving.value = false
  }
}

// ---- picture upload ----
function triggerPictureUpload() {
  pictureInput.value?.click()
}

async function onPictureSelected(e) {
  const file = e.target.files?.[0]
  if (!file) return
  uploadingPicture.value = true
  try {
    const fd = new FormData()
    fd.append('profile_picture', file)
    const { data } = await $api.patch('/doctors/me/upload-picture/', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    applyProfileToForm(data)
    showSnack('Profile picture updated!', 'success')
  } catch (e) {
    showSnack('Failed to upload picture', 'error')
  } finally {
    uploadingPicture.value = false
    if (pictureInput.value) pictureInput.value.value = ''
  }
}

// ---- signature upload ----
function triggerSigUpload() {
  sigInput.value?.click()
}

async function onSignatureSelected(e) {
  const file = e.target.files?.[0]
  if (!file) return
  uploadingSig.value = true
  try {
    const fd = new FormData()
    fd.append('signature', file)
    const { data } = await $api.patch('/doctors/me/upload-signature/', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    applyProfileToForm(data)
    showSnack('Signature uploaded!', 'success')
  } catch (e) {
    showSnack('Failed to upload signature', 'error')
  } finally {
    uploadingSig.value = false
    if (sigInput.value) sigInput.value.value = ''
  }
}

// ---- delete signature ----
async function deleteSignature() {
  deletingSig.value = true
  try {
    const { data } = await $api.delete('/doctors/me/delete-signature/')
    applyProfileToForm(data)
    showSnack('Signature removed', 'info')
  } catch (e) {
    showSnack('Failed to remove signature', 'error')
  } finally {
    deletingSig.value = false
  }
}

// ---- regenerate PIN ----
async function regeneratePin() {
  regeneratingPin.value = true
  try {
    const { data } = await $api.post('/auth/regenerate-pin/')
    if (data?.pin) {
      // Update local auth user pin
      if (auth.user) auth.user.pin = data.pin
      showSnack(`New PIN: ${data.pin}`, 'success')
    }
  } catch (e) {
    showSnack('Failed to regenerate PIN', 'error')
  } finally {
    regeneratingPin.value = false
  }
}

// ---- change password ----
async function changePassword() {
  if (!pwValid.value) return
  changingPassword.value = true
  try {
    await $api.post('/auth/change-password/', {
      old_password: pwForm.old_password,
      new_password: pwForm.new_password,
    })
    passwordDialog.value = false
    pwForm.old_password = ''
    pwForm.new_password = ''
    pwForm.confirm_password = ''
    showSnack('Password changed successfully!', 'success')
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to change password', 'error')
  } finally {
    changingPassword.value = false
  }
}

onMounted(() => {
  loadProfile()
})
</script>

<style scoped>
.doctor-profile { max-width: 1200px; margin: 0 auto; }

/* Hero */
.hero-card {
  background: linear-gradient(135deg, #1565C0 0%, #0D47A1 60%, #082A6D 100%);
}
.hero-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(40px);
  pointer-events: none;
}
.blob-1 { width: 300px; height: 300px; background: #42A5F5; top: -120px; right: -60px; opacity: 0.2; }
.blob-2 { width: 200px; height: 200px; background: #66BB6A; bottom: -100px; left: 30%; opacity: 0.1; }

/* Avatar upload */
.avatar-upload-btn {
  position: absolute;
  bottom: -4px;
  right: -4px;
  z-index: 2;
}
.position-relative { position: relative; }

/* Font mono for PIN */
.font-mono { font-family: 'Courier New', monospace; letter-spacing: 2px; }
</style>
