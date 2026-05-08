<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:1080px;">
    <PageHeader title="Company profile" icon="mdi-domain" subtitle="Manage your homecare organisation profile." />
    <v-card v-if="profile" rounded="xl" class="pa-4 pa-md-6">
      <v-form @submit.prevent="save">
        <v-row>
          <v-col cols="12" md="6"><v-text-field v-model="profile.legal_name" label="Legal name" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="profile.registration_number" label="Registration number" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="profile.contact_email" label="Email" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="profile.contact_phone" label="Phone" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="profile.city" label="City" /></v-col>
          <v-col cols="12" md="6"><v-text-field v-model="profile.country" label="Country" /></v-col>
          <v-col cols="12"><v-textarea v-model="profile.about" label="About" rows="3" /></v-col>
          <v-col cols="12"><v-combobox v-model="profile.service_areas" label="Service areas" multiple chips clearable /></v-col>
          <v-col cols="12"><v-combobox v-model="profile.accreditations" label="Accreditations" multiple chips clearable /></v-col>
        </v-row>
        <div class="d-flex justify-end mt-4">
          <v-btn type="submit" color="teal" rounded="lg" prepend-icon="mdi-content-save"
                 class="text-none" :loading="saving">Save</v-btn>
        </div>
      </v-form>
    </v-card>
    <EmptyState v-else icon="mdi-domain" title="Loading…" />
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>
<script setup>
const { $api } = useNuxtApp()
const profile = ref(null)
const saving = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })
async function load() {
  try {
    const { data } = await $api.get('/homecare/company-profile/current/')
    profile.value = data
  } catch {
    profile.value = {
      legal_name: '', registration_number: '', contact_email: '', contact_phone: '',
      city: '', country: 'Kenya', about: '', service_areas: [], accreditations: []
    }
  }
}
async function save() {
  saving.value = true
  try {
    if (profile.value.id) {
      await $api.patch(`/homecare/company-profile/${profile.value.id}/`, profile.value)
    } else {
      const { data } = await $api.post('/homecare/company-profile/', profile.value)
      profile.value = data
    }
    snack.text = 'Saved'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Save failed'; snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}
onMounted(load)
</script>
