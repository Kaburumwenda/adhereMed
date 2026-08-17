<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Accounts" subtitle="Financial accounts and payments"
      icon="mdi-cash-multiple" color="success">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="loading" @click="load">Refresh</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-tray-arrow-down"
          :disabled="!payments.length" @click="exportCsv">Export CSV</v-btn>
      </template>
    </PageHeader>

    <!-- ── KPI stat cards ─────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="44" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline text-medium-emphasis" style="line-height:1.1">
                {{ k.label }}
              </div>
              <div class="text-h5 font-weight-bold" style="line-height:1.2">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="7">
          <v-text-field v-model="searchLocal" prepend-inner-icon="mdi-magnify"
            placeholder="Search by invoice number, patient…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="8" md="3">
          <v-text-field v-model="dateFilter" type="date" label="Date"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="4" md="2" class="d-flex align-center">
          <v-btn-toggle v-model="tab" mandatory density="compact" rounded="lg" color="success">
            <v-btn value="all" size="small">All</v-btn>
            <v-btn value="received" size="small">Received</v-btn>
            <v-btn value="pending" size="small">Pending</v-btn>
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="loading" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="success" size="48" />
      </div>

      <div v-else-if="!filteredPayments.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-cash-off</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No payments found</div>
        <div class="text-body-2 text-medium-emphasis">Try adjusting your filters.</div>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredPayments"
        :items-per-page="20"
        item-value=""
        hover
        class="payments-table">
        <template #item.invoice_number="{ item }">
          <span class="font-monospace font-weight-medium">{{ item.invoice_number || item.invoice?.invoice_number || '—' }}</span>
        </template>
        <template #item.patient_name="{ item }">
          {{ patientName(item) || '—' }}
        </template>
        <template #item.amount="{ value, item }">{{ formatMoney(value || item.amount_paid || 0) }}</template>
        <template #item.method="{ value }">
          <v-chip size="x-small" variant="tonal" :color="methodColor(value)"
            class="text-capitalize">{{ value || 'cash' }}</v-chip>
        </template>
        <template #item.date="{ value }">{{ formatDate(value) }}</template>
        <template #item.status="{ value, item }">
          <v-chip size="small" variant="tonal" :color="statusColor(value || item.invoice?.status)"
            class="text-capitalize">{{ value || item.invoice?.status || 'unpaid' }}</v-chip>
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatDate, formatMoney } from '~/utils/format'

const ns = '/clinics'
const { $api } = useNuxtApp()

const items = ref([])
const loading = ref(false)
const searchLocal = ref('')
const dateFilter = ref('')
const tab = ref('all')

const headers = [
  { title: 'Invoice #', key: 'invoice_number', width: 140 },
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Amount', key: 'amount', width: 130, align: 'end' },
  { title: 'Method', key: 'method', width: 120 },
  { title: 'Date', key: 'date', width: 130 },
  { title: 'Status', key: 'status', width: 120 },
]

const payments = computed(() => items.value)

const filteredPayments = computed(() => {
  let list = items.value
  // Tab filter
  if (tab.value === 'received') {
    list = list.filter(p => (p.status || p.invoice?.status) === 'paid' || p.amount_paid != null)
  } else if (tab.value === 'pending') {
    list = list.filter(p => {
      const st = p.status || p.invoice?.status
      return st !== 'paid' && st !== 'cancelled'
    })
  }
  // Search
  const q = searchLocal.value?.toLowerCase()
  if (q) {
    list = list.filter(p =>
      p.invoice_number?.toLowerCase().includes(q) ||
      patientName(p)?.toLowerCase().includes(q) ||
      JSON.stringify(p).toLowerCase().includes(q)
    )
  }
  // Date filter
  if (dateFilter.value) {
    list = list.filter(p => {
      const d = p.payment_date || p.date || p.invoice_date
      return d?.slice(0, 10) === dateFilter.value
    })
  }
  return list
})

