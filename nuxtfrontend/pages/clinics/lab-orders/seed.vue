<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ═══════════ Hero ═══════════ -->
    <section class="sd-hero" :style="heroTheme">
      <span class="sd-hero-glow" />
      <span class="sd-hero-glow sd-hero-glow-2" />

      <div class="sd-hero-main">
        <NuxtLink to="/clinics/lab-orders?tab=catalog" class="sd-hero-back">
          <v-icon size="15">mdi-arrow-left</v-icon>
          <span>Lab catalogue</span>
        </NuxtLink>

        <div class="sd-hero-title">
          <span class="sd-hero-ico"><v-icon size="24">mdi-flask-outline</v-icon></span>
          <div>
            <h1>Build your laboratory catalogue</h1>
            <p>Review the starter library, adjust anything, then add only what your clinic runs.</p>
          </div>
        </div>

        <div class="sd-hero-stats">
          <div class="sd-hero-stat">
            <b>{{ meta.total_tests }}</b>
            <span>tests available</span>
          </div>
          <div class="sd-hero-stat">
            <b>{{ meta.total_panels }}</b>
            <span>panels available</span>
          </div>
          <div class="sd-hero-stat">
            <b>{{ selectedCount }}</b>
            <span>selected</span>
          </div>
          <div class="sd-hero-stat">
            <b>{{ customizedCount }}</b>
            <span>edited by you</span>
          </div>
        </div>
      </div>

      <div class="sd-hero-actions">
        <button type="button" class="sd-btn is-ghost" :disabled="loading || applying" @click="load">
          <v-icon size="15">mdi-refresh</v-icon>
          <span>Refresh</span>
        </button>
        <button
          type="button"
          class="sd-btn is-primary is-lg"
          :disabled="applying || loading || !selectedCount"
          @click="openReview"
        >
          <v-icon size="16" :class="{ 'sd-spin': applying }">
            {{ applying ? 'mdi-loading' : 'mdi-plus-box-multiple-outline' }}
          </v-icon>
          <span>
            {{ applying ? 'Adding…' : selectedCount ? `Add ${selectedCount} to my lab` : 'Select what to add' }}
          </span>
        </button>
      </div>
    </section>

    <!-- ═══════════ Toolbar ═══════════ -->
    <section class="sd-toolbar">
      <div class="sd-seg">
        <button
          v-for="tab in KIND_TABS"
          :key="tab.value"
          type="button"
          class="sd-seg-btn"
          :class="{ 'is-on': kind === tab.value }"
          @click="kind = tab.value"
        >
          <v-icon size="14">{{ tab.icon }}</v-icon>
          <span>{{ tab.label }}</span>
          <span class="sd-seg-count">{{ kindCount(tab.value) }}</span>
        </button>
      </div>

      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        placeholder="Search name, code, department…"
        variant="outlined"
        density="compact"
        hide-details
        clearable
        rounded="lg"
        class="sd-search"
      />

      <v-select
        v-model="department"
        :items="departmentOptions"
        label="Department"
        variant="outlined"
        density="compact"
        hide-details
        clearable
        rounded="lg"
        class="sd-select"
      />

      <div class="sd-quick">
        <button type="button" class="sd-mini-btn" @click="selectAll(true)">Select all</button>
        <button type="button" class="sd-mini-btn" @click="selectAll(false)">Clear</button>
        <button type="button" class="sd-mini-btn" @click="selectOnlyNew">Only new</button>
        <button type="button" class="sd-mini-btn is-warn" :disabled="!customizedCount" @click="resetAll">
          Reset edits
        </button>
      </div>
    </section>

    <!-- ═══════════ Progress ═══════════ -->
    <section class="sd-progress">
      <div class="sd-progress-head">
        <div>
          <b v-if="selectedCount">{{ selectedCount }} of {{ totalEntries }} selected</b>
          <b v-else>Nothing selected yet</b>
          <span v-if="selectedCount">{{ addedCount }} already in your catalogue · {{ lockedCount }} protected</span>
          <span v-else>Tap the circle on the tests and panels you want — only those get added.</span>
        </div>
        <span class="sd-progress-pct">{{ selectionPct }}%</span>
      </div>
      <div class="sd-bar">
        <span class="sd-bar-fill" :style="{ width: `${selectionPct}%` }" />
      </div>
    </section>

    <!-- ═══════════ Entries ═══════════ -->
    <div v-if="loading" class="sd-loading">
      <v-progress-circular indeterminate size="38" width="3" color="primary" />
      <span>Loading the starter library…</span>
    </div>

    <div v-else-if="!visibleEntries.length" class="sd-empty">
      <v-icon size="40">mdi-filter-off-outline</v-icon>
      <b>Nothing matches this filter</b>
      <span>Try a different department or clear the search.</span>
    </div>

    <div v-else class="sd-grid">
      <article
        v-for="entry in visibleEntries"
        :key="`${entry.kind}:${entry.code}`"
        class="sd-card"
        :class="{
          'is-picked': entry.is_selected && !entry.is_locked,
          'is-locked': entry.is_locked,
          'is-edited': entry.is_customized,
        }"
      >
        <header class="sd-card-head">
          <button
            type="button"
            class="sd-check"
            :class="{ 'is-on': entry.is_selected && !entry.is_locked }"
            :disabled="entry.is_locked"
            :aria-label="entry.is_selected ? `Deselect ${entry.name}` : `Select ${entry.name}`"
            @click="toggle(entry)"
          >
            <v-icon size="14">{{ entry.is_selected && !entry.is_locked ? 'mdi-check' : 'mdi-plus' }}</v-icon>
          </button>

          <div class="sd-card-id">
            <b>{{ entry.name }}</b>
            <span class="sd-card-meta">
              <em class="sd-code">{{ entry.code }}</em>
              <em v-if="entry.department">{{ entry.department }}</em>
            </span>
          </div>

          <span v-if="entry.is_locked" class="sd-flag is-locked" title="Already in your catalogue with hand-made data">
            <v-icon size="11">mdi-lock-outline</v-icon>
            yours
          </span>
          <span v-else-if="entry.is_customized" class="sd-flag is-edited">
            <v-icon size="11">mdi-pencil-outline</v-icon>
            edited
          </span>
          <span v-else-if="entry.existing_id" class="sd-flag is-added">
            <v-icon size="11">mdi-check-circle-outline</v-icon>
            added
          </span>

          <button
            type="button"
            class="sd-icon-btn"
            :disabled="entry.is_locked"
            :title="entry.is_locked ? 'Protected — you already own this code' : 'Review and edit'"
            @click="openEdit(entry)"
          >
            <v-icon size="15">mdi-tune-variant</v-icon>
          </button>
        </header>

        <p v-if="entry.description" class="sd-card-desc">{{ entry.description }}</p>

        <div class="sd-card-facts">
          <span v-if="entry.specimen_type" class="sd-fact">
            <v-icon size="12">mdi-water-outline</v-icon>{{ entry.specimen_type }}
          </span>
          <span v-if="entry.turnaround_time" class="sd-fact">
            <v-icon size="12">mdi-clock-outline</v-icon>{{ entry.turnaround_time }}
          </span>
          <span class="sd-fact is-price">
            <v-icon size="12">mdi-cash</v-icon>{{ money(entry.price) }}
          </span>
          <span v-if="entry.kind === 'test' && rangeCount(entry)" class="sd-fact">
            <v-icon size="12">mdi-format-list-numbered</v-icon>{{ rangeCount(entry) }} ref.
          </span>
          <span v-if="entry.kind === 'panel' && entry.test_codes?.length" class="sd-fact">
            <v-icon size="12">mdi-flask-outline</v-icon>{{ entry.test_codes.length }} tests
          </span>
        </div>

        <div v-if="entry.kind === 'panel' && entry.test_codes?.length" class="sd-panel-tests">
          <span v-for="code in entry.test_codes" :key="code" class="sd-test-chip">{{ code }}</span>
        </div>

        <p v-if="entry.is_locked" class="sd-card-locked-note">
          Your catalogue already has <b>{{ entry.existing_name }}</b> under this code — seeding never overwrites it.
        </p>
      </article>
    </div>

    <!-- ═══════════ Edit dialog ═══════════ -->
    <v-dialog v-model="editOpen" max-width="720" persistent>
      <v-card rounded="xl" class="sd-dlg" :style="heroTheme">
        <BrandDialogHeader
          icon="mdi-tune-variant"
          :title="`Edit ${editing?.kind === 'panel' ? 'panel' : 'test'}`"
          :subtitle="editing?.code"
          @close="editOpen = false"
        >
          <template #actions>
            <span class="sd-flag is-edited">Your copy</span>
          </template>
        </BrandDialogHeader>

        <div v-if="editing" class="sd-dlg-body">
          <div class="sd-dlg-grid">
            <v-text-field v-model="draft.name" label="Name on your catalogue" variant="outlined" density="compact" hide-details />
            <v-text-field v-model="draft.department" label="Department" variant="outlined" density="compact" hide-details />
          </div>

          <div class="sd-dlg-grid">
            <v-text-field
              v-model.number="draft.price"
              label="Price"
              type="number"
              prefix="KSh"
              variant="outlined"
              density="compact"
              hide-details
            />
            <v-text-field v-if="editing.kind === 'test'" v-model="draft.turnaround_time" label="Turnaround" variant="outlined" density="compact" hide-details />
            <v-text-field v-else v-model="draft.department" label="Department" variant="outlined" density="compact" hide-details />
          </div>

          <template v-if="editing.kind === 'test'">
            <v-text-field v-model="draft.specimen_type" label="Specimen" variant="outlined" density="compact" hide-details />
            <v-textarea
              v-model="draft.instructions"
              label="Instructions"
              rows="2"
              auto-grow
              variant="outlined"
              density="compact"
            />

            <div class="sd-ranges">
              <div class="sd-ranges-head">
                <b>Reference ranges</b>
                <v-btn size="x-small" variant="text" class="text-none" prepend-icon="mdi-plus" @click="addRange">
                  Add
                </v-btn>
              </div>
              <div v-for="(range, index) in draftRanges" :key="index" class="sd-range-row">
                <v-text-field v-model="range.key" placeholder="Analyte" variant="outlined" density="compact" hide-details />
                <v-text-field v-model="range.value" placeholder="Range" variant="outlined" density="compact" hide-details />
                <button type="button" class="sd-icon-btn" @click="draftRanges.splice(index, 1)">
                  <v-icon size="14">mdi-close</v-icon>
                </button>
              </div>
              <p v-if="!draftRanges.length" class="sd-ranges-empty">No reference ranges — optional.</p>
            </div>
          </template>

          <template v-else>
            <v-textarea
              v-model="draft.description"
              label="Description"
              rows="2"
              auto-grow
              variant="outlined"
              density="compact"
            />
            <div class="sd-ranges">
              <div class="sd-ranges-head"><b>Tests in this panel</b></div>
              <div class="sd-panel-picks">
                <button
                  v-for="test in panelTestOptions"
                  :key="test.code"
                  type="button"
                  class="sd-test-pick"
                  :class="{ 'is-on': draftTestCodes.includes(test.code) }"
                  @click="togglePanelTest(test.code)"
                >
                  <v-icon size="12">{{ draftTestCodes.includes(test.code) ? 'mdi-check' : 'mdi-plus' }}</v-icon>
                  {{ test.code }}
                </button>
              </div>
            </div>
          </template>

          <p v-if="editError" class="sd-err">
            <v-icon size="13">mdi-alert-circle-outline</v-icon>
            {{ editError }}
          </p>
        </div>

        <footer class="sd-dlg-actions">
          <button type="button" class="sd-btn is-ghost is-sm" @click="restoreDraft">Restore template</button>
          <v-spacer />
          <button type="button" class="sd-btn is-ghost is-sm" @click="editOpen = false">Cancel</button>
          <button type="button" class="sd-btn is-primary is-sm" @click="saveDraft">Save my version</button>
        </footer>
      </v-card>
    </v-dialog>

    <!-- ═══════════ Apply confirmation ═══════════ -->
    <InfoDialog
      v-model="info.open"
      :tone="info.tone"
      :title="info.title"
      :subtitle="info.subtitle"
      :message="info.message"
      :points="info.points"
      :hint="info.hint"
      :confirm-label="info.confirm"
      @confirm="applySelection"
    />

    <!-- ═══════════ Result toast ═══════════ -->
    <transition name="sdToast">
      <div v-if="notice" class="sd-notice" :class="`is-${notice.tone}`">
        <v-icon size="15">{{ notice.tone === 'bad' ? 'mdi-alert-circle-outline' : 'mdi-check-circle-outline' }}</v-icon>
        <span>{{ notice.message }}</span>
      </div>
    </transition>
  </v-container>
