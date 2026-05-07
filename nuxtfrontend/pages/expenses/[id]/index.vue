<template>
  <v-container fluid class="pa-4 pa-md-6 exp-detail-shell">
    <PageHeader
      :title="item ? `Expense ${item.reference}` : 'Expense'"
      icon="mdi-cash-minus"
      :subtitle="item ? `${item.title} • ${formatDate(item.expense_date)}` : ''"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/expenses">Back</v-btn>
        <v-btn v-if="item" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-printer" @click="doPrint">Print</v-btn>
        <v-btn v-if="item && item.status === 'pending'" color="success" rounded="lg" class="text-none" prepend-icon="mdi-check-circle-outline" :loading="busy" @click="approve">Approve</v-btn>
        <v-btn v-if="item && item.status === 'pending'" color="error" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-close-circle" @click="rejectDialog.show = true">Reject</v-btn>
        <v-btn v-if="item && ['pending','approved'].includes(item.status)" color="info" rounded="lg" class="text-none" prepend-icon="mdi-cash-check" @click="payDialog.show = true">Mark Paid</v-btn>
        <v-btn v-if="item" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-pencil" :to="`/expenses/${id}/edit`">Edit</v-btn>
      </template>
    </PageHeader>

    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <div v-else-if="item">
      <v-card rounded="lg" class="exp-hero pa-5 pa-md-6 mb-4">
        <v-row align="center">
          <v-col cols="12" md="6">
            <div class="d-flex align-center mb-3">
              <v-avatar size="48" color="white" class="mr-3">
                <v-icon color="primary" size="28">mdi-cash-minus</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption" style="opacity:0.85">Reference</div>
                <div class="text-h4 font-weight-bold">{{ item.reference }}</div>
              </div>
            </div>
            <div class="d-flex flex-wrap ga-2 align-center">
              <StatusChip :status="item.status" />
              <v-chip v-if="item.category_name" size="small" variant="flat" color="white" prepend-icon="mdi-shape" class="text-primary font-weight-bold">{{ item.category_name }}</v-chip>
              <v-chip v-if="item.vendor || item.supplier_name" size="small" variant="flat" color="white" prepend-icon="mdi-truck-delivery" class="text-primary font-weight-bold">{{ item.supplier_name || item.vendor }}</v-chip>
              <v-chip size="small" variant="flat" color="white" prepend-icon="mdi-calendar" class="text-primary font-weight-bold">{{ formatDate(item.expense_date) }}</v-chip>
              <v-chip v-if="item.is_recurring" size="small" variant="flat" color="white" prepend-icon="mdi-repeat" class="text-primary font-weight-bold">Recurring {{ item.recurring_period }}</v-chip>
            </div>
          </v-col>
          <v-col cols="12" md="6" class="text-md-end">
            <div class="text-caption" style="opacity:0.85">Total amount</div>
            <div class="text-h3 font-weight-bold">{{ formatMoney(item.total_amount || item.amount) }}</div>
            <div v-if="Number(item.tax_amount) > 0" class="text-caption mt-1" style="opacity:0.85">
              {{ formatMoney(item.amount) }} + {{ formatMoney(item.tax_amount) }} tax
            </div>
          </v-col>
        </v-row>
      </v-card>

      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 exp-card">
        <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-information-outline</v-icon>{{ item.title }}
        </div>
        <div v-if="item.description" class="text-body-2 mb-3" style="white-space: pre-wrap">{{ item.description }}</div>
        <v-table density="compact" class="exp-detail-table">
          <tbody>
            <tr><th>Reference</th><td class="font-weight-bold">{{ item.reference }}</td></tr>
            <tr><th>Category</th><td>{{ item.category_name || '—' }}</td></tr>
            <tr><th>Vendor</th><td>{{ item.supplier_name || item.vendor || '—' }}</td></tr>
            <tr><th>Subtotal</th><td>{{ formatMoney(item.amount) }}</td></tr>
            <tr><th>Tax</th><td>{{ formatMoney(item.tax_amount || 0) }}</td></tr>
            <tr><th>Total</th><td class="font-weight-bold text-primary">{{ formatMoney(item.total_amount || item.amount) }}</td></tr>
            <tr><th>Payment Method</th><td>{{ methodLabel(item.payment_method) }}</td></tr>
            <tr><th>Payment Reference</th><td>{{ item.payment_reference || '—' }}</td></tr>
            <tr><th>Expense Date</th><td>{{ formatDate(item.expense_date) }}</td></tr>
            <tr><th>Due Date</th><td>{{ item.due_date ? formatDate(item.due_date) : '—' }}</td></tr>
            <tr v-if="item.is_recurring"><th>Recurring</th><td>Yes — {{ item.recurring_period || '—' }}</td></tr>
          </tbody>
        </v-table>
      </v-card>

      <v-row dense>
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 pa-md-5 exp-card h-100">
            <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
              <v-icon color="primary" class="mr-2">mdi-clipboard-text</v-icon>Workflow
            </div>
            <v-timeline density="compact" side="end" align="start" truncate-line="both">
              <v-timeline-item dot-color="primary" size="x-small">
                <div class="text-body-2 font-weight-medium">Created</div>
                <div class="text-caption text-medium-emphasis">{{ formatDateTime(item.created_at) }} • {{ item.submitted_by_name || '—' }}</div>
              </v-timeline-item>
              <v-timeline-item v-if="item.approved_at" dot-color="success" size="x-small">
                <div class="text-body-2 font-weight-medium">Approved</div>
                <div class="text-caption text-medium-emphasis">{{ formatDateTime(item.approved_at) }} • {{ item.approved_by_name || '—' }}</div>
              </v-timeline-item>
              <v-timeline-item v-if="item.paid_at" dot-color="info" size="x-small">
                <div class="text-body-2 font-weight-medium">Paid</div>
                <div class="text-caption text-medium-emphasis">{{ formatDateTime(item.paid_at) }}</div>
              </v-timeline-item>
              <v-timeline-item v-if="item.status === 'rejected'" dot-color="error" size="x-small">
                <div class="text-body-2 font-weight-medium">Rejected</div>
              </v-timeline-item>
            </v-timeline>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 pa-md-5 exp-card h-100">
            <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
              <v-icon color="primary" class="mr-2">mdi-paperclip</v-icon>Receipt &amp; Notes
            </div>
            <div v-if="item.receipt" class="mb-3">
              <v-btn :href="item.receipt" target="_blank" variant="tonal" prepend-icon="mdi-file-download" class="text-none">View receipt</v-btn>
            </div>
            <div v-if="item.notes" class="text-body-2" style="white-space: pre-wrap">{{ item.notes }}</div>
            <EmptyState v-if="!item.receipt && !item.notes" icon="mdi-note-outline" title="No notes" message="No receipt or notes attached." />
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Reject dialog -->
    <v-dialog v-model="rejectDialog.show" max-width="500" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold">Reject Expense</v-card-title>
        <v-card-text>
          <v-textarea v-model="rejectDialog.reason" label="Reason" rows="3" auto-grow />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="rejectDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="busy" @click="reject">Reject</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Pay dialog -->
    <v-dialog v-model="payDialog.show" max-width="500" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold">Mark as Paid</v-card-title>
        <v-card-text>
          <v-select v-model="payDialog.method" :items="methodOptions" item-title="label" item-value="value" label="Payment Method" />
          <v-text-field v-model="payDialog.ref" label="Payment Reference" placeholder="M-Pesa code, cheque #" class="mt-2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="payDialog.show = false">Cancel</v-btn>
          <v-btn color="info" variant="flat" :loading="busy" @click="markPaid">Confirm</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/expenses/expenses/')

