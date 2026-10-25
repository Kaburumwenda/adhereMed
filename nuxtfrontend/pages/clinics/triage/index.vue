<template>
  <v-container fluid class="pa-4 pa-md-6 tq-page" :style="heroTheme">
    <!-- ══ Hero ══════════════════════════════════════════════════════ -->
    <header class="tq-hero">
      <span class="tq-hero-glow"></span>
      <span class="tq-hero-glow-2"></span>

      <div class="tq-hero-top">
        <div class="tq-hero-icon"><v-icon size="24">mdi-monitor-heart</v-icon></div>

        <div class="tq-hero-id">
          <div class="tq-eyebrow">
            <v-icon size="11">mdi-pulse</v-icon>
            Clinical operations · Triage
          </div>
          <h1 class="tq-hero-title">Triage &amp; encounter workflow</h1>
          <p class="tq-hero-sub">
            Nurse triage, acuity scoring and the doctor handoff queue
          </p>
        </div>

        <div class="tq-hero-actions">
          <button type="button" class="tq-glass" :disabled="r.loading.value" @click="loadAll">
            <v-icon size="16" :class="{ 'mdi-spin': r.loading.value }">mdi-refresh</v-icon>
            Refresh
          </button>
          <button type="button" class="tq-solid" @click="navigateTo('/clinics/triage/new')">
            <v-icon size="16">mdi-plus</v-icon>
            New triage
          </button>
        </div>
      </div>

      <div class="tq-hero-foot">
        <div class="tq-chip" :class="{ 'is-warn': draftTriages.length }">
          <v-icon size="13">mdi-clipboard-pulse</v-icon>
          {{ draftTriages.length }} in triage queue
        </div>
        <div class="tq-chip" :class="{ 'is-ok': doctorQueue.length }">
          <v-icon size="13">mdi-stethoscope</v-icon>
          {{ doctorQueue.length }} awaiting doctor
        </div>
        <div class="tq-chip" :class="{ 'is-bad': criticalCount }">
          <v-icon size="13">mdi-alert-circle</v-icon>
          {{ criticalCount }} critical
        </div>
        <div class="tq-chip">
          <v-icon size="13">mdi-calendar-today</v-icon>
          {{ todayCount }} today
        </div>
        <div v-if="longestWaitLabel" class="tq-chip tq-chip--muted">
          <v-icon size="13">mdi-timer-sand</v-icon>
          Longest wait {{ longestWaitLabel }}
        </div>

        <div class="tq-hero-stamp">
          <span class="tq-live-dot"></span>
          Live · updated {{ updatedLabel }}
        </div>
      </div>
    </header>

    <!-- ══ Critical banner ═══════════════════════════════════════════ -->
    <div v-if="criticalCount" class="tq-critical">
      <v-icon size="18">mdi-alert-octagon</v-icon>
      <div class="tq-critical-text">
        <strong>{{ criticalCount }} {{ criticalCount === 1 ? 'patient needs' : 'patients need' }} immediate attention</strong>
        <span>ESI 1–2 · review these before the rest of the queue</span>
      </div>
      <button type="button" class="tq-critical-btn" @click="focusCritical">
        Show critical
        <v-icon size="14">mdi-arrow-right</v-icon>
      </button>
    </div>

    <!-- ══ KPI tiles ═════════════════════════════════════════════════ -->
    <div class="tq-kpis">
      <article
        v-for="k in kpis"
        :key="k.key"
        class="tq-kpi"
        :style="{ '--tone': k.tone }"
        role="button"
        tabindex="0"
        @click="jumpTo(k)"
        @keydown.enter.prevent="jumpTo(k)"
      >
        <div class="tq-kpi-head">
          <div class="tq-kpi-icon"><v-icon size="18">{{ k.icon }}</v-icon></div>
          <span class="tq-kpi-label">{{ k.label }}</span>
        </div>
        <div class="tq-kpi-value">{{ k.value }}</div>
        <div class="tq-kpi-foot">
          <span class="tq-kpi-hint">{{ k.hint }}</span>
          <span class="tq-kpi-bar"><span :style="{ width: k.pct + '%' }"></span></span>
        </div>
      </article>
    </div>

    <!-- ══ Analytics ═════════════════════════════════════════════════ -->
    <div class="tq-analytics">
      <!-- Status split -->
      <section class="tq-card">
        <div class="tq-card-head">
          <div class="tq-card-icon is-amber"><v-icon size="17">mdi-chart-donut</v-icon></div>
          <div class="tq-card-titles">
            <h2>Documentation status</h2>
            <p>{{ totalEntries }} entr{{ totalEntries === 1 ? 'y' : 'ies' }} in the register</p>
          </div>
        </div>

        <div class="tq-card-body">
          <div class="tq-status-legend">
            <div class="tq-status-key">
              <span class="tq-dot is-draft"></span>
              <div>
                <div class="tq-status-num">{{ draftTriages.length }}</div>
                <div class="tq-status-label">In triage</div>
              </div>
            </div>
            <div class="tq-status-key">
              <span class="tq-dot is-done"></span>
              <div>
                <div class="tq-status-num">{{ doctorQueue.length }}</div>
                <div class="tq-status-label">Completed</div>
              </div>
            </div>
          </div>

          <div class="tq-stack">
            <span class="tq-stack-draft" :style="{ width: draftPct + '%' }"></span>
            <span class="tq-stack-done" :style="{ width: donePct + '%' }"></span>
          </div>
          <div class="tq-stack-axes">
            <span>{{ draftPct }}% pending</span>
            <span>{{ donePct }}% signed off</span>
          </div>
        </div>
      </section>

      <!-- ESI mix -->
      <section class="tq-card">
        <div class="tq-card-head">
          <div class="tq-card-icon is-red"><v-icon size="17">mdi-chart-bell-curve</v-icon></div>
          <div class="tq-card-titles">
            <h2>Acuity mix</h2>
            <p>Distribution across the five ESI levels</p>
          </div>
        </div>

        <div class="tq-card-body">
          <div class="tq-esi-chart">
            <div v-for="e in 5" :key="e" class="tq-esi-col">
              <span class="tq-esi-count" :style="{ color: esiHex(e) }">{{ esiCount(e) }}</span>
              <div class="tq-esi-track">
                <div
                  class="tq-esi-fill"
                  :style="{ height: esiBarHeight(e) + '%', background: esiHex(e) }"
                ></div>
              </div>
              <span class="tq-esi-name" :title="esiLabels[e]">ESI {{ e }}</span>
            </div>
          </div>

          <div class="tq-esi-note">
            <v-icon size="12">mdi-information-outline</v-icon>
            <span v-if="unassignedCount">{{ unassignedCount }} awaiting an ESI level</span>
            <span v-else>Every entry has an acuity level</span>
          </div>
        </div>
      </section>

      <!-- Weekly volume -->
      <section class="tq-card">
        <div class="tq-card-head">
          <div class="tq-card-icon is-teal"><v-icon size="17">mdi-calendar-week</v-icon></div>
          <div class="tq-card-titles">
            <h2>This week</h2>
            <p>Triage arrivals by weekday</p>
          </div>
        </div>

        <div class="tq-card-body">
          <div class="tq-week-chart">
            <div v-for="(d, i) in weekDays" :key="i" class="tq-week-col" :class="{ 'is-today': isToday(i) }">
              <span class="tq-week-count">{{ weekdayCount(i) }}</span>
              <div class="tq-week-track">
                <div class="tq-week-fill" :style="{ height: weekdayBarHeight(i) + '%' }"></div>
              </div>
              <span class="tq-week-name">{{ d }}</span>
            </div>
          </div>

          <div class="tq-esi-note">
            <v-icon size="12">mdi-information-outline</v-icon>
            <span>{{ weekTotal }} arrival{{ weekTotal === 1 ? '' : 's' }} since Monday</span>
          </div>
        </div>
      </section>
    </div>

    <!-- ══ Queue panel ═══════════════════════════════════════════════ -->
    <section class="tq-panel">
      <header class="tq-panel-head">
        <div class="tq-tabs">
          <button
            v-for="t in tabs"
            :key="t.value"
            type="button"
            class="tq-tab"
            :class="{ on: queueTab === t.value }"
            @click="queueTab = t.value"
          >
            <v-icon size="15">{{ t.icon }}</v-icon>
            {{ t.label }}
            <span class="tq-tab-count">{{ t.count }}</span>
          </button>
        </div>

        <div class="tq-panel-tools">
          <div v-if="queueTab === 'triage'" class="tq-seg">
            <button
              type="button"
              class="tq-seg-btn"
              :class="{ on: triageViewMode === 'list' }"
              @click="triageViewMode = 'list'"
            >
              <v-icon size="14">mdi-view-list</v-icon>List
            </button>
            <button
              type="button"
              class="tq-seg-btn"
              :class="{ on: triageViewMode === 'board' }"
              @click="triageViewMode = 'board'"
            >
              <v-icon size="14">mdi-view-column</v-icon>Board
            </button>
          </div>

          <div v-if="queueTab === 'all'" class="tq-filters">
            <v-text-field
              v-model="r.search.value"
              prepend-inner-icon="mdi-magnify"
              placeholder="Search triage…"
              variant="outlined"
              density="compact"
              rounded="lg"
              hide-details
              clearable
              class="tq-filter-search"
            />
            <v-select
              v-model="statusFilter"
              :items="statusOptions"
              label="Status"
              variant="outlined"
              density="compact"
              rounded="lg"
              hide-details
              clearable
              class="tq-filter-select"
            />
            <v-select
              v-model="esiFilter"
              :items="[1, 2, 3, 4, 5]"
              label="ESI"
              variant="outlined"
              density="compact"
              rounded="lg"
              hide-details
              clearable
              class="tq-filter-select"
            />
          </div>
        </div>
      </header>

      <div class="tq-panel-body">
        <!-- ─────────── Triage queue ─────────── -->
        <div v-if="queueTab === 'triage'">
          <div v-if="!draftTriages.length && !r.loading.value" class="tq-empty">
            <div class="tq-empty-icon"><v-icon size="28">mdi-clipboard-check-outline</v-icon></div>
            <h3>The triage queue is clear</h3>
            <p>Patients sent for triage by reception will appear here in arrival order.</p>
            <button type="button" class="tq-cta" @click="navigateTo('/clinics/triage/new')">
              <v-icon size="15">mdi-plus</v-icon>Start a triage
            </button>
          </div>

          <!-- List -->
          <div v-else-if="triageViewMode === 'list'" class="tq-list">
            <article
              v-for="item in draftTriages"
              :key="item.id"
              class="tq-row"
              :class="waitTone(item.triage_time)"
              role="button"
              tabindex="0"
              @click="navigateTo(`/clinics/triage/workspace/${item.id}`)"
              @keydown.enter.prevent="navigateTo(`/clinics/triage/workspace/${item.id}`)"
            >
              <div class="tq-row-avatar">{{ initialsOf(item.patient_name) }}</div>

              <div class="tq-row-main">
                <div class="tq-row-title">
                  <span class="tq-row-name">{{ item.patient_name }}</span>
                  <span class="tq-tag is-warn">
                    <v-icon size="10">mdi-flag</v-icon>Draft
                  </span>
                  <span v-if="item.esi_level" class="tq-tag" :style="{ '--tone': esiHex(item.esi_level) }">
                    ESI {{ item.esi_level }}
                  </span>
                  <span class="tq-tag" :style="{ '--tone': news2Hex(item.news2_score) }">
                    NEWS2 {{ item.news2_score || 0 }}
                  </span>
                </div>
                <div class="tq-row-sub">
                  <v-icon size="12">mdi-format-quote-close</v-icon>
                  <span class="tq-row-complaint">{{ item.chief_complaint || 'No complaint captured yet' }}</span>
                </div>
              </div>

              <div class="tq-row-meta">
                <div class="tq-wait" :class="waitTone(item.triage_time)">
                  <v-icon size="13">mdi-timer-sand</v-icon>
                  {{ waitTime(item.triage_time) }}
                </div>
                <span class="tq-row-arrived">{{ formatDateTime(item.triage_time) }}</span>
              </div>

              <button type="button" class="tq-row-cta">
                Continue
                <v-icon size="14">mdi-arrow-right</v-icon>
              </button>
            </article>
          </div>

          <!-- Board -->
          <div v-else class="tq-board">
            <div
              v-for="col in boardColumns"
              :key="col.key"
              class="tq-board-col"
              :style="{ '--tone': col.tone }"
            >
              <header class="tq-board-head">
                <span class="tq-board-badge">{{ col.badge }}</span>
                <span class="tq-board-title">{{ col.title }}</span>
                <span class="tq-board-count">{{ col.items.length }}</span>
              </header>

              <div class="tq-board-body">
                <article
                  v-for="item in col.items"
                  :key="item.id"
                  class="tq-board-card"
                  :class="waitTone(item.triage_time)"
                  role="button"
                  tabindex="0"
                  @click="navigateTo(`/clinics/triage/workspace/${item.id}`)"
                  @keydown.enter.prevent="navigateTo(`/clinics/triage/workspace/${item.id}`)"
                >
                  <div class="tq-board-card-top">
                    <span class="tq-board-name">{{ item.patient_name }}</span>
                    <span class="tq-wait is-mini" :class="waitTone(item.triage_time)">
                      {{ waitTime(item.triage_time) }}
                    </span>
                  </div>
                  <p class="tq-board-complaint">{{ item.chief_complaint || 'No complaint yet' }}</p>
                  <div class="tq-board-card-foot">
                    <span v-if="item.esi_level" class="tq-tag" :style="{ '--tone': esiHex(item.esi_level) }">
                      ESI {{ item.esi_level }}
                    </span>
                    <span class="tq-tag" :style="{ '--tone': news2Hex(item.news2_score) }">
                      NEWS2 {{ item.news2_score || 0 }}
                    </span>
                  </div>
                </article>

                <div v-if="!col.items.length" class="tq-board-empty">Nothing here</div>
              </div>
            </div>
          </div>
        </div>

        <!-- ─────────── Doctor queue ─────────── -->
        <div v-else-if="queueTab === 'doctor'">
          <div v-if="!doctorQueue.length && !r.loading.value" class="tq-empty">
            <div class="tq-empty-icon"><v-icon size="28">mdi-stethoscope</v-icon></div>
            <h3>No patients waiting for a doctor</h3>
            <p>Completed triages appear here, ordered by acuity.</p>
          </div>

          <div v-else class="tq-list">
            <article
              v-for="item in doctorQueue"
              :key="item.id"
              class="tq-row-card"
              :style="{ '--tone': esiHex(item.esi_level) }"
              role="button"
              tabindex="0"
              @click="startConsultationFromTriage(item)"
              @keydown.enter.prevent="startConsultationFromTriage(item)"
            >
              <div class="tq-esi-ring" :style="{ '--tone': esiHex(item.esi_level) }">
                <span class="tq-esi-ring-num">{{ item.esi_level || '?' }}</span>
                <span class="tq-esi-ring-label">ESI</span>
              </div>

              <div class="tq-row-main">
                <div class="tq-row-title">
                  <span class="tq-row-name">{{ item.patient_name }}</span>
                  <span class="tq-tag" :style="{ '--tone': esiHex(item.esi_level) }">
                    {{ esiLabels[item.esi_level] || 'Unassigned' }}
                  </span>
                  <span class="tq-tag" :style="{ '--tone': news2Hex(item.news2_score) }">
                    NEWS2 {{ item.news2_score || 0 }}
                  </span>
                </div>
                <div class="tq-row-sub">
                  <v-icon size="12">mdi-format-quote-close</v-icon>
                  <span class="tq-row-complaint">{{ item.chief_complaint || 'No complaint recorded' }}</span>
                </div>
                <div class="tq-row-docline">
                  <v-icon size="12">mdi-clock-check-outline</v-icon>
                  Triaged {{ formatDateTime(item.completed_at) }}
                  <span v-if="item.doctor_name" class="tq-docname">
                    <v-icon size="12">mdi-doctor</v-icon>{{ item.doctor_name }}
                  </span>
                </div>
              </div>

              <button type="button" class="tq-row-cta is-solid">
                Start consult
                <v-icon size="14">mdi-arrow-right</v-icon>
              </button>
            </article>
          </div>
        </div>

        <!-- ─────────── All entries ─────────── -->
        <div v-else>
          <v-data-table
            :headers="headers"
            :items="allFiltered"
            :loading="r.loading.value"
            density="comfortable"
            hover
            item-value="id"
            class="tq-table"
            @click:row="goDetail"
          >
            <template #item.patient_name="{ item }">
              <div class="tq-cell-patient">
                <span class="tq-mini-avatar">{{ initialsOf(item.patient_name) }}</span>
                <span>{{ item.patient_name }}</span>
              </div>
            </template>
            <template #item.status="{ value }">
              <span class="tq-tag" :style="{ '--tone': value === 'completed' ? '#16a34a' : '#f59e0b' }">
                {{ value === 'completed' ? 'Completed' : 'In triage' }}
              </span>
            </template>
            <template #item.esi_level="{ value }">
              <span v-if="value" class="tq-tag" :style="{ '--tone': esiHex(value) }">ESI {{ value }}</span>
              <span v-else class="tq-dash">—</span>
            </template>
            <template #item.news2_score="{ value }">
              <span v-if="value != null" class="tq-tag" :style="{ '--tone': news2Hex(value) }">{{ value }}</span>
              <span v-else class="tq-dash">—</span>
            </template>
            <template #item.triage_time="{ value }">
              <span class="tq-cell-time">{{ formatDateTime(value) }}</span>
            </template>
            <template #item.actions="{ item }">
              <div class="tq-cell-actions">
                <button
                  type="button"
                  class="tq-icon-btn"
                  title="Open workspace"
                  @click.stop="navigateTo(`/clinics/triage/workspace/${item.id}`)"
                >
                  <v-icon size="16">mdi-monitor-heart</v-icon>
                </button>
                <button
                  v-if="item.status === 'completed'"
                  type="button"
                  class="tq-icon-btn is-accent"
                  title="Start consultation"
                  @click.stop="startConsultationFromTriage(item)"
                >
                  <v-icon size="16">mdi-stethoscope</v-icon>
                </button>
              </div>
            </template>
          </v-data-table>
        </div>
      </div>
    </section>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom" rounded="lg" timeout="4000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'

