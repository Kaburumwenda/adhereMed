<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="Edit Caregiver"
      :subtitle="caregiver ? caregiver.patient_name : ''"
      icon="mdi-account-heart" color="pink">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/caregivers/${id}`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-progress-linear v-if="loadingCaregiver" indeterminate color="pink" class="mb-4" />

    <v-form v-else-if="caregiver" ref="formRef" @submit.prevent="save">
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

      <div class="d-flex flex-wrap align-center ga-2 mb-4">
        <v-btn variant="tonal" color="error" rounded="lg" class="text-none"
          prepend-icon="mdi-delete" @click="deleteDialog = true">Delete</v-btn>
        <v-spacer />
        <v-btn variant="text" rounded="lg" class="text-none"
          @click="navigateTo(`${ns}/caregivers/${id}`)">Cancel</v-btn>
        <v-btn type="submit" color="pink" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Save Changes</v-btn>
      </div>
    </v-form>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Caregiver?</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete this caregiver assignment for
              <strong>{{ caregiver?.patient_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

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

const id = computed(() => route.params.id)
const caregiver = ref(null)
const loadingCaregiver = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)

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

onMounted(async () => {
  patientR.list({ page_size: 1000 })
  loadingCaregiver.value = true
  try {
    const data = await r.get(id.value)
    caregiver.value = data
    if (data) {
      form.patient = data.patient
      form.caregiver_name = data.caregiver_name || ''
      form.relationship = data.relationship || ''
      form.phone = data.phone || ''
      form.email = data.email || ''
      form.address = data.address || ''
      form.is_active = data.is_active ?? true
      form.notes = data.notes || ''
    }
  } finally {
    loadingCaregiver.value = false
  }
})

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    await r.update(id.value, { ...form })
    snack.text = 'Caregiver updated successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/caregivers/${id.value}`)
  } catch {
    snack.text = r.error.value || 'Failed to update caregiver'
    snack.color = 'error'
    snack.show = true
  }
}

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(id.value)
    snack.text = 'Caregiver deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    navigateTo(`${ns}/caregivers`)
  } catch {
    snack.text = r.error.value || 'Failed to delete caregiver'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
