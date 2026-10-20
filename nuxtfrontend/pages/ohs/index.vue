<template>
  <div class="ohs-page">
    <!-- ═══════════════ HERO ═══════════════ -->
    <OhsHero
      icon="mdi-shield-check-outline"
      eyebrow="OHSMS · ISO 45001 Safety Command Centre"
      title="Safety Command Centre"
      :subtitle="heroSubtitle"
    >
      <template #actions>
        <v-btn
          class="ohs-btn-glass text-none"
          rounded="lg"
          size="small"
          prepend-icon="mdi-magnify"
          @click="openPalette"
        >Search</v-btn>
        <v-btn
          class="ohs-btn-glass text-none"
          rounded="lg"
          size="small"
          prepend-icon="mdi-chart-timeline-variant-shimmer"
          to="/ohs/intelligence"
        >Intelligence</v-btn>
        <v-btn
          class="ohs-btn-glass text-none"
          rounded="lg"
          size="small"
          prepend-icon="mdi-download"
          @click="exportSnapshot"
        >Snapshot</v-btn>
        <v-btn
          class="ohs-btn-strong text-none"
          rounded="lg"
          size="small"
          prepend-icon="mdi-alert-plus"
          to="/ohs/incidents"
        >Report incident</v-btn>
      </template>

      <span class="ohs-chip"><v-icon size="12">mdi-office-building</v-icon>
        <b>{{ sites.total }}</b> sites</span>
      <span class="ohs-chip"><v-icon size="12">mdi-account-group</v-icon>
        <b>{{ fmt(sites.headcount) }}</b> workers</span>
      <span class="ohs-chip"><v-icon size="12">mdi-clock-outline</v-icon>
        <b>{{ fmt(sites.hours_worked) }}</b> h/yr</span>
      <span class="ohs-chip"><v-icon size="12">mdi-calendar-range</v-icon>
        Last {{ periodDays }} days</span>
      <span v-if="kpis.high_risk_hazards" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ kpis.high_risk_hazards }}</b> high-risk hazards</span>
      <span v-if="kpis.overdue_actions" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-clock-alert</v-icon>
        <b>{{ kpis.overdue_actions }}</b> overdue CAPA</span>
      <span v-if="alertCount" class="ohs-chip ohs-chip-warn" role="button" @click="gotoAlerts">
        <v-icon size="12">mdi-bell-alert</v-icon>
        <b>{{ alertCount }}</b> open alerts</span>
    </OhsHero>

    <!-- ═══════════════ PREVIEW / UNDER-DEVELOPMENT DIALOG ═══════════════ -->
    <v-dialog v-model="noticeDialog" max-width="580" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-hammer-wrench"
          title="Preview build"
          subtitle="Some OHSMS modules are still under active development."
          close-label="Dismiss this notice"
        />

        <v-card-text class="pt-4 pb-0">
          <div v-for="row in noticeRows" :key="row.title" class="pv-row">
            <span class="pv-icon" :class="`pv-icon--${row.tone}`">
              <v-icon size="16">{{ row.icon }}</v-icon>
            </span>
            <div class="pv-copy">
              <div class="pv-title">{{ row.title }}</div>
              <p class="pv-text">{{ row.text }}</p>
            </div>
          </div>

          <div class="pv-tags">
            <span class="pv-tag">Preview build</span>
            <span class="pv-tag">ISO 45001 rollout in progress</span>
          </div>
        </v-card-text>

        <v-card-actions class="px-4 pb-4 pt-1">
          <span class="pv-hint">Dismissing hides this notice for good.</span>
          <v-spacer />
          <v-btn
            class="dn-dismiss text-none"
            rounded="lg"
            size="small"
            variant="flat"
            prepend-icon="mdi-close"
            @click="dismissNotice"
          >Dismiss</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ COMMAND STRIP ═══════════════ -->
    <div class="cmd-strip mb-3">
      <button class="cmd-tile" @click="openPalette">
        <v-icon size="17">mdi-magnify</v-icon>
        <span class="cmd-label">Command palette</span>
        <span class="cmd-kbd">⌘K</span>
      </button>
      <button class="cmd-tile" @click="goto('/ohs/intelligence')">
        <v-icon size="17">mdi-chart-timeline-variant-shimmer</v-icon>
        <span class="cmd-label">Safety intelligence</span>
        <span class="cmd-meta">maturity {{ maturityScore }}</span>
      </button>
      <button class="cmd-tile" @click="goto('/ohs/alerts')">
        <v-icon size="17">mdi-bell-alert</v-icon>
        <span class="cmd-label">Alert centre</span>
        <span class="cmd-meta" :class="{ 'cmd-meta--warn': alertCount }">{{ alertCount }} open</span>
      </button>
      <button class="cmd-tile" @click="goto('/ohs/documents')">
        <v-icon size="17">mdi-file-document-multiple-outline</v-icon>
        <span class="cmd-label">Document control</span>
        <span class="cmd-meta">{{ docCount }} controlled</span>
      </button>
      <button class="cmd-tile" @click="goto('/ohs/contractors')">
        <v-icon size="17">mdi-account-hard-hat</v-icon>
        <span class="cmd-label">Contractors</span>
        <span class="cmd-meta">{{ contractorCount }} registered</span>
      </button>
      <button class="cmd-tile" @click="goto('/ohs/equipment')">
        <v-icon size="17">mdi-fire-extinguisher</v-icon>
        <span class="cmd-label">Safety equipment</span>
        <span class="cmd-meta" :class="{ 'cmd-meta--warn': equipmentOverdue }">
          {{ equipmentDue }} due · {{ equipmentOverdue }} overdue
        </span>
      </button>
      <button class="cmd-tile" @click="goto('/ohs/certifications')">
        <v-icon size="17">mdi-certificate-outline</v-icon>
        <span class="cmd-label">Certifications</span>
        <span class="cmd-meta" :class="{ 'cmd-meta--warn': certExpiring }">{{ certExpiring }} expiring</span>
      </button>
    </div>

    <!-- ═══════════════ KPI GRID ═══════════════ -->
    <div class="ohs-kpi-grid mb-3">
      <OhsKpi
        label="TRIR"
        :value="num(kpis.trir)"
        icon="mdi-chart-timeline-variant"
        :tone="kpis.trir > 1.5 ? 'err' : kpis.trir > 0.8 ? 'warn' : 'ok'"
        :sub="`${kpis.recordable || 0} recordable · per 200k h`"
      />
      <OhsKpi
        label="LTIFR"
        :value="num(kpis.ltifr)"
        icon="mdi-ambulance"
        :tone="kpis.ltifr > 2 ? 'err' : kpis.ltifr > 0.8 ? 'warn' : 'ok'"
        :sub="`${kpis.lost_time_injuries || 0} LTI · per 1M h`"
      />
      <OhsKpi
        label="Open hazards"
        :value="kpis.open_hazards || 0"
        icon="mdi-alert-outline"
        :tone="kpis.high_risk_hazards ? 'err' : 'warn'"
        :sub="`${kpis.high_risk_hazards || 0} high / critical`"
      />
      <OhsKpi
        label="Overdue controls"
        :value="kpis.overdue_controls || 0"
        icon="mdi-shield-alert-outline"
        :tone="kpis.overdue_controls ? 'err' : 'ok'"
        sub="past their due date"
      />
      <OhsKpi
        label="Lost days"
        :value="kpis.lost_days || 0"
        icon="mdi-calendar-remove"
        tone="warn"
        :sub="`severity rate ${severityRate}`"
      />
      <OhsKpi
        label="Training currency"
        :value="`${num(kpis.training_compliance_pct)}%`"
        icon="mdi-school-outline"
        :tone="kpis.training_compliance_pct >= 90 ? 'ok' : kpis.training_compliance_pct >= 70 ? 'warn' : 'err'"
        :sub="`${kpis.training_expiring || 0} expiring in 60d`"
      />
      <OhsKpi
        label="Inspection score"
        :value="`${num(kpis.inspection_score)}%`"
        icon="mdi-clipboard-check-outline"
        :tone="kpis.inspection_score >= 85 ? 'ok' : kpis.inspection_score >= 70 ? 'warn' : 'err'"
        :sub="`${kpis.inspections_due || 0} inspections due`"
      />
      <OhsKpi
        label="Legal compliance"
        :value="`${num(kpis.legal_compliance_pct)}%`"
        icon="mdi-gavel"
        :tone="kpis.legal_non_compliant ? 'warn' : 'ok'"
        :sub="`${kpis.legal_non_compliant || 0} non-compliant`"
      />
      <OhsKpi
        label="Active permits"
        :value="kpis.permits_active || 0"
        icon="mdi-file-document-check-outline"
        :tone="kpis.permits_expiring ? 'warn' : 'info'"
        :sub="`${kpis.permits_expiring || 0} expiring in 24h`"
      />
      <OhsKpi
        label="Health surveillance"
        :value="kpis.health_surveillance_due || 0"
        icon="mdi-heart-pulse"
        :tone="kpis.health_surveillance_due ? 'warn' : 'ok'"
        sub="overdue medicals"
      />
      <OhsKpi
        label="Open CAPA"
        :value="kpis.open_actions || 0"
        icon="mdi-source-branch-check"
        :tone="kpis.overdue_actions ? 'err' : 'info'"
        :sub="`${kpis.overdue_actions || 0} overdue`"
      />
      <OhsKpi
        label="Safe behaviour"
        :value="`${num(kpis.safe_ratio)}%`"
        icon="mdi-account-check-outline"
        :tone="kpis.safe_ratio >= 70 ? 'ok' : 'warn'"
        :sub="`${kpis.observations_period || 0} observations`"
      />
    </div>

    <v-row dense class="mb-0">
      <!-- ═══════════════ RISK MATRIX ═══════════════ -->
      <v-col cols="12" lg="5">
        <OhsPanel title="Risk heat map" subtitle="Severity × likelihood across the live register" icon="mdi-grid">
          <template #actions>
            <v-chip size="x-small" variant="tonal" color="primary" class="font-weight-bold">
              {{ riskTotal }} assessed
            </v-chip>
          </template>

          <div class="d-flex" style="gap:8px">
            <div class="d-flex align-center justify-center flex-column" style="width:16px">
              <span class="matrix-axis-vert">Likelihood →</span>
            </div>
            <div class="flex-grow-1">
              <div class="ohs-matrix">
                <template v-for="row in 5" :key="`r${row}`">
                  <span class="ohs-matrix-axis">{{ 6 - row }}</span>
                  <span
                    v-for="col in 5"
                    :key="`c${row}-${col}`"
                    class="ohs-matrix-cell"
                    :class="`ohs-matrix-cell--${cellStep(6 - row, col)}`"
                    :title="`Severity ${col} × Likelihood ${6 - row} = ${(6 - row) * col} · ${matrixCell(row, col)} hazard(s)`"
                  >
                    {{ matrixCell(row, col) || '·' }}
                  </span>
                </template>
                <span />
                <span v-for="col in 5" :key="`x${col}`" class="ohs-matrix-axis">{{ col }}</span>
              </div>
              <div class="text-center mt-1 matrix-axis-horiz">Severity →</div>
            </div>
          </div>

          <div class="d-flex flex-wrap mt-3" style="gap:6px">
            <span
              v-for="lvl in levelKeys"
              :key="lvl"
              class="ohs-badge"
              :class="`ohs-badge--${RISK_BANDS[lvl].tone}`"
            >
              {{ RISK_BANDS[lvl].label }} · {{ riskByLevel[lvl] || 0 }}
            </span>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ INCIDENT TREND ═══════════════ -->
      <v-col cols="12" lg="7">
        <OhsPanel title="Incident trend" subtitle="Rolling 12 months · all incident types" icon="mdi-chart-timeline-variant-shimmer">
          <template #actions>
            <v-chip size="x-small" variant="tonal" color="primary">
              {{ trendTotals.total }} total
            </v-chip>
            <v-chip size="x-small" variant="tonal" color="error">
              {{ trendTotals.lti }} LTI
            </v-chip>
            <v-chip size="x-small" variant="tonal" color="info">
              {{ trendTotals.near }} near miss
            </v-chip>
          </template>

          <SparkArea
            :values="trendValues"
            :labels="trendLabels"
            :height="176"
            :color="brand.primary.value"
            :show-y-axis="true"
          />

          <div class="d-flex flex-wrap mt-2" style="gap:14px">
            <div class="d-flex align-center" style="gap:6px">
              <span class="dot" :style="{ background: brand.primary.value }" />
              <span class="text-caption text-medium-emphasis">Total incidents</span>
            </div>
            <div class="d-flex align-center" style="gap:6px">
              <span class="dot" style="background: #ef4444" />
              <span class="text-caption text-medium-emphasis">Lost-time injuries</span>
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ SITE SCORECARD ═══════════════ -->
      <v-col cols="12" lg="5">
        <OhsPanel title="Site safety scorecard" subtitle="Ranked by composite safety score" icon="mdi-office-building-outline" flush>
          <div class="ohs-scroll" style="max-height:330px">
            <div v-for="s in scorecard" :key="s.id" class="site-row">
              <div class="site-score" :class="scoreTone(s.score)">{{ s.score }}</div>
              <div class="flex-grow-1" style="min-width:0">
                <div class="d-flex align-center justify-space-between" style="gap:8px">
                  <span class="text-body-2 font-weight-bold text-truncate">{{ s.name }}</span>
                  <span class="text-caption text-medium-emphasis">{{ s.headcount }} staff</span>
                </div>
                <div class="d-flex flex-wrap mt-1" style="gap:5px">
                  <span v-if="s.open_hazards" class="mini-chip">{{ s.open_hazards }} hazards</span>
                  <span v-if="s.high_risk" class="mini-chip mini-chip--err">{{ s.high_risk }} high</span>
                  <span v-if="s.open_incidents" class="mini-chip mini-chip--warn">{{ s.open_incidents }} incidents</span>
                  <span v-if="s.overdue_controls" class="mini-chip mini-chip--warn">{{ s.overdue_controls }} overdue</span>
                  <span v-if="s.active_permits" class="mini-chip mini-chip--info">{{ s.active_permits }} permits</span>
                  <span class="mini-chip">{{ num(s.training_pct) }}% trained</span>
                </div>
                <div class="ohs-meter mt-1" :style="{ color: scoreColor(s.score) }">
                  <div class="ohs-meter-fill" :style="{ width: s.score + '%' }" />
                </div>
              </div>
            </div>
            <div v-if="!scorecard.length" class="ohs-empty">No sites configured yet.</div>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ ACTION QUEUE ═══════════════ -->
      <v-col cols="12" lg="7">
        <OhsPanel title="Action queue" subtitle="Overdue and expiring items across every module" icon="mdi-lightning-bolt-outline" flush>
          <template #actions>
            <v-chip v-if="queue.length" size="x-small" variant="tonal" color="error" class="font-weight-bold">
              {{ queue.length }} outstanding
            </v-chip>
          </template>
          <div class="ohs-scroll" style="max-height:330px">
            <div v-for="(q, i) in queue" :key="i" class="ohs-list-row">
              <v-avatar size="26" :color="queueTone(q.kind)" variant="tonal">
                <v-icon size="14">{{ queueIcon(q.kind) }}</v-icon>
              </v-avatar>
              <div class="flex-grow-1" style="min-width:0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ q.title }}</div>
                <div class="text-caption text-medium-emphasis">
                  <span class="ohs-mono">{{ q.ref }}</span>
                  <span v-if="q.owner"> · {{ q.owner }}</span>
                  <span v-if="q.due"> · due {{ formatDate(q.due) }}</span>
                </div>
              </div>
              <span class="ohs-badge" :class="q.days > 14 ? 'ohs-badge--err' : 'ohs-badge--warn'">
                {{ q.days > 0 ? `${q.days}d late` : 'due' }}
              </span>
              <v-btn
                icon="mdi-arrow-right"
                variant="text"
                size="x-small"
                :to="q.href"
              />
            </div>
            <div v-if="!queue.length" class="ohs-empty">
              <v-icon size="30" color="success">mdi-check-decagram</v-icon>
              Nothing overdue. The register is fully current.
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ TOP RISKS ═══════════════ -->
      <v-col cols="12" lg="7">
        <OhsPanel title="Highest residual risks" subtitle="Open hazards ranked by severity × likelihood" icon="mdi-alert-octagon-outline" flush>
          <div class="ohs-scroll" style="max-height:340px">
            <table class="ohs-table ohs-table--plain">
              <thead>
                <tr>
                  <th style="width:104px">Ref</th>
                  <th>Hazard</th>
                  <th style="width:120px">Site</th>
                  <th style="width:78px" class="num">Score</th>
                  <th style="width:92px">Rating</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="h in topRisks" :key="h.id">
                  <td class="ohs-mono">{{ h.reference }}</td>
                  <td>
                    <div class="font-weight-medium text-truncate" style="max-width:320px">{{ h.title }}</div>
                    <div class="text-caption text-medium-emphasis">{{ h.area || h.hazard_type_display }}</div>
                  </td>
                  <td class="text-caption">{{ h.site_name }}</td>
                  <td class="num font-weight-bold">{{ h.risk_score }}</td>
                  <td><RiskBadge :level="h.risk_level" /></td>
                </tr>
              </tbody>
            </table>
            <div v-if="!topRisks.length" class="ohs-empty">No open hazards recorded.</div>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ RECENT INCIDENTS ═══════════════ -->
      <v-col cols="12" lg="5">
        <OhsPanel title="Recent incidents" subtitle="Latest reports across all sites" icon="mdi-alert-circle-outline" flush>
          <div class="ohs-scroll" style="max-height:340px">
            <div v-for="inc in recentIncidents" :key="inc.id" class="incident-row">
              <div class="incident-dot" :class="`incident-dot--${toneFor(inc.severity)}`" />
              <div class="flex-grow-1" style="min-width:0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ inc.title }}</div>
                <div class="text-caption text-medium-emphasis">
                  <span class="ohs-mono">{{ inc.reference }}</span> · {{ inc.site_name }} ·
                  {{ formatDateTime(inc.occurred_at) }}
                </div>
              </div>
              <span class="ohs-badge" :class="`ohs-badge--${toneFor(inc.status)}`">
                {{ inc.status_display }}
              </span>
            </div>
            <div v-if="!recentIncidents.length" class="ohs-empty">No incidents reported.</div>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ TRAINING ═══════════════ -->
      <v-col cols="12" md="6" lg="4">
        <OhsPanel title="Training currency" subtitle="Valid certificates vs records held" icon="mdi-school-outline">
          <div v-for="c in trainingCourses" :key="c.id" class="mb-2">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="text-caption font-weight-medium text-truncate">{{ c.name }}</span>
              <span class="text-caption ohs-tabular" :style="{ color: pctColor(c.pct) }">{{ num(c.pct) }}%</span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: pctColor(c.pct) }">
              <div class="ohs-meter-fill" :style="{ width: Math.min(c.pct, 100) + '%' }" />
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ c.trained }} valid
              <span v-if="c.mandatory"> · <span class="text-warning">mandatory</span></span>
            </div>
          </div>
          <div v-if="!trainingCourses.length" class="ohs-empty">No courses defined.</div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ EXPOSURE ═══════════════ -->
      <v-col cols="12" md="6" lg="4">
        <OhsPanel title="Exposure monitoring" subtitle="Worst reading per agent vs OEL" icon="mdi-air-filter">
          <div v-for="e in exposure" :key="e.agent" class="mb-2">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="text-caption font-weight-medium">{{ e.label }}</span>
              <span class="text-caption ohs-tabular">
                {{ e.worst }} {{ e.unit }}
                <span v-if="e.limit" class="text-medium-emphasis">/ {{ e.limit }}</span>
              </span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: e.exceeded ? '#dc2626' : '#16a34a' }">
              <div
                class="ohs-meter-fill"
                :style="{ width: Math.min(e.limit ? (e.worst / e.limit) * 100 : 40, 100) + '%' }"
              />
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ e.readings }} readings
              <span v-if="e.exceeded" class="text-error font-weight-bold"> · {{ e.exceeded }} above limit</span>
            </div>
          </div>
          <div v-if="!exposure.length" class="ohs-empty">No exposure data.</div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ COMPLIANCE + OBJECTIVES ═══════════════ -->
      <v-col cols="12" lg="4">
        <OhsPanel title="Objectives & targets" subtitle="Annual OH&S programme progress" icon="mdi-target">
          <div v-for="o in objectives" :key="o.id" class="mb-2">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="text-caption font-weight-medium text-truncate">{{ o.title }}</span>
              <span class="ohs-badge" :class="`ohs-badge--${toneFor(o.status)}`">
                {{ o.status_display }}
              </span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: pctColor(o.progress_pct) }">
              <div class="ohs-meter-fill" :style="{ width: Math.min(o.progress_pct, 100) + '%' }" />
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ num(o.current_value) }} → {{ num(o.target_value) }} {{ o.unit }} ·
              {{ num(o.progress_pct) }}%
            </div>
          </div>
          <div v-if="!objectives.length" class="ohs-empty">No objectives set.</div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ COMPLIANCE BREAKDOWN ═══════════════ -->
      <v-col cols="12" lg="4">
        <OhsPanel title="Legal register status" subtitle="Statutory and standard obligations" icon="mdi-gavel">
          <div class="d-flex align-center" style="gap:16px">
            <div class="donut" :style="donutStyle">
              <div class="donut-hole">
                <span class="donut-value">{{ num(kpis.legal_compliance_pct) }}%</span>
                <span class="donut-label">compliance</span>
              </div>
            </div>
            <div class="flex-grow-1">
              <div v-for="row in legalRows" :key="row.key" class="d-flex align-center justify-space-between mb-1">
                <span class="d-flex align-center text-caption" style="gap:6px">
                  <span class="dot" :style="{ background: row.color }" />
                  {{ row.label }}
                </span>
                <span class="text-caption font-weight-bold ohs-tabular">{{ row.value }}</span>
              </div>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="d-flex align-center justify-space-between">
            <span class="text-caption text-medium-emphasis">Latest audit score</span>
            <span class="text-subtitle-1 font-weight-bold" :style="{ color: pctColor(kpis.audit_score) }">
              {{ num(kpis.audit_score) }}%
            </span>
          </div>
          <div class="d-flex align-center justify-space-between mt-1">
            <span class="text-caption text-medium-emphasis">Drills completed · avg evacuation</span>
            <span class="text-caption font-weight-bold">{{ kpis.avg_evacuation_seconds || 0 }}s</span>
          </div>
        </OhsPanel>
      </v-col>

      <!-- ═══════════════ INCIDENT MIX ═══════════════ -->
      <v-col cols="12" lg="4">
        <OhsPanel title="Incident mix" subtitle="By type for the reporting period" icon="mdi-chart-donut-variant">
          <div v-for="t in incidentsByType" :key="t.key" class="mb-2">
            <div class="d-flex align-center justify-space-between">
              <span class="text-caption font-weight-medium">{{ t.label }}</span>
              <span class="text-caption ohs-tabular">{{ t.count }}</span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: brand.primary.value }">
              <div class="ohs-meter-fill" :style="{ width: shareOf(t.count) + '%' }" />
            </div>
          </div>
          <div v-if="!incidentsByType.length" class="ohs-empty">No incidents in this period.</div>
        </OhsPanel>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