const r = useResource('/triage/')
const { $api } = useNuxtApp()
const auth = useAuthStore()
const brand = useBranding()

const queueTab = ref('triage')
const triageViewMode = ref('list')
const statusFilter = ref('')
const esiFilter = ref('')

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

// ── Brand bridge ─────────────────────────────────────────────────────
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

const esiLabels = {
  1: 'Resuscitation',
  2: 'Emergent',
  3: 'Urgent',
  4: 'Less urgent',
  5: 'Non-urgent',
}

// Matches the acuity palette used in the workspace and doctor-handoff rail.
const ESI_HEX = { 1: '#dc2626', 2: '#ea580c', 3: '#f59e0b', 4: '#3b82f6', 5: '#22c55e' }
function esiHex(level) {
  return ESI_HEX[Number(level)] || '#94a3b8'
}
function news2Hex(score) {
  const s = Number(score) || 0
  if (s >= 7) return '#dc2626'
  if (s >= 5) return '#ea580c'
  if (s >= 1) return '#f59e0b'
  return '#22c55e'
}

function initialsOf(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase()
}

// ── Live clock ───────────────────────────────────────────────────────
// Wait times must re-render on their own; `Date.now()` inside a helper is not
// reactive, so a ticking ref drives it.
const now = ref(Date.now())
const updatedAt = ref(null)

