<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1000px;">
    <!-- ═══ Header ════════════════════════════════════════════════ -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-btn icon="mdi-arrow-left" variant="text" @click="navigateTo(`${ns}/doctors`)" />
      <v-avatar color="blue-lighten-5" size="48">
        <v-icon color="blue-darken-2" size="28">mdi-doctor-plus</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">New Doctor Profile</div>
        <div class="text-body-2 text-medium-emphasis">Create a doctor profile linked to a staff user</div>
      </div>
    </div>

    <v-form ref="formRef" @submit.prevent="save">
      <!-- ═══ Profile details ══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="blue-lighten-5" size="36" class="mr-3">
            <v-icon color="blue-darken-2" size="20">mdi-account-tie</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Profile Details</div>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-select v-model="form.user" :items="staffOptions" item-title="title" item-value="value"
              label="Staff User *" required variant="outlined" density="compact"
              prepend-inner-icon="mdi-account"
              hint="Link this doctor profile to an existing staff user."
              persistent-hint
              :loading="staffLoading"
              :rules="req" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.specialization" label="Specialization *"
              required variant="outlined" density="compact"
              prepend-inner-icon="mdi-medical-bag"
              hint="e.g. Cardiology, Pediatrics" persistent-hint
              :rules="req" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.license_number" label="License Number *" required
              variant="outlined" density="compact" prepend-inner-icon="mdi-card-account-details"
              hint="e.g. KMPDB/A/12345" persistent-hint
              :rules="req" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.qualification" label="Qualification"
              variant="outlined" density="compact" prepend-inner-icon="mdi-school"
              hint="e.g. MBChB, MD" persistent-hint />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.practice_type" :items="practiceTypeOptions"
              label="Practice Type" variant="outlined" density="compact"
              prepend-inner-icon="mdi-hospital-building" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model.number="form.years_of_experience" label="Years of Experience"
              type="number" min="0" variant="outlined" density="compact"
              prepend-inner-icon="mdi-timer-sand" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model.number="form.consultation_fee" label="Consultation Fee"
              type="number" min="0" variant="outlined" density="compact"
              prepend-inner-icon="mdi-cash" hint="KES" persistent-hint />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.department" :items="deptOptions"
              label="Department" variant="outlined" density="compact" clearable
              prepend-inner-icon="mdi-domain"
              :loading="deptLoading" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.bio" label="Bio" rows="3" auto-grow
              variant="outlined" density="compact" prepend-inner-icon="mdi-text-account"
              placeholder="Brief professional bio..." />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Availability ═══════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="teal-lighten-5" size="36" class="mr-3">
            <v-icon color="teal-darken-2" size="20">mdi-calendar-clock</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Availability Schedule</div>
        </div>
        <v-row dense>
          <v-col cols="12">
            <div class="text-subtitle-2 text-medium-emphasis mb-2 d-flex align-center"><v-icon size="16" class="mr-1">mdi-calendar</v-icon>Available Days</div>
            <div class="d-flex flex-wrap ga-1">
              <v-chip v-for="day in dayOptions" :key="day" size="small"
                :variant="form.available_days.includes(day) ? 'flat' : 'outlined'"
                :color="form.available_days.includes(day) ? 'teal' : undefined"
                @click="toggleDay(day)">{{ day }}</v-chip>
            </div>
          </v-col>
          <v-col cols="12" sm="6" class="mt-3">
            <v-text-field v-model="form.available_hours.start" label="Start Time" type="time"
              variant="outlined" density="compact" prepend-inner-icon="mdi-clock-start" />
          </v-col>
          <v-col cols="12" sm="6" class="mt-3">
            <v-text-field v-model="form.available_hours.end" label="End Time" type="time"
              variant="outlined" density="compact" prepend-inner-icon="mdi-clock-end" />
          </v-col>
          <v-col cols="12" class="pt-2">
            <v-switch v-model="form.is_accepting_patients" label="Accepting new patients"
              color="teal" hide-details density="compact" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Languages ═════════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="indigo-lighten-5" size="36" class="mr-3">
            <v-icon color="indigo-darken-2" size="20">mdi-translate</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Languages</div>
        </div>
        <div class="d-flex flex-wrap ga-1">
          <v-chip v-for="lang in languageOptions" :key="lang" size="small"
            :variant="form.languages.includes(lang) ? 'flat' : 'outlined'"
            :color="form.languages.includes(lang) ? 'indigo' : undefined"
            @click="toggleLang(lang)">{{ lang }}</v-chip>
        </div>
      </v-card>

      <!-- ═══ Action bar ═══════════════════════════════════════════ -->
      <v-alert v-if="saveError" type="error" variant="tonal" density="compact" class="mb-4">
        {{ saveError }}
      </v-alert>
      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none" @click="navigateTo(`${ns}/doctors`)">Cancel</v-btn>
        <v-btn type="submit" color="blue" rounded="lg" class="text-none"
          :loading="saving" prepend-icon="mdi-content-save">Create Doctor</v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const ns = '/clinics'
