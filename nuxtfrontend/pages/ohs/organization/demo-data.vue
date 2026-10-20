<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-database-plus-outline"
      eyebrow="Security & settings · Data"
      title="Demo data"
      subtitle="Load a realistic safety register into this tenant so the team can explore OHSMS, then remove exactly what was loaded — your own records are never touched."
    >
      <template #actions>
        <v-btn
          class="ohs-btn-glass text-none"
          rounded="lg"
          size="small"
          prepend-icon="mdi-refresh"
          :loading="loading"
          @click="load"
        >Refresh</v-btn>
        <v-btn
          v-if="canManage && totals.demo_objects"
          class="ohs-btn-strong text-none"
          rounded="lg"
          size="small"
          prepend-icon="mdi-delete-sweep-outline"
          @click="openClearAll"
        >Clear all demo data</v-btn>
      </template>

      <span class="ohs-chip"><v-icon size="12">mdi-database-outline</v-icon>
        <b>{{ fmt(totals.demo_objects) }}</b> demo objects</span>
      <span class="ohs-chip"><v-icon size="12">mdi-shape-outline</v-icon>
        <b>{{ totals.datasets_with_data || 0 }}</b> datasets loaded</span>
      <span class="ohs-chip"><v-icon size="12">mdi-history</v-icon>
        <b>{{ totals.runs || 0 }}</b> runs</span>
      <span v-if="lastRun" class="ohs-chip">
        <v-icon size="12">mdi-clock-outline</v-icon>
        Last {{ relativeDays(lastRun.created_at) }}</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi
        label="Demo objects live"
        :value="fmt(totals.demo_objects)"
        icon="mdi-database-outline"
        :tone="totals.demo_objects ? 'warn' : 'ok'"
        sub="tracked & removable"
      />
      <OhsKpi
        label="Datasets loaded"
        :value="`${totals.datasets_with_data || 0}/${datasets.length}`"
        icon="mdi-shape-outline"
        tone="info"
        sub="of the demo catalogue"
      />
      <OhsKpi
        label="Selected"
        :value="effectiveSelection.length"
        icon="mdi-checkbox-multiple-marked-outline"
        tone="primary"
        :sub="prerequisiteOnly.length ? `${prerequisiteOnly.length} added as prerequisites` : 'nothing extra needed'"
      />
      <OhsKpi
        label="Last run"
        :value="lastRun ? fmt(lastRun.objects_created) : '—'"
        icon="mdi-history"
        :tone="lastRun?.status === 'failed' ? 'err' : 'ok'"
        :sub="lastRun ? relativeDays(lastRun.created_at) : 'never seeded'"
      />
    </div>

    <v-alert
      v-if="!canManage"
      type="info"
      variant="tonal"
      density="compact"
      rounded="lg"
      class="mb-3"
    >
      Demo data is managed by tenant administrators only.
    </v-alert>

    <v-alert
      v-else
      type="warning"
      variant="tonal"
      density="compact"
      rounded="lg"
      class="mb-3 demo-warn"
    >
      <div class="demo-warn-title">This runs against the live production database</div>
      Seeded records are clearly tracked, so <b>Clear</b> removes only demo objects — nothing your
      team has entered. Seeding the same dataset twice will collide on reference codes; use
      <b>Clear &amp; re-seed</b> instead.
    </v-alert>

    <!-- ═══════════════ DATASET PICKER ═══════════════ -->
    <OhsPanel
      title="Choose what to load"
      subtitle="Datasets are seeded in dependency order — selecting one pulls in the parents it needs"
      icon="mdi-format-list-checks"
    >
      <template #actions>
        <v-chip size="small" variant="tonal" color="primary" class="font-weight-bold">
          {{ effectiveSelection.length }} selected
        </v-chip>
        <v-btn
          v-if="canManage"
          variant="text"
          size="small"
          class="text-none"
          @click="toggleAll"
        >{{ allSelected ? 'Clear selection' : 'Select all' }}</v-btn>
      </template>

      <div v-for="group in groups" :key="group" class="demo-group">
        <div class="demo-group-head">
          <v-icon size="14">{{ groupIcon(group) }}</v-icon>
          <span>{{ group }}</span>
          <span class="demo-group-count">{{ groupDatasets(group).length }}</span>
          <v-spacer />
          <button
            v-if="canManage && groupDatasets(group).length"
            class="demo-mini"
            type="button"
            @click="toggleGroup(group)"
          >{{ groupFullySelected(group) ? 'none' : 'all' }}</button>
        </div>

        <div class="demo-grid">
          <button
            v-for="ds in groupDatasets(group)"
            :key="ds.key"
            type="button"
            class="demo-card"
            :class="{
              'is-on': selected.includes(ds.key),
              'is-prereq': prerequisiteOnly.includes(ds.key),
              'is-disabled': !canManage,
            }"
            :disabled="!canManage"
            @click="toggleDataset(ds.key)"
          >
            <span class="demo-check">
              <v-icon v-if="selected.includes(ds.key)" size="14">mdi-check</v-icon>
            </span>
            <span class="demo-icon"><v-icon size="17">{{ ds.icon }}</v-icon></span>
            <span class="demo-body">
              <span class="demo-name">{{ ds.label }}</span>
              <span class="demo-desc">{{ ds.description }}</span>
              <span class="demo-meta">
                <span v-if="ds.demo_count" class="demo-badge demo-badge--live">
                  {{ fmt(ds.demo_count) }} loaded
                </span>
                <span v-if="ds.prerequisites?.length" class="demo-badge">
                  needs {{ ds.prerequisites.map((p) => p.label).join(', ') }}
                </span>
                <span v-if="ds.warning" class="demo-badge demo-badge--warn">
                  <v-icon size="11">mdi-alert-outline</v-icon>
                  {{ ds.warning }}
                </span>
              </span>
            </span>
          </button>
        </div>
      </div>

      <div v-if="!datasets.length" class="ohs-empty">Loading the demo catalogue…</div>
    </OhsPanel>

    <!-- ═══════════════ ACTION BAR ═══════════════ -->
    <div v-if="canManage" class="demo-bar">
      <div class="demo-bar-info">
        <span class="demo-bar-count">{{ effectiveSelection.length }}</span>
        <span class="demo-bar-label">
          dataset{{ effectiveSelection.length === 1 ? '' : 's' }} ready to seed
          <span v-if="prerequisiteOnly.length" class="demo-bar-prereq">
            · {{ prerequisiteOnly.length }} prerequisite{{ prerequisiteOnly.length === 1 ? '' : 's' }} included
          </span>
        </span>
      </div>
      <v-spacer />
      <v-btn
        variant="text"
        class="text-none"
        size="small"
        :disabled="!effectiveSelection.length || saving"
        @click="openClearSelected"
      >Clear selected</v-btn>
      <v-btn
        class="ohs-btn-strong text-none"
        rounded="lg"
        size="small"
        prepend-icon="mdi-database-plus-outline"
        :disabled="!effectiveSelection.length"
        :loading="saving"
        @click="confirmSeed = true"
      >Seed {{ effectiveSelection.length }} dataset{{ effectiveSelection.length === 1 ? '' : 's' }}</v-btn>
    </div>

    <!-- ═══════════════ RUN HISTORY ═══════════════ -->
    <OhsPanel
      title="Seeding history"
      subtitle="Every run and how many of its objects are still in the database"
      icon="mdi-history"
      class="mt-3"
    >
      <div class="ohs-table-wrap">
        <table class="ohs-table demo-table">
          <thead>
            <tr>
              <th>When</th>
              <th>By</th>
              <th>Datasets</th>
              <th class="num">Created</th>
              <th class="num">Still live</th>
              <th>Took</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="run in runs" :key="run.run_id">
              <td class="nowrap">{{ formatDateTime(run.created_at) }}</td>
              <td class="nowrap">{{ run.created_by_name || '—' }}</td>
              <td>
                <span class="demo-run-datasets">
                  <span v-for="k in run.datasets.slice(0, 3)" :key="k" class="demo-pill">
                    {{ labelOf(k) }}
                  </span>
                  <span v-if="run.datasets.length > 3" class="demo-pill demo-pill--more">
                    +{{ run.datasets.length - 3 }}
                  </span>
                </span>
              </td>
              <td class="num">{{ fmt(run.objects_created) }}</td>
              <td class="num">{{ fmt(run.live_objects) }}</td>
              <td class="nowrap">{{ (run.duration_ms / 1000).toFixed(1) }}s</td>
              <td>
                <span class="ohs-badge" :class="runBadge(run.status)">{{ titleCase(run.status) }}</span>
              </td>
              <td class="num">
                <v-btn
                  v-if="canManage && run.live_objects"
                  icon="mdi-delete-outline"
                  variant="text"
                  size="x-small"
                  density="comfortable"
                  title="Remove this run's demo data"
                  @click="openClearRun(run)"
                />
              </td>
            </tr>
            <tr v-if="!runs.length">
              <td colspan="8">
                <div class="ohs-empty">Nothing seeded yet.</div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="failedRuns.length" class="demo-failures">
        <div class="demo-fail-head">
          <v-icon size="14" color="error">mdi-alert-circle-outline</v-icon>
          Last failure
        </div>
        <pre class="demo-fail-body">{{ failedRuns[0].error }}</pre>
      </div>
    </OhsPanel>

    <!-- ═══════════════ SEED DIALOG ═══════════════ -->
    <v-dialog v-model="confirmSeed" max-width="600" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-database-plus-outline"
          title="Seed demo data"
          :subtitle="`${effectiveSelection.length} dataset${effectiveSelection.length === 1 ? '' : 's'} · ${schema} schema`"
        />
        <v-card-text class="pt-4">
          <div class="seed-list">
            <div v-for="key in effectiveSelection" :key="key" class="seed-row">
              <v-icon size="15" :color="prerequisiteOnly.includes(key) ? 'medium-emphasis' : 'primary'">
                {{ iconOf(key) }}
              </v-icon>
              <span class="seed-name">{{ labelOf(key) }}</span>
              <span v-if="prerequisiteOnly.includes(key)" class="seed-tag">prerequisite</span>
              <span v-else-if="demoCountOf(key)" class="seed-tag seed-tag--live">replaces demo data</span>
            </div>
          </div>

          <v-alert
            v-if="willReplace"
            type="warning"
            variant="tonal"
            density="compact"
            rounded="lg"
            class="mt-3"
          >
            Some of these datasets already contain demo records. They will be cleared first so the
            seed starts clean.
          </v-alert>

          <div class="seed-enabled">
            <v-switch
              v-model="resetFirst"
              color="primary"
              density="compact"
              hide-details
              label="Clear & re-seed (recommended when demo data already exists)"
            />
          </div>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <span class="seed-hint">Takes a few seconds for a full seed.</span>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="confirmSeed = false">Cancel</v-btn>
          <v-btn
            color="primary"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-database-plus-outline"
            :loading="saving"
            @click="doSeed"
          >{{ resetFirst ? 'Clear & seed' : 'Seed now' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ CLEAR DIALOG ═══════════════ -->
    <v-dialog v-model="confirmClear" max-width="560" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-delete-sweep-outline"
          title="Clear demo data"
          :subtitle="clearTarget === 'all'
            ? `Removes all ${fmt(totals.demo_objects)} tracked demo objects`
            : clearTarget === 'run'
              ? 'Removes the objects created by this run'
              : `Removes demo objects for ${clearDatasets.length} dataset(s)`"
        />
        <v-card-text class="pt-4">
          <v-alert type="error" variant="tonal" density="compact" rounded="lg">
            <div class="clear-title">Only demo records are deleted</div>
            Records your team entered are never included — the system deletes exactly the objects
            it created in earlier runs. Anything that references a demo object will also be removed
            by the database cascade.
          </v-alert>

          <div v-if="clearDatasets.length && clearTarget === 'selected'" class="seed-list mt-3">
            <div v-for="key in clearDatasets" :key="key" class="seed-row">
              <v-icon size="15" color="error">{{ iconOf(key) }}</v-icon>
              <span class="seed-name">{{ labelOf(key) }}</span>
              <span class="seed-tag">{{ fmt(demoCountOf(key)) }} objects</span>
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="confirmClear = false">Cancel</v-btn>
          <v-btn
            color="error"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-delete-forever-outline"
            :loading="clearing"
            @click="doClear"
          >Delete demo data</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="5000">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { relativeDays } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Demo data · OHSMS' })

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const clearing = ref(false)

const datasets = ref([])
const groups = ref([])
const runs = ref([])
const totals = ref({ demo_objects: 0, datasets_with_data: 0, runs: 0, objects_seeded: 0 })
const canManage = ref(false)
const schema = ref('')

const selected = ref([])
const resetFirst = ref(false)
const confirmSeed = ref(false)
const confirmClear = ref(false)
const clearTarget = ref('selected')     // 'selected' | 'all' | 'run'
const clearDatasets = ref([])
const clearRunId = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })

// ── derived ─────────────────────────────────────────────────────────────
const lastRun = computed(() => runs.value[0] || null)
const failedRuns = computed(() => runs.value.filter((r) => r.status === 'failed'))
const allSelected = computed(() =>
  datasets.value.length > 0 && selected.value.length === datasets.value.length)

/** Closure of the selection, mirroring the backend's dependency expansion. */
const effectiveSelection = computed(() => {
  const out = new Set()
  const stack = [...selected.value]
  while (stack.length) {
    const key = stack.pop()
    if (out.has(key)) continue
    out.add(key)
    const ds = datasets.value.find((d) => d.key === key)
    for (const req of ds?.requires || []) stack.push(req)
  }
  return datasets.value.filter((d) => out.has(d.key)).map((d) => d.key)
})

const prerequisiteOnly = computed(() =>
  effectiveSelection.value.filter((k) => !selected.value.includes(k)))

const willReplace = computed(() =>
  effectiveSelection.value.some((k) => demoCountOf(k) > 0))

/** Pre-tick the reset switch whenever a re-seed would collide. */
watch(willReplace, (v) => { resetFirst.value = v }, { immediate: true })

// ── helpers ─────────────────────────────────────────────────────────────
function fmt(n) {
  return (n ?? 0).toLocaleString()
}
function titleCase(s) {
  return String(s || '').replace(/(^|\s|_)\S/g, (c) => c.toUpperCase()).replace(/_/g, ' ')
}
function labelOf(key) {
  return datasets.value.find((d) => d.key === key)?.label || titleCase(key)
}
function iconOf(key) {
  return datasets.value.find((d) => d.key === key)?.icon || 'mdi-shape-outline'
}
function demoCountOf(key) {
  return datasets.value.find((d) => d.key === key)?.demo_count || 0
}
function runBadge(status) {
  return { complete: 'ohs-badge--ok', partial: 'ohs-badge--warn', failed: 'ohs-badge--err' }[status]
    || 'ohs-badge--muted'
}
function groupDatasets(group) {
  return datasets.value.filter((d) => d.group === group)
}
function groupIcon(group) {
  return {
    'Risk & planning': 'mdi-shield-alert-outline',
    Operations: 'mdi-clipboard-check-outline',
    'People & health': 'mdi-heart-pulse',
    Governance: 'mdi-gavel',
    'Documents & partners': 'mdi-file-document-multiple-outline',
  }[group] || 'mdi-shape-outline'
}
function groupFullySelected(group) {
  const list = groupDatasets(group)
  return list.length > 0 && list.every((d) => selected.value.includes(d.key))
}