const updatedLabel = computed(() => {
  if (!updatedAt.value) return 'just now'
  const mins = Math.floor((now.value - updatedAt.value) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  return `${Math.floor(mins / 60)}h ago`
})

let refreshTimer = null
onMounted(() => {
  loadAll()
  refreshTimer = setInterval(() => {
    now.value = Date.now()
    // Data refresh is cheap here and keeps the queue honest.
    loadAll({ silent: true })
  }, 30000)
})
onUnmounted(() => { if (refreshTimer) clearInterval(refreshTimer) })

async function loadAll({ silent = false } = {}) {
  if (!silent) await r.list({ page_size: 1000 })
  else await r.list({ page_size: 1000 })
  now.value = Date.now()
  updatedAt.value = Date.now()
}

// ── Filters ──────────────────────────────────────────────────────────
const statusOptions = [
  { title: 'In triage', value: 'draft' },
  { title: 'Completed', value: 'completed' },
]

const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'ESI', key: 'esi_level', width: 92 },
  { title: 'NEWS2', key: 'news2_score', width: 92 },
  { title: 'Status', key: 'status', width: 128 },
  { title: 'Chief complaint', key: 'chief_complaint' },
  { title: 'Arrived', key: 'triage_time', width: 180 },
  { title: '', key: 'actions', sortable: false, width: 92 },
]

