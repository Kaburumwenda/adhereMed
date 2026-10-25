<template>
  <v-container fluid class="pa-4 pa-md-6 vs-page">
    <!-- ── Header (deliberately NOT a branded hero) ───────────────── -->
    <div class="vs-head">
      <div class="vs-head-lead">
        <div class="vs-head-icon">
          <v-icon size="24">mdi-heart-pulse</v-icon>
        </div>
        <div class="vs-head-text">
          <div class="vs-head-titlerow">
            <h1 class="vs-head-title">Vital Signs</h1>
            <span class="vs-head-count">{{ data.summary.total }} observations</span>
            <span class="vs-head-count">{{ data.summary.patients }} patients</span>
            <span v-if="data.summary.critical" class="vs-head-alert">
              <v-icon size="13">mdi-alert-decagram</v-icon>
              {{ data.summary.critical }} critical
            </span>
          </div>
          <p class="vs-head-sub">
            NEWS2-scored observations from triage, consultations and ward checks — one clinical record per patient.
          </p>
        </div>
      </div>

      <div class="vs-head-actions">
        <v-btn variant="outlined" rounded="lg" class="text-none vs-btn"
               prepend-icon="mdi-refresh" :loading="loading" @click="load()">
          Refresh
        </v-btn>
        <v-btn color="primary" rounded="lg" class="text-none vs-btn vs-btn-solid"
               prepend-icon="mdi-plus" @click="openDialog()">
          Record vitals
        </v-btn>
      </div>
    </div>

    <!-- ── KPI tiles ──────────────────────────────────────────────── -->
    <div class="vs-kpis">
      <button v-for="k in kpis" :key="k.key" type="button" class="vs-kpi"
              :class="[`is-${k.tone}`, { 'is-on': activeKpi === k.key }]"
              @click="toggleKpi(k.key)">
        <span class="vs-kpi-icon"><v-icon size="18">{{ k.icon }}</v-icon></span>
        <span class="vs-kpi-body">
          <span class="vs-kpi-value">{{ k.value }}</span>
          <span class="vs-kpi-label">{{ k.label }}</span>
        </span>
      </button>
    </div>

    <!-- ── Toolbar ────────────────────────────────────────────────── -->
    <div class="vs-toolbar">
      <div class="vs-search">
        <v-icon size="18" class="vs-search-icon">mdi-magnify</v-icon>
        <input v-model="search" class="vs-search-input" type="search"
               placeholder="Search patient, ID, recorder…" />
        <button v-if="search" type="button" class="vs-search-clear"
                aria-label="Clear search" @click="search = ''">
          <v-icon size="16">mdi-close</v-icon>
        </button>
      </div>

      <v-select v-model="patientFilter" :items="patientOptions" item-title="label" item-value="value"
                label="Patient" variant="outlined" density="compact" hide-details
                clearable filterable class="vs-select vs-select-wide" />

      <v-select v-model="riskFilter" :items="riskOptions" item-title="label" item-value="value"
                label="NEWS2 risk" variant="outlined" density="compact" hide-details
                clearable class="vs-select" />

      <v-select v-model="sourceFilter" :items="sourceOptions" item-title="label" item-value="value"
                label="Source" variant="outlined" density="compact" hide-details
                clearable class="vs-select" />

      <div class="vs-seg">
        <button type="button" class="vs-seg-btn" :class="{ 'is-on': view === 'timeline' }"
                @click="view = 'timeline'">
          <v-icon size="15">mdi-view-agenda-outline</v-icon> Timeline
        </button>
        <button type="button" class="vs-seg-btn" :class="{ 'is-on': view === 'patients' }"
                @click="view = 'patients'">
          <v-icon size="15">mdi-account-multiple-outline</v-icon> By patient
        </button>
      </div>
    </div>

    <!-- ── Body ───────────────────────────────────────────────────── -->
    <div class="vs-grid">
      <div class="vs-main">
        <div v-if="loading && !rows.length" class="vs-skel">
          <div v-for="i in 5" :key="i" class="vs-skel-row" />
        </div>

        <v-alert v-else-if="error" type="error" variant="tonal" density="comfortable"
                 class="mb-3" closable @click:close="error = null">
          {{ error }}
        </v-alert>

        <div v-else-if="!visibleRows.length" class="vs-empty">
          <div class="vs-empty-icon"><v-icon size="30">mdi-heart-pulse</v-icon></div>
          <div class="vs-empty-title">{{ hasFilters ? 'No observations match these filters' : 'No vitals recorded yet' }}</div>
          <div class="vs-empty-sub">
            {{ hasFilters ? 'Clear the filters or widen your search.' : 'Record the first observation to start the vitals timeline.' }}
          </div>
          <div class="vs-empty-actions">
            <v-btn v-if="hasFilters" variant="outlined" rounded="lg" class="text-none" @click="clearFilters">
              Clear filters
            </v-btn>
            <v-btn v-else color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openDialog()">
              Record vitals
            </v-btn>
          </div>
        </div>

        <!-- ── By patient ────────────────────────────────────────── -->
        <div v-else-if="view === 'patients'" class="vs-patient-grid">
          <article v-for="p in visiblePatientRows" :key="p.patient" class="vs-pcard"
                   :class="`risk-${p.risk}`" @click="focusPatient(p)">
            <header class="vs-pcard-head">
              <span class="vs-avatar">{{ initials(p.patient_name) }}</span>
              <span class="vs-pcard-id">
                <strong>{{ p.patient_name || 'Unknown patient' }}</strong>
                <small>
                  {{ p.patient_display_id || p.patient_number }}
                  <template v-if="p.patient_display_id && p.patient_number"> · {{ p.patient_number }}</template>
                </small>
              </span>
              <span class="vs-news2" :class="`risk-${p.risk}`">
                <em>{{ p.latest_news2 }}</em>
                <small>NEWS2</small>
              </span>
            </header>

            <div class="vs-risk-strip" :class="`risk-${p.risk}`">
              <v-icon size="13">{{ riskIcon(p.risk) }}</v-icon>
              {{ riskLabel(p.risk) }}
              <span class="vs-risk-when">{{ formatWhen(p.latest_at) }}</span>
            </div>

            <div class="vs-pcard-vitals">
              <span v-for="v in vitalCells(p.vital_signs, {})" :key="v.key" class="vs-mini"
                    :class="v.tone ? `tone-${v.tone}` : ''">
                <em>{{ v.short }}</em>{{ v.value }}<small>{{ v.unit }}</small>
              </span>
            </div>

            <footer class="vs-pcard-foot">
              <span class="vs-spark">
                <svg v-if="(p.series || []).length > 1" :viewBox="`0 0 ${sparkW} ${sparkH}`"
                     class="vs-spark-svg" preserveAspectRatio="none">
                  <polyline :points="sparkPoints(p.series)" fill="none"
                            :stroke="riskColor(p.risk)" stroke-width="2"
                            stroke-linejoin="round" stroke-linecap="round" />
                  <circle :cx="sparkW" :cy="sparkLastY(p.series)" r="2.6" :fill="riskColor(p.risk)" />
                </svg>
                <span v-else class="vs-spark-flat">no trend</span>
              </span>
              <span class="vs-pcard-count">
                <v-icon size="12">mdi-clipboard-list-outline</v-icon>
                {{ p.count }} {{ p.count === 1 ? 'reading' : 'readings' }}
              </span>
              <span v-if="p.bmi" class="vs-pcard-bmi">BMI {{ p.bmi }}</span>
            </footer>
          </article>
        </div>

        <!-- ── Timeline ──────────────────────────────────────────── -->
        <div v-else class="vs-timeline">
          <article v-for="r in visibleRows" :key="r.key" class="vs-row"
                   :class="[`risk-${r.risk}`, { 'is-expanded': expanded.has(r.key) }]">
            <span class="vs-row-accent" :class="`risk-${r.risk}`" />

            <header class="vs-row-head">
              <span class="vs-avatar vs-avatar-sm">{{ initials(r.patient_name) }}</span>
              <span class="vs-row-patient">
                <strong>{{ r.patient_name || 'Unknown patient' }}</strong>
                <small>{{ r.patient_display_id || r.patient_number }}</small>
              </span>

              <span class="vs-source" :class="`src-${r.source}`">{{ r.source_label }}</span>

              <span class="vs-row-spacer" />

              <span class="vs-news2 vs-news2-sm" :class="`risk-${r.risk}`">
                <em>{{ r.news2_score }}</em>
                <small>NEWS2</small>
              </span>

              <time class="vs-row-when">{{ formatWhen(r.recorded_at) }}</time>

              <button type="button" class="vs-icon-btn" title="Details"
                      @click="toggleExpand(r.key)">
                <v-icon size="16">{{ expanded.has(r.key) ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
              </button>
              <template v-if="r.editable">
                <button type="button" class="vs-icon-btn" title="Edit" @click="openDialog(r)">
                  <v-icon size="16">mdi-pencil-outline</v-icon>
                </button>
                <button type="button" class="vs-icon-btn vs-icon-btn-danger" title="Delete"
                        @click="confirmDelete(r)">
                  <v-icon size="16">mdi-trash-can-outline</v-icon>
                </button>
              </template>
              <span v-else class="vs-locked" title="Captured during triage / consultation — edit it there">
                <v-icon size="14">mdi-lock-outline</v-icon>
              </span>
            </header>

            <div class="vs-vitals">
              <span v-for="v in vitalCells(r.vital_signs, r.news2_breakdown)" :key="v.key"
                    class="vs-cell" :class="v.tone ? `tone-${v.tone}` : 'tone-none'">
                <em>{{ v.short }}</em>
                <span class="vs-cell-value">{{ v.value }}</span>
                <small>{{ v.unit }}</small>
                <span v-if="v.score" class="vs-cell-score">{{ v.score }}</span>
              </span>
            </div>

            <div v-if="expanded.has(r.key)" class="vs-detail">
              <div class="vs-detail-col">
                <div class="vs-detail-title">
                  <v-icon size="14">mdi-chart-bell-curve</v-icon> NEWS2 breakdown
                </div>
                <ul class="vs-bars">
                  <li v-for="b in breakdownRows(r)" :key="b.key" class="vs-bar-row">
                    <span class="vs-bar-label">{{ b.label }}</span>
                    <span class="vs-bar-track">
                      <span class="vs-bar-fill" :class="`tone-${b.tone}`"
                            :style="{ width: (b.score / 3) * 100 + '%' }" />
                    </span>
                    <span class="vs-bar-score" :class="`tone-${b.tone}`">{{ b.score }}</span>
                  </li>
                </ul>
              </div>

              <div class="vs-detail-col">
                <div class="vs-detail-title">
                  <v-icon size="14">mdi-information-outline</v-icon> Record
                </div>
                <dl class="vs-meta">
                  <dt>Recorded</dt>
                  <dd>{{ formatFull(r.recorded_at) }}</dd>
                  <dt>By</dt>
                  <dd>{{ r.recorded_by_name || '—' }}</dd>
                  <dt>Response</dt>
                  <dd :class="`tone-${riskTone(r.risk)}`">{{ clinicalResponse(r.risk) }}</dd>
                  <template v-if="r.bmi">
                    <dt>BMI</dt><dd>{{ r.bmi }}</dd>
                  </template>
                  <template v-if="r.context">
                    <dt>Context</dt><dd>{{ r.context }}</dd>
                  </template>
                  <template v-if="r.notes">
                    <dt>Notes</dt><dd>{{ r.notes }}</dd>
                  </template>
                </dl>
              </div>
            </div>
          </article>
        </div>
      </div>

      <!-- ── Rail ──────────────────────────────────────────────── -->
      <aside class="vs-rail">
        <section class="vs-card">
          <header class="vs-card-head">
            <v-icon size="16">mdi-chart-donut</v-icon>
            <span>Risk mix</span>
            <span class="vs-card-count">{{ data.summary.total }}</span>
          </header>
          <ul class="vs-mix">
            <li v-for="m in riskMix" :key="m.value" class="vs-mix-row">
              <button type="button" class="vs-mix-btn"
                      @click="riskFilter = riskFilter === m.value ? null : m.value">
                <span class="vs-mix-dot" :style="{ background: m.color }" />
                <span class="vs-mix-label">{{ m.label }}</span>
                <span class="vs-mix-bar">
                  <span class="vs-mix-fill" :style="{ width: m.pct + '%', background: m.color }" />
                </span>
                <span class="vs-mix-num">{{ m.count }}</span>
              </button>
            </li>
          </ul>
          <div class="vs-mix-foot">
            <span>Mean NEWS2 <strong>{{ data.summary.avg_news2 }}</strong></span>
            <span>{{ data.summary.last_24h }} in last 24 h</span>
          </div>
        </section>

        <section class="vs-card">
          <header class="vs-card-head">
            <v-icon size="16">mdi-source-branch</v-icon>
            <span>Where it came from</span>
          </header>
          <ul class="vs-sources">
            <li v-for="s in sourceMix" :key="s.value" class="vs-source-row">
              <span class="vs-source" :class="`src-${s.value}`">{{ s.label }}</span>
              <span class="vs-source-bar">
                <span class="vs-source-fill" :class="`src-${s.value}`" :style="{ width: s.pct + '%' }" />
              </span>
              <span class="vs-source-num">{{ s.count }}</span>
            </li>
          </ul>
        </section>

        <section class="vs-card">
          <header class="vs-card-head">
            <v-icon size="16">mdi-alert-decagram-outline</v-icon>
            <span>Needs review</span>
            <span class="vs-card-count">{{ reviewRows.length }}</span>
          </header>
          <div v-if="!reviewRows.length" class="vs-card-empty">Every patient is scoring low. Nice.</div>
          <ul v-else class="vs-review">
            <li v-for="r in reviewRows" :key="r.key" class="vs-review-row" @click="focusRow(r)">
              <span class="vs-review-dot" :class="`risk-${r.risk}`" />
              <span class="vs-review-text">
                <strong>{{ r.patient_name || 'Patient' }}</strong>
                <small>{{ r.source_label }} · {{ formatWhen(r.recorded_at) }}</small>
              </span>
              <span class="vs-news2 vs-news2-xs" :class="`risk-${r.risk}`">{{ r.news2_score }}</span>
            </li>
          </ul>
        </section>

        <section class="vs-card vs-legend">
          <header class="vs-card-head">
            <v-icon size="16">mdi-school-outline</v-icon>
            <span>NEWS2 reference</span>
          </header>
          <ul class="vs-legend-list">
            <li><span class="vs-legend-dot risk-low" />0 — Low, routine monitoring</li>
            <li><span class="vs-legend-dot risk-low_medium" />1–4 or any single 3 — ward review</li>
            <li><span class="vs-legend-dot risk-medium" />5–6 — urgent review within 1 h</li>
            <li><span class="vs-legend-dot risk-high" />≥7 — emergency response</li>
          </ul>
        </section>
      </aside>
    </div>

    <!-- ── Record / edit dialog ───────────────────────────────────── -->
    <v-dialog v-model="dialog" max-width="920" persistent scrollable>
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-heart-pulse"
                           :title="editing ? 'Edit vital signs' : 'Record vital signs'"
                           :subtitle="editing ? 'Correct the observation' : 'Capture a set of observations and score NEWS2 live'"
                           @close="dialog = false">
          <template #actions>
            <span class="vs-live" :class="`risk-${liveRisk}`">
              NEWS2 {{ liveTotal }} · {{ riskLabel(liveRisk) }}
            </span>
          </template>
        </BrandDialogHeader>

        <v-card-text class="vs-dialog-body">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" md="7">
                <v-select v-model="form.patient" :items="patientOptions" item-title="label" item-value="value"
                          label="Patient" variant="outlined" density="comfortable" :rules="req"
                          prepend-inner-icon="mdi-account-outline" filterable
                          :loading="patientLoading" />
              </v-col>
              <v-col cols="12" md="5">
                <v-text-field v-model="form.recorded_at" type="datetime-local" label="Observation time"
                              variant="outlined" density="comfortable"
                              prepend-inner-icon="mdi-clock-outline" />
              </v-col>
            </v-row>

            <!-- Measurements -->
            <div class="vs-field">
              <div class="vs-field-head">
                <span class="vs-field-label">Measurements</span>
                <span class="vs-field-hint">Leave blank what you did not measure</span>
              </div>
              <div class="vs-input-grid">
                <div v-for="p in PARAMS" :key="p.key" class="vs-input"
                     :class="liveScores[p.scoreKey] >= 3 ? 'tone-high' : liveScores[p.scoreKey] >= 1 ? 'tone-watch' : (form[p.key] != null && form[p.key] !== '' ? 'tone-ok' : '')">
                  <div class="vs-input-head">
                    <span>{{ p.label }}</span>
                    <span class="vs-input-score">{{ liveScores[p.scoreKey] }}</span>
                  </div>
                  <v-text-field v-model.number="form[p.key]" type="number" :suffix="p.unit"
                                :step="p.step" variant="outlined" density="compact" hide-details
                                :placeholder="p.range" />
                  <div class="vs-input-normal">{{ p.normal }}</div>
                </div>
              </div>
            </div>

            <!-- Modifiers -->
            <div class="vs-field">
              <div class="vs-field-head">
                <span class="vs-field-label">NEWS2 modifiers</span>
              </div>
              <v-row dense>
                <v-col cols="12" md="4">
                  <v-select v-model="form.consciousness" :items="consciousnessOptions"
                            label="Consciousness (AVPU)" variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-brain" hide-details />
                </v-col>
                <v-col cols="12" md="4">
                  <div class="vs-toggle-block">
                    <span class="vs-toggle-label">Supplemental oxygen</span>
                    <v-btn-toggle v-model="form.on_oxygen" mandatory density="compact" divided
                                  class="vs-toggle" color="primary">
                      <v-btn :value="false" size="small">Room air</v-btn>
                      <v-btn :value="true" size="small">On O₂</v-btn>
                    </v-btn-toggle>
                  </div>
                </v-col>
                <v-col cols="12" md="4">
                  <div class="vs-toggle-block">
                    <span class="vs-toggle-label">SpO₂ scale</span>
                    <v-btn-toggle v-model="form.spo2_scale" mandatory density="compact" divided
                                  class="vs-toggle" color="primary">
                      <v-btn :value="1" size="small">Scale 1</v-btn>
                      <v-btn :value="2" size="small">Scale 2</v-btn>
                    </v-btn-toggle>
                  </div>
                </v-col>
              </v-row>
            </div>

            <v-textarea v-model="form.notes" label="Notes (optional)" variant="outlined"
                        rows="2" auto-grow density="comfortable"
                        prepend-inner-icon="mdi-text-box-outline"
                        placeholder="Position, oxygen delivery, repeat reading, anything that explains the values…" />

            <!-- Live summary -->
            <div class="vs-live-panel" :class="`risk-${liveRisk}`">
              <div class="vs-live-score">
                <span class="vs-live-num">{{ liveTotal }}</span>
                <span class="vs-live-cap">NEWS2</span>
              </div>
              <div class="vs-live-body">
                <div class="vs-live-head">{{ riskLabel(liveRisk) }}<span v-if="hasAnyInput"> · {{ clinicalResponse(liveRisk) }}</span></div>
                <div v-if="criticalParams.length" class="vs-live-flags">
                  <span v-for="c in criticalParams" :key="c" class="vs-live-flag">{{ c }}</span>
                </div>
                <div v-else-if="!hasAnyInput" class="vs-live-muted">Enter a measurement to score.</div>
                <div v-else class="vs-live-muted">No single parameter scoring 3.</div>
              </div>
              <div v-if="liveBmi" class="vs-live-bmi">BMI {{ liveBmi }}</div>
            </div>

            <v-alert v-if="error" type="error" variant="tonal" density="compact" class="mt-2">
              {{ error }}
            </v-alert>
          </v-form>
        </v-card-text>

        <v-divider />
        <v-card-actions class="vs-dialog-actions">
          <span class="vs-dialog-hint">{{ measuredCount }} of {{ PARAMS.length }} measurements</span>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving" @click="save">
            {{ editing ? 'Save changes' : 'Record vitals' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Delete ─────────────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="440">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-trash-can-outline" title="Delete this observation?"
                           subtitle="This cannot be undone" @close="deleteDialog = false" />
        <v-card-text>
          <div class="vs-del-body">
            <div class="vs-del-icon"><v-icon size="22">mdi-alert-outline</v-icon></div>
            <div>
              The vitals record for <strong>{{ deleteTarget?.patient_name || 'this patient' }}</strong>
              taken {{ formatWhen(deleteTarget?.recorded_at) }} will be permanently removed.
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="deleting" @click="performDelete">
            Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
definePageMeta({ title: 'Vital Signs' })

/* ── Reference tables ────────────────────────────────────────── */
// scoreKey maps each measurement onto the server's NEWS2 breakdown keys.
const PARAMS = [
  { key: 'temperature', scoreKey: 'temperature', label: 'Temperature', short: 'Temp', unit: '°C', step: 0.1, range: '36.5', normal: '36.1–38.0' },
  { key: 'heart_rate', scoreKey: 'heart_rate', label: 'Heart rate', short: 'HR', unit: 'bpm', step: 1, range: '72', normal: '51–90' },
  { key: 'respiratory_rate', scoreKey: 'respiratory_rate', label: 'Respiratory rate', short: 'RR', unit: '/min', step: 1, range: '16', normal: '12–20' },
  { key: 'bp_systolic', scoreKey: 'bp_systolic', label: 'Systolic BP', short: 'BP', unit: 'mmHg', step: 1, range: '120', normal: '111–219' },
  { key: 'bp_diastolic', scoreKey: null, label: 'Diastolic BP', short: 'DIA', unit: 'mmHg', step: 1, range: '80', normal: '60–90' },
  { key: 'oxygen_saturation', scoreKey: 'oxygen_saturation', label: 'SpO₂', short: 'SpO₂', unit: '%', step: 1, range: '97', normal: '≥96' },
  { key: 'blood_sugar', scoreKey: null, label: 'Blood sugar', short: 'BG', unit: 'mmol/L', step: 0.1, range: '5.5', normal: '4.0–7.8' },
  { key: 'weight', scoreKey: null, label: 'Weight', short: 'WT', unit: 'kg', step: 0.1, range: '70', normal: '' },
  { key: 'height', scoreKey: null, label: 'Height', short: 'HT', unit: 'cm', step: 0.1, range: '170', normal: '' },
  { key: 'pain_score', scoreKey: null, label: 'Pain (0–10)', short: 'PAIN', unit: '/10', step: 1, range: '0', normal: '0–3' },
]

const consciousnessOptions = [
  { title: 'Alert', value: 'A' },
  { title: 'New confusion', value: 'CVPU' },
  { title: 'Responds to voice', value: 'V' },
  { title: 'Responds to pain', value: 'P' },
  { title: 'Unresponsive', value: 'U' },
]

const BREAKDOWN_LABELS = {
  respiratory_rate: 'Respiratory rate',
  oxygen_saturation: 'SpO₂',
  on_oxygen: 'Supplemental O₂',
  bp_systolic: 'Systolic BP',
  heart_rate: 'Heart rate',
  consciousness: 'Consciousness',
  temperature: 'Temperature',
}

const RISK_META = {
  low: { label: 'Low', color: '#10b981', icon: 'mdi-check-circle-outline' },
  low_medium: { label: 'Low–medium', color: '#f59e0b', icon: 'mdi-alert-outline' },
  medium: { label: 'Medium', color: '#f97316', icon: 'mdi-alert-outline' },
  high: { label: 'High', color: '#ef4444', icon: 'mdi-alert-decagram' },
}

const SOURCE_META = {
  vitals: { label: 'Vitals', icon: 'mdi-heart-pulse' },
  triage: { label: 'Triage', icon: 'mdi-stethoscope' },
  consultation: { label: 'Consultation', icon: 'mdi-medical-bag' },
}

/* ── State ───────────────────────────────────────────────────── */
const data = reactive({
  summary: { total: 0, patients: 0, critical: 0, review: 0, last_24h: 0, avg_news2: 0 },
  patients: [],
  results: [],
})
const loading = ref(false)
const saving = ref(false)
const error = ref(null)

const search = ref('')
const patientFilter = ref(null)
const riskFilter = ref(null)
const sourceFilter = ref(null)
const activeKpi = ref(null)
const view = ref('timeline')
const expanded = reactive(new Set())

const dialog = ref(false)
const editing = ref(null)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const deleting = ref(false)
const formRef = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })
const req = [v => (v !== null && v !== undefined && String(v).trim() !== '') || 'Required']

// The patient picker needs its own fetch — the vitals endpoint only returns
// patients who already have a reading, and you must be able to record the first.
const patientR = useResource('/patients/')
const patientOptions = computed(() =>
  (patientR.items.value || []).map(p => ({
    value: p.id,
    label: [p.patient_id || p.patient_number, p.user_name].filter(Boolean).join(' — '),
  })),
)
const patientLoading = computed(() => patientR.loading.value)

const riskOptions = [
  { value: 'high', label: 'High' },
  { value: 'medium', label: 'Medium' },
  { value: 'low_medium', label: 'Low–medium' },
  { value: 'low', label: 'Low' },
]
const sourceOptions = [
  { value: 'vitals', label: 'Vitals module' },
  { value: 'triage', label: 'Triage' },
  { value: 'consultation', label: 'Consultation' },
]

const rows = computed(() => data.results)
const patientRows = computed(() => data.patients)

/* ── Loading ─────────────────────────────────────────────────── */
async function load() {
  loading.value = true
  error.value = null
  const { $api } = useNuxtApp()
  try {
    const { data: payload } = await $api.get('/patients/vitals/', { params: { limit: 1000 } })
    data.summary = payload.summary || data.summary
    data.patients = payload.patients || []
    data.results = payload.results || []
  } catch (e) {
    error.value = e?.response?.data?.detail || e?.message || 'Could not load vitals.'
    data.results = []
    data.patients = []
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  load()
  patientR.list({ page_size: 1000 })
})

/* ── Filtering ───────────────────────────────────────────────── */
const hasFilters = computed(() =>
  !!(search.value || patientFilter.value || riskFilter.value || sourceFilter.value || activeKpi.value),
)

function passesFilters(r) {
  const q = (search.value || '').trim().toLowerCase()
  if (q) {
    const hay = [r.patient_name, r.patient_number, r.patient_display_id, r.recorded_by_name, r.context]
      .filter(Boolean).join(' ').toLowerCase()
    if (!hay.includes(q)) return false
  }
  if (patientFilter.value && r.patient !== patientFilter.value) return false
  if (riskFilter.value && r.risk !== riskFilter.value) return false
  if (sourceFilter.value && r.source !== sourceFilter.value) return false
  if (activeKpi.value === 'critical' && r.risk !== 'high') return false
  if (activeKpi.value === 'review' && !['high', 'medium'].includes(r.risk)) return false
  if (activeKpi.value === 'today') {
    const start = new Date(); start.setHours(0, 0, 0, 0)
    if (new Date(r.recorded_at).getTime() < start.getTime()) return false
  }
  if (activeKpi.value === 'mine' && r.source !== 'vitals') return false
  return true
}

const visibleRows = computed(() => rows.value.filter(passesFilters))

const visiblePatientRows = computed(() => {
  const q = (search.value || '').trim().toLowerCase()
  return patientRows.value.filter(p => {
    if (q) {
      const hay = [p.patient_name, p.patient_number, p.patient_display_id].filter(Boolean).join(' ').toLowerCase()
      if (!hay.includes(q)) return false
    }
    if (patientFilter.value && p.patient !== patientFilter.value) return false
    if (riskFilter.value && p.risk !== riskFilter.value) return false
    if (sourceFilter.value && p.source !== sourceFilter.value) return false
    if (activeKpi.value === 'critical' && p.risk !== 'high') return false
    if (activeKpi.value === 'review' && !['high', 'medium'].includes(p.risk)) return false
    return true
  })
})

function clearFilters() {
  search.value = ''
  patientFilter.value = null
  riskFilter.value = null
  sourceFilter.value = null
  activeKpi.value = null
}

function toggleKpi(key) {
  if (key === 'patients') { view.value = 'patients'; activeKpi.value = null; return }
  activeKpi.value = activeKpi.value === key ? null : key
}

const kpis = computed(() => [
  { key: 'all', label: 'Observations', value: data.summary.total, icon: 'mdi-heart-pulse', tone: 'slate' },
  { key: 'patients', label: 'Patients', value: data.summary.patients, icon: 'mdi-account-multiple-outline', tone: 'indigo' },
  { key: 'review', label: 'Need review', value: data.summary.review, icon: 'mdi-alert-outline', tone: 'amber' },
  { key: 'critical', label: 'Critical', value: data.summary.critical, icon: 'mdi-alert-decagram', tone: 'red' },
  { key: 'today', label: 'Last 24 h', value: data.summary.last_24h, icon: 'mdi-clock-outline', tone: 'teal' },
])

/* ── Rail analytics ──────────────────────────────────────────── */
const riskMix = computed(() => {
  const total = data.summary.total || 1
  return ['low', 'low_medium', 'medium', 'high'].map(value => {
    const count = rows.value.filter(r => r.risk === value).length
    return {
      value,
      label: RISK_META[value].label,
      color: RISK_META[value].color,
      count,
      pct: Math.round((count / total) * 100),
    }
  })
})

const sourceMix = computed(() => {
  const total = data.summary.total || 1
  return ['vitals', 'triage', 'consultation'].map(value => {
    const count = rows.value.filter(r => r.source === value).length
    return {
      value,
      label: SOURCE_META[value].label,
      count,
      pct: Math.round((count / total) * 100),
    }
  })
})

const reviewRows = computed(() =>
  rows.value
    .filter(r => ['high', 'medium'].includes(r.risk))
    .slice(0, 6),
)

/* ── Helpers ─────────────────────────────────────────────────── */
function riskMeta(risk) { return RISK_META[risk] || RISK_META.low }
function riskLabel(risk) { return riskMeta(risk).label }
function riskIcon(risk) { return riskMeta(risk).icon }
function riskColor(risk) { return riskMeta(risk).color }
function riskTone(risk) { return risk === 'high' ? 'high' : risk === 'medium' ? 'watch' : 'ok' }

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0].toUpperCase()).join('')
}

