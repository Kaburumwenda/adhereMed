<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- Hero -->
    <v-card class="hc-rx-hero pa-5 mb-4 text-white" rounded="xl" :elevation="0">
      <div class="d-flex align-center ga-3 flex-wrap">
        <v-btn icon="mdi-arrow-left" variant="text" color="white" @click="goBack" />
        <v-avatar size="56" color="white" variant="flat">
          <v-icon icon="mdi-pill" color="teal-darken-2" size="32" />
        </v-avatar>
        <div class="flex-grow-1 min-w-0">
          <div class="text-overline" style="opacity:.8;">MEDICATION SCHEDULE</div>
          <div class="text-h5 font-weight-bold text-truncate">
            {{ schedule?.medication_name || (loading ? 'Loading…' : 'Schedule') }}
          </div>
          <div class="text-body-2" style="opacity:.9;">
            <v-icon icon="mdi-account" size="14" /> {{ schedule?.patient_name || '—' }}
            <span v-if="schedule?.dose" class="mx-1">·</span>
            <strong v-if="schedule?.dose">{{ schedule.dose }}</strong>
          </div>
        </div>
        <v-chip v-if="schedule" size="small" :color="schedule.is_active ? 'success' : 'grey'"
                variant="flat" class="text-white">
          {{ schedule.is_active ? 'Active' : 'Stopped' }}
        </v-chip>
        <v-btn variant="tonal" color="white" rounded="pill" prepend-icon="mdi-pencil"
               class="text-none" @click="onEdit">Edit</v-btn>
        <v-btn variant="flat" color="white" rounded="pill" prepend-icon="mdi-calendar-month"
               class="text-none" @click="onGenerate">
          <span class="text-teal-darken-2 font-weight-bold">Generate doses</span>
        </v-btn>
      </div>
      <div v-if="schedule" class="d-flex flex-wrap ga-2 mt-3">
        <v-chip color="white" variant="tonal" size="small">
          <v-icon icon="mdi-pill" size="14" class="mr-1" /> {{ routeLabel(schedule.route) }}
        </v-chip>
        <v-chip color="white" variant="tonal" size="small">
          <v-icon icon="mdi-calendar-start" size="14" class="mr-1" /> {{ fmtDate(schedule.start_date) }}
        </v-chip>
        <v-chip color="white" variant="tonal" size="small">
          <v-icon icon="mdi-calendar-end" size="14" class="mr-1" />
          {{ schedule.end_date ? fmtDate(schedule.end_date) : 'Ongoing' }}
        </v-chip>
        <v-chip v-if="schedule.requires_caregiver" color="warning" variant="flat" size="small">
          <v-icon icon="mdi-account-heart" size="14" class="mr-1" /> Caregiver-led
        </v-chip>
        <v-chip v-if="daysLeft !== null" :color="daysLeft <= 3 ? 'amber' : 'white'"
                variant="tonal" size="small">
          <v-icon icon="mdi-timer-sand" size="14" class="mr-1" />
          <template v-if="daysLeft > 0">{{ daysLeft }} day(s) left</template>
          <template v-else-if="daysLeft === 0">Ends today</template>
          <template v-else>Ended {{ -daysLeft }}d ago</template>
        </v-chip>
        <v-chip color="white" variant="tonal" size="small">
          <v-icon icon="mdi-clock-outline" size="14" class="mr-1" />
          {{ schedule.upcoming_doses || 0 }} upcoming
        </v-chip>
      </div>
    </v-card>

    <v-progress-linear v-if="loading" indeterminate color="teal" rounded class="mb-3" />

    <v-row v-if="schedule" dense>
      <!-- LEFT: details -->
      <v-col cols="12" lg="8">
        <!-- Overview -->
        <v-card class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-information-outline" size="18" /> Overview
          </div>
          <div class="hc-kv"><span>Medication</span><strong>{{ schedule.medication_name }}</strong></div>
          <div class="hc-kv"><span>Dose</span><strong>{{ schedule.dose || '—' }}</strong></div>
          <div class="hc-kv"><span>Route</span><strong>{{ routeLabel(schedule.route) }}</strong></div>
          <div class="hc-kv"><span>Patient</span><strong>{{ schedule.patient_name || '—' }}</strong></div>
          <div class="hc-kv">
            <span>Treatment plan</span>
            <strong>
              <v-chip v-if="schedule.treatment_plan" size="x-small" color="purple" variant="tonal">
                #{{ schedule.treatment_plan }}
              </v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </strong>
          </div>
          <div class="hc-kv"><span>Caregiver-led</span><strong>{{ schedule.requires_caregiver ? 'Yes' : 'No' }}</strong></div>
        </v-card>

        <!-- Schedule window -->
        <v-card class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-calendar-clock" size="18" /> Schedule window
          </div>
          <div class="hc-kv"><span>Start</span><strong>{{ fmtFullDate(schedule.start_date) }}</strong></div>
          <div class="hc-kv">
            <span>End</span>
            <strong>{{ schedule.end_date ? fmtFullDate(schedule.end_date) : 'Ongoing' }}</strong>
          </div>
          <div class="hc-kv">
            <span>Days remaining</span>
            <strong>
              <template v-if="daysLeft === null">Ongoing</template>
              <template v-else-if="daysLeft > 0">{{ daysLeft }} day(s)</template>
              <template v-else-if="daysLeft === 0">Ends today</template>
              <template v-else>Ended {{ -daysLeft }}d ago</template>
            </strong>
          </div>
          <div v-if="(schedule.times_of_day || []).length" class="hc-kv align-start">
            <span>Times of day</span>
            <div class="d-flex flex-wrap ga-1">
              <v-chip v-for="t in schedule.times_of_day" :key="t" size="small"
                      color="teal" variant="tonal">
                <v-icon icon="mdi-clock-outline" size="12" class="mr-1" /> {{ t }}
              </v-chip>
            </div>
          </div>
          <div v-if="schedule.frequency_cron" class="hc-kv">
            <span>Cron</span><code>{{ schedule.frequency_cron }}</code>
          </div>
        </v-card>

        <!-- Instructions -->
        <v-card v-if="schedule.instructions" class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-file-document-outline" size="18" /> Instructions
          </div>
          <p class="text-body-2 mb-0">{{ schedule.instructions }}</p>
        </v-card>

        <!-- Recent doses -->
        <v-card class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title d-flex align-center">
            <v-icon icon="mdi-history" size="18" />
            <span class="ml-1">Recent doses</span>
            <v-spacer />
            <v-chip size="x-small" color="teal" variant="tonal">{{ doses.length }} loaded</v-chip>
          </div>
          <div v-if="loadingDoses" class="text-center pa-4">
            <v-progress-circular indeterminate color="teal" />
          </div>
          <div v-else-if="doses.length">
            <div v-for="d in doses" :key="d.id"
                 class="hc-dose-row d-flex align-center ga-3 pa-2 mb-2 rounded-lg">
              <v-avatar size="34" :color="doseColor(d.status)" variant="tonal">
                <v-icon :icon="doseIcon(d.status)" size="16" />
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-bold">{{ fmtFullDateTime(d.scheduled_at) }}</div>
                <div class="text-caption text-medium-emphasis">
                  Status: <strong>{{ d.status }}</strong>
                  <template v-if="d.administered_at">
                    · Given {{ fmtFullDateTime(d.administered_at) }}
                  </template>
                  <template v-if="d.administered_by_name">
                    by {{ d.administered_by_name }}
                  </template>
                </div>
                <div v-if="d.notes" class="text-caption text-medium-emphasis">
                  <v-icon icon="mdi-message-outline" size="12" /> {{ d.notes }}
                </div>
              </div>
              <v-chip size="x-small" :color="doseColor(d.status)" variant="tonal">
                {{ d.status }}
              </v-chip>
            </div>
          </div>
          <EmptyState v-else icon="mdi-calendar-blank" title="No doses yet"
                      message="Generate doses for this schedule to see them here." />
        </v-card>
      </v-col>

      <!-- RIGHT: side panels -->
      <v-col cols="12" lg="4">
        <!-- Stats -->
        <v-card class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-chart-donut" size="18" /> Adherence
          </div>
          <div class="d-flex align-center ga-2 mb-2">
            <v-progress-circular :model-value="adherence" :size="64" :width="6"
                                 color="teal">
              <span class="font-weight-bold">{{ adherence }}%</span>
            </v-progress-circular>
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis">Doses on time</div>
              <div class="text-body-2"><strong>{{ doseStats.taken }}</strong> taken</div>
              <div class="text-body-2"><strong>{{ doseStats.missed }}</strong> missed</div>
              <div class="text-body-2"><strong>{{ doseStats.pending }}</strong> pending</div>
            </div>
          </div>
        </v-card>

        <!-- Audit -->
        <v-card class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-shield-check" size="18" /> Last generation
          </div>
          <v-alert v-if="lastGen" type="success" variant="tonal" density="compact" rounded="lg">
            <div class="font-weight-bold">
              {{ lastGen.count }} dose(s) ({{ lastGen.days }}d)
            </div>
            <div class="text-caption">
              By <strong>{{ lastGen.by }}</strong>
              <span v-if="lastGen.role" class="text-medium-emphasis">({{ lastGen.role }})</span><br>
              {{ fmtFullDateTime(lastGen.at) }}
            </div>
          </v-alert>
          <div v-else class="text-caption text-medium-emphasis">
            No generation recorded yet.
          </div>
        </v-card>

        <!-- Metadata -->
        <v-card class="hc-rx-section pa-4 mb-3" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-database" size="18" /> Metadata
          </div>
          <div class="hc-kv"><span>Schedule ID</span><code>#{{ schedule.id }}</code></div>
          <div class="hc-kv"><span>Created</span><strong>{{ fmtFullDateTime(schedule.created_at) }}</strong></div>
          <div class="hc-kv"><span>Updated</span><strong>{{ fmtFullDateTime(schedule.updated_at) }}</strong></div>
          <div v-if="schedule.prescribed_by_doctor_id" class="hc-kv">
            <span>Prescriber ID</span><code>#{{ schedule.prescribed_by_doctor_id }}</code>
          </div>
          <div v-if="schedule.source_prescription_id" class="hc-kv">
            <span>Source Rx</span><code>#{{ schedule.source_prescription_id }}</code>
          </div>
        </v-card>

        <!-- Danger zone -->
        <v-card class="hc-rx-section pa-4" rounded="xl" :elevation="0">
          <div class="hc-rx-section-title">
            <v-icon icon="mdi-cog" size="18" /> Actions
          </div>
          <v-btn block class="mb-2 text-none" rounded="lg"
                 :color="schedule.is_active ? 'warning' : 'success'"
                 variant="tonal"
                 :prepend-icon="schedule.is_active ? 'mdi-stop' : 'mdi-play'"
                 @click="toggleActive">
            {{ schedule.is_active ? 'Stop schedule' : 'Reactivate' }}
          </v-btn>
          <v-btn block class="text-none" rounded="lg" color="error" variant="tonal"
                 prepend-icon="mdi-delete" @click="confirmDelete">
            Delete schedule
          </v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- Generation acknowledgement -->
    <v-dialog v-model="genDialog" max-width="460" persistent>
      <v-card rounded="xl">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon icon="mdi-shield-key" color="teal" />
          Acknowledge dose generation
        </v-card-title>
        <v-card-text>
          <div class="text-body-2 mb-3">
            You are about to generate <strong>{{ genDays }} day(s)</strong> of doses for
            <strong>{{ schedule?.medication_name }}</strong>
            ({{ schedule?.dose }}) for
            <strong>{{ schedule?.patient_name }}</strong>.
          </div>
          <v-radio-group v-model="genDays" inline density="compact" hide-details class="mb-2">
            <v-radio :value="7"  label="7 days" />
            <v-radio :value="14" label="14 days" />
            <v-radio :value="30" label="30 days" />
          </v-radio-group>
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mb-3">
            Enter your unique staff PIN. It must match your account
            (<strong>{{ auth.fullName || auth.user?.email }}</strong>).
          </v-alert>
          <v-text-field v-model="genPin" label="Your staff PIN" type="password"
                        density="comfortable" variant="outlined" rounded="lg"
                        prepend-inner-icon="mdi-key" autofocus
                        inputmode="numeric" maxlength="12"
                        @keyup.enter="confirmGenerate" />
          <div class="text-caption text-medium-emphasis mt-1">
            <a href="#" @click.prevent="showMyPin = !showMyPin">
              {{ showMyPin ? 'Hide my PIN' : "Don't know your PIN? Reveal mine" }}
            </a>
            <span v-if="showMyPin && auth.user?.pin" class="ml-1">
              — <code>{{ auth.user.pin }}</code>
            </span>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="genBusy" @click="genDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 prepend-icon="mdi-check" :loading="genBusy" @click="confirmGenerate">
            Confirm & generate
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-alert" color="error" class="mr-1" /> Delete schedule?
        </v-card-title>
        <v-card-text>
          This permanently removes the schedule and any pending dose events.
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none"
                 :loading="deleting" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const id = computed(() => route.params.id)

