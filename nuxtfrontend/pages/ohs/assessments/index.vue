<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-clipboard-pulse-outline"
      eyebrow="OHSMS · Medical assessment"
      title="Pre- & Post-Employment Assessment"
      subtitle="Statutory medicals scored against the inherent requirements of the role — from the day someone is hired to the day they leave."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportRegister">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">
          New assessment
        </v-btn>
      </template>
      <span class="ohs-chip">
        <v-icon size="12">mdi-account-check-outline</v-icon>
        <b>{{ assessments.count.value }}</b> assessments
      </span>
      <span v-if="summary.overdue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-clock-alert</v-icon>
        <b>{{ summary.overdue }}</b> overdue
      </span>
      <span v-if="summary.awaiting_certificate" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-certificate-outline</v-icon>
        <b>{{ summary.awaiting_certificate }}</b> awaiting certificate
      </span>
      <span v-if="summary.work_related" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-decagram-outline</v-icon>
        <b>{{ summary.work_related }}</b> work-related
      </span>
    </OhsHero>

    <!-- ══ KPI band ══ -->
    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Assessments" :value="summary.total || 0" icon="mdi-clipboard-pulse-outline"
              tone="primary" :sub="`${summary.job_profiles || 0} job demand profiles`" />
      <OhsKpi label="Fit for duty" :value="`${summary.fit_rate || 0}%`" icon="mdi-account-check-outline"
              tone="ok" :sub="`${summary.fit || 0} cleared unconditionally`" />
      <OhsKpi label="With restrictions" :value="summary.fit_with_restrictions || 0"
              icon="mdi-account-alert-outline" :tone="summary.fit_with_restrictions ? 'warn' : 'ok'"
              sub="restricted duties" />
      <OhsKpi label="Overdue" :value="summary.overdue || 0" icon="mdi-clock-alert"
              :tone="summary.overdue ? 'err' : 'ok'" sub="past scheduled date" />
      <OhsKpi label="Awaiting certificate" :value="summary.awaiting_certificate || 0"
              icon="mdi-certificate-outline" :tone="summary.awaiting_certificate ? 'warn' : 'ok'"
              sub="outcome recorded, no document" />
      <OhsKpi label="Expiring in 60d" :value="summary.expiring || 0" icon="mdi-calendar-clock"
              :tone="summary.expiring ? 'warn' : 'ok'"
              :sub="`${summary.expired || 0} already lapsed`" />
    </div>

    <v-tabs v-model="tab" color="primary" density="compact" class="mb-3">
      <v-tab value="register" class="text-none">
        <v-icon start size="16">mdi-format-list-bulleted</v-icon>
        Register
        <span class="tab-count">{{ assessments.count.value }}</span>
      </v-tab>
      <v-tab value="queue" class="text-none">
        <v-icon start size="16">mdi-clipboard-text-clock-outline</v-icon>
        Work queue
        <span v-if="queueTotal" class="tab-count is-alert">{{ queueTotal }}</span>
      </v-tab>
      <v-tab value="jobs" class="text-none">
        <v-icon start size="16">mdi-account-hard-hat</v-icon>
        Job demand profiles
        <span class="tab-count">{{ jobDemands.count.value }}</span>
      </v-tab>
    </v-tabs>

    <v-window v-model="tab">
      <!-- ══════════════ REGISTER ══════════════ -->
      <v-window-item value="register">
        <OhsPanel title="Assessment register" :subtitle="`${filtered.length} shown`"
                  icon="mdi-format-list-bulleted" flush>
          <template #actions>
            <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-refresh"
                   :loading="assessments.loading.value" @click="load">
              Refresh
            </v-btn>
          </template>

          <div class="ohs-toolbar">
            <v-text-field v-model="search" placeholder="Search employee, reference, examiner…"
                          prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                          rounded="lg" hide-details single-line clearable style="max-width:270px" />
            <v-select v-model="kindFilter" :items="lookups.assessment_kinds || []"
                      item-title="label" item-value="value" placeholder="All kinds"
                      density="compact" variant="outlined" rounded="lg" hide-details clearable
                      style="max-width:180px" />
            <v-select v-model="fitnessFilter" :items="lookups.fitness_outcomes || []"
                      item-title="label" item-value="value" placeholder="Any outcome"
                      density="compact" variant="outlined" rounded="lg" hide-details clearable
                      style="max-width:190px" />
            <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                      placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:180px" />
            <v-spacer />
            <v-btn-toggle v-model="registerScope" density="compact" rounded color="primary"
                          class="text-none">
              <v-btn value="all" size="small" variant="text" class="text-none">All</v-btn>
              <v-btn value="overdue" size="small" variant="text" class="text-none">Overdue</v-btn>
              <v-btn value="expiring" size="small" variant="text" class="text-none">Expiring</v-btn>
            </v-btn-toggle>
          </div>

          <div class="ohs-scroll" style="max-height:64vh">
            <table class="ohs-table assess-table">
              <thead>
                <tr>
                  <th style="width:44px" class="num">#</th>
                  <th style="width:120px">Reference</th>
                  <th>Employee</th>
                  <th style="width:150px">Kind</th>
                  <th style="width:150px">Role / site</th>
                  <th style="width:104px">Scheduled</th>
                  <th style="width:96px">Examined</th>
                  <th style="width:100px" class="num">BMI</th>
                  <th style="width:108px" class="num">BP</th>
                  <th style="width:150px">Fitness</th>
                  <th style="width:130px">Certificate</th>
                  <th style="width:40px" />
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r, i) in filtered" :key="r.id" class="clickable" @click="openDetail(r)">
                  <td class="num"><span class="row-num">{{ i + 1 }}</span></td>
                  <td><span class="ohs-mono ref-cell">{{ r.reference }}</span></td>
                  <td>
                    <div class="d-flex align-center" style="gap:8px">
                      <span class="mini-avatar">{{ initialsOf(r.employee_name) }}</span>
                      <div style="min-width:0">
                        <div class="cell-strong">{{ r.employee_name }}</div>
                        <div class="cell-sub">
                          {{ r.employee_ref || 'No staff no.' }}
                          <template v-if="r.abnormal_labs">
                            · <span class="flag-ink">{{ r.abnormal_labs }} abnormal</span>
                          </template>
                        </div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="kind-chip" :class="`kind-chip--${kindTone(r.kind)}`">
                      {{ r.kind_display }}
                    </span>
                  </td>
                  <td>
                    <div class="cell-strong">{{ r.job_title || r.job_demand_title || '—' }}</div>
                    <div class="cell-sub">{{ r.site_name || 'No site' }}</div>
                  </td>
                  <td class="cell-sub">{{ formatDate(r.scheduled_on) }}</td>
                  <td class="cell-sub">
                    <span v-if="r.examined_on">{{ formatDate(r.examined_on) }}</span>
                    <span v-else-if="r.is_overdue" class="ohs-badge ohs-badge--err">Overdue</span>
                    <span v-else class="muted-dash">—</span>
                  </td>
                  <td class="num">
                    <span v-if="r.bmi" class="bmi-cell" :class="`bmi-cell--${r.bmi_band}`">
                      {{ r.bmi }}
                    </span>
                    <span v-else class="muted-dash">—</span>
                  </td>
                  <td class="num">
                    <span v-if="r.blood_pressure" class="bp-cell" :class="`bp-cell--${r.bp_band}`">
                      {{ r.blood_pressure }}
                    </span>
                    <span v-else class="muted-dash">—</span>
                  </td>
                  <td>
                    <span class="ohs-badge" :class="`ohs-badge--${fitnessTone(r.fitness)}`">
                      {{ r.fitness_display }}
                    </span>
                  </td>
                  <td class="cell-sub">
                    <span v-if="r.is_certificate_expired" class="ohs-badge ohs-badge--err">Expired</span>
                    <span v-else-if="r.certificate_no" class="cert-chip">
                      <v-icon size="11">mdi-certificate-outline</v-icon>
                      {{ r.days_to_expiry }}d left
                    </span>
                    <span v-else-if="r.status === 'completed'"
                          class="ohs-badge ohs-badge--warn">To issue</span>
                    <span v-else class="muted-dash">—</span>
                  </td>
                  <td>
                    <v-icon size="16" class="row-chevron">mdi-chevron-right</v-icon>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!filtered.length && !assessments.loading.value" class="ohs-empty">
              <v-icon size="34">mdi-clipboard-pulse-outline</v-icon>
              No assessments match these filters.
            </div>
          </div>
        </OhsPanel>
      </v-window-item>

      <!-- ══════════════ WORK QUEUE ══════════════ -->
      <v-window-item value="queue">
        <div class="queue-grid">
          <section v-for="col in queueColumns" :key="col.key" class="queue-col">
            <header class="queue-head" :class="`queue-head--${col.tone}`">
              <span class="queue-dot" />
              <span class="queue-title">{{ col.label }}</span>
              <span class="queue-count">{{ col.rows.length }}</span>
            </header>
            <p class="queue-hint">{{ col.hint }}</p>

            <div v-if="!col.rows.length" class="queue-empty">
              <v-icon size="18" :color="col.tone === 'ok' ? 'success' : undefined">
                {{ col.tone === 'ok' ? 'mdi-check-circle-outline' : 'mdi-minus-circle-outline' }}
              </v-icon>
              <span>{{ col.empty }}</span>
            </div>

            <article v-for="r in col.rows" :key="r.id" class="queue-card"
                     :class="`queue-card--${col.tone}`" @click="openDetail(r)">
              <div class="queue-card-top">
                <span class="mini-avatar">{{ initialsOf(r.employee_name) }}</span>
                <div style="min-width:0;flex:1">
                  <div class="cell-strong">{{ r.employee_name }}</div>
                  <div class="cell-sub">{{ r.job_title || r.job_demand_title || 'No role recorded' }}</div>
                </div>
                <span class="kind-chip" :class="`kind-chip--${kindTone(r.kind)}`">{{ shortKind(r) }}</span>
              </div>
              <div class="queue-card-foot">
                <span class="queue-meta">
                  <v-icon size="11">mdi-calendar</v-icon>
                  {{ formatDate(r.scheduled_on) }}
                </span>
                <span v-if="col.key === 'overdue'" class="queue-meta is-late">
                  {{ daysLate(r) }}d late
                </span>
                <span v-else-if="col.key === 'certificate'" class="queue-meta is-warn">
                  Outcome ready
                </span>
                <span v-else class="queue-meta">{{ relativeDays(r.scheduled_on) }}</span>
              </div>
            </article>
          </section>
        </div>
      </v-window-item>

      <!-- ══════════════ JOB DEMAND PROFILES ══════════════ -->
      <v-window-item value="jobs">
        <OhsPanel title="Job demand profiles" subtitle="The inherent requirements each assessment is scored against"
                  icon="mdi-account-hard-hat">
          <template #actions>
            <v-btn size="small" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
                   @click="openJobProfile()">
              New profile
            </v-btn>
          </template>

          <div v-if="!jobDemands.items.value.length" class="ohs-empty">
            <v-icon size="34">mdi-account-hard-hat</v-icon>
            No job demand profiles yet — create one to score assessments against a role.
          </div>

          <div v-else class="job-grid">
            <article v-for="j in jobDemands.items.value" :key="j.id" class="job-card">
              <div class="job-card-top">
                <span class="job-glyph">
                  <v-icon size="17">mdi-badge-account-horizontal-outline</v-icon>
                </span>
                <div style="min-width:0;flex:1">
                  <div class="cell-strong">{{ j.job_title }}</div>
                  <div class="cell-sub">
                    {{ j.department || 'No department' }}
                    <template v-if="j.site_name"> · {{ j.site_name }}</template>
                  </div>
                </div>
                <v-btn icon="mdi-pencil-outline" size="x-small" variant="text"
                       @click="openJobProfile(j)" />
              </div>

              <div class="job-facts">
                <div class="job-fact">
                  <span>Physical demand</span>
                  <b :class="`demand-${j.physical_demand}`">{{ j.physical_demand_display }}</b>
                </div>
                <div class="job-fact">
                  <span>Surveillance</span>
                  <b>{{ j.surveillance_tier_display }}</b>
                </div>
                <div class="job-fact">
                  <span>Assessments</span>
                  <b>{{ j.assessment_count }}</b>
                </div>
              </div>

              <div v-if="j.hazard_exposures?.length" class="job-chips">
                <span class="job-chips-label">Exposures</span>
                <span v-for="e in j.hazard_exposures" :key="e" class="job-chip is-risk">{{ e }}</span>
              </div>
              <div v-if="j.mandatory_tests?.length" class="job-chips">
                <span class="job-chips-label">Required tests</span>
                <span v-for="t in j.mandatory_tests" :key="t" class="job-chip">{{ t }}</span>
              </div>
              <div v-if="j.mandatory_immunisations?.length" class="job-chips">
                <span class="job-chips-label">Immunisations</span>
                <span v-for="m in j.mandatory_immunisations" :key="m" class="job-chip is-ok">{{ m }}</span>
              </div>

              <div class="job-standards">
                <span><v-icon size="11">mdi-eye-outline</v-icon>Vision {{ j.min_vision_left }} / {{ j.min_vision_right }}</span>
                <span><v-icon size="11">mdi-ear-hearing</v-icon>Hearing ≤ {{ j.max_hearing_loss_db ?? '—' }} dB</span>
              </div>
            </article>
          </div>
        </OhsPanel>
      </v-window-item>
    </v-window>

    <!-- ══════════════════ DETAIL DRAWER ══════════════════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="640">
      <div v-if="detail" class="assess-drawer">
        <header class="ad-head">
          <span class="ad-glow" />
          <div class="ad-head-row">
            <div style="min-width:0">
              <div class="ad-ref">{{ detail.reference }}</div>
              <div class="ad-name">{{ detail.employee_name }}</div>
              <div class="ad-role">
                {{ detail.job_title || detail.job_demand_title || 'Role not recorded' }}
                <template v-if="detail.site_name"> · {{ detail.site_name }}</template>
              </div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" class="ad-close" @click="drawer = false" />
          </div>
          <div class="ad-chips">
            <span class="glass-chip">{{ detail.kind_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span v-if="detail.work_related" class="glass-chip is-alert">Work-related</span>
            <span v-if="detail.compensation_claim" class="glass-chip is-alert">Compensation claim</span>
          </div>

          <!-- Fitness verdict -->
          <div class="ad-verdict" :class="`ad-verdict--${fitnessTone(detail.fitness)}`">
            <v-icon size="20">{{ fitnessIcon(detail.fitness) }}</v-icon>
            <div style="min-width:0">
              <div class="ad-verdict-label">{{ detail.fitness_display }}</div>
              <div class="ad-verdict-sub">
                <template v-if="detail.restrictions">{{ detail.restrictions }}</template>
                <template v-else-if="detail.examined_on">Examined {{ formatDate(detail.examined_on) }} by {{ detail.examiner_name || 'unspecified examiner' }}</template>
                <template v-else>Awaiting examination</template>
              </div>
            </div>
          </div>
        </header>

        <div class="ad-body">
          <!-- Measurements -->
          <div class="ad-section">
            <div class="ad-section-title">
              <v-icon size="13">mdi-human-male-height</v-icon> Measurements
            </div>
            <div class="measure-grid">
              <div v-for="m in measurements" :key="m.key" class="measure" :class="`measure--${m.tone}`">
                <span class="measure-label">{{ m.label }}</span>
                <span class="measure-value">
                  {{ m.value }}<i v-if="m.unit">{{ m.unit }}</i>
                </span>
                <span v-if="m.hint" class="measure-hint">{{ m.hint }}</span>
              </div>
            </div>
          </div>

          <!-- Sensory -->
          <div class="ad-section">
            <div class="ad-section-title"><v-icon size="13">mdi-eye-check-outline</v-icon> Vision & hearing</div>
            <div class="sensory-grid">
              <div class="sensory-card">
                <div class="sensory-head">Visual acuity</div>
                <div class="sensory-row"><span>Right eye</span><b>{{ eye('right') }}</b></div>
                <div class="sensory-row"><span>Left eye</span><b>{{ eye('left') }}</b></div>
                <div class="sensory-row">
                  <span>Colour vision</span>
                  <b :class="isColourNormal ? 'is-ok' : 'is-warn'">
                    {{ detail.vision?.colour_vision || 'Not tested' }}
                  </b>
                </div>
                <div v-if="jobProfile" class="sensory-foot">
                  Role standard {{ jobProfile.min_vision_right }} / {{ jobProfile.min_vision_left }}
                </div>
              </div>
              <div class="sensory-card">
                <div class="sensory-head">Audiometry</div>
                <div class="sensory-row"><span>Right ear</span><b>{{ db('right_db') }}</b></div>
                <div class="sensory-row"><span>Left ear</span><b>{{ db('left_db') }}</b></div>
                <div class="sensory-row">
                  <span>Pattern</span>
                  <b :class="detail.hearing?.noise_induced ? 'is-err' : 'is-ok'">
                    {{ detail.hearing?.audiogram_shape || 'Not recorded' }}
                  </b>
                </div>
                <div v-if="jobProfile?.max_hearing_loss_db" class="sensory-foot">
                  Role limit ≤ {{ jobProfile.max_hearing_loss_db }} dB
                </div>
              </div>
              <div class="sensory-card">
                <div class="sensory-head">Spirometry</div>
                <div class="sensory-row"><span>FEV1</span><b>{{ lit('fev1_l') }}</b></div>
                <div class="sensory-row"><span>FVC</span><b>{{ lit('fvc_l') }}</b></div>
                <div class="sensory-row">
                  <span>FEV1/FVC</span>
                  <b :class="ratioTone">{{ detail.spirometry?.fev1_fvc_pct ? `${detail.spirometry.fev1_fvc_pct}%` : '—' }}</b>
                </div>
                <div v-if="detail.spirometry?.predicted_pct" class="sensory-foot">
                  {{ detail.spirometry.predicted_pct }}% of predicted
                </div>
              </div>
            </div>
          </div>

          <!-- Baseline comparison -->
          <div class="ad-section">
            <div class="ad-section-title">
              <v-icon size="13">mdi-compare-horizontal</v-icon> Baseline comparison
              <v-spacer />
              <span v-if="comparison && comparison.has_baseline" class="ad-section-extra">
                vs {{ comparison.baseline.reference }} · {{ formatDate(comparison.baseline.examined_on || comparison.baseline.scheduled_on) }}
              </span>
            </div>
            <div v-if="!comparison" class="ad-note">Loading baseline…</div>
            <div v-else-if="!comparison.has_baseline" class="ad-note">
              <v-icon size="14">mdi-information-outline</v-icon>
              No pre-employment baseline found for {{ detail.employee_name }} — drift cannot be measured.
            </div>
            <div v-else>
              <div v-if="driftAlerts.length" class="drift-alert">
                <v-icon size="14">mdi-alert-decagram-outline</v-icon>
                <div>
                  <b>{{ driftAlerts.length }} material change{{ driftAlerts.length === 1 ? '' : 's' }}</b>
                  since the baseline examination
                  <span class="drift-list">{{ driftAlerts.join(' · ') }}</span>
                </div>
              </div>
              <div class="drift-grid">
                <div v-for="d in comparison.deltas" :key="`${d.group}-${d.key}`"
                     class="drift" :class="`drift--${d.direction}`">
                  <span class="drift-label">{{ prettyKey(d.key) }}</span>
                  <div class="drift-values">
                    <span class="drift-then">{{ d.baseline }}</span>
                    <v-icon size="11">mdi-arrow-right</v-icon>
                    <span class="drift-now">{{ d.current }}</span>
                  </div>
                  <span class="drift-delta">
                    {{ d.delta > 0 ? '+' : '' }}{{ d.delta }}<i>{{ d.unit }}</i>
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Findings -->
          <div class="ad-section">
            <div class="ad-section-title">
              <v-icon size="13">mdi-stethoscope</v-icon> Clinical findings
              <v-spacer />
              <v-btn size="x-small" variant="text" class="text-none" prepend-icon="mdi-plus"
                     @click="toggleFindingForm">
                Add
              </v-btn>
            </div>

            <div v-if="findingForm.open" class="inline-form">
              <v-row dense>
                <v-col cols="6">
                  <v-select v-model="findingForm.system" :items="lookups.finding_systems || []"
                            item-title="label" item-value="value" label="System" density="compact"
                            variant="outlined" hide-details />
                </v-col>
                <v-col cols="6">
                  <v-select v-model="findingForm.severity" :items="lookups.finding_severities || []"
                            item-title="label" item-value="value" label="Severity" density="compact"
                            variant="outlined" hide-details />
                </v-col>
                <v-col cols="12">
                  <v-text-field v-model="findingForm.finding" label="Finding" density="compact"
                                variant="outlined" hide-details />
                </v-col>
                <v-col cols="12">
                  <v-text-field v-model="findingForm.recommendation" label="Recommendation (optional)"
                                density="compact" variant="outlined" hide-details />
                </v-col>
                <v-col cols="12" class="d-flex align-center" style="gap:10px">
                  <v-switch v-model="findingForm.work_related" label="Work-related" density="compact"
                            hide-details color="primary" />
                  <v-spacer />
                  <v-btn size="small" variant="text" class="text-none" @click="findingForm.open = false">
                    Cancel
                  </v-btn>
                  <v-btn size="small" color="primary" rounded="lg" class="text-none"
                         :disabled="!findingForm.finding" :loading="savingFinding" @click="saveFinding">
                    Save finding
                  </v-btn>
                </v-col>
              </v-row>
            </div>

            <div v-if="!detail.findings?.length" class="ad-note">
              No findings recorded — a fit outcome with no documented findings is not auditable.
            </div>
            <div v-else class="finding-list">
              <div v-for="f in detail.findings" :key="f.id" class="finding-row"
                   :class="`finding-row--${f.severity}`">
                <span class="finding-dot" />
                <div style="min-width:0;flex:1">
                  <div class="cell-strong">{{ f.finding }}</div>
                  <div class="cell-sub">
                    {{ f.system_display }}
                    <template v-if="f.work_related"> · <span class="flag-ink">work-related</span></template>
                    <template v-if="f.recommendation"> · {{ f.recommendation }}</template>
                  </div>
                </div>
                <span class="ohs-badge" :class="`ohs-badge--${severityTone(f.severity)}`">
                  {{ f.severity_display }}
                </span>
                <v-btn icon="mdi-close" size="x-small" variant="text"
                       @click.stop="removeFinding(f.id)" />
              </div>
            </div>
          </div>

          <!-- Lab results -->
          <div class="ad-section">
            <div class="ad-section-title">
              <v-icon size="13">mdi-test-tube</v-icon> Investigations
              <v-spacer />
              <v-btn size="x-small" variant="text" class="text-none" prepend-icon="mdi-plus"
                     @click="toggleLabForm">
                Add
              </v-btn>
            </div>

            <div v-if="labForm.open" class="inline-form">
              <v-row dense>
                <v-col cols="7">
                  <v-text-field v-model="labForm.analyte" label="Analyte" density="compact"
                                variant="outlined" hide-details />
                </v-col>
                <v-col cols="5">
                  <v-text-field v-model="labForm.value" label="Value" density="compact"
                                variant="outlined" hide-details />
                </v-col>
                <v-col cols="4">
                  <v-text-field v-model="labForm.unit" label="Unit" density="compact"
                                variant="outlined" hide-details />
                </v-col>
                <v-col cols="4">
                  <v-text-field v-model.number="labForm.reference_low" label="Low" type="number"
                                density="compact" variant="outlined" hide-details />
                </v-col>
                <v-col cols="4">
                  <v-text-field v-model.number="labForm.reference_high" label="High" type="number"
                                density="compact" variant="outlined" hide-details />
                </v-col>
                <v-col cols="12" class="d-flex justify-end" style="gap:8px">
                  <v-btn size="small" variant="text" class="text-none" @click="labForm.open = false">
                    Cancel
                  </v-btn>
                  <v-btn size="small" color="primary" rounded="lg" class="text-none"
                         :disabled="!labForm.analyte || !labForm.value" :loading="savingLab"
                         @click="saveLab">
                    Save result
                  </v-btn>
                </v-col>
              </v-row>
            </div>

            <div v-if="!detail.lab_results?.length" class="ad-note">No investigations recorded.</div>
            <table v-else class="mini-table">
              <thead>
                <tr>
                  <th>Analyte</th>
                  <th class="num">Result</th>
                  <th class="num">Reference</th>
                  <th style="width:80px">Flag</th>
                  <th style="width:30px" />
                </tr>
              </thead>
              <tbody>
                <tr v-for="l in detail.lab_results" :key="l.id">
                  <td class="cell-strong">{{ l.analyte }}</td>
                  <td class="num">{{ l.value }} <span class="cell-sub">{{ l.unit }}</span></td>
                  <td class="num cell-sub">{{ l.reference_range || '—' }}</td>
                  <td>
                    <span class="ohs-badge" :class="`ohs-badge--${labTone(l.flag)}`">
                      {{ l.flag_display }}
                    </span>
                  </td>
                  <td>
                    <v-btn icon="mdi-close" size="x-small" variant="text"
                           @click.stop="removeLab(l.id)" />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Job demands -->
          <div v-if="jobProfile" class="ad-section">
            <div class="ad-section-title"><v-icon size="13">mdi-account-hard-hat</v-icon> Role requirements</div>
            <div class="req-grid">
              <div class="req"><span>Physical demand</span><b>{{ jobProfile.physical_demand_display }}</b></div>
              <div class="req"><span>Surveillance</span><b>{{ jobProfile.surveillance_tier_display }}</b></div>
              <div class="req"><span>Vision standard</span>
                <b>{{ jobProfile.min_vision_right }} / {{ jobProfile.min_vision_left }}</b>
              </div>
              <div class="req"><span>Hearing limit</span>
                <b>{{ jobProfile.max_hearing_loss_db ?? '—' }} dB</b>
              </div>
            </div>
            <div v-if="jobProfile.hazard_exposures?.length" class="job-chips mt-2">
              <span class="job-chips-label">Exposures</span>
              <span v-for="e in jobProfile.hazard_exposures" :key="e"
                    class="job-chip is-risk">{{ e }}</span>
            </div>
            <p v-if="jobProfile.inherent_requirements" class="req-note">
              {{ jobProfile.inherent_requirements }}
            </p>
          </div>

          <!-- Exit / handover -->
          <div v-if="detail.kind === 'exit'" class="ad-section">
            <div class="ad-section-title">
              <v-icon size="13">mdi-door-open</v-icon> Exit summary
            </div>
            <div class="req-grid">
              <div class="req"><span>Reason</span><b>{{ detail.exit_reason_display || 'Not recorded' }}</b></div>
              <div class="req"><span>Work-related</span>
                <b :class="detail.work_related ? 'is-err' : 'is-ok'">
                  {{ detail.work_related ? 'Yes' : 'No' }}
                </b>
              </div>
              <div class="req"><span>Compensation</span>
                <b :class="detail.compensation_claim ? 'is-warn' : ''">
                  {{ detail.compensation_claim ? 'Referred' : 'Not referred' }}
                </b>
              </div>
              <div class="req"><span>Examined</span><b>{{ formatDate(detail.examined_on) }}</b></div>
            </div>
            <p v-if="detail.attributable_condition" class="req-note is-alert">
              <v-icon size="13">mdi-alert-decagram-outline</v-icon>
              {{ detail.attributable_condition }}
            </p>
            <p v-if="detail.clearance_notes" class="req-note">{{ detail.clearance_notes }}</p>
          </div>

          <!-- Certificate -->
          <div class="ad-section">
            <div class="ad-section-title"><v-icon size="13">mdi-certificate-outline</v-icon> Fitness certificate</div>
            <div v-if="detail.certificate_no" class="cert-block">
              <div class="cert-row"><span>Certificate</span><b class="ohs-mono">{{ detail.certificate_no }}</b></div>
              <div class="cert-row"><span>Issued</span><b>{{ formatDate(detail.issued_on) }}</b></div>
              <div class="cert-row"><span>Valid until</span>
                <b :class="detail.is_certificate_expired ? 'is-err' : ''">
                  {{ formatDate(detail.valid_until) }}
                </b>
              </div>
              <div class="cert-row"><span>Status</span>
                <b :class="detail.is_certificate_expired ? 'is-err' : 'is-ok'">
                  {{ detail.is_certificate_expired ? 'Expired' : `${detail.days_to_expiry} days remaining` }}
                </b>
              </div>
            </div>
            <div v-else class="ad-note">
              No certificate issued. A completed assessment without a certificate cannot be presented to an inspector.
            </div>
          </div>
        </div>

        <footer class="ad-foot">
          <v-btn v-if="canComplete" variant="tonal" color="success" rounded="lg" class="text-none"
                 prepend-icon="mdi-check-decagram-outline" @click="openComplete">
            Record outcome
          </v-btn>
          <v-btn v-if="canIssue" color="primary" rounded="lg" class="text-none"
                 prepend-icon="mdi-certificate-outline" @click="openCertificate">
            Issue certificate
          </v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="drawer = false">Close</v-btn>
        </footer>
      </div>
    </v-navigation-drawer>

    <!-- ══════════════════ NEW ASSESSMENT ══════════════════ -->
    <v-dialog v-model="createDialog" max-width="680" scrollable>
      <v-card rounded="xl" class="dialog-card">
        <BrandDialogHeader icon="mdi-clipboard-pulse-outline" title="New health assessment"
                           subtitle="Book a pre-employment, periodic or exit medical"
                           @close="createDialog = false" />
        <v-card-text class="pa-5">
          <v-alert v-if="formError" type="error" variant="tonal" density="compact" rounded="lg"
                   class="mb-4">{{ formError }}</v-alert>

          <div class="form-section">Assessment</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.kind" :items="lookups.assessment_kinds || []"
                        item-title="label" item-value="value" label="Assessment kind"
                        density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.scheduled_on" type="date" label="Scheduled for"
                            density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12">
              <v-select v-model="form.job_demand" :items="lookups.job_demands || []"
                        item-title="job_title" item-value="id" label="Job demand profile"
                        density="compact" variant="outlined" clearable
                        hint="Scores the assessment against the role and sets the recall interval"
                        persistent-hint />
            </v-col>
          </v-row>

          <div class="form-section">Candidate / employee</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.employee_name" label="Full name" density="compact"
                            variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.employee_ref" label="Staff number" density="compact"
                            variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.job_title" label="Job title" density="compact"
                            variant="outlined" hint="Auto-filled from the profile" persistent-hint />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" density="compact" variant="outlined" clearable />
            </v-col>
            <v-col cols="6" sm="4">
              <v-text-field v-model="form.date_of_birth" type="date" label="Date of birth"
                            density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="4">
              <v-select v-model="form.gender" :items="['Female', 'Male', 'Other']" label="Gender"
                        density="compact" variant="outlined" clearable />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.national_id" label="National ID" density="compact"
                            variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.examiner_name" label="Examining clinician"
                            density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.provider" label="Provider / clinic" density="compact"
                            variant="outlined" />
            </v-col>
          </v-row>

          <div v-if="form.kind === 'exit'" class="form-section">Exit details</div>
          <v-row v-if="form.kind === 'exit'" dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.exit_reason" :items="lookups.exit_reasons || []"
                        item-title="label" item-value="value" label="Reason for exit"
                        density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.clearance_notes" label="Handover notes"
                            density="compact" variant="outlined" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="assessments.saving.value"
                 :disabled="!form.employee_name" @click="saveAssessment">
            Create assessment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ══════════════════ RECORD OUTCOME ══════════════════ -->
    <v-dialog v-model="completeDialog" max-width="820" scrollable>
      <v-card rounded="xl" class="dialog-card">
        <BrandDialogHeader icon="mdi-stethoscope" title="Record clinical outcome"
                           :subtitle="detail ? `${detail.employee_name} · ${detail.reference}` : ''"
                           @close="completeDialog = false" />
        <v-card-text class="pa-5">
          <v-alert v-if="formError" type="error" variant="tonal" density="compact" rounded="lg"
                   class="mb-4">{{ formError }}</v-alert>

          <div class="form-section">
            Measurements
            <span v-if="bmiPreview" class="form-badge">BMI {{ bmiPreview }}</span>
          </div>
          <v-row dense>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.height_cm" type="number" label="Height"
                            suffix="cm" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.weight_kg" type="number" label="Weight"
                            suffix="kg" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.bp_systolic" type="number" label="BP systolic"
                            suffix="mmHg" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.bp_diastolic" type="number" label="BP diastolic"
                            suffix="mmHg" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.pulse" type="number" label="Pulse" suffix="bpm"
                            density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.resp_rate" type="number" label="Resp. rate"
                            suffix="/min" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.temperature_c" type="number" step="0.1"
                            label="Temperature" suffix="°C" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.spo2" type="number" label="SpO₂" suffix="%"
                            density="compact" variant="outlined" />
            </v-col>
          </v-row>

          <div class="form-section">Vision & hearing</div>
          <v-row dense>
            <v-col cols="6" sm="3">
              <v-text-field v-model="outcome.vision_right_corrected" label="Right (corrected)"
                            placeholder="6/6" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model="outcome.vision_left_corrected" label="Left (corrected)"
                            placeholder="6/6" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model="outcome.colour_vision" label="Colour vision"
                            placeholder="Normal" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model="outcome.audiogram_shape" label="Audiogram pattern"
                            placeholder="Normal" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.hearing_right_db" type="number" label="Right ear"
                            suffix="dB" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.hearing_left_db" type="number" label="Left ear"
                            suffix="dB" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.fev1_l" type="number" step="0.01" label="FEV1"
                            suffix="L" density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model.number="outcome.fvc_l" type="number" step="0.01" label="FVC"
                            suffix="L" density="compact" variant="outlined" />
            </v-col>
          </v-row>

          <div class="form-section">Fitness decision</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="outcome.fitness" :items="lookups.fitness_outcomes || []"
                        item-title="label" item-value="value" label="Outcome" density="compact"
                        variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="outcome.examined_on" type="date" label="Examined on"
                            density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="outcome.restrictions" label="Restrictions to honour on the job"
                          rows="2" density="compact" variant="outlined" hide-details
                          placeholder="e.g. No work at height; hearing protection mandatory; no night shift" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="outcome.recommendations" label="Recommendations / follow-up"
                          rows="2" density="compact" variant="outlined" hide-details />
            </v-col>
          </v-row>

          <div class="form-section">Attribution</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-switch v-model="outcome.work_related" label="Findings attributable to this employment"
                        density="compact" color="primary" hide-details />
            </v-col>
            <v-col cols="12" sm="6">
              <v-switch v-model="outcome.compensation_claim" label="Refer for statutory compensation"
                        density="compact" color="warning" hide-details />
            </v-col>
            <v-col v-if="outcome.work_related" cols="12">
              <v-textarea v-model="outcome.attributable_condition" label="Condition and attribution basis"
                          rows="2" density="compact" variant="outlined" hide-details
                          placeholder="e.g. Bilateral noise-induced hearing loss, 12 dB shift at 4 kHz, ≥8 years in the press shop" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="completeDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingOutcome"
                 @click="saveOutcome">
            Save outcome
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ══════════════════ ISSUE CERTIFICATE ══════════════════ -->
    <v-dialog v-model="certificateDialog" max-width="520">
      <v-card rounded="xl" class="dialog-card">
        <BrandDialogHeader icon="mdi-certificate-outline" title="Issue fitness certificate"
                           :subtitle="detail ? `${detail.employee_name} · ${detail.fitness_display}` : ''"
                           @close="certificateDialog = false" />
        <v-card-text class="pa-5">
          <v-alert v-if="formError" type="error" variant="tonal" density="compact" rounded="lg"
                   class="mb-4">{{ formError }}</v-alert>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="certificateForm.certificate_no" label="Certificate number"
                            density="compact" variant="outlined" placeholder="Auto if blank" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="certificateForm.issued_on" type="date" label="Issued on"
                            density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model.number="certificateForm.valid_months" type="number"
                            label="Validity (months)" density="compact" variant="outlined"
                            :hint="validityHint" persistent-hint />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="certificateDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingCertificate"
                 @click="issueCertificate">
            Issue certificate
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ══════════════════ JOB DEMAND PROFILE ══════════════════ -->
    <v-dialog v-model="jobDialog" max-width="720" scrollable>
      <v-card rounded="xl" class="dialog-card">
        <BrandDialogHeader icon="mdi-account-hard-hat"
                           :title="jobForm.id ? 'Edit job demand profile' : 'New job demand profile'"
                           subtitle="The inherent requirements an assessment is scored against"
                           @close="jobDialog = false" />
        <v-card-text class="pa-5">
          <v-alert v-if="formError" type="error" variant="tonal" density="compact" rounded="lg"
                   class="mb-4">{{ formError }}</v-alert>

          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="jobForm.job_title" label="Job title" density="compact"
                            variant="outlined" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="jobForm.code" label="Code" density="compact"
                            variant="outlined" placeholder="OPS-01" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="jobForm.department" label="Department" density="compact"
                            variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="jobForm.site" :items="siteOptions" item-title="label"
                        item-value="value" label="Site" density="compact" variant="outlined"
                        clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="jobForm.physical_demand" :items="lookups.physical_demands || []"
                        item-title="label" item-value="value" label="Physical demand"
                        density="compact" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="jobForm.surveillance_tier" :items="lookups.surveillance_tiers || []"
                        item-title="label" item-value="value" label="Surveillance interval"
                        density="compact" variant="outlined" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model="jobForm.min_vision_right" label="Min vision R" density="compact"
                            variant="outlined" placeholder="6/12" />
            </v-col>
            <v-col cols="6" sm="3">
              <v-text-field v-model="jobForm.min_vision_left" label="Min vision L" density="compact"
                            variant="outlined" placeholder="6/12" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="jobForm.max_hearing_loss_db" type="number"
                            label="Max hearing loss" suffix="dB" density="compact"
                            variant="outlined" />
            </v-col>

            <v-col cols="12">
              <v-combobox v-model="jobForm.hazard_exposures" label="Hazard exposures" multiple chips
                          closable-chips density="compact" variant="outlined"
                          :hide-no-data="false"
                          hint="Press Enter to add, e.g. noise, respirable dust, organic vapour"
                          persistent-hint />
            </v-col>
            <v-col cols="12" sm="6">
              <v-combobox v-model="jobForm.mandatory_tests" label="Mandatory tests" multiple chips
                          closable-chips density="compact" variant="outlined" :hide-no-data="false"
                          hint="audiometry, spirometry, urinalysis…" persistent-hint />
            </v-col>
            <v-col cols="12" sm="6">
              <v-combobox v-model="jobForm.mandatory_immunisations" label="Immunisations" multiple
                          chips closable-chips density="compact" variant="outlined"
                          :hide-no-data="false" hint="tetanus, hepatitis B…" persistent-hint />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="jobForm.inherent_requirements" label="Inherent requirements"
                          rows="3" density="compact" variant="outlined" hide-details
                          placeholder="e.g. Sustained standing 8h; repeated lifting to 25 kg; ability to climb ladders; clear speech for radio use" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="jobDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingJob"
                 :disabled="!jobForm.job_title" @click="saveJobProfile">
            {{ jobForm.id ? 'Save changes' : 'Create profile' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2800">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { relativeDays, initialsOf, titleCase, exportCsv } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Medical Assessment · OHSMS' })

const { $api } = useNuxtApp()
const ohs = useOhs()

const assessments = ohs.resource('assessments')
const jobDemands = ohs.resource('job-demands')

const lookups = ref({})
const summary = ref({})
const tab = ref('register')
const drawer = ref(false)
const detail = ref(null)
const comparison = ref(null)

const search = ref('')
const kindFilter = ref(null)
const fitnessFilter = ref(null)
const siteFilter = ref(null)
const registerScope = ref('all')

const snack = reactive({ show: false, color: 'success', text: '' })
const formError = ref('')

const createDialog = ref(false)
const completeDialog = ref(false)
const certificateDialog = ref(false)
const jobDialog = ref(false)

const savingOutcome = ref(false)
const savingCertificate = ref(false)
const savingJob = ref(false)
const savingFinding = ref(false)
const savingLab = ref(false)

const today = () => new Date().toISOString().slice(0, 10)

const form = reactive({
  kind: 'pre_employment', scheduled_on: today(), job_demand: null,
  employee_name: '', employee_ref: '', job_title: '', site: null,
  date_of_birth: '', gender: null, national_id: '',
  examiner_name: '', provider: '', exit_reason: null, clearance_notes: '',
})

const outcome = reactive({
  height_cm: null, weight_kg: null, bp_systolic: null, bp_diastolic: null,
  pulse: null, resp_rate: null, temperature_c: null, spo2: null,
  vision_right_corrected: '', vision_left_corrected: '', colour_vision: '',
  hearing_right_db: null, hearing_left_db: null, audiogram_shape: '',
  fev1_l: null, fvc_l: null,
  fitness: 'fit', examined_on: today(), restrictions: '', recommendations: '',
  work_related: false, compensation_claim: false, attributable_condition: '',
})

const certificateForm = reactive({ certificate_no: '', issued_on: today(), valid_months: 12 })

const jobForm = reactive({
  id: null, job_title: '', code: '', department: '', site: null,
  physical_demand: 'light', surveillance_tier: 'annual',
  min_vision_right: '6/12', min_vision_left: '6/12', max_hearing_loss_db: 30,
  hazard_exposures: [], mandatory_tests: [], mandatory_immunisations: [],
  inherent_requirements: '',
})

const findingForm = reactive({
  open: false, system: 'general', severity: 'normal', finding: '', recommendation: '',
  work_related: false,
})

const labForm = reactive({
  open: false, analyte: '', value: '', unit: '',
  reference_low: null, reference_high: null,
})

// ── Options ────────────────────────────────────────────────────────────
const siteOptions = computed(
  () => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })),
)

const filtered = computed(() => {
  let rows = assessments.items.value || []
  if (registerScope.value === 'overdue') rows = rows.filter((r) => r.is_overdue)
  if (registerScope.value === 'expiring') {
    rows = rows.filter((r) => r.days_to_expiry !== null && r.days_to_expiry <= 60)
  }
  if (kindFilter.value) rows = rows.filter((r) => r.kind === kindFilter.value)
  if (fitnessFilter.value) rows = rows.filter((r) => r.fitness === fitnessFilter.value)
  if (siteFilter.value) rows = rows.filter((r) => r.site === siteFilter.value)
  const q = search.value.trim().toLowerCase()
  if (q) {
    rows = rows.filter((r) => `${r.reference} ${r.employee_name} ${r.employee_ref} ` +
      `${r.job_title} ${r.examiner_name} ${r.provider} ${r.site_name}`.toLowerCase().includes(q))
  }
  // A register is read for what was *found*, so examined records lead; future
  // bookings trail behind rather than burying the clinical history.
  return [...rows].sort((a, b) => {
    if (!!a.examined_on !== !!b.examined_on) return a.examined_on ? -1 : 1
    return String(b.examined_on || b.scheduled_on || '')
      .localeCompare(String(a.examined_on || a.scheduled_on || ''))
  })
})

// ── Work queue ─────────────────────────────────────────────────────────
const queueColumns = computed(() => {
  const all = assessments.items.value || []
  const open = all.filter((r) => !['certified', 'cancelled', 'declined'].includes(r.status))
  const overdue = open.filter((r) => r.is_overdue)
  const soon = Date.now() + 7 * 86400000
  const upcoming = open.filter((r) => !r.is_overdue
    && new Date(r.scheduled_on).getTime() <= soon)
  const scheduled = open.filter((r) => !r.is_overdue
    && new Date(r.scheduled_on).getTime() > soon)
  const toCertificate = all.filter((r) => r.status === 'completed' && !r.certificate_no)
  const inProgress = all.filter((r) => r.status === 'in_progress')

  return [
    {
      key: 'overdue', label: 'Overdue', tone: 'err', rows: overdue,
      hint: 'Past their scheduled date with no outcome recorded',
      empty: 'Nothing overdue',
    },
    {
      key: 'inprogress', label: 'In progress', tone: 'info', rows: inProgress,
      hint: 'Under examination right now',
      empty: 'No open examinations',
    },
    {
      key: 'certificate', label: 'Awaiting certificate', tone: 'warn', rows: toCertificate,
      hint: 'Outcome recorded — the employee has no fitness document',
      empty: 'All outcomes documented',
    },
    {
      key: 'upcoming', label: 'Next 7 days', tone: 'primary', rows: upcoming,
      hint: 'Booked for this week',
      empty: 'Nothing booked this week',
    },
    {
      key: 'scheduled', label: 'Scheduled', tone: 'muted', rows: scheduled,
      hint: 'Further out in the diary',
      empty: 'Nothing in the diary',
    },
  ]
})

const queueTotal = computed(() =>
  queueColumns.value
    .filter((c) => ['overdue', 'certificate'].includes(c.key))
    .reduce((s, c) => s + c.rows.length, 0),
)

// ── Drawer derived ─────────────────────────────────────────────────────
const canComplete = computed(() =>
  !!detail.value && ['scheduled', 'in_progress'].includes(detail.value.status),
)
const canIssue = computed(() =>
  !!detail.value && detail.value.status === 'completed' && !detail.value.certificate_no,
)

/** The role profile the assessment is scored against, when one is attached. */
const jobProfile = computed(() => detail.value?.job_demand_detail || null)

const bmiPreview = computed(() => {
  const h = Number(outcome.height_cm) / 100
  const w = Number(outcome.weight_kg)
  if (!h || !w) return null
  return (w / (h * h)).toFixed(1)
})

const validityHint = computed(() => {
  const months = Number(certificateForm.valid_months) || 12
  return `Expires ${new Date(new Date(certificateForm.issued_on || today()).getTime()
    + months * 30 * 86400000).toISOString().slice(0, 10)}`
})

const BMI_BANDS = {
  underweight: { label: 'Underweight', tone: 'warn' },
  normal: { label: 'Normal', tone: 'ok' },
  overweight: { label: 'Overweight', tone: 'warn' },
  obese_1: { label: 'Obese I', tone: 'err' },
  obese_2: { label: 'Obese II', tone: 'err' },
  obese_3: { label: 'Obese III', tone: 'err' },
}

const measurements = computed(() => {
  const d = detail.value
  if (!d) return []
  const v = d.vital_signs || {}
  const bmiBand = BMI_BANDS[d.bmi_band]
  return [
    { key: 'bmi', label: 'BMI', value: d.bmi ?? '—', unit: '',
      tone: bmiBand ? bmiBand.tone : 'muted', hint: bmiBand ? bmiBand.label : 'Not recorded' },
    { key: 'bp', label: 'Blood pressure', value: d.blood_pressure || '—', unit: '',
      tone: bpTone(d.bp_band), hint: bpLabel(d.bp_band) },
    { key: 'pulse', label: 'Pulse', value: v.pulse ?? '—', unit: 'bpm',
      tone: pulseTone(v.pulse), hint: 'Resting' },
    { key: 'spo2', label: 'SpO₂', value: v.spo2 ?? '—', unit: '%',
      tone: spo2Tone(v.spo2), hint: 'Room air' },
    { key: 'temp', label: 'Temperature', value: v.temperature_c ?? '—', unit: '°C',
      tone: 'muted', hint: 'Oral' },
    { key: 'resp', label: 'Resp. rate', value: v.resp_rate ?? '—', unit: '/min',
      tone: 'muted', hint: 'At rest' },
    { key: 'waist', label: 'Waist', value: v.waist_cm ?? '—', unit: 'cm',
      tone: 'muted', hint: 'At umbilicus' },
    { key: 'height', label: 'Height', value: v.height_cm ?? '—', unit: 'cm',
      tone: 'muted', hint: 'Standing' },
  ]
})

const isColourNormal = computed(() => {
  const c = String(detail.value?.vision?.colour_vision || '').toLowerCase()
  return !c || c.includes('normal')
})

const ratioTone = computed(() => {
  const r = Number(detail.value?.spirometry?.fev1_fvc_pct)
  if (!r) return ''
  if (r < 70) return 'is-err'
  if (r < 75) return 'is-warn'
  return 'is-ok'
})

/** Deltas big enough to matter clinically, phrased for a human. */
const driftAlerts = computed(() => {
  const deltas = comparison.value?.deltas || []
  const out = []
  for (const d of deltas) {
    if (d.key === 'left_db' || d.key === 'right_db') {
      if (d.delta >= 10) out.push(`${prettyKey(d.key)} +${d.delta} dB`)
    } else if (d.key === 'bmi') {
      if (Math.abs(d.delta) >= 3) out.push(`BMI ${d.delta > 0 ? '+' : ''}${d.delta}`)
    } else if (d.key === 'weight_kg') {
      if (Math.abs(d.delta) >= 5) out.push(`Weight ${d.delta > 0 ? '+' : ''}${d.delta} kg`)
    } else if (d.key === 'fev1_l') {
      if (d.delta <= -0.3) out.push(`FEV1 ${d.delta} L`)
    } else if (d.key === 'bp_systolic') {
      if (d.delta >= 15) out.push(`Systolic +${d.delta} mmHg`)
    }
  }
  return out
})

// ── Presenters ─────────────────────────────────────────────────────────
function fitnessTone(value) {
  return {
    fit: 'ok',
    fit_with_restrictions: 'warn',
    temporarily_unfit: 'warn',
    unfit: 'err',
    pending: 'muted',
  }[value] || 'muted'
}

function fitnessIcon(value) {
  return {
    fit: 'mdi-check-decagram-outline',
    fit_with_restrictions: 'mdi-account-alert-outline',
    temporarily_unfit: 'mdi-clock-alert-outline',
    unfit: 'mdi-close-octagon-outline',
    pending: 'mdi-progress-clock',
  }[value] || 'mdi-account-question-outline'
}

function kindTone(kind) {
  return {
    pre_employment: 'plan',
    periodic: 'live',
    exit: 'exit',
    return_to_work: 'care',
    transfer: 'move',
  }[kind] || 'plan'
}

function severityTone(severity) {
  return { normal: 'ok', minor: 'info', major: 'warn', critical: 'err' }[severity] || 'muted'
}

function labTone(flag) {
  return { normal: 'ok', low: 'info', high: 'warn', critical: 'err' }[flag] || 'muted'
}

function bpTone(band) {
  return { normal: 'ok', low: 'warn', elevated: 'warn', high: 'err', crisis: 'err' }[band] || 'muted'
}
function bpLabel(band) {
  return {
    normal: 'Normal', low: 'Hypotensive', elevated: 'Elevated',
    high: 'Hypertensive', crisis: 'Crisis',
  }[band] || 'Not recorded'
}

function pulseTone(pulse) {
  const n = Number(pulse)
  if (!n) return 'muted'
  if (n < 50 || n > 100) return 'warn'
  return 'ok'
}

function spo2Tone(v) {
  const n = Number(v)
  if (!n) return 'muted'
  if (n < 92) return 'err'
  if (n < 95) return 'warn'
  return 'ok'
}

function eye(side) {
  const v = detail.value?.vision || {}
  const corrected = v[`${side}_corrected`]
  const unaided = v[`${side}_unaided`]
  if (corrected && unaided) return `${corrected} (${unaided} uncorrected)`
  return corrected || unaided || '—'
}

function db(key) {
  const v = detail.value?.hearing?.[key]
  return v === null || v === undefined || v === '' ? '—' : `${v} dB`
}

function lit(key) {
  const v = detail.value?.spirometry?.[key]
  return v === null || v === undefined || v === '' ? '—' : `${v} L`
}

function prettyKey(key) {
  return KEY_LABELS[key] || titleCase(key)
}

/** Compact kind label for the queue card badge. */
function shortKind(r) {
  return {
    pre_employment: 'Pre',
    periodic: 'Periodic',
    exit: 'Exit',
    return_to_work: 'RTW',
    transfer: 'Transfer',
  }[r?.kind] || '—'
}

function daysLate(r) {
  const d = new Date(r.scheduled_on)
  return Math.max(0, Math.round((Date.now() - d.getTime()) / 86400000))
}

// ── Loading ────────────────────────────────────────────────────────────
async function loadSummary() {
  try {
    const { data } = await $api.get('/ohs/assessment-summary/')
    summary.value = data
  } catch { summary.value = {} }
}

async function load() {
  await Promise.all([
    assessments.list({ ordering: '-scheduled_on', page_size: 500 }),
    jobDemands.list({ ordering: 'job_title', page_size: 300 }),
    loadSummary(),
  ])
  lookups.value = await ohs.loadLookups()
}

// The register payload needs the "short" kind label the queue card shows.
const KEY_LABELS = {
  height_cm: 'Height', weight_kg: 'Weight', bp_systolic: 'Systolic',
  bp_diastolic: 'Diastolic', pulse: 'Pulse', resp_rate: 'Resp. rate',
  temperature_c: 'Temperature', spo2: 'SpO₂', waist_cm: 'Waist',
  left_db: 'Left ear', right_db: 'Right ear',
  fev1_l: 'FEV1', fvc_l: 'FVC', fev1_fvc_pct: 'FEV1/FVC', predicted_pct: 'Predicted',
  bmi: 'BMI',
}

// ── Drawer ─────────────────────────────────────────────────────────────
async function openDetail(row) {
  drawer.value = true
  comparison.value = null
  detail.value = { ...row }
  closeInlineForms()
  try {
    const { data } = await $api.get(`/ohs/assessments/${row.id}/`)
    detail.value = data
  } catch { /* keep the list payload */ }
  loadComparison(row.id)
}

async function refreshDetail(id) {
  try {
    const { data } = await $api.get(`/ohs/assessments/${id}/`)
    detail.value = data
  } catch { /* ignore */ }
  await Promise.all([loadSummary(), load()])
}

async function loadComparison(id) {
  try {
    const { data } = await $api.get(`/ohs/assessments/${id}/baseline_comparison/`)
    comparison.value = data
  } catch {
    comparison.value = { has_baseline: false, deltas: [] }
  }
}

// ── Create ─────────────────────────────────────────────────────────────
function openCreate() {
  formError.value = ''
  Object.assign(form, {
    kind: 'pre_employment', scheduled_on: today(), job_demand: null,
    employee_name: '', employee_ref: '', job_title: '', site: null,
    date_of_birth: '', gender: null, national_id: '',
    examiner_name: '', provider: '', exit_reason: null, clearance_notes: '',
  })
  createDialog.value = true
}

// Picking a job profile pre-fills the role fields so the operator never
// re-types what the register already knows.
watch(() => form.job_demand, (id) => {
  if (!id) return
  const profile = (lookups.value.job_demands || []).find((j) => j.id === id)
  if (!profile) return
  if (!form.job_title) form.job_title = profile.job_title
  if (!form.site && profile.site) form.site = profile.site
})

async function saveAssessment() {
  formError.value = ''
  try {
    const payload = { ...form }
    if (!payload.job_demand) delete payload.job_demand
    if (!payload.site) delete payload.site
    if (!payload.date_of_birth) delete payload.date_of_birth
    if (!payload.gender) delete payload.gender
    if (!payload.exit_reason) delete payload.exit_reason
    await assessments.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Assessment scheduled.' }
    await Promise.all([load(), loadSummary()])
  } catch (e) {
    formError.value = assessments.message(e)
  }
}

// ── Outcome ────────────────────────────────────────────────────────────
function openComplete() {
  formError.value = ''
  const v = detail.value?.vital_signs || {}
  const vis = detail.value?.vision || {}
  const hear = detail.value?.hearing || {}
  const spiro = detail.value?.spirometry || {}
  Object.assign(outcome, {
    height_cm: v.height_cm ?? null, weight_kg: v.weight_kg ?? null,
    bp_systolic: v.bp_systolic ?? null, bp_diastolic: v.bp_diastolic ?? null,
    pulse: v.pulse ?? null, resp_rate: v.resp_rate ?? null,
    temperature_c: v.temperature_c ?? null, spo2: v.spo2 ?? null,
    vision_right_corrected: vis.right_corrected || '',
    vision_left_corrected: vis.left_corrected || '',
    colour_vision: vis.colour_vision || '',
    hearing_right_db: hear.right_db ?? null, hearing_left_db: hear.left_db ?? null,
    audiogram_shape: hear.audiogram_shape || '',
    fev1_l: spiro.fev1_l ?? null, fvc_l: spiro.fvc_l ?? null,
    fitness: detail.value?.fitness === 'pending' ? 'fit' : detail.value?.fitness,
    examined_on: detail.value?.examined_on || today(),
    restrictions: detail.value?.restrictions || '',
    recommendations: detail.value?.recommendations || '',
    work_related: !!detail.value?.work_related,
    compensation_claim: !!detail.value?.compensation_claim,
    attributable_condition: detail.value?.attributable_condition || '',
  })
  completeDialog.value = true
}

async function saveOutcome() {
  formError.value = ''
  savingOutcome.value = true
  try {
    const fev1 = Number(outcome.fev1_l) || null
    const fvc = Number(outcome.fvc_l) || null
    const payload = {
      examined_on: outcome.examined_on,
      fitness: outcome.fitness,
      restrictions: outcome.restrictions,
      recommendations: outcome.recommendations,
      work_related: outcome.work_related,
      compensation_claim: outcome.compensation_claim,
      attributable_condition: outcome.attributable_condition,
      vital_signs: {
        height_cm: outcome.height_cm, weight_kg: outcome.weight_kg,
        bp_systolic: outcome.bp_systolic, bp_diastolic: outcome.bp_diastolic,
        pulse: outcome.pulse, resp_rate: outcome.resp_rate,
        temperature_c: outcome.temperature_c, spo2: outcome.spo2,
        waist_cm: detail.value?.vital_signs?.waist_cm ?? null,
      },
      vision: {
        ...(detail.value?.vision || {}),
        right_corrected: outcome.vision_right_corrected,
        left_corrected: outcome.vision_left_corrected,
        colour_vision: outcome.colour_vision,
      },
      hearing: {
        ...(detail.value?.hearing || {}),
        right_db: outcome.hearing_right_db,
        left_db: outcome.hearing_left_db,
        audiogram_shape: outcome.audiogram_shape,
      },
      spirometry: {
        ...(detail.value?.spirometry || {}),
        fev1_l: fev1, fvc_l: fvc,
        fev1_fvc_pct: fev1 && fvc ? Math.round((fev1 / fvc) * 1000) / 10 : null,
      },
    }
    await $api.patch(`/ohs/assessments/${detail.value.id}/`, payload)
    await $api.post(`/ohs/assessments/${detail.value.id}/complete/`, {
      examined_on: outcome.examined_on,
      fitness: outcome.fitness,
      restrictions: outcome.restrictions,
      recommendations: outcome.recommendations,
      work_related: outcome.work_related,
      compensation_claim: outcome.compensation_claim,
      attributable_condition: outcome.attributable_condition,
    })
    completeDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Outcome recorded.' }
    await refreshDetail(detail.value.id)
  } catch (e) {
    formError.value = assessments.message(e)
  } finally {
    savingOutcome.value = false
  }
}

// ── Certificate ────────────────────────────────────────────────────────
function openCertificate() {
  formError.value = ''
  Object.assign(certificateForm, {
    certificate_no: '', issued_on: today(), valid_months: 12,
  })
  certificateDialog.value = true
}

async function issueCertificate() {
  formError.value = ''
  savingCertificate.value = true
  try {
    await $api.post(`/ohs/assessments/${detail.value.id}/issue-certificate/`, {
      ...certificateForm,
    })
    certificateDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Certificate issued.' }
    await refreshDetail(detail.value.id)
  } catch (e) {
    formError.value = assessments.message(e)
  } finally {
    savingCertificate.value = false
  }
}

// ── Findings & labs ────────────────────────────────────────────────────
function closeInlineForms() {
  findingForm.open = false
  labForm.open = false
}

function toggleFindingForm() {
  findingForm.open = !findingForm.open
  labForm.open = false
  Object.assign(findingForm, {
    open: findingForm.open, system: 'general', severity: 'normal',
    finding: '', recommendation: '', work_related: false,
  })
}

function toggleLabForm() {
  labForm.open = !labForm.open
  findingForm.open = false
  Object.assign(labForm, {
    open: labForm.open, analyte: '', value: '', unit: '',
    reference_low: null, reference_high: null,
  })
}

async function saveFinding() {
  savingFinding.value = true
  try {
    const { data } = await $api.post(
      `/ohs/assessments/${detail.value.id}/add-finding/`,
      { ...findingForm },
    )
    detail.value = data
    findingForm.open = false
    snack.value = { show: true, color: 'success', text: 'Finding recorded.' }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: assessments.message(e) }
  } finally {
    savingFinding.value = false
  }
}

