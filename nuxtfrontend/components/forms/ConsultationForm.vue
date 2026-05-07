<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Consultation' : 'New Consultation'"
    icon="mdi-medical-bag"
    back-path="/consultations"
    :load-id="loadId"
    :initial="initial"
    @saved="(p) => router.push(p?.id ? `/consultations/${p.id}` : '/consultations')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.patient" :items="patients" item-title="user_email" item-value="id" label="Patient" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.doctor" :items="doctors" item-title="full_name" item-value="id" label="Doctor" />
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.chief_complaint" label="Chief complaint" rows="2" auto-grow :rules="req" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.history" label="History" rows="3" auto-grow /></v-col>
        <v-col cols="12"><v-textarea v-model="form.examination" label="Examination" rows="3" auto-grow /></v-col>
        <v-col cols="12"><v-textarea v-model="form.diagnosis" label="Diagnosis" rows="2" auto-grow /></v-col>
        <v-col cols="12"><v-textarea v-model="form.treatment_plan" label="Treatment plan" rows="3" auto-grow /></v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.status" :items="['draft','active','completed','cancelled']" label="Status" />
        </v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/consultations/')
const req = [v => !!v || 'Required']
const initial = { patient: null, doctor: null, chief_complaint: '', history: '', examination: '', diagnosis: '', treatment_plan: '', status: 'active' }
const patients = ref([]); const doctors = ref([])
async function loadOptions() {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  patients.value = await safe('/patients/')
  doctors.value = await safe('/accounts/staff/?role=doctor')
}
onMounted(loadOptions)
</script>