const schedule = ref(null)
const doses = ref([])
const loading = ref(false)
const loadingDoses = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

// PIN-gated generation
const genDialog = ref(false)
const genDays = ref(7)
const genPin = ref('')
const genBusy = ref(false)
const showMyPin = ref(false)
const lastGen = ref(null)

const routeOptions = [
  { value: 'oral',    title: 'Oral' },
  { value: 'iv',      title: 'IV' },
  { value: 'im',      title: 'Intramuscular' },
  { value: 'sc',      title: 'Subcutaneous' },
  { value: 'topical', title: 'Topical' },
  { value: 'inhaled', title: 'Inhaled' },
  { value: 'sublingual', title: 'Sublingual' },
  { value: 'rectal',  title: 'Rectal' },
  { value: 'ophthalmic', title: 'Ophthalmic' },
  { value: 'otic',    title: 'Otic (ear)' },
  { value: 'nasal',   title: 'Nasal' },
  { value: 'vaginal', title: 'Vaginal' },
  { value: 'transdermal', title: 'Transdermal' },
  { value: 'other',   title: 'Other' }
]
function routeLabel(r) { return (routeOptions.find(o => o.value === r) || {}).title || r || '—' }

function doseColor(s) {
  return ({ taken: 'success', pending: 'info', missed: 'error',
            skipped: 'warning', refused: 'grey' })[s] || 'grey'
}
function doseIcon(s) {
  return ({ taken: 'mdi-check-circle', pending: 'mdi-clock-outline',
            missed: 'mdi-alert', skipped: 'mdi-skip-next',
            refused: 'mdi-cancel' })[s] || 'mdi-pill'
}
function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}
function fmtFullDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, {
    weekday: 'short', day: '2-digit', month: 'short', year: 'numeric'
  })
}
function fmtFullDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

