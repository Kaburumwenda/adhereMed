<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Doses"
      subtitle="Scheduled medication doses across all patients. Track adherence in real time."
      eyebrow="ADHERENCE"
      icon="mdi-clipboard-pulse"
      :chips="[
        { icon: 'mdi-clock-outline',  label: `${stats.pending} pending` },
        { icon: 'mdi-check-decagram', label: `${stats.taken} taken today` },
        { icon: 'mdi-percent',        label: `${stats.adherence}% adherence` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white"
               prepend-icon="mdi-refresh" class="text-none mr-2"
               :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
        <v-btn variant="tonal" rounded="pill" color="white"
               prepend-icon="mdi-chart-line" class="text-none mr-2"
               to="/homecare/doses/analysis">
          <span class="font-weight-bold">Analysis</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-pill" class="text-none"
               to="/homecare/medications">
          <span class="text-teal-darken-2 font-weight-bold">Schedules</span>
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
      <v-col cols="12">
        <HomecarePanel title="Doses timeline" subtitle="Grouped by hour"
                       icon="mdi-timeline-clock" color="#0d9488">
          <v-row dense class="mb-2">
            <v-col cols="12" md="5">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                            placeholder="Search patient or drug…" density="compact"
                            variant="outlined" hide-details rounded="lg" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="filterStatus" :items="statusOptions"
                        label="Status" density="compact" variant="outlined"
                        hide-details clearable rounded="lg" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="filterDate" :items="dateRangeOptions"
                        label="Date range" density="compact" variant="outlined"
                        hide-details rounded="lg"
                        prepend-inner-icon="mdi-calendar-range" />
            </v-col>
            <v-col v-if="filterDate === 'custom'" cols="12" md="6">
              <v-text-field v-model="customFrom" type="date" label="From"
                            density="compact" variant="outlined" hide-details rounded="lg" />
            </v-col>
            <v-col v-if="filterDate === 'custom'" cols="12" md="6">
              <v-text-field v-model="customTo" type="date" label="To"
                            density="compact" variant="outlined" hide-details rounded="lg" />
            </v-col>
          </v-row>

          <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-2" rounded />

          <div v-if="grouped.length">
            <div v-for="g in grouped" :key="g.key" class="mb-3">
              <div class="d-flex align-center mb-1 flex-wrap ga-2">
                <v-chip color="teal" variant="tonal" size="small" class="hc-date-chip">
                  <v-icon start icon="mdi-clock" /> {{ g.label }}
                </v-chip>
                <v-divider class="flex-grow-1" />
                <span class="text-caption text-medium-emphasis">{{ g.list.length }} dose(s)</span>
              </div>
              <v-card v-for="d in g.list" :key="d.id" class="hc-dose-card mb-2"
                      rounded="xl" :elevation="0">
                <div class="hc-dose-band" :style="{ background: statusColor(d.status).hex }" />
                <div class="pa-3 pl-4 d-flex align-center ga-3 flex-wrap">
                  <v-avatar size="40" :color="statusColor(d.status).vuetify" variant="tonal">
                    <v-icon :icon="statusIcon(d.status)" />
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-2 font-weight-bold">
                        {{ d.medication_name || d.schedule_medication || 'Medication' }}
                      </div>
                      <v-chip size="x-small" :color="statusColor(d.status).vuetify" variant="flat"
                              class="text-white font-weight-bold">
                        <v-icon :icon="statusIcon(d.status)" size="12" start />
                        {{ statusDisplay(d.status) }}
                      </v-chip>
                      <v-chip v-if="d.auto_missed" size="x-small" color="amber" variant="tonal">
                        <v-icon icon="mdi-robot" size="12" start /> Auto
                      </v-chip>
                      <v-chip v-if="d.dose" size="x-small" variant="text">
                        {{ d.dose }} {{ d.dose_unit }}
                      </v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis hc-dose-meta">
                      <span><v-icon icon="mdi-account" size="12" /> {{ d.patient_name || '—' }}</span>
                      <span><v-icon icon="mdi-calendar" size="12" /> Scheduled {{ formatFullDateTime(d.scheduled_at) }}</span>
                      <span v-if="d.administered_at">
                        <v-icon icon="mdi-check" size="12" /> Given {{ formatFullDateTime(d.administered_at) }}
                      </span>
                      <span v-if="d.administered_by_name">
                        <v-icon icon="mdi-account-check" size="12" />
                        by <strong>{{ d.administered_by_name }}</strong>
                        <span v-if="d.administered_by_role" class="text-medium-emphasis">
                          ({{ d.administered_by_role }})
                        </span>
                      </span>
                    </div>
                    <div v-if="d.reason" class="text-caption hc-reason mt-1">
                      <v-icon icon="mdi-message-alert" size="12" /> Reason: {{ d.reason }}
                    </div>
                  </div>
                  <div class="d-flex ga-1 flex-wrap justify-end">
                    <template v-if="d.status === 'pending' || d.status === 'overdue'">
                      <v-btn size="small" color="success" variant="flat" rounded="lg"
                             class="text-none" prepend-icon="mdi-clipboard-check"
                             @click="openAction(d, 'document')">Document</v-btn>
                      <v-btn size="small" color="warning" variant="tonal" rounded="lg"
                             class="text-none" prepend-icon="mdi-skip-next"
                             @click="openAction(d, 'skip')">Skip</v-btn>
                      <v-btn size="small" color="error" variant="tonal" rounded="lg"
                             class="text-none" prepend-icon="mdi-cancel"
                             @click="openAction(d, 'not_given')">Not given</v-btn>
                      <v-btn size="small" color="primary" variant="tonal" rounded="lg"
                             class="text-none" prepend-icon="mdi-pencil-box"
                             @click="openAction(d, 'edit')">Edit</v-btn>
                    </template>
                    <template v-else>
                      <v-btn size="small" color="primary" variant="tonal" rounded="lg"
                             class="text-none" prepend-icon="mdi-pencil-box"
                             @click="openAction(d, 'edit')">Edit assessment</v-btn>
                    </template>
                    <v-btn size="small" variant="text" rounded="lg" class="text-none"
                           :prepend-icon="expanded[d.id] ? 'mdi-chevron-up' : 'mdi-history'"
                           @click="expanded[d.id] = !expanded[d.id]">
                      {{ expanded[d.id] ? 'Hide log' : 'Log' }}
                    </v-btn>
                  </div>
                </div>
                <v-expand-transition>
                  <div v-if="expanded[d.id]" class="px-4 pb-3">
                    <v-divider class="mb-2" />
                    <div class="text-overline text-medium-emphasis mb-1">AUDIT TRAIL</div>
                    <div v-if="(d.audit_log || []).length">
                      <div v-for="(log, i) in d.audit_log" :key="i"
                           class="hc-audit d-flex ga-2 align-start py-1">
                        <v-avatar size="22" :color="auditColor(log.action)" variant="tonal">
                          <v-icon :icon="auditIcon(log.action)" size="12" />
                        </v-avatar>
                        <div class="flex-grow-1">
                          <div class="text-caption">
                            <strong>{{ log.by_name || 'system' }}</strong>
                            <span class="text-medium-emphasis"> · {{ log.action }}</span>
                            <span v-if="log.status_to" class="text-medium-emphasis">
                              → {{ statusDisplay(log.status_to) }}
                            </span>
                          </div>
                          <div class="text-caption text-medium-emphasis">
                            {{ formatFullDateTime(log.at) }}
                            <span v-if="log.dose_to !== undefined">
                              · dose <strong>{{ log.dose_from || '—' }}</strong>
                              → <strong>{{ log.dose_to }}</strong>
                            </span>
                            <span v-if="log.reason"> · {{ log.reason }}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div v-else class="text-caption text-medium-emphasis">No history yet.</div>
                  </div>
                </v-expand-transition>
              </v-card>
            </div>

            <!-- Pagination -->
            <div class="d-flex align-center justify-space-between flex-wrap mt-3">
              <span class="text-caption text-medium-emphasis">
                Showing {{ pagedFrom }}–{{ pagedTo }} of {{ filtered.length }}
              </span>
              <v-pagination v-model="page" :length="totalPages" :total-visible="6"
                            density="comfortable" rounded="circle" />
            </div>
          </div>
          <EmptyState v-else icon="mdi-clipboard-pulse" title="No doses" message="Try a different filter." />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="6">
        <HomecarePanel title="Status breakdown" icon="mdi-chart-donut" color="#7c3aed">
          <DonutRing :segments="segments" :size="180" :thickness="18">
            <div class="text-h4 font-weight-bold">{{ stats.adherence }}%</div>
            <div class="text-caption text-medium-emphasis">adherence</div>
          </DonutRing>
          <v-divider class="my-3" />
          <div v-for="r in rows" :key="r.label"
               class="d-flex align-center pa-2 rounded-lg mb-1"
               :style="{ background: r.bg }">
            <v-avatar size="28" :color="r.color" variant="flat" class="mr-2">
              <v-icon :icon="r.icon" color="white" size="14" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ r.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ r.count }} dose(s)</div>
            </div>
          </div>
        </HomecarePanel>

      </v-col>

      <v-col cols="12" md="6">
        <HomecarePanel title="Adherence by patient" icon="mdi-account-group" color="#0284c7">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="p in patientAdherence" :key="p.name" rounded="lg">
              <v-list-item-title class="d-flex align-center">
                <span class="font-weight-bold flex-grow-1 text-truncate">{{ p.name }}</span>
                <v-chip size="x-small" :color="adherenceColor(p.pct)" variant="tonal">
                  {{ p.pct }}%
                </v-chip>
              </v-list-item-title>
              <v-progress-linear :model-value="p.pct" :color="adherenceColor(p.pct)"
                                 height="4" rounded class="mt-1" />
            </v-list-item>
            <EmptyState v-if="!patientAdherence.length" icon="mdi-account-off" title="No data" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>

    <!-- Unified action dialog -->
    <v-dialog v-model="actionDialog" max-width="540" persistent scrollable>
      <v-card v-if="actionTarget" rounded="xl" class="hc-action-card">
        <div class="hc-action-hero pa-4 d-flex align-center ga-3"
             :style="{ background: `linear-gradient(135deg, ${actionMeta.bg} 0%, ${actionMeta.bg2} 100%)` }">
          <v-avatar size="48" color="white" variant="flat">
            <v-icon :icon="actionMeta.icon" :color="actionMeta.color" size="28" />
          </v-avatar>
          <div class="flex-grow-1 text-white">
            <div class="text-overline" style="opacity:.85;">{{ actionMeta.eyebrow }}</div>
            <div class="text-h6 font-weight-bold">{{ actionMeta.title }}</div>
            <div class="text-caption" style="opacity:.9;">
              {{ actionTarget.medication_name }} · {{ actionTarget.dose }}
              · {{ actionTarget.patient_name }}
            </div>
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mb-3">
            <div class="text-caption">
              Scheduled: <strong>{{ formatFullDateTime(actionTarget.scheduled_at) }}</strong>
            </div>
            <div class="text-caption">
              Acting as <strong>{{ auth.fullName || auth.user?.email }}</strong>
            </div>
          </v-alert>

          <!-- Edit-only: status switcher -->
          <v-select v-if="actionType === 'edit'" v-model="actionStatus"
                    :items="editStatusOptions" label="New status"
                    density="comfortable" variant="outlined" rounded="lg"
                    prepend-inner-icon="mdi-tag" class="mb-3" hide-details />

          <!-- Edit-only: dose change -->
          <div v-if="actionType === 'edit'" class="mb-3">
            <div class="text-overline text-medium-emphasis mb-1">DOSE</div>
            <div class="d-flex flex-wrap ga-1 mb-2">
              <v-chip v-for="opt in doseOptions" :key="opt.value"
                      :color="actionDose === opt.value ? 'primary' : undefined"
                      :variant="actionDose === opt.value ? 'flat' : 'tonal'"
                      size="small" class="text-none"
                      @click="actionDose = opt.value">
                <v-icon v-if="opt.current" start icon="mdi-star" size="12" />
                {{ opt.label }}
              </v-chip>
            </div>
            <v-text-field v-model="actionDose"
                          label="Custom dose" density="comfortable"
                          variant="outlined" rounded="lg"
                          prepend-inner-icon="mdi-pill"
                          :placeholder="actionTarget.dose || 'e.g. 500 mg'"
                          hide-details />
          </div>

          <!-- Time of administration: Document or Edit-to-Documented -->
          <v-text-field v-if="actionType === 'document' || (actionType === 'edit' && actionStatus === 'taken')"
                        v-model="actionTime" type="datetime-local"
                        label="Time given" density="comfortable" variant="outlined"
                        rounded="lg" prepend-inner-icon="mdi-clock-outline"
                        hide-details class="mb-3" />

          <!-- Reason: required for skip / not_given / edit-when-missed -->
          <v-textarea v-if="needsReason" v-model="actionReason"
                      label="Reason" rows="2" auto-grow
                      density="comfortable" variant="outlined" rounded="lg"
                      prepend-inner-icon="mdi-message-alert"
                      :rules="[v => !!v?.trim() || 'Reason is required']"
                      class="mb-3" />

          <!-- Optional notes -->
          <v-textarea v-model="actionNotes" label="Notes (optional)" rows="2" auto-grow
                      density="comfortable" variant="outlined" rounded="lg"
                      prepend-inner-icon="mdi-note-text" hide-details class="mb-3" />

          <v-divider class="mb-3" />
          <div class="text-overline text-medium-emphasis mb-1">VERIFY IDENTITY</div>
          <v-text-field v-model="actionPin" label="Your staff PIN"
                        type="password" inputmode="numeric" maxlength="12"
                        density="comfortable" variant="outlined" rounded="lg"
                        prepend-inner-icon="mdi-key" autofocus
                        @keyup.enter="submitAction" hide-details />
          <div class="text-caption text-medium-emphasis mt-1">
            <a href="#" @click.prevent="showMyPin = !showMyPin">
              {{ showMyPin ? 'Hide my PIN' : "Don't know your PIN? Reveal mine" }}
            </a>
            <span v-if="showMyPin && auth.user?.pin" class="ml-1">
              — <code>{{ auth.user.pin }}</code>
            </span>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="actionBusy" @click="actionDialog = false">Cancel</v-btn>
          <v-btn :color="actionMeta.color" variant="flat" rounded="lg" class="text-none"
                 :prepend-icon="actionMeta.icon" :loading="actionBusy"
                 @click="submitAction">
            {{ actionMeta.cta }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const auth = useAuthStore()

const items = ref([])
const loading = ref(false)
const search = ref('')
const filterStatus = ref(null)
const filterDate = ref('today')
const customFrom = ref('')
const customTo = ref('')
const page = ref(1)
const pageSize = 25
const expanded = reactive({})
const snack = reactive({ show: false, text: '', color: 'info' })

// Action dialog state
const actionDialog = ref(false)
const actionTarget = ref(null)
const actionType = ref('document')   // 'document' | 'skip' | 'not_given' | 'edit'
const actionStatus = ref('taken')    // for edit only
const actionTime = ref('')
const actionDose = ref('')
const actionReason = ref('')
const actionNotes = ref('')
const actionPin = ref('')
const actionBusy = ref(false)
const showMyPin = ref(false)

const statusOptions = [
  { value: 'pending',   title: 'Pending' },
  { value: 'taken',     title: 'Documented' },
  { value: 'missed',    title: 'Missed' },
  { value: 'skipped',   title: 'Skipped' },
  { value: 'not_given', title: 'Not given' },
  { value: 'overdue',   title: 'Overdue' }
]

const editStatusOptions = [
  { value: 'pending',   title: 'Pending (keep open)' },
  { value: 'taken',     title: 'Documented (give now / change time)' },
  { value: 'missed',    title: 'Missed' },
  { value: 'skipped',   title: 'Skipped' },
  { value: 'not_given', title: 'Not given' }
]

const dateRangeOptions = [
  { value: 'today',     title: 'Today' },
  { value: 'yesterday', title: 'Yesterday' },
  { value: 'last7',     title: 'Last 7 days' },
  { value: 'last30',    title: 'Last 30 days' },
  { value: 'thisMonth', title: 'This month' },
  { value: 'upcoming',  title: 'Upcoming' },
  { value: 'overdue',   title: 'Overdue (pending past due)' },
  { value: 'all',       title: 'All' },
  { value: 'custom',    title: 'Custom range…' }
]

function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
function endOfDay(d)   { const x = new Date(d); x.setHours(23, 59, 59, 999); return x }

function rangeFor(filter) {
  const now = new Date()
  switch (filter) {
    case 'today':     return { from: startOfDay(now), to: endOfDay(now) }
    case 'yesterday': {
      const y = new Date(now); y.setDate(y.getDate() - 1)
      return { from: startOfDay(y), to: endOfDay(y) }
    }
    case 'last7': {
      const f = new Date(now); f.setDate(f.getDate() - 6)
      return { from: startOfDay(f), to: endOfDay(now) }
    }
    case 'last30': {
      const f = new Date(now); f.setDate(f.getDate() - 29)
      return { from: startOfDay(f), to: endOfDay(now) }
    }
    case 'thisMonth': {
      const f = new Date(now.getFullYear(), now.getMonth(), 1)
      const t = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999)
      return { from: f, to: t }
    }
    case 'upcoming': return { from: now, to: null }
    case 'overdue':  return { from: null, to: now }
    case 'custom': {
      return {
        from: customFrom.value ? startOfDay(customFrom.value) : null,
        to: customTo.value ? endOfDay(customTo.value) : null,
      }
    }
    default: return { from: null, to: null }
  }
}

