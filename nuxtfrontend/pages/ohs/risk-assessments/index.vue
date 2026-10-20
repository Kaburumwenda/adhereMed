<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-clipboard-text-search-outline"
      eyebrow="OHSMS · Risk assessment"
      title="Risk Assessments"
      subtitle="HIRA, JSA and HAZOP studies with structured line items, residual scoring and formal approval."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          New assessment
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-clipboard-text-outline</v-icon>
        <b>{{ items.count.value }}</b> assessments</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.approved }}</b> approved</span>
      <span v-if="stats.reviewDue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-calendar-alert</v-icon>
        <b>{{ stats.reviewDue }}</b> reviews due</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Approved" :value="stats.approved" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`of ${items.count.value} assessments`" />
      <OhsKpi label="In review / draft" :value="stats.inReview" icon="mdi-progress-clock"
              :tone="stats.inReview ? 'warn' : 'ok'" sub="awaiting sign-off" />
      <OhsKpi label="Expired" :value="stats.expired" icon="mdi-calendar-remove"
              :tone="stats.expired ? 'err' : 'ok'" sub="re-assessment required" />
      <OhsKpi label="Review due" :value="stats.reviewDue" icon="mdi-calendar-clock" tone="warn"
              sub="past review date" />
      <OhsKpi label="Line items" :value="stats.items" icon="mdi-format-list-numbered" tone="primary"
              sub="scored hazard lines" />
    </div>

    <OhsPanel title="Assessment register" :subtitle="`${filtered.length} shown`"
              icon="mdi-clipboard-text-outline" flush>
      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search reference, title, assessor…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:280px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:195px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="Any status" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:170px" />
        <v-select v-model="methodFilter" :items="methodOptions" item-title="label" item-value="value"
                  placeholder="Any method" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:175px" />
      </div>

      <v-progress-linear v-if="items.loading.value" indeterminate color="primary" height="2" />

      <div class="ohs-scroll">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:110px">Ref</th>
              <th>Assessment</th>
              <th style="width:140px">Site</th>
              <th style="width:110px">Method</th>
              <th style="width:70px" class="num">Lines</th>
              <th style="width:80px" class="num">Top score</th>
              <th style="width:110px">Assessed</th>
              <th style="width:110px">Review</th>
              <th style="width:110px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in filtered" :key="a.id" @click="openDetail(a)">
              <td class="ohs-mono">{{ a.reference }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:330px">{{ a.title }}</div>
                <div class="text-caption text-medium-emphasis">{{ a.assessor_name || 'Unassigned' }}</div>
              </td>
              <td class="text-caption">{{ a.site_name }}</td>
              <td class="text-caption">{{ a.methodology_display }}</td>
              <td class="num">{{ a.item_count }}</td>
              <td class="num font-weight-bold" :style="{ color: scoreColor(a.highest_score) }">
                {{ a.highest_score || '—' }}
              </td>
              <td class="text-caption">{{ formatDate(a.assessment_date) }}</td>
              <td class="text-caption">
                {{ formatDate(a.review_date) }}
                <span v-if="a.is_review_due" class="ohs-badge ohs-badge--warn ml-1">due</span>
              </td>
              <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(a.status)}`">{{ a.status_display }}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !items.loading.value" class="ohs-empty">
          No assessments match these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- Detail -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="640">
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
            <span class="glass-chip">{{ detail.methodology_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span class="glass-chip">{{ detail.site_name }}</span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <div class="text-body-2">{{ detail.scope || 'No scope recorded.' }}</div>
          <div class="text-caption text-medium-emphasis mt-2">
            Assessor {{ detail.assessor_name || '—' }} · assessed {{ formatDate(detail.assessment_date) }}
            · review {{ formatDate(detail.review_date) }}
            <span v-if="detail.approved_by"> · approved by {{ detail.approved_by }}</span>
          </div>

          <div class="section-title">Line items ({{ detail.items?.length || 0 }})</div>
          <div class="ohs-scroll" style="max-height:none">
            <table class="ohs-table ohs-table--plain">
              <thead>
                <tr>
                  <th>Hazard / activity</th>
                  <th style="width:56px" class="num">S</th>
                  <th style="width:56px" class="num">L</th>
                  <th style="width:60px" class="num">Score</th>
                  <th style="width:70px" class="num">Resid.</th>
                  <th style="width:96px">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="it in detail.items" :key="it.id">
                  <td>
                    <div class="text-caption font-weight-medium">{{ it.hazard_text }}</div>
                    <div class="text-caption text-medium-emphasis">{{ it.activity }} · {{ it.responsible || '—' }}</div>
                  </td>
                  <td class="num">{{ it.severity }}</td>
                  <td class="num">{{ it.likelihood }}</td>
                  <td class="num font-weight-bold" :style="{ color: scoreColor(it.risk_score) }">{{ it.risk_score }}</td>
                  <td class="num text-caption">{{ it.residual_score || '—' }}</td>
                  <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(it.status)}`">{{ it.status_display }}</span></td>
                </tr>
              </tbody>
            </table>
            <div v-if="!detail.items?.length" class="text-caption text-medium-emphasis">No line items yet.</div>
          </div>
        </div>

        <div class="drawer-actions">
          <v-btn v-if="detail.status !== 'approved'" variant="tonal" color="success" rounded="lg"
                 class="text-none" :loading="approving" @click="approve">Approve assessment</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- Create -->
    <v-dialog v-model="createDialog" max-width="680">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-clipboard-text-plus-outline" title="New risk assessment"
                           subtitle="Create the study header — line items are added from the register." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Assessment title" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.assessment_date" type="date" label="Date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.methodology" :items="methodOptions" item-title="label" item-value="value"
                        label="Methodology" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.assessor_name" label="Assessor" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.review_date" type="date" label="Review date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.scope" label="Scope" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.title || !form.site" @click="save">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { toneFor, riskBand } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Risk Assessments · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const items = ohs.resource('risk-assessments')