import { RISK_BANDS, riskStep, toneFor } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Safety Command Centre · OHSMS' })

const ohs = useOhs()
const brand = useBranding()
const router = useRouter()
const { $api } = useNuxtApp()

const periodDays = ref(90)
const raw = ref(null)
const loading = ref(true)
const alertCount = ref(0)
const maturityScore = ref(0)
const docCount = ref(0)
const contractorCount = ref(0)
const certExpiring = ref(0)
const equipmentDue = ref(0)
const equipmentOverdue = ref(0)

/* ── "Under development" dialog (dismissed once per browser) ────────── */
const NOTICE_KEY = 'ohs_preview_notice_v1'
const noticeDialog = ref(false)

const noticeRows = [
  {
    title: 'Incomplete screens',
    text: 'A few pages may look unfinished, show placeholder filters or behave unexpectedly while we finish building them.',
    icon: 'mdi-progress-wrench',
    tone: 'warn',
  },
  {
    title: 'Your data is safe',
    text: 'Everything you record — hazards, incidents, inspections, equipment and training — is saved and reported as normal.',
    icon: 'mdi-database-check-outline',
    tone: 'ok',
  },
  {
    title: 'Tell us what breaks',
    text: 'If a module gets in your way, note the page name and send it to your safety administrator so it can be prioritised.',
    icon: 'mdi-message-alert-outline',
    tone: 'info',
  },
]

