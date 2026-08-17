<template>
  <v-container fluid class="pa-4 pa-md-6">
    <template v-if="order">
      <!-- Header -->
      <div class="d-flex align-center flex-wrap ga-3 mb-5">
        <v-btn icon="mdi-arrow-left" variant="text" to="/clinics/lab-orders" />
        <v-avatar color="teal-lighten-5" size="48">
          <v-icon color="teal-darken-2" size="26">mdi-microscope</v-icon>
        </v-avatar>
        <div class="flex-grow-1">
          <div class="d-flex align-center ga-2 flex-wrap">
            <span class="text-h5 font-weight-bold">Order #{{ order.id }}</span>
            <StatusChip :status="order.status" />
            <v-chip size="small" :variant="order.priority === 'stat' ? 'flat' : 'tonal'"
                    :color="priorityColor(order.priority)">
              <v-icon v-if="order.priority === 'stat'" size="14" start class="blink">mdi-alert</v-icon>
              {{ priorityLabel(order.priority) }}
            </v-chip>
            <v-chip v-if="order.is_home_collection" size="small" variant="tonal" color="purple" prepend-icon="mdi-home-clock">Home Collection</v-chip>
          </div>
          <div class="text-body-2 text-medium-emphasis">{{ order.patient_name }} · {{ order.test_names?.length || 0 }} test(s) · ordered {{ fmtDateTime(order.created_at) }}</div>
        </div>
        <v-spacer class="d-none d-md-flex" />
        <div class="d-flex ga-2 flex-wrap">
          <v-btn v-if="canEdit" variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
                 :to="`/clinics/lab-orders/${orderId}/edit`">Edit</v-btn>
          <v-menu v-if="nextStatuses.length">
            <template #activator="{ props }">
              <v-btn v-bind="props" color="primary" rounded="lg" class="text-none" append-icon="mdi-chevron-down">Update Status</v-btn>
            </template>
            <v-list density="compact" rounded="lg">
              <v-list-item v-for="s in nextStatuses" :key="s.value" @click="updateStatus(s.value)">
                <template #prepend><v-icon :color="s.color" size="18">{{ s.icon }}</v-icon></template>
                <v-list-item-title>{{ s.title }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </div>
      </div>

      <!-- Status timeline -->
      <v-card flat rounded="xl" class="pa-4 mb-5 timeline-card">
        <div class="d-flex align-center justify-space-between flex-wrap ga-2">
          <template v-for="(st, i) in statusFlow" :key="st.value">
            <div class="d-flex align-center ga-2">
              <v-avatar :color="statusProgress(st.value)" size="32">
                <v-icon size="16" :color="statusProgress(st.value) === 'grey-lighten-2' ? 'grey' : 'white'">{{ st.icon }}</v-icon>
              </v-avatar>
              <span class="text-caption font-weight-medium" :class="statusProgress(st.value) !== 'grey-lighten-2' ? '' : 'text-medium-emphasis'">{{ st.title }}</span>
            </div>
            <v-icon v-if="i < statusFlow.length - 1" size="16" color="grey-lighten-1" class="d-none d-sm-flex">mdi-chevron-right</v-icon>
          </template>
        </div>
      </v-card>

      <v-row>
        <!-- Main content -->
        <v-col cols="12" md="8">
          <!-- Order details card -->
          <v-card flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center mb-4">
              <v-icon color="primary" class="mr-2">mdi-information</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Order Details</div>
            </div>
            <v-row dense>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Patient</div>
                <div class="text-body-2 font-weight-medium">{{ order.patient_name }}</div>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Ordered By</div>
                <div class="text-body-2 font-weight-medium">{{ order.ordered_by_name || '—' }}</div>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Priority</div>
                <v-chip size="small" :variant="order.priority === 'stat' ? 'flat' : 'tonal'" :color="priorityColor(order.priority)">{{ priorityLabel(order.priority) }}</v-chip>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Created</div>
                <div class="text-body-2 font-weight-medium">{{ fmtDateTime(order.created_at) }}</div>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Updated</div>
                <div class="text-body-2 font-weight-medium">{{ fmtDateTime(order.updated_at) }}</div>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Collection</div>
                <v-chip v-if="order.is_home_collection" size="small" variant="tonal" color="purple" prepend-icon="mdi-home-clock">Home</v-chip>
                <span v-else class="text-body-2 font-weight-medium">In-house</span>
              </v-col>
              <v-col v-if="order.clinical_notes" cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Clinical Notes</div>
                <div class="text-body-2" style="white-space: pre-wrap">{{ order.clinical_notes }}</div>
              </v-col>
            </v-row>
          </v-card>

          <!-- Order Extra (referring info) -->
          <v-card v-if="orderExtra" flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center mb-4">
              <v-icon color="indigo" class="mr-2">mdi-hospital-building</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Referring &amp; Billing</div>
            </div>
            <v-row dense>
              <v-col v-if="orderExtra.referring_doctor_name" cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Referring Doctor</div>
                <div class="text-body-2 font-weight-medium">{{ orderExtra.referring_doctor_name }}</div>
              </v-col>
              <v-col v-if="orderExtra.referring_facility_name" cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Referring Facility</div>
                <div class="text-body-2 font-weight-medium">{{ orderExtra.referring_facility_name }}</div>
              </v-col>
              <v-col v-if="orderExtra.payer_type" cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Payer Type</div>
                <v-chip size="small" variant="tonal">{{ orderExtra.payer_type }}</v-chip>
              </v-col>
              <v-col v-if="orderExtra.accession_number" cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Accession #</div>
                <div class="text-body-2 font-weight-bold font-weight-bold">{{ orderExtra.accession_number }}</div>
              </v-col>
              <v-col v-if="orderExtra.notes_for_lab" cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Notes for Lab</div>
                <div class="text-body-2" style="white-space: pre-wrap">{{ orderExtra.notes_for_lab }}</div>
              </v-col>
            </v-row>
          </v-card>

          <!-- Tests ordered -->
          <v-card flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-4">
              <div class="d-flex align-center">
                <v-icon color="teal" class="mr-2">mdi-test-tube</v-icon>
                <div class="text-subtitle-1 font-weight-bold">Tests Ordered</div>
              </div>
              <v-chip size="small" variant="tonal">{{ orderedTests.length }}</v-chip>
            </div>
            <v-table density="compact" class="rounded-lg">
              <thead>
                <tr><th>Test</th><th>Specimen</th><th>Turnaround</th><th>Result</th><th class="text-end">Price</th></tr>
              </thead>
              <tbody>
                <tr v-for="t in orderedTests" :key="t.id">
                  <td>
                    <div class="font-weight-medium">{{ t.name }}</div>
                    <div v-if="t.department" class="text-caption text-medium-emphasis">{{ t.department }}</div>
                  </td>
                  <td>{{ t.specimen_type || '—' }}</td>
                  <td>{{ t.turnaround_time || '—' }}</td>
                  <td>
                    <v-chip v-if="resultForTest(t.id)" size="x-small" variant="tonal"
                      :color="resultForTest(t.id).is_abnormal ? 'error' : 'success'"
                      prepend-icon="mdi-check">
                      {{ resultForTest(t.id).result_value }} {{ resultForTest(t.id).unit }}
                    </v-chip>
                    <v-chip v-else size="x-small" variant="outlined" color="grey">Pending</v-chip>
                  </td>
                  <td class="text-end">{{ formatMoney(t.price) }}</td>
                </tr>
                <tr class="bg-grey-lighten-5">
                  <td colspan="4" class="font-weight-bold">Total</td>
                  <td class="font-weight-bold text-end">{{ formatMoney(orderedTestTotal) }}</td>
                </tr>
              </tbody>
            </v-table>
          </v-card>

          <!-- Results -->
          <v-card flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-4">
              <div class="d-flex align-center">
                <v-icon color="success" class="mr-2">mdi-clipboard-pulse</v-icon>
                <div class="text-subtitle-1 font-weight-bold">Results</div>
              </div>
              <v-chip size="small" variant="tonal">{{ results.length }}</v-chip>
            </div>
            <div v-if="!results.length" class="text-center pa-6">
              <v-icon size="48" color="grey-lighten-2">mdi-clipboard-pulse-outline</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2 mb-3">No results recorded yet</div>
              <v-btn v-if="canEnterResults" color="success" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openResultDialog">Enter Result</v-btn>
            </div>
            <div v-else>
              <v-table density="compact" class="rounded-lg mb-3">
                <thead><tr><th>Test</th><th>Result</th><th>Flag</th><th>Performed By</th><th>Verified</th><th></th></tr></thead>
                <tbody>
                  <tr v-for="r in results" :key="r.id">
                    <td class="font-weight-medium">{{ r.test_name }}</td>
                    <td>
                      <div class="text-body-2">{{ r.result_value }} <span class="text-medium-emphasis">{{ r.unit }}</span></div>
                      <div v-if="r.comments" class="text-caption text-medium-emphasis">{{ r.comments }}</div>
                    </td>
                    <td>
                      <v-chip v-if="r.is_abnormal" size="x-small" color="error" variant="flat" prepend-icon="mdi-alert">Abnormal</v-chip>
                      <v-chip v-else size="x-small" color="success" variant="tonal">Normal</v-chip>
                    </td>
                    <td class="text-body-2">{{ r.performed_by_name || '—' }}</td>
                    <td>
                      <v-chip v-if="r.verified_by" size="x-small" color="success" variant="tonal" prepend-icon="mdi-check-decagram">Verified</v-chip>
                      <v-chip v-else size="x-small" color="warning" variant="tonal" prepend-icon="mdi-clock">Pending</v-chip>
                    </td>
                    <td class="text-end">
                      <v-btn v-if="!r.verified_by" icon="mdi-check-decagram" size="x-small" variant="text" color="success" @click="verifyResult(r.id)" />
                    </td>
                  </tr>
                </tbody>
              </v-table>
              <v-btn v-if="canEnterResults" color="success" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openResultDialog">Add Result</v-btn>
            </div>
          </v-card>
        </v-col>

        <!-- Sidebar -->
        <v-col cols="12" md="4">
          <!-- Specimens -->
          <v-card flat rounded="xl" class="pa-4 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <v-icon color="blue" class="mr-2" size="20">mdi-test-tube-empty</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Specimens</div>
              </div>
              <v-chip size="x-small" variant="tonal">{{ specimens.length }}</v-chip>
            </div>
            <div v-if="!specimens.length" class="text-center pa-4">
              <v-icon size="32" color="grey-lighten-2">mdi-test-tube-empty</v-icon>
              <div class="text-caption text-medium-emphasis mt-1">No specimens recorded</div>
            </div>
            <div v-for="s in specimens" :key="s.id" class="sidebar-item pa-3 rounded-lg mb-2">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="text-body-2 font-weight-medium font-weight-bold">{{ s.accession_number }}</span>
                <StatusChip :status="s.status" />
              </div>
              <div class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-droplet</v-icon>{{ s.specimen_type }} · {{ s.container_type }}
              </div>
              <div v-if="s.collected_at" class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-clock-outline</v-icon>Collected {{ fmtDateTime(s.collected_at) }}
              </div>
              <div v-if="s.rejection_reason" class="mt-1">
                <v-alert type="error" variant="tonal" density="compact" rounded="lg" class="text-caption">Rejected: {{ s.rejection_reason }}</v-alert>
              </div>
            </div>
          </v-card>

          <!-- Home visits -->
          <v-card v-if="homeVisits.length" flat rounded="xl" class="pa-4 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <v-icon color="purple" class="mr-2" size="20">mdi-home-clock</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Home Visits</div>
              </div>
              <v-chip size="x-small" variant="tonal">{{ homeVisits.length }}</v-chip>
            </div>
            <div v-for="v in homeVisits" :key="v.id" class="sidebar-item pa-3 rounded-lg mb-2">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="text-body-2 font-weight-medium">{{ fmtDate(v.scheduled_date) }} · {{ v.scheduled_time }}</span>
                <StatusChip :status="v.status" />
              </div>
              <div class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-account</v-icon>{{ v.assigned_lab_tech_name || 'Unassigned' }}
              </div>
              <div class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-map-marker</v-icon>{{ v.patient_address }}
              </div>
            </div>
          </v-card>

          <!-- Invoice summary -->
          <v-card v-if="invoice" flat rounded="xl" class="pa-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <v-icon color="green" class="mr-2" size="20">mdi-receipt</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Invoice</div>
              </div>
              <StatusChip :status="invoice.status" />
            </div>
            <div class="text-body-2 mb-1 font-weight-bold">{{ invoice.invoice_number }}</div>
            <div class="d-flex justify-space-between text-caption mb-1"><span>Subtotal</span><span>{{ fmtMoney(invoice.subtotal) }}</span></div>
            <div v-if="invoice.discount > 0" class="d-flex justify-space-between text-caption mb-1"><span>Discount</span><span class="text-error">-{{ fmtMoney(invoice.discount) }}</span></div>
            <div v-if="invoice.tax > 0" class="d-flex justify-space-between text-caption mb-1"><span>Tax</span><span>{{ fmtMoney(invoice.tax) }}</span></div>
            <v-divider class="my-2" />
            <div class="d-flex justify-space-between text-body-2 font-weight-bold"><span>Total</span><span>{{ fmtMoney(invoice.total) }}</span></div>
            <div class="d-flex justify-space-between text-caption mt-1"><span>Paid</span><span class="text-success">{{ fmtMoney(invoice.amount_paid) }}</span></div>
            <div class="d-flex justify-space-between text-caption"><span>Balance</span><span :class="invoice.balance > 0 ? 'text-error' : 'text-success'">{{ fmtMoney(invoice.balance) }}</span></div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <div v-else class="d-flex justify-center pa-10">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <!-- Result Dialog -->
    <v-dialog v-model="resultDialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title class="text-h6">Enter Result</v-card-title>
        <v-card-text>
          <v-form ref="resultFormRef">
            <v-select v-model="resultForm.test" :items="pendingTests" item-title="name" item-value="id"
              label="Test" variant="outlined" density="compact" rounded="lg" class="mb-3" :rules="req" />
            <v-text-field v-model="resultForm.result_value" label="Result Value" required
              variant="outlined" density="compact" rounded="lg" class="mb-3" :rules="req" />
            <v-row dense>
              <v-col cols="6">
                <v-text-field v-model="resultForm.unit" label="Unit"
                  variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="6">
                <v-checkbox v-model="resultForm.is_abnormal" label="Abnormal" color="error" hide-details density="compact" />
              </v-col>
            </v-row>
            <v-textarea v-model="resultForm.comments" label="Comments" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" class="mt-3" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="resultDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="savingResult" @click="saveResult">Save Result</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()
const orderId = route.params.id
const order = ref(null)
const orderExtra = ref(null)
const orderedTests = ref([])
const results = ref([])
const specimens = ref([])
const homeVisits = ref([])
const invoice = ref(null)
const resultDialog = ref(false)
const savingResult = ref(false)
const resultFormRef = ref(null)
const req = [v => (v != null && v !== '') || 'Required']
const resultForm = reactive({ test: null, result_value: '', unit: '', is_abnormal: false, comments: '' })

const canEdit = computed(() => order.value && !['completed', 'cancelled'].includes(order.value.status))
const canEnterResults = computed(() => order.value && ['sample_collected', 'processing'].includes(order.value.status))
const pendingTests = computed(() => orderedTests.value.filter(t => !results.value.some(r => r.test === t.id)))

const statusFlow = [
  { value: 'pending', title: 'Pending', icon: 'mdi-clock-outline' },
  { value: 'sample_collected', title: 'Sample Collected', icon: 'mdi-test-tube' },
  { value: 'processing', title: 'Processing', icon: 'mdi-progress-clock' },
  { value: 'completed', title: 'Completed', icon: 'mdi-check-circle' },
]
const statusOrder = statusFlow.map(s => s.value)

function statusProgress(val) {
  if (!order.value) return 'grey-lighten-2'
  const current = statusOrder.indexOf(order.value.status)
  const target = statusOrder.indexOf(val)
  if (order.value.status === 'cancelled') return val === 'cancelled' ? 'error' : 'grey-lighten-2'
  if (target < current) return 'success'
  if (target === current) return 'primary'
  return 'grey-lighten-2'
}

const nextStatuses = computed(() => {
  const map = {
    pending: [
      { title: 'Mark Sample Collected', value: 'sample_collected', icon: 'mdi-test-tube', color: 'blue' },
      { title: 'Cancel', value: 'cancelled', icon: 'mdi-cancel', color: 'error' },
    ],
    sample_collected: [
      { title: 'Start Processing', value: 'processing', icon: 'mdi-progress-clock', color: 'orange' },
      { title: 'Cancel', value: 'cancelled', icon: 'mdi-cancel', color: 'error' },
    ],
    processing: [
      { title: 'Complete', value: 'completed', icon: 'mdi-check-circle', color: 'success' },
    ],
  }
  return map[order.value?.status] || []
})

const orderedTestTotal = computed(() => orderedTests.value.reduce((s, t) => s + (parseFloat(t.price) || 0), 0))

function priorityLabel(p) { return { routine: 'Routine', urgent: 'Urgent', stat: 'STAT' }[p] || p }
function priorityColor(p) { return p === 'stat' ? 'error' : p === 'urgent' ? 'warning' : 'info' }
function fmtDate(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) }
function fmtDateTime(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) }
function formatMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }
function fmtMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }
function resultForTest(testId) { return results.value.find(r => r.test === testId) }

