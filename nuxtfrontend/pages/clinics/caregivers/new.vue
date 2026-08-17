<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="New Caregiver" subtitle="Assign a caregiver to a patient"
      icon="mdi-account-heart-plus" color="pink">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/caregivers`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" @submit.prevent="save">
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="pink-lighten-5" size="36" class="mr-3">
            <v-icon color="pink-darken-2" size="20">mdi-account-heart</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Patient &amp; Caregiver</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-select v-model="form.patient" :items="patientOptions"
              label="Patient" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-account" :loading="patientR.loading.value" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.caregiver_name" label="Caregiver name"
              variant="outlined" :rules="req" prepend-inner-icon="mdi-account-plus" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.relationship" :items="relationshipOptions"
              label="Relationship" variant="outlined"
              prepend-inner-icon="mdi-account-multiple" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.phone" label="Phone"
              variant="outlined" prepend-inner-icon="mdi-phone" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.email" label="Email" type="email"
              variant="outlined" prepend-inner-icon="mdi-email" />
          </v-col>
          <v-col cols="12" md="6" class="d-flex align-center">
            <v-switch v-model="form.is_active" label="Active" color="success"
              hide-details inset />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.address" label="Address"
              variant="outlined" rows="2" auto-grow
              prepend-inner-icon="mdi-map-marker" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="Notes"
              variant="outlined" rows="2" auto-grow
              prepend-inner-icon="mdi-note-text" />
          </v-col>
        </v-row>
      </v-card>

      <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mb-4">
        {{ r.error.value }}
      </v-alert>

      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none"
          @click="navigateTo(`${ns}/caregivers`)">Cancel</v-btn>
        <v-btn type="submit" color="pink" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Assign Caregiver</v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const ns = '/clinics'
const route = useRoute()

const r = useResource('/homecare/caregivers/')
const patientR = useResource('/patients/')

const formRef = ref(null)
const req = [v => !!v || 'Required']

const relationshipOptions = ['spouse', 'parent', 'child', 'sibling', 'relative', 'friend', 'other']

const form = reactive({
  patient: null,
  caregiver_name: '',
  relationship: '',
  phone: '',
  email: '',
  address: '',
  is_active: true,
  notes: '',
})

const snack = reactive({ show: false, color: 'success', text: '' })

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: `${p.patient_number || ''} — ${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown'}`.trim(),
    value: p.id,
  })),
)

onMounted(() => {
  patientR.list({ page_size: 1000 })
  if (route.query.patient) form.patient = Number(route.query.patient)
})

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    await r.create({ ...form })
    snack.text = 'Caregiver assigned successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/caregivers`)
  } catch {
    snack.text = r.error.value || 'Failed to assign caregiver'
    snack.color = 'error'
    snack.show = true
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