function persistNotice() {
  try {
    localStorage.setItem(NOTICE_KEY, 'dismissed')
  } catch { /* storage blocked — the notice simply returns next visit */ }
}

function initNotice() {
  let dismissed = false
  try {
    dismissed = localStorage.getItem(NOTICE_KEY) === 'dismissed'
  } catch {
    dismissed = false
  }
  if (dismissed) return
  // Let the dashboard paint first so the dialog doesn't fight the initial load.
  setTimeout(() => { noticeDialog.value = true }, 900)
}

function dismissNotice() {
  noticeDialog.value = false
  persistNotice()
}

// Closing via the ✕, Escape or the scrim counts as a dismissal too.
watch(noticeDialog, (open) => {
  if (!open) persistNotice()
})

const empty = {
  sites: { total: 0, active: 0, headcount: 0, hours_worked: 0 },
  kpis: {},
  risk_matrix: { matrix: Array.from({ length: 5 }, () => Array(5).fill(0)), by_level: {} },
  incidents_trend: [],
  incidents_by_type: [],
  hazards_by_category: [],
  site_scorecard: [],
  action_queue: [],
  recent_incidents: [],
  top_risks: [],
  training_courses: [],
  compliance_breakdown: {},
  exposure_summary: [],
  objectives: [],
}

