<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Dose analysis"
      subtitle="Per-patient adherence trends, missed-dose patterns, and medication-level insights."
      eyebrow="ANALYTICS"
      icon="mdi-chart-line"
      :chips="[
        { icon: 'mdi-account-heart', label: `${selectedPatients.length || 'All'} patient(s)` },
        { icon: 'mdi-calendar-range', label: rangeLabel },
        { icon: 'mdi-percent', label: `${overall.adherence}% adherence` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white"
               prepend-icon="mdi-arrow-left" class="text-none mr-2"
               to="/homecare/doses">
          <span class="font-weight-bold">Back to doses</span>
        </v-btn>
        <v-btn variant="tonal" rounded="pill" color="white"
               prepend-icon="mdi-refresh" class="text-none mr-2"
               :loading="loading" @click="load">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-download" class="text-none"
               :disabled="!doses.length" @click="exportCsv">
          <span class="text-teal-darken-2 font-weight-bold">Export CSV</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- ─── Filters ──────────────────────────────────────── -->
    <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="6">
          <v-autocomplete v-model="selectedPatients"
                          :items="patientOptions"
                          item-title="label" item-value="id"
                          label="Patients" prepend-inner-icon="mdi-account-search"
                          variant="outlined" rounded="lg" density="comfortable"
                          chips closable-chips multiple clearable hide-details
                          placeholder="All patients">
            <template #chip="{ props, item }">
              <v-chip v-bind="props" :prepend-icon="'mdi-account'"
                      color="purple-darken-2" size="small" variant="tonal" />
            </template>
          </v-autocomplete>
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="dateRange"
                    :items="rangeOptions"
                    item-title="label" item-value="value"
                    label="Range" prepend-inner-icon="mdi-calendar-range"
                    variant="outlined" rounded="lg" density="comfortable"
                    hide-details>
            <template #selection="{ item }">
              <v-icon :icon="item.raw.icon" size="16" class="mr-2" />
              <span>{{ item.raw.label }}</span>
            </template>
            <template #item="{ item, props }">
              <v-list-item v-bind="props" :prepend-icon="item.raw.icon"
                           :title="item.raw.label" :subtitle="item.raw.hint" />
            </template>
          </v-select>
        </v-col>
        <v-col cols="12" md="3" class="d-flex align-center ga-2">
          <v-btn-toggle v-model="groupBy" mandatory color="purple-darken-2"
                        density="comfortable" variant="outlined" rounded="lg">
            <v-btn value="day" size="small" class="text-none">Day</v-btn>
            <v-btn value="week" size="small" class="text-none">Week</v-btn>
            <v-btn value="month" size="small" class="text-none">Month</v-btn>
          </v-btn-toggle>
          <v-spacer />
          <v-btn variant="tonal" rounded="lg" size="small" class="text-none"
                 :loading="loading" prepend-icon="mdi-refresh" @click="load">
            Refresh
          </v-btn>
        </v-col>
        <v-col v-if="dateRange === 'custom'" cols="12" md="6">
          <v-text-field v-model="customStart" type="date" label="From"
                        density="comfortable" variant="outlined" rounded="lg"
                        prepend-inner-icon="mdi-calendar-start" hide-details />
        </v-col>
        <v-col v-if="dateRange === 'custom'" cols="12" md="6">
          <v-text-field v-model="customEnd" type="date" label="To"
                        :min="customStart" density="comfortable" variant="outlined"
                        rounded="lg" prepend-inner-icon="mdi-calendar-end" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <!-- ─── KPI cards ──────────────────────────────────── -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 h-100">
          <div class="d-flex align-center ga-3">
            <v-avatar :color="k.color" variant="tonal" size="48">
              <v-icon :icon="k.icon" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold"
                   style="letter-spacing:.5px">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
          <v-progress-linear v-if="k.bar !== undefined" :model-value="k.bar"
                             :color="k.color" height="6" rounded class="mt-2" />
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <!-- ─── Adherence trend ──────────────────────────── -->
      <v-col cols="12" md="8">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon icon="mdi-chart-areaspline" color="purple-darken-2" class="mr-2" />
            <div class="text-subtitle-1 font-weight-bold">Adherence trend</div>
            <v-spacer />
            <v-chip size="x-small" color="success" variant="tonal" class="mr-1">
              <v-icon icon="mdi-check" start size="12" /> Taken
            </v-chip>
            <v-chip size="x-small" color="error" variant="tonal" class="mr-1">
              <v-icon icon="mdi-close" start size="12" /> Missed
            </v-chip>
            <v-chip size="x-small" color="warning" variant="tonal" class="mr-1">
              <v-icon icon="mdi-skip-next" start size="12" /> Skipped
            </v-chip>
            <v-chip size="x-small" color="grey" variant="tonal">
              <v-icon icon="mdi-clock-outline" start size="12" /> Pending
            </v-chip>
          </div>
          <div v-if="!trend.length" class="text-center text-medium-emphasis pa-6">
            <v-icon icon="mdi-chart-line-variant" size="48" />
            <div class="text-body-2 mt-2">No data for the selected range.</div>
          </div>
          <div v-else class="hc-trend">
            <div class="hc-trend-axis">
              <span>100%</span><span>75%</span><span>50%</span><span>25%</span><span>0%</span>
            </div>
            <div class="hc-trend-bars">
              <div v-for="(b, i) in trend" :key="i" class="hc-trend-bar"
                   :title="`${b.label}\nTaken ${b.taken} · Missed ${b.missed} · Skipped ${b.skipped} · Pending ${b.pending}\nAdherence ${b.adherence}%`">
                <div class="hc-trend-stack">
                  <div class="hc-seg hc-seg-pending"  :style="{ height: pct(b.pending,b.total) + '%' }" />
                  <div class="hc-seg hc-seg-skipped"  :style="{ height: pct(b.skipped,b.total) + '%' }" />
                  <div class="hc-seg hc-seg-missed"   :style="{ height: pct(b.missed,b.total) + '%' }" />
                  <div class="hc-seg hc-seg-taken"    :style="{ height: pct(b.taken,b.total) + '%' }" />
                </div>
                <div class="hc-trend-line"
                     :style="{ bottom: b.adherence + '%' }" />
                <div class="text-caption text-center text-medium-emphasis hc-trend-label">
                  {{ b.short }}
                </div>
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- ─── Status donut ─────────────────────────────── -->
      <v-col cols="12" md="4">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon icon="mdi-chart-donut" color="purple-darken-2" class="mr-2" />
            <div class="text-subtitle-1 font-weight-bold">Status breakdown</div>
          </div>
          <div class="d-flex justify-center align-center">
            <svg viewBox="0 0 120 120" width="180" height="180" class="hc-donut">
              <circle cx="60" cy="60" r="48" fill="none" stroke="rgba(15,23,42,0.06)" stroke-width="16" />
              <circle v-for="seg in donutSegments" :key="seg.key"
                      cx="60" cy="60" r="48" fill="none"
                      :stroke="seg.color" stroke-width="16"
                      :stroke-dasharray="seg.dash"
                      :stroke-dashoffset="seg.offset"
                      transform="rotate(-90 60 60)" />
              <text x="60" y="56" text-anchor="middle" class="hc-donut-num">
                {{ overall.adherence }}%
              </text>
              <text x="60" y="72" text-anchor="middle" class="hc-donut-cap">
                adherence
              </text>
            </svg>
          </div>
          <div class="mt-3">
            <div v-for="seg in donutSegments" :key="seg.key"
                 class="d-flex align-center ga-2 mb-1">
              <span class="hc-dot" :style="{ background: seg.color }" />
              <div class="text-body-2 flex-grow-1">{{ seg.label }}</div>
              <div class="text-body-2 font-weight-bold">{{ seg.value }}</div>
              <div class="text-caption text-medium-emphasis"
                   style="min-width:48px;text-align:right">
                {{ pct(seg.value, overall.total) }}%
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- ─── Per-patient leaderboard ─────────────────── -->
      <v-col cols="12" md="6">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon icon="mdi-podium" color="purple-darken-2" class="mr-2" />
            <div class="text-subtitle-1 font-weight-bold">Per-patient adherence</div>
            <v-spacer />
            <v-btn-toggle v-model="patientSort" mandatory density="compact"
                          variant="outlined" rounded="lg" color="purple-darken-2">
              <v-btn value="best" size="x-small" class="text-none">Best</v-btn>
              <v-btn value="worst" size="x-small" class="text-none">At-risk</v-btn>
            </v-btn-toggle>
          </div>
          <div v-if="!perPatient.length" class="text-center text-medium-emphasis pa-4">
            No patient data.
          </div>
          <div v-else>
            <div v-for="row in perPatientSorted.slice(0, 8)" :key="row.id"
                 class="d-flex align-center ga-2 mb-2 hc-pat-row">
              <v-avatar size="32" :color="adherenceColor(row.adherence)" variant="tonal">
                <span class="text-body-2 font-weight-bold">{{ initials(row.name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ row.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ row.taken }}/{{ row.total }} taken · {{ row.missed }} missed
                </div>
                <v-progress-linear :model-value="row.adherence" height="5" rounded
                                   :color="adherenceColor(row.adherence)" class="mt-1" />
              </div>
              <v-chip :color="adherenceColor(row.adherence)" variant="tonal" size="small"
                      class="font-weight-bold">
                {{ row.adherence }}%
              </v-chip>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- ─── Top medications ─────────────────────────── -->
      <v-col cols="12" md="6">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon icon="mdi-pill" color="purple-darken-2" class="mr-2" />
            <div class="text-subtitle-1 font-weight-bold">Medication-level adherence</div>
          </div>
          <div v-if="!perMed.length" class="text-center text-medium-emphasis pa-4">
            No medication data.
          </div>
          <div v-else>
            <div v-for="row in perMed.slice(0, 8)" :key="row.name"
                 class="d-flex align-center ga-2 mb-2">
              <v-avatar size="32" color="teal" variant="tonal">
                <v-icon icon="mdi-pill" size="18" />
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ row.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ row.taken }}/{{ row.total }} doses
                  <span v-if="row.missed"> · {{ row.missed }} missed</span>
                </div>
                <v-progress-linear :model-value="row.adherence" height="5" rounded
                                   :color="adherenceColor(row.adherence)" class="mt-1" />
              </div>
              <v-chip :color="adherenceColor(row.adherence)" variant="tonal" size="small"
                      class="font-weight-bold">
                {{ row.adherence }}%
              </v-chip>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- ─── Time-of-day heatmap ─────────────────────── -->
      <v-col cols="12" md="7">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon icon="mdi-clock-time-eight" color="purple-darken-2" class="mr-2" />
            <div class="text-subtitle-1 font-weight-bold">Time-of-day pattern</div>
            <v-spacer />
            <span class="text-caption text-medium-emphasis">
              Bubble size = doses · color = missed %
            </span>
          </div>
          <div class="hc-hm-scroll">
            <table class="hc-hm">
              <thead>
                <tr>
                  <th class="hc-hm-row-h"></th>
                  <th v-for="h in 24" :key="h" class="hc-hm-col-h">{{ h - 1 }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, i) in heatmap" :key="i">
                  <td class="hc-hm-row-h">{{ row.dow }}</td>
                  <td v-for="(cell, j) in row.cells" :key="j" class="hc-hm-cell"
                      :title="`${row.dow} ${j}:00\n${cell.total} doses · ${cell.missed} missed (${pct(cell.missed, cell.total)}%)`">
                    <span v-if="cell.total" class="hc-hm-bubble"
                          :style="{
                            width:  hmSize(cell.total) + 'px',
                            height: hmSize(cell.total) + 'px',
                            background: hmColor(cell.missed, cell.total)
                          }" />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </v-card>
      </v-col>

      <!-- ─── Recent missed / at-risk ─────────────────── -->
      <v-col cols="12" md="5">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 h-100">
          <div class="d-flex align-center mb-3">
            <v-icon icon="mdi-alert-circle" color="error" class="mr-2" />
            <div class="text-subtitle-1 font-weight-bold">Recent missed doses</div>
            <v-spacer />
            <v-chip size="x-small" color="error" variant="tonal">
              {{ recentMissed.length }}
            </v-chip>
          </div>
          <div v-if="!recentMissed.length" class="text-center text-medium-emphasis pa-4">
            <v-icon icon="mdi-emoticon-happy" size="36" color="success" />
            <div class="text-body-2 mt-1">No missed doses — great adherence!</div>
          </div>
          <v-list v-else density="compact" class="pa-0">
            <v-list-item v-for="d in recentMissed.slice(0, 8)" :key="d.id"
                         class="px-0">
              <template #prepend>
                <v-avatar size="32" color="error" variant="tonal">
                  <v-icon :icon="d.auto_missed ? 'mdi-robot' : 'mdi-close'" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">
                {{ d.medication_name }}
              </v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ d.patient_name }}
                · {{ formatFullDateTime(d.scheduled_at) }}
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()

