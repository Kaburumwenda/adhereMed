<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="`Welcome back, ${auth.user?.first_name || 'there'} 👋`"
      subtitle="Here's today's laboratory activity."
    />
    <StatGrid :stats="stats" />

    <v-row class="mt-2">
      <v-col cols="12">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Quick actions</h3>
          <v-row dense>
            <v-col cols="12" sm="6" md="4">
              <v-btn block variant="tonal" rounded="lg" class="text-none justify-start" prepend-icon="mdi-clock-alert" to="/lab-exchange">Lab Requests</v-btn>
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

const counts = reactive({ pending: 0, completed: 0 })

const stats = computed(() => [
  { title: 'Pending Requests', value: counts.pending, icon: 'mdi-clock-outline', color: 'warning' },
  { title: 'Completed Today', value: counts.completed, icon: 'mdi-check-circle', color: 'success' }
])

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.count ?? r.data?.results?.length ?? (Array.isArray(r.data) ? r.data.length : 0)).catch(() => 0)
  counts.pending = await safe('/lab/orders/?status=ordered')
  counts.completed = await safe('/lab/orders/?status=resulted')
}
onMounted(load)
</script>