async function removeFinding(id) {
  try {
    const { data } = await $api.delete(
      `/ohs/assessments/${detail.value.id}/findings/${id}/`,
    )
    detail.value = data
  } catch { /* ignore */ }
}

async function saveLab() {
  savingLab.value = true
  try {
    const { data } = await $api.post(
      `/ohs/assessments/${detail.value.id}/add-lab-result/`,
      { ...labForm },
    )
    detail.value = data
    labForm.open = false
    snack.value = { show: true, color: 'success', text: 'Result recorded.' }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: assessments.message(e) }
  } finally {
    savingLab.value = false
  }
}

async function removeLab(id) {
  try {
    const { data } = await $api.delete(
      `/ohs/assessments/${detail.value.id}/lab-results/${id}/`,
    )
    detail.value = data
  } catch { /* ignore */ }
}

// ── Job demand profiles ────────────────────────────────────────────────
function openJobProfile(existing = null) {
  formError.value = ''
  Object.assign(jobForm, {
    id: existing?.id || null,
    job_title: existing?.job_title || '',
    code: existing?.code || '',
    department: existing?.department || '',
    site: existing?.site || null,
    physical_demand: existing?.physical_demand || 'light',
    surveillance_tier: existing?.surveillance_tier || 'annual',
    min_vision_right: existing?.min_vision_right || '6/12',
    min_vision_left: existing?.min_vision_left || '6/12',
    max_hearing_loss_db: existing?.max_hearing_loss_db ?? 30,
    hazard_exposures: [...(existing?.hazard_exposures || [])],
    mandatory_tests: [...(existing?.mandatory_tests || [])],
    mandatory_immunisations: [...(existing?.mandatory_immunisations || [])],
    inherent_requirements: existing?.inherent_requirements || '',
  })
  jobDialog.value = true
}