function formatWhen(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  const mins = Math.floor((Date.now() - d.getTime()) / 60000)
  if (mins >= 0 && mins < 1) return 'Just now'
  if (mins >= 0 && mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs >= 0 && hrs < 24) return `${hrs}h ago`
  const days = Math.floor(hrs / 24)
  if (days < 7) return `${days}d ago`
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
}

function formatFull(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
    + ' · ' + d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}

function clinicalResponse(risk) {
  if (risk === 'high') return 'Emergency team review, continuous monitoring.'
  if (risk === 'medium') return 'Urgent review by a clinician within 1 hour.'
  if (risk === 'low_medium') return 'Ward-based review; increase observation frequency.'
  return 'Routine monitoring at the usual interval.'
}

// Compact per-parameter cells. `score` (from the server breakdown) drives the
// colour so the UI can never disagree with the stored NEWS2 total.
function vitalCells(vs, breakdown) {
  const v = vs || {}
  const b = breakdown || {}
  const out = []
  const sys = v.bp_systolic
  const dia = v.bp_diastolic
  if (sys || dia) {
    out.push({
      key: 'bp',
      short: 'BP',
      value: `${sys ?? '—'}/${dia ?? '—'}`,
      unit: '',
      score: Number(b.bp_systolic || 0),
      tone: scoreTone(b.bp_systolic),
    })
  }
  const direct = [
    { key: 'temperature', short: 'Temp', unit: '°C', scoreKey: 'temperature', digits: 1 },
    { key: 'heart_rate', short: 'HR', unit: 'bpm', scoreKey: 'heart_rate' },
    { key: 'respiratory_rate', short: 'RR', unit: '/min', scoreKey: 'respiratory_rate' },
    { key: 'oxygen_saturation', short: 'SpO₂', unit: '%', scoreKey: 'oxygen_saturation' },
    { key: 'blood_sugar', short: 'BG', unit: 'mmol/L', scoreKey: null },
    { key: 'weight', short: 'WT', unit: 'kg', scoreKey: null },
  ]
  for (const d of direct) {
    const raw = v[d.key]
    if (raw === null || raw === undefined || raw === '') continue
    out.push({
      key: d.key,
      short: d.short,
      value: d.digits ? Number(raw).toFixed(d.digits) : raw,
      unit: d.unit,
      score: d.scoreKey ? Number(b[d.scoreKey] || 0) : 0,
      tone: d.scoreKey ? scoreTone(b[d.scoreKey]) : null,
    })
  }
  if (v.on_oxygen) {
    out.push({ key: 'o2', short: 'O₂', value: 'on', unit: '', score: 2, tone: 'high' })
  }
  return out
}

