<template>
  <ResourceListPage
    :resource="r"
    title="My Prescriptions"
    icon="mdi-receipt"
    :headers="headers"
    :detail-path="(p) => `/prescriptions/${p.id}`"
    :edit-path="null"
    :deletable="false"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
    <template #cell-created_at="{ value }">{{ formatDate(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'
const r = useResource('/prescriptions/?mine=true')
const headers = [
  { title: 'Doctor', key: 'doctor_name' },
  { title: 'Diagnosis', key: 'diagnosis' },
  { title: 'Status', key: 'status' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 }
]
</script>
