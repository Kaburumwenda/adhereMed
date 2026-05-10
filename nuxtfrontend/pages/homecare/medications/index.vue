?<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Medication Schedules"
      subtitle="Active regimens, dosing windows and adherence at a glance."
      eyebrow="MEDICATIONS"
      icon="mdi-pill"
      :chips="[
        { icon: 'mdi-flash',          label: `${stats.active} active` },
        { icon: 'mdi-clock-outline',  label: `${todayDoses.length} doses today` },
        { icon: 'mdi-check-decagram', label: `${stats.adherence}% adherence` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-calendar-plus"
               class="text-none mr-2" :loading="generatingAll" @click="askGenerateAll">
          <span class="font-weight-bold">Generate doses</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-plus" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">New schedule</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- ───────────── Stats ───────────── -->
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
      <!-- ───────────── Schedules list ───────────── -->
      <v-col cols="12" lg="8">
        <HomecarePanel title="Regimens" subtitle="All medication schedules across your patients"
                       icon="mdi-clipboard-list" color="#7c3aed">
          <v-row dense class="mb-2">
            <v-col cols="12" md="4">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                            placeholder="Search medication, dose, patient…"
                            density="compact" variant="outlined" hide-details rounded="lg" />
            </v-col>
            <v-col cols="12" md="3">
              <v-autocomplete v-model="filterPatient" :items="patientOptions"
                              item-title="name" item-value="id"
                              label="Patient" density="compact" variant="outlined"
                              hide-details clearable rounded="lg" :loading="loadingPatients" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="filterRoute" :items="routeOptions" label="Route"
                        density="compact" variant="outlined" hide-details
                        clearable rounded="lg" />
            </v-col>
            <v-col cols="12" md="2">
              <v-btn-toggle v-model="filterActive" mandatory density="comfortable"
                            rounded="lg" color="teal" class="w-100">
                <v-btn value="all"    size="small">All</v-btn>
                <v-btn value="active" size="small">Active</v-btn>
              </v-btn-toggle>
            </v-col>
          </v-row>

          <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-2" rounded />

          <div v-if="filteredSchedules.length">
            <v-card v-for="s in filteredSchedules" :key="s.id"
                    class="hc-med-card mb-2" rounded="xl" :elevation="0">
              <div class="hc-med-band" :style="{ background: routeColor(s.route).hex }" />
              <div class="pa-4">
                <div class="d-flex align-center ga-3 mb-2">
                  <v-avatar size="44" :color="routeColor(s.route).vuetify" variant="tonal">
                    <v-icon icon="mdi-pill" />
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="d-flex align-center ga-2">
                      <div class="text-subtitle-1 font-weight-bold text-truncate">
                        {{ s.medication_name }}
                      </div>
                      <v-chip size="x-small" :color="routeColor(s.route).vuetify" variant="tonal">
                        {{ routeLabel(s.route) }}
                      </v-chip>
                      <v-chip v-if="s.requires_caregiver" size="x-small" color="warning" variant="tonal">
                        <v-icon icon="mdi-account-heart" size="12" class="mr-1" /> Caregiver
                      </v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      <v-icon icon="mdi-account" size="12" /> {{ s.patient_name }}
                      <span class="mx-1">·</span>
                      <strong>{{ s.dose }}</strong>
                      <span v-if="s.upcoming_doses != null" class="mx-1">·</span>
                      <span v-if="s.upcoming_doses != null">
                        <v-icon icon="mdi-clock-outline" size="12" />
                        {{ s.upcoming_doses }} upcoming
                      </span>
                    </div>
                  </div>
                  <v-chip size="small" :color="s.is_active ? 'success' : 'grey'" variant="tonal">
                    {{ s.is_active ? 'Active' : 'Stopped' }}
                  </v-chip>
                  <v-menu>
                    <template #activator="{ props: a }">
                      <v-btn v-bind="a" icon="mdi-dots-vertical" variant="text" size="small" />
                    </template>
                    <v-list density="compact">
                      <v-list-item prepend-icon="mdi-eye" title="View details"
                                   @click="openView(s)" />
                      <v-divider />
                      <v-list-item prepend-icon="mdi-calendar-plus" title="Generate 7 days"
                                   @click="askGenerate(s, 7)" />
                      <v-list-item prepend-icon="mdi-calendar-month" title="Generate 30 days"
                                   @click="askGenerate(s, 30)" />
                      <v-divider />
                      <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="openEdit(s)" />
                      <v-list-item v-if="s.is_active" prepend-icon="mdi-stop"
                                   title="Stop schedule" @click="toggleActive(s, false)" />
                      <v-list-item v-else prepend-icon="mdi-play" title="Reactivate"
                                   @click="toggleActive(s, true)" />
                      <v-divider />
                      <v-list-item prepend-icon="mdi-delete" title="Delete"
                                   base-color="error" @click="confirmDelete(s)" />
                    </v-list>
                  </v-menu>
                </div>

                <!-- times of day chips -->
                <div v-if="(s.times_of_day || []).length" class="d-flex flex-wrap ga-1 mb-2">
                  <v-chip v-for="t in s.times_of_day" :key="t" size="x-small"
                          color="teal" variant="tonal">
                    <v-icon icon="mdi-clock-outline" size="12" class="mr-1" /> {{ t }}
                  </v-chip>
                </div>
                <div v-else-if="s.frequency_cron" class="text-caption text-medium-emphasis mb-2">
                  <v-icon icon="mdi-repeat" size="12" class="mr-1" />
                  Cron: <code>{{ s.frequency_cron }}</code>
                </div>

                <div class="d-flex align-center ga-1 text-caption text-medium-emphasis">
                  <v-icon icon="mdi-calendar-start" size="12" /> {{ fmtDate(s.start_date) }}
                  <v-icon v-if="s.end_date" icon="mdi-arrow-right" size="12" class="mx-1" />
                  <span v-if="s.end_date">{{ fmtDate(s.end_date) }}</span>
                  <v-chip v-if="daysLeftFor(s) !== null" size="x-small" class="ml-2"
                          :color="daysLeftFor(s) <= 3 ? 'amber' : 'teal'" variant="tonal">
                    <v-icon icon="mdi-timer-sand" size="10" class="mr-1" />
                    <template v-if="daysLeftFor(s) > 0">{{ daysLeftFor(s) }}d left</template>
                    <template v-else-if="daysLeftFor(s) === 0">Ends today</template>
                    <template v-else>Ended</template>
                  </v-chip>
                  <v-spacer />
                  <v-btn size="x-small" variant="text" rounded="lg" class="text-none"
                         prepend-icon="mdi-calendar-plus" :loading="busyId === s.id"
                         @click="askGenerate(s, 7)">
                    Generate doses
                  </v-btn>
                </div>

                <!-- last generation audit chip -->
                <div v-if="genHistory[s.id]" class="mt-2">
                  <v-chip size="x-small" color="success" variant="tonal"
                          prepend-icon="mdi-check-decagram">
                    {{ genHistory[s.id].count }} dose(s) · {{ genHistory[s.id].days }}d ·
                    by {{ genHistory[s.id].by }} · {{ fmtWhen(genHistory[s.id].at) }}
                  </v-chip>
                </div>

                <p v-if="s.instructions" class="text-caption text-medium-emphasis mt-2 mb-0">
                  <v-icon icon="mdi-information" size="12" class="mr-1" />
                  {{ s.instructions }}
                </p>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-pill-off" title="No medication schedules"
                      message="Create the first regimen to start tracking doses." />
        </HomecarePanel>
      </v-col>

      <!-- ───────────── Today's doses ───────────── -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" class="hc-today-card pa-4 mb-3" :elevation="0">
          <div class="d-flex align-center ga-2 mb-1">
            <v-avatar size="40" color="white" variant="flat">
              <v-icon icon="mdi-calendar-today" color="indigo-darken-2" />
            </v-avatar>
            <div class="flex-grow-1 text-white">
              <div class="text-overline" style="opacity:.85;">TODAY</div>
              <div class="text-h6 font-weight-bold">{{ todayDoses.length }} doses</div>
            </div>
            <v-chip color="white" variant="flat" class="text-indigo-darken-2 font-weight-bold">
              {{ stats.adherence }}% on time
            </v-chip>
          </div>
          <v-progress-linear :model-value="stats.adherence" rounded height="8"
                             color="white" bg-color="white" bg-opacity="0.25" class="mt-2" />
          <div class="d-flex ga-3 mt-3 text-caption text-white-soft">
            <div><v-icon icon="mdi-check-circle" size="12" /> Taken {{ doseCounts.taken }}</div>
            <div><v-icon icon="mdi-clock-outline" size="12" /> Pending {{ doseCounts.pending }}</div>
            <div><v-icon icon="mdi-alert" size="12" /> Missed {{ doseCounts.missed }}</div>
          </div>
        </v-card>

        <HomecarePanel title="Today's dose timeline" icon="mdi-timeline-clock"
                       color="#0284c7">
          <div v-if="loadingToday" class="pa-4 text-center">
            <v-progress-circular indeterminate color="teal" />
          </div>
          <div v-else-if="todayDoses.length">
            <div v-for="d in todayDoses" :key="d.id"
                 class="hc-dose-row d-flex align-center ga-3 pa-2 mb-2 rounded-lg">
              <div class="hc-dose-time text-caption font-weight-bold">
                {{ fmtTime(d.scheduled_at) }}
              </div>
              <v-avatar size="32" :color="doseColor(d.status)" variant="tonal">
                <v-icon :icon="doseIcon(d.status)" size="16" />
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-bold text-truncate">
                  {{ d.medication_name }} · {{ d.dose }}
                </div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ d.patient_name }}
                </div>
              </div>
              <v-menu v-if="d.status === 'pending'">
                <template #activator="{ props: a }">
                  <v-btn v-bind="a" size="x-small" variant="tonal" color="teal"
                         icon="mdi-check" />
                </template>
                <v-list density="compact">
                  <v-list-item prepend-icon="mdi-check-circle" title="Mark taken"
                               @click="markDose(d, 'taken')" />
                  <v-list-item prepend-icon="mdi-skip-next" title="Mark skipped"
                               @click="markDose(d, 'skipped')" />
                  <v-list-item prepend-icon="mdi-alert" title="Mark missed"
                               @click="markDose(d, 'missed')" />
                </v-list>
              </v-menu>
              <v-chip v-else size="x-small" :color="doseColor(d.status)" variant="tonal">
                {{ d.status }}
              </v-chip>
            </div>
          </div>
          <EmptyState v-else icon="mdi-calendar-blank" title="No doses today"
                      message="Generate doses on a schedule to populate the timeline." />
        </HomecarePanel>
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
          <div v-if="genTarget" class="text-body-2 mb-3">
            You are about to generate <strong>{{ genDays }} day(s)</strong> of doses for
            <strong>{{ genTarget.medication_name }}</strong>
            ({{ genTarget.dose }}) for
            <strong>{{ genTarget.patient_name }}</strong>.
          </div>
          <div v-else class="text-body-2 mb-3">
            You are about to generate <strong>{{ genDays }} day(s)</strong> of doses for
            <strong>all active schedules</strong> ({{ activeCount }} regimen{{ activeCount === 1 ? '' : 's' }}).
          </div>
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mb-3">
            Enter your unique staff PIN to confirm. The PIN must match your account
            (signed in as <strong>{{ auth.fullName || auth.user?.email }}</strong>).
          </v-alert>
          <v-text-field v-model="genPin" label="Your staff PIN" type="password"
                        density="comfortable" variant="outlined" rounded="lg"
                        prepend-inner-icon="mdi-key" autofocus
                        inputmode="numeric" maxlength="12"
                        @keyup.enter="confirmGenerate" />
          <div class="text-caption text-medium-emphasis mt-1">
            <v-icon icon="mdi-information" size="12" />
            Don't know your PIN?
            <a href="#" @click.prevent="showMyPin = !showMyPin">
              {{ showMyPin ? 'Hide it' : 'Reveal mine' }}
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

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const schedules = ref([])
const patientOptions = ref([])
const todayDoses = ref([])

