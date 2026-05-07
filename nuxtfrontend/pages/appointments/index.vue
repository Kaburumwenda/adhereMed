<template>
  <ResourceListPage
    :resource="r"
    title="Appointments"
    icon="mdi-calendar"
    :headers="headers"
    create-path="/appointments/new"
    create-label="New Appointment"
    singular="appointment"
    :detail-path="(p) => `/appointments/${p.id}`"
    :edit-path="(p) => `/appointments/${p.id}/edit`"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
    <template #cell-appointment_date="{ value }">{{ formatDate(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const r = useResource('/appointments/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Doctor / Staff', key: 'staff_name' },
  { title: 'Department', key: 'department_name' },
  { title: 'Date', key: 'appointment_date' },
  { title: 'Time', key: 'appointment_time' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
