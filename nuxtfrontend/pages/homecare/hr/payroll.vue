<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Payroll & Benefits"
      subtitle="Run payroll cycles, manage deductions, statutory contributions, and employee benefit plans."
      eyebrow="HR · PAYROLL"
      icon="mdi-cash-multiple"
      :chips="[
        { icon: 'mdi-cash-check', label: `${money(currentCycle.gross)} gross` },
        { icon: 'mdi-cash-remove', label: `${money(currentCycle.net)} net` },
        { icon: 'mdi-account-group', label: `${currentCycle.count} employees` },
        { icon: currentCycle.status === 'processed' ? 'mdi-check-circle' : 'mdi-clock-outline', label: cycleStatusLabel },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-play"
               class="text-none" :loading="running" @click="runPayroll">
          <span class="text-teal-darken-2 font-weight-bold">Run payroll</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Gross Payroll" :value="money(currentCycle.gross)" icon="mdi-cash-multiple" color="#0d9488" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Net Payroll" :value="money(currentCycle.net)" icon="mdi-cash-check" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Statutory Deductions" :value="money(currentCycle.deductions)" icon="mdi-cash-remove" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Benefits Cost" :value="money(currentCycle.benefits)" icon="mdi-heart-multiple" color="#8b5cf6" /></v-col>
    </v-row>

    <v-row dense>
      <!-- Payroll cycle controls -->
      <v-col cols="12" lg="8">
        <HomecarePanel title="Payroll Cycle" subtitle="Select a period to view or process" icon="mdi-calendar-sync" color="#0d9488">
          <template #actions>
            <v-btn variant="text" size="small" prepend-icon="mdi-download" @click="exportPayslips">Export</v-btn>
          </template>
          <div class="d-flex flex-wrap align-center ga-2 mb-3">
            <v-btn icon="mdi-chevron-left" variant="text" size="small" @click="shiftMonth(-1)" />
            <v-btn variant="tonal" color="teal" size="small" class="text-none" @click="shiftMonth(0)">This Month</v-btn>
            <v-btn icon="mdi-chevron-right" variant="text" size="small" @click="shiftMonth(1)" />
            <span class="text-h6 font-weight-bold ml-2">{{ monthLabel }}</span>
            <v-spacer />
            <v-chip :color="currentCycle.status === 'processed' ? 'success' : 'warning'" variant="tonal" size="small">
              <v-icon start :icon="currentCycle.status === 'processed' ? 'mdi-check-circle' : 'mdi-clock-outline'" />
              {{ cycleStatusLabel }}
            </v-chip>
          </div>

          <v-data-table :headers="payrollHeaders" :items="payrollItems" :loading="loading" item-value="id" class="hc-table">
            <template #[`item.employee`]="{ item }">
              <div class="d-flex align-center">
                <v-avatar size="28" :color="avatarColor(item.employee_name)" variant="tonal" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(item.employee_name) }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium text-body-2">{{ item.employee_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.department }}</div>
                </div>
              </div>
            </template>
            <template #[`item.gross`]="{ item }">{{ money(item.gross) }}</template>
            <template #[`item.deductions`]="{ item }">
              <span class="text-orange">{{ money(item.deductions) }}</span>
            </template>
            <template #[`item.net`]="{ item }"><span class="font-weight-bold text-teal-darken-2">{{ money(item.net) }}</span></template>
            <template #[`item.status`]="{ item }"><StatusChip :status="item.status" /></template>
            <template #[`item.actions`]="{ item }">
              <v-btn size="small" variant="text" prepend-icon="mdi-file-document" @click="viewPayslip(item)">Payslip</v-btn>
            </template>
          </v-data-table>
        </HomecarePanel>
      </v-col>

      <!-- Benefits -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Benefit Plans" subtitle="Active schemes" icon="mdi-heart-multiple" color="#8b5cf6">
          <template #actions>
            <v-btn variant="text" size="small" prepend-icon="mdi-plus" @click="openBenefitDialog">Add</v-btn>
          </template>
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="b in benefits" :key="b.id" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" :color="benefitColor(b)" variant="tonal">
                  <v-icon :icon="benefitIcon(b)" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">{{ b.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ b.enrolled_count || 0 }} enrolled · {{ money(b.employer_contribution) }}/mo</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" variant="tonal" :color="b.mandatory ? 'error' : 'success'">
                  {{ b.mandatory ? 'Mandatory' : 'Optional' }}
                </v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!benefits.length" icon="mdi-heart-off" title="No benefit plans" dense />
          </v-list>
        </HomecarePanel>

        <HomecarePanel title="Deduction Breakdown" icon="mdi-chart-pie" color="#f59e0b" class="mt-3">
          <div v-for="d in deductionBreakdown" :key="d.label" class="d-flex align-center mb-2">
            <v-icon :icon="d.icon" :color="d.color" size="18" class="mr-2" />
            <span class="text-body-2 flex-grow-1">{{ d.label }}</span>
            <span class="font-weight-bold mr-2">{{ money(d.amount) }}</span>
            <v-progress-linear :model-value="d.pct" :color="d.color" style="max-width:60px;" height="4" rounded />
          </div>
          <EmptyState v-if="!deductionBreakdown.length" icon="mdi-cash-off" title="No deductions" dense />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Payslip dialog -->
    <v-dialog v-model="payslipDialog" max-width="600" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-file-document" class="mr-2" />Payslip — {{ payslipItem?.employee_name }}
        </v-card-title>
        <v-divider />
        <v-card-text v-if="payslipItem" style="max-height:70vh">
          <div class="text-center mb-3">
            <div class="text-overline text-medium-emphasis">{{ monthLabel }}</div>
          </div>
          <v-table density="compact">
            <tbody>
              <tr><td class="text-medium-emphasis">Basic salary</td><td class="text-right font-weight-medium">{{ money(payslipItem.basic_salary) }}</td></tr>
              <tr v-if="payslipItem.allowances"><td class="text-medium-emphasis">Allowances</td><td class="text-right">{{ money(payslipItem.allowances) }}</td></tr>
              <tr v-if="payslipItem.overtime_pay"><td class="text-medium-emphasis">Overtime</td><td class="text-right">{{ money(payslipItem.overtime_pay) }}</td></tr>
              <tr><td class="font-weight-bold">Gross pay</td><td class="text-right font-weight-bold">{{ money(payslipItem.gross) }}</td></tr>
              <tr v-for="d in (payslipItem.deduction_items || [])" :key="d.label">
                <td class="text-medium-emphasis pl-6">— {{ d.label }}</td><td class="text-right text-orange">-{{ money(d.amount) }}</td>
              </tr>
              <tr><td class="font-weight-bold">Total deductions</td><td class="text-right font-weight-bold text-orange">-{{ money(payslipItem.deductions) }}</td></tr>
              <tr v-if="payslipItem.benefits_cost"><td class="text-medium-emphasis">Benefits (employer)</td><td class="text-right">{{ money(payslipItem.benefits_cost) }}</td></tr>
              <tr><td class="font-weight-bold text-teal-darken-2">Net pay</td><td class="text-right font-weight-bold text-teal-darken-2 text-h6">{{ money(payslipItem.net) }}</td></tr>
            </tbody>
          </v-table>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-btn variant="text" prepend-icon="mdi-download" @click="downloadPayslip">Download</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="payslipDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Benefit dialog -->
    <v-dialog v-model="benefitDialog" max-width="520" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-heart-plus" class="mr-2" />Benefit Plan</v-card-title>
        <v-divider />
        <v-card-text style="max-height:70vh">
          <v-text-field v-model="benefitForm.name" label="Plan name *" density="comfortable" variant="outlined" />
          <v-select v-model="benefitForm.type" :items="benefitTypes" item-title="label" item-value="value"
                    label="Type" density="comfortable" variant="outlined" />
          <v-textarea v-model="benefitForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model.number="benefitForm.employer_contribution" label="Employer /mo" type="number" prefix="KSh" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="benefitForm.employee_contribution" label="Employee /mo" type="number" prefix="KSh" density="comfortable" variant="outlined" /></v-col>
          </v-row>
          <v-switch v-model="benefitForm.mandatory" color="teal" label="Mandatory for all staff" density="compact" hide-details />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="benefitDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveBenefit">Save</v-btn>
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
const running = ref(false)
const monthOffset = ref(0)
const payrollItems = ref([])
const benefits = ref([])
const payslipDialog = ref(false)
const payslipItem = ref(null)
const benefitDialog = ref(false)

