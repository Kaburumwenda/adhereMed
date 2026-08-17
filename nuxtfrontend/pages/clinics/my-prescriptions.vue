<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="My Prescriptions" subtitle="Your medication history" icon="mdi-pill" color="purple">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="r.loading.value" @click="loadList">Refresh</v-btn>
      </template>
    </PageHeader>

    <v-card rounded="lg">
      <v-card-text>
        <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify" placeholder="Search prescriptions…" variant="outlined" density="compact" hide-details clearable class="mb-3" />
        <v-data-table :headers="headers" :items="r.filtered.value" :loading="r.loading.value" density="compact" hover @click:row="goDetail">
          <template #item.status="{ value }"><v-chip :color="statusColor(value)" size="small" variant="tonal">{{ value }}</v-chip></template>
          <template #item.created_at="{ value }">{{ formatDate(value) }}</template>
          <template #no-data>
            <div class="text-center pa-8">
              <v-icon size="64" color="grey-lighten-1">mdi-pill</v-icon>
              <div class="text-h6 mt-2">No prescriptions found</div>
            </div>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatDate } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const r = useResource('/prescriptions/')

const headers = [
  { title: 'Date', key: 'created_at' },
  { title: 'Doctor', key: 'doctor_name' },
  { title: 'Medications', key: 'medication_count' },
  { title: 'Status', key: 'status' },
  { title: 'Notes', key: 'notes' },
]

onMounted(() => loadList())
function loadList() {
  // My prescriptions: filter by the logged-in patient (if applicable) or all shared with me
  r.list({ page_size: 1000 })
}

function statusColor(s) { return { pending: 'info', dispensed: 'success', cancelled: 'error', expired: 'warning' }[s] || 'grey' }
function goDetail(_, item) { navigateTo(`/clinics/prescriptions/${item.id}`) }
</script>
