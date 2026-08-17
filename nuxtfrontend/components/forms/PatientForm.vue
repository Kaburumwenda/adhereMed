<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <!-- ── Header ─────────────────────────────────────────────────── -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="primary-lighten-5" size="48">
        <v-icon color="primary-darken-2" size="28">
          {{ loadId ? 'mdi-account-edit' : 'mdi-account-plus' }}
        </v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">
          {{ loadId ? 'Edit Patient' : 'New Patient' }}
        </div>
        <div class="text-body-2 text-medium-emphasis">
          {{ loadId ? 'Update patient demographic and medical information' : 'Register a new patient in the system' }}
        </div>
      </div>
      <v-spacer />
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
             :to="backPath">Back</v-btn>
    </div>

    <!-- ── Loading skeleton ──────────────────────────────────────── -->
    <v-progress-linear v-if="loadingById" indeterminate color="primary" class="mb-4" />

    <v-form ref="formRef" @submit.prevent="onSubmit">
      <!-- ═══ Section: Demographics ════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="indigo-lighten-5" size="36" class="mr-3">
            <v-icon color="indigo-darken-2" size="20">mdi-account-details</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Demographics</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.first_name" label="First name" variant="outlined"
                          :rules="req" prepend-inner-icon="mdi-account" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.last_name" label="Last name" variant="outlined"
                          :rules="req" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.email" label="Email" type="email" variant="outlined"
                          :rules="emailRules" prepend-inner-icon="mdi-email" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                          prepend-inner-icon="mdi-phone" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.national_id" label="National ID" variant="outlined"
                          :rules="req" prepend-inner-icon="mdi-card-account-details" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.date_of_birth" label="Date of birth"
                          type="date" variant="outlined" :rules="req" prepend-inner-icon="mdi-cake-variant" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.gender" :items="genderOptions" label="Gender"
                      variant="outlined" :rules="req" prepend-inner-icon="mdi-gender-male-female" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.blood_type" :items="bloodOptions" label="Blood type"
                      variant="outlined" clearable prepend-inner-icon="mdi-water" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.address" label="Address" rows="2" auto-grow
                        variant="outlined" prepend-inner-icon="mdi-map-marker" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Section: Medical Information ═════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="red-lighten-5" size="36" class="mr-3">
            <v-icon color="red-darken-2" size="20">mdi-medical-bag</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Medical Information</div>
        </div>
        <v-row dense>
          <v-col cols="12">
            <v-combobox
              v-model="form.allergies"
              :items="commonAllergies"
              label="Allergies"
              multiple chips closable-chips small-chips
              variant="outlined"
              placeholder="Add an allergy and press Enter"
              hint="Known drug or food allergies"
              persistent-hint
              prepend-inner-icon="mdi-alert-circle"
            />
          </v-col>
          <v-col cols="12">
            <v-combobox
              v-model="form.chronic_conditions"
              :items="commonChronic"
              label="Chronic conditions"
              multiple chips closable-chips small-chips
              variant="outlined"
              placeholder="Add a condition and press Enter"
              hint="Long-term health conditions"
              persistent-hint
              prepend-inner-icon="mdi-pulse"
            />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="Clinical notes" rows="2" auto-grow
                        variant="outlined" prepend-inner-icon="mdi-note-text" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Section: Emergency Contact ═══════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="amber-lighten-5" size="36" class="mr-3">
            <v-icon color="amber-darken-3" size="20">mdi-phone-alert</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Emergency Contact</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.emergency_contact_name" label="Contact name"
                          variant="outlined" prepend-inner-icon="mdi-account" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.emergency_contact_relation" label="Relationship"
                          variant="outlined" placeholder="e.g. Spouse, Parent, Sibling"
                          prepend-inner-icon="mdi-account-group" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.emergency_contact_phone" label="Contact phone"
                          variant="outlined" prepend-inner-icon="mdi-phone" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Section: Insurance ═══════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="green-lighten-5" size="36" class="mr-3">
            <v-icon color="green-darken-2" size="20">mdi-shield-plus</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Insurance</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.insurance_provider" label="Insurance provider"
                          variant="outlined" prepend-inner-icon="mdi-domain" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.insurance_number" label="Policy / member number"
                          variant="outlined" prepend-inner-icon="mdi-numeric" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ── Error alert ───────────────────────────────────────────── -->
      <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mb-4">
        {{ topError }}
      </v-alert>

      <!-- ── Action bar ─────────────────────────────────────────────── -->
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none" :to="backPath">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
               :loading="saving" prepend-icon="mdi-content-save">
          {{ loadId ? 'Save Changes' : 'Create Patient' }}
        </v-btn>
      </div>
    </v-form>

    <!-- ── Snackbar ───────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const route = useRoute()
