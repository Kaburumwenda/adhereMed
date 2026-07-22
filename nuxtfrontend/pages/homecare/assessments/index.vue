<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- ═══ PREMIUM HERO ═══ -->
    <HomecareHero
      title="Patient Assessments"
      subtitle="Structured nursing assessments — initial survey, head-to-toe baseline, validated risk scales, device & disease care bundles. Per WHO/CDC/NPIAP guidelines."
      eyebrow="CLINICAL ASSESSMENTS"
      icon="mdi-clipboard-list-outline"
      :chips="heroChips"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus" class="text-none"
               to="/homecare/assessments/new">
          <span class="text-teal-darken-2 font-weight-bold">New assessment</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- ═══ KPI CARDS ═══ -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpis" :key="k.label" cols="12" sm="6" md="3">
        <HomecareKpiCard v-bind="k" />
      </v-col>
    </v-row>

    <!-- ═══ SESSIONS TABLE ═══ -->
    <HomecarePanel
      title="Assessment sessions"
      subtitle="All patient assessments · newest first"
      icon="mdi-clipboard-list-outline"
      color="#0d9488"
      class="mt-1"
    >
      <template #actions>
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search patient…"
                      density="compact" variant="outlined" hide-details rounded="lg"
                      style="max-width:240px" clearable />
        <v-select v-model="riskFilter" :items="riskOptions" item-title="label" item-value="value"
                  density="compact" hide-details variant="outlined" rounded="lg"
                  prepend-inner-icon="mdi-shield" style="max-width:160px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  density="compact" hide-details variant="outlined" rounded="lg"
                  prepend-inner-icon="mdi-filter-variant" style="max-width:180px" />
      </template>

      <v-table density="comfortable" hover class="sessions-table">
        <thead>
          <tr>
            <th>Patient</th>
            <th>Type</th>
            <th>Assessed</th>
            <th>By</th>
            <th>Braden</th>
            <th>Morse</th>
            <th>Caprini</th>
            <th>MUST</th>
            <th>Pain</th>
            <th>Risk</th>
            <th>Alerts</th>
            <th class="text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in paged" :key="s.id" class="session-row">
            <td>
              <div class="text-body-2 font-weight-medium text-truncate" style="max-width:170px">
                {{ s.patient_name || '—' }}
              </div>
              <div class="text-caption text-medium-emphasis">{{ s.medical_record_number || '—' }}</div>
            </td>
            <td>
              <v-chip size="x-small" variant="tonal" color="teal">{{ s.session_type_label || s.session_type }}</v-chip>
            </td>
            <td class="text-caption">{{ formatDate(s.assessed_at) }}</td>
            <td class="text-caption text-truncate" style="max-width:120px">{{ s.assessed_by_name || '—' }}</td>
            <td><span v-if="s.braden_total != null" class="font-weight-bold" :class="`text-${bradenChip(s.braden_total).color}`">{{ s.braden_total }}</span><span v-else>—</span></td>
            <td><span v-if="s.morse_score != null" class="font-weight-bold" :class="`text-${morseChip(s.morse_score).color}`">{{ s.morse_score }}</span><span v-else>—</span></td>
            <td><span v-if="s.caprini_points != null" class="font-weight-bold" :class="`text-${capriniChip(s.caprini_points).color}`">{{ s.caprini_points }}</span><span v-else>—</span></td>
            <td><span v-if="s.must_score != null" class="font-weight-bold" :class="`text-${mustChip(s.must_score).color}`">{{ s.must_score }}</span><span v-else>—</span></td>
            <td>
              <span v-if="s.pain_score != null" class="font-weight-bold" :class="painClass(s.pain_score)">{{ s.pain_score }}/10</span>
              <span v-else>—</span>
            </td>
            <td>
              <v-chip size="x-small" :color="riskColor(s.overall_risk_level)" variant="flat"
                      class="text-uppercase font-weight-bold">
                {{ s.overall_risk_label || s.overall_risk_level }}
              </v-chip>
            </td>
            <td>
              <v-chip v-if="s.alert_count" size="x-small" color="error" variant="tonal"
                      class="font-weight-bold">
                <v-icon size="12" class="mr-1">mdi-bell-alert</v-icon>{{ s.alert_count }}
              </v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </td>
            <td class="text-right text-no-wrap">
              <v-btn icon="mdi-eye" size="x-small" variant="text" color="teal"
                     :to="`/homecare/assessments/${s.id}`" />
            </td>
          </tr>
          <tr v-if="!filtered.length">
            <td colspan="12" class="text-center text-medium-emphasis py-8">
              <v-icon icon="mdi-clipboard-list-outline" size="48" class="d-block mx-auto mb-2" color="grey-lighten-1" />
              No assessment sessions yet. Click <strong>New assessment</strong> to begin.
            </td>
          </tr>
        </tbody>
      </v-table>

      <div v-if="filtered.length > perPage" class="d-flex justify-center mt-4">
        <v-pagination v-model="page" :length="pageCount" :total-visible="7" density="comfortable" color="teal" />
      </div>
    </HomecarePanel>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="4000" location="top">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import { RISK_META, SEVERITY_META } from '~/composables/useAssessmentScoring'

