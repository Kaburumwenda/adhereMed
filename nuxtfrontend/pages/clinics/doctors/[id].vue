<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ═══ Header ════════════════════════════════════════════════ -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-btn icon="mdi-arrow-left" variant="text" @click="navigateTo(`${ns}/doctors`)" />
      <v-avatar color="blue-lighten-5" size="48">
        <v-icon color="blue-darken-2" size="28">mdi-doctor</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Dr. {{ doctor?.user_name || '—' }}</div>
        <div class="text-body-2 text-medium-emphasis">{{ doctor?.specialization || '' }}{{ doctor?.license_number ? ' • Lic #' + doctor.license_number : '' }}</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil" @click="navigateTo(`${ns}/doctors/${id}/edit`)">Edit</v-btn>
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-printer" @click="printPage">Print</v-btn>
    </div>

    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="blue" size="48" />
    </div>

    <div v-else-if="!doctor" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-doctor</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">Doctor not found</div>
      <v-btn color="blue" rounded="lg" class="text-none mt-3" @click="navigateTo(`${ns}/doctors`)">Back to Doctors</v-btn>
    </div>

    <v-row v-else>
      <!-- ═══ Left: Profile summary + actions ═════════════════════ -->
      <v-col cols="12" md="4">
        <v-card flat rounded="xl" class="profile-card pa-5 text-center h-100">
          <v-avatar size="120" :color="avatarColor(doctor.user_name)" variant="tonal" class="mb-3">
            <v-img v-if="doctor.profile_picture_url" :src="doctor.profile_picture_url" />
            <span class="text-h4 font-weight-bold" v-else>{{ initials(doctor.user_name) }}</span>
          </v-avatar>
          <h2 class="text-h5 font-weight-bold">Dr. {{ doctor.user_name || '—' }}</h2>
          <div class="text-body-2 text-medium-emphasis mb-2">{{ doctor.specialization || '—' }}</div>
          <div class="d-flex justify-center flex-wrap ga-1 mb-3">
            <v-chip size="small" :variant="doctor.is_verified ? 'flat' : 'outlined'" :color="doctor.is_verified ? 'green' : 'warning'" :prepend-icon="doctor.is_verified ? 'mdi-check-decagram' : 'mdi-clock-outline'">
              {{ doctor.is_verified ? 'Verified' : 'Pending' }}
            </v-chip>
            <v-chip size="small" :variant="doctor.is_accepting_patients ? 'flat' : 'outlined'" :color="doctor.is_accepting_patients ? 'success' : 'grey'">
              {{ doctor.is_accepting_patients ? 'Available' : 'Unavailable' }}
            </v-chip>
          </div>
          <div class="text-body-2 text-left mb-3" v-if="doctor.bio">{{ doctor.bio }}</div>
          <v-divider class="mb-3" />
          <div class="d-flex flex-column ga-2">
            <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-account-check" :color="doctor.is_verified ? 'warning' : 'green'" @click="toggleVerified">
              {{ doctor.is_verified ? 'Unverify Doctor' : 'Verify Doctor' }}
            </v-btn>
            <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-calendar-clock" :color="doctor.is_accepting_patients ? 'grey' : 'success'" @click="toggleAccepting">
              {{ doctor.is_accepting_patients ? 'Set Unavailable' : 'Set Available' }}
            </v-btn>
            <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-image" @click="uploadPicture">Upload Picture</v-btn>
            <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-draw" @click="uploadSignature">Upload Signature</v-btn>
            <input ref="pictureInput" type="file" accept="image/*" class="d-none" @change="onPictureSelected" />
            <input ref="signatureInput" type="file" accept="image/*" class="d-none" @change="onSignatureSelected" />
          </div>
        </v-card>
      </v-col>

      <!-- ═══ Right: Details + availability + stats ══════════════ -->
      <v-col cols="12" md="8">
        <!-- Info grid -->
        <v-card flat rounded="lg" class="detail-card pa-4 mb-4">
          <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center"><v-icon class="mr-2" color="blue">mdi-card-account-details-outline</v-icon>Profile Information</div>
          <v-row dense>
            <v-col cols="12" sm="6" md="4" v-for="f in infoFields" :key="f.key">
              <div class="text-caption text-medium-emphasis">{{ f.label }}</div>
              <div class="text-body-1 font-weight-medium mb-2">{{ f.display || '—' }}</div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-1">Bio</div>
          <div class="text-body-2">{{ doctor.bio || '—' }}</div>
        </v-card>

        <!-- Availability schedule -->
        <v-card flat rounded="lg" class="detail-card pa-4 mb-4">
          <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center"><v-icon class="mr-2" color="teal">mdi-calendar-check</v-icon>Availability Schedule</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="text-caption text-medium-emphasis mb-1">Available Days</div>
              <div v-if="days.length" class="d-flex flex-wrap ga-1">
                <v-chip v-for="d in days" :key="d" size="small" variant="tonal" color="teal">{{ d }}</v-chip>
              </div>
              <span v-else class="text-body-2 text-medium-emphasis">Not set</span>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-caption text-medium-emphasis mb-1">Available Hours</div>
              <div v-if="hoursText" class="text-body-1 font-weight-medium">
                <v-icon size="16" class="mr-1" color="teal">mdi-clock-outline</v-icon>{{ hoursText }}
              </div>
              <span v-else class="text-body-2 text-medium-emphasis">Not set</span>
            </v-col>
          </v-row>
          <v-divider class="my-3" v-if="doctor.languages?.length" />
          <div v-if="doctor.languages?.length" class="text-caption text-medium-emphasis mb-1">Languages</div>
          <div v-if="doctor.languages?.length" class="d-flex flex-wrap ga-1">
            <v-chip v-for="l in doctor.languages" :key="l" size="small" variant="tonal" color="indigo">{{ l }}</v-chip>
          </div>
        </v-card>

        <!-- Stats -->
        <v-card flat rounded="lg" class="detail-card pa-4">
          <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center"><v-icon class="mr-2" color="orange">mdi-chart-line</v-icon>Activity Stats</div>
          <v-row dense>
            <v-col v-for="s in statsCards" :key="s.label" cols="6" sm="3">
              <v-card flat rounded="lg" class="pa-3 text-center" :class="statBgClass">
                <v-icon :color="s.color" size="28" class="mb-1">{{ s.icon }}</v-icon>
                <div class="text-h5 font-weight-bold">{{ s.value }}</div>
                <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
              </v-card>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>

    <!-- Picture preview dialog -->
    <v-dialog v-model="picturePreview" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Profile Picture</v-card-title>
        <v-card-text class="text-center">
          <v-img v-if="pendingPicture" :src="pendingPicture" max-height="200" contain />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="picturePreview = false; pendingPicture = null">Cancel</v-btn>
          <v-btn color="blue" :loading="uploading" @click="confirmUploadPicture">Upload</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()
