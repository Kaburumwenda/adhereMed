<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" :to="backPath">
        Back
      </v-btn>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil" :to="editPath">
        Edit
      </v-btn>
      <v-menu>
        <template #activator="{ props }">
          <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" />
        </template>
        <v-list density="compact">
          <v-list-item :to="editPath" prepend-icon="mdi-calendar-edit">
            <v-list-item-title>Edit Appointment</v-list-item-title>
          </v-list-item>
          <v-divider />
          <v-list-item @click="confirmDelete" prepend-icon="mdi-delete" base-color="error">
            <v-list-item-title>Delete Appointment</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </div>

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-4" />

    <!-- Banner -->
    <v-card v-if="item" rounded="lg" variant="outlined" class="mb-4">
      <v-card-text class="pa-4 pa-md-5">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar size="56" :color="avatarColor(item.patient_name)" variant="tonal">
            <span class="text-h6 font-weight-bold">{{ initials(item.patient_name) }}</span>
          </v-avatar>
          <div class="flex-grow-1">
            <div class="d-flex align-center ga-2 flex-wrap">
              <h2 class="text-h6 font-weight-bold mb-0">{{ item.patient_name || 'Unknown Patient' }}</h2>
              <StatusChip :status="item.status" />
            </div>
            <div class="text-body-2 text-medium-emphasis">
              <v-icon size="small" class="mr-1">mdi-calendar</v-icon>
              {{ formatDate(item.appointment_date) }} at {{ formatTime(item.appointment_time) }}
              <span class="mx-2">·</span>
              <v-icon size="small" class="mr-1">mdi-timer-outline</v-icon>
              {{ item.duration_minutes || 30 }} min
              <span class="mx-2">·</span>
              <v-icon size="small" class="mr-1">mdi-doctor</v-icon>
              {{ item.staff_name || 'Unassigned' }}
            </div>
          </div>
          <!-- Quick status actions -->
          <div class="d-flex flex-wrap ga-2">
            <v-btn v-if="canConfirm" color="success" variant="tonal" rounded="lg" class="text-none" size="small"
                   :loading="actionLoading" @click="quickStatus('confirmed')">
              <v-icon start>mdi-calendar-check</v-icon> Confirm
            </v-btn>
            <v-btn v-if="canCheckIn" color="info" variant="tonal" rounded="lg" class="text-none" size="small"
                   :loading="actionLoading" @click="quickStatus('in_progress')">
              <v-icon start>mdi-login</v-icon> Check In
            </v-btn>
            <v-btn v-if="canComplete" color="success" variant="tonal" rounded="lg" class="text-none" size="small"
                   :loading="actionLoading" @click="quickStatus('completed')">
              <v-icon start>mdi-check-circle</v-icon> Complete
            </v-btn>
            <v-btn v-if="canNoShow" color="warning" variant="tonal" rounded="lg" class="text-none" size="small"
                   :loading="actionLoading" @click="quickStatus('no_show')">
              <v-icon start>mdi-calendar-remove</v-icon> No Show
            </v-btn>
            <v-btn v-if="canCancel" color="error" variant="tonal" rounded="lg" class="text-none" size="small"
                   :loading="actionLoading" @click="quickStatus('cancelled')">
              <v-icon start>mdi-cancel</v-icon> Cancel
            </v-btn>
          </div>
        </div>
      </v-card-text>
    </v-card>

    <!-- Tabs -->
    <v-card v-if="item" rounded="lg" variant="outlined">
      <v-tabs v-model="tab" color="primary" density="compact">
        <v-tab value="overview" prepend-icon="mdi-information-outline">Overview</v-tab>
        <v-tab value="patient" prepend-icon="mdi-account-outline">Patient</v-tab>
        <v-tab value="history" prepend-icon="mdi-history">History</v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4 pa-md-5">
        <!-- Overview Tab -->
        <v-window-item value="overview">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-calendar-clock</v-icon> Appointment Info
                </div>
                <DetailField label="Date" :value="formatDate(item.appointment_date)" />
                <DetailField label="Time" :value="formatTime(item.appointment_time)" />
                <DetailField label="Duration" :value="`${item.duration_minutes || 30} minutes`" />
                <DetailField label="Status">
                  <StatusChip :status="item.status" />
                </DetailField>
                <DetailField label="Department" :value="item.department_name || 'Unassigned'" />
                <DetailField label="Doctor" :value="item.staff_name || 'Unassigned'" />
              </v-card>
            </v-col>

            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="detail-section pa-4 mb-4">
                <div class="text-subtitle-2 font-weight-bold mb-3">
                  <v-icon size="18" class="mr-1">mdi-note-text-outline</v-icon> Reason &amp; Notes
                </div>
                <DetailField label="Reason" :value="item.reason || '—'" full />
                <v-divider class="my-2" />
                <DetailField label="Notes" :value="item.notes || '—'" full />
                <v-divider class="my-2" />
                <DetailField label="Created" :value="formatDate(item.created_at)" />
                <DetailField label="Updated" :value="formatDate(item.updated_at)" />
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

        <!-- Patient Tab -->
        <v-window-item value="patient">
          <v-card flat rounded="lg" class="detail-section pa-4" v-if="patientDetail">
            <div class="d-flex align-center ga-3 mb-4">
              <v-avatar size="48" :color="avatarColor(patientDetail.full_name || item.patient_name)" variant="tonal">
                <span class="text-h6 font-weight-bold">{{ initials(patientDetail.full_name || item.patient_name) }}</span>
              </v-avatar>
              <div>
                <div class="text-h6 font-weight-bold">{{ patientDetail.full_name || item.patient_name }}</div>
                <div class="text-body-2 text-medium-emphasis">{{ patientDetail.user_email || patientDetail.user?.email }}</div>
              </div>
              <v-spacer />
              <v-btn variant="tonal" color="primary" size="small" rounded="lg" class="text-none"
                     :to="patientLink" prepend-icon="mdi-account-eye">
                View Patient
              </v-btn>
            </div>
            <v-row dense>
              <v-col cols="12" sm="6" md="4"><DetailField label="Gender" :value="patientDetail.gender || '—'" capitalize /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Date of Birth" :value="formatDate(patientDetail.date_of_birth)" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Blood Type" :value="patientDetail.blood_type || '—'" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Phone" :value="patientDetail.user?.phone || '—'" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="National ID" :value="patientDetail.national_id || '—'" /></v-col>
              <v-col cols="12" sm="6" md="4"><DetailField label="Insurance" :value="patientDetail.insurance_provider || '—'" /></v-col>
            </v-row>
            <v-divider class="my-3" />
            <DetailField label="Allergies" :value="(patientDetail.allergies || []).join(', ') || 'None'" full />
            <DetailField label="Chronic Conditions" :value="(patientDetail.chronic_conditions || []).join(', ') || 'None'" full />
            <DetailField label="Address" :value="patientDetail.address || '—'" full />
          </v-card>
          <div v-else-if="patientLoading" class="text-center py-6">
            <v-progress-circular indeterminate color="primary" size="40" />
          </div>
          <div v-else class="text-center py-6 text-medium-emphasis">
            <v-icon size="40" class="mb-2">mdi-account-question-outline</v-icon>
            <div class="text-body-2">Patient details unavailable</div>
          </div>
        </v-window-item>

        <!-- History Tab -->
        <v-window-item value="history">
          <div class="text-subtitle-2 font-weight-bold mb-3">
            <v-icon size="18" class="mr-1">mdi-history</v-icon> Patient's Appointment History
          </div>
          <v-timeline v-if="patientAppts.length" density="compact" side="end">
            <v-timeline-item v-for="a in patientAppts" :key="a.id" :dot-color="statusColor(a.status)" size="x-small">
              <div class="d-flex align-center justify-space-between flex-wrap ga-2">
                <div>
                  <div class="text-body-2 font-weight-medium">{{ formatDate(a.appointment_date) }} · {{ formatTime(a.appointment_time) }}</div>
                  <div class="text-caption text-medium-emphasis">{{ a.reason || 'No reason' }}</div>
                </div>
                <div class="d-flex align-center ga-2">
                  <StatusChip :status="a.status" />
                  <v-btn icon="mdi-eye" variant="text" size="x-small"
                         @click="navigateTo(`${basePath}/${a.id}`)" />
                </div>
              </div>
            </v-timeline-item>
          </v-timeline>
          <div v-else-if="historyLoading" class="text-center py-4">
            <v-progress-circular indeterminate color="primary" size="30" />
          </div>
          <div v-else class="text-center py-6 text-medium-emphasis">
            <v-icon size="40" class="mb-2">mdi-calendar-blank</v-icon>
            <div class="text-body-2">No other appointments for this patient</div>
          </div>
        </v-window-item>
      </v-window>
    </v-card>

    <!-- Not found -->
    <div v-if="!loading && !item" class="text-center py-12">
      <v-icon size="64" color="medium-emphasis" class="mb-3">mdi-calendar-question</v-icon>
      <h3 class="text-h6 text-medium-emphasis mb-2">Appointment not found</h3>
      <v-btn color="primary" variant="tonal" :to="backPath">Back to Appointments</v-btn>
    </div>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>

    <!-- Delete dialog -->
    <v-dialog v-model="deleteDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Appointment?</v-card-title>
        <v-card-text>
          Are you sure you want to delete this appointment for
          <strong>{{ item?.patient_name }}</strong>?
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="tonal" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const route = useRoute()
const router = useRouter()

