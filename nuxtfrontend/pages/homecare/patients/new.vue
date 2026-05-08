<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:920px;">
    <PageHeader title="Enrol patient" icon="mdi-account-plus" subtitle="Create a patient account & open a homecare record.">
      <template #actions>
        <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
               class="text-none" to="/homecare/patients">Back</v-btn>
      </template>
    </PageHeader>

    <v-card rounded="xl" class="pa-4 pa-md-6">
      <v-form ref="formRef" @submit.prevent="submit">
        <v-row>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.user_email" label="Email" type="email" required
                          :error-messages="errors.user_email" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.first_name" label="First name" required
                          :error-messages="errors.first_name" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.last_name" label="Last name" required
                          :error-messages="errors.last_name" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.phone" label="Phone" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.password" label="Initial password" type="text"
                          hint="Patient can change later" persistent-hint />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.date_of_birth" label="Date of birth" type="date" />
          </v-col>
          <v-col cols="12" md="3">
            <v-select v-model="form.gender" label="Gender" :items="['Male','Female','Other']" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.risk_level" label="Risk level"
                      :items="['low','medium','high','critical']" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.assigned_caregiver" label="Assigned caregiver"
                      :items="caregivers" item-title="full_name" item-value="id" clearable />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.address" label="Address" rows="2" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.primary_diagnosis" label="Primary diagnosis" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.allergies" label="Allergies" />
          </v-col>
        </v-row>

        <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mt-4">
          {{ topError }}
        </v-alert>
        <div class="d-flex justify-end ga-2 mt-6">
          <v-btn variant="text" rounded="lg" class="text-none" to="/homecare/patients">Cancel</v-btn>
          <v-btn type="submit" color="teal" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-account-check">Enrol patient</v-btn>
        </div>
      </v-form>
    </v-card>
  </v-container>
</template>

<script setup>
const router = useRouter()
const { $api } = useNuxtApp()

const form = reactive({
  user_email: '', first_name: '', last_name: '', phone: '', password: '',
  date_of_birth: '', gender: '', address: '', primary_diagnosis: '',
  allergies: '', risk_level: 'low', assigned_caregiver: null
})
const errors = ref({})
const topError = ref('')
const saving = ref(false)
const formRef = ref(null)
const caregivers = ref([])

onMounted(async () => {
  try {
    const { data } = await $api.get('/homecare/caregivers/')
    const items = data?.results || data || []
    caregivers.value = items.map(c => ({ id: c.id, full_name: c.user?.full_name || c.user?.email }))
  } catch { /* ignore */ }
})

async function submit() {
  topError.value = ''
  errors.value = {}
  saving.value = true
  try {
    const payload = { ...form }
    if (!payload.date_of_birth) delete payload.date_of_birth
    const { data } = await $api.post('/homecare/patients/enroll/', payload)
    router.push(`/homecare/patients/${data.id}`)
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object' && !data.detail) errors.value = data
    topError.value = data?.detail || 'Enrolment failed.'
  } finally {
    saving.value = false
  }
}
</script>

