<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <v-btn variant="text" class="text-none mb-1" prepend-icon="mdi-arrow-left" to="/radiology/billing">Back</v-btn>
        <h1 class="text-h5 font-weight-bold">Invoice {{ invoice?.invoice_number }}</h1>
      </div>
      <div v-if="invoice" class="d-flex" style="gap:8px">
        <v-btn v-if="invoice.status === 'draft'" variant="tonal" rounded="lg" class="text-none" @click="issueInvoice">Issue</v-btn>
        <v-btn v-if="invoice.status !== 'paid' && invoice.status !== 'void'" color="success" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-cash-plus" @click="payDlg=true">Add Payment</v-btn>
      </div>
    </div>

    <v-row v-if="invoice">
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-5 mb-4" border>
          <v-row dense>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Invoice #</div><div class="font-weight-medium">{{ invoice.invoice_number }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Patient</div><div>{{ invoice.patient_name }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Status</div><v-chip size="small" :color="invoiceColor(invoice.status)" variant="tonal">{{ invoice.status_display }}</v-chip></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Payer Type</div><div>{{ invoice.payer_type_display }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Date</div><div>{{ formatDate(invoice.created_at) }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Order #</div><nuxt-link :to="`/radiology/orders/${invoice.order}`" class="text-primary">#{{ invoice.order }}</nuxt-link></v-col>
          </v-row>
        </v-card>

        <!-- Items -->
        <v-card rounded="lg" class="pa-5 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Line Items</h3>
          <v-table v-if="invoice.items?.length" density="compact">
            <thead><tr><th>Description</th><th>Qty</th><th>Unit Price</th><th>Discount</th><th class="text-end">Total</th></tr></thead>
            <tbody>
              <tr v-for="it in invoice.items" :key="it.id">
                <td>{{ it.description || it.exam_name || it.panel_name }}</td>
                <td>{{ it.quantity }}</td>
                <td>{{ formatMoney(it.unit_price) }}</td>
                <td>{{ formatMoney(it.discount) }}</td>
                <td class="text-end font-weight-medium">{{ formatMoney(it.total) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-body-2 text-medium-emphasis">No items</div>
        </v-card>

        <!-- Payments -->
        <v-card rounded="lg" class="pa-5" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Payments</h3>
          <v-table v-if="invoice.payments?.length" density="compact">
            <thead><tr><th>Date</th><th>Method</th><th>Reference</th><th>By</th><th class="text-end">Amount</th></tr></thead>
            <tbody>
              <tr v-for="p in invoice.payments" :key="p.id">
                <td>{{ formatDate(p.payment_date) }}</td>
                <td>{{ p.method_display }}</td>
                <td>{{ p.reference || '—' }}</td>
                <td>{{ p.received_by_name }}</td>
                <td class="text-end font-weight-medium text-success">{{ formatMoney(p.amount) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-body-2 text-medium-emphasis">No payments yet</div>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-5" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">Summary</h3>
          <div class="d-flex justify-space-between mb-1"><span>Subtotal</span><span>{{ formatMoney(invoice.subtotal) }}</span></div>
          <div class="d-flex justify-space-between mb-1"><span>Discount</span><span>-{{ formatMoney(invoice.discount) }}</span></div>
          <div class="d-flex justify-space-between mb-1"><span>Tax</span><span>{{ formatMoney(invoice.tax) }}</span></div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between mb-1 text-h6 font-weight-bold"><span>Total</span><span>{{ formatMoney(invoice.total) }}</span></div>
          <div class="d-flex justify-space-between mb-1 text-success"><span>Paid</span><span>{{ formatMoney(invoice.amount_paid) }}</span></div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between text-h6 font-weight-bold" :class="invoice.balance > 0 ? 'text-error' : 'text-success'">
            <span>Balance</span><span>{{ formatMoney(invoice.balance) }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>
    <v-skeleton-loader v-else type="card,card" />

    <!-- Payment dialog -->
    <v-dialog v-model="payDlg" max-width="400" persistent>
      <v-card rounded="lg" class="pa-5">
        <h3 class="text-h6 font-weight-bold mb-3">Add Payment</h3>
        <v-form ref="payForm" @submit.prevent="addPayment">
          <v-text-field v-model.number="payment.amount" label="Amount *" type="number" :rules="[v => v > 0 || 'Required']" variant="outlined" density="compact" class="mb-2" />
          <v-select v-model="payment.method" :items="payMethods" label="Method *" :rules="[v => !!v || 'Required']" variant="outlined" density="compact" class="mb-2" />
          <v-text-field v-model="payment.reference" label="Reference" variant="outlined" density="compact" class="mb-2" />
          <v-textarea v-model="payment.notes" label="Notes" rows="2" auto-grow variant="outlined" density="compact" />
          <div class="d-flex justify-end mt-3" style="gap:8px">
            <v-btn variant="tonal" class="text-none" @click="payDlg=false">Cancel</v-btn>
            <v-btn type="submit" color="success" variant="flat" class="text-none" :loading="payingSaving">Pay</v-btn>
          </div>
        </v-form>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const route = useRoute()
const invoiceId = route.params.id
const invoice = ref(null)
const payDlg = ref(false)
const payForm = ref(null)
const payingSaving = ref(false)
const payment = reactive({ amount: 0, method: '', reference: '', notes: '' })
const payMethods = [
  { title: 'Cash', value: 'cash' }, { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Card', value: 'card' }, { title: 'Bank Transfer', value: 'bank' },
  { title: 'Insurance', value: 'insurance' },
]

function invoiceColor(s) { return { draft: 'grey', issued: 'info', partial: 'warning', paid: 'success', void: 'error' }[s] || 'grey' }
function formatDate(d) { return d ? new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) : '—' }

async function issueInvoice() {
  try { await $api.patch(`/radiology/invoices/${invoiceId}/`, { status: 'issued' }); await load() } catch (e) { console.error(e) }
}

async function addPayment() {
  const { valid } = await payForm.value.validate()
  if (!valid) return
  payingSaving.value = true
  try {
    await $api.post(`/radiology/invoices/${invoiceId}/add_payment/`, payment)
    payDlg.value = false
    await load()
  } catch (e) { console.error(e) }
  payingSaving.value = false
}

async function load() {
  try {
    const res = await $api.get(`/radiology/invoices/${invoiceId}/`)
    invoice.value = res.data
  } catch { }
}
onMounted(load)
</script>
