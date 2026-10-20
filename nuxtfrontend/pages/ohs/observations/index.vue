<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-account-check-outline"
      eyebrow="OHSMS · Safety culture"
      title="Behaviour-Based Observations"
      subtitle="Safe and at-risk behaviour observations, unsafe conditions and positive practice — the leading indicators of culture."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Record observation
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-eye-check-outline</v-icon>
        <b>{{ items.count.value }}</b> observations</span>
      <span class="ohs-chip"><v-icon size="12">mdi-thumb-up</v-icon>
        <b>{{ stats.safePct }}%</b> safe</span>
      <span v-if="stats.atRisk" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-alert-outline</v-icon>
        <b>{{ stats.atRisk }}</b> at risk</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Total observations" :value="items.count.value" icon="mdi-eye-check-outline" tone="primary"
              sub="culture sample size" />
      <OhsKpi label="Safe behaviour" :value="`${stats.safePct}%`" icon="mdi-thumb-up-outline"
              :tone="stats.safePct >= 70 ? 'ok' : 'warn'" sub="safe + positive" />
      <OhsKpi label="At risk" :value="stats.atRisk" icon="mdi-alert-outline"
              :tone="stats.atRisk ? 'warn' : 'ok'" sub="coaching opportunity" />
      <OhsKpi label="Unsafe conditions" :value="stats.conditions" icon="mdi-home-alert-outline"
              :tone="stats.conditions ? 'warn' : 'ok'" sub="environmental hazards" />
      <OhsKpi label="Feedback given" :value="`${stats.feedbackPct}%`" icon="mdi-comment-check-outline" tone="ok"
              sub="on-the-spot coaching" />
    </div>

    <v-row dense>
      <v-col cols="12" lg="4">
        <OhsPanel title="Observation mix" subtitle="Share of each behaviour type" icon="mdi-chart-donut-variant">
          <div v-for="k in kindRows" :key="k.key" class="mb-2">
            <div class="d-flex align-center justify-space-between">
              <span class="d-flex align-center text-caption font-weight-medium" style="gap:6px">
                <span class="dot" :style="{ background: k.color }" /> {{ k.label }}
              </span>
              <span class="text-caption ohs-tabular">{{ k.count }}</span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: k.color }">
              <div class="ohs-meter-fill" :style="{ width: k.pct + '%' }" />
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption font-weight-bold mb-2">Top at-risk categories</div>
          <div v-for="c in topRiskCategories" :key="c.label" class="d-flex align-center justify-space-between mb-1">
            <span class="text-caption">{{ c.label }}</span>
            <span class="text-caption font-weight-bold">{{ c.count }}</span>
          </div>
          <div v-if="!topRiskCategories.length" class="text-caption text-medium-emphasis">Nothing recorded.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" lg="8">
        <OhsPanel title="Observation log" :subtitle="`${filtered.length} shown`" icon="mdi-format-list-bulleted" flush>
          <div class="ohs-toolbar">
            <v-text-field v-model="search" placeholder="Search observer, person, description…"
                          prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                          hide-details single-line clearable style="max-width:270px" />
            <v-select v-model="kindFilter" :items="kindOptions" item-title="label" item-value="value"
                      placeholder="Any type" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:180px" />
            <v-select v-model="categoryFilter" :items="categoryOptions" item-title="label" item-value="value"
                      placeholder="Any category" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:190px" />
            <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                      placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:185px" />
          </div>
          <div class="ohs-scroll" style="max-height:60vh">
            <div v-for="o in filtered" :key="o.id" class="obs-row">
              <div class="obs-icon" :style="{ background: kindColor(o.kind) }">
                <v-icon size="15" color="#fff">{{ kindIcon(o.kind) }}</v-icon>
              </div>
              <div class="flex-grow-1" style="min-width:0">
                <div class="d-flex align-center" style="gap:6px">
                  <span class="text-body-2 font-weight-medium">{{ o.category_display }}</span>
                  <span class="ohs-badge" :class="`ohs-badge--${toneFor(o.kind)}`">{{ o.kind_display }}</span>
                </div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ o.description }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ o.observer_name || '—' }} · {{ o.site_name }} · {{ formatDateTime(o.observed_at) }}
                </div>
              </div>
              <v-icon v-if="o.feedback_given" size="15" color="success" title="Feedback given">
                mdi-comment-check
              </v-icon>
            </div>
            <div v-if="!filtered.length" class="ohs-empty">No observations match these filters.</div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <v-dialog v-model="createDialog" max-width="620">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-eye-check-outline" title="Record an observation"
                           subtitle="Capture the behaviour, the conversation and the correction." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.kind" :items="kindOptions" item-title="label" item-value="value"
                        label="Observation type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.category" :items="categoryOptions" item-title="label" item-value="value"
                        label="Category" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.observer_name" label="Observer" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.observed_person" label="Person observed" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.department" label="Department" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="What was observed" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.action_taken" label="Action / coaching given" rows="2"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-checkbox v-model="form.feedback_given" density="compact" hide-details
                          label="Feedback given on the spot" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.site" @click="save">Save observation</v-btn>
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
useHead({ title: 'Observations · OHSMS' })