const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')
const basePath = computed(() => `${ns.value}/appointments`)
const patientBase = computed(() => `${ns.value}/patients`)
const backPath = computed(() => basePath.value)
const editPath = computed(() => `${basePath.value}/${route.params.id}/edit`)
const patientLink = computed(() => item.value?.patient ? `${patientBase.value}/${item.value.patient}` : '#')

const r = useResource('/appointments/')
const patientsRes = useResource('/patients/')

const item = ref(null)
const loading = ref(true)
const tab = ref('overview')
const actionLoading = ref(false)
const patientDetail = ref(null)
const patientLoading = ref(false)
const patientAppts = ref([])
const historyLoading = ref(false)
const deleteDialog = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const statusMeta = {
  scheduled: 'info', confirmed: 'success', in_progress: 'blue',
  completed: 'success', cancelled: 'error', no_show: 'warning',
}

onMounted(async () => {
  await load()
})

async function load() {
  loading.value = true
  try {
    const data = await r.get(route.params.id)
    item.value = data
    if (data?.patient) {
      loadPatient(data.patient)
      loadHistory(data.patient)
    }
  } catch { /* ignore */ } finally {
    loading.value = false
  }
}

async function loadPatient(id) {
  patientLoading.value = true
  try {
    patientDetail.value = await patientsRes.get(id)
  } catch { /* ignore */ } finally { patientLoading.value = false }
}