// ── selection ───────────────────────────────────────────────────────────
function toggleDataset(key) {
  const i = selected.value.indexOf(key)
  if (i === -1) selected.value.push(key)
  else selected.value.splice(i, 1)
}
function toggleGroup(group) {
  const list = groupDatasets(group)
  if (groupFullySelected(group)) {
    selected.value = selected.value.filter((k) => !list.some((d) => d.key === k))
  } else {
    for (const d of list) if (!selected.value.includes(d.key)) selected.value.push(d.key)
  }
}
function toggleAll() {
  selected.value = allSelected.value ? [] : datasets.value.map((d) => d.key)
}

// ── data ────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/ohs/demo-data/')
    datasets.value = data.datasets || []
    groups.value = data.groups || []
    runs.value = data.runs || []
    totals.value = data.totals || totals.value
    canManage.value = !!data.can_manage
    schema.value = data.schema || ''
    // Drop selections for datasets that vanished from the catalogue.
    const known = new Set(datasets.value.map((d) => d.key))
    selected.value = selected.value.filter((k) => known.has(k))
  } catch (e) {
    snack.value = {
      show: true,
      color: 'error',
      text: e?.response?.data?.detail || 'Could not load the demo data catalogue.',
    }
  } finally {
    loading.value = false
  }
}