const item = computed(() => r.item.value)
const loading = computed(() => r.loading.value)
const busy = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const methodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Bank Transfer', value: 'bank' },
  { label: 'Card', value: 'card' },
  { label: 'Cheque', value: 'cheque' },
  { label: 'Other', value: 'other' },
]
function methodLabel(v) { return methodOptions.find(o => o.value === v)?.label || v }

const rejectDialog = reactive({ show: false, reason: '' })
const payDialog = reactive({ show: false, method: 'cash', ref: '' })

watch(() => item.value, (i) => {
  if (i) { payDialog.method = i.payment_method || 'cash'; payDialog.ref = i.payment_reference || '' }
})

async function approve() {
  busy.value = true
  try {
    await $api.post(`/expenses/expenses/${id.value}/approve/`)
    snack.text = 'Expense approved'; snack.color = 'success'; snack.show = true
    await r.get(id.value)
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Approve failed.'; snack.color = 'error'; snack.show = true
  } finally { busy.value = false }
}
async function reject() {
  busy.value = true
  try {
    await $api.post(`/expenses/expenses/${id.value}/reject/`, { reason: rejectDialog.reason })
    snack.text = 'Expense rejected'; snack.color = 'success'; snack.show = true
    rejectDialog.show = false; rejectDialog.reason = ''
    await r.get(id.value)
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Reject failed.'; snack.color = 'error'; snack.show = true
  } finally { busy.value = false }
}
async function markPaid() {
  busy.value = true
  try {
    await $api.post(`/expenses/expenses/${id.value}/mark_paid/`, {
      payment_method: payDialog.method,
      payment_reference: payDialog.ref,
    })
    snack.text = 'Marked as paid'; snack.color = 'success'; snack.show = true
    payDialog.show = false
    await r.get(id.value)
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed.'; snack.color = 'error'; snack.show = true
  } finally { busy.value = false }
}
function doPrint() { if (typeof window !== 'undefined') window.print() }

onMounted(() => r.get(id.value))
</script>

<style scoped>
.exp-detail-shell { max-width: 1300px; margin: 0 auto; }
.exp-hero { background: linear-gradient(135deg, #4f46e5, #7c3aed); color: white; border: none; }
.exp-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

.exp-detail-table :deep(th) {
  width: 200px; text-align: left; font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.7); background: transparent;
}

@media print {
  .v-app-bar, .v-navigation-drawer, .v-btn { display: none !important; }
  .exp-detail-shell { max-width: 100%; }
}
</style>
