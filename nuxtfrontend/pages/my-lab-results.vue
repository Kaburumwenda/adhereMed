<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="My Lab Tests"
      subtitle="Follow every test from request to released report — updated by your clinic as it happens."
    />

    <!-- Summary strip -->
    <div class="mlr-stats mb-5">
      <div v-for="s in statCards" :key="s.label" class="mlr-stat" :class="`is-${s.tone}`">
        <v-avatar :color="s.color" variant="tonal" size="34" rounded="lg">
          <v-icon size="18">{{ s.icon }}</v-icon>
        </v-avatar>
        <div class="mlr-stat-body">
          <b>{{ s.value }}</b>
          <span>{{ s.label }}</span>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="mlr-toolbar mb-4">
      <div class="mlr-seg">
        <button
          v-for="f in FILTERS"
          :key="f.value"
          type="button"
          class="mlr-seg-btn"
          :class="{ 'is-on': filter === f.value }"
          @click="filter = f.value"
        >
          {{ f.label }}
          <span class="mlr-seg-count">{{ countFor(f.value) }}</span>
        </button>
      </div>
      <v-btn variant="text" size="small" rounded="lg" class="text-none" :loading="loading" @click="load">
        <v-icon start size="17">mdi-refresh</v-icon>
        Refresh
      </v-btn>
    </div>

    <!-- Empty -->
    <v-card v-if="!loading && !visible.length" flat rounded="xl" class="mlr-empty pa-8 text-center">
      <v-icon size="40" color="medium-emphasis" class="mb-2">mdi-flask-empty-outline</v-icon>
      <div class="text-subtitle-1 font-weight-bold mb-1">
        {{ filter === 'all' ? 'No lab tests yet' : 'Nothing in this view' }}
      </div>
      <div class="text-body-2 text-medium-emphasis">
        When your clinic requests a test it will appear here and update as the sample is
        collected, analysed and verified.
      </div>
    </v-card>

    <!-- Records -->
    <div v-else class="mlr-list">
      <v-card
        v-for="r in visible"
        :key="r.id"
        flat
        rounded="xl"
        class="mlr-card"
        :class="{ 'is-open': expanded === r.id }"
      >
        <!-- Head -->
        <button type="button" class="mlr-head" @click="toggle(r)">
          <div class="mlr-head-main">
            <div class="mlr-ref">
              <span class="mlr-ref-code">{{ r.order_ref || `LAB-${r.source_order_id}` }}</span>
              <span class="mlr-ref-clinic">{{ r.source_tenant_name || 'Clinic' }}</span>
            </div>
            <div class="mlr-tests-line">
              {{ testSummary(r) }}
            </div>
            <div class="mlr-meta">
              <span><v-icon size="12">mdi-calendar-blank-outline</v-icon>{{ formatDate(r.requested_on) }}</span>
              <span v-if="r.ordered_by_name"><v-icon size="12">mdi-stethoscope</v-icon>{{ r.ordered_by_name }}</span>
              <span v-if="r.clinic_site_name"><v-icon size="12">mdi-map-marker-outline</v-icon>{{ r.clinic_site_name }}</span>
              <span v-if="r.priority !== 'routine'" class="mlr-prio">
                <v-icon size="12">mdi-flag-variant</v-icon>{{ priorityLabel(r.priority) }}
              </span>
            </div>
          </div>

          <div class="mlr-head-side">
            <v-chip :color="r.status_tone" size="x-small" variant="flat" class="mlr-chip">
              {{ r.stage_label }}
            </v-chip>
            <v-icon class="mlr-caret" size="20">mdi-chevron-down</v-icon>
          </div>
        </button>

        <!-- Pipeline -->
        <div class="mlr-pipe">
          <div
            v-for="(step, i) in PIPELINE"
            :key="step.key"
            class="mlr-step"
            :class="{
              'is-done': stepIndex(r) > i,
              'is-current': stepIndex(r) === i,
              'is-off': r.stage === 'cancelled',
            }"
          >
            <span class="mlr-step-dot"><v-icon size="11">{{ step.icon }}</v-icon></span>
            <span class="mlr-step-label">{{ step.label }}</span>
          </div>
        </div>

        <!-- Detail -->
        <v-expand-transition>
          <div v-if="expanded === r.id" class="mlr-body">
            <!-- Not yet released -->
            <div v-if="!r.is_verified" class="mlr-note">
              <v-icon size="16">mdi-clock-outline</v-icon>
              <div>
                <b>Not released yet.</b>
                {{ r.stage === 'ready'
                  ? 'Your results are in. A lab verifier is checking the report before it is released to you.'
                  : 'Results appear here the moment a verifier signs your report.' }}
              </div>
            </div>

            <!-- Released -->
            <template v-else>
              <div class="mlr-summary-row">
                <v-chip
                  :color="r.abnormal_count ? 'warning' : 'success'"
                  size="small"
                  variant="tonal"
                >
                  <v-icon start size="14">{{ r.abnormal_count ? 'mdi-alert-circle-outline' : 'mdi-check-circle-outline' }}</v-icon>
                  {{ r.result_summary || 'Results released' }}
                </v-chip>
                <span v-if="r.performed_by_name" class="mlr-byline">
                  Analysed by <b>{{ r.performed_by_name }}</b>
                </span>
              </div>

              <div class="mlr-results">
                <div class="mlr-results-head">
                  <span>Test</span>
                  <span>Result</span>
                  <span>Reference range</span>
                </div>
                <div
                  v-for="(res, idx) in r.results"
                  :key="idx"
                  class="mlr-result-row"
                  :class="{ 'is-abnormal': res.is_abnormal }"
                >
                  <span class="mlr-result-name">
                    {{ res.test_name }}
                    <span v-if="res.is_abnormal" class="mlr-flag">outside range</span>
                  </span>
                  <span class="mlr-result-value">
                    <b>{{ res.result_value || '—' }}</b>
                    <em v-if="res.unit">{{ res.unit }}</em>
                  </span>
                  <span class="mlr-result-range">{{ res.reference_range || '—' }}</span>
                </div>
              </div>

              <div v-if="r.clinical_notes" class="mlr-notes">
                <v-icon size="14">mdi-note-text-outline</v-icon>
                {{ r.clinical_notes }}
              </div>

              <div class="mlr-auth">
                <v-icon size="15" color="success">mdi-shield-check-outline</v-icon>
                <span>
                  Verified by <b>{{ r.verified_by_name || 'the laboratory' }}</b>
                  <template v-if="r.verified_at"> on {{ formatDateTime(r.verified_at) }}</template>
                </span>
              </div>

              <div class="mlr-actions">
                <button
                  type="button"
                  class="mlr-download"
                  :disabled="downloading === r.id"
                  @click="downloadReport(r)"
                >
                  <v-icon size="16">
                    {{ downloading === r.id ? 'mdi-loading' : 'mdi-file-download-outline' }}
                  </v-icon>
                  <span>{{ downloading === r.id ? 'Preparing…' : 'Download full report' }}</span>
                </button>
                <span class="mlr-actions-hint">
                  A printable PDF with your results, reference ranges and what each test means.
                </span>
              </div>
            </template>

            <!-- Test list -->
            <div class="mlr-testlist">
              <div v-for="(t, i) in r.tests" :key="i" class="mlr-test-item">
                <v-icon size="13">mdi-test-tube</v-icon>
                <span class="mlr-test-name">{{ t.name }}</span>
                <span class="mlr-test-code">{{ t.code }}</span>
                <span v-if="t.specimen_type" class="mlr-test-spec">{{ t.specimen_type }}</span>
              </div>
            </div>
          </div>
        </v-expand-transition>
      </v-card>
    </div>
  </v-container>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { formatDate, formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()

// Patients reach this page from the plain route, but clinic/hospital tenants
// prefix personal routes — alias it so the nav link works in every namespace.
definePageMeta({
  alias: ['/clinics/my-lab-results', '/hos/my-lab-results'],
})

const loading = ref(false)
const records = ref([])
const summary = ref({ total: 0, in_progress: 0, released: 0, abnormal_results: 0 })
const filter = ref('all')
const expanded = ref(null)
/** Id of the record whose PDF is currently being generated. */
const downloading = ref(null)

const FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'in_progress', label: 'In progress' },
  { value: 'released', label: 'Released' },
]

