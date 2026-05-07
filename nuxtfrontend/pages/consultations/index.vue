<template>
  <ResourceListPage
    :resource="r"
    title="Consultations"
    icon="mdi-medical-bag"
    :headers="headers"
    create-path="/consultations/new"
    create-label="New Consultation"
    singular="consultation"
    :detail-path="(p) => `/consultations/${p.id}`"
    :edit-path="(p) => `/consultations/${p.id}/edit`"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
    <template #cell-created_at="{ value }">{{ formatDateTime(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'

const r = useResource('/consultations/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Doctor', key: 'doctor_name' },
  { title: 'Chief Complaint', key: 'chief_complaint' },
  { title: 'Status', key: 'status' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
