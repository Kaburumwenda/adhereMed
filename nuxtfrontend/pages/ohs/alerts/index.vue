<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-bell-alert"
      eyebrow="OHSMS · Alert centre"
      title="Alert Centre"
      subtitle="Every overdue, expiring and out-of-tolerance item across the whole OHSMS, ranked by severity in one action list."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-radar"
               to="/ohs/intelligence">Intelligence</v-btn>
      </template>
      <span class="ohs-chip ohs-chip-danger"><v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ counts.high }}</b> high</span>
      <span class="ohs-chip ohs-chip-warn"><v-icon size="12">mdi-alert</v-icon>
        <b>{{ counts.medium }}</b> medium</span>
      <span class="ohs-chip"><v-icon size="12">mdi-information</v-icon>
        <b>{{ counts.low }}</b> low</span>
      <span class="ohs-chip"><v-icon size="12">mdi-format-list-bulleted</v-icon>
        <b>{{ counts.total }}</b> total</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="High severity" :value="counts.high" icon="mdi-alert-octagon-outline"
              :tone="counts.high ? 'err' : 'ok'" sub="act today" />
      <OhsKpi label="Medium" :value="counts.medium" icon="mdi-alert-outline"
              :tone="counts.medium ? 'warn' : 'ok'" sub="this week" />
      <OhsKpi label="Low" :value="counts.low" icon="mdi-information-outline" tone="info"
              sub="housekeeping" />
      <OhsKpi label="Categories affected" :value="categories" icon="mdi-shape-outline" tone="primary"
              sub="of 13 registers" />
      <OhsKpi label="Oldest item" :value="`${oldest}d`" icon="mdi-clock-alert"
              :tone="oldest > 60 ? 'err' : 'warn'" sub="days overdue" />
    </div>

    <OhsPanel title="Action list" :subtitle="`${filtered.length} item(s)`" icon="mdi-bell-alert" flush>
      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Filter alerts…" prepend-inner-icon="mdi-magnify"
                      density="compact" variant="outlined" rounded="lg" hide-details single-line clearable
                      style="max-width:250px" />
        <v-select v-model="severityFilter" :items="severityOptions" item-title="label" item-value="value"
                  placeholder="Any severity" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:170px" />
        <v-select v-model="categoryFilter" :items="categoryOptions" item-title="label" item-value="value"
                  placeholder="All categories" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:190px" />
        <v-spacer />
        <v-btn variant="text" class="text-none" prepend-icon="mdi-check-all" @click="reload">Reload</v-btn>
      </div>

      <v-progress-linear v-if="loading" indeterminate color="primary" height="2" />

      <div class="ohs-scroll" style="max-height:66vh">
        <div v-for="a in filtered" :key="a.id" class="alert-row" :class="`alert-row--${a.severity}`">
          <div class="alert-icon" :class="`alert-icon--${a.severity}`">
            <v-icon size="15">{{ categoryIcon(a.category) }}</v-icon>
          </div>
          <div class="flex-grow-1" style="min-width:0">
            <div class="text-body-2 font-weight-bold">{{ a.title }}</div>
            <div class="text-caption text-medium-emphasis">{{ a.detail }}</div>
            <div class="d-flex flex-wrap mt-1" style="gap:5px">
              <span class="mini-chip">{{ categoryLabel(a.category) }}</span>
              <span v-if="a.owner" class="mini-chip">{{ a.owner }}</span>
              <span v-if="a.due" class="mini-chip mini-chip--due">due {{ formatDate(a.due) }}</span>
            </div>
          </div>
          <span class="ohs-badge"
                :class="a.severity === 'high' ? 'ohs-badge--err'
                  : a.severity === 'medium' ? 'ohs-badge--warn' : 'ohs-badge--info'">
            {{ a.severity }}
          </span>
          <v-btn icon="mdi-arrow-right" variant="text" size="x-small" :to="a.href" />
        </div>
        <div v-if="!filtered.length && !loading" class="ohs-empty">
          <v-icon size="34" color="success">mdi-check-decagram</v-icon>
          Nothing needs attention. Every register is current.
        </div>
      </div>
    </OhsPanel>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Alerts · OHSMS' })

