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
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $api } = useNuxtApp()

const counts = reactive({ rx: 0, orders: 0, pharmacies: 0 })

const stats = computed(() => [
  { title: 'My Prescriptions', value: counts.rx, icon: 'mdi-receipt', color: 'primary' },
  { title: 'My Orders', value: counts.orders, icon: 'mdi-receipt-text', color: 'info' },
  { title: 'Pharmacies Nearby', value: counts.pharmacies, icon: 'mdi-pharmacy', color: 'success' }
])

const actions = [
  { icon: 'mdi-account-circle', label: 'My Profile', to: '/my-profile' },
  { icon: 'mdi-receipt', label: 'My Prescriptions', to: '/my-prescriptions' },
  { icon: 'mdi-storefront', label: 'Browse Pharmacies', to: '/pharmacy-store' },
  { icon: 'mdi-receipt-text', label: 'My Orders', to: '/pharmacy-store/orders' },
  { icon: 'mdi-magnify', label: 'Find Doctors', to: '/doctors' },
  { icon: 'mdi-chat', label: 'Messages', to: '/messages' }
]

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.count ?? r.data?.results?.length ?? (Array.isArray(r.data) ? r.data.length : 0)).catch(() => 0)
  counts.rx = await safe('/prescriptions/')
  counts.orders = await safe('/exchange/orders/')
  counts.pharmacies = await safe('/exchange/pharmacies/')
}
onMounted(load)
</script>