const loading = ref(false)
const patients = ref([])
const doses = ref([])

const selectedPatients = ref([])
const dateRange = ref('30d')
const customStart = ref('')
const customEnd = ref('')
const groupBy = ref('day')
const patientSort = ref('worst')

const rangeOptions = [
  { value: '7d',     label: 'Last 7 days',   icon: 'mdi-calendar-week',     hint: 'Past week' },
  { value: '30d',    label: 'Last 30 days',  icon: 'mdi-calendar-month',    hint: 'Past month (default)' },
  { value: '90d',    label: 'Last 90 days',  icon: 'mdi-calendar-multiselect', hint: 'Quarter' },
  { value: '180d',   label: 'Last 180 days', icon: 'mdi-calendar-clock',    hint: 'Half-year' },
  { value: '365d',   label: 'Last 12 months',icon: 'mdi-calendar-text',     hint: 'Year over year' },
  { value: 'custom', label: 'Custom range',  icon: 'mdi-calendar-edit',     hint: 'Pick your dates' },
]

// ── Derived date window ──
const rangeBounds = computed(() => {
  const now = new Date()
  if (dateRange.value === 'custom') {
    if (!customStart.value || !customEnd.value) return null
    return {
      start: new Date(`${customStart.value}T00:00`),
      end:   new Date(`${customEnd.value}T23:59`),
    }
  }
  const days = parseInt(dateRange.value, 10)
  const start = new Date(now); start.setDate(start.getDate() - (days - 1))
  start.setHours(0, 0, 0, 0)
  return { start, end: now }
})

