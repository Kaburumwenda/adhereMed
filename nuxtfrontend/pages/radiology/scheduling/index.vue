<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="blue-lighten-5" size="48">
        <v-icon color="blue-darken-2" size="28">mdi-calendar-clock</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Scheduling</div>
        <div class="text-body-2 text-medium-emphasis">Manage exam appointments &amp; modality slots</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="openNew()">Schedule Exam</v-btn>
    </div>

    <!-- KPI strip -->
    <div class="kpi-strip mb-4">
      <div v-for="k in kpis" :key="k.label" class="kpi-item pa-3 rounded-lg">
        <div class="d-flex align-center ga-2">
          <v-avatar :color="k.color" size="36" variant="tonal">
            <v-icon size="18">{{ k.icon }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6 font-weight-bold" style="line-height:1">{{ k.count }}</div>
            <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Date nav + filters + view toggle -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <!-- Date navigation -->
        <v-col cols="12" sm="auto" class="d-flex align-center ga-1">
          <v-btn icon="mdi-chevron-left" size="small" variant="text" @click="shiftDate(-1)" />
          <v-btn variant="tonal" rounded="lg" size="small" class="text-none px-3" prepend-icon="mdi-calendar"
                 @click="showDatePicker = !showDatePicker">
            {{ dateLabel }}
          </v-btn>
          <v-btn icon="mdi-chevron-right" size="small" variant="text" @click="shiftDate(1)" />
          <v-btn variant="text" size="small" class="text-none ml-1" @click="goToday">Today</v-btn>
        </v-col>
        <v-col cols="12" sm="3" md="2">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="2">
          <v-select v-model="filterStatus" :items="statusOpts" label="Status" variant="outlined"
            density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="2">
          <v-select v-model="filterModality" :items="modalities" item-title="name" item-value="id"
            label="Equipment" variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="auto" class="d-flex align-center ga-2 ml-auto">
          <v-btn v-if="hasFilters" variant="text" size="small" class="text-none"
                 prepend-icon="mdi-filter-off" @click="clearFilters">Clear</v-btn>
          <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="timeline" icon="mdi-chart-timeline-variant" size="small" />
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
      <!-- Date picker dropdown -->
      <v-expand-transition>
        <div v-if="showDatePicker" class="mt-3 d-flex justify-center">
          <v-date-picker v-model="selectedDateObj" color="primary" @update:model-value="showDatePicker = false" />
        </div>
      </v-expand-transition>
    </v-card>

    <!-- TIMELINE VIEW -->
    <div v-if="viewMode === 'timeline'" class="timeline-wrapper">
      <!-- Modality columns header -->
      <div class="timeline-grid">
        <!-- Time gutter -->
        <div class="time-gutter">
          <div class="gutter-header pa-2 text-caption font-weight-bold text-medium-emphasis">Time</div>
          <div v-for="h in timeSlots" :key="h" class="time-label text-caption text-medium-emphasis">
            {{ formatHour(h) }}
          </div>
        </div>
        <!-- Modality columns -->
        <div v-for="mod in activeModalities" :key="mod.id" class="modality-col">
          <div class="modality-header pa-2 rounded-t-lg">
            <div class="text-caption font-weight-bold text-truncate">{{ mod.name }}</div>
            <div class="text-caption text-medium-emphasis">{{ mod.room_location || 'No room' }}</div>
            <v-chip size="x-small" variant="tonal" class="mt-1">
              {{ modalityDayCount(mod.id) }}/{{ mod.max_daily_slots }} slots
            </v-chip>
          </div>
          <div class="modality-body">
            <div v-for="h in timeSlots" :key="h" class="time-cell"
                 @click="openNew({ modality: mod.id, hour: h })">
              <!-- Scheduled items in this cell -->
              <div v-for="s in cellItems(mod.id, h)" :key="s.id"
                   class="timeline-block rounded-lg pa-2 cursor-pointer"
                   :class="`timeline-block--${s.status}`"
                   :style="{ height: `${Math.max(s.duration_minutes || 30, 30)}px` }"
                   @click.stop="openDetail(s)">
                <div class="d-flex align-center ga-1 mb-1">
                  <div class="urgency-dot" :class="`urgency-dot-${orderPriority(s)}`" />
                  <span class="text-caption font-weight-bold text-truncate">{{ s.patient_name }}</span>
                </div>
                <div class="text-caption text-truncate" style="opacity:0.8">
                  {{ s.body_part }} · {{ s.duration_minutes }}m
                </div>
                <StatusChip :status="s.status" class="mt-1" />
              </div>
              <div v-if="!cellItems(mod.id, h).length" class="empty-slot text-center">
                <v-icon size="14" color="grey-lighten-2">mdi-plus</v-icon>
              </div>
            </div>
          </div>
        </div>
      </div>
      <!-- No modalities fallback -->
      <div v-if="!activeModalities.length" class="text-center pa-10">
        <v-icon size="64" color="grey-lighten-1">mdi-calendar-blank</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No equipment configured</div>
        <div class="text-body-2 text-medium-emphasis">Add imaging modalities to enable the timeline view.</div>
      </div>
    </div>

    <!-- TABLE VIEW -->
    <v-card v-else flat rounded="xl" class="overflow-hidden table-card">
      <v-data-table :headers="headers" :items="filteredSchedules" :search="search" :loading="loading"
        density="comfortable" hover items-per-page="25" class="sched-table"
        @click:row="(_, { item }) => openDetail(item)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>

        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-2">
            <div class="urgency-bar mr-3" :class="`urgency-${orderPriority(item)}`" />
            <v-avatar :color="avatarColor(item.order)" size="32" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ initials(item) }}</span>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.patient_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis">Order #{{ item.order }}</div>
            </div>
          </div>
        </template>

        <template #item.scheduled_datetime="{ value }">
          <div class="text-body-2">{{ fmtDateTime(value) }}</div>
        </template>

        <template #item.duration_minutes="{ value }">
          <span class="text-body-2">{{ value }}m</span>
        </template>

        <template #item.status="{ item }">
          <StatusChip :status="item.status" />
        </template>

        <template #item.technologist_name="{ value }">
          <span class="text-body-2">{{ value || 'Unassigned' }}</span>
        </template>

        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1" @click.stop>
            <v-tooltip v-if="item.status === 'scheduled'" text="Check In" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-account-check" size="x-small" variant="tonal" color="indigo"
                       :loading="item._busy" @click="doAction(item, 'check_in')" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="item.status === 'checked_in'" text="Start" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-play" size="x-small" variant="tonal" color="orange"
                       :loading="item._busy" @click="doAction(item, 'start')" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="item.status === 'in_progress'" text="Complete" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-check-circle" size="x-small" variant="tonal" color="success"
                       :loading="item._busy" @click="doAction(item, 'complete')" />
              </template>
            </v-tooltip>
            <v-btn icon="mdi-eye" size="x-small" variant="text" :to="`/radiology/orders/${item.order}`" />
          </div>
        </template>

        <template #no-data>
          <div class="pa-10 text-center">
            <v-icon size="64" color="grey-lighten-1">mdi-calendar-blank</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No schedules for {{ dateLabel }}</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Create a new appointment to get started.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openNew()">Schedule Exam</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- SCHEDULE DETAIL DRAWER -->
    <v-navigation-drawer v-model="detailDrawer" location="right" temporary width="400" class="pa-0">
      <template v-if="detailItem">
        <div class="pa-5">
          <div class="d-flex align-center justify-space-between mb-4">
            <div class="text-h6 font-weight-bold">Schedule Detail</div>
            <v-btn icon="mdi-close" variant="text" size="small" @click="detailDrawer = false" />
          </div>

          <div class="detail-section pa-4 rounded-lg mb-3">
            <div class="d-flex align-center mb-3">
              <v-avatar :color="avatarColor(detailItem.order)" size="40" class="mr-3">
                <span class="text-white font-weight-bold">{{ initials(detailItem) }}</span>
              </v-avatar>
              <div>
                <div class="text-body-1 font-weight-bold">{{ detailItem.patient_name }}</div>
                <div class="text-caption text-medium-emphasis">Order #{{ detailItem.order }}</div>
              </div>
            </div>
            <div class="detail-row"><span>Date &amp; Time</span><strong>{{ fmtDateTime(detailItem.scheduled_datetime) }}</strong></div>
            <div class="detail-row"><span>Duration</span><strong>{{ detailItem.duration_minutes }} min</strong></div>
            <div class="detail-row"><span>Equipment</span><strong>{{ detailItem.modality_name || '—' }}</strong></div>
            <div class="detail-row"><span>Imaging</span><strong>{{ detailItem.imaging_type || '—' }}</strong></div>
            <div class="detail-row"><span>Body Part</span><strong>{{ detailItem.body_part || '—' }}</strong></div>
            <div class="detail-row"><span>Technologist</span><strong>{{ detailItem.technologist_name || 'Unassigned' }}</strong></div>
            <div class="detail-row">
              <span>Status</span>
              <StatusChip :status="detailItem.status" />
            </div>
            <div v-if="detailItem.notes" class="mt-3">
              <div class="text-caption text-medium-emphasis mb-1">Notes</div>
              <div class="text-body-2" style="white-space:pre-wrap">{{ detailItem.notes }}</div>
            </div>
          </div>

          <!-- Quick actions -->
          <div class="d-flex flex-column ga-2">
            <v-btn v-if="detailItem.status === 'scheduled'" block variant="tonal" color="indigo" rounded="lg"
                   class="text-none" prepend-icon="mdi-account-check" :loading="detailItem._busy"
                   @click="doAction(detailItem, 'check_in')">Check In Patient</v-btn>
            <v-btn v-if="detailItem.status === 'checked_in'" block variant="tonal" color="orange" rounded="lg"
                   class="text-none" prepend-icon="mdi-play" :loading="detailItem._busy"
                   @click="doAction(detailItem, 'start')">Start Imaging</v-btn>
            <v-btn v-if="detailItem.status === 'in_progress'" block variant="tonal" color="success" rounded="lg"
                   class="text-none" prepend-icon="mdi-check-circle" :loading="detailItem._busy"
                   @click="doAction(detailItem, 'complete')">Mark Complete</v-btn>
            <v-btn block variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-eye"
                   :to="`/radiology/orders/${detailItem.order}`">View Full Order</v-btn>
          </div>
        </div>
      </template>
    </v-navigation-drawer>

    <!-- CREATE / EDIT DIALOG -->
    <v-dialog v-model="dlg" max-width="560" persistent>
      <v-card rounded="xl" class="pa-6">
        <div class="d-flex align-center mb-4">
          <v-avatar color="primary-lighten-5" size="40" class="mr-3">
            <v-icon color="primary">mdi-calendar-plus</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Schedule Exam</div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dlg = false" />
        </div>

        <v-form ref="dlgForm" @submit.prevent="saveSchedule">
          <v-autocomplete v-model="newSched.order" :items="ordersForSchedule" item-title="label" item-value="id"
            label="Order" :rules="reqRule" variant="outlined" density="compact" rounded="lg"
            prepend-inner-icon="mdi-clipboard-text" class="mb-3">
            <template #item="{ item, props: p }">
              <v-list-item v-bind="p">
                <v-list-item-subtitle>{{ item.raw.sub }}</v-list-item-subtitle>
              </v-list-item>
            </template>
          </v-autocomplete>

          <v-autocomplete v-model="newSched.modality" :items="modalities" item-title="name" item-value="id"
            label="Equipment / Modality" :rules="reqRule" variant="outlined" density="compact" rounded="lg"
            prepend-inner-icon="mdi-cog" class="mb-3">
            <template #item="{ item, props: p }">
              <v-list-item v-bind="p">
                <v-list-item-subtitle>{{ item.raw.room_location || 'No room' }} · {{ item.raw.max_daily_slots }} slots/day</v-list-item-subtitle>
              </v-list-item>
            </template>
          </v-autocomplete>

          <v-row dense class="mb-3">
            <v-col cols="7">
              <v-text-field v-model="newSched.scheduled_datetime" label="Date &amp; Time" type="datetime-local"
                :rules="reqRule" variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-clock" />
            </v-col>
            <v-col cols="5">
              <v-text-field v-model.number="newSched.duration_minutes" label="Duration (min)" type="number"
                variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-timer" />
            </v-col>
          </v-row>

          <v-autocomplete v-model="newSched.technologist" :items="staffList" item-title="full_name" item-value="id"
            label="Technologist (optional)" clearable variant="outlined" density="compact" rounded="lg"
            prepend-inner-icon="mdi-account" class="mb-3" />

          <v-textarea v-model="newSched.notes" label="Notes" rows="2" auto-grow variant="outlined"
            density="compact" rounded="lg" prepend-inner-icon="mdi-note-text" class="mb-3" />

          <v-alert v-if="dlgError" type="error" variant="tonal" rounded="lg" density="compact" class="mb-3" closable
                   @click:close="dlgError = ''">{{ dlgError }}</v-alert>

          <div class="d-flex justify-end ga-2">
            <v-btn variant="text" rounded="lg" class="text-none" @click="dlg = false">Cancel</v-btn>
            <v-btn type="submit" color="primary" rounded="lg" class="text-none" :loading="saving"
                   prepend-icon="mdi-content-save">Save Schedule</v-btn>
          </div>
        </v-form>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack" :color="snackColor" rounded="lg" timeout="2500" location="bottom right">
      {{ snackMsg }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()

const loading = ref(false)
const saving = ref(false)
const schedules = ref([])
const orders = ref([])
const modalities = ref([])
const staffList = ref([])
const search = ref('')
const filterStatus = ref(null)
const filterModality = ref(null)
const viewMode = ref('timeline')
const selectedDate = ref(todayStr())
const showDatePicker = ref(false)
const dlg = ref(false)
const dlgForm = ref(null)
const dlgError = ref('')
const detailDrawer = ref(false)
const detailItem = ref(null)
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')
const reqRule = [v => !!v || 'Required']

const statusOpts = [
  { title: 'Scheduled', value: 'scheduled' }, { title: 'Checked In', value: 'checked_in' },
  { title: 'In Progress', value: 'in_progress' }, { title: 'Completed', value: 'completed' },
  { title: 'No Show', value: 'no_show' }, { title: 'Cancelled', value: 'cancelled' },
]

const newSched = reactive({ order: null, modality: null, scheduled_datetime: '', duration_minutes: 30, technologist: null, notes: '' })

const headers = [
  { title: 'Patient', key: 'patient_name', width: 200 },
  { title: 'Imaging', key: 'imaging_type', width: 110 },
  { title: 'Body Part', key: 'body_part', width: 120 },
  { title: 'Equipment', key: 'modality_name', width: 140 },
  { title: 'Date/Time', key: 'scheduled_datetime', width: 160 },
  { title: 'Duration', key: 'duration_minutes', align: 'center', width: 90 },
  { title: 'Technologist', key: 'technologist_name', width: 130 },
  { title: 'Status', key: 'status', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 150 },
]

// Timeline: hours from 6 AM to 10 PM
const timeSlots = Array.from({ length: 17 }, (_, i) => i + 6)

const activeModalities = computed(() => modalities.value.filter(m => m.is_active))

// Date helpers
function todayStr() { return new Date().toISOString().slice(0, 10) }
const dateLabel = computed(() => {
  const d = new Date(selectedDate.value + 'T00:00:00')
  return d.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'long', year: 'numeric' })
})
const selectedDateObj = computed({
  get: () => new Date(selectedDate.value + 'T00:00:00'),
  set: (v) => { if (v) selectedDate.value = v.toISOString().slice(0, 10) }
})
function shiftDate(n) {
  const d = new Date(selectedDate.value + 'T00:00:00')
  d.setDate(d.getDate() + n)
  selectedDate.value = d.toISOString().slice(0, 10)
}
function goToday() { selectedDate.value = todayStr() }

