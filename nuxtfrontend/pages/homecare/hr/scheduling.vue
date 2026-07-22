<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Scheduling & Time Tracking"
      subtitle="Build shift rosters, track clock-in/out, monitor attendance, and manage overtime across the workforce."
      eyebrow="HR · SCHEDULING"
      icon="mdi-calendar-clock-outline"
      :chips="[
        { icon: 'mdi-clock-time-eight', label: `${todayClockIns} clocked in` },
        { icon: 'mdi-calendar-alert', label: `${pendingShifts} unassigned shifts` },
        { icon: 'mdi-timer-alert', label: `${overtimeHours}h overtime this week` },
        { icon: 'mdi-account-remove', label: `${absentToday} absent` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-calendar-plus"
               class="text-none" @click="openShiftDialog">
          <span class="text-teal-darken-2 font-weight-bold">Create shift</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Clocked In Now" :value="todayClockIns" icon="mdi-clock-time-eight" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Scheduled Today" :value="scheduledToday" icon="mdi-calendar-check" color="#0d9488" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Overtime (week)" :value="overtimeHours" suffix="hrs" icon="mdi-timer-alert" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Absent Today" :value="absentToday" icon="mdi-account-remove" color="#ef4444" /></v-col>
    </v-row>

    <v-tabs v-model="tab" color="teal" density="compact" class="mb-3">
      <v-tab value="roster"><v-icon start icon="mdi-calendar-month" />Shift Roster</v-tab>
      <v-tab value="attendance"><v-icon start icon="mdi-clock-in" />Attendance & Clock</v-tab>
      <v-tab value="timesheets"><v-icon start icon="mdi-file-clock" />Timesheets</v-tab>
    </v-tabs>

    <!-- ROSTER TAB -->
    <template v-if="tab === 'roster'">
      <HomecarePanel title="Weekly Shift Roster" subtitle="Assign and manage employee shifts" icon="mdi-calendar-month" color="#0d9488">
        <template #actions>
          <div class="d-flex align-center ga-2">
            <v-btn icon="mdi-chevron-left" variant="text" size="small" @click="shiftWeek(-1)" />
            <v-btn variant="tonal" color="teal" size="small" class="text-none" @click="shiftWeek(0)">This Week</v-btn>
            <v-btn icon="mdi-chevron-right" variant="text" size="small" @click="shiftWeek(1)" />
            <span class="text-body-2 font-weight-bold ml-2">{{ weekLabel }}</span>
          </div>
        </template>
        <div class="hc-roster-wrap overflow-x-auto">
          <table class="hc-roster-table">
            <thead>
              <tr>
                <th class="hc-roster-emp">Employee</th>
                <th v-for="d in weekDays" :key="d.iso" class="text-center hc-roster-day"
                    :class="{ 'hc-today': d.isToday }">
                  {{ d.short }}<br><span class="text-caption">{{ d.date }}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="emp in employees" :key="emp.id">
                <td class="hc-roster-emp">
                  <div class="d-flex align-center">
                    <v-avatar size="28" :color="avatarColor(emp.name)" variant="tonal" class="mr-2">
                      <span class="text-caption font-weight-bold">{{ initials(emp.name) }}</span>
                    </v-avatar>
                    <div>
                      <div class="font-weight-medium text-body-2">{{ emp.name }}</div>
                      <div class="text-caption text-medium-emphasis">{{ emp.department }}</div>
                    </div>
                  </div>
                </td>
                <td v-for="d in weekDays" :key="d.iso" class="text-center hc-roster-cell"
                    @click="openAssignShift(emp, d.iso)">
                  <div v-for="s in shiftsFor(emp.id, d.iso)" :key="s.id"
                       class="hc-shift-chip" :class="`hc-shift-${s.shift_type}`"
                       :title="`${shiftLabel(s.shift_type)} ${s.start_time}–${s.end_time}`">
                    <v-icon :icon="shiftIcon(s.shift_type)" size="12" />
                    {{ s.start_time }}–{{ s.end_time }}
                  </div>
                  <v-icon v-if="!shiftsFor(emp.id, d.iso).length" icon="mdi-plus-circle-outline"
                          size="16" class="text-medium-emphasis opacity-50" />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </HomecarePanel>
    </template>

    <!-- ATTENDANCE TAB -->
    <template v-if="tab === 'attendance'">
      <v-row dense>
        <v-col cols="12" lg="7">
          <HomecarePanel title="Live Attendance" subtitle="Today's clock-in/out status" icon="mdi-clock-in" color="#10b981">
            <v-text-field v-model="attendanceSearch" prepend-inner-icon="mdi-magnify" placeholder="Search employee…"
                          density="compact" variant="outlined" hide-details clearable class="mb-2" />
            <v-data-table :headers="attendanceHeaders" :items="filteredAttendance" :loading="loading" item-value="id" density="compact">
              <template #[`item.name`]="{ item }">
                <div class="d-flex align-center">
                  <v-avatar size="28" :color="avatarColor(item.name)" variant="tonal" class="mr-2">
                    <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
                  </v-avatar>
                  <div class="text-body-2 font-weight-medium">{{ item.name }}</div>
                </div>
              </template>
              <template #[`item.clock_in`]="{ item }">
                <v-chip v-if="item.clock_in" size="small" variant="tonal" color="success" prepend-icon="mdi-login">
                  {{ item.clock_in }}
                </v-chip>
                <span v-else class="text-medium-emphasis">—</span>
              </template>
              <template #[`item.clock_out`]="{ item }">
                <v-chip v-if="item.clock_out" size="small" variant="tonal" color="error" prepend-icon="mdi-logout">
                  {{ item.clock_out }}
                </v-chip>
                <span v-else class="text-medium-emphasis">—</span>
              </template>
              <template #[`item.hours`]="{ item }">
                <span v-if="item.hours" :class="item.hours > 8 ? 'text-orange font-weight-bold' : ''">{{ item.hours }}h</span>
                <span v-else class="text-medium-emphasis">—</span>
              </template>
              <template #[`item.status`]="{ item }">
                <StatusChip :status="attStatusKey(item)" :label="attStatusLabel(item)" />
              </template>
              <template #[`item.actions`]="{ item }">
                <v-btn v-if="!item.clock_in" size="small" variant="tonal" color="success" prepend-icon="mdi-login"
                       @click="clockAction(item, 'in')">Clock In</v-btn>
                <v-btn v-else-if="!item.clock_out" size="small" variant="tonal" color="error" prepend-icon="mdi-logout"
                       @click="clockAction(item, 'out')">Clock Out</v-btn>
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" lg="5">
          <HomecarePanel title="Attendance Summary" icon="mdi-chart-donut" color="#8b5cf6">
            <div v-for="s in attendanceSummary" :key="s.label" class="d-flex align-center mb-2">
              <v-icon :icon="s.icon" :color="s.color" class="mr-2" size="20" />
              <span class="text-body-2 flex-grow-1">{{ s.label }}</span>
              <span class="font-weight-bold mr-2">{{ s.count }}</span>
              <v-progress-linear :model-value="s.pct" :color="s.color" style="max-width:60px;" height="4" rounded />
            </div>
          </HomecarePanel>

          <HomecarePanel title="Overtime Watch" subtitle="Employees exceeding 48h/week" icon="mdi-timer-alert" color="#f59e0b" class="mt-3">
            <v-list density="compact" class="bg-transparent pa-0">
              <v-list-item v-for="o in overtimeList" :key="o.id" rounded="lg" class="mb-1">
                <template #prepend>
                  <v-avatar size="32" color="warning" variant="tonal">
                    <v-icon icon="mdi-timer-alert" size="16" />
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">{{ o.name }}</v-list-item-title>
                <v-list-item-subtitle>{{ o.weekly_hours }}h this week · {{ o.overtime_hours }}h overtime</v-list-item-subtitle>
                <template #append>
                  <v-chip size="small" variant="tonal" color="warning">{{ o.overtime_hours }}h OT</v-chip>
                </template>
              </v-list-item>
              <EmptyState v-if="!overtimeList.length" icon="mdi-check-circle" title="No overtime" dense />
            </v-list>
          </HomecarePanel>
        </v-col>
      </v-row>
    </template>

    <!-- TIMESHEETS TAB -->
    <template v-if="tab === 'timesheets'">
      <HomecarePanel title="Timesheets" subtitle="Submitted hours for approval" icon="mdi-file-clock" color="#0ea5e9">
        <template #actions>
          <v-select v-model="tsStatusFilter" :items="tsStatusOptions" item-title="label" item-value="value"
                    density="compact" variant="outlined" hide-details clearable
                    placeholder="Status" style="max-width:160px;" />
        </template>
        <v-data-table :headers="tsHeaders" :items="filteredTimesheets" :loading="loading" item-value="id">
          <template #[`item.employee`]="{ item }">
            <div class="d-flex align-center">
              <v-avatar size="28" :color="avatarColor(item.employee_name)" variant="tonal" class="mr-2">
                <span class="text-caption font-weight-bold">{{ initials(item.employee_name) }}</span>
              </v-avatar>
              {{ item.employee_name }}
            </div>
          </template>
          <template #[`item.date`]="{ item }">{{ formatDate(item.date) }}</template>
          <template #[`item.shift_type`]="{ item }">
            <v-chip size="small" variant="tonal" :prepend-icon="shiftIcon(item.shift_type)">{{ shiftLabel(item.shift_type) }}</v-chip>
          </template>
          <template #[`item.hours`]="{ item }">
            <span :class="item.hours > 8 ? 'text-orange font-weight-bold' : ''">{{ item.hours }}h</span>
          </template>
          <template #[`item.status`]="{ item }">
            <StatusChip :status="item.status" />
          </template>
          <template #[`item.actions`]="{ item }">
            <template v-if="item.status === 'pending'">
              <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check" class="mr-1" @click="approveTs(item)">Approve</v-btn>
              <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-close" @click="rejectTs(item)">Reject</v-btn>
            </template>
          </template>
        </v-data-table>
      </HomecarePanel>
    </template>

    <!-- Assign shift dialog -->
    <v-dialog v-model="shiftDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-calendar-plus" class="mr-2" />Assign Shift</v-card-title>
        <v-divider />
        <v-card-text>
          <div v-if="shiftTarget" class="text-body-2 text-medium-emphasis mb-3">
            {{ shiftTarget.employeeName }} · {{ formatDate(shiftTarget.date) }}
          </div>
          <v-select v-model="shiftForm.employee" :items="employees" item-title="name" item-value="id"
                    label="Employee" density="comfortable" variant="outlined" />
          <v-text-field v-model="shiftForm.date" label="Date" type="date" density="comfortable" variant="outlined" />
          <v-select v-model="shiftForm.shift_type" :items="shiftTypes" item-title="label" item-value="value"
                    label="Shift type" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="shiftForm.start_time" label="Start" type="time" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="6"><v-text-field v-model="shiftForm.end_time" label="End" type="time" density="comfortable" variant="outlined" /></v-col>
          </v-row>
          <v-textarea v-model="shiftForm.notes" label="Notes" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="shiftDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveShift">Assign</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const tab = ref('roster')
const employees = ref([])
const shifts = ref([])
const attendance = ref([])
const timesheets = ref([])
const loading = ref(false)
const saving = ref(false)
const attendanceSearch = ref('')
const tsStatusFilter = ref(null)
const weekOffset = ref(0)
const shiftDialog = ref(false)
const shiftTarget = ref(null)

const shiftForm = reactive({ employee: null, date: '', shift_type: 'day', start_time: '08:00', end_time: '17:00', notes: '' })

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const shiftTypes = [
  { value: 'day', label: 'Day Shift' },
  { value: 'night', label: 'Night Shift' },
  { value: 'evening', label: 'Evening Shift' },
  { value: 'on_call', label: 'On-call' },
  { value: 'split', label: 'Split Shift' },
]
const tsStatusOptions = [
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
]

const attendanceHeaders = [
  { title: 'Employee', key: 'name' },
  { title: 'Clock In', key: 'clock_in' },
  { title: 'Clock Out', key: 'clock_out' },
  { title: 'Hours', key: 'hours', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false },
]
const tsHeaders = [
  { title: 'Employee', key: 'employee' },
  { title: 'Date', key: 'date' },
  { title: 'Shift', key: 'shift_type' },
  { title: 'Hours', key: 'hours', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false },
]

const weekDays = computed(() => {
  const today = new Date()
  const dayOfWeek = today.getDay()
  const monday = new Date(today)
  monday.setDate(today.getDate() - dayOfWeek + 1 + weekOffset.value * 7)
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(monday)
    d.setDate(monday.getDate() + i)
    const iso = d.toISOString().slice(0, 10)
    return {
      iso, short: d.toLocaleDateString(undefined, { weekday: 'short' }),
      date: d.getDate(), isToday: iso === today.toISOString().slice(0, 10),
    }
  })
})
const weekLabel = computed(() => {
  const days = weekDays.value
  return `${formatDate(days[0].iso)} – ${formatDate(days[6].iso)}`
})

