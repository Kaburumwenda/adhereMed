<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="green-darken-3" size="32">mdi-clipboard-check-multiple</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Dispensing</div>
              <div class="text-body-2" style="opacity:0.9">
                Prescription-based medication issue · Auto stock deduction · Patient labels.
              </div>
              <div class="text-caption mt-1" style="opacity:0.85">
                <v-icon size="14" class="mr-1">mdi-information-outline</v-icon>
                For walk-in / OTC retail sales without a prescription, use
                <NuxtLink to="/pos" class="text-white font-weight-bold" style="text-decoration:underline">Point of Sale</NuxtLink>.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-green-darken-3"
                 prepend-icon="mdi-plus" :to="'/dispensing/new'">New Dispense</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-refresh"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
        </v-col>
      </v-row>

      <v-row class="mt-4" dense>
        <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="36" class="mr-3">
                <v-icon color="white" size="20">{{ k.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <v-row dense>
      <!-- Filters + table -->
      <v-col cols="12" lg="8">
        <v-card flat rounded="xl" class="pa-3 mb-3" border>
          <v-row dense align="center">
            <v-col cols="12" md="5">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                            placeholder="Search by patient, phone, receipt…" density="comfortable"
                            hide-details variant="solo-filled" flat clearable />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="status" :items="statusOptions" item-title="label" item-value="value"
                        label="Status" density="comfortable" hide-details variant="outlined" />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="payment" :items="paymentOptions" item-title="label" item-value="value"
                        label="Payment" density="comfortable" hide-details variant="outlined" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="dateRange" :items="dateOptions" item-title="label" item-value="value"
                        label="Date" density="comfortable" hide-details variant="outlined" />
            </v-col>
          </v-row>
        </v-card>

        <v-card flat rounded="xl" border>
          <v-data-table :headers="headers" :items="filtered" :loading="loading"
                        items-per-page="15" density="comfortable" class="dispense-table">
            <template #item.receipt_number="{ item }">
              <div class="font-weight-bold">{{ item.receipt_number || `#${item.id}` }}</div>
              <div class="text-caption text-medium-emphasis">{{ formatDate(item.dispensed_at) }}</div>
            </template>
            <template #item.patient_name="{ item }">
              <div class="font-weight-medium">{{ item.patient_name }}</div>
              <div v-if="item.patient_phone" class="text-caption text-medium-emphasis">{{ item.patient_phone }}</div>
            </template>
            <template #item.item_count="{ item }">
              <v-chip size="small" variant="tonal" color="indigo">
                <v-icon start size="14">mdi-pill</v-icon>{{ item.item_count }} items
              </v-chip>
            </template>
            <template #item.payment_method="{ item }">
              <v-chip size="small" variant="tonal" :color="paymentColor(item.payment_method)">
                <v-icon start size="14">{{ paymentIcon(item.payment_method) }}</v-icon>
                {{ paymentLabel(item.payment_method) }}
              </v-chip>
            </template>
            <template #item.total="{ item }">
              <div class="font-weight-bold">KSh {{ Number(item.total).toLocaleString() }}</div>
            </template>
            <template #item.status="{ item }">
              <v-chip size="small" variant="flat"
                      :color="item.status === 'completed' ? 'success' : 'grey'">
                {{ item.status }}
              </v-chip>
            </template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-receipt-text" variant="text" size="small" @click="openReceipt(item)" />
              <v-btn icon="mdi-printer" variant="text" size="small" @click="printReceipt(item)" />
              <v-btn v-if="item.status === 'completed'" icon="mdi-cancel" variant="text"
                     size="small" color="error" @click="confirmVoid(item)" />
            </template>
            <template #no-data>
              <div class="text-center pa-6">
                <v-icon size="48" color="grey-lighten-1">mdi-clipboard-text-off</v-icon>
                <div class="text-body-2 mt-2">No dispensing records yet.</div>
                <v-btn color="primary" class="mt-3" :to="'/dispensing/new'" prepend-icon="mdi-plus">
                  Create first dispense
                </v-btn>
              </div>
            </template>
          </v-data-table>
        </v-card>
      </v-col>

      <!-- Side: Top items + recent activity -->
      <v-col cols="12" lg="4">
        <v-card flat rounded="xl" border class="pa-4 mb-3">
          <div class="d-flex align-center mb-3">
            <v-icon color="amber-darken-2" class="mr-2">mdi-trophy</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Top Items This Month</div>
          </div>
          <v-list v-if="(stats.top_items || []).length" density="compact">
            <v-list-item v-for="(it, i) in stats.top_items" :key="i">
              <template #prepend>
                <v-avatar :color="topColor(i)" size="32" class="mr-2">
                  <span class="text-caption font-weight-bold text-white">{{ i + 1 }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ it.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ it.qty }} units · KSh {{ Number(it.revenue).toLocaleString() }}</v-list-item-subtitle>
            </v-list-item>
          </v-list>
          <div v-else class="text-caption text-medium-emphasis text-center py-4">
            No sales data yet this month.
          </div>
        </v-card>

        <v-card flat rounded="xl" border class="pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon color="primary" class="mr-2">mdi-chart-line</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Quick Stats</div>
          </div>
          <div class="d-flex justify-space-between py-2">
            <span class="text-body-2 text-medium-emphasis">Today's revenue</span>
            <span class="font-weight-bold">KSh {{ Number(stats.today_revenue || 0).toLocaleString() }}</span>
          </div>
          <v-divider />
          <div class="d-flex justify-space-between py-2">
            <span class="text-body-2 text-medium-emphasis">Month revenue</span>
            <span class="font-weight-bold">KSh {{ Number(stats.month_revenue || 0).toLocaleString() }}</span>
          </div>
          <v-divider />
          <div class="d-flex justify-space-between py-2">
            <span class="text-body-2 text-medium-emphasis">All-time revenue</span>
            <span class="font-weight-bold">KSh {{ Number(stats.total_revenue || 0).toLocaleString() }}</span>
          </div>
          <v-divider />
          <div class="d-flex justify-space-between py-2">
            <span class="text-body-2 text-medium-emphasis">All-time receipts</span>
            <span class="font-weight-bold">{{ stats.total_count || 0 }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Receipt dialog -->
    <v-dialog v-model="receiptDialog" max-width="520">
      <v-card v-if="active" rounded="xl" class="receipt">
        <div class="receipt-header text-center pa-5">
          <v-icon size="44" color="white">mdi-receipt-text-check</v-icon>
          <div class="text-h6 font-weight-bold text-white mt-2">{{ active.receipt_number || '—' }}</div>
          <div class="text-body-2 text-white" style="opacity:0.85">
            {{ formatDateTime(active.dispensed_at) }}
          </div>
        </div>
        <v-card-text class="pa-5">
          <div class="d-flex justify-space-between mb-1">
            <span class="text-medium-emphasis">Patient</span>
            <span class="font-weight-medium">{{ active.patient_name }}</span>
          </div>
          <div v-if="active.patient_phone" class="d-flex justify-space-between mb-1">
            <span class="text-medium-emphasis">Phone</span>
            <span>{{ active.patient_phone }}</span>
          </div>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-medium-emphasis">Dispensed by</span>
            <span>{{ active.dispensed_by_name || '—' }}</span>
          </div>

          <v-divider class="my-2" />
          <div class="text-overline mb-2">Items</div>
          <div v-for="(it, i) in active.items_dispensed || []" :key="i" class="d-flex justify-space-between py-1">
            <div>
              <div class="font-weight-medium">{{ it.medication_name }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ it.qty }} × KSh {{ Number(it.unit_price).toLocaleString() }}
                <span v-if="it.batch_number"> · Batch {{ it.batch_number }}</span>
              </div>
            </div>
            <div class="font-weight-bold">KSh {{ Number(it.line_total).toLocaleString() }}</div>
          </div>

          <v-divider class="my-2" />
          <div class="d-flex justify-space-between"><span>Subtotal</span><span>KSh {{ Number(active.subtotal).toLocaleString() }}</span></div>
          <div v-if="Number(active.discount) > 0" class="d-flex justify-space-between text-error">
            <span>Discount</span><span>− KSh {{ Number(active.discount).toLocaleString() }}</span>
          </div>
          <div class="d-flex justify-space-between text-h6 font-weight-bold mt-1">
            <span>Total</span><span>KSh {{ Number(active.total).toLocaleString() }}</span>
          </div>
          <div class="d-flex justify-space-between mt-2">
            <span class="text-medium-emphasis">Payment ({{ paymentLabel(active.payment_method) }})</span>
            <span>KSh {{ Number(active.paid_amount).toLocaleString() }}</span>
          </div>
          <div v-if="active.change_due > 0" class="d-flex justify-space-between text-success font-weight-bold">
            <span>Change</span><span>KSh {{ Number(active.change_due).toLocaleString() }}</span>
          </div>

          <div v-if="active.notes" class="mt-3 pa-2 bg-grey-lighten-4 rounded">
            <div class="text-caption text-medium-emphasis">Notes</div>
            <div class="text-body-2">{{ active.notes }}</div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="receiptDialog = false">Close</v-btn>
          <v-btn color="primary" prepend-icon="mdi-printer" @click="printReceipt(active)">Print</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Void confirm -->
    <v-dialog v-model="voidDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Void this dispense?</v-card-title>
        <v-card-text>
          This will mark <strong>{{ target?.receipt_number }}</strong> as cancelled and restock the items.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="voidDialog = false">Cancel</v-btn>
          <v-btn color="error" :loading="voiding" @click="doVoid">Void</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const records = ref([])
const stats = ref({})
const search = ref('')
const status = ref('all')
const payment = ref('all')
const dateRange = ref('all')

const receiptDialog = ref(false)
const active = ref(null)
const voidDialog = ref(false)
const target = ref(null)
const voiding = ref(false)
const snack = ref({ show: false, color: 'success', text: '' })

const statusOptions = [
  { label: 'All', value: 'all' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]
const paymentOptions = [
  { label: 'All', value: 'all' },
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Card', value: 'card' },
  { label: 'Insurance', value: 'insurance' },
  { label: 'Credit', value: 'credit' },
]
const dateOptions = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'Last 7 days', value: '7d' },
  { label: 'Last 30 days', value: '30d' },
]