async function load() {
  loading.value = true
  try {
    // Auto-mark missed doses (>60 min past) before loading.
    try { await $api.post('/homecare/doses/auto_expire/') } catch { /* non-fatal */ }
    const params = { page_size: 1000 }
    if (filterDate.value === 'today') {
      const { data } = await $api.get('/homecare/doses/today/', { params })
      items.value = data?.results || data || []
    } else {
      const r = rangeFor(filterDate.value)
      if (r.from) params.from = r.from.toISOString()
      if (r.to)   params.to   = r.to.toISOString()
      const { data } = await $api.get('/homecare/doses/', { params })
      items.value = data?.results || data || []
    }
  } catch {
    snack.text = 'Failed to load doses'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(load)
watch(filterDate, () => { page.value = 1; load() })
watch([customFrom, customTo], () => { if (filterDate.value === 'custom') { page.value = 1; load() } })
watch([search, filterStatus], () => { page.value = 1 })

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  const r = rangeFor(filterDate.value)
  return items.value.filter(d => {
    if (filterStatus.value && d.status !== filterStatus.value) return false
    const ts = new Date(d.scheduled_at).getTime()
    if (r.from && ts < r.from.getTime()) return false
    if (r.to && ts > r.to.getTime()) return false
    if (filterDate.value === 'overdue' && d.status !== 'pending') return false
    if (!q) return true
    return [d.medication_name, d.schedule_medication, d.patient_name]
      .filter(Boolean).some(s => s.toLowerCase().includes(q))
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize)))
const paged = computed(() => {
  const start = (page.value - 1) * pageSize
  return filtered.value.slice(start, start + pageSize)
})
const pagedFrom = computed(() => filtered.value.length ? (page.value - 1) * pageSize + 1 : 0)
const pagedTo = computed(() => Math.min(page.value * pageSize, filtered.value.length))

const grouped = computed(() => {
  const map = new Map()
  for (const d of paged.value) {
    const dt = new Date(d.scheduled_at)
    const key = `${dt.toDateString()}-${dt.getHours()}`
    const label = dt.toLocaleString(undefined, {
      weekday: 'short', day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit'
    })
    if (!map.has(key)) map.set(key, { key, label, list: [], ts: dt.getTime() })
    map.get(key).list.push(d)
  }
  return Array.from(map.values()).sort((a, b) => a.ts - b.ts)
})

const stats = computed(() => {
  const list = items.value
  const taken = list.filter(d => d.status === 'taken').length
  const missed = list.filter(d => d.status === 'missed').length
  const pending = list.filter(d => d.status === 'pending').length
  const skipped = list.filter(d => d.status === 'skipped').length
  const total = list.length
  const finalized = taken + missed
  const adherence = finalized ? Math.round((taken / finalized) * 100) : 0
  return { total, taken, missed, pending, skipped, adherence }
})
const summary = computed(() => [
  { label: 'Total',   value: stats.value.total,   color: 'teal',    icon: 'mdi-clipboard-pulse' },
  { label: 'Pending', value: stats.value.pending, color: 'warning', icon: 'mdi-clock-outline' },
  { label: 'Taken',   value: stats.value.taken,   color: 'success', icon: 'mdi-check-decagram' },
  { label: 'Missed',  value: stats.value.missed,  color: 'error',   icon: 'mdi-close-circle' }
])

const rows = computed(() => statusOptions.map(o => ({
  label: o.title, count: items.value.filter(d => d.status === o.value).length,
  color: statusColor(o.value).hex, bg: `${statusColor(o.value).hex}14`,
  icon: statusIcon(o.value)
})))
const segments = computed(() => statusOptions.map(o => ({
  label: o.title, value: items.value.filter(d => d.status === o.value).length,
  color: statusColor(o.value).vuetify
})))

const patientAdherence = computed(() => {
  const map = {}
  for (const d of items.value) {
    const k = d.patient_name || '—'
    if (!map[k]) map[k] = { taken: 0, total: 0 }
    if (d.status === 'taken' || d.status === 'missed') {
      map[k].total += 1
      if (d.status === 'taken') map[k].taken += 1
    }
  }
  return Object.entries(map).map(([name, v]) => ({
    name, pct: v.total ? Math.round((v.taken / v.total) * 100) : 0
  })).sort((a, b) => a.pct - b.pct).slice(0, 6)
})

function statusColor(s) {
  return ({
    pending:   { hex: '#f59e0b', vuetify: 'warning' },
    taken:     { hex: '#10b981', vuetify: 'success' },
    missed:    { hex: '#ef4444', vuetify: 'error' },
    skipped:   { hex: '#94a3b8', vuetify: 'grey' },
    not_given: { hex: '#dc2626', vuetify: 'error' },
    overdue:   { hex: '#dc2626', vuetify: 'error' }
  })[s] || { hex: '#64748b', vuetify: 'grey' }
}
function statusIcon(s) {
  return ({ pending: 'mdi-clock', taken: 'mdi-clipboard-check',
            missed: 'mdi-alert', skipped: 'mdi-skip-next',
            not_given: 'mdi-cancel', overdue: 'mdi-alert' })[s] || 'mdi-circle'
}
function statusDisplay(s) {
  return ({ pending: 'Pending', taken: 'Documented', missed: 'Missed',
            skipped: 'Skipped', not_given: 'Not given',
            overdue: 'Overdue' })[s] || s
}
function auditColor(action) {
  return ({ document: 'success', skip: 'warning', not_given: 'error',
            mark_missed: 'error', auto_missed: 'amber',
            edit_assessment: 'primary' })[action] || 'grey'
}
function auditIcon(action) {
  return ({ document: 'mdi-clipboard-check', skip: 'mdi-skip-next',
            not_given: 'mdi-cancel', mark_missed: 'mdi-alert',
            auto_missed: 'mdi-robot', edit_assessment: 'mdi-pencil-box'
          })[action] || 'mdi-circle-small'
}
function adherenceColor(p) {
  if (p >= 85) return 'success'
  if (p >= 60) return 'warning'
  return 'error'
}
function formatTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}
function formatFullDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