function shiftsFor(empId, dateIso) {
  return shifts.value.filter(s => s.employee === empId && s.date === dateIso)
}
const filteredAttendance = computed(() => {
  const q = attendanceSearch.value.toLowerCase()
  return attendance.value.filter(a => !q || a.name?.toLowerCase().includes(q))
})
const filteredTimesheets = computed(() => {
  if (!tsStatusFilter.value) return timesheets.value
  return timesheets.value.filter(t => t.status === tsStatusFilter.value)
})
const todayClockIns = computed(() => attendance.value.filter(a => a.clock_in).length)
const scheduledToday = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return shifts.value.filter(s => s.date === today).length
})
const pendingShifts = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return employees.value.length - scheduledToday.value
})
const overtimeHours = computed(() => timesheets.value.filter(t => t.status === 'approved').reduce((sum, t) => sum + Math.max(t.hours - 8, 0), 0))
const absentToday = computed(() => attendance.value.filter(a => !a.clock_in && a.status !== 'on_leave').length)
const attendanceSummary = computed(() => {
  const total = attendance.value.length || 1
  const present = attendance.value.filter(a => a.clock_in && !a.clock_out).length
  const completed = attendance.value.filter(a => a.clock_out).length
  const late = attendance.value.filter(a => a.late).length
  const absent = attendance.value.filter(a => !a.clock_in && a.status !== 'on_leave').length
  const onLeave = attendance.value.filter(a => a.status === 'on_leave').length
  return [
    { label: 'Present now', count: present, pct: Math.round(present / total * 100), icon: 'mdi-login', color: 'success' },
    { label: 'Completed', count: completed, pct: Math.round(completed / total * 100), icon: 'mdi-check-circle', color: 'teal' },
    { label: 'Late arrivals', count: late, pct: Math.round(late / total * 100), icon: 'mdi-clock-alert', color: 'warning' },
    { label: 'Absent', count: absent, pct: Math.round(absent / total * 100), icon: 'mdi-account-remove', color: 'error' },
    { label: 'On leave', count: onLeave, pct: Math.round(onLeave / total * 100), icon: 'mdi-calendar-remove', color: 'info' },
  ]
})
const overtimeList = computed(() => employees.value.filter(e => (e.weekly_hours || 0) > 48))