async function doSeed() {
  saving.value = true
  try {
    const { data } = await $api.post('/ohs/demo-data/seed/', {
      datasets: effectiveSelection.value,
      reset: resetFirst.value,
    })
    confirmSeed.value = false
    snack.value = {
      show: true,
      color: 'success',
      text: `Seeded ${fmt(data.objects_created)} demo records across `
        + `${data.datasets.length} datasets in ${(data.duration_ms / 1000).toFixed(1)}s.`,
    }
    selected.value = []
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = {
      show: true,
      color: 'error',
      text: d?.hint || d?.detail || d?.error || 'Seeding failed. Check the server log.',
    }
    await load()
  } finally {
    saving.value = false
  }
}

function openClearSelected() {
  clearTarget.value = 'selected'
  clearDatasets.value = [...effectiveSelection.value]
  clearRunId.value = null
  confirmClear.value = true
}
function openClearAll() {
  clearTarget.value = 'all'
  clearDatasets.value = []
  clearRunId.value = null
  confirmClear.value = true
}
function openClearRun(run) {
  clearTarget.value = 'run'
  clearDatasets.value = [...run.datasets]
  clearRunId.value = run.run_id
  confirmClear.value = true
}

async function doClear() {
  clearing.value = true
  try {
    const body = clearTarget.value === 'all'
      ? { all: true }
      : clearTarget.value === 'run'
        ? { run: clearRunId.value }
        : { datasets: clearDatasets.value }
    const { data } = await $api.post('/ohs/demo-data/clear/', body)
    confirmClear.value = false
    snack.value = {
      show: true,
      color: data.errors?.length ? 'warning' : 'success',
      text: data.errors?.length
        ? `Removed ${fmt(data.deleted)} objects, ${data.errors.length} model(s) failed.`
        : `Removed ${fmt(data.deleted)} demo objects.`,
    }
    selected.value = []
    await load()
  } catch (e) {
    snack.value = {
      show: true,
      color: 'error',
      text: e?.response?.data?.detail || 'Could not clear demo data.',
    }
  } finally {
    clearing.value = false
  }
}

