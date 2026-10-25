<template>
  <v-container fluid class="pa-4 pa-md-6 cn-page">
    <!-- ── Header (deliberately NOT a branded hero) ───────────────── -->
    <div class="cn-head">
      <div class="cn-head-lead">
        <div class="cn-head-icon">
          <v-icon size="24">mdi-notebook-edit-outline</v-icon>
        </div>
        <div class="cn-head-text">
          <div class="cn-head-titlerow">
            <h1 class="cn-head-title">Care Notes</h1>
            <span class="cn-head-count">{{ noteCount }} {{ noteCount === 1 ? 'note' : 'notes' }}</span>
            <span v-if="urgentCount" class="cn-head-alert">
              <v-icon size="13">mdi-alert-circle</v-icon>
              {{ urgentCount }} urgent
            </span>
          </div>
          <p class="cn-head-sub">
            Nursing observations, assessments, handovers and follow-ups — one clinical timeline per patient.
          </p>
        </div>
      </div>

      <div class="cn-head-actions">
        <v-btn variant="outlined" rounded="lg" class="text-none cn-btn"
               prepend-icon="mdi-refresh" :loading="r.loading.value" @click="load()">
          Refresh
        </v-btn>
        <v-btn color="primary" rounded="lg" class="text-none cn-btn cn-btn-solid"
               prepend-icon="mdi-plus" @click="openDialog()">
          New note
        </v-btn>
      </div>
    </div>

    <!-- ── KPI tiles ──────────────────────────────────────────────── -->
    <div class="cn-kpis">
      <button v-for="k in kpis" :key="k.key" type="button" class="cn-kpi"
              :class="[`is-${k.tone}`, { 'is-on': activeKpi === k.key }]"
              @click="toggleKpi(k.key)">
        <span class="cn-kpi-icon"><v-icon size="18">{{ k.icon }}</v-icon></span>
        <span class="cn-kpi-body">
          <span class="cn-kpi-value">{{ k.value }}</span>
          <span class="cn-kpi-label">{{ k.label }}</span>
        </span>
        <span class="cn-kpi-hint">{{ k.hint }}</span>
      </button>
    </div>

    <!-- ── Toolbar ────────────────────────────────────────────────── -->
    <div class="cn-toolbar">
      <div class="cn-search">
        <v-icon size="18" class="cn-search-icon">mdi-magnify</v-icon>
        <input v-model="r.search.value" class="cn-search-input" type="search"
               placeholder="Search note text, patient, tag, author…" />
        <button v-if="r.search.value" type="button" class="cn-search-clear"
                aria-label="Clear search" @click="r.search.value = ''">
          <v-icon size="16">mdi-close</v-icon>
        </button>
      </div>

      <v-select v-model="catFilter" :items="catOptions" item-title="label" item-value="value"
                label="Type" variant="outlined" density="compact" hide-details
                clearable class="cn-select" />

      <v-select v-model="prioFilter" :items="prioOptions" item-title="label" item-value="value"
                label="Priority" variant="outlined" density="compact" hide-details
                clearable class="cn-select" />

      <v-select v-model="patientFilter" :items="patientOptions" item-title="label" item-value="value"
                label="Patient" variant="outlined" density="compact" hide-details
                clearable filterable class="cn-select cn-select-wide" />

      <v-select v-model="sortBy" :items="sortOptions" item-title="label" item-value="value"
                label="Sort" variant="outlined" density="compact" hide-details
                class="cn-select" />

      <div class="cn-seg">
        <button type="button" class="cn-seg-btn" :class="{ 'is-on': view === 'feed' }" @click="view = 'feed'">
          <v-icon size="15">mdi-view-agenda-outline</v-icon> Feed
        </button>
        <button type="button" class="cn-seg-btn" :class="{ 'is-on': view === 'table' }" @click="view = 'table'">
          <v-icon size="15">mdi-table</v-icon> Table
        </button>
      </div>
    </div>

    <!-- ── Body ───────────────────────────────────────────────────── -->
    <div class="cn-grid">
      <!-- Main column -->
      <div class="cn-main">
        <div v-if="r.loading.value && !notes.length" class="cn-skel">
          <div v-for="i in 4" :key="i" class="cn-skel-row" />
        </div>

        <v-alert v-else-if="r.error.value" type="error" variant="tonal" density="comfortable"
                 class="mb-3" closable @click:close="r.error.value = null">
          {{ r.error.value }}
        </v-alert>

        <div v-else-if="!visibleNotes.length" class="cn-empty">
          <div class="cn-empty-icon"><v-icon size="30">mdi-notebook-edit-outline</v-icon></div>
          <div class="cn-empty-title">{{ hasFilters ? 'No notes match these filters' : 'No care notes yet' }}</div>
          <div class="cn-empty-sub">
            {{ hasFilters ? 'Clear the filters or widen your search.' : 'Document the first observation to start the clinical timeline.' }}
          </div>
          <div class="cn-empty-actions">
            <v-btn v-if="hasFilters" variant="outlined" rounded="lg" class="text-none" @click="clearFilters">
              Clear filters
            </v-btn>
            <v-btn v-else color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openDialog()">
              New note
            </v-btn>
          </div>
        </div>

        <!-- Feed -->
        <div v-else-if="view === 'feed'" class="cn-feed">
          <article v-for="n in visibleNotes" :key="n.id" class="cn-note"
                   :class="[`tone-${n.category}`, { 'is-pinned': n.is_pinned, 'is-urgent': n.priority === 'urgent' }]">
            <span class="cn-note-accent" />

            <header class="cn-note-head">
              <span class="cn-note-chip" :class="`tone-${n.category}`">
                <v-icon size="13">{{ catMeta(n.category).icon }}</v-icon>
                {{ n.category_label || catMeta(n.category).label }}
              </span>
              <span class="cn-prio" :class="`prio-${n.priority}`">{{ n.priority_label || n.priority }}</span>
              <span v-if="n.is_pinned" class="cn-pin-flag"><v-icon size="13">mdi-pin</v-icon> Pinned</span>
              <span class="cn-note-spacer" />
              <time class="cn-note-when">{{ formatWhen(n.recorded_at) }}</time>
              <button type="button" class="cn-icon-btn" :title="n.is_pinned ? 'Unpin' : 'Pin'"
                      @click="togglePin(n)">
                <v-icon size="16">{{ n.is_pinned ? 'mdi-pin' : 'mdi-pin-outline' }}</v-icon>
              </button>
              <button type="button" class="cn-icon-btn" title="Edit" @click="openDialog(n)">
                <v-icon size="16">mdi-pencil-outline</v-icon>
              </button>
              <button type="button" class="cn-icon-btn cn-icon-btn-danger" title="Delete"
                      @click="confirmDelete(n)">
                <v-icon size="16">mdi-trash-can-outline</v-icon>
              </button>
            </header>

            <h3 v-if="n.title" class="cn-note-title">{{ n.title }}</h3>

            <p class="cn-note-body" :class="{ 'is-open': expanded.has(n.id) }">{{ n.content }}</p>
            <button v-if="needsToggle(n.content)" type="button" class="cn-more"
                    @click="toggleExpand(n.id)">
              {{ expanded.has(n.id) ? 'Show less' : 'Read more' }}
            </button>

            <div v-if="vitalPairs(n).length" class="cn-note-vitals">
              <span v-for="v in vitalPairs(n)" :key="v.key" class="cn-vital">
                <em>{{ v.label }}</em>{{ v.value }}<small>{{ v.unit }}</small>
              </span>
            </div>

            <div v-if="n.tags && n.tags.length" class="cn-note-tags">
              <span v-for="t in n.tags" :key="t" class="cn-tag">#{{ t }}</span>
            </div>

            <footer class="cn-note-foot">
              <span class="cn-note-patient">
                <span class="cn-avatar">{{ initials(n.patient_name) }}</span>
                <span class="cn-note-patient-text">
                  <strong>{{ n.patient_name || 'Unknown patient' }}</strong>
                  <small>{{ n.patient_display_id || n.patient_number }}</small>
                </span>
              </span>

              <span v-if="n.author_name" class="cn-note-author">
                <v-icon size="14">mdi-account-edit-outline</v-icon>
                {{ n.author_name }}
              </span>

              <span v-if="n.follow_up_at" class="cn-followup"
                    :class="{ 'is-due': isDue(n.follow_up_at), 'is-past': isPast(n.follow_up_at) }">
                <v-icon size="13">mdi-calendar-clock</v-icon>
                {{ followUpLabel(n.follow_up_at) }}
              </span>
            </footer>
          </article>
        </div>

        <!-- Table -->
        <v-card v-else flat rounded="lg" class="cn-table-card">
          <v-data-table :headers="headers" :items="visibleNotes" :items-per-page="25"
                        item-value="id" hover density="comfortable" class="cn-table">
            <template #item.patient_name="{ item }">
              <div class="cn-cell-patient">
                <span class="cn-avatar cn-avatar-sm">{{ initials(item.patient_name) }}</span>
                <div class="cn-cell-patient-text">
                  <strong>{{ item.patient_name || '—' }}</strong>
                  <small>{{ item.patient_display_id || item.patient_number || '' }}</small>
                </div>
              </div>
            </template>
            <template #item.category="{ item }">
              <span class="cn-note-chip" :class="`tone-${item.category}`">
                <v-icon size="12">{{ catMeta(item.category).icon }}</v-icon>
                {{ item.category_label || item.category }}
              </span>
            </template>
            <template #item.priority="{ item }">
              <span class="cn-prio" :class="`prio-${item.priority}`">{{ item.priority_label || item.priority }}</span>
            </template>
            <template #item.content="{ item }">
              <span class="cn-cell-clip">{{ item.title || item.content }}</span>
            </template>
            <template #item.recorded_at="{ item }">
              <span class="cn-cell-when">{{ formatWhen(item.recorded_at) }}</span>
            </template>
            <template #item.actions="{ item }">
              <div class="cn-cell-actions">
                <button type="button" class="cn-icon-btn" title="Edit" @click="openDialog(item)">
                  <v-icon size="16">mdi-pencil-outline</v-icon>
                </button>
                <button type="button" class="cn-icon-btn cn-icon-btn-danger" title="Delete"
                        @click="confirmDelete(item)">
                  <v-icon size="16">mdi-trash-can-outline</v-icon>
                </button>
              </div>
            </template>
          </v-data-table>
        </v-card>
      </div>

      <!-- Rail -->
      <aside class="cn-rail">
        <section class="cn-card">
          <header class="cn-card-head">
            <v-icon size="16">mdi-chart-donut</v-icon>
            <span>Note mix</span>
            <span class="cn-card-count">{{ noteCount }}</span>
          </header>
          <div v-if="!noteMix.length" class="cn-card-empty">No notes recorded yet.</div>
          <ul v-else class="cn-mix">
            <li v-for="m in noteMix" :key="m.value" class="cn-mix-row">
              <button type="button" class="cn-mix-btn" @click="catFilter = catFilter === m.value ? null : m.value">
                <span class="cn-mix-dot" :style="{ background: m.color }" />
                <span class="cn-mix-label">{{ m.label }}</span>
                <span class="cn-mix-bar">
                  <span class="cn-mix-fill" :style="{ width: m.pct + '%', background: m.color }" />
                </span>
                <span class="cn-mix-num">{{ m.count }}</span>
              </button>
            </li>
          </ul>
        </section>

        <section class="cn-card">
          <header class="cn-card-head">
            <v-icon size="16">mdi-calendar-clock</v-icon>
            <span>Follow-ups</span>
            <span class="cn-card-count">{{ followUps.length }}</span>
          </header>
          <div v-if="!followUps.length" class="cn-card-empty">No follow-ups scheduled.</div>
          <ul v-else class="cn-follow">
            <li v-for="f in followUps" :key="f.id" class="cn-follow-row" @click="openDialog(f)">
              <span class="cn-follow-dot" :class="{ 'is-over': isPast(f.follow_up_at) }" />
              <span class="cn-follow-text">
                <strong>{{ f.patient_name || 'Patient' }}</strong>
                <small>{{ followUpLabel(f.follow_up_at) }}</small>
              </span>
              <v-icon size="14" class="cn-follow-go">mdi-chevron-right</v-icon>
            </li>
          </ul>
        </section>

        <section class="cn-card">
          <header class="cn-card-head">
            <v-icon size="16">mdi-account-multiple-outline</v-icon>
            <span>Most documented</span>
          </header>
          <div v-if="!topPatients.length" class="cn-card-empty">No patients yet.</div>
          <ul v-else class="cn-top">
            <li v-for="p in topPatients" :key="p.id" class="cn-top-row"
                @click="patientFilter = patientFilter === p.id ? null : p.id">
              <span class="cn-avatar cn-avatar-sm">{{ initials(p.name) }}</span>
              <span class="cn-top-text">
                <strong>{{ p.name }}</strong>
                <small>{{ p.number }}</small>
              </span>
              <span class="cn-top-count">{{ p.count }}</span>
            </li>
          </ul>
        </section>
      </aside>
    </div>

    <!-- ── Create / edit dialog ───────────────────────────────────── -->
    <v-dialog v-model="dialog" max-width="880" persistent scrollable>
      <v-card rounded="lg" class="cn-dialog">
        <BrandDialogHeader :icon="editing ? 'mdi-pencil-outline' : 'mdi-notebook-plus-outline'"
                           :title="editing ? 'Edit care note' : 'New care note'"
                           :subtitle="editing ? 'Update the clinical record' : 'Document an observation, assessment or handover'"
                           @close="dialog = false" />

        <v-card-text class="cn-dialog-body">
          <v-form ref="formRef" @submit.prevent="saveNote">
            <v-row dense>
              <v-col cols="12" md="7">
                <v-select v-model="form.patient" :items="patientOptions" item-title="label" item-value="value"
                          label="Patient" variant="outlined" density="comfortable" :rules="req"
                          prepend-inner-icon="mdi-account-outline" filterable :loading="patientR.loading.value" />
              </v-col>
              <v-col cols="12" md="5">
                <v-text-field v-model="form.recorded_at" type="datetime-local" label="Clinical time"
                              variant="outlined" density="comfortable" prepend-inner-icon="mdi-clock-outline" />
              </v-col>
            </v-row>

            <div class="cn-field">
              <div class="cn-field-head">
                <span class="cn-field-label">Note type</span>
                <span class="cn-field-value">{{ catMeta(form.category).label }}</span>
              </div>
              <div class="cn-type-grid">
                <button v-for="c in categories" :key="c.value" type="button"
                        class="cn-type-tile" :class="[`tone-${c.value}`, { 'is-on': form.category === c.value }]"
                        @click="form.category = c.value">
                  <v-icon size="17">{{ c.icon }}</v-icon>
                  <span>{{ c.label }}</span>
                </button>
              </div>
            </div>

            <div class="cn-field">
              <div class="cn-field-head">
                <span class="cn-field-label">Priority</span>
                <span class="cn-field-value">{{ prioMeta(form.priority).label }}</span>
              </div>
              <div class="cn-prio-row">
                <button v-for="p in priorities" :key="p.value" type="button"
                        class="cn-prio-tile" :class="[`prio-${p.value}`, { 'is-on': form.priority === p.value }]"
                        @click="form.priority = p.value">
                  <v-icon size="16">{{ p.icon }}</v-icon>
                  <span>{{ p.label }}</span>
                  <small>{{ p.desc }}</small>
                </button>
              </div>
            </div>

            <v-text-field v-model="form.title" label="Headline (optional)" variant="outlined"
                          density="comfortable" prepend-inner-icon="mdi-format-title"
                          counter="140" maxlength="140" class="mb-1" />

            <v-textarea v-model="form.content" label="Note" variant="outlined" rows="6" auto-grow
                        :rules="req" prepend-inner-icon="mdi-text-box-outline"
                        placeholder="Objective findings, care given, patient response, plan…" />

            <div class="cn-field">
              <button type="button" class="cn-fold" @click="vitalsOpen = !vitalsOpen">
                <v-icon size="16">{{ vitalsOpen ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
                <span>Attach a vital-sign snapshot</span>
                <span v-if="vitalsFilled" class="cn-fold-badge">{{ vitalsFilled }} recorded</span>
              </button>
              <div v-if="vitalsOpen" class="cn-vitals-grid">
                <v-text-field v-for="v in vitalFields" :key="v.key" v-model.number="form.vitals[v.key]"
                              :label="v.label" :suffix="v.unit" type="number" :step="v.step"
                              variant="outlined" density="compact" hide-details />
              </div>
            </div>

            <v-row dense class="mt-1">
              <v-col cols="12" md="7">
                <v-combobox v-model="form.tags" :items="tagSuggestions" label="Tags"
                            variant="outlined" density="comfortable" multiple chips closable-chips
                            hide-details="auto" prepend-inner-icon="mdi-tag-outline"
                            hint="Free text — press Enter to add" persistent-hint />
              </v-col>
              <v-col cols="12" md="5">
                <v-text-field v-model="form.follow_up_at" type="datetime-local" label="Follow-up"
                              variant="outlined" density="comfortable" hide-details
                              prepend-inner-icon="mdi-calendar-clock" />
              </v-col>
            </v-row>

            <div class="cn-pin-row">
              <v-switch v-model="form.is_pinned" color="primary" density="compact" hide-details
                        label="Pin to top of the timeline" />
            </div>

            <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mt-2">
              {{ r.error.value }}
            </v-alert>
          </v-form>
        </v-card-text>

        <v-divider />
        <v-card-actions class="cn-dialog-actions">
          <span class="cn-dialog-hint">
            {{ wordCount }} words
          </span>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="r.saving.value" @click="saveNote">
            {{ editing ? 'Save changes' : 'Create note' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Delete ─────────────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="440">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-trash-can-outline" title="Delete this note?"
                           subtitle="This cannot be undone" @close="deleteDialog = false" />
        <v-card-text>
          <div class="cn-del-body">
            <div class="cn-del-icon"><v-icon size="22">mdi-alert-outline</v-icon></div>
            <div>
              The note for <strong>{{ deleteTarget?.patient_name || 'this patient' }}</strong>
              will be permanently removed from the clinical timeline.
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
import { useResource } from '~/composables/useResource'

definePageMeta({ title: 'Care Notes' })

const r = useResource('/patients/care-notes/')
const patientR = useResource('/patients/')

/* ── Option sets ─────────────────────────────────────────────── */
const categories = [
  { value: 'observation', label: 'Observation', icon: 'mdi-eye-outline', color: '#0ea5e9' },
  { value: 'assessment', label: 'Assessment', icon: 'mdi-clipboard-pulse-outline', color: '#6366f1' },
  { value: 'nursing', label: 'Nursing care', icon: 'mdi-hand-heart-outline', color: '#14b8a6' },
  { value: 'medication', label: 'Medication', icon: 'mdi-pill', color: '#f59e0b' },
  { value: 'procedure', label: 'Procedure', icon: 'mdi-needle', color: '#8b5cf6' },
  { value: 'handover', label: 'Handover', icon: 'mdi-swap-horizontal', color: '#0891b2' },
  { value: 'incident', label: 'Incident', icon: 'mdi-alert-octagon-outline', color: '#ef4444' },
  { value: 'diet', label: 'Diet', icon: 'mdi-food-apple-outline', color: '#84cc16' },
  { value: 'activity', label: 'Activity', icon: 'mdi-walk', color: '#f97316' },
  { value: 'follow_up', label: 'Follow-up', icon: 'mdi-calendar-check-outline', color: '#10b981' },
  { value: 'general', label: 'General', icon: 'mdi-note-outline', color: '#64748b' },
]

const priorities = [
  { value: 'routine', label: 'Routine', desc: 'Normal documentation', icon: 'mdi-circle-outline' },
  { value: 'important', label: 'Important', desc: 'Needs a review today', icon: 'mdi-alert-outline' },
  { value: 'urgent', label: 'Urgent', desc: 'Escalate now', icon: 'mdi-alert-decagram-outline' },
]

const vitalFields = [
  { key: 'temp', label: 'Temp', unit: '°C', step: 0.1 },
  { key: 'pulse', label: 'Pulse', unit: 'bpm', step: 1 },
  { key: 'resp', label: 'Resp', unit: '/min', step: 1 },
  { key: 'systolic', label: 'Systolic', unit: 'mmHg', step: 1 },
  { key: 'diastolic', label: 'Diastolic', unit: 'mmHg', step: 1 },
  { key: 'spo2', label: 'SpO₂', unit: '%', step: 1 },
]

const tagSuggestions = [
  'wound-care', 'pain', 'fall-risk', 'mobility', 'hydration', 'nutrition',
  'hygiene', 'pressure-area', 'catheter', 'iv-line', 'infection', 'escalated',
]

const sortOptions = [
  { value: 'newest', label: 'Newest first' },
  { value: 'oldest', label: 'Oldest first' },
  { value: 'priority', label: 'Priority' },
  { value: 'patient', label: 'Patient A–Z' },
]

/* ── State ───────────────────────────────────────────────────── */
const catFilter = ref(null)
const prioFilter = ref(null)
const patientFilter = ref(null)
const sortBy = ref('newest')
const view = ref('feed')
const activeKpi = ref(null)
const expanded = reactive(new Set())
const dialog = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const deleting = ref(false)
const editing = ref(null)
const vitalsOpen = ref(false)
const formRef = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })
const req = [v => (v !== null && v !== undefined && String(v).trim() !== '') || 'Required']

const nowTick = ref(Date.now())

function toLocalInput(date) {
  const d = date instanceof Date ? date : new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const blankForm = () => ({
  patient: null,
  category: 'observation',
  priority: 'routine',
  title: '',
  content: '',
  tags: [],
  recorded_at: toLocalInput(new Date()),
  follow_up_at: '',
  is_pinned: false,
  vitals: { temp: null, pulse: null, resp: null, systolic: null, diastolic: null, spo2: null },
})
const form = reactive(blankForm())

/* ── Data ────────────────────────────────────────────────────── */
async function load() {
  await Promise.all([
    r.list({ page_size: 1000 }),
    patientR.list({ page_size: 1000 }),
  ])
}

onMounted(() => {
  load()
  const t = setInterval(() => { nowTick.value = Date.now() }, 60000)
  onBeforeUnmount(() => clearInterval(t))
})

const notes = computed(() => r.items.value || [])
const noteCount = computed(() => notes.value.length)

const patientOptions = computed(() =>
  (patientR.items.value || []).map(p => ({
    value: p.id,
    label: [p.patient_id || p.patient_number, p.user_name].filter(Boolean).join(' — '),
  })),
)

const catOptions = computed(() => categories.map(c => ({ value: c.value, label: c.label })))
const prioOptions = computed(() => priorities.map(p => ({ value: p.value, label: p.label })))

/* ── KPI tiles ───────────────────────────────────────────────── */
const urgentCount = computed(() => notes.value.filter(n => n.priority === 'urgent').length)
const weekCount = computed(() => {
  const cut = Date.now() - 7 * 86400000
  return notes.value.filter(n => new Date(n.recorded_at).getTime() >= cut).length
})
const pinnedCount = computed(() => notes.value.filter(n => n.is_pinned).length)

const kpis = computed(() => [
  { key: 'all', label: 'Total notes', value: noteCount.value, icon: 'mdi-notebook-outline', tone: 'slate', hint: 'All documentation' },
  { key: 'urgent', label: 'Urgent', value: urgentCount.value, icon: 'mdi-alert-decagram-outline', tone: 'red', hint: 'Needs escalation' },
  { key: 'week', label: 'This week', value: weekCount.value, icon: 'mdi-calendar-week-outline', tone: 'teal', hint: 'Last 7 days' },
  { key: 'pinned', label: 'Pinned', value: pinnedCount.value, icon: 'mdi-pin-outline', tone: 'amber', hint: 'Kept on top' },
])

function toggleKpi(key) {
  if (key === 'all') activeKpi.value = null
  else activeKpi.value = activeKpi.value === key ? null : key
}

/* ── Filtering ───────────────────────────────────────────────── */
const hasFilters = computed(() =>
  !!(r.search.value || catFilter.value || prioFilter.value || patientFilter.value || activeKpi.value),
)

const visibleNotes = computed(() => {
  let list = [...notes.value]

  const q = (r.search.value || '').trim().toLowerCase()
  if (q) {
    list = list.filter(n => [
      n.title, n.content, n.patient_name, n.patient_display_id, n.patient_number,
      n.author_name, (n.tags || []).join(' '), n.category_label,
    ].filter(Boolean).join(' ').toLowerCase().includes(q))
  }
  if (catFilter.value) list = list.filter(n => n.category === catFilter.value)
  if (prioFilter.value) list = list.filter(n => n.priority === prioFilter.value)
  if (patientFilter.value) list = list.filter(n => n.patient === patientFilter.value)

  if (activeKpi.value === 'urgent') list = list.filter(n => n.priority === 'urgent')
  if (activeKpi.value === 'pinned') list = list.filter(n => n.is_pinned)
  if (activeKpi.value === 'week') {
    const cut = Date.now() - 7 * 86400000
    list = list.filter(n => new Date(n.recorded_at).getTime() >= cut)
  }

  const rank = { urgent: 0, important: 1, routine: 2 }
  if (sortBy.value === 'oldest') {
    list.sort((a, b) => new Date(a.recorded_at) - new Date(b.recorded_at))
  } else if (sortBy.value === 'priority') {
    list.sort((a, b) => (rank[a.priority] ?? 9) - (rank[b.priority] ?? 9)
      || new Date(b.recorded_at) - new Date(a.recorded_at))
  } else if (sortBy.value === 'patient') {
    list.sort((a, b) => (a.patient_name || '').localeCompare(b.patient_name || ''))
  } else {
    list.sort((a, b) => (Number(b.is_pinned) - Number(a.is_pinned))
      || (new Date(b.recorded_at) - new Date(a.recorded_at)))
  }

  return list
})

function clearFilters() {
  r.search.value = ''
  catFilter.value = null
  prioFilter.value = null
  patientFilter.value = null
  activeKpi.value = null
}

/* ── Rail analytics ──────────────────────────────────────────── */
const noteMix = computed(() => {
  const total = noteCount.value || 1
  return categories
    .map(c => {
      const count = notes.value.filter(n => n.category === c.value).length
      return { value: c.value, label: c.label, color: c.color, count, pct: Math.round((count / total) * 100) }
    })
    .filter(c => c.count > 0)
    .sort((a, b) => b.count - a.count)
})

const followUps = computed(() =>
  notes.value
    .filter(n => n.follow_up_at)
    .sort((a, b) => new Date(a.follow_up_at) - new Date(b.follow_up_at))
    .slice(0, 6),
)

const topPatients = computed(() => {
  const map = new Map()
  for (const n of notes.value) {
    if (!n.patient) continue
    const row = map.get(n.patient) || {
      id: n.patient,
      name: n.patient_name || 'Patient',
      number: n.patient_display_id || n.patient_number || '',
      count: 0,
    }
    row.count += 1
    map.set(n.patient, row)
  }
  return [...map.values()].sort((a, b) => b.count - a.count).slice(0, 5)
})

/* ── Table headers ───────────────────────────────────────────── */
const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false, width: 220 },
  { title: 'Type', key: 'category', sortable: false, width: 150 },
  { title: 'Priority', key: 'priority', sortable: false, width: 120 },
  { title: 'Note', key: 'content', sortable: false },
  { title: 'When', key: 'recorded_at', sortable: false, width: 190 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 96 },
]

/* ── Helpers ─────────────────────────────────────────────────── */
function catMeta(value) {
  return categories.find(c => c.value === value) || categories[categories.length - 1]
}
function prioMeta(value) {
  return priorities.find(p => p.value === value) || priorities[0]
}
function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0].toUpperCase()).join('')
}

