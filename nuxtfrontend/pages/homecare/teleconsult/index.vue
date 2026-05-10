<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Teleconsult"
      subtitle="Virtual visits between doctors and homecare patients."
      eyebrow="VIRTUAL CARE"
      icon="mdi-video"
      :chips="[
        { icon: 'mdi-calendar-clock', label: `${stats.upcoming} upcoming` },
        { icon: 'mdi-broadcast',      label: `${stats.live} live` },
        { icon: 'mdi-check-decagram', label: `${stats.completed} completed` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-video-plus" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">New session</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="44" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <!-- Sessions list -->
      <v-col cols="12" md="5">
        <HomecarePanel title="Sessions" subtitle="All scheduled and past visits"
                       icon="mdi-format-list-bulleted" color="#0d9488">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search patient…" density="compact"
                        variant="outlined" hide-details rounded="lg" class="mb-2" />
          <v-btn-toggle v-model="filterStatus" mandatory density="comfortable"
                        rounded="lg" color="teal" class="w-100 mb-2">
            <v-btn value="all"         size="small">All</v-btn>
            <v-btn value="scheduled"   size="small">Scheduled</v-btn>
            <v-btn value="in_progress" size="small">Live</v-btn>
            <v-btn value="ended"       size="small">Past</v-btn>
          </v-btn-toggle>

          <div v-if="loading" class="pa-6 text-center">
            <v-progress-circular indeterminate color="teal" />
          </div>
          <v-list v-else lines="two" class="bg-transparent pa-0" density="comfortable">
            <v-list-item v-for="r in filteredRooms" :key="r.id" rounded="lg"
                         class="hc-room-row mb-1"
                         :class="{ 'hc-room-active': active?.id === r.id }"
                         @click="select(r)">
              <template #prepend>
                <v-avatar size="40" :color="statusColor(r.status)" variant="tonal">
                  <v-icon :icon="statusIcon(r.status)" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ r.patient_name }}</v-list-item-title>
              <v-list-item-subtitle>
                {{ formatDateTime(r.scheduled_at) }} · {{ r.provider }}
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="statusColor(r.status)" variant="tonal">
                  {{ r.status.replace('_', ' ') }}
                </v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!filteredRooms.length" icon="mdi-video-off"
                        title="No sessions" message="Create one to start." />
          </v-list>
        </HomecarePanel>
      </v-col>

      <!-- Active session -->
      <v-col cols="12" md="7">
        <v-card v-if="!active" class="hc-empty-card pa-8 text-center" rounded="xl"
                :elevation="0" min-height="520">
          <v-icon icon="mdi-video" size="80" color="teal" />
          <h3 class="text-h6 font-weight-bold mt-3">Select a session</h3>
          <p class="text-body-2 text-medium-emphasis">
            Pick a session from the list to view details and join the call.
          </p>
        </v-card>

        <v-card v-else rounded="xl" class="hc-detail-card overflow-hidden" :elevation="0">
          <div class="hc-detail-hero pa-5 text-white"
               :style="{ background: detailGradient(active.status) }">
            <div class="d-flex align-center ga-3">
              <v-avatar size="56" color="white" variant="flat">
                <v-icon :icon="statusIcon(active.status)"
                        :color="statusColor(active.status)" size="28" />
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="text-overline" style="opacity:.85;">
                  {{ active.status.replace('_', ' ').toUpperCase() }} · {{ active.provider.toUpperCase() }}
                </div>
                <h2 class="text-h5 font-weight-bold ma-0 text-truncate">
                  {{ active.patient_name }}
                </h2>
                <div class="text-body-2" style="opacity:.85;">
                  <v-icon icon="mdi-calendar-clock" size="14" />
                  {{ formatDateTime(active.scheduled_at) }}
                  · {{ active.duration_minutes }} min
                </div>
              </div>
            </div>
            <div class="d-flex flex-wrap ga-2 mt-3">
              <v-btn v-if="active.status !== 'ended' && active.status !== 'cancelled'"
                     variant="flat" color="white" rounded="lg" class="text-none text-teal-darken-2"
                     prepend-icon="mdi-video" :loading="joining" @click="join">Join call</v-btn>
              <v-btn v-if="active.status === 'in_progress'" variant="outlined"
                     color="white" rounded="lg" class="text-none"
                     prepend-icon="mdi-stop" @click="endCall">End</v-btn>
              <v-spacer />
              <v-btn v-if="active.status === 'scheduled'" variant="outlined" color="white"
                     rounded="lg" class="text-none" prepend-icon="mdi-cancel"
                     @click="cancelSession">Cancel</v-btn>
              <v-btn variant="text" color="white" rounded="lg" class="text-none"
                     prepend-icon="mdi-content-copy" @click="copyLink">Copy link</v-btn>
            </div>
          </div>

          <v-card-text class="pa-5">
            <div v-if="joinUrl" class="mb-4">
              <iframe :src="joinUrl" allow="camera; microphone; fullscreen; display-capture"
                      allowfullscreen
                      style="width:100%; height:480px; border:0; border-radius:16px;
                             box-shadow: 0 16px 36px -20px rgba(15,23,42,0.4);" />
            </div>
            <div v-else class="hc-info-block pa-4 mb-4 rounded-lg">
              <div class="d-flex align-center ga-2 mb-2">
                <v-icon icon="mdi-link" color="teal" />
                <div class="text-body-2 font-weight-bold">Meeting room</div>
              </div>
              <code class="text-caption">{{ buildJoinUrl(active) || '—' }}</code>
              <div class="text-caption text-medium-emphasis mt-2">
                Click "Join call" to launch the room in this window.
              </div>
            </div>

            <v-row dense>
              <v-col cols="12" md="6">
                <div class="hc-info-row">
                  <div class="text-caption text-medium-emphasis">Patient</div>
                  <div class="text-body-2 font-weight-bold">{{ active.patient_name }}</div>
                </div>
                <div class="hc-info-row">
                  <div class="text-caption text-medium-emphasis">Provider</div>
                  <div class="text-body-2 font-weight-bold">{{ active.provider }}</div>
                </div>
              </v-col>
              <v-col cols="12" md="6">
                <div class="hc-info-row">
                  <div class="text-caption text-medium-emphasis">Started</div>
                  <div class="text-body-2 font-weight-bold">
                    {{ active.started_at ? formatDateTime(active.started_at) : '—' }}
                  </div>
                </div>
                <div class="hc-info-row">
                  <div class="text-caption text-medium-emphasis">Ended</div>
                  <div class="text-body-2 font-weight-bold">
                    {{ active.ended_at ? formatDateTime(active.ended_at) : '—' }}
                  </div>
                </div>
              </v-col>
            </v-row>

            <v-divider class="my-4" />
            <h4 class="text-subtitle-1 font-weight-bold mb-2">
              <v-icon icon="mdi-note-text" color="indigo" class="mr-1" /> Visit summary
            </h4>
            <v-textarea v-model="summaryNotes" rows="3" auto-grow variant="outlined"
                        density="comfortable" rounded="lg"
                        placeholder="Subjective findings, plan, follow-up…" />
            <div class="d-flex ga-2 mt-2">
              <v-spacer />
              <v-btn variant="tonal" color="teal" rounded="lg" class="text-none"
                     prepend-icon="mdi-content-save" :loading="savingSummary"
                     @click="saveSummary">Save summary</v-btn>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- New session dialog -->
    <v-dialog v-model="dialog" max-width="640" scrollable persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-video-plus" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">SCHEDULE</div>
              <h3 class="text-h6 ma-0">New teleconsult session</h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="dialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="create">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.patient" :items="patients"
                                item-title="name" item-value="id"
                                label="Patient *" variant="outlined" density="comfortable"
                                rounded="lg" prepend-inner-icon="mdi-account"
                                :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.scheduled_at" label="Scheduled at *"
                              type="datetime-local" variant="outlined"
                              density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-calendar-clock"
                              :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="6">
                <v-text-field v-model.number="form.duration_minutes" label="Duration (min)"
                              type="number" variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-timer" />
              </v-col>
              <v-col cols="6">
                <v-select v-model="form.provider" :items="providerOptions"
                          label="Provider" variant="outlined" density="comfortable"
                          rounded="lg" prepend-inner-icon="mdi-broadcast" />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="form.doctor_user_id" label="Doctor user ID"
                              type="number" variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-doctor"
                              hint="Internal user ID of the consulting doctor"
                              persistent-hint />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-check" @click="create">
            Create session
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const rooms = ref([])
const patients = ref([])
const active = ref(null)
const joinUrl = ref('')
const summaryNotes = ref('')
const search = ref('')
const filterStatus = ref('all')
const loading = ref(false)
const joining = ref(false)
const saving = ref(false)
const savingSummary = ref(false)

