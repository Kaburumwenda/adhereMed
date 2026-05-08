<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Escalations" icon="mdi-alert-octagram"
                subtitle="Patients flagged for clinical attention.">
      <template #actions>
        <v-btn color="teal" variant="tonal" rounded="lg" prepend-icon="mdi-radar"
               class="text-none" :loading="evaluating" @click="evaluate">Evaluate now</v-btn>
      </template>
    </PageHeader>
    <v-card rounded="xl" class="pa-4">
      <v-data-table :headers="headers" :items="items" :loading="loading" item-value="id">
        <template #[`item.severity`]="{ item }"><StatusChip :status="item.severity" /></template>
        <template #[`item.status`]="{ item }"><StatusChip :status="item.status" /></template>
        <template #[`item.actions`]="{ item }">
          <v-btn v-if="item.status === 'open'" size="small" variant="text" color="info"
                 prepend-icon="mdi-eye-check" @click="acknowledge(item)">Acknowledge</v-btn>
          <v-btn v-if="item.status !== 'resolved'" size="small" variant="text" color="success"
                 prepend-icon="mdi-check-decagram" @click="resolveDialog(item)">Resolve</v-btn>
        </template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="dialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title>Resolve escalation</v-card-title>
        <v-card-text>
          <v-textarea v-model="resolution" label="Resolution notes" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="success" @click="resolve">Resolve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>
<script setup>
const { $api } = useNuxtApp()
const items = ref([])
const loading = ref(false)
const evaluating = ref(false)
const dialog = ref(false)
const target = ref(null)
const resolution = ref('')
const headers = [
  { title: 'Triggered', key: 'triggered_at' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Reason', key: 'reason' },
  { title: 'Severity', key: 'severity' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/escalations/')
    items.value = data?.results || data || []
  } finally { loading.value = false }
}
async function evaluate() {
  evaluating.value = true
  try { await $api.post('/homecare/escalations/evaluate_now/'); load() }
  finally { evaluating.value = false }
}
async function acknowledge(e) { await $api.post(`/homecare/escalations/${e.id}/acknowledge/`); load() }
function resolveDialog(e) { target.value = e; resolution.value = ''; dialog.value = true }
async function resolve() {
  await $api.post(`/homecare/escalations/${target.value.id}/resolve/`, { notes: resolution.value })
  dialog.value = false
  load()
}
onMounted(load)
</script>