// Filter schedules for selected date
const daySchedules = computed(() =>
  schedules.value.filter(s => s.scheduled_datetime?.startsWith(selectedDate.value))
)

const filteredSchedules = computed(() => {
  let list = daySchedules.value
  if (filterStatus.value) list = list.filter(s => s.status === filterStatus.value)
  if (filterModality.value) list = list.filter(s => s.modality === filterModality.value)
  return list
})

const hasFilters = computed(() => search.value || filterStatus.value || filterModality.value)
function clearFilters() { search.value = ''; filterStatus.value = null; filterModality.value = null }

// KPIs for the selected day
const kpis = computed(() => {
  const d = daySchedules.value
  return [
    { label: 'Total', count: d.length, color: 'indigo', icon: 'mdi-calendar-multiple' },
    { label: 'Scheduled', count: d.filter(s => s.status === 'scheduled').length, color: 'blue', icon: 'mdi-calendar-clock' },
    { label: 'Checked In', count: d.filter(s => s.status === 'checked_in').length, color: 'indigo', icon: 'mdi-account-check' },
    { label: 'In Progress', count: d.filter(s => s.status === 'in_progress').length, color: 'orange', icon: 'mdi-progress-clock' },
    { label: 'Completed', count: d.filter(s => s.status === 'completed').length, color: 'success', icon: 'mdi-check-circle' },
    { label: 'No Show', count: d.filter(s => s.status === 'no_show').length, color: 'error', icon: 'mdi-account-off' },
  ]
})

