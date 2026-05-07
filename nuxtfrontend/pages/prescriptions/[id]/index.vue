<template>
  <ResourceDetailPage
    :resource="r"
    title="Prescription"
    icon="mdi-pill"
    back-path="/prescriptions"
    :edit-path="`/prescriptions/${id}/edit`"
    :load-id="id"
  >
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center justify-space-between mb-4">
          <div>
            <div class="text-h5 font-weight-bold">{{ item.patient_name }}</div>
            <div class="text-body-2 text-medium-emphasis">Dr. {{ item.doctor_name }}</div>
          </div>
          <StatusChip :status="item.status" />
        </div>
        <InfoGrid :item="item" :fields="[{key:'diagnosis',label:'Diagnosis',md:12},{key:'notes',label:'Notes',md:12}]" />
        <v-divider class="my-4" />
        <h3 class="text-subtitle-1 font-weight-bold mb-2">Items</h3>
        <v-table density="compact">
          <thead>
            <tr><th>Medication</th><th>Dosage</th><th>Frequency</th><th>Duration</th></tr>
          </thead>
          <tbody>
            <tr v-for="(it, i) in (item.items || [])" :key="i">
              <td>{{ it.medication_name }}</td><td>{{ it.dosage }}</td><td>{{ it.frequency }}</td><td>{{ it.duration }}</td>
            </tr>
          </tbody>
        </v-table>
      </v-card>
    </template>
  </ResourceDetailPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/prescriptions/')
</script>
