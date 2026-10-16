<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Alerts" subtitle="System alerts and notifications" icon="mdi-bell-ring" color="error">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-check-all" @click="markAllRead">Mark All Read</v-btn>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="r.loading.value" @click="load">Refresh</v-btn>
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
        <v-data-table :headers="headers" :items="filteredAlerts" :loading="r.loading.value" density="compact" hover>
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

// Notifications are served by the tenant-scoped NotificationViewSet
// (`/notifications/`). The previous endpoint (/notifications/alerts/) was never
// implemented, so this page always came up empty with 404s.
const r = useResource('/notifications/')
const { $api } = useNuxtApp()

async function load() {
  await r.list({ page_size: 1000 })
}
onMounted(load)

const headers = [
  { title: 'Title', key: 'title' },
  { title: 'Severity', key: 'severity' },
  { title: 'Message', key: 'message' },
  { title: 'Status', key: 'is_read' },
  { title: 'Date', key: 'created_at' },
  { title: 'Actions', key: 'actions', sortable: false },
]

// There is no `severity` column on Notification, so it is derived from the
// notification type plus the `data` payload written by the alert producers
// (e.g. `scan_alerts` sets data.kind = low_stock | expiring_soon | expired).
const SEVERITY_BY_KIND = {
  expired: 'critical',
  expiring_soon: 'high',
  low_stock: 'high',
}
const SEVERITY_BY_TYPE = {
  dose_missed: 'critical',
  escalation: 'critical',
  stock_alert: 'high',
  lab_result: 'medium',
  insurance_claim: 'medium',
  billing: 'medium',
  teleconsult: 'medium',
  appointment: 'low',
  prescription: 'low',
  home_collection: 'low',
  dose_reminder: 'low',
  caregiver_update: 'low',
  consent: 'low',
  system: 'low',
}

function severityOf(n) {
  return SEVERITY_BY_KIND[n?.data?.kind] || SEVERITY_BY_TYPE[n?.type] || 'low'
}

// Decorate the fetched rows so the severity column renders.
const alerts = computed(() => r.items.value.map(n => ({ ...n, severity: severityOf(n) })))

const filteredAlerts = computed(() => {
  const q = (r.search.value || '').toLowerCase()
  if (!q) return alerts.value
  return alerts.value.filter(a =>
    [a.title, a.message, a.type, a.severity].some(v => String(v ?? '').toLowerCase().includes(q))
  )
})

const kpis = computed(() => [
  { label: 'Total', value: alerts.value.length, icon: 'mdi-bell', color: 'error' },
  { label: 'Unread', value: alerts.value.filter(a => !a.is_read).length, icon: 'mdi-bell-ring', color: 'warning' },
  { label: 'Critical', value: alerts.value.filter(a => a.severity === 'critical').length, icon: 'mdi-alert-circle', color: 'red' },
  { label: 'High', value: alerts.value.filter(a => a.severity === 'high').length, icon: 'mdi-alert', color: 'orange' },
])

function severityColor(s) { return { critical: 'red', high: 'orange', medium: 'warning', low: 'info' }[s] || 'grey' }

async function markRead(item) {
  if (item.is_read) return
  try {
    await $api.post(`/notifications/${item.id}/mark_read/`)
    await load()
  } catch {}
}

async function markAllRead() {
  try {
    await $api.post('/notifications/mark_all_read/')
    await load()
  } catch {}
}
</script>
