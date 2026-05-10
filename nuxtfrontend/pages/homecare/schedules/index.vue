<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- Hero -->
    <HomecareHero
      title="Schedules"
      subtitle="Plan, dispatch and track every caregiver visit in real time."
      eyebrow="HOMECARE · OPERATIONS"
      icon="mdi-calendar-clock"
      :chips="[
        { icon: 'mdi-calendar-today',  label: `${kpis.today} today` },
        { icon: 'mdi-progress-clock',  label: `${kpis.inProgress} in progress` },
        { icon: 'mdi-check-decagram',  label: `${kpis.completedToday} completed` },
        { icon: 'mdi-calendar-arrow-right', label: `${kpis.upcoming} upcoming` },
        { icon: 'mdi-alert-octagon',   label: `${kpis.missed} missed` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-plus" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">New schedule</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- View tabs -->
    <v-card rounded="xl" elevation="0" class="mt-4 hc-card pa-2">
      <v-tabs v-model="view" align-tabs="start" color="teal"
              density="comfortable" class="hc-tabs">
        <v-tab value="day"><v-icon start icon="mdi-calendar-today" />Day</v-tab>
        <v-tab value="week"><v-icon start icon="mdi-calendar-week" />Week</v-tab>
        <v-tab value="list"><v-icon start icon="mdi-format-list-bulleted" />List</v-tab>
      </v-tabs>
    </v-card>

    <!-- Filter / nav bar -->
    <v-card rounded="xl" elevation="0" class="mt-3 pa-3 hc-card">
      <div class="d-flex flex-wrap align-center ga-2">
        <template v-if="view !== 'list'">
          <v-btn icon="mdi-chevron-left" variant="text" size="small" @click="navigate(-1)" />
          <v-btn variant="tonal" color="teal" rounded="lg" size="small"
                 class="text-none" @click="goToday">Today</v-btn>
          <v-btn icon="mdi-chevron-right" variant="text" size="small" @click="navigate(1)" />
          <div class="text-subtitle-1 font-weight-bold ml-2">{{ rangeLabel }}</div>
        </template>
        <v-text-field v-if="view === 'list'" v-model="search"
                      prepend-inner-icon="mdi-magnify"
                      placeholder="Search caregiver, patient, notes…"
                      density="comfortable" variant="outlined" hide-details rounded="lg"
                      style="max-width:340px;" clearable />
        <v-spacer />
        <v-select v-model="filters.caregiver" :items="caregiverOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Caregiver" style="max-width:220px;" />
        <v-select v-model="filters.patient" :items="patientOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Patient" style="max-width:220px;" />
        <v-select v-model="filters.status" :items="statusOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Status" style="max-width:180px;" />
        <v-select v-model="filters.shift_type" :items="shiftTypeOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Shift" style="max-width:160px;" />
        <v-btn variant="text" size="small" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </v-card>

    <!-- DAY VIEW -->
    <div v-if="view === 'day'" class="mt-3">
      <v-card rounded="xl" elevation="0" class="hc-card pa-0 overflow-hidden">
        <div class="hc-day-grid">
          <div class="hc-hours">
            <div v-for="h in HOURS" :key="h" class="hc-hour">
              <span class="text-caption text-medium-emphasis">{{ formatHour(h) }}</span>
            </div>
          </div>
          <div class="hc-day-col">
            <div v-for="h in HOURS" :key="h" class="hc-hour-line" />
            <div v-for="ev in dayEvents" :key="ev.id"
                 class="hc-event"
                 :style="eventStyle(ev)"
                 :class="`hc-ev-${ev.status}`"
                 @click="openDetail(ev)">
              <div class="d-flex align-center ga-1 mb-1">
                <v-icon :icon="STATUS_META[ev.status]?.icon" size="12" />
                <span class="text-caption font-weight-bold">
                  {{ formatTime(ev.start_at) }} – {{ formatTime(ev.end_at) }}
                </span>
              </div>
              <div class="text-body-2 font-weight-bold text-truncate">
                {{ ev.patient_name || 'Patient' }}
              </div>
              <div class="text-caption text-truncate" style="opacity:0.85;">
                <v-icon icon="mdi-account-heart" size="11" /> {{ ev.caregiver_name || '—' }}
              </div>
            </div>
            <v-progress-linear v-if="loading" indeterminate color="teal" class="position-absolute top-0" />
          </div>
        </div>
        <div v-if="!dayEvents.length && !loading" class="pa-6">
          <EmptyState icon="mdi-calendar-blank" title="No visits scheduled"
                      message="Adjust filters or create a new schedule." />
        </div>
      </v-card>
    </div>

    <!-- WEEK VIEW -->
    <div v-else-if="view === 'week'" class="mt-3">
      <v-card rounded="xl" elevation="0" class="hc-card pa-0 overflow-hidden">
        <div class="hc-week-head">
          <div class="hc-week-spacer"></div>
          <div v-for="d in weekDays" :key="d.iso" class="hc-week-day"
               :class="{ 'hc-week-today': d.isToday }">
            <div class="text-caption text-uppercase text-medium-emphasis">{{ d.weekday }}</div>
            <div class="text-h6 font-weight-bold">{{ d.day }}</div>
            <v-chip v-if="d.count" size="x-small" color="teal" variant="tonal" class="mt-1">
              {{ d.count }} visits
            </v-chip>
          </div>
        </div>
        <div class="hc-week-body">
          <div class="hc-hours">
            <div v-for="h in HOURS" :key="h" class="hc-hour">
              <span class="text-caption text-medium-emphasis">{{ formatHour(h) }}</span>
            </div>
          </div>
          <div v-for="d in weekDays" :key="d.iso" class="hc-day-col">
            <div v-for="h in HOURS" :key="h" class="hc-hour-line" />
            <div v-for="ev in d.events" :key="ev.id"
                 class="hc-event"
                 :style="eventStyle(ev)"
                 :class="`hc-ev-${ev.status}`"
                 @click="openDetail(ev)">
              <div class="text-caption font-weight-bold">
                {{ formatTime(ev.start_at) }}
              </div>
              <div class="text-caption text-truncate">{{ ev.patient_name }}</div>
            </div>
          </div>
        </div>
        <v-progress-linear v-if="loading" indeterminate color="teal" />
      </v-card>
    </div>

    <!-- LIST VIEW -->
    <v-card v-else rounded="xl" elevation="0" class="mt-3 hc-card">
      <v-data-table :items="filteredList" :headers="tableHeaders" item-value="id"
                    :loading="loading" class="hc-table">
        <template #[`item.when`]="{ item }">
          <div class="font-weight-medium">{{ formatDateTime(item.start_at) }}</div>
          <div class="text-caption text-medium-emphasis">
            → {{ formatTime(item.end_at) }} · {{ shiftLabel(item.shift_type) }}
          </div>
        </template>
        <template #[`item.caregiver_name`]="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="indigo" variant="flat">
              <span class="text-caption font-weight-bold text-white">
                {{ initials(item.caregiver_name) }}
              </span>
            </v-avatar>
            <div class="font-weight-medium">{{ item.caregiver_name || '—' }}</div>
          </div>
        </template>
        <template #[`item.patient_name`]="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="teal" variant="flat">
              <span class="text-caption font-weight-bold text-white">
                {{ initials(item.patient_name) }}
              </span>
            </v-avatar>
            <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
          </div>
        </template>
        <template #[`item.status`]="{ item }">
          <v-chip size="small" :color="STATUS_META[item.status]?.color" variant="tonal">
            <v-icon :icon="STATUS_META[item.status]?.icon" start size="14" />
            {{ STATUS_META[item.status]?.label }}
          </v-chip>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn v-if="item.status === 'scheduled'" icon="mdi-login-variant"
                 size="small" variant="text" color="teal"
                 @click.stop="quickAction(item, 'check_in')" />
          <v-btn v-if="item.status === 'checked_in'" icon="mdi-logout-variant"
                 size="small" variant="text" color="success"
                 @click.stop="quickAction(item, 'check_out')" />
          <v-btn icon="mdi-eye" size="small" variant="text" @click.stop="openDetail(item)" />
        </template>
      </v-data-table>
    </v-card>

    <!-- CREATE / EDIT dialog -->
    <v-dialog v-model="formDialog" max-width="720" scrollable>
      <v-card rounded="xl" class="pa-0">
        <div class="pa-4 d-flex align-center ga-2"
             :style="{ background: 'linear-gradient(135deg,#0d9488 0%,#14b8a6 100%)', color:'white' }">
          <v-icon :icon="editing ? 'mdi-calendar-edit' : 'mdi-calendar-plus'" />
          <div class="text-h6 font-weight-bold">
            {{ editing ? 'Edit schedule' : 'New schedule' }}
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" color="white" @click="formDialog = false" />
        </div>
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.caregiver" :items="caregiverOptions"
                        prepend-inner-icon="mdi-account-heart" label="Caregiver"
                        variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.patient" :items="patientOptions"
                        prepend-inner-icon="mdi-account-injury" label="Patient"
                        variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.start_at" type="datetime-local" label="Start"
                            prepend-inner-icon="mdi-clock-start"
                            variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.end_at" type="datetime-local" label="End"
                            prepend-inner-icon="mdi-clock-end"
                            variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.shift_type" :items="shiftTypeOptions" label="Shift type"
                        prepend-inner-icon="mdi-briefcase-clock"
                        variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.recurrenceMode" :items="recurrenceModes"
                        label="Recurrence" prepend-inner-icon="mdi-repeat"
                        variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col v-if="form.recurrenceMode === 'weekly'" cols="12">
              <div class="text-caption text-medium-emphasis mb-1">Repeat on</div>
              <v-btn-toggle v-model="form.byday" multiple color="teal" variant="outlined"
                            rounded="lg" density="comfortable">
                <v-btn v-for="d in WEEKDAYS" :key="d.value" :value="d.value"
                       size="small" class="text-none">{{ d.short }}</v-btn>
              </v-btn-toggle>
            </v-col>
            <v-col v-if="form.recurrenceMode !== 'none'" cols="12" md="6">
              <v-text-field v-model="form.until" type="date" label="Repeat until"
                            prepend-inner-icon="mdi-calendar-end"
                            variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2"
                          variant="outlined" rounded="lg" density="comfortable" auto-grow />
            </v-col>
          </v-row>
          <v-alert v-if="formError" type="error" variant="tonal" density="compact"
                   rounded="lg" class="mt-2">{{ formError }}</v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn v-if="editing" color="error" variant="text" prepend-icon="mdi-delete"
                 class="text-none" @click="removeSchedule">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="teal" rounded="lg" class="text-none" :loading="saving"
                 prepend-icon="mdi-content-save" @click="save">
            {{ editing ? 'Save' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- DETAIL dialog -->
    <v-dialog v-model="detailDialog" max-width="640">
      <v-card v-if="selected" rounded="xl" class="pa-0">
        <div class="pa-4 d-flex align-center ga-2"
             :style="{ background: STATUS_META[selected.status]?.gradient, color:'white' }">
          <v-icon :icon="STATUS_META[selected.status]?.icon" />
          <div>
            <div class="text-overline" style="opacity:0.85;">
              {{ STATUS_META[selected.status]?.label }} · {{ shiftLabel(selected.shift_type) }}
            </div>
            <div class="text-h6 font-weight-bold">
              {{ formatDateTime(selected.start_at) }} – {{ formatTime(selected.end_at) }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" color="white" @click="detailDialog = false" />
        </div>
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Caregiver</div>
              <div class="font-weight-medium">{{ selected.caregiver_name || '—' }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Patient</div>
              <div class="font-weight-medium">{{ selected.patient_name || '—' }}</div>
            </v-col>
            <v-col v-if="selected.check_in_at" cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Checked in</div>
              <div class="font-weight-medium">{{ formatDateTime(selected.check_in_at) }}</div>
              <div v-if="selected.gps_check_in?.lat" class="text-caption text-medium-emphasis">
                <v-icon icon="mdi-map-marker" size="12" />
                {{ selected.gps_check_in.lat.toFixed(4) }}, {{ selected.gps_check_in.lng.toFixed(4) }}
              </div>
            </v-col>
            <v-col v-if="selected.check_out_at" cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Checked out</div>
              <div class="font-weight-medium">{{ formatDateTime(selected.check_out_at) }}</div>
              <div v-if="selected.check_in_at" class="text-caption text-medium-emphasis">
                Duration: {{ duration(selected.check_in_at, selected.check_out_at) }}
              </div>
            </v-col>
            <v-col v-if="selected.notes" cols="12">
              <div class="text-caption text-medium-emphasis">Notes</div>
              <div class="text-body-2" style="white-space: pre-wrap;">{{ selected.notes }}</div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3 flex-wrap ga-1">
          <v-btn v-if="selected.status === 'scheduled'" color="teal" variant="tonal" rounded="lg"
                 class="text-none" prepend-icon="mdi-login-variant"
                 :loading="acting" @click="doAction('check_in')">Check-in</v-btn>
          <v-btn v-if="selected.status === 'checked_in'" color="success" variant="tonal" rounded="lg"
                 class="text-none" prepend-icon="mdi-logout-variant"
                 :loading="acting" @click="doAction('check_out')">Check-out</v-btn>
          <v-btn v-if="['scheduled','checked_in'].includes(selected.status)"
                 color="warning" variant="tonal" rounded="lg"
                 class="text-none" prepend-icon="mdi-alert-octagon"
                 :loading="acting" @click="doAction('mark_missed')">Mark missed</v-btn>
          <v-btn v-if="selected.status === 'scheduled'"
                 color="error" variant="tonal" rounded="lg"
                 class="text-none" prepend-icon="mdi-cancel"
                 :loading="acting" @click="cancelSchedule">Cancel</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
          <v-btn color="indigo" variant="tonal" rounded="lg" class="text-none"
                 prepend-icon="mdi-pencil" @click="openEdit(selected)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

// ── State ──────────────────────────────────────────────────────────────
const view = ref('day')
const cursor = ref(new Date())
const items = ref([])
const loading = ref(false)
const search = ref('')
const filters = reactive({ caregiver: null, patient: null, status: null, shift_type: null })

const caregivers = ref([])
const patients = ref([])

const formDialog = ref(false)
const editing = ref(null)
const saving = ref(false)
const formError = ref('')
const form = reactive({
  caregiver: null, patient: null, start_at: '', end_at: '',
  shift_type: 'visit', notes: '',
  recurrenceMode: 'none', byday: [], until: '',
})

const detailDialog = ref(false)
const selected = ref(null)
const acting = ref(false)

const snack = reactive({ show: false, text: '', color: 'info' })

// ── Constants ──────────────────────────────────────────────────────────
const HOURS = Array.from({ length: 24 }, (_, i) => i)
const HOUR_PX = 56

const STATUS_META = {
  scheduled:  { label: 'Scheduled',  icon: 'mdi-calendar-clock',  color: 'blue',
                gradient: 'linear-gradient(135deg,#1d4ed8 0%,#3b82f6 100%)' },
  checked_in: { label: 'In progress', icon: 'mdi-progress-clock', color: 'teal',
                gradient: 'linear-gradient(135deg,#0f766e 0%,#14b8a6 100%)' },
  completed:  { label: 'Completed',  icon: 'mdi-check-decagram',  color: 'success',
                gradient: 'linear-gradient(135deg,#15803d 0%,#22c55e 100%)' },
  missed:     { label: 'Missed',     icon: 'mdi-alert-octagon',   color: 'warning',
                gradient: 'linear-gradient(135deg,#b45309 0%,#f59e0b 100%)' },
  cancelled:  { label: 'Cancelled',  icon: 'mdi-cancel',          color: 'grey',
                gradient: 'linear-gradient(135deg,#475569 0%,#94a3b8 100%)' },
}

const statusOptions = [
  { title: 'Scheduled',   value: 'scheduled' },
  { title: 'In progress', value: 'checked_in' },
  { title: 'Completed',   value: 'completed' },
  { title: 'Missed',      value: 'missed' },
  { title: 'Cancelled',   value: 'cancelled' },
]
const shiftTypeOptions = [
  { title: 'Single Visit', value: 'visit' },
  { title: 'Live-in',      value: 'live_in' },
  { title: 'On Call',      value: 'on_call' },
]
function shiftLabel(v) { return shiftTypeOptions.find(o => o.value === v)?.title || v }

const WEEKDAYS = [
  { value: 'MO', short: 'Mon' }, { value: 'TU', short: 'Tue' },
  { value: 'WE', short: 'Wed' }, { value: 'TH', short: 'Thu' },
  { value: 'FR', short: 'Fri' }, { value: 'SA', short: 'Sat' },
  { value: 'SU', short: 'Sun' },
]
const recurrenceModes = [
  { title: 'No repeat', value: 'none' },
  { title: 'Daily',     value: 'daily' },
  { title: 'Weekly',    value: 'weekly' },
]

const tableHeaders = [
  { title: 'When',      key: 'when',           sortable: false },
  { title: 'Caregiver', key: 'caregiver_name' },
  { title: 'Patient',   key: 'patient_name' },
  { title: 'Status',    key: 'status' },
  { title: '',          key: 'actions',        sortable: false, align: 'end' },
]

// ── Options ────────────────────────────────────────────────────────────
const caregiverOptions = computed(() =>
  caregivers.value.map(c => ({ title: c.user?.full_name || c.user?.email, value: c.id }))
)
const patientOptions = computed(() =>
  patients.value.map(p => ({ title: p.user?.full_name || p.medical_record_number, value: p.id }))
)

// ── Range computed ─────────────────────────────────────────────────────
function startOfDay(d) { const x = new Date(d); x.setHours(0,0,0,0); return x }
function endOfDay(d)   { const x = new Date(d); x.setHours(23,59,59,999); return x }
function startOfWeek(d) {
  const x = startOfDay(d)
  const day = (x.getDay() + 6) % 7   // Monday = 0
  x.setDate(x.getDate() - day)
  return x
}

const range = computed(() => {
  if (view.value === 'day') return { start: startOfDay(cursor.value), end: endOfDay(cursor.value) }
  if (view.value === 'week') {
    const s = startOfWeek(cursor.value)
    const e = new Date(s); e.setDate(s.getDate() + 6); return { start: s, end: endOfDay(e) }
  }
  // list = ±30d
  const s = new Date(cursor.value); s.setDate(s.getDate() - 7)
  const e = new Date(cursor.value); e.setDate(e.getDate() + 30)
  return { start: startOfDay(s), end: endOfDay(e) }
})

const rangeLabel = computed(() => {
  const fmt = (d, opts) => d.toLocaleDateString([], opts)
  if (view.value === 'day') return fmt(cursor.value, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })
  if (view.value === 'week') {
    const { start, end } = range.value
    return `${fmt(start, { month: 'short', day: 'numeric' })} – ${fmt(end, { month: 'short', day: 'numeric', year: 'numeric' })}`
  }
  return ''
})

// ── KPIs ───────────────────────────────────────────────────────────────
const kpis = computed(() => {
  const today = startOfDay(new Date()).getTime()
  const tEnd = endOfDay(new Date()).getTime()
  let t = 0, ct = 0, ip = 0, up = 0, ms = 0
  for (const ev of items.value) {
    const s = new Date(ev.start_at).getTime()
    const onToday = s >= today && s <= tEnd
    if (onToday) t++
    if (ev.status === 'checked_in') ip++
    if (onToday && ev.status === 'completed') ct++
    if (s > Date.now() && ev.status === 'scheduled') up++
    if (ev.status === 'missed') ms++
  }
  return { today: t, completedToday: ct, inProgress: ip, upcoming: up, missed: ms }
})

// ── Day events ─────────────────────────────────────────────────────────
const dayEvents = computed(() =>
  filteredAll.value.filter(ev => sameDay(ev.start_at, cursor.value))
)

const weekDays = computed(() => {
  const out = []
  const s = startOfWeek(cursor.value)
  const today = startOfDay(new Date()).getTime()
  for (let i = 0; i < 7; i++) {
    const d = new Date(s); d.setDate(s.getDate() + i)
    const evs = filteredAll.value.filter(ev => sameDay(ev.start_at, d))
    out.push({
      iso: d.toISOString().slice(0, 10),
      weekday: d.toLocaleDateString([], { weekday: 'short' }),
      day: d.getDate(),
      isToday: startOfDay(d).getTime() === today,
      count: evs.length,
      events: evs,
    })
  }
  return out
})

const filteredAll = computed(() => {
  return items.value.filter(ev => {
    if (filters.caregiver && ev.caregiver !== filters.caregiver) return false
    if (filters.patient && ev.patient !== filters.patient) return false
    if (filters.status && ev.status !== filters.status) return false
    if (filters.shift_type && ev.shift_type !== filters.shift_type) return false
    return true
  })
})

const filteredList = computed(() => {
  const q = search.value?.trim().toLowerCase()
  if (!q) return filteredAll.value
  return filteredAll.value.filter(ev => {
    const blob = [ev.caregiver_name, ev.patient_name, ev.notes].filter(Boolean).join(' ').toLowerCase()
    return blob.includes(q)
  })
})

// ── Helpers ────────────────────────────────────────────────────────────
function sameDay(iso, d) {
  const x = new Date(iso)
  return x.getFullYear() === d.getFullYear() &&
         x.getMonth() === d.getMonth() &&
         x.getDate() === d.getDate()
}
function formatHour(h) {
  return new Date(2000, 0, 1, h).toLocaleTimeString([], { hour: 'numeric' })
}
function formatTime(iso) {
  return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''
}
function formatDateTime(iso) {
  return iso ? new Date(iso).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : ''
}
function duration(a, b) {
  const ms = new Date(b) - new Date(a)
  const m = Math.round(ms / 60000)
  const h = Math.floor(m / 60), mm = m % 60
  return h ? `${h}h ${mm}m` : `${mm}m`
}
function initials(name) {
  if (!name) return '?'
  const p = name.trim().split(/\s+/)
  return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || name[0].toUpperCase()
}

function eventStyle(ev) {
  const s = new Date(ev.start_at)
  const e = new Date(ev.end_at)
  const top = (s.getHours() + s.getMinutes() / 60) * HOUR_PX
  const dur = Math.max(0.5, (e - s) / 3600000)
  return {
    top: `${top}px`,
    height: `${Math.max(dur * HOUR_PX - 2, 36)}px`,
  }
}

function navigate(delta) {
  const d = new Date(cursor.value)
  if (view.value === 'day') d.setDate(d.getDate() + delta)
  else if (view.value === 'week') d.setDate(d.getDate() + delta * 7)
  cursor.value = d
  load()
}
function goToday() { cursor.value = new Date(); load() }

// ── Data loading ───────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const params = {
      page_size: 1000,
      start_after: range.value.start.toISOString(),
      end_before: range.value.end.toISOString(),
    }
    const { data } = await $api.get('/homecare/schedules/', { params })
    items.value = data?.results || data || []
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to load schedules', color: 'error' })
  } finally {
    loading.value = false
  }
}

async function loadOptions() {
  try {
    const [c, p] = await Promise.all([
      $api.get('/homecare/caregivers/', { params: { page_size: 500 } }),
      $api.get('/homecare/patients/',   { params: { page_size: 500 } }),
    ])
    caregivers.value = c.data?.results || c.data || []
    patients.value   = p.data?.results || p.data || []
  } catch { /* silent */ }
}

watch(view, load)

// ── Create / edit ──────────────────────────────────────────────────────
function resetForm() {
  Object.assign(form, {
    caregiver: filters.caregiver || null,
    patient:   filters.patient || null,
    start_at: defaultStart(),
    end_at:   defaultEnd(),
    shift_type: 'visit', notes: '',
    recurrenceMode: 'none', byday: [], until: '',
  })
}
function defaultStart() {
  const d = new Date(cursor.value); d.setHours(9, 0, 0, 0)
  return toLocalInput(d)
}
function defaultEnd() {
  const d = new Date(cursor.value); d.setHours(10, 0, 0, 0)
  return toLocalInput(d)
}
function toLocalInput(d) {
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function openCreate() {
  editing.value = null
  formError.value = ''
  resetForm()
  formDialog.value = true
}
function openEdit(ev) {
  editing.value = ev
  formError.value = ''
  Object.assign(form, {
    caregiver: ev.caregiver,
    patient: ev.patient,
    start_at: toLocalInput(new Date(ev.start_at)),
    end_at: toLocalInput(new Date(ev.end_at)),
    shift_type: ev.shift_type,
    notes: ev.notes || '',
    recurrenceMode: ev.recurrence?.freq || 'none',
    byday: ev.recurrence?.byday || [],
    until: ev.recurrence?.until ? ev.recurrence.until.slice(0, 10) : '',
  })
  detailDialog.value = false
  formDialog.value = true
}

async function save() {
  if (!form.caregiver || !form.patient || !form.start_at || !form.end_at) {
    formError.value = 'Caregiver, patient, start and end are required.'
    return
  }
  saving.value = true
  formError.value = ''
  const recurrence = form.recurrenceMode === 'none' ? {}
    : { freq: form.recurrenceMode,
        ...(form.recurrenceMode === 'weekly' ? { byday: form.byday } : {}),
        ...(form.until ? { until: new Date(form.until).toISOString() } : {}) }
  const payload = {
    caregiver: form.caregiver,
    patient: form.patient,
    start_at: new Date(form.start_at).toISOString(),
    end_at: new Date(form.end_at).toISOString(),
    shift_type: form.shift_type,
    notes: form.notes,
    recurrence,
  }
  try {
    if (editing.value) {
      await $api.patch(`/homecare/schedules/${editing.value.id}/`, payload)
    } else {
      await $api.post('/homecare/schedules/', payload)
    }
    formDialog.value = false
    Object.assign(snack, { show: true, text: editing.value ? 'Schedule updated' : 'Schedule created', color: 'success' })
    await load()
  } catch (e) {
    const d = e?.response?.data
    formError.value = (typeof d === 'string' ? d : d?.detail) ||
      Object.entries(d || {}).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join('\n') ||
      'Could not save schedule.'
  } finally {
    saving.value = false
  }
}

async function removeSchedule() {
  if (!editing.value) return
  if (!confirm('Delete this schedule?')) return
  try {
    await $api.delete(`/homecare/schedules/${editing.value.id}/`)
    formDialog.value = false
    Object.assign(snack, { show: true, text: 'Schedule deleted', color: 'success' })
    await load()
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to delete', color: 'error' })
  }
}

// ── Detail / actions ───────────────────────────────────────────────────
function openDetail(ev) { selected.value = ev; detailDialog.value = true }

async function doAction(verb) {
  if (!selected.value) return
  acting.value = true
  try {
    const body = {}
    if ((verb === 'check_in' || verb === 'check_out') && navigator.geolocation) {
      try {
        body.gps = await new Promise((res) => {
          navigator.geolocation.getCurrentPosition(
            pos => res({ lat: pos.coords.latitude, lng: pos.coords.longitude, accuracy: pos.coords.accuracy }),
            () => res({}),
            { timeout: 4000 }
          )
        })
      } catch { /* skip GPS */ }
    }
    const { data } = await $api.post(`/homecare/schedules/${selected.value.id}/${verb}/`, body)
    selected.value = data
    const i = items.value.findIndex(x => x.id === data.id)
    if (i >= 0) items.value.splice(i, 1, data)
    Object.assign(snack, { show: true, text: 'Updated', color: 'success' })
  } catch {
    Object.assign(snack, { show: true, text: 'Action failed', color: 'error' })
  } finally {
    acting.value = false
  }
}
async function cancelSchedule() {
  if (!selected.value) return
  const reason = prompt('Cancellation reason (optional):') || ''
  acting.value = true
  try {
    const { data } = await $api.post(`/homecare/schedules/${selected.value.id}/cancel/`, { reason })
    selected.value = data
    const i = items.value.findIndex(x => x.id === data.id)
    if (i >= 0) items.value.splice(i, 1, data)
    Object.assign(snack, { show: true, text: 'Schedule cancelled', color: 'success' })
  } catch {
    Object.assign(snack, { show: true, text: 'Cancel failed', color: 'error' })
  } finally {
    acting.value = false
  }
}

async function quickAction(item, verb) {
  selected.value = item
  await doAction(verb)
}

onMounted(async () => { await loadOptions(); await load() })
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); }