const rangeLabel = computed(() => {
  const b = rangeBounds.value
  if (!b) return ''
  return `${b.start.toLocaleDateString()} – ${b.end.toLocaleDateString()}`
})

// ── Data loading ──
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 500 } })
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}

async function loadDoses() {
  loading.value = true
  try {
    const params = { page_size: 1000 }
    const b = rangeBounds.value
    if (b) {
      params.scheduled_at__gte = b.start.toISOString()
      params.scheduled_at__lte = b.end.toISOString()
    }
    if (selectedPatients.value.length === 1) {
      params.schedule__patient = selectedPatients.value[0]
    }
    const { data } = await $api.get('/homecare/doses/', { params })
    let list = data?.results || data || []
    // Client-side filters (multi-patient + date guard if backend ignores params).
    if (selectedPatients.value.length > 1) {
      const set = new Set(selectedPatients.value)
      list = list.filter(d => set.has(d.patient_id))
    }
    if (b) {
      list = list.filter(d => {
        const t = new Date(d.scheduled_at).getTime()
        return t >= b.start.getTime() && t <= b.end.getTime()
      })
    }
    doses.value = list
  } catch {
    doses.value = []
  } finally {
    loading.value = false
  }
}

async function load() {
  await Promise.all([loadPatients(), loadDoses()])
}

