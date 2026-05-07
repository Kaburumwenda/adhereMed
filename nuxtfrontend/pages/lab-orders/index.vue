<template>
  <ResourceListPage
    :resource="r"
    title="Lab Orders"
    icon="mdi-microscope"
    :headers="headers"
    create-path="/lab-orders/new"
    create-label="Order Lab Test"
    singular="lab order"
    :detail-path="(p) => `/lab-orders/${p.id}`"
    :edit-path="(p) => `/lab-orders/${p.id}/edit`"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
    <template #cell-priority="{ value }"><StatusChip :status="value" /></template>
    <template #cell-ordered_at="{ value }">{{ formatDateTime(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'
const r = useResource('/lab/orders/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Test', key: 'test_name' },
  { title: 'Priority', key: 'priority' },
  { title: 'Status', key: 'status' },
  { title: 'Ordered', key: 'ordered_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