function scoreTone(score) {
  const n = Number(score || 0)
  if (n >= 3) return 'high'
  if (n >= 1) return 'watch'
  return 'ok'
}

function breakdownRows(row) {
  const b = row.news2_breakdown || {}
  return Object.entries(BREAKDOWN_LABELS).map(([key, label]) => ({
    key,
    label,
    score: Number(b[key] || 0),
    tone: scoreTone(b[key]),
  }))
}

/* ── Sparkline (inline SVG, tiny) ────────────────────────────── */
const sparkW = 96
const sparkH = 22

function sparkPoints(series) {
  const values = series || []
  if (values.length < 2) return ''
  const max = Math.max(1, ...values)
  return values.map((v, i) => {
    const x = (i / (values.length - 1)) * sparkW
    const y = sparkH - (v / max) * (sparkH - 2) - 1
    return `${x.toFixed(1)},${y.toFixed(1)}`
  }).join(' ')
}

function sparkLastY(series) {
  const values = series || []
  if (!values.length) return sparkH
  const max = Math.max(1, ...values)
  const v = values[values.length - 1]
  return sparkH - (v / max) * (sparkH - 2) - 1
}

/* ── Navigation between the two views ───────────────────────── */
function focusPatient(p) {
  patientFilter.value = p.patient
  view.value = 'timeline'
}