const { $api } = useNuxtApp()
const sessions = ref([])
const summary = ref({ total: 0, by_risk: {}, open_alerts: 0, signed: 0, last_assessed_at: null })
const search = ref('')
const riskFilter = ref('all')
const typeFilter = ref('all')
const page = ref(1)
const perPage = 15
const snack = reactive({ show: false, color: 'success', text: '' })

const riskOptions = [
  { value: 'all', label: 'All risks' },
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
  { value: 'critical', label: 'Critical' },
]
const typeOptions = [
  { value: 'all', label: 'All types' },
  { value: 'initial', label: 'Initial' },
  { value: 'head_to_toe', label: 'Head-to-Toe' },
  { value: 'reassessment', label: 'Reassessment' },
  { value: 'admission', label: 'Admission' },
  { value: 'discharge', label: 'Discharge' },
]

const heroChips = computed(() => [
  { icon: 'mdi-clipboard-list-outline', label: `${summary.value.total} sessions` },
  { icon: 'mdi-alert-octagram', label: `${summary.value.open_alerts} open alerts` },
  { icon: 'mdi-shield-check', label: `${summary.value.signed} signed` },
])

const kpis = computed(() => [
  { label: 'Total assessments', value: summary.value.total || '—', icon: 'mdi-clipboard-list-outline', color: '#0d9488' },
  { label: 'High / critical risk', value: ((summary.value.by_risk?.high || 0) + (summary.value.by_risk?.critical || 0)) || '—', icon: 'mdi-shield-alert', color: '#ef4444' },
  { label: 'Open alerts', value: summary.value.open_alerts || '—', icon: 'mdi-bell-alert', color: '#f59e0b' },
  { label: 'Last assessment', value: summary.value.last_assessed_at ? formatDate(summary.value.last_assessed_at) : '—', icon: 'mdi-clock-outline', color: '#8b5cf6' },
])

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return sessions.value.filter(s => {
    if (riskFilter.value !== 'all' && s.overall_risk_level !== riskFilter.value) return false
    if (typeFilter.value !== 'all' && s.session_type !== typeFilter.value) return false
    if (!q) return true
    return [s.patient_name, s.medical_record_number, s.assessed_by_name].filter(Boolean).join(' ').toLowerCase().includes(q)
  })
})
const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / perPage)))
const paged = computed(() => filtered.value.slice((page.value - 1) * perPage, page.value * perPage))

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}
function riskColor(level) { return (RISK_META[level]?.color) || 'grey' }
function painClass(s) {
  if (s == null) return ''
  if (s >= 7) return 'text-error'
  if (s >= 4) return 'text-warning'
  return 'text-success'
}
function bradenChip(v) {
  if (v == null) return { color: 'grey' }
  if (v <= 12) return { color: 'error' }
  if (v <= 18) return { color: 'warning' }
  return { color: 'success' }
}
function morseChip(v) {
  if (v == null) return { color: 'grey' }
  if (v >= 45) return { color: 'error' }
  if (v >= 25) return { color: 'warning' }
  return { color: 'success' }
}
function capriniChip(v) {
  if (v == null) return { color: 'grey' }
  if (v >= 5) return { color: 'error' }
  if (v >= 3) return { color: 'warning' }
  if (v === 2) return { color: 'info' }
  return { color: 'success' }
}
function mustChip(v) {
  if (v == null) return { color: 'grey' }
  if (v >= 2) return { color: 'error' }
  if (v === 1) return { color: 'warning' }
  return { color: 'success' }
}

async function load() {
  try {
    const [sess, sum] = await Promise.all([
      $api.get('/homecare/assessment-sessions/', { params: { page_size: 500 } }),
      $api.get('/homecare/assessment-sessions/summary/'),
    ])
    sessions.value = sess.data?.results || sess.data || []
    summary.value = sum.data || summary.value
  } catch (e) {
    snack.color = 'error'; snack.text = 'Could not load assessments.'; snack.show = true
  }
}
onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.sessions-table :deep(td), .sessions-table :deep(th) { white-space: nowrap; }
.session-row { transition: background 0.15s ease; }
.session-row:hover { background: rgba(13,148,136,0.04); }
</style>
