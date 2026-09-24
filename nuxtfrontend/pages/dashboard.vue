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
import HomecareDashboard from '~/components/dashboards/HomecareDashboard.vue'
import CaregiverDashboard from '~/components/dashboards/CaregiverDashboard.vue'
import ClinicDashboard from '~/components/dashboards/ClinicDashboard.vue'
import InventoryDashboard from '~/components/dashboards/InventoryDashboard.vue'
import GenericDashboard from '~/components/dashboards/GenericDashboard.vue'

const auth = useAuthStore()

// Lab tenants use the full /lab dashboard.
if (process.client && auth.tenantType === 'lab' && !['patient'].includes(auth.role)) {
  navigateTo('/lab', { replace: true })
}

// Pharmacy tenants use the /pharmacy dashboard.
if (process.client && auth.tenantType === 'pharmacy' && !['patient'].includes(auth.role)) {
  navigateTo('/pharmacy', { replace: true })
}

// Hospital tenants use the /hos dashboard.
if (process.client && auth.tenantType === 'hospital' && !['patient'].includes(auth.role)) {
  navigateTo('/hos', { replace: true })
}

// Clinic tenants use the /clinics dashboard.
if (process.client && auth.tenantType === 'clinic' && !['patient'].includes(auth.role)) {
  navigateTo('/clinics', { replace: true })
}

// Inventory / warehouse tenants use the /ims dashboard.
if (process.client && auth.tenantType === 'inventory' && !['patient'].includes(auth.role)) {
  navigateTo('/ims', { replace: true })
}

const component = computed(() => {
  if (auth.role === 'super_admin') {
    navigateTo('/superadmin')
    return GenericDashboard
  }
  if (auth.role === 'patient') return PatientDashboard
  if (auth.tenantType === 'homecare' && auth.role === 'caregiver') return CaregiverDashboard
  if (auth.tenantType === 'homecare') return HomecareDashboard
  if (['doctor', 'clinical_officer', 'dentist'].includes(auth.role)) return DoctorDashboard
  if (auth.tenantType === 'hospital') return HospitalDashboard
  if (auth.tenantType === 'clinic') return ClinicDashboard
  if (auth.tenantType === 'pharmacy') return PharmacyDashboard
  if (auth.tenantType === 'lab') return LabDashboard
  if (auth.tenantType === 'inventory') return InventoryDashboard
  return GenericDashboard
})
</script>
