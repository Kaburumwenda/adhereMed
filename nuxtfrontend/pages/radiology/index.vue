<template>
  <ResourceListPage
    :resource="r"
    title="Radiology"
    icon="mdi-radioactive"
    :headers="headers"
    create-path="/radiology/new"
    create-label="New Order"
    singular="radiology order"
    :detail-path="(p) => `/radiology/${p.id}/edit`"
    :edit-path="(p) => `/radiology/${p.id}/edit`"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/radiology/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Modality', key: 'modality' },
  { title: 'Body Part', key: 'body_part' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
