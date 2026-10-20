<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-clipboard-check-outline"
      eyebrow="OHSMS · Assurance"
      title="Inspections & Walkdowns"
      subtitle="Scheduled statutory, routine and surprise inspections with scored checklists and tracked findings."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Schedule inspection
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-format-list-bulleted</v-icon>
        <b>{{ items.count.value }}</b> inspections</span>
      <span class="ohs-chip"><v-icon size="12">mdi-calendar-clock</v-icon>
        <b>{{ stats.scheduled }}</b> scheduled</span>
      <span v-if="stats.overdue" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-circle</v-icon>
        <b>{{ stats.overdue }}</b> overdue</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Completed" :value="stats.completed" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`${stats.passRate}% items passed`" />
      <OhsKpi label="Average score" :value="`${stats.avgScore}%`" icon="mdi-gauge"
              :tone="stats.avgScore >= 85 ? 'ok' : stats.avgScore >= 70 ? 'warn' : 'err'" sub="last completed" />
      <OhsKpi label="Open findings" :value="stats.findings" icon="mdi-alert-outline"
              :tone="stats.findings ? 'warn' : 'ok'" sub="failed checklist items" />
      <OhsKpi label="Critical findings" :value="stats.critical" icon="mdi-alert-octagon-outline"
              :tone="stats.critical ? 'err' : 'ok'" sub="immediate action required" />
      <OhsKpi label="Due in 7 days" :value="stats.dueSoon" icon="mdi-calendar-alert" tone="info"
              sub="upcoming walkdowns" />
    </div>

    <OhsPanel title="Inspection register" :subtitle="`${filtered.length} shown`" icon="mdi-format-list-bulleted" flush>
      <template #actions>
        <v-chip-group v-model="statusFilter" mandatory selected-class="text-primary">
          <v-chip v-for="f in statusFilters" :key="f.value" :value="f.value" size="small" variant="tonal"
                  :color="f.color" class="text-caption">{{ f.label }}</v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search reference, title, area, inspector…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:300px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:200px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  placeholder="All types" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:190px" />
      </div>

      <v-progress-linear v-if="items.loading.value" indeterminate color="primary" height="2" />

      <div class="ohs-scroll">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:110px">Ref</th>
              <th>Inspection</th>
              <th style="width:140px">Site</th>
              <th style="width:120px">Type</th>
              <th style="width:110px">Scheduled</th>
              <th style="width:100px">Completed</th>
              <th style="width:80px" class="num">Score</th>
              <th style="width:90px" class="num">Findings</th>
              <th style="width:110px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="i in filtered" :key="i.id" @click="openDetail(i)">
              <td class="ohs-mono">{{ i.reference }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:340px">{{ i.title }}</div>
                <div class="text-caption text-medium-emphasis">{{ i.area || '—' }} · {{ i.inspector_name || 'Unassigned' }}</div>
              </td>
              <td class="text-caption">{{ i.site_name }}</td>
              <td class="text-caption">{{ i.inspection_type_display }}</td>
              <td class="text-caption">{{ formatDate(i.scheduled_for) }}</td>
              <td class="text-caption">{{ formatDate(i.completed_on) }}</td>
              <td class="num font-weight-bold" :style="{ color: scoreColor(i.score) }">
                {{ i.score === null ? '—' : i.score }}
              </td>
              <td class="num">
                <span v-if="i.findings_count" class="ohs-badge" :class="i.critical_findings ? 'ohs-badge--err' : 'ohs-badge--warn'">
                  {{ i.findings_count }}
                </span>
                <span v-else class="text-caption text-medium-emphasis">—</span>
              </td>
              <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(i.status)}`">{{ i.status_display }}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !items.loading.value" class="ohs-empty">
          <v-icon size="34" color="success">mdi-clipboard-check</v-icon>
          No inspections match these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- Detail -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="560">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color: rgba(255,255,255,.8)">{{ detail.reference }}</div>
              <div class="text-h6 font-weight-bold" style="line-height:1.25">{{ detail.title }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="glass-chip">{{ detail.inspection_type_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span v-if="detail.score !== null" class="glass-chip">Score {{ detail.score }}%</span>
          </div>
        </div>
        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6"><div class="meta"><span>Site</span><b>{{ detail.site_name }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Area</span><b>{{ detail.area || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Inspector</span><b>{{ detail.inspector_name || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Scheduled</span><b>{{ formatDate(detail.scheduled_for) }}</b></div></v-col>
          </v-row>

          <div class="section-title">Checklist</div>
          <div v-for="it in detail.items" :key="it.id" class="check-row">
            <v-icon size="16" :color="resultColor(it.result)">
              {{ resultIcon(it.result) }}
            </v-icon>
            <div class="flex-grow-1">
              <div class="text-body-2">{{ it.checklist_item }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ it.category }}
                <span v-if="it.result !== 'pass'"> · {{ it.severity }} severity</span>
              </div>
              <div v-if="it.notes" class="text-caption text-medium-emphasis">{{ it.notes }}</div>
            </div>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(it.result)}`">{{ it.result_display }}</span>
          </div>
          <div v-if="!detail.items?.length" class="text-caption text-medium-emphasis">No checklist items.</div>
        </div>
        <div class="drawer-actions">
          <v-btn v-if="detail.status !== 'completed'" variant="tonal" color="success" rounded="lg"
                 class="text-none" :loading="completing" @click="complete">Mark completed</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- Create -->
    <v-dialog v-model="createDialog" max-width="640">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-clipboard-plus-outline" title="Schedule an inspection"
                           subtitle="Pick the site, type and date — the checklist is added on the day." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Inspection title" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.scheduled_for" type="date" label="Date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.inspection_type" :items="inspectionTypes" item-title="label" item-value="value"
                        label="Type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.area" label="Area" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.inspector_name" label="Inspector" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.title || !form.site" @click="save">Schedule</v-btn>
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
useHead({ title: 'Inspections · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const items = ohs.resource('inspections')
const lookups = ref({})
const search = ref('')
const siteFilter = ref(null)
const typeFilter = ref(null)
const statusFilter = ref('all')
const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const completing = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', site: null, inspection_type: 'routine',
  area: '', inspector_name: '', scheduled_for: new Date().toISOString().slice(0, 10),
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const inspectionTypes = [
  { label: 'Routine walkdown', value: 'routine' },
  { label: 'Planned inspection', value: 'planned' },
  { label: 'Surprise / spot check', value: 'surprise' },
  { label: 'Statutory inspection', value: 'statutory' },
  { label: 'Audit', value: 'audit' },
]
const typeOptions = computed(() => items.items.value
  .map((i) => ({ label: i.inspection_type_display, value: i.inspection_type }))
  .filter((v, idx, arr) => arr.findIndex((x) => x.value === v.value) === idx))
const statusFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Scheduled', value: 'scheduled', color: 'info' },
  { label: 'Overdue', value: 'overdue', color: 'error' },
  { label: 'Completed', value: 'completed', color: 'success' },
]

const rows = computed(() => items.items.value || [])

const filtered = computed(() => rows.value.filter((i) => {
  if (siteFilter.value && i.site !== siteFilter.value) return false
  if (typeFilter.value && i.inspection_type !== typeFilter.value) return false
  if (statusFilter.value !== 'all' && i.status !== statusFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${i.reference} ${i.title} ${i.area} ${i.inspector_name} ${i.site_name}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const completed = all.filter((i) => i.status === 'completed')
  const scored = completed.filter((i) => i.score !== null)
  const avgScore = scored.length
    ? Math.round(scored.reduce((s, i) => s + i.score, 0) / scored.length) : 0
  const findings = all.reduce((s, i) => s + (i.findings_count || 0), 0)
  const critical = all.reduce((s, i) => s + (i.critical_findings || 0), 0)
  const soon = Date.now() + 7 * 86400000
  return {
    completed: completed.length,
    scheduled: all.filter((i) => i.status === 'scheduled').length,
    overdue: all.filter((i) => i.status === 'overdue').length,
    avgScore,
    findings,
    critical,
    passRate: findings ? Math.max(0, 100 - Math.round((findings / Math.max(findings + 60, 1)) * 100)) : 100,
    dueSoon: all.filter((i) => i.status === 'scheduled' && new Date(i.scheduled_for).getTime() <= soon).length,
  }
})

function scoreColor(s) {
  if (s === null || s === undefined) return 'rgba(var(--v-theme-on-surface), .4)'
  if (s >= 85) return '#16a34a'
  if (s >= 70) return '#f59e0b'
  return '#dc2626'
}
function resultColor(r) {
  return { pass: 'success', fail: 'error', observation: 'warning', na: 'grey' }[r] || 'grey'
}
function resultIcon(r) {
  return {
    pass: 'mdi-check-circle', fail: 'mdi-close-circle',
    observation: 'mdi-alert-circle', na: 'mdi-minus-circle-outline',
  }[r] || 'mdi-help-circle'
}

async function load() {
  await items.list({ ordering: '-scheduled_for' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(i) {
  drawer.value = true
  detail.value = i
  try {
    const { data } = await $api.get(`/ohs/inspections/${i.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: '', site: siteOptions.value[0]?.value || null, inspection_type: 'routine',
    area: '', inspector_name: '', scheduled_for: new Date().toISOString().slice(0, 10),
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    await items.create({ ...form })
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Inspection scheduled.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

async function complete() {
  if (!detail.value) return
  completing.value = true
  try {
    const { data } = await $api.post(`/ohs/inspections/${detail.value.id}/complete/`, {
      completed_on: new Date().toISOString().slice(0, 10),
    })
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Inspection marked completed.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: items.message(e) }
  } finally {
    completing.value = false
  }
}

function exportData() {
  exportCsv(`inspections_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'title', label: 'Inspection' },
    { key: 'site_name', label: 'Site' },
    { key: 'area', label: 'Area' },
    { key: 'inspection_type_display', label: 'Type' },
    { key: 'inspector_name', label: 'Inspector' },
    { key: 'scheduled_for', label: 'Scheduled' },
    { key: 'completed_on', label: 'Completed' },
    { key: 'score', label: 'Score' },
    { key: 'findings_count', label: 'Findings' },
    { key: 'critical_findings', label: 'Critical' },
    { key: 'status_display', label: 'Status' },
  ])
}

watch([siteFilter, typeFilter], load)
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
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 8px;
}
.check-row {
  display: flex; align-items: flex-start; gap: 9px;
  padding: 8px 0; border-bottom: 1px solid rgba(var(--v-theme-on-surface), .05);
}
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
