<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-account-voice"
      eyebrow="OHSMS · Clause 5.4 consultation & participation"
      title="Safety Committee & Toolbox Talks"
      subtitle="Committee meetings, toolbox briefings, site inductions and pre-job briefings with attendance registers and signed records."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">Schedule meeting</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-account-voice</v-icon>
        <b>{{ meetings.count.value }}</b> sessions</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.completed }}</b> completed</span>
      <span v-if="stats.overdue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-calendar-alert</v-icon>
        <b>{{ stats.overdue }}</b> not held</span>
      <span class="ohs-chip"><v-icon size="12">mdi-account-multiple</v-icon>
        <b>{{ fmt(stats.attendances) }}</b> attendances</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Completed sessions" :value="stats.completed" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`${stats.toolbox} toolbox talks`" />
      <OhsKpi label="Committee meetings" :value="stats.committee" icon="mdi-account-voice" tone="primary"
              sub="statutory forum" />
      <OhsKpi label="Total attendances" :value="fmt(stats.attendances)" icon="mdi-account-multiple"
              tone="info" sub="worker contacts" />
      <OhsKpi label="Avg attendance" :value="`${stats.avgAttendance}%`" icon="mdi-percent-outline"
              :tone="stats.avgAttendance >= 90 ? 'ok' : 'warn'" sub="signed register rate" />
      <OhsKpi label="Not held" :value="stats.overdue" icon="mdi-calendar-alert"
              :tone="stats.overdue ? 'err' : 'ok'" sub="past scheduled date" />
    </div>

    <OhsPanel title="Meetings & briefings" :subtitle="`${filtered.length} shown`"
              icon="mdi-account-voice" flush>
      <template #actions>
        <v-chip-group v-model="typeFilter" mandatory selected-class="text-primary">
          <v-chip v-for="f in typeFilters" :key="f.value" :value="f.value" size="small" variant="tonal"
                  :color="f.color">{{ f.label }}</v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search title, chairperson, topic…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:270px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:185px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="Any status" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:160px" />
      </div>

      <v-progress-linear v-if="meetings.loading.value" indeterminate color="primary" height="2" />

      <div class="ohs-scroll" style="max-height:62vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:96px">Date</th>
              <th>Session</th>
              <th style="width:130px">Type</th>
              <th style="width:130px">Site</th>
              <th style="width:140px">Chairperson</th>
              <th style="width:94px" class="num">Present</th>
              <th style="width:96px" class="num">Signed</th>
              <th style="width:105px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in filtered" :key="m.id" @click="openDetail(m)">
              <td class="text-caption">{{ formatDate(m.meeting_date) }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:330px">{{ m.title }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ m.topics_covered || m.location || '—' }}
                </div>
              </td>
              <td class="text-caption">{{ m.meeting_type_display }}</td>
              <td class="text-caption">{{ m.site_name || 'All sites' }}</td>
              <td class="text-caption">{{ m.chairperson || '—' }}</td>
              <td class="num">{{ m.attendees_count || 0 }}</td>
              <td class="num" :style="{ color: pctColor(m.attendance_pct) }">{{ m.attendance_pct }}%</td>
              <td>
                <span class="ohs-badge"
                      :class="m.is_overdue ? 'ohs-badge--err' : `ohs-badge--${toneFor(m.status)}`">
                  {{ m.is_overdue ? 'Not held' : m.status_display }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !meetings.loading.value" class="ohs-empty">
          No sessions match these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- ═════ DETAIL ═════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="580">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color:rgba(255,255,255,.8)">
                {{ formatDate(detail.meeting_date) }}<span v-if="detail.start_time"> · {{ detail.start_time }}</span>
              </div>
              <div class="text-h6 font-weight-bold" style="line-height:1.25">{{ detail.title }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="glass-chip">{{ detail.meeting_type_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span class="glass-chip">{{ detail.attendees_count }} attended</span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6"><div class="meta"><span>Site</span><b>{{ detail.site_name || 'All sites' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Chairperson</span><b>{{ detail.chairperson || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Location</span><b>{{ detail.location || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Duration</span><b>{{ detail.duration_minutes }} min</b></div></v-col>
          </v-row>

          <div class="section-title">Agenda</div>
          <div class="text-body-2">{{ detail.agenda || '—' }}</div>

          <div class="section-title">Minutes</div>
          <div class="text-body-2">{{ detail.minutes || 'Not recorded yet.' }}</div>

          <div class="section-title">Decisions & actions</div>
          <div class="text-body-2">{{ detail.decisions || '—' }}</div>

          <div class="d-flex align-center justify-space-between mt-4 mb-2">
            <span class="section-title" style="margin:0">Attendance register</span>
            <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none"
                   prepend-icon="mdi-account-plus" @click="attendeeDialog = true">Add attendee</v-btn>
          </div>
          <div class="attendance-list">
            <div v-for="a in detail.attendance" :key="a.id" class="att-row">
              <v-icon size="14" :color="a.present ? 'success' : 'grey'">
                {{ a.present ? 'mdi-check-circle' : 'mdi-minus-circle-outline' }}
              </v-icon>
              <span class="flex-grow-1 text-caption font-weight-medium">{{ a.employee_name }}</span>
              <span class="text-caption text-medium-emphasis">{{ a.role || '—' }}</span>
              <v-icon v-if="a.signed" size="13" color="success" title="Signed">mdi-draw</v-icon>
            </div>
            <div v-if="!detail.attendance?.length" class="text-caption text-medium-emphasis">
              No attendees recorded.
            </div>
          </div>
        </div>

        <div class="drawer-actions">
          <v-btn v-if="detail.status !== 'completed'" variant="tonal" color="success" rounded="lg"
                 class="text-none" @click="complete">Mark completed</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═════ CREATE ═════ -->
    <v-dialog v-model="createDialog" max-width="640">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-voice" title="Schedule a session"
                           subtitle="Committee meeting, toolbox talk, induction or pre-job briefing." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Title" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.meeting_date" type="date" label="Date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.meeting_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Session type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.chairperson" label="Chairperson" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.location" label="Location" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.start_time" type="time" label="Start time" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.duration_minutes" type="number" min="5"
                            label="Duration (min)" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="form.topics_covered" label="Topic(s)" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.agenda" label="Agenda" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="meetings.saving.value"
                 :disabled="!form.title" @click="save">Schedule</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════ ADD ATTENDEE ═════ -->
    <v-dialog v-model="attendeeDialog" max-width="460">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-plus" title="Add attendee"
                           subtitle="Record presence and signature for the register." />
        <v-card-text>
          <v-text-field v-model="attendeeForm.employee_name" label="Employee name" variant="outlined"
                        density="compact" rounded="lg" class="mb-2" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="attendeeForm.employee_ref" label="Employee ref" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="attendeeForm.role" label="Role" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-checkbox v-model="attendeeForm.present" density="compact" hide-details label="Present" />
          <v-checkbox v-model="attendeeForm.signed" density="compact" hide-details label="Signed register" />
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="attendeeDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingAttendee"
                 :disabled="!attendeeForm.employee_name" @click="saveAttendee">Add</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { toneFor } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Safety Committee · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const meetings = ohs.resource('meetings')
const lookups = ref({})
const search = ref('')
const typeFilter = ref('all')
const siteFilter = ref(null)
const statusFilter = ref(null)
const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const attendeeDialog = ref(false)
const savingAttendee = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', meeting_type: 'toolbox', site: null, chairperson: '', location: '',
  meeting_date: new Date().toISOString().slice(0, 10), start_time: '', duration_minutes: 30,
  topics_covered: '', agenda: '',
})
const attendeeForm = reactive({
  employee_name: '', employee_ref: '', role: '', present: true, signed: true,
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const typeOptions = computed(() => lookups.value.meeting_types || [])
const statusOptions = [
  { label: 'Scheduled', value: 'scheduled' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]
const typeFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Committee', value: 'committee', color: 'primary' },
  { label: 'Toolbox', value: 'toolbox', color: 'teal' },
  { label: 'Induction', value: 'induction', color: 'info' },
  { label: 'Pre-job', value: 'pre_job', color: 'warning' },
]

const rows = computed(() => meetings.items.value || [])

const filtered = computed(() => rows.value.filter((m) => {
  if (typeFilter.value !== 'all' && m.meeting_type !== typeFilter.value) return false
  if (siteFilter.value && m.site !== siteFilter.value) return false
  if (statusFilter.value && m.status !== statusFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${m.title} ${m.chairperson} ${m.topics_covered} ${m.location}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const completed = all.filter((m) => m.status === 'completed')
  const withAttendance = completed.filter((m) => m.attendance_pct > 0)
  return {
    completed: completed.length,
    committee: all.filter((m) => m.meeting_type === 'committee').length,
    toolbox: all.filter((m) => ['toolbox', 'pre_job', 'induction'].includes(m.meeting_type)).length,
    overdue: all.filter((m) => m.is_overdue).length,
    attendances: all.reduce((s, m) => s + (m.attendees_count || 0), 0),
    avgAttendance: withAttendance.length
      ? Math.round(withAttendance.reduce((s, m) => s + m.attendance_pct, 0) / withAttendance.length)
      : 0,
  }
})

function fmt(v) {
  return Number(v || 0).toLocaleString()
}
function pctColor(v) {
  const n = Number(v || 0)
  if (n >= 90) return '#16a34a'
  if (n >= 70) return '#f59e0b'
  return '#dc2626'
}

async function load() {
  await meetings.list({ ordering: '-meeting_date' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(m) {
  drawer.value = true
  detail.value = m
  try {
    const { data } = await $api.get(`/ohs/meetings/${m.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: '', meeting_type: 'toolbox', site: siteOptions.value[0]?.value || null,
    chairperson: '', location: '',
    meeting_date: new Date().toISOString().slice(0, 10), start_time: '',
    duration_minutes: 30, topics_covered: '', agenda: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.site) delete payload.site
    if (!payload.start_time) delete payload.start_time
    await meetings.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Session scheduled.' }
    await load()
  } catch (e) {
    error.value = meetings.message(e)
  }
}

async function complete() {
  if (!detail.value) return
  try {
    const { data } = await $api.post(`/ohs/meetings/${detail.value.id}/complete/`, {
      minutes: 'Session held; topics discussed and actions agreed.',
    })
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Session marked completed.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: meetings.message(e) }
  }
}

async function saveAttendee() {
  if (!detail.value) return
  savingAttendee.value = true
  try {
    const { data } = await $api.post(`/ohs/meetings/${detail.value.id}/add_attendee/`, {
      ...attendeeForm,
    })
    detail.value = data
    attendeeDialog.value = false
    Object.assign(attendeeForm, { employee_name: '', employee_ref: '', role: '', present: true, signed: true })
    snack.value = { show: true, color: 'success', text: 'Attendee added.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: meetings.message(e) }
  } finally {
    savingAttendee.value = false
  }
}

function exportData() {
  exportCsv(`safety_meetings_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'meeting_date', label: 'Date' },
    { key: 'title', label: 'Session' },
    { key: 'meeting_type_display', label: 'Type' },
    { key: 'site_name', label: 'Site' },
    { key: 'chairperson', label: 'Chairperson' },
    { key: 'location', label: 'Location' },
    { key: 'topics_covered', label: 'Topics' },
    { key: 'attendees_count', label: 'Attendees' },
    { key: 'attendance_pct', label: 'Attendance %' },
    { key: 'status_display', label: 'Status' },
  ])
}

watch([typeFilter, siteFilter, statusFilter], load)
onMounted(load)
</script>

<style scoped>
.drawer-head { padding: 16px; color: #fff; background: var(--brand-gradient); }
.glass-chip {
  display: inline-flex; align-items: center; padding: 2px 9px; border-radius: 999px;
  font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .3px;
  background: rgba(255, 255, 255, 0.16); border: 1px solid rgba(255, 255, 255, 0.3); color: #fff;
}
.meta { display: flex; flex-direction: column; gap: 1px; }
.meta span { font-size: 10.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase; color: rgba(var(--v-theme-on-surface), .5); }
.meta b { font-size: 12.5px; font-weight: 600; }
.section-title {
  font-size: 11px; font-weight: 800; letter-spacing: .6px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 4px;
}
.attendance-list {
  border: 1px solid rgba(15, 23, 42, 0.08); border-radius: 10px; overflow: hidden;
}
.att-row {
  display: flex; align-items: center; gap: 9px;
  padding: 7px 11px; border-bottom: 1px solid rgba(var(--v-theme-on-surface), .05);
}
.att-row:last-child { border-bottom: none; }
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
