<template>
  <ResourceListPage
    :resource="r"
    title="Prescriptions"
    icon="mdi-pill"
    :headers="headers"
    create-path="/prescriptions/new"
    create-label="Write Prescription"
    singular="prescription"
    :detail-path="(p) => `/prescriptions/${p.id}`"
    :edit-path="(p) => `/prescriptions/${p.id}/edit`"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
    <template #cell-created_at="{ value }">{{ formatDate(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'
const r = useResource('/prescriptions/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Doctor', key: 'doctor_name' },
  { title: 'Diagnosis', key: 'diagnosis' },
  { title: 'Status', key: 'status' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
