<template>
  <ResourceDetailPage
    :resource="r"
    title="Appointment"
    icon="mdi-calendar"
    back-path="/appointments"
    :edit-path="`/appointments/${id}/edit`"
    :load-id="id"
  >
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center justify-space-between mb-4">
          <div>
            <div class="text-h5 font-weight-bold">{{ item.patient_name }}</div>
            <div class="text-body-2 text-medium-emphasis">{{ formatDate(item.appointment_date) }} • {{ item.appointment_time }}</div>
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
import { formatDate } from '~/utils/format'
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/appointments/')
const fields = [
  { key: 'staff_name', label: 'Doctor / Staff' },
  { key: 'department_name', label: 'Department' },
  { key: 'reason', label: 'Reason', md: 12 }
]
</script>
