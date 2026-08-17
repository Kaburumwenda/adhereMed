<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Triage & Encounter Workflow" subtitle="Triage queue, doctor queue, and clinical workflow" icon="mdi-monitor-heart" color="error">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="r.loading.value" @click="loadAll">Refresh</v-btn>
        <v-btn color="error" rounded="lg" prepend-icon="mdi-plus" to="/clinics/triage/new">New Triage</v-btn>
      </template>
    </PageHeader>

    <!-- ── KPI Stat Cards ── -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-3" :loading="r.loading.value">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">IN TRIAGE QUEUE</div>
              <div class="text-h4 font-weight-bold text-error">{{ draftTriages.length }}</div>
              <div class="text-caption text-medium-emphasis">awaiting nurse</div>
            </div>
            <v-avatar color="error-lighten-5" variant="tonal" size="48">
              <v-icon color="error" size="24">mdi-clipboard-pulse</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-3">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">AWAITING DOCTOR</div>
              <div class="text-h4 font-weight-bold text-warning">{{ doctorQueue.length }}</div>
              <div class="text-caption text-medium-emphasis">triage completed</div>
            </div>
            <v-avatar color="warning-lighten-5" variant="tonal" size="48">
              <v-icon color="warning" size="24">mdi-stethoscope</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-3">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">CRITICAL (ESI 1-2)</div>
              <div class="text-h4 font-weight-bold text-red-darken-3">{{ criticalCount }}</div>
              <div class="text-caption text-medium-emphasis">high acuity</div>
            </div>
            <v-avatar color="red-lighten-5" variant="tonal" size="48">
              <v-icon color="red-darken-3" size="24">mdi-alert-circle</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-3">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">TOTAL TODAY</div>
              <div class="text-h4 font-weight-bold text-info">{{ todayCount }}</div>
              <div class="text-caption text-medium-emphasis">triage entries</div>
            </div>
            <v-avatar color="info-lighten-5" variant="tonal" size="48">
              <v-icon color="info" size="24">mdi-monitor-heart</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Analytical Stat Cards (with bars) ── -->
    <v-row dense class="mb-4">
      <!-- Status Distribution Card -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="stat-card-bar pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">STATUS DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-chart-bar</v-icon>
          </div>
          <div class="d-flex align-center ga-4 mb-3">
            <div class="flex-1">
              <div class="d-flex align-center ga-1 mb-1">
                <v-icon size="14" color="warning">mdi-flag</v-icon>
                <span class="text-caption font-weight-bold">Draft</span>
              </div>
              <div class="text-h5 font-weight-bold text-warning">{{ draftTriages.length }}</div>
            </div>
            <v-divider vertical />
            <div class="flex-1">
              <div class="d-flex align-center ga-1 mb-1">
                <v-icon size="14" color="success">mdi-check-circle</v-icon>
                <span class="text-caption font-weight-bold">Completed</span>
              </div>
              <div class="text-h5 font-weight-bold text-success">{{ doctorQueue.length }}</div>
            </div>
          </div>
          <!-- Stacked bar -->
          <div class="status-bar-container rounded-lg overflow-hidden">
            <div
              v-if="totalEntries"
              class="status-bar-draft"
              :style="{ width: `${(draftTriages.length / totalEntries) * 100}%` }"
            />
            <div
              v-if="totalEntries"
              class="status-bar-completed"
              :style="{ width: `${(doctorQueue.length / totalEntries) * 100}%` }"
            />
          </div>
          <div class="text-caption text-medium-emphasis mt-2">
            {{ totalEntries }} total entr{{ totalEntries === 1 ? 'y' : 'ies' }}
          </div>
        </v-card>
      </v-col>

      <!-- ESI Level Distribution Card -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="stat-card-bar pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">ESI LEVEL DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-chart-bell-curve</v-icon>
          </div>
          <div class="d-flex align-end ga-2 mb-2 esi-bar-chart">
            <div v-for="e in 5" :key="e" class="esi-bar-col flex-1 d-flex flex-column align-center">
              <span class="text-caption font-weight-bold mb-1" :class="esiCount(e) ? `text-${esiColorVarName(e)}` : 'text-medium-emphasis'">
                {{ esiCount(e) }}
              </span>
              <div
                class="esi-bar-fill rounded-top"
                :class="`esi-bar-${e}`"
                :style="{ height: `${esiBarHeight(e)}%` }"
              />
            </div>
          </div>
          <div class="d-flex ga-2 mt-1">
            <span v-for="e in 5" :key="e" class="text-caption text-medium-emphasis flex-1 text-center">ESI {{ e }}</span>
          </div>
        </v-card>
      </v-col>

      <!-- Days of Week Volume Card -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="stat-card-bar pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">TRIAGE VOLUME BY DAY</span>
            <v-icon size="16" color="medium-emphasis">mdi-calendar-week</v-icon>
          </div>
          <div class="d-flex align-end ga-1 mb-2 weekday-bar-chart">
            <div v-for="(d, i) in weekDays" :key="i" class="weekday-bar-col flex-1 d-flex flex-column align-center">
              <span class="text-caption font-weight-bold mb-1" :class="isToday(i) ? 'text-error' : 'text-medium-emphasis'">
                {{ weekdayCount(i) }}
              </span>
              <div
                class="weekday-bar-fill rounded-top"
                :class="{ 'weekday-bar-today': isToday(i) }"
                :style="{ height: `${weekdayBarHeight(i)}%` }"
              />
            </div>
          </div>
          <div class="d-flex ga-1 mt-1">
            <span v-for="(d, i) in weekDays" :key="i" class="text-caption flex-1 text-center"
              :class="isToday(i) ? 'font-weight-bold text-error' : 'text-medium-emphasis'"
            >{{ d }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Queue Tabs + View Toggle -->
    <div class="d-flex align-center justify-space-between mb-3 flex-wrap ga-2">
      <v-tabs v-model="queueTab" color="error" density="compact">
        <v-tab value="triage"><v-icon start size="18">mdi-clipboard-pulse</v-icon>Triage Queue ({{ draftTriages.length }})</v-tab>
        <v-tab value="doctor"><v-icon start size="18">mdi-stethoscope</v-icon>Doctor Queue ({{ doctorQueue.length }})</v-tab>
        <v-tab value="all"><v-icon start size="18">mdi-format-list-bulleted</v-icon>All Triage Entries</v-tab>
      </v-tabs>
      <!-- View toggle: List / Board (only for triage queue tab) -->
      <v-btn-toggle v-if="queueTab === 'triage'" v-model="triageViewMode" mandatory density="compact" color="error" rounded="lg">
        <v-btn value="list" size="small" variant="outlined"><v-icon start size="16">mdi-view-list</v-icon>List</v-btn>
        <v-btn value="board" size="small" variant="outlined"><v-icon start size="16">mdi-view-column</v-icon>Board</v-btn>
      </v-btn-toggle>
    </div>

    <v-window v-model="queueTab">
      <!-- ── TRIAGE QUEUE (drafts waiting for nurse) ── -->
      <v-window-item value="triage">
        <!-- List View -->
        <v-card v-if="triageViewMode === 'list'" rounded="lg">
          <v-card-text>
            <div v-if="!draftTriages.length && !r.loading.value" class="text-center pa-8">
              <v-icon size="64" color="grey-lighten-1">mdi-clipboard-pulse</v-icon>
              <div class="text-h6 mt-2">No patients in triage queue</div>
              <div class="text-body-2 text-medium-emphasis">New patients awaiting triage will appear here</div>
              <v-btn color="error" class="mt-3" to="/clinics/triage/new" prepend-icon="mdi-plus">Start New Triage</v-btn>
            </div>
            <div v-else class="d-flex flex-column ga-2">
              <v-card
                v-for="item in draftTriages" :key="item.id"
                variant="outlined" hover class="queue-card pa-3"
                :class="waitTimeClass(item.triage_time)"
                :to="`/clinics/triage/workspace/${item.id}`"
              >
                <div class="d-flex align-center justify-space-between flex-wrap ga-2">
                  <div class="d-flex align-center ga-3">
                    <v-avatar color="error" variant="tonal" size="44">
                      <v-icon>mdi-account</v-icon>
                    </v-avatar>
                    <div>
                      <div class="font-weight-bold text-subtitle-1">{{ item.patient_name }}</div>
                      <div class="text-caption text-medium-emphasis d-flex align-center ga-2">
                        <v-icon size="12">mdi-clock-outline</v-icon>
                        {{ formatDateTime(item.triage_time) }}
                        <span class="ml-1">·</span>
                        <v-chip size="x-small" variant="tonal" color="warning" prepend-icon="mdi-flag">
                          Draft
                        </v-chip>
                      </div>
                    </div>
                  </div>
                  <div class="d-flex align-center ga-2">
                    <div class="wait-time-badge">
                      <v-icon size="14" :color="waitTimeColor(item.triage_time)">mdi-timer-sand</v-icon>
                      <span class="text-caption font-weight-bold" :class="waitTextColor(item.triage_time)">
                        {{ waitTime(item.triage_time) }}
                      </span>
                    </div>
                    <v-btn color="error" size="small" variant="tonal" prepend-icon="mdi-heart-pulse">
                      Continue Triage
                    </v-btn>
                  </div>
                </div>
              </v-card>
            </div>
          </v-card-text>
        </v-card>

        <!-- Board View (Kanban-style columns by ESI level) -->
        <div v-else>
          <div v-if="!draftTriages.length && !r.loading.value" class="text-center pa-8">
            <v-icon size="64" color="grey-lighten-1">mdi-clipboard-pulse</v-icon>
            <div class="text-h6 mt-2">No patients in triage queue</div>
            <div class="text-body-2 text-medium-emphasis">New patients awaiting triage will appear here</div>
            <v-btn color="error" class="mt-3" to="/clinics/triage/new" prepend-icon="mdi-plus">Start New Triage</v-btn>
          </div>
          <div v-else class="triage-board d-flex ga-3 overflow-x-auto pb-2">
            <!-- Column: Unassigned ESI -->
            <div class="board-column flex-1" style="min-width: 260px">
              <div class="board-col-header d-flex align-center justify-space-between px-3 py-2 rounded-t-lg board-col-unassigned">
                <div class="d-flex align-center ga-2">
                  <v-icon size="18" color="grey-darken-1">mdi-help-circle</v-icon>
                  <span class="text-subtitle-2 font-weight-bold">Unassigned</span>
                </div>
                <v-chip size="x-small" variant="flat" color="grey-darken-2">{{ boardColumnItems(null).length }}</v-chip>
              </div>
              <div class="board-col-body pa-2 ga-2 d-flex flex-column">
                <div
                  v-for="item in boardColumnItems(null)" :key="item.id"
                  class="board-card pa-3 rounded-lg"
                  :class="waitTimeClass(item.triage_time)"
                  @click="navigateTo(`/clinics/triage/workspace/${item.id}`)"
                >
                  <div class="d-flex align-center justify-space-between mb-1">
                    <span class="text-body-2 font-weight-bold text-truncate">{{ item.patient_name }}</span>
                    <v-icon size="14" :color="waitTimeColor(item.triage_time)">mdi-timer-sand</v-icon>
                  </div>
                  <div class="text-caption text-medium-emphasis mb-2 text-truncate">
                    {{ item.chief_complaint || 'No complaint yet' }}
                  </div>
                  <div class="d-flex align-center justify-space-between">
                    <div class="wait-time-badge">
                      <span class="text-caption font-weight-bold" :class="waitTextColor(item.triage_time)">
                        {{ waitTime(item.triage_time) }}
                      </span>
                    </div>
                    <v-chip size="x-small" variant="tonal" color="warning" prepend-icon="mdi-flag">Draft</v-chip>
                  </div>
                </div>
                <div v-if="!boardColumnItems(null).length" class="text-center text-caption text-medium-emphasis py-4">
                  No patients
                </div>
              </div>
            </div>
            <!-- Columns: ESI 1 through 5 -->
            <div v-for="esi in 5" :key="esi" class="board-column flex-1" style="min-width: 220px">
              <div class="board-col-header d-flex align-center justify-space-between px-3 py-2 rounded-t-lg" :class="`board-col-esi-${esi}`">
                <div class="d-flex align-center ga-2">
                  <v-avatar :color="esiColor(esi)" size="24" variant="tonal" class="esi-avatar">
                    <span class="text-caption font-weight-black">{{ esi }}</span>
                  </v-avatar>
                  <span class="text-subtitle-2 font-weight-bold">ESI {{ esi }}</span>
                  <span class="text-caption text-medium-emphasis d-none d-md-inline">{{ esiLabels[esi] }}</span>
                </div>
                <v-chip size="x-small" variant="flat" :color="esiColor(esi)">{{ boardColumnItems(esi).length }}</v-chip>
              </div>
              <div class="board-col-body pa-2 ga-2 d-flex flex-column">
                <div
                  v-for="item in boardColumnItems(esi)" :key="item.id"
                  class="board-card pa-3 rounded-lg"
                  :class="waitTimeClass(item.triage_time)"
                  @click="navigateTo(`/clinics/triage/workspace/${item.id}`)"
                >
                  <div class="d-flex align-center justify-space-between mb-1">
                    <span class="text-body-2 font-weight-bold text-truncate">{{ item.patient_name }}</span>
                    <v-icon size="14" :color="waitTimeColor(item.triage_time)">mdi-timer-sand</v-icon>
                  </div>
                  <div class="text-caption text-medium-emphasis mb-2 text-truncate">
                    {{ item.chief_complaint || 'No complaint yet' }}
                  </div>
                  <div class="d-flex align-center justify-space-between">
                    <div class="wait-time-badge">
                      <span class="text-caption font-weight-bold" :class="waitTextColor(item.triage_time)">
                        {{ waitTime(item.triage_time) }}
                      </span>
                    </div>
                    <v-chip :color="news2Color(item.news2_score)" size="x-small" variant="tonal" class="font-weight-bold">
                      NEWS2 {{ item.news2_score || 0 }}
                    </v-chip>
                  </div>
                </div>
                <div v-if="!boardColumnItems(esi).length" class="text-center text-caption text-medium-emphasis py-4">
                  No patients
                </div>
              </div>
            </div>
          </div>
        </div>
      </v-window-item>

      <!-- ── DOCTOR QUEUE (completed triages awaiting doctor) ── -->
      <v-window-item value="doctor">
        <v-card rounded="lg">
          <v-card-text>
            <div v-if="!doctorQueue.length && !r.loading.value" class="text-center pa-8">
              <v-icon size="64" color="grey-lighten-1">mdi-stethoscope</v-icon>
              <div class="text-h6 mt-2">No patients in doctor queue</div>
              <div class="text-body-2 text-medium-emphasis">Completed triages will appear here for doctor review</div>
            </div>
            <div v-else class="d-flex flex-column ga-2">
              <v-card
                v-for="item in doctorQueue" :key="item.id"
                variant="outlined" hover class="doctor-card pa-3"
                :class="`esi-border-${item.esi_level || 5}`"
                @click="startConsultationFromTriage(item)"
              >
                <div class="d-flex align-center justify-space-between flex-wrap ga-2">
                  <div class="d-flex align-center ga-3">
                    <v-avatar
                      :color="esiColor(item.esi_level)" variant="tonal" size="48"
                      class="esi-avatar"
                    >
                      <span class="text-h5 font-weight-black">{{ item.esi_level || '?' }}</span>
                    </v-avatar>
                    <div>
                      <div class="font-weight-bold text-subtitle-1">{{ item.patient_name }}</div>
                      <div class="text-caption text-medium-emphasis d-flex align-center ga-1 flex-wrap">
                        <span v-if="item.chief_complaint" class="text-truncate" style="max-width: 220px">
                          <v-icon size="12" class="mr-1">mdi-format-quote-close</v-icon>{{ item.chief_complaint }}
                        </span>
                        <span class="ml-1">·</span>
                        <v-icon size="12" class="ml-1">mdi-clock-check</v-icon>
                        {{ formatDateTime(item.completed_at) }}
                      </div>
                    </div>
                  </div>
                  <div class="d-flex align-center ga-2 flex-wrap">
                    <v-chip :color="esiColor(item.esi_level)" size="small" variant="tonal" class="font-weight-bold">
                      ESI {{ item.esi_level }}
                    </v-chip>
                    <v-chip :color="news2Color(item.news2_score)" size="small" variant="tonal" class="font-weight-bold">
                      <v-icon start size="14">mdi-heart-pulse</v-icon>
                      NEWS2 {{ item.news2_score || 0 }}
                    </v-chip>
                    <v-btn color="primary" size="small" variant="tonal" prepend-icon="mdi-stethoscope">
                      Start Consult
                    </v-btn>
                  </div>
                </div>
              </v-card>
            </div>
          </v-card-text>
        </v-card>
      </v-window-item>

      <!-- ── ALL TRIAGE ENTRIES ── -->
      <v-window-item value="all">
        <v-card rounded="lg">
          <v-card-text>
            <v-row dense class="mb-2" align="center">
              <v-col cols="12" md="6">
                <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify" placeholder="Search triage…" variant="outlined" density="compact" hide-details clearable />
              </v-col>
              <v-col cols="6" md="3">
                <v-select v-model="statusFilter" :items="statusOptions" label="Status" variant="outlined" density="compact" hide-details clearable />
              </v-col>
              <v-col cols="6" md="3">
                <v-select v-model="esiFilter" :items="[1,2,3,4,5]" label="ESI Level" variant="outlined" density="compact" hide-details clearable />
              </v-col>
            </v-row>
            <v-data-table :headers="headers" :items="allFiltered" :loading="r.loading.value" density="compact" hover @click:row="goDetail">
              <template #item.status="{ value }">
                <v-chip :color="value === 'completed' ? 'success' : 'warning'" size="small" variant="tonal">{{ value }}</v-chip>
              </template>
              <template #item.esi_level="{ value }">
                <v-chip v-if="value" :color="esiColor(value)" size="small" variant="tonal" class="font-weight-bold">ESI {{ value }}</v-chip>
                <span v-else>—</span>
              </template>
              <template #item.news2_score="{ value }">
                <v-chip v-if="value != null" :color="news2Color(value)" size="small" variant="tonal" class="font-weight-bold">{{ value }}</v-chip>
                <span v-else>—</span>
              </template>
              <template #item.triage_time="{ value }">{{ formatDateTime(value) }}</template>
              <template #item.actions="{ item }">
                <v-btn icon="mdi-monitor-heart" size="small" variant="text" :to="`/clinics/triage/workspace/${item.id}`" />
                <v-btn v-if="item.status === 'completed'" icon="mdi-stethoscope" size="small" variant="text" color="primary" @click.stop="startConsultationFromTriage(item)" />
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-window-item>
    </v-window>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
import { esiColor, news2Color } from '~/composables/useClinicalScoring'
import { useAuthStore } from '~/stores/auth'

const r = useResource('/triage/')
const { $api } = useNuxtApp()
const auth = useAuthStore()
const queueTab = ref('triage')
const triageViewMode = ref('list')
const statusFilter = ref('')
const esiFilter = ref('')

const esiLabels = {
  1: 'Resuscitation',
  2: 'Emergent',
  3: 'Urgent',
  4: 'Less Urgent',
  5: 'Non-Urgent',
}

// Board view: group drafts by ESI level
function boardColumnItems(esiLevel) {
  const drafts = draftTriages.value
  if (esiLevel === null) {
    return drafts.filter(i => !i.esi_level)
  }
  return drafts.filter(i => i.esi_level === esiLevel)
}

const statusOptions = [
  { title: 'Draft', value: 'draft' },
  { title: 'Completed', value: 'completed' },
]

onMounted(() => loadAll())

// Auto-refresh every 30 seconds
let refreshTimer = null
onMounted(() => { refreshTimer = setInterval(loadAll, 30000) })
onUnmounted(() => { if (refreshTimer) clearInterval(refreshTimer) })

async function loadAll() {
  await r.list({ page_size: 1000 })
}

const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'ESI', key: 'esi_level' },
  { title: 'NEWS2', key: 'news2_score' },
  { title: 'Status', key: 'status' },
  { title: 'Chief Complaint', key: 'chief_complaint' },
  { title: 'Time', key: 'triage_time' },
  { title: 'Actions', key: 'actions', sortable: false },
]

