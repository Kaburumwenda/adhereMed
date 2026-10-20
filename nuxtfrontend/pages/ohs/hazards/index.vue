<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-alert-outline"
      eyebrow="OHSMS · Risk register"
      title="Hazard & Risk Register"
      subtitle="Every identified hazard with its 5×5 risk score, hierarchy of controls and review cadence."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportRegister">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          New hazard
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-format-list-bulleted</v-icon>
        <b>{{ hazards.count.value }}</b> in register</span>
      <span class="ohs-chip"><v-icon size="12">mdi-alert-outline</v-icon>
        <b>{{ stats.open }}</b> open</span>
      <span v-if="stats.high" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ stats.high }}</b> high / critical</span>
      <span v-if="stats.overdue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-clock-alert</v-icon>
        <b>{{ stats.overdue }}</b> controls overdue</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Open hazards" :value="stats.open" icon="mdi-alert-outline" :tone="stats.high ? 'err' : 'warn'"
              :sub="`of ${hazards.count.value} total`" />
      <OhsKpi label="High / critical" :value="stats.high" icon="mdi-alert-octagon-outline"
              :tone="stats.high ? 'err' : 'ok'" sub="score ≥ 15" />
      <OhsKpi label="Average score" :value="stats.avg" icon="mdi-gauge" tone="info" sub="severity × likelihood" />
      <OhsKpi label="Controls tracked" :value="stats.controls" icon="mdi-shield-half-full" tone="primary"
              :sub="`${stats.overdue} overdue`" />
      <OhsKpi label="Reviews due" :value="stats.reviewsDue" icon="mdi-calendar-clock" tone="warn"
              sub="next review date passed" />
    </div>

    <OhsPanel title="Register" :subtitle="`${filtered.length} hazard(s) shown`" icon="mdi-format-list-bulleted" flush>
      <template #actions>
        <v-chip-group v-model="riskFilter" mandatory selected-class="text-primary" class="ohs-chips">
          <v-chip v-for="f in riskFilters" :key="f.value" :value="f.value" size="small" variant="tonal"
                  :color="f.color" class="text-caption">
            {{ f.label }}
            <span v-if="f.value !== 'all'" class="ml-1 opacity-70">{{ levelCount(f.value) }}</span>
          </v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search reference, hazard, area…" prepend-inner-icon="mdi-magnify"
                      density="compact" variant="outlined" rounded="lg" hide-details single-line clearable
                      style="max-width:280px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:200px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  placeholder="All types" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:190px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="Any status" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:165px" />
        <v-spacer />
        <v-btn-toggle v-model="view" mandatory density="compact" variant="outlined" rounded="lg" divided>
          <v-btn value="table" size="small" icon="mdi-format-list-bulleted" />
          <v-btn value="board" size="small" icon="mdi-view-grid-outline" />
        </v-btn-toggle>
      </div>

      <v-progress-linear v-if="hazards.loading.value" indeterminate color="primary" height="2" />

      <!-- TABLE -->
      <div v-if="view === 'table'" class="ohs-scroll">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:110px">Ref</th>
              <th>Hazard</th>
              <th style="width:140px">Site / area</th>
              <th style="width:130px">Type</th>
              <th style="width:62px" class="num">Sev</th>
              <th style="width:62px" class="num">Lik</th>
              <th style="width:70px" class="num">Score</th>
              <th style="width:96px">Rating</th>
              <th style="width:96px">Residual</th>
              <th style="width:86px">Controls</th>
              <th style="width:110px">Status</th>
              <th style="width:110px">Next review</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="h in filtered" :key="h.id" @click="openDetail(h)">
              <td class="ohs-mono">{{ h.reference }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:330px">{{ h.title }}</div>
                <div class="text-caption text-medium-emphasis">{{ h.owner_name || 'Unassigned' }}</div>
              </td>
              <td>
                <div class="text-caption font-weight-medium">{{ h.site_name }}</div>
                <div class="text-caption text-medium-emphasis">{{ h.area || '—' }}</div>
              </td>
              <td class="text-caption">{{ h.hazard_type_display }}</td>
              <td class="num">{{ h.severity }}</td>
              <td class="num">{{ h.likelihood }}</td>
              <td class="num font-weight-bold" :style="{ color: scoreColor(h.risk_score) }">{{ h.risk_score }}</td>
              <td><RiskBadge :level="h.risk_level" /></td>
              <td>
                <span v-if="h.residual_score" class="text-caption ohs-tabular">{{ h.residual_score }}</span>
                <span v-else class="text-caption text-medium-emphasis">—</span>
              </td>
              <td>
                <span class="text-caption">{{ h.control_count }}</span>
                <span v-if="h.overdue_controls" class="ohs-badge ohs-badge--err ml-1">
                  {{ h.overdue_controls }}
                </span>
              </td>
              <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(h.status)}`">{{ h.status_display }}</span></td>
              <td class="text-caption">{{ formatDate(h.next_review_on) }}</td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !hazards.loading.value" class="ohs-empty">
          <v-icon size="34" color="success">mdi-shield-check</v-icon>
          No hazards match these filters.
        </div>
      </div>

      <!-- BOARD -->
      <div v-else class="board">
        <div v-for="col in boardColumns" :key="col.band" class="board-col">
          <div class="board-head" :class="`board-head--${RISK_BANDS[col.band].tone}`">
            <span>{{ RISK_BANDS[col.band].label }}</span>
            <span class="board-count">{{ col.items.length }}</span>
          </div>
          <div class="board-body">
            <div v-for="h in col.items" :key="h.id" class="board-card" @click="openDetail(h)">
              <div class="d-flex align-center justify-space-between">
                <span class="ohs-mono text-caption">{{ h.reference }}</span>
                <span class="board-score" :style="{ color: scoreColor(h.risk_score) }">{{ h.risk_score }}</span>
              </div>
              <div class="text-body-2 font-weight-medium mt-1">{{ h.title }}</div>
              <div class="text-caption text-medium-emphasis">{{ h.site_name }}</div>
              <div class="d-flex flex-wrap mt-1" style="gap:4px">
                <span v-if="h.overdue_controls" class="ohs-badge ohs-badge--err">
                  {{ h.overdue_controls }} overdue
                </span>
                <span class="ohs-badge ohs-badge--muted">{{ h.control_count }} controls</span>
              </div>
            </div>
            <div v-if="!col.items.length" class="board-empty">None</div>
          </div>
        </div>
      </div>
    </OhsPanel>

    <!-- ═══════════ DETAIL DRAWER ═══════════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="560" class="ohs-drawer">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color: rgba(255,255,255,.8)">{{ detail.reference }}</div>
              <div class="text-h6 font-weight-bold" style="line-height:1.2">{{ detail.title }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <RiskBadge :level="detail.risk_level" />
            <span class="ohs-badge ohs-badge--muted" style="background:rgba(255,255,255,.16); color:#fff">
              {{ detail.hazard_type_display }}
            </span>
            <span class="ohs-badge ohs-badge--muted" style="background:rgba(255,255,255,.16); color:#fff">
              {{ detail.status_display }}
            </span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6">
              <div class="meta"><span>Site</span><b>{{ detail.site_name }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Area</span><b>{{ detail.area || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Activity</span><b>{{ detail.activity || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Exposed</span><b>{{ detail.exposed_persons || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Owner</span><b>{{ detail.owner_name || 'Unassigned' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Identified</span><b>{{ formatDate(detail.identified_on) }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Next review</span><b>{{ formatDate(detail.next_review_on) }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Legal ref.</span><b>{{ detail.legal_reference || '—' }}</b></div>
            </v-col>
          </v-row>

          <div class="score-pair">
            <div class="score-box">
              <div class="score-label">Initial risk</div>
              <div class="score-value" :style="{ color: scoreColor(detail.risk_score) }">{{ detail.risk_score }}</div>
              <div class="text-caption text-medium-emphasis">S{{ detail.severity }} × L{{ detail.likelihood }}</div>
            </div>
            <v-icon size="18" color="grey">mdi-arrow-right</v-icon>
            <div class="score-box">
              <div class="score-label">Residual risk</div>
              <div class="score-value" :style="{ color: scoreColor(detail.residual_score) }">
                {{ detail.residual_score || '—' }}
              </div>
              <div class="text-caption text-medium-emphasis">
                <template v-if="detail.residual_score">
                  S{{ detail.residual_severity }} × L{{ detail.residual_likelihood }}
                </template>
                <template v-else>not re-scored</template>
              </div>
            </div>
          </div>

          <div v-if="detail.description" class="text-body-2 mt-3">{{ detail.description }}</div>

          <div class="d-flex align-center justify-space-between mt-4 mb-2">
            <span class="text-subtitle-2 font-weight-bold">Hierarchy of controls</span>
            <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none"
                   prepend-icon="mdi-plus" @click="controlDialog = true">Add</v-btn>
          </div>

          <div v-for="c in detail.controls" :key="c.id" class="control-card">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="ohs-badge" :class="`ohs-badge--${hierarchyTone(c.hierarchy)}`">
                {{ c.hierarchy_display }}
              </span>
              <span class="ohs-badge" :class="c.is_overdue ? 'ohs-badge--err' : `ohs-badge--${toneFor(c.status)}`">
                {{ c.is_overdue ? 'Overdue' : c.status_display }}
              </span>
            </div>
            <div class="text-body-2 mt-1">{{ c.description }}</div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ c.owner_name || 'Unassigned' }} · due {{ formatDate(c.due_date) }}
              <span v-if="c.effectiveness"> · effectiveness {{ c.effectiveness }}/5</span>
            </div>
          </div>
          <div v-if="!detail.controls?.length" class="text-caption text-medium-emphasis">
            No controls recorded yet — add the first one.
          </div>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═══════════ CREATE HAZARD ═══════════ -->
    <v-dialog v-model="createDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-alert-plus" title="Log a new hazard"
                           subtitle="Score it with the 5×5 matrix — controls follow the hierarchy." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Hazard title" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.hazard_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Hazard type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.category" :items="categoryOptions" item-title="name" item-value="id"
                        label="Category" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.area" label="Area / process" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.owner_name" label="Risk owner" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="Description" rows="2" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <div class="d-flex align-center justify-space-between">
                <span class="text-caption font-weight-medium">Severity</span>
                <span class="text-caption font-weight-bold">{{ form.severity }}</span>
              </div>
              <v-slider v-model="form.severity" :min="1" :max="5" :step="1" thumb-label color="primary"
                        density="compact" hide-details show-ticks="always" />
            </v-col>
            <v-col cols="12" sm="6">
              <div class="d-flex align-center justify-space-between">
                <span class="text-caption font-weight-medium">Likelihood</span>
                <span class="text-caption font-weight-bold">{{ form.likelihood }}</span>
              </div>
              <v-slider v-model="form.likelihood" :min="1" :max="5" :step="1" thumb-label color="primary"
                        density="compact" hide-details show-ticks="always" />
            </v-col>
            <v-col cols="12" sm="6">
              <div class="d-flex align-center justify-space-between">
                <span class="text-caption font-weight-medium">Residual severity</span>
                <span class="text-caption font-weight-bold">{{ form.residual_severity }}</span>
              </div>
              <v-slider v-model="form.residual_severity" :min="1" :max="5" :step="1" thumb-label color="success"
                        density="compact" hide-details show-ticks="always" />
            </v-col>
            <v-col cols="12" sm="6">
              <div class="d-flex align-center justify-space-between">
                <span class="text-caption font-weight-medium">Residual likelihood</span>
                <span class="text-caption font-weight-bold">{{ form.residual_likelihood }}</span>
              </div>
              <v-slider v-model="form.residual_likelihood" :min="1" :max="5" :step="1" thumb-label color="success"
                        density="compact" hide-details show-ticks="always" />
            </v-col>
          </v-row>

          <div class="preview-score" :class="`preview-score--${RISK_BANDS[previewBand].tone}`">
            <div>
              <div class="text-caption opacity-90">Calculated risk</div>
              <div class="preview-value">{{ previewScore }}</div>
            </div>
            <div class="text-right">
              <div class="text-subtitle-2 font-weight-bold">{{ RISK_BANDS[previewBand].label }}</div>
              <div class="text-caption opacity-90">
                Residual {{ form.residual_severity * form.residual_likelihood }}
                · {{ RISK_BANDS[riskBand(form.residual_severity * form.residual_likelihood)].label }}
              </div>
            </div>
          </div>

          <v-alert v-if="createError" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ createError }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="hazards.saving.value"
                 :disabled="!form.title || !form.site" @click="saveHazard">Save hazard</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ ADD CONTROL ═══════════ -->
    <v-dialog v-model="controlDialog" max-width="540">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-shield-plus-outline" title="Add a control"
                           subtitle="Prefer controls higher up the hierarchy." />
        <v-card-text>
          <v-select v-model="controlForm.hierarchy" :items="hierarchyOptions" item-title="label" item-value="value"
                    label="Control type" variant="outlined" density="compact" rounded="lg" class="mb-2" />
          <v-textarea v-model="controlForm.description" label="What will be done" rows="2"
                      variant="outlined" density="compact" rounded="lg" class="mb-2" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="controlForm.owner_name" label="Responsible" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="controlForm.due_date" type="date" label="Due date"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="controlDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingControl"
                 :disabled="!controlForm.description" @click="saveControl">Add control</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { RISK_BANDS, riskBand, riskMeta, toneFor } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Risk Register · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const hazards = ohs.resource('hazards')
const lookups = ref({})

const search = ref('')
const siteFilter = ref(null)
const typeFilter = ref(null)
const statusFilter = ref(null)
const riskFilter = ref('all')
const view = ref('table')

const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const controlDialog = ref(false)
const savingControl = ref(false)
const createError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', site: null, hazard_type: 'physical', category: null, area: '',
  owner_name: '', description: '', severity: 3, likelihood: 3,
  residual_severity: 2, residual_likelihood: 2,
})
const controlForm = reactive({ hierarchy: 'engineering', description: '', owner_name: '', due_date: '' })

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const typeOptions = computed(() => lookups.value.hazard_types || [])
const categoryOptions = computed(() => lookups.value.hazard_categories || [])
const hierarchyOptions = computed(() => lookups.value.control_hierarchy || [])
const statusOptions = [
  { label: 'Open', value: 'open' },
  { label: 'Controlled', value: 'controlled' },
  { label: 'Monitoring', value: 'monitoring' },
  { label: 'Closed', value: 'closed' },
]

const riskFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Critical', value: 'critical', color: 'error' },
  { label: 'High', value: 'high', color: 'deep-orange' },
  { label: 'Medium', value: 'medium', color: 'warning' },
  { label: 'Low', value: 'low', color: 'light-green' },
  { label: 'Negligible', value: 'negligible', color: 'success' },
]

const rows = computed(() => hazards.items.value || [])

const filtered = computed(() => rows.value.filter((h) => {
  if (siteFilter.value && h.site !== siteFilter.value) return false
  if (typeFilter.value && h.hazard_type !== typeFilter.value) return false
  if (statusFilter.value && h.status !== statusFilter.value) return false
  if (riskFilter.value !== 'all' && h.risk_level !== riskFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${h.reference} ${h.title} ${h.area} ${h.activity} ${h.owner_name} ${h.site_name}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const open = rows.value.filter((h) => h.status !== 'closed')
  const high = open.filter((h) => (h.risk_score || 0) >= 15).length
  const avg = rows.value.length
    ? (rows.value.reduce((s, h) => s + (h.risk_score || 0), 0) / rows.value.length).toFixed(1)
    : '0.0'
  const controls = rows.value.reduce((s, h) => s + (h.control_count || 0), 0)
  const overdue = rows.value.reduce((s, h) => s + (h.overdue_controls || 0), 0)
  const today = new Date().toISOString().slice(0, 10)
  const reviewsDue = open.filter((h) => h.next_review_on && h.next_review_on <= today).length
  return { open: open.length, high, avg, controls, overdue, reviewsDue }
})

const boardColumns = computed(() => ['critical', 'high', 'medium', 'low'].map((band) => ({
  band,
  items: filtered.value.filter((h) => h.risk_level === band).slice(0, 12),
})))

const previewScore = computed(() => form.severity * form.likelihood)
const previewBand = computed(() => riskBand(previewScore.value))

function levelCount(band) {
  return rows.value.filter((h) => h.risk_level === band).length
}

function scoreColor(score) {
  if (!score) return 'rgba(var(--v-theme-on-surface), .45)'
  const band = riskBand(score)
  return { critical: '#b91c1c', high: '#c2410c', medium: '#b45309', low: '#4d7c0f', negligible: '#15803d' }[band]
}

function hierarchyTone(h) {
  return {
    elimination: 'ok', substitution: 'ok', engineering: 'info',
    administrative: 'warn', ppe: 'muted',
  }[h] || 'muted'
}

async function load() {
  const params = {}
  if (siteFilter.value) params.site = siteFilter.value
  if (typeFilter.value) params.hazard_type = typeFilter.value
  if (statusFilter.value) params.status = statusFilter.value
  await hazards.list(params)
  lookups.value = await ohs.loadLookups()
}

async function openDetail(h) {
  drawer.value = true
  detail.value = h
  try {
    const { data } = await $api.get(`/ohs/hazards/${h.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  createError.value = ''
  Object.assign(form, {
    title: '', site: siteOptions.value[0]?.value || null, hazard_type: 'physical',
    category: null, area: '', owner_name: '', description: '',
    severity: 3, likelihood: 3, residual_severity: 2, residual_likelihood: 2,
  })
  createDialog.value = true
}

