<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="`Hello Dr. ${auth.user?.last_name || ''}`"
      subtitle="Your practice at a glance."
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

const counts = reactive({ rx: 0, msg: 0 })

const stats = computed(() => [
  { title: 'My Prescriptions', value: counts.rx, icon: 'mdi-pill', color: 'primary' },
  { title: 'Messages', value: counts.msg, icon: 'mdi-chat', color: 'info' }
])

const actions = [
  { icon: 'mdi-account-circle', label: 'My Profile', to: '/doctor-profile' },
  { icon: 'mdi-note-edit', label: 'Write Prescription', to: '/prescriptions/new' },
  { icon: 'mdi-magnify', label: 'Doctor Directory', to: '/doctors' },
  { icon: 'mdi-chat', label: 'Messages', to: '/messages' }
]

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.count ?? r.data?.results?.length ?? (Array.isArray(r.data) ? r.data.length : 0)).catch(() => 0)
  counts.rx = await safe('/prescriptions/')
  counts.msg = await safe('/messaging/conversations/')
}
onMounted(load)
</script>
