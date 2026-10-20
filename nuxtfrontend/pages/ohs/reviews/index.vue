<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-clipboard-text-clock-outline"
      eyebrow="OHSMS · Clause 9.3 management review"
      title="Management Reviews"
      subtitle="Board-level reviews of the OH&S management system — clause 9.3.2 inputs, 9.3.3 outputs and the KPI snapshot at the time of decision."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">Schedule review</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-clipboard-text-clock</v-icon>
        <b>{{ items.count.value }}</b> reviews</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.completed }}</b> completed</span>
      <span v-if="stats.nextDue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-calendar-clock</v-icon>
        next due {{ formatDate(stats.nextDue) }}</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Completed" :value="stats.completed" icon="mdi-check-decagram-outline" tone="ok"
              sub="reviewed & minuted" />
      <OhsKpi label="Scheduled" :value="stats.scheduled" icon="mdi-calendar-clock" tone="info"
              sub="upcoming" />
      <OhsKpi label="System effective" :value="stats.effective" icon="mdi-shield-check-outline" tone="ok"
              sub="latest outcome" />
      <OhsKpi label="Requires improvement" :value="stats.improvement" icon="mdi-progress-wrench"
              :tone="stats.improvement ? 'warn' : 'ok'" sub="action plans open" />
      <OhsKpi label="Days since review" :value="stats.daysSince" icon="mdi-timer-outline"
              :tone="stats.daysSince > 365 ? 'err' : stats.daysSince > 300 ? 'warn' : 'ok'"
              sub="max interval 12 months" />
    </div>

    <v-row dense>
      <v-col v-for="r in items.items.value" :key="r.id" cols="12" lg="6">
        <div class="review-card" :class="`review-card--${outcomeTone(r)}`">
          <div class="d-flex align-center justify-space-between" style="gap:8px">
            <div>
              <div class="ohs-mono text-caption" style="color: rgba(var(--v-theme-on-surface),.55)">
                {{ r.reference }}
              </div>
              <div class="text-body-1 font-weight-bold" style="line-height:1.25">{{ r.title }}</div>
            </div>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(r.status)}`">{{ r.status_display }}</span>
          </div>

          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="mini-chip">{{ formatDate(r.review_date) }}</span>
            <span v-if="r.chairperson" class="mini-chip">Chair: {{ r.chairperson }}</span>
            <span v-if="r.outcome" class="ohs-badge" :class="`ohs-badge--${outcomeTone(r)}`">
              {{ r.outcome_display }}
            </span>
          </div>

          <div v-if="r.decisions" class="review-decision">
            <v-icon size="13">mdi-gavel</v-icon>
            <span>{{ r.decisions }}</span>
          </div>

          <div v-if="r.kpi_snapshot && Object.keys(r.kpi_snapshot).length" class="kpi-snap">
            <div v-for="(v, k) in kpiSnapshotRows(r)" :key="k" class="snap-item">
              <div class="snap-label">{{ k }}</div>
              <div class="snap-value">{{ v }}</div>
            </div>
          </div>

          <div class="d-flex align-center justify-space-between mt-2">
            <span class="text-caption text-medium-emphasis">
              <span v-if="r.next_review_on">Next review {{ formatDate(r.next_review_on) }}</span>
              <span v-else>No next review set</span>
            </span>
            <v-btn size="x-small" variant="text" color="primary" class="text-none"
                   prepend-icon="mdi-arrow-right" @click="openDetail(r)">Open</v-btn>
          </div>
        </div>
      </v-col>
    </v-row>
    <div v-if="!items.items.value.length" class="ohs-empty">No management reviews recorded.</div>

    <!-- ═════ DETAIL ═════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="620">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color:rgba(255,255,255,.8)">
                {{ detail.reference }} · {{ formatDate(detail.review_date) }}
              </div>
              <div class="text-h6 font-weight-bold" style="line-height:1.25">{{ detail.title }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span v-if="detail.outcome" class="glass-chip">{{ detail.outcome_display }}</span>
            <span v-if="detail.chairperson" class="glass-chip">{{ detail.chairperson }}</span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6">
              <div class="meta"><span>Period</span>
                <b>{{ formatDate(detail.period_from) }} → {{ formatDate(detail.period_to) }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Next review</span><b>{{ formatDate(detail.next_review_on) }}</b></div>
            </v-col>
          </v-row>

          <div class="section-title">Participants</div>
          <div class="text-body-2">{{ detail.participants || '—' }}</div>

          <div class="section-title">Agenda</div>
          <div class="text-body-2 prewrap">{{ detail.agenda || '—' }}</div>

          <div class="section-title">Clause 9.3.2 — Inputs</div>
          <div class="text-body-2">{{ detail.inputs || '—' }}</div>

          <div class="section-title">Clause 9.3.3 — Outputs & actions</div>
          <div class="text-body-2">{{ detail.outputs || '—' }}</div>

          <div class="section-title">Decisions</div>
          <div class="text-body-2">{{ detail.decisions || '—' }}</div>

          <template v-if="detail.kpi_snapshot && Object.keys(detail.kpi_snapshot).length">
            <div class="section-title">KPI snapshot at review</div>
            <div class="kpi-snap">
              <div v-for="(v, k) in kpiSnapshotRows(detail)" :key="k" class="snap-item">
                <div class="snap-label">{{ k }}</div>
                <div class="snap-value">{{ v }}</div>
              </div>
            </div>
          </template>
        </div>

        <div class="drawer-actions">
          <v-btn v-if="detail.status !== 'completed'" variant="tonal" color="success" rounded="lg"
                 class="text-none" @click="complete">Mark completed</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═════ CREATE ═════ -->
    <v-dialog v-model="createDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-clipboard-text-clock-outline" title="Schedule a management review"
                           subtitle="ISO 45001 requires a review at planned intervals." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Review title" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.review_date" type="date" label="Review date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.period_from" type="date" label="Period from" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.period_to" type="date" label="Period to" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.chairperson" label="Chairperson" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.next_review_on" type="date" label="Next review" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.participants" label="Participants" rows="1" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.agenda" label="Agenda" rows="3" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.inputs" label="Clause 9.3.2 inputs considered" rows="2"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.title" @click="save">Schedule</v-btn>
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
useHead({ title: 'Management Reviews · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const items = ohs.resource('management-reviews')
const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', review_date: new Date().toISOString().slice(0, 10), period_from: '', period_to: '',
  chairperson: '', participants: '', agenda: '', inputs: '', next_review_on: '',
})

const stats = computed(() => {
  const all = items.items.value || []
  const completed = all.filter((r) => r.status === 'completed')
  const latest = completed.sort((a, b) => (b.review_date || '').localeCompare(a.review_date || ''))[0]
  const daysSince = latest?.review_date
    ? Math.round((Date.now() - new Date(latest.review_date).getTime()) / 86400000) : 999
  return {
    completed: completed.length,
    scheduled: all.filter((r) => r.status === 'scheduled').length,
    effective: all.filter((r) => r.outcome === 'effective').length,
    improvement: all.filter((r) => r.outcome === 'improvement').length,
    nextDue: all.find((r) => r.status === 'scheduled')?.review_date || null,
    daysSince,
  }
})

function outcomeTone(r) {
  if (r.outcome === 'effective') return 'ok'
  if (r.outcome === 'improvement') return 'warn'
  if (r.outcome === 'inadequate') return 'err'
  return 'muted'
}

function kpiSnapshotRows(r) {
  const s = r.kpi_snapshot || {}
  const out = {}
  const map = {
    trir: 'TRIR', ltifr: 'LTIFR', open_hazards: 'Open hazards',
    high_risk_hazards: 'High-risk hazards', incidents_12m: 'Incidents (12m)',
    lost_days: 'Lost days', training_compliance_pct: 'Training currency',
    legal_compliance_pct: 'Legal compliance', inspections_completed: 'Inspections',
    permits_active: 'Active permits', contractors_approved: 'Contractors approved',
    certifications_expiring: 'Certifications expiring',
  }
  for (const [key, label] of Object.entries(map)) {
    if (s[key] !== undefined && s[key] !== null) out[label] = s[key]
  }
  return out
}

async function load() {
  await items.list({ ordering: '-review_date' })
}

async function openDetail(r) {
  drawer.value = true
  detail.value = r
  try {
    const { data } = await $api.get(`/ohs/management-reviews/${r.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: `Management review — ${new Date().toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}`,
    review_date: new Date().toISOString().slice(0, 10), period_from: '', period_to: '',
    chairperson: '', participants: '', agenda: '', inputs: '', next_review_on: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    for (const key of ['period_from', 'period_to', 'next_review_on']) {
      if (!payload[key]) delete payload[key]
    }
    await items.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Review scheduled.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

async function complete() {
  if (!detail.value) return
  try {
    const { data } = await $api.post(`/ohs/management-reviews/${detail.value.id}/complete/`, {
      outputs: 'Decisions and actions agreed; improvement plan issued.',
      outcome: 'improvement',
      next_review_on: new Date(Date.now() + 365 * 86400000).toISOString().slice(0, 10),
    })
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Review completed with KPI snapshot captured.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: items.message(e) }
  }
}

