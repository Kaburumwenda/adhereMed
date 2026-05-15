<template>
  <v-container fluid class="pa-4 pa-md-6">
    <template v-if="order">
      <!-- Header -->
      <div class="d-flex align-center flex-wrap ga-3 mb-5">
        <v-btn icon="mdi-arrow-left" variant="text" to="/radiology/orders" />
        <v-avatar color="deep-purple-lighten-5" size="48">
          <v-icon color="deep-purple-darken-2" size="26">mdi-clipboard-text</v-icon>
        </v-avatar>
        <div class="flex-grow-1">
          <div class="d-flex align-center ga-2 flex-wrap">
            <span class="text-h5 font-weight-bold">Order #{{ order.id }}</span>
            <StatusChip :status="order.status" />
            <v-chip size="small" :variant="order.priority === 'stat' ? 'flat' : 'tonal'"
                    :color="priorityColor(order.priority)">
              <v-icon v-if="order.priority === 'stat'" size="14" start class="blink">mdi-alert</v-icon>
              {{ order.priority_display }}
            </v-chip>
          </div>
          <div class="text-body-2 text-medium-emphasis">{{ order.patient_name }} · {{ order.imaging_type_display }} · {{ order.body_part }}</div>
        </div>
        <v-spacer class="d-none d-md-flex" />
        <div class="d-flex ga-2 flex-wrap">
          <v-btn v-if="canEdit" variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
                 :to="`/radiology/orders/${orderId}/edit`">Edit</v-btn>
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
              <v-avatar :color="statusProgress(st.value)" size="32" :variant="statusProgress(st.value) === 'grey-lighten-2' ? 'flat' : 'flat'">
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
              <v-col v-for="f in orderFields" :key="f.label" cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">{{ f.label }}</div>
                <div class="text-body-2 font-weight-medium">{{ f.value }}</div>
              </v-col>
              <v-col v-if="order.exam_names?.length" cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Exams</div>
                <div class="d-flex flex-wrap ga-1">
                  <v-chip v-for="e in order.exam_names" :key="e" size="small" variant="tonal" color="indigo">{{ e }}</v-chip>
                </div>
              </v-col>
              <v-col v-if="order.clinical_indication" cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Clinical Indication</div>
                <div class="text-body-2" style="white-space: pre-wrap">{{ order.clinical_indication }}</div>
              </v-col>
            </v-row>
          </v-card>

          <!-- Order Extra (referring info) -->
          <v-card v-if="orderExtra" flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center mb-4">
              <v-icon color="indigo" class="mr-2">mdi-hospital-building</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Referring &amp; Clinical</div>
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
                <div class="text-body-2 font-weight-medium font-weight-bold">{{ orderExtra.accession_number }}</div>
              </v-col>
              <v-col v-if="orderExtra.pregnancy_status" cols="6" sm="4">
                <div class="text-caption text-medium-emphasis mb-1">Pregnancy Status</div>
                <div class="text-body-2">{{ orderExtra.pregnancy_status }}</div>
              </v-col>
              <v-col v-if="orderExtra.clinical_history" cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Clinical History</div>
                <div class="text-body-2" style="white-space: pre-wrap">{{ orderExtra.clinical_history }}</div>
              </v-col>
              <v-col v-if="orderExtra.allergies_contrast" cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Contrast Allergies</div>
                <v-alert type="warning" variant="tonal" density="compact" rounded="lg" class="mt-1">{{ orderExtra.allergies_contrast }}</v-alert>
              </v-col>
            </v-row>
          </v-card>

          <!-- Report -->
          <v-card flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-4">
              <div class="d-flex align-center">
                <v-icon color="teal" class="mr-2">mdi-file-document</v-icon>
                <div class="text-subtitle-1 font-weight-bold">Report</div>
              </div>
              <v-chip v-if="order.report" size="small" variant="tonal"
                      :color="order.report.report_status === 'final' ? 'success' : order.report.report_status === 'draft' ? 'grey' : 'warning'">
                {{ order.report.report_status_display || order.report.report_status }}
              </v-chip>
            </div>
            <template v-if="order.report">
              <div v-if="order.report.critical_finding" class="mb-3">
                <v-alert type="error" variant="tonal" rounded="lg" density="compact" prepend-icon="mdi-alert-octagon">
                  <strong>Critical Finding</strong> — Immediate action may be required
                </v-alert>
              </div>
              <div v-if="order.report.findings" class="mb-3">
                <div class="text-caption font-weight-bold text-medium-emphasis mb-1">FINDINGS</div>
                <div class="text-body-2 report-text pa-3 rounded-lg" style="white-space: pre-wrap">{{ order.report.findings }}</div>
              </div>
              <div v-if="order.report.impression" class="mb-3">
                <div class="text-caption font-weight-bold text-medium-emphasis mb-1">IMPRESSION</div>
                <div class="text-body-2 report-text pa-3 rounded-lg" style="white-space: pre-wrap">{{ order.report.impression }}</div>
              </div>
              <div v-if="order.report.recommendation" class="mb-3">
                <div class="text-caption font-weight-bold text-medium-emphasis mb-1">RECOMMENDATION</div>
                <div class="text-body-2 report-text pa-3 rounded-lg" style="white-space: pre-wrap">{{ order.report.recommendation }}</div>
              </div>
              <v-divider class="my-3" />
              <div class="d-flex flex-wrap ga-4 text-caption text-medium-emphasis">
                <span><v-icon size="14" class="mr-1">mdi-doctor</v-icon>{{ order.report.radiologist_name || 'Unassigned' }}</span>
                <span v-if="order.report.signed_at"><v-icon size="14" class="mr-1">mdi-pen</v-icon>Signed {{ fmtDate(order.report.signed_at) }}</span>
                <span v-else class="text-warning"><v-icon size="14" class="mr-1" color="warning">mdi-pen-off</v-icon>Unsigned</span>
              </div>
            </template>
            <template v-else>
              <div class="text-center pa-6">
                <v-icon size="48" color="grey-lighten-2">mdi-file-document-plus</v-icon>
                <div class="text-body-2 text-medium-emphasis mt-2 mb-3">No report created yet</div>
                <v-btn color="teal" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="createReport">Create Report</v-btn>
              </div>
            </template>
          </v-card>

          <!-- Result (legacy / image URL) -->
          <v-card v-if="order.result" flat rounded="xl" class="pa-5 mb-4 detail-card">
            <div class="d-flex align-center mb-4">
              <v-icon color="amber-darken-2" class="mr-2">mdi-image-multiple</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Result / Images</div>
            </div>
            <div v-if="order.result.findings" class="mb-2"><div class="text-caption text-medium-emphasis mb-1">Findings</div><div class="text-body-2">{{ order.result.findings }}</div></div>
            <div v-if="order.result.impression" class="mb-2"><div class="text-caption text-medium-emphasis mb-1">Impression</div><div class="text-body-2">{{ order.result.impression }}</div></div>
            <div v-if="order.result.image_url" class="mt-3">
              <v-img :src="order.result.image_url" max-height="300" rounded="lg" class="bg-grey-lighten-4" />
            </div>
          </v-card>
        </v-col>

        <!-- Sidebar -->
        <v-col cols="12" md="4">
          <!-- Schedules -->
          <v-card flat rounded="xl" class="pa-4 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <v-icon color="blue" class="mr-2" size="20">mdi-calendar-clock</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Schedules</div>
              </div>
              <v-chip size="x-small" variant="tonal">{{ schedules.length }}</v-chip>
            </div>
            <div v-if="!schedules.length" class="text-center pa-4">
              <v-icon size="32" color="grey-lighten-2">mdi-calendar-blank</v-icon>
              <div class="text-caption text-medium-emphasis mt-1">No schedules</div>
            </div>
            <div v-for="s in schedules" :key="s.id" class="sidebar-item pa-3 rounded-lg mb-2">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="text-body-2 font-weight-medium">{{ fmtDateTime(s.scheduled_datetime) }}</span>
                <StatusChip :status="s.status" />
              </div>
              <div class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-cog</v-icon>{{ s.modality_name || '—' }} ·
                <v-icon size="12" class="mr-1">mdi-account</v-icon>{{ s.technologist_name || 'Unassigned' }}
              </div>
              <div v-if="s.duration_minutes" class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-clock-outline</v-icon>{{ s.duration_minutes }} min
              </div>
              <div v-if="s.notes" class="text-caption mt-1" style="white-space: pre-wrap">{{ s.notes }}</div>
            </div>
          </v-card>

          <!-- Contrast -->
          <v-card flat rounded="xl" class="pa-4 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <v-icon color="orange" class="mr-2" size="20">mdi-needle</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Contrast</div>
              </div>
              <v-chip size="x-small" variant="tonal">{{ contrast.length }}</v-chip>
            </div>
            <div v-if="!contrast.length" class="text-center pa-4">
              <v-icon size="32" color="grey-lighten-2">mdi-needle</v-icon>
              <div class="text-caption text-medium-emphasis mt-1">No contrast records</div>
            </div>
            <div v-for="c in contrast" :key="c.id" class="sidebar-item pa-3 rounded-lg mb-2">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="text-body-2 font-weight-medium">{{ c.contrast_agent }}</span>
                <v-icon v-if="c.reaction_noted" color="error" size="18" title="Reaction noted">mdi-alert-circle</v-icon>
              </div>
              <div class="text-caption text-medium-emphasis">
                {{ c.dose_ml }}ml · {{ c.route }} · Lot: {{ c.lot_number || '—' }}
              </div>
              <div class="text-caption text-medium-emphasis">
                By: {{ c.administered_by_name || '—' }} · {{ fmtDateTime(c.administered_at) }}
              </div>
              <v-alert v-if="c.reaction_noted && c.reaction_details" type="error" variant="tonal" density="compact" class="mt-2 text-caption" rounded="lg">
                {{ c.reaction_details }}
              </v-alert>
            </div>
          </v-card>

          <!-- Dose records -->
          <v-card flat rounded="xl" class="pa-4 mb-4 detail-card">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <v-icon color="red" class="mr-2" size="20">mdi-radioactive</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Dose Records</div>
              </div>
              <v-chip size="x-small" variant="tonal">{{ doses.length }}</v-chip>
            </div>
            <div v-if="!doses.length" class="text-center pa-4">
              <v-icon size="32" color="grey-lighten-2">mdi-radioactive</v-icon>
              <div class="text-caption text-medium-emphasis mt-1">No dose records</div>
            </div>
            <div v-for="d in doses" :key="d.id" class="sidebar-item pa-3 rounded-lg mb-2">
              <div class="text-body-2 font-weight-medium mb-1">{{ d.modality_name || 'Unknown' }}</div>
              <div class="d-flex flex-wrap ga-2">
                <v-chip v-if="d.ctdi_vol" size="x-small" variant="tonal" color="red">CTDIvol: {{ d.ctdi_vol }}</v-chip>
                <v-chip v-if="d.dlp" size="x-small" variant="tonal" color="orange">DLP: {{ d.dlp }}</v-chip>
                <v-chip v-if="d.effective_dose_msv" size="x-small" variant="tonal" color="deep-orange">{{ d.effective_dose_msv }} mSv</v-chip>
                <v-chip v-if="d.kvp" size="x-small" variant="tonal">{{ d.kvp }} kVp</v-chip>
                <v-chip v-if="d.mas" size="x-small" variant="tonal">{{ d.mas }} mAs</v-chip>
              </div>
              <div v-if="d.notes" class="text-caption text-medium-emphasis mt-1">{{ d.notes }}</div>
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
            <div class="text-body-2 mb-1"><strong>{{ invoice.invoice_number }}</strong></div>
            <div class="d-flex justify-space-between text-caption mb-1"><span>Subtotal</span><span>{{ fmtMoney(invoice.subtotal) }}</span></div>
            <div v-if="invoice.discount > 0" class="d-flex justify-space-between text-caption mb-1"><span>Discount</span><span class="text-error">-{{ fmtMoney(invoice.discount) }}</span></div>
            <div v-if="invoice.tax > 0" class="d-flex justify-space-between text-caption mb-1"><span>Tax</span><span>{{ fmtMoney(invoice.tax) }}</span></div>
            <v-divider class="my-2" />
            <div class="d-flex justify-space-between text-body-2 font-weight-bold"><span>Total</span><span>{{ fmtMoney(invoice.total) }}</span></div>
            <div class="d-flex justify-space-between text-caption mt-1"><span>Paid</span><span class="text-success">{{ fmtMoney(invoice.amount_paid) }}</span></div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <div v-else class="d-flex justify-center pa-10">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()
