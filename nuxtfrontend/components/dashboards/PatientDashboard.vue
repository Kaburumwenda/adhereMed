<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="`Welcome, ${auth.user?.first_name || 'there'}`"
      subtitle="Manage your health, prescriptions and orders."
    />
    <StatGrid :stats="stats" />

    <v-row class="mt-2">
      <v-col cols="12">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Quick actions</h3>
          <v-row dense>
            <v-col v-for="a in actions" :key="a.label" cols="12" sm="6" md="4">
              <v-btn block variant="tonal" rounded="lg" class="text-none justify-start" :prepend-icon="a.icon" :to="a.to">{{ a.label }}</v-btn>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { computed, reactive, onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $api } = useNuxtApp()

const counts = reactive({ rx: 0, orders: 0, pharmacies: 0, labs: 0, labReports: 0 })

const stats = computed(() => [
  { title: 'My Prescriptions', value: counts.rx, icon: 'mdi-receipt', color: 'primary' },
  { title: 'My Lab Tests', value: counts.labs, icon: 'mdi-flask-outline', color: 'warning' },
  { title: 'Lab Reports Ready', value: counts.labReports, icon: 'mdi-file-check', color: 'success' },
  { title: 'My Orders', value: counts.orders, icon: 'mdi-receipt-text', color: 'info' }
])

const actions = computed(() => {
  const p = auth.tenantType === 'hospital' ? '/hos' : auth.tenantType === 'clinic' ? '/clinics' : ''
  return [
    { icon: 'mdi-account-circle', label: 'My Profile', to: `${p}/my-profile` },
    { icon: 'mdi-receipt', label: 'My Prescriptions', to: `${p}/my-prescriptions` },
    { icon: 'mdi-flask-outline', label: 'My Lab Tests', to: `${p}/my-lab-results` },
    { icon: 'mdi-storefront', label: 'Browse Pharmacies', to: '/pharmacy-store' },
    { icon: 'mdi-receipt-text', label: 'My Orders', to: '/pharmacy-store/orders' },
    { icon: 'mdi-magnify', label: 'Find Doctors', to: `${p}/doctors` },
    { icon: 'mdi-chat', label: 'Messages', to: `${p}/messages` }
  ]
})

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.count ?? r.data?.results?.length ?? (Array.isArray(r.data) ? r.data.length : 0)).catch(() => 0)
  counts.rx = await safe('/prescriptions/?mine=true')
  counts.orders = await safe('/exchange/orders/')
  counts.pharmacies = await safe('/exchange/pharmacies/')

  // Lab tests are shared by the clinic through the exchange app — the patient
  // reads its own mirrored rows (results only appear once verified).
  try {
    const { data } = await $api.get('/exchange/lab-records/summary/')
    counts.labs = data?.total ?? 0
    counts.labReports = data?.released ?? 0
  } catch {
    counts.labs = 0
    counts.labReports = 0
  }
}
onMounted(load)
</script>