function focusRow(r) {
  patientFilter.value = r.patient
  view.value = 'timeline'
  expanded.add(r.key)
}

function toggleExpand(key) {
  if (expanded.has(key)) expanded.delete(key)
  else expanded.add(key)
}

/* ── Form ────────────────────────────────────────────────────── */
function toLocalInput(date) {
  const d = date instanceof Date ? date : new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const blankForm = () => ({
  patient: null,
  recorded_at: toLocalInput(new Date()),
  temperature: null,
  bp_systolic: null,
  bp_diastolic: null,
  heart_rate: null,
  respiratory_rate: null,
  oxygen_saturation: null,
  blood_sugar: null,
  weight: null,
  height: null,
  pain_score: null,
  spo2_scale: 1,
  on_oxygen: false,
  consciousness: 'A',
  notes: '',
})
const form = reactive(blankForm())

const hasAnyInput = computed(() =>
  PARAMS.some(p => form[p.key] !== null && form[p.key] !== undefined && form[p.key] !== ''),
)

const measuredCount = computed(() =>
  PARAMS.filter(p => form[p.key] !== null && form[p.key] !== undefined && form[p.key] !== '').length,
)

const liveBmi = computed(() => {
  const w = Number(form.weight)
  const h = Number(form.height)
  if (!w || !h) return null
  const m = h > 3 ? h / 100 : h
  return (w / (m * m)).toFixed(1)
})

/**
 * Mirror of the server's NEWS2 bands (backend/patients/vitals.py).
 * Duplicated so the dialog can score while typing — the value the server
 * computes on save is authoritative.
 */
function scoreRr(rr) {
  if (!rr || rr <= 0) return 0
  if (rr <= 8) return 3
  if (rr <= 11) return 1
  if (rr <= 20) return 0
  if (rr <= 24) return 2
  return 3
}
function scoreSpo2(sat, scale) {
  if (!sat || sat <= 0) return 0
  if (Number(scale) === 2) {
    if (sat <= 83) return 3
    if (sat <= 85) return 2
    if (sat <= 87) return 1
    if (sat <= 92) return 0
    if (sat <= 94) return 1
    if (sat <= 96) return 2
    return 3
  }
  if (sat <= 91) return 3
  if (sat <= 93) return 2
  if (sat <= 95) return 1
  return 0
}
function scoreSys(v) {
  if (!v || v <= 0) return 0
  if (v <= 90) return 3
  if (v <= 100) return 2
  if (v <= 110) return 1
  if (v <= 219) return 0
  return 3
}
function scoreHr(v) {
  if (!v || v <= 0) return 0
  if (v <= 40) return 3
  if (v <= 50) return 1
  if (v <= 90) return 0
  if (v <= 110) return 1
  if (v <= 130) return 2
  return 3
}
function scoreTemp(v) {
  if (!v || v <= 0) return 0
  if (v <= 35.0) return 3
  if (v <= 36.0) return 1
  if (v <= 38.0) return 0
  if (v <= 39.0) return 1
  return 2
}

const liveScores = computed(() => ({
  respiratory_rate: scoreRr(Number(form.respiratory_rate)),
  oxygen_saturation: scoreSpo2(Number(form.oxygen_saturation), form.spo2_scale),
  on_oxygen: form.on_oxygen ? 2 : 0,
  bp_systolic: scoreSys(Number(form.bp_systolic)),
  heart_rate: scoreHr(Number(form.heart_rate)),
  consciousness: form.consciousness && form.consciousness !== 'A' ? 3 : 0,
  temperature: scoreTemp(Number(form.temperature)),
}))

const liveTotal = computed(() => Object.values(liveScores.value).reduce((a, b) => a + b, 0))

const liveRisk = computed(() => {
  const anyThree = Object.values(liveScores.value).some(v => v >= 3)
  const t = liveTotal.value
  if (t >= 7) return 'high'
  if (t >= 5) return 'medium'
  if (anyThree || t >= 1) return 'low_medium'
  return 'low'
})

const criticalParams = computed(() =>
  Object.entries(liveScores.value)
    .filter(([, v]) => v >= 3)
    .map(([k]) => BREAKDOWN_LABELS[k] || k),
)

function openDialog(row) {
  error.value = null
  if (row) {
    editing.value = row.id
    const vs = row.vital_signs || {}
    Object.assign(form, {
      patient: row.patient,
      recorded_at: toLocalInput(row.recorded_at),
      temperature: vs.temperature ?? null,
      bp_systolic: vs.bp_systolic ?? null,
      bp_diastolic: vs.bp_diastolic ?? null,
      heart_rate: vs.heart_rate ?? null,
      respiratory_rate: vs.respiratory_rate ?? null,
      oxygen_saturation: vs.oxygen_saturation ?? null,
      blood_sugar: vs.blood_sugar ?? null,
      weight: vs.weight ?? null,
      height: vs.height ?? null,
      pain_score: vs.pain_score ?? null,
      spo2_scale: vs.spo2_scale || 1,
      on_oxygen: !!vs.on_oxygen,
      consciousness: vs.consciousness || 'A',
      notes: row.notes || '',
    })
  } else {
    editing.value = null
    Object.assign(form, blankForm())
    if (patientFilter.value) form.patient = patientFilter.value
  }
  dialog.value = true
}

function buildPayload() {
  const payload = {
    patient: form.patient,
    recorded_at: form.recorded_at ? new Date(form.recorded_at).toISOString() : new Date().toISOString(),
    spo2_scale: form.spo2_scale,
    on_oxygen: !!form.on_oxygen,
    consciousness: form.consciousness,
    notes: (form.notes || '').trim(),
  }
  for (const p of PARAMS) {
    const raw = form[p.key]
    payload[p.key] = (raw === '' || raw === null || raw === undefined) ? null : raw
  }
  return payload
}

async function save() {
  const valid = await formRef.value?.validate()
  if (valid?.valid === false) return
  saving.value = true
  error.value = null
  const { $api } = useNuxtApp()
  try {
    const payload = buildPayload()
    if (editing.value) {
      await $api.patch(`/patients/vitals/${editing.value}/`, payload)
      flash('Vitals updated')
    } else {
      await $api.post('/patients/vitals/', payload)
      flash('Vitals recorded')
    }
    dialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    error.value = d && typeof d === 'object'
      ? Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join(' · ')
      : (d?.detail || e?.message || 'Could not save the vitals.')
  } finally {
    saving.value = false
  }
}

function confirmDelete(row) {
  deleteTarget.value = row
  deleteDialog.value = true
}

async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  const { $api } = useNuxtApp()
  try {
    await $api.delete(`/patients/vitals/${deleteTarget.value.id}/`)
    deleteDialog.value = false
    deleteTarget.value = null
    flash('Vitals deleted')
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Could not delete the record', 'error')
  } finally {
    deleting.value = false
  }
}