const { $api } = useNuxtApp()

const id = computed(() => route.params.id)
const doctor = ref(null)
const loading = ref(true)
const snack = reactive({ show: false, color: 'success', text: '' })
function showToast(t, c = 'success') { snack.text = t; snack.color = c; snack.show = true }

const stats = reactive({ appointments: 0, consultations: 0, patientsSeen: 0, upcoming: 0 })

const statBgClass = 'bg-surface'
const statsCards = computed(() => [
  { label: 'Appointments', value: stats.appointments, icon: 'mdi-calendar', color: 'blue' },
  { label: 'Consultations', value: stats.consultations, icon: 'mdi-clipboard-text', color: 'teal' },
  { label: 'Patients Seen', value: stats.patientsSeen, icon: 'mdi-account-group', color: 'indigo' },
  { label: 'Upcoming', value: stats.upcoming, icon: 'mdi-calendar-clock', color: 'orange' },
])

const infoFields = computed(() => {
  const d = doctor.value || {}
  return [
    { key: 'specialization', label: 'Specialization', display: d.specialization || '—' },
    { key: 'license_number', label: 'License #', display: d.license_number || '—' },
    { key: 'qualification', label: 'Qualification', display: d.qualification || '—' },
    { key: 'years_of_experience', label: 'Experience', display: d.years_of_experience != null ? `${d.years_of_experience} yrs` : '—' },
    { key: 'consultation_fee', label: 'Consultation Fee', display: d.consultation_fee ? formatMoney(d.consultation_fee) : '—' },
    { key: 'practice_type', label: 'Practice Type', display: d.practice_type === 'hospital' ? 'Hospital-Affiliated' : 'Independent' },
    { key: 'user_email', label: 'Email', display: d.user_email || '—' },
    { key: 'user_phone', label: 'Phone', display: d.user_phone || d.phone || '—' },
  ]
})

const days = computed(() => {
  const d = doctor.value?.available_days
  return Array.isArray(d) ? d : []
})
const hoursText = computed(() => {
  const h = doctor.value?.available_hours
  if (!h) return ''
  if (typeof h === 'string') return h
  if (h.start && h.end) return `${h.start} – ${h.end}`
  return ''
})