const headers = [
  { title: 'Receipt', key: 'receipt_number', width: 160 },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Items', key: 'item_count', width: 110 },
  { title: 'Payment', key: 'payment_method', width: 130 },
  { title: 'Total', key: 'total', width: 130, align: 'end' },
  { title: 'Status', key: 'status', width: 110 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 150 },
]

const kpis = computed(() => [
  { label: "Today's Dispenses", value: stats.value.today_count || 0, icon: 'mdi-calendar-today', color: 'green' },
  { label: "Today's Revenue", value: 'KSh ' + Number(stats.value.today_revenue || 0).toLocaleString(), icon: 'mdi-cash', color: 'teal' },
  { label: 'This Month', value: 'KSh ' + Number(stats.value.month_revenue || 0).toLocaleString(), icon: 'mdi-chart-bar', color: 'indigo' },
  { label: 'Total Records', value: stats.value.total_count || 0, icon: 'mdi-database', color: 'purple' },
])

const filtered = computed(() => {
  const s = (search.value || '').toLowerCase().trim()
  const now = new Date()
  return records.value.filter(r => {
    if (status.value !== 'all' && r.status !== status.value) return false
    if (payment.value !== 'all' && r.payment_method !== payment.value) return false
    if (dateRange.value !== 'all') {
      const d = new Date(r.dispensed_at)
      if (dateRange.value === 'today' && d.toDateString() !== now.toDateString()) return false
      if (dateRange.value === '7d' && (now - d) > 7 * 86400000) return false
      if (dateRange.value === '30d' && (now - d) > 30 * 86400000) return false
    }
    if (!s) return true
    return [r.patient_name, r.patient_phone, r.receipt_number]
      .filter(Boolean).some(v => v.toString().toLowerCase().includes(s))
  })
})