watch([selectedPatients, dateRange, customStart, customEnd], () => loadDoses())

const patientOptions = computed(() =>
  patients.value.map(p => ({
    id: p.id,
    label: (p.user?.full_name || p.user?.email)
         + (p.medical_record_number ? ` · ${p.medical_record_number}` : ''),
  }))
)

// ── KPI summary ──
const overall = computed(() => {
  const total = doses.value.length
  let taken = 0, missed = 0, skipped = 0, pending = 0, notGiven = 0
  doses.value.forEach(d => {
    if (d.status === 'taken') taken++
    else if (d.status === 'missed') missed++
    else if (d.status === 'skipped') skipped++
    else if (d.status === 'pending') pending++
    else if (d.status === 'not_given') notGiven++
  })
  const denom = taken + missed + skipped + notGiven
  const adherence = denom ? Math.round((taken / denom) * 100) : 0
  return { total, taken, missed, skipped, pending, notGiven, adherence }
})

const kpis = computed(() => {
  const o = overall.value
  return [
    { label: 'Total doses', value: o.total, icon: 'mdi-clipboard-list', color: 'purple',
      sub: `${o.pending} pending` },
    { label: 'Adherence',   value: `${o.adherence}%`, icon: 'mdi-shield-check',
      color: o.adherence >= 80 ? 'success' : o.adherence >= 60 ? 'warning' : 'error',
      bar: o.adherence,
      sub: `${o.taken} taken` },
    { label: 'Missed',      value: o.missed, icon: 'mdi-close-octagon', color: 'error',
      sub: `${o.notGiven} not given` },
    { label: 'Skipped',     value: o.skipped, icon: 'mdi-skip-next-circle', color: 'warning',
      sub: `${perPatient.value.filter(p => p.adherence < 60).length} at-risk patients` },
  ]
})

