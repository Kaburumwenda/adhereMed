<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Triage' : 'New Triage'"
    icon="mdi-monitor-heart"
    back-path="/triage"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/triage')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.patient" :items="patients" item-title="user_email" item-value="id" label="Patient" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.priority" :items="['low','medium','high','urgent']" label="Priority" />
        </v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.blood_pressure" label="BP" placeholder="120/80" /></v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.pulse" label="Pulse" type="number" /></v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.temperature" label="Temperature (°C)" type="number" step="0.1" /></v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.respiratory_rate" label="Respiratory rate" type="number" /></v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.weight" label="Weight (kg)" type="number" step="0.1" /></v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.height" label="Height (cm)" type="number" /></v-col>
        <v-col cols="12" sm="3"><v-text-field v-model="form.oxygen_saturation" label="SpO₂ (%)" type="number" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/triage/')
const req = [v => !!v || 'Required']
const initial = { patient: null, priority: 'medium', blood_pressure: '', pulse: '', temperature: '', respiratory_rate: '', weight: '', height: '', oxygen_saturation: '', notes: '' }
const patients = ref([])
onMounted(async () => { patients.value = await $api.get('/patients/').then(r => r.data?.results || r.data || []).catch(() => []) })
</script>
