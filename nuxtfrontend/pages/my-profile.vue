<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="My Profile" icon="mdi-account-circle" subtitle="Update your personal information" />
    <v-card rounded="lg" class="pa-4">
      <v-form v-if="form" @submit.prevent="save">
        <v-row dense>
          <v-col cols="12" sm="6"><v-text-field v-model="form.first_name" label="First name" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.last_name" label="Last name" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Email" type="email" disabled /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" /></v-col>
        </v-row>
        <div class="d-flex justify-end mt-3">
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving" type="submit">Save</v-btn>
        </div>
      </v-form>
    </v-card>
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $api } = useNuxtApp()
const form = ref({ ...(auth.user || {}) })
const saving = ref(false)
const snack = reactive({ show: false, text: '', color: 'success' })
async function save() {
  saving.value = true
  try {
    const res = await $api.patch('/accounts/me/', form.value)
    auth.user = res.data
    snack.text = 'Saved'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed'; snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}
</script>