</template>

<script setup>
/**
 * Demo-catalogue review page.
 *
 * The starter library is a shared, immutable template. This page merges it with
 * the clinic's own overrides (saved server-side per tenant), lets the clinic
 * pick and edit entries, then writes only the selected ones into its own
 * catalogue. Hand-made tests that merely share a code are never overwritten.
 */
const { $api } = useNuxtApp()
const brand = useBranding()

const heroTheme = computed(() => ({
  '--sd-deep': brand.secondary.value,
  '--sd-main': brand.primary.value,
  '--sd-accent': brand.gradientStops.value[2],
  // Ink is only used on white surfaces (the primary hero button), never on the
  // gradient itself — that always takes white text.
  '--sd-ink': brand.ink.value,
  '--sd-glow': brand.tint('primary', 0.3),
  '--sd-glow-2': brand.tint('accent', 0.2),
}))

const KIND_TABS = [
  { value: 'all', label: 'Everything', icon: 'mdi-view-grid-outline' },
  { value: 'test', label: 'Tests', icon: 'mdi-test-tube' },
  { value: 'panel', label: 'Panels', icon: 'mdi-package-variant-closed' },
]

const loading = ref(true)
const applying = ref(false)
const tests = ref([])
const panels = ref([])
const meta = reactive({ total_tests: 0, total_panels: 0, departments: [] })