const d = computed(() => raw.value || empty)
const sites = computed(() => d.value.sites || empty.sites)
const kpis = computed(() => d.value.kpis || {})
const scorecard = computed(() => d.value.site_scorecard || [])
const queue = computed(() => d.value.action_queue || [])
const topRisks = computed(() => d.value.top_risks || [])
const recentIncidents = computed(() => d.value.recent_incidents || [])
const trainingCourses = computed(() => d.value.training_courses || [])
const exposure = computed(() => d.value.exposure_summary || [])
const objectives = computed(() => d.value.objectives || [])
const incidentsByType = computed(() => d.value.incidents_by_type || [])

const levelKeys = ['critical', 'high', 'medium', 'low', 'negligible']
const riskByLevel = computed(() => d.value.risk_matrix?.by_level || {})
const riskTotal = computed(() => Object.values(riskByLevel.value).reduce((a, b) => a + b, 0))

const trend = computed(() => d.value.incidents_trend || [])
const trendValues = computed(() => trend.value.map((t) => t.total))
const trendLabels = computed(() => trend.value.map((t) => t.label))
const trendTotals = computed(() => ({
  total: trend.value.reduce((s, t) => s + t.total, 0),
  lti: trend.value.reduce((s, t) => s + t.lti, 0),
  near: trend.value.reduce((s, t) => s + t.near_miss, 0),
}))

