<template>
  <ResourceListPage
    title="Treatment plans"
    subtitle="Care plans linked to treatment programmes"
    icon="mdi-clipboard-text"
    :resource="resource"
    :headers="headers"
    singular="plan"
    empty-icon="mdi-clipboard-outline"
    empty-title="No treatment plans yet"
  >
    <template #cell-status="{ item }"><StatusChip :status="item.status" /></template>
  </ResourceListPage>
</template>
<script setup>
const resource = useResource('/homecare/treatment-plans/')
const headers = [
  { title: 'Title', key: 'title' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Diagnosis', key: 'diagnosis' },
  { title: 'Start', key: 'start_date' },
  { title: 'Medications', key: 'medication_count' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
</script>
