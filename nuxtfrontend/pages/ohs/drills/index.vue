<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-fire-alert"
      eyebrow="OHSMS · Emergency preparedness"
      title="Emergency Drills"
      subtitle="Evacuation, spill, rescue and security drills with participation, response times and lessons learned."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Schedule drill
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-fire-alert</v-icon>
        <b>{{ items.count.value }}</b> drills</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.completed }}</b> completed</span>
      <span v-if="stats.overdue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-clock-alert</v-icon>
        <b>{{ stats.overdue }}</b> overdue</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Completed" :value="stats.completed" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`${stats.participants} participants`" />
      <OhsKpi label="Avg evacuation" :value="`${stats.avgEvac}s`" icon="mdi-timer-outline"
              :tone="stats.avgEvac && stats.avgEvac <= 240 ? 'ok' : 'warn'" sub="target ≤ 240s" />
      <OhsKpi label="Average score" :value="`${stats.avgScore}%`" icon="mdi-gauge"
              :tone="stats.avgScore >= 85 ? 'ok' : 'warn'" sub="drill effectiveness" />
      <OhsKpi label="Planned" :value="stats.planned" icon="mdi-calendar-clock" tone="info"
              sub="upcoming exercises" />
      <OhsKpi label="Overdue" :value="stats.overdue" icon="mdi-clock-alert"
              :tone="stats.overdue ? 'err' : 'ok'" sub="not executed" />
    </div>

    <v-row dense>
      <v-col v-for="d in items.items.value" :key="d.id" cols="12" md="6" lg="4">
        <div class="drill-card" :class="`drill-card--${drillTone(d)}`">
          <div class="d-flex align-center justify-space-between" style="gap:8px">
            <div class="d-flex align-center" style="gap:8px">
              <v-avatar size="32" :color="drillColor(d.drill_type)" variant="tonal">
                <v-icon size="16">{{ drillIcon(d.drill_type) }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-body-2 font-weight-bold" style="line-height:1.2">{{ d.drill_type_display }}</div>
                <div class="text-caption text-medium-emphasis">{{ d.site_name }}</div>
              </div>
            </div>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(d.status)}`">{{ d.status_display }}</span>
          </div>

          <div class="d-flex align-center justify-space-between mt-3">
            <div>
              <div class="drill-label">Scheduled</div>
              <div class="text-body-2 font-weight-bold">{{ formatDate(d.scheduled_on) }}</div>
            </div>
            <div class="text-right">
              <div class="drill-label">Evacuation</div>
              <div class="text-body-2 font-weight-bold" :class="{ 'text-success': d.evacuation_seconds && d.evacuation_seconds <= 240 }">
                {{ d.evacuation_seconds ? `${d.evacuation_seconds}s` : '—' }}
              </div>
            </div>
          </div>

          <div class="d-flex flex-wrap mt-2" style="gap:5px">
            <span v-if="d.participants" class="mini-chip">{{ d.participants }} participants</span>
            <span v-if="d.duration_minutes" class="mini-chip">{{ d.duration_minutes }} min</span>
            <span v-if="d.score" class="mini-chip mini-chip--ok">{{ d.score }}% score</span>
            <span v-if="d.coordinator" class="mini-chip">{{ d.coordinator }}</span>
          </div>

          <div v-if="d.findings" class="text-caption text-medium-emphasis mt-2">
            <v-icon size="12">mdi-lightbulb-outline</v-icon> {{ d.findings }}
          </div>
        </div>
      </v-col>
    </v-row>
    <div v-if="!items.items.value.length" class="ohs-empty">No drills recorded.</div>

    <v-dialog v-model="createDialog" max-width="620">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-fire-alert" title="Schedule an emergency drill"
                           subtitle="Plan the exercise; record outcomes once it runs." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.drill_type" :items="drillTypes" item-title="label" item-value="value"
                        label="Drill type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.scheduled_on" type="date" label="Scheduled" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.coordinator" label="Coordinator" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.scenario" label="Scenario" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.site" @click="save">Schedule drill</v-btn>
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
useHead({ title: 'Emergency Drills · OHSMS' })

const ohs = useOhs()
const items = ohs.resource('drills')
const lookups = ref({})
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  drill_type: 'fire', site: null, coordinator: '', scenario: '',
  scheduled_on: new Date().toISOString().slice(0, 10),
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const drillTypes = computed(() => lookups.value.drill_types || [])

const stats = computed(() => {
  const all = items.items.value || []
  const completed = all.filter((d) => d.status === 'completed')
  const scored = completed.filter((d) => d.score)
  const evacs = completed.filter((d) => d.evacuation_seconds)
  const today = new Date().toISOString().slice(0, 10)
  return {
    completed: completed.length,
    planned: all.filter((d) => d.status === 'planned').length,
    overdue: all.filter((d) => d.status === 'planned' && d.scheduled_on < today).length,
    participants: completed.reduce((s, d) => s + (d.participants || 0), 0),
    avgEvac: evacs.length ? Math.round(evacs.reduce((s, d) => s + d.evacuation_seconds, 0) / evacs.length) : 0,
    avgScore: scored.length ? Math.round(scored.reduce((s, d) => s + d.score, 0) / scored.length) : 0,
  }
})

function drillColor(t) {
  return {
    fire: 'error', chemical: 'deep-purple', medical: 'success', earthquake: 'brown',
    confined_space: 'blue-grey', security: 'indigo', power: 'amber',
  }[t] || 'primary'
}
function drillIcon(t) {
  return {
    fire: 'mdi-fire', chemical: 'mdi-flask-outline', medical: 'mdi-medical-bag',
    earthquake: 'mdi-pulse', confined_space: 'mdi-valve', security: 'mdi-shield-alert',
    power: 'mdi-flash-off',
  }[t] || 'mdi-fire-alert'
}
function drillTone(d) {
  if (d.status === 'completed') return (d.score || 0) >= 85 ? 'ok' : 'warn'
  if (d.status === 'planned' && d.scheduled_on < new Date().toISOString().slice(0, 10)) return 'err'
  return 'info'
}

async function load() {
  await items.list({ ordering: '-scheduled_on' })
  lookups.value = await ohs.loadLookups()
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    drill_type: 'fire', site: siteOptions.value[0]?.value || null, coordinator: '',
    scenario: '', scheduled_on: new Date().toISOString().slice(0, 10),
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    await items.create({ ...form })
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Drill scheduled.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

function exportData() {
  exportCsv(`emergency_drills_${new Date().toISOString().slice(0, 10)}.csv`, items.items.value, [
    { key: 'drill_type_display', label: 'Drill type' },
    { key: 'site_name', label: 'Site' },
    { key: 'scheduled_on', label: 'Scheduled' },
    { key: 'conducted_on', label: 'Conducted' },
    { key: 'status_display', label: 'Status' },
    { key: 'participants', label: 'Participants' },
    { key: 'duration_minutes', label: 'Duration (min)' },
    { key: 'evacuation_seconds', label: 'Evacuation (s)' },
    { key: 'score', label: 'Score' },
    { key: 'findings', label: 'Findings' },
    { key: 'coordinator', label: 'Coordinator' },
  ])
}

onMounted(load)
</script>

<style scoped>
.drill-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-left-width: 3px;
  border-radius: 13px;
  padding: 13px 14px;
  background: rgb(var(--v-theme-surface));
  height: 100%;
  transition: box-shadow .16s ease, transform .16s ease;
}
.drill-card:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(15, 23, 42, .08); }
.drill-card--ok { border-left-color: #16a34a; }
.drill-card--warn { border-left-color: #f59e0b; }
.drill-card--err { border-left-color: #dc2626; }
.drill-card--info { border-left-color: #0284c7; }
.drill-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .5px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.mini-chip {
  font-size: 10px; font-weight: 600; padding: 1px 7px; border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), .62); background: rgba(15, 23, 42, 0.05);
}
.mini-chip--ok { color: #15803d; background: rgba(34, 197, 94, 0.13); }
</style>
