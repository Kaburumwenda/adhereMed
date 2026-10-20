<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-fire-extinguisher"
      eyebrow="OHSMS · Clause 8.1 · Operational control"
      title="Safety Equipment"
      subtitle="Every physical control on one register — fire fighting, respiratory, fall arrest, gas detection, lifting gear and LOTO — with statutory inspection, calibration and defect tracking."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-wrench"
               @click="openDefectLog">Report defect</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">Add equipment</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-shield-half-full</v-icon>
        <b>{{ summary.kpis.total }}</b> assets</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-circle-outline</v-icon>
        <b>{{ summary.kpis.currency_pct }}%</b> inspection currency</span>
      <span v-if="summary.kpis.overdue" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ summary.kpis.overdue }}</b> inspections overdue</span>
      <span v-if="summary.kpis.open_defects" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-wrench-clock</v-icon>
        <b>{{ summary.kpis.open_defects }}</b> open defects</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Assets" :value="summary.kpis.total" icon="mdi-shield-half-full" tone="primary"
              :sub="`${summary.kpis.in_service} in service`" />
      <OhsKpi label="Inspection currency" :value="`${summary.kpis.currency_pct}%`"
              icon="mdi-calendar-check-outline" :tone="currencyTone"
              sub="statutory regime met" />
      <OhsKpi label="Overdue" :value="summary.kpis.overdue" icon="mdi-alert-octagon-outline"
              :tone="summary.kpis.overdue ? 'err' : 'ok'" :sub="`${summary.kpis.calibration_overdue} calibration`" />
      <OhsKpi label="Due ≤ 14 days" :value="summary.kpis.due_soon" icon="mdi-timer-sand"
              :tone="summary.kpis.due_soon ? 'warn' : 'ok'" sub="schedule now" />
      <OhsKpi label="Open defects" :value="summary.kpis.open_defects" icon="mdi-wrench-clock"
              :tone="summary.kpis.open_defects ? 'warn' : 'ok'" sub="work orders live" />
      <OhsKpi label="Fleet health" :value="`${summary.kpis.avg_health}%`" icon="mdi-heart-pulse"
              :tone="healthTone" :sub="`${summary.kpis.end_of_life} near end of life`" />
    </div>

    <!-- ═══════════ COVERAGE + ATTENTION ═══════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="5">
        <OhsPanel title="Coverage by category" :subtitle="`${summary.by_category.length} equipment families`"
                  icon="mdi-view-grid-outline" class="h-100">
          <div v-for="c in summary.by_category" :key="c.key" class="cat-row">
            <div class="cat-row-top">
              <span class="cat-name">{{ c.label }}</span>
              <span class="cat-figures">
                <b>{{ c.total }}</b>
                <span v-if="c.overdue" class="cat-overdue">{{ c.overdue }} overdue</span>
              </span>
            </div>
            <div class="ohs-meter" :style="{ color: categoryTone(c) }">
              <div class="ohs-meter-fill" :style="{ width: c.health + '%' }" />
            </div>
          </div>
          <div v-if="!summary.by_category.length" class="ohs-empty">No equipment recorded yet.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="7">
        <OhsPanel title="Needs attention" subtitle="Overdue, quarantined or out of service — highest risk first"
                  icon="mdi-alert-decagram-outline" class="h-100" flush>
          <div class="attn-list">
            <button v-for="e in summary.attention" :key="e.id" class="attn-row" @click="openDetailById(e.id)">
              <span class="attn-rail" :class="`attn-rail--${e.compliance_state}`" />
              <span class="attn-main">
                <span class="attn-title">{{ e.name }}</span>
                <span class="attn-meta">
                  <span class="ohs-mono">{{ e.reference }}</span> · {{ e.category }}
                  <template v-if="e.site_name"> · {{ e.site_name }}</template>
                </span>
              </span>
              <span class="attn-days">
                <template v-if="e.days_to_inspection !== null">
                  <b :style="{ color: e.days_to_inspection < 0 ? '#dc2626' : '#b45309' }">
                    {{ e.days_to_inspection < 0 ? `${Math.abs(e.days_to_inspection)}d` : `${e.days_to_inspection}d` }}
                  </b>
                  <small>{{ e.days_to_inspection < 0 ? 'past due' : 'to inspect' }}</small>
                </template>
                <span v-else class="text-caption text-medium-emphasis">—</span>
              </span>
              <span class="ohs-badge" :class="stateBadge(e.compliance_state)">{{ stateLabel(e) }}</span>
            </button>
            <div v-if="!summary.attention.length" class="ohs-empty">
              Everything is within its inspection window. 🎉
            </div>
            <div class="attn-freshness">Recomputed from the live register · refreshed {{ refreshedAt }}</div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ ASSET REGISTER ═══════════ -->
    <OhsPanel title="Equipment register" :subtitle="`${filtered.length} of ${items.count.value} assets`"
              icon="mdi-format-list-checks" flush>
      <template #actions>
        <v-btn-toggle v-model="view" density="compact" variant="text" divided mandatory
                      class="mr-1">
          <v-btn value="table" size="small" icon="mdi-format-list-bulleted" />
          <v-btn value="cards" size="small" icon="mdi-view-grid-outline" />
        </v-btn-toggle>
        <v-chip-group v-model="stateFilter" mandatory selected-class="text-primary">
          <v-chip v-for="f in stateFilters" :key="f.value" :value="f.value" size="small"
                  variant="tonal" :color="f.color">{{ f.label }}</v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search name, tag, serial, location…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                      rounded="lg" hide-details single-line clearable style="max-width:280px" />
        <v-select v-model="categoryFilter" :items="categoryOptions" item-title="label"
                  item-value="value" placeholder="All categories" density="compact"
                  variant="outlined" rounded="lg" hide-details clearable style="max-width:200px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="All statuses" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
      </div>

      <v-progress-linear v-if="items.loading.value" indeterminate color="primary" height="2" />

      <!-- table view -->
      <div v-if="view === 'table'" class="ohs-scroll" style="max-height:64vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th>Equipment</th>
              <th style="width:130px">Category</th>
              <th style="width:130px">Site / location</th>
              <th style="width:120px">Criticality</th>
              <th style="width:145px">Next inspection</th>
              <th style="width:95px">Health</th>
              <th style="width:110px">Status</th>
              <th style="width:64px" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="e in filtered" :key="e.id" class="row-click" @click="openDetail(e)">
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:280px">{{ e.name }}</div>
                <div class="text-caption text-medium-emphasis ohs-mono">
                  {{ e.reference }}<template v-if="e.asset_tag"> · {{ e.asset_tag }}</template>
                </div>
              </td>
              <td class="text-caption">{{ e.category_display }}</td>
              <td>
                <div class="text-caption text-truncate" style="max-width:130px">{{ e.site_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis text-truncate" style="max-width:130px">
                  {{ e.location || '—' }}
                </div>
              </td>
              <td>
                <span class="ohs-badge" :class="criticalityBadge(e.criticality)">
                  {{ e.criticality_display }}
                </span>
              </td>
              <td>
                <div class="d-flex align-center" style="gap:6px">
                  <div class="ohs-meter" style="width:54px" :style="{ color: inspectionTone(e) }">
                    <div class="ohs-meter-fill" :style="{ width: e.inspection_currency_pct + '%' }" />
                  </div>
                  <span class="text-caption" :style="{ color: inspectionText(e) }">
                    {{ inspectionLabel(e) }}
                  </span>
                </div>
              </td>
              <td>
                <div class="d-flex align-center" style="gap:5px">
                  <span class="health-dot" :style="{ background: healthColor(e.health_score) }" />
                  <span class="text-caption font-weight-medium">{{ e.health_score }}%</span>
                </div>
                <div v-if="e.open_defects" class="text-caption" style="color:#b45309">
                  {{ e.open_defects }} defect{{ e.open_defects > 1 ? 's' : '' }}
                </div>
              </td>
              <td>
                <span class="ohs-badge" :class="statusBadge(e.status)">{{ e.status_display }}</span>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-chevron-right" variant="text" size="x-small" density="comfortable" />
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !items.loading.value" class="ohs-empty">
          No equipment matches these filters.
        </div>
      </div>

      <!-- card view -->
      <div v-else class="eq-grid">
        <button v-for="e in filtered" :key="e.id" class="eq-card" @click="openDetail(e)">
          <div class="eq-card-top">
            <span class="eq-icon" :style="{ color: categoryColor(e.category) }">
              <v-icon size="17">{{ categoryIcon(e.category) }}</v-icon>
            </span>
            <span class="ohs-badge" :class="stateBadge(e.compliance_state)">{{ stateLabel(e) }}</span>
          </div>
          <div class="eq-name">{{ e.name }}</div>
          <div class="eq-ref ohs-mono">{{ e.reference }}</div>
          <div class="eq-foot">
            <span class="text-caption text-medium-emphasis">{{ e.site_name || 'Unassigned' }}</span>
            <span class="eq-health" :style="{ color: healthColor(e.health_score) }">
              {{ e.health_score }}%
            </span>
          </div>
          <div class="ohs-meter" :style="{ color: inspectionTone(e) }">
            <div class="ohs-meter-fill" :style="{ width: e.inspection_currency_pct + '%' }" />
          </div>
          <div class="eq-foot mt-1">
            <span class="text-caption">{{ e.category_display }}</span>
            <span class="text-caption" :style="{ color: inspectionText(e) }">{{ inspectionLabel(e) }}</span>
          </div>
        </button>
        <div v-if="!filtered.length && !items.loading.value" class="ohs-empty" style="grid-column:1/-1">
          No equipment matches these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- ═══════════ DEFECTS + TREND ═══════════ -->
    <v-row dense class="mt-3">
      <v-col cols="12" md="7">
        <OhsPanel title="Defect & work-order log" :subtitle="`${openDefects.length} open · ${defects.length} total`"
                  icon="mdi-wrench-clock-outline" class="h-100" flush>
          <div class="ohs-scroll" style="max-height:42vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th>Defect</th>
                  <th style="width:150px">Equipment</th>
                  <th style="width:92px">Raised</th>
                  <th style="width:92px">Severity</th>
                  <th style="width:110px">Status</th>
                  <th style="width:74px" />
                </tr>
              </thead>
              <tbody>
                <tr v-for="d in defects" :key="d.id">
                  <td>
                    <div class="text-caption" style="max-width:300px">{{ d.description }}</div>
                    <div class="text-caption text-medium-emphasis ohs-mono">
                      {{ d.work_order || 'no work order' }}
                      <template v-if="d.days_open !== null"> · open {{ d.days_open }}d</template>
                    </div>
                  </td>
                  <td class="text-caption text-truncate" style="max-width:150px">
                    {{ d.equipment_name }}
                  </td>
                  <td class="text-caption">{{ formatDate(d.reported_on) }}</td>
                  <td>
                    <span class="ohs-badge" :class="severityBadge(d.severity)">{{ d.severity_display }}</span>
                  </td>
                  <td>
                    <span class="ohs-badge" :class="defectBadge(d.status)">{{ d.status_display }}</span>
                  </td>
                  <td class="text-right">
                    <v-btn v-if="d.is_open" size="x-small" variant="tonal" color="success"
                           rounded="lg" class="text-none" @click="openResolve(d)">Fix</v-btn>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!defects.length" class="ohs-empty">No defects reported — the fleet is clean.</div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="5">
        <OhsPanel title="Defects raised vs closed" subtitle="Rolling 12 months" icon="mdi-chart-areaspline"
                  class="h-100">
          <SparkArea :values="defectTrend" :labels="defectMonths" :height="132" color="#f43f5e"
                     :show-y-axis="false" />
          <div class="trend-legend mt-3">
            <div class="legend-item">
              <span class="legend-dot" style="background:#f43f5e" />
              <span><b>{{ trendTotals.raised }}</b> raised</span>
            </div>
            <div class="legend-item">
              <span class="legend-dot" style="background:#16a34a" />
              <span><b>{{ trendTotals.closed }}</b> closed</span>
            </div>
            <div class="legend-item">
              <span class="legend-dot" style="background:#94a3b8" />
              <span><b>{{ trendTotals.ratio }}%</b> closure rate</span>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="cal-block">
            <div class="d-flex align-center justify-content-between mb-1">
              <span class="text-caption font-weight-bold">CALIBRATION REGIME</span>
              <span class="text-caption text-medium-emphasis">
                {{ calibratedCount }} instruments
              </span>
            </div>
            <div class="ohs-meter" :style="{ color: summary.kpis.calibration_overdue ? '#dc2626' : '#16a34a' }">
              <div class="ohs-meter-fill" :style="{ width: calibrationPct + '%' }" />
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ calibrationPct }}% of calibration-due instruments are within their window
            </div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ DETAIL DRAWER ═══════════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="580" class="ohs-drawer">
      <div v-if="detail" class="drawer-wrap">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color: rgba(255,255,255,.8)">
                {{ detail.reference }}
              </div>
              <div class="text-h6 font-weight-bold" style="line-height:1.2">{{ detail.name }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="ohs-badge ohs-badge--muted"
                  style="background:rgba(255,255,255,.16); color:#fff">
              {{ detail.category_display }}
            </span>
            <span class="ohs-badge ohs-badge--muted"
                  style="background:rgba(255,255,255,.16); color:#fff">
              {{ detail.criticality_display }} criticality
            </span>
            <span class="ohs-badge ohs-badge--muted"
                  style="background:rgba(255,255,255,.16); color:#fff">
              {{ detail.status_display }}
            </span>
          </div>
        </div>

        <div class="pa-4 drawer-body">
          <!-- health strip -->
          <div class="health-strip">
            <div class="hs-item">
              <span class="hs-label">Health</span>
              <span class="hs-value" :style="{ color: healthColor(detail.health_score) }">
                {{ detail.health_score }}%
              </span>
            </div>
            <div class="hs-item">
              <span class="hs-label">Inspection</span>
              <span class="hs-value" :style="{ color: inspectionText(detail) }">
                {{ inspectionLabel(detail) }}
              </span>
            </div>
            <div class="hs-item">
              <span class="hs-label">Calibration</span>
              <span class="hs-value" :style="{ color: calibrationText(detail) }">
                {{ calibrationLabel(detail) }}
              </span>
            </div>
            <div class="hs-item">
              <span class="hs-label">Open defects</span>
              <span class="hs-value" :style="{ color: detail.open_defects ? '#b45309' : '#16a34a' }">
                {{ detail.open_defects }}
              </span>
            </div>
          </div>

          <!-- passport -->
          <div class="section-title">Asset passport</div>
          <v-row dense>
            <v-col cols="6">
              <div class="meta"><span>Asset tag</span><b class="ohs-mono">{{ detail.asset_tag || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Serial no.</span><b class="ohs-mono">{{ detail.serial_number || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Manufacturer</span><b>{{ detail.manufacturer || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Model</span><b>{{ detail.model || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Standard</span><b>{{ detail.standard || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Quantity</span><b>{{ detail.quantity }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Site</span><b>{{ detail.site_name || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Location</span><b>{{ detail.location || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Department</span><b>{{ detail.department || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Custodian</span><b>{{ detail.custodian || '—' }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Acquired</span><b>{{ formatDate(detail.acquired_on) }}</b></div>
            </v-col>
            <v-col cols="6">
              <div class="meta"><span>Age</span>
                <b>{{ detail.age_years ?? '—' }} yrs<template v-if="detail.is_end_of_life"> · end of life</template></b>
              </div>
            </v-col>
          </v-row>

          <!-- inspection regime -->
          <div class="section-title">Inspection & calibration</div>
          <div class="regime-grid">
            <div class="regime-box">
              <div class="regime-label">Last inspected</div>
              <div class="regime-value">{{ formatDate(detail.last_inspected_on) }}</div>
              <div class="regime-foot">every {{ detail.inspection_interval_days }}d</div>
            </div>
            <div class="regime-box" :class="{ 'regime-box--warn': detail.is_inspection_overdue }">
              <div class="regime-label">Next inspection</div>
              <div class="regime-value">{{ formatDate(detail.next_inspection_on) }}</div>
              <div class="regime-foot">{{ inspectionLabel(detail) }}</div>
            </div>
            <div class="regime-box">
              <div class="regime-label">Last calibrated</div>
              <div class="regime-value">{{ formatDate(detail.last_calibrated_on) }}</div>
              <div class="regime-foot">
                {{ detail.requires_calibration ? `every ${detail.calibration_interval_days}d` : 'not required' }}
              </div>
            </div>
            <div class="regime-box" :class="{ 'regime-box--warn': detail.is_calibration_overdue }">
              <div class="regime-label">Next calibration</div>
              <div class="regime-value">{{ formatDate(detail.next_calibration_on) }}</div>
              <div class="regime-foot">{{ calibrationLabel(detail) }}</div>
            </div>
          </div>

          <!-- inspection history -->
          <div class="d-flex align-center justify-space-between mt-4 mb-2">
            <span class="section-title" style="margin:0">Inspection history</span>
            <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none"
                   prepend-icon="mdi-plus" @click="openInspection(detail)">Record</v-btn>
          </div>
          <div v-for="i in detail.inspections" :key="i.id" class="hist-row">
            <span class="hist-dot" :class="{ 'hist-dot--fail': i.is_failed }" />
            <div class="flex-grow-1">
              <div class="d-flex align-center" style="gap:6px">
                <b class="text-body-2">{{ i.inspection_type_display }}</b>
                <span class="ohs-badge" :class="i.is_failed ? 'ohs-badge--err' : 'ohs-badge--ok'">
                  {{ i.result_display }}
                </span>
              </div>
              <div class="text-caption text-medium-emphasis">
                {{ formatDate(i.performed_on) }} · {{ i.performed_by || 'unrecorded' }}
                <template v-if="i.provider"> · {{ i.provider }}</template>
              </div>
              <div v-if="i.findings" class="text-caption mt-1">{{ i.findings }}</div>
            </div>
            <div class="text-caption text-medium-emphasis text-right">
              <div v-if="Number(i.cost)">KES {{ Number(i.cost).toLocaleString() }}</div>
              <div v-if="i.next_due" class="text-caption">next {{ formatDate(i.next_due) }}</div>
            </div>
          </div>
          <div v-if="!detail.inspections?.length" class="text-caption text-medium-emphasis">
            No inspection history yet.
          </div>

          <!-- defects -->
          <div class="d-flex align-center justify-space-between mt-4 mb-2">
            <span class="section-title" style="margin:0">Defects & repairs</span>
            <v-btn size="x-small" variant="tonal" color="warning" rounded="lg" class="text-none"
                   prepend-icon="mdi-wrench" @click="openDefect(detail)">Report</v-btn>
          </div>
          <div v-for="d in detail.defects" :key="d.id" class="defect-card">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="ohs-badge" :class="severityBadge(d.severity)">{{ d.severity_display }}</span>
              <span class="ohs-badge" :class="defectBadge(d.status)">{{ d.status_display }}</span>
            </div>
            <div class="text-body-2 mt-1">{{ d.description }}</div>
            <div class="text-caption text-medium-emphasis mt-1">
              Raised {{ formatDate(d.reported_on) }} by {{ d.reported_by || '—' }}
              <template v-if="d.resolved_on"> · resolved {{ formatDate(d.resolved_on) }}</template>
              <template v-else> · open {{ d.days_open }}d</template>
            </div>
            <div v-if="d.resolution" class="text-caption mt-1">{{ d.resolution }}</div>
            <v-btn v-if="d.is_open" size="x-small" variant="tonal" color="success" rounded="lg"
                   class="text-none mt-2" @click="openResolve(d)">Mark resolved</v-btn>
          </div>
          <div v-if="!detail.defects?.length" class="text-caption text-medium-emphasis">
            No defects recorded for this asset.
          </div>

          <div v-if="detail.notes" class="mt-4">
            <div class="section-title">Notes</div>
            <div class="text-body-2">{{ detail.notes }}</div>
          </div>
        </div>

        <div class="drawer-foot">
          <v-btn variant="text" class="text-none" prepend-icon="mdi-swap-horizontal"
                 @click="openStatus(detail)">Change status</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" color="primary" prepend-icon="mdi-calendar-check"
                 @click="openInspection(detail)">Record inspection</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═══════════ CREATE EQUIPMENT ═══════════ -->
    <v-dialog v-model="createDialog" max-width="760" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-plus-box-multiple-outline" title="Add safety equipment"
                           subtitle="Assign an inspection regime — the register tracks currency automatically." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.name" label="Equipment name" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.quantity" type="number" min="1" label="Quantity"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.category" :items="categoryOptions" item-title="label"
                        item-value="value" label="Category" variant="outlined" density="compact"
                        rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.criticality" :items="criticalityOptions" item-title="label"
                        item-value="value" label="Criticality" variant="outlined" density="compact"
                        rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.status" :items="statusOptions" item-title="label"
                        item-value="value" label="Status" variant="outlined" density="compact"
                        rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.asset_tag" label="Asset tag" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.serial_number" label="Serial number" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.standard" label="Standard (EN/ANSI)" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.manufacturer" label="Manufacturer" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.model" label="Model" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.location" label="Location / area" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.department" label="Department" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.custodian" label="Custodian" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>

            <v-col cols="12">
              <v-divider class="my-1" />
              <div class="text-caption font-weight-bold mb-1" style="letter-spacing:.5px">
                INSPECTION REGIME
              </div>
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.inspection_interval_days" type="number" min="1"
                            label="Inspect every (days)" variant="outlined" density="compact"
                            rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.last_inspected_on" type="date" label="Last inspected"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-switch v-model="form.requires_calibration" label="Requires calibration"
                        color="primary" density="compact" hide-details class="mt-1" />
            </v-col>
            <template v-if="form.requires_calibration">
              <v-col cols="12" sm="6">
                <v-text-field v-model.number="form.calibration_interval_days" type="number" min="1"
                              label="Calibrate every (days)" variant="outlined" density="compact"
                              rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.last_calibrated_on" type="date" label="Last calibrated"
                              variant="outlined" density="compact" rounded="lg" />
              </v-col>
            </template>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.acquired_on" type="date" label="Acquired on"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.unit_cost" type="number" min="0" label="Unit cost (KES)"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
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
                 :disabled="!form.name" @click="save">Add to register</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ RECORD INSPECTION ═══════════ -->
    <v-dialog v-model="inspectionDialog" max-width="620" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-clipboard-check-outline" title="Record inspection"
                           :subtitle="inspectionTarget?.name || ''" />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="inspectionForm.inspection_type" :items="inspectionTypeOptions"
                        item-title="label" item-value="value" label="Inspection type"
                        variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="inspectionForm.performed_on" type="date" label="Performed on"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="inspectionForm.performed_by" label="Performed by"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="inspectionForm.provider" label="Provider / contractor"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="inspectionForm.result" :items="inspectionResultOptions"
                        item-title="label" item-value="value" label="Result" variant="outlined"
                        density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="inspectionForm.next_due" type="date" label="Next due"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="inspectionForm.findings" label="Findings" rows="2"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="inspectionForm.action_taken" label="Action taken" rows="2"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="inspectionForm.cost" type="number" min="0"
                            label="Cost (KES)" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="inspectionForm.downtime_hours" type="number" min="0"
                            label="Downtime (hours)" variant="outlined" density="compact"
                            rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="inspectionForm.result === 'fail'" type="warning" variant="tonal"
                   density="compact" rounded="lg" class="mt-2">
            A failed inspection automatically moves this asset out of service.
          </v-alert>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="inspectionDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingAction"
                 @click="saveInspection">Save inspection</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ REPORT DEFECT ═══════════ -->
    <v-dialog v-model="defectDialog" max-width="620" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-wrench" title="Report a defect"
                           :subtitle="defectTarget?.name || 'Select the affected asset'" />
        <v-card-text>
          <v-row dense>
            <v-col v-if="!defectTarget" cols="12">
              <v-select v-model="defectForm.equipment" :items="equipmentOptions"
                        item-title="label" item-value="value" label="Equipment" variant="outlined"
                        density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="defectForm.severity" :items="severityOptions" item-title="label"
                        item-value="value" label="Severity" variant="outlined" density="compact"
                        rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="defectForm.reported_on" type="date" label="Reported on"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="defectForm.reported_by" label="Reported by" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="defectForm.work_order" label="Work order no." variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="defectForm.description" label="Defect description" rows="3"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="defectForm.status" :items="defectStatusOptions" item-title="label"
                        item-value="value" label="Status" variant="outlined" density="compact"
                        rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="defectForm.downtime_hours" type="number" min="0"
                            label="Downtime (hours)" variant="outlined" density="compact"
                            rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="defectForm.severity === 'critical'" type="warning" variant="tonal"
                   density="compact" rounded="lg" class="mt-2">
            Critical defects take the asset out of service immediately.
          </v-alert>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="defectDialog = false">Cancel</v-btn>
          <v-btn color="warning" rounded="lg" class="text-none" :loading="savingAction"
                 :disabled="!defectForm.equipment || !defectForm.description"
                 @click="saveDefect">Report defect</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ RESOLVE DEFECT ═══════════ -->
    <v-dialog v-model="resolveDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-check-circle-outline" title="Resolve defect"
                           :subtitle="resolveTarget?.description || ''" />
        <v-card-text>
          <v-textarea v-model="resolveForm.resolution" label="Resolution" rows="3"
                      variant="outlined" density="compact" rounded="lg" class="mb-2" />
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model.number="resolveForm.repair_cost" type="number" min="0"
                            label="Repair cost (KES)" variant="outlined" density="compact"
                            rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="resolveForm.downtime_hours" type="number" min="0"
                            label="Downtime (hours)" variant="outlined" density="compact"
                            rounded="lg" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="resolveDialog = false">Cancel</v-btn>
          <v-btn color="success" rounded="lg" class="text-none" :loading="savingAction"
                 @click="saveResolve">Mark resolved</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ CHANGE STATUS ═══════════ -->
    <v-dialog v-model="statusDialog" max-width="440">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-swap-horizontal" title="Change equipment status"
                           :subtitle="statusTarget?.name || ''" />
        <v-card-text>
          <v-select v-model="statusValue" :items="statusOptions" item-title="label"
                    item-value="value" label="New status" variant="outlined" density="compact"
                    rounded="lg" />
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="statusDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingAction"
                 @click="saveStatus">Update status</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2800">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Safety Equipment · OHSMS' })

const { $api } = useNuxtApp()
const ohs = useOhs()

const items = ohs.resource('equipment')
const defectsRes = ohs.resource('equipment-defects')
const lookups = ref({})
const summary = ref({
  kpis: {
    total: 0, in_service: 0, overdue: 0, due_soon: 0, calibration_overdue: 0,
    out_of_service: 0, open_defects: 0, end_of_life: 0, currency_pct: 0, avg_health: 0,
  },
  by_category: [], by_site: [], attention: [], trend: [],
})
const refreshedAt = ref('—')

const view = ref('table')
const search = ref('')
const categoryFilter = ref(null)
const siteFilter = ref(null)
const statusFilter = ref(null)
const stateFilter = ref('all')

const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const inspectionDialog = ref(false)
const defectDialog = ref(false)
const resolveDialog = ref(false)
const statusDialog = ref(false)
const inspectionTarget = ref(null)
const defectTarget = ref(null)
const resolveTarget = ref(null)
const statusTarget = ref(null)
const statusValue = ref('in_service')
const savingAction = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  name: '', category: 'fire', criticality: 'medium', status: 'in_service', quantity: 1,
  asset_tag: '', serial_number: '', standard: '', manufacturer: '', model: '', site: null,
  location: '', department: '', custodian: '', inspection_interval_days: 30,
  last_inspected_on: '', requires_calibration: false, calibration_interval_days: 365,
  last_calibrated_on: '', acquired_on: '', unit_cost: 0, notes: '',
})

const inspectionForm = reactive({
  inspection_type: 'routine', performed_on: today(), performed_by: '', provider: '',
  result: 'pass', next_due: '', findings: '', action_taken: '', cost: 0, downtime_hours: 0,
})

const defectForm = reactive({
  equipment: null, severity: 'medium', reported_on: today(), reported_by: '',
  work_order: '', description: '', status: 'open', downtime_hours: 0,
})

const resolveForm = reactive({ resolution: '', repair_cost: 0, downtime_hours: 0 })

function today() {
  return new Date().toISOString().slice(0, 10)
}

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const categoryOptions = computed(() => lookups.value.equipment_categories || [])
const criticalityOptions = computed(() => lookups.value.equipment_criticality || [])
const statusOptions = computed(() => lookups.value.equipment_status || [])
const inspectionTypeOptions = computed(() => lookups.value.inspection_types || [])
const inspectionResultOptions = computed(() => lookups.value.inspection_results || [])
const severityOptions = computed(() => lookups.value.defect_severities || [])
const defectStatusOptions = computed(() => lookups.value.defect_status || [])

const stateFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Overdue', value: 'overdue', color: 'error' },
  { label: 'Due soon', value: 'due', color: 'warning' },
  { label: 'Out of service', value: 'out_of_service', color: 'deep-orange' },
  { label: 'Healthy', value: 'ok', color: 'success' },
]

const rows = computed(() => items.items.value || [])
const defects = computed(() => defectsRes.items.value || [])
const openDefects = computed(() => defects.value.filter((d) => d.is_open))

const filtered = computed(() => rows.value.filter((e) => {
  if (categoryFilter.value && e.category !== categoryFilter.value) return false
  if (siteFilter.value && e.site !== siteFilter.value) return false
  if (statusFilter.value && e.status !== statusFilter.value) return false
  if (stateFilter.value !== 'all' && e.compliance_state !== stateFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${e.name} ${e.reference} ${e.asset_tag} ${e.serial_number} ${e.location} ${e.manufacturer}`
      .toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const equipmentOptions = computed(() => rows.value.map((e) => ({
  label: `${e.reference} · ${e.name}`, value: e.id,
})))

const defectTrend = computed(() => (summary.value.trend || []).map((t) => t.raised))
const defectMonths = computed(() => (summary.value.trend || []).map((t) => t.month))
const trendTotals = computed(() => {
  const raised = defectTrend.value.reduce((a, b) => a + b, 0)
  const closed = (summary.value.trend || []).reduce((a, t) => a + t.closed, 0)
  return { raised, closed, ratio: raised ? Math.round(closed / raised * 100) : 0 }
})

const calibratedCount = computed(() => rows.value.filter((e) => e.requires_calibration).length)
const calibrationPct = computed(() => {
  const list = rows.value.filter((e) => e.requires_calibration)
  if (!list.length) return 100
  const good = list.filter((e) => !e.is_calibration_overdue).length
  return Math.round(good / list.length * 100)
})

const currencyTone = computed(() => {
  const v = summary.value.kpis.currency_pct
  return v >= 90 ? 'ok' : v >= 75 ? 'info' : v >= 60 ? 'warn' : 'err'
})
const healthTone = computed(() => {
  const v = summary.value.kpis.avg_health
  return v >= 85 ? 'ok' : v >= 70 ? 'info' : v >= 50 ? 'warn' : 'err'
})

// ── presentation helpers ────────────────────────────────────────────────
const CATEGORY_ICONS = {
  fire: 'mdi-fire-extinguisher', detection: 'mdi-smoke-detector', respiratory: 'mdi-gas-cylinder',
  fall: 'mdi-harness', gas: 'mdi-radar', first_aid: 'mdi-medical-bag',
  eyewash: 'mdi-eye-outline', spill: 'mdi-water-off-outline', loto: 'mdi-lock-outline',
  lifting: 'mdi-crane', pressure: 'mdi-gauge', electrical: 'mdi-flash-alert',
  rescue: 'mdi-lifebuoy', monitoring: 'mdi-chart-timeline-variant', other: 'mdi-shield-outline',
}
const CATEGORY_COLORS = {
  fire: '#dc2626', detection: '#f97316', respiratory: '#0284c7', fall: '#7c3aed',
  gas: '#0891b2', first_aid: '#16a34a', eyewash: '#0ea5e9', spill: '#65a30d',
  loto: '#b45309', lifting: '#475569', pressure: '#334155', electrical: '#eab308',
  rescue: '#f43f5e', monitoring: '#6366f1', other: '#64748b',
}
function categoryIcon(key) {
  return CATEGORY_ICONS[key] || 'mdi-shield-outline'
}
function categoryColor(key) {
  return CATEGORY_COLORS[key] || '#64748b'
}
function categoryTone(c) {
  if (c.overdue) return '#dc2626'
  if (c.health >= 85) return '#16a34a'
  if (c.health >= 65) return '#f59e0b'
  return '#ea580c'
}
function healthColor(score) {
  if (score >= 85) return '#16a34a'
  if (score >= 70) return '#0284c7'
  if (score >= 50) return '#f59e0b'
  return '#dc2626'
}
function inspectionLabel(e) {
  if (!e.requires_inspection) return 'not required'
  const d = e.days_to_inspection
  if (d === null || d === undefined) return 'unscheduled'
  if (d < 0) return `${Math.abs(d)}d overdue`
  if (d === 0) return 'due today'
  return `in ${d}d`
}
function inspectionTone(e) {
  if (e.is_inspection_overdue) return '#dc2626'
  if (e.is_inspection_due_soon) return '#f59e0b'
  return '#16a34a'
}
function inspectionText(e) {
  if (e.is_inspection_overdue) return '#dc2626'
  if (e.is_inspection_due_soon) return '#b45309'
  return 'inherit'
}
function calibrationLabel(e) {
  if (!e.requires_calibration) return 'n/a'
  const d = e.days_to_calibration
  if (d === null || d === undefined) return 'unscheduled'
  if (d < 0) return `${Math.abs(d)}d overdue`
  return `in ${d}d`
}
function calibrationText(e) {
  if (!e.requires_calibration) return '#94a3b8'
  if (e.is_calibration_overdue) return '#dc2626'
  if (e.is_calibration_due_soon) return '#b45309'
  return 'inherit'
}
function stateBadge(state) {
  return {
    overdue: 'ohs-badge--err', due: 'ohs-badge--warn', out_of_service: 'ohs-badge--err',
    unmonitored: 'ohs-badge--muted', ok: 'ohs-badge--ok',
  }[state] || 'ohs-badge--muted'
}
function stateLabel(e) {
  return {
    overdue: 'Overdue', due: 'Due soon', out_of_service: 'Out of service',
    unmonitored: 'Unmonitored', ok: 'Compliant',
  }[e.compliance_state] || e.compliance_state
}
function statusBadge(status) {
  return {
    in_service: 'ohs-badge--ok', maintenance: 'ohs-badge--info', quarantine: 'ohs-badge--warn',
    out_of_service: 'ohs-badge--err', decommissioned: 'ohs-badge--muted',
  }[status] || 'ohs-badge--muted'
}
function criticalityBadge(level) {
  return {
    critical: 'ohs-badge--err', high: 'ohs-badge--warn',
    medium: 'ohs-badge--info', low: 'ohs-badge--muted',
  }[level] || 'ohs-badge--muted'
}
function severityBadge(level) {
  return {
    critical: 'ohs-badge--err', high: 'ohs-badge--warn',
    medium: 'ohs-badge--info', low: 'ohs-badge--muted',
  }[level] || 'ohs-badge--muted'
}
function defectBadge(status) {
  return {
    open: 'ohs-badge--err', in_progress: 'ohs-badge--warn',
    awaiting_parts: 'ohs-badge--warn', resolved: 'ohs-badge--ok',
    written_off: 'ohs-badge--muted',
  }[status] || 'ohs-badge--muted'
}

// ── data loading ────────────────────────────────────────────────────────
async function loadSummary() {
  try {
    const { data } = await $api.get('/ohs/equipment-summary/')
    summary.value = data
    refreshedAt.value = new Date().toLocaleTimeString(undefined, {
      hour: '2-digit', minute: '2-digit',
    })
  } catch { /* keep prior snapshot */ }
}

async function load() {
  await Promise.all([
    items.list({ ordering: 'next_inspection_on', page_size: 500 }),
    defectsRes.list({ ordering: '-reported_on', page_size: 200 }),
    loadSummary(),
  ])
  lookups.value = await ohs.loadLookups()
}

async function refreshAll() {
  await Promise.all([load(), loadSummary()])
}

function openDetail(e) {
  detail.value = e
  drawer.value = true
  // The list serializer is lightweight — pull the full asset with its
  // inspection history and defect log.
  loadOne(e.id).then((full) => {
    if (full && detail.value?.id === full.id) detail.value = full
  })
}
async function openDetailById(id) {
  const local = rows.value.find((e) => e.id === id)
  if (local) {
    openDetail(local)
    return
  }
  const full = await loadOne(id)
  if (full) openDetail(full)
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    name: '', category: 'fire', criticality: 'medium', status: 'in_service', quantity: 1,
    asset_tag: '', serial_number: '', standard: '', manufacturer: '', model: '', site: null,
    location: '', department: '', custodian: '', inspection_interval_days: 30,
    last_inspected_on: today(), requires_calibration: false, calibration_interval_days: 365,
    last_calibrated_on: '', acquired_on: '', unit_cost: 0, notes: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    for (const key of ['last_inspected_on', 'last_calibrated_on', 'acquired_on', 'site']) {
      if (!payload[key]) delete payload[key]
    }
    if (!payload.requires_calibration) {
      delete payload.calibration_interval_days
      delete payload.last_calibrated_on
    }
    const created = await items.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: `${created.reference} added to the register.` }
    await refreshAll()
  } catch (e) {
    error.value = items.message(e)
  }
}

function openInspection(e) {
  error.value = ''
  inspectionTarget.value = e
  Object.assign(inspectionForm, {
    inspection_type: 'routine', performed_on: today(), performed_by: '', provider: '',
    result: 'pass', next_due: '', findings: '', action_taken: '', cost: 0, downtime_hours: 0,
  })
  inspectionDialog.value = true
}

async function saveInspection() {
  if (!inspectionTarget.value) return
  error.value = ''
  savingAction.value = true
  try {
    const payload = { ...inspectionForm }
    if (!payload.next_due) delete payload.next_due
    const { data } = await $api.post(
      `/ohs/equipment/${inspectionTarget.value.id}/record_inspection/`, payload,
    )
    inspectionDialog.value = false
    snack.value = {
      show: true, color: inspectionForm.result === 'fail' ? 'warning' : 'success',
      text: inspectionForm.result === 'fail'
        ? 'Inspection logged — asset moved out of service.'
        : 'Inspection recorded and dates rolled forward.',
    }
    if (detail.value?.id === inspectionTarget.value.id) detail.value = data.equipment
    await refreshAll()
  } catch (e) {
    error.value = items.message(e)
  } finally {
    savingAction.value = false
  }
}

function openDefect(e) {
  error.value = ''
  defectTarget.value = e
  Object.assign(defectForm, {
    equipment: e?.id ?? null, severity: 'medium', reported_on: today(), reported_by: '',
    work_order: '', description: '', status: 'open', downtime_hours: 0,
  })
  defectDialog.value = true
}

function openDefectLog() {
  openDefect(null)
}

async function saveDefect() {
  error.value = ''
  savingAction.value = true
  try {
    const { data } = await $api.post(
      `/ohs/equipment/${defectForm.equipment}/report_defect/`, { ...defectForm },
    )
    defectDialog.value = false
    snack.value = {
      show: true, color: defectForm.severity === 'critical' ? 'warning' : 'success',
      text: defectForm.severity === 'critical'
        ? 'Critical defect logged — asset taken out of service.'
        : 'Defect logged to the work-order queue.',
    }
    if (detail.value?.id === defectForm.equipment) detail.value = data.equipment
    await refreshAll()
  } catch (e) {
    error.value = items.message(e)
  } finally {
    savingAction.value = false
  }
}

function openResolve(d) {
  resolveTarget.value = d
  Object.assign(resolveForm, {
    resolution: '', repair_cost: 0, downtime_hours: d.downtime_hours || 0,
  })
  resolveDialog.value = true
}

async function saveResolve() {
  if (!resolveTarget.value) return
  savingAction.value = true
  try {
    await $api.post(`/ohs/equipment-defects/${resolveTarget.value.id}/resolve/`, { ...resolveForm })
    resolveDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Defect resolved and closed out.' }
    await refreshAll()
    if (detail.value) {
      const fresh = await loadOne(detail.value.id)
      if (fresh) detail.value = fresh
    }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: items.message(e) }
  } finally {
    savingAction.value = false
  }
}

function openStatus(e) {
  statusTarget.value = e
  statusValue.value = e.status
  statusDialog.value = true
}

async function saveStatus() {
  if (!statusTarget.value) return
  savingAction.value = true
  try {
    const { data } = await $api.post(`/ohs/equipment/${statusTarget.value.id}/set_status/`, {
      status: statusValue.value,
    })
    statusDialog.value = false
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Equipment status updated.' }
    await refreshAll()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: items.message(e) }
  } finally {
    savingAction.value = false
  }
}

async function loadOne(id) {
  try {
    const { data } = await $api.get(`/ohs/equipment/${id}/`)
    return data
  } catch {
    return null
  }
}

function exportData() {
  exportCsv(`safety_equipment_${today()}.csv`, filtered.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'name', label: 'Equipment' },
    { key: 'category_display', label: 'Category' },
    { key: 'site_name', label: 'Site' },
    { key: 'location', label: 'Location' },
    { key: 'criticality_display', label: 'Criticality' },
    { key: 'status_display', label: 'Status' },
    { key: 'last_inspected_on', label: 'Last inspected' },
    { key: 'next_inspection_on', label: 'Next inspection' },
    { key: 'days_to_inspection', label: 'Days to inspection' },
    { key: 'next_calibration_on', label: 'Next calibration' },
    { key: 'health_score', label: 'Health score' },
    { key: 'open_defects', label: 'Open defects' },
    { key: 'manufacturer', label: 'Manufacturer' },
    { key: 'serial_number', label: 'Serial no.' },
  ])
}

onMounted(load)
</script>

<style scoped>
/* ── category coverage ─────────────────────────────────────────────── */
.cat-row { padding: 5px 0; }
.cat-row-top { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; margin-bottom: 4px; }
.cat-name { font-size: 12px; font-weight: 600; }
.cat-figures { display: flex; align-items: center; gap: 8px; font-size: 11.5px; }
.cat-figures b { font-weight: 800; }
.cat-overdue { color: #dc2626; font-weight: 700; font-size: 10.5px; }

/* ── needs attention ───────────────────────────────────────────────── */
.attn-list { display: flex; flex-direction: column; }
.attn-row {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 14px 8px 0; text-align: left; width: 100%;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: transparent; cursor: pointer; transition: background .14s ease;
}
.attn-row:hover { background: rgba(15, 23, 42, 0.03); }
.attn-rail { width: 3px; align-self: stretch; border-radius: 0 3px 3px 0; background: #94a3b8; }
.attn-rail--overdue { background: #dc2626; }
.attn-rail--out_of_service { background: #ea580c; }
.attn-rail--due { background: #f59e0b; }
.attn-main { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.attn-title { font-size: 12.5px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.attn-meta { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55); }
.attn-days { display: flex; flex-direction: column; align-items: flex-end; min-width: 58px; }
.attn-days b { font-size: 12px; }
.attn-days small { font-size: 9.5px; text-transform: uppercase; letter-spacing: .3px; color: rgba(var(--v-theme-on-surface), .5); }
.attn-freshness {
  padding: 8px 14px; font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), .45); border-top: 1px solid rgba(15, 23, 42, 0.06);
}

/* ── register table ────────────────────────────────────────────────── */
.row-click { cursor: pointer; }
.row-click:hover { background: rgba(15, 23, 42, 0.03); }
.health-dot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; flex: 0 0 auto; }

/* ── card view ─────────────────────────────────────────────────────── */
.eq-grid {
  display: grid; gap: 10px; padding: 12px;
  grid-template-columns: repeat(auto-fill, minmax(214px, 1fr));
  max-height: 64vh; overflow: auto;
}
.eq-card {
  text-align: left; padding: 11px 12px 10px; border-radius: 12px; cursor: pointer;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  transition: box-shadow .16s ease, transform .16s ease;
}
.eq-card:hover { transform: translateY(-1px); box-shadow: 0 8px 20px rgba(15, 23, 42, .09); }
.eq-card-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 7px; }
.eq-icon {
  width: 30px; height: 30px; border-radius: 9px; display: grid; place-items: center;
  background: rgba(15, 23, 42, .05);
}
.eq-name {
  font-size: 12.5px; font-weight: 700; line-height: 1.25; min-height: 31px;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
}
.eq-ref { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .5); margin: 2px 0 6px; }
.eq-foot { display: flex; align-items: center; justify-content: space-between; gap: 6px; margin-bottom: 4px; }
.eq-health { font-size: 12px; font-weight: 800; }

/* ── trend legend ──────────────────────────────────────────────────── */
.trend-legend { display: flex; gap: 16px; flex-wrap: wrap; }
.legend-item { display: flex; align-items: center; gap: 6px; font-size: 11.5px; }
.legend-dot { width: 8px; height: 8px; border-radius: 50%; }
.cal-block { font-size: 12px; }

/* ── drawer ────────────────────────────────────────────────────────── */
.drawer-wrap { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.drawer-body { flex: 1 1 auto; min-height: 0; overflow: auto; }
.drawer-head { flex: 0 0 auto; padding: 16px; color: #fff; background: var(--brand-gradient); }
.drawer-foot {
  flex: 0 0 auto;
  display: flex; align-items: center; gap: 6px;
  padding: 8px 12px; border-top: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
}
.meta { display: flex; flex-direction: column; gap: 1px; }
.meta span {
  font-size: 10.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.meta b { font-size: 12.5px; font-weight: 600; }

.health-strip {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin-bottom: 14px;
}
.hs-item {
  padding: 9px 10px; border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08); background: rgba(15, 23, 42, .02);
  display: flex; flex-direction: column; gap: 2px;
}
.hs-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.hs-value { font-size: 13.5px; font-weight: 800; }

.section-title {
  font-size: 10.5px; font-weight: 800; letter-spacing: .6px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5); margin: 18px 0 8px;
}

.regime-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.regime-box {
  padding: 9px 11px; border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08); background: rgba(15, 23, 42, .02);
}
.regime-box--warn { border-color: rgba(220, 38, 38, .35); background: rgba(220, 38, 38, .06); }
.regime-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.regime-value { font-size: 13px; font-weight: 700; }
.regime-foot { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55); }

.hist-row {
  display: flex; gap: 9px; padding: 8px 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}
.hist-dot {
  width: 8px; height: 8px; border-radius: 50%; background: #16a34a;
  margin-top: 6px; flex: 0 0 auto;
}
.hist-dot--fail { background: #dc2626; }

.defect-card {
  border: 1px solid rgba(15, 23, 42, 0.08); border-radius: 10px;
  padding: 9px 11px; margin-bottom: 7px; background: rgb(var(--v-theme-surface));
}
</style>
