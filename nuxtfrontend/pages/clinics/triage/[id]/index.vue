<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Triage Detail" subtitle="Patient vital signs and triage info" icon="mdi-monitor-heart" color="error">
      <template #actions>
        <v-btn variant="text" to="/clinics/triage">Back</v-btn>
      </template>
    </PageHeader>

    <v-progress-circular v-if="r.loading.value" indeterminate color="primary" />
    <v-alert v-else-if="!r.item.value" type="info" variant="tonal">Triage entry not found.</v-alert>
    <template v-else>
      <v-row dense>
        <v-col cols="12" md="8">
          <v-card rounded="lg" class="mb-3">
            <v-card-title class="text-subtitle-1 font-weight-bold">Vital Signs</v-card-title>
            <v-card-text>
              <v-row dense>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Temperature</div><div class="text-h6">{{ r.item.value.temperature || '—' }} °C</div></v-col>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Blood Pressure</div><div class="text-h6">{{ r.item.value.blood_pressure || (r.item.value.bp_systolic ? `${r.item.value.bp_systolic}/${r.item.value.bp_diastolic}` : '—') }}</div></v-col>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Heart Rate</div><div class="text-h6">{{ r.item.value.heart_rate || '—' }} bpm</div></v-col>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Respiratory Rate</div><div class="text-h6">{{ r.item.value.respiratory_rate || '—' }}</div></v-col>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Oxygen Saturation</div><div class="text-h6">{{ r.item.value.oxygen_saturation || '—' }} %</div></v-col>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Weight</div><div class="text-h6">{{ r.item.value.weight || '—' }} kg</div></v-col>
                <v-col cols="6" md="3"><div class="text-caption text-medium-emphasis">Height</div><div class="text-h6">{{ r.item.value.height || '—' }} cm</div></v-col>
              </v-row>
            </v-card-text>
          </v-card>
          <v-card rounded="lg" class="mb-3">
            <v-card-title class="text-subtitle-1 font-weight-bold">Chief Complaint</v-card-title>
            <v-card-text>{{ r.item.value.chief_complaint || '—' }}</v-card-text>
            <template v-if="r.item.value.notes">
              <v-divider />
              <v-card-title class="text-subtitle-1 font-weight-bold">Notes</v-card-title>
              <v-card-text>{{ r.item.value.notes }}</v-card-text>
            </template>
          </v-card>
        </v-col>
        <v-col cols="12" md="4">
          <v-card rounded="lg" class="mb-3">
            <v-card-title class="text-subtitle-1 font-weight-bold">Patient Info</v-card-title>
            <v-card-text>
              <v-list density="compact">
                <v-list-item title="Patient" :to="r.item.value.patient ? `/clinics/patients/${r.item.value.patient}` : null"><template #subtitle>{{ r.item.value.patient_name || '—' }}</template></v-list-item>
                <v-list-item title="Priority"><template #subtitle><v-chip :color="priorityColor(r.item.value.priority)" size="small" variant="tonal">{{ r.item.value.priority }}</v-chip></template></v-list-item>
                <v-list-item title="Triage Nurse"><template #subtitle>{{ r.item.value.triage_nurse_name || '—' }}</template></v-list-item>
                <v-list-item title="Date"><template #subtitle>{{ formatDateTime(r.item.value.created_at) }}</template></v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
          <v-btn block color="primary" variant="tonal" prepend-icon="mdi-medical-bag"
                 :to="`/clinics/consultations/new?patient=${r.item.value.patient}`">
            Start Consultation
          </v-btn>
        </v-col>
      </v-row>
    </template>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
const route = useRoute()
const r = useResource('/triage/')
onMounted(() => r.get(route.params.id))

function priorityColor(p) { return { critical: 'red', urgent: 'orange', routine: 'green' }[p] || 'grey' }
</script>
