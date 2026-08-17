<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- ── Toolbar ──────────────────────────────────────────────── -->
    <PageHeader :title="pageTitle" :subtitle="patientName || ''"
      icon="mdi-receipt-text" color="indigo">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/invoices`)">Back</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
          @click="navigateTo(`${ns}/invoices/${id}/edit`)">Edit</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-printer"
          @click="printInvoice">Print</v-btn>
      </template>
    </PageHeader>

    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <div v-else-if="!invoice" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-receipt-text-outline</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Invoice not found</div>
      <v-btn color="primary" rounded="lg" class="text-none mt-3"
        @click="navigateTo(`${ns}/invoices`)">Back to Invoices</v-btn>
    </div>

    <template v-else>
      <!-- ═══ Info cards ═══════════════════════════════════════════ -->
      <v-row dense class="mb-4">
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="indigo-lighten-5" size="36" class="mr-3">
                <v-icon color="indigo-darken-2" size="20">mdi-account</v-icon>
              </v-avatar>
              <div class="text-h6 font-weight-bold">Patient</div>
            </div>
            <v-list density="compact" class="bg-transparent">
              <v-list-item>
                <template #prepend><v-icon size="18">mdi-account</v-icon></template>
                <v-list-item-title>{{ patientName || '—' }}</v-list-item-title>
                <v-list-item-subtitle v-if="invoice.patient?.patient_number" class="font-monospace">
                  {{ invoice.patient.patient_number }}
                </v-list-item-subtitle>
              </v-list-item>
              <v-list-item v-if="invoice.patient?.user?.phone">
                <template #prepend><v-icon size="18">mdi-phone</v-icon></template>
                <v-list-item-title>{{ invoice.patient.user.phone }}</v-list-item-title>
              </v-list-item>
              <v-list-item v-if="invoice.patient?.user_email || invoice.patient?.user?.email">
                <template #prepend><v-icon size="18">mdi-email</v-icon></template>
                <v-list-item-title>{{ invoice.patient.user_email || invoice.patient.user.email }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="amber-lighten-5" size="36" class="mr-3">
                <v-icon color="amber-darken-3" size="20">mdi-receipt-text</v-icon>
              </v-avatar>
              <div class="text-h6 font-weight-bold">Invoice Meta</div>
            </div>
            <v-list density="compact" class="bg-transparent">
              <v-list-item>
                <template #prepend><v-icon size="18">mdi-identifier</v-icon></template>
                <v-list-item-title class="font-monospace">{{ invoice.invoice_number || '—' }}</v-list-item-title>
                <v-list-item-subtitle>Invoice number</v-list-item-subtitle>
              </v-list-item>
              <v-list-item>
                <template #prepend><v-icon size="18">mdi-calendar</v-icon></template>
                <v-list-item-title>{{ formatDate(invoice.invoice_date) }}</v-list-item-title>
                <v-list-item-subtitle>Invoice date</v-list-item-subtitle>
              </v-list-item>
              <v-list-item>
                <template #prepend><v-icon size="18">mdi-calendar-clock</v-icon></template>
                <v-list-item-title>{{ formatDate(invoice.due_date) }}</v-list-item-title>
                <v-list-item-subtitle>Due date</v-list-item-subtitle>
              </v-list-item>
              <v-list-item>
                <template #prepend><v-icon size="18">mdi-list-status</v-icon></template>
                <v-list-item-title>
                  <v-chip size="small" variant="tonal" :color="statusColor(invoice.status)"
                    class="text-capitalize font-weight-medium">{{ invoice.status || 'unpaid' }}</v-chip>
                </v-list-item-title>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <!-- ═══ Line items table ═════════════════════════════════════ -->
      <v-card flat rounded="lg" class="info-card mb-4">
        <div class="d-flex align-center pa-4 pb-0">
          <v-icon color="primary" class="mr-2">mdi-format-list-bulleted</v-icon>
          <div class="text-h6 font-weight-bold">Line Items</div>
        </div>
        <v-data-table
          :headers="itemHeaders"
          :items="lineItems"
          :items-per-page="-1"
          hide-default-footer
          item-value="id"
          density="compact">
          <template #item.unit_price="{ value }">{{ formatMoney(value) }}</template>
          <template #item.total="{ value }">{{ formatMoney(value) }}</template>
          <template #bottom>
            <div class="pa-3">
              <div class="d-flex justify-end text-body-2 pa-1">
                <span class="text-medium-emphasis mr-4">Subtotal</span>
                <span class="font-weight-medium">{{ formatMoney(invoice.subtotal || subtotalAmount) }}</span>
              </div>
              <div class="d-flex justify-end text-body-2 pa-1">
                <span class="text-medium-emphasis mr-4">Tax</span>
                <span class="font-weight-medium">{{ formatMoney(invoice.tax_amount || 0) }}</span>
              </div>
              <v-divider class="my-1" />
              <div class="d-flex justify-end text-h6 font-weight-bold pa-1">
                <span class="mr-4">Total</span>
                <span>{{ formatMoney(invoice.total_amount) }}</span>
              </div>
            </div>
          </template>
        </v-data-table>
      </v-card>

      <!-- ═══ Summary & payment ════════════════════════════════════ -->
      <v-row dense class="mb-4">
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="text-h6 font-weight-bold mb-3">Payment Summary</div>
            <div class="d-flex justify-space-between text-body-1 pa-1">
              <span class="text-medium-emphasis">Total</span>
              <span class="font-weight-medium">{{ formatMoney(invoice.total_amount) }}</span>
            </div>
            <div class="d-flex justify-space-between text-body-1 pa-1">
              <span class="text-medium-emphasis">Paid</span>
              <span class="font-weight-medium text-success">{{ formatMoney(invoice.amount_paid) }}</span>
            </div>
            <v-divider class="my-1" />
            <div class="d-flex justify-space-between text-h6 font-weight-bold pa-1">
              <span>Balance</span>
              <span :class="balance > 0 ? 'text-error' : 'text-success'">
                {{ formatMoney(balance) }}
              </span>
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-h6 font-weight-bold">Payments</div>
              <v-btn color="primary" variant="tonal" rounded="lg" size="small"
                prepend-icon="mdi-cash-plus" :disabled="balance <= 0"
                @click="paymentDialog = true">Record Payment</v-btn>
            </div>
            <div v-if="!payments.length" class="text-body-2 text-medium-emphasis text-center pa-4">
              No payments recorded yet
            </div>
            <v-list v-else density="compact">
              <v-list-item v-for="p in payments" :key="p.id">
                <template #prepend><v-icon size="18" color="success">mdi-cash-check</v-icon></template>
                <v-list-item-title>{{ formatMoney(p.amount) }}</v-list-item-title>
                <v-list-item-subtitle>
                  {{ formatDate(p.payment_date || p.date) }} · {{ p.method || 'cash' }}
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mb-4">
        {{ r.error.value }}
      </v-alert>
    </template>

    <!-- ═══ Payment dialog ════════════════════════════════════════ -->
    <v-dialog v-model="paymentDialog" max-width="500">
      <v-card rounded="lg" class="pa-4">
        <div class="text-h6 font-weight-bold mb-4">Record Payment</div>
        <v-row dense>
          <v-col cols="12">
            <v-text-field v-model="paymentForm.amount" label="Amount" type="number"
              min="0" variant="outlined" :rules="req" prepend-inner-icon="mdi-cash" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="paymentForm.method" :items="methodOptions" label="Method"
              variant="outlined" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="paymentForm.date" label="Payment date" type="date"
              variant="outlined" />
          </v-col>
        </v-row>
        <div class="d-flex justify-end ga-2 mt-3">
          <v-btn variant="text" class="text-none" @click="paymentDialog = false">Cancel</v-btn>
          <v-btn color="primary" class="text-none" :loading="r.saving.value"
            prepend-icon="mdi-check" @click="recordPayment">Record</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()
const id = computed(() => route.params.id)

const r = useResource('/invoices/')

const loading = computed(() => r.loading.value)
const invoice = computed(() => r.item.value)

onMounted(async () => { await r.get(id.value) })

const patientName = computed(() => {
  const p = invoice.value?.patient
  if (!p) return ''
  return p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || p.user_email || p.patient_number || ''
})
const pageTitle = computed(() => `Invoice ${invoice.value?.invoice_number || ''}`.trim())

const lineItems = computed(() => invoice.value?.line_items || invoice.value?.items || [])
const subtotalAmount = computed(() =>
  lineItems.value.reduce((s, l) => s + (Number(l.total) || 0), 0)
)
const balance = computed(() =>
  (Number(invoice.value?.total_amount) || 0) - (Number(invoice.value?.amount_paid) || 0)
)
const payments = computed(() => invoice.value?.payments || [])

const itemHeaders = [
  { title: 'Description', key: 'description' },
  { title: 'Qty', key: 'quantity', width: 80, align: 'end' },
  { title: 'Unit Price', key: 'unit_price', width: 140, align: 'end' },
  { title: 'Total', key: 'total', width: 140, align: 'end' },
]

const req = [v => !!v || 'Required']
const methodOptions = ['cash', 'card', 'insurance', 'mpesa']

const paymentDialog = ref(false)
const paymentForm = reactive({
  amount: 0,
  method: 'cash',
  date: new Date().toISOString().slice(0, 10),
})

watch(paymentDialog, (v) => {
  if (v) {
    paymentForm.amount = balance.value > 0 ? balance.value : 0
    paymentForm.date = new Date().toISOString().slice(0, 10)
  }
})

const snack = reactive({ show: false, color: 'success', text: '' })

function statusColor(s) {
  const map = { paid: 'success', partial: 'info', unpaid: 'warning', cancelled: 'grey', overdue: 'error' }
  return map[s] || 'default'
}

async function recordPayment() {
  if (!paymentForm.amount || Number(paymentForm.amount) <= 0) {
    snack.text = 'Enter a valid amount'
    snack.color = 'error'
    snack.show = true
    return
  }
  const newPaid = (Number(invoice.value?.amount_paid) || 0) + Number(paymentForm.amount)
  const total = Number(invoice.value?.total_amount) || 0
  const newStatus = newPaid >= total ? 'paid' : 'partial'
  try {
    await r.update(id.value, {
      amount_paid: newPaid,
      status: newStatus,
      payment_method: paymentForm.method,
      payment_date: paymentForm.date,
    })
    await r.get(id.value)
    paymentDialog.value = false
    snack.text = 'Payment recorded successfully'
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = r.error.value || 'Failed to record payment'
    snack.color = 'error'
    snack.show = true
  }
}

function printInvoice() {
  window.print()
}
</script>

<style scoped>
.info-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