const dialog = ref(false)
const formRef = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

const providerOptions = [
  { value: 'jitsi', title: 'Jitsi' },
  { value: 'twilio', title: 'Twilio' },
  { value: 'internal_webrtc', title: 'Internal WebRTC' }
]
const blank = () => ({
  patient: null,
  scheduled_at: new Date(Date.now() + 3600000).toISOString().slice(0, 16),
  duration_minutes: 30, provider: 'jitsi', doctor_user_id: null
})
const form = reactive(blank())

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/teleconsult-rooms/', { params: { page_size: 200 } })
    rooms.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load sessions'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 200 } })
    const items = data?.results || data || []
    patients.value = items.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'}${p.medical_record_number ? ' · ' + p.medical_record_number : ''}`
    }))
  } catch { /* ignore */ }
}
onMounted(() => { load(); loadPatients() })

const filteredRooms = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rooms.value.filter(r => {
    if (filterStatus.value !== 'all' && r.status !== filterStatus.value) return false
    if (!q) return true
    return (r.patient_name || '').toLowerCase().includes(q)
  })
})

const stats = computed(() => {
  const list = rooms.value
  return {
    upcoming: list.filter(r => r.status === 'scheduled').length,
    live:      list.filter(r => r.status === 'in_progress').length,
    completed: list.filter(r => r.status === 'ended').length,
    cancelled: list.filter(r => r.status === 'cancelled').length
  }
})
const summary = computed(() => [
  { label: 'Upcoming',  value: stats.value.upcoming,  color: 'teal',    icon: 'mdi-calendar-clock' },
  { label: 'Live now',  value: stats.value.live,      color: 'success', icon: 'mdi-broadcast' },
  { label: 'Completed', value: stats.value.completed, color: 'info',    icon: 'mdi-check-decagram' },
  { label: 'Cancelled', value: stats.value.cancelled, color: 'grey',    icon: 'mdi-cancel' }
])
watch(active, (v) => { summaryNotes.value = v?.summary || '' })