async function mark(d, status) {
  try {
    const { data } = await $api.post(`/homecare/doses/${d.id}/mark_${status}/`)
    const i = items.value.findIndex(x => x.id === d.id)
    if (i >= 0) items.value.splice(i, 1, data)
    snack.text = `Marked ${status}`; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Update failed'; snack.color = 'error'; snack.show = true
  }
}

// ─── Action dialog ───────────────────────────────────────
const actionMeta = computed(() => {
  const map = {
    document:  { eyebrow: 'DOCUMENT DOSE', title: 'Document administration',
                 cta: 'Save & document', icon: 'mdi-clipboard-check',
                 color: 'success', bg: '#10b981', bg2: '#059669' },
    skip:      { eyebrow: 'SKIP DOSE', title: 'Skip this dose',
                 cta: 'Confirm skip', icon: 'mdi-skip-next',
                 color: 'warning', bg: '#f59e0b', bg2: '#d97706' },
    not_given: { eyebrow: 'NOT GIVEN', title: 'Mark as not given',
                 cta: 'Confirm not given', icon: 'mdi-cancel',
                 color: 'error', bg: '#ef4444', bg2: '#dc2626' },
    edit:      { eyebrow: 'EDIT ASSESSMENT', title: 'Edit dose assessment',
                 cta: 'Save changes', icon: 'mdi-pencil-box',
                 color: 'primary', bg: '#0d9488', bg2: '#7c3aed' },
  }
  return map[actionType.value] || map.document
})
const needsReason = computed(() => {
  if (actionType.value === 'skip' || actionType.value === 'not_given') return true
  if (actionType.value === 'edit') return true
  return false
})

