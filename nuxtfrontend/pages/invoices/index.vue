<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="indigo-lighten-5" size="48" class="mr-3">
          <v-icon color="indigo-darken-2" size="28">mdi-receipt-text</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">{{ $t('invoices.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Issue, track &amp; collect — full receivables management</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="loadAll">{{ $t('common.refresh') }}</v-btn>
      <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-download" class="text-none"
                 @click="exportCsv">Export</v-btn>
      <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" to="/invoices/new">New invoice</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Aging buckets -->
    <v-row dense class="mb-3">
      <v-col v-for="b in agingBuckets" :key="b.key" cols="6" md="3">
        <v-card class="pa-3 bucket" :class="b.key === bucketFilter ? 'bucket-active' : ''"
                rounded="xl" border @click="toggleBucket(b.key)">
          <div class="d-flex align-center mb-1">
            <v-avatar :color="b.color" size="32" class="mr-2">
              <v-icon size="16" color="white">{{ b.icon }}</v-icon>
            </v-avatar>
            <div class="text-caption text-uppercase text-medium-emphasis">{{ b.label }}</div>
          </div>
          <div class="text-h6 font-weight-bold">{{ formatMoney(b.total) }}</div>
          <div class="text-caption text-medium-emphasis">{{ b.count }} invoices</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters bar -->
    <v-card flat rounded="xl" class="pa-3 mb-3" border>
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search invoice # or patient…" density="comfortable"
                        variant="solo-filled" flat hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusItems"
                    label="Status" density="comfortable" hide-details variant="outlined" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="balanceFilter" :items="balanceItems"
                    label="Balance" density="comfortable" hide-details variant="outlined" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortBy" :items="sortItems"
                    label="Sort" density="comfortable" hide-details variant="outlined" />
        </v-col>
        <v-col cols="6" md="2" class="text-right">
          <v-chip color="primary" variant="tonal">{{ filteredInvoices.length }} shown</v-chip>
        </v-col>
      </v-row>
    </v-card>

    <!-- Bulk action bar -->
    <v-card v-if="selected.length" flat rounded="xl" class="pa-3 mb-3 bulk-bar" border>
      <div class="d-flex align-center" style="gap:8px">
        <v-icon color="primary">mdi-checkbox-marked-circle</v-icon>
        <div class="font-weight-medium">{{ selected.length }} selected</div>
        <v-spacer />
        <v-btn size="small" variant="tonal" color="info" prepend-icon="mdi-email-fast"
               @click="bulkUpdateStatus('sent')">Mark Sent</v-btn>
        <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-cancel"
               @click="bulkUpdateStatus('cancelled')">{{ $t('common.cancel') }}</v-btn>
        <v-btn size="small" variant="text" @click="selected = []">Clear</v-btn>
      </div>
    </v-card>

    <!-- Invoices table -->
    <v-card flat rounded="xl" border>
      <v-data-table
        v-model="selected"
        show-select
        :headers="headers"
        :items="filteredInvoices"
        :loading="loading"
        item-value="id"
        density="comfortable" hover :items-per-page="20"
      >
        <template #item.invoice_number="{ item }">
          <div class="font-weight-medium">{{ item.invoice_number }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</div>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="avatarColor(item.patient_name)" size="32" class="mr-2">
              <span class="text-caption font-weight-bold text-white">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div>{{ item.patient_name || '—' }}</div>
          </div>
        </template>
        <template #item.total="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.total) }}</span>
        </template>
        <template #item.amount_paid="{ item }">
          <span class="text-medium-emphasis">{{ formatMoney(item.amount_paid) }}</span>
        </template>
        <template #item.balance="{ item }">
          <span class="font-weight-bold" :class="invoiceBalance(item) > 0 ? 'text-error' : 'text-success'">
            {{ formatMoney(invoiceBalance(item)) }}
          </span>
        </template>
        <template #item.due_date="{ item }">
          <div v-if="item.due_date" class="d-flex align-center">
            <span>{{ formatDate(item.due_date) }}</span>
            <v-chip v-if="isOverdue(item)" size="x-small" color="error" variant="tonal" class="ml-2">
              {{ daysLate(item) }}d late
            </v-chip>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.status="{ item }">
          <v-chip :color="invoiceStatusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
            {{ (item.status || '').replace('_', ' ') }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn v-if="invoiceBalance(item) > 0"
                 icon="mdi-cash-plus" variant="text" size="small" color="success"
                 @click="openPayDialog(item)" />
          <v-btn icon="mdi-eye" variant="text" size="small" @click="openInvoiceDetail(item)" />
          <v-btn icon="mdi-printer" variant="text" size="small" color="primary"
                 @click="printInvoice(item)" />
          <v-menu>
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
            </template>
            <v-list density="compact">
              <v-list-item :to="`/invoices/${item.id}`" prepend-icon="mdi-file-document-outline">
                <v-list-item-title>Open</v-list-item-title>
              </v-list-item>
              <v-list-item :to="`/invoices/${item.id}/edit`" prepend-icon="mdi-pencil">
                <v-list-item-title>{{ $t('common.edit') }}</v-list-item-title>
              </v-list-item>
              <v-list-item prepend-icon="mdi-content-copy" @click="duplicateInvoice(item)">
                <v-list-item-title>Duplicate</v-list-item-title>
              </v-list-item>
              <v-list-item v-if="item.status === 'draft'" prepend-icon="mdi-email-fast"
                           @click="updateStatus(item, 'sent')">
                <v-list-item-title>Mark as Sent</v-list-item-title>
              </v-list-item>
              <v-list-item v-if="item.status !== 'cancelled'" prepend-icon="mdi-cancel"
                           @click="updateStatus(item, 'cancelled')">
                <v-list-item-title>Cancel invoice</v-list-item-title>
              </v-list-item>
              <v-divider />
              <v-list-item prepend-icon="mdi-delete" base-color="error" @click="confirmDelete(item)">
                <v-list-item-title>{{ $t('common.delete') }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </template>
        <template #no-data>
          <EmptyState icon="mdi-receipt-text-outline" title="No invoices found"
                      message="Try widening filters or create your first invoice." />
        </template>
      </v-data-table>
    </v-card>

    <!-- Record payment dialog -->
    <v-dialog v-model="payDialog" max-width="520" persistent>
      <v-card v-if="payTarget" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="success" class="mr-2">mdi-cash-plus</v-icon>
          Record payment
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="payDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Invoice</span>
            <span class="font-weight-medium">{{ payTarget.invoice_number }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Patient</span>
            <span>{{ payTarget.patient_name || '—' }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">{{ $t('common.total') }}</span>
            <span class="font-weight-bold">{{ formatMoney(payTarget.total) }}</span>
          </div>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis">Outstanding balance</span>
            <span class="font-weight-bold text-error">{{ formatMoney(invoiceBalance(payTarget)) }}</span>
          </div>
          <v-divider class="mb-3" />
          <v-text-field v-model.number="payForm.amount" type="number" min="0" :max="invoiceBalance(payTarget)"
                        label="Amount *" variant="outlined" density="comfortable"
                        prepend-inner-icon="mdi-cash" :error-messages="payErrors.amount" />
          <v-select v-model="payForm.method" :items="paymentMethodItems"
                    label="Method *" variant="outlined" density="comfortable"
                    :error-messages="payErrors.method" />
          <v-text-field v-model="payForm.reference" label="Reference (M-Pesa code, cheque #…)"
                        variant="outlined" density="comfortable" prepend-inner-icon="mdi-pound" />
          <v-textarea v-model="payForm.notes" label="Notes" variant="outlined"
                      density="comfortable" rows="2" auto-grow />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" @click="setFullAmount">Pay full balance</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="success" variant="flat" :loading="saving" @click="recordPayment">
            Record payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Invoice detail dialog -->
    <v-dialog v-model="invDetailDialog" max-width="720" scrollable>
      <v-card v-if="invDetail" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-receipt-text</v-icon>
          {{ invDetail.invoice_number }}
          <v-chip class="ml-2" size="small" :color="invoiceStatusColor(invDetail.status)" variant="tonal">
            {{ invDetail.status }}
          </v-chip>
          <v-spacer />
          <v-btn icon="mdi-printer" variant="text" size="small" color="primary" @click="printInvoice(invDetail)" />
          <v-btn icon="mdi-close" variant="text" size="small" @click="invDetailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Patient</div>
              <div>{{ invDetail.patient_name || '—' }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Created</div>
              <div>{{ formatDateTime(invDetail.created_at) }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Due</div>
              <div>{{ invDetail.due_date ? formatDate(invDetail.due_date) : '—' }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">{{ $t('common.status') }}</div>
              <v-chip size="x-small" :color="invoiceStatusColor(invDetail.status)" variant="tonal">
                {{ invDetail.status }}
              </v-chip>
            </v-col>
          </v-row>

          <v-divider class="my-3" />
          <div class="text-subtitle-2 mb-2">Line items</div>
          <v-table density="compact">
            <thead>
              <tr>
                <th>Description</th>
                <th class="text-right">Qty × Unit</th>
                <th class="text-right">{{ $t('common.total') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, i) in (invDetail.items || [])" :key="i">
                <td>{{ it.description }}</td>
                <td class="text-right">{{ it.quantity }} × {{ formatMoney(it.unit_price) }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(it.total) }}</td>
              </tr>
              <tr v-if="!invDetail.items?.length">
                <td colspan="3" class="text-center text-medium-emphasis py-3">No line items</td>
              </tr>
            </tbody>
          </v-table>

          <v-divider class="my-3" />
          <v-row dense>
            <v-col cols="12" md="6">
              <div v-if="invDetail.notes" class="text-caption text-medium-emphasis">{{ $t('common.notes') }}</div>
              <div v-if="invDetail.notes" class="text-body-2">{{ invDetail.notes }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="d-flex justify-space-between"><span>{{ $t('common.subtotal') }}</span><span>{{ formatMoney(invDetail.subtotal) }}</span></div>
              <div class="d-flex justify-space-between"><span>{{ $t('common.tax') }}</span><span>{{ formatMoney(invDetail.tax) }}</span></div>
              <div class="d-flex justify-space-between"><span>{{ $t('common.discount') }}</span><span>− {{ formatMoney(invDetail.discount) }}</span></div>
              <div class="d-flex justify-space-between font-weight-bold"><span>{{ $t('common.total') }}</span><span>{{ formatMoney(invDetail.total) }}</span></div>
              <div class="d-flex justify-space-between text-success"><span>{{ $t('common.paid') }}</span><span>{{ formatMoney(invDetail.amount_paid) }}</span></div>
              <div class="d-flex justify-space-between font-weight-bold text-error">
                <span>{{ $t('common.balance') }}</span><span>{{ formatMoney(invoiceBalance(invDetail)) }}</span>
              </div>
            </v-col>
          </v-row>

          <template v-if="invDetail.payments?.length">
            <v-divider class="my-3" />
            <div class="text-subtitle-2 mb-2">Payments ({{ invDetail.payments.length }})</div>
            <v-list density="compact" class="pa-0">
              <v-list-item v-for="p in invDetail.payments" :key="p.id" class="px-0">
                <template #prepend>
                  <v-icon :color="paymentColor(p.method)">{{ paymentIcon(p.method) }}</v-icon>
                </template>
                <v-list-item-title class="text-body-2">
                  {{ formatMoney(p.amount) }} · <span class="text-capitalize">{{ p.method }}</span>
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ formatDateTime(p.paid_at) }}{{ p.reference ? ' · ' + p.reference : '' }}{{ p.received_by_name ? ' · by ' + p.received_by_name : '' }}
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
          </template>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" :to="`/invoices/${invDetail.id}/edit`" prepend-icon="mdi-pencil">{{ $t('common.edit') }}</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="invDetailDialog = false">{{ $t('common.close') }}</v-btn>
          <v-btn v-if="invoiceBalance(invDetail) > 0" color="success" variant="flat"
                 prepend-icon="mdi-cash-plus"
                 @click="openPayDialog(invDetail); invDetailDialog = false">
            Record payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Custom range -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Custom date range</v-card-title>
        <v-card-text>
          <v-text-field v-model="customStart" type="date" label="Start" variant="outlined" density="comfortable" />
          <v-text-field v-model="customEnd" type="date" label="End" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="customDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="flat" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card v-if="deleteTarget" rounded="xl">
        <v-card-title>Delete invoice?</v-card-title>
        <v-card-text>
          This will permanently delete invoice
          <strong>{{ deleteTarget.invoice_number }}</strong>. This action cannot be undone.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="deleteInvoice">{{ $t('common.delete') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, computed, onMounted } from 'vue'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const invoices = ref([])
const selected = ref([])

// ────── Date range
const rangeKey = ref('30d')
const rangeOptions = [
  { key: 'today', label: 'Today' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: 'mtd', label: 'Month to date' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'ytd', label: 'Year to date' },
  { key: 'all', label: 'All time' },
  { key: 'custom', label: 'Custom range…' },
]
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')

function resolveRange() {
  const today = new Date()
  const iso = (d) => d.toISOString().slice(0, 10)
  const sub = (n) => { const d = new Date(today); d.setDate(d.getDate() - n); return d }
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1)
  const yearStart = new Date(today.getFullYear(), 0, 1)
  switch (rangeKey.value) {
    case 'today': return { start: iso(today), end: iso(today), label: 'Today' }
    case '7d': return { start: iso(sub(6)), end: iso(today), label: 'Last 7 days' }
    case 'mtd': return { start: iso(monthStart), end: iso(today), label: 'Month to date' }
    case '90d': return { start: iso(sub(89)), end: iso(today), label: 'Last 90 days' }
    case 'ytd': return { start: iso(yearStart), end: iso(today), label: 'Year to date' }
    case 'all': return { start: '1970-01-01', end: '2999-12-31', label: 'All time' }
    case 'custom':
      if (customStart.value && customEnd.value)
        return { start: customStart.value, end: customEnd.value, label: `${customStart.value} → ${customEnd.value}` }
      return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
    case '30d':
    default: return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
  }
}
const range = ref(resolveRange())
function onRangeChange(v) {
  if (v === 'custom') { customDialog.value = true; return }
  range.value = resolveRange()
}
function applyCustom() {
  if (!customStart.value || !customEnd.value) return
  rangeKey.value = 'custom'
  customDialog.value = false
  range.value = resolveRange()
}

// ────── Loading
async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/billing/invoices/', { params: { page_size: 500, ordering: '-created_at' } })
    invoices.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify('Failed to load invoices', 'error')
  } finally {
    loading.value = false
  }
}
onMounted(loadAll)

// ────── Helpers
function invoiceBalance(i) { return Number(i?.total || 0) - Number(i?.amount_paid || 0) }
function isOverdue(i) {
  if (!i?.due_date) return false
  if (['paid', 'cancelled'].includes(i.status)) return false
  return new Date(i.due_date) < new Date(new Date().toISOString().slice(0, 10))
}
function daysLate(i) {
  if (!isOverdue(i)) return 0
  return Math.floor((new Date() - new Date(i.due_date)) / 86400000)
}
function invoiceStatusColor(s) {
  return ({ draft: 'grey', sent: 'info', paid: 'success', partially_paid: 'amber', overdue: 'error', cancelled: 'grey' })[s] || 'grey'
}
function paymentColor(m) {
  return ({ cash: 'success', mpesa: 'green', card: 'indigo', insurance: 'purple', bank_transfer: 'blue' })[(m || '').toLowerCase()] || 'grey'
}
function paymentIcon(m) {
  return ({ cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card-outline',
    insurance: 'mdi-shield-account', bank_transfer: 'mdi-bank-transfer' })[(m || '').toLowerCase()] || 'mdi-cash'
}
function initials(n) { if (!n) return '?'; return n.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('') }
function avatarColor(name) {
  const palette = ['primary', 'indigo', 'teal', 'deep-purple', 'pink', 'orange', 'cyan', 'green']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}

// ────── Date filter
const inRange = (iso) => {
  if (!iso) return false
  const d = String(iso).slice(0, 10)
  return d >= range.value.start && d <= range.value.end
}
const invoicesInRange = computed(() => invoices.value.filter(i => inRange(i.created_at)))

// ────── KPIs
const totalIssued = computed(() => sumBy(invoicesInRange.value, 'total'))
const totalCollected = computed(() => sumBy(invoicesInRange.value, 'amount_paid'))
const totalOutstanding = computed(() =>
  invoices.value.filter(i => !['cancelled'].includes(i.status))
    .reduce((s, i) => s + invoiceBalance(i), 0))
const overdueCount = computed(() => invoices.value.filter(i => isOverdue(i) && invoiceBalance(i) > 0).length)
const overdueTotal = computed(() =>
  invoices.value.filter(i => isOverdue(i) && invoiceBalance(i) > 0)
    .reduce((s, i) => s + invoiceBalance(i), 0))
const collectionRate = computed(() =>
  totalIssued.value > 0 ? Math.round((totalCollected.value / totalIssued.value) * 100) : 0)

const kpiTiles = computed(() => [
  { label: 'Issued', value: formatMoney(totalIssued.value), icon: 'mdi-receipt-text-outline',
    color: 'indigo', sub: `${invoicesInRange.value.length} invoices`, trendClass: 'text-medium-emphasis' },
  { label: 'Collected', value: formatMoney(totalCollected.value), icon: 'mdi-cash-check',
    color: 'success', sub: `${collectionRate.value}% collection rate`, trendClass: 'text-success' },
  { label: 'Outstanding', value: formatMoney(totalOutstanding.value), icon: 'mdi-cash-fast',
    color: 'amber-darken-2', sub: 'across all invoices', trendClass: 'text-medium-emphasis' },
  { label: 'Overdue', value: formatMoney(overdueTotal.value), icon: 'mdi-alert',
    color: 'error', sub: `${overdueCount.value} overdue invoices`, trendClass: 'text-error' },
])

// ────── Aging buckets (clickable filter)
const bucketFilter = ref(null)
function toggleBucket(key) { bucketFilter.value = bucketFilter.value === key ? null : key }
function bucketOf(i) {
  if (invoiceBalance(i) <= 0) return null
  if (!isOverdue(i)) return 'current'
  const d = daysLate(i)
  if (d <= 30) return '1-30'
  if (d <= 60) return '31-60'
  return '60+'
}
const agingBuckets = computed(() => {
  const open = invoices.value.filter(i => invoiceBalance(i) > 0 && i.status !== 'cancelled')
  const buckets = [
    { key: 'current', label: 'Not yet due', icon: 'mdi-calendar-clock', color: 'info', total: 0, count: 0 },
    { key: '1-30', label: '1-30 days', icon: 'mdi-calendar-alert', color: 'amber-darken-2', total: 0, count: 0 },
    { key: '31-60', label: '31-60 days', icon: 'mdi-alert', color: 'orange-darken-2', total: 0, count: 0 },
    { key: '60+', label: '60+ days', icon: 'mdi-alert-octagon', color: 'error', total: 0, count: 0 },
  ]
  open.forEach(i => {
    const k = bucketOf(i); if (!k) return
    const b = buckets.find(x => x.key === k)
    b.total += invoiceBalance(i); b.count++
  })
  return buckets
})

// ────── Filters
const search = ref('')
const statusFilter = ref('all')
const balanceFilter = ref('all')
const sortBy = ref('newest')
const statusItems = [
  { title: 'All statuses', value: 'all' },
  { title: 'Draft', value: 'draft' },
  { title: 'Sent', value: 'sent' },
  { title: 'Partially paid', value: 'partially_paid' },
  { title: 'Paid', value: 'paid' },
  { title: 'Overdue', value: 'overdue' },
  { title: 'Cancelled', value: 'cancelled' },
]
const balanceItems = [
  { title: 'All', value: 'all' },
  { title: 'Outstanding only', value: 'outstanding' },
  { title: 'Fully paid', value: 'paid' },
  { title: 'Overdue', value: 'overdue' },
]
const sortItems = [
  { title: 'Newest', value: 'newest' },
  { title: 'Oldest', value: 'oldest' },
  { title: 'Total ↓', value: 'total_desc' },
  { title: 'Balance ↓', value: 'balance_desc' },
  { title: 'Due date', value: 'due' },
]
const headers = [
  { title: 'Invoice', key: 'invoice_number', sortable: true },
  { title: 'Patient', key: 'patient_name', sortable: true },
  { title: 'Total', key: 'total', sortable: true, align: 'end' },
  { title: 'Paid', key: 'amount_paid', sortable: true, align: 'end' },
  { title: 'Balance', key: 'balance', sortable: true, align: 'end' },
  { title: 'Due', key: 'due_date', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 200 },
]

const filteredInvoices = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let rows = invoices.value.filter(i => {
    if (rangeKey.value !== 'all' && !inRange(i.created_at)) return false
    if (statusFilter.value !== 'all' && i.status !== statusFilter.value) return false
    if (balanceFilter.value === 'outstanding' && invoiceBalance(i) <= 0) return false
    if (balanceFilter.value === 'paid' && invoiceBalance(i) > 0) return false
    if (balanceFilter.value === 'overdue' && !isOverdue(i)) return false
    if (bucketFilter.value && bucketOf(i) !== bucketFilter.value) return false
    if (!q) return true
    return (i.invoice_number || '').toLowerCase().includes(q)
        || (i.patient_name || '').toLowerCase().includes(q)
  })
  const sorters = {
    newest: (a, b) => (b.created_at || '').localeCompare(a.created_at || ''),
    oldest: (a, b) => (a.created_at || '').localeCompare(b.created_at || ''),
    total_desc: (a, b) => Number(b.total) - Number(a.total),
    balance_desc: (a, b) => invoiceBalance(b) - invoiceBalance(a),
    due: (a, b) => (a.due_date || '9999').localeCompare(b.due_date || '9999'),
  }
  return [...rows].sort(sorters[sortBy.value] || sorters.newest)
})

// ────── Record payment
const payDialog = ref(false)
const payTarget = ref(null)
const payForm = reactive({ amount: 0, method: 'cash', reference: '', notes: '' })
const payErrors = reactive({})
const paymentMethodItems = [
  { title: 'Cash', value: 'cash' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Card', value: 'card' },
  { title: 'Bank Transfer', value: 'bank_transfer' },
  { title: 'Insurance', value: 'insurance' },
]
function openPayDialog(inv) {
  if (!inv) return
  payTarget.value = inv
  Object.assign(payForm, { amount: invoiceBalance(inv), method: 'cash', reference: '', notes: '' })
  Object.keys(payErrors).forEach(k => delete payErrors[k])
  payDialog.value = true
}
function setFullAmount() { payForm.amount = invoiceBalance(payTarget.value) }
async function recordPayment() {
  Object.keys(payErrors).forEach(k => delete payErrors[k])
  if (!payForm.amount || payForm.amount <= 0) { payErrors.amount = 'Enter an amount > 0'; return }
  if (payForm.amount > invoiceBalance(payTarget.value)) { payErrors.amount = 'Cannot exceed outstanding balance'; return }
  if (!payForm.method) { payErrors.method = 'Select a method'; return }
  saving.value = true
  try {
    await $api.post(`/billing/invoices/${payTarget.value.id}/record_payment/`, payForm)
    notify('Payment recorded')
    payDialog.value = false
    await loadAll()
  } catch (e) {
    notify(extractError(e) || 'Failed to record payment', 'error')
  } finally { saving.value = false }
}

// ────── Invoice detail
const invDetailDialog = ref(false)
const invDetail = ref(null)
async function openInvoiceDetail(inv) {
  invDetail.value = inv
  invDetailDialog.value = true
  try {
    const { data: full } = await $api.get(`/billing/invoices/${inv.id}/`)
    invDetail.value = full
  } catch { /* keep summary */ }
}

// ────── Status updates
async function updateStatus(inv, status) {
  saving.value = true
  try {
    await $api.patch(`/billing/invoices/${inv.id}/`, { status })
    notify(`Marked as ${status}`)
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
  finally { saving.value = false }
}
async function bulkUpdateStatus(status) {
  saving.value = true
  try {
    await Promise.allSettled(
      selected.value.map(id => $api.patch(`/billing/invoices/${id}/`, { status }))
    )
    notify(`${selected.value.length} invoice(s) updated`)
    selected.value = []
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Bulk update failed', 'error') }
  finally { saving.value = false }
}

// ────── Duplicate
async function duplicateInvoice(inv) {
  saving.value = true
  try {
    const payload = {
      patient: inv.patient,
      consultation: inv.consultation,
      items: inv.items || [],
      tax: inv.tax,
      discount: inv.discount,
      due_date: inv.due_date,
      notes: inv.notes,
      status: 'draft',
    }
    await $api.post('/billing/invoices/', payload)
    notify('Invoice duplicated')
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Failed to duplicate', 'error') }
  finally { saving.value = false }
}

// ────── Delete
const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(inv) { deleteTarget.value = inv; deleteDialog.value = true }
async function deleteInvoice() {
  if (!deleteTarget.value) return
  saving.value = true
  try {
    await $api.delete(`/billing/invoices/${deleteTarget.value.id}/`)
    notify('Invoice deleted')
    deleteDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { saving.value = false }
}

// ────── Print
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}
function printInvoice(inv) {
  const itemsHtml = (inv.items || []).map(it => `
    <tr>
      <td style="padding:6px 8px;border-bottom:1px solid #eee">${escapeHtml(it.description || '')}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right">${it.quantity}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right">${formatMoney(it.unit_price)}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right">${formatMoney(it.total)}</td>
    </tr>`).join('')
  const html = `<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(inv.invoice_number)}</title>
    <style>body{font-family:system-ui,Segoe UI,Arial;padding:32px;color:#111}
      h1{margin:0 0 4px;font-size:22px}.muted{color:#777;font-size:12px}
      .totals{margin-top:16px;width:300px;float:right}
      .totals div{display:flex;justify-content:space-between;padding:4px 0}
      table{width:100%;border-collapse:collapse;margin-top:16px}
      th{text-align:left;padding:8px;background:#f5f7fb;font-size:12px;text-transform:uppercase;color:#555}
      .badge{display:inline-block;padding:2px 8px;border-radius:12px;background:#eef;color:#225;font-size:11px}
    </style></head><body>
    <div style="display:flex;justify-content:space-between;align-items:start">
      <div><h1>INVOICE</h1>
        <div class="muted">${escapeHtml(inv.invoice_number)} · <span class="badge">${escapeHtml(inv.status || '')}</span></div>
      </div>
      <div style="text-align:right">
        <div class="muted">Issued ${formatDate(inv.created_at)}</div>
        ${inv.due_date ? `<div class="muted">Due ${formatDate(inv.due_date)}</div>` : ''}
      </div>
    </div>
    <div style="margin-top:24px">
      <div class="muted">BILL TO</div>
      <div style="font-weight:600">${escapeHtml(inv.patient_name || '—')}</div>
    </div>
    <table><thead><tr><th>Description</th><th style="text-align:right">Qty</th>
      <th style="text-align:right">Unit</th><th style="text-align:right">{{ $t('common.total') }}</th></tr></thead>
      <tbody>${itemsHtml || '<tr><td colspan="4" style="padding:12px;text-align:center;color:#999">No line items</td></tr>'}</tbody>
    </table>
    <div class="totals">
      <div><span>{{ $t('common.subtotal') }}</span><span>${formatMoney(inv.subtotal)}</span></div>
      <div><span>{{ $t('common.tax') }}</span><span>${formatMoney(inv.tax)}</span></div>
      <div><span>{{ $t('common.discount') }}</span><span>− ${formatMoney(inv.discount)}</span></div>
      <div style="font-weight:700;border-top:1px solid #ddd;margin-top:6px;padding-top:6px"><span>{{ $t('common.total') }}</span><span>${formatMoney(inv.total)}</span></div>
      <div style="color:#0a0"><span>{{ $t('common.paid') }}</span><span>${formatMoney(inv.amount_paid)}</span></div>
      <div style="font-weight:700;color:#c00"><span>{{ $t('common.balance') }}</span><span>${formatMoney(invoiceBalance(inv))}</span></div>
    </div>
    <div style="clear:both;margin-top:32px" class="muted">${escapeHtml(inv.notes || '')}</div>
    <script>window.onload=()=>setTimeout(()=>window.print(),200)<\/script>
  </body></html>`
  const w = window.open('', '_blank')
  if (!w) { notify('Allow popups to print invoice', 'warning'); return }
  w.document.write(html); w.document.close()
}

// ────── CSV export
function exportCsv() {
  const rows = filteredInvoices.value.map(i =>
    [i.invoice_number, i.patient_name || '', i.total, i.amount_paid, invoiceBalance(i),
     i.due_date || '', i.status, i.created_at])
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const header = ['Invoice', 'Patient', 'Total', 'Paid', 'Balance', 'Due', 'Status', 'Created']
  const lines = [header.join(',')]
  rows.forEach(r => lines.push(r.map(c => typeof c === 'string' ? JSON.stringify(c) : c).join(',')))
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `invoices-${new Date().toISOString().slice(0, 10)}.csv`; a.click()
  URL.revokeObjectURL(url)
}

// ────── Helpers / snackbar
function sumBy(arr, key) { return arr.reduce((s, x) => s + Number(x?.[key] || 0), 0) }
function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

.bucket { cursor: pointer; transition: transform 0.15s ease, box-shadow 0.15s ease; }
.bucket:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.08); }
.bucket-active {
  border-color: rgb(var(--v-theme-primary)) !important;
  box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.2);
}
.bulk-bar { background: rgba(99, 102, 241, 0.06); }
</style>