const blankBenefit = () => ({ name: '', type: 'health', description: '', employer_contribution: null, employee_contribution: null, mandatory: false })
const benefitForm = reactive(blankBenefit())

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const benefitTypes = [
  { value: 'health', label: 'Health Insurance' },
  { value: 'pension', label: 'Pension / Retirement' },
  { value: 'life', label: 'Life Insurance' },
  { value: 'dental', label: 'Dental' },
  { value: 'transport', label: 'Transport Allowance' },
  { value: 'meal', label: 'Meal Allowance' },
  { value: 'housing', label: 'Housing' },
  { value: 'wellness', label: 'Wellness Program' },
]

const payrollHeaders = [
  { title: 'Employee', key: 'employee' },
  { title: 'Gross', key: 'gross', align: 'end' },
  { title: 'Deductions', key: 'deductions', align: 'end' },
  { title: 'Net', key: 'net', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false },
]

const currentCycle = computed(() => {
  const gross = payrollItems.value.reduce((s, i) => s + (i.gross || 0), 0)
  const net = payrollItems.value.reduce((s, i) => s + (i.net || 0), 0)
  const deductions = payrollItems.value.reduce((s, i) => s + (i.deductions || 0), 0)
  const benefitsCost = benefits.value.reduce((s, b) => s + (b.employer_contribution || 0) * (b.enrolled_count || 0), 0)
  const status = payrollItems.value.length && payrollItems.value.every(i => i.status === 'paid') ? 'processed' : 'draft'
  return { gross, net, deductions, benefits: benefitsCost, count: payrollItems.value.length, status }
})
const cycleStatusLabel = computed(() => currentCycle.value.status === 'processed' ? 'Processed' : 'Draft')
const monthLabel = computed(() => {
  const d = new Date()
  d.setMonth(d.getMonth() + monthOffset.value)
  return d.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
})
const deductionBreakdown = computed(() => {
  const totals = {}
  payrollItems.value.forEach(i => {
    (i.deduction_items || []).forEach(d => {
      totals[d.label] = (totals[d.label] || 0) + (d.amount || 0)
    })
  })
  const total = Object.values(totals).reduce((a, b) => a + b, 0) || 1
  const iconMap = { NSSF: 'mdi-shield-account', NHIF: 'mdi-hospital-box', PAYE: 'mdi-cash-register', Insurance: 'mdi-shield', Loan: 'mdi-bank' }
  const colorMap = { NSSF: 'blue', NHIF: 'red', PAYE: 'amber', Insurance: 'purple', Loan: 'orange' }
  return Object.entries(totals).map(([label, amount]) => ({
    label, amount, pct: Math.round(amount / total * 100),
    icon: iconMap[label] || 'mdi-cash-minus', color: colorMap[label] || 'teal',
  }))
})