function shiftLabel(t) { return shiftTypes.find(s => s.value === t)?.label || t }
function shiftIcon(t) {
  const map = { day: 'mdi-weather-sunny', night: 'mdi-weather-night', evening: 'mdi-weather-sunset', on_call: 'mdi-phone', split: 'mdi-call-split' }
  return map[t] || 'mdi-clock'
}
function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function attStatusKey(item) {
  if (item.status === 'on_leave') return 'scheduled'
  if (item.clock_out) return 'completed'
  if (item.clock_in) return 'in_progress'
  if (item.late) return 'overdue'
  return 'pending'
}
function attStatusLabel(item) {
  if (item.status === 'on_leave') return 'On Leave'
  if (item.clock_out) return 'Completed'
  if (item.clock_in) return 'Working'
  if (item.late) return 'Late'
  return 'Not in'
}

function shiftWeek(n) {
  if (n === 0) weekOffset.value = 0
  else weekOffset.value += n
  loadShifts()
}

function openAssignShift(emp, dateIso) {
  shiftTarget.value = { employeeName: emp.name, date: dateIso }
  Object.assign(shiftForm, { employee: emp.id, date: dateIso, shift_type: 'day', start_time: '08:00', end_time: '17:00', notes: '' })
  shiftDialog.value = true
}
function openShiftDialog() {
  shiftTarget.value = null
  Object.assign(shiftForm, { employee: null, date: new Date().toISOString().slice(0, 10), shift_type: 'day', start_time: '08:00', end_time: '17:00', notes: '' })
  shiftDialog.value = true
}
async function saveShift() {
  if (!shiftForm.employee || !shiftForm.date) { notify('Employee and date required.', 'error'); return }
  saving.value = true
  try {
    await $api.post('/homecare/hr/shifts/', { ...shiftForm })
    notify('Shift assigned.')
    shiftDialog.value = false
    loadShifts()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to assign.', 'error')
  } finally { saving.value = false }
}