const doseStats = computed(() => {
  const c = { taken: 0, pending: 0, missed: 0, skipped: 0, refused: 0 }
  doses.value.forEach(d => { c[d.status] = (c[d.status] || 0) + 1 })
  return c
})
const adherence = computed(() => {
  const total = doses.value.length
  if (!total) return 100
  return Math.round((doseStats.value.taken / total) * 100)
})

const daysLeft = computed(() => {
  if (!schedule.value?.end_date) return null
  const end = new Date(schedule.value.end_date)
  const today = new Date()
  end.setHours(0, 0, 0, 0)
  today.setHours(0, 0, 0, 0)
  return Math.round((end - today) / 86400000)
})

async function loadSchedule() {
  loading.value = true
  try {
    const { data } = await $api.get(`/homecare/medication-schedules/${id.value}/`)
    schedule.value = data
    if (data.last_generation_at) {
      lastGen.value = {
        at: data.last_generation_at,
        by: data.last_generation_by_name || 'Staff',
        role: data.last_generation_by_role || '',
        count: data.last_generation_count || 0,
        days: data.last_generation_days || 0,
      }
    }
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to load schedule'
    snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
async function loadDoses() {
  loadingDoses.value = true
  try {
    const { data } = await $api.get('/homecare/doses/', {
      params: { schedule: id.value, page_size: 200, ordering: 'scheduled_at' }
    })
    const list = data?.results || data || []
    // Server-side filter is preferred; keep client-side fallback for safety.
    const sid = Number(id.value)
    const filtered = list.filter(d => Number(d.schedule) === sid)
    // Ascending: oldest -> newest (e.g. May -> June). Cap at last 100 for UI.
    filtered.sort((a, b) => new Date(a.scheduled_at) - new Date(b.scheduled_at))
    doses.value = filtered.slice(-100)
  } catch { /* ignore */ }
  finally { loadingDoses.value = false }
}

onMounted(async () => {
  await loadSchedule()
  loadDoses()
})

function goBack() { router.push('/homecare/medications') }
function onEdit() {
  router.push({ path: '/homecare/medications/new', query: { id: id.value } })
}

function onGenerate() {
  genPin.value = ''
  showMyPin.value = false
  genDialog.value = true
}

async function confirmGenerate() {
  const pin = genPin.value.trim()
  if (!pin) {
    snack.text = 'Please enter your staff PIN'; snack.color = 'warning'; snack.show = true
    return
  }
  if (auth.user?.pin && pin !== auth.user.pin) {
    snack.text = 'PIN does not match the logged-in user'
    snack.color = 'error'; snack.show = true
    return
  }
  genBusy.value = true
  try {
    const { data } = await $api.post(
      `/homecare/medication-schedules/${id.value}/generate_doses/`,
      { days_ahead: genDays.value, pin }
    )
    const ack = data.acknowledged_by || {}
    lastGen.value = {
      at: data.acknowledged_at || new Date().toISOString(),
      by: ack.full_name || auth.fullName || 'Staff',
      role: ack.role || '',
      count: data.created || 0,
      days: genDays.value
    }
    snack.text = `Generated ${data.created || 0} dose(s) — acknowledged by ${lastGen.value.by}`
    snack.color = 'success'; snack.show = true
    genDialog.value = false
    loadDoses()
    loadSchedule()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to generate doses'
    snack.color = 'error'; snack.show = true
  } finally {
    genBusy.value = false
  }
}

async function toggleActive() {
  try {
    const { data } = await $api.patch(
      `/homecare/medication-schedules/${id.value}/`,
      { is_active: !schedule.value.is_active }
    )
    schedule.value = data
    snack.text = data.is_active ? 'Schedule reactivated' : 'Schedule stopped'
    snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Update failed'; snack.color = 'error'; snack.show = true
  }
}

function confirmDelete() { deleteDialog.value = true }
async function doDelete() {
  deleting.value = true
  try {
    await $api.delete(`/homecare/medication-schedules/${id.value}/`)
    snack.text = 'Schedule deleted'; snack.color = 'success'; snack.show = true
    deleteDialog.value = false
    setTimeout(() => router.push('/homecare/medications'), 600)
  } catch {
    snack.text = 'Delete failed'; snack.color = 'error'; snack.show = true
  } finally { deleting.value = false }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(124,58,237,0.05) 0%, rgba(13,148,136,0.05) 100%);
  min-height: calc(100vh - 64px);
}
.hc-rx-hero {
  background: linear-gradient(135deg, #0d9488 0%, #0f766e 100%);
  box-shadow: 0 12px 32px -16px rgba(13,148,136,0.45);
}
.hc-rx-section {
  background: rgba(255,255,255,0.95);
  border: 1px solid rgba(15,23,42,0.05);
}
.hc-rx-section-title {
  font-size: 0.78rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(15,23,42,0.55);
  margin-bottom: 10px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.hc-kv {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 0;
  border-bottom: 1px dashed rgba(15,23,42,0.08);
  font-size: 0.875rem;
}
.hc-kv:last-of-type { border-bottom: none; }
.hc-kv span { color: rgba(15,23,42,0.6); }
.hc-kv.align-start { align-items: flex-start; }
.hc-dose-row {
  background: rgba(241,245,249,0.6);
  transition: background .15s ease;
}
.hc-dose-row:hover { background: rgba(13,148,136,0.08); }

:global(.v-theme--dark) .hc-rx-section {
  background: rgba(30,41,59,0.7);
  border-color: rgba(255,255,255,0.06);
}
:global(.v-theme--dark) .hc-rx-section-title { color: rgba(255,255,255,0.7); }
:global(.v-theme--dark) .hc-kv { border-bottom-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark) .hc-kv span { color: rgba(255,255,255,0.6); }
:global(.v-theme--dark) .hc-dose-row { background: rgba(255,255,255,0.04); }
</style>