async function saveJobProfile() {
  formError.value = ''
  savingJob.value = true
  try {
    const payload = { ...jobForm }
    const id = payload.id
    delete payload.id
    if (!payload.site) delete payload.site
    if (id) await jobDemands.update(id, payload)
    else await jobDemands.create(payload)
    jobDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Job demand profile saved.' }
    await Promise.all([jobDemands.list({ ordering: 'job_title', page_size: 300 }), loadSummary()])
    lookups.value = await ohs.loadLookups(true)
  } catch (e) {
    formError.value = jobDemands.message(e)
  } finally {
    savingJob.value = false
  }
}

// ── Export ─────────────────────────────────────────────────────────────
function exportRegister() {
  exportCsv(`health_assessments_${today()}.csv`, filtered.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'employee_name', label: 'Employee' },
    { key: 'employee_ref', label: 'Staff no.' },
    { key: 'kind_display', label: 'Kind' },
    { key: 'job_title', label: 'Job title' },
    { key: 'site_name', label: 'Site' },
    { key: 'scheduled_on', label: 'Scheduled' },
    { key: 'examined_on', label: 'Examined' },
    { key: 'bmi', label: 'BMI' },
    { key: 'blood_pressure', label: 'BP' },
    { key: 'fitness_display', label: 'Fitness' },
    { key: 'restrictions', label: 'Restrictions' },
    { key: 'certificate_no', label: 'Certificate' },
    { key: 'valid_until', label: 'Valid until' },
    { key: 'work_related', label: 'Work-related' },
    { key: 'status_display', label: 'Status' },
  ])
}