const kind = ref('all')
const search = ref('')
const department = ref(null)

/* ── Derived ──────────────────────────────────────────────────────────── */
const allEntries = computed(() => [...tests.value, ...panels.value])

const totalEntries = computed(() => allEntries.value.length)
const selectedCount = computed(() => allEntries.value.filter((e) => e.is_selected && !e.is_locked).length)
const customizedCount = computed(() => allEntries.value.filter((e) => e.is_customized).length)
const addedCount = computed(() => allEntries.value.filter((e) => e.is_applied).length)
const lockedCount = computed(() => allEntries.value.filter((e) => e.is_locked).length)
const selectionPct = computed(() =>
  totalEntries.value ? Math.round((selectedCount.value / totalEntries.value) * 100) : 0,
)

const departmentOptions = computed(() => meta.departments || [])

function kindCount(value) {
  if (value === 'test') return tests.value.length
  if (value === 'panel') return panels.value.length
  return allEntries.value.length
}

const visibleEntries = computed(() => {
  let list = allEntries.value
  if (kind.value !== 'all') list = list.filter((e) => e.kind === kind.value)
  if (department.value) list = list.filter((e) => e.department === department.value)
  const q = search.value?.trim().toLowerCase()
  if (q) {
    list = list.filter((e) =>
      [e.name, e.code, e.department, e.description, e.specimen_type]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q)),
    )
  }
  return list
})