async function saveHazard() {
  createError.value = ''
  try {
    await hazards.create({ ...form })
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Hazard added to the register.' }
    await load()
  } catch (e) {
    createError.value = hazards.message(e)
  }
}

async function saveControl() {
  if (!detail.value) return
  savingControl.value = true
  try {
    const payload = { hazard: detail.value.id, ...controlForm }
    if (!payload.due_date) delete payload.due_date
    await $api.post(`/ohs/hazards/${detail.value.id}/add_control/`, payload)
    controlDialog.value = false
    Object.assign(controlForm, { hierarchy: 'engineering', description: '', owner_name: '', due_date: '' })
    snack.value = { show: true, color: 'success', text: 'Control added.' }
    await openDetail(detail.value)
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: hazards.message(e) }
  } finally {
    savingControl.value = false
  }
}

function exportRegister() {
  exportCsv(
    `hazard_register_${new Date().toISOString().slice(0, 10)}.csv`,
    filtered.value,
    [
      { key: 'reference', label: 'Reference' },
      { key: 'title', label: 'Hazard' },
      { key: 'site_name', label: 'Site' },
      { key: 'area', label: 'Area' },
      { key: 'hazard_type_display', label: 'Type' },
      { key: 'severity', label: 'Severity' },
      { key: 'likelihood', label: 'Likelihood' },
      { key: 'risk_score', label: 'Score' },
      { key: 'risk_level', label: 'Rating' },
      { key: 'residual_score', label: 'Residual' },
      { key: 'control_count', label: 'Controls' },
      { key: 'overdue_controls', label: 'Overdue controls' },
      { key: 'status_display', label: 'Status' },
      { key: 'owner_name', label: 'Owner' },
      { key: 'next_review_on', label: 'Next review' },
    ],
  )
}