const draftTriages = computed(() => r.items.value.filter(t => t.status === 'draft'))
const doctorQueue = computed(() => r.items.value.filter(t => t.status === 'completed')
  .sort((a, b) => (a.esi_level || 5) - (b.esi_level || 5)))
const allFiltered = computed(() => r.filtered.value.filter(t => {
  if (statusFilter.value && t.status !== statusFilter.value) return false
  if (esiFilter.value && t.esi_level !== esiFilter.value) return false
  return true
}))

const criticalCount = computed(() => r.items.value.filter(i => i.esi_level && i.esi_level <= 2).length)
const todayCount = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return r.items.value.filter(i => (i.triage_time || '').startsWith(today)).length
})

// ── Status Distribution ──
const totalEntries = computed(() => r.items.value.length)

// ── ESI Level Distribution ──
function esiCount(level) {
  return r.items.value.filter(i => i.esi_level === level).length
}
function esiBarHeight(level) {
  const max = Math.max(...[1, 2, 3, 4, 5].map(esiCount), 1)
  return Math.max(6, (esiCount(level) / max) * 100)
}
function esiColorVarName(level) {
  return { 1: 'red-darken-3', 2: 'error', 3: 'warning', 4: 'success', 5: 'info' }[level] || 'medium-emphasis'
}

