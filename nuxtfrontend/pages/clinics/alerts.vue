<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Alerts" subtitle="System alerts and notifications" icon="mdi-bell-ring" color="error">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-check-all" @click="markAllRead">Mark All Read</v-btn>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="r.loading.value" @click="r.list({ page_size: 1000 })">Refresh</v-btn>
      </template>
    </PageHeader>

    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="h-100">
          <v-card-text class="d-flex align-center ga-3 py-3">
            <v-avatar :color="k.color" size="40" rounded="lg" variant="tonal"><v-icon :icon="k.icon" :color="k.color" size="22" /></v-avatar>
            <div><div class="text-h6 font-weight-bold">{{ k.value }}</div><div class="text-caption text-medium-emphasis">{{ k.label }}</div></div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg">
      <v-card-text>
        <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify" placeholder="Search alerts…" variant="outlined" density="compact" hide-details clearable class="mb-3" />
        <v-data-table :headers="headers" :items="r.filtered.value" :loading="r.loading.value" density="compact" hover>
          <template #item.severity="{ value }"><v-chip :color="severityColor(value)" size="small" variant="tonal">{{ value }}</v-chip></template>
          <template #item.is_read="{ value }"><v-chip :color="value ? 'grey' : 'primary'" size="small" variant="tonal">{{ value ? 'Read' : 'Unread' }}</v-chip></template>
          <template #item.created_at="{ value }">{{ formatDateTime(value) }}</template>
          <template #item.actions="{ item }">
            <v-btn v-if="!item.is_read" icon="mdi-check" size="small" variant="text" @click="markRead(item)" />
          </template>
          <template #no-data>
            <div class="text-center pa-8">
              <v-icon size="64" color="grey-lighten-1">mdi-bell-off</v-icon>
              <div class="text-h6 mt-2">No alerts</div>
            </div>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
const r = useResource('/notifications/alerts/')
const { $api } = useNuxtApp()
onMounted(() => r.list({ page_size: 1000 }))

const headers = [
  { title: 'Title', key: 'title' },
  { title: 'Severity', key: 'severity' },
  { title: 'Message', key: 'message' },
  { title: 'Status', key: 'is_read' },
  { title: 'Date', key: 'created_at' },
  { title: 'Actions', key: 'actions', sortable: false },
]

const kpis = computed(() => [
  { label: 'Total', value: r.items.value.length, icon: 'mdi-bell', color: 'error' },
  { label: 'Unread', value: r.items.value.filter(a => !a.is_read).length, icon: 'mdi-bell-ring', color: 'warning' },
  { label: 'Critical', value: r.items.value.filter(a => a.severity === 'critical').length, icon: 'mdi-alert-circle', color: 'red' },
  { label: 'High', value: r.items.value.filter(a => a.severity === 'high').length, icon: 'mdi-alert', color: 'orange' },
])

function severityColor(s) { return { critical: 'red', high: 'orange', medium: 'warning', low: 'info' }[s] || 'grey' }

async function markRead(item) {
  try { await $api.patch(`/notifications/alerts/${item.id}/`, { is_read: true }); r.list({ page_size: 1000 }) } catch {}
}
async function markAllRead() {
  try {
    await Promise.all(r.items.value.filter(a => !a.is_read).map(a => $api.patch(`/notifications/alerts/${a.id}/`, { is_read: true })))
    r.list({ page_size: 1000 })
  } catch {}
}
</script>