const legalRows = computed(() => {
  const b = d.value.compliance_breakdown || {}
  return [
    { key: 'compliant', label: 'Compliant', value: b.compliant || 0, color: '#16a34a' },
    { key: 'partial', label: 'Partial', value: b.partial || 0, color: '#f59e0b' },
    { key: 'non_compliant', label: 'Non-compliant', value: b.non_compliant || 0, color: '#dc2626' },
    { key: 'not_assessed', label: 'Not assessed', value: b.not_assessed || 0, color: '#94a3b8' },
  ]
})

const donutStyle = computed(() => {
  const rows = legalRows.value
  const total = rows.reduce((s, r) => s + r.value, 0) || 1
  let acc = 0
  const stops = rows.map((r) => {
    const from = (acc / total) * 100
    acc += r.value
    const to = (acc / total) * 100
    return `${r.color} ${from}% ${to}%`
  })
  return { background: `conic-gradient(${stops.join(', ')})` }
})

const heroSubtitle = computed(() => {
  const s = sites.value
  return `${s.total} sites · ${fmt(s.headcount)} workers under management · ISO 45001-aligned risk, incident, permit and compliance control.`
})

const severityRate = computed(() => Number(kpis.value.severity_rate || 0).toFixed(2))

function fmt(v) {
  return Number(v || 0).toLocaleString()
}
function num(v) {
  const n = Number(v ?? 0)
  return Number.isInteger(n) ? n : n.toFixed(n < 10 ? 1 : 0)
}