const loading = ref(false)
const loadingPatients = ref(false)
const loadingToday = ref(false)
const generatingAll = ref(false)
const deleting = ref(false)
const busyId = ref(null)

const search = ref('')
const filterPatient = ref(null)
const filterRoute = ref(null)
const filterActive = ref('active')

const deleteDialog = ref(false)
const toDelete = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })
const router = useRouter()
const auth = useAuthStore()

// View details dialog
// (View now opens the dedicated detail page /homecare/medications/:id)

// Generate-doses acknowledgement
const genDialog = ref(false)
const genTarget = ref(null)   // null = bulk mode
const genDays = ref(7)
const genPin = ref('')
const genBusy = ref(false)
const showMyPin = ref(false)

const activeCount = computed(() => schedules.value.filter(s => s.is_active).length)

// Map<scheduleId, { at, by, count, days }> — client-side audit for this session
const genHistory = reactive({})

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

// ─────── data
async function loadSchedules() {
  loading.value = true
  try {
    const params = { page_size: 200 }
    if (filterActive.value === 'active') params.is_active = true
    const { data } = await $api.get('/homecare/medication-schedules/', { params })
    schedules.value = data?.results || data || []
    // Hydrate generation history from persisted fields
    for (const s of schedules.value) {
      if (s.last_generation_at) {
        genHistory[s.id] = {
          at: s.last_generation_at,
          by: s.last_generation_by_name || 'Staff',
          count: s.last_generation_count || 0,
          days: s.last_generation_days || 0,
        }
      }
    }
  } catch {
    snack.text = 'Failed to load schedules'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
async function loadPatients() {
  loadingPatients.value = true
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 200 } })
    const items = data?.results || data || []
    patientOptions.value = items.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'}${p.medical_record_number ? ' · ' + p.medical_record_number : ''}`,
      primary_diagnosis: p.primary_diagnosis || ''
    }))
  } catch { /* ignore */ }
  finally { loadingPatients.value = false }
}
async function loadToday() {
  loadingToday.value = true
  try {
    const { data } = await $api.get('/homecare/doses/today/')
    const list = Array.isArray(data) ? data : data?.results || []
    todayDoses.value = list.sort((a, b) =>
      new Date(a.scheduled_at) - new Date(b.scheduled_at))
  } catch { /* ignore */ }
  finally { loadingToday.value = false }
}