const kpis = computed(() => {
  const list = items.value
  const totalRevenue = list
    .filter(p => p.status === 'paid' || p.invoice?.status === 'paid')
    .reduce((s, p) => s + (Number(p.amount) || Number(p.amount_paid) || 0), 0)
  const outstanding = list.reduce((s, p) => {
    const total = Number(p.total_amount || p.invoice?.total_amount) || 0
    const paid = Number(p.amount_paid) || 0
    return s + Math.max(0, total - paid)
  }, 0)
  const todayStr = new Date().toISOString().slice(0, 10)
  const receivedToday = list.filter(p => {
    const d = p.payment_date || p.date
    return d?.slice(0, 10) === todayStr
  }).reduce((s, p) => s + (Number(p.amount) || Number(p.amount_paid) || 0), 0)
  return [
    { label: 'Total Revenue', value: formatMoney(totalRevenue), icon: 'mdi-chart-line', color: 'success' },
    { label: 'Outstanding', value: formatMoney(outstanding), icon: 'mdi-clock-alert', color: 'error' },
    { label: 'Received Today', value: formatMoney(receivedToday), icon: 'mdi-cash-check', color: 'teal' },
    { label: 'Total Invoices', value: list.length, icon: 'mdi-receipt-text', color: 'indigo' },
  ]
})

function methodColor(m) {
  const map = { cash: 'success', card: 'info', insurance: 'primary', mpesa: 'teal' }
  return map[m] || 'default'
}
function statusColor(s) {
  const map = { paid: 'success', partial: 'info', unpaid: 'warning', cancelled: 'grey', overdue: 'error' }
  return map[s] || 'default'
}
function patientName(p) {
  if (p.patient_name) return p.patient_name
  const pat = p.patient || p.invoice?.patient
  if (!pat) return ''
  return pat.user_name || `${pat.user?.first_name || ''} ${pat.user?.last_name || ''}`.trim() || pat.user_email || pat.patient_number || ''
}

async function load() {
  loading.value = true
  try {
    // Try billing/payments endpoint first, fall back to invoices
    let data
    try {
      const res = await $api.get('/billing/payments/', { params: { page_size: 1000 } })
      data = res.data
    } catch {
      const res = await $api.get('/invoices/', { params: { page_size: 1000 } })
      const invs = Array.isArray(res.data) ? res.data : (res.data.results || [])
      // Flatten invoice payments + treat invoices as payment records
      data = invs.flatMap(inv => {
        const pays = inv.payments?.length ? inv.payments : []
        if (!pays.length) {
          return [{
            id: inv.id,
            invoice_number: inv.invoice_number,
            invoice: inv,
            patient: inv.patient,
            amount: inv.amount_paid || 0,
            total_amount: inv.total_amount,
            amount_paid: inv.amount_paid,
            method: inv.payment_method || 'cash',
            date: inv.invoice_date,
            payment_date: inv.invoice_date,
            status: inv.status,
          }]
        }
        return pays.map(p => ({
          ...p,
          invoice_number: inv.invoice_number,
          invoice: inv,
          patient: inv.patient,
          status: inv.status,
        }))
      })
    }
    items.value = Array.isArray(data) ? data : (data?.results || [])
  } catch (e) {
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)

function exportCsv() {
  const rows = filteredPayments.value
  if (!rows.length) return
  const cols = ['invoice_number', 'patient', 'amount', 'method', 'date', 'status']
  const header = ['Invoice #', 'Patient', 'Amount', 'Method', 'Date', 'Status'].join(',')
  const body = rows.map(p => [
    p.invoice_number || p.invoice?.invoice_number || '',
    `"${(patientName(p) || '').replace(/"/g, '""')}"`,
    p.amount || p.amount_paid || 0,
    p.method || 'cash',
    p.payment_date || p.date || '',
    p.status || p.invoice?.status || '',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `clinic_accounts_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
