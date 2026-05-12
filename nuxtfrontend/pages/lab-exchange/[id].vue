<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1500px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn icon="mdi-arrow-left" variant="text" @click="$router.push('/lab-exchange')" />
      <v-avatar :color="hashColor(item?.patient_user_id || 0)" size="48">
        <span class="text-white font-weight-bold text-h6">{{ initials(item?.patient_name) }}</span>
      </v-avatar>
      <div class="min-width-0">
        <div class="d-flex align-center ga-2 flex-wrap">
          <span class="text-h5 font-weight-bold">{{ item?.patient_name || 'Loading…' }}</span>
          <v-chip v-if="item" size="small" variant="flat"
                  :color="priorityColor(item.priority)" class="text-capitalize text-white">
            <v-icon size="14" start>{{ priorityIcon(item.priority) }}</v-icon>{{ item.priority }}
          </v-chip>
          <v-chip v-if="item" size="small" variant="tonal"
                  :color="statusColor(item.status)" class="text-capitalize">
            <v-icon size="14" start>{{ statusIcon(item.status) }}</v-icon>{{ statusLabel(item.status) }}
          </v-chip>
        </div>
        <div class="text-caption text-medium-emphasis font-monospace">
          LX-{{ String(routeId).padStart(5, '0') }}
          <span v-if="item"> · created {{ formatDateTime(item.created_at) }}</span>
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-printer-outline"
             @click="printDoc">Print</v-btn>
      <v-btn v-if="canAccept" color="primary" rounded="lg" prepend-icon="mdi-check"
             :loading="busy" @click="doAccept">Accept request</v-btn>
      <v-btn v-if="canCancel" variant="outlined" color="error" rounded="lg"
             prepend-icon="mdi-cancel" @click="doCancel">Cancel</v-btn>
    </div>

    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <div v-else-if="!item" class="text-center pa-12">
      <v-icon size="56" color="grey-lighten-1">mdi-alert-circle-outline</v-icon>
      <div class="text-h6 mt-2">Request not found</div>
    </div>

    <v-row v-else>
      <!-- LEFT — main work area -->
      <v-col cols="12" md="8">
        <!-- Workflow stepper -->
        <v-card flat rounded="lg" class="pa-3 mb-3">
          <v-stepper :model-value="stepIndex" alt-labels flat hide-actions class="bg-transparent">
            <v-stepper-header>
              <v-stepper-item :value="1" :complete="stepIndex >= 1" title="Submitted" />
              <v-divider />
              <v-stepper-item :value="2" :complete="stepIndex >= 2" title="Accepted" />
              <v-divider />
              <v-stepper-item :value="3" :complete="stepIndex >= 3" title="Sample collected" />
              <v-divider />
              <v-stepper-item :value="4" :complete="stepIndex >= 4" title="Processing" />
              <v-divider />
              <v-stepper-item :value="5" :complete="stepIndex >= 5" title="Completed" />
            </v-stepper-header>
          </v-stepper>
        </v-card>

        <!-- Tests requested -->
        <v-card flat rounded="lg" class="pa-4 mb-3">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-flask-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Tests requested</div>
            <v-spacer />
            <v-chip size="small" variant="tonal">{{ (item.tests || []).length }} tests</v-chip>
          </div>
          <v-table density="comfortable" class="tests-table">
            <thead>
              <tr>
                <th>Test</th>
                <th>Code</th>
                <th>Specimen</th>
                <th>Instructions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(t, i) in (item.tests || [])" :key="i">
                <td class="font-weight-medium">{{ t.test_name || t.name || '—' }}</td>
                <td><span class="font-monospace text-caption">{{ t.code || '—' }}</span></td>
                <td>
                  <v-chip v-if="t.specimen_type" size="x-small" variant="tonal" color="indigo">
                    {{ t.specimen_type }}
                  </v-chip>
                  <span v-else class="text-medium-emphasis">—</span>
                </td>
                <td class="text-caption text-medium-emphasis">{{ t.instructions || '—' }}</td>
              </tr>
              <tr v-if="!(item.tests || []).length">
                <td colspan="4" class="text-center text-medium-emphasis py-6">
                  No tests on this request
                </td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="item.clinical_notes" class="mt-3">
            <div class="text-overline text-medium-emphasis">Clinical notes</div>
            <div class="text-body-2">{{ item.clinical_notes }}</div>
          </div>
        </v-card>

        <!-- Status update (lab side) -->
        <v-card v-if="canUpdateStatus" flat rounded="lg" class="pa-4 mb-3">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-progress-check</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Update workflow</div>
          </div>
          <div class="d-flex flex-wrap ga-2">
            <v-btn v-for="s in nextStatuses" :key="s.value"
                   :color="s.color" :variant="item.status === s.value ? 'flat' : 'tonal'"
                   size="small" rounded="lg" :prepend-icon="s.icon"
                   :loading="busy && pendingStatus === s.value"
                   @click="updateStatus(s.value)">
              {{ s.label }}
            </v-btn>
          </div>
        </v-card>

        <!-- Results -->
        <v-card flat rounded="lg" class="pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-clipboard-text-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Results</div>
            <v-spacer />
            <v-btn v-if="canEnterResults && !editingResults"
                   variant="tonal" color="primary" size="small" rounded="lg"
                   prepend-icon="mdi-pencil" @click="startEditResults">
              {{ (item.results || []).length ? 'Edit results' : 'Enter results' }}
            </v-btn>
            <v-btn v-if="editingResults" variant="text" size="small" class="mr-1"
                   @click="cancelEditResults">Cancel</v-btn>
            <v-btn v-if="editingResults" color="primary" size="small" rounded="lg"
                   prepend-icon="mdi-content-save" :loading="busy"
                   @click="submitResults">Save & complete</v-btn>
          </div>

          <!-- Read-only display -->
          <div v-if="!editingResults">
            <v-table v-if="(item.results || []).length" density="comfortable" class="results-table">
              <thead>
                <tr>
                  <th>Test</th>
                  <th>Result</th>
                  <th>Unit</th>
                  <th>Flag</th>
                  <th>Comments</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r, i) in item.results" :key="i">
                  <td class="font-weight-medium">{{ r.test_name || '—' }}</td>
                  <td :class="{ 'text-red-darken-2 font-weight-bold': r.is_abnormal }">
                    {{ r.result_value || '—' }}
                  </td>
                  <td>{{ r.unit || '—' }}</td>
                  <td>
                    <v-chip v-if="r.is_abnormal" size="x-small" variant="flat" color="red-darken-2"
                            class="text-white">
                      <v-icon size="12" start>mdi-alert</v-icon>Abnormal
                    </v-chip>
                    <v-chip v-else size="x-small" variant="tonal" color="green">
                      <v-icon size="12" start>mdi-check</v-icon>Normal
                    </v-chip>
                  </td>
                  <td class="text-caption text-medium-emphasis">{{ r.comments || '—' }}</td>
                </tr>
              </tbody>
            </v-table>
            <div v-else class="text-center pa-6 text-medium-emphasis">
              <v-icon size="40" color="grey-lighten-1">mdi-flask-empty-outline</v-icon>
              <div class="text-body-2 mt-1">No results submitted yet.</div>
            </div>
          </div>

          <!-- Editable -->
          <div v-else>
            <v-table density="comfortable" class="results-table">
              <thead>
                <tr>
                  <th>Test</th>
                  <th>Result *</th>
                  <th>Unit</th>
                  <th>Abnormal</th>
                  <th>Comments</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r, i) in editingRows" :key="i">
                  <td class="font-weight-medium">{{ r.test_name }}</td>
                  <td>
                    <v-text-field v-model="r.result_value" density="compact" hide-details
                                  variant="outlined" />
                  </td>
                  <td style="width: 110px">
                    <v-text-field v-model="r.unit" density="compact" hide-details variant="outlined" />
                  </td>
                  <td style="width: 110px">
                    <v-switch v-model="r.is_abnormal" color="red-darken-2" density="compact"
                              hide-details inset />
                  </td>
                  <td>
                    <v-text-field v-model="r.comments" density="compact" hide-details
                                  variant="outlined" placeholder="optional" />
                  </td>
                </tr>
              </tbody>
            </v-table>
          </div>
        </v-card>
      </v-col>

      <!-- RIGHT — sidebar -->
      <v-col cols="12" md="4">
        <!-- Patient -->
        <v-card flat rounded="lg" class="pa-4 mb-3">
          <div class="text-overline text-medium-emphasis mb-1">Patient</div>
          <div class="d-flex align-center mb-2">
            <v-avatar :color="hashColor(item.patient_user_id || 0)" size="40" class="mr-3">
              <span class="text-white font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-bold text-truncate">{{ item.patient_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis">
                Patient ID: {{ item.patient_user_id }}
              </div>
            </div>
          </div>
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-if="item.patient_phone" prepend-icon="mdi-phone"
                         :title="item.patient_phone" />
            <v-list-item v-if="item.is_home_collection" prepend-icon="mdi-home-import-outline"
                         title="Home collection" />
            <v-list-item v-if="item.collection_address" prepend-icon="mdi-map-marker-outline"
                         :subtitle="item.collection_address" title="Address" />
          </v-list>
        </v-card>

        <!-- Source / partner -->
        <v-card flat rounded="lg" class="pa-4 mb-3">
          <div class="text-overline text-medium-emphasis mb-1">
            {{ isLab ? 'Referring source' : 'Performing lab' }}
          </div>
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item prepend-icon="mdi-hospital-building"
                         :title="isLab ? (item.source_tenant_name || '—') : (item.lab_tenant_name || 'Unassigned')" />
            <v-list-item v-if="item.ordering_doctor_name" prepend-icon="mdi-doctor"
                         :title="`Dr. ${item.ordering_doctor_name}`" subtitle="Ordering doctor" />
          </v-list>
        </v-card>

        <!-- Timeline -->
        <v-card flat rounded="lg" class="pa-4">
          <div class="text-overline text-medium-emphasis mb-2">Activity</div>
          <v-timeline density="compact" side="end" align="start" line-thickness="2"
                      truncate-line="both" class="pa-0">
            <v-timeline-item dot-color="indigo-darken-2" size="x-small">
              <div class="text-body-2 font-weight-medium">Request submitted</div>
              <div class="text-caption text-medium-emphasis">
                {{ formatDateTime(item.created_at) }}
              </div>
            </v-timeline-item>
            <v-timeline-item v-if="['accepted','sample_collected','processing','completed'].includes(item.status)"
                             dot-color="cyan-darken-2" size="x-small">
              <div class="text-body-2 font-weight-medium">Accepted by lab</div>
              <div class="text-caption text-medium-emphasis">
                {{ item.lab_tenant_name }}
              </div>
            </v-timeline-item>
            <v-timeline-item v-if="['sample_collected','processing','completed'].includes(item.status)"
                             dot-color="teal-darken-2" size="x-small">
              <div class="text-body-2 font-weight-medium">Sample collected</div>
            </v-timeline-item>
            <v-timeline-item v-if="['processing','completed'].includes(item.status)"
                             dot-color="blue-darken-2" size="x-small">
              <div class="text-body-2 font-weight-medium">Processing</div>
            </v-timeline-item>
            <v-timeline-item v-if="item.status === 'completed'"
                             dot-color="green-darken-2" size="x-small">
              <div class="text-body-2 font-weight-medium">Results delivered</div>
              <div class="text-caption text-medium-emphasis">
                {{ formatDateTime(item.updated_at) }}
              </div>
            </v-timeline-item>
            <v-timeline-item v-if="item.status === 'cancelled'"
                             dot-color="red-darken-2" size="x-small">
              <div class="text-body-2 font-weight-medium">Cancelled</div>
            </v-timeline-item>
          </v-timeline>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatDateTime } from '~/utils/format'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const auth = useAuthStore()
const isLab = computed(() => auth.tenantType === 'lab')

const routeId = computed(() => Number(route.params.id))
const item = ref(null)
const loading = ref(true)
const busy = ref(false)
const pendingStatus = ref(null)
const editingResults = ref(false)
const editingRows = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })

const STATUS_META = {
  pending: { label: 'Pending', color: 'amber-darken-2', icon: 'mdi-clock-outline' },
  accepted: { label: 'Accepted', color: 'cyan-darken-2', icon: 'mdi-check' },
  sample_collected: { label: 'Sample collected', color: 'teal-darken-2', icon: 'mdi-test-tube' },
  processing: { label: 'Processing', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
  completed: { label: 'Completed', color: 'green-darken-2', icon: 'mdi-check-circle' },
  cancelled: { label: 'Cancelled', color: 'red-darken-2', icon: 'mdi-cancel' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1', icon: 'mdi-clock-outline' },
  urgent: { color: 'orange-darken-2', icon: 'mdi-alert' },
  stat: { color: 'red-darken-2', icon: 'mdi-flash' },
}
function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }
function priorityIcon(v) { return PRIORITY_META[v]?.icon || 'mdi-flag-outline' }

const stepIndex = computed(() => {
  if (!item.value) return 0
  const map = { pending: 1, accepted: 2, sample_collected: 3, processing: 4, completed: 5, cancelled: 0 }
  return map[item.value.status] ?? 0
})

const canAccept = computed(() => isLab.value && item.value?.status === 'pending')
const canCancel = computed(() =>
  item.value && ['pending', 'accepted', 'sample_collected', 'processing'].includes(item.value.status)
)
const canUpdateStatus = computed(() =>
  isLab.value && item.value && ['accepted', 'sample_collected', 'processing'].includes(item.value.status)
)
const canEnterResults = computed(() =>
  isLab.value && item.value && ['accepted', 'sample_collected', 'processing', 'completed'].includes(item.value.status)
)

const nextStatuses = computed(() => {
  const all = [
    { value: 'sample_collected', label: 'Mark sample collected', icon: 'mdi-test-tube', color: 'teal' },
    { value: 'processing', label: 'Mark processing', icon: 'mdi-cog-outline', color: 'blue' },
  ]
  return all
})

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get(`/exchange/lab/${routeId.value}/`)
    item.value = data
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to load request'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}
onMounted(load)

async function doAccept() {
  busy.value = true
  try {
    const { data } = await $api.post(`/exchange/lab/${routeId.value}/accept/`)
    item.value = data
    snack.text = 'Request accepted'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to accept'
    snack.color = 'error'
    snack.show = true
  } finally {
    busy.value = false
  }
}

async function updateStatus(value) {
  pendingStatus.value = value
  busy.value = true
  try {
    const { data } = await $api.patch(`/exchange/lab/${routeId.value}/`, { status: value })
    item.value = data
    snack.text = `Status updated to ${statusLabel(value)}`
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to update status'
    snack.color = 'error'
    snack.show = true
  } finally {
    busy.value = false
    pendingStatus.value = null
  }
}

async function doCancel() {
  if (!confirm('Cancel this lab exchange request?')) return
  busy.value = true
  try {
    const { data } = await $api.patch(`/exchange/lab/${routeId.value}/`, { status: 'cancelled' })
    item.value = data
    snack.text = 'Cancelled'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to cancel'
    snack.color = 'error'
    snack.show = true
  } finally {
    busy.value = false
  }
}

function startEditResults() {
  const existing = item.value.results || []
  const tests = item.value.tests || []
  editingRows.value = tests.map((t, i) => {
    const found = existing.find(r => r.test_name === (t.test_name || t.name)) || existing[i] || {}
    return {
      test_name: t.test_name || t.name || `Test ${i + 1}`,
      result_value: found.result_value || '',
      unit: found.unit || '',
      is_abnormal: !!found.is_abnormal,
      comments: found.comments || '',
    }
  })
  editingResults.value = true
}
function cancelEditResults() { editingResults.value = false }

async function submitResults() {
  const valid = editingRows.value.filter(r => (r.result_value || '').toString().trim())
  if (!valid.length) {
    snack.text = 'Enter at least one result'
    snack.color = 'error'
    snack.show = true
    return
  }
  busy.value = true
  try {
    const { data } = await $api.post(`/exchange/lab/${routeId.value}/results/`, { results: valid })
    item.value = data
    editingResults.value = false
    snack.text = 'Results submitted'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to submit results'
    snack.color = 'error'
    snack.show = true
  } finally {
    busy.value = false
  }
}

function initials(name) {
  if (!name) return '?'
  const parts = name.split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function hashColor(seed) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(seed) || 0) % colors.length]
}

