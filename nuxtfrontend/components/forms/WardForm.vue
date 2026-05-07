<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Ward' : 'New Ward'"
    icon="mdi-bed"
    back-path="/wards"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/wards')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.total_beds" label="Total beds" type="number" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.description" label="Description" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/wards/wards/')
const req = [v => !!v || 'Required']
const initial = { name: '', total_beds: 0, description: '' }
</script>
