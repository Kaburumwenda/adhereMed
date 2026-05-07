<template>
  <ResourceFormPage :resource="r" :title="loadId ? 'Edit Customer' : 'New Customer'" icon="mdi-account-group" back-path="/customers" :load-id="loadId" :initial="initial" @saved="() => router.push('/customers')">
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Email" type="email" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model.number="form.loyalty_points" label="Loyalty points" type="number" /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/pos/customers/')
const req = [v => !!v || 'Required']
const initial = { name: '', phone: '', email: '', loyalty_points: 0 }
</script>