// ── Derived queues ───────────────────────────────────────────────────
const draftTriages = computed(() =>
  r.items.value
    .filter(t => t.status === 'draft')
    .sort((a, b) => new Date(a.triage_time) - new Date(b.triage_time)))

const doctorQueue = computed(() =>
  r.items.value
    .filter(t => t.status === 'completed')
    .sort((a, b) => (a.esi_level || 5) - (b.esi_level || 5)))

const allFiltered = computed(() => r.filtered.value.filter(t => {
  if (statusFilter.value && t.status !== statusFilter.value) return false
  if (esiFilter.value && t.esi_level !== esiFilter.value) return false
  return true
}))

const totalEntries = computed(() => r.items.value.length)
const criticalCount = computed(() => r.items.value.filter(i => i.esi_level && i.esi_level <= 2).length)
const unassignedCount = computed(() => r.items.value.filter(i => !i.esi_level).length)
const todayCount = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return r.items.value.filter(i => (i.triage_time || '').startsWith(today)).length
})

function esiCount(level) {
  return r.items.value.filter(i => i.esi_level === level).length
}
function esiBarHeight(level) {
  const max = Math.max(...[1, 2, 3, 4, 5].map(esiCount), 1)
  return Math.max(6, Math.round((esiCount(level) / max) * 100))
}

// ── KPIs ─────────────────────────────────────────────────────────────
const kpis = computed(() => {
  const total = totalEntries.value || 1
  return [
    {
      key: 'draft',
      label: 'In triage queue',
      value: draftTriages.value.length,
      hint: 'awaiting a nurse',
      icon: 'mdi-clipboard-pulse',
      tone: '#f59e0b',
      pct: Math.round((draftTriages.value.length / total) * 100),
      target: 'triage',
    },
    {
      key: 'doctor',
      label: 'Awaiting doctor',
      value: doctorQueue.value.length,
      hint: 'triage signed off',
      icon: 'mdi-stethoscope',
      tone: '#3b82f6',
      pct: Math.round((doctorQueue.value.length / total) * 100),
      target: 'doctor',
    },
    {
      key: 'critical',
      label: 'Critical acuity',
      value: criticalCount.value,
      hint: 'ESI 1–2',
      icon: 'mdi-alert-circle',
      tone: '#dc2626',
      pct: Math.round((criticalCount.value / total) * 100),
      target: 'triage',
    },
    {
      key: 'today',
      label: 'Arrivals today',
      value: todayCount.value,
      hint: 'triages opened',
      icon: 'mdi-calendar-today',
      tone: '#0d9488',
      pct: Math.round((todayCount.value / total) * 100),
      target: 'all',
    },
  ]
})

function jumpTo(k) {
  queueTab.value = k.target
  if (k.target === 'all') {
    statusFilter.value = ''
    esiFilter.value = ''
  }
}

function focusCritical() {
  queueTab.value = 'all'
  esiFilter.value = 1
  if (!allFiltered.value.length) esiFilter.value = 2
}

// ── Distribution ─────────────────────────────────────────────────────
const draftPct = computed(() => {
  if (!totalEntries.value) return 0
  return Math.round((draftTriages.value.length / totalEntries.value) * 100)
})
const donePct = computed(() => {
  if (!totalEntries.value) return 0
  return 100 - draftPct.value
})

