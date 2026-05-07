<template>
  <component :is="component" />
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import HospitalDashboard from '~/components/dashboards/HospitalDashboard.vue'
import PharmacyDashboard from '~/components/dashboards/PharmacyDashboard.vue'
import LabDashboard from '~/components/dashboards/LabDashboard.vue'
import DoctorDashboard from '~/components/dashboards/DoctorDashboard.vue'
import PatientDashboard from '~/components/dashboards/PatientDashboard.vue'
import GenericDashboard from '~/components/dashboards/GenericDashboard.vue'

const auth = useAuthStore()

// Auto-enter fullscreen when /dashboard loads.
// Browsers require a user gesture, so we try immediately and fall back to
// triggering on the first click/keypress if that's blocked.
onMounted(() => {
  if (typeof document === 'undefined') return
  const enter = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen?.().catch(() => {})
    }
  }
  enter()
  const onGesture = () => {
    enter()
    window.removeEventListener('click', onGesture)
    window.removeEventListener('keydown', onGesture)
  }
  if (!document.fullscreenElement) {
    window.addEventListener('click', onGesture, { once: true })
    window.addEventListener('keydown', onGesture, { once: true })
  }
})

const component = computed(() => {
  if (auth.role === 'super_admin') {
    navigateTo('/superadmin')
    return GenericDashboard
  }
  if (auth.role === 'patient') return PatientDashboard
  if (['doctor', 'clinical_officer', 'dentist'].includes(auth.role)) return DoctorDashboard
  if (auth.tenantType === 'hospital') return HospitalDashboard
  if (auth.tenantType === 'pharmacy') return PharmacyDashboard
  if (auth.tenantType === 'lab') return LabDashboard
  return GenericDashboard
})
</script>