// ── Days of Week Volume ──
const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
function getDayIndex(dateStr) {
  if (!dateStr) return -1
  const d = new Date(dateStr)
  let day = d.getDay() // 0 = Sunday
  // Convert to Monday-based (0=Mon, 6=Sun)
  return day === 0 ? 6 : day - 1
}
function isToday(dayIdx) {
  let today = new Date().getDay()
  today = today === 0 ? 6 : today - 1
  return today === dayIdx
}
function weekdayCount(dayIdx) {
  // Count entries from the current week (last 7 days, grouped by day of week)
  const now = new Date()
  const weekStart = new Date(now)
  // Get the start of current week (Monday)
  const currentDay = now.getDay() === 0 ? 6 : now.getDay() - 1
  weekStart.setDate(now.getDate() - currentDay)
  weekStart.setHours(0, 0, 0, 0)

  return r.items.value.filter(i => {
    if (!i.triage_time) return false
    const entryDate = new Date(i.triage_time)
    if (entryDate < weekStart) return false
    return getDayIndex(i.triage_time) === dayIdx
  }).length
}
function weekdayBarHeight(dayIdx) {
  const max = Math.max(...[0, 1, 2, 3, 4, 5, 6].map(weekdayCount), 1)
  return Math.max(6, (weekdayCount(dayIdx) / max) * 100)
}

