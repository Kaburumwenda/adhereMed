<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:920px;">
    <PageHeader title="Add caregiver" icon="mdi-account-plus" subtitle="Onboard a new caregiver to your homecare team.">
      <template #actions>
        <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
               class="text-none" to="/homecare/caregivers">Back</v-btn>
      </template>
    </PageHeader>
    <v-card rounded="xl" class="pa-4 pa-md-6">
      <v-form @submit.prevent="submit">
        <v-row>
          <v-col cols="12" md="6"><v-text-field v-model="form.email" label="Email" type="email" required /></v-col>
          <v-col cols="12" md="3"><v-text-field v-model="form.first_name" label="First name" required /></v-col>
          <v-col cols="12" md="3"><v-text-field v-model="form.last_name" label="Last name" required /></v-col>
          <v-col cols="12" md="4"><v-text-field v-model="form.phone" label="Phone" /></v-col>
          <v-col cols="12" md="4"><v-text-field v-model="form.password" label="Initial password" /></v-col>
          <v-col cols="12" md="4"><v-text-field v-model="form.license_number" label="License number" /></v-col>
          <v-col cols="12"><v-combobox v-model="form.specialties" label="Specialties" multiple chips clearable /></v-col>
          <v-col cols="12"><v-textarea v-model="form.bio" label="Bio" rows="2" /></v-col>
          <v-col cols="12" md="3"><v-text-field v-model.number="form.hourly_rate" label="Hourly rate" type="number" /></v-col>
          <v-col cols="12" md="3"><v-text-field v-model="form.hire_date" label="Hire date" type="date" /></v-col>
          <v-col cols="12" md="3"><v-switch v-model="form.is_available" label="Available" color="teal" /></v-col>
          <v-col cols="12" md="3"><v-switch v-model="form.is_independent" label="Independent contractor" color="teal" /></v-col>
        </v-row>
        <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mt-4">{{ topError }}</v-alert>
        <div class="d-flex justify-end ga-2 mt-4">
          <v-btn variant="text" rounded="lg" class="text-none" to="/homecare/caregivers">Cancel</v-btn>
          <v-btn type="submit" color="teal" rounded="lg" class="text-none" :loading="saving" prepend-icon="mdi-content-save">Save</v-btn>
        </div>
      </v-form>
    </v-card>
  </v-container>
</template>
<script setup>
const router = useRouter()
const { $api } = useNuxtApp()
const form = reactive({
  email: '', first_name: '', last_name: '', phone: '', password: 'caregiver1234',
  license_number: '', specialties: [], bio: '', hourly_rate: 0,
  hire_date: '', is_available: true, is_independent: false
})
const saving = ref(false)
const topError = ref('')
async function submit() {
  saving.value = true
  topError.value = ''
  try {
    const { data } = await $api.post('/homecare/caregivers/enroll/', {
      user_email: form.email, first_name: form.first_name, last_name: form.last_name,
      phone: form.phone, password: form.password,
      license_number: form.license_number, specialties: form.specialties, bio: form.bio,
      hourly_rate: form.hourly_rate, is_available: form.is_available,
      is_independent: form.is_independent
    })
    router.push(`/homecare/caregivers/${data.id}`)
  } catch (e) {
    topError.value = e?.response?.data?.detail || 'Could not create caregiver.'
  } finally {
    saving.value = false
  }
}
</script>