const lookups = ref({})
const search = ref('')
const siteFilter = ref(null)
const statusFilter = ref(null)
const methodFilter = ref(null)
const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const approving = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', site: null, methodology: '5x5', assessor_name: '', scope: '',
  assessment_date: new Date().toISOString().slice(0, 10), review_date: '',
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const statusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'In review', value: 'in_review' },
  { label: 'Approved', value: 'approved' },
  { label: 'Expired', value: 'expired' },
  { label: 'Archived', value: 'archived' },
]
const methodOptions = [
  { label: '5 × 5 matrix', value: '5x5' },
  { label: 'HIRA', value: 'hira' },
  { label: 'JSA', value: 'jsa' },
  { label: 'HAZOP', value: 'hazop' },
  { label: 'FMEA', value: 'fmea' },
]

const filtered = computed(() => (items.items.value || []).filter((a) => {
  if (siteFilter.value && a.site !== siteFilter.value) return false
  if (statusFilter.value && a.status !== statusFilter.value) return false
  if (methodFilter.value && a.methodology !== methodFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q && !`${a.reference} ${a.title} ${a.assessor_name} ${a.scope}`.toLowerCase().includes(q)) return false
  return true
}))

const stats = computed(() => {
  const all = items.items.value || []
  return {
    approved: all.filter((a) => a.status === 'approved').length,
    inReview: all.filter((a) => ['draft', 'in_review'].includes(a.status)).length,
    expired: all.filter((a) => a.status === 'expired').length,
    reviewDue: all.filter((a) => a.is_review_due).length,
    items: all.reduce((s, a) => s + (a.item_count || 0), 0),
  }
})

function scoreColor(score) {
  if (!score) return 'rgba(var(--v-theme-on-surface), .4)'
  const band = riskBand(score)
  return { critical: '#b91c1c', high: '#c2410c', medium: '#b45309', low: '#4d7c0f', negligible: '#15803d' }[band]
}

async function load() {
  await items.list({ ordering: '-assessment_date' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(a) {
  drawer.value = true
  detail.value = a
  try {
    const { data } = await $api.get(`/ohs/risk-assessments/${a.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: '', site: siteOptions.value[0]?.value || null, methodology: '5x5',
    assessor_name: '', scope: '',
    assessment_date: new Date().toISOString().slice(0, 10), review_date: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.review_date) delete payload.review_date
    await items.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Assessment created.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

async function approve() {
  if (!detail.value) return
  approving.value = true
  try {
    const { data } = await $api.post(`/ohs/risk-assessments/${detail.value.id}/approve/`, {})
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Assessment approved.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: items.message(e) }
  } finally {
    approving.value = false
  }
}

function exportData() {
  exportCsv(`risk_assessments_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'title', label: 'Assessment' },
    { key: 'site_name', label: 'Site' },
    { key: 'methodology_display', label: 'Method' },
    { key: 'assessor_name', label: 'Assessor' },
    { key: 'item_count', label: 'Line items' },
    { key: 'highest_score', label: 'Top score' },
    { key: 'assessment_date', label: 'Assessed' },
    { key: 'review_date', label: 'Review' },
    { key: 'status_display', label: 'Status' },
  ])
}

watch([siteFilter, statusFilter, methodFilter], load)
onMounted(load)
</script>

<style scoped>
.drawer-head { padding: 16px; color: #fff; background: var(--brand-gradient); }
.glass-chip {
  display: inline-flex; align-items: center; padding: 2px 9px; border-radius: 999px;
  font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .3px;
  background: rgba(255, 255, 255, 0.16); border: 1px solid rgba(255, 255, 255, 0.3); color: #fff;
}
.section-title {
  font-size: 11px; font-weight: 800; letter-spacing: .6px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 8px;
}
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