function matrixCell(row, col) {
  const m = d.value.risk_matrix?.matrix || []
  const lik = 6 - row
  return m?.[lik - 1]?.[col - 1] || 0
}

function cellStep(lik, sev) {
  return riskStep(lik * sev)
}

function scoreColor(score) {
  if (score >= 85) return '#16a34a'
  if (score >= 70) return '#f59e0b'
  return '#dc2626'
}
function scoreTone(score) {
  if (score >= 85) return 'site-score--ok'
  if (score >= 70) return 'site-score--warn'
  return 'site-score--err'
}
function pctColor(pct) {
  const n = Number(pct || 0)
  if (n >= 85) return '#16a34a'
  if (n >= 60) return '#f59e0b'
  return '#dc2626'
}

function shareOf(count) {
  const max = Math.max(1, ...incidentsByType.value.map((t) => t.count))
  return Math.round((count / max) * 100)
}

function queueIcon(kind) {
  return {
    control: 'mdi-shield-alert-outline',
    capa: 'mdi-source-branch-check',
    inspection: 'mdi-clipboard-check-outline',
    permit: 'mdi-file-document-check-outline',
    training: 'mdi-school-outline',
  }[kind] || 'mdi-clock-alert'
}
function queueTone(kind) {
  return {
    control: 'error',
    capa: 'error',
    inspection: 'warning',
    permit: 'info',
    training: 'warning',
  }[kind] || 'grey'
}