// ── Trend buckets ──
function bucketKey(d, mode) {
  const dt = new Date(d.scheduled_at)
  if (mode === 'day') {
    return dt.toISOString().slice(0, 10)
  }
  if (mode === 'week') {
    const monday = new Date(dt)
    const dow = (monday.getDay() + 6) % 7
    monday.setDate(monday.getDate() - dow)
    return monday.toISOString().slice(0, 10) + '|w'
  }
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}|m`
}

const trend = computed(() => {
  const buckets = new Map()
  doses.value.forEach(d => {
    const k = bucketKey(d, groupBy.value)
    if (!buckets.has(k)) buckets.set(k, { key: k, taken: 0, missed: 0, skipped: 0, pending: 0, notGiven: 0, total: 0 })
    const b = buckets.get(k)
    b.total++
    if (d.status === 'taken') b.taken++
    else if (d.status === 'missed') b.missed++
    else if (d.status === 'skipped') b.skipped++
    else if (d.status === 'pending') b.pending++
    else if (d.status === 'not_given') b.notGiven++
  })
  return [...buckets.values()]
    .sort((a, b) => a.key.localeCompare(b.key))
    .map(b => {
      const denom = b.taken + b.missed + b.skipped + b.notGiven
      const adherence = denom ? Math.round((b.taken / denom) * 100) : 0
      let label = b.key, short = b.key
      if (groupBy.value === 'day') {
        const dt = new Date(b.key)
        label = dt.toDateString()
        short = `${dt.getMonth() + 1}/${dt.getDate()}`
      } else if (groupBy.value === 'week') {
        const dt = new Date(b.key.split('|')[0])
        label = `Week of ${dt.toDateString()}`
        short = `W${weekNo(dt)}`
      } else {
        const [y, m] = b.key.split('|')[0].split('-')
        const dt = new Date(+y, +m - 1, 1)
        label = dt.toLocaleString(undefined, { month: 'long', year: 'numeric' })
        short = dt.toLocaleString(undefined, { month: 'short' })
      }
      return { ...b, adherence, label, short }
    })
})

function weekNo(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
  const dayNum = d.getUTCDay() || 7
  d.setUTCDate(d.getUTCDate() + 4 - dayNum)
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
  return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
}

// ── Donut ──
const donutSegments = computed(() => {
  const o = overall.value
  const total = o.total || 1
  const segs = [
    { key: 'taken',    label: 'Taken',     value: o.taken,    color: '#10b981' },
    { key: 'missed',   label: 'Missed',    value: o.missed,   color: '#ef4444' },
    { key: 'skipped',  label: 'Skipped',   value: o.skipped,  color: '#f59e0b' },
    { key: 'notGiven', label: 'Not given', value: o.notGiven, color: '#9ca3af' },
    { key: 'pending',  label: 'Pending',   value: o.pending,  color: '#6366f1' },
  ]
  const C = 2 * Math.PI * 48
  let acc = 0
  return segs.map(s => {
    const len = (s.value / total) * C
    const seg = { ...s, dash: `${len} ${C - len}`, offset: -acc }
    acc += len
    return seg
  })
})

// ── Per-patient ──
const perPatient = computed(() => {
  const map = new Map()
  doses.value.forEach(d => {
    const id = d.patient_id || 'unknown'
    if (!map.has(id)) {
      map.set(id, { id, name: d.patient_name || `Patient #${id}`, taken: 0, missed: 0, total: 0, denom: 0 })
    }
    const r = map.get(id)
    r.total++
    if (d.status === 'taken') { r.taken++; r.denom++ }
    else if (d.status === 'missed') { r.missed++; r.denom++ }
    else if (d.status === 'skipped' || d.status === 'not_given') { r.denom++ }
  })
  return [...map.values()].map(r => ({
    ...r, adherence: r.denom ? Math.round((r.taken / r.denom) * 100) : 0,
  }))
})

