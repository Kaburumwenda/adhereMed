<template>
  <ResourceDetailPage
    :resource="r"
    title="Consultation"
    icon="mdi-medical-bag"
    back-path="/consultations"
    :edit-path="`/consultations/${id}/edit`"
    :load-id="id"
  >
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center justify-space-between mb-4">
          <div>
            <div class="text-h5 font-weight-bold">{{ item.patient_name }}</div>
            <div class="text-body-2 text-medium-emphasis">Dr. {{ item.doctor_name }} • {{ formatDateTime(item.created_at) }}</div>
          </div>
          <StatusChip :status="item.status" />
        </div>
        <v-divider class="mb-4" />
        <InfoGrid :item="item" :fields="fields" />
      </v-card>
    </template>
  </ResourceDetailPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/consultations/')
const fields = [
  { key: 'chief_complaint', label: 'Chief Complaint', md: 12 },
  { key: 'history', label: 'History', md: 12 },
  { key: 'examination', label: 'Examination', md: 12 },
  { key: 'diagnosis', label: 'Diagnosis', md: 12 },
  { key: 'treatment_plan', label: 'Treatment Plan', md: 12 }
]
</script>
