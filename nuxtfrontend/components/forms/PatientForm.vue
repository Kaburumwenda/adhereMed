<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Patient' : 'New Patient'"
    icon="mdi-account-plus"
    back-path="/patients"
    :load-id="loadId"
    :initial="initial"
    @saved="onSaved"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.first_name" label="First name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.last_name" label="Last name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Email" type="email" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.national_id" label="National ID" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.date_of_birth" label="Date of birth" type="date" /></v-col>
        <v-col cols="12" sm="6"><v-select v-model="form.gender" :items="['male','female','other']" label="Gender" /></v-col>
        <v-col cols="12" sm="6"><v-select v-model="form.blood_type" :items="['A+','A-','B+','B-','AB+','AB-','O+','O-']" label="Blood type" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.address" label="Address" rows="2" auto-grow /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.emergency_contact_name" label="Emergency contact name" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.emergency_contact_phone" label="Emergency contact phone" /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const route = useRoute()
const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/patients/')
const req = [v => !!v || 'Required']

const initial = {
  first_name: '', last_name: '', email: '', phone: '',
  national_id: '', date_of_birth: '', gender: '', blood_type: '',
  address: '', emergency_contact_name: '', emergency_contact_phone: ''
}

function onSaved(p) {
  router.push(p?.id ? `/patients/${p.id}` : '/patients')
}
</script>
