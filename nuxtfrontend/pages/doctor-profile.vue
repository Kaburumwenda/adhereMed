<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="My Doctor Profile" icon="mdi-account-tie" subtitle="Manage your professional profile" />
    <v-card v-if="form" rounded="lg" class="pa-4">
      <v-form @submit.prevent="save">
        <v-row dense>
          <v-col cols="12" sm="6"><v-text-field v-model="form.qualification" label="Qualification" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.license_number" label="License #" /></v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.specialization" :items="specs" item-title="name" item-value="id" label="Specialization" />
          </v-col>
          <v-col cols="12" sm="6"><v-text-field v-model.number="form.experience_years" label="Experience (yrs)" type="number" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model.number="form.consultation_fee" label="Consultation fee" type="number" step="0.01" /></v-col>
          <v-col cols="12"><v-textarea v-model="form.bio" label="Bio" rows="3" auto-grow /></v-col>
        </v-row>
        <div class="d-flex justify-end mt-3">
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving" type="submit">Save Profile</v-btn>
        </div>
      </v-form>
    </v-card>
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const form = ref(null)
const specs = ref([])
const saving = ref(false)
const snack = reactive({ show: false, text: '', color: 'success' })
onMounted(async () => {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  specs.value = await safe('/doctors/specializations/')
  form.value = await $api.get('/doctors/me/').then(r => r.data).catch(() => ({ qualification: '', license_number: '', specialization: null, experience_years: 0, consultation_fee: 0, bio: '' }))
})
async function save() {
  saving.value = true
  try {
    await $api.put('/doctors/me/', form.value)
    snack.text = 'Profile saved'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to save'; snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}
</script>