// Timeline cell items
function cellItems(modalityId, hour) {
  return filteredSchedules.value.filter(s => {
    if (s.modality !== modalityId) return false
    const h = new Date(s.scheduled_datetime).getHours()
    return h === hour
  })
}
function modalityDayCount(modalityId) {
  return daySchedules.value.filter(s => s.modality === modalityId && s.status !== 'cancelled').length
}

// Order priority lookup
function orderPriority(sched) {
  const o = orders.value.find(x => x.id === sched.order)
  return o?.priority || 'routine'
}

const ordersForSchedule = computed(() =>
  orders.value
    .filter(o => !['completed', 'cancelled'].includes(o.status))
    .map(o => ({ id: o.id, label: `#${o.id} ${o.patient_name} — ${o.body_part}`, sub: `${o.imaging_type_display} · ${o.priority_display}` }))
)

// Helpers
function formatHour(h) { return h < 12 ? `${h} AM` : h === 12 ? '12 PM' : `${h - 12} PM` }
function fmtDateTime(d) { if (!d) return '—'; return new Date(d).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) }
function initials(o) { const p = (o.patient_name || '').split(/\s+/).filter(Boolean); return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '?' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }

function openNew(opts = {}) {
  Object.assign(newSched, { order: null, modality: opts.modality || null, scheduled_datetime: '', duration_minutes: 30, technologist: null, notes: '' })
  if (opts.hour != null) {
    newSched.scheduled_datetime = `${selectedDate.value}T${String(opts.hour).padStart(2, '0')}:00`
  }
  dlgError.value = ''
  dlg.value = true
}

