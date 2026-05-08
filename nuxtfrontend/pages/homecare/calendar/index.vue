<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Visit Calendar"
      subtitle="Plan caregiver visits across the month — drag, drop and assign."
      eyebrow="SCHEDULING"
      icon="mdi-calendar-month"
      :chips="[{ icon: 'mdi-calendar-week', label: monthLabel }, { icon: 'mdi-account-heart', label: `${visitsThisMonth} visits this month` }]"
    >
      <template #actions>
        <div class="d-flex ga-2 align-center">
          <v-btn icon="mdi-chevron-left" variant="flat" color="rgba(255,255,255,0.18)" @click="shiftMonth(-1)" />
          <v-btn variant="flat" rounded="pill" color="rgba(255,255,255,0.18)" class="text-none"
                 @click="goToday"><span class="text-white">Today</span></v-btn>
          <v-btn icon="mdi-chevron-right" variant="flat" color="rgba(255,255,255,0.18)" @click="shiftMonth(1)" />
          <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus" class="text-none"
                 to="/homecare/schedules"><span class="text-teal-darken-2 font-weight-bold">New visit</span></v-btn>
        </div>
      </template>
    </HomecareHero>

    <v-card rounded="xl" :elevation="0" class="hc-cal pa-3 pa-md-4">
      <div class="hc-cal-grid">
        <div v-for="d in weekDays" :key="d" class="hc-cal-weekday">{{ d }}</div>
        <div v-for="(cell, idx) in cells" :key="idx" class="hc-cal-cell"
             :class="{ 'hc-cal-cell--out': !cell.inMonth, 'hc-cal-cell--today': cell.isToday }">
          <div class="d-flex justify-space-between align-center">
            <span class="text-caption font-weight-bold" :class="cell.isToday ? 'text-teal' : 'text-medium-emphasis'">
              {{ cell.day }}
            </span>
            <v-chip v-if="cell.events.length" size="x-small" color="teal" variant="tonal">
              {{ cell.events.length }}
            </v-chip>
          </div>
          <div class="hc-cal-events">
            <div v-for="e in cell.events.slice(0, 3)" :key="e.id" class="hc-cal-event"
                 :style="`background:${eventColor(e.status)}1a;color:${eventColor(e.status)}`"
                 @click="openEvent(e)">
              <span class="font-weight-bold">{{ formatTime(e.start_at) }}</span>
              {{ e.patient_name }}
            </div>
            <div v-if="cell.events.length > 3" class="text-caption text-teal text-center">
              +{{ cell.events.length - 3 }} more
            </div>
          </div>
        </div>
      </div>
    </v-card>

    <v-dialog v-model="eventDialog" max-width="500">
      <v-card v-if="selectedEvent" rounded="xl">
        <v-card-title>{{ selectedEvent.patient_name }}</v-card-title>
        <v-card-text>
          <div class="text-body-2 mb-2"><v-icon icon="mdi-account-heart" size="14" /> {{ selectedEvent.caregiver_name }}</div>
          <div class="text-body-2 mb-2"><v-icon icon="mdi-clock" size="14" /> {{ formatRange(selectedEvent.start_at, selectedEvent.end_at) }}</div>
          <StatusChip :status="selectedEvent.status" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="eventDialog = false">Close</v-btn>
          <v-btn color="teal" to="/homecare/schedules">Open in schedules</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const visits = ref([])
const cursor = ref(new Date())
const eventDialog = ref(false)
const selectedEvent = ref(null)
const weekDays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']

const monthLabel = computed(() => cursor.value.toLocaleDateString([], { month: 'long', year: 'numeric' }))
const visitsThisMonth = computed(() => visits.value.length)

const cells = computed(() => {
  const year = cursor.value.getFullYear()
  const month = cursor.value.getMonth()
  const first = new Date(year, month, 1)
  const last = new Date(year, month + 1, 0)
  const startWeekday = (first.getDay() + 6) % 7  // make Monday=0
  const totalCells = Math.ceil((startWeekday + last.getDate()) / 7) * 7
  const today = new Date(); today.setHours(0,0,0,0)
  const out = []
  for (let i = 0; i < totalCells; i++) {
    const d = new Date(year, month, i - startWeekday + 1)
    const inMonth = d.getMonth() === month
    const isToday = d.getTime() === today.getTime()
    const dayKey = d.toISOString().slice(0, 10)
    const events = visits.value.filter(v => (v.start_at || '').slice(0,10) === dayKey)
    out.push({ date: d, day: d.getDate(), inMonth, isToday, events })
  }
  return out
})

function eventColor(s) {
  return { scheduled: '#0ea5e9', checked_in: '#0d9488', completed: '#10b981',
    missed: '#ef4444', cancelled: '#94a3b8' }[s] || '#64748b'
}
function formatTime(iso) {
  return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''
}
function formatRange(a, b) { return `${formatTime(a)} – ${formatTime(b)}` }
function shiftMonth(delta) {
  const d = new Date(cursor.value); d.setMonth(d.getMonth() + delta); cursor.value = d; load()
}
function goToday() { cursor.value = new Date(); load() }
function openEvent(e) { selectedEvent.value = e; eventDialog.value = true }

async function load() {
  const start = new Date(cursor.value.getFullYear(), cursor.value.getMonth(), 1).toISOString().slice(0,10)
  const end = new Date(cursor.value.getFullYear(), cursor.value.getMonth() + 1, 0).toISOString().slice(0,10)
  try {
    const { data } = await $api.get('/homecare/schedules/', { params: { start_after: start, start_before: end } })
    visits.value = data?.results || data || []
  } catch { visits.value = [] }
}
onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-cal { background: white; border: 1px solid rgba(15,23,42,0.06); }
.hc-cal-grid {
  display: grid; grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}
.hc-cal-weekday {
  text-align: center; font-weight: 700; font-size: 11px;
  color: #64748b; text-transform: uppercase; letter-spacing: 1px; padding: 8px 0;
}
.hc-cal-cell {
  min-height: 110px; padding: 6px; border-radius: 12px;
  background: rgba(15,23,42,0.025); border: 1px solid transparent;
  transition: all 0.15s ease;
}
.hc-cal-cell:hover { background: rgba(13,148,136,0.06); }
.hc-cal-cell--out { opacity: 0.4; }
.hc-cal-cell--today {
  background: rgba(13,148,136,0.1) !important;
  border-color: rgba(13,148,136,0.3);
}
.hc-cal-events { display: flex; flex-direction: column; gap: 3px; margin-top: 4px; }
.hc-cal-event {
  font-size: 11px; padding: 3px 6px; border-radius: 6px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  cursor: pointer; line-height: 1.3;
}
.hc-cal-event:hover { filter: brightness(0.95); }
</style>