function exportSnapshot() {
  const k = kpis.value
  exportCsv(
    `ohsms_snapshot_${new Date().toISOString().slice(0, 10)}.csv`,
    [
      { metric: 'TRIR', value: k.trir },
      { metric: 'LTIFR', value: k.ltifr },
      { metric: 'Open hazards', value: k.open_hazards },
      { metric: 'High-risk hazards', value: k.high_risk_hazards },
      { metric: 'Overdue controls', value: k.overdue_controls },
      { metric: 'Incidents (period)', value: k.incidents_period },
      { metric: 'Lost-time injuries', value: k.lost_time_injuries },
      { metric: 'Lost days', value: k.lost_days },
      { metric: 'Open CAPA', value: k.open_actions },
      { metric: 'Overdue CAPA', value: k.overdue_actions },
      { metric: 'Training currency %', value: k.training_compliance_pct },
      { metric: 'Inspection score %', value: k.inspection_score },
      { metric: 'Legal compliance %', value: k.legal_compliance_pct },
      { metric: 'Active permits', value: k.permits_active },
      { metric: 'Health surveillance due', value: k.health_surveillance_due },
      { metric: 'Observations (period)', value: k.observations_period },
      { metric: 'Safe behaviour %', value: k.safe_ratio },
      { metric: 'Audit score %', value: k.audit_score },
    ],
    [{ key: 'metric', label: 'Metric' }, { key: 'value', label: 'Value' }],
  )
}

async function load() {
  loading.value = true
  try {
    raw.value = await ohs.dashboard(periodDays.value)
  } catch {
    raw.value = null
  } finally {
    loading.value = false
  }
  loadExtras()
}

/** Lightweight side-load for the command strip counters. */
async function loadExtras() {
  try {
    const [alerts, intel, docs, contractors, certs, equipment] = await Promise.all([
      $api.get('/ohs/alerts/'),
      $api.get('/ohs/intelligence/'),
      $api.get('/ohs/documents/', { params: { page_size: 1 } }),
      $api.get('/ohs/contractors/', { params: { page_size: 1 } }),
      $api.get('/ohs/certifications/', { params: { expiring: 60, page_size: 1 } }),
      $api.get('/ohs/equipment-summary/'),
    ])
    alertCount.value = alerts.data?.counts?.total || 0
    maturityScore.value = intel.data?.maturity?.score ?? 0
    docCount.value = docs.data?.count ?? 0
    contractorCount.value = contractors.data?.count ?? 0
    certExpiring.value = certs.data?.count ?? 0
    equipmentOverdue.value = equipment.data?.kpis?.overdue ?? 0
    equipmentDue.value = (equipment.data?.kpis?.due_soon ?? 0)
      + (equipment.data?.kpis?.calibration_overdue ?? 0)
  } catch { /* counters are non-critical */ }
}

