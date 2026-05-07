<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Prescription' : 'New Prescription'"
    icon="mdi-pill"
    back-path="/prescriptions"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/prescriptions')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.patient" :items="patients" item-title="user_email" item-value="id" label="Patient" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-text-field v-model="form.diagnosis" label="Diagnosis" />
        </v-col>
        <v-col cols="12">
          <h4 class="text-subtitle-1 font-weight-bold mt-2 mb-2">Items</h4>
          <v-card v-for="(it, i) in form.items" :key="i" class="pa-3 mb-2" variant="outlined">
            <v-row dense>
              <v-col cols="12" sm="5"><v-text-field v-model="it.medication_name" label="Medication" density="compact" /></v-col>
              <v-col cols="6" sm="2"><v-text-field v-model="it.dosage" label="Dosage" density="compact" /></v-col>
              <v-col cols="6" sm="2"><v-text-field v-model="it.frequency" label="Frequency" density="compact" /></v-col>
              <v-col cols="8" sm="2"><v-text-field v-model="it.duration" label="Duration" density="compact" /></v-col>
              <v-col cols="4" sm="1" class="text-end">
                <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="form.items.splice(i,1)" />
              </v-col>
            </v-row>
          </v-card>
          <v-btn variant="tonal" prepend-icon="mdi-plus" @click="form.items.push({medication_name:'',dosage:'',frequency:'',duration:''})">Add Item</v-btn>
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/prescriptions/')
const req = [v => !!v || 'Required']
const initial = { patient: null, diagnosis: '', notes: '', items: [{ medication_name: '', dosage: '', frequency: '', duration: '' }] }
const patients = ref([])
onMounted(async () => {
  patients.value = await $api.get('/patients/').then(r => r.data?.results || r.data || []).catch(() => [])
})
</script>
