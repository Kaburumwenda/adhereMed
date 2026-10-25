<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-shield-lock-outline"
      eyebrow="Security & settings · Clinic"
      title="Security & Settings"
      subtitle="Access control, clinical policy and the audited trail for this clinic — who signed in, what they changed and how long it is retained."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small"
               prepend-icon="mdi-tray-arrow-down" :loading="exporting" @click="exportTrail">
          Export trail
        </v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small"
               prepend-icon="mdi-code-json" :loading="exporting" @click="exportJson">
          JSON
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small"
               prepend-icon="mdi-refresh" :loading="loading" @click="loadAll">
          Refresh
        </v-btn>
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
      <span class="ohs-chip" :style="{ background: postureChipBg, borderColor: postureChipBorder }">
        <v-icon size="12">mdi-shield-check-outline</v-icon>
        <b>{{ posture.score }}</b> posture · {{ posture.label }}
      </span>
    </OhsHero>

    <!-- ═══════════ KPIs ═══════════ -->
    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Audited events" :value="fmtNum(kpis.total)" icon="mdi-database-eye-outline"
              tone="primary" :sub="`${kpis.modules || 0} modules covered`" />
      <OhsKpi label="Last 24 hours" :value="fmtNum(kpis.last_24h)" icon="mdi-clock-fast"
              tone="info" :sub="`${fmtNum(kpis.last_7d)} in 7 days`" />
      <OhsKpi label="Critical" :value="kpis.critical || 0" icon="mdi-alert-octagon-outline"
              :tone="kpis.critical ? 'err' : 'ok'" sub="deletions & faults" />
      <OhsKpi label="Warnings" :value="kpis.warnings || 0" icon="mdi-alert-outline"
              :tone="kpis.warnings ? 'warn' : 'ok'" sub="4xx responses" />
      <OhsKpi label="Active actors" :value="kpis.distinct_actors || 0" icon="mdi-account-multiple-outline"
              tone="primary" :sub="`${staffActive} active staff`" />
      <OhsKpi label="Failed requests" :value="fmtNum(kpis.failures)" icon="mdi-cancel"
              :tone="kpis.failures ? 'warn' : 'ok'" sub="blocked or errored" />
    </div>

    <!-- ═══════════ Trend + composition ═══════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="7">
        <OhsPanel title="Activity trend" :subtitle="`Audited events per day · last ${window.days} days`"
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
            <p v-if="!actionMix.length" class="ohs-empty">No actions recorded in this window.</p>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ Signals + modules + posture ═══════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="5">
        <OhsPanel title="Security signals" subtitle="Derived from the trail — highest risk first"
                  icon="mdi-shield-alert-outline" class="h-100" flush>
          <div class="signal-list">
            <div v-for="s in signals" :key="s.kind" class="signal-row">
              <span class="signal-rail" :class="`signal-rail--${s.severity}`" />
              <div class="signal-body">
                <div class="signal-title">{{ s.title }}</div>
                <div class="signal-detail">{{ s.detail }}</div>
              </div>
              <span class="ohs-badge" :class="severityBadge(s.severity)">{{ severityLabel(s.severity) }}</span>
            </div>
            <div v-if="!signals.length" class="ohs-empty">
              No anomalies detected — the trail looks calm.
            </div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="4">
        <OhsPanel title="Audited modules" subtitle="Where activity is concentrated"
                  icon="mdi-database-eye-outline" class="h-100">
          <div v-for="m in moduleMix" :key="m.object_type" class="mix-row">
            <span class="mix-label">{{ pretty(m.object_type) }}</span>
            <div class="ohs-meter" style="color:#0ea5e9">
              <div class="ohs-meter-fill" :style="{ width: modulePct(m.count) + '%' }" />
            </div>
            <span class="mix-count">{{ m.count }}</span>
          </div>
          <p v-if="!moduleMix.length" class="ohs-empty">No module activity in this window.</p>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="3">
        <OhsPanel title="Posture" subtitle="How this clinic scores today"
                  icon="mdi-shield-check-outline" class="h-100">
          <div class="posture-ring" :style="{ '--tone': posture.color }">
            <span class="posture-score">{{ posture.score }}</span>
            <span class="posture-label">{{ posture.label }}</span>
          </div>
          <div class="posture-checks">
            <div v-for="c in postureChecks" :key="c.label" class="posture-check">
              <v-icon size="14" :color="c.ok ? '#16a34a' : '#f59e0b'">
                {{ c.ok ? 'mdi-check-circle' : 'mdi-alert-circle-outline' }}
              </v-icon>
              <span>{{ c.label }}</span>
            </div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ Policy + access ═══════════ -->
    <v-row dense class="mb-3">
      <v-col cols="12" md="6">
        <OhsPanel title="Access & roles" subtitle="Everyone with a login to this clinic"
                  icon="mdi-account-hard-hat" class="h-100" flush>
          <template #actions>
            <NuxtLink to="/clinics/staff" class="ov-link">Manage<v-icon size="13">mdi-arrow-right</v-icon></NuxtLink>
          </template>
          <table v-if="staff.length" class="ohs-table ohs-table--plain">
            <thead>
              <tr>
                <th>Name</th>
                <th>Role</th>
                <th>Status</th>
                <th class="num">Joined</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="u in staff.slice(0, 8)" :key="u.id">
                <td>
                  <div class="cell-stack">
                    <span class="cell-strong">{{ fullName(u) }}</span>
                    <span class="cell-sub">{{ u.email }}</span>
                  </div>
                </td>
                <td>{{ pretty(u.role) }}</td>
                <td>
                  <span class="ohs-badge" :class="u.is_active ? 'ohs-badge--ok' : 'ohs-badge--muted'">
                    {{ u.is_active ? 'Active' : 'Suspended' }}
                  </span>
                </td>
                <td class="num">{{ shortDate(u.date_joined) }}</td>
              </tr>
            </tbody>
          </table>
          <div v-else class="ohs-empty">No staff accounts found for this clinic.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="6">
        <OhsPanel title="Security policy" subtitle="Applies to every sign-in to this clinic"
                  icon="mdi-shield-lock-outline" class="h-100">
          <template #actions>
            <span class="ohs-badge" :class="dirty ? 'ohs-badge--warn' : 'ohs-badge--ok'">
              {{ dirty ? 'Unsaved' : 'Saved' }}
            </span>
          </template>

          <div class="policy-switch" v-for="p in toggles" :key="p.key">
            <div class="policy-switch-body" role="button" tabindex="0"
                 @click="policy[p.key] = !policy[p.key]"
                 @keydown.enter.prevent="policy[p.key] = !policy[p.key]"
                 @keydown.space.prevent="policy[p.key] = !policy[p.key]">
              <span class="policy-label">{{ p.label }}</span>
              <span class="policy-hint">{{ p.hint }}</span>
            </div>
            <v-switch v-model="policy[p.key]" color="#2f6dff" density="compact" hide-details inset
                      :aria-label="p.label" />
          </div>

          <div class="policy-selects">
            <v-select v-model="policy.idle_timeout" :items="idleOptions" item-title="label"
                      item-value="value" label="Auto sign-out" variant="outlined" density="compact"
                      hide-details />
            <v-select v-model="policy.retention_days" :items="retentionOptions" item-title="label"
                      item-value="value" label="Audit retention" variant="outlined" density="compact"
                      hide-details />
            <v-select v-model="policy.reminder_hours" :items="reminderOptions" item-title="label"
                      item-value="value" label="Reminders" variant="outlined" density="compact"
                      hide-details />
          </div>

          <div class="policy-foot">
            <span class="policy-saved">
              <v-icon size="13">mdi-information-outline</v-icon>
              {{ dirty ? 'You have unsaved changes' : `Saved ${savedLabel}` }}
            </span>
            <v-btn class="ohs-btn-primary text-none" rounded="lg" size="small"
                   prepend-icon="mdi-content-save" :loading="saving" :disabled="!dirty"
                   @click="savePolicy">Save policy</v-btn>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ Trail + shortcuts ═══════════ -->
    <v-row dense>
      <v-col cols="12" md="8">
        <OhsPanel title="Recent trail" subtitle="Newest audited actions in this clinic"
                  icon="mdi-shield-search" class="h-100" flush>
          <template #actions>
            <NuxtLink to="/clinics/audit" class="ov-link">Full trail<v-icon size="13">mdi-arrow-right</v-icon></NuxtLink>
          </template>
          <table v-if="trail.length" class="ohs-table">
            <thead>
              <tr>
                <th>When</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Record</th>
                <th>Severity</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="ev in trail" :key="ev.id" @click="openEvent(ev)">
                <td class="nowrap">{{ timeAgo(ev.created_at) }}</td>
                <td>{{ ev.actor_email || 'system' }}</td>
                <td>{{ actionLabel(ev.action) }}</td>
                <td class="clip">{{ ev.object_repr || ev.description || '—' }}</td>
                <td>
                  <span class="ohs-badge" :class="severityBadge(ev.severity)">
                    {{ severityLabel(ev.severity) }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
          <div v-else class="ohs-empty">No audited actions recorded yet.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="4">
        <OhsPanel title="Settings shortcuts" subtitle="Every control surface in one place"
                  icon="mdi-tune-variant" class="h-100">
          <div class="shortcut-list">
            <NuxtLink v-for="s in shortcuts" :key="s.to" :to="s.to" class="shortcut">
              <span class="shortcut-icon" :style="{ color: s.accent, background: s.soft }">
                <v-icon size="16">{{ s.icon }}</v-icon>
              </span>
              <span class="shortcut-body">
                <span class="shortcut-label">{{ s.label }}</span>
                <span class="shortcut-hint">{{ s.hint }}</span>
              </span>
              <v-icon size="14" class="shortcut-arrow">mdi-arrow-right</v-icon>
            </NuxtLink>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="4000" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import OhsHero from '~/components/ohs/OhsHero.vue'
import OhsKpi from '~/components/ohs/OhsKpi.vue'
import OhsPanel from '~/components/ohs/OhsPanel.vue'
import { useAuthStore } from '~/stores/auth'

definePageMeta({ title: 'Security & Settings' })

const auth = useAuthStore()
const { $api } = useNuxtApp()

// ── State ──────────────────────────────────────────────────────────
const loading = ref(false)
const exporting = ref(false)
const overview = ref(null)
const trail = ref([])
const staff = ref([])
const now = ref(Date.now())
let tickTimer = null

const snack = reactive({ show: false, color: 'success', text: '' })

const policyDefaults = {
  mfa_required: false,
  log_patient_access: true,
  require_override_reason: true,
  restrict_export: true,
  idle_timeout: 30,
  retention_days: 180,
  reminder_hours: 24,
}
const policy = reactive({ ...policyDefaults })
const savedJson = ref(JSON.stringify(policyDefaults))
const savedLabel = ref('just now')
const saving = ref(false)

const toggles = [
  { key: 'mfa_required', label: 'Require MFA for clinical staff', hint: 'Two-factor challenge on every new device' },
  { key: 'log_patient_access', label: 'Log every patient record view', hint: 'Writes an audit entry when a chart is opened' },
  { key: 'require_override_reason', label: 'Reason required for overrides', hint: 'Staff must justify breaking a clinical rule' },
  { key: 'restrict_export', label: 'Restrict bulk exports', hint: 'Only clinic admins may export patient data' },
]

const idleOptions = [15, 30, 60, 120].map(v => ({
  label: v < 60 ? `${v} minutes` : `${v / 60} hour${v > 60 ? 's' : ''}`, value: v,
}))
const retentionOptions = [90, 180, 365, 730].map(v => ({ label: `${v} days`, value: v }))
const reminderOptions = [1, 6, 12, 24, 48].map(v => ({ label: `${v}h before`, value: v }))

const shortcuts = [
  { icon: 'mdi-account-hard-hat', label: 'Staff & access', hint: 'Invite, suspend, assign roles', to: '/clinics/staff', accent: '#2f6dff', soft: 'rgba(47,109,255,0.12)' },
  { icon: 'mdi-account-key', label: 'Patient consents', hint: 'Signed permissions on file', to: '/clinics/consents', accent: '#10b981', soft: 'rgba(16,185,129,0.12)' },
  { icon: 'mdi-share-variant', label: 'Data sharing', hint: 'Who can see this clinic', to: '/clinics/data-sharing', accent: '#0ea5e9', soft: 'rgba(14,165,233,0.12)' },
  { icon: 'mdi-cog', label: 'Clinic settings', hint: 'Profile, hours, billing', to: '/clinics/settings', accent: '#f59e0b', soft: 'rgba(245,158,11,0.14)' },
  { icon: 'mdi-account-group-outline', label: 'Accounts', hint: 'Billing & subscriptions', to: '/clinics/accounts', accent: '#a855f7', soft: 'rgba(168,85,247,0.12)' },
  { icon: 'mdi-database-plus-outline', label: 'Demo data', hint: 'Load a sample register', to: '/clinics/seed-data', accent: '#14b8a6', soft: 'rgba(20,184,166,0.12)' },
]

// ── Derived ────────────────────────────────────────────────────────
const kpis = computed(() => overview.value?.kpis || {})
const signals = computed(() => overview.value?.signals || [])
const window = computed(() => overview.value?.window || { days: 30 })
const trendRaw = computed(() => overview.value?.trend || [])
const trendValues = computed(() => trendRaw.value.map(p => p.count))
const trendLabels = computed(() => trendRaw.value.map(p => p.date))

const staffActive = computed(() => staff.value.filter(u => u.is_active).length)

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
  const mix = overview.value?.severity_mix || []
  const total = mix.reduce((a, b) => a + (b.count || 0), 0) || 1
  return SEVERITY_META.map((m) => {
    const count = mix.find(x => x.severity === m.key)?.count || 0
    return { ...m, count, pct: Math.round((count / total) * 100) }
  })
})