function goto(path) {
  router.push(path)
}
function gotoAlerts() {
  router.push('/ohs/alerts')
}
function openPalette() {
  // The palette is mounted in the default layout; dispatch the same hotkey.
  window.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', ctrlKey: true }))
}

onMounted(load)
onMounted(initNotice)
</script>

<style scoped>
/* ── Preview / under-development dialog ─────────────────────────────── */
.pv-row {
  display: flex;
  gap: 11px;
  padding: 9px 0;
}
.pv-row + .pv-row {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.pv-icon {
  flex-shrink: 0;
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border-radius: 9px;
  margin-top: 1px;
}
.pv-icon--warn { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.pv-icon--ok   { color: #15803d; background: rgba(22, 163, 74, 0.13); }
.pv-icon--info { color: #0369a1; background: rgba(2, 132, 199, 0.13); }
.pv-copy { min-width: 0; }
.pv-title {
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.1px;
  color: rgb(var(--v-theme-on-surface));
}
.pv-text {
  margin: 2px 0 0;
  font-size: 11.5px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.pv-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 14px 0 4px;
}
.pv-tag {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.45px;
  text-transform: uppercase;
  padding: 4px 8px;
  border-radius: 6px;
  color: rgba(var(--v-theme-on-surface), 0.68);
  background: rgba(var(--v-theme-on-surface), 0.06);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
}
.pv-hint {
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.dn-dismiss {
  font-weight: 700;
  letter-spacing: 0.2px;
  color: #fff !important;
  background: linear-gradient(135deg, #ea580c, #b45309) !important;
  box-shadow: 0 6px 16px rgba(180, 83, 9, 0.28);
}
.dn-dismiss:hover { filter: brightness(1.06); }

.v-theme--dark .pv-icon--warn { color: #fcd34d; background: rgba(245, 158, 11, 0.2); }
.v-theme--dark .pv-icon--ok   { color: #86efac; background: rgba(22, 163, 74, 0.2); }
.v-theme--dark .pv-icon--info { color: #7dd3fc; background: rgba(2, 132, 199, 0.22); }
.v-theme--dark .pv-row + .pv-row { border-top-color: rgba(255, 255, 255, 0.08); }

@media (max-width: 600px) {
  .pv-hint { display: none; }
}

.cmd-strip {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(178px, 1fr));
  gap: 8px;
}
.cmd-tile {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 12px;
  border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  text-align: left;
  cursor: pointer;
  font-size: 12px;
  font-weight: 600;
  color: rgb(var(--v-theme-on-surface));
  transition: transform .15s ease, box-shadow .15s ease, border-color .15s ease;
}
.cmd-tile:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
  border-color: rgba(var(--v-theme-primary), 0.32);
}
.cmd-tile .v-icon { color: rgb(var(--v-theme-primary)); flex-shrink: 0; }
.cmd-label { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cmd-kbd {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: .4px;
  padding: 2px 6px;
  border-radius: 5px;
  color: rgba(var(--v-theme-on-surface), .55);
  background: rgba(15, 23, 42, 0.06);
}
.cmd-meta {
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), .5);
  white-space: nowrap;
}
.cmd-meta--warn { color: #b45309; }

.matrix-axis-vert {
  writing-mode: vertical-rl;
  transform: rotate(180deg);
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
  white-space: nowrap;
}
.matrix-axis-horiz {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.dot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; }

.site-row {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.site-row:last-child { border-bottom: none; }
.site-score {
  width: 40px;
  height: 40px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 800;
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}
.site-score--ok { color: #15803d; background: rgba(34, 197, 94, 0.14); }
.site-score--warn { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.site-score--err { color: #b91c1c; background: rgba(239, 68, 68, 0.14); }

.incident-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.incident-row:last-child { border-bottom: none; }
.incident-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.incident-dot--ok { background: #16a34a; }
.incident-dot--info { background: #0284c7; }
.incident-dot--warn { background: #f59e0b; }
.incident-dot--err { background: #dc2626; }
.incident-dot--muted { background: #94a3b8; }

.mini-chip {
  font-size: 10px;
  font-weight: 600;
  padding: 1px 6px;
  border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: rgba(15, 23, 42, 0.05);
}
.mini-chip--err { color: #b91c1c; background: rgba(239, 68, 68, 0.12); }
.mini-chip--warn { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.mini-chip--info { color: #0369a1; background: rgba(14, 165, 233, 0.12); }

.donut {
  position: relative;
  width: 92px;
  height: 92px;
  border-radius: 50%;
  flex-shrink: 0;
}
.donut-hole {
  position: absolute;
  inset: 12px;
  border-radius: 50%;
  background: rgb(var(--v-theme-surface));
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
.donut-value { font-size: 15px; font-weight: 800; line-height: 1; }
.donut-label {
  font-size: 8.5px;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
</style>