watch(tab, () => { formError.value = '' })
onMounted(load)
</script>

<style scoped>
/* ══ Tab counter ══ */
.tab-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 17px;
  margin-left: 6px;
  padding: 0 5px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  background: rgba(var(--v-theme-on-surface), 0.08);
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.tab-count.is-alert { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }

/* ══ Register table ══ */
.row-num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 21px;
  height: 19px;
  padding: 0 5px;
  border-radius: 6px;
  font-size: 10px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  background: rgba(var(--v-theme-on-surface), 0.045);
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.assess-table tr:hover .row-num {
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}
.ref-cell { font-size: 11px; font-weight: 700; letter-spacing: 0.2px; }
.cell-strong {
  font-size: 12.5px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.88);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cell-sub {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.muted-dash { color: rgba(var(--v-theme-on-surface), 0.28); }
.flag-ink { color: #b45309; font-weight: 700; }
.row-chevron { color: rgba(var(--v-theme-on-surface), 0.26); }
.clickable { cursor: pointer; }

.mini-avatar {
  display: inline-grid;
  place-items: center;
  width: 26px;
  height: 26px;
  flex: 0 0 auto;
  border-radius: 8px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.3px;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.11);
}

/* ══ Kind chips ══ */
.kind-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  white-space: nowrap;
  border: 1px solid transparent;
}
.kind-chip--plan { color: #0369a1; background: rgba(14, 165, 233, 0.1); border-color: rgba(14, 165, 233, 0.24); }
.kind-chip--live { color: #15803d; background: rgba(34, 197, 94, 0.11); border-color: rgba(34, 197, 94, 0.24); }
.kind-chip--exit { color: #b91c1c; background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.24); }
.kind-chip--care { color: #7e22ce; background: rgba(168, 85, 247, 0.1); border-color: rgba(168, 85, 247, 0.24); }
.kind-chip--move { color: #b45309; background: rgba(245, 158, 11, 0.12); border-color: rgba(245, 158, 11, 0.26); }

/* ══ BMI / BP cells ══ */
.bmi-cell, .bp-cell {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 6px;
  font-size: 11.5px;
  font-weight: 750;
  font-variant-numeric: tabular-nums;
}
.bmi-cell--normal { color: #15803d; background: rgba(34, 197, 94, 0.12); }
.bmi-cell--underweight, .bmi-cell--overweight { color: #b45309; background: rgba(245, 158, 11, 0.12); }
.bmi-cell--obese_1, .bmi-cell--obese_2, .bmi-cell--obese_3 {
  color: #b91c1c; background: rgba(239, 68, 68, 0.12);
}
.bp-cell--normal { color: #15803d; background: rgba(34, 197, 94, 0.12); }
.bp-cell--low, .bp-cell--elevated { color: #b45309; background: rgba(245, 158, 11, 0.12); }
.bp-cell--high, .bp-cell--crisis { color: #b91c1c; background: rgba(239, 68, 68, 0.12); }

.cert-chip {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 10.5px;
  font-weight: 700;
  color: #15803d;
  white-space: nowrap;
}

/* ══ Work queue ══ */
.queue-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(232px, 1fr));
  gap: 12px;
  align-items: start;
}
.queue-col {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  border-radius: 15px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.018);
}
.queue-head {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.queue-dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }
.queue-head--err { color: #b91c1c; }
.queue-head--warn { color: #b45309; }
.queue-head--info { color: #0369a1; }
.queue-head--primary { color: rgb(var(--v-theme-primary)); }
.queue-count {
  margin-left: auto;
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.queue-hint {
  margin: -4px 0 2px;
  font-size: 10.5px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.queue-empty {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 12px 10px;
  border-radius: 10px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.queue-card {
  padding: 10px 11px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-left: 3px solid rgba(var(--v-theme-on-surface), 0.18);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease;
}
.queue-card:hover { transform: translateY(-1px); box-shadow: 0 8px 20px -16px rgba(2, 6, 23, 0.5); }
.queue-card--err { border-left-color: #dc2626; }
.queue-card--warn { border-left-color: #f59e0b; }
.queue-card--info { border-left-color: #0ea5e9; }
.queue-card--primary { border-left-color: rgb(var(--v-theme-primary)); }
.queue-card-top { display: flex; align-items: center; gap: 8px; }
.queue-card-foot {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
  padding-top: 7px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.08);
}
.queue-meta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 10px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.queue-meta.is-late { margin-left: auto; color: #b91c1c; }
.queue-meta.is-warn { margin-left: auto; color: #b45309; }

/* ══ Job demand cards ══ */
.job-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
  gap: 12px;
}
.job-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border-radius: 15px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgb(var(--v-theme-surface));
  transition: box-shadow 0.18s ease, transform 0.18s ease;
}
.job-card:hover { transform: translateY(-1px); box-shadow: 0 12px 26px -22px rgba(2, 6, 23, 0.5); }
.job-card-top { display: flex; align-items: center; gap: 9px; }
.job-glyph {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  border-radius: 10px;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
}
.job-facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  padding: 9px 0;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.job-fact { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.job-fact span {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.job-fact b {
  font-size: 12px;
  font-weight: 750;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.demand-sedentary, .demand-light { color: #15803d; }
.demand-medium { color: #b45309; }
.demand-heavy, .demand-very_heavy { color: #b91c1c; }

.job-chips { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; }
.job-chips-label {
  margin-right: 3px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.38);
}
.job-chip {
  padding: 2px 7px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 650;
  background: rgba(var(--v-theme-on-surface), 0.06);
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.job-chip.is-risk { background: rgba(239, 68, 68, 0.1); color: #b91c1c; }
.job-chip.is-ok { background: rgba(34, 197, 94, 0.11); color: #15803d; }

.job-standards {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  font-size: 10.5px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.48);
}
.job-standards span { display: inline-flex; align-items: center; gap: 4px; }

/* ══ Drawer ══ */
.assess-drawer { display: flex; flex-direction: column; height: 100%; min-height: 0; }

.ad-head {
  position: relative;
  overflow: hidden;
  flex: 0 0 auto;
  padding: 16px 16px 14px;
  color: #fff;
  background: var(--brand-gradient);
}
.ad-glow {
  position: absolute;
  top: -70px;
  right: -50px;
  width: 220px;
  height: 220px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.14);
  filter: blur(38px);
  pointer-events: none;
}
.ad-head-row {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}
.ad-ref {
  font-family: ui-monospace, monospace;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.4px;
  color: rgba(255, 255, 255, 0.82);
}
.ad-name { font-size: 1.12rem; font-weight: 800; letter-spacing: -0.4px; line-height: 1.25; }
.ad-role { font-size: 11.5px; color: rgba(255, 255, 255, 0.78); }
.ad-close { color: #fff !important; }
.ad-chips { position: relative; z-index: 1; display: flex; flex-wrap: wrap; gap: 5px; margin-top: 9px; }
.glass-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: #fff;
}
.glass-chip.is-alert { background: rgba(255, 255, 255, 0.92); color: #b91c1c; border-color: #fff; }

.ad-verdict {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 12px;
  padding: 10px 12px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.26);
  backdrop-filter: blur(6px);
}
.ad-verdict-label { font-size: 13px; font-weight: 800; letter-spacing: -0.2px; }
.ad-verdict-sub {
  font-size: 11px;
  line-height: 1.35;
  color: rgba(255, 255, 255, 0.82);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.ad-body { flex: 1 1 auto; min-height: 0; overflow: auto; padding: 14px 16px 6px; }

.ad-section { margin-bottom: 18px; }
.ad-section-title {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 8px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.ad-section-extra {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0;
  text-transform: none;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.ad-note {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 10px 11px;
  border-radius: 10px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.14);
  font-size: 11px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.48);
}

/* Measurements */
.measure-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(96px, 1fr));
  gap: 7px;
}
.measure {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 8px 10px;
  border-radius: 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-top: 2px solid rgba(var(--v-theme-on-surface), 0.14);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.measure--ok { border-top-color: #22c55e; }
.measure--warn { border-top-color: #f59e0b; }
.measure--err { border-top-color: #ef4444; }
.measure-label {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.measure-value {
  font-size: 15px;
  font-weight: 800;
  letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.9);
}
.measure-value i {
  margin-left: 2px;
  font-style: normal;
  font-size: 9px;
  font-weight: 700;
  opacity: 0.5;
}
.measure-hint { font-size: 9.5px; font-weight: 650; color: rgba(var(--v-theme-on-surface), 0.42); }

/* Sensory */
.sensory-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 8px;
}
.sensory-card {
  padding: 9px 11px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.sensory-head {
  margin-bottom: 5px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.sensory-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  padding: 2px 0;
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.sensory-row b {
  font-size: 11.5px;
  font-weight: 750;
  color: rgba(var(--v-theme-on-surface), 0.88);
  font-variant-numeric: tabular-nums;
}
.sensory-row b.is-ok { color: #15803d; }
.sensory-row b.is-warn { color: #b45309; }
.sensory-row b.is-err { color: #b91c1c; }
.sensory-foot {
  margin-top: 4px;
  padding-top: 4px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.08);
  font-size: 9.5px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

/* Baseline drift */
.drift-alert {
  display: flex;
  align-items: flex-start;
  gap: 7px;
  margin-bottom: 8px;
  padding: 9px 11px;
  border-radius: 10px;
  font-size: 11px;
  line-height: 1.4;
  background: rgba(245, 158, 11, 0.1);
  border: 1px solid rgba(245, 158, 11, 0.28);
  color: #92400e;
}
.drift-list { display: block; margin-top: 2px; font-weight: 700; }
.drift-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 6px;
}
.drift {
  padding: 7px 9px;
  border-radius: 9px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.drift-label {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.drift-values {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.drift-now { color: rgba(var(--v-theme-on-surface), 0.92); font-weight: 800; }
.drift-delta {
  display: inline-block;
  margin-top: 2px;
  font-size: 10px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.drift-delta i { font-style: normal; opacity: 0.6; margin-left: 1px; }
.drift--up .drift-delta { color: #b45309; }
.drift--down .drift-delta { color: #0369a1; }

/* Findings */
.inline-form {
  margin-bottom: 10px;
  padding: 10px 11px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-primary), 0.28);
  background: rgba(var(--v-theme-primary), 0.04);
}
.finding-list { display: flex; flex-direction: column; gap: 5px; }
.finding-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.finding-dot { width: 6px; height: 6px; flex: 0 0 auto; border-radius: 50%; background: #22c55e; }
.finding-row--minor .finding-dot { background: #0ea5e9; }
.finding-row--major .finding-dot { background: #f59e0b; }
.finding-row--critical .finding-dot { background: #ef4444; }

/* Mini table */
.mini-table { width: 100%; border-collapse: collapse; }
.mini-table th {
  padding: 4px 6px;
  text-align: left;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.42);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.mini-table td {
  padding: 5px 6px;
  font-size: 11.5px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.mini-table .num { text-align: right; font-variant-numeric: tabular-nums; }

/* Role requirements */
.req-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 7px;
}
.req {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 7px 9px;
  border-radius: 9px;
  background: rgba(var(--v-theme-on-surface), 0.025);
}
.req span {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.req b { font-size: 11.5px; font-weight: 750; }
.req b.is-ok { color: #15803d; }
.req b.is-warn { color: #b45309; }
.req b.is-err { color: #b91c1c; }
.req-note {
  display: flex;
  align-items: flex-start;
  gap: 5px;
  margin: 8px 0 0;
  font-size: 11px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.req-note.is-alert { color: #b45309; font-weight: 650; }

/* Certificate */
.cert-block {
  padding: 10px 12px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: linear-gradient(135deg,
    rgba(var(--v-theme-primary), 0.06),
    rgba(var(--v-theme-on-surface), 0.015));
}
.cert-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  padding: 3px 0;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.cert-row b { font-weight: 750; color: rgba(var(--v-theme-on-surface), 0.88); }
.cert-row b.is-ok { color: #15803d; }
.cert-row b.is-err { color: #b91c1c; }

.ad-foot {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 0 0 auto;
  padding: 10px 16px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

/* ══ Dialogs ══ */
.dialog-card { overflow: hidden; }
.form-section {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 14px 0 8px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.48);
}
.form-section:first-child { margin-top: 0; }
.form-badge {
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 9.5px;
  letter-spacing: 0;
  text-transform: none;
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}

@media (max-width: 960px) {
  .queue-grid { grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); }
}

/* ══ Dark mode ══
   The tint palette below is authored for light surfaces, so the ink colours
   go unreadable once the surface flips. Only the text is re-lit — the tinted
   backgrounds already sit at the right luminosity on dark. */
.v-theme--dark .kind-chip--plan { color: #7dd3fc; }
.v-theme--dark .kind-chip--live { color: #86efac; }
.v-theme--dark .kind-chip--exit { color: #fca5a5; }
.v-theme--dark .kind-chip--care { color: #d8b4fe; }
.v-theme--dark .kind-chip--move { color: #fcd34d; }

.v-theme--dark .bmi-cell--normal,
.v-theme--dark .bp-cell--normal { color: #86efac; }
.v-theme--dark .bmi-cell--underweight,
.v-theme--dark .bmi-cell--overweight,
.v-theme--dark .bp-cell--low,
.v-theme--dark .bp-cell--elevated { color: #fcd34d; }
.v-theme--dark .bmi-cell--obese_1,
.v-theme--dark .bmi-cell--obese_2,
.v-theme--dark .bmi-cell--obese_3,
.v-theme--dark .bp-cell--high,
.v-theme--dark .bp-cell--crisis { color: #fca5a5; }

.v-theme--dark .cert-chip { color: #86efac; }
.v-theme--dark .flag-ink { color: #fcd34d; }
.v-theme--dark .tab-count.is-alert { color: #fca5a5; }

.v-theme--dark .queue-head--err { color: #fca5a5; }
.v-theme--dark .queue-head--warn { color: #fcd34d; }
.v-theme--dark .queue-head--info { color: #7dd3fc; }
.v-theme--dark .queue-meta.is-late { color: #fca5a5; }
.v-theme--dark .queue-meta.is-warn { color: #fcd34d; }

.v-theme--dark .demand-sedentary,
.v-theme--dark .demand-light { color: #86efac; }
.v-theme--dark .demand-medium { color: #fcd34d; }
.v-theme--dark .demand-heavy,
.v-theme--dark .demand-very_heavy { color: #fca5a5; }

.v-theme--dark .job-chip.is-risk { color: #fca5a5; }
.v-theme--dark .job-chip.is-ok { color: #86efac; }

.v-theme--dark .sensory-row b.is-ok,
.v-theme--dark .req b.is-ok,
.v-theme--dark .cert-row b.is-ok,
.v-theme--dark .is-ok { color: #86efac; }
.v-theme--dark .sensory-row b.is-warn,
.v-theme--dark .req b.is-warn,
.v-theme--dark .is-warn { color: #fcd34d; }
.v-theme--dark .sensory-row b.is-err,
.v-theme--dark .req b.is-err,
.v-theme--dark .cert-row b.is-err,
.v-theme--dark .is-err { color: #fca5a5; }

.v-theme--dark .drift-alert {
  background: rgba(245, 158, 11, 0.16);
  color: #fcd34d;
}
.v-theme--dark .drift--up .drift-delta { color: #fcd34d; }
.v-theme--dark .drift--down .drift-delta { color: #7dd3fc; }
.v-theme--dark .req-note.is-alert { color: #fcd34d; }

.v-theme--dark .row-num { color: rgba(241, 245, 249, 0.5); }
</style>
