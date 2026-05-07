<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="`Welcome back, ${auth.user?.first_name || 'there'} 👋`"
      subtitle="Here's what's happening at your hospital today."
    />
    <StatGrid :stats="stats" />

    <v-row class="mt-2">
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Quick actions</h3>
          <v-row dense>
            <v-col v-for="a in actions" :key="a.label" cols="12" sm="6" md="4">
              <v-btn block variant="tonal" rounded="lg" class="text-none justify-start" :prepend-icon="a.icon" :to="a.to">
                {{ a.label }}
              </v-btn>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Today</h3>
          <v-list density="compact">
            <v-list-item prepend-icon="mdi-calendar-today" title="Appointments" :subtitle="String(counts.appointments)" />
            <v-list-item prepend-icon="mdi-medical-bag" title="Consultations" :subtitle="String(counts.consultations)" />
            <v-list-item prepend-icon="mdi-monitor-heart" title="Triage" :subtitle="String(counts.triage)" />
          </v-list>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $api } = useNuxtApp()

const counts = reactive({ patients: 0, appointments: 0, consultations: 0, triage: 0, beds: 0 })

const stats = computed(() => [
  { title: 'Patients', value: counts.patients, icon: 'mdi-account-multiple', color: 'primary' },
  { title: "Today's Appointments", value: counts.appointments, icon: 'mdi-calendar', color: 'info' },
  { title: 'Consultations', value: counts.consultations, icon: 'mdi-medical-bag', color: 'success' },
  { title: 'Beds Available', value: counts.beds, icon: 'mdi-bed', color: 'warning' }
])

const actions = [
  { icon: 'mdi-account-plus', label: 'New Patient', to: '/patients/new' },
  { icon: 'mdi-calendar-plus', label: 'New Appointment', to: '/appointments/new' },
  { icon: 'mdi-medical-bag', label: 'New Consultation', to: '/consultations/new' },
  { icon: 'mdi-pill', label: 'Write Prescription', to: '/prescriptions/new' },
  { icon: 'mdi-microscope', label: 'Order Lab Test', to: '/lab-orders' },
  { icon: 'mdi-receipt-text', label: 'Create Invoice', to: '/invoices' }
]

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.count ?? r.data?.results?.length ?? (Array.isArray(r.data) ? r.data.length : 0)).catch(() => 0)
  counts.patients = await safe('/patients/')
  counts.appointments = await safe('/appointments/')
  counts.consultations = await safe('/consultations/')
  counts.triage = await safe('/triage/')
  counts.beds = await safe('/wards/wards/')
}
onMounted(load)
</script>