function openDetail(item) {
  detailItem.value = item
  detailDrawer.value = true
}

async function saveSchedule() {
  const { valid } = await dlgForm.value.validate()
  if (!valid) return
  saving.value = true
  dlgError.value = ''
  try {
    const payload = { ...newSched }
    if (!payload.technologist) delete payload.technologist
    await $api.post('/radiology/schedules/', payload)
    dlg.value = false
    snackMsg.value = 'Schedule created'
    snackColor.value = 'success'
    snack.value = true
    await load()
  } catch (e) {
    dlgError.value = e.response?.data?.detail || e.response?.data?.non_field_errors?.[0] || 'Failed to create schedule.'
  }
  saving.value = false
}

async function doAction(item, act) {
  item._busy = true
  try {
    const res = await $api.post(`/radiology/schedules/${item.id}/${act}/`)
    item.status = res.data?.status || item.status
    snackMsg.value = `${item.patient_name} → ${act.replace(/_/g, ' ')}`
    snackColor.value = 'success'
    snack.value = true
  } catch {
    snackMsg.value = 'Action failed'
    snackColor.value = 'error'
    snack.value = true
  }
  item._busy = false
}

async function load() {
  loading.value = true
  try {
    const [sRes, oRes, mRes, stRes] = await Promise.allSettled([
      $api.get('/radiology/schedules/?page_size=500&ordering=scheduled_datetime'),
      $api.get('/radiology/orders/?page_size=500'),
      $api.get('/radiology/modalities/?page_size=200'),
      $api.get('/accounts/users/?page_size=200'),
    ])
    schedules.value = (sRes.status === 'fulfilled' ? sRes.value.data?.results || sRes.value.data || [] : []).map(s => ({ ...s, _busy: false }))
    orders.value = oRes.status === 'fulfilled' ? oRes.value.data?.results || oRes.value.data || [] : []
    modalities.value = mRes.status === 'fulfilled' ? mRes.value.data?.results || mRes.value.data || [] : []
    staffList.value = (stRes.status === 'fulfilled' ? stRes.value.data?.results || stRes.value.data || [] : []).map(u => ({
      ...u, full_name: `${u.first_name || ''} ${u.last_name || ''}`.trim() || u.email || `User #${u.id}`
    }))
  } catch { }
  loading.value = false
}