const { $api } = useNuxtApp()

const raw = ref({ counts: {}, alerts: [] })
const loading = ref(true)
const search = ref('')
const severityFilter = ref(null)
const categoryFilter = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const severityOptions = [
  { label: 'High', value: 'high' },
  { label: 'Medium', value: 'medium' },
  { label: 'Low', value: 'low' },
]

const CATEGORY_LABELS = {
  control: 'Control measure', capa: 'CAPA', inspection: 'Inspection', permit: 'Permit',
  training: 'Training', certification: 'Certification', contractor: 'Contractor',
  document: 'Document', meeting: 'Meeting', health: 'Health', risk: 'Risk',
  exposure: 'Exposure', site: 'Site',
}

const counts = computed(() => raw.value.counts || { high: 0, medium: 0, low: 0, total: 0 })
const alerts = computed(() => raw.value.alerts || [])

const categories = computed(() => new Set(alerts.value.map((a) => a.category)).size)

const categoryOptions = computed(() => [...new Set(alerts.value.map((a) => a.category))]
  .map((c) => ({ label: CATEGORY_LABELS[c] || c, value: c })))

const oldest = computed(() => {
  const days = alerts.value
    .filter((a) => a.due)
    .map((a) => Math.round((Date.now() - new Date(a.due).getTime()) / 86400000))
  return days.length ? Math.max(...days) : 0
})

const filtered = computed(() => alerts.value.filter((a) => {
  if (severityFilter.value && a.severity !== severityFilter.value) return false
  if (categoryFilter.value && a.category !== categoryFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${a.title} ${a.detail} ${a.owner} ${a.category}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

function categoryLabel(c) {
  return CATEGORY_LABELS[c] || c
}
function categoryIcon(c) {
  return {
    control: 'mdi-shield-alert', capa: 'mdi-source-branch-check', inspection: 'mdi-clipboard-check',
    permit: 'mdi-file-document-check', training: 'mdi-school', certification: 'mdi-certificate',
    contractor: 'mdi-account-hard-hat', document: 'mdi-file-document-multiple',
    meeting: 'mdi-account-voice', health: 'mdi-heart-pulse', risk: 'mdi-alert-octagon',
    exposure: 'mdi-air-filter', site: 'mdi-office-building',
  }[c] || 'mdi-bell-alert'
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/ohs/alerts/')
    raw.value = data
  } catch (e) {
    snack.value = { show: true, color: 'error', text: 'Could not load alerts.' }
  } finally {
    loading.value = false
  }
}

function reload() {
  load()
  snack.value = { show: true, color: 'success', text: 'Alert feed refreshed.' }
}

function exportData() {
  exportCsv(`ohs_alerts_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'severity', label: 'Severity' },
    { key: 'category', label: 'Category' },
    { key: 'title', label: 'Alert' },
    { key: 'detail', label: 'Detail' },
    { key: 'owner', label: 'Owner' },
    { key: 'due', label: 'Due' },
  ])
}

onMounted(load)
</script>

<style scoped>
.alert-row {
  display: flex; align-items: center; gap: 11px;
  padding: 10px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), .05);
  border-left: 3px solid transparent;
}
.alert-row:last-child { border-bottom: none; }
.alert-row--high { border-left-color: #dc2626; background: rgba(239, 68, 68, .025); }
.alert-row--medium { border-left-color: #f59e0b; }
.alert-row--low { border-left-color: #0284c7; }
.alert-icon {
  width: 30px; height: 30px; border-radius: 9px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center; color: #fff;
}
.alert-icon--high { background: #dc2626; }
.alert-icon--medium { background: #f59e0b; }
.alert-icon--low { background: #0284c7; }
.mini-chip {
  font-size: 10px; font-weight: 600; padding: 1px 7px; border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), .62); background: rgba(15, 23, 42, 0.05);
}
.mini-chip--due { color: #b45309; background: rgba(245, 158, 11, .13); }
</style>