const orderId = route.params.id
const order = ref(null)
const orderExtra = ref(null)
const schedules = ref([])
const contrast = ref([])
const doses = ref([])
const invoice = ref(null)

const canEdit = computed(() => order.value && !['completed', 'cancelled'].includes(order.value.status))

const statusFlow = [
  { value: 'pending', title: 'Pending', icon: 'mdi-clock-outline' },
  { value: 'scheduled', title: 'Scheduled', icon: 'mdi-calendar-clock' },
  { value: 'checked_in', title: 'Checked In', icon: 'mdi-account-check' },
  { value: 'in_progress', title: 'In Progress', icon: 'mdi-progress-clock' },
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
    pending: [{ title: 'Schedule', value: 'scheduled', icon: 'mdi-calendar-clock', color: 'blue' }, { title: 'Cancel', value: 'cancelled', icon: 'mdi-cancel', color: 'error' }],
    scheduled: [{ title: 'Check In', value: 'checked_in', icon: 'mdi-account-check', color: 'indigo' }, { title: 'Cancel', value: 'cancelled', icon: 'mdi-cancel', color: 'error' }],
    checked_in: [{ title: 'Start Imaging', value: 'in_progress', icon: 'mdi-play', color: 'orange' }],
    in_progress: [{ title: 'Complete', value: 'completed', icon: 'mdi-check-circle', color: 'success' }],
  }
  return map[order.value?.status] || []
})