async function clockAction(item, direction) {
  try {
    await $api.post('/homecare/hr/attendance/clock/', { employee: item.id, direction })
    notify(`Clocked ${direction} ${item.name}.`)
    loadAttendance()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Clock action failed.', 'error')
  }
}

async function approveTs(item) { await updateTs(item, 'approved') }
async function rejectTs(item) { await updateTs(item, 'rejected') }
async function updateTs(item, status) {
  try {
    await $api.patch(`/homecare/hr/timesheets/${item.id}/`, { status })
    notify(`Timesheet ${status}.`)
    loadTimesheets()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  }
}

async function load() {
  loading.value = true
  try {
    const [emp, att, ts] = await Promise.all([
      $api.get('/homecare/hr/employees/', { params: { page_size: 500, status: 'active' } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/attendance/today/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/timesheets/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
    ])
    employees.value = (emp.data?.results || emp.data || []).map(e => ({ ...e, name: e.name || `${e.first_name || ''} ${e.last_name || ''}`.trim() }))
    attendance.value = (att.data?.results || att.data || []).map(a => ({ ...a, name: a.employee_name || a.name }))
    timesheets.value = ts.data?.results || ts.data || []
    loadShifts()
  } catch (e) {
    console.warn('load scheduling failed', e)
  } finally { loading.value = false }
}
async function loadShifts() {
  if (!weekDays.value.length) return
  try {
    const { data } = await $api.get('/homecare/hr/shifts/', {
      params: { start: weekDays.value[0].iso, end: weekDays.value[6].iso, page_size: 500 },
    })
    shifts.value = data?.results || data || []
  } catch { shifts.value = [] }
}
async function loadAttendance() {
  try {
    const { data } = await $api.get('/homecare/hr/attendance/today/')
    attendance.value = (data?.results || data || []).map(a => ({ ...a, name: a.employee_name || a.name }))
  } catch { /* keep */ }
}
async function loadTimesheets() {
  try {
    const { data } = await $api.get('/homecare/hr/timesheets/', { params: { page_size: 500 } })
    timesheets.value = data?.results || data || []
  } catch { /* keep */ }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
.hc-roster-table { width: 100%; border-collapse: collapse; min-width: 700px; }
.hc-roster-table th, .hc-roster-table td { border: 1px solid rgba(15,23,42,0.08); padding: 6px 8px; }
.hc-roster-emp { position: sticky; left: 0; background: white; z-index: 1; min-width: 180px; }
:global(.v-theme--dark .hc-roster-emp) { background: #1e293b; }
.hc-roster-day { font-size: 12px; font-weight: 600; min-width: 80px; }
.hc-today { background: rgba(13,148,136,0.08); }
.hc-roster-cell { cursor: pointer; transition: background 0.15s; }
.hc-roster-cell:hover { background: rgba(13,148,136,0.06); }
.hc-shift-chip { display: inline-flex; align-items: center; gap: 2px; font-size: 10px; font-weight: 600; padding: 2px 6px; border-radius: 6px; margin: 1px; color: white; }
.hc-shift-day { background: #f59e0b; }
.hc-shift-night { background: #6366f1; }
.hc-shift-evening { background: #f97316; }
.hc-shift-on_call { background: #8b5cf6; }
.hc-shift-split { background: #0ea5e9; }
.hc-table :deep(td) { vertical-align: middle; }
</style>
