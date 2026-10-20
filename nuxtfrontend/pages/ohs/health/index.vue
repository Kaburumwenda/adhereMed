<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-heart-pulse"
      eyebrow="OHSMS · Occupational health"
      title="Health Surveillance & Exposure"
      subtitle="Statutory medicals, fitness-for-duty outcomes and workplace exposure readings against OEL limits."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="tab === 'surveillance' ? openSurveillance() : openExposure()">
          {{ tab === 'surveillance' ? 'Schedule medical' : 'Add reading' }}
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-heart-pulse</v-icon>
        <b>{{ surveillance.count.value }}</b> medicals</span>
      <span v-if="stats.due" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-clock-alert</v-icon>
        <b>{{ stats.due }}</b> overdue</span>
      <span v-if="stats.exceeded" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-air-filter</v-icon>
        <b>{{ stats.exceeded }}</b> readings above limit</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Medicals booked" :value="surveillance.count.value" icon="mdi-heart-pulse" tone="primary"
              sub="all programmes" />
      <OhsKpi label="Fit for duty" :value="stats.fit" icon="mdi-account-check-outline" tone="ok"
              :sub="`${stats.fitPct}% of completed`" />
      <OhsKpi label="With restrictions" :value="stats.conditional" icon="mdi-account-alert-outline"
              :tone="stats.conditional ? 'warn' : 'ok'" sub="conditional fitness" />
      <OhsKpi label="Overdue" :value="stats.due" icon="mdi-clock-alert"
              :tone="stats.due ? 'err' : 'ok'" sub="medicals not done" />
      <OhsKpi label="Exposure exceedances" :value="stats.exceeded" icon="mdi-air-filter"
              :tone="stats.exceeded ? 'err' : 'ok'" :sub="`${exposure.count.value} readings`" />
    </div>

    <v-tabs v-model="tab" color="primary" density="compact" class="mb-3">
      <v-tab value="surveillance" class="text-none">
        <v-icon start size="16">mdi-heart-pulse</v-icon> Health surveillance
      </v-tab>
      <v-tab value="exposure" class="text-none">
        <v-icon start size="16">mdi-air-filter</v-icon> Exposure monitoring
      </v-tab>
    </v-tabs>

    <v-window v-model="tab">
      <v-window-item value="surveillance">
        <OhsPanel title="Surveillance register" :subtitle="`${filteredSurveillance.length} shown`"
                  icon="mdi-heart-pulse" flush>
          <div class="ohs-toolbar">
            <v-text-field v-model="search" placeholder="Search employee, job title…" prepend-inner-icon="mdi-magnify"
                          density="compact" variant="outlined" rounded="lg" hide-details single-line clearable
                          style="max-width:260px" />
            <v-select v-model="programmeFilter" :items="programmeOptions" item-title="label" item-value="value"
                      placeholder="All programmes" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:210px" />
            <v-select v-model="resultFilter" :items="resultOptions" item-title="label" item-value="value"
                      placeholder="Any outcome" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:180px" />
          </div>
          <div class="ohs-scroll" style="max-height:62vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th style="width:150px">Programme</th>
                  <th style="width:130px">Site</th>
                  <th style="width:110px">Scheduled</th>
                  <th style="width:110px">Completed</th>
                  <th style="width:110px">Next due</th>
                  <th style="width:120px">Outcome</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in filteredSurveillance" :key="r.id">
                  <td>
                    <div class="font-weight-medium">{{ r.employee_name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ r.job_title || '—' }}</div>
                  </td>
                  <td class="text-caption">{{ r.programme_display }}</td>
                  <td class="text-caption">{{ r.site_name || '—' }}</td>
                  <td class="text-caption">{{ formatDate(r.scheduled_on) }}</td>
                  <td class="text-caption">{{ formatDate(r.completed_on) }}</td>
                  <td class="text-caption">{{ formatDate(r.next_due) }}</td>
                  <td>
                    <span class="ohs-badge" :class="r.is_overdue ? 'ohs-badge--err' : `ohs-badge--${toneFor(r.result)}`">
                      {{ r.is_overdue ? 'Overdue' : r.result_display }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!filteredSurveillance.length" class="ohs-empty">No medicals match these filters.</div>
          </div>
        </OhsPanel>
      </v-window-item>

      <v-window-item value="exposure">
        <OhsPanel title="Exposure readings" :subtitle="`${filteredExposure.length} shown`"
                  icon="mdi-air-filter" flush>
          <div class="ohs-toolbar">
            <v-select v-model="agentFilter" :items="agentOptions" item-title="label" item-value="value"
                      placeholder="All agents" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:200px" />
            <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                      placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:200px" />
          </div>
          <div class="ohs-scroll" style="max-height:62vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th style="width:150px">Agent</th>
                  <th style="width:150px">Site / area</th>
                  <th style="width:120px" class="num">Reading</th>
                  <th style="width:110px" class="num">OEL</th>
                  <th style="width:110px" class="num">% of limit</th>
                  <th style="width:110px">Measured</th>
                  <th style="width:120px">Result</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="e in filteredExposure" :key="e.id">
                  <td class="font-weight-medium">{{ e.agent_display }}</td>
                  <td>
                    <div class="text-caption font-weight-medium">{{ e.site_name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ e.area || '—' }}</div>
                  </td>
                  <td class="num font-weight-bold">{{ e.measured_value }} {{ e.unit }}</td>
                  <td class="num text-caption">{{ e.oel_limit ?? '—' }}</td>
                  <td class="num">
                    <div class="d-flex align-center justify-end" style="gap:6px">
                      <div class="ohs-meter" style="width:52px"
                           :style="{ color: e.result === 'exceeded' ? '#dc2626' : e.result === 'action' ? '#f59e0b' : '#16a34a' }">
                        <div class="ohs-meter-fill" :style="{ width: Math.min(e.pct_of_limit || 0, 100) + '%' }" />
                      </div>
                      <span class="text-caption">{{ e.pct_of_limit ?? '—' }}%</span>
                    </div>
                  </td>
                  <td class="text-caption">{{ formatDate(e.measured_on) }}</td>
                  <td>
                    <span class="ohs-badge" :class="`ohs-badge--${toneFor(e.result)}`">{{ e.result_display }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!filteredExposure.length" class="ohs-empty">No readings match these filters.</div>
          </div>
        </OhsPanel>
      </v-window-item>
    </v-window>

    <!-- Schedule medical -->
    <v-dialog v-model="surveillanceDialog" max-width="600">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-heart-plus" title="Schedule health surveillance"
                           subtitle="Statutory medical per the OHSMS health programme." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="surveillanceForm.programme" :items="programmeOptions" item-title="label"
                        item-value="value" label="Programme" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="surveillanceForm.scheduled_on" type="date" label="Scheduled"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="surveillanceForm.employee_name" label="Employee" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="surveillanceForm.job_title" label="Job title" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="surveillanceForm.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="surveillanceForm.provider" label="Provider" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="surveillanceDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="surveillance.saving.value"
                 :disabled="!surveillanceForm.employee_name" @click="saveSurveillance">Schedule</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Add reading -->
    <v-dialog v-model="exposureDialog" max-width="600">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-air-filter" title="Add an exposure reading"
                           subtitle="Compare the measurement against the occupational exposure limit." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="exposureForm.agent" :items="agentOptions" item-title="label" item-value="value"
                        label="Agent" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="exposureForm.measured_on" type="date" label="Measured on"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="exposureForm.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="exposureForm.area" label="Area" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="exposureForm.measured_value" type="number" label="Reading"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="exposureForm.unit" label="Unit" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="exposureForm.oel_limit" type="number" label="OEL"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="exposureDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="exposure.saving.value"
                 :disabled="!exposureForm.site" @click="saveExposure">Add reading</v-btn>
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
useHead({ title: 'Occupational Health · OHSMS' })

const ohs = useOhs()

const surveillance = ohs.resource('health-surveillance')
const exposure = ohs.resource('exposure')
const lookups = ref({})
const tab = ref('surveillance')
const search = ref('')
const programmeFilter = ref(null)
const resultFilter = ref(null)
const agentFilter = ref(null)
const siteFilter = ref(null)
const surveillanceDialog = ref(false)
const exposureDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const surveillanceForm = reactive({
  programme: 'general', scheduled_on: new Date().toISOString().slice(0, 10),
  employee_name: '', job_title: '', site: null, provider: '',
})
const exposureForm = reactive({
  agent: 'noise', site: null, area: '', measured_value: 80, unit: 'dB(A)',
  oel_limit: 85, measured_on: new Date().toISOString().slice(0, 10),
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const programmeOptions = computed(() => lookups.value.programmes || [])
const agentOptions = computed(() => lookups.value.agents || [])
const resultOptions = [
  { label: 'Fit for duty', value: 'fit' },
  { label: 'With restrictions', value: 'conditional' },
  { label: 'Unfit', value: 'unfit' },
  { label: 'Pending', value: 'pending' },
]

const filteredSurveillance = computed(() => (surveillance.items.value || []).filter((r) => {
  if (programmeFilter.value && r.programme !== programmeFilter.value) return false
  if (resultFilter.value && r.result !== resultFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q && !`${r.employee_name} ${r.job_title} ${r.provider}`.toLowerCase().includes(q)) return false
  return true
}))

const filteredExposure = computed(() => (exposure.items.value || []).filter((e) => {
  if (agentFilter.value && e.agent !== agentFilter.value) return false
  if (siteFilter.value && e.site !== siteFilter.value) return false
  return true
}))

const stats = computed(() => {
  const s = surveillance.items.value || []
  const done = s.filter((r) => r.result !== 'pending')
  const fit = done.filter((r) => r.result === 'fit').length
  return {
    fit,
    fitPct: done.length ? Math.round((fit / done.length) * 100) : 0,
    conditional: s.filter((r) => r.result === 'conditional').length,
    due: s.filter((r) => r.is_overdue).length,
    exceeded: (exposure.items.value || []).filter((e) => e.result === 'exceeded').length,
  }
})

async function load() {
  await Promise.all([
    surveillance.list({ ordering: '-scheduled_on' }),
    exposure.list({ ordering: '-measured_on' }),
  ])
  lookups.value = await ohs.loadLookups()
}

function openSurveillance() {
  error.value = ''
  Object.assign(surveillanceForm, {
    programme: 'general', scheduled_on: new Date().toISOString().slice(0, 10),
    employee_name: '', job_title: '', site: null, provider: '',
  })
  surveillanceDialog.value = true
}

async function saveSurveillance() {
  error.value = ''
  try {
    const payload = { ...surveillanceForm }
    if (!payload.site) delete payload.site
    await surveillance.create(payload)
    surveillanceDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Medical scheduled.' }
    await load()
  } catch (e) {
    error.value = surveillance.message(e)
  }
}

function openExposure() {
  error.value = ''
  Object.assign(exposureForm, {
    agent: 'noise', site: siteOptions.value[0]?.value || null, area: '',
    measured_value: 80, unit: 'dB(A)', oel_limit: 85,
    measured_on: new Date().toISOString().slice(0, 10),
  })
  exposureDialog.value = true
}

async function saveExposure() {
  error.value = ''
  try {
    const value = Number(exposureForm.measured_value || 0)
    const limit = Number(exposureForm.oel_limit || 0)
    const result = limit && value >= limit ? 'exceeded' : limit && value >= limit * 0.8 ? 'action' : 'compliant'
    await exposure.create({ ...exposureForm, result })
    exposureDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Reading recorded.' }
    await load()
  } catch (e) {
    error.value = exposure.message(e)
  }
}

function exportData() {
  const date = new Date().toISOString().slice(0, 10)
  if (tab.value === 'surveillance') {
    exportCsv(`health_surveillance_${date}.csv`, filteredSurveillance.value, [
      { key: 'employee_name', label: 'Employee' },
      { key: 'job_title', label: 'Job title' },
      { key: 'programme_display', label: 'Programme' },
      { key: 'site_name', label: 'Site' },
      { key: 'scheduled_on', label: 'Scheduled' },
      { key: 'completed_on', label: 'Completed' },
      { key: 'result_display', label: 'Outcome' },
      { key: 'next_due', label: 'Next due' },
      { key: 'provider', label: 'Provider' },
    ])
  } else {
    exportCsv(`exposure_monitoring_${date}.csv`, filteredExposure.value, [
      { key: 'agent_display', label: 'Agent' },
      { key: 'site_name', label: 'Site' },
      { key: 'area', label: 'Area' },
      { key: 'measured_value', label: 'Reading' },
      { key: 'unit', label: 'Unit' },
      { key: 'oel_limit', label: 'OEL' },
      { key: 'pct_of_limit', label: '% of limit' },
      { key: 'measured_on', label: 'Measured' },
      { key: 'result_display', label: 'Result' },
    ])
  }
}

watch([programmeFilter, resultFilter, agentFilter, siteFilter], load)
onMounted(load)
</script>
