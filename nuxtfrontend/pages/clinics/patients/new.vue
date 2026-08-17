<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="New Patient" subtitle="Register a new clinic patient"
      icon="mdi-account-plus" color="primary">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo('/clinics/patients')">Back</v-btn>
      </template>
    </PageHeader>

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
          @click="navigateTo('/clinics/patients')">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Create Patient</v-btn>
      </div>
    </v-form>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const router = useRouter()
const r = useResource('/patients/')
const formRef = ref(null)

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

const snack = reactive({ show: false, color: 'success', text: '' })

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  // Map blood_group -> blood_type for backend
  const payload = { ...form }
  if (payload.blood_group && payload.blood_group !== 'Unknown') {
    payload.blood_type = payload.blood_group
  } else {
    payload.blood_type = ''
  }
  delete payload.blood_group
  try {
    const created = await r.create(payload)
    snack.text = 'Patient created successfully'
    snack.color = 'success'
    snack.show = true
    if (created?.id) {
      router.push(`/clinics/patients/${created.id}`)
    } else {
      router.push('/clinics/patients')
    }
  } catch {
    snack.text = r.error.value || 'Failed to create patient'
    snack.color = 'error'
    snack.show = true
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
