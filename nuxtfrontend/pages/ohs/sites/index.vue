<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-office-building-outline"
      eyebrow="OHSMS · Organisational context"
      title="Sites & Workplaces"
      subtitle="Every workplace with its hazard profile, headcount, exposure hours and live safety status."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Add site
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-office-building</v-icon>
        <b>{{ items.count.value }}</b> sites</span>
      <span class="ohs-chip"><v-icon size="12">mdi-account-group</v-icon>
        <b>{{ fmt(stats.headcount) }}</b> workers</span>
      <span class="ohs-chip"><v-icon size="12">mdi-clock-outline</v-icon>
        <b>{{ fmt(stats.hours) }}</b> h/yr</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Sites" :value="items.count.value" icon="mdi-office-building-outline" tone="primary"
              :sub="`${stats.highHazard} high-hazard`" />
      <OhsKpi label="Workforce" :value="fmt(stats.headcount)" icon="mdi-account-group" tone="info"
              sub="total headcount" />
      <OhsKpi label="Exposure hours" :value="fmt(stats.hours)" icon="mdi-clock-outline" tone="primary"
              sub="person-hours per year" />
      <OhsKpi label="Open hazards" :value="stats.hazards" icon="mdi-alert-outline" tone="warn"
              sub="across all sites" />
      <OhsKpi label="Open incidents" :value="stats.incidents" icon="mdi-alert-circle-outline"
              :tone="stats.incidents ? 'err' : 'ok'" sub="unresolved" />
    </div>

    <v-row dense>
      <v-col v-for="s in items.items.value" :key="s.id" cols="12" md="6" lg="4">
        <div class="site-card" :class="`site-card--${s.risk_profile}`">
          <div class="d-flex align-center justify-space-between" style="gap:8px">
            <div class="d-flex align-center" style="gap:9px">
              <v-avatar size="34" :color="profileColor(s.risk_profile)" variant="tonal">
                <v-icon size="17">{{ siteIcon(s.site_type) }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-body-2 font-weight-bold" style="line-height:1.2">{{ s.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ s.code || '—' }} · {{ s.site_type_display }}</div>
              </div>
            </div>
            <span class="ohs-badge" :class="`ohs-badge--${profileTone(s.risk_profile)}`">
              {{ s.risk_profile_display }}
            </span>
          </div>

          <div class="site-metrics">
            <div class="site-metric">
              <div class="site-metric-label">Headcount</div>
              <div class="site-metric-value">{{ fmt(s.headcount) }}</div>
            </div>
            <div class="site-metric">
              <div class="site-metric-label">Open hazards</div>
              <div class="site-metric-value" :class="{ 'text-warning': s.open_hazards }">{{ s.open_hazards }}</div>
            </div>
            <div class="site-metric">
              <div class="site-metric-label">Incidents</div>
              <div class="site-metric-value" :class="{ 'text-error': s.open_incidents }">{{ s.open_incidents }}</div>
            </div>
          </div>

          <div class="text-caption text-medium-emphasis mt-2">
            <v-icon size="12">mdi-account-hard-hat</v-icon> {{ s.site_manager || 'No manager' }}
            <span v-if="s.manager_phone"> · {{ s.manager_phone }}</span>
          </div>
          <div class="text-caption text-medium-emphasis">
            <v-icon size="12">mdi-map-marker</v-icon> {{ s.address || s.county || '—' }}
          </div>
          <div class="text-caption text-medium-emphasis">
            <v-icon size="12">mdi-medical-bag</v-icon> {{ s.first_aider_count }} first aider(s)
            <span v-if="s.emergency_assembly_point"> · assembly: {{ s.emergency_assembly_point }}</span>
          </div>
        </div>
      </v-col>
    </v-row>
    <div v-if="!items.items.value.length" class="ohs-empty">No sites configured.</div>

    <v-dialog v-model="createDialog" max-width="680" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-office-building-plus" title="Add a site"
                           subtitle="Hazard profile drives the default risk weighting in reports." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.name" label="Site name" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.code" label="Code" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site_type" :items="siteTypes" item-title="label" item-value="value"
                        label="Site type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.risk_profile" :items="riskProfiles" item-title="label" item-value="value"
                        label="Hazard profile" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.county" label="County / region" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.headcount" type="number" min="0" label="Headcount"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="form.address" label="Address" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.site_manager" label="Site manager" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.manager_phone" label="Manager phone" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.name" @click="save">Add site</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Sites · OHSMS' })

const ohs = useOhs()
const items = ohs.resource('sites')
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  name: '', code: '', site_type: 'office', risk_profile: 'medium',
  county: '', headcount: 0, address: '', site_manager: '', manager_phone: '',
})