function formatWhen(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  const mins = Math.floor((nowTick.value - d.getTime()) / 60000)
  if (mins >= 0 && mins < 1) return 'Just now'
  if (mins >= 0 && mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs >= 0 && hrs < 24) return `${hrs}h ago`
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
    + ' · ' + d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}

function isPast(iso) {
  return iso ? new Date(iso).getTime() < nowTick.value : false
}
function isDue(iso) {
  if (!iso) return false
  const t = new Date(iso).getTime()
  return t >= nowTick.value && (t - nowTick.value) < 86400000
}
function followUpLabel(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return `Follow-up ${d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })}`
}

function needsToggle(text) {
  return (text || '').length > 240
}
function toggleExpand(id) {
  if (expanded.has(id)) expanded.delete(id)
  else expanded.add(id)
}

const VITAL_LABELS = { temp: 'Temp', pulse: 'Pulse', resp: 'Resp', spo2: 'SpO₂' }
const VITAL_UNITS = { temp: '°C', pulse: 'bpm', resp: '/min', spo2: '%' }

function vitalPairs(note) {
  const v = note?.vitals || {}
  const out = []
  if (v.systolic || v.diastolic) {
    out.push({ key: 'bp', label: 'BP', value: `${v.systolic || '—'}/${v.diastolic || '—'}`, unit: 'mmHg' })
  }
  for (const key of ['temp', 'pulse', 'resp', 'spo2']) {
    if (v[key] !== null && v[key] !== undefined && v[key] !== '') {
      out.push({ key, label: VITAL_LABELS[key], value: v[key], unit: VITAL_UNITS[key] })
    }
  }
  return out
}

