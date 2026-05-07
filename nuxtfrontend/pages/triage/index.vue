<template>
  <ResourceListPage
    :resource="r"
    title="Triage"
    icon="mdi-monitor-heart"
    :headers="headers"
    create-path="/triage/new"
    create-label="New Triage"
    singular="triage record"
    :detail-path="(p) => `/triage/${p.id}/edit`"
    :edit-path="(p) => `/triage/${p.id}/edit`"
  >
    <template #cell-priority="{ value }"><StatusChip :status="value" /></template>
    <template #cell-created_at="{ value }">{{ formatDateTime(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'
const r = useResource('/triage/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Priority', key: 'priority' },
  { title: 'BP', key: 'blood_pressure' },
  { title: 'Pulse', key: 'pulse' },
  { title: 'Temp', key: 'temperature' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
