<template>
  <ResourceDetailPage
    :resource="r"
    title="Patient Detail"
    icon="mdi-account"
    back-path="/patients"
    :edit-path="`/patients/${id}/edit`"
    :load-id="id"
  >
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center mb-6">
          <v-avatar size="72" color="primary" variant="tonal">
            <v-icon size="48">mdi-account</v-icon>
          </v-avatar>
          <div class="ml-4">
            <div class="text-h5 font-weight-bold">{{ item.user_email || '—' }}</div>
            <div class="text-body-2 text-medium-emphasis">Patient #{{ item.patient_number || '—' }}</div>
          </div>
        </div>
        <v-divider class="mb-4" />
        <InfoGrid :item="item" :fields="fields" />
      </v-card>
    </template>
  </ResourceDetailPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/patients/')

const fields = [
  { key: 'national_id', label: 'National ID' },
  { key: 'date_of_birth', label: 'Date of Birth', format: formatDate },
  { key: 'gender', label: 'Gender' },
  { key: 'blood_type', label: 'Blood Type' },
  { key: 'phone', label: 'Phone' },
  { key: 'address', label: 'Address', md: 8 },
  { key: 'emergency_contact_name', label: 'Emergency Contact' },
  { key: 'emergency_contact_phone', label: 'Emergency Phone' }
]
</script>
