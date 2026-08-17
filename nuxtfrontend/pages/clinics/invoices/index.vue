<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Invoices" subtitle="Patient billing and invoices"
      icon="mdi-receipt-text" color="indigo">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="load">Refresh</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="navigateTo(`${ns}/invoices/new`)">New Invoice</v-btn>
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
        <v-col cols="12" md="6">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search by invoice number, patient…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="4">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact" hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" size="48" />
      </div>

      <div v-else-if="!filteredInvoices.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-receipt-text-outline</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No invoices found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ statusFilter ? 'Try adjusting your filters.' : 'Create your first invoice to get started.' }}
        </div>
        <v-btn v-if="!statusFilter" color="primary" rounded="lg" prepend-icon="mdi-plus"
          @click="navigateTo(`${ns}/invoices/new`)">New Invoice</v-btn>
        <v-btn v-else variant="text" rounded="lg" prepend-icon="mdi-filter-remove"
          @click="statusFilter = null">Clear filters</v-btn>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredInvoices"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => goTo(item.id)"
        class="invoices-table">
        <template #item.invoice_number="{ value }">
          <span class="font-monospace font-weight-medium">{{ value || '—' }}</span>
        </template>
        <template #item.patient_name="{ item }">
          {{ patientName(item) || '—' }}
        </template>
        <template #item.invoice_date="{ value }">{{ formatDate(value) }}</template>
        <template #item.due_date="{ value }">{{ formatDate(value) }}</template>
        <template #item.total_amount="{ value }">{{ formatMoney(value) }}</template>
        <template #item.amount_paid="{ value }">{{ formatMoney(value) }}</template>
        <template #item.balance="{ item }">
          {{ formatMoney((Number(item.total_amount) || 0) - (Number(item.amount_paid) || 0)) }}
        </template>
        <template #item.status="{ value }">
          <v-chip size="small" variant="tonal" :color="statusColor(value)"
            class="text-capitalize font-weight-medium">{{ value || 'unpaid' }}</v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
              @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
              @click="goToEdit(item.id)" />
          </div>
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'

const ns = '/clinics'

const r = useResource('/invoices/')
function load() { r.list({ page_size: 1000 }) }
onMounted(load)

const statusFilter = ref(null)
const statusOptions = [
  { title: 'Unpaid', value: 'unpaid' },
  { title: 'Partial', value: 'partial' },
  { title: 'Paid', value: 'paid' },
  { title: 'Cancelled', value: 'cancelled' },
  { title: 'Overdue', value: 'overdue' },
]

const headers = [
  { title: 'Invoice #', key: 'invoice_number', width: 140 },
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Date', key: 'invoice_date', width: 130 },
  { title: 'Due Date', key: 'due_date', width: 130 },
  { title: 'Total', key: 'total_amount', width: 130, align: 'end' },
  { title: 'Paid', key: 'amount_paid', width: 130, align: 'end' },
  { title: 'Balance', key: 'balance', sortable: false, width: 130, align: 'end' },
  { title: 'Status', key: 'status', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]

const filteredInvoices = computed(() => {
  let list = r.filtered.value
  if (statusFilter.value) list = list.filter(i => i.status === statusFilter.value)
  return list
})

const kpis = computed(() => {
  const list = r.items.value
  const total = list.reduce((s, i) => s + (Number(i.total_amount) || 0), 0)
  const paid = list.reduce((s, i) => s + (Number(i.amount_paid) || 0), 0)
  const pending = list.filter(i => i.status !== 'paid' && i.status !== 'cancelled').length
  return [
    { label: 'Total Invoices', value: list.length, icon: 'mdi-receipt-text', color: 'indigo' },
    { label: 'Pending Payment', value: pending, icon: 'mdi-clock-alert', color: 'orange' },
    { label: 'Total Amount', value: formatMoney(total), icon: 'mdi-cash', color: 'teal' },
    { label: 'Paid Amount', value: formatMoney(paid), icon: 'mdi-cash-check', color: 'green' },
  ]
})

function statusColor(s) {
  const map = { paid: 'success', partial: 'info', unpaid: 'warning', cancelled: 'grey', overdue: 'error' }
  return map[s] || 'default'
}
function patientName(inv) {
  return inv.patient_name || inv.patient?.user_name || inv.patient?.user?.first_name
    || (inv.patient ? `${inv.patient.user?.first_name || ''} ${inv.patient.user?.last_name || ''}`.trim() : '')
}

function goTo(id) { navigateTo(`${ns}/invoices/${id}`) }
function goToEdit(id) { navigateTo(`${ns}/invoices/${id}/edit`) }
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