onMounted(() => { loadSchedules(); loadPatients(); loadToday() })
watch(filterActive, loadSchedules)

// ─────── derived
const filteredSchedules = computed(() => {
  const q = search.value.trim().toLowerCase()
  return schedules.value.filter(s => {
    if (filterPatient.value && s.patient !== filterPatient.value) return false
    if (filterRoute.value && s.route !== filterRoute.value) return false
    if (!q) return true
    return [s.medication_name, s.dose, s.patient_name, s.instructions]
      .filter(Boolean).some(v => v.toLowerCase().includes(q))
  })
})

const doseCounts = computed(() => {
  const c = { taken: 0, pending: 0, missed: 0, skipped: 0 }
  todayDoses.value.forEach(d => { c[d.status] = (c[d.status] || 0) + 1 })
  return c
})

const stats = computed(() => {
  const list = schedules.value
  const total = todayDoses.value.length
  const taken = doseCounts.value.taken
  return {
    active: list.filter(s => s.is_active).length,
    paused: list.filter(s => !s.is_active).length,
    caregiver: list.filter(s => s.requires_caregiver).length,
    adherence: total ? Math.round((taken / total) * 100) : 100
  }
})

const summary = computed(() => [
  { label: 'Active schedules',  value: stats.value.active,    color: 'teal',    icon: 'mdi-flash' },
  { label: 'Stopped',           value: stats.value.paused,    color: 'grey',    icon: 'mdi-stop-circle' },
  { label: 'Caregiver-led',     value: stats.value.caregiver, color: 'warning', icon: 'mdi-account-heart' },
  { label: 'Doses today',       value: todayDoses.value.length, color: 'indigo', icon: 'mdi-clock-outline' }
])