async function updateStatus(status) {
  if (status === 'cancelled') {
    try { await $api.post(`/lab/orders/${orderId}/cancel/`) }
    catch (e) { console.error(e); return }
  } else {
    try { await $api.patch(`/lab/orders/${orderId}/`, { status }) }
    catch (e) { console.error(e); return }
  }
  order.value.status = status
}

async function verifyResult(resultId) {
  try { await $api.post(`/lab/results/${resultId}/verify/`); await load() }
  catch (e) { console.error(e) }
}

function openResultDialog() {
  resultForm.test = null
  resultForm.result_value = ''
  resultForm.unit = ''
  resultForm.is_abnormal = false
  resultForm.comments = ''
  resultDialog.value = true
}

async function saveResult() {
  const { valid } = await resultFormRef.value.validate()
  if (!valid) return
  savingResult.value = true
  try {
    await $api.post(`/lab/orders/${orderId}/add_result/`, resultForm)
    resultDialog.value = false
    await load()
  } catch (e) { console.error(e) }
  savingResult.value = false
}

async function load() {
  try {
    const [oRes, exRes, rRes, sRes, hvRes, iRes] = await Promise.allSettled([
      $api.get(`/lab/orders/${orderId}/`),
      $api.get(`/lab/order-extras/?lab_order=${orderId}`),
      $api.get(`/lab/results/?order=${orderId}&page_size=500`),
      $api.get(`/lab/specimens/?lab_order=${orderId}&page_size=200`),
      $api.get(`/lab/home-visits/?lab_order=${orderId}`),
      $api.get(`/lab/invoices/?lab_order=${orderId}`),
    ])
    order.value = oRes.status === 'fulfilled' ? oRes.value.data : null
    // Fetch detailed test info from catalog for tests on this order
    if (order.value?.test_names) {
      const testNames = order.value.test_names
      try {
        const { data } = await $api.get('/lab/catalog/?page_size=1000')
        const allTests = data?.results || data || []
        orderedTests.value = allTests.filter(t => testNames.includes(t.name))
      } catch { orderedTests.value = testNames.map((n, i) => ({ id: i, name: n, price: 0, specimen_type: '', turnaround_time: '' })) }
    }
    const extras = exRes.status === 'fulfilled' ? (exRes.value.data?.results || exRes.value.data || []) : []
    orderExtra.value = extras[0] || null
    results.value = rRes.status === 'fulfilled' ? (rRes.value.data?.results || rRes.value.data || []) : []
    specimens.value = sRes.status === 'fulfilled' ? (sRes.value.data?.results || sRes.value.data || []) : []
    homeVisits.value = hvRes.status === 'fulfilled' ? (hvRes.value.data?.results || hvRes.value.data || []) : []
    const invs = iRes.status === 'fulfilled' ? (iRes.value.data?.results || iRes.value.data || []) : []
    invoice.value = invs[0] || null
  } catch { }
}
onMounted(load)
</script>

<style scoped>
.detail-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.timeline-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.sidebar-item { background: rgba(var(--v-theme-on-surface), 0.02); border: 1px solid rgba(var(--v-theme-on-surface), 0.05); }
@keyframes blink { 0%,100% { opacity:1 } 50% { opacity:0.3 } }
.blink { animation: blink 1.2s infinite; }
</style>