async function loadHistory(patientId) {
  historyLoading.value = true
  try {
    await patientsRes.list()
    // use patient appointment list filtered by patient
    await r.list()
    patientAppts.value = r.items.value.filter(a => a.patient === patientId && a.id !== item.value?.id).slice(0, 10)
  } catch { /* ignore */ } finally { historyLoading.value = false }
}

/* Status actions */
const canConfirm = computed(() => item.value?.status === 'scheduled')
const canCheckIn = computed(() => ['scheduled', 'confirmed'].includes(item.value?.status))
const canComplete = computed(() => ['in_progress', 'confirmed', 'scheduled'].includes(item.value?.status))
const canNoShow = computed(() => ['scheduled', 'confirmed'].includes(item.value?.status))
const canCancel = computed(() => ['scheduled', 'confirmed', 'in_progress'].includes(item.value?.status))

async function quickStatus(status) {
  if (!item.value) return
  actionLoading.value = true
  try {
    await r.update(item.value.id, { status })
    item.value.status = status
    snack.text = `Status updated to ${status.replace(/_/g, ' ')}`
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = 'Failed to update status'
    snack.color = 'error'
    snack.show = true
  } finally {
    actionLoading.value = false
  }
}

function statusColor(s) { return statusMeta[s] || 'grey' }

function confirmDelete() { deleteDialog.value = true }
async function doDelete() {
  try {
    await r.remove(item.value.id)
    snack.text = 'Appointment deleted'
    snack.show = true
    setTimeout(() => router.push(basePath.value), 500)
  } catch {
    snack.text = 'Failed to delete'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleteDialog.value = false
  }
}

/* Helpers */
function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(s => s[0]).slice(0, 2).join('').toUpperCase()
}
function avatarColor(name) {
  const colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'orange']
  const h = (name || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0)
  return colors[h % colors.length]
}
function formatTime(t) {
  if (!t) return '—'
  return t.length === 5 ? t : new Date(`2000-01-01T${t}`).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
</script>

<style scoped>
.detail-section {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
</style>