// ─────── helpers
function routeLabel(r) {
  return (routeOptions.find(o => o.value === r) || {}).title || r
}
function routeColor(r) {
  const map = {
    oral:    { hex: '#0d9488', vuetify: 'teal' },
    iv:      { hex: '#dc2626', vuetify: 'error' },
    im:      { hex: '#ea580c', vuetify: 'deep-orange' },
    sc:      { hex: '#d97706', vuetify: 'amber' },
    topical: { hex: '#7c3aed', vuetify: 'purple' },
    inhaled: { hex: '#0284c7', vuetify: 'info' },
    other:   { hex: '#64748b', vuetify: 'grey' }
  }
  return map[r] || map.other
}
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
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short' })
}
function daysLeftFor(s) {
  if (!s?.end_date) return null
  const end = new Date(s.end_date); end.setHours(0, 0, 0, 0)
  const today = new Date(); today.setHours(0, 0, 0, 0)
  return Math.round((end - today) / 86400000)
}
function fmtTime(d) {
  if (!d) return ''
  return new Date(d).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
function fmtWhen(d) {
  if (!d) return ''
  const date = new Date(d)
  const diffMin = Math.round((Date.now() - date.getTime()) / 60000)
  if (diffMin < 1) return 'just now'
  if (diffMin < 60) return `${diffMin}m ago`
  if (diffMin < 1440) return `${Math.round(diffMin / 60)}h ago`
  return date.toLocaleDateString(undefined, { day: '2-digit', month: 'short' })
}
function fmtFull(d) {
  if (!d) return ''
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}
function currentActor(pin) {
  const name = auth.fullName || auth.user?.username || 'Staff'
  const idPart = pin ? ` (#${pin})` : ''
  return `${name}${idPart}`
}

// ─────── actions
function openCreate() {
  router.push('/homecare/medications/new')
}
function openEdit(s) {
  router.push({ path: '/homecare/medications/new', query: { id: s.id } })
}
function openView(s) {
  router.push(`/homecare/medications/${s.id}`)
}

// Show acknowledgement dialog before any per-schedule generation.
function askGenerate(s, days = 7) {
  genTarget.value = s
  genDays.value = days
  genPin.value = ''
  showMyPin.value = false
  genDialog.value = true
}

// Bulk variant: gate all-active generation behind the same PIN dialog.
function askGenerateAll(days = 7) {
  genTarget.value = null
  genDays.value = days
  genPin.value = ''
  showMyPin.value = false
  genDialog.value = true
}

async function confirmGenerate() {
  const pin = genPin.value.trim()
  if (!pin) {
    snack.text = 'Please enter your staff PIN to acknowledge'
    snack.color = 'warning'; snack.show = true
    return
  }
  // Local pre-check against the logged-in user's PIN (server still validates).
  if (auth.user?.pin && pin !== auth.user.pin) {
    snack.text = 'PIN does not match the logged-in user'
    snack.color = 'error'; snack.show = true
    return
  }
  genBusy.value = true
  try {
    if (genTarget.value) {
      await runGenerate(genTarget.value, genDays.value, pin)
    } else {
      await runGenerateAll(genDays.value, pin)
    }
    genDialog.value = false
  } finally {
    genBusy.value = false
  }
}

async function runGenerate(s, days, pin) {
  busyId.value = s.id
  try {
    const { data } = await $api.post(
      `/homecare/medication-schedules/${s.id}/generate_doses/`,
      { days_ahead: days, pin }
    )
    const count = data.created || 0
    const ack = data.acknowledged_by || {}
    genHistory[s.id] = {
      at: data.acknowledged_at || new Date().toISOString(),
      by: ack.full_name || currentActor(pin),
      count,
      days
    }
    snack.text = `Generated ${count} dose(s) over ${days} day(s) — acknowledged by ${ack.full_name || currentActor(pin)}`
    snack.color = 'success'; snack.show = true
    loadToday()
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Failed to generate doses'
    snack.text = msg; snack.color = 'error'; snack.show = true
    throw e
  } finally {
    busyId.value = null
  }
}

async function runGenerateAll(days, pin) {
  generatingAll.value = true
  let total = 0
  let firstAck = null
  const nowIso = new Date().toISOString()
  try {
    for (const s of schedules.value.filter(x => x.is_active)) {
      try {
        const { data } = await $api.post(
          `/homecare/medication-schedules/${s.id}/generate_doses/`,
          { days_ahead: days, pin }
        )
        const count = data.created || 0
        total += count
        const ack = data.acknowledged_by || {}
        if (!firstAck) firstAck = ack
        genHistory[s.id] = {
          at: data.acknowledged_at || nowIso,
          by: ack.full_name || currentActor(pin),
          count,
          days
        }
      } catch (inner) {
        // 403 on first call = bad PIN; abort the whole bulk run.
        if (inner?.response?.status === 403) {
          throw inner
        }
      }
    }
    const who = firstAck?.full_name || currentActor(pin)
    snack.text = `Generated ${total} dose(s) across ${activeCount.value} schedule(s) — acknowledged by ${who}`
    snack.color = 'success'; snack.show = true
    loadToday()
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Bulk generation failed'
    snack.text = msg; snack.color = 'error'; snack.show = true
    throw e
  } finally {
    generatingAll.value = false
  }
}

async function toggleActive(s, value) {
  try {
    const { data } = await $api.patch(
      `/homecare/medication-schedules/${s.id}/`, { is_active: value }
    )
    const i = schedules.value.findIndex(x => x.id === s.id)
    if (i >= 0) schedules.value.splice(i, 1, data)
    snack.text = value ? 'Schedule reactivated' : 'Schedule stopped'
    snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Update failed'; snack.color = 'error'; snack.show = true
  }
}

function confirmDelete(s) { toDelete.value = s; deleteDialog.value = true }
async function doDelete() {
  if (!toDelete.value) return
  deleting.value = true
  try {
    await $api.delete(`/homecare/medication-schedules/${toDelete.value.id}/`)
    schedules.value = schedules.value.filter(s => s.id !== toDelete.value.id)
    snack.text = 'Schedule deleted'; snack.color = 'success'; snack.show = true
    deleteDialog.value = false
  } catch {
    snack.text = 'Delete failed'; snack.color = 'error'; snack.show = true
  } finally { deleting.value = false }
}

async function markDose(d, status) {
  try {
    await $api.post(`/homecare/doses/${d.id}/mark_${status}/`, {})
    const i = todayDoses.value.findIndex(x => x.id === d.id)
    if (i >= 0) todayDoses.value[i] = { ...todayDoses.value[i], status }
    snack.text = `Dose marked ${status}`; snack.color = doseColor(status)
    snack.show = true
  } catch {
    snack.text = 'Failed to update dose'; snack.color = 'error'; snack.show = true
  }
}
</script>

<style scoped>
.hc-kv {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 6px 0;
  border-bottom: 1px dashed rgba(15,23,42,0.08);
  font-size: 0.875rem;
}
.hc-kv:last-of-type { border-bottom: none; }
.hc-kv span { color: rgba(15,23,42,0.6); }
.hc-bg {
  background: linear-gradient(135deg, rgba(124,58,237,0.05) 0%, rgba(13,148,136,0.05) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
  transition: transform .15s ease, box-shadow .15s ease;
}
.hc-stat:hover { transform: translateY(-2px); box-shadow: 0 10px 28px -16px rgba(15,23,42,0.25); }

.hc-med-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
  transition: transform .12s ease, box-shadow .12s ease;
}
.hc-med-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 14px 28px -18px rgba(15,23,42,0.25);
}
.hc-med-band {
  position: absolute; left: 0; top: 0; bottom: 0;
  width: 4px;
}

