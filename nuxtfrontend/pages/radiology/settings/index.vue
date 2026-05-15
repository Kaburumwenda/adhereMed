<template>
  <v-container fluid class="pa-3 pa-md-5">
    <h1 class="text-h5 font-weight-bold mb-4"><v-icon class="mr-1">mdi-cog</v-icon>Radiology Settings</h1>

    <v-row>
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-5 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">General</h3>
          <v-text-field v-model="settings.facility_name" label="Facility Name" variant="outlined" density="compact" class="mb-2" />
          <v-text-field v-model="settings.phone" label="Phone" variant="outlined" density="compact" class="mb-2" />
          <v-text-field v-model="settings.email" label="Email" type="email" variant="outlined" density="compact" class="mb-2" />
          <v-textarea v-model="settings.address" label="Address" rows="2" auto-grow variant="outlined" density="compact" />
        </v-card>
      </v-col>
      <v-col cols="12" md="6">
        <v-card rounded="lg" class="pa-5 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Defaults</h3>
          <v-text-field v-model.number="settings.default_slot_duration" label="Default Slot Duration (min)" type="number" variant="outlined" density="compact" class="mb-2" />
          <v-text-field v-model.number="settings.default_tax_rate" label="Default Tax Rate (%)" type="number" variant="outlined" density="compact" class="mb-2" />
          <v-select v-model="settings.default_payer_type" :items="['self','insurance','facility','corporate']" label="Default Payer Type" variant="outlined" density="compact" />
        </v-card>

        <v-card rounded="lg" class="pa-5" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Report Settings</h3>
          <v-textarea v-model="settings.report_header" label="Report Header HTML" rows="3" auto-grow variant="outlined" density="compact" class="mb-2" />
          <v-textarea v-model="settings.report_footer" label="Report Footer HTML" rows="3" auto-grow variant="outlined" density="compact" />
        </v-card>
      </v-col>
    </v-row>

    <div class="d-flex justify-end mt-4">
      <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="save">Save Settings</v-btn>
    </div>
  </v-container>
</template>

<script setup>
const saving = ref(false)
const settings = reactive({
  facility_name: '', phone: '', email: '', address: '',
  default_slot_duration: 30, default_tax_rate: 0, default_payer_type: 'self',
  report_header: '', report_footer: '',
})

async function save() {
  saving.value = true
  // Settings would be stored via tenant profile or a dedicated settings API
  setTimeout(() => { saving.value = false }, 500)
}
</script>