watch([siteFilter, typeFilter, statusFilter], load)
onMounted(load)
</script>

<style scoped>
.ohs-chips { gap: 2px; }
.board {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  padding: 12px;
}
@media (max-width: 1100px) { .board { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 640px) { .board { grid-template-columns: 1fr; } }
.board-col { border: 1px solid rgba(15, 23, 42, 0.08); border-radius: 11px; overflow: hidden; background: rgba(15,23,42,.015); }
.board-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 7px 11px; font-size: 11px; font-weight: 800;
  letter-spacing: 0.5px; text-transform: uppercase;
}
.board-head--err { color: #b91c1c; background: rgba(239, 68, 68, 0.12); }
.board-head--warn { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.board-head--info { color: #3f6212; background: rgba(132, 204, 22, 0.16); }
.board-head--ok { color: #15803d; background: rgba(34, 197, 94, 0.14); }
.board-head--muted { color: #64748b; background: rgba(15, 23, 42, 0.05); }
.board-count { background: rgba(255,255,255,.55); border-radius: 999px; padding: 0 6px; font-size: 10px; }
.board-body { padding: 7px; display: flex; flex-direction: column; gap: 6px; max-height: 420px; overflow: auto; }
.board-card {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.07);
  border-radius: 9px;
  padding: 8px 9px;
  cursor: pointer;
  transition: box-shadow .15s ease, transform .15s ease;
}
.board-card:hover { transform: translateY(-1px); box-shadow: 0 6px 16px rgba(15,23,42,.08); }
.board-score { font-size: 13px; font-weight: 800; }
.board-empty { padding: 14px; text-align: center; font-size: 11.5px; color: rgba(var(--v-theme-on-surface), .4); }

.drawer-head {
  padding: 16px;
  color: #fff;
  background: var(--brand-gradient);
}
.meta { display: flex; flex-direction: column; gap: 1px; }
.meta span { font-size: 10.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase; color: rgba(var(--v-theme-on-surface), .5); }
.meta b { font-size: 12.5px; font-weight: 600; }

.score-pair { display: flex; align-items: center; gap: 10px; margin-top: 14px; }
.score-box {
  flex: 1; padding: 10px 12px; border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08); background: rgba(15,23,42,.02);
}
.score-label { font-size: 10px; font-weight: 700; letter-spacing: .5px; text-transform: uppercase; color: rgba(var(--v-theme-on-surface), .5); }
.score-value { font-size: 22px; font-weight: 800; line-height: 1.1; }

.control-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 10px;
  padding: 9px 11px;
  margin-bottom: 7px;
  background: rgb(var(--v-theme-surface));
}

.preview-score {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 14px; border-radius: 12px; margin-top: 6px;
  color: #fff;
}
.preview-score--err { background: linear-gradient(120deg, #991b1b, #dc2626); }
.preview-score--warn { background: linear-gradient(120deg, #b45309, #f59e0b); }
.preview-score--info { background: linear-gradient(120deg, #3f6212, #84cc16); }
.preview-score--ok { background: linear-gradient(120deg, #15803d, #22c55e); }
.preview-score--muted { background: linear-gradient(120deg, #334155, #64748b); }
.preview-value { font-size: 26px; font-weight: 800; line-height: 1; }
</style>