onMounted(load)
</script>

<style scoped>
/* ── warning band ──────────────────────────────────────────────────────── */
.demo-warn-title {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: .2px;
  margin-bottom: 2px;
}

/* ── groups ────────────────────────────────────────────────────────────── */
.demo-group { margin-bottom: 14px; }
.demo-group-head {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: .6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55);
  padding-bottom: 7px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), .07);
  margin-bottom: 9px;
}
.demo-group-count {
  font-size: 9.5px;
  font-weight: 800;
  padding: 1px 6px;
  border-radius: 5px;
  background: rgba(var(--v-theme-on-surface), .07);
}
.demo-mini {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .3px;
  text-transform: uppercase;
  color: rgb(var(--v-theme-primary));
  background: none;
  border: 0;
  cursor: pointer;
  padding: 2px 4px;
}

/* ── dataset cards ─────────────────────────────────────────────────────── */
.demo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(276px, 1fr));
  gap: 9px;
}
.demo-card {
  position: relative;
  display: flex;
  gap: 10px;
  text-align: left;
  padding: 11px 12px 11px 11px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), .1);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: border-color .15s ease, box-shadow .15s ease, transform .15s ease;
}
.demo-card:hover:not(.is-disabled) {
  transform: translateY(-1px);
  border-color: rgba(var(--v-theme-primary), .4);
  box-shadow: 0 8px 18px rgba(15, 23, 42, .07);
}
.demo-card.is-on {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), .045);
  box-shadow: 0 6px 16px rgba(var(--v-theme-primary), .12);
}
.demo-card.is-prereq {
  border-style: dashed;
  border-color: rgba(var(--v-theme-primary), .38);
  background: rgba(var(--v-theme-primary), .025);
}
.demo-card.is-disabled { cursor: not-allowed; opacity: .6; }