const vitalsFilled = computed(() =>
  Object.values(form.vitals || {}).filter(v => v !== null && v !== undefined && v !== '').length,
)

const wordCount = computed(() => {
  const t = (form.content || '').trim()
  return t ? t.split(/\s+/).length : 0
})

function toIsoOrNull(local) {
  if (!local) return null
  const d = new Date(local)
  return Number.isNaN(d.getTime()) ? null : d.toISOString()
}

/* ── Dialog ──────────────────────────────────────────────────── */
function openDialog(note) {
  r.error.value = null
  if (note) {
    editing.value = note.id
    Object.assign(form, {
      patient: note.patient,
      category: note.category || 'observation',
      priority: note.priority || 'routine',
      title: note.title || '',
      content: note.content || '',
      tags: Array.isArray(note.tags) ? [...note.tags] : [],
      recorded_at: toLocalInput(note.recorded_at),
      follow_up_at: note.follow_up_at ? toLocalInput(note.follow_up_at) : '',
      is_pinned: !!note.is_pinned,
      vitals: {
        temp: note.vitals?.temp ?? null,
        pulse: note.vitals?.pulse ?? null,
        resp: note.vitals?.resp ?? null,
        systolic: note.vitals?.systolic ?? null,
        diastolic: note.vitals?.diastolic ?? null,
        spo2: note.vitals?.spo2 ?? null,
      },
    })
    vitalsOpen.value = vitalPairs(note).length > 0
  } else {
    editing.value = null
    Object.assign(form, blankForm())
    if (patientFilter.value) form.patient = patientFilter.value
    if (catFilter.value) form.category = catFilter.value
    vitalsOpen.value = false
  }
  dialog.value = true
}

