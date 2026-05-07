<template>
  <ResourceListPage
    :resource="r"
    title="Patients"
    icon="mdi-account-multiple"
    :headers="headers"
    create-path="/patients/new"
    create-label="New Patient"
    singular="patient"
    :detail-path="(p) => `/patients/${p.id}`"
    :edit-path="(p) => `/patients/${p.id}/edit`"
  >
    <template #cell-gender="{ value }">
      <v-chip size="small" variant="tonal" :color="value === 'male' ? 'info' : value === 'female' ? 'pink' : 'grey'" class="text-capitalize">
        {{ value || '—' }}
      </v-chip>
    </template>
    <template #cell-date_of_birth="{ value }">{{ formatDate(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const r = useResource('/patients/')
const headers = [
  { title: 'Patient #', key: 'patient_number', width: 130 },
  { title: 'Name', key: 'user_email' },
  { title: 'National ID', key: 'national_id' },
  { title: 'DOB', key: 'date_of_birth' },
  { title: 'Gender', key: 'gender' },
  { title: 'Blood', key: 'blood_type', width: 80 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
