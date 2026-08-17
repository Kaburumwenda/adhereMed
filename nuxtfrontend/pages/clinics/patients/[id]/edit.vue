<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader :title="'Edit Patient'" :subtitle="patient?.patient_number || ''"
      icon="mdi-account-edit" color="primary">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`/clinics/patients/${id}`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-progress-linear v-if="loadingPatient" indeterminate color="primary" class="mb-4" />

    <v-form ref="formRef" @submit.prevent="save">
      <!-- ═══ Demographics ════════════════════════════════════════ -->
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
            <v-text-field v-model="form.date_of_birth" label="Date of birth"
              type="date" variant="outlined" :rules="req" prepend-inner-icon="mdi-cake-variant" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.gender" :items="genderOptions" label="Gender"
              variant="outlined" :rules="req" prepend-inner-icon="mdi-gender-male-female" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.blood_group" :items="bloodOptions" label="Blood group"
              variant="outlined" clearable prepend-inner-icon="mdi-water" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.phone" label="Phone" variant="outlined"
              prepend-inner-icon="mdi-phone" />
          </v-col>
          <v-col cols="12">
            <v-text-field v-model="form.email" label="Email" type="email" variant="outlined"
              :rules="emailRules" prepend-inner-icon="mdi-email" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.address" label="Address" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-map-marker" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Emergency Contact ════════════════════════════════════ -->
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
            <v-text-field v-model="form.emergency_contact_phone" label="Contact phone"
              variant="outlined" prepend-inner-icon="mdi-phone" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Insurance ═══════════════════════════════════════════ -->
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

      <!-- ── Error alert ─────────────────────────────────────────── -->
      <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mb-4">
        {{ r.error.value }}
      </v-alert>

      <!-- ── Action bar ──────────────────────────────────────────── -->
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none"
          @click="navigateTo(`/clinics/patients/${id}`)">Cancel</v-btn>
        <v-btn color="error" variant="text" rounded="lg" class="text-none"
          prepend-icon="mdi-delete" @click="deleteDialog = true">Delete</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Save Changes</v-btn>
      </div>
    </v-form>

    <!-- ── Delete confirmation dialog ────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Patient</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete
              <strong>{{ displayName }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">
                Patient #{{ patient?.patient_number || '—' }} — This action cannot be undone.
              </div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">
            Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const route = useRoute()
const r = useResource('/patients/')

const id = computed(() => route.params.id)

const formRef = ref(null)
const loadingPatient = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)
const patient = ref(null)

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
const bloodOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown']

const form = reactive({
  first_name: '', last_name: '', date_of_birth: '', gender: '', blood_group: '',
  phone: '', email: '', address: '',
  emergency_contact_name: '', emergency_contact_phone: '',
  insurance_provider: '', insurance_number: '',
})

const displayName = computed(() => {
  const p = patient.value
  if (!p) return ''
  if (p.user_name) return p.user_name
  return `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || p.user_email || p.user?.email || ''
})

// ── Load patient on mount ─────────────────────────────────────────
onMounted(async () => {
  loadingPatient.value = true
  try {
    const data = await r.get(id.value)
    patient.value = data
    if (data) {
      form.first_name = data.user?.first_name || ''
      form.last_name = data.user?.last_name || ''
      form.date_of_birth = data.date_of_birth || ''
      form.gender = data.gender || ''
      form.blood_group = data.blood_type || 'Unknown'
      form.phone = data.user?.phone || ''
      form.email = data.user_email || data.user?.email || ''
      form.address = data.address || ''
      form.emergency_contact_name = data.emergency_contact_name || ''
      form.emergency_contact_phone = data.emergency_contact_phone || ''
      form.insurance_provider = data.insurance_provider || ''
      form.insurance_number = data.insurance_number || ''
    }
  } catch {
    // error handled by r.error
  } finally {
    loadingPatient.value = false
  }
})

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  const payload = { ...form }
  if (payload.blood_group && payload.blood_group !== 'Unknown') {
    payload.blood_type = payload.blood_group
  } else {
    payload.blood_type = ''
  }
  delete payload.blood_group
  try {
    await r.update(id.value, payload)
    snack.text = 'Patient updated successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`/clinics/patients/${id.value}`)
  } catch {
    snack.text = r.error.value || 'Failed to save patient'
    snack.color = 'error'
    snack.show = true
  }
}

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(id.value)
    snack.text = 'Patient deleted'
    snack.color = 'success'
    snack.show = true
    navigateTo('/clinics/patients')
  } catch {
    snack.text = r.error.value || 'Failed to delete patient'
    snack.color = 'error'
    snack.show = true
    deleteDialog.value = false
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