function buildPayload() {
  const vitals = {}
  for (const [k, v] of Object.entries(form.vitals || {})) {
    if (v !== null && v !== undefined && v !== '') vitals[k] = v
  }
  return {
    patient: form.patient,
    category: form.category,
    priority: form.priority,
    title: (form.title || '').trim(),
    content: (form.content || '').trim(),
    tags: (form.tags || []).map(t => String(t).trim()).filter(Boolean),
    recorded_at: toIsoOrNull(form.recorded_at) || new Date().toISOString(),
    follow_up_at: toIsoOrNull(form.follow_up_at),
    is_pinned: !!form.is_pinned,
    vitals,
  }
}

async function saveNote() {
  const valid = await formRef.value?.validate()
  if (valid?.valid === false) return
  try {
    const payload = buildPayload()
    if (editing.value) {
      await r.update(editing.value, payload)
      flash('Care note updated')
    } else {
      await r.create(payload)
      flash('Care note created')
    }
    dialog.value = false
    await load()
  } catch {
    showSnack(r.error.value || 'Could not save the note', 'error')
  }
}

async function togglePin(note) {
  try {
    await r.update(note.id, { is_pinned: !note.is_pinned })
    note.is_pinned = !note.is_pinned
  } catch {
    showSnack(r.error.value || 'Could not update the note', 'error')
  }
}