function avatarColor(name) {
  if (!name) return 'grey'
  const colors = ['blue', 'teal', 'indigo', 'green', 'orange', 'pink', 'cyan', 'purple']
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function initials(name) {
  if (!name) return '?'
  return name.split(' ').filter(s => s).slice(0, 2).map(s => s[0]).join('').toUpperCase()
}

function printPage() { window.print() }

async function toggleVerified() {
  try {
    const { data } = await $api.patch(`/doctors/${id.value}/toggle_verified/`)
    Object.assign(doctor.value, data)
    showToast(`Dr. ${doctor.value.user_name} ${doctor.value.is_verified ? 'verified' : 'unverified'}`, doctor.value.is_verified ? 'success' : 'warning')
  } catch (e) { showToast('Failed to update', 'error') }
}
async function toggleAccepting() {
  try {
    const { data } = await $api.patch(`/doctors/${id.value}/toggle_accepting/`)
    Object.assign(doctor.value, data)
    showToast(`Dr. ${doctor.value.user_name} ${doctor.value.is_accepting_patients ? 'now available' : 'now unavailable'}`, doctor.value.is_accepting_patients ? 'success' : 'warning')
  } catch (e) { showToast('Failed to update', 'error') }
}

// Picture upload
const pictureInput = ref(null)
const signatureInput = ref(null)
const picturePreview = ref(false)
const pendingPicture = ref(null)
const pendingFile = ref(null)
const pendingType = ref('')
const uploading = ref(false)

function uploadPicture() { pendingType.value = 'picture'; pictureInput.value?.click() }
function uploadSignature() { pendingType.value = 'signature'; signatureInput.value?.click() }

function onPictureSelected(e) {
  const f = e.target.files[0]
  if (!f) return
  pendingFile.value = f
  const reader = new FileReader()
  reader.onload = (ev) => { pendingPicture.value = ev.target.result; picturePreview.value = true }
  reader.readAsDataURL(f)
}

function onSignatureSelected(e) {
  const f = e.target.files[0]
  if (!f) return
  pendingFile.value = f
  pendingType.value = 'signature'
  confirmUpload()
}

async function confirmUploadPicture() {
  if (!pendingFile.value) return
  uploading.value = true
  try {
    const fd = new FormData()
    fd.append('profile_picture', pendingFile.value)
    const { data } = await $api.post(`/doctors/me/upload-picture/`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
    if (data?.profile_picture_url) doctor.value.profile_picture_url = data.profile_picture_url
    showToast('Picture uploaded')
    picturePreview.value = false; pendingPicture.value = null; pendingFile.value = null; pendingType.value = ''
  } catch (e) { showToast('Upload failed', 'error') }
  finally { uploading.value = false }
}

async function confirmUpload() {
  if (!pendingFile.value) return
  uploading.value = true
  try {
    const fd = new FormData()
    const endpoint = pendingType.value === 'signature' ? '/doctors/me/upload-signature/' : '/doctors/me/upload-picture/'
    fd.append(pendingType.value === 'signature' ? 'signature' : 'profile_picture', pendingFile.value)
    const { data } = await $api.post(endpoint, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
    if (data?.profile_picture_url) doctor.value.profile_picture_url = data.profile_picture_url
    if (data?.signature_url) doctor.value.signature_url = data.signature_url
    showToast(`${pendingType.value === 'signature' ? 'Signature' : 'Picture'} uploaded`)
    pendingFile.value = null; pendingType.value = ''
  } catch (e) { showToast('Upload failed', 'error') }
  finally { uploading.value = false }
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await $api.get(`/doctors/${id.value}/`)
    doctor.value = data
    const safe = (p) => $api.get(p, { params: { page_size: 1000 } })
      .then(r => r.data?.results || r.data || []).catch(() => [])
    const [appts, consults] = await Promise.all([
      safe(`/appointments/?doctor=${id.value}`),
      safe(`/consultations/?doctor=${id.value}`),
    ])
    stats.appointments = appts.length
    stats.upcoming = appts.filter(a => a.status === 'scheduled' || a.status === 'confirmed').length
    stats.consultations = consults.length
    stats.patientsSeen = new Set(consults.map(c => c.patient)).size
  } catch (e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.profile-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.detail-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
@media print {
  .v-btn, .v-snackbar { display: none !important; }
}
</style>