/* ── Load ─────────────────────────────────────────────────────────────── */
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/lab/catalog/seed-preview/')
    tests.value = (data?.tests || []).map((t) => ({ ...t, kind: 'test' }))
    panels.value = (data?.panels || []).map((p) => ({ ...p, kind: 'panel' }))
    Object.assign(meta, data?.meta || {})
  } catch (error) {
    notify(apiError(error, 'Could not load the starter library.'), 'bad')
  } finally {
    loading.value = false
  }
}

/* ── Selection ────────────────────────────────────────────────────────── */
function toggle(entry) {
  if (entry.is_locked) return
  entry.is_selected = !entry.is_selected
}

function selectAll(value) {
  visibleEntries.value.forEach((entry) => {
    if (!entry.is_locked) entry.is_selected = value
  })
}

function selectOnlyNew() {
  visibleEntries.value.forEach((entry) => {
    if (!entry.is_locked) entry.is_selected = !entry.is_applied
  })
}

/* ── Edit dialog ──────────────────────────────────────────────────────── */
const editOpen = ref(false)
const editing = ref(null)
const editError = ref('')
const draft = reactive({
  name: '', department: '', specimen_type: '', turnaround_time: '',
  instructions: '', description: '', price: 0,
})
const draftRanges = ref([])
const draftTestCodes = ref([])

const panelTestOptions = computed(() =>
  tests.value.map((t) => ({ code: t.code, name: t.name })),
)

function openEdit(entry) {
  if (entry.is_locked) return
  editing.value = entry
  editError.value = ''
  Object.assign(draft, {
    name: entry.name || '',
    department: entry.department || '',
    specimen_type: entry.specimen_type || '',
    turnaround_time: entry.turnaround_time || '',
    instructions: entry.instructions || '',
    description: entry.description || '',
    price: entry.price ?? 0,
  })
  draftRanges.value = Object.entries(entry.reference_ranges || {}).map(([key, value]) => ({
    key,
    value: String(value),
  }))
  draftTestCodes.value = [...(entry.test_codes || [])]
  editOpen.value = true
}

function addRange() {
  draftRanges.value.push({ key: '', value: '' })
}

function togglePanelTest(code) {
  if (draftTestCodes.value.includes(code)) {
    draftTestCodes.value = draftTestCodes.value.filter((c) => c !== code)
  } else {
    draftTestCodes.value = [...draftTestCodes.value, code]
  }
}

function restoreDraft() {
  if (!editing.value) return
  const defaults = editing.value.defaults || {}
  Object.assign(draft, {
    name: defaults.name || '',
    department: defaults.department || '',
    specimen_type: defaults.specimen_type || '',
    turnaround_time: defaults.turnaround_time || '',
    instructions: defaults.instructions || '',
    description: defaults.description || '',
    price: defaults.price ?? 0,
  })
  draftRanges.value = Object.entries(defaults.reference_ranges || {}).map(([key, value]) => ({
    key,
    value: String(value),
  }))
  draftTestCodes.value = [...(defaults.test_codes || [])]
}