// Wait time helpers
function waitTime(timeStr) {
  if (!timeStr) return '—'
  const diff = Date.now() - new Date(timeStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `${mins}m`
  const hrs = Math.floor(mins / 60)
  const remMins = mins % 60
  return `${hrs}h ${remMins}m`
}
function waitTimeColor(timeStr) {
  if (!timeStr) return 'grey'
  const mins = (Date.now() - new Date(timeStr).getTime()) / 60000
  if (mins > 30) return 'error'
  if (mins > 15) return 'warning'
  return 'success'
}
function waitTextColor(timeStr) {
  const c = waitTimeColor(timeStr)
  return { success: 'text-success', warning: 'text-warning', error: 'text-error', grey: 'text-medium-emphasis' }[c]
}
function waitTimeClass(timeStr) {
  const c = waitTimeColor(timeStr)
  return { 'border-l-error': c === 'error', 'border-l-warning': c === 'warning' }[c] || ''
}

function goDetail(_, item) { navigateTo(`/clinics/triage/workspace/${item.id}`) }

async function startConsultationFromTriage(item) {
  try {
    const { data } = await $api.get('/consultations/', { params: { triage: item.id, page_size: 1 } })
    if (data.results?.length) {
      navigateTo(`/clinics/consultations/workspace/${data.results[0].id}`)
    } else {
      const { data: consult } = await $api.post('/consultations/', {
        patient: item.patient, triage: item.id, doctor: auth.user?.id, draft_owner: auth.user?.id,
        chief_complaint: item.chief_complaint, vital_signs: item.vital_signs, status: 'draft',
      })
      navigateTo(`/clinics/consultations/workspace/${consult.id}`)
    }
  } catch (e) {
    console.error('Failed to start consultation', e)
  }
}
</script>

<style scoped>
.stat-card { transition: box-shadow 0.2s; }
.stat-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08) }
.queue-card { border-left: 4px solid transparent; transition: border-color 0.2s; }
.queue-card.border-l-warning { border-left-color: #ff9800; }
.queue-card.border-l-error { border-left-color: #d32f2f; }
.doctor-card { border-left: 4px solid transparent; transition: all 0.2s; }
.esi-border-1 { border-left-color: #b71c1c !important; }
.esi-border-2 { border-left-color: #d32f2f !important; }
.esi-border-3 { border-left-color: #ff9800 !important; }
.esi-border-4 { border-left-color: #4caf50 !important; }
.esi-border-5 { border-left-color: #2196f3 !important; }
.esi-avatar { font-family: 'Inter', sans-serif; }
.wait-time-badge {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 2px 8px; border-radius: 8px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}

/* ── Stat Cards with Bars ── */
.stat-card-bar {
  position: relative;
  overflow: hidden;
}
.flex-1 { flex: 1; }

/* Status distribution stacked bar */
.status-bar-container {
  display: flex;
  height: 10px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.status-bar-draft {
  background: rgb(var(--v-theme-warning));
  transition: width 0.3s ease;
}
.status-bar-completed {
  background: rgb(var(--v-theme-success));
  transition: width 0.3s ease;
}

/* ESI bar chart */
.esi-bar-chart {
  height: 80px;
  align-items: flex-end;
}
.esi-bar-col {
  height: 100%;
  justify-content: flex-end;
}
.esi-bar-fill {
  width: 100%;
  min-height: 4px;
  opacity: 0.75;
  transition: height 0.3s ease, opacity 0.2s ease;
}
.esi-bar-fill:hover { opacity: 1; }
.esi-bar-1 { background: #b71c1c; }
.esi-bar-2 { background: #d32f2f; }
.esi-bar-3 { background: #ff9800; }
.esi-bar-4 { background: #4caf50; }
.esi-bar-5 { background: #2196f3; }
.rounded-top { border-radius: 4px 4px 0 0; }

/* Weekday bar chart */
.weekday-bar-chart {
  height: 80px;
  align-items: flex-end;
}
.weekday-bar-col {
  height: 100%;
  justify-content: flex-end;
}
.weekday-bar-fill {
  width: 100%;
  min-height: 4px;
  background: rgba(var(--v-theme-error), 0.4);
  opacity: 0.6;
  transition: height 0.3s ease, opacity 0.2s ease;
}
.weekday-bar-fill:hover { opacity: 0.85; }
.weekday-bar-today {
  background: rgb(var(--v-theme-error));
  opacity: 0.8;
}

/* ── Triage Board View (Kanban) ── */
.triage-board {
  min-height: 400px;
}
.board-column {
  background: rgba(var(--v-theme-on-surface), 0.03);
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  display: flex;
  flex-direction: column;
}
.board-col-header {
  border-bottom: 2px solid transparent;
}
.board-col-body {
  flex: 1;
  min-height: 200px;
  max-height: 60vh;
  overflow-y: auto;
}
.board-card {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  border-left: 4px solid transparent;
  cursor: pointer;
  transition: box-shadow 0.2s, transform 0.15s;
}
.board-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-1px);
}
.board-card.border-l-warning { border-left-color: #ff9800; }
.board-card.border-l-error { border-left-color: #d32f2f; }

/* Column header colors */
.board-col-unassigned { border-bottom-color: #9e9e9e; background: rgba(158, 158, 158, 0.06); }
.board-col-esi-1 { border-bottom-color: #b71c1c; background: rgba(183, 28, 28, 0.06); }
.board-col-esi-2 { border-bottom-color: #d32f2f; background: rgba(211, 47, 47, 0.06); }
.board-col-esi-3 { border-bottom-color: #ff9800; background: rgba(255, 152, 0, 0.06); }
.board-col-esi-4 { border-bottom-color: #4caf50; background: rgba(76, 175, 80, 0.06); }
.board-col-esi-5 { border-bottom-color: #2196f3; background: rgba(33, 150, 243, 0.06); }
</style>
