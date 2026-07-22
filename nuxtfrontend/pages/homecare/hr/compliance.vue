<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Compliance & Reporting"
      subtitle="Labor law compliance, working hours, overtime limits, certification tracking, and regulatory reporting."
      eyebrow="HR · COMPLIANCE"
      icon="mdi-gavel"
      :chips="[
        { icon: 'mdi-shield-check', label: `${complianceScore}% compliant` },
        { icon: 'mdi-alert-circle', label: `${violations.length} violations` },
        { icon: 'mdi-certificate', label: `${expiringCerts} certs expiring` },
        { icon: 'mdi-file-chart', label: `${reports.length} reports` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-file-document-plus"
               class="text-none" @click="openReportDialog">
          <span class="text-teal-darken-2 font-weight-bold">Generate report</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Compliance Score" :value="`${complianceScore}%`" icon="mdi-shield-check" color="#10b981"
                         :trend="complianceTrend" trendLabel="vs last quarter" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Labor Violations" :value="violations.length" icon="mdi-alert-circle" color="#ef4444"
                         :hint="`${overTimeViolations} overtime · ${hoursViolations} hours`" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Expiring Certs" :value="expiringCerts" icon="mdi-certificate" color="#f59e0b"
                         hint="within 60 days" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Avg Weekly Hours" :value="avgWeeklyHours" suffix="hrs" icon="mdi-clock-outline" color="#0ea5e9"
                         hint="limit: 48h/week" />
      </v-col>
    </v-row>

    <v-row dense>
      <!-- Working hours compliance -->
      <v-col cols="12" lg="7">
        <HomecarePanel title="Working Hours & Overtime Compliance" subtitle="Kenya Employment Act — max 48h/week, OT 1.5x" icon="mdi-clock-alert" color="#ef4444">
          <v-data-table :headers="hoursHeaders" :items="hoursCompliance" :loading="loading" item-value="id" class="hc-table">
            <template #[`item.name`]="{ item }">
              <div class="d-flex align-center">
                <v-avatar size="28" :color="avatarColor(item.name)" variant="tonal" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
                </v-avatar>
                <div class="font-weight-medium text-body-2">{{ item.name }}</div>
              </div>
            </template>
            <template #[`item.weekly_hours`]="{ item }">
              <span :class="item.weekly_hours > 48 ? 'text-red font-weight-bold' : ''">{{ item.weekly_hours }}h</span>
            </template>
            <template #[`item.overtime_hours`]="{ item }">
              <span :class="item.overtime_hours > 0 ? 'text-orange font-weight-bold' : ''">{{ item.overtime_hours }}h</span>
            </template>
            <template #[`item.rest_days`]="{ item }">
              <v-chip size="small" variant="tonal" :color="item.rest_days >= 1 ? 'success' : 'error'">
                {{ item.rest_days >= 1 ? `${item.rest_days} day(s)` : 'None' }}
              </v-chip>
            </template>
            <template #[`item.status`]="{ item }">
              <v-chip size="small" variant="tonal" :color="complianceColor(item)">
                <v-icon start :icon="complianceIcon(item)" size="14" />
                {{ complianceLabel(item) }}
              </v-chip>
            </template>
          </v-data-table>
        </HomecarePanel>

        <HomecarePanel title="Compliance Violations" subtitle="Active issues requiring attention" icon="mdi-alert-octagon" color="#f59e0b" class="mt-3">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="v in violations" :key="v.id" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" :color="severityColor(v.severity)" variant="tonal">
                  <v-icon :icon="severityIcon(v.severity)" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">{{ v.title }}</v-list-item-title>
              <v-list-item-subtitle>{{ v.employee_name }} · {{ v.description }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="small" variant="tonal" :color="severityColor(v.severity)">{{ v.severity }}</v-chip>
                <v-btn size="small" variant="text" icon="mdi-check" @click="resolveViolation(v)" />
              </template>
            </v-list-item>
            <EmptyState v-if="!violations.length" icon="mdi-shield-check" title="No violations — all compliant!" dense />
          </v-list>
        </HomecarePanel>
      </v-col>

      <!-- Certifications & reports -->
      <v-col cols="12" lg="5">
        <HomecarePanel title="Certification Tracking" subtitle="Licenses & mandatory certs" icon="mdi-certificate" color="#8b5cf6">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="c in certifications" :key="c.id" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" :color="certColor(c)" variant="tonal">
                  <v-icon :icon="certIcon(c)" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">{{ c.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ c.employee_name }} · expires {{ formatDate(c.expiry_date) }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="small" variant="tonal" :color="certColor(c)">
                  {{ c.days_left < 0 ? `${Math.abs(c.days_left)}d overdue` : `${c.days_left}d left` }}
                </v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!certifications.length" icon="mdi-certificate-outline" title="No certifications tracked" dense />
          </v-list>
        </HomecarePanel>

        <HomecarePanel title="Regulatory Reports" subtitle="Generated compliance reports" icon="mdi-file-chart" color="#0d9488" class="mt-3">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="r in reports" :key="r.id" rounded="lg" class="mb-1"
                         @click="downloadReport(r)">
              <template #prepend>
                <v-avatar size="32" color="teal" variant="tonal">
                  <v-icon :icon="reportIcon(r.type)" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">{{ r.title }}</v-list-item-title>
              <v-list-item-subtitle>{{ r.type_label || r.type }} · {{ formatDate(r.generated_at) }}</v-list-item-subtitle>
              <template #append>
                <v-icon icon="mdi-download" size="16" />
              </template>
            </v-list-item>
            <EmptyState v-if="!reports.length" icon="mdi-file-document-outline" title="No reports generated" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Generate report dialog -->
    <v-dialog v-model="reportDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-file-document-plus" class="mr-2" />Generate Compliance Report</v-card-title>
        <v-divider />
        <v-card-text>
          <v-select v-model="reportForm.type" :items="reportTypes" item-title="label" item-value="value"
                    label="Report type *" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="reportForm.start_date" label="From" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="6"><v-text-field v-model="reportForm.end_date" label="To" type="date" density="comfortable" variant="outlined" /></v-col>
          </v-row>
          <v-textarea v-model="reportForm.notes" label="Notes" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="reportDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="generateReport">Generate</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const hoursCompliance = ref([])
const violations = ref([])
const certifications = ref([])
const reports = ref([])
const reportDialog = ref(false)

const reportForm = reactive({ type: 'labor_hours', start_date: '', end_date: '', notes: '' })

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const reportTypes = [
  { value: 'labor_hours', label: 'Labor Hours & Overtime Report' },
  { value: 'payroll_audit', label: 'Payroll Audit Report' },
  { value: 'leave_compliance', label: 'Leave Entitlement Report' },
  { value: 'certification', label: 'Certification Status Report' },
  { value: 'workplace_safety', label: 'Workplace Safety Report' },
  { value: 'diversity', label: 'Diversity & Inclusion Report' },
  { value: 'turnover', label: 'Employee Turnover Report' },
]

const hoursHeaders = [
  { title: 'Employee', key: 'name' },
  { title: 'Weekly Hrs', key: 'weekly_hours', align: 'end' },
  { title: 'OT Hours', key: 'overtime_hours', align: 'end' },
  { title: 'Rest Days', key: 'rest_days', align: 'center' },
  { title: 'Status', key: 'status' },
]

const complianceScore = computed(() => {
  if (!hoursCompliance.value.length) return 100
  const compliant = hoursCompliance.value.filter(isCompliant).length
  return Math.round(compliant / hoursCompliance.value.length * 100)
})
const overTimeViolations = computed(() => violations.value.filter(v => v.type === 'overtime').length)
const hoursViolations = computed(() => violations.value.filter(v => v.type === 'max_hours').length)
const expiringCerts = computed(() => certifications.value.filter(c => c.days_left >= 0 && c.days_left <= 60).length)
const avgWeeklyHours = computed(() => {
  if (!hoursCompliance.value.length) return 0
  return Math.round(hoursCompliance.value.reduce((s, e) => s + (e.weekly_hours || 0), 0) / hoursCompliance.value.length)
})
const complianceTrend = computed(() => 0)

function isCompliant(item) {
  return item.weekly_hours <= 48 && item.rest_days >= 1
}
function complianceColor(item) { return isCompliant(item) ? 'success' : 'error' }
function complianceIcon(item) { return isCompliant(item) ? 'mdi-check-circle' : 'mdi-alert-circle' }
function complianceLabel(item) { return isCompliant(item) ? 'Compliant' : 'Violation' }
function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function severityColor(s) { return { high: 'error', medium: 'warning', low: 'info' }[s] || 'grey' }
function severityIcon(s) { return { high: 'mdi-alert-octagon', medium: 'mdi-alert', low: 'mdi-information' }[s] || 'mdi-alert' }
function certColor(c) {
  if (c.days_left < 0) return 'error'
  if (c.days_left <= 30) return 'error'
  if (c.days_left <= 60) return 'warning'
  return 'success'
}
function certIcon(c) { return c.days_left < 0 ? 'mdi-certificate-off' : 'mdi-certificate' }
function reportIcon(type) {
  const map = { labor_hours: 'mdi-clock-alert', payroll_audit: 'mdi-cash-check', leave_compliance: 'mdi-calendar-check', certification: 'mdi-certificate', workplace_safety: 'mdi-hard-hat', diversity: 'mdi-account-group', turnover: 'mdi-account-arrow-right' }
  return map[type] || 'mdi-file-chart'
}

async function load() {
  loading.value = true
  try {
    const [hours, viols, certs, reps] = await Promise.all([
      $api.get('/homecare/hr/compliance/working-hours/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/compliance/violations/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/compliance/certifications/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/compliance/reports/').catch(() => ({ data: [] })),
    ])
    hoursCompliance.value = (hours.data?.results || hours.data || []).map(h => ({ ...h, name: h.employee_name || h.name }))
    violations.value = viols.data?.results || viols.data || []
    certifications.value = certs.data?.results || certs.data || []
    reports.value = reps.data?.results || reps.data || []
  } catch (e) {
    console.warn('load compliance failed', e)
  } finally { loading.value = false }
}

function openReportDialog() {
  Object.assign(reportForm, { type: 'labor_hours', start_date: '', end_date: '', notes: '' })
  reportDialog.value = true
}
async function generateReport() {
  saving.value = true
  try {
    await $api.post('/homecare/hr/compliance/reports/', { ...reportForm })
    notify('Report generated.')
    reportDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to generate.', 'error')
  } finally { saving.value = false }
}

async function resolveViolation(v) {
  try {
    await $api.patch(`/homecare/hr/compliance/violations/${v.id}/`, { status: 'resolved' })
    notify('Violation resolved.')
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  }
}

function downloadReport(r) {
  if (r.file_url) { window.open(r.file_url, '_blank'); return }
  notify('Report file not available.', 'info')
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