function confirmDelete(note) {
  deleteTarget.value = note
  deleteDialog.value = true
}

async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    deleteDialog.value = false
    deleteTarget.value = null
    flash('Care note deleted')
  } catch {
    showSnack(r.error.value || 'Could not delete the note', 'error')
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
.cn-page { width: 100%; }

/* ── Header ── */
.cn-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 16px; flex-wrap: wrap; margin-bottom: 16px;
}
.cn-head-lead { display: flex; align-items: center; gap: 14px; min-width: 0; }
.cn-head-icon {
  width: 50px; height: 50px; border-radius: 15px; flex: 0 0 auto;
  display: grid; place-items: center;
  color: #fff;
  background: linear-gradient(135deg, #4f46e5, #0ea5e9);
  box-shadow: 0 10px 24px rgba(79, 70, 229, 0.28);
}
.cn-head-text { min-width: 0; }
.cn-head-titlerow { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.cn-head-title { font-size: 22px; font-weight: 800; letter-spacing: -0.02em; line-height: 1.2; margin: 0; }
.cn-head-count {
  font-size: 11.5px; font-weight: 700; letter-spacing: 0.03em;
  padding: 2px 9px; border-radius: 999px;
  background: rgba(15, 23, 42, 0.06); color: rgba(15, 23, 42, 0.62);
}
.cn-head-alert {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11.5px; font-weight: 700;
  padding: 2px 9px; border-radius: 999px;
  background: rgba(239, 68, 68, 0.12); color: #dc2626;
}
.cn-head-sub { margin: 3px 0 0; font-size: 13px; line-height: 1.45; color: rgba(15, 23, 42, 0.55); }
.cn-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.cn-btn { height: 42px !important; font-weight: 600; }
.cn-btn-solid { color: #fff !important; }

/* ── KPI tiles ── */
.cn-kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-bottom: 14px; }
.cn-kpi {
  position: relative; display: flex; align-items: center; gap: 11px;
  padding: 13px 14px; border-radius: 14px; text-align: left;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease;
  cursor: pointer;
}
.cn-kpi:hover { transform: translateY(-1px); box-shadow: 0 8px 20px rgba(15, 23, 42, 0.08); }
.cn-kpi.is-on { border-color: rgba(79, 70, 229, 0.45); box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.12); }
.cn-kpi-icon {
  width: 34px; height: 34px; border-radius: 11px; flex: 0 0 auto;
  display: grid; place-items: center;
}
.cn-kpi-body { display: flex; flex-direction: column; min-width: 0; }
.cn-kpi-value { font-size: 19px; font-weight: 800; line-height: 1.1; letter-spacing: -0.02em; }
.cn-kpi-label { font-size: 11.5px; font-weight: 600; color: rgba(15, 23, 42, 0.55); }
.cn-kpi-hint { margin-left: auto; font-size: 10.5px; color: rgba(15, 23, 42, 0.38); display: none; }
.cn-kpi.is-slate .cn-kpi-icon { background: rgba(100, 116, 139, 0.14); color: #475569; }
.cn-kpi.is-red .cn-kpi-icon { background: rgba(239, 68, 68, 0.14); color: #dc2626; }
.cn-kpi.is-teal .cn-kpi-icon { background: rgba(20, 184, 166, 0.14); color: #0d9488; }
.cn-kpi.is-amber .cn-kpi-icon { background: rgba(245, 158, 11, 0.16); color: #d97706; }

/* ── Toolbar ── */
.cn-toolbar {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  padding: 10px 12px; margin-bottom: 14px;
  border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
}
.cn-search {
  position: relative; display: flex; align-items: center; gap: 8px;
  flex: 1 1 240px; min-width: 200px; height: 40px; padding: 0 12px;
  border-radius: 11px; background: rgba(15, 23, 42, 0.04);
  border: 1px solid transparent; transition: border-color .16s ease, background .16s ease;
}
.cn-search:focus-within { background: transparent; border-color: rgba(79, 70, 229, 0.45); }
.cn-search-icon { color: rgba(15, 23, 42, 0.42); }
.cn-search-input {
  flex: 1; min-width: 0; border: 0; outline: 0; background: transparent;
  font-size: 13.5px; color: inherit;
}
.cn-search-input::-webkit-search-cancel-button { display: none; }
.cn-search-clear {
  display: grid; place-items: center; width: 22px; height: 22px; border-radius: 6px;
  color: rgba(15, 23, 42, 0.5);
}
.cn-search-clear:hover { background: rgba(15, 23, 42, 0.08); }
.cn-select { flex: 0 0 148px; max-width: 148px; }
.cn-select-wide { flex: 0 0 208px; max-width: 208px; }

.cn-seg {
  display: inline-flex; gap: 2px; padding: 3px; border-radius: 11px;
  background: rgba(15, 23, 42, 0.05);
}
.cn-seg-btn {
  display: inline-flex; align-items: center; gap: 5px;
  height: 32px; padding: 0 11px; border-radius: 9px;
  font-size: 12px; font-weight: 600; color: rgba(15, 23, 42, 0.6);
  transition: background .16s ease, color .16s ease;
}
.cn-seg-btn.is-on { background: rgb(var(--v-theme-surface)); color: #4f46e5; box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12); }

/* ── Layout ── */
.cn-grid { display: grid; grid-template-columns: minmax(0, 1fr) 312px; gap: 14px; align-items: start; }
.cn-main { min-width: 0; }
.cn-rail { display: flex; flex-direction: column; gap: 12px; position: sticky; top: 12px; min-width: 0; }

/* ── Note cards ── */
.cn-feed { display: flex; flex-direction: column; gap: 10px; }
.cn-note {
  position: relative; padding: 14px 16px 13px 18px;
  border-radius: 14px; overflow: hidden;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: box-shadow .18s ease, border-color .18s ease, transform .18s ease;
}
.cn-note:hover { box-shadow: 0 10px 26px rgba(15, 23, 42, 0.08); transform: translateY(-1px); }
.cn-note.is-pinned { border-color: rgba(245, 158, 11, 0.42); }
.cn-note.is-urgent { border-color: rgba(239, 68, 68, 0.42); }
.cn-note-accent { position: absolute; inset: 0 auto 0 0; width: 4px; background: #64748b; }
.cn-note.tone-observation .cn-note-accent { background: #0ea5e9; }
.cn-note.tone-assessment .cn-note-accent { background: #6366f1; }
.cn-note.tone-nursing .cn-note-accent { background: #14b8a6; }
.cn-note.tone-medication .cn-note-accent { background: #f59e0b; }
.cn-note.tone-procedure .cn-note-accent { background: #8b5cf6; }
.cn-note.tone-handover .cn-note-accent { background: #0891b2; }
.cn-note.tone-incident .cn-note-accent { background: #ef4444; }
.cn-note.tone-diet .cn-note-accent { background: #84cc16; }
.cn-note.tone-activity .cn-note-accent { background: #f97316; }
.cn-note.tone-follow_up .cn-note-accent { background: #10b981; }
.cn-note.tone-general .cn-note-accent { background: #64748b; }

.cn-note-head { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.cn-note-spacer { flex: 1 1 auto; }
.cn-note-chip {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 3px 9px; border-radius: 999px;
  font-size: 11px; font-weight: 700; letter-spacing: 0.01em;
  background: rgba(100, 116, 139, 0.13); color: #475569;
}
.cn-note-chip.tone-observation { background: rgba(14, 165, 233, 0.14); color: #0369a1; }
.cn-note-chip.tone-assessment { background: rgba(99, 102, 241, 0.14); color: #4338ca; }
.cn-note-chip.tone-nursing { background: rgba(20, 184, 166, 0.15); color: #0f766e; }
.cn-note-chip.tone-medication { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.cn-note-chip.tone-procedure { background: rgba(139, 92, 246, 0.15); color: #6d28d9; }
.cn-note-chip.tone-handover { background: rgba(8, 145, 178, 0.15); color: #0e7490; }
.cn-note-chip.tone-incident { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }
.cn-note-chip.tone-diet { background: rgba(132, 204, 22, 0.18); color: #4d7c0f; }
.cn-note-chip.tone-activity { background: rgba(249, 115, 22, 0.15); color: #c2410c; }
.cn-note-chip.tone-follow_up { background: rgba(16, 185, 129, 0.15); color: #047857; }
.cn-note-chip.tone-general { background: rgba(100, 116, 139, 0.13); color: #475569; }

.cn-prio {
  display: inline-flex; align-items: center;
  padding: 2px 8px; border-radius: 6px;
  font-size: 10.5px; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase;
}
.cn-prio.prio-routine { background: rgba(100, 116, 139, 0.12); color: #475569; }
.cn-prio.prio-important { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.cn-prio.prio-urgent { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }

.cn-pin-flag { display: inline-flex; align-items: center; gap: 3px; font-size: 10.5px; font-weight: 700; color: #b45309; }
.cn-note-when { font-size: 11.5px; color: rgba(15, 23, 42, 0.45); white-space: nowrap; }

.cn-icon-btn {
  display: grid; place-items: center; width: 28px; height: 28px; border-radius: 8px;
  color: rgba(15, 23, 42, 0.45);
  transition: background .14s ease, color .14s ease;
}
.cn-icon-btn:hover { background: rgba(15, 23, 42, 0.06); color: #4f46e5; }
.cn-icon-btn-danger:hover { background: rgba(239, 68, 68, 0.1); color: #dc2626; }

.cn-note-title { margin: 9px 0 0; font-size: 14.5px; font-weight: 750; letter-spacing: -0.01em; line-height: 1.35; }
.cn-note-body {
  margin: 6px 0 0; font-size: 13.5px; line-height: 1.62;
  color: rgba(15, 23, 42, 0.72); white-space: pre-wrap;
  display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;
}
.cn-note-body.is-open { display: block; -webkit-line-clamp: unset; }
.cn-more { margin-top: 4px; font-size: 12px; font-weight: 700; color: #4f46e5; }
.cn-more:hover { text-decoration: underline; }

.cn-note-vitals { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.cn-vital {
  display: inline-flex; align-items: baseline; gap: 4px;
  padding: 3px 9px; border-radius: 8px;
  font-size: 12px; font-weight: 700;
  background: rgba(15, 23, 42, 0.045); color: rgba(15, 23, 42, 0.8);
}
.cn-vital em { font-style: normal; font-weight: 600; font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.cn-vital small { font-size: 10px; font-weight: 600; color: rgba(15, 23, 42, 0.42); }

.cn-note-tags { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 9px; }
.cn-tag {
  font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 999px;
  background: rgba(79, 70, 229, 0.08); color: #4338ca;
}

.cn-note-foot {
  display: flex; align-items: center; gap: 12px; flex-wrap: wrap;
  margin-top: 12px; padding-top: 10px;
  border-top: 1px solid rgba(15, 23, 42, 0.07);
}
.cn-note-patient { display: inline-flex; align-items: center; gap: 8px; min-width: 0; }
.cn-avatar {
  width: 28px; height: 28px; border-radius: 9px; flex: 0 0 auto;
  display: grid; place-items: center;
  font-size: 11px; font-weight: 800; color: #4338ca;
  background: rgba(79, 70, 229, 0.12);
}
.cn-avatar-sm { width: 24px; height: 24px; border-radius: 8px; font-size: 10px; }
.cn-note-patient-text { display: flex; flex-direction: column; min-width: 0; }
.cn-note-patient-text strong { font-size: 12.5px; font-weight: 700; }
.cn-note-patient-text small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.cn-note-author { display: inline-flex; align-items: center; gap: 4px; font-size: 11.5px; color: rgba(15, 23, 42, 0.5); }
.cn-followup {
  display: inline-flex; align-items: center; gap: 4px; margin-left: auto;
  font-size: 11px; font-weight: 700; padding: 3px 9px; border-radius: 999px;
  background: rgba(16, 185, 129, 0.12); color: #047857;
}
.cn-followup.is-due { background: rgba(245, 158, 11, 0.15); color: #b45309; }
.cn-followup.is-past { background: rgba(239, 68, 68, 0.13); color: #b91c1c; }

/* ── Table ── */
.cn-table-card { border: 1px solid rgba(15, 23, 42, 0.08); overflow: hidden; }
.cn-cell-patient { display: flex; align-items: center; gap: 8px; }
.cn-cell-patient-text { display: flex; flex-direction: column; }
.cn-cell-patient-text strong { font-size: 12.5px; font-weight: 700; }
.cn-cell-patient-text small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.cn-cell-clip {
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
  overflow: hidden; font-size: 12.5px;
}
.cn-cell-when { font-size: 12px; color: rgba(15, 23, 42, 0.6); white-space: nowrap; }
.cn-cell-actions { display: flex; justify-content: flex-end; gap: 2px; }

/* ── Rail cards ── */
.cn-card {
  padding: 13px 14px; border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
}
.cn-card-head {
  display: flex; align-items: center; gap: 7px;
  font-size: 12px; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase;
  color: rgba(15, 23, 42, 0.55); margin-bottom: 10px;
}
.cn-card-count {
  margin-left: auto; font-size: 11px; font-weight: 800;
  padding: 1px 8px; border-radius: 999px;
  background: rgba(15, 23, 42, 0.06); color: rgba(15, 23, 42, 0.6);
}
.cn-card-empty { font-size: 12px; color: rgba(15, 23, 42, 0.42); padding: 4px 0 2px; }

.cn-mix { display: flex; flex-direction: column; gap: 3px; }
.cn-mix-btn {
  display: flex; align-items: center; gap: 8px; width: 100%;
  padding: 5px 6px; border-radius: 8px; text-align: left;
  transition: background .14s ease;
}
.cn-mix-btn:hover { background: rgba(15, 23, 42, 0.04); }
.cn-mix-dot { width: 8px; height: 8px; border-radius: 3px; flex: 0 0 auto; }
.cn-mix-label {
  font-size: 12px; font-weight: 600; width: 82px; flex: 0 0 auto;
  color: rgba(15, 23, 42, 0.72); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.cn-mix-bar { flex: 1; height: 6px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.cn-mix-fill { display: block; height: 100%; border-radius: 999px; }
.cn-mix-num { font-size: 11.5px; font-weight: 800; color: rgba(15, 23, 42, 0.6); width: 18px; text-align: right; }

.cn-follow { display: flex; flex-direction: column; gap: 2px; }
.cn-follow-row {
  display: flex; align-items: center; gap: 9px; padding: 7px 6px;
  border-radius: 9px; cursor: pointer; transition: background .14s ease;
}
.cn-follow-row:hover { background: rgba(15, 23, 42, 0.04); }
.cn-follow-dot { width: 7px; height: 7px; border-radius: 50%; background: #10b981; flex: 0 0 auto; }
.cn-follow-dot.is-over { background: #ef4444; }
.cn-follow-text { display: flex; flex-direction: column; min-width: 0; }
.cn-follow-text strong { font-size: 12px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cn-follow-text small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.cn-follow-go { margin-left: auto; color: rgba(15, 23, 42, 0.3); }

.cn-top { display: flex; flex-direction: column; gap: 2px; }
.cn-top-row {
  display: flex; align-items: center; gap: 9px; padding: 6px;
  border-radius: 9px; cursor: pointer; transition: background .14s ease;
}
.cn-top-row:hover { background: rgba(15, 23, 42, 0.04); }
.cn-top-text { display: flex; flex-direction: column; min-width: 0; }
.cn-top-text strong { font-size: 12px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cn-top-text small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.cn-top-count {
  margin-left: auto; font-size: 11px; font-weight: 800;
  padding: 1px 8px; border-radius: 999px;
  background: rgba(79, 70, 229, 0.1); color: #4338ca;
}

/* ── Empty / skeleton ── */
.cn-empty {
  display: flex; flex-direction: column; align-items: center; text-align: center;
  padding: 54px 24px; border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px dashed rgba(15, 23, 42, 0.16);
}
.cn-empty-icon {
  width: 58px; height: 58px; border-radius: 18px; display: grid; place-items: center;
  background: rgba(79, 70, 229, 0.08); color: #4f46e5; margin-bottom: 12px;
}
.cn-empty-title { font-size: 15px; font-weight: 800; }
.cn-empty-sub { font-size: 13px; color: rgba(15, 23, 42, 0.5); margin-top: 3px; max-width: 420px; }
.cn-empty-actions { margin-top: 14px; }

.cn-skel { display: flex; flex-direction: column; gap: 10px; }
.cn-skel-row {
  height: 116px; border-radius: 14px;
  background: linear-gradient(90deg, rgba(15, 23, 42, 0.05), rgba(15, 23, 42, 0.09), rgba(15, 23, 42, 0.05));
  background-size: 200% 100%;
  animation: cnShimmer 1.4s ease-in-out infinite;
}
@keyframes cnShimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* ── Dialog ── */
.cn-dialog-body { padding: 18px 22px !important; }
.cn-dialog-actions { padding: 10px 18px !important; }
.cn-dialog-hint { font-size: 11.5px; color: rgba(15, 23, 42, 0.42); }
.cn-field { margin: 4px 0 14px; }
.cn-field-head { display: flex; align-items: baseline; gap: 8px; margin-bottom: 7px; }
.cn-field-label {
  font-size: 11px; font-weight: 800; letter-spacing: 0.06em; text-transform: uppercase;
  color: rgba(15, 23, 42, 0.5);
}
.cn-field-value { margin-left: auto; font-size: 12px; font-weight: 700; color: #4f46e5; }

.cn-type-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(122px, 1fr)); gap: 8px; }
.cn-type-tile {
  display: flex; align-items: center; gap: 7px;
  padding: 9px 10px; border-radius: 10px; text-align: left;
  font-size: 12px; font-weight: 650;
  background: rgba(15, 23, 42, 0.035);
  border: 1px solid transparent;
  color: rgba(15, 23, 42, 0.7);
  transition: border-color .14s ease, background .14s ease, color .14s ease;
}
.cn-type-tile:hover { background: rgba(15, 23, 42, 0.06); }
.cn-type-tile.is-on { background: rgba(79, 70, 229, 0.1); border-color: rgba(79, 70, 229, 0.4); color: #4338ca; }
.cn-type-tile.tone-medication.is-on { background: rgba(245, 158, 11, 0.13); border-color: rgba(245, 158, 11, 0.45); color: #b45309; }
.cn-type-tile.tone-incident.is-on { background: rgba(239, 68, 68, 0.12); border-color: rgba(239, 68, 68, 0.45); color: #b91c1c; }
.cn-type-tile.tone-nursing.is-on { background: rgba(20, 184, 166, 0.13); border-color: rgba(20, 184, 166, 0.45); color: #0f766e; }
.cn-type-tile.tone-follow_up.is-on { background: rgba(16, 185, 129, 0.13); border-color: rgba(16, 185, 129, 0.45); color: #047857; }

.cn-prio-row { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
.cn-prio-tile {
  display: flex; flex-direction: column; align-items: flex-start; gap: 2px;
  padding: 10px 11px; border-radius: 10px;
  background: rgba(15, 23, 42, 0.035); border: 1px solid transparent;
  text-align: left; transition: border-color .14s ease, background .14s ease;
}
.cn-prio-tile span { font-size: 12.5px; font-weight: 750; }
.cn-prio-tile small { font-size: 10.5px; color: rgba(15, 23, 42, 0.45); }
.cn-prio-tile.is-on.prio-routine { background: rgba(100, 116, 139, 0.13); border-color: rgba(100, 116, 139, 0.45); }
.cn-prio-tile.is-on.prio-important { background: rgba(245, 158, 11, 0.14); border-color: rgba(245, 158, 11, 0.5); }
.cn-prio-tile.is-on.prio-urgent { background: rgba(239, 68, 68, 0.12); border-color: rgba(239, 68, 68, 0.5); }
.cn-prio-tile.is-on.prio-important span { color: #b45309; }
.cn-prio-tile.is-on.prio-urgent span { color: #b91c1c; }

.cn-fold {
  display: flex; align-items: center; gap: 7px; width: 100%;
  padding: 8px 10px; border-radius: 10px;
  font-size: 12.5px; font-weight: 650; color: rgba(15, 23, 42, 0.7);
  background: rgba(15, 23, 42, 0.035);
  transition: background .14s ease;
}
.cn-fold:hover { background: rgba(15, 23, 42, 0.06); }
.cn-fold-badge {
  margin-left: auto; font-size: 10.5px; font-weight: 800;
  padding: 1px 8px; border-radius: 999px;
  background: rgba(79, 70, 229, 0.12); color: #4338ca;
}
.cn-vitals-grid {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(118px, 1fr));
  gap: 8px; margin-top: 8px;
}
.cn-pin-row { margin-top: 8px; }

.cn-del-body { display: flex; align-items: flex-start; gap: 12px; font-size: 13.5px; line-height: 1.55; }
.cn-del-icon {
  width: 40px; height: 40px; border-radius: 12px; flex: 0 0 auto;
  display: grid; place-items: center;
  background: rgba(239, 68, 68, 0.12); color: #dc2626;
}

/* ── Responsive ── */
@media (min-width: 1500px) {
  .cn-kpi-hint { display: block; }
}
@media (max-width: 1279px) {
  .cn-grid { grid-template-columns: minmax(0, 1fr); }
  .cn-rail { position: static; flex-direction: row; flex-wrap: wrap; }
  .cn-rail > .cn-card { flex: 1 1 280px; }
}
@media (max-width: 900px) {
  .cn-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cn-select, .cn-select-wide { flex: 1 1 140px; max-width: none; }
}
@media (max-width: 640px) {
  .cn-head { flex-direction: column; align-items: stretch; }
  .cn-head-actions { justify-content: stretch; }
  .cn-head-actions .cn-btn { flex: 1; }
  .cn-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
  .cn-kpi { padding: 10px 11px; }
  .cn-kpi-value { font-size: 17px; }
  .cn-kpi-hint { display: none; }
  .cn-prio-row { grid-template-columns: 1fr; }
  .cn-type-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cn-rail { flex-direction: column; }
  .cn-followup { margin-left: 0; }
  .cn-note { padding: 12px 13px 12px 15px; }
}
</style>