const PIPELINE = [
  { key: 'requested', label: 'Requested', icon: 'mdi-clipboard-text-outline' },
  { key: 'sample_collected', label: 'Sample taken', icon: 'mdi-test-tube' },
  { key: 'processing', label: 'Analysing', icon: 'mdi-microscope' },
  { key: 'ready', label: 'Report ready', icon: 'mdi-file-check-outline' },
  { key: 'released', label: 'Released', icon: 'mdi-shield-check-outline' },
]
const PIPELINE_ORDER = PIPELINE.map(p => p.key)

const statCards = computed(() => [
  { label: 'Lab tests', value: summary.value.total ?? 0, icon: 'mdi-flask-outline', color: 'primary', tone: 'primary' },
  { label: 'In progress', value: summary.value.in_progress ?? 0, icon: 'mdi-progress-clock', color: 'warning', tone: 'warning' },
  { label: 'Reports released', value: summary.value.released ?? 0, icon: 'mdi-file-check', color: 'success', tone: 'success' },
  {
    label: 'Flagged results',
    value: summary.value.abnormal_results ?? 0,
    icon: 'mdi-alert-circle-outline',
    color: (summary.value.abnormal_results ?? 0) ? 'error' : 'grey',
    tone: 'error',
  },
])

const visible = computed(() => {
  if (filter.value === 'released') return records.value.filter(r => r.is_verified)
  if (filter.value === 'in_progress') return records.value.filter(r => !r.is_verified && r.stage !== 'cancelled')
  return records.value
})

