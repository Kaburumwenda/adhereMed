<script setup>
// New Consultation page — creates a draft and redirects to the doctor workspace
const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const loading = ref(true)
const error = ref(null)

onMounted(async () => {
  const patientId = route.query.patient
  const triageId = route.query.triage
  const appointmentId = route.query.appointment
  if (!patientId && !triageId) {
    router.replace('/clinics/consultations')
    return
  }
  try {
    const payload = {
      patient: patientId ? Number(patientId) : null,
      triage: triageId ? Number(triageId) : null,
      appointment: appointmentId ? Number(appointmentId) : null,
      doctor: auth.user?.id,
      status: 'draft',
      draft_owner: auth.user?.id,
      chief_complaint: '',
    }
    // If triage provided and no patient, fetch patient from triage
    if (triageId && !patientId) {
      const { data: t } = await $api.get(`/triage/${triageId}/`)
      payload.patient = t.patient
      payload.chief_complaint = t.chief_complaint || ''
      payload.vital_signs = t.vital_signs || {}
    }
    const { data } = await $api.post('/consultations/', payload)
    router.replace(`/clinics/consultations/workspace/${data.id}`)
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to start consultation'
    loading.value = false
  }
})
</script>

<template>
  <v-container fluid class="d-flex align-center justify-center" style="min-height: 50vh">
    <div v-if="loading" class="text-center">
      <v-progress-circular indeterminate color="success" size="48" />
      <div class="text-body-1 mt-3">Opening doctor workspace…</div>
    </div>
    <v-alert v-if="error" type="error" variant="tonal" class="ma-4">
      {{ error }}
      <v-btn to="/clinics/consultations" class="mt-2" variant="text">Back to Consultations</v-btn>
    </v-alert>
  </v-container>
</template>


<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
