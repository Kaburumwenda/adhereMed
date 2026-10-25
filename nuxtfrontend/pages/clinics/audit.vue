<template>
  <div class="ohs-page audit-page">
    <!-- ═══════════════ HERO ═══════════════ -->
    <OhsHero
      icon="mdi-shield-search"
      eyebrow="Security & settings · Audit"
      title="Audit Trail"
      subtitle="An append-only record of every change in this clinic — who acted, on which record, from where, and whether it succeeded."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small"
               prepend-icon="mdi-file-delimited-outline" :loading="exporting === 'csv'"
               @click="exportLog('csv')">Export CSV</v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small"
               prepend-icon="mdi-code-json" :loading="exporting === 'json'"
               @click="exportLog('json')">JSON</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small"
               prepend-icon="mdi-refresh" :loading="loading" @click="loadAll">Refresh</v-btn>
      </template>

      <span class="ohs-chip">
        <v-icon size="12">mdi-database-clock</v-icon>
        <b>{{ fmtNum(kpis.total) }}</b> events retained
      </span>
      <span class="ohs-chip">
        <v-icon size="12">mdi-history</v-icon>
        <b>{{ kpis.retention_days }}</b> days of history
      </span>
      <span v-if="kpis.critical" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ kpis.critical }}</b> critical
      </span>
      <span v-if="kpis.failures" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-cancel</v-icon>
        <b>{{ fmtNum(kpis.failures) }}</b> failed requests
      </span>
      <span class="ohs-chip">
        <v-icon size="12">mdi-shield-check-outline</v-icon>
        <b>{{ posture.score }}</b> posture · {{ posture.label }}
      </span>
    </OhsHero>

    <!-- ═══════════════ KPIs ═══════════════ -->
    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Total events" :value="fmtNum(kpis.total)" icon="mdi-database-eye-outline"
              tone="primary" :sub="`${kpis.modules || 0} modules covered`" />
      <OhsKpi label="Last 24 hours" :value="fmtNum(kpis.last_24h)" icon="mdi-clock-fast"
              tone="info" :sub="`${fmtNum(kpis.last_7d)} in 7 days`" />
      <OhsKpi label="Critical" :value="kpis.critical || 0" icon="mdi-alert-octagon-outline"
              :tone="kpis.critical ? 'err' : 'ok'" sub="deletions & faults" />
      <OhsKpi label="Warnings" :value="kpis.warnings || 0" icon="mdi-alert-outline"
              :tone="kpis.warnings ? 'warn' : 'ok'" sub="4xx responses" />
      <OhsKpi label="Active actors" :value="kpis.distinct_actors || 0"
              icon="mdi-account-multiple-outline" tone="primary" sub="distinct users" />
      <OhsKpi label="Failed requests" :value="fmtNum(kpis.failures)" icon="mdi-cancel"
              :tone="kpis.failures ? 'warn' : 'ok'" sub="blocked or errored" />
    </div>

    <!-- ═══════════════ TREND + COMPOSITION ═══════════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="7">
        <OhsPanel title="Activity trend" :subtitle="`Audited events per day · ${rangeLabel}`"
                  icon="mdi-chart-areaspline" class="h-100">
          <template #actions>
            <div class="trend-tabs">
              <button
                v-for="t in TREND_MODES"
                :key="t.value"
                type="button"
                class="trend-tab"
                :class="{ 'trend-tab--on': trendMode === t.value }"
                @click="trendMode = t.value"
              >{{ t.label }}</button>
            </div>
          </template>
          <SparkArea :values="trendValues" :labels="trendLabels" :height="168"
                     :color="trendMode === 'events' ? '#6366f1' : '#dc2626'" />
          <div class="trend-foot">
            <div class="trend-stat">
              <span class="ts-label">Daily average</span>
              <span class="ts-value">{{ trendStats.avg }}</span>
            </div>
            <div class="trend-stat">
              <span class="ts-label">Busiest day</span>
              <span class="ts-value">{{ trendStats.peak }}</span>
            </div>
            <div class="trend-stat">
              <span class="ts-label">Quietest day</span>
              <span class="ts-value">{{ trendStats.trough }}</span>
            </div>
            <div class="trend-stat">
              <span class="ts-label">2nd half vs 1st</span>
              <span class="ts-value" :style="{ color: trendStats.delta >= 0 ? '#b45309' : '#16a34a' }">
                {{ trendStats.delta > 0 ? '+' : '' }}{{ trendStats.delta }}%
              </span>
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="5">
        <OhsPanel title="Composition" subtitle="What kind of activity is being recorded"
                  icon="mdi-chart-donut" class="h-100">
          <div class="mix-block">
            <div class="mix-title">SEVERITY</div>
            <div class="sev-bar">
              <span v-for="s in severitySegments" :key="s.key" class="sev-seg"
                    :style="{ width: s.pct + '%', background: s.color }"
                    :title="`${s.label}: ${s.count}`" />
            </div>
            <div class="sev-legend">
              <button v-for="s in severitySegments" :key="s.key" class="sev-item sev-item--btn"
                      :class="{ 'sev-item--on': severityFilter === s.key }"
                      :disabled="!s.count"
                      type="button"
                      @click="severityFilter = severityFilter === s.key ? null : s.key; reload()">
                <i class="sev-dot" :style="{ background: s.color }" />
                {{ s.label }} <b>{{ s.count }}</b>
              </button>
            </div>
          </div>

          <v-divider class="my-3" />

          <div class="mix-block">
            <div class="mix-title">TOP ACTIONS</div>
            <div v-for="a in actionMix" :key="a.action" class="mix-row">
              <span class="mix-label">{{ actionLabel(a.action) }}</span>
              <div class="ohs-meter" :style="{ color: actionColor(a.action) }">
                <div class="ohs-meter-fill" :style="{ width: a.pct + '%' }" />
              </div>
              <span class="mix-count">{{ a.count }}</span>
            </div>
            <p v-if="!actionMix.length" class="ohs-empty">No actions recorded in this window.</p>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════════ SIGNALS + ACTORS + HOURLY ═══════════════ -->
    <v-row dense class="mb-3" align="stretch">
      <v-col cols="12" md="4">
        <OhsPanel title="Security signals" subtitle="Derived from the trail — highest risk first"
                  icon="mdi-shield-alert-outline" class="h-100" flush>
          <div class="signal-list">
            <button v-for="s in signals" :key="s.kind" type="button" class="signal-row"
                    @click="applySignal(s.kind)">
              <span class="signal-rail" :class="`signal-rail--${s.severity}`" />
              <div class="signal-body">
                <div class="signal-title">{{ s.title }}</div>
                <div class="signal-detail">{{ s.detail }}</div>
              </div>
              <span class="ohs-badge" :class="severityBadge(s.severity)">
                {{ severityLabel(s.severity) }}
              </span>
            </button>
            <div v-if="!signals.length" class="ohs-empty">
              No anomalies detected — the trail looks calm.
            </div>
          </div>
          <div class="signal-foot">
            Recomputed from the live trail · refreshed {{ refreshedAt }}
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="4">
        <OhsPanel title="Most active actors" subtitle="Event volume per user"
                  icon="mdi-account-star-outline" class="h-100">
          <div class="actor-list">
            <button v-for="a in topActors" :key="a.user_id ?? a.email" type="button"
                    class="actor-row" @click="filterByActor(a.email)">
              <span class="actor-avatar" :style="actorStyle(a)">{{ initialsOf(a.email) }}</span>
              <div class="actor-id">
                <div class="actor-name">{{ shortEmail(a.email) || 'Anonymous' }}</div>
                <div class="actor-role">{{ roleLabel(a.role) || '—' }}</div>
              </div>
              <div class="actor-count">{{ a.count }}</div>
            </button>
          </div>
          <div v-if="!topActors.length" class="ohs-empty">No identified actors yet.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="4">
        <OhsPanel title="Hourly profile" subtitle="Events by hour of day"
                  icon="mdi-clock-outline" class="h-100">
          <div class="hour-grid">
            <div v-for="h in hourly" :key="h.hour" class="hour-cell"
                 :class="{
                   'hour-cell--night': h.hour >= 22 || h.hour < 6,
                   'hour-cell--active': h.count > 0,
                 }"
                 :title="`${String(h.hour).padStart(2, '0')}:00 — ${h.count} events`">
              <span class="hour-bar" :style="{ height: hourPct(h.count) + '%' }" />
            </div>
          </div>
          <div class="hour-axis">
            <span>00</span><span>06</span><span>12</span><span>18</span><span>23</span>
          </div>
          <v-divider class="my-3" />
          <div class="hour-note">
            Peak at <b>{{ peakHour }}</b>. Night hours (22:00–06:00) are ringed so on-call
            access stands out.
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════════ MODULE COVERAGE ═══════════════ -->
    <OhsPanel title="Module coverage" subtitle="Which clinical registers generate audit traffic"
              icon="mdi-view-grid-outline" class="mb-3">
      <template #actions>
        <v-btn v-if="moduleFilter" variant="text" size="small" class="text-none"
               prepend-icon="mdi-filter-remove-outline" @click="moduleFilter = null; reload()">
          Clear module
        </v-btn>
      </template>
      <div class="module-grid">
        <button v-for="m in moduleMix" :key="m.object_type" type="button" class="module-tile"
                :class="{ 'module-tile--active': moduleFilter === m.object_type }"
                @click="toggleModule(m.object_type)">
          <div class="module-top">
            <span class="module-icon" :style="{ color: moduleColor(m.object_type) }">
              <v-icon size="15">{{ moduleIcon(m.object_type) }}</v-icon>
            </span>
            <span class="module-count">{{ m.count }}</span>
          </div>
          <div class="module-name">{{ moduleLabel(m.object_type) }}</div>
          <div class="ohs-meter" :style="{ color: moduleColor(m.object_type) }">
            <div class="ohs-meter-fill" :style="{ width: m.pct + '%' }" />
          </div>
        </button>
      </div>
      <div v-if="!moduleMix.length" class="ohs-empty">No module activity recorded yet.</div>
    </OhsPanel>

    <!-- ═══════════════ EVENT LOG ═══════════════ -->
    <OhsPanel :title="view === 'table' ? 'Event log' : 'Investigation timeline'"
              :subtitle="`${fmtNum(eventCount)} events match · ${rangeSpanLabel}`"
              icon="mdi-format-list-bulleted-square" flush>
      <template #actions>
        <div class="view-toggle">
          <button type="button" class="view-btn" :class="{ 'view-btn--on': view === 'table' }"
                  @click="view = 'table'">
            <v-icon size="14">mdi-table</v-icon> Table
          </button>
          <button type="button" class="view-btn" :class="{ 'view-btn--on': view === 'timeline' }"
                  @click="view = 'timeline'">
            <v-icon size="14">mdi-timeline-clock-outline</v-icon> Timeline
          </button>
        </div>

        <v-menu location="bottom end" :close-on-content-click="true">
          <template #activator="{ props }">
            <v-btn v-bind="props" variant="tonal" size="small" rounded="lg" class="text-none"
                   prepend-icon="mdi-calendar-range">
              {{ rangeLabel }}
              <v-icon end size="15">mdi-chevron-down</v-icon>
            </v-btn>
          </template>
          <v-list density="compact" class="py-1" style="min-width:238px">
            <v-list-subheader>Quick ranges</v-list-subheader>
            <v-list-item v-for="r in QUICK_RANGES" :key="r.value" :value="r.value"
                         :prepend-icon="r.icon" :title="r.label"
                         :class="{ 'text-primary font-weight-bold': rangeValue === r.value }"
                         @click="applyRange(r.value)" />
            <v-divider class="my-1" />
            <v-list-item prepend-icon="mdi-calendar-edit" title="Custom range…"
                         :class="{ 'text-primary font-weight-bold': rangeValue === 'custom' }"
                         @click="openCustom" />
            <v-list-item prepend-icon="mdi-calendar-remove" title="All time"
                         :class="{ 'text-primary font-weight-bold': rangeValue === 'all' }"
                         @click="applyRange('all')" />
          </v-list>
        </v-menu>
      </template>

      <!-- Toolbar -->
      <div class="ohs-toolbar">
        <v-text-field
          ref="searchRef"
          v-model="search"
          placeholder="Search actor, record, path or IP…  ( / )"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          single-line
          clearable
          style="max-width:290px"
          @update:model-value="debouncedLoad"
        />
        <v-select v-model="actionFilter" :items="ACTIONS" item-title="label" item-value="value"
                  placeholder="All actions" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:168px" @update:model-value="reload" />
        <v-select v-model="severityFilter" :items="SEVERITIES" item-title="label" item-value="value"
                  placeholder="All severities" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:178px" @update:model-value="reload" />
        <v-select v-model="moduleFilter" :items="moduleOptions" item-title="label" item-value="value"
                  placeholder="All modules" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:198px" @update:model-value="reload" />
        <span class="range-pill" :title="rangeSpanLabel">
          <v-icon size="13">mdi-calendar-clock</v-icon>
          {{ rangeSpanLabel }}
        </span>
        <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-filter-remove-outline"
               :disabled="!hasFilters" @click="clearFilters">Clear</v-btn>
      </div>

      <!-- Active filter summary -->
      <div v-if="hasFilters" class="filter-summary">
        <span class="fs-label">Active filters</span>
        <v-chip v-if="search" size="x-small" variant="tonal" closable
                prepend-icon="mdi-magnify" @click:close="search = ''; reload()">
          “{{ search }}”
        </v-chip>
        <v-chip v-if="actionFilter" size="x-small" variant="tonal" closable
                @click:close="actionFilter = null; reload()">
          Action: {{ actionLabel(actionFilter) }}
        </v-chip>
        <v-chip v-if="severityFilter" size="x-small" variant="tonal" closable
                @click:close="severityFilter = null; reload()">
          Severity: {{ severityLabel(severityFilter) }}
        </v-chip>
        <v-chip v-if="moduleFilter" size="x-small" variant="tonal" closable
                @click:close="moduleFilter = null; reload()">
          Module: {{ moduleLabel(moduleFilter) }}
        </v-chip>
        <v-chip v-if="rangeValue !== '30d'" size="x-small" variant="tonal" closable
                @click:close="applyRange('30d')">
          Range: {{ rangeLabel }}
        </v-chip>
      </div>

      <v-progress-linear v-if="loading" indeterminate color="primary" height="2" />

      <!-- ── TABLE VIEW ── -->
      <div v-if="view === 'table'" class="ohs-scroll audit-scroll">
        <table class="ohs-table audit-table">
          <thead>
            <tr>
              <th style="width:152px">When</th>
              <th style="width:176px">Actor</th>
              <th style="width:104px">Action</th>
              <th style="width:100px">Severity</th>
              <th>Record</th>
              <th style="width:144px">Module</th>
              <th style="width:78px">Status</th>
              <th style="width:44px" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="e in events" :key="e.id" class="row-click" @click="openDetail(e)">
              <td>
                <div class="cell-time">{{ formatDateTime(e.created_at) }}</div>
                <div class="cell-sub">{{ relativeDays(e.created_at) }}</div>
              </td>
              <td>
                <div class="cell-actor">
                  <span class="actor-dot" :style="actorDotStyle(e)">{{ initialsOf(e.actor_email) }}</span>
                  <span class="cell-actor-name">{{ shortEmail(e.actor_email) || 'Anonymous' }}</span>
                </div>
                <div class="cell-sub">{{ roleLabel(e.actor_role) || '—' }}</div>
              </td>
              <td>
                <span class="ohs-badge" :class="actionBadge(e.action)">
                  {{ actionLabel(e.action) }}
                </span>
              </td>
              <td>
                <span class="ohs-badge" :class="severityBadge(e.severity)">
                  {{ severityLabel(e.severity) }}
                </span>
              </td>
              <td>
                <div class="cell-record">{{ e.object_repr || e.description || '—' }}</div>
                <div class="cell-sub ohs-mono">
                  {{ e.object_id || e.path || '' }}
                </div>
              </td>
              <td>
                <span class="cell-module">{{ moduleLabel(e.object_type) }}</span>
              </td>
              <td>
                <span class="status-pill" :class="statusClass(e.status_code)">
                  {{ e.status_code ?? '—' }}
                </span>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-chevron-right" variant="text" size="x-small" density="comfortable" />
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!events.length && !loading" class="ohs-empty">
          <v-icon size="26" class="mb-1">mdi-shield-search</v-icon>
          <div>No audit events match these filters.</div>
          <div class="ohs-empty-sub">Try widening the date range or clearing a filter.</div>
        </div>
      </div>

      <!-- ── TIMELINE VIEW ── -->
      <div v-else class="timeline-wrap">
        <template v-for="group in timelineGroups" :key="group.day">
          <div class="tl-day">
            <span class="tl-day-label">{{ group.label }}</span>
            <span class="tl-day-count">{{ group.items.length }} events</span>
            <span class="tl-day-rule" />
          </div>
          <ol class="tl-list">
            <li v-for="e in group.items" :key="e.id" class="tl-item"
                :class="`tl-item--${e.severity}`" @click="openDetail(e)">
              <span class="tl-dot" />
              <span class="tl-time">{{ formatTime(e.created_at) }}</span>
              <span class="tl-badge" :class="actionBadge(e.action)">{{ actionLabel(e.action) }}</span>
              <span class="tl-text">{{ e.object_repr || e.description || e.path || '—' }}</span>
              <span class="tl-actor">{{ shortEmail(e.actor_email) || 'system' }}</span>
              <span class="tl-status" :class="statusClass(e.status_code)">
                {{ e.status_code ?? '—' }}
              </span>
            </li>
          </ol>
        </template>
        <div v-if="!timelineGroups.length && !loading" class="ohs-empty">
          No audit events match these filters.
        </div>
      </div>

      <!-- Pager -->
      <div class="pager">
        <span class="pager-info">{{ rangeStart }}–{{ rangeEnd }} of {{ fmtNum(eventCount) }}</span>
        <v-spacer />
        <v-btn icon="mdi-page-first" variant="text" size="small" :disabled="page <= 1"
               @click="gotoPage(1)" />
        <v-btn icon="mdi-chevron-left" variant="text" size="small" :disabled="page <= 1"
               @click="gotoPage(page - 1)" />
        <span class="pager-page">Page {{ page }} / {{ pageCount }}</span>
        <v-btn icon="mdi-chevron-right" variant="text" size="small" :disabled="page >= pageCount"
               @click="gotoPage(page + 1)" />
        <v-btn icon="mdi-page-last" variant="text" size="small" :disabled="page >= pageCount"
               @click="gotoPage(pageCount)" />
        <v-select v-model="pageSize" :items="[25, 50, 100, 200]" density="compact"
                  variant="outlined" rounded="lg" hide-details style="max-width:96px"
                  class="ml-3" @update:model-value="reload" />
      </div>
    </OhsPanel>

    <!-- ═══════════════ CUSTOM RANGE DIALOG ═══════════════ -->
    <v-dialog v-model="customDialog" max-width="520" attach=".audit-page">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-calendar-range" title="Custom date range"
                           subtitle="Narrow the trail to an exact period for an investigation." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="customFrom" type="date" label="From" variant="outlined"
                            density="compact" rounded="lg" hide-details />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="customTo" type="date" label="To" variant="outlined"
                            density="compact" rounded="lg" hide-details />
            </v-col>
          </v-row>
          <div class="preset-strip mt-3">
            <span class="text-caption text-medium-emphasis mr-2">Quick fill:</span>
            <v-chip v-for="p in CUSTOM_PRESETS" :key="p.value" size="x-small" variant="tonal"
                    @click="fillPreset(p.value)">{{ p.label }}</v-chip>
          </div>
          <v-alert v-if="customError" type="warning" variant="tonal" density="compact"
                   rounded="lg" class="mt-3">{{ customError }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none"
                 :disabled="!customFrom || !customTo" @click="applyCustom">Apply range</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ EVENT DRAWER ═══════════════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="620"
                         class="ohs-drawer audit-drawer">
      <div v-if="detail" class="drawer-wrap">
        <div class="drawer-head">
          <div class="drawer-head-top">
            <div>
              <div class="drawer-eyebrow">
                EVENT #{{ detail.id }} · {{ formatDateTime(detail.created_at) }}
              </div>
              <div class="drawer-title">
                {{ actionLabel(detail.action) }} · {{ moduleLabel(detail.object_type) }}
              </div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" class="drawer-close"
                   @click="drawer = false" />
          </div>
          <div class="drawer-chips">
            <span class="drawer-chip">{{ severityLabel(detail.severity) }}</span>
            <span class="drawer-chip">{{ roleLabel(detail.actor_role) || 'Anonymous' }}</span>
            <span class="drawer-chip">HTTP {{ detail.status_code ?? '—' }}</span>
            <span v-if="detail.session_id" class="drawer-chip ohs-mono">
              {{ String(detail.session_id).slice(0, 10) }}
            </span>
          </div>
        </div>

        <div class="drawer-body pa-4">
          <div class="section-title">What happened</div>
          <div class="event-headline">
            {{ detail.description || detail.object_repr || 'No description recorded.' }}
          </div>

          <div class="section-title">Actor</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Email</span><b>{{ detail.actor_email || 'Anonymous' }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Role</span><b>{{ roleLabel(detail.actor_role) || '—' }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>User ID</span>
                <b class="ohs-mono">{{ detail.actor_user_id ?? '—' }}</b>
              </div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Session</span>
                <b class="ohs-mono">{{ detail.session_id || '—' }}</b>
              </div>
            </v-col>
          </v-row>

          <div class="section-title">Target record</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Module</span><b>{{ moduleLabel(detail.object_type) }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Object ID</span>
                <b class="ohs-mono">{{ detail.object_id || '—' }}</b>
              </div>
            </v-col>
            <v-col cols="12">
              <div class="meta"><span>Representation</span><b>{{ detail.object_repr || '—' }}</b></div>
            </v-col>
          </v-row>

          <div class="section-title">Request</div>
          <v-row dense>
            <v-col cols="12" sm="4">
              <div class="meta"><span>Method</span>
                <b class="ohs-mono">{{ detail.method || '—' }}</b>
              </div>
            </v-col>
            <v-col cols="12" sm="4">
              <div class="meta"><span>Status</span>
                <b class="ohs-mono" :style="{ color: statusTextColor(detail.status_code) }">
                  {{ detail.status_code ?? '—' }}
                </b>
              </div>
            </v-col>
            <v-col cols="12" sm="4">
              <div class="meta"><span>IP address</span>
                <b class="ohs-mono">{{ detail.ip || '—' }}</b>
              </div>
            </v-col>
            <v-col cols="12">
              <div class="meta"><span>Path</span><b class="ohs-mono">{{ detail.path || '—' }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Geolocation</span>
                <b class="ohs-mono">
                  {{ detail.latitude && detail.longitude
                    ? `${Number(detail.latitude).toFixed(4)}, ${Number(detail.longitude).toFixed(4)}`
                    : 'not recorded' }}
                </b>
              </div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>User agent</span>
                <b class="ua">{{ detail.user_agent || '—' }}</b>
              </div>
            </v-col>
          </v-row>

          <div class="section-title">Payload diff</div>
          <pre class="payload">{{ prettyJson(detail.payload_diff) }}</pre>

          <template v-if="detail.extra && Object.keys(detail.extra).length">
            <div class="section-title">Context</div>
            <pre class="payload">{{ prettyJson(detail.extra) }}</pre>
          </template>

          <div class="section-title">Related events</div>
          <div v-if="relatedLoading" class="related-note">Looking up correlated events…</div>
          <div v-else-if="related.length" class="related-list">
            <button v-for="r in related" :key="r.id" type="button" class="related-row"
                    @click="openDetail(r)">
              <span class="related-time">{{ formatTime(r.created_at) }}</span>
              <span class="ohs-badge" :class="actionBadge(r.action)">{{ actionLabel(r.action) }}</span>
              <span class="related-text">{{ r.object_repr || r.description || r.path || '—' }}</span>
            </button>
          </div>
          <div v-else class="related-note">
            No other events share this actor, session or record in the selected window.
          </div>

          <div class="integrity-note">
            <v-icon size="14">mdi-lock-check-outline</v-icon>
            <span>
              Audit events are append-only. This record cannot be edited or deleted from the
              application — corrections are made by appending a new event.
            </span>
          </div>
        </div>

        <div class="drawer-foot">
          <v-btn variant="text" class="text-none" prepend-icon="mdi-content-copy"
                 @click="copyEvent">Copy JSON</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" color="primary"
                 prepend-icon="mdi-account-search-outline"
                 :disabled="!detail.actor_email" @click="filterByActor(detail.actor_email)">
            All events by this actor
          </v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2800">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import OhsHero from '~/components/ohs/OhsHero.vue'
import OhsKpi from '~/components/ohs/OhsKpi.vue'
import OhsPanel from '~/components/ohs/OhsPanel.vue'
import { formatDateTime } from '~/utils/format'

definePageMeta({ title: 'Audit Trail' })

const { $api } = useNuxtApp()

// ── State ──────────────────────────────────────────────────────────
const overview = ref({
  kpis: {
    total: 0, last_24h: 0, last_7d: 0, critical: 0, warnings: 0,
    failures: 0, distinct_actors: 0, modules: 0, retention_days: 0,
  },
  severity_mix: [], action_mix: [], module_mix: [], trend: [], hourly: [],
  top_actors: [], signals: [],
})
const refreshedAt = ref('—')

const events = ref([])
const eventCount = ref(0)
const page = ref(1)
const pageSize = ref(50)
const loading = ref(false)
const exporting = ref(null)
const view = ref('table')
const trendMode = ref('events')

const search = ref('')
const searchRef = ref(null)
const actionFilter = ref(null)
const severityFilter = ref(null)
const moduleFilter = ref(null)

// ── Date range ─────────────────────────────────────────────────────
const rangeValue = ref('30d')
const customDialog = ref(false)
const customFrom = ref('')
const customTo = ref('')
const customError = ref('')
const appliedCustom = reactive({ from: '', to: '' })

const drawer = ref(false)
const detail = ref(null)
const related = ref([])
const relatedLoading = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const TREND_MODES = [
  { value: 'events', label: 'All events' },
  { value: 'critical', label: 'Critical only' },
]

const QUICK_RANGES = [
  { value: 'today', label: 'Today', icon: 'mdi-calendar-today' },
  { value: 'yesterday', label: 'Yesterday', icon: 'mdi-calendar-arrow-left' },
  { value: '7d', label: 'Last 7 days', icon: 'mdi-calendar-week' },
  { value: '30d', label: 'Last 30 days', icon: 'mdi-calendar-month' },
  { value: '60d', label: 'Last 60 days', icon: 'mdi-calendar-month-outline' },
  { value: '90d', label: 'Last 90 days', icon: 'mdi-calendar-expand-horizontal' },
  { value: 'mtd', label: 'Month to date', icon: 'mdi-calendar-start' },
  { value: 'last_month', label: 'Last month', icon: 'mdi-calendar-arrow-left' },
  { value: 'ytd', label: 'Year to date', icon: 'mdi-calendar-end' },
]

const CUSTOM_PRESETS = [
  { value: '7d', label: '7 days' },
  { value: '30d', label: '30 days' },
  { value: '60d', label: '60 days' },
  { value: '90d', label: '90 days' },
  { value: 'mtd', label: 'This month' },
]

const ACTIONS = [
  { value: 'create', label: 'Create' },
  { value: 'update', label: 'Update' },
  { value: 'delete', label: 'Delete' },
  { value: 'view', label: 'View' },
  { value: 'login', label: 'Login' },
  { value: 'logout', label: 'Logout' },
  { value: 'export', label: 'Export' },
  { value: 'print', label: 'Print' },
  { value: 'config', label: 'Config change' },
  { value: 'action', label: 'Custom action' },
]

const SEVERITIES = [
  { value: 'info', label: 'Info' },
  { value: 'notice', label: 'Notice' },
  { value: 'warning', label: 'Warning' },
  { value: 'critical', label: 'Critical' },
]

/** Clinic module labels — falls back to a prettified key for anything unknown. */
const MODULE_META = {
  'clinic/patients': { label: 'Patients', icon: 'mdi-account-multiple', color: '#2f6dff' },
  'clinic/appointments': { label: 'Appointments', icon: 'mdi-calendar-clock', color: '#0ea5e9' },
  'clinic/consultations': { label: 'Consultations', icon: 'mdi-stethoscope', color: '#10b981' },
  'clinic/triage': { label: 'Triage', icon: 'mdi-heart-pulse', color: '#ef4444' },
  'clinic/prescriptions': { label: 'Prescriptions', icon: 'mdi-pill', color: '#a855f7' },
  'clinic/lab-orders': { label: 'Lab orders', icon: 'mdi-flask-outline', color: '#f59e0b' },
  'clinic/radiology': { label: 'Radiology', icon: 'mdi-radiology-box', color: '#8b5cf6' },
  'clinic/invoices': { label: 'Invoices', icon: 'mdi-receipt-text', color: '#14b8a6' },
  'clinic/wards': { label: 'Wards & beds', icon: 'mdi-bed', color: '#6366f1' },
  'clinic/departments': { label: 'Departments', icon: 'mdi-domain', color: '#0284c7' },
  'clinic/staff': { label: 'Staff', icon: 'mdi-account-hard-hat', color: '#b45309' },
  'clinic/consents': { label: 'Consents', icon: 'mdi-account-key', color: '#16a34a' },
  'clinic/escalations': { label: 'Escalations', icon: 'mdi-bell-alert', color: '#dc2626' },
  'accounts/user': { label: 'Users', icon: 'mdi-account-cog', color: '#7c3aed' },
  'accounts/auth': { label: 'Authentication', icon: 'mdi-login', color: '#0891b2' },
  tenants_tenant: { label: 'Tenant', icon: 'mdi-office-building', color: '#475569' },
}

const ROLE_LABELS = {
  tenant_admin: 'Tenant Admin',
  super_admin: 'Super Admin',
  clinic_admin: 'Clinic Admin',
  admin: 'Administrator',
  doctor: 'Doctor',
  clinical_officer: 'Clinical Officer',
  dentist: 'Dentist',
  nurse: 'Nurse',
  midwife: 'Midwife',
  receptionist: 'Receptionist',
  lab_tech: 'Lab Technician',
  radiologist: 'Radiologist',
  pharmacist: 'Pharmacist',
  cashier: 'Cashier',
}

// ── Derived ────────────────────────────────────────────────────────
const kpis = computed(() => overview.value.kpis || {})
const signals = computed(() => overview.value.signals || [])
const topActors = computed(() => overview.value.top_actors || [])
const hourly = computed(() => overview.value.hourly || [])
const moduleMix = computed(() => {
  const rows = overview.value.module_mix || []
  const max = Math.max(1, ...rows.map(r => r.count))
  return rows.map(r => ({ ...r, pct: Math.max(4, Math.round((r.count / max) * 100)) }))
})

const moduleOptions = computed(() =>
  moduleMix.value.map(m => ({ label: moduleLabel(m.object_type), value: m.object_type })))

const hasFilters = computed(() =>
  !!search.value || !!actionFilter.value || !!severityFilter.value ||
  !!moduleFilter.value || rangeValue.value !== '30d')

const trendRaw = computed(() => overview.value.trend || [])
const trendValues = computed(() => trendRaw.value.map(p => p.count))
const trendLabels = computed(() => trendRaw.value.map(p => p.date))

const trendStats = computed(() => {
  const vals = trendValues.value
  if (!vals.length) return { avg: '—', peak: 0, trough: 0, delta: 0 }
  const sum = vals.reduce((a, b) => a + b, 0)
  const mid = Math.floor(vals.length / 2)
  const older = vals.slice(0, mid).reduce((a, b) => a + b, 0)
  const newer = vals.slice(mid).reduce((a, b) => a + b, 0)
  const delta = older ? Math.round(((newer - older) / older) * 100) : (newer ? 100 : 0)
  return {
    avg: (sum / vals.length).toFixed(1),
    peak: Math.max(...vals),
    trough: Math.min(...vals),
    delta,
  }
})

const SEVERITY_META = [
  { key: 'info', label: 'Info', color: '#0ea5e9' },
  { key: 'notice', label: 'Notice', color: '#6366f1' },
  { key: 'warning', label: 'Warning', color: '#f59e0b' },
  { key: 'critical', label: 'Critical', color: '#ef4444' },
]

const severitySegments = computed(() => {
  const mix = overview.value.severity_mix || []
  const total = mix.reduce((a, b) => a + (b.count || 0), 0) || 1
  return SEVERITY_META.map((m) => {
    const count = mix.find(x => x.severity === m.key)?.count || 0
    return { ...m, count, pct: Math.round((count / total) * 100) }
  })
})

const actionMix = computed(() => {
  const rows = (overview.value.action_mix || []).slice(0, 6)
  const max = Math.max(1, ...rows.map(r => r.count))
  return rows.map(r => ({ ...r, pct: Math.round((r.count / max) * 100) }))
})

const posture = computed(() => {
  const k = kpis.value
  const high = signals.value.filter(s => s.severity === 'high').length
  let score = 100
  score -= Math.min(30, (Number(k.critical) || 0) * 4)
  score -= Math.min(18, Math.floor((Number(k.failures) || 0) / 3))
  score -= high * 7
  score = Math.max(15, Math.min(100, Math.round(score)))
  if (score >= 85) return { score, label: 'Strong' }
  if (score >= 65) return { score, label: 'Watch' }
  return { score, label: 'At risk' }
})

const peakHour = computed(() => {
  const rows = hourly.value
  if (!rows.length) return '—'
  const top = rows.reduce((a, b) => (b.count > a.count ? b : a), rows[0])
  return `${String(top.hour).padStart(2, '0')}:00`
})

const pageCount = computed(() => Math.max(1, Math.ceil(eventCount.value / pageSize.value)))
const rangeStart = computed(() => (eventCount.value ? (page.value - 1) * pageSize.value + 1 : 0))
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, eventCount.value))

/** Group the current page into day buckets for the timeline view. */
const timelineGroups = computed(() => {
  const groups = []
  for (const e of events.value) {
    const day = String(e.created_at || '').slice(0, 10)
    const last = groups[groups.length - 1]
    if (last && last.day === day) last.items.push(e)
    else groups.push({ day, label: dayLabel(day), items: [e] })
  }
  return groups
})

// ── Formatting ─────────────────────────────────────────────────────
function fmtNum(v) {
  return Number(v || 0).toLocaleString()
}

function titleCase(s) {
  if (!s) return ''
  return String(s).replace(/[_-]/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

function moduleLabel(key) {
  if (!key) return '—'
  return MODULE_META[key]?.label || titleCase(String(key).split('/').pop())
}
function moduleIcon(key) {
  return MODULE_META[key]?.icon || 'mdi-shape-outline'
}
function moduleColor(key) {
  return MODULE_META[key]?.color || '#64748b'
}
function actionLabel(action) {
  return ACTIONS.find(a => a.value === action)?.label || titleCase(action)
}
function roleLabel(role) {
  if (!role) return ''
  return ROLE_LABELS[role] || titleCase(role)
}
function actionColor(action) {
  return {
    create: '#16a34a', update: '#0284c7', delete: '#dc2626', view: '#64748b',
    login: '#7c3aed', logout: '#94a3b8', export: '#b45309', print: '#0891b2',
    config: '#f59e0b', action: '#6366f1',
  }[action] || '#64748b'
}
function actionBadge(action) {
  return {
    create: 'ohs-badge--ok', update: 'ohs-badge--info', delete: 'ohs-badge--err',
    view: 'ohs-badge--muted', login: 'ohs-badge--info', logout: 'ohs-badge--muted',
    export: 'ohs-badge--warn', print: 'ohs-badge--info', config: 'ohs-badge--warn',
    action: 'ohs-badge--info',
  }[action] || 'ohs-badge--muted'
}
function severityLabel(sev) {
  return { info: 'Info', notice: 'Notice', warning: 'Warning', critical: 'Critical' }[sev]
    || titleCase(sev)
}
function severityBadge(sev) {
  return {
    info: 'ohs-badge--info', notice: 'ohs-badge--info',
    warning: 'ohs-badge--warn', critical: 'ohs-badge--err',
  }[sev] || 'ohs-badge--muted'
}
function statusClass(code) {
  if (!code) return 'status-pill--muted'
  if (code >= 500) return 'status-pill--err'
  if (code >= 400) return 'status-pill--warn'
  if (code >= 300) return 'status-pill--info'
  return 'status-pill--ok'
}
function statusTextColor(code) {
  if (!code) return 'inherit'
  if (code >= 500) return '#dc2626'
  if (code >= 400) return '#b45309'
  if (code >= 300) return '#0284c7'
  return '#16a34a'
}
function shortEmail(email) {
  if (!email) return ''
  const [name, domain] = String(email).split('@')
  if (!domain) return email
  return name.split(/[._-]/).map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(' ') || name
}
function initialsOf(email) {
  const n = shortEmail(email)
  if (!n) return '—'
  return n.split(' ').filter(Boolean).slice(0, 2).map(p => p[0].toUpperCase()).join('')
}
function actorStyle(a) {
  const hue = a.role === 'tenant_admin' || a.role === 'clinic_admin' ? '#b45309'
    : a.role === 'doctor' ? '#2f6dff'
      : a.role === 'nurse' || a.role === 'midwife' ? '#0891b2'
        : a.role === 'pharmacist' ? '#7c3aed'
          : a.role === 'lab_tech' || a.role === 'radiologist' ? '#ea580c' : '#0284c7'
  return { background: `${hue}1f`, color: hue }
}
function actorDotStyle(e) {
  const hue = actionColor(e.action)
  return { background: `${hue}1f`, color: hue }
}
function hourPct(count) {
  const max = Math.max(1, ...hourly.value.map(h => h.count))
  if (!count) return 0
  return Math.max(8, Math.round((count / max) * 100))
}
function prettyJson(value) {
  try {
    if (!value || (typeof value === 'object' && !Object.keys(value).length)) return '{}'
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

function formatTime(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}

function relativeDays(iso) {
  if (!iso) return '—'
  const ts = new Date(iso).getTime()
  if (Number.isNaN(ts)) return '—'
  const mins = Math.floor((Date.now() - ts) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins} min ago`
  const h = Math.floor(mins / 60)
  if (h < 24) return `${h}h ago`
  const d = Math.floor(h / 24)
  return `${d}d ago`
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function dayLabel(iso) {
  if (!iso) return '—'
  const d = new Date(`${iso}T00:00:00`)
  if (Number.isNaN(d.getTime())) return iso
  const today = todayISO()
  if (iso === today) return 'Today'
  if (iso === shiftDays(today, -1)) return 'Yesterday'
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`
}

function shortDate(iso) {
  if (!iso) return '—'
  const [y, m, d] = iso.split('-')
  return `${Number(d)} ${MONTHS[Number(m) - 1]} ${y.slice(2)}`
}

// ── Date range helpers ─────────────────────────────────────────────
function pad2(n) {
  return String(n).padStart(2, '0')
}
function isoOf(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}
function todayISO() {
  return isoOf(new Date())
}
function shiftDays(iso, n) {
  const d = new Date(`${iso}T00:00:00`)
  d.setDate(d.getDate() + n)
  return isoOf(d)
}

function boundsFor(value) {
  const today = todayISO()
  switch (value) {
    case 'today':
      return { from: today, to: today }
    case 'yesterday': {
      const y = shiftDays(today, -1)
      return { from: y, to: y }
    }
    case '7d':
      return { from: shiftDays(today, -6), to: today }
    case '30d':
      return { from: shiftDays(today, -29), to: today }
    case '60d':
      return { from: shiftDays(today, -59), to: today }
    case '90d':
      return { from: shiftDays(today, -89), to: today }
    case 'mtd':
      return { from: `${today.slice(0, 8)}01`, to: today }
    case 'last_month': {
      const d = new Date(`${today}T00:00:00`)
      const first = new Date(d.getFullYear(), d.getMonth() - 1, 1)
      const last = new Date(d.getFullYear(), d.getMonth(), 0)
      return { from: isoOf(first), to: isoOf(last) }
    }
    case 'ytd':
      return { from: `${today.slice(0, 4)}-01-01`, to: today }
    case 'custom':
      return {
        from: appliedCustom.from || shiftDays(today, -29),
        to: appliedCustom.to || today,
      }
    default:
      return { from: '', to: '' }
  }
}

const activeBounds = computed(() => boundsFor(rangeValue.value))

const rangeLabel = computed(() => {
  if (rangeValue.value === 'custom') return 'Custom range'
  if (rangeValue.value === 'all') return 'All time'
  return QUICK_RANGES.find(r => r.value === rangeValue.value)?.label || 'Last 30 days'
})

const rangeSpanLabel = computed(() => {
  const { from, to } = activeBounds.value
  if (!from && !to) return 'All time'
  if (from === to) return shortDate(from)
  return `${shortDate(from)} – ${shortDate(to)}`
})

function applyRange(value) {
  rangeValue.value = value
  page.value = 1
  loadAll()
}

function openCustom() {
  customError.value = ''
  const { from, to } = activeBounds.value
  customFrom.value = from || shiftDays(todayISO(), -29)
  customTo.value = to || todayISO()
  customDialog.value = true
}

function fillPreset(value) {
  const { from, to } = boundsFor(value)
  customFrom.value = from
  customTo.value = to
  customError.value = ''
}

function applyCustom() {
  if (!customFrom.value || !customTo.value) return
  if (customFrom.value > customTo.value) {
    customError.value = 'The start date must be on or before the end date.'
    return
  }
  appliedCustom.from = customFrom.value
  appliedCustom.to = customTo.value
  rangeValue.value = 'custom'
  customDialog.value = false
  page.value = 1
  loadAll()
}

// ── Data loading ───────────────────────────────────────────────────
let debounceTimer = null
function debouncedLoad() {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    page.value = 1
    loadEvents()
  }, 320)
}

function rangeParams() {
  const { from, to } = activeBounds.value
  const params = {}
  if (from) params.created_at__gte = `${from}T00:00:00`
  if (to) params.created_at__lte = `${to}T23:59:59`
  return params
}

function overviewParams() {
  const params = rangeParams()
  if (rangeValue.value === 'all') {
    const retained = Number(kpis.value.retention_days || 0) + 1
    params.trend_days = Math.min(180, Math.max(30, retained))
  }
  return params
}

async function loadOverview() {
  try {
    const { data } = await $api.get('/audit/events/security-overview/', {
      params: overviewParams(),
    })
    overview.value = data
    refreshedAt.value = new Date().toLocaleTimeString(undefined, {
      hour: '2-digit', minute: '2-digit',
    })
  } catch {
    /* keep the previous snapshot */
  }
}

function buildParams() {
  const params = {
    page: page.value,
    page_size: pageSize.value,
    ordering: '-created_at',
    ...rangeParams(),
  }
  if (search.value) params.search = search.value
  if (actionFilter.value) params.action = actionFilter.value
  if (severityFilter.value) params.severity = severityFilter.value
  if (moduleFilter.value) params.object_type = moduleFilter.value
  return params
}

async function loadEvents() {
  loading.value = true
  try {
    const { data } = await $api.get('/audit/events/', { params: buildParams() })
    events.value = data?.results || data || []
    eventCount.value = data?.count ?? events.value.length
  } catch (e) {
    events.value = []
    eventCount.value = 0
    snack.show = true
    snack.color = 'error'
    snack.text = e?.response?.data?.detail
      || 'Could not load the audit trail — administrator access is required.'
  } finally {
    loading.value = false
  }
}

async function loadAll() {
  await Promise.all([loadOverview(), loadEvents()])
}

function reload() {
  page.value = 1
  loadEvents()
}

function gotoPage(p) {
  page.value = Math.min(Math.max(1, p), pageCount.value)
  loadEvents()
}

function clearFilters() {
  search.value = ''
  actionFilter.value = null
  severityFilter.value = null
  moduleFilter.value = null
  rangeValue.value = '30d'
  appliedCustom.from = ''
  appliedCustom.to = ''
  page.value = 1
  loadAll()
}

function toggleModule(key) {
  moduleFilter.value = moduleFilter.value === key ? null : key
  reload()
}

/** Jump to a filtered slice that corresponds to a derived signal. */
function applySignal(kind) {
  const base = { action: null, severity: null }
  if (kind === 'critical') base.severity = 'critical'
  else if (kind === 'auth') { base.action = 'login'; base.severity = 'warning' }
  else if (kind === 'deletion') base.action = 'delete'
  else if (kind === 'export') base.action = 'export'
  else if (kind === 'config') base.action = 'config'
  else {
    snack.show = true
    snack.color = 'info'
    snack.text = 'Use the date range menu to inspect after-hours activity.'
    return
  }
  actionFilter.value = base.action
  severityFilter.value = base.severity
  page.value = 1
  loadEvents()
}

// ── Drawer ─────────────────────────────────────────────────────────
async function openDetail(e) {
  detail.value = e
  drawer.value = true
  related.value = []
  relatedLoading.value = true
  try {
    const params = { page_size: 8, ordering: '-created_at' }
    if (e.session_id) params.session_id = e.session_id
    else if (e.actor_email) params.actor_email = e.actor_email
    else if (e.object_type) params.object_type = e.object_type
    const { data } = await $api.get('/audit/events/', { params })
    const rows = data?.results || data || []
    related.value = rows.filter(r => r.id !== e.id).slice(0, 6)
  } catch {
    related.value = []
  } finally {
    relatedLoading.value = false
  }
}

function filterByActor(email) {
  search.value = email
  drawer.value = false
  reload()
}

async function copyEvent() {
  try {
    await navigator.clipboard.writeText(JSON.stringify(detail.value, null, 2))
    snack.show = true
    snack.color = 'success'
    snack.text = 'Event JSON copied to clipboard.'
  } catch {
    snack.show = true
    snack.color = 'error'
    snack.text = 'Clipboard unavailable in this browser.'
  }
}

// ── Export ─────────────────────────────────────────────────────────
async function exportLog(format) {
  exporting.value = format
  try {
    const params = buildParams()
    delete params.page
    delete params.page_size
    // `fmt`, not `format` — DRF reserves `?format=` for its renderer override.
    params.fmt = format
    params.limit = 20000
    const { data } = await $api.get('/audit/events/export/', { params, responseType: 'blob' })
    const blob = data instanceof Blob
      ? data
      : new Blob([data], { type: format === 'json' ? 'application/json' : 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `clinic-audit-${todayISO()}.${format === 'json' ? 'json' : 'csv'}`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
    snack.show = true
    snack.color = 'success'
    snack.text = `Audit trail exported as ${format.toUpperCase()}.`
  } catch {
    snack.show = true
    snack.color = 'error'
    snack.text = 'Export failed — administrator access is required.'
  } finally {
    exporting.value = null
  }
}

// ── Keyboard shortcuts ─────────────────────────────────────────────
function onKeydown(e) {
  const tag = (e.target?.tagName || '').toLowerCase()
  const typing = tag === 'input' || tag === 'textarea' || e.target?.isContentEditable
  if (e.key === '/' && !typing) {
    e.preventDefault()
    searchRef.value?.focus?.()
  }
  if (e.key === 'Escape' && drawer.value) drawer.value = false
}

onMounted(() => {
  window.addEventListener('keydown', onKeydown)
  loadAll()
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown)
  clearTimeout(debounceTimer)
})
</script>

<style scoped>
.audit-page { min-height: 100vh; }

/* ══════════════════════════════════════════════════════════════
   Panel robustness — the shared OhsPanel is a plain block with
   `overflow: hidden`. Inside a `h-100` column, tall content (many
   signals, actors, beds…) was clipped or squeezed into its
   neighbours. Make every panel in this page a flex column whose
   body absorbs the leftover height and scrolls instead of
   overflowing.
   ══════════════════════════════════════════════════════════════ */
.audit-page :deep(.ohs-panel) {
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.audit-page :deep(.ohs-panel-head) { flex: 0 0 auto; }
.audit-page :deep(.ohs-panel-body) {
  flex: 1 1 auto;
  min-height: 0;
  overflow: auto;
  overscroll-behavior: contain;
}
.audit-page :deep(.ohs-panel-title),
.audit-page :deep(.ohs-panel-sub) { overflow-wrap: anywhere; }

/* Every list row keeps its intrinsic height — no squashing. */
.signal-row, .actor-row, .module-tile, .hour-cell, .related-row { flex-shrink: 0; }

/* ── Trend tabs ── */
.trend-tabs { display: inline-flex; gap: 2px; padding: 2px; border-radius: 9px; background: rgba(var(--v-theme-on-surface), 0.05); }
.trend-tab {
  border: 0; background: transparent; cursor: pointer;
  padding: 4px 9px; border-radius: 7px;
  font-size: 10.5px; font-weight: 700; letter-spacing: 0;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.trend-tab--on { background: rgb(var(--v-theme-surface)); color: rgb(var(--v-theme-primary)); box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12); }

/* ── Trend footer ── */
.trend-foot {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
@media (min-width: 700px) { .trend-foot { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
.trend-stat { display: flex; flex-direction: column; gap: 1px; }
.ts-label {
  font-size: 9.5px; font-weight: 750; letter-spacing: 0.7px;
  text-transform: uppercase; color: rgba(var(--v-theme-on-surface), 0.55);
}
.ts-value { font-size: 15px; font-weight: 800; color: rgb(var(--v-theme-on-surface)); }

/* ── Composition ── */
.mix-block + .mix-block { margin-top: 4px; }
.mix-title {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.8px;
  text-transform: uppercase; color: rgba(var(--v-theme-on-surface), 0.55);
  margin-bottom: 7px;
}
.sev-bar { display: flex; height: 9px; border-radius: 999px; overflow: hidden; background: rgba(var(--v-theme-on-surface), 0.07); }
.sev-seg { display: block; height: 100%; }
.sev-legend { display: flex; flex-wrap: wrap; gap: 6px 14px; margin-top: 8px; }
.sev-item {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 10.5px; font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.sev-item--btn {
  border: 0; background: transparent; cursor: pointer;
  padding: 2px 5px; border-radius: 6px;
}
.sev-item--btn:disabled { cursor: default; opacity: 0.5; }
.sev-item--on { background: rgba(var(--v-theme-primary), 0.1); color: rgb(var(--v-theme-primary)); }
.sev-item b { color: rgb(var(--v-theme-on-surface)); font-weight: 800; }
.sev-item--on b { color: inherit; }
.sev-dot { width: 7px; height: 7px; border-radius: 50%; }
.mix-row { display: flex; align-items: center; gap: 9px; padding: 3px 0; }
.mix-label {
  width: 86px; flex-shrink: 0; font-size: 11px; font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.78);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.mix-count { margin-left: auto; font-size: 11px; font-weight: 800; font-variant-numeric: tabular-nums; color: rgb(var(--v-theme-on-surface)); }

/* ── Signals ── */
.signal-list { display: flex; flex-direction: column; }
.signal-row {
  display: flex; align-items: center; gap: 10px;
  width: 100%; min-height: 46px; text-align: left; border: 0; cursor: pointer;
  padding: 9px 14px;
  background: transparent;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.signal-row:hover { background: rgba(var(--v-theme-primary), 0.04); }
.signal-row:last-of-type { border-bottom: 0; }
.signal-rail { width: 3px; flex: 0 0 3px; align-self: stretch; min-height: 26px; border-radius: 3px; background: #94a3b8; }
.signal-rail--high { background: #dc2626; }
.signal-rail--medium { background: #f59e0b; }
.signal-rail--low { background: #0ea5e9; }
.signal-body { flex: 1 1 auto; min-width: 0; }
.signal-title {
  font-size: 12px; font-weight: 700; line-height: 1.3;
  color: rgb(var(--v-theme-on-surface));
  overflow-wrap: anywhere;
}
.signal-detail {
  font-size: 10.5px; line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.62);
  overflow-wrap: anywhere;
}
.signal-row :deep(.ohs-badge) { flex: 0 0 auto; white-space: nowrap; }
.signal-foot {
  flex: 0 0 auto;
  padding: 7px 14px; font-size: 9.5px; font-weight: 600;
  letter-spacing: 0.4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}

/* ── Actors ── */
.actor-list { display: flex; flex-direction: column; gap: 2px; }
.actor-row {
  display: flex; align-items: center; gap: 9px;
  width: 100%; min-height: 38px; text-align: left; border: 0; cursor: pointer;
  padding: 5px 6px; border-radius: 9px; background: transparent;
}
.actor-row:hover { background: rgba(var(--v-theme-primary), 0.05); }
.actor-avatar {
  width: 28px; height: 28px; flex: 0 0 28px;
  display: grid; place-items: center; border-radius: 50%;
  font-size: 10px; font-weight: 800;
}
.actor-id { flex: 1 1 auto; min-width: 0; line-height: 1.25; }
.actor-name {
  font-size: 11.5px; font-weight: 700; color: rgb(var(--v-theme-on-surface));
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.actor-role {
  font-size: 10px; color: rgba(var(--v-theme-on-surface), 0.58);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.actor-count {
  flex: 0 0 auto; min-width: 26px; text-align: right;
  font-size: 12px; font-weight: 800; font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-primary));
}

/* ── Hourly ── */
.hour-grid {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: 3px;
}
.hour-cell {
  position: relative; height: 42px; border-radius: 4px;
  display: flex; align-items: flex-end; overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.055);
}
.hour-cell--night { box-shadow: inset 0 0 0 1px rgba(99, 102, 241, 0.55); }
.hour-cell--active { background: rgba(var(--v-theme-on-surface), 0.085); }
.hour-bar {
  width: 100%; height: 0; border-radius: 3px;
  background: linear-gradient(180deg, #818cf8, #4f46e5);
}
.hour-axis {
  display: flex; justify-content: space-between; margin-top: 4px;
  font-size: 9px; font-weight: 700; color: rgba(var(--v-theme-on-surface), 0.45);
}
.hour-note { font-size: 10.5px; line-height: 1.5; color: rgba(var(--v-theme-on-surface), 0.6); }

/* ── Module coverage ── */
.module-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
@media (min-width: 760px) { .module-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
@media (min-width: 1200px) { .module-grid { grid-template-columns: repeat(6, minmax(0, 1fr)); } }
.module-tile {
  display: flex; flex-direction: column; gap: 5px;
  min-width: 0;
  padding: 9px 10px; border-radius: 11px; cursor: pointer;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgba(var(--v-theme-on-surface), 0.015);
  text-align: left; transition: transform 0.16s, border-color 0.16s, background 0.16s;
}
.module-tile:hover { transform: translateY(-1px); border-color: rgba(var(--v-theme-primary), 0.35); }
.module-tile--active { border-color: rgba(var(--v-theme-primary), 0.6); background: rgba(var(--v-theme-primary), 0.06); }
.module-top { display: flex; align-items: center; justify-content: space-between; gap: 4px; min-width: 0; }
.module-icon { display: grid; place-items: center; flex: 0 0 auto; }
.module-count {
  font-size: 12.5px; font-weight: 800; font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-on-surface));
}
.module-name {
  font-size: 10.5px; font-weight: 650; color: rgba(var(--v-theme-on-surface), 0.72);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.module-tile :deep(.ohs-meter) { margin-top: auto; }

/* ── View toggle ── */
.view-toggle { display: inline-flex; gap: 2px; padding: 2px; border-radius: 9px; background: rgba(var(--v-theme-on-surface), 0.05); }
.view-btn {
  display: inline-flex; align-items: center; gap: 4px;
  border: 0; background: transparent; cursor: pointer;
  padding: 4px 9px; border-radius: 7px;
  font-size: 10.5px; font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.view-btn--on { background: rgb(var(--v-theme-surface)); color: rgb(var(--v-theme-primary)); box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12); }

/* ── Range pill + filter summary ── */
.range-pill {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 5px 10px; border-radius: 999px;
  font-size: 10.5px; font-weight: 700; white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.68);
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.filter-summary {
  display: flex; align-items: center; flex-wrap: wrap; gap: 6px;
  padding: 7px 14px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-primary), 0.03);
}
.fs-label {
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: rgba(var(--v-theme-on-surface), 0.5);
}

/* ── Audit table ── */
.audit-scroll { max-height: 62vh; }
.audit-table thead th { position: sticky; top: 0; z-index: 1; }
.row-click { cursor: pointer; }
.cell-time { font-size: 11.5px; font-weight: 650; color: rgb(var(--v-theme-on-surface)); white-space: nowrap; }
.cell-sub { font-size: 10px; color: rgba(var(--v-theme-on-surface), 0.55); }
.cell-actor { display: flex; align-items: center; gap: 6px; }
.actor-dot {
  width: 20px; height: 20px; flex-shrink: 0;
  display: grid; place-items: center; border-radius: 50%;
  font-size: 8.5px; font-weight: 800;
}
.cell-actor-name { font-size: 11.5px; font-weight: 650; color: rgb(var(--v-theme-on-surface)); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cell-record {
  font-size: 11.5px; font-weight: 600; color: rgb(var(--v-theme-on-surface));
  max-width: 340px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cell-module { font-size: 10.5px; font-weight: 600; color: rgba(var(--v-theme-on-surface), 0.68); }
.status-pill {
  display: inline-flex; align-items: center; justify-content: center;
  min-width: 38px; padding: 2px 7px; border-radius: 999px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 10px; font-weight: 700;
}
.status-pill--ok { background: rgba(22, 163, 74, 0.12); color: #15803d; }
.status-pill--info { background: rgba(2, 132, 199, 0.12); color: #0369a1; }
.status-pill--warn { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.status-pill--err { background: rgba(220, 38, 38, 0.12); color: #b91c1c; }
.status-pill--muted { background: rgba(100, 116, 139, 0.12); color: #475569; }
.ohs-empty-sub { font-size: 10.5px; opacity: 0.7; margin-top: 3px; }

/* ── Timeline view ── */
.timeline-wrap { padding: 6px 14px 12px; max-height: 62vh; overflow: auto; }
.tl-day { display: flex; align-items: center; gap: 9px; margin: 12px 0 6px; }
.tl-day:first-child { margin-top: 4px; }
.tl-day-label {
  font-size: 10px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: rgb(var(--v-theme-on-surface));
}
.tl-day-count { font-size: 10px; font-weight: 650; color: rgba(var(--v-theme-on-surface), 0.5); }
.tl-day-rule { flex: 1 1 auto; height: 1px; background: rgba(var(--v-theme-on-surface), 0.1); }
.tl-list { list-style: none; margin: 0; padding: 0 0 0 8px; border-left: 1px solid rgba(var(--v-theme-on-surface), 0.12); }
.tl-item {
  position: relative;
  display: flex; align-items: center; gap: 8px;
  padding: 5px 6px 5px 14px; margin-left: 2px;
  border-radius: 8px; cursor: pointer;
}
.tl-item:hover { background: rgba(var(--v-theme-primary), 0.05); }
.tl-dot {
  position: absolute; left: -5px; top: 50%; transform: translateY(-50%);
  width: 8px; height: 8px; border-radius: 50%;
  background: #94a3b8; box-shadow: 0 0 0 2px rgb(var(--v-theme-surface));
}
.tl-item--critical .tl-dot { background: #dc2626; }
.tl-item--warning .tl-dot { background: #f59e0b; }
.tl-item--notice .tl-dot { background: #6366f1; }
.tl-time {
  flex-shrink: 0; width: 58px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 10px; font-weight: 700; color: rgba(var(--v-theme-on-surface), 0.6);
}
.tl-badge {
  flex-shrink: 0; padding: 1px 6px; border-radius: 5px;
  border: 1px solid transparent;
  font-size: 9px; font-weight: 800; letter-spacing: 0.4px; text-transform: uppercase;
}
.tl-text {
  flex: 1 1 auto; min-width: 0;
  font-size: 11.5px; font-weight: 600; color: rgb(var(--v-theme-on-surface));
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.tl-actor { flex-shrink: 0; font-size: 10px; color: rgba(var(--v-theme-on-surface), 0.55); }
.tl-status {
  flex-shrink: 0; padding: 0 5px; border-radius: 999px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 9px; font-weight: 700;
}
.tl-status.status-pill--ok { color: #15803d; }
.tl-status.status-pill--err { color: #b91c1c; }

/* ── Pager ── */
.pager {
  display: flex; align-items: center; gap: 4px;
  padding: 8px 14px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.pager-info, .pager-page {
  font-size: 10.5px; font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.62);
  font-variant-numeric: tabular-nums;
}

/* ── Drawer ── */
.drawer-wrap { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.drawer-body { flex: 1 1 auto; min-height: 0; overflow: auto; }
.drawer-head { flex: 0 0 auto; padding: 16px; color: #fff; background: var(--brand-gradient, linear-gradient(120deg, #143ce1, #2f6dff)); }
.drawer-head-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; }
.drawer-eyebrow { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 10px; color: rgba(255, 255, 255, 0.82); }
.drawer-title { font-size: 17px; font-weight: 800; line-height: 1.2; margin-top: 2px; }
.drawer-close { color: #fff !important; }
.drawer-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 9px; }
.drawer-chip {
  padding: 2px 8px; border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.24);
  font-size: 10px; font-weight: 700;
}
.drawer-foot {
  flex: 0 0 auto; display: flex; align-items: center; gap: 6px;
  padding: 8px 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.meta { display: flex; flex-direction: column; gap: 1px; }
.meta span {
  font-size: 9px; font-weight: 800; letter-spacing: 0.6px;
  text-transform: uppercase; color: rgba(var(--v-theme-on-surface), 0.5);
}
.meta b { font-size: 12.5px; font-weight: 600; word-break: break-word; }
.meta .ua { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.6); }
.section-title {
  margin: 16px 0 6px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.8px;
  text-transform: uppercase; color: rgba(var(--v-theme-on-surface), 0.5);
}
.section-title:first-child { margin-top: 0; }
.event-headline {
  font-size: 13px; font-weight: 650; line-height: 1.45;
  padding: 9px 11px; border-radius: 10px;
  background: rgba(var(--v-theme-primary), 0.055);
  border: 1px solid rgba(var(--v-theme-primary), 0.16);
}
.payload {
  margin: 0; padding: 10px 12px; border-radius: 10px;
  background: rgba(var(--v-theme-on-surface), 0.04);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 10.5px; line-height: 1.55;
  max-height: 220px; overflow: auto;
  white-space: pre-wrap; word-break: break-word;
}
.related-list { display: flex; flex-direction: column; gap: 3px; }
.related-row {
  display: flex; align-items: center; gap: 8px;
  width: 100%; text-align: left; cursor: pointer;
  padding: 5px 7px; border-radius: 8px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: transparent;
}
.related-row:hover { background: rgba(var(--v-theme-primary), 0.05); }
.related-time {
  flex-shrink: 0; width: 56px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 9.5px; font-weight: 700; color: rgba(var(--v-theme-on-surface), 0.6);
}
.related-text {
  flex: 1 1 auto; min-width: 0;
  font-size: 11px; font-weight: 600; color: rgb(var(--v-theme-on-surface));
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.related-note { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.58); }
.integrity-note {
  display: flex; align-items: flex-start; gap: 7px;
  margin-top: 16px; padding: 9px 11px; border-radius: 10px;
  font-size: 10.5px; line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.68);
  background: rgba(22, 163, 74, 0.06);
  border: 1px solid rgba(22, 163, 74, 0.22);
}
.preset-strip { display: flex; align-items: center; flex-wrap: wrap; gap: 6px; }

/* ── Responsive ── */
@media (max-width: 719px) {
  .tl-actor, .tl-status { display: none; }
  .range-pill { display: none; }
  .cell-record { max-width: 160px; }
}
</style>