// ── Wait time ────────────────────────────────────────────────────────
function waitMinutes(timeStr) {
  if (!timeStr) return 0
  return Math.max(0, Math.floor((now.value - new Date(timeStr).getTime()) / 60000))
}
function waitTime(timeStr) {
  const mins = waitMinutes(timeStr)
  if (mins < 60) return `${mins}m`
  return `${Math.floor(mins / 60)}h ${mins % 60}m`
}
function waitTone(timeStr) {
  const m = waitMinutes(timeStr)
  if (m > 30) return 'is-bad'
  if (m > 15) return 'is-warn'
  return 'is-ok'
}

const longestWaitLabel = computed(() => {
  if (!draftTriages.value.length) return ''
  const longest = draftTriages.value.reduce((max, t) => {
    const m = waitMinutes(t.triage_time)
    return m > max ? m : max
  }, 0)
  if (longest < 60) return `${longest}m`
  return `${Math.floor(longest / 60)}h ${longest % 60}m`
})

// ── Board ────────────────────────────────────────────────────────────
function boardColumnItems(esiLevel) {
  const drafts = draftTriages.value
  if (esiLevel === null) return drafts.filter(i => !i.esi_level)
  return drafts.filter(i => i.esi_level === esiLevel)
}

const boardColumns = computed(() => [
  {
    key: 'unassigned',
    badge: '?',
    title: 'Unassigned',
    tone: '#94a3b8',
    items: boardColumnItems(null),
  },
  ...[1, 2, 3, 4, 5].map(e => ({
    key: `esi-${e}`,
    badge: String(e),
    title: esiLabels[e],
    tone: esiHex(e),
    items: boardColumnItems(e),
  })),
])

// ── Weekly volume ────────────────────────────────────────────────────
const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

function weekStart() {
  const d = new Date()
  const offset = d.getDay() === 0 ? 6 : d.getDay() - 1
  const start = new Date(d)
  start.setDate(d.getDate() - offset)
  start.setHours(0, 0, 0, 0)
  return start
}
function weekdayCount(dayIdx) {
  const start = weekStart()
  return r.items.value.filter(i => {
    if (!i.triage_time) return false
    const d = new Date(i.triage_time)
    if (d < start) return false
    const idx = d.getDay() === 0 ? 6 : d.getDay() - 1
    return idx === dayIdx
  }).length
}
function weekdayBarHeight(dayIdx) {
  const max = Math.max(...[0, 1, 2, 3, 4, 5, 6].map(weekdayCount), 1)
  return Math.max(6, Math.round((weekdayCount(dayIdx) / max) * 100))
}
function isToday(dayIdx) {
  const d = new Date().getDay()
  return (d === 0 ? 6 : d - 1) === dayIdx
}
const weekTotal = computed(() => [0, 1, 2, 3, 4, 5, 6].reduce((s, i) => s + weekdayCount(i), 0))

// ── Actions ──────────────────────────────────────────────────────────
const tabs = computed(() => [
  { value: 'triage', label: 'Triage queue', icon: 'mdi-clipboard-pulse', count: draftTriages.value.length },
  { value: 'doctor', label: 'Doctor queue', icon: 'mdi-stethoscope', count: doctorQueue.value.length },
  { value: 'all', label: 'All entries', icon: 'mdi-format-list-bulleted', count: totalEntries.value },
])

function goDetail(_, item) { navigateTo(`/clinics/triage/workspace/${item.id}`) }

async function startConsultationFromTriage(item) {
  try {
    const { data } = await $api.get('/consultations/', { params: { triage: item.id, page_size: 1 } })
    if (data.results?.length) {
      navigateTo(`/clinics/consultations/workspace/${data.results[0].id}`)
    } else {
      const { data: consult } = await $api.post('/consultations/', {
        patient: item.patient,
        triage: item.id,
        // Prefer the clinician assigned during triage over whoever is clicking.
        doctor: item.doctor || auth.user?.id,
        draft_owner: auth.user?.id,
        chief_complaint: item.chief_complaint,
        vital_signs: item.vital_signs,
        status: 'draft',
      })
      navigateTo(`/clinics/consultations/workspace/${consult.id}`)
    }
  } catch (e) {
    console.error('Failed to start consultation', e)
    notify('Could not start the consultation', 'error')
  }
}
</script>

<style scoped>
/* ══ Page ════════════════════════════════════════════════════════════ */
/* Uses the full main-area width; the container's own padding provides the
   gutter, so no max-width is imposed here. */
.tq-page { width: 100%; }

/* ══ Hero ════════════════════════════════════════════════════════════ */
.tq-hero {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
  padding: 20px 22px 14px;
  color: #fff;
  margin-bottom: 16px;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #1e3a8a) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #60a5fa) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.tq-hero-glow {
  position: absolute;
  width: 360px; height: 360px;
  border-radius: 50%;
  right: -120px; top: -200px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255,255,255,0.28)), transparent 68%);
  pointer-events: none;
}
.tq-hero-glow-2 {
  right: auto; left: -150px; top: auto; bottom: -250px;
  width: 320px; height: 320px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(96,165,250,0.24)), transparent 70%);
}
.tq-hero-top {
  position: relative;
  display: flex;
  align-items: center;
  gap: 14px;
}
.tq-hero-icon {
  width: 54px; height: 54px;
  border-radius: 16px;
  display: grid; place-items: center;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(6px);
}
.tq-hero-id { min-width: 0; flex: 1; }
.tq-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 1.3px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.72);
}
.tq-hero-title {
  font-size: 25px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.3px;
  margin: 3px 0 2px;
}
.tq-hero-sub {
  font-size: 13px;
  margin: 0;
  color: rgba(255, 255, 255, 0.8);
}