const actionMix = computed(() => {
  const rows = (overview.value?.action_mix || []).slice(0, 6)
  const max = Math.max(1, ...rows.map(r => r.count))
  return rows.map(r => ({ ...r, pct: Math.round((r.count / max) * 100) }))
})

const moduleMix = computed(() => {
  const rows = (overview.value?.module_mix || []).slice(0, 6)
  const max = Math.max(1, ...rows.map(r => r.count))
  return rows.map(r => ({ ...r, pct: Math.round((r.count / max) * 100) }))
})

function modulePct(count) {
  const max = Math.max(1, ...(overview.value?.module_mix || []).map(r => r.count))
  return Math.max(4, Math.round(((count || 0) / max) * 100))
}

/** Composite posture — coarse at-a-glance indicator. */
const posture = computed(() => {
  const k = kpis.value
  const high = signals.value.filter(s => s.severity === 'high').length
  let score = 100
  score -= Math.min(30, (Number(k.critical) || 0) * 4)
  score -= Math.min(18, Math.floor((Number(k.failures) || 0) / 3))
  score -= high * 7
  score = Math.max(15, Math.min(100, Math.round(score)))
  if (score >= 85) return { score, label: 'Strong', color: '#16a34a' }
  if (score >= 65) return { score, label: 'Watch', color: '#f59e0b' }
  return { score, label: 'At risk', color: '#dc2626' }
})