function countFor(value) {
  if (value === 'released') return records.value.filter(r => r.is_verified).length
  if (value === 'in_progress') return records.value.filter(r => !r.is_verified && r.stage !== 'cancelled').length
  return records.value.length
}

/** Index of the current stage inside the pipeline (0-based). */
function stepIndex(record) {
  const at = PIPELINE_ORDER.indexOf(record.stage)
  return at === -1 ? 0 : at
}

function testSummary(record) {
  const tests = record.tests || []
  if (!tests.length) return 'Laboratory test'
  const names = tests.map(t => t.name).filter(Boolean)
  if (names.length <= 2) return names.join(' · ')
  return `${names.slice(0, 2).join(' · ')} +${names.length - 2} more`
}

function priorityLabel(p) {
  return { stat: 'STAT', urgent: 'Urgent', routine: 'Routine' }[p] || p
}

function toggle(record) {
  expanded.value = expanded.value === record.id ? null : record.id
}

/**
 * Download the premium PDF report for a released result.
 * Only verified reports have one — the API refuses drafts with 409.
 */
async function downloadReport(record) {
  if (!import.meta.client || downloading.value) return
  downloading.value = record.id
  try {
    const { data } = await $api.get(`/exchange/lab-records/${record.id}/report/`, {
      responseType: 'blob',
    })
    const url = URL.createObjectURL(data)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `lab_report_${(record.order_ref || record.id).replace(/\s+/g, '_')}.pdf`
    document.body.appendChild(anchor)
    anchor.click()
    document.body.removeChild(anchor)
    setTimeout(() => URL.revokeObjectURL(url), 4000)
  } catch {
    // Keep it simple for the patient: no alert storm, just stop the spinner.
  } finally {
    downloading.value = null
  }
}

