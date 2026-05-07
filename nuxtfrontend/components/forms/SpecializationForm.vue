<template>
  <ResourceFormPage :resource="r" :title="loadId ? 'Edit Specialization' : 'New Specialization'" icon="mdi-stethoscope" back-path="/specializations" :load-id="loadId" :initial="initial" @saved="() => router.push('/specializations')">
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.description" label="Description" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/doctors/specializations/')
const req = [v => !!v || 'Required']
const initial = { name: '', description: '' }
</script>
