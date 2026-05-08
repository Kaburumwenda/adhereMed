<template>
  <ResourceListPage
    title="Patients"
    subtitle="Enrolled homecare patients"
    icon="mdi-account-multiple"
    :resource="resource"
    :headers="headers"
    create-path="/homecare/patients/new"
    create-label="Enrol patient"
    :detail-path="(p) => `/homecare/patients/${p.id}`"
    :edit-path="(p) => `/homecare/patients/${p.id}/edit`"
    singular="patient"
    empty-icon="mdi-account-multiple-outline"
    empty-title="No patients yet"
    empty-message="Enrol your first patient to get started."
  >
    <template #cell-patient_name="{ item }">
      <div class="d-flex align-center">
        <v-avatar size="32" color="teal" variant="tonal" class="mr-2">
          <v-icon icon="mdi-account" />
        </v-avatar>
        <div>
          <div class="font-weight-medium">{{ item.patient_name }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.medical_record_number }}</div>
        </div>
      </div>
    </template>
    <template #cell-risk_level="{ item }">
      <StatusChip :status="item.risk_level" />
    </template>
    <template #cell-adherence_rate="{ item }">
      <span :class="adherenceClass(item.adherence_rate)">
        {{ item.adherence_rate != null ? item.adherence_rate + '%' : '—' }}
      </span>
    </template>
    <template #cell-is_active="{ item }">
      <StatusChip :status="item.is_active ? 'active' : 'closed'" />
    </template>
  </ResourceListPage>
</template>

<script setup>
const resource = useResource('/homecare/patients/')
const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Diagnosis', key: 'primary_diagnosis' },
  { title: 'Caregiver', key: 'caregiver_name', sortable: false },
  { title: 'Risk', key: 'risk_level' },
  { title: 'Adherence', key: 'adherence_rate', sortable: false },
  { title: 'Status', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
function adherenceClass(rate) {
  if (rate == null) return ''
  if (rate >= 85) return 'text-success font-weight-bold'
  if (rate >= 60) return 'text-warning font-weight-bold'
  return 'text-error font-weight-bold'
}
</script>