.tq-hero-actions { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
.tq-glass,
.tq-solid {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 38px;
  padding: 0 15px;
  border-radius: 11px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: transform 0.15s ease, background 0.18s ease, opacity 0.15s ease;
}
.tq-glass {
  color: #fff;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.32);
  backdrop-filter: blur(6px);
}
.tq-glass:hover:not(:disabled) { background: rgba(255, 255, 255, 0.26); transform: translateY(-1px); }
.tq-solid {
  color: var(--hero-ink, #1e3a8a);
  background: #fff;
  border: 1px solid #fff;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.16);
}
.tq-solid:hover { transform: translateY(-1px); }
.tq-glass:disabled { opacity: 0.5; cursor: not-allowed; }

.tq-hero-foot {
  position: relative;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 7px;
  margin-top: 15px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.tq-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 700;
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.22);
  backdrop-filter: blur(4px);
}
.tq-chip--muted { opacity: 0.8; font-weight: 600; }
.tq-chip.is-warn { background: rgba(245, 158, 11, 0.85); }
.tq-chip.is-ok { background: rgba(59, 130, 246, 0.85); }
.tq-chip.is-bad { background: rgba(220, 38, 38, 0.88); }

.tq-hero-stamp {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-left: auto;
  font-size: 11px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.85);
  white-space: nowrap;
}
.tq-live-dot {
  width: 7px; height: 7px;
  border-radius: 50%;
  background: #4ade80;
  box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.7);
  animation: tqPulse 1.9s infinite;
}
@keyframes tqPulse {
  0% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.6); }
  70% { box-shadow: 0 0 0 7px rgba(74, 222, 128, 0); }
  100% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0); }
}

/* ══ Critical banner ═════════════════════════════════════════════════ */
.tq-critical {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 11px 16px;
  margin-bottom: 14px;
  border-radius: 14px;
  color: #fff;
  background: linear-gradient(100deg, #b91c1c, #dc2626 60%, #ef4444);
  box-shadow: 0 10px 26px rgba(185, 28, 28, 0.26);
}
.tq-critical-text { flex: 1; min-width: 0; }
.tq-critical-text strong { display: block; font-size: 13px; font-weight: 800; line-height: 1.35; }
.tq-critical-text span { font-size: 11px; color: rgba(255, 255, 255, 0.85); }
.tq-critical-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
  height: 30px;
  padding: 0 12px;
  border-radius: 9px;
  border: 1px solid rgba(255, 255, 255, 0.4);
  background: rgba(255, 255, 255, 0.18);
  color: #fff;
  font-size: 11.5px;
  font-weight: 800;
  cursor: pointer;
  transition: background 0.15s ease;
}
.tq-critical-btn:hover { background: rgba(255, 255, 255, 0.3); }

/* ══ KPI tiles ═══════════════════════════════════════════════════════ */
.tq-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 14px;
}
.tq-kpi {
  position: relative;
  padding: 13px 14px 12px;
  border-radius: 15px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  cursor: pointer;
  overflow: hidden;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.tq-kpi::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 3px;
  background: var(--tone);
  opacity: 0.7;
}
.tq-kpi:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--tone) 40%, transparent);
  box-shadow: 0 8px 22px color-mix(in srgb, var(--tone) 16%, transparent);
}
.tq-kpi-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}
.tq-kpi-icon {
  width: 30px; height: 30px;
  border-radius: 9px;
  display: grid; place-items: center;
  flex-shrink: 0;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.tq-kpi-label {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  line-height: 1.2;
}
.tq-kpi-value {
  font-size: 30px;
  font-weight: 800;
  line-height: 1;
  letter-spacing: -0.5px;
  color: var(--tone);
  font-variant-numeric: tabular-nums;
  margin-bottom: 7px;
}
.tq-kpi-foot {
  display: flex;
  align-items: center;
  gap: 8px;
}
.tq-kpi-hint {
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tq-kpi-bar {
  flex: 1;
  min-width: 24px;
  height: 4px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
}
.tq-kpi-bar span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--tone);
  transition: width 0.35s ease;
}

