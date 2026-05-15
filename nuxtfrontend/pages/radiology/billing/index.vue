<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">Invoices</h1>
      <div class="d-flex" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/radiology/billing/new">New Invoice</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="kpi in kpis" :key="kpi.label" cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" :color="kpi.color" variant="tonal" border>
          <div class="text-h6 font-weight-bold">{{ kpi.value }}</div>
          <div class="text-caption">{{ kpi.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg" class="pa-3 mb-4" border>
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" label="Search..." density="compact" hide-details clearable variant="outlined" rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterStatus" :items="statusOpts" label="Status" density="compact" hide-details clearable variant="outlined" rounded="lg" />
        </v-col>
      </v-row>
    </v-card>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.invoice_number="{ item }">
          <nuxt-link :to="`/radiology/billing/${item.id}`" class="font-weight-medium text-primary text-decoration-none">{{ item.invoice_number }}</nuxt-link>
        </template>
        <template #item.total="{ item }">{{ formatMoney(item.total) }}</template>
        <template #item.amount_paid="{ item }">{{ formatMoney(item.amount_paid) }}</template>
        <template #item.balance="{ item }">
          <span :class="item.balance > 0 ? 'text-error' : 'text-success'">{{ formatMoney(item.balance) }}</span>
        </template>
        <template #item.status="{ item }">
          <v-chip size="x-small" :color="invoiceColor(item.status)" variant="tonal">{{ item.status_display }}</v-chip>
        </template>
        <template #item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" size="small" variant="text" :to="`/radiology/billing/${item.id}`" />
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const loading = ref(false)
const invoices = ref([])
const search = ref('')
const filterStatus = ref(null)

const statusOpts = [
  { title: 'Draft', value: 'draft' }, { title: 'Issued', value: 'issued' },
  { title: 'Partial', value: 'partial' }, { title: 'Paid', value: 'paid' }, { title: 'Void', value: 'void' },
]

const kpis = computed(() => {
  const total = invoices.value.reduce((s, i) => s + Number(i.total || 0), 0)
  const paid = invoices.value.reduce((s, i) => s + Number(i.amount_paid || 0), 0)
  const outstanding = total - paid
  const count = invoices.value.length
  return [
    { label: 'Total Invoiced', value: formatMoney(total), color: 'primary' },
    { label: 'Collected', value: formatMoney(paid), color: 'success' },
    { label: 'Outstanding', value: formatMoney(outstanding), color: 'warning' },
    { label: 'Invoices', value: count, color: 'info' },
  ]
})

const headers = [
  { title: 'Invoice #', key: 'invoice_number' }, { title: 'Patient', key: 'patient_name' },
  { title: 'Total', key: 'total', align: 'end' }, { title: 'Paid', key: 'amount_paid', align: 'end' },
  { title: 'Balance', key: 'balance', align: 'end' }, { title: 'Status', key: 'status' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]

const filtered = computed(() => {
  let list = invoices.value
  if (filterStatus.value) list = list.filter(i => i.status === filterStatus.value)
  return list
})

function invoiceColor(s) { return { draft: 'grey', issued: 'info', partial: 'warning', paid: 'success', void: 'error' }[s] || 'grey' }
function formatDate(d) { return d ? new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) : '—' }

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/invoices/?page_size=500&ordering=-created_at')
    invoices.value = res.data?.results || res.data || []
  } catch { invoices.value = [] }
  loading.value = false
}
onMounted(load)
</script>
