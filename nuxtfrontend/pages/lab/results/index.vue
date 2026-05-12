<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="green-lighten-5" size="48">
        <v-icon color="green-darken-2" size="28">mdi-file-chart</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Results &amp; reporting</div>
        <div class="text-body-2 text-medium-emphasis">
          Enter, verify, release and audit lab results
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3" lg="2">
        <v-card flat rounded="lg" class="kpi pa-3">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense class="mt-3">
      <!-- LEFT: order picker / queue -->
      <v-col cols="12" lg="4">
        <v-card flat rounded="lg" class="pa-3 queue-card">
          <div class="d-flex align-center mb-2">
            <div class="text-subtitle-2 font-weight-bold">Result entry queue</div>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" color="primary">{{ filteredOrders.length }}</v-chip>
          </div>
          <v-text-field v-model="orderSearch" prepend-inner-icon="mdi-magnify"
                        placeholder="Search patient or REQ #" variant="outlined"
                        density="compact" hide-details clearable class="mb-2" />
          <v-chip-group v-model="orderStatusFilter" mandatory>
            <v-chip v-for="s in queueStatuses" :key="s.value" :value="s.value"
                    size="small" filter variant="tonal" :color="s.color">
              <v-icon size="14" start>{{ s.icon }}</v-icon>{{ s.label }}
              <span class="ml-1 font-weight-bold">{{ orderStatusCount(s.value) }}</span>
            </v-chip>
          </v-chip-group>
          <v-divider class="my-2" />
          <div v-if="loading" class="d-flex justify-center pa-4">
            <v-progress-circular indeterminate color="primary" size="28" />
          </div>
          <div v-else-if="!filteredOrders.length" class="text-center pa-4 text-medium-emphasis text-caption">
            No orders awaiting results.
          </div>
          <div v-else class="queue-list">
            <v-card v-for="o in filteredOrders" :key="o.id"
                    flat class="queue-item pa-2 mb-1"
                    :class="{ 'is-active': selectedOrderId === o.id }"
                    @click="selectOrder(o.id)">
              <div class="d-flex align-center">
                <v-avatar :color="hashColor(o.patient || o.id)" size="32" class="mr-2">
                  <span class="text-white text-caption font-weight-bold">{{ initials(o.patient_name) }}</span>
                </v-avatar>
                <div class="min-width-0 flex-grow-1">
                  <div class="font-weight-medium text-body-2 text-truncate">{{ o.patient_name || 'Unknown' }}</div>
                  <div class="text-caption text-medium-emphasis font-monospace">REQ-{{ String(o.id).padStart(5, '0') }}</div>
                </div>
                <v-chip size="x-small" variant="flat"
                        :color="priorityColor(o.priority)" class="text-uppercase text-white">
                  {{ o.priority }}
                </v-chip>
              </div>
              <div class="d-flex align-center mt-1 ga-1">
                <v-progress-linear :model-value="resultProgress(o)"
                                   :color="resultProgress(o) === 100 ? 'success' : 'primary'"
                                   height="4" rounded style="flex:1" />
                <span class="text-caption text-medium-emphasis">
                  {{ (o.results || []).length }}/{{ (o.test_names || []).length }}
                </span>
              </div>
            </v-card>
          </div>
        </v-card>
      </v-col>

      <!-- RIGHT: editor -->
      <v-col cols="12" lg="8">
        <v-card v-if="!selectedOrderObj" flat rounded="lg" class="pa-12 text-center editor-empty">
          <v-icon size="64" color="grey-lighten-1">mdi-clipboard-text-search-outline</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">Select an order from the queue</div>
          <div class="text-body-2 text-medium-emphasis">
            Pick a requisition on the left to enter or edit results.
          </div>
        </v-card>

        <v-card v-else flat rounded="lg" class="pa-4 editor-card">
          <!-- Order header -->
          <div class="d-flex align-center flex-wrap ga-3 mb-3">
            <v-avatar :color="hashColor(selectedOrderObj.patient || selectedOrderObj.id)" size="44">
              <span class="text-white font-weight-bold">{{ initials(selectedOrderObj.patient_name) }}</span>
            </v-avatar>
            <div>
              <div class="text-h6 font-weight-bold">{{ selectedOrderObj.patient_name }}</div>
              <div class="text-caption text-medium-emphasis font-monospace">
                REQ-{{ String(selectedOrderObj.id).padStart(5, '0') }} · {{ selectedOrderObj.ordered_by_name }}
              </div>
            </div>
            <v-spacer />
            <v-chip size="small" variant="flat" :color="priorityColor(selectedOrderObj.priority)" class="text-uppercase text-white">
              {{ selectedOrderObj.priority }}
            </v-chip>
            <v-chip size="small" variant="tonal" :color="statusColor(selectedOrderObj.status)" class="text-capitalize">
              <v-icon size="14" start>{{ statusIcon(selectedOrderObj.status) }}</v-icon>{{ statusLabel(selectedOrderObj.status) }}
            </v-chip>
          </div>

          <v-card v-if="selectedOrderObj.clinical_notes" flat class="pa-3 mb-3 notes-card">
            <div class="text-overline text-medium-emphasis">Clinical notes</div>
            <div class="text-body-2">{{ selectedOrderObj.clinical_notes }}</div>
          </v-card>

          <!-- Bulk actions -->
          <div class="d-flex flex-wrap align-center ga-2 mb-2">
            <div class="text-subtitle-2 font-weight-bold">Tests</div>
            <v-chip size="x-small" variant="tonal">{{ resultRows.length }}</v-chip>
            <v-spacer />
            <v-btn size="small" variant="text" prepend-icon="mdi-flag-checkered"
                   @click="markAllNormal">Mark all normal</v-btn>
            <v-btn size="small" variant="text" prepend-icon="mdi-content-copy"
                   @click="copyTemplate">Apply previous</v-btn>
          </div>

          <!-- Test rows -->
          <div class="result-grid">
            <div v-for="row in resultRows" :key="row.test"
                 class="result-row"
                 :class="{ 'is-abnormal': row.is_abnormal, 'is-verified': row.verified }">
              <div class="d-flex align-center mb-2">
                <v-icon size="18" color="indigo" class="mr-2">mdi-flask-outline</v-icon>
                <div class="flex-grow-1">
                  <div class="font-weight-medium">{{ row.test_name }}</div>
                  <div class="text-caption text-medium-emphasis">
                    {{ row.code }}<span v-if="row.specimen_type"> · {{ row.specimen_type }}</span>
                  </div>
                </div>
                <v-chip v-if="row.verified" size="x-small" color="success" variant="tonal">
                  <v-icon size="12" start>mdi-shield-check</v-icon>Verified
                </v-chip>
                <v-chip v-else-if="row.existing_id" size="x-small" color="amber-darken-2" variant="tonal">
                  <v-icon size="12" start>mdi-clock-outline</v-icon>Awaiting verification
                </v-chip>
                <v-chip v-else size="x-small" variant="tonal">
                  Not entered
                </v-chip>
              </div>
              <v-row dense>
                <v-col cols="12" sm="5">
                  <v-text-field v-model="row.result_value" label="Result"
                                variant="outlined" density="compact" hide-details
                                @blur="autoFlag(row)" />
                </v-col>
                <v-col cols="6" sm="2">
                  <v-text-field v-model="row.unit" label="Unit"
                                variant="outlined" density="compact" hide-details />
                </v-col>
                <v-col cols="6" sm="3">
                  <v-text-field :model-value="formatRange(row.reference)" label="Reference"
                                variant="outlined" density="compact" hide-details readonly />
                </v-col>
                <v-col cols="12" sm="2" class="d-flex align-center">
                  <v-switch v-model="row.is_abnormal" color="error" hide-details density="compact"
                            label="Abnormal" inset />
                </v-col>
                <v-col cols="12">
                  <v-textarea v-model="row.comments" label="Comments"
                              variant="outlined" density="compact" hide-details
                              rows="1" auto-grow />
                </v-col>
              </v-row>
            </div>
          </div>

          <!-- Footer actions -->
          <v-divider class="my-4" />
          <div class="d-flex flex-wrap align-center ga-2">
            <v-btn variant="text" prepend-icon="mdi-printer-outline"
                   @click="printReport(selectedOrderObj)">Print report</v-btn>
            <v-btn variant="text" prepend-icon="mdi-history"
                   @click="auditDialog = true" :disabled="!auditLog.length">Audit log</v-btn>
            <v-spacer />
            <v-btn variant="text" @click="selectedOrderId = null">Close</v-btn>
            <v-btn variant="outlined" rounded="lg" color="primary"
                   prepend-icon="mdi-content-save-outline"
                   :loading="saving" @click="saveAll(false)">Save draft</v-btn>
            <v-btn color="primary" rounded="lg"
                   prepend-icon="mdi-shield-check"
                   :loading="saving" @click="saveAll(true)">Save &amp; verify</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- All recent results -->
    <v-card flat rounded="lg" class="mt-4">
      <div class="d-flex align-center pa-3">
        <div class="text-subtitle-2 font-weight-bold">All recent results</div>
        <v-spacer />
        <v-text-field v-model="resultSearch" prepend-inner-icon="mdi-magnify"
                      placeholder="Search results…" variant="outlined" density="compact"
                      hide-details clearable style="max-width:280px" />
        <v-btn-toggle v-model="resultFlagFilter" mandatory density="compact" rounded="lg"
                      color="primary" class="ml-2">
          <v-btn value="all" size="small">All</v-btn>
          <v-btn value="abnormal" size="small">Abnormal</v-btn>
          <v-btn value="normal" size="small">Normal</v-btn>
        </v-btn-toggle>
      </div>
      <v-data-table
        :headers="recentHeaders"
        :items="filteredResults"
        :loading="loadingResults"
        :items-per-page="15"
        density="comfortable"
        item-value="id"
      >
        <template #item.test_name="{ item }">
          <div class="font-weight-medium">{{ item.test_name }}</div>
          <div class="text-caption text-medium-emphasis font-monospace">
            REQ-{{ String(item.order).padStart(5, '0') }}
          </div>
        </template>
        <template #item.result_value="{ item }">
          <span :class="item.is_abnormal ? 'text-error font-weight-bold' : 'font-weight-medium'">
            {{ item.result_value }}<span v-if="item.unit" class="text-caption text-medium-emphasis"> {{ item.unit }}</span>
          </span>
        </template>
        <template #item.is_abnormal="{ value }">
          <v-chip v-if="value" color="error" size="x-small" variant="tonal">
            <v-icon size="12" start>mdi-alert</v-icon>Abnormal
          </v-chip>
          <v-chip v-else color="success" size="x-small" variant="tonal">
            <v-icon size="12" start>mdi-check</v-icon>Normal
          </v-chip>
        </template>
        <template #item.verified_by_name="{ value }">
          <v-chip v-if="value" size="x-small" color="success" variant="tonal">
            <v-icon size="12" start>mdi-shield-check</v-icon>{{ value }}
          </v-chip>
          <v-chip v-else size="x-small" variant="tonal">Pending</v-chip>
        </template>
        <template #item.result_date="{ value }">
          <span class="text-caption">{{ formatDateTime(value) }}</span>
        </template>
      </v-data-table>
    </v-card>

    <!-- Audit log dialog -->
    <v-dialog v-model="auditDialog" max-width="640" scrollable>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center">
          <v-icon class="mr-2">mdi-history</v-icon>Audit log
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <div v-if="!auditLog.length" class="text-center text-medium-emphasis pa-4">
            No audit entries.
          </div>
          <div v-else class="audit-list">
            <div v-for="a in auditLog" :key="a.id" class="audit-item d-flex ga-3 mb-3">
              <v-avatar :color="auditColor(a.action) + '-lighten-5'" size="32">
                <v-icon :color="auditColor(a.action) + '-darken-2'" size="18">mdi-history</v-icon>
              </v-avatar>
              <div class="flex-grow-1">
                <div class="text-body-2 font-weight-medium">{{ auditLabel(a.action) }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ a.user_name || 'System' }} · {{ formatDateTime(a.created_at) }}
                </div>
                <div v-if="a.notes" class="text-caption mt-1">{{ a.notes }}</div>
              </div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="auditDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()

