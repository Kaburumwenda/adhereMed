<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-target"
      eyebrow="OHSMS · Clause 6.2 objectives"
      title="Safety Objectives & Targets"
      subtitle="Annual OH&S objectives with baselines, targets and live progress against the programme."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          New objective
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-target</v-icon>
        <b>{{ items.count.value }}</b> objectives</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.onTrack }}</b> on track</span>
      <span v-if="stats.atRisk" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-alert-outline</v-icon>
        <b>{{ stats.atRisk }}</b> at risk</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="On track" :value="stats.onTrack" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`of ${items.count.value} objectives`" />
      <OhsKpi label="At risk" :value="stats.atRisk" icon="mdi-alert-outline"
              :tone="stats.atRisk ? 'warn' : 'ok'" sub="needs intervention" />
      <OhsKpi label="Off track" :value="stats.offTrack" icon="mdi-close-octagon-outline"
              :tone="stats.offTrack ? 'err' : 'ok'" sub="recovery plan required" />
      <OhsKpi label="Average progress" :value="`${stats.avgProgress}%`" icon="mdi-gauge"
              :tone="stats.avgProgress >= 70 ? 'ok' : 'warn'" sub="across the programme" />
      <OhsKpi label="Due this quarter" :value="stats.dueSoon" icon="mdi-calendar-clock" tone="info"
              sub="target dates approaching" />
    </div>

    <v-row dense>
      <v-col v-for="o in items.items.value" :key="o.id" cols="12" md="6" lg="4">
        <div class="obj-card">
          <div class="d-flex align-center justify-space-between" style="gap:8px">
            <span class="ohs-badge ohs-badge--muted">{{ o.category_display }}</span>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(o.status)}`">{{ o.status_display }}</span>
          </div>
          <div class="text-body-1 font-weight-bold mt-2" style="line-height:1.3">{{ o.title }}</div>
          <div class="text-caption text-medium-emphasis">{{ o.site_name || 'All sites' }} · {{ o.owner_name || 'Unowned' }}</div>

          <div class="d-flex align-end justify-space-between mt-3">
            <div>
              <div class="obj-label">Current</div>
              <div class="obj-value" :style="{ color: pctColor(o.progress_pct) }">
                {{ num(o.current_value) }}<span class="obj-unit">{{ o.unit }}</span>
              </div>
            </div>
            <div class="text-right">
              <div class="obj-label">Target</div>
              <div class="obj-target">{{ num(o.target_value) }}{{ o.unit }}</div>
            </div>
          </div>

          <div class="ohs-meter mt-2" :style="{ color: pctColor(o.progress_pct) }">
            <div class="ohs-meter-fill" :style="{ width: o.progress_pct + '%' }" />
          </div>
          <div class="d-flex align-center justify-space-between mt-1">
            <span class="text-caption text-medium-emphasis">
              baseline {{ num(o.baseline_value) }}{{ o.unit }}
            </span>
            <span class="text-caption font-weight-bold">{{ num(o.progress_pct) }}%</span>
          </div>
          <div class="text-caption text-medium-emphasis mt-1">
            Due {{ formatDate(o.due_date) }} · {{ relativeDays(o.due_date) }}
          </div>
        </div>
      </v-col>
    </v-row>
    <div v-if="!items.items.value.length" class="ohs-empty">No objectives defined yet.</div>

    <v-dialog v-model="createDialog" max-width="640">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-target" title="Set a new objective"
                           subtitle="Give it a measurable baseline and target so progress is automatic." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12">
              <v-text-field v-model="form.title" label="Objective" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.category" :items="categories" item-title="label" item-value="value"
                        label="Category" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="3">
              <v-text-field v-model.number="form.baseline_value" type="number" label="Baseline"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="3">
              <v-text-field v-model.number="form.target_value" type="number" label="Target"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="3">
              <v-text-field v-model.number="form.current_value" type="number" label="Current"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="3">
              <v-text-field v-model="form.unit" label="Unit" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.owner_name" label="Owner" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.due_date" type="date" label="Due date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.title" @click="save">Save objective</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { toneFor } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Objectives · OHSMS' })

const ohs = useOhs()
const items = ohs.resource('objectives')
const lookups = ref({})
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', category: 'incident_reduction', site: null,
  baseline_value: 0, target_value: 0, current_value: 0, unit: '%',
  owner_name: '', due_date: '',
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const categories = computed(() => lookups.value.objective_categories || [
  { value: 'incident_reduction', label: 'Incident reduction' },
  { value: 'compliance', label: 'Compliance' },
  { value: 'training', label: 'Training & competence' },
  { value: 'risk', label: 'Risk reduction' },
  { value: 'culture', label: 'Safety culture' },
  { value: 'health', label: 'Occupational health' },
])

const stats = computed(() => {
  const all = items.items.value || []
  const avg = all.length
    ? Math.round(all.reduce((s, o) => s + (o.progress_pct || 0), 0) / all.length) : 0
  const soon = Date.now() + 90 * 86400000
  return {
    onTrack: all.filter((o) => ['on_track', 'achieved'].includes(o.status)).length,
    atRisk: all.filter((o) => o.status === 'at_risk').length,
    offTrack: all.filter((o) => o.status === 'off_track').length,
    avgProgress: avg,
    dueSoon: all.filter((o) => o.due_date && new Date(o.due_date).getTime() <= soon).length,
  }
})

function num(v) {
  const n = Number(v ?? 0)
  return Number.isInteger(n) ? n : n.toFixed(1)
}
function pctColor(pct) {
  const n = Number(pct || 0)
  if (n >= 85) return '#16a34a'
  if (n >= 55) return '#f59e0b'
  return '#dc2626'
}

async function load() {
  await items.list({ ordering: 'due_date' })
  lookups.value = await ohs.loadLookups()
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: '', category: 'incident_reduction', site: null,
    baseline_value: 0, target_value: 0, current_value: 0, unit: '%',
    owner_name: '', due_date: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.site) delete payload.site
    if (!payload.due_date) delete payload.due_date
    await items.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Objective created.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

function exportData() {
  exportCsv(`safety_objectives_${new Date().toISOString().slice(0, 10)}.csv`, items.items.value, [
    { key: 'title', label: 'Objective' },
    { key: 'category_display', label: 'Category' },
    { key: 'site_name', label: 'Site' },
    { key: 'baseline_value', label: 'Baseline' },
    { key: 'target_value', label: 'Target' },
    { key: 'current_value', label: 'Current' },
    { key: 'unit', label: 'Unit' },
    { key: 'progress_pct', label: 'Progress %' },
    { key: 'status_display', label: 'Status' },
    { key: 'owner_name', label: 'Owner' },
    { key: 'due_date', label: 'Due' },
  ])
}

onMounted(load)
</script>

<style scoped>
.obj-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 13px;
  padding: 13px 14px;
  background: rgb(var(--v-theme-surface));
  height: 100%;
  transition: box-shadow .16s ease, transform .16s ease;
}
.obj-card:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(15, 23, 42, .08); }
.obj-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .5px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.obj-value { font-size: 22px; font-weight: 800; line-height: 1.1; }
.obj-unit { font-size: 11px; font-weight: 700; margin-left: 2px; opacity: .7; }
.obj-target { font-size: 14px; font-weight: 700; color: rgba(var(--v-theme-on-surface), .62); }
</style>