const orderFields = computed(() => {
  if (!order.value) return []
  return [
    { label: 'Patient', value: order.value.patient_name },
    { label: 'Imaging Type', value: order.value.imaging_type_display },
    { label: 'Body Part', value: order.value.body_part },
    { label: 'Priority', value: order.value.priority_display },
    { label: 'Equipment', value: order.value.modality_name || '—' },
    { label: 'Ordered By', value: order.value.ordered_by_name || '—' },
    { label: 'Created', value: fmtDateTime(order.value.created_at) },
    { label: 'Updated', value: fmtDateTime(order.value.updated_at) },
  ]
})

function priorityColor(p) { return p === 'stat' ? 'error' : p === 'urgent' ? 'warning' : 'info' }
function fmtDate(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) }
function fmtDateTime(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) }
function fmtMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }

async function updateStatus(status) {
  try {
    await $api.patch(`/radiology/orders/${orderId}/`, { status })
    order.value.status = status
  } catch (e) { console.error(e) }
}

async function createReport() {
  try {
    await $api.post('/radiology/reports/', { order: orderId, findings: '', impression: '', report_status: 'draft' })
    await load()
  } catch (e) { console.error(e) }
}

async function load() {
  try {
    const [oRes, exRes, sRes, cRes, dRes, iRes] = await Promise.allSettled([
      $api.get(`/radiology/orders/${orderId}/`),
      $api.get(`/radiology/order-extras/?order=${orderId}`),
      $api.get(`/radiology/schedules/?order=${orderId}`),
      $api.get(`/radiology/contrast/?order=${orderId}`),
      $api.get(`/radiology/dose-records/?order=${orderId}`),
      $api.get(`/radiology/invoices/?order=${orderId}`),
    ])
    order.value = oRes.status === 'fulfilled' ? oRes.value.data : null
    const extras = exRes.status === 'fulfilled' ? (exRes.value.data?.results || exRes.value.data || []) : []
    orderExtra.value = extras[0] || null
    schedules.value = sRes.status === 'fulfilled' ? (sRes.value.data?.results || sRes.value.data || []) : []
    contrast.value = cRes.status === 'fulfilled' ? (cRes.value.data?.results || cRes.value.data || []) : []
    doses.value = dRes.status === 'fulfilled' ? (dRes.value.data?.results || dRes.value.data || []) : []
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
.report-text { background: rgba(var(--v-theme-on-surface), 0.02); border: 1px solid rgba(var(--v-theme-on-surface), 0.04); }
@keyframes blink { 0%,100% { opacity:1 } 50% { opacity:0.3 } }
.blink { animation: blink 1.2s infinite; }
</style>
