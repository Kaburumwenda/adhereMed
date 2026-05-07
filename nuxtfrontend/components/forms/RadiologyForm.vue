<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Order' : 'New Radiology Order'"
    icon="mdi-radioactive"
    back-path="/radiology"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/radiology')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.patient" :items="patients" item-title="user_email" item-value="id" label="Patient" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.modality" :items="['X-Ray','CT','MRI','Ultrasound','Mammography']" label="Modality" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.body_part" label="Body part" /></v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.status" :items="['ordered','scheduled','completed','cancelled']" label="Status" />
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.indication" label="Clinical indication" rows="2" auto-grow /></v-col>
        <v-col cols="12"><v-textarea v-model="form.findings" label="Findings" rows="3" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/radiology/')
const req = [v => !!v || 'Required']
const initial = { patient: null, modality: '', body_part: '', status: 'ordered', indication: '', findings: '' }
const patients = ref([])
onMounted(async () => { patients.value = await $api.get('/patients/').then(r => r.data?.results || r.data || []).catch(() => []) })
</script>