// Build quick-pick dose chips by parsing the current dose string
// e.g. "500 mg" -> [250 mg (half), 500 mg (current), 750 mg, 1000 mg (double)]
const doseOptions = computed(() => {
  const cur = (actionTarget.value?.dose || '').trim()
  if (!cur) return []
  const m = cur.match(/^([0-9]*\.?[0-9]+)\s*(.*)$/)
  if (!m) return [{ value: cur, label: cur, current: true }]
  const n = parseFloat(m[1])
  const unit = (m[2] || '').trim()
  const fmt = (v) => {
    const s = Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/\.?0+$/, '')
    return unit ? `${s} ${unit}` : s
  }
  const seen = new Set()
  const out = []
  for (const [mult, suffix] of [[0.5, 'half'], [1, 'current'], [1.5, '1.5×'], [2, 'double']]) {
    const v = +(n * mult).toFixed(4)
    if (v <= 0) continue
    const label = fmt(v)
    if (seen.has(label)) continue
    seen.add(label)
    out.push({ value: label, label: `${label}${suffix === 'current' ? '' : ' · ' + suffix}`, current: mult === 1 })
  }
  return out
})

function toLocalInput(d) {
  if (!d) return ''
  const dt = new Date(d)
  const tz = dt.getTimezoneOffset() * 60000
  return new Date(dt.getTime() - tz).toISOString().slice(0, 16)
}