const siteTypes = [
  { label: 'Office', value: 'office' },
  { label: 'Warehouse', value: 'warehouse' },
  { label: 'Factory / plant', value: 'factory' },
  { label: 'Construction site', value: 'construction' },
  { label: 'Laboratory', value: 'laboratory' },
  { label: 'Clinic', value: 'clinic' },
  { label: 'Fuel station', value: 'fuel_station' },
  { label: 'Farm', value: 'farm' },
  { label: 'Mine / quarry', value: 'mine' },
  { label: 'Other', value: 'other' },
]
const riskProfiles = [
  { label: 'Low hazard', value: 'low' },
  { label: 'Medium hazard', value: 'medium' },
  { label: 'High hazard', value: 'high' },
  { label: 'Severe hazard', value: 'severe' },
]

const stats = computed(() => {
  const all = items.items.value || []
  return {
    headcount: all.reduce((s, i) => s + (i.headcount || 0), 0),
    hours: all.reduce((s, i) => s + (i.hours_worked || 0), 0),
    hazards: all.reduce((s, i) => s + (i.open_hazards || 0), 0),
    incidents: all.reduce((s, i) => s + (i.open_incidents || 0), 0),
    highHazard: all.filter((i) => ['high', 'severe'].includes(i.risk_profile)).length,
  }
})

function fmt(v) {
  return Number(v || 0).toLocaleString()
}
function siteIcon(t) {
  return {
    office: 'mdi-office-building', warehouse: 'mdi-warehouse', factory: 'mdi-factory',
    construction: 'mdi-crane', laboratory: 'mdi-flask-outline', clinic: 'mdi-hospital-box-outline',
    fuel_station: 'mdi-gas-station', farm: 'mdi-barn', mine: 'mdi-pickaxe', other: 'mdi-map-marker',
  }[t] || 'mdi-office-building'
}
function profileColor(p) {
  return { low: 'success', medium: 'info', high: 'warning', severe: 'error' }[p] || 'grey'
}
function profileTone(p) {
  return { low: 'ok', medium: 'info', high: 'warn', severe: 'err' }[p] || 'muted'
}

async function load() {
  await items.list({ ordering: 'name' })
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    name: '', code: '', site_type: 'office', risk_profile: 'medium',
    county: '', headcount: 0, address: '', site_manager: '', manager_phone: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    await items.create({ ...form })
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Site added.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

function exportData() {
  exportCsv(`sites_${new Date().toISOString().slice(0, 10)}.csv`, items.items.value, [
    { key: 'name', label: 'Site' },
    { key: 'code', label: 'Code' },
    { key: 'site_type_display', label: 'Type' },
    { key: 'risk_profile_display', label: 'Hazard profile' },
    { key: 'county', label: 'County' },
    { key: 'headcount', label: 'Headcount' },
    { key: 'hours_worked', label: 'Hours/yr' },
    { key: 'open_hazards', label: 'Open hazards' },
    { key: 'open_incidents', label: 'Open incidents' },
    { key: 'site_manager', label: 'Manager' },
  ])
}

onMounted(load)
</script>

<style scoped>
.site-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-top-width: 3px;
  border-radius: 13px;
  padding: 13px 14px;
  background: rgb(var(--v-theme-surface));
  height: 100%;
  transition: box-shadow .16s ease, transform .16s ease;
}
.site-card:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(15, 23, 42, .08); }
.site-card--low { border-top-color: #16a34a; }
.site-card--medium { border-top-color: #0284c7; }
.site-card--high { border-top-color: #f59e0b; }
.site-card--severe { border-top-color: #dc2626; }
.site-metrics {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
  margin-top: 11px;
}
.site-metric {
  border-radius: 9px;
  padding: 6px 8px;
  background: rgba(15, 23, 42, 0.03);
}
.site-metric-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.site-metric-value { font-size: 15px; font-weight: 800; line-height: 1.2; }
</style>