const ohs = useOhs()
const items = ohs.resource('observations')
const lookups = ref({})
const search = ref('')
const kindFilter = ref(null)
const categoryFilter = ref(null)
const siteFilter = ref(null)
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  kind: 'at_risk', category: 'ppe', site: null, observer_name: '',
  observed_person: '', department: '', description: '', action_taken: '',
  feedback_given: true,
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const kindOptions = computed(() => lookups.value.observation_kinds || [
  { value: 'safe', label: 'Safe behaviour' },
  { value: 'at_risk', label: 'At-risk behaviour' },
  { value: 'condition', label: 'Unsafe condition' },
  { value: 'positive', label: 'Positive practice' },
])
const categoryOptions = computed(() => lookups.value.observation_categories || [])

const KIND_META = {
  safe: '#16a34a', positive: '#0d9488', at_risk: '#f59e0b', condition: '#dc2626',
}

const filtered = computed(() => (items.items.value || []).filter((o) => {
  if (kindFilter.value && o.kind !== kindFilter.value) return false
  if (categoryFilter.value && o.category !== categoryFilter.value) return false
  if (siteFilter.value && o.site !== siteFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q && !`${o.observer_name} ${o.observed_person} ${o.description} ${o.department}`.toLowerCase().includes(q)) return false
  return true
}))

const stats = computed(() => {
  const all = items.items.value || []
  const safe = all.filter((o) => ['safe', 'positive'].includes(o.kind)).length
  return {
    safePct: all.length ? Math.round((safe / all.length) * 100) : 0,
    atRisk: all.filter((o) => o.kind === 'at_risk').length,
    conditions: all.filter((o) => o.kind === 'condition').length,
    feedbackPct: all.length ? Math.round((all.filter((o) => o.feedback_given).length / all.length) * 100) : 0,
  }
})

const kindRows = computed(() => kindOptions.value.map((k) => {
  const count = (items.items.value || []).filter((o) => o.kind === k.value).length
  const total = items.items.value.length || 1
  return { key: k.value, label: k.label, count, pct: Math.round((count / total) * 100), color: KIND_META[k.value] || '#94a3b8' }
}))

const topRiskCategories = computed(() => {
  const map = {}
  for (const o of items.items.value || []) {
    if (o.kind !== 'at_risk' && o.kind !== 'condition') continue
    map[o.category_display] = (map[o.category_display] || 0) + 1
  }
  return Object.entries(map)
    .map(([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5)
})

function kindColor(k) {
  return KIND_META[k] || '#94a3b8'
}
function kindIcon(k) {
  return {
    safe: 'mdi-thumb-up', positive: 'mdi-star', at_risk: 'mdi-alert', condition: 'mdi-home-alert',
  }[k] || 'mdi-eye'
}

async function load() {
  await items.list({ ordering: '-observed_at' })
  lookups.value = await ohs.loadLookups()
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    kind: 'at_risk', category: 'ppe', site: siteOptions.value[0]?.value || null,
    observer_name: '', observed_person: '', department: '', description: '',
    action_taken: '', feedback_given: true,
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    await items.create({ ...form })
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Observation recorded.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

function exportData() {
  exportCsv(`observations_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'observed_at', label: 'Observed' },
    { key: 'kind_display', label: 'Type' },
    { key: 'category_display', label: 'Category' },
    { key: 'site_name', label: 'Site' },
    { key: 'observer_name', label: 'Observer' },
    { key: 'observed_person', label: 'Person' },
    { key: 'department', label: 'Department' },
    { key: 'description', label: 'Description' },
    { key: 'action_taken', label: 'Action taken' },
    { key: 'feedback_given', label: 'Feedback given' },
  ])
}

watch([kindFilter, categoryFilter, siteFilter], load)
onMounted(load)
</script>

<style scoped>
.dot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; }
.obs-row {
  display: flex; align-items: center; gap: 10px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.obs-row:last-child { border-bottom: none; }
.obs-icon {
  width: 28px; height: 28px; border-radius: 9px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
</style>