function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}
function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function benefitColor(b) {
  const map = { health: 'red', pension: 'blue', life: 'purple', dental: 'teal', transport: 'orange', meal: 'amber', housing: 'indigo', wellness: 'green' }
  return map[b?.type] || 'teal'
}
function benefitIcon(b) {
  const map = { health: 'mdi-hospital-box', pension: 'mdi-bank', life: 'mdi-shield-account', dental: 'mdi-tooth', transport: 'mdi-bus', meal: 'mdi-food', housing: 'mdi-home', wellness: 'mdi-heart-pulse' }
  return map[b?.type] || 'mdi-heart'
}

function shiftMonth(n) {
  if (n === 0) monthOffset.value = 0
  else monthOffset.value += n
  load()
}

async function load() {
  loading.value = true
  try {
    const d = new Date()
    d.setMonth(d.getMonth() + monthOffset.value)
    const period = d.toISOString().slice(0, 7)
    const [pr, ben] = await Promise.all([
      $api.get('/homecare/hr/payroll/', { params: { period, page_size: 500 } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/benefits/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
    ])
    payrollItems.value = pr.data?.results || pr.data || []
    benefits.value = ben.data?.results || ben.data || []
  } catch (e) {
    console.warn('load payroll failed', e)
  } finally { loading.value = false }
}

async function runPayroll() {
  if (currentCycle.value.status === 'processed') { notify('Payroll already processed.', 'info'); return }
  running.value = true
  try {
    const d = new Date()
    d.setMonth(d.getMonth() + monthOffset.value)
    const period = d.toISOString().slice(0, 7)
    await $api.post('/homecare/hr/payroll/run/', { period })
    notify('Payroll run complete.')
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to run payroll.', 'error')
  } finally { running.value = false }
}

function viewPayslip(item) {
  payslipItem.value = item
  payslipDialog.value = true
}
function downloadPayslip() {
  const item = payslipItem.value
  if (!item) return
  const lines = [
    `Payslip — ${item.employee_name}`,
    `Period: ${monthLabel.value}`,
    '',
    `Basic salary: ${money(item.basic_salary)}`,
    `Gross pay: ${money(item.gross)}`,
    `Deductions: ${money(item.deductions)}`,
    `Net pay: ${money(item.net)}`,
  ]
  const blob = new Blob([lines.join('\n')], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `payslip_${item.employee_name}.txt`; a.click()
  URL.revokeObjectURL(url)
}

function openBenefitDialog() {
  Object.assign(benefitForm, blankBenefit())
  benefitDialog.value = true
}
async function saveBenefit() {
  if (!benefitForm.name) { notify('Name required.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...benefitForm }
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    await $api.post('/homecare/hr/benefits/', payload)
    notify('Benefit plan saved.')
    benefitDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save.', 'error')
  } finally { saving.value = false }
}

function exportPayslips() {
  const rows = payrollItems.value.map(i => ({
    Employee: i.employee_name, Department: i.department,
    Gross: i.gross, Deductions: i.deductions, Net: i.net, Status: i.status,
  }))
  if (!rows.length) { notify('No data to export.', 'info'); return }
  const csv = [Object.keys(rows[0]).join(','), ...rows.map(r => Object.values(r).join(','))].join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `payroll_${monthLabel.value}.csv`; a.click()
  URL.revokeObjectURL(url)
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