const { $api } = useNuxtApp()

const formRef = ref(null)
const req = [v => v != null && v !== '' || 'Required']
const dayOptions = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
const practiceTypeOptions = [
  { title: 'Independent', value: 'independent' },
  { title: 'Hospital-Affiliated', value: 'hospital' },
]
const languageOptions = ['English', 'Swahili', 'French', 'Arabic', 'Spanish', 'Portuguese', 'Amharic', 'Hausa', 'German', 'Hindi']

const form = reactive({
  user: null,
  specialization: '',
  license_number: '',
  qualification: '',
  practice_type: 'independent',
  years_of_experience: 0,
  consultation_fee: 0,
  department: null,
  bio: '',
  available_days: [],
  available_hours: { start: '08:00', end: '17:00' },
  is_accepting_patients: true,
  languages: [],
})

const staffOptions = ref([])
const staffLoading = ref(false)
const deptOptions = ref([])
const deptLoading = ref(false)
const saving = ref(false)
const saveError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

function toggleDay(day) {
  const idx = form.available_days.indexOf(day)
  if (idx >= 0) form.available_days.splice(idx, 1)
  else form.available_days.push(day)
}
function toggleLang(lang) {
  const idx = form.languages.indexOf(lang)
  if (idx >= 0) form.languages.splice(idx, 1)
  else form.languages.push(lang)
}

onMounted(async () => {
  staffLoading.value = true
  deptLoading.value = true
  try {
    const [staffRes, deptRes] = await Promise.all([
      $api.get('/auth/staff/', { params: { page_size: 1000 } }).catch(() => ({ data: [] })),
      $api.get('/departments/', { params: { page_size: 1000 } }).catch(() => ({ data: [] })),
    ])
    const staffList = staffRes.data?.results || staffRes.data || []
    staffOptions.value = staffList
      .filter(s => ['doctor', 'clinical_officer', 'admin', 'superadmin'].includes(s.role) || !s.role)
      .map(s => ({ title: `${s.first_name || s.full_name || ''} ${s.last_name || ''} — ${s.email}`.trim(), value: s.id }))
    const deptList = deptRes.data?.results || deptRes.data || []
    deptOptions.value = deptList.map(d => ({ title: d.name, value: d.id }))
  } finally {
    staffLoading.value = false
    deptLoading.value = false
  }
})

async function save() {
  const v = await formRef.value?.validate()
  if (v?.valid === false) return
  saving.value = true
  saveError.value = ''
  try {
    const payload = { ...form }
    if (payload.department) payload.hospital = payload.department
    delete payload.department
    await $api.post('/doctors/', payload)
    snack.text = 'Doctor profile created successfully'
    snack.color = 'success'
    snack.show = true
    navigateTo(`${ns}/doctors`)
  } catch (e) {
    saveError.value = e?.response?.data?.detail || 'Failed to create doctor profile.'
    snack.text = saveError.value
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