function printDoc() {
  if (!item.value) return
  const x = item.value
  const tests = (x.tests || []).map(t =>
    `<tr><td>${t.test_name || t.name || ''}</td><td>${t.code || ''}</td><td>${t.specimen_type || ''}</td><td>${t.instructions || ''}</td></tr>`
  ).join('')
  const results = (x.results || []).map(r =>
    `<tr><td>${r.test_name || ''}</td><td>${r.result_value || ''}</td><td>${r.unit || ''}</td><td>${r.is_abnormal ? 'ABNORMAL' : 'Normal'}</td><td>${r.comments || ''}</td></tr>`
  ).join('')
  const w = window.open('', '_blank')
  if (!w) return
  w.document.write(`
    <html><head><title>LX-${String(x.id).padStart(5,'0')}</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222;font-size:13px}
      h1{margin:0 0 4px;font-size:22px}
      h3{margin:18px 0 6px;font-size:14px}
      .muted{color:#666;font-size:12px}
      table{width:100%;border-collapse:collapse;margin-top:6px}
      th,td{border:1px solid #ddd;padding:6px 8px;text-align:left}
      th{background:#f5f5f5}
      .row{display:flex;justify-content:space-between;margin:8px 0}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;background:#eef;color:#225;font-size:11px;text-transform:uppercase}
    </style></head><body>
    <h1>Lab Exchange Request</h1>
    <div class="muted">LX-${String(x.id).padStart(5,'0')} · ${new Date(x.created_at).toLocaleString()}</div>
    <div class="row"><div><b>Patient:</b> ${x.patient_name || '—'} · ${x.patient_phone || ''}</div>
      <div><span class="badge">${x.priority?.toUpperCase()}</span></div></div>
    <div class="row"><div><b>From:</b> ${x.source_tenant_name || '—'} · Dr. ${x.ordering_doctor_name || '—'}</div>
      <div><b>Lab:</b> ${x.lab_tenant_name || '—'}</div></div>
    <h3>Tests</h3>
    <table><thead><tr><th>Test</th><th>Code</th><th>Specimen</th><th>Instructions</th></tr></thead>
      <tbody>${tests || '<tr><td colspan="4">—</td></tr>'}</tbody></table>
    ${x.clinical_notes ? `<h3>Clinical notes</h3><p>${x.clinical_notes}</p>` : ''}
    ${results ? `<h3>Results</h3><table><thead><tr><th>Test</th><th>Result</th><th>Unit</th><th>Flag</th><th>Comments</th></tr></thead><tbody>${results}</tbody></table>` : ''}
    </body></html>`)
  w.document.close()
  w.print()
}
</script>

<style scoped>
.tests-table th, .results-table th {
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.6);
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.05em;
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