.hc-today-card {
  background: linear-gradient(135deg,#6366f1 0%,#4338ca 100%);
  color: white;
  box-shadow: 0 18px 40px -18px rgba(67,56,202,0.55);
}
.text-white-soft { color: rgba(255,255,255,0.82) !important; }

.hc-form-hero { background: linear-gradient(135deg,#7c3aed 0%,#6d28d9 100%); }

/* New schedule dialog */
.hc-rx-hero {
  background: linear-gradient(135deg,#7c3aed 0%,#6d28d9 60%,#4f46e5 100%);
}
.hc-rx-section + .hc-rx-section {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px dashed rgba(15,23,42,0.08);
}
.hc-rx-section-title {
  display: flex; align-items: center;
  font-size: 12px; font-weight: 700;
  letter-spacing: 0.06em; text-transform: uppercase;
  color: rgba(15,23,42,0.7);
  margin-bottom: 8px;
}
.hc-chip-pick { cursor: pointer; transition: transform .1s ease; }
.hc-chip-pick:hover { transform: translateY(-1px); }

.hc-dose-row { background: rgba(15,23,42,0.03); }
.hc-dose-time {
  width: 56px; flex-shrink: 0;
  font-variant-numeric: tabular-nums;
  color: var(--v-theme-on-surface, inherit);
}

:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-med-card {
  background: rgba(30,41,59,0.7);
  border-color: rgba(255,255,255,0.06);
}
:global(.v-theme--dark) .hc-dose-row { background: rgba(255,255,255,0.04); }
:global(.v-theme--dark) .hc-rx-section + .hc-rx-section {
  border-top-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark) .hc-rx-section-title { color: rgba(255,255,255,0.75); }
</style>