function openAction(dose, type) {
  actionTarget.value = dose
  actionType.value = type
  actionStatus.value = type === 'edit'
    ? (dose.status === 'missed' ? 'taken' : dose.status)
    : 'taken'
  actionTime.value = toLocalInput(dose.administered_at || new Date())
  actionDose.value = dose.dose || ''
  actionReason.value = type === 'edit' ? (dose.reason || '') : ''
  actionNotes.value = ''
  actionPin.value = ''
  showMyPin.value = false
  actionDialog.value = true
}

async function submitAction() {
  if (!actionTarget.value) return
  const pin = actionPin.value.trim()
  if (!pin) {
    snack.text = 'Please enter your staff PIN'; snack.color = 'warning'; snack.show = true
    return
  }
  if (auth.user?.pin && pin !== auth.user.pin) {
    snack.text = 'PIN does not match the logged-in user'
    snack.color = 'error'; snack.show = true
    return
  }
  if (needsReason.value && !actionReason.value.trim()) {
    snack.text = 'A reason is required'; snack.color = 'warning'; snack.show = true
    return
  }
  actionBusy.value = true
  const payload = { pin }
  if (actionNotes.value) payload.notes = actionNotes.value
  if (actionReason.value) payload.reason = actionReason.value
  let url = ''
  if (actionType.value === 'document') {
    url = `/homecare/doses/${actionTarget.value.id}/mark_taken/`
    if (actionTime.value) payload.administered_at = new Date(actionTime.value).toISOString()
  } else if (actionType.value === 'skip') {
    url = `/homecare/doses/${actionTarget.value.id}/mark_skipped/`
  } else if (actionType.value === 'not_given') {
    url = `/homecare/doses/${actionTarget.value.id}/mark_not_given/`
  } else if (actionType.value === 'edit') {
    url = `/homecare/doses/${actionTarget.value.id}/edit_assessment/`
    payload.status = actionStatus.value
    if (actionDose.value && actionDose.value !== actionTarget.value.dose) {
      payload.dose = actionDose.value
    }
    if (actionStatus.value === 'taken' && actionTime.value) {
      payload.administered_at = new Date(actionTime.value).toISOString()
    }
  }
  try {
    const { data } = await $api.post(url, payload)
    const i = items.value.findIndex(x => x.id === data.id)
    if (i >= 0) items.value.splice(i, 1, data)
    snack.text = `${actionMeta.value.title} – saved`; snack.color = 'success'; snack.show = true
    actionDialog.value = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Action failed'
    snack.color = 'error'; snack.show = true
  } finally {
    actionBusy.value = false
  }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(245,158,11,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
}
.hc-dose-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
}
.hc-dose-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
.hc-date-chip {
  min-width: 280px;
  max-width: 100%;
  height: auto !important;
  padding: 6px 14px !important;
  white-space: nowrap;
  letter-spacing: 0.02em;
}
:deep(.hc-date-chip .v-chip__content) { white-space: nowrap; overflow: visible; }
.hc-dose-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 14px;
  align-items: center;
  margin-top: 2px;
  white-space: nowrap;
}
.hc-dose-meta > span { display: inline-flex; align-items: center; gap: 4px; }
.hc-reason {
  background: rgba(239,68,68,0.06);
  border-left: 3px solid rgba(239,68,68,0.5);
  padding: 4px 8px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.hc-audit { border-bottom: 1px dashed rgba(15,23,42,0.06); }
.hc-audit:last-child { border-bottom: none; }
.hc-action-card { overflow: hidden; }
.hc-action-hero { color: white; }
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-dose-card { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
</style>