// Reload when date changes
watch(selectedDate, load)
onMounted(load)
</script>

<style scoped>
.kpi-strip { display: flex; gap: 10px; overflow-x: auto; padding-bottom: 4px; }
.kpi-item { flex: 1; min-width: 130px; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.table-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.sched-table :deep(tbody tr) { cursor: pointer; }

/* Urgency */
.urgency-bar { width: 4px; height: 32px; border-radius: 4px; flex-shrink: 0; }
.urgency-stat { background: #EF4444; animation: pulse-bar 1.5s infinite; }
.urgency-urgent { background: #F59E0B; }
.urgency-routine { background: #94A3B8; }
.urgency-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.urgency-dot-stat { background: #EF4444; animation: pulse-bar 1.5s infinite; }
.urgency-dot-urgent { background: #F59E0B; }
.urgency-dot-routine { background: #94A3B8; }

/* Timeline grid */
.timeline-wrapper { overflow-x: auto; }
.timeline-grid { display: flex; gap: 0; min-width: 600px; }
.time-gutter { flex: 0 0 64px; border-right: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
.gutter-header { height: 72px; display: flex; align-items: flex-end; }
.time-label { height: 80px; display: flex; align-items: flex-start; padding: 4px 8px; border-top: 1px solid rgba(var(--v-theme-on-surface), 0.04); }
.modality-col { flex: 1; min-width: 180px; border-right: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.modality-col:last-child { border-right: none; }
.modality-header { height: 72px; background: rgba(var(--v-theme-on-surface), 0.03); border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06); text-align: center; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.modality-body { }
.time-cell { height: 80px; border-top: 1px solid rgba(var(--v-theme-on-surface), 0.04); padding: 2px 4px; position: relative; cursor: pointer; transition: background 0.15s; }
.time-cell:hover { background: rgba(var(--v-theme-primary), 0.03); }
.empty-slot { opacity: 0; transition: opacity 0.15s; height: 100%; display: flex; align-items: center; justify-content: center; }
.time-cell:hover .empty-slot { opacity: 1; }

/* Timeline blocks */
.timeline-block { border-left: 3px solid; overflow: hidden; font-size: 12px; min-height: 30px; }
.timeline-block--scheduled { border-color: #3B82F6; background: rgba(59, 130, 246, 0.08); }
.timeline-block--checked_in { border-color: #6366F1; background: rgba(99, 102, 241, 0.08); }
.timeline-block--in_progress { border-color: #F97316; background: rgba(249, 115, 22, 0.08); }
.timeline-block--completed { border-color: #10B981; background: rgba(16, 185, 129, 0.08); }
.timeline-block--no_show { border-color: #EF4444; background: rgba(239, 68, 68, 0.06); }
.timeline-block--cancelled { border-color: #9CA3AF; background: rgba(156, 163, 175, 0.06); opacity: 0.6; }

/* Detail drawer */
.detail-section { background: rgba(var(--v-theme-on-surface), 0.02); border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.detail-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.04); }
.detail-row:last-child { border-bottom: none; }
.detail-row span { color: rgba(var(--v-theme-on-surface), 0.6); font-size: 0.875rem; }

@keyframes pulse-bar { 0%,100% { opacity:1 } 50% { opacity:0.4 } }
</style>