const router = useRouter()

const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePatientsPath = computed(() => `${ns.value}/patients`)
const backPath = computed(() => basePatientsPath.value)

const loadId = computed(() => route.params.id || null)
const r = useResource('/patients/')
const { $api } = useNuxtApp()

const formRef = ref(null)
const saving = ref(false)
const loadingById = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const req = [v => !!v || 'Required']
const emailRules = [
  v => !!v || 'Email is required',
  v => /.+@.+\..+/.test(v) || 'Enter a valid email',
]

const genderOptions = [
  { title: 'Male', value: 'male' },
  { title: 'Female', value: 'female' },
  { title: 'Other', value: 'other' },
]
const bloodOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']

const commonAllergies = ['Penicillin', 'Sulfa', 'Aspirin', 'Ibuprofen', 'Latex', 'Peanuts', 'Shellfish', 'Eggs', 'Milk', 'Pollen']
const commonChronic = ['Diabetes', 'Hypertension', 'Asthma', 'Arthritis', 'Heart Disease', 'CKD', 'COPD', 'Epilepsy', 'Thyroid Disorder']

const form = reactive({
  first_name: '', last_name: '', email: '', phone: '',
  national_id: '', date_of_birth: '', gender: '', blood_type: '',
  address: '', allergies: [], chronic_conditions: [], notes: '',
  emergency_contact_name: '', emergency_contact_phone: '', emergency_contact_relation: '',
  insurance_provider: '', insurance_number: '',
})

onMounted(async () => {
  if (loadId.value) {
    loadingById.value = true
    try {
      const data = await r.get(loadId.value)
      if (data) {
        // Flatten user fields into form
        form.first_name = data.user?.first_name || ''
        form.last_name = data.user?.last_name || ''
        form.email = data.user?.email || data.user_email || ''
        form.phone = data.user?.phone || ''
        // Patient fields
        form.national_id = data.national_id || ''
        form.date_of_birth = data.date_of_birth || ''
        form.gender = data.gender || ''
        form.blood_type = data.blood_type || ''
        form.address = data.address || ''
        form.allergies = Array.isArray(data.allergies) ? [...data.allergies] : []
        form.chronic_conditions = Array.isArray(data.chronic_conditions) ? [...data.chronic_conditions] : []
        form.notes = data.notes || ''
        form.emergency_contact_name = data.emergency_contact_name || ''
        form.emergency_contact_phone = data.emergency_contact_phone || ''
        form.emergency_contact_relation = data.emergency_contact_relation || ''
        form.insurance_provider = data.insurance_provider || ''
        form.insurance_number = data.insurance_number || ''
      }
    } catch (e) {
      topError.value = r.error.value || 'Failed to load patient'
    } finally {
      loadingById.value = false
    }
  }
})

async function onSubmit() {
  topError.value = ''
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  saving.value = true
  try {
    const payload = { ...form }
    const result = loadId.value
      ? await r.update(loadId.value, payload)
      : await r.create(payload)
    snack.text = loadId.value ? 'Patient updated successfully' : 'Patient created successfully'
    snack.color = 'success'
    snack.show = true
    // Navigate to detail page or list
    setTimeout(() => {
      if (result?.id) {
        router.push(`${basePatientsPath.value}/${result.id}`)
      } else {
        router.push(basePatientsPath.value)
      }
    }, 600)
  } catch (e) {
    const data = e?.response?.data
    if (data) {
      if (typeof data === 'object' && !data.detail) {
        // Field-level errors — show first few as top error
        const msgs = Object.entries(data).map(([k, v]) => {
          const val = Array.isArray(v) ? v.join(', ') : String(v)
          return `${k}: ${val}`
        })
        topError.value = msgs.slice(0, 3).join(' · ')
      } else {
        topError.value = data.detail || r.error.value || 'Failed to save patient'
      }
    } else {
      topError.value = r.error.value || 'Failed to save patient'
    }
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.form-section {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
</style>