.demo-check {
  position: absolute;
  top: 9px;
  right: 9px;
  width: 17px;
  height: 17px;
  border-radius: 5px;
  display: grid;
  place-items: center;
  border: 1.5px solid rgba(var(--v-theme-on-surface), .22);
  color: #fff;
  background: transparent;
}
.demo-card.is-on .demo-check {
  background: rgb(var(--v-theme-primary));
  border-color: rgb(var(--v-theme-primary));
}
.demo-icon {
  flex-shrink: 0;
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border-radius: 9px;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), .1);
}
.demo-body { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.demo-name {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: .1px;
  padding-right: 20px;
}
.demo-desc {
  font-size: 10.5px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), .58);
}
.demo-meta { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 4px; }
.demo-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: .25px;
  padding: 2px 6px;
  border-radius: 5px;
  color: rgba(var(--v-theme-on-surface), .6);
  background: rgba(var(--v-theme-on-surface), .06);
}
.demo-badge--live { color: #0369a1; background: rgba(2, 132, 199, .12); }
.demo-badge--warn { color: #b45309; background: rgba(245, 158, 11, .14); }

/* ── action bar ────────────────────────────────────────────────────────── */
.demo-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 12px;
  padding: 10px 14px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-primary), .22);
  background: rgba(var(--v-theme-primary), .05);
}
.demo-bar-info { display: flex; align-items: baseline; gap: 8px; }
.demo-bar-count {
  font-size: 20px;
  font-weight: 900;
  line-height: 1;
  color: rgb(var(--v-theme-primary));
}
.demo-bar-label {
  font-size: 12px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), .7);
}
.demo-bar-prereq { font-weight: 600; color: rgba(var(--v-theme-on-surface), .5); }

/* ── history table ─────────────────────────────────────────────────────── */
.demo-table .num { text-align: right; }
.demo-table .nowrap { white-space: nowrap; }
.demo-run-datasets { display: flex; flex-wrap: wrap; gap: 4px; }
.demo-pill {
  font-size: 9.5px;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 5px;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), .7);
  background: rgba(var(--v-theme-on-surface), .06);
}
.demo-pill--more { color: rgb(var(--v-theme-primary)); background: rgba(var(--v-theme-primary), .12); }

.demo-failures {
  margin-top: 12px;
  border: 1px solid rgba(220, 38, 38, .28);
  border-radius: 10px;
  overflow: hidden;
}
.demo-fail-head {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: .5px;
  text-transform: uppercase;
  color: #b91c1c;
  background: rgba(220, 38, 38, .07);
  padding: 6px 10px;
}
.demo-fail-body {
  margin: 0;
  padding: 9px 11px;
  font-size: 10.5px;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-word;
  color: rgba(var(--v-theme-on-surface), .72);
  background: rgba(var(--v-theme-on-surface), .03);
}

/* ── dialogs ───────────────────────────────────────────────────────────── */
.seed-list {
  display: flex;
  flex-direction: column;
  border: 1px solid rgba(var(--v-theme-on-surface), .09);
  border-radius: 10px;
  overflow: hidden;
}
.seed-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 11px;
  font-size: 11.5px;
}
.seed-row + .seed-row { border-top: 1px solid rgba(var(--v-theme-on-surface), .06); }
.seed-name { font-weight: 700; }
.seed-tag {
  margin-left: auto;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: .35px;
  text-transform: uppercase;
  padding: 2px 6px;
  border-radius: 5px;
  color: rgba(var(--v-theme-on-surface), .55);
  background: rgba(var(--v-theme-on-surface), .06);
}
.seed-tag--live { color: #b45309; background: rgba(245, 158, 11, .15); }
.seed-enabled { margin-top: 10px; }
.seed-hint {
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), .45);
}
.clear-title { font-size: 12px; font-weight: 800; margin-bottom: 2px; }

.v-theme--dark .demo-card { border-color: rgba(255, 255, 255, .1); }
.v-theme--dark .demo-card.is-on { background: rgba(var(--v-theme-primary), .12); }
.v-theme--dark .demo-fail-body { background: rgba(255, 255, 255, .03); }

@media (max-width: 700px) {
  .demo-grid { grid-template-columns: 1fr; }
  .demo-bar { flex-direction: column; align-items: stretch; }
}
</style>
