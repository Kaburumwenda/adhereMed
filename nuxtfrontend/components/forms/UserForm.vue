<template>
  <ResourceFormPage :resource="r" :title="loadId ? 'Edit User' : 'New User'" icon="mdi-account" back-path="/superadmin/users" :load-id="loadId" :initial="initial" @saved="() => router.push('/superadmin/users')">
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.first_name" label="First name" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.last_name" label="Last name" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Email" type="email" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" /></v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.role" :items="roles" label="Role" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.tenant" :items="tenants" item-title="name" item-value="id" label="Tenant" clearable />
        </v-col>
        <v-col v-if="!loadId" cols="12"><v-text-field v-model="form.password" label="Password" type="password" :rules="req" /></v-col>
        <v-col cols="12"><v-switch v-model="form.is_active" label="Active" color="primary" inset /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/superadmin/users/')
const req = [v => !!v || 'Required']
const initial = { first_name: '', last_name: '', email: '', phone: '', role: 'tenant_admin', tenant: null, password: '', is_active: true }
const tenants = ref([])
const roles = [
  { title: 'Super Admin', value: 'super_admin' },
  { title: 'Tenant Admin', value: 'tenant_admin' },
  { title: 'Doctor', value: 'doctor' },
  { title: 'Clinical Officer', value: 'clinical_officer' },
  { title: 'Dentist', value: 'dentist' },
  { title: 'Nurse', value: 'nurse' },
  { title: 'Midwife', value: 'midwife' },
  { title: 'Lab Tech', value: 'lab_tech' },
  { title: 'Radiologist', value: 'radiologist' },
  { title: 'Pharmacist', value: 'pharmacist' },
  { title: 'Pharmacy Tech', value: 'pharmacy_tech' },
  { title: 'Cashier', value: 'cashier' },
  { title: 'Receptionist', value: 'receptionist' },
  { title: 'Homecare Admin', value: 'homecare_admin' },
  { title: 'Caregiver', value: 'caregiver' },
  { title: 'Patient', value: 'patient' },
]
onMounted(async () => { tenants.value = await $api.get('/superadmin/tenants/').then(r => r.data?.results || r.data || []).catch(() => []) })
</script>
