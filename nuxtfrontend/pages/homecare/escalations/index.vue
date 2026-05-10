<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Escalations"
      subtitle="Patients flagged for clinical attention. Triage, acknowledge and resolve."
      eyebrow="CLINICAL SAFETY"
      icon="mdi-alert-octagram"
      :chips="[
        { icon: 'mdi-flash',  label: `${stats.open} open` },
        { icon: 'mdi-fire',   label: `${stats.critical} critical` },
        { icon: 'mdi-check-decagram', label: `${stats.mttrLabel} avg MTTR` }
      ]"
    >
      <template #actions>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-radar"
               class="text-none mr-2" :loading="evaluating" @click="evaluate">
          <span class="font-weight-bold">Evaluate now</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-cog" class="text-none" to="/homecare/escalations/rules"
               @click.stop>
          <span class="text-teal-darken-2 font-weight-bold">Rules</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="44" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <v-col cols="12" lg="8">
        <HomecarePanel title="Active escalations" subtitle="Open and acknowledged events"
                       icon="mdi-bell-alert" color="#dc2626">
          <v-row dense class="mb-2">
            <v-col cols="12" md="5">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                            placeholder="Search reason, patient…" density="compact"
                            variant="outlined" hide-details rounded="lg" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="filterSeverity" :items="severityOptions"
                        label="Severity" density="compact" variant="outlined"
                        hide-details clearable rounded="lg" />
            </v-col>
            <v-col cols="12" md="4">
              <v-btn-toggle v-model="filterStatus" mandatory density="comfortable"
                            rounded="lg" color="teal" class="w-100">
                <v-btn value="all" size="small">All</v-btn>
                <v-btn value="open" size="small">Open</v-btn>
                <v-btn value="acknowledged" size="small">Ack</v-btn>
                <v-btn value="resolved" size="small">Resolved</v-btn>
              </v-btn-toggle>
            </v-col>
          </v-row>

          <v-progress-linear v-if="loading" indeterminate color="error" class="mb-2" rounded />

          <div v-if="filtered.length">
            <v-card v-for="e in filtered" :key="e.id" class="hc-esc-card mb-2"
                    rounded="xl" :elevation="0">
              <div class="hc-esc-band" :style="{ background: severityColor(e.severity).hex }" />
              <div class="pa-4">
                <div class="d-flex align-center ga-3 mb-2">
                  <v-avatar size="44" :color="severityColor(e.severity).vuetify" variant="tonal">
                    <v-icon :icon="severityIcon(e.severity)" />
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="d-flex align-center ga-2">
                      <div class="text-subtitle-1 font-weight-bold text-truncate">{{ e.reason }}</div>
                      <v-chip size="x-small" :color="severityColor(e.severity).vuetify" variant="tonal">
                        {{ e.severity }}
                      </v-chip>
                      <v-chip size="x-small" :color="statusColor(e.status)" variant="tonal">
                        {{ e.status }}
                      </v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      <v-icon icon="mdi-account" size="12" /> {{ e.patient_name }}
                      <span class="mx-1">·</span>
                      <v-icon icon="mdi-clock-outline" size="12" /> {{ relTime(e.triggered_at) }}
                      <span v-if="e.rule_name" class="mx-1">·</span>
                      <span v-if="e.rule_name">
                        <v-icon icon="mdi-shield-check" size="12" /> {{ e.rule_name }}
                      </span>
                    </div>
                  </div>
                  <v-btn v-if="e.status === 'open'" size="small" color="info" variant="tonal"
                         rounded="lg" class="text-none" prepend-icon="mdi-eye-check"
                         @click="acknowledge(e)">Acknowledge</v-btn>
                  <v-btn v-if="e.status !== 'resolved'" size="small" color="success"
                         variant="tonal" rounded="lg" class="text-none ml-1"
                         prepend-icon="mdi-check-decagram" @click="openResolve(e)">Resolve</v-btn>
                </div>
                <p v-if="e.detail" class="text-body-2 text-medium-emphasis mb-2"
                   style="white-space:pre-wrap;">{{ e.detail }}</p>
                <div v-if="e.acknowledged_by_name || e.resolution_notes"
                     class="text-caption text-medium-emphasis">
                  <span v-if="e.acknowledged_by_name">
                    <v-icon icon="mdi-account-check" size="12" />
                    Acknowledged by {{ e.acknowledged_by_name }}
                  </span>
                  <span v-if="e.resolution_notes" class="ml-2">
                    <v-icon icon="mdi-message-text" size="12" /> {{ e.resolution_notes }}
                  </span>
                </div>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-shield-check" title="No escalations match"
                      message="Adjust filters or run an evaluation." />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel title="By severity" icon="mdi-chart-donut" color="#7c3aed">
          <DonutRing :segments="severitySegments" :size="180" :thickness="18">
            <div class="text-h4 font-weight-bold">{{ items.length }}</div>
            <div class="text-caption text-medium-emphasis">total</div>
          </DonutRing>
          <v-divider class="my-3" />
          <div v-for="r in severityRows" :key="r.label"
               class="d-flex align-center pa-2 rounded-lg mb-1"
               :style="{ background: r.bg }">
            <v-avatar size="28" :color="r.color" variant="flat" class="mr-2">
              <v-icon :icon="r.icon" color="white" size="14" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ r.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ r.count }} event(s)</div>
            </div>
          </div>
        </HomecarePanel>

        <HomecarePanel title="Recent activity" icon="mdi-history" color="#0284c7" class="mt-3">
          <v-timeline density="compact" side="end" line-thickness="2"
                      line-color="grey-lighten-2">
            <v-timeline-item v-for="e in recent" :key="e.id" size="small"
                             :dot-color="severityColor(e.severity).vuetify">
              <template #icon>
                <v-icon :icon="severityIcon(e.severity)" color="white" size="12" />
              </template>
              <div class="text-caption text-medium-emphasis">{{ relTime(e.triggered_at) }}</div>
              <div class="text-body-2 font-weight-bold">{{ e.reason }}</div>
              <div class="text-caption">{{ e.patient_name }}</div>
            </v-timeline-item>
          </v-timeline>
          <EmptyState v-if="!recent.length" icon="mdi-clock" title="No recent activity" dense />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Resolve dialog -->
    <v-dialog v-model="resolveDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-check-decagram" color="success" class="mr-1" /> Resolve escalation
        </v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-2" v-if="target">
            <strong>{{ target.reason }}</strong> · {{ target.patient_name }}
          </p>
          <v-textarea v-model="resolution" label="Resolution notes" rows="3" auto-grow
                      variant="outlined" density="comfortable" rounded="lg"
                      prepend-inner-icon="mdi-message-text" />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="resolveDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" rounded="lg" class="text-none"
                 :loading="resolving" @click="resolve">Resolve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const items = ref([])