function exportData() {
  exportCsv(`management_reviews_${new Date().toISOString().slice(0, 10)}.csv`, items.items.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'title', label: 'Review' },
    { key: 'review_date', label: 'Date' },
    { key: 'chairperson', label: 'Chairperson' },
    { key: 'status_display', label: 'Status' },
    { key: 'outcome_display', label: 'Outcome' },
    { key: 'decisions', label: 'Decisions' },
    { key: 'next_review_on', label: 'Next review' },
  ])
}

onMounted(load)
</script>

<style scoped>
.review-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-left-width: 3px;
  border-radius: 13px;
  padding: 13px 14px;
  background: rgb(var(--v-theme-surface));
  height: 100%;
  transition: box-shadow .16s ease, transform .16s ease;
}
.review-card:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(15, 23, 42, .08); }
.review-card--ok { border-left-color: #16a34a; }
.review-card--warn { border-left-color: #f59e0b; }
.review-card--err { border-left-color: #dc2626; }
.review-card--muted { border-left-color: #94a3b8; }

.review-decision {
  display: flex; align-items: flex-start; gap: 7px;
  margin-top: 10px; padding: 8px 10px; border-radius: 9px;
  font-size: 11.5px; line-height: 1.4;
  background: rgba(var(--v-theme-primary), .045);
  border: 1px solid rgba(var(--v-theme-primary), .14);
}
.kpi-snap {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(88px, 1fr));
  gap: 5px; margin-top: 10px;
}
.snap-item {
  padding: 5px 7px; border-radius: 8px;
  background: rgba(15, 23, 42, .03); border: 1px solid rgba(15, 23, 42, .05);
}
.snap-label {
  font-size: 8.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .3px;
  color: rgba(var(--v-theme-on-surface), .5); line-height: 1.2;
}
.snap-value { font-size: 13px; font-weight: 800; line-height: 1.2; }

.mini-chip {
  font-size: 10px; font-weight: 600; padding: 1px 7px; border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), .62); background: rgba(15, 23, 42, 0.05);
}

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
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 4px;
}
.prewrap { white-space: pre-wrap; }
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
