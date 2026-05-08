<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Today's doses" icon="mdi-pill-multiple" :subtitle="today" />
    <v-card rounded="xl" class="pa-4">
      <div class="d-flex flex-wrap ga-2 mb-3">
        <v-chip v-for="s in summary" :key="s.label" :color="s.color" variant="tonal">
          {{ s.label }}: {{ s.value }}
        </v-chip>
      </div>
      <v-list>
        <v-list-item v-for="d in items" :key="d.id"
          :title="`${d.medication_name} · ${d.dose}`"
          :subtitle="`${d.patient_name} · ${formatTime(d.scheduled_at)}`">
          <template #prepend>
            <v-avatar :color="dotColor(d.status)" size="36">
              <v-icon icon="mdi-pill" color="white" />
            </v-avatar>
          </template>
          <template #append>
            <div class="d-flex ga-1">
              <template v-if="d.status === 'pending'">
                <v-btn size="small" color="success" variant="tonal" prepend-icon="mdi-check"
                       @click="mark(d.id, 'mark_taken')">Taken</v-btn>
                <v-btn size="small" color="error" variant="tonal" prepend-icon="mdi-close"
                       @click="mark(d.id, 'mark_missed')">Missed</v-btn>
                <v-btn size="small" variant="text" @click="mark(d.id, 'mark_skipped')">Skip</v-btn>
              </template>
              <StatusChip v-else :status="d.status" />
            </div>
          </template>
        </v-list-item>
        <EmptyState v-if="!items.length" icon="mdi-pill-off" title="No doses today" />
      </v-list>
    </v-card>
  </v-container>
</template>
<script setup>
const { $api } = useNuxtApp()
const items = ref([])
const today = computed(() => new Date().toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' }))
const summary = computed(() => {
  const t = items.value
  const c = (s) => t.filter(x => x.status === s).length
  return [
    { label: 'Total', value: t.length, color: 'primary' },
    { label: 'Taken', value: c('taken'), color: 'success' },
    { label: 'Pending', value: c('pending'), color: 'info' },
    { label: 'Missed', value: c('missed'), color: 'error' },
    { label: 'Skipped', value: c('skipped'), color: 'grey' }
  ]
})
function dotColor(s) { return { taken: 'success', missed: 'error', skipped: 'grey', pending: 'info' }[s] || 'grey' }
function formatTime(iso) { return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '' }
async function load() {
  const { data } = await $api.get('/homecare/doses/today/')
  items.value = data || []
}
async function mark(id, verb) {
  await $api.post(`/homecare/doses/${id}/${verb}/`)
  load()
}
onMounted(load)
</script>
