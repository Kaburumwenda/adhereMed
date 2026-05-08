<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Teleconsult" icon="mdi-video" subtitle="Doctor virtual visits with your patients">
      <template #actions>
        <v-btn color="teal" rounded="lg" prepend-icon="mdi-video-plus" class="text-none" @click="openDialog">New session</v-btn>
      </template>
    </PageHeader>

    <v-row>
      <v-col cols="12" md="5">
        <v-card rounded="xl">
          <v-list>
            <v-list-item v-for="r in rooms" :key="r.id" :class="{'bg-teal-lighten-5': active?.id === r.id}"
              :title="r.patient_name"
              :subtitle="`${formatDate(r.scheduled_at)} · ${r.provider}`"
              @click="select(r)">
              <template #append><StatusChip :status="r.status" /></template>
            </v-list-item>
            <EmptyState v-if="!rooms.length" icon="mdi-video-off" title="No rooms yet" />
          </v-list>
        </v-card>
      </v-col>
      <v-col cols="12" md="7">
        <v-card rounded="xl" class="pa-4" style="min-height:520px;">
          <div v-if="!active" class="text-center text-medium-emphasis pa-8">
            <v-icon icon="mdi-video" size="64" />
            <div class="mt-2">Select a session to join.</div>
          </div>
          <div v-else>
            <div class="d-flex align-center mb-2">
              <h3 class="text-h6 font-weight-bold flex-grow-1">{{ active.patient_name }}</h3>
              <v-btn variant="tonal" color="teal" prepend-icon="mdi-video" class="text-none mr-2"
                     :loading="joining" @click="join">Join call</v-btn>
              <v-btn v-if="active.status === 'in_progress'" variant="tonal" color="error" prepend-icon="mdi-stop"
                     class="text-none" @click="endCall">End</v-btn>
            </div>
            <div v-if="joinUrl">
              <iframe :src="joinUrl" allow="camera; microphone; fullscreen; display-capture" allowfullscreen
                      style="width:100%; height:480px; border:0; border-radius:12px;" />
            </div>
            <div v-else class="text-medium-emphasis">Click "Join call" to launch the room in this window.</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="dialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title>New teleconsult session</v-card-title>
        <v-card-text>
          <v-select v-model="form.patient" :items="patients" item-title="name" item-value="id" label="Patient" />
          <v-text-field v-model="form.scheduled_at" label="Scheduled at" type="datetime-local" />
          <v-text-field v-model.number="form.duration_minutes" label="Duration (minutes)" type="number" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="create">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>
<script setup>
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $api } = useNuxtApp()
const rooms = ref([])
const active = ref(null)
const joinUrl = ref('')
const joining = ref(false)
const dialog = ref(false)
const saving = ref(false)
const patients = ref([])
const form = reactive({ patient: null, scheduled_at: '', duration_minutes: 30 })

async function load() {
  const { data } = await $api.get('/homecare/teleconsult-rooms/')
  rooms.value = data?.results || data || []
}
function select(r) { active.value = r; joinUrl.value = '' }
async function join() {
  joining.value = true
  try {
    const { data } = await $api.post(`/homecare/teleconsult-rooms/${active.value.id}/join/`)
    joinUrl.value = data.join_url
    active.value = { ...active.value, status: data.status }
    load()
  } finally { joining.value = false }
}
async function endCall() {
  await $api.post(`/homecare/teleconsult-rooms/${active.value.id}/end/`)
  joinUrl.value = ''
  load()
}
async function openDialog() {
  dialog.value = true
  if (!patients.value.length) {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = (data?.results || data || []).map(p => ({ id: p.id, name: p.patient_name }))
  }
}
async function create() {
  saving.value = true
  try {
    await $api.post('/homecare/teleconsult-rooms/', {
      patient: form.patient, scheduled_at: form.scheduled_at,
      duration_minutes: form.duration_minutes,
      doctor_user_id: auth.user?.id, provider: 'jitsi'
    })
    dialog.value = false
    load()
  } finally { saving.value = false }
}
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }
onMounted(load)
</script>