function saveDraft() {
  if (!editing.value) return
  if (!draft.name.trim()) {
    editError.value = 'Give this entry a name for your catalogue.'
    return
  }
  const target = editing.value
  const ranges = {}
  for (const range of draftRanges.value) {
    const key = range.key?.trim()
    if (key) ranges[key] = range.value
  }

  target.name = draft.name.trim()
  target.department = draft.department
  if (target.kind === 'test') {
    target.specimen_type = draft.specimen_type
    target.turnaround_time = draft.turnaround_time
    target.instructions = draft.instructions
    target.reference_ranges = ranges
  } else {
    target.description = draft.description
    target.test_codes = [...draftTestCodes.value]
  }
  target.price = Number(draft.price) || 0
  recomputeCustomized(target)
  target.is_selected = true
  editOpen.value = false
  notify(`Your version of ${target.code} is saved.`)
}

/** Mirrors the server's diff so the "edited" badge is accurate immediately. */
function recomputeCustomized(entry) {
  const defaults = entry.defaults || {}
  const fields = entry.kind === 'test'
    ? ['name', 'department', 'specimen_type', 'turnaround_time', 'instructions']
    : ['name', 'department', 'description']
  let changed = fields.some((field) => (entry[field] || '') !== (defaults[field] || ''))
  if (Number(entry.price) !== Number(defaults.price || 0)) changed = true
  if (entry.kind === 'test') {
    const a = JSON.stringify(entry.reference_ranges || {})
    const b = JSON.stringify(defaults.reference_ranges || {})
    if (a !== b) changed = true
  } else {
    const a = [...(entry.test_codes || [])].sort().join(',')
    const b = [...(defaults.test_codes || [])].sort().join(',')
    if (a !== b) changed = true
  }
  entry.is_customized = changed
}

/* ── Reset ────────────────────────────────────────────────────────────── */
async function resetAll() {
  if (!import.meta.client) return
  if (!window.confirm('Discard every edit you made to the starter library and go back to the original values?')) {
    return
  }
  try {
    await $api.post('/lab/catalog/seed-reset/', {})
    await load()
    notify('Your edits were reset to the original library.')
  } catch (error) {
    notify(apiError(error, 'Could not reset your edits.'), 'bad')
  }
}

/* ── Apply ────────────────────────────────────────────────────────────── */
const info = reactive({
  open: false, tone: 'info', title: '', subtitle: '', message: '', points: [], hint: '', confirm: 'OK',
})

function openReview() {
  const chosen = allEntries.value.filter((e) => e.is_selected && !e.is_locked)
  const chosenTests = chosen.filter((e) => e.kind === 'test').length
  const chosenPanels = chosen.filter((e) => e.kind === 'panel').length
  Object.assign(info, {
    open: true,
    tone: 'info',
    title: 'Add to your clinic lab?',
    subtitle: `${chosenTests} tests · ${chosenPanels} panels`,
    message: 'Only the entries you selected will be written to your catalogue, using your edited values.',
    points: [
      'Panel membership links to tests already in your catalogue.',
      'Entries that already exist under the same code are refreshed, not duplicated.',
      'Tests you created yourself are never overwritten.',
    ],
    hint: 'You can re-open this page any time to add more.',
    confirm: 'Add to my lab',
  })
}

function onInfoClose(open) {
  if (!open) info.open = false
}


async function applySelection() {
  const chosen = allEntries.value.filter((e) => e.is_selected && !e.is_locked)
  if (!chosen.length) return
  applying.value = true
  try {
    const payload = {
      tests: chosen.filter((e) => e.kind === 'test').map(stripEntry),
      panels: chosen.filter((e) => e.kind === 'panel').map(stripEntry),
    }
    const { data } = await $api.post('/lab/catalog/seed-apply/', payload)
    notify(data?.detail || 'Catalogue updated.')
    await load()
  } catch (error) {
    notify(apiError(error, 'Could not add the selected entries.'), 'bad')
  } finally {
    applying.value = false
  }
}

/** Only the fields the server accepts. */
function stripEntry(entry) {
  return {
    kind: entry.kind,
    code: entry.code,
    name: entry.name,
    department: entry.department,
    specimen_type: entry.specimen_type,
    turnaround_time: entry.turnaround_time,
    instructions: entry.instructions,
    description: entry.description,
    reference_ranges: entry.reference_ranges,
    price: entry.price,
    test_codes: entry.test_codes,
    is_selected: entry.is_selected,
    is_dismissed: entry.is_dismissed,
  }
}

/* ── Helpers ──────────────────────────────────────────────────────────── */
function rangeCount(entry) {
  return Object.keys(entry.reference_ranges || {}).length
}

