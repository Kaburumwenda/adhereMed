<template>
  <v-container fluid class="pa-4 pa-md-6 so-detail-shell">
    <PageHeader :title="so.so_number || 'Sales Order'" icon="mdi-receipt-text-plus" subtitle="Sales order details">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/sales-orders">Back</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-receipt-text-outline" :loading="pdfBusy" @click="downloadPdf">Download (PDF)</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-pencil" :to="`/sales-orders/${so.id}/edit`">Edit</v-btn>
      </template>
    </PageHeader>

    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <template v-else>
      <!-- Overview row -->
      <v-row dense class="mb-4">
        <v-col cols="12" md="4">
          <v-card rounded="lg" class="pa-4 h-100 so-panel">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-account-box-outline</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Customer</div>
            </div>
            <div class="text-h6 font-weight-bold">{{ so.customer_name || '—' }}</div>
            <div v-if="so.customer_phone" class="text-body-2 text-medium-emphasis mb-2">
              <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ so.customer_phone }}
            </div>
            <div v-if="so.branch_name" class="text-caption text-medium-emphasis">
              <v-icon size="14" class="mr-1">mdi-store</v-icon>{{ so.branch_name }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="6" md="4">
          <v-card rounded="lg" class="pa-4 h-100 so-panel">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-truck-delivery-outline</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Delivery</div>
            </div>
            <div class="text-body-2">
              <div class="text-caption text-medium-emphasis text-uppercase">Expected</div>
              <div class="font-weight-medium mb-2">{{ so.expected_delivery ? formatDate(so.expected_delivery) : '—' }}</div>
              <template v-if="so.delivery_address">
                <div class="text-caption text-medium-emphasis text-uppercase">Address</div>
                <div class="text-body-2">{{ so.delivery_address }}</div>
                <div v-if="so.delivery_place_name" class="text-caption text-medium-emphasis mt-1">
                  <v-icon size="12" class="mr-1">mdi-tag-outline</v-icon>{{ so.delivery_place_name }}
                </div>
              </template>
            </div>
            <LocationMap
              v-if="so.delivery_lat != null && so.delivery_lng != null"
              class="mt-3"
              :height="220"
              :zoom="15"
              :center="{ lat: Number(so.delivery_lat), lng: Number(so.delivery_lng) }"
              :markers="[{ lat: Number(so.delivery_lat), lng: Number(so.delivery_lng), title: so.delivery_place_name || so.delivery_address, color: '#0d9488' }]"
            />
          </v-card>
        </v-col>
        <v-col cols="6" md="4">
          <v-card rounded="lg" class="pa-4 h-100 so-panel">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-information-outline</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Order</div>
            </div>
            <div class="d-flex align-center ga-2 mb-2">
              <span class="text-caption text-medium-emphasis">Status</span>
              <StatusChip :status="so.status" />
            </div>
            <div class="d-flex align-center ga-2">
              <span class="text-caption text-medium-emphasis">Payment</span>
              <v-chip size="small" :color="paymentColor(so.payment_status)" variant="tonal">{{ so.payment_status?.replace('_', ' ') }}</v-chip>
              <v-chip size="small" variant="tonal" prepend-icon="mdi-credit-card-outline">{{ paymentMethodLabel(so.payment_method) }}</v-chip>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Items -->
      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 so-panel">
        <div class="d-flex align-center mb-3">
          <v-icon color="primary" class="mr-2">mdi-package-variant</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Items</div>
          <v-chip size="x-small" color="primary" variant="tonal" class="ml-2">{{ (so.items || []).length }}</v-chip>
        </div>
        <v-data-table
          :headers="itemHeaders"
          :items="so.items || []"
          :items-per-page="-1"
          density="comfortable"
          hover
          hide-default-footer
        >
          <template #item.index="{ index }">{{ index + 1 }}</template>
          <template #item.qty="{ item }">{{ item.qty }}</template>
          <template #item.unit_price="{ item }">{{ formatMoney(item.unit_price) }}</template>
          <template #item.discount_percent="{ item }">{{ item.discount_percent }}%</template>
          <template #item.total="{ item }">
            <span class="font-weight-bold">{{ formatMoney(item.total) }}</span>
          </template>
        </v-data-table>
      </v-card>

      <!-- Totals + payments -->
      <v-row dense>
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 so-panel h-100" :class="{ 'so-panel-primary': Number(so.balance_due) > 0 }">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-cash-multiple</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Payments</div>
            </div>
            <div class="d-flex justify-space-between mb-1">
              <span class="text-body-2 text-medium-emphasis">Order total</span>
              <span class="text-h6 font-weight-bold">{{ formatMoney(so.total_amount) }}</span>
            </div>
            <div v-if="Number(so.delivery_fee) > 0" class="d-flex justify-space-between mb-1">
              <span class="text-body-2 text-medium-emphasis">
                <v-icon size="14" class="mr-1">mdi-truck-delivery-outline</v-icon>Includes delivery fee
              </span>
              <span class="text-body-2 font-weight-medium text-info">{{ formatMoney(so.delivery_fee) }}</span>
            </div>
            <div class="d-flex justify-space-between mb-1">
              <span class="text-body-2 text-medium-emphasis">Paid to date</span>
              <span class="text-h6 font-weight-bold text-success">{{ formatMoney(so.amount_paid) }}</span>
            </div>
            <div class="d-flex justify-space-between mb-3">
              <span class="text-body-2 text-medium-emphasis">Balance due</span>
              <span class="text-h6 font-weight-bold" :class="Number(so.balance_due) > 0 ? 'text-error' : 'text-success'">{{ formatMoney(so.balance_due) }}</span>
            </div>
            <v-btn
              v-if="Number(so.balance_due) > 0"
              color="primary"
              rounded="lg"
              class="text-none"
              block
              prepend-icon="mdi-cash-plus"
              @click="openPaymentDialog"
            >Record Payment</v-btn>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 so-panel h-100">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-note-text-outline</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Notes</div>
            </div>
            <div class="text-body-2 text-medium-emphasis">{{ so.notes || 'No notes.' }}</div>
            <v-divider class="my-3" />
            <div class="text-caption text-medium-emphasis">
              Created {{ formatDate(so.created_at) }}<span v-if="so.created_by_name"> by {{ so.created_by_name }}</span>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Record payment dialog -->
      <v-dialog v-model="paymentDialog.show" max-width="420" persistent>
        <v-card rounded="lg">
          <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
            <v-icon color="primary" class="mr-2">mdi-cash-plus</v-icon>Record Payment
          </v-card-title>
          <v-card-text>
            <div class="text-body-2 text-medium-emphasis mb-3">
              Outstanding balance: <b>{{ formatMoney(so.balance_due) }}</b>
            </div>
            <v-text-field
              v-model.number="paymentDialog.amount"
              label="Amount received (KSh)"
              type="number"
              min="0.01"
              step="0.01"
              variant="outlined"
              density="comfortable"
              prefix="KSh"
              hide-details="auto"
              autofocus
            />
            <v-select
              v-model="paymentDialog.method"
              :items="paymentMethodOptions"
              item-title="label"
              item-value="value"
              label="Payment method"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-credit-card-outline"
              hide-details="auto"
              class="mb-3"
            />
            <div class="d-flex ga-2 mt-2">
              <v-btn size="small" variant="text" class="text-none" @click="paymentDialog.amount = Number(so.balance_due)">Full balance</v-btn>
              <v-btn size="small" variant="text" class="text-none" @click="paymentDialog.amount = Math.round(Number(so.balance_due) / 2)">Half</v-btn>
            </div>
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn variant="text" @click="paymentDialog.show = false">Cancel</v-btn>
            <v-btn color="primary" variant="flat" :loading="paymentDialog.busy" :disabled="!(Number(paymentDialog.amount) > 0)" @click="recordPayment">Record</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'

const route = useRoute()
const { $api } = useNuxtApp()
const r = useResource('/sales-orders/orders/')
const loadId = computed(() => route.params.id)

const so = ref({})
const loading = ref(true)
const pdfBusy = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })
const paymentDialog = reactive({ show: false, amount: null, method: 'cash', busy: false })

const paymentMethodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Bank Transfer', value: 'bank' },
  { label: 'Card', value: 'card' },
  { label: 'Cheque', value: 'cheque' },
  { label: 'Insurance', value: 'insurance' },
  { label: 'Credit', value: 'credit' },
  { label: 'Other', value: 'other' },
]

function paymentMethodLabel(m) { return paymentMethodOptions.find(o => o.value === m)?.label || m }

function openPaymentDialog() {
  paymentDialog.method = so.value.payment_method || 'cash'
  paymentDialog.amount = null
  paymentDialog.show = true
}

const itemHeaders = [
  { title: '#', key: 'index', width: 50, sortable: false },
  { title: 'Item', key: 'name' },
  { title: 'Qty', key: 'qty', width: 80, align: 'end' },
  { title: 'Unit price', key: 'unit_price', width: 130, align: 'end' },
  { title: 'Disc %', key: 'discount_percent', width: 90, align: 'end' },
  { title: 'Line total', key: 'total', width: 140, align: 'end' },
]

function paymentColor(s) { return { unpaid: 'error', partial: 'warning', paid: 'success' }[s] || 'grey' }

async function load() {
  loading.value = true
  try {
    const data = await r.get(loadId.value)
    so.value = data || {}
  } finally {
    loading.value = false
  }
}

async function recordPayment() {
  paymentDialog.busy = true
  try {
    const { data } = await $api.post(`/sales-orders/orders/${loadId.value}/record-payment/`, {
      amount: Number(paymentDialog.amount),
      payment_method: paymentDialog.method,
    })
    so.value = data
    paymentDialog.show = false
    paymentDialog.amount = null
    snack.text = 'Payment recorded.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to record payment.'
    snack.color = 'error'
    snack.show = true
  } finally {
    paymentDialog.busy = false
  }
}

async function downloadPdf() {
  pdfBusy.value = true
  try {
    const blob = (await $api.get(`/sales-orders/orders/${loadId.value}/so-pdf/`, { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `sales_order_${so.value.so_number || loadId.value}.pdf`
    a.click()
    URL.revokeObjectURL(objectUrl)
  } catch {
    snack.text = 'PDF download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    pdfBusy.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.so-detail-shell { max-width: 1200px; margin: 0 auto; }
.so-panel { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); height: 100%; }
.so-panel-primary { border-color: rgba(var(--v-theme-warning), 0.4); background: rgba(var(--v-theme-warning), 0.03); }
</style>
