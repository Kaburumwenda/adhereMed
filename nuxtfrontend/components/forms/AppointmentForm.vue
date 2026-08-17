<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="primary-lighten-5" size="48">
        <v-icon color="primary-darken-2" size="28">
          {{ loadId ? 'mdi-calendar-edit' : 'mdi-calendar-plus' }}
        </v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">
          {{ loadId ? 'Edit Appointment' : 'New Appointment' }}
        </div>
        <div class="text-body-2 text-medium-emphasis">
          {{ loadId ? 'Update appointment details' : 'Schedule a new appointment' }}
        </div>
      </div>
      <v-spacer />
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" :to="backPath">
        Back
      </v-btn>
    </div>

    <v-progress-linear v-if="loadingById" indeterminate color="primary" class="mb-4" />

    <v-form ref="formRef" @submit.prevent="onSubmit">
      <!-- Section: Appointment Details -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="blue-lighten-5" size="36" class="mr-3">
            <v-icon color="blue-darken-2" size="22">mdi-calendar-outline</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Appointment Details</div>
        </div>

        <v-row dense>
          <v-col cols="12">
            <v-autocomplete
              v-model="form.patient"
              :items="patients"
              item-title="full_name"
              item-value="id"
              label="Patient *"
              placeholder="Search patient…"
              variant="outlined"
              prepend-inner-icon="mdi-account-search"
              :rules="req"
              :loading="patientsLoading"
              clearable
              return-object
              @update:model-value="onPatientChange"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props">
                  <template #prepend>
                    <v-avatar size="32" :color="avatarColor(item.raw.full_name)" variant="tonal">
                      <span class="text-caption font-weight-bold">{{ initials(item.raw.full_name) }}</span>
                    </v-avatar>
                  </template>
                  <v-list-item-subtitle class="text-caption">
                    {{ item.raw.user_email || item.raw.phone || '—' }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>

          <v-col cols="12" sm="6">
            <v-autocomplete
              v-model="form.staff"
              :items="doctors"
              item-title="full_name"
              item-value="id"
              label="Doctor / Staff"
              placeholder="Assign doctor…"
              variant="outlined"
              prepend-inner-icon="mdi-doctor"
              :loading="doctorsLoading"
              clearable
            />
          </v-col>

          <v-col cols="12" sm="6">
            <v-autocomplete
              v-model="form.department"
              :items="departments"
              item-title="name"
              item-value="id"
              label="Department"
              placeholder="Select department…"
              variant="outlined"
              prepend-inner-icon="mdi-office-building-outline"
              :loading="deptsLoading"
              clearable
            />
          </v-col>

          <v-col cols="12" sm="6">
            <v-text-field
              v-model="form.appointment_date"
              type="date"
              label="Date *"
              variant="outlined"
              prepend-inner-icon="mdi-calendar"
              :rules="req"
            />
          </v-col>

          <v-col cols="12" sm="3">
            <v-text-field
              v-model="form.appointment_time"
              type="time"
              label="Time *"
              variant="outlined"
              prepend-inner-icon="mdi-clock-outline"
              :rules="req"
            />
          </v-col>

          <v-col cols="12" sm="3">
            <v-select
              v-model="form.duration_minutes"
              :items="durationOptions"
              label="Duration"
              variant="outlined"
              prepend-inner-icon="mdi-timer-outline"
              suffix="min"
            />
          </v-col>
        </v-row>
      </v-card>

      <!-- Section: Status and Reason -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="teal-lighten-5" size="36" class="mr-3">
            <v-icon color="teal-darken-2" size="22">mdi-clipboard-text-outline</v-icon>
          </v-avatar>
          <div class="text-subtitle-1 font-weight-bold">Status and Reason</div>
        </div>

        <v-row dense>
          <v-col cols="12" sm="6">
            <v-select
              v-model="form.status"
              :items="statusOptions"
              label="Status"
              variant="outlined"
              prepend-inner-icon="mdi-flag-outline"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props">
                  <template #prepend>
                    <v-icon :color="statusMeta[item.value]?.color" size="20">
                      {{ statusMeta[item.value]?.icon }}
                    </v-icon>
                  </template>
                </v-list-item>
              </template>
            </v-select>
          </v-col>

          <v-col cols="12">
            <v-textarea
              v-model="form.reason"
              label="Reason for visit"
              placeholder="Describe the reason for the appointment…"
              variant="outlined"
              prepend-inner-icon="mdi-note-text-outline"
              rows="2"
              auto-grow
            />
          </v-col>

          <v-col cols="12">
            <v-textarea
              v-model="form.notes"
              label="Notes"
              placeholder="Additional notes or instructions…"
              variant="outlined"
              prepend-inner-icon="mdi-note-edit-outline"
              rows="2"
              auto-grow
            />
          </v-col>
        </v-row>
      </v-card>

      <!-- Error -->
      <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mb-4">
        {{ topError }}
      </v-alert>

      <!-- Actions -->
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none" :to="backPath">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
               :loading="saving" prepend-icon="mdi-content-save">
          {{ loadId ? 'Save Changes' : 'Create Appointment' }}
        </v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const route = useRoute()
const router = useRouter()

const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePath = computed(() => `${ns.value}/appointments`)
const backPath = computed(() => basePath.value)

const loadId = computed(() => route.params.id || null)
const r = useResource('/appointments/')
const patientsRes = useResource('/patients/')
const doctorsRes = useResource('/auth/staff/')
const deptsRes = useResource('/departments/')

const formRef = ref(null)
const saving = ref(false)
const loadingById = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const req = [v => (v !== null && v !== undefined && v !== '') || 'Required']

const statusMeta = {
  scheduled: { color: 'info', icon: 'mdi-calendar-clock' },
  confirmed: { color: 'success', icon: 'mdi-calendar-check' },
  in_progress: { color: 'blue', icon: 'mdi-progress-clock' },
  completed: { color: 'success', icon: 'mdi-check-circle' },
  cancelled: { color: 'error', icon: 'mdi-cancel' },
  no_show: { color: 'warning', icon: 'mdi-calendar-remove' },
}

const statusOptions = Object.entries(statusMeta).map(([value, m]) => ({
  title: value.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
  value,
}))

const durationOptions = [15, 30, 45, 60, 90, 120]

const patients = ref([])
const patientsLoading = ref(true)
const doctors = ref([])
const doctorsLoading = ref(true)
const departments = ref([])
const deptsLoading = ref(true)

const form = reactive({
  patient: null,
  staff: null,
  department: null,
  appointment_date: '',
  appointment_time: '09:00',
  duration_minutes: 30,
  status: loadId.value ? 'scheduled' : 'scheduled',
  reason: '',
  notes: '',
})

onMounted(async () => {
  await loadOptions()
  if (loadId.value) await loadAppointment()
})

async function loadOptions() {
  try {
    await patientsRes.list({ page_size: 1000 })
    patients.value = patientsRes.items.value.map(p => ({ ...p, full_name: p.user_name || p.user?.full_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || p.user_email || 'Unknown' }))
  } catch { /* ignore */ } finally { patientsLoading.value = false }
  try {
    await doctorsRes.list({ page_size: 1000 })
    doctors.value = doctorsRes.items.value.map(s => ({ ...s, full_name: s.full_name || `${s.first_name || ''} ${s.last_name || ''}`.trim() || s.email || 'Unknown' }))
  } catch { /* ignore */ } finally { doctorsLoading.value = false }
  try {
    await deptsRes.list({ page_size: 1000 })
    departments.value = deptsRes.items.value
  } catch { /* ignore */ } finally { deptsLoading.value = false }
}

async function loadAppointment() {
  loadingById.value = true
  try {
    const data = await r.get(loadId.value)
    if (data) {
      form.patient = data.patient || null
      form.staff = data.staff || null
      form.department = data.department || null
      form.appointment_date = data.appointment_date || ''
      form.appointment_time = data.appointment_time || '09:00'
      form.duration_minutes = data.duration_minutes || 30
      form.status = data.status || 'scheduled'
      form.reason = data.reason || ''
      form.notes = data.notes || ''
    }
  } catch (e) {
    topError.value = r.error.value || 'Failed to load appointment'
  } finally {
    loadingById.value = false
  }
}

function onPatientChange(val) {
  if (val && typeof val === 'object') {
    form.patient = val.id
  }
}

async function onSubmit() {
  topError.value = ''
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  saving.value = true
  try {
    const payload = { ...form }
    if (form.patient && typeof form.patient === 'object') form.patient = form.patient.id
    const result = loadId.value
      ? await r.update(loadId.value, payload)
      : await r.create(payload)
    snack.text = loadId.value ? 'Appointment updated successfully' : 'Appointment created successfully'
    snack.color = 'success'
    snack.show = true
    setTimeout(() => {
      if (result?.id) {
        router.push(`${basePath.value}/${result.id}`)
      } else {
        router.push(basePath.value)
      }
    }, 800)
  } catch (e) {
    topError.value = r.error.value || 'Failed to save appointment'
  } finally {
    saving.value = false
  }
}

function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(s => s[0]).slice(0, 2).join('').toUpperCase()
}
function avatarColor(name) {
  const colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'orange']
  const h = (name || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0)
  return colors[h % colors.length]
}
</script>

<style scoped>
.form-section {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  transition: border-color 0.2s;
}
.form-section:hover {
  border-color: rgba(var(--v-theme-primary), 0.2);
}
</style>
