<template>
  <ResourceFormPage
    :resource="r"
    title="Edit Equipment"
    icon="mdi-cog-transfer"
    back-path="/radiology/equipment"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/radiology/equipment')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name *" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-select v-model="form.modality_type" :items="modalityTypes" label="Type *" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.manufacturer" label="Manufacturer" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.model_name" label="Model" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.serial_number" label="Serial Number" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.room_location" label="Room / Location" /></v-col>
        <v-col cols="12" sm="4"><v-text-field v-model="form.installation_date" label="Installation Date" type="date" /></v-col>
        <v-col cols="12" sm="4"><v-text-field v-model="form.last_service_date" label="Last Service" type="date" /></v-col>
        <v-col cols="12" sm="4"><v-text-field v-model="form.next_service_date" label="Next Service" type="date" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model.number="form.max_daily_slots" label="Max Daily Slots" type="number" /></v-col>
        <v-col cols="12" sm="6"><v-switch v-model="form.is_active" label="Active" color="success" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id)
const r = useResource('/radiology/modalities/')
const req = [v => !!v || 'Required']
const modalityTypes = [
  { title: 'X-Ray', value: 'xray' }, { title: 'CT Scan', value: 'ct' }, { title: 'MRI', value: 'mri' },
  { title: 'Ultrasound', value: 'ultrasound' }, { title: 'Mammography', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' }, { title: 'PET-CT', value: 'pet_ct' },
  { title: 'DEXA', value: 'dexa' }, { title: 'Other', value: 'other' },
]
const initial = { name: '', modality_type: '', manufacturer: '', model_name: '', serial_number: '', room_location: '', installation_date: null, last_service_date: null, next_service_date: null, max_daily_slots: 20, is_active: true, notes: '' }
</script>
