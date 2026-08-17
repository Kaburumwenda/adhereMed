<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Vital Signs" subtitle="Patient vital signs tracking"
      icon="mdi-heart-pulse" color="red">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="r.list({ page_size: 1000 })">Refresh</v-btn>
        <v-btn color="red" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openDialog()">New Vitals</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search patient…" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="4">
          <v-select v-model="patientFilter" :items="patientOptions"
            label="Filter by patient" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="red" size="48" />
      </div>

      <div v-else-if="!filteredVitals.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-heart-pulse</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No vitals recorded</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ r.search.value || patientFilter ? 'Try adjusting your filters.' : 'Record vital signs to get started.' }}
        </div>
        <v-btn v-if="!r.search.value && !patientFilter" color="red" rounded="lg"
          prepend-icon="mdi-plus" class="text-none" @click="openDialog()">New Vitals</v-btn>
      </div>

      <v-data-table v-else :headers="headers" :items="filteredVitals"
        :items-per-page="20" item-value="id" hover class="vitals-table">
        <template #item.patient_name="{ value }">
          <span class="font-weight-medium">{{ value || '—' }}</span>
        </template>
        <template #item.vital_signs.temperature="{ value }">
          {{ value != null ? `${value} °C` : '—' }}
        </template>
        <template #item.bp="{ item }">
          {{ bpLabel(item) }}
        </template>
        <template #item.vital_signs.heart_rate="{ value }">
          {{ value != null ? `${value} bpm` : '—' }}
        </template>
        <template #item.vital_signs.respiratory_rate="{ value }">
          {{ value != null ? value : '—' }}
        </template>
        <template #item.vital_signs.oxygen_saturation="{ value }">
          {{ value != null ? `${value}%` : '—' }}
        </template>
        <template #item.vital_signs.weight="{ value }">
          {{ value != null ? `${value} kg` : '—' }}
        </template>
        <template #item.created_at="{ value }">{{ formatDateTime(value) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end">
            <v-btn icon="mdi-pencil" variant="text" size="small" @click="openDialog(item)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ── New / Edit dialog ─────────────────────────────────────── -->
    <v-dialog v-model="dialog" max-width="700" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6">
          <v-icon color="red" class="mr-2">mdi-heart-pulse</v-icon>
          {{ editing ? 'Edit Vitals' : 'New Vitals' }}
        </v-card-title>
        <v-divider />
        <v-card-text>
          <v-form ref="formRef">
            <v-select v-model="vitalsForm.patient" :items="patientOptions"
              label="Patient" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-account" class="mb-3"
              :loading="patientR.loading.value" />
            <v-row dense>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.temperature" type="number"
                  label="Temperature (°C)" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.bp_systolic" type="number"
                  label="BP Systolic" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.bp_diastolic" type="number"
                  label="BP Diastolic" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.heart_rate" type="number"
                  label="Heart Rate (bpm)" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.respiratory_rate" type="number"
                  label="Respiratory Rate" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.oxygen_saturation" type="number"
                  label="SpO₂ (%)" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.weight" type="number"
                  label="Weight (kg)" variant="outlined" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="vitalsForm.height" type="number"
                  label="Height (cm)" variant="outlined" density="compact" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="dialog = false">Cancel</v-btn>
          <v-btn color="red" rounded="lg" :loading="r.saving.value"
            @click="saveVitals">{{ editing ? 'Update' : 'Create' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Vitals?</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete this vitals record for
              <strong>{{ deleteTarget?.patient_name || '—' }}</strong>?
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
import { formatDateTime } from '~/utils/format'

const ns = '/clinics'

const r = useResource('/triage/')
const patientR = useResource('/patients/')

onMounted(() => {
  r.list({ page_size: 1000 })
  patientR.list({ page_size: 1000 })
})

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Temp', key: 'temperature', sortable: false, width: 90 },
  { title: 'BP', key: 'bp', sortable: false, width: 90 },
  { title: 'HR', key: 'vital_signs.heart_rate', sortable: false, width: 90 },
  { title: 'RR', key: 'vital_signs.respiratory_rate', sortable: false, width: 80 },
  { title: 'SpO₂', key: 'vital_signs.oxygen_saturation', sortable: false, width: 80 },
  { title: 'Weight', key: 'vital_signs.weight', sortable: false, width: 90 },
  { title: 'Date', key: 'created_at', width: 160 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]

const patientFilter = ref(null)
const req = [v => !!v || 'Required']
const formRef = ref(null)
const dialog = ref(false)
const editing = ref(null)
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const vitalsForm = reactive({
  patient: null,
  temperature: null,
  bp_systolic: null,
  bp_diastolic: null,
  heart_rate: null,
  respiratory_rate: null,
  oxygen_saturation: null,
  weight: null,
  height: null,
})

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: `${p.patient_number || ''} — ${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown'}`.trim(),
    value: p.id,
  })),
)