const perPatientSorted = computed(() => {
  const list = [...perPatient.value]
  if (patientSort.value === 'best') list.sort((a, b) => b.adherence - a.adherence || b.taken - a.taken)
  else list.sort((a, b) => a.adherence - b.adherence || b.missed - a.missed)
  return list
})

// ── Per-medication ──
const perMed = computed(() => {
  const map = new Map()
  doses.value.forEach(d => {
    const name = d.medication_name || '—'
    if (!map.has(name)) map.set(name, { name, taken: 0, missed: 0, total: 0, denom: 0 })
    const r = map.get(name)
    r.total++
    if (d.status === 'taken') { r.taken++; r.denom++ }
    else if (d.status === 'missed') { r.missed++; r.denom++ }
    else if (d.status === 'skipped' || d.status === 'not_given') { r.denom++ }
  })
  return [...map.values()]
    .map(r => ({ ...r, adherence: r.denom ? Math.round((r.taken / r.denom) * 100) : 0 }))
    .sort((a, b) => b.total - a.total)
})

// ── Heatmap ──
const heatmap = computed(() => {
  const dows = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
  const grid = dows.map(dow => ({
    dow,
    cells: Array.from({ length: 24 }, () => ({ total: 0, missed: 0 })),
  }))
  doses.value.forEach(d => {
    const dt = new Date(d.scheduled_at)
    const di = (dt.getDay() + 6) % 7
    const hi = dt.getHours()
    grid[di].cells[hi].total++
    if (d.status === 'missed') grid[di].cells[hi].missed++
  })
  return grid
})

const maxBubble = computed(() => {
  let m = 0
  heatmap.value.forEach(r => r.cells.forEach(c => { if (c.total > m) m = c.total }))
  return m || 1
})

function hmSize(n) {
  const min = 6, max = 24
  return Math.round(min + (max - min) * (n / maxBubble.value))
}
function hmColor(missed, total) {
  if (!total) return 'transparent'
  const r = missed / total
  if (r >= 0.5) return '#ef4444'
  if (r >= 0.25) return '#f59e0b'
  if (r >= 0.1) return '#6366f1'
  return '#10b981'
}

// ── Recent missed ──
const recentMissed = computed(() =>
  doses.value
    .filter(d => d.status === 'missed')
    .sort((a, b) => new Date(b.scheduled_at) - new Date(a.scheduled_at))
)