async function loadAll() {
  loading.value = true
  try {
    const [recs, st] = await Promise.all([
      $api.get('/dispensing/').then(r => r.data?.results || r.data || []),
      $api.get('/dispensing/stats/').then(r => r.data || {}).catch(() => ({})),
    ])
    records.value = recs
    stats.value = st
  } catch (e) {
    showSnack('Failed to load records', 'error')
  } finally {
    loading.value = false
  }
}

function openReceipt(r) { active.value = r; receiptDialog.value = true }
function confirmVoid(r) { target.value = r; voidDialog.value = true }

async function doVoid() {
  if (!target.value) return
  voiding.value = true
  try {
    await $api.post(`/dispensing/${target.value.id}/void/`)
    showSnack('Dispense voided', 'success')
    voidDialog.value = false
    await loadAll()
  } catch (e) {
    showSnack('Failed to void', 'error')
  } finally {
    voiding.value = false
  }
}

function printReceipt(r) {
  const win = window.open('', '_blank', 'width=420,height=600')
  if (!win) return
  const items = (r.items_dispensed || []).map(it => `
    <tr>
      <td>${it.medication_name}<br><small>${it.qty} × KSh ${Number(it.unit_price).toLocaleString()}</small></td>
      <td style="text-align:right">KSh ${Number(it.line_total).toLocaleString()}</td>
    </tr>`).join('')
  win.document.write(`<!doctype html><html><head><title>${r.receipt_number}</title>
    <style>body{font-family:monospace;font-size:12px;padding:12px;max-width:320px;margin:auto}
    h2{text-align:center;margin:4px 0} .muted{color:#666;font-size:11px}
    table{width:100%;border-collapse:collapse} td{padding:4px 0;vertical-align:top}
    .row{display:flex;justify-content:space-between;padding:2px 0} hr{border:0;border-top:1px dashed #999;margin:6px 0}
    .total{font-weight:bold;font-size:14px}</style></head><body>
    <h2>${r.receipt_number || ''}</h2>
    <div class="muted" style="text-align:center">${new Date(r.dispensed_at).toLocaleString()}</div>
    <hr>
    <div class="row"><span>Patient:</span><span>${r.patient_name}</span></div>
    ${r.patient_phone ? `<div class="row"><span>Phone:</span><span>${r.patient_phone}</span></div>` : ''}
    <hr><table>${items}</table><hr>
    <div class="row"><span>Subtotal</span><span>KSh ${Number(r.subtotal).toLocaleString()}</span></div>
    ${Number(r.discount) > 0 ? `<div class="row"><span>Discount</span><span>− KSh ${Number(r.discount).toLocaleString()}</span></div>` : ''}
    <div class="row total"><span>Total</span><span>KSh ${Number(r.total).toLocaleString()}</span></div>
    <div class="row"><span>Paid (${r.payment_method})</span><span>KSh ${Number(r.paid_amount).toLocaleString()}</span></div>
    ${r.change_due > 0 ? `<div class="row"><span>Change</span><span>KSh ${Number(r.change_due).toLocaleString()}</span></div>` : ''}
    <hr><div style="text-align:center" class="muted">Thank you!</div>
    <script>window.print()<\/script></body></html>`)
  win.document.close()
}

