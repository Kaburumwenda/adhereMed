<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="My Profile" subtitle="View and edit your profile" icon="mdi-account" color="primary">
      <template #actions>
        <v-btn color="primary" :loading="saving" @click="saveProfile">Save Changes</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>
    <v-alert v-if="success" type="success" variant="tonal" class="mb-4">{{ success }}</v-alert>

    <v-row dense>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="text-center pa-4">
          <v-avatar size="100" color="primary" variant="tonal" class="mb-3">
            <v-icon size="48" icon="mdi-account" />
          </v-avatar>
          <h3 class="text-h6 font-weight-bold">{{ form.first_name }} {{ form.last_name }}</h3>
          <div class="text-body-2 text-medium-emphasis">{{ formatRole(form.role) }}</div>
          <div class="text-body-2 text-medium-emphasis">{{ form.email }}</div>
        </v-card>
      </v-col>
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-4">
          <div class="text-subtitle-1 font-weight-bold mb-3">Personal Information</div>
          <v-row dense>
            <v-col cols="12" md="6"><v-text-field v-model="form.first_name" label="First Name" variant="outlined" density="compact" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.last_name" label="Last Name" variant="outlined" density="compact" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.email" label="Email" variant="outlined" density="compact" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.phone" label="Phone" variant="outlined" density="compact" /></v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-subtitle-1 font-weight-bold mb-3">Change Password</div>
          <v-text-field v-model="form.new_password" label="New Password" type="password" variant="outlined" density="compact" hint="Leave blank to keep current password" persistent-hint />
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatRole } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $api } = useNuxtApp()
const form = reactive({ first_name: '', last_name: '', email: '', phone: '', role: '', new_password: '' })
const saving = ref(false)
const error = ref(null)
const success = ref(null)

onMounted(async () => {
  try {
    const { data } = await $api.get('/auth/me/')
    Object.assign(form, data)
  } catch (e) { error.value = 'Failed to load profile' }
})

async function saveProfile() {
  saving.value = true
  error.value = null
  success.value = null
  try {
    const payload = { first_name: form.first_name, last_name: form.last_name, email: form.email, phone: form.phone }
    if (form.new_password) payload.password = form.new_password
    await $api.patch('/auth/me/', payload)
    success.value = 'Profile updated successfully'
    auth.user = { ...auth.user, ...payload }
    form.new_password = ''
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to update profile'
  } finally { saving.value = false }
}
</script>