const orders = ref([])
const results = ref([])
const catalog = ref([])
const auditLog = ref([])

const loading = ref(false)
const loadingResults = ref(false)
const saving = ref(false)

const selectedOrderId = ref(null)
const resultRows = ref([])
const orderSearch = ref('')
const orderStatusFilter = ref('all')
const resultSearch = ref('')
const resultFlagFilter = ref('all')
const auditDialog = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const STATUS_META = {
  pending: { label: 'Pending', color: 'amber-darken-2', icon: 'mdi-clock-outline' },
  sample_collected: { label: 'Collected', color: 'cyan-darken-2', icon: 'mdi-tray-arrow-down' },
  processing: { label: 'Processing', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
  completed: { label: 'Completed', color: 'green-darken-2', icon: 'mdi-check' },
  cancelled: { label: 'Cancelled', color: 'grey-darken-1', icon: 'mdi-close-circle-outline' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1' },
  urgent: { color: 'orange-darken-2' },
  stat: { color: 'red-darken-2' },
}
const queueStatuses = [
  { value: 'all', label: 'All', color: 'primary', icon: 'mdi-format-list-bulleted' },
  { value: 'pending', label: 'Pending', color: 'amber-darken-2', icon: 'mdi-clock-outline' },
  { value: 'sample_collected', label: 'Collected', color: 'cyan-darken-2', icon: 'mdi-tray-arrow-down' },
  { value: 'processing', label: 'Processing', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
]

const recentHeaders = [
  { title: 'Test', key: 'test_name' },
  { title: 'Result', key: 'result_value' },
  { title: 'Flag', key: 'is_abnormal', width: 130 },
  { title: 'Performed by', key: 'performed_by_name' },
  { title: 'Verified by', key: 'verified_by_name' },
  { title: 'Date', key: 'result_date', width: 170 },
]

function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }

const filteredOrders = computed(() => {
  let arr = orders.value.filter(o => ['pending', 'sample_collected', 'processing'].includes(o.status))
  if (orderStatusFilter.value !== 'all') {
    arr = arr.filter(o => o.status === orderStatusFilter.value)
  }
  if (orderSearch.value) {
    const q = orderSearch.value.toLowerCase()
    arr = arr.filter(o =>
      (o.patient_name || '').toLowerCase().includes(q)
      || `req-${String(o.id).padStart(5, '0')}`.includes(q)
      || (o.test_names || []).some(t => t.toLowerCase().includes(q))
    )
  }
  // Sort: STAT first, then by created
  return arr.sort((a, b) => {
    const pri = { stat: 0, urgent: 1, routine: 2 }
    const da = pri[a.priority] ?? 9
    const db = pri[b.priority] ?? 9
    if (da !== db) return da - db
    return new Date(b.created_at) - new Date(a.created_at)
  })
})

function orderStatusCount(value) {
  const arr = orders.value.filter(o => ['pending', 'sample_collected', 'processing'].includes(o.status))
  if (value === 'all') return arr.length
  return arr.filter(o => o.status === value).length
}

const selectedOrderObj = computed(() =>
  orders.value.find(o => o.id === selectedOrderId.value)
)

const filteredResults = computed(() => {
  let arr = results.value
  if (resultFlagFilter.value === 'abnormal') arr = arr.filter(r => r.is_abnormal)
  else if (resultFlagFilter.value === 'normal') arr = arr.filter(r => !r.is_abnormal)
  if (resultSearch.value) {
    const q = resultSearch.value.toLowerCase()
    arr = arr.filter(r =>
      (r.test_name || '').toLowerCase().includes(q)
      || (r.result_value || '').toLowerCase().includes(q)
      || (r.performed_by_name || '').toLowerCase().includes(q)
      || `req-${String(r.order).padStart(5, '0')}`.includes(q)
    )
  }
  return arr
})

const kpis = computed(() => {
  const today = new Date().toDateString()
  const sameDay = (iso) => iso && new Date(iso).toDateString() === today
  return [
    { label: 'Awaiting entry', value: orders.value.filter(o => ['pending', 'sample_collected', 'processing'].includes(o.status)
        && (o.results || []).length < (o.test_names || []).length).length,
      icon: 'mdi-clipboard-edit-outline', color: 'amber' },
    { label: 'Pending verify', value: results.value.filter(r => !r.verified_by).length,
      icon: 'mdi-shield-alert-outline', color: 'deep-purple' },
    { label: 'Verified today', value: results.value.filter(r => r.verified_by && sameDay(r.result_date)).length,
      icon: 'mdi-shield-check', color: 'green' },
    { label: 'Abnormal today', value: results.value.filter(r => r.is_abnormal && sameDay(r.result_date)).length,
      icon: 'mdi-alert', color: 'red' },
    { label: 'Released today', value: orders.value.filter(o => o.status === 'completed' && sameDay(o.updated_at)).length,
      icon: 'mdi-send-check-outline', color: 'teal' },
    { label: 'Total results', value: results.value.length,
      icon: 'mdi-file-chart-outline', color: 'indigo' },
  ]
})

function resultProgress(o) {
  const total = (o.test_names || []).length
  const done = (o.results || []).length
  return total ? Math.min(100, Math.round((done / total) * 100)) : 0
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

function formatRange(ref) {
  if (!ref) return ''
  if (typeof ref === 'string') return ref
  if (typeof ref === 'object') {
    if (ref.min != null || ref.max != null) {
      return `${ref.min ?? '—'} - ${ref.max ?? '—'}${ref.unit ? ' ' + ref.unit : ''}`
    }
    if (ref.normal) return ref.normal
    return Object.entries(ref).map(([k, v]) => `${k}: ${v}`).join(', ')
  }
  return String(ref)
}

function autoFlag(row) {
  if (!row.result_value) return
  const num = parseFloat(row.result_value)
  if (isNaN(num)) return
  const ref = row.reference
  if (ref && typeof ref === 'object' && (ref.min != null || ref.max != null)) {
    const min = ref.min != null ? Number(ref.min) : -Infinity
    const max = ref.max != null ? Number(ref.max) : Infinity
    row.is_abnormal = num < min || num > max
  }
}

async function loadAll() {
  loading.value = true
  loadingResults.value = true
  try {
    const [o, r, c] = await Promise.all([
      $api.get('/lab/orders/').then(x => x.data),
      $api.get('/lab/results/').then(x => x.data),
      $api.get('/lab/catalog/').then(x => x.data),
    ])
    orders.value = o.results || o
    results.value = r.results || r
    catalog.value = c.results || c
  } catch (e) {
    snack.text = 'Failed to load data'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
    loadingResults.value = false
  }
}

function selectOrder(id) {
  selectedOrderId.value = id
  router.replace({ query: { ...route.query, order: id } })
}

watch(selectedOrderId, async (id) => {
  resultRows.value = []
  auditLog.value = []
  if (!id) {
    const q = { ...route.query }
    delete q.order
    router.replace({ query: q })
    return
  }
  const o = orders.value.find(x => x.id === id)
  if (!o) return
  resultRows.value = (o.tests || []).map(tid => {
    const t = catalog.value.find(x => x.id === tid) || {}
    const existing = (o.results || []).find(r => r.test === tid)
    return {
      test: tid,
      test_name: t.name || `Test #${tid}`,
      code: t.code || '',
      specimen_type: t.specimen_type || '',
      reference: t.reference_ranges || '',
      result_value: existing?.result_value || '',
      unit: existing?.unit || (t.reference_ranges?.unit ?? ''),
      is_abnormal: existing?.is_abnormal || false,
      comments: existing?.comments || '',
      existing_id: existing?.id || null,
      verified: !!existing?.verified_by,
    }
  })
  // Try to load audit (optional endpoint)
  try {
    const a = await $api.get(`/lab/result-audits/?order=${id}`).then(x => x.data)
    auditLog.value = a.results || a || []
  } catch { auditLog.value = [] }
})

function markAllNormal() {
  resultRows.value.forEach(r => { r.is_abnormal = false })
}

async function copyTemplate() {
  if (!selectedOrderObj.value?.patient) return
  try {
    const data = await $api.get(`/lab/results/?order__patient=${selectedOrderObj.value.patient}`)
      .then(x => x.data)
    const arr = data.results || data
    let applied = 0
    resultRows.value.forEach(row => {
      if (row.result_value) return
      const prev = arr.find(p => p.test === row.test)
      if (prev) {
        row.result_value = prev.result_value
        row.unit = prev.unit || row.unit
        row.is_abnormal = prev.is_abnormal
        applied++
      }
    })
    snack.text = applied ? `Applied ${applied} previous result(s)` : 'No previous results found'
    snack.color = applied ? 'success' : 'info'
    snack.show = true
  } catch (e) {
    snack.text = 'Failed to load previous results'
    snack.color = 'error'
    snack.show = true
  }
}

async function saveAll(verify) {
  if (!selectedOrderObj.value) return
  saving.value = true
  let saved = 0
  try {
    for (const row of resultRows.value) {
      if (!row.result_value) continue
      const payload = {
        order: selectedOrderObj.value.id,
        test: row.test,
        result_value: row.result_value,
        unit: row.unit,
        is_abnormal: row.is_abnormal,
        comments: row.comments,
      }
      if (row.existing_id) {
        await $api.patch(`/lab/results/${row.existing_id}/`, payload)
      } else {
        const created = await $api.post('/lab/results/', payload).then(x => x.data)
        row.existing_id = created.id
      }
      saved++
    }
    if (verify && saved) {
      // Move order to completed (release)
      const o = selectedOrderObj.value
      await $api.patch(`/lab/orders/${o.id}/`, {
        ...o, status: 'completed', test_ids: o.tests || [],
      })
    } else if (saved && selectedOrderObj.value.status === 'pending') {
      const o = selectedOrderObj.value
      await $api.patch(`/lab/orders/${o.id}/`, {
        ...o, status: 'processing', test_ids: o.tests || [],
      })
    }
    snack.text = verify ? `Released ${saved} result(s)` : `Saved ${saved} result(s)`
    snack.color = 'success'
    snack.show = true
    await loadAll()
  } catch (e) {
    snack.text = e?.response?.data?.detail
      || (typeof e?.response?.data === 'object'
          ? Object.values(e.response.data).flat().join(' ')
          : 'Save failed')
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

function auditColor(a) {
  const v = (a || '').toLowerCase()
  if (v.includes('verify')) return 'green'
  if (v.includes('release')) return 'teal'
  if (v.includes('amend') || v.includes('correct')) return 'orange'
  if (v.includes('delete')) return 'red'
  return 'indigo'
}
function auditLabel(a) {
  if (!a) return 'Activity'
  return a.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

function printReport(o) {
  if (!o) return
  const w = window.open('', '_blank', 'width=820,height=900')
  if (!w) return
  const rows = (o.results || []).map(r => `
    <tr>
      <td style="padding:8px;border:1px solid #ccc">${r.test_name}</td>
      <td style="padding:8px;border:1px solid #ccc;${r.is_abnormal ? 'color:#c62828;font-weight:bold' : ''}">
        ${r.result_value || '—'} ${r.unit || ''}
        ${r.is_abnormal ? ' ⚑' : ''}
      </td>
      <td style="padding:8px;border:1px solid #ccc">${r.comments || ''}</td>
    </tr>`).join('')
  w.document.write(`
    <html><head><title>Report REQ-${String(o.id).padStart(5, '0')}</title>
    <style>
      body{font-family:Arial,sans-serif;margin:24px;color:#222}
      h1{margin:0;font-size:22px}
      .sub{color:#666;font-size:12px;margin-bottom:16px}
      table{width:100%;border-collapse:collapse;margin-top:8px}
      th{padding:8px;background:#f5f5f5;border:1px solid #ccc;text-align:left;font-size:12px}
      .meta{display:flex;justify-content:space-between;margin:12px 0;font-size:13px;gap:8px}
      .box{border:1px solid #ccc;padding:8px;border-radius:6px;flex:1}
      .sig{margin-top:32px;display:flex;justify-content:space-between;font-size:12px;color:#444}
      .footer{margin-top:24px;font-size:10px;color:#888;text-align:center}
    </style></head><body>
      <h1>Laboratory Report</h1>
      <div class="sub">REQ-${String(o.id).padStart(5, '0')} · ${o.priority?.toUpperCase()} · Released ${new Date().toLocaleString()}</div>
      <div class="meta">
        <div class="box"><b>Patient:</b> ${o.patient_name || '—'}</div>
        <div class="box"><b>Ordered by:</b> ${o.ordered_by_name || '—'}</div>
        <div class="box"><b>Order date:</b> ${new Date(o.created_at).toLocaleString()}</div>
      </div>
      ${o.clinical_notes ? `<div class="box"><b>Clinical notes:</b> ${o.clinical_notes}</div>` : ''}
      <table>
        <thead><tr><th>Test</th><th>Result</th><th>Comments</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="3" style="padding:16px;text-align:center;color:#888">No results entered</td></tr>'}</tbody>
      </table>
      <div class="sig">
        <div>Performed by: ____________________</div>
        <div>Verified by: ____________________</div>
      </div>
      <div class="footer">Generated by AfyaOne Laboratory Information System</div>
    </body></html>`)
  w.document.close()
  setTimeout(() => w.print(), 200)
}

function exportCsv() {
  const rows = filteredResults.value
  if (!rows.length) return
  const cols = ['req', 'test', 'result', 'unit', 'flag', 'performed_by', 'verified_by', 'date']
  const header = cols.join(',')
  const body = rows.map(r => [
    `REQ-${String(r.order).padStart(5, '0')}`,
    `"${(r.test_name || '').replace(/"/g, '""')}"`,
    `"${(r.result_value || '').replace(/"/g, '""')}"`,
    r.unit || '',
    r.is_abnormal ? 'abnormal' : 'normal',
    `"${(r.performed_by_name || '').replace(/"/g, '""')}"`,
    `"${(r.verified_by_name || '').replace(/"/g, '""')}"`,
    r.result_date || '',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab_results_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  await loadAll()
  const id = route.query.order
  if (id) selectedOrderId.value = Number(id)
})
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.queue-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  height: 100%;
}
.queue-list { max-height: 600px; overflow-y: auto; }
.queue-item {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: all 100ms ease;
}
.queue-item:hover { border-color: rgba(var(--v-theme-primary), 0.4); }
.queue-item.is-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.06);
}
.editor-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.editor-empty {
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.result-grid { display: flex; flex-direction: column; gap: 10px; }
.result-row {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 12px;
  padding: 12px;
  transition: all 120ms ease;
}
.result-row.is-abnormal {
  border-color: rgba(var(--v-theme-error), 0.5);
  background: rgba(var(--v-theme-error), 0.02);
}
.result-row.is-verified {
  border-color: rgba(var(--v-theme-success), 0.5);
  background: rgba(var(--v-theme-success), 0.02);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