const filteredVitals = computed(() => {
  if (!patientFilter.value) return r.filtered.value
  return r.filtered.value.filter(v => v.patient === patientFilter.value)
})

function bpLabel(item) {
  const vs = item.vital_signs || {}
  const sys = vs.bp_systolic || vs.blood_pressure_systolic
  const dia = vs.bp_diastolic || vs.blood_pressure_diastolic
  if (sys && dia) return `${sys}/${dia}`
  return '—'
}

function openDialog(item) {
  if (item) {
    editing.value = item.id
    const vs = item.vital_signs || {}
    vitalsForm.patient = item.patient
    vitalsForm.temperature = vs.temperature ?? null
    vitalsForm.bp_systolic = vs.bp_systolic ?? vs.blood_pressure_systolic ?? null
    vitalsForm.bp_diastolic = vs.bp_diastolic ?? vs.blood_pressure_diastolic ?? null
    vitalsForm.heart_rate = vs.heart_rate ?? null
    vitalsForm.respiratory_rate = vs.respiratory_rate ?? null
    vitalsForm.oxygen_saturation = vs.oxygen_saturation ?? null
    vitalsForm.weight = vs.weight ?? null
    vitalsForm.height = vs.height ?? null
  } else {
    editing.value = null
    Object.assign(vitalsForm, {
      patient: null, temperature: null, bp_systolic: null, bp_diastolic: null,
      heart_rate: null, respiratory_rate: null, oxygen_saturation: null,
      weight: null, height: null,
    })
  }
  dialog.value = true
}

async function saveVitals() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  const payload = { ...vitalsForm }
  if (vitalsForm.bp_systolic && vitalsForm.bp_diastolic) {
    payload.vital_signs = {
      temperature: vitalsForm.temperature,
      bp_systolic: vitalsForm.bp_systolic,
      bp_diastolic: vitalsForm.bp_diastolic,
      heart_rate: vitalsForm.heart_rate,
      respiratory_rate: vitalsForm.respiratory_rate,
      oxygen_saturation: vitalsForm.oxygen_saturation,
      weight: vitalsForm.weight,
      height: vitalsForm.height,
    }
    delete payload.temperature
    delete payload.bp_systolic
    delete payload.bp_diastolic
    delete payload.heart_rate
    delete payload.respiratory_rate
    delete payload.oxygen_saturation
    delete payload.weight
    delete payload.height
  }
  try {
    if (editing.value) await r.update(editing.value, payload)
    else await r.create(payload)
    snack.text = editing.value ? 'Vitals updated' : 'Vitals recorded'
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    r.list({ page_size: 1000 })
  } catch {
    snack.text = r.error.value || 'Failed to save vitals'
    snack.color = 'error'
    snack.show = true
  }
}

function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Vitals record deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    deleteTarget.value = null
  } catch {
    snack.text = r.error.value || 'Failed to delete vitals'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
</style>