async function load() {
  loading.value = true
  try {
    const [list, stats] = await Promise.all([
      $api.get('/exchange/lab-records/'),
      $api.get('/exchange/lab-records/summary/'),
    ])
    records.value = Array.isArray(list.data) ? list.data : (list.data?.results || [])
    summary.value = stats.data || summary.value
  } catch {
    records.value = []
  }
  loading.value = false
}

onMounted(load)
</script>

<style scoped>
/* ── Summary cards ─────────────────────────────────────────────────────── */
.mlr-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 12px;
}
.mlr-stat {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 12px 14px;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgb(var(--v-theme-surface));
}
.mlr-stat-body { display: flex; flex-direction: column; line-height: 1.2; }
.mlr-stat-body b { font-size: 19px; font-weight: 800; font-variant-numeric: tabular-nums; }
.mlr-stat-body span {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ── Filter segmented control ──────────────────────────────────────────── */
.mlr-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
.mlr-seg {
  display: inline-flex;
  gap: 4px;
  padding: 4px;
  border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.mlr-seg-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 13px;
  border: 0;
  border-radius: 9px;
  background: transparent;
  cursor: pointer;
  font-size: 12px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.65);
  transition: background-color 0.16s ease, color 0.16s ease;
}
.mlr-seg-btn.is-on {
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-primary));
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.1);
}
.mlr-seg-count {
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  background: rgba(var(--v-theme-on-surface), 0.09);
}
.mlr-seg-btn.is-on .mlr-seg-count {
  background: rgba(var(--v-theme-primary), 0.14);
  color: rgb(var(--v-theme-primary));
}

/* ── Cards ─────────────────────────────────────────────────────────────── */
.mlr-list { display: flex; flex-direction: column; gap: 12px; }
.mlr-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
  transition: border-color 0.18s ease, box-shadow 0.18s ease;
}
.mlr-card.is-open {
  border-color: rgba(var(--v-theme-primary), 0.35);
  box-shadow: 0 10px 30px -20px rgba(15, 23, 42, 0.45);
}
.mlr-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
  width: 100%;
  padding: 14px 18px 12px;
  border: 0;
  background: transparent;
  text-align: left;
  cursor: pointer;
}
.mlr-head-main { min-width: 0; flex: 1 1 auto; }
.mlr-ref { display: flex; align-items: baseline; gap: 9px; flex-wrap: wrap; }
.mlr-ref-code {
  font-size: 13.5px;
  font-weight: 800;
  letter-spacing: 0.2px;
  font-variant-numeric: tabular-nums;
}
.mlr-ref-clinic {
  font-size: 11px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.mlr-tests-line {
  margin-top: 3px;
  font-size: 13px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.82);
}
.mlr-meta {
  display: flex;
  align-items: center;
  gap: 13px;
  margin-top: 7px;
  flex-wrap: wrap;
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.mlr-meta span { display: inline-flex; align-items: center; gap: 4px; }
.mlr-prio { color: rgb(var(--v-theme-warning)); font-weight: 700; }
.mlr-head-side { display: flex; align-items: center; gap: 8px; flex: 0 0 auto; }
.mlr-chip { font-weight: 800; letter-spacing: 0.2px; }
.mlr-caret {
  color: rgba(var(--v-theme-on-surface), 0.4);
  transition: transform 0.2s ease;
}
.mlr-card.is-open .mlr-caret { transform: rotate(180deg); }

/* ── Pipeline ──────────────────────────────────────────────────────────── */
.mlr-pipe {
  display: flex;
  gap: 0;
  padding: 0 18px 14px;
  overflow-x: auto;
}
.mlr-step {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1 1 0;
  min-width: 118px;
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.38);
  white-space: nowrap;
}
.mlr-step:not(:last-child)::after {
  content: '';
  flex: 1 1 auto;
  height: 2px;
  margin: 0 8px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.1);
}
.mlr-step-dot {
  display: grid;
  place-items: center;
  width: 20px;
  height: 20px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: rgba(var(--v-theme-on-surface), 0.08);
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.mlr-step.is-done .mlr-step-dot {
  background: rgba(var(--v-theme-success), 0.16);
  color: rgb(var(--v-theme-success));
}
.mlr-step.is-current .mlr-step-dot {
  background: rgb(var(--v-theme-primary));
  color: rgb(var(--v-theme-on-primary));
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.16);
}
.mlr-step.is-done,
.mlr-step.is-current { color: rgba(var(--v-theme-on-surface), 0.8); }
.mlr-step.is-current { color: rgb(var(--v-theme-primary)); }
.mlr-step.is-off .mlr-step-dot {
  background: rgba(var(--v-theme-error), 0.14);
  color: rgb(var(--v-theme-error));
}

