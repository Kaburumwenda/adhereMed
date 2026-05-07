<template>
  <ResourceFormPage :resource="r" :title="loadId ? 'Edit Branch' : 'New Branch'" icon="mdi-source-branch" back-path="/branches" :load-id="loadId" :initial="initial" @saved="() => router.push('/branches')">
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.address" label="Address" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/pharmacy_profile/branches/')
const req = [v => !!v || 'Required']
const initial = { name: '', phone: '', address: '' }
</script>