/* ══ Analytics ═══════════════════════════════════════════════════════ */
.tq-analytics {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}
.tq-card {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-radius: 15px;
  overflow: hidden;
}
.tq-card-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.025), transparent);
}
.tq-card-icon {
  width: 30px; height: 30px;
  border-radius: 9px;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.tq-card-icon.is-amber { background: rgba(245, 158, 11, 0.13); color: #b45309; }
.tq-card-icon.is-red { background: rgba(220, 38, 38, 0.1); color: #dc2626; }
.tq-card-icon.is-teal { background: rgba(13, 148, 136, 0.1); color: #0d9488; }
.tq-card-titles { min-width: 0; }
.tq-card-titles h2 {
  font-size: 13px;
  font-weight: 800;
  margin: 0;
  line-height: 1.3;
}
.tq-card-titles p {
  font-size: 10.5px;
  margin: 1px 0 0;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.tq-card-body { padding: 14px; }

/* Status split */
.tq-status-legend { display: flex; gap: 20px; margin-bottom: 11px; }
.tq-status-key { display: flex; align-items: center; gap: 8px; }
.tq-dot { width: 9px; height: 9px; border-radius: 3px; flex-shrink: 0; }
.tq-dot.is-draft { background: #f59e0b; }
.tq-dot.is-done { background: #16a34a; }
.tq-status-num {
  font-size: 19px;
  font-weight: 800;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.tq-status-label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.42);
  margin-top: 1px;
}
.tq-stack {
  display: flex;
  height: 9px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.tq-stack-draft { background: #f59e0b; transition: width 0.35s ease; }
.tq-stack-done { background: #16a34a; transition: width 0.35s ease; }
.tq-stack-axes {
  display: flex;
  justify-content: space-between;
  margin-top: 6px;
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.36);
}

/* ESI + week charts */
.tq-esi-chart,
.tq-week-chart {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  height: 96px;
}
.tq-esi-col,
.tq-week-col {
  flex: 1;
  min-width: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}
.tq-esi-count,
.tq-week-count {
  font-size: 10.5px;
  font-weight: 800;
  line-height: 1;
  color: rgba(var(--v-theme-on-surface), 0.55);
  font-variant-numeric: tabular-nums;
}
.tq-esi-track,
.tq-week-track {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  background: rgba(var(--v-theme-on-surface), 0.045);
  border-radius: 5px;
  overflow: hidden;
}
.tq-esi-fill,
.tq-week-fill {
  width: 100%;
  border-radius: 4px 4px 0 0;
  transition: height 0.35s ease;
}
.tq-week-fill { background: rgba(var(--v-theme-on-surface), 0.22); }
.tq-week-col.is-today .tq-week-fill { background: var(--hero-main, #2f6dff); }
.tq-week-col.is-today .tq-week-count { color: var(--hero-main, #2f6dff); }
.tq-week-col.is-today .tq-week-name { color: var(--hero-main, #2f6dff); font-weight: 800; }
.tq-esi-name,
.tq-week-name {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.2px;
  color: rgba(var(--v-theme-on-surface), 0.4);
  white-space: nowrap;
}
.tq-esi-note {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 10px;
  font-size: 10px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.38);
}

/* ══ Queue panel ═════════════════════════════════════════════════════ */
.tq-panel {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-radius: 16px;
  overflow: hidden;
}
.tq-panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  padding: 11px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.025), transparent);
}
.tq-tabs { display: flex; gap: 5px; flex-wrap: wrap; }
.tq-tab {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 32px;
  padding: 0 12px;
  border-radius: 9px;
  border: 1px solid transparent;
  background: transparent;
  font-size: 12px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.58);
  cursor: pointer;
  transition: all 0.15s ease;
  white-space: nowrap;
}
.tq-tab:hover { background: rgba(var(--v-theme-on-surface), 0.05); }
.tq-tab.on {
  color: var(--hero-ink, #1e3a8a);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 11%, transparent);
  border-color: color-mix(in srgb, var(--hero-main, #2f6dff) 32%, transparent);
}
.tq-tab-count {
  font-size: 10px;
  font-weight: 800;
  padding: 1px 6px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  font-variant-numeric: tabular-nums;
}
.tq-tab.on .tq-tab-count {
  background: var(--hero-main, #2f6dff);
  color: #fff;
}

.tq-panel-tools { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.tq-seg {
  display: flex;
  gap: 3px;
  padding: 3px;
  border-radius: 10px;
  background: rgba(var(--v-theme-on-surface), 0.05);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.tq-seg-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 26px;
  padding: 0 10px;
  border-radius: 7px;
  border: none;
  background: transparent;
  font-size: 11.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.55);
  cursor: pointer;
  transition: all 0.14s ease;
}
.tq-seg-btn.on {
  background: rgb(var(--v-theme-surface));
  color: var(--hero-ink, #1e3a8a);
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.12);
}
.tq-filters { display: flex; align-items: center; gap: 8px; }
.tq-filter-search { width: 210px; }
.tq-filter-select { width: 128px; }

.tq-panel-body { padding: 14px; }

/* ══ Empty state ═════════════════════════════════════════════════════ */
.tq-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 46px 20px;
}
.tq-empty-icon {
  width: 56px; height: 56px;
  border-radius: 16px;
  display: grid; place-items: center;
  margin-bottom: 12px;
  color: var(--hero-main, #2f6dff);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--hero-main, #2f6dff) 22%, transparent);
}
.tq-empty h3 { font-size: 15px; font-weight: 800; margin: 0 0 3px; }
.tq-empty p {
  font-size: 12px;
  margin: 0 0 14px;
  max-width: 340px;
  color: rgba(var(--v-theme-on-surface), 0.48);
}
.tq-cta {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 36px;
  padding: 0 16px;
  border-radius: 10px;
  border: none;
  color: #fff;
  font-size: 12.5px;
  font-weight: 800;
  cursor: pointer;
  background: linear-gradient(120deg, var(--hero-deep, #1e3a8a), var(--hero-main, #2f6dff));
  transition: transform 0.15s ease;
}
.tq-cta:hover { transform: translateY(-1px); }

/* ══ Queue rows ══════════════════════════════════════════════════════ */
.tq-list { display: flex; flex-direction: column; gap: 9px; }

.tq-row-card,
.tq-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 11px 13px;
  border-radius: 13px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-left: 3px solid var(--tone, rgba(var(--v-theme-on-surface), 0.15));
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.tq-row-card:hover,
.tq-row:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 22px rgba(15, 23, 42, 0.09);
  border-color: color-mix(in srgb, var(--tone, var(--hero-main, #2f6dff)) 45%, transparent);
}
/* Wait-time edge colours override the tint when a patient is waiting too long. */
.tq-row.is-warn { border-left-color: #f59e0b; }
.tq-row.is-bad { border-left-color: #dc2626; }
.tq-row.is-ok { border-left-color: #16a34a; }

.tq-row-avatar {
  width: 42px; height: 42px;
  border-radius: 12px;
  display: grid; place-items: center;
  flex-shrink: 0;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.3px;
  color: var(--hero-ink, #1e3a8a);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 11%, transparent);
  border: 1px solid color-mix(in srgb, var(--hero-main, #2f6dff) 24%, transparent);
}
.tq-esi-ring {
  width: 46px; height: 46px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 0;
  flex-shrink: 0;
  border: 3px solid var(--tone);
  background: color-mix(in srgb, var(--tone) 8%, transparent);
}
.tq-esi-ring-num {
  font-size: 17px;
  font-weight: 800;
  line-height: 1;
  color: var(--tone);
}
.tq-esi-ring-label {
  font-size: 7.5px;
  font-weight: 800;
  letter-spacing: 0.6px;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

.tq-row-main { flex: 1; min-width: 0; }
.tq-row-title {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  margin-bottom: 2px;
}
.tq-row-name {
  font-size: 13.5px;
  font-weight: 800;
  letter-spacing: -0.1px;
  color: rgba(var(--v-theme-on-surface), 0.85);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 240px;
}
.tq-row-sub {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  min-width: 0;
}
.tq-row-complaint {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 380px;
}
.tq-row-docline {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 3px;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
  flex-wrap: wrap;
}
.tq-docname {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  margin-left: 6px;
  color: var(--hero-ink, #1e3a8a);
  font-weight: 700;
}

.tq-row-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
  flex-shrink: 0;
}
.tq-wait {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  padding: 2px 8px;
  border-radius: 7px;
}
.tq-wait.is-ok { color: #15803d; background: rgba(34, 197, 94, 0.12); }
.tq-wait.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.tq-wait.is-bad { color: #b91c1c; background: rgba(220, 38, 38, 0.12); }
.tq-wait.is-mini { font-size: 10.5px; padding: 1px 6px; }
.tq-row-arrived {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.34);
}

.tq-row-cta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 32px;
  padding: 0 12px;
  flex-shrink: 0;
  border-radius: 9px;
  border: 1px solid color-mix(in srgb, var(--hero-main, #2f6dff) 34%, transparent);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 8%, transparent);
  color: var(--hero-ink, #1e3a8a);
  font-size: 11.5px;
  font-weight: 800;
  cursor: pointer;
  transition: all 0.14s ease;
}
.tq-row-cta:hover {
  background: var(--hero-main, #2f6dff);
  color: #fff;
  border-color: var(--hero-main, #2f6dff);
}
.tq-row-cta.is-solid {
  background: linear-gradient(120deg, var(--hero-deep, #1e3a8a), var(--hero-main, #2f6dff));
  color: #fff;
  border-color: transparent;
}

/* ══ Tags ════════════════════════════════════════════════════════════ */
.tq-tag {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 7px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  white-space: nowrap;
  color: var(--tone, rgba(var(--v-theme-on-surface), 0.55));
  background: color-mix(in srgb, var(--tone, #94a3b8) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--tone, #94a3b8) 28%, transparent);
}
.tq-tag.is-warn { --tone: #f59e0b; }

/* ══ Board ═══════════════════════════════════════════════════════════ */
.tq-board {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  padding-bottom: 6px;
}
.tq-board-col {
  flex: 1;
  min-width: 220px;
  display: flex;
  flex-direction: column;
  border-radius: 13px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
}
.tq-board-head {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 9px 11px;
  border-bottom: 2px solid var(--tone);
  background: color-mix(in srgb, var(--tone) 7%, transparent);
}
.tq-board-badge {
  width: 20px; height: 20px;
  border-radius: 6px;
  display: grid; place-items: center;
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  color: #fff;
  background: var(--tone);
}
.tq-board-title {
  flex: 1;
  min-width: 0;
  font-size: 11.5px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.72);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tq-board-count {
  font-size: 10px;
  font-weight: 800;
  padding: 1px 7px;
  border-radius: 999px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 14%, transparent);
  font-variant-numeric: tabular-nums;
}
.tq-board-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 8px;
  max-height: 58vh;
  overflow-y: auto;
}
.tq-board-card {
  padding: 9px 10px;
  border-radius: 10px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-left: 3px solid rgba(var(--v-theme-on-surface), 0.15);
  cursor: pointer;
  transition: transform 0.14s ease, box-shadow 0.14s ease;
}
.tq-board-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 16px rgba(15, 23, 42, 0.1);
}
.tq-board-card.is-ok { border-left-color: #16a34a; }
.tq-board-card.is-warn { border-left-color: #f59e0b; }
.tq-board-card.is-bad { border-left-color: #dc2626; }
.tq-board-card-top {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 3px;
}
.tq-board-name {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  font-weight: 800;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: rgba(var(--v-theme-on-surface), 0.82);
}
.tq-board-complaint {
  font-size: 10.5px;
  line-height: 1.4;
  margin: 0 0 6px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.tq-board-card-foot { display: flex; gap: 4px; flex-wrap: wrap; }
.tq-board-empty {
  padding: 16px 8px;
  text-align: center;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.28);
}

/* ══ Table ═══════════════════════════════════════════════════════════ */
.tq-table { background: transparent; }
.tq-table :deep(thead th) {
  font-size: 9.5px !important;
  font-weight: 800 !important;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45) !important;
  background: rgba(var(--v-theme-on-surface), 0.025);
}
.tq-table :deep(tbody tr) { cursor: pointer; }
.tq-cell-patient { display: flex; align-items: center; gap: 8px; font-weight: 700; }
.tq-mini-avatar {
  width: 26px; height: 26px;
  border-radius: 8px;
  display: grid; place-items: center;
  flex-shrink: 0;
  font-size: 9.5px;
  font-weight: 800;
  color: var(--hero-ink, #1e3a8a);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 11%, transparent);
}
.tq-cell-time { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.5); }
.tq-dash { color: rgba(var(--v-theme-on-surface), 0.25); }
.tq-cell-actions { display: flex; gap: 3px; }
.tq-icon-btn {
  width: 28px; height: 28px;
  display: grid; place-items: center;
  border-radius: 8px;
  border: 1px solid transparent;
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.45);
  cursor: pointer;
  transition: all 0.14s ease;
}
.tq-icon-btn:hover {
  color: var(--hero-ink, #1e3a8a);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 10%, transparent);
}
.tq-icon-btn.is-accent:hover { color: #fff; background: var(--hero-main, #2f6dff); }

/* ══ Responsive ══════════════════════════════════════════════════════ */
@media (max-width: 1180px) {
  .tq-analytics { grid-template-columns: minmax(0, 1fr); }
  .tq-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 900px) {
  .tq-hero-top { flex-wrap: wrap; }
  .tq-hero-actions { width: 100%; }
  .tq-glass, .tq-solid { flex: 1; justify-content: center; }
  .tq-hero-stamp { margin-left: 0; }
  .tq-row-complaint { max-width: 200px; }
  .tq-filter-search { width: 150px; }
}
@media (max-width: 640px) {
  .tq-hero-title { font-size: 20px; }
  .tq-kpis { grid-template-columns: minmax(0, 1fr); }
  .tq-panel-head { flex-direction: column; align-items: stretch; }
  .tq-panel-tools { justify-content: space-between; }
  .tq-filters { width: 100%; }
  .tq-filter-search { flex: 1; width: auto; }
  .tq-filter-select { width: 104px; }
  .tq-row { flex-wrap: wrap; }
  .tq-row-meta { align-items: flex-start; width: 100%; }
  .tq-row-cta { width: 100%; justify-content: center; }
  .tq-critical { flex-wrap: wrap; }
  .tq-critical-btn { width: 100%; justify-content: center; }
  .tq-row-complaint { max-width: 180px; }
}
</style>