const postureChipBg = computed(() =>
  posture.value.label === 'Strong' ? 'rgba(22,163,74,0.34)'
    : posture.value.label === 'Watch' ? 'rgba(245,158,11,0.32)' : 'rgba(220,38,38,0.34)')
const postureChipBorder = computed(() => 'rgba(255,255,255,0.34)')

const postureChecks = computed(() => [
  { label: 'MFA enforced', ok: !!policy.mfa_required },
  { label: 'Record views logged', ok: !!policy.log_patient_access },
  { label: 'Override reasons required', ok: !!policy.require_override_reason },
  { label: 'Exports restricted', ok: !!policy.restrict_export },
  { label: 'Retention ≥ 180 days', ok: (policy.retention_days || 0) >= 180 },
  { label: 'No critical events', ok: !kpis.value.critical },
])

const dirty = computed(() => JSON.stringify({ ...policy }) !== savedJson.value)

// ── Formatting ─────────────────────────────────────────────────────
function fmtNum(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}

function pretty(s) {
  if (!s) return '—'
  return String(s).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

function fullName(u) {
  const n = `${u.first_name || ''} ${u.last_name || ''}`.trim()
  return n || u.email || 'Unnamed'
}

function shortDate(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: '2-digit' })
}

function timeAgo(iso) {
  if (!iso) return '—'
  const ts = new Date(iso).getTime()
  if (Number.isNaN(ts)) return '—'
  const mins = Math.floor(Math.max(0, now.value - ts) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return shortDate(iso)
}

const ACTION_LABELS = {
  create: 'Create', update: 'Update', delete: 'Delete', view: 'View',
  login: 'Sign in', logout: 'Sign out', export: 'Export', import: 'Import',
  config: 'Config change', dispense: 'Dispense', approve: 'Approve',
}
function actionLabel(a) {
  return ACTION_LABELS[a] || pretty(a)
}

const ACTION_COLORS = {
  create: '#16a34a', update: '#2f6dff', delete: '#dc2626', view: '#64748b',
  login: '#0ea5e9', logout: '#94a3b8', export: '#f59e0b', config: '#a855f7',
}
function actionColor(a) {
  return ACTION_COLORS[a] || '#6366f1'
}

const SEVERITY_BADGE = {
  info: 'ohs-badge--info', notice: 'ohs-badge--info',
  warning: 'ohs-badge--warn', critical: 'ohs-badge--crit',
}
function severityBadge(s) {
  return SEVERITY_BADGE[s] || 'ohs-badge--muted'
}
const SEVERITY_LABEL = { info: 'Info', notice: 'Notice', warning: 'Warn', critical: 'Critical' }
function severityLabel(s) {
  return SEVERITY_LABEL[s] || pretty(s)
}

// ── Data ───────────────────────────────────────────────────────────
function rowsOf(res) {
  const p = res?.data
  return Array.isArray(p) ? p : (p?.results || [])
}

async function loadAll() {
  loading.value = true
  await Promise.allSettled([
    $api.get('/audit/events/security-overview/', { params: { since_days: 30 } })
      .then((res) => { overview.value = res.data })
      .catch(() => { overview.value = null }),
    $api.get('/audit/events/', { params: { page_size: 12, ordering: '-created_at' } })
      .then((res) => { trail.value = rowsOf(res) })
      .catch(() => { trail.value = [] }),
    $api.get('/auth/users/', { params: { page_size: 500 } })
      .then((res) => { staff.value = rowsOf(res) })
      .catch(() => { staff.value = [] }),
  ])
  loading.value = false
}

function policyKey() {
  return `adheremed.clinic.security.${auth.tenantSchema || 'default'}`
}

function loadPolicy() {
  if (!import.meta.client) return
  try {
    const raw = localStorage.getItem(policyKey())
    if (raw) Object.assign(policy, { ...policyDefaults, ...JSON.parse(raw) })
  } catch { /* ignore corrupt storage */ }
  savedJson.value = JSON.stringify({ ...policy })
}

async function savePolicy() {
  saving.value = true
  try {
    if (import.meta.client) localStorage.setItem(policyKey(), JSON.stringify({ ...policy }))
    savedJson.value = JSON.stringify({ ...policy })
    savedLabel.value = new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
    snack.text = 'Security policy saved for this clinic.'
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = 'Could not save the policy in this browser.'
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

async function download(fmt) {
  exporting.value = true
  try {
    const res = await $api.get('/audit/events/export/', {
      params: { fmt, limit: 5000, since_days: 30 },
      responseType: 'blob',
    })
    const blob = new Blob([res.data], {
      type: fmt === 'json' ? 'application/json' : 'text/csv;charset=utf-8;',
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `clinic-audit-${new Date().toISOString().slice(0, 10)}.${fmt === 'json' ? 'json' : 'csv'}`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
    snack.text = `Audit ${fmt.toUpperCase()} downloaded.`
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = 'Export failed — administrator access is required.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exporting.value = false
  }
}

function exportTrail() { download('csv') }
function exportJson() { download('json') }

function openEvent(ev) {
  if (!ev?.id) return
  navigateTo(`/clinics/audit?id=${ev.id}`)
}

onMounted(() => {
  now.value = Date.now()
  tickTimer = setInterval(() => { now.value = Date.now() }, 30000)
  loadPolicy()
  loadAll()
})

onBeforeUnmount(() => {
  if (tickTimer) clearInterval(tickTimer)
})
</script>

<style scoped>
.ov-link {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  font-weight: 700;
  color: var(--brand-primary, #2f6dff);
  text-decoration: none;
  white-space: nowrap;
}
.ov-link:hover { text-decoration: underline; }

/* Trend footer */
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
  font-size: 9.5px;
  font-weight: 750;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.ts-value {
  font-size: 15px;
  font-weight: 800;
  color: rgb(var(--v-theme-on-surface));
}

/* Composition */
.mix-block + .mix-block { margin-top: 4px; }
.mix-title {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-bottom: 7px;
}
.sev-bar {
  display: flex;
  height: 9px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.sev-seg { display: block; height: 100%; }
.sev-legend { display: flex; flex-wrap: wrap; gap: 6px 14px; margin-top: 8px; }
.sev-item {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.sev-item b { color: rgb(var(--v-theme-on-surface)); font-weight: 800; }
.sev-dot { width: 7px; height: 7px; border-radius: 50%; }
.mix-row { display: flex; align-items: center; gap: 9px; padding: 3px 0; }
.mix-label {
  width: 82px;
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.78);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.mix-count {
  margin-left: auto;
  font-size: 11px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-on-surface));
}

/* Signals */
.signal-list { display: flex; flex-direction: column; }
.signal-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.signal-row:last-child { border-bottom: 0; }
.signal-rail { width: 3px; align-self: stretch; min-height: 26px; border-radius: 3px; background: #94a3b8; }
.signal-rail--high { background: #dc2626; }
.signal-rail--medium { background: #f59e0b; }
.signal-rail--low { background: #0ea5e9; }
.signal-body { flex: 1 1 auto; min-width: 0; }
.signal-title { font-size: 12px; font-weight: 700; color: rgb(var(--v-theme-on-surface)); line-height: 1.3; }
.signal-detail { font-size: 10.5px; line-height: 1.4; color: rgba(var(--v-theme-on-surface), 0.62); }

/* Posture */
.posture-ring {
  --tone: #16a34a;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1px;
  width: 108px;
  height: 108px;
  margin: 4px auto 12px;
  border-radius: 50%;
  border: 7px solid color-mix(in srgb, var(--tone) 28%, transparent);
  background: color-mix(in srgb, var(--tone) 9%, transparent);
}
.posture-score { font-size: 30px; font-weight: 800; line-height: 1; color: var(--tone); }
.posture-label {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.posture-checks { display: flex; flex-direction: column; gap: 5px; }
.posture-check {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.78);
}

/* Table cells */
.cell-stack { display: flex; flex-direction: column; line-height: 1.3; }
.cell-strong { font-weight: 700; font-size: 12px; }
.cell-sub { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), 0.55); }
.ohs-table .clip { max-width: 220px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ohs-table .nowrap { white-space: nowrap; }

/* Policy */
.policy-switch {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.policy-switch:last-of-type { border-bottom: 0; }
.policy-switch-body { flex: 1 1 auto; min-width: 0; display: flex; flex-direction: column; cursor: pointer; outline: none; border-radius: 8px; }
.policy-switch-body:focus-visible { box-shadow: 0 0 0 3px rgba(47, 109, 255, 0.22); }
.policy-label { font-size: 12px; font-weight: 650; color: rgb(var(--v-theme-on-surface)); }
.policy-hint { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), 0.58); }
.policy-switch :deep(.v-switch) { flex-shrink: 0; }
.policy-switch :deep(.v-selection-control) { min-height: 28px; }

.policy-selects {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 10px;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
@media (min-width: 620px) { .policy-selects { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
.policy-selects :deep(.v-field) { border-radius: 11px; }
.policy-selects :deep(.v-label) { font-size: 12px; }

.policy-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 14px;
}
.policy-saved {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.ohs-btn-primary {
  background: linear-gradient(120deg, #2f6dff, #1d4ed8) !important;
  color: #fff !important;
  font-weight: 700 !important;
  letter-spacing: 0 !important;
  box-shadow: 0 10px 22px -12px rgba(47, 109, 255, 0.9) !important;
}
.ohs-btn-primary:disabled { opacity: 0.45; box-shadow: none !important; }

/* Shortcuts */
.shortcut-list { display: flex; flex-direction: column; gap: 5px; }
.shortcut {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 9px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  text-decoration: none;
  color: rgb(var(--v-theme-on-surface));
  transition: transform 0.18s, border-color 0.18s, background 0.18s;
}
.shortcut:hover {
  transform: translateX(2px);
  border-color: rgba(var(--v-theme-primary), 0.35);
  background: rgba(var(--v-theme-primary), 0.045);
}
.shortcut-icon { width: 30px; height: 30px; flex-shrink: 0; display: grid; place-items: center; border-radius: 9px; }
.shortcut-body { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
.shortcut-label { font-size: 12px; font-weight: 700; }
.shortcut-hint { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), 0.58); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.shortcut-arrow { margin-left: auto; flex-shrink: 0; opacity: 0.5; }
.shortcut:hover .shortcut-arrow { opacity: 1; transform: translateX(2px); }
</style>