const loading = ref(false)
const evaluating = ref(false)
const resolving = ref(false)

const search = ref('')
const filterSeverity = ref(null)
const filterStatus = ref('open')

const resolveDialog = ref(false)
const resolution = ref('')
const target = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

const severityOptions = [
  { value: 'low',      title: 'Low' },
  { value: 'medium',   title: 'Medium' },
  { value: 'high',     title: 'High' },
  { value: 'critical', title: 'Critical' }
]

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/escalations/', { params: { page_size: 200 } })
    items.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load escalations'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(load)

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return items.value.filter(e => {
    if (filterStatus.value !== 'all' && e.status !== filterStatus.value) return false
    if (filterSeverity.value && e.severity !== filterSeverity.value) return false
    if (!q) return true
    return [e.reason, e.detail, e.patient_name].filter(Boolean)
      .some(s => s.toLowerCase().includes(q))
  })
})

const stats = computed(() => {
  const list = items.value
  const open = list.filter(e => e.status === 'open').length
  const ack = list.filter(e => e.status === 'acknowledged').length
  const resolved = list.filter(e => e.status === 'resolved')
  const critical = list.filter(e => e.severity === 'critical' && e.status !== 'resolved').length
  // Mean Time To Resolve (hours)
  const mttrs = resolved.filter(e => e.resolved_at && e.triggered_at).map(e =>
    (new Date(e.resolved_at) - new Date(e.triggered_at)) / 3600000
  )
  const mttr = mttrs.length ? (mttrs.reduce((a, b) => a + b, 0) / mttrs.length) : 0
  const mttrLabel = mttr ? `${mttr.toFixed(1)} h` : '—'
  return { open, ack, critical, resolved: resolved.length, total: list.length, mttr, mttrLabel }
})

