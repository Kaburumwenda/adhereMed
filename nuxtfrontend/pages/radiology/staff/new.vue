<template>
  <v-container fluid class="pa-3 pa-md-5">
    <h1 class="text-h5 font-weight-bold mb-4"><v-icon class="mr-1">mdi-account-plus</v-icon>Add Staff</h1>
    <v-form ref="formRef" @submit.prevent="submit">
      <v-card rounded="lg" class="pa-5 mb-4" border>
        <v-row dense>
          <v-col cols="12" sm="6"><v-text-field v-model="form.first_name" label="First Name *" :rules="req" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.last_name" label="Last Name *" :rules="req" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Email *" type="email" :rules="req" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.role" :items="roles" label="Role *" :rules="req" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.password" label="Password *" type="password" :rules="req" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" variant="outlined" density="compact" /></v-col>
        </v-row>
      </v-card>
      <div class="d-flex justify-end" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" to="/radiology/staff">Cancel</v-btn>
        <v-btn type="submit" color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving">Create</v-btn>
      </div>
    </v-form>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()
const formRef = ref(null)
const saving = ref(false)
const req = [v => !!v || 'Required']
const roles = ['radiologist', 'lab_tech', 'radiology_admin', 'receptionist', 'admin']
const form = reactive({ first_name: '', last_name: '', email: '', role: '', password: '', phone: '' })

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await $api.post('/accounts/users/', form)
    router.push('/radiology/staff')
  } catch (e) { console.error(e) }
  saving.value = false
}
</script>