function flash(text) { showSnack(text, 'success') }
function showSnack(text, color) {
  snack.text = text
  snack.color = color
  snack.show = true
}
</script>

<style scoped>
.vs-page { width: 100%; }

/* ── Header ── */
.vs-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 16px; flex-wrap: wrap; margin-bottom: 16px;
}
.vs-head-lead { display: flex; align-items: center; gap: 14px; min-width: 0; }
.vs-head-icon {
  width: 50px; height: 50px; border-radius: 15px; flex: 0 0 auto;
  display: grid; place-items: center; color: #fff;
  background: linear-gradient(135deg, #e11d48, #f97316);
  box-shadow: 0 10px 24px rgba(225, 29, 72, 0.28);
}
.vs-head-text { min-width: 0; }
.vs-head-titlerow { display: flex; align-items: center; gap: 9px; flex-wrap: wrap; }
.vs-head-title { font-size: 22px; font-weight: 800; letter-spacing: -0.02em; line-height: 1.2; margin: 0; }
.vs-head-count {
  font-size: 11.5px; font-weight: 700; padding: 2px 9px; border-radius: 999px;
  background: rgba(15, 23, 42, 0.06); color: rgba(15, 23, 42, 0.62);
}
.vs-head-alert {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11.5px; font-weight: 700; padding: 2px 9px; border-radius: 999px;
  background: rgba(239, 68, 68, 0.12); color: #dc2626;
}
.vs-head-sub { margin: 3px 0 0; font-size: 13px; line-height: 1.45; color: rgba(15, 23, 42, 0.55); }
.vs-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.vs-btn { height: 42px !important; font-weight: 600; }
.vs-btn-solid { color: #fff !important; }

/* ── KPI tiles ── */
.vs-kpis { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; margin-bottom: 14px; }
.vs-kpi {
  display: flex; align-items: center; gap: 11px; padding: 13px 14px;
  border-radius: 14px; text-align: left; cursor: pointer;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease;
}
.vs-kpi:hover { transform: translateY(-1px); box-shadow: 0 8px 20px rgba(15, 23, 42, 0.08); }
.vs-kpi.is-on { border-color: rgba(225, 29, 72, 0.45); box-shadow: 0 0 0 3px rgba(225, 29, 72, 0.12); }
.vs-kpi-icon { width: 34px; height: 34px; border-radius: 11px; display: grid; place-items: center; flex: 0 0 auto; }
.vs-kpi-body { display: flex; flex-direction: column; min-width: 0; }
.vs-kpi-value { font-size: 19px; font-weight: 800; line-height: 1.1; letter-spacing: -0.02em; }
.vs-kpi-label { font-size: 11.5px; font-weight: 600; color: rgba(15, 23, 42, 0.55); }
.vs-kpi.is-slate .vs-kpi-icon { background: rgba(100, 116, 139, 0.14); color: #475569; }
.vs-kpi.is-indigo .vs-kpi-icon { background: rgba(99, 102, 241, 0.14); color: #4338ca; }
.vs-kpi.is-amber .vs-kpi-icon { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.vs-kpi.is-red .vs-kpi-icon { background: rgba(239, 68, 68, 0.14); color: #dc2626; }
.vs-kpi.is-teal .vs-kpi-icon { background: rgba(20, 184, 166, 0.14); color: #0d9488; }

/* ── Toolbar ── */
.vs-toolbar {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  padding: 10px 12px; margin-bottom: 14px; border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
}
.vs-search {
  position: relative; display: flex; align-items: center; gap: 8px;
  flex: 1 1 220px; min-width: 180px; height: 40px; padding: 0 12px;
  border-radius: 11px; background: rgba(15, 23, 42, 0.04);
  border: 1px solid transparent; transition: border-color .16s ease, background .16s ease;
}
.vs-search:focus-within { background: transparent; border-color: rgba(225, 29, 72, 0.45); }
.vs-search-icon { color: rgba(15, 23, 42, 0.42); }
.vs-search-input { flex: 1; min-width: 0; border: 0; outline: 0; background: transparent; font-size: 13.5px; color: inherit; }
.vs-search-input::-webkit-search-cancel-button { display: none; }
.vs-search-clear { display: grid; place-items: center; width: 22px; height: 22px; border-radius: 6px; color: rgba(15, 23, 42, 0.5); }
.vs-search-clear:hover { background: rgba(15, 23, 42, 0.08); }
.vs-select { flex: 0 0 150px; max-width: 150px; }
.vs-select-wide { flex: 0 0 210px; max-width: 210px; }

.vs-seg { display: inline-flex; gap: 2px; padding: 3px; border-radius: 11px; background: rgba(15, 23, 42, 0.05); }
.vs-seg-btn {
  display: inline-flex; align-items: center; gap: 5px; height: 32px; padding: 0 11px;
  border-radius: 9px; font-size: 12px; font-weight: 600; color: rgba(15, 23, 42, 0.6);
  transition: background .16s ease, color .16s ease;
}
.vs-seg-btn.is-on { background: rgb(var(--v-theme-surface)); color: #e11d48; box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12); }

/* ── Layout ── */
.vs-grid { display: grid; grid-template-columns: minmax(0, 1fr) 316px; gap: 14px; align-items: start; }
.vs-main { min-width: 0; }
.vs-rail { display: flex; flex-direction: column; gap: 12px; position: sticky; top: 12px; min-width: 0; }

/* ── Risk tones ── */
.risk-low { --risk: #10b981; }
.risk-low_medium { --risk: #f59e0b; }
.risk-medium { --risk: #f97316; }
.risk-high { --risk: #ef4444; }
.tone-ok { --cell: #10b981; }
.tone-watch { --cell: #f59e0b; }
.tone-high { --cell: #ef4444; }
.tone-none { --cell: rgba(15, 23, 42, 0.45); }

/* ── Patient cards ── */
.vs-patient-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(292px, 1fr)); gap: 12px;
}
.vs-pcard {
  padding: 13px 14px; border-radius: 14px; cursor: pointer;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: box-shadow .18s ease, border-color .18s ease, transform .18s ease;
  overflow: hidden;
}
.vs-pcard:hover { box-shadow: 0 10px 26px rgba(15, 23, 42, 0.09); transform: translateY(-1px); border-color: var(--risk); }
.vs-pcard.risk-high { border-left: 3px solid #ef4444; }
.vs-pcard.risk-medium { border-left: 3px solid #f97316; }
.vs-pcard.risk-low_medium { border-left: 3px solid #f59e0b; }
.vs-pcard.risk-low { border-left: 3px solid #10b981; }

.vs-pcard-head { display: flex; align-items: center; gap: 9px; }
.vs-avatar {
  width: 32px; height: 32px; border-radius: 10px; flex: 0 0 auto;
  display: grid; place-items: center;
  font-size: 11.5px; font-weight: 800; color: #9f1239;
  background: rgba(225, 29, 72, 0.1);
}
.vs-avatar-sm { width: 28px; height: 28px; border-radius: 9px; font-size: 10.5px; }
.vs-pcard-id { display: flex; flex-direction: column; min-width: 0; }
.vs-pcard-id strong { font-size: 13px; font-weight: 750; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.vs-pcard-id small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }

.vs-news2 {
  margin-left: auto; display: flex; flex-direction: column; align-items: center;
  min-width: 42px; padding: 3px 8px; border-radius: 10px;
  background: color-mix(in srgb, var(--risk) 13%, transparent);
}
.vs-news2 em { font-style: normal; font-size: 17px; font-weight: 850; line-height: 1; color: var(--risk); }
.vs-news2 small { font-size: 8.5px; font-weight: 800; letter-spacing: 0.06em; color: var(--risk); opacity: .75; }
.vs-news2-sm { min-width: 36px; padding: 2px 7px; }
.vs-news2-sm em { font-size: 14px; }
.vs-news2-xs {
  min-width: 26px; padding: 1px 6px; font-size: 12px; font-weight: 850;
  color: var(--risk); background: color-mix(in srgb, var(--risk) 13%, transparent);
}

.vs-risk-strip {
  display: flex; align-items: center; gap: 5px; margin-top: 9px;
  padding: 4px 9px; border-radius: 8px;
  font-size: 11px; font-weight: 750; color: var(--risk);
  background: color-mix(in srgb, var(--risk) 9%, transparent);
}
.vs-risk-when { margin-left: auto; font-weight: 600; color: rgba(15, 23, 42, 0.45); }

.vs-pcard-vitals { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 9px; }
.vs-mini {
  display: inline-flex; align-items: baseline; gap: 3px;
  padding: 2px 7px; border-radius: 7px;
  font-size: 11.5px; font-weight: 700;
  background: rgba(15, 23, 42, 0.045); color: rgba(15, 23, 42, 0.78);
}
.vs-mini em { font-style: normal; font-size: 9.5px; font-weight: 700; color: rgba(15, 23, 42, 0.45); }
.vs-mini small { font-size: 9px; font-weight: 600; color: rgba(15, 23, 42, 0.4); }
.vs-mini.tone-high { background: rgba(239, 68, 68, 0.11); color: #b91c1c; }
.vs-mini.tone-watch { background: rgba(245, 158, 11, 0.13); color: #b45309; }

.vs-pcard-foot {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  margin-top: 10px; padding-top: 9px;
  border-top: 1px solid rgba(15, 23, 42, 0.07);
}
.vs-spark { display: inline-flex; align-items: center; }
.vs-spark-svg { width: 84px; height: 20px; overflow: visible; }
.vs-spark-flat { font-size: 10px; color: rgba(15, 23, 42, 0.32); }
.vs-pcard-count {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11px; font-weight: 600; color: rgba(15, 23, 42, 0.5);
}
.vs-pcard-bmi { margin-left: auto; font-size: 10.5px; font-weight: 700; color: rgba(15, 23, 42, 0.4); }

/* ── Timeline rows ── */
.vs-timeline { display: flex; flex-direction: column; gap: 9px; }
.vs-row {
  position: relative; padding: 12px 14px 12px 17px; border-radius: 14px; overflow: hidden;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: box-shadow .18s ease, border-color .18s ease;
}
.vs-row:hover { box-shadow: 0 8px 22px rgba(15, 23, 42, 0.07); }
.vs-row.is-expanded { border-color: rgba(15, 23, 42, 0.16); }
.vs-row-accent { position: absolute; inset: 0 auto 0 0; width: 4px; background: var(--risk); }

.vs-row-head { display: flex; align-items: center; gap: 9px; flex-wrap: wrap; }
.vs-row-patient { display: flex; flex-direction: column; min-width: 0; }
.vs-row-patient strong { font-size: 13px; font-weight: 750; }
.vs-row-patient small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.vs-row-spacer { flex: 1 1 auto; }
.vs-row-when { font-size: 11.5px; color: rgba(15, 23, 42, 0.45); white-space: nowrap; }

.vs-source {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 2px 8px; border-radius: 999px;
  font-size: 10.5px; font-weight: 750; letter-spacing: 0.02em;
  background: rgba(15, 23, 42, 0.06); color: rgba(15, 23, 42, 0.6);
}
.vs-source.src-vitals { background: rgba(225, 29, 72, 0.1); color: #9f1239; }
.vs-source.src-triage { background: rgba(14, 165, 233, 0.12); color: #0369a1; }
.vs-source.src-consultation { background: rgba(99, 102, 241, 0.12); color: #4338ca; }

.vs-locked {
  display: grid; place-items: center; width: 28px; height: 28px;
  color: rgba(15, 23, 42, 0.25);
}
.vs-icon-btn {
  display: grid; place-items: center; width: 28px; height: 28px; border-radius: 8px;
  color: rgba(15, 23, 42, 0.45); transition: background .14s ease, color .14s ease;
}
.vs-icon-btn:hover { background: rgba(15, 23, 42, 0.06); color: #e11d48; }
.vs-icon-btn-danger:hover { background: rgba(239, 68, 68, 0.1); color: #dc2626; }

/* Measurement cells */
.vs-vitals { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.vs-cell {
  position: relative; display: inline-flex; align-items: baseline; gap: 3px;
  padding: 4px 9px; border-radius: 9px;
  background: rgba(15, 23, 42, 0.04);
  font-size: 12.5px; font-weight: 750; color: rgba(15, 23, 42, 0.82);
  border: 1px solid transparent;
}
.vs-cell em { font-style: normal; font-size: 10px; font-weight: 700; letter-spacing: 0.03em; color: rgba(15, 23, 42, 0.45); text-transform: uppercase; }
.vs-cell small { font-size: 9.5px; font-weight: 600; color: rgba(15, 23, 42, 0.4); }
.vs-cell.tone-ok { background: rgba(16, 185, 129, 0.09); border-color: rgba(16, 185, 129, 0.22); }
.vs-cell.tone-watch { background: rgba(245, 158, 11, 0.12); border-color: rgba(245, 158, 11, 0.32); color: #92400e; }
.vs-cell.tone-high { background: rgba(239, 68, 68, 0.11); border-color: rgba(239, 68, 68, 0.34); color: #b91c1c; }
.vs-cell.tone-high em, .vs-cell.tone-high small { color: #b91c1c; opacity: .75; }
.vs-cell-score {
  margin-left: 2px; min-width: 15px; height: 15px; border-radius: 5px;
  display: inline-grid; place-items: center;
  font-size: 9.5px; font-weight: 850; color: #fff; background: var(--cell, #64748b);
}

/* Expanded detail */
.vs-detail {
  display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 18px;
  margin-top: 12px; padding-top: 12px;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}
.vs-detail-col { min-width: 0; }
.vs-detail-title {
  display: flex; align-items: center; gap: 6px; margin-bottom: 8px;
  font-size: 10.5px; font-weight: 800; letter-spacing: 0.06em; text-transform: uppercase;
  color: rgba(15, 23, 42, 0.45);
}
.vs-bars { display: flex; flex-direction: column; gap: 5px; }
.vs-bar-row { display: flex; align-items: center; gap: 8px; }
.vs-bar-label { font-size: 11.5px; font-weight: 600; width: 118px; flex: 0 0 auto; color: rgba(15, 23, 42, 0.65); }
.vs-bar-track { flex: 1; height: 6px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.vs-bar-fill { display: block; height: 100%; border-radius: 999px; background: var(--cell, #64748b); min-width: 0; }
.vs-bar-score { width: 14px; text-align: right; font-size: 11px; font-weight: 850; color: var(--cell, #64748b); }

.vs-meta { display: grid; grid-template-columns: 80px minmax(0, 1fr); gap: 4px 10px; margin: 0; }
.vs-meta dt { font-size: 11px; font-weight: 700; color: rgba(15, 23, 42, 0.42); }
.vs-meta dd { margin: 0; font-size: 12px; color: rgba(15, 23, 42, 0.75); word-break: break-word; }
.vs-meta dd.tone-high { color: #b91c1c; font-weight: 700; }
.vs-meta dd.tone-watch { color: #b45309; font-weight: 700; }
.vs-meta dd.tone-ok { color: #047857; font-weight: 700; }

/* ── Rail ── */
.vs-card {
  padding: 13px 14px; border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
}
.vs-card-head {
  display: flex; align-items: center; gap: 7px; margin-bottom: 10px;
  font-size: 12px; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase;
  color: rgba(15, 23, 42, 0.55);
}
.vs-card-count {
  margin-left: auto; font-size: 11px; font-weight: 800;
  padding: 1px 8px; border-radius: 999px;
  background: rgba(15, 23, 42, 0.06); color: rgba(15, 23, 42, 0.6);
}
.vs-card-empty { font-size: 12px; color: rgba(15, 23, 42, 0.42); }

.vs-mix { display: flex; flex-direction: column; gap: 3px; }
.vs-mix-btn { display: flex; align-items: center; gap: 8px; width: 100%; padding: 5px 6px; border-radius: 8px; text-align: left; transition: background .14s ease; }
.vs-mix-btn:hover { background: rgba(15, 23, 42, 0.04); }
.vs-mix-dot { width: 8px; height: 8px; border-radius: 3px; flex: 0 0 auto; }
.vs-mix-label { font-size: 12px; font-weight: 600; width: 88px; flex: 0 0 auto; color: rgba(15, 23, 42, 0.72); }
.vs-mix-bar { flex: 1; height: 6px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.vs-mix-fill { display: block; height: 100%; border-radius: 999px; }
.vs-mix-num { font-size: 11.5px; font-weight: 800; color: rgba(15, 23, 42, 0.6); width: 20px; text-align: right; }
.vs-mix-foot {
  display: flex; justify-content: space-between; margin-top: 10px; padding-top: 9px;
  border-top: 1px solid rgba(15, 23, 42, 0.07);
  font-size: 11px; color: rgba(15, 23, 42, 0.45);
}

.vs-sources { display: flex; flex-direction: column; gap: 7px; }
.vs-source-row { display: flex; align-items: center; gap: 8px; }
.vs-source-bar { flex: 1; height: 6px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.vs-source-fill { display: block; height: 100%; border-radius: 999px; background: rgba(15, 23, 42, 0.35); }
.vs-source-fill.src-vitals { background: #e11d48; }
.vs-source-fill.src-triage { background: #0ea5e9; }
.vs-source-fill.src-consultation { background: #6366f1; }
.vs-source-num { font-size: 11.5px; font-weight: 800; color: rgba(15, 23, 42, 0.6); width: 20px; text-align: right; }

.vs-review { display: flex; flex-direction: column; gap: 2px; }
.vs-review-row {
  display: flex; align-items: center; gap: 9px; padding: 6px;
  border-radius: 9px; cursor: pointer; transition: background .14s ease;
}
.vs-review-row:hover { background: rgba(15, 23, 42, 0.04); }
.vs-review-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--risk); flex: 0 0 auto; }
.vs-review-text { display: flex; flex-direction: column; min-width: 0; }
.vs-review-text strong { font-size: 12px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.vs-review-text small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }

.vs-legend-list { display: flex; flex-direction: column; gap: 6px; }
.vs-legend-list li { display: flex; align-items: center; gap: 7px; font-size: 11.5px; color: rgba(15, 23, 42, 0.62); }
.vs-legend-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--risk); flex: 0 0 auto; }

/* ── Empty / skeleton ── */
.vs-empty {
  display: flex; flex-direction: column; align-items: center; text-align: center;
  padding: 54px 24px; border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px dashed rgba(15, 23, 42, 0.16);
}
.vs-empty-icon {
  width: 58px; height: 58px; border-radius: 18px; display: grid; place-items: center;
  background: rgba(225, 29, 72, 0.08); color: #e11d48; margin-bottom: 12px;
}
.vs-empty-title { font-size: 15px; font-weight: 800; }
.vs-empty-sub { font-size: 13px; color: rgba(15, 23, 42, 0.5); margin-top: 3px; max-width: 430px; }
.vs-empty-actions { margin-top: 14px; }

.vs-skel { display: flex; flex-direction: column; gap: 9px; }
.vs-skel-row {
  height: 86px; border-radius: 14px;
  background: linear-gradient(90deg, rgba(15, 23, 42, 0.05), rgba(15, 23, 42, 0.09), rgba(15, 23, 42, 0.05));
  background-size: 200% 100%; animation: vsShimmer 1.4s ease-in-out infinite;
}
@keyframes vsShimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* ── Dialog ── */
.vs-dialog-body { padding: 18px 22px !important; }
.vs-dialog-actions { padding: 10px 18px !important; }
.vs-dialog-hint { font-size: 11.5px; color: rgba(15, 23, 42, 0.42); }

.vs-live {
  padding: 4px 10px; border-radius: 999px;
  font-size: 11.5px; font-weight: 800; letter-spacing: 0.02em;
  color: var(--risk); background: color-mix(in srgb, var(--risk) 14%, transparent);
}

.vs-field { margin: 6px 0 16px; }
.vs-field-head { display: flex; align-items: baseline; gap: 8px; margin-bottom: 8px; }
.vs-field-label {
  font-size: 11px; font-weight: 800; letter-spacing: 0.06em; text-transform: uppercase;
  color: rgba(15, 23, 42, 0.5);
}
.vs-field-hint { margin-left: auto; font-size: 11px; color: rgba(15, 23, 42, 0.4); }

.vs-input-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 9px; }
.vs-input {
  padding: 9px 10px; border-radius: 11px;
  background: rgba(15, 23, 42, 0.028);
  border: 1px solid rgba(15, 23, 42, 0.06);
  transition: border-color .16s ease, background .16s ease;
}
.vs-input.tone-ok { border-color: rgba(16, 185, 129, 0.35); background: rgba(16, 185, 129, 0.05); }
.vs-input.tone-watch { border-color: rgba(245, 158, 11, 0.42); background: rgba(245, 158, 11, 0.06); }
.vs-input.tone-high { border-color: rgba(239, 68, 68, 0.45); background: rgba(239, 68, 68, 0.055); }
.vs-input-head {
  display: flex; align-items: center; justify-content: space-between; gap: 6px;
  margin-bottom: 5px; font-size: 11.5px; font-weight: 700; color: rgba(15, 23, 42, 0.68);
}
.vs-input-score {
  min-width: 17px; height: 17px; border-radius: 5px;
  display: inline-grid; place-items: center;
  font-size: 9.5px; font-weight: 850; color: #fff; background: rgba(15, 23, 42, 0.25);
}
.vs-input.tone-ok .vs-input-score { background: #10b981; }
.vs-input.tone-watch .vs-input-score { background: #f59e0b; }
.vs-input.tone-high .vs-input-score { background: #ef4444; }
.vs-input-normal { margin-top: 4px; font-size: 10px; color: rgba(15, 23, 42, 0.4); min-height: 13px; }

.vs-toggle-block { display: flex; flex-direction: column; gap: 5px; }
.vs-toggle-label { font-size: 11.5px; font-weight: 600; color: rgba(15, 23, 42, 0.6); }
.vs-toggle { width: 100%; }
.vs-toggle .v-btn { flex: 1; }

.vs-live-panel {
  display: flex; align-items: center; gap: 14px;
  margin-top: 12px; padding: 12px 14px; border-radius: 13px;
  background: color-mix(in srgb, var(--risk) 8%, transparent);
  border: 1px solid color-mix(in srgb, var(--risk) 28%, transparent);
}
.vs-live-score { display: flex; flex-direction: column; align-items: center; flex: 0 0 auto; }
.vs-live-num { font-size: 26px; font-weight: 850; line-height: 1; color: var(--risk); }
.vs-live-cap { font-size: 8.5px; font-weight: 850; letter-spacing: 0.08em; color: var(--risk); opacity: .75; }
.vs-live-body { min-width: 0; flex: 1; }
.vs-live-head { font-size: 12.5px; font-weight: 750; color: rgba(15, 23, 42, 0.8); }
.vs-live-muted { font-size: 11.5px; color: rgba(15, 23, 42, 0.45); margin-top: 2px; }
.vs-live-flags { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 5px; }
.vs-live-flag {
  font-size: 10px; font-weight: 750; padding: 2px 7px; border-radius: 999px;
  background: rgba(239, 68, 68, 0.14); color: #b91c1c;
}
.vs-live-bmi { font-size: 10.5px; font-weight: 700; color: rgba(15, 23, 42, 0.45); flex: 0 0 auto; }

.vs-del-body { display: flex; align-items: flex-start; gap: 12px; font-size: 13.5px; line-height: 1.55; }
.vs-del-icon {
  width: 40px; height: 40px; border-radius: 12px; flex: 0 0 auto;
  display: grid; place-items: center;
  background: rgba(239, 68, 68, 0.12); color: #dc2626;
}

/* ── Responsive ── */
@media (max-width: 1400px) {
  .vs-kpis { grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 10px; }
  .vs-kpi { padding: 11px 12px; }
  .vs-kpi-value { font-size: 17px; }
}
@media (max-width: 1279px) {
  .vs-grid { grid-template-columns: minmax(0, 1fr); }
  .vs-rail { position: static; flex-direction: row; flex-wrap: wrap; }
  .vs-rail > .vs-card { flex: 1 1 280px; }
}
@media (max-width: 960px) {
  .vs-kpis { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .vs-select, .vs-select-wide { flex: 1 1 140px; max-width: none; }
  .vs-detail { grid-template-columns: minmax(0, 1fr); }
}
@media (max-width: 640px) {
  .vs-head { flex-direction: column; align-items: stretch; }
  .vs-head-actions .vs-btn { flex: 1; }
  .vs-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
  .vs-rail { flex-direction: column; }
  .vs-patient-grid { grid-template-columns: minmax(0, 1fr); }
  .vs-row { padding: 11px 12px 11px 15px; }
  .vs-row-when { width: 100%; }
  .vs-live-panel { flex-wrap: wrap; }
  .vs-input-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
</style>