function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
function paymentColor(p) { return ({ cash: 'green', mpesa: 'teal', card: 'blue', insurance: 'purple', credit: 'orange' }[p] || 'grey') }
function paymentIcon(p) { return ({ cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card', insurance: 'mdi-shield-account', credit: 'mdi-account-cash' }[p] || 'mdi-cash') }
function paymentLabel(p) { return (paymentOptions.find(o => o.value === p) || {}).label || p }
function topColor(i) { return ['amber-darken-2', 'grey', 'orange-darken-3', 'blue', 'teal'][i] || 'grey' }
function formatDate(d) { return d ? new Date(d).toLocaleDateString() : '' }
function formatDateTime(d) { return d ? new Date(d).toLocaleString() : '' }

onMounted(loadAll)
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #14532d 0%, #16a34a 50%, #4ade80 100%);
}
.kpi {
  background: rgba(255, 255, 255, 0.1) !important;
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255, 255, 255, 0.15);
}
.kpi :deep(.text-h6) { color: #fff; }
.kpi :deep(.text-medium-emphasis) { color: rgba(255, 255, 255, 0.85) !important; }
.dispense-table { font-size: 0.92rem; }
.receipt-header {
  background: linear-gradient(135deg, #14532d, #16a34a);
}
.receipt { overflow: hidden; }
</style>
