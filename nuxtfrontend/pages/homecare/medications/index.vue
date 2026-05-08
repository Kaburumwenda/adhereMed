<template>
  <ResourceListPage
    title="Medication schedules"
    subtitle="Active medication regimens"
    icon="mdi-pill"
    :resource="resource"
    :headers="headers"
    singular="schedule"
    empty-icon="mdi-pill-off"
    empty-title="No medication schedules"
  >
    <template #cell-times="{ item }">
      <v-chip v-for="t in (item.times_of_day || [])" :key="t" size="x-small" class="mr-1" color="teal" variant="tonal">{{ t }}</v-chip>
    </template>
    <template #cell-is_active="{ item }"><StatusChip :status="item.is_active ? 'active' : 'closed'" /></template>
    <template #actions="{ item }">
      <v-btn size="small" color="teal" variant="text" prepend-icon="mdi-calendar-plus"
             @click="generate(item.id)">Generate doses</v-btn>
    </template>
  </ResourceListPage>
</template>
<script setup>
const { $api } = useNuxtApp()
const resource = useResource('/homecare/medication-schedules/')
const headers = [
  { title: 'Medication', key: 'medication_name' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Dose', key: 'dose' },
  { title: 'Times', key: 'times' },
  { title: 'Active', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
async function generate(id) {
  await $api.post(`/homecare/medication-schedules/${id}/generate_doses/`, { days_ahead: 7 })
  resource.list()
}
</script>
