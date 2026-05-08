<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Billing & Invoices"
      subtitle="Manage patient invoices, payments and outstanding balances."
      eyebrow="REVENUE"
      icon="mdi-cash-register"
      :chips="[{ icon: 'mdi-receipt', label: `${invoices.length} invoices` }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus"
               class="text-none" @click="dialog = true">
          <span class="text-teal-darken-2 font-weight-bold">New invoice</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Outstanding" :value="format(totals.outstanding)" suffix="KSh" icon="mdi-clock-alert" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Paid this month" :value="format(totals.paid)" suffix="KSh" icon="mdi-check-circle" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Overdue" :value="totals.overdue" icon="mdi-alert" color="#ef4444" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Total invoices" :value="invoices.length" icon="mdi-receipt-text" color="#0d9488" /></v-col>
    </v-row>

    <HomecarePanel title="Invoices" subtitle="All patient invoices" icon="mdi-receipt"
                   color="#0284c7" class="mt-3">
      <template #actions>
        <v-btn-toggle v-model="filterStatus" density="compact" rounded="lg" color="teal" variant="outlined">
          <v-btn value="all" size="small" class="text-none">All</v-btn>
          <v-btn value="draft" size="small" class="text-none">Draft</v-btn>
          <v-btn value="sent" size="small" class="text-none">Sent</v-btn>
          <v-btn value="paid" size="small" class="text-none">Paid</v-btn>
          <v-btn value="overdue" size="small" class="text-none">Overdue</v-btn>
        </v-btn-toggle>
      </template>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id">
        <template #[`item.amount`]="{ item }">KSh {{ format(item.amount) }}</template>
        <template #[`item.balance`]="{ item }">KSh {{ format(item.balance ?? item.amount) }}</template>
        <template #[`item.status`]="{ item }"><StatusChip :status="item.status" /></template>
        <template #[`item.actions`]="{ item }">
          <v-btn v-if="item.status !== 'paid'" size="small" variant="text" color="success"
                 prepend-icon="mdi-cash" @click="pay(item)">Pay</v-btn>
          <v-btn size="small" variant="text" icon="mdi-printer" @click="print(item)" />
        </template>
      </v-data-table>
    </HomecarePanel>

    <v-dialog v-model="dialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title>New invoice</v-card-title>
        <v-card-text>
          <v-select v-model="form.patient" :items="patients" item-title="patient_name" item-value="id" label="Patient" />
          <v-text-field v-model="form.title" label="Description" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model.number="form.amount" label="Amount (KSh)" type="number" /></v-col>
            <v-col cols="6"><v-text-field v-model="form.due_date" label="Due date" type="date" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="save">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const invoices = ref([])
const patients = ref([])
const filterStatus = ref('all')
const loading = ref(false)
const dialog = ref(false)
const saving = ref(false)
const form = reactive({ patient: null, title: '', amount: 0, due_date: '' })

const headers = [
  { title: 'Invoice #', key: 'invoice_number' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Description', key: 'title' },
  { title: 'Amount', key: 'amount' },
  { title: 'Balance', key: 'balance' },
  { title: 'Due', key: 'due_date' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
const filtered = computed(() => filterStatus.value === 'all'
  ? invoices.value
  : invoices.value.filter(i => i.status === filterStatus.value))
const totals = computed(() => {
  const t = { outstanding: 0, paid: 0, overdue: 0 }
  const now = new Date()
  for (const i of invoices.value) {
    const bal = Number(i.balance ?? (i.status !== 'paid' ? i.amount : 0)) || 0
    if (i.status === 'paid') t.paid += Number(i.amount) || 0
    else t.outstanding += bal
    if (i.due_date && new Date(i.due_date) < now && i.status !== 'paid') t.overdue += 1
  }
  return t
})
function format(n) { return Number(n || 0).toLocaleString() }
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/invoices/')
    invoices.value = data?.results || data || []
  } catch { invoices.value = [] }
  finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}
async function save() {
  saving.value = true
  try { await $api.post('/homecare/invoices/', form); dialog.value = false; load() }
  catch (e) { console.warn('invoices endpoint missing', e) }
  finally { saving.value = false }
}
async function pay(item) {
  try { await $api.post(`/homecare/invoices/${item.id}/pay/`); load() } catch { /* */ }
}
function print(item) { window.print() }
onMounted(() => { load(); loadPatients() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
</style>