.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}

.hc-tabs :deep(.v-tab) { text-transform: none; font-weight: 600; }
.hc-table :deep(th) { background: rgba(0,0,0,0.025); font-weight: 600; }

/* Day grid */
.hc-day-grid {
  display: grid;
  grid-template-columns: 60px 1fr;
  position: relative;
  max-height: 70vh;
  overflow-y: auto;
}
.hc-hours { position: relative; }
.hc-hour {
  height: 56px;
  border-bottom: 1px dashed rgba(0,0,0,0.06);
  padding: 4px 6px;
  text-align: right;
}
.hc-day-col {
  position: relative;
  border-left: 1px solid rgba(0,0,0,0.08);
}
.hc-hour-line {
  height: 56px;
  border-bottom: 1px dashed rgba(0,0,0,0.06);
}
.hc-event {
  position: absolute;
  left: 6px; right: 6px;
  border-radius: 10px;
  padding: 6px 8px;
  cursor: pointer;
  color: white;
  overflow: hidden;
  box-shadow: 0 4px 12px -4px rgba(0,0,0,0.25);
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}
.hc-event:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 18px -6px rgba(0,0,0,0.35);
}
.hc-ev-scheduled  { background: linear-gradient(135deg,#1d4ed8 0%,#3b82f6 100%); }
.hc-ev-checked_in { background: linear-gradient(135deg,#0f766e 0%,#14b8a6 100%); }
.hc-ev-completed  { background: linear-gradient(135deg,#15803d 0%,#22c55e 100%); }
.hc-ev-missed     { background: linear-gradient(135deg,#b45309 0%,#f59e0b 100%); }
.hc-ev-cancelled  { background: linear-gradient(135deg,#475569 0%,#94a3b8 100%); }

/* Week */
.hc-week-head {
  display: grid;
  grid-template-columns: 60px repeat(7, 1fr);
  border-bottom: 1px solid rgba(0,0,0,0.08);
  position: sticky; top: 0; background: white; z-index: 1;
}
:global(.v-theme--dark) .hc-week-head { background: rgb(30,41,59); }
.hc-week-spacer { }
.hc-week-day {
  text-align: center;
  padding: 8px 4px;
  border-left: 1px solid rgba(0,0,0,0.06);
}
.hc-week-today { background: rgba(20,184,166,0.08); }
.hc-week-body {
  display: grid;
  grid-template-columns: 60px repeat(7, 1fr);
  position: relative;
  max-height: 70vh;
  overflow-y: auto;
}

.position-absolute { position: absolute; }
.top-0 { top: 0; left: 0; right: 0; }
</style>