function statusColor(s) {
  return ({ scheduled: 'teal', in_progress: 'success',
            ended: 'info', cancelled: 'grey' })[s] || 'grey'
}
function statusIcon(s) {
  return ({ scheduled: 'mdi-calendar-clock', in_progress: 'mdi-broadcast',
            ended: 'mdi-check-decagram', cancelled: 'mdi-cancel' })[s] || 'mdi-video'
}
function detailGradient(s) {
  return ({
    scheduled:   'linear-gradient(135deg,#0d9488 0%,#0f766e 100%)',
    in_progress: 'linear-gradient(135deg,#10b981 0%,#059669 100%)',
    ended:       'linear-gradient(135deg,#0ea5e9 0%,#0284c7 100%)',
    cancelled:   'linear-gradient(135deg,#64748b 0%,#475569 100%)'
  })[s] || 'linear-gradient(135deg,#0d9488 0%,#0f766e 100%)'
}
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
  })
}
function buildJoinUrl(r) {
  return r?.join_url || (r?.provider === 'jitsi' && r?.room_token
    ? `https://meet.jit.si/AfyaOne-${r.room_token}` : '')
}

function select(r) { active.value = r; joinUrl.value = '' }
function openCreate() { Object.assign(form, blank()); dialog.value = true }
async function create() {
  const v = await formRef.value?.validate()
  if (v && v.valid === false) return
  saving.value = true
  try {
    const { data } = await $api.post('/homecare/teleconsult-rooms/', form)
    rooms.value.unshift(data)
    select(data)
    dialog.value = false
    snack.text = 'Session created'; snack.color = 'success'; snack.show = true
  } catch (e) {
    const msg = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Create failed'
    snack.text = msg; snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}
async function join() {
  if (!active.value) return
  joining.value = true
  try {
    const { data } = await $api.post(`/homecare/teleconsult-rooms/${active.value.id}/join/`)
    joinUrl.value = data.join_url
    active.value = { ...active.value, status: data.status }
    load()
  } catch {
    snack.text = 'Could not start the room'; snack.color = 'error'; snack.show = true
  } finally { joining.value = false }
}
async function endCall() {
  if (!active.value) return
  try {
    await $api.post(`/homecare/teleconsult-rooms/${active.value.id}/end/`,
      { summary: summaryNotes.value })
    joinUrl.value = ''
    snack.text = 'Session ended'; snack.color = 'info'; snack.show = true
    load()
  } catch {
    snack.text = 'End failed'; snack.color = 'error'; snack.show = true
  }
}
async function cancelSession() {
  if (!active.value) return
  try {
    const { data } = await $api.patch(
      `/homecare/teleconsult-rooms/${active.value.id}/`, { status: 'cancelled' })
    const i = rooms.value.findIndex(r => r.id === active.value.id)
    if (i >= 0) rooms.value.splice(i, 1, data)
    active.value = data
    snack.text = 'Session cancelled'; snack.color = 'warning'; snack.show = true
  } catch {
    snack.text = 'Cancel failed'; snack.color = 'error'; snack.show = true
  }
}
async function saveSummary() {
  if (!active.value) return
  savingSummary.value = true
  try {
    const { data } = await $api.patch(
      `/homecare/teleconsult-rooms/${active.value.id}/`, { summary: summaryNotes.value })
    const i = rooms.value.findIndex(r => r.id === active.value.id)
    if (i >= 0) rooms.value.splice(i, 1, data)
    active.value = data
    snack.text = 'Summary saved'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Save failed'; snack.color = 'error'; snack.show = true
  } finally { savingSummary.value = false }
}
function copyLink() {
  const url = buildJoinUrl(active.value)
  if (!url) return
  navigator.clipboard?.writeText(url)
  snack.text = 'Link copied'; snack.color = 'info'; snack.show = true
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
}
.hc-room-row {
  background: rgba(15,23,42,0.03);
  cursor: pointer;
}
.hc-room-row:hover { background: rgba(13,148,136,0.07); }
.hc-room-active { background: rgba(13,148,136,0.12) !important; }
.hc-empty-card {
  background: rgba(255,255,255,0.75);
  border: 1px dashed rgba(15,23,42,0.12);
}
.hc-detail-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
.hc-form-hero { background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%); }
.hc-info-row { padding: 8px 0; border-bottom: 1px dashed rgba(15,23,42,0.08); }
.hc-info-block {
  background: rgba(13,148,136,0.06);
  border: 1px dashed rgba(13,148,136,0.3);
}
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-detail-card { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
:global(.v-theme--dark) .hc-room-row { background: rgba(255,255,255,0.04); }
</style>
