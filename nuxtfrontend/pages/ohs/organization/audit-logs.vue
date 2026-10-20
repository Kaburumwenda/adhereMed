<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-shield-search"
      eyebrow="Security & settings · Governance"
      title="Audit Logs"
      subtitle="An append-only record of every change made in this safety system — who acted, on which record, from where, and whether it succeeded."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-file-delimited-outline"
               :loading="exporting" @click="exportLog('csv')">Export CSV</v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-code-json"
               :loading="exporting" @click="exportLog('json')">JSON</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-refresh"
               :loading="loading" @click="loadAll">Refresh</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-database-clock</v-icon>
        <b>{{ fmtNum(overview.kpis.total) }}</b> events retained</span>
      <span class="ohs-chip"><v-icon size="12">mdi-history</v-icon>
        <b>{{ overview.kpis.retention_days }}</b> days of history</span>
      <span v-if="overview.kpis.critical" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ overview.kpis.critical }}</b> critical</span>
      <span v-if="overview.kpis.failures" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-cancel</v-icon>
        <b>{{ fmtNum(overview.kpis.failures) }}</b> failed requests</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Total events" :value="fmtNum(overview.kpis.total)" icon="mdi-database-eye-outline"
              tone="primary" :sub="`${overview.kpis.modules} modules covered`" />
      <OhsKpi label="Last 24 hours" :value="fmtNum(overview.kpis.last_24h)" icon="mdi-clock-fast"
              tone="info" :sub="`${fmtNum(overview.kpis.last_7d)} in 7 days`" />
      <OhsKpi label="Critical" :value="overview.kpis.critical" icon="mdi-alert-octagon-outline"
              :tone="overview.kpis.critical ? 'err' : 'ok'" sub="deletions & faults" />
      <OhsKpi label="Warnings" :value="overview.kpis.warnings" icon="mdi-alert-outline"
              :tone="overview.kpis.warnings ? 'warn' : 'ok'" sub="4xx responses" />
      <OhsKpi label="Active actors" :value="overview.kpis.distinct_actors" icon="mdi-account-multiple-outline"
              tone="primary" sub="distinct users" />
      <OhsKpi label="Failed requests" :value="fmtNum(overview.kpis.failures)" icon="mdi-cancel"
              :tone="overview.kpis.failures ? 'warn' : 'ok'" sub="blocked or errored" />
    </div>

    <!-- ═══════════ TREND + MIXES ═══════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="7">
        <OhsPanel title="Activity trend" :subtitle="`Audited events per day · ${rangeShortLabel}`"
                  icon="mdi-chart-areaspline" class="h-100">
          <SparkArea :values="trendValues" :labels="trendLabels" :height="168" color="#6366f1" />
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
              <span class="ts-label">7-day vs prior</span>
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
                    :style="{ width: s.pct + '%', background: s.color }" :title="`${s.label}: ${s.count}`" />
            </div>
            <div class="sev-legend">
              <span v-for="s in severitySegments" :key="s.key" class="sev-item">
                <i class="sev-dot" :style="{ background: s.color }" />
                {{ s.label }} <b>{{ s.count }}</b>
              </span>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="mix-block">
            <div class="mix-title">ACTIONS</div>
            <div v-for="a in actionMix" :key="a.action" class="mix-row">
              <span class="mix-label">{{ actionLabel(a.action) }}</span>
              <div class="ohs-meter" :style="{ color: actionColor(a.action) }">
                <div class="ohs-meter-fill" :style="{ width: a.pct + '%' }" />
              </div>
              <span class="mix-count">{{ a.count }}</span>
            </div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ SIGNALS + ACTORS + HOURLY ═══════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="5">
        <OhsPanel title="Security signals" subtitle="Derived from the trail — highest risk first"
                  icon="mdi-shield-alert-outline" class="h-100" flush>
          <div class="signal-list">
            <div v-for="s in overview.signals" :key="s.kind" class="signal-row">
              <span class="signal-rail" :class="`signal-rail--${s.severity}`" />
              <div class="signal-body">
                <div class="signal-title">{{ s.title }}</div>
                <div class="signal-detail">{{ s.detail }}</div>
              </div>
              <span class="ohs-badge" :class="severityBadge(s.severity)">{{ severityLabel(s.severity) }}</span>
            </div>
            <div v-if="!overview.signals.length" class="ohs-empty">
              No anomalies detected — the trail looks calm.
            </div>
            <div class="signal-foot">
              Recomputed from the live trail · refreshed {{ refreshedAt }}
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="4">
        <OhsPanel title="Most active actors" subtitle="Event volume per user" icon="mdi-account-star-outline"
                  class="h-100">
          <div v-for="a in overview.top_actors" :key="a.user_id" class="actor-row">
            <span class="actor-avatar" :style="actorStyle(a)">{{ initialsOf(a.email) }}</span>
            <div class="actor-id">
              <div class="actor-name">{{ shortEmail(a.email) }}</div>
              <div class="actor-role">{{ roleLabel(a.role) }}</div>
            </div>
            <div class="actor-count">{{ a.count }}</div>
          </div>
          <div v-if="!overview.top_actors.length" class="ohs-empty">No identified actors yet.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="3">
        <OhsPanel title="Hourly profile" subtitle="Events by hour of day" icon="mdi-clock-outline"
                  class="h-100">
          <div class="hour-grid">
            <div v-for="h in overview.hourly" :key="h.hour" class="hour-cell"
                 :style="{ background: hourColor(h.count) }"
                 :title="`${String(h.hour).padStart(2, '0')}:00 — ${h.count} events`">
              <span class="hour-bar" :style="{ height: hourPct(h.count) + '%' }" />
            </div>
          </div>
          <div class="hour-axis">
            <span>00</span><span>06</span><span>12</span><span>18</span><span>23</span>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            Peak activity at <b>{{ peakHour }}</b>. After-hours events (22:00–06:00) are
            highlighted so on-call access is easy to spot.
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ MODULE COVERAGE ═══════════ -->
    <OhsPanel title="Module coverage" subtitle="Which registers generate audit traffic"
              icon="mdi-view-grid-outline" class="mb-3">
      <div class="module-grid">
        <button v-for="m in moduleMix" :key="m.object_type" class="module-tile"
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

    <!-- ═══════════ EVENT LOG ═══════════ -->
    <OhsPanel title="Event log" :subtitle="`${fmtNum(eventCount)} events match · showing page ${page}`"
              icon="mdi-format-list-bulleted-square" flush>
      <template #actions>
        <v-menu location="bottom end" :close-on-content-click="true">
          <template #activator="{ props }">
            <v-btn v-bind="props" variant="tonal" size="small" rounded="lg" class="text-none"
                   prepend-icon="mdi-calendar-range">
              {{ rangeLabel }}
              <v-icon end size="15">mdi-chevron-down</v-icon>
            </v-btn>
          </template>
          <v-list density="compact" class="py-1" style="min-width:236px">
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

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search actor, record, path, IP…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                      rounded="lg" hide-details single-line clearable style="max-width:270px"
                      @update:model-value="debouncedLoad" />
        <v-select v-model="actionFilter" :items="actionOptions" item-title="label" item-value="value"
                  placeholder="All actions" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:170px" @update:model-value="reload" />
        <v-select v-model="severityFilter" :items="severityOptions" item-title="label"
                  item-value="value" placeholder="All severities" density="compact"
                  variant="outlined" rounded="lg" hide-details clearable style="max-width:180px"
                  @update:model-value="reload" />
        <v-select v-model="moduleFilter" :items="moduleOptions" item-title="label"
                  item-value="value" placeholder="All modules" density="compact"
                  variant="outlined" rounded="lg" hide-details clearable style="max-width:200px"
                  @update:model-value="reload" />
        <span class="range-pill" :title="rangeLabel">
          <v-icon size="13">mdi-calendar-clock</v-icon>
          {{ rangeSpanLabel }}
        </span>
        <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-filter-remove-outline"
               @click="clearFilters">Clear</v-btn>
      </div>

      <v-progress-linear v-if="loading" indeterminate color="primary" height="2" />

      <div class="ohs-scroll" style="max-height:66vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:150px">When</th>
              <th style="width:180px">Actor</th>
              <th style="width:104px">Action</th>
              <th style="width:100px">Severity</th>
              <th>Record</th>
              <th style="width:150px">Module</th>
              <th style="width:84px">Status</th>
              <th style="width:52px" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="e in events" :key="e.id" class="row-click" @click="openDetail(e)">
              <td>
                <div class="cell-time">{{ formatDateTime(e.created_at) }}</div>
                <div class="cell-sub">{{ relativeDays(e.created_at) }}</div>
              </td>
              <td>
                <div class="cell-actor">{{ shortEmail(e.actor_email) || 'Anonymous' }}</div>
                <div class="cell-sub">{{ roleLabel(e.actor_role) || '—' }}</div>
              </td>
              <td>
                <span class="ohs-badge" :class="actionBadge(e.action)">{{ actionLabel(e.action) }}</span>
              </td>
              <td>
                <span class="ohs-badge" :class="severityBadge(e.severity)">{{ severityLabel(e.severity) }}</span>
              </td>
              <td>
                <div class="cell-record">{{ e.object_repr || e.description || '—' }}</div>
                <div class="cell-sub ohs-mono">{{ e.object_id || e.path || '' }}</div>
              </td>
              <td class="cell-module">{{ moduleLabel(e.object_type) }}</td>
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
          No audit events match these filters.
        </div>
      </div>

      <div class="pager">
        <span class="pager-info">
          {{ rangeStart }}–{{ rangeEnd }} of {{ fmtNum(eventCount) }}
        </span>
        <v-spacer />
        <v-btn icon="mdi-chevron-left" variant="text" size="small" :disabled="page <= 1"
               @click="gotoPage(page - 1)" />
        <span class="pager-page">Page {{ page }} / {{ pageCount }}</span>
        <v-btn icon="mdi-chevron-right" variant="text" size="small" :disabled="page >= pageCount"
               @click="gotoPage(page + 1)" />
        <v-select v-model="pageSize" :items="[25, 50, 100, 200]" density="compact"
                  variant="outlined" rounded="lg" hide-details style="max-width:96px"
                  class="ml-3" @update:model-value="reload" />
      </div>
    </OhsPanel>

    <!-- ═══════════ CUSTOM DATE RANGE ═══════════ -->
    <v-dialog v-model="customDialog" max-width="520">
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
          <v-btn color="primary" rounded="lg" class="text-none" :disabled="!customFrom || !customTo"
                 @click="applyCustom">Apply range</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ EVENT DRAWER ═══════════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="600" class="ohs-drawer">
      <div v-if="detail" class="drawer-wrap">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color: rgba(255,255,255,.8)">
                EVENT #{{ detail.id }} · {{ formatDateTime(detail.created_at) }}
              </div>
              <div class="text-h6 font-weight-bold" style="line-height:1.2">
                {{ actionLabel(detail.action) }} · {{ moduleLabel(detail.object_type) }}
              </div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff"
                   @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="ohs-badge ohs-badge--muted"
                  style="background:rgba(255,255,255,.16); color:#fff">
              {{ severityLabel(detail.severity) }}
            </span>
            <span class="ohs-badge ohs-badge--muted"
                  style="background:rgba(255,255,255,.16); color:#fff">
              {{ roleLabel(detail.actor_role) || 'Anonymous' }}
            </span>
            <span class="ohs-badge ohs-badge--muted"
                  style="background:rgba(255,255,255,.16); color:#fff">
              HTTP {{ detail.status_code ?? '—' }}
            </span>
          </div>
        </div>

        <div class="pa-4 drawer-body">
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
              <div class="meta"><span>User ID</span><b class="ohs-mono">{{ detail.actor_user_id ?? '—' }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Session</span><b class="ohs-mono">{{ detail.session_id || '—' }}</b></div>
            </v-col>
          </v-row>

          <div class="section-title">Target record</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Module</span><b>{{ moduleLabel(detail.object_type) }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Object ID</span><b class="ohs-mono">{{ detail.object_id || '—' }}</b></div>
            </v-col>
            <v-col cols="12">
              <div class="meta"><span>Representation</span><b>{{ detail.object_repr || '—' }}</b></div>
            </v-col>
          </v-row>

          <div class="section-title">Request</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Method</span><b class="ohs-mono">{{ detail.method || '—' }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>Status</span>
                <b class="ohs-mono" :style="{ color: statusTextColor(detail.status_code) }">
                  {{ detail.status_code ?? '—' }}
                </b>
              </div>
            </v-col>
            <v-col cols="12">
              <div class="meta"><span>Path</span><b class="ohs-mono">{{ detail.path || '—' }}</b></div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="meta"><span>IP address</span><b class="ohs-mono">{{ detail.ip || '—' }}</b></div>
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
            <v-col cols="12">
              <div class="meta"><span>User agent</span><b class="ua">{{ detail.user_agent || '—' }}</b></div>
            </v-col>
          </v-row>

          <div class="section-title">Payload diff</div>
          <pre class="payload">{{ prettyJson(detail.payload_diff) }}</pre>

          <template v-if="detail.extra && Object.keys(detail.extra).length">
            <div class="section-title">Context</div>
            <pre class="payload">{{ prettyJson(detail.extra) }}</pre>
          </template>

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
          <v-btn variant="text" class="text-none" color="primary" prepend-icon="mdi-account-search-outline"
                 :disabled="!detail.actor_email" @click="filterByActor(detail.actor_email)">
            All events by this actor
          </v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Audit Logs · OHSMS' })

const { $api } = useNuxtApp()

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
const exporting = ref(false)

const search = ref('')
const actionFilter = ref(null)
const severityFilter = ref(null)
const moduleFilter = ref(null)

// ── Date range ─────────────────────────────────────────────────────────
const rangeValue = ref('30d')
const customDialog = ref(false)
const customFrom = ref('')
const customTo = ref('')
const customError = ref('')
/** The bounds that were actually applied for a custom range. */
const appliedCustom = reactive({ from: '', to: '' })

const drawer = ref(false)
const detail = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

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

const MODULE_META = {
  'ohs/hazards': { label: 'Hazard register', icon: 'mdi-alert-outline', color: '#dc2626' },
  'ohs/incidents': { label: 'Incidents & CAPA', icon: 'mdi-alert-circle-outline', color: '#ea580c' },
  'ohs/risk-assessments': { label: 'Risk assessments', icon: 'mdi-clipboard-text-outline', color: '#7c3aed' },
  'ohs/inspections': { label: 'Inspections', icon: 'mdi-clipboard-check-outline', color: '#0284c7' },
  'ohs/permits': { label: 'Permits to work', icon: 'mdi-file-document-check-outline', color: '#0891b2' },
  'ohs/equipment': { label: 'Safety equipment', icon: 'mdi-fire-extinguisher', color: '#f43f5e' },
  'ohs/documents': { label: 'Document control', icon: 'mdi-file-document-multiple-outline', color: '#6366f1' },
  'ohs/contractors': { label: 'Contractors', icon: 'mdi-account-hard-hat', color: '#b45309' },
  'ohs/meetings': { label: 'Safety committee', icon: 'mdi-account-voice', color: '#16a34a' },
  'ohs/management-reviews': { label: 'Management reviews', icon: 'mdi-clipboard-text-clock-outline', color: '#475569' },
  'ohs/training-records': { label: 'Training records', icon: 'mdi-school-outline', color: '#0d9488' },
  'ohs/health-surveillance': { label: 'Health surveillance', icon: 'mdi-heart-pulse', color: '#be123c' },
  'ohs/observations': { label: 'Observations', icon: 'mdi-eye-check-outline', color: '#65a30d' },
  'ohs/certifications': { label: 'Certifications', icon: 'mdi-certificate-outline', color: '#9333ea' },
  'ohs/sites': { label: 'Sites', icon: 'mdi-office-building-outline', color: '#334155' },
  'ohs/equipment-defects': { label: 'Equipment defects', icon: 'mdi-wrench-clock-outline', color: '#dc2626' },
  staff: { label: 'Staff & access', icon: 'mdi-account-cog-outline', color: '#0284c7' },
  tenants: { label: 'Organization settings', icon: 'mdi-office-building-cog', color: '#475569' },
  accounts: { label: 'Accounts', icon: 'mdi-account-key-outline', color: '#b45309' },
  auth: { label: 'Authentication', icon: 'mdi-login-variant', color: '#7c3aed' },
}

const actionOptions = ACTIONS
const severityOptions = SEVERITIES
const moduleOptions = computed(() => overview.value.module_mix.map((m) => ({
  value: m.object_type,
  label: moduleLabel(m.object_type),
})))

// ── derived ─────────────────────────────────────────────────────────────
const trendValues = computed(() => overview.value.trend.map((t) => t.count))
const trendLabels = computed(() => overview.value.trend.map((t) => t.date))

const trendStats = computed(() => {
  const vals = trendValues.value
  if (!vals.length) return { avg: 0, peak: 0, trough: 0, delta: 0 }
  const sum = vals.reduce((a, b) => a + b, 0)
  const last7 = vals.slice(-7).reduce((a, b) => a + b, 0)
  const prev7 = vals.slice(-14, -7).reduce((a, b) => a + b, 0)
  const delta = prev7 ? Math.round(((last7 - prev7) / prev7) * 100) : 0
  return {
    avg: Math.round(sum / vals.length),
    peak: Math.max(...vals),
    trough: Math.min(...vals),
    delta,
  }
})

const SEVERITY_COLORS = {
  info: '#0284c7', notice: '#6366f1', warning: '#f59e0b', critical: '#dc2626',
}

const severitySegments = computed(() => {
  const rows = overview.value.severity_mix.filter((s) => s.count > 0)
  const total = rows.reduce((a, s) => a + s.count, 0) || 1
  return rows.map((s) => ({
    key: s.severity,
    label: severityLabel(s.severity),
    count: s.count,
    color: SEVERITY_COLORS[s.severity] || '#94a3b8',
    pct: Math.round((s.count / total) * 100),
  }))
})

const actionMix = computed(() => {
  const rows = overview.value.action_mix || []
  const top = rows.reduce((a, r) => Math.max(a, r.count), 0) || 1
  return rows.slice(0, 7).map((r) => ({
    action: r.action,
    count: r.count,
    pct: Math.round((r.count / top) * 100),
  }))
})

const moduleMix = computed(() => {
  const rows = overview.value.module_mix || []
  const top = rows.reduce((a, r) => Math.max(a, r.count), 0) || 1
  return rows.map((r) => ({
    object_type: r.object_type,
    count: r.count,
    pct: Math.round((r.count / top) * 100),
  }))
})

const peakHour = computed(() => {
  const rows = overview.value.hourly
  if (!rows.length) return '—'
  const top = rows.reduce((a, b) => (b.count > a.count ? b : a), rows[0])
  return `${String(top.hour).padStart(2, '0')}:00`
})

const pageCount = computed(() => Math.max(1, Math.ceil(eventCount.value / pageSize.value)))
const rangeStart = computed(() => (eventCount.value ? (page.value - 1) * pageSize.value + 1 : 0))
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, eventCount.value))

// ── formatting ──────────────────────────────────────────────────────────
function fmtNum(v) {
  return Number(v || 0).toLocaleString()
}
function moduleLabel(key) {
  if (!key) return '—'
  return MODULE_META[key]?.label || titleCase(key.replace(/^ohs\//, ''))
}
function moduleIcon(key) {
  return MODULE_META[key]?.icon || 'mdi-shape-outline'
}
function moduleColor(key) {
  return MODULE_META[key]?.color || '#64748b'
}
function actionLabel(action) {
  return ACTIONS.find((a) => a.value === action)?.label || titleCase(action)
}
const ROLE_LABELS = {
  tenant_admin: 'Tenant Admin',
  super_admin: 'Super Admin',
  admin: 'Administrator',
  hse_manager: 'HSE Manager',
  safety_officer: 'Safety Officer',
  occ_health_nurse: 'Occupational Health Nurse',
  supervisor: 'Supervisor',
  branch_admin: 'Branch Admin',
  pharmacist: 'Pharmacist',
  cashier: 'Cashier',
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
  const pretty = name.split(/[._-]/).map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join(' ')
  return pretty || name
}
function actorStyle(a) {
  const hue = a.role === 'hse_manager' ? '#7c3aed'
    : a.role === 'safety_officer' ? '#dc2626'
      : a.role === 'occ_health_nurse' ? '#0891b2'
        : a.role === 'tenant_admin' ? '#b45309' : '#0284c7'
  return { background: `${hue}22`, color: hue }
}
function hourPct(count) {
  const max = Math.max(1, ...overview.value.hourly.map((h) => h.count))
  return Math.round((count / max) * 100)
}
function hourColor(count) {
  if (!count) return 'rgba(15, 23, 42, 0.04)'
  const pct = hourPct(count) / 100
  return `rgba(99, 102, 241, ${0.12 + pct * 0.68})`
}
function prettyJson(value) {
  try {
    if (!value || (typeof value === 'object' && !Object.keys(value).length)) return '{}'
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

// ── Date range helpers ──────────────────────────────────────────────────
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

/** Inclusive ISO bounds for a named range ('' means unbounded). */
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
  return QUICK_RANGES.find((r) => r.value === rangeValue.value)?.label || 'Last 30 days'
})

const rangeShortLabel = computed(() => rangeLabel.value.toLowerCase())

function shortDate(iso) {
  if (!iso) return '—'
  const [y, m, d] = iso.split('-')
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return `${Number(d)} ${months[Number(m) - 1]} ${y.slice(2)}`
}

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

// ── data loading ────────────────────────────────────────────────────────
let debounceTimer = null
function debouncedLoad() {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    page.value = 1
    loadEvents()
  }, 320)
}

/** Date bounds shared by the list, the aggregates and the export. */
function rangeParams() {
  const { from, to } = activeBounds.value
  const params = {}
  if (from) params.created_at__gte = `${from}T00:00:00`
  if (to) params.created_at__lte = `${to}T23:59:59`
  return params
}

/**
 * "All time" has no date bounds, so the trend window is derived from how far
 * back the trail actually goes (reported by the previous response).
 */
function overviewParams() {
  const params = rangeParams()
  if (rangeValue.value === 'all') {
    const retained = Number(overview.value.kpis.retention_days || 0) + 1
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
    // keep the previous snapshot
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
    snack.value = {
      show: true, color: 'error',
      text: e?.response?.data?.detail || 'Could not load the audit trail.',
    }
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

function openDetail(e) {
  detail.value = e
  drawer.value = true
}

function filterByActor(email) {
  search.value = email
  drawer.value = false
  reload()
}

async function copyEvent() {
  try {
    await navigator.clipboard.writeText(JSON.stringify(detail.value, null, 2))
    snack.value = { show: true, color: 'success', text: 'Event JSON copied to clipboard.' }
  } catch {
    snack.value = { show: true, color: 'error', text: 'Clipboard unavailable.' }
  }
}

async function exportLog(format) {
  exporting.value = true
  try {
    const params = buildParams()
    delete params.page
    delete params.page_size
    // `fmt`, not `format` — DRF reserves `?format=` for its renderer override.
    params.fmt = format
    params.limit = 20000
    const { data } = await $api.get('/audit/events/export/', { params, responseType: 'blob' })
    const blob = data instanceof Blob ? data : new Blob([data])
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `audit-trail-${new Date().toISOString().slice(0, 10)}.${format}`
    a.click()
    URL.revokeObjectURL(url)
    snack.value = { show: true, color: 'success', text: `Download started (${format.toUpperCase()}).` }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: 'Export failed.' }
  } finally {
    exporting.value = false
  }
}

onMounted(loadAll)
</script>

<style scoped>
/* ── trend footer ──────────────────────────────────────────────────── */
.trend-foot {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px;
  margin-top: 10px; padding-top: 10px;
  border-top: 1px solid rgba(15, 23, 42, 0.07);
}
.trend-stat { display: flex; flex-direction: column; gap: 1px; }
.ts-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.ts-value { font-size: 14px; font-weight: 800; font-variant-numeric: tabular-nums; }

/* ── composition ───────────────────────────────────────────────────── */
.mix-block { font-size: 12px; }
.mix-title {
  font-size: 9.5px; font-weight: 800; letter-spacing: .6px;
  color: rgba(var(--v-theme-on-surface), .5); margin-bottom: 6px;
}
.sev-bar {
  display: flex; height: 9px; border-radius: 999px; overflow: hidden;
  background: rgba(15, 23, 42, .06);
}
.sev-seg { height: 100%; }
.sev-legend { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 7px; }
.sev-item { display: flex; align-items: center; gap: 5px; font-size: 11px; }
.sev-item b { font-weight: 800; }
.sev-dot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; }
.mix-row { display: flex; align-items: center; gap: 9px; padding: 3px 0; }
.mix-label {
  flex: 0 0 104px; font-size: 11.5px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.mix-count {
  font-size: 11.5px; font-weight: 800; min-width: 26px; text-align: right;
  font-variant-numeric: tabular-nums;
}

/* ── signals ───────────────────────────────────────────────────────── */
.signal-list { display: flex; flex-direction: column; }
.signal-row {
  display: flex; align-items: center; gap: 10px;
  padding: 9px 14px 9px 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}
.signal-rail { width: 3px; align-self: stretch; border-radius: 0 3px 3px 0; background: #94a3b8; }
.signal-rail--high { background: #dc2626; }
.signal-rail--medium { background: #f59e0b; }
.signal-rail--low { background: #0284c7; }
.signal-body { flex: 1; min-width: 0; }
.signal-title { font-size: 12.5px; font-weight: 600; }
.signal-detail {
  font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.signal-foot {
  padding: 8px 14px; font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .45);
  border-top: 1px solid rgba(15, 23, 42, 0.06);
}

/* ── actors ────────────────────────────────────────────────────────── */
.actor-row {
  display: flex; align-items: center; gap: 9px; padding: 5px 0;
}
.actor-avatar {
  width: 28px; height: 28px; border-radius: 9px;
  display: grid; place-items: center; flex: 0 0 auto;
  font-size: 10px; font-weight: 800; letter-spacing: .3px;
}
.actor-id { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.actor-name {
  font-size: 12px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.actor-role { font-size: 10px; color: rgba(var(--v-theme-on-surface), .5); }
.actor-count {
  font-size: 12px; font-weight: 800; font-variant-numeric: tabular-nums;
}

/* ── hourly profile ────────────────────────────────────────────────── */
.hour-grid {
  display: grid; grid-template-columns: repeat(24, 1fr);
  gap: 2px; align-items: end; height: 68px;
}
.hour-cell {
  height: 100%; border-radius: 3px; display: flex; align-items: flex-end;
  overflow: hidden; position: relative;
}
.hour-bar {
  width: 100%; background: rgba(99, 102, 241, .55); border-radius: 3px;
}
.hour-axis {
  display: flex; justify-content: space-between;
  font-size: 9px; color: rgba(var(--v-theme-on-surface), .45);
  margin-top: 4px;
}

/* ── module coverage ───────────────────────────────────────────────── */
.module-grid {
  display: grid; gap: 8px;
  grid-template-columns: repeat(auto-fill, minmax(168px, 1fr));
}
.module-tile {
  text-align: left; padding: 9px 10px 8px; border-radius: 11px; cursor: pointer;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  transition: transform .15s ease, box-shadow .15s ease, border-color .15s ease;
}
.module-tile:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 16px rgba(15, 23, 42, .07);
  border-color: rgba(var(--v-theme-primary), .3);
}
.module-tile--active { border-color: rgba(var(--v-theme-primary), .55); }
.module-top {
  display: flex; align-items: center; justify-content: space-between; margin-bottom: 5px;
}
.module-icon { display: grid; place-items: center; }
.module-count { font-size: 12.5px; font-weight: 800; font-variant-numeric: tabular-nums; }
.module-name {
  font-size: 11.5px; font-weight: 600; margin-bottom: 5px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}

/* ── table ─────────────────────────────────────────────────────────── */
.row-click { cursor: pointer; }
.row-click:hover { background: rgba(15, 23, 42, 0.03); }
.cell-time { font-size: 11.5px; font-weight: 600; white-space: nowrap; }
.cell-actor { font-size: 12px; font-weight: 600; }
.cell-record {
  font-size: 12px; font-weight: 500; max-width: 300px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cell-sub {
  font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .5);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 300px;
}
.cell-module { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), .7); }
.status-pill {
  display: inline-block; padding: 1px 7px; border-radius: 999px;
  font-size: 10.5px; font-weight: 800; font-variant-numeric: tabular-nums;
}
.status-pill--ok { background: rgba(22, 163, 74, .12); color: #15803d; }
.status-pill--info { background: rgba(2, 132, 199, .12); color: #0369a1; }
.status-pill--warn { background: rgba(245, 158, 11, .16); color: #b45309; }
.status-pill--err { background: rgba(220, 38, 38, .12); color: #b91c1c; }
.status-pill--muted { background: rgba(100, 116, 139, .12); color: #475569; }

.pager {
  display: flex; align-items: center; gap: 6px;
  padding: 8px 12px; border-top: 1px solid rgba(15, 23, 42, 0.07);
}
.pager-info, .pager-page {
  font-size: 11.5px; color: rgba(var(--v-theme-on-surface), .6);
}

.range-pill {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 5px 10px; border-radius: 999px;
  font-size: 11.5px; font-weight: 600; white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), .72);
  background: rgba(15, 23, 42, .05);
  border: 1px solid rgba(15, 23, 42, .07);
}
.preset-strip { display: flex; align-items: center; flex-wrap: wrap; gap: 6px; }

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
.meta b { font-size: 12.5px; font-weight: 600; word-break: break-word; }
.meta .ua { font-size: 11px; color: rgba(var(--v-theme-on-surface), .6); }

.section-title {
  font-size: 10.5px; font-weight: 800; letter-spacing: .6px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5); margin: 18px 0 8px;
}
.event-headline {
  font-size: 13px; line-height: 1.45; padding: 10px 12px; border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08); background: rgba(15, 23, 42, .02);
}
.payload {
  font-family: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11px; line-height: 1.5;
  background: rgba(15, 23, 42, .04); border-radius: 10px;
  padding: 10px 12px; max-height: 220px; overflow: auto;
  white-space: pre-wrap; word-break: break-word; margin: 0;
}
.integrity-note {
  display: flex; align-items: flex-start; gap: 7px;
  margin-top: 16px; padding: 9px 11px; border-radius: 10px;
  font-size: 11px; line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), .7);
  background: rgba(2, 132, 199, .07);
  border: 1px solid rgba(2, 132, 199, .18);
}
</style>