function money(value) {
  const amount = Number(value || 0)
  return `KSh ${amount.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
}

function apiError(error, fallback) {
  return error?.response?.data?.detail || error?.response?.data?.message || fallback
}

const notice = ref(null)
let noticeTimer = null

function notify(message, tone = 'good') {
  notice.value = { message, tone }
  if (noticeTimer) clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => { notice.value = null }, 4200)
}

onMounted(load)
onBeforeUnmount(() => { if (noticeTimer) clearTimeout(noticeTimer) })
</script>

<style scoped>
/* ══ Hero ══ */
.sd-hero {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
  padding: 22px 24px;
  margin-bottom: 16px;
  display: flex;
  align-items: flex-end;
  gap: 20px;
  flex-wrap: wrap;
  /* The gradient is always dark-ish in the middle, so foreground is white and
     `ink` is reserved for the white primary button (see BrandDialogHeader). */
  color: #fff;
  background: linear-gradient(135deg, var(--sd-deep) 0%, var(--sd-main) 58%, var(--sd-accent) 100%);
  box-shadow: 0 22px 46px -26px rgba(15, 23, 42, 0.5);
}
/* Scrim: the accent end of the gradient is light enough that plain white text
   would drop to ~2.9:1. Deepening it keeps every label readable. */
.sd-hero::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(120deg, rgba(6, 12, 30, 0.06) 0%, rgba(6, 12, 30, 0.2) 55%, rgba(6, 12, 30, 0.42) 100%);
  pointer-events: none;
  z-index: 0;
}
/* Vuetify icons and any nested text inherit the hero foreground. */
.sd-hero :deep(.v-icon) { color: currentColor; }
.sd-hero-glow {
  position: absolute;
  width: 320px; height: 320px;
  border-radius: 50%;
  filter: blur(64px);
  background: var(--sd-glow);
  top: -140px; right: -60px;
  pointer-events: none;
  z-index: 0;
}
.sd-hero-glow-2 {
  width: 240px; height: 240px;
  left: -90px; bottom: -140px; top: auto; right: auto;
  background: var(--sd-glow-2);
}
.sd-hero-main { position: relative; flex: 1 1 420px; min-width: 0; z-index: 1; }

.sd-hero-back {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-bottom: 10px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  text-decoration: none;
  color: inherit;
  opacity: 0.78;
  transition: opacity 0.15s ease;
}
.sd-hero-back:hover { opacity: 1; }

.sd-hero-title { display: flex; align-items: center; gap: 13px; }
.sd-hero-ico {
  width: 46px; height: 46px;
  border-radius: 14px;
  flex-shrink: 0;
  display: grid; place-items: center;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.28);
  color: #fff;
}
.sd-hero-ico :deep(.v-icon) { color: #fff; }
.sd-hero-title h1 {
  margin: 0;
  font-size: 21px;
  font-weight: 800;
  letter-spacing: -0.5px;
  line-height: 1.2;
}
.sd-hero-title p {
  margin: 3px 0 0;
  font-size: 11.5px;
  font-weight: 600;
  opacity: 0.85;
  max-width: 74ch;
}

.sd-hero-stats {
  display: flex;
  gap: 22px;
  margin-top: 16px;
  flex-wrap: wrap;
}
.sd-hero-stat { display: flex; flex-direction: column; line-height: 1.15; }
.sd-hero-stat b { font-size: 19px; font-weight: 800; font-variant-numeric: tabular-nums; }
.sd-hero-stat span {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  opacity: 0.72;
}

.sd-hero-actions {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

/* ══ Buttons ══ */
.sd-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 14px;
  border-radius: 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.13);
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease, filter 0.15s ease;
}
.sd-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.sd-btn.is-sm { height: 30px; padding: 0 11px; font-size: 11.5px; }
.sd-btn.is-lg { height: 40px; padding: 0 18px; font-size: 12.5px; border-radius: 12px; }
.sd-btn.is-ghost {
  background: rgba(255, 255, 255, 0.16);
  border-color: rgba(255, 255, 255, 0.3);
  color: #fff;
}
.sd-btn.is-ghost:hover:not(:disabled) { background: rgba(255, 255, 255, 0.26); }
.sd-btn.is-ghost :deep(.v-icon) { color: #fff; }
.sd-btn.is-primary {
  background: #fff;
  color: var(--sd-ink);
  border-color: transparent;
  box-shadow: 0 10px 24px -10px rgba(15, 23, 42, 0.6);
}
.sd-btn.is-primary:hover:not(:disabled) {
  background: #fff;
  color: var(--sd-ink);
  filter: brightness(0.96);
  transform: translateY(-1px);
}
.sd-btn.is-primary:active { transform: none; filter: brightness(0.9); }

.sd-dlg .sd-btn.is-ghost,
.sd-card .sd-btn.is-ghost {
  background: transparent;
  border-color: rgba(var(--v-theme-on-surface), 0.13);
  color: rgb(var(--v-theme-on-surface));
}

.sd-spin { animation: sdSpin 0.9s linear infinite; }
@keyframes sdSpin { to { transform: rotate(360deg); } }

/* ══ Toolbar ══ */
.sd-toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  padding: 10px 12px;
  margin-bottom: 12px;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.022);
}
.sd-seg {
  display: inline-flex;
  padding: 3px;
  border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.sd-seg-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 28px;
  padding: 0 11px;
  border: none;
  border-radius: 9px;
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.6);
  font-family: inherit;
  font-size: 11.5px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.sd-seg-btn:hover { color: rgb(var(--v-theme-on-surface)); }
.sd-seg-btn.is-on {
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-primary));
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.12);
}
.sd-seg-count {
  font-size: 9.5px;
  font-weight: 800;
  padding: 0 5px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.08);
}
.sd-seg-btn.is-on .sd-seg-count { background: rgba(var(--v-theme-primary), 0.14); }

.sd-search { max-width: 290px; flex: 1 1 200px; }
.sd-select { max-width: 180px; flex: 0 1 150px; }

.sd-quick { display: flex; gap: 5px; margin-left: auto; flex-wrap: wrap; }
.sd-mini-btn {
  height: 28px;
  padding: 0 10px;
  border-radius: 8px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.7);
  font-family: inherit;
  font-size: 10.5px;
  font-weight: 800;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.sd-mini-btn:hover:not(:disabled) {
  background: rgba(var(--v-theme-primary), 0.08);
  color: rgb(var(--v-theme-primary));
}
.sd-mini-btn:disabled { opacity: 0.45; cursor: not-allowed; }
.sd-mini-btn.is-warn { color: #b45309; border-color: rgba(245, 158, 11, 0.35); }

/* ══ Progress ══ */
.sd-progress {
  padding: 3px 2px 12px;
}
.sd-progress-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 7px;
}
.sd-progress-head b { font-size: 12px; font-weight: 800; }
.sd-progress-head span {
  display: block;
  font-size: 10px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.sd-progress-pct {
  font-size: 13px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-primary));
}
.sd-bar {
  height: 6px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.08);
}
.sd-bar-fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--sd-main), var(--sd-accent));
  transition: width 0.35s ease;
}

/* ══ Grid ══ */
.sd-grid {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(auto-fill, minmax(286px, 1fr));
}

.sd-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 11px 12px;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgb(var(--v-theme-surface));
  transition: border-color 0.16s ease, box-shadow 0.16s ease, transform 0.16s ease;
}
.sd-card:hover { box-shadow: 0 8px 22px -14px rgba(15, 23, 42, 0.45); transform: translateY(-1px); }
.sd-card.is-picked {
  border-color: rgba(var(--v-theme-primary), 0.4);
  background: rgba(var(--v-theme-primary), 0.03);
}
.sd-card.is-locked { opacity: 0.72; }
.sd-card.is-edited { box-shadow: inset 3px 0 0 rgb(var(--v-theme-primary)); }

.sd-card-head { display: flex; align-items: flex-start; gap: 8px; }

.sd-check {
  width: 22px; height: 22px;
  flex-shrink: 0;
  margin-top: 1px;
  border-radius: 7px;
  display: grid; place-items: center;
  border: 1.5px dashed rgba(var(--v-theme-on-surface), 0.26);
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.45);
  cursor: pointer;
  transition: all 0.15s ease;
}
.sd-check.is-on {
  border-style: solid;
  border-color: transparent;
  background: rgb(var(--v-theme-primary));
  color: #fff;
}
.sd-check:disabled { cursor: not-allowed; }

.sd-card-id { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.sd-card-id b { font-size: 12px; font-weight: 800; line-height: 1.3; }
.sd-card-meta {
  display: flex;
  align-items: center;
  gap: 7px;
  flex-wrap: wrap;
  font-size: 9.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.sd-code {
  font-style: normal;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  padding: 0 4px;
  border-radius: 4px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}

.sd-flag {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  height: 18px;
  padding: 0 6px;
  border-radius: 999px;
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  white-space: nowrap;
}
.sd-flag.is-edited {
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.12);
  border: 1px solid rgba(var(--v-theme-primary), 0.28);
}
.sd-flag.is-added {
  color: #047857;
  background: rgba(16, 185, 129, 0.11);
  border: 1px solid rgba(16, 185, 129, 0.28);
}
.sd-flag.is-locked {
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(var(--v-theme-on-surface), 0.06);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
}

.sd-icon-btn {
  width: 24px; height: 24px;
  flex-shrink: 0;
  border-radius: 7px;
  display: grid; place-items: center;
  border: 1px solid transparent;
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.45);
  cursor: pointer;
  transition: all 0.15s ease;
}
.sd-icon-btn:hover:not(:disabled) {
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
  border-color: rgba(var(--v-theme-primary), 0.24);
}
.sd-icon-btn:disabled { opacity: 0.3; cursor: not-allowed; }

.sd-card-desc {
  margin: 0;
  font-size: 10.5px;
  font-weight: 600;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

.sd-card-facts {
  display: flex;
  align-items: center;
  gap: 9px;
  flex-wrap: wrap;
  font-size: 9.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.sd-fact { display: inline-flex; align-items: center; gap: 3px; }
.sd-fact.is-price { color: rgb(var(--v-theme-primary)); font-weight: 800; }

.sd-panel-tests { display: flex; flex-wrap: wrap; gap: 4px; }
.sd-test-chip {
  padding: 1px 6px;
  border-radius: 5px;
  font-size: 8.5px;
  font-weight: 800;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.055);
}

.sd-card-locked-note {
  margin: 0;
  padding: 6px 8px;
  border-radius: 8px;
  font-size: 9.5px;
  font-weight: 600;
  line-height: 1.45;
  color: #b45309;
  background: rgba(245, 158, 11, 0.1);
}

/* ══ States ══ */
.sd-loading,
.sd-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 62px 20px;
  border-radius: 16px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
  font-size: 11.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.sd-empty b { font-size: 13px; font-weight: 800; color: rgb(var(--v-theme-on-surface)); }

/* ══ Dialog ══ */
.sd-dlg { display: flex; flex-direction: column; max-height: calc(100vh - 48px); overflow: hidden; }
.sd-dlg-body {
  flex: 1 1 auto;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 18px;
  display: flex;
  flex-direction: column;
  gap: 11px;
}
.sd-dlg-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.sd-dlg-actions {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 11px 18px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.025);
}

.sd-ranges {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 11px;
  padding: 9px 10px;
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.sd-ranges-head { display: flex; align-items: center; justify-content: space-between; }
.sd-ranges-head b { font-size: 10.5px; font-weight: 800; letter-spacing: 0.2px; }
.sd-range-row { display: grid; grid-template-columns: 1fr 1fr 26px; gap: 7px; align-items: center; }
.sd-ranges-empty {
  margin: 0;
  font-size: 10px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
}

.sd-panel-picks { display: flex; flex-wrap: wrap; gap: 5px; }
.sd-test-pick {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 3px 7px;
  border-radius: 7px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.6);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 9.5px;
  font-weight: 800;
  cursor: pointer;
  transition: all 0.15s ease;
}
.sd-test-pick.is-on {
  border-color: rgba(var(--v-theme-primary), 0.45);
  background: rgba(var(--v-theme-primary), 0.1);
  color: rgb(var(--v-theme-primary));
}

.sd-err {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 0;
  font-size: 11px;
  font-weight: 700;
  color: #b91c1c;
}

/* ══ Toast ══ */
.sd-notice {
  position: fixed;
  right: 24px;
  bottom: 24px;
  z-index: 3000;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-radius: 11px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  box-shadow: 0 18px 40px -18px rgba(15, 23, 42, 0.5);
  font-size: 11.5px;
  font-weight: 700;
}
.sd-notice.is-good :deep(.v-icon) { color: #10b981; }
.sd-notice.is-bad { border-color: rgba(239, 68, 68, 0.35); }
.sd-notice.is-bad :deep(.v-icon) { color: #ef4444; }
.sdToast-enter-active, .sdToast-leave-active { transition: opacity 0.18s ease, transform 0.18s ease; }
.sdToast-enter-from, .sdToast-leave-to { opacity: 0; transform: translateY(8px); }

/* ══ Dark mode ══ */
:global(.v-theme--dark .sd-flag.is-added) {
  color: #34d399;
  border-color: rgba(52, 211, 153, 0.34);
  background: rgba(16, 185, 129, 0.14);
}
:global(.v-theme--dark .sd-card-locked-note) { color: #fbbf24; background: rgba(245, 158, 11, 0.14); }
:global(.v-theme--dark .sd-mini-btn.is-warn) { color: #fbbf24; }

@media (max-width: 720px) {
  .sd-dlg-grid { grid-template-columns: 1fr; }
  .sd-hero-actions { width: 100%; }
}
</style>