// ── Helpers ──
function pct(n, d) { return d ? Math.round((n / d) * 100) : 0 }
function adherenceColor(p) {
  if (p >= 85) return 'success'
  if (p >= 70) return 'teal'
  if (p >= 50) return 'warning'
  return 'error'
}
function initials(name) {
  if (!name) return '?'
  return name.trim().split(/\s+/).map(p => p[0]).join('').slice(0, 2).toUpperCase()
}
function formatFullDateTime(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString([], {
    month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

function exportCsv() {
  const headers = ['Patient','Medication','Scheduled','Status','Administered at','Administered by','Auto missed','Reason']
  const rows = doses.value.map(d => [
    d.patient_name, d.medication_name,
    d.scheduled_at, d.status,
    d.administered_at || '', d.administered_by_name || '',
    d.auto_missed ? 'yes' : 'no', (d.reason || '').replace(/[\r\n]+/g, ' '),
  ])
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers, ...rows].map(r => r.map(esc).join(',')).join('\r\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `dose-analysis-${new Date().toISOString().slice(0,10)}.csv`
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

onMounted(async () => {
  // Allow ?patient=ID to deep-link into a single-patient view.
  const q = route.query.patient
  if (q) selectedPatients.value = Array.isArray(q) ? q.map(Number) : [Number(q)]
  await load()
})
</script>

<style scoped>
.hc-bg {
  min-height: calc(100vh - 64px);
  background: linear-gradient(135deg, rgba(124,58,237,0.05) 0%, rgba(13,148,136,0.05) 100%);
}
.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
}
:global(.v-theme--dark) .hc-card {
  background: #1e1e1e;
  border-color: rgba(255,255,255,0.08);
}

/* Trend chart */
.hc-trend {
  display: flex;
  height: 240px;
  gap: 6px;
}
.hc-trend-axis {
  display: flex; flex-direction: column; justify-content: space-between;
  font-size: 10px; color: rgba(15,23,42,0.55);
  width: 32px; text-align: right; padding-bottom: 22px;
}
.hc-trend-bars {
  flex: 1; display: flex; align-items: flex-end; gap: 4px;
  border-left: 1px solid rgba(15,23,42,0.10);
  border-bottom: 1px solid rgba(15,23,42,0.10);
  padding: 0 4px 0 4px;
  position: relative;
  overflow-x: auto;
}
.hc-trend-bar {
  position: relative;
  flex: 1 0 24px;
  height: 100%;
  display: flex; flex-direction: column; align-items: stretch;
  cursor: pointer;
}
.hc-trend-stack {
  flex: 1; display: flex; flex-direction: column-reverse;
  border-radius: 4px 4px 0 0; overflow: hidden;
}
.hc-seg-taken    { background: #10b981; }
.hc-seg-missed   { background: #ef4444; }
.hc-seg-skipped  { background: #f59e0b; }
.hc-seg-pending  { background: #6366f1; }
.hc-trend-line {
  position: absolute; left: 0; right: 0;
  height: 2px; background: rgba(124,58,237,0.7);
  border-radius: 2px;
}
.hc-trend-label {
  height: 18px; font-size: 10px; line-height: 18px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.hc-trend-bar:hover .hc-trend-stack { filter: brightness(1.1); }

/* Donut */
.hc-donut { display: block; }
.hc-donut-num { font-size: 18px; font-weight: 700; fill: currentColor; }
.hc-donut-cap { font-size: 8px; fill: rgba(100,116,139,0.85); }
.hc-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }

/* Patient row */
.hc-pat-row { padding: 4px 0; border-bottom: 1px dashed rgba(15,23,42,0.06); }
.hc-pat-row:last-child { border-bottom: none; }

/* Heatmap */
.hc-hm-scroll { overflow-x: auto; }
.hc-hm { border-collapse: collapse; }
.hc-hm-row-h {
  font-size: 10px; color: rgba(15,23,42,0.55);
  width: 36px; text-align: right; padding-right: 6px;
}
.hc-hm-col-h {
  font-size: 9px; color: rgba(15,23,42,0.55);
  width: 22px; text-align: center;
}
.hc-hm-cell {
  width: 22px; height: 22px; text-align: center; vertical-align: middle;
  border: 1px solid rgba(15,23,42,0.04);
}
.hc-hm-bubble { display: inline-block; border-radius: 50%; }
:global(.v-theme--dark) .hc-trend-axis,
:global(.v-theme--dark) .hc-hm-row-h,
:global(.v-theme--dark) .hc-hm-col-h { color: rgba(255,255,255,0.65); }
:global(.v-theme--dark) .hc-trend-bars,
:global(.v-theme--dark) .hc-hm-cell { border-color: rgba(255,255,255,0.10); }
</style>