/* ── Body ──────────────────────────────────────────────────────────────── */
.mlr-body {
  padding: 4px 18px 18px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.mlr-note {
  display: flex;
  gap: 9px;
  margin-top: 14px;
  padding: 11px 13px;
  border-radius: 11px;
  font-size: 12.5px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.78);
  background: rgba(var(--v-theme-info), 0.08);
  border: 1px solid rgba(var(--v-theme-info), 0.2);
}
.mlr-summary-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 14px;
  flex-wrap: wrap;
}
.mlr-byline { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), 0.55); }
.mlr-byline b { color: rgba(var(--v-theme-on-surface), 0.8); }

.mlr-results {
  margin-top: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 11px;
  overflow: hidden;
}
.mlr-results-head,
.mlr-result-row {
  display: grid;
  grid-template-columns: minmax(140px, 1.4fr) minmax(90px, 0.8fr) minmax(110px, 1fr);
  gap: 10px;
  padding: 8px 13px;
  align-items: center;
}
.mlr-results-head {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  background: rgba(var(--v-theme-on-surface), 0.04);
}
.mlr-result-row {
  font-size: 12.5px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.mlr-result-row.is-abnormal { background: rgba(var(--v-theme-warning), 0.07); }
.mlr-result-name { font-weight: 600; display: flex; align-items: center; gap: 7px; flex-wrap: wrap; }
.mlr-flag {
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  background: rgba(var(--v-theme-warning), 0.18);
  color: rgb(var(--v-theme-warning));
}
.mlr-result-value b { font-variant-numeric: tabular-nums; }
.mlr-result-value em {
  margin-left: 4px;
  font-size: 10.5px;
  font-style: normal;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.mlr-result-range {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  font-variant-numeric: tabular-nums;
}

.mlr-notes {
  display: flex;
  gap: 8px;
  margin-top: 11px;
  font-size: 12px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.mlr-auth {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 12px;
  padding-top: 11px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.65);
}
.mlr-auth b { color: rgba(var(--v-theme-on-surface), 0.85); }

.mlr-testlist {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin-top: 13px;
}
.mlr-test-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 11px;
  background: rgba(var(--v-theme-on-surface), 0.05);
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.mlr-test-name { font-weight: 700; }
.mlr-test-code {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.3px;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.mlr-test-spec { font-size: 10px; color: rgba(var(--v-theme-on-surface), 0.45); }

/* ── Download action ───────────────────────────────────────────────────── */
.mlr-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 14px;
  flex-wrap: wrap;
}
.mlr-download {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 9px 16px;
  border: 0;
  border-radius: 11px;
  cursor: pointer;
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.1px;
  color: rgb(var(--v-theme-on-primary));
  background: rgb(var(--v-theme-primary));
  box-shadow: 0 8px 20px -12px rgba(var(--v-theme-primary), 0.9);
  transition: transform 0.14s ease, box-shadow 0.14s ease, opacity 0.14s ease;
}
.mlr-download:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 12px 24px -12px rgba(var(--v-theme-primary), 0.95);
}
.mlr-download:disabled { opacity: 0.6; cursor: default; }
.mlr-download :deep(.v-icon) { color: currentColor; }
.mlr-actions-hint {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  max-width: 34ch;
  line-height: 1.4;
}

.mlr-empty { border: 1px dashed rgba(var(--v-theme-on-surface), 0.15); }
</style>