const summary = computed(() => [
  { label: 'Open',         value: stats.value.open,     color: 'error',   icon: 'mdi-bell-alert' },
  { label: 'Acknowledged', value: stats.value.ack,      color: 'info',    icon: 'mdi-eye-check' },
  { label: 'Critical',     value: stats.value.critical, color: 'deep-orange', icon: 'mdi-fire' },
  { label: 'Resolved',     value: stats.value.resolved, color: 'success', icon: 'mdi-check-decagram' }
])

const severityRows = computed(() => severityOptions.map(o => ({
  label: o.title,
  color: severityColor(o.value).hex,
  bg: `${severityColor(o.value).hex}14`,
  icon: severityIcon(o.value),
  count: items.value.filter(e => e.severity === o.value).length
})))

const severitySegments = computed(() => severityOptions.map(o => ({
  label: o.title,
  value: items.value.filter(e => e.severity === o.value).length,
  color: severityColor(o.value).vuetify
})))

const recent = computed(() => [...items.value]
  .sort((a, b) => new Date(b.triggered_at) - new Date(a.triggered_at))
  .slice(0, 6))

function severityColor(s) {
  return ({
    low:      { hex: '#0ea5e9', vuetify: 'info' },
    medium:   { hex: '#f59e0b', vuetify: 'warning' },
    high:     { hex: '#ef4444', vuetify: 'error' },
    critical: { hex: '#7c2d12', vuetify: 'deep-orange' }
  })[s] || { hex: '#64748b', vuetify: 'grey' }
}
function severityIcon(s) {
  return ({ low: 'mdi-information', medium: 'mdi-alert',
            high: 'mdi-alert-octagram', critical: 'mdi-fire' })[s] || 'mdi-bell'
}
function statusColor(s) {
  return ({ open: 'error', acknowledged: 'info', resolved: 'success' })[s] || 'grey'
}
function relTime(d) {
  if (!d) return ''
  const diff = (Date.now() - new Date(d).getTime()) / 60000
  if (diff < 1) return 'just now'
  if (diff < 60) return `${Math.round(diff)} min ago`
  if (diff < 1440) return `${Math.round(diff / 60)} h ago`
  return `${Math.round(diff / 1440)} d ago`
}

async function evaluate() {
  evaluating.value = true
  try {
    const { data } = await $api.post('/homecare/escalations/evaluate_now/')
    snack.text = `Evaluation complete · ${data.created || 0} new event(s)`
    snack.color = 'success'; snack.show = true
    load()
  } catch {
    snack.text = 'Evaluation failed'; snack.color = 'error'; snack.show = true
  } finally { evaluating.value = false }
}
async function acknowledge(e) {
  try {
    const { data } = await $api.post(`/homecare/escalations/${e.id}/acknowledge/`)
    const i = items.value.findIndex(x => x.id === e.id)
    if (i >= 0) items.value.splice(i, 1, data)
    snack.text = 'Acknowledged'; snack.color = 'info'; snack.show = true
  } catch {
    snack.text = 'Acknowledge failed'; snack.color = 'error'; snack.show = true
  }
}
function openResolve(e) { target.value = e; resolution.value = ''; resolveDialog.value = true }
async function resolve() {
  if (!target.value) return
  resolving.value = true
  try {
    const { data } = await $api.post(`/homecare/escalations/${target.value.id}/resolve/`,
      { notes: resolution.value })
    const i = items.value.findIndex(x => x.id === target.value.id)
    if (i >= 0) items.value.splice(i, 1, data)
    snack.text = 'Resolved'; snack.color = 'success'; snack.show = true
    resolveDialog.value = false
  } catch {
    snack.text = 'Resolve failed'; snack.color = 'error'; snack.show = true
  } finally { resolving.value = false }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(220,38,38,0.05) 0%, rgba(13,148,136,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
  transition: transform .15s ease, box-shadow .15s ease;
}
.hc-stat:hover { transform: translateY(-2px); box-shadow: 0 10px 28px -16px rgba(15,23,42,0.25); }
.hc-esc-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
  transition: transform .12s ease, box-shadow .12s ease;
}
.hc-esc-card:hover { transform: translateY(-1px); box-shadow: 0 14px 28px -18px rgba(15,23,42,0.25); }
.hc-esc-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-esc-card { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
</style>
