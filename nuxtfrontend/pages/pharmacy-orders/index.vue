<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ════════ Hero ════════ -->
    <v-card flat rounded="xl" class="hero pa-5 pa-md-6 mb-4 text-white">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="7">
          <div class="d-flex align-center mb-2">
            <v-avatar color="white" size="44" class="mr-3">
              <v-icon color="indigo-darken-3" size="26">mdi-receipt-text</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold">Patient Orders</div>
              <div class="text-body-2 opacity-90">Walk-in & online pharmacy orders</div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="5">
          <div class="d-flex justify-md-end gap-2 mt-3 mt-md-0 flex-wrap">
            <v-btn color="white" variant="flat" prepend-icon="mdi-refresh"
                   @click="reload" :loading="loading">Refresh</v-btn>
            <v-btn color="white" variant="outlined" prepend-icon="mdi-download"
                   class="text-white" @click="exportCsv">Export CSV</v-btn>
            <v-btn color="white" variant="outlined" prepend-icon="mdi-printer"
                   class="text-white" @click="printPage">Print</v-btn>
          </div>
        </v-col>
      </v-row>
    </v-card>

    <!-- ════════ KPI strip ════════ -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpis" :key="k.label" cols="6" sm="4" md="2">
        <v-card flat rounded="xl" class="kpi-card pa-3"
                @click="filterByStatus(k.statusFilter)" style="cursor:pointer">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption" :class="`text-${k.tone}`">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.tone" size="38" variant="tonal">
              <v-icon :color="k.tone" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ════════ Filters bar ════════ -->
    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                      label="Search order # or patient" variant="outlined"
                      density="comfortable" hide-details clearable
                      style="min-width:240px;flex:1 1 240px" />
        <v-select v-model="statusFilter" :items="statusOptions" label="Status"
                  variant="outlined" density="comfortable" hide-details clearable
                  style="min-width:180px" />
        <v-select v-model="paymentFilter" :items="paymentOptions" label="Payment"
                  variant="outlined" density="comfortable" hide-details clearable
                  style="min-width:160px" />
        <v-select v-model="rangeFilter" :items="rangeOptions" label="Period"
                  variant="outlined" density="comfortable" hide-details
                  style="min-width:160px" />
        <v-btn-toggle v-model="viewMode" color="primary" density="comfortable" mandatory>
          <v-btn value="board" prepend-icon="mdi-view-column">Board</v-btn>
          <v-btn value="list" prepend-icon="mdi-view-list">List</v-btn>
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- ════════ KANBAN BOARD ════════ -->
    <div v-if="viewMode === 'board'" class="board-scroll">
      <div class="board-grid">
        <div v-for="col in columns" :key="col.value" class="board-col">
          <div class="board-col-header" :class="`col-${col.tone}`">
            <div class="d-flex align-center">
              <v-icon :color="col.tone" size="18" class="mr-1">{{ col.icon }}</v-icon>
              <span class="font-weight-bold text-uppercase text-caption">{{ col.label }}</span>
            </div>
            <v-chip size="x-small" variant="flat" :color="col.tone">
              {{ groupedOrders[col.value]?.length || 0 }}
            </v-chip>
          </div>
          <div class="board-col-body">
            <div v-if="loading" class="text-center py-6 text-medium-emphasis">
              <v-progress-circular indeterminate size="20" />
            </div>
            <div v-else-if="!(groupedOrders[col.value]?.length)"
                 class="text-center py-6 text-medium-emphasis text-caption">
              <v-icon size="24">mdi-inbox-outline</v-icon>
              <div>No orders</div>
            </div>
            <v-card v-for="o in groupedOrders[col.value] || []" :key="o.id"
                    flat rounded="lg" class="board-card mb-2 pa-3"
                    @click="openOrder(o)">
              <div class="d-flex align-center justify-space-between">
                <div class="font-weight-bold text-body-2">{{ o.order_number }}</div>
                <v-chip size="x-small" variant="tonal" :color="paymentTone(o.payment_method)">
                  <v-icon size="11" start>{{ paymentIcon(o.payment_method) }}</v-icon>
                  {{ o.payment_method }}
                </v-chip>
              </div>
              <div class="d-flex align-center mt-2">
                <v-avatar :color="avatarColor(o.patient_name)" size="26" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(o.patient_name) }}</span>
                </v-avatar>
                <div style="min-width:0">
                  <div class="text-body-2 font-weight-medium text-truncate">{{ o.patient_name }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    <v-icon size="11">mdi-phone</v-icon> {{ o.patient_phone || '—' }}
                  </div>
                </div>
              </div>
              <v-divider class="my-2" />
              <div class="d-flex justify-space-between align-center">
                <div class="text-caption text-medium-emphasis">
                  <v-icon size="13">mdi-package-variant</v-icon>
                  {{ (o.items || []).length }} item{{ (o.items || []).length === 1 ? '' : 's' }}
                </div>
                <div class="font-weight-bold text-success">{{ formatMoney(o.total) }}</div>
              </div>
              <div v-if="o.delivery_address" class="text-caption text-medium-emphasis mt-1 text-truncate">
                <v-icon size="11">mdi-map-marker</v-icon> {{ o.delivery_address }}
              </div>
              <div class="text-caption text-medium-emphasis mt-1">
                <v-icon size="11">mdi-clock-outline</v-icon> {{ relativeTime(o.created_at) }}
              </div>
              <div class="d-flex mt-2 flex-wrap" style="gap:4px">
                <v-btn v-for="a in nextActions(o)" :key="a.value"
                       size="x-small" variant="tonal" :color="a.color"
                       :prepend-icon="a.icon" @click.stop="advance(o, a.value)">
                  {{ a.label }}
                </v-btn>
              </div>
            </v-card>
          </div>
        </div>
      </div>
    </div>

    <!-- ════════ LIST VIEW ════════ -->
    <v-card v-else flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filteredOrders" :loading="loading"
                    items-per-page="25" density="comfortable" hover>
        <template #item.order_number="{ item }">
          <div class="font-weight-bold">{{ item.order_number }}</div>
          <div class="text-caption text-medium-emphasis">{{ relativeTime(item.created_at) }}</div>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="avatarColor(item.patient_name)" size="28" class="mr-2">
              <span class="text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.patient_name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.patient_phone || '—' }}</div>
            </div>
          </div>
        </template>
        <template #item.items="{ item }">
          <v-chip size="small" variant="tonal" color="indigo">
            {{ (item.items || []).length }} item{{ (item.items || []).length === 1 ? '' : 's' }}
          </v-chip>
        </template>
        <template #item.payment_method="{ item }">
          <v-chip size="small" variant="tonal" :color="paymentTone(item.payment_method)"
                  :prepend-icon="paymentIcon(item.payment_method)">
            {{ item.payment_method }}
          </v-chip>
        </template>
        <template #item.total="{ item }">
          <span class="font-weight-bold text-success">{{ formatMoney(item.total) }}</span>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="flat" :color="statusTone(item.status)">{{ item.status }}</v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn size="small" variant="text" icon="mdi-eye" @click="openOrder(item)" />
        </template>
      </v-data-table>
    </v-card>

    <!-- ════════ Detail dialog ════════ -->
    <v-dialog v-model="detailDialog" max-width="780" scrollable>
      <v-card v-if="selected" rounded="xl">
        <v-toolbar :color="statusTone(selected.status)" density="compact" flat>
          <v-icon class="ml-3">mdi-receipt-text</v-icon>
          <v-toolbar-title class="font-weight-bold">{{ selected.order_number }}</v-toolbar-title>
          <v-spacer />
          <v-chip color="white" :text-color="statusTone(selected.status)" size="small" class="mr-2">
            {{ selected.status }}
          </v-chip>
          <v-btn icon="mdi-close" @click="detailDialog = false" />
        </v-toolbar>
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Patient</div>
              <div class="d-flex align-center mt-1">
                <v-avatar :color="avatarColor(selected.patient_name)" size="40" class="mr-2">
                  <span class="font-weight-bold">{{ initials(selected.patient_name) }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-bold">{{ selected.patient_name }}</div>
                  <div class="text-caption">
                    <v-icon size="13">mdi-phone</v-icon> {{ selected.patient_phone || '—' }}
                  </div>
                </div>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Placed</div>
              <div class="font-weight-medium">{{ formatDateTime(selected.created_at) }}</div>
              <div class="text-caption text-medium-emphasis mt-2">Updated</div>
              <div class="font-weight-medium">{{ formatDateTime(selected.updated_at) }}</div>
            </v-col>
          </v-row>

          <v-row dense class="mt-3">
            <v-col cols="12" md="8">
              <v-card flat rounded="lg" class="pa-3 info-tile">
                <div class="text-caption text-medium-emphasis">Delivery Address</div>
                <div class="font-weight-medium">
                  <v-icon size="16" class="mr-1">mdi-map-marker</v-icon>
                  {{ selected.delivery_address || 'Pickup at counter' }}
                </div>
              </v-card>
            </v-col>
            <v-col cols="12" md="4">
              <v-card flat rounded="lg" class="pa-3 info-tile">
                <div class="text-caption text-medium-emphasis">Payment Method</div>
                <v-chip size="small" variant="tonal" :color="paymentTone(selected.payment_method)"
                        :prepend-icon="paymentIcon(selected.payment_method)" class="mt-1">
                  {{ selected.payment_method }}
                </v-chip>
              </v-card>
            </v-col>
          </v-row>

          <div class="text-overline mt-4 mb-1">Items</div>
          <v-table density="compact" class="items-table">
            <thead>
              <tr>
                <th>Medication</th>
                <th class="text-end">Qty</th>
                <th class="text-end">Unit Price</th>
                <th class="text-end">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, i) in (selected.items || [])" :key="i">
                <td>{{ it.medication_name || it.product_name }}</td>
                <td class="text-end">{{ it.quantity }}</td>
                <td class="text-end">{{ formatMoney(it.unit_price) }}</td>
                <td class="text-end font-weight-medium">
                  {{ formatMoney(it.total ?? (it.quantity || 0) * (it.unit_price || 0)) }}
                </td>
              </tr>
            </tbody>
          </v-table>

          <v-row dense class="mt-3">
            <v-col cols="12" md="6">
              <div v-if="selected.notes" class="text-caption text-medium-emphasis">Notes</div>
              <div v-if="selected.notes" class="text-body-2">{{ selected.notes }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="pa-3 totals-tile">
                <div class="d-flex justify-space-between text-body-2">
                  <span>Subtotal</span><span>{{ formatMoney(selected.subtotal) }}</span>
                </div>
                <div class="d-flex justify-space-between text-body-2 mt-1">
                  <span>Delivery Fee</span><span>{{ formatMoney(selected.delivery_fee) }}</span>
                </div>
                <v-divider class="my-2" />
                <div class="d-flex justify-space-between font-weight-bold">
                  <span>Total</span>
                  <span class="text-success text-h6">{{ formatMoney(selected.total) }}</span>
                </div>
              </v-card>
            </v-col>
          </v-row>

          <div class="text-overline mt-4 mb-2">Order Lifecycle</div>
          <div class="timeline">
            <div v-for="(s, idx) in lifecycleSteps" :key="s.value"
                 class="timeline-step"
                 :class="{
                    'step-done': lifecycleIndex(selected.status) >= idx,
                    'step-current': lifecycleIndex(selected.status) === idx,
                 }">
              <div class="step-dot">
                <v-icon size="14" color="white">{{ s.icon }}</v-icon>
              </div>
              <div class="step-label text-caption">{{ s.label }}</div>
            </div>
          </div>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3 flex-wrap" style="gap:6px">
          <v-btn variant="outlined" prepend-icon="mdi-printer" @click="printOrder(selected)">Print Receipt</v-btn>
          <v-spacer />
          <v-btn v-for="a in nextActions(selected)" :key="a.value"
                 :color="a.color" variant="flat" :prepend-icon="a.icon"
                 :loading="updating === selected.id + ':' + a.value"
                 @click="advance(selected, a.value)">
            {{ a.label }}
          </v-btn>
          <v-btn v-if="selected.status !== 'cancelled' && selected.status !== 'completed'"
                 color="error" variant="text" prepend-icon="mdi-cancel"
                 :loading="updating === selected.id + ':cancelled'"
                 @click="advance(selected, 'cancelled')">
            Cancel Order
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, reactive, onMounted, onBeforeUnmount } from 'vue'
import { formatMoney, formatDateTime } from '~/utils/format'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()

const orders = ref([])
const loading = ref(false)
const search = ref('')
const statusFilter = ref(null)
const paymentFilter = ref(null)
const rangeFilter = ref('all')
const viewMode = ref('board')
const detailDialog = ref(false)
const selected = ref(null)
const updating = ref(null)
const snack = reactive({ show: false, color: 'success', message: '' })

const statusOptions = [
  { title: 'Pending', value: 'pending' },
  { title: 'Confirmed', value: 'confirmed' },
  { title: 'Processing', value: 'processing' },
  { title: 'Ready', value: 'ready' },
  { title: 'Completed', value: 'completed' },
  { title: 'Cancelled', value: 'cancelled' },
]
const paymentOptions = [
  { title: 'Cash on Delivery', value: 'cash' },
  { title: 'M-Pesa', value: 'mpesa' },
]
const rangeOptions = [
  { title: 'All time', value: 'all' },
  { title: 'Today', value: 'today' },
  { title: 'Last 7 days', value: '7d' },
  { title: 'Last 30 days', value: '30d' },
]
const columns = [
  { value: 'pending', label: 'Pending', tone: 'orange', icon: 'mdi-clock-outline' },
  { value: 'confirmed', label: 'Confirmed', tone: 'blue', icon: 'mdi-check-circle-outline' },
  { value: 'processing', label: 'Processing', tone: 'indigo', icon: 'mdi-cog-sync' },
  { value: 'ready', label: 'Ready', tone: 'teal', icon: 'mdi-package-check' },
  { value: 'completed', label: 'Completed', tone: 'success', icon: 'mdi-check-all' },
  { value: 'cancelled', label: 'Cancelled', tone: 'error', icon: 'mdi-cancel' },
]
const lifecycleSteps = [
  { value: 'pending', label: 'Placed', icon: 'mdi-cart' },
  { value: 'confirmed', label: 'Confirmed', icon: 'mdi-check' },
  { value: 'processing', label: 'Processing', icon: 'mdi-cog' },
  { value: 'ready', label: 'Ready', icon: 'mdi-package' },
  { value: 'completed', label: 'Delivered', icon: 'mdi-truck-check' },
]
const headers = [
  { title: 'Order #', key: 'order_number', width: 160 },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Items', key: 'items', sortable: false, width: 100 },
  { title: 'Payment', key: 'payment_method', width: 140 },
  { title: 'Total', key: 'total', align: 'end' },
  { title: 'Status', key: 'status', width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]

async function reload() {
  loading.value = true
  try {
    const { data } = await $api.get('/exchange/pharmacy/orders/', { params: { page_size: 200 } })
    orders.value = data?.results || data || []
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to load orders', 'error')
  } finally {
    loading.value = false
  }
}

function inSelectedRange(iso) {
  if (rangeFilter.value === 'all') return true
  const d = new Date(iso)
  const now = new Date()
  const diff = (now - d) / (1000 * 60 * 60 * 24)
  if (rangeFilter.value === 'today') return d.toDateString() === now.toDateString()
  if (rangeFilter.value === '7d') return diff <= 7
  if (rangeFilter.value === '30d') return diff <= 30
  return true
}

const filteredOrders = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  return orders.value.filter(o => {
    if (statusFilter.value && o.status !== statusFilter.value) return false
    if (paymentFilter.value && o.payment_method !== paymentFilter.value) return false
    if (!inSelectedRange(o.created_at)) return false
    if (!q) return true
    return (o.order_number || '').toLowerCase().includes(q)
        || (o.patient_name || '').toLowerCase().includes(q)
        || (o.patient_phone || '').toLowerCase().includes(q)
  })
})

const groupedOrders = computed(() => {
  const g = {}
  for (const c of columns) g[c.value] = []
  filteredOrders.value.forEach(o => { if (g[o.status]) g[o.status].push(o) })
  return g
})

function filterByStatus(s) {
  if (s === undefined) return
  statusFilter.value = statusFilter.value === s ? null : s
}

const kpis = computed(() => {
  const today = orders.value.filter(o => new Date(o.created_at).toDateString() === new Date().toDateString())
  const pending = orders.value.filter(o => o.status === 'pending').length
  const processing = orders.value.filter(o => ['confirmed', 'processing'].includes(o.status)).length
  const ready = orders.value.filter(o => o.status === 'ready').length
  const completedToday = today.filter(o => o.status === 'completed')
  const revenueToday = completedToday.reduce((s, o) => s + Number(o.total || 0), 0)
  const cancelled = orders.value.filter(o => o.status === 'cancelled').length
  return [
    { label: 'Today', value: today.length, sub: `${completedToday.length} completed`,
      icon: 'mdi-calendar-today', tone: 'primary', statusFilter: null },
    { label: 'Pending', value: pending, icon: 'mdi-clock-outline',
      tone: 'orange', statusFilter: 'pending' },
    { label: 'In Progress', value: processing, icon: 'mdi-cog-sync',
      tone: 'indigo', statusFilter: 'processing' },
    { label: 'Ready', value: ready, icon: 'mdi-package-check',
      tone: 'teal', statusFilter: 'ready' },
    { label: 'Revenue Today', value: formatMoney(revenueToday),
      icon: 'mdi-cash', tone: 'success', statusFilter: 'completed' },
    { label: 'Cancelled', value: cancelled, icon: 'mdi-cancel',
      tone: 'error', statusFilter: 'cancelled' },
  ]
})

const TRANSITIONS = {
  pending:    [{ value: 'confirmed', label: 'Confirm', color: 'blue', icon: 'mdi-check' }],
  confirmed:  [{ value: 'processing', label: 'Start Processing', color: 'indigo', icon: 'mdi-cog' }],
  processing: [{ value: 'ready', label: 'Mark Ready', color: 'teal', icon: 'mdi-package-check' }],
  ready:      [{ value: 'completed', label: 'Complete', color: 'success', icon: 'mdi-truck-check' }],
  completed:  [],
  cancelled:  [],
}
function nextActions(o) { return TRANSITIONS[o?.status] || [] }

async function advance(order, newStatus) {
  if (!order) return
  if (newStatus === 'cancelled' && !confirm(`Cancel order ${order.order_number}?`)) return
  updating.value = `${order.id}:${newStatus}`
  try {
    const { data } = await $api.patch(`/exchange/pharmacy/orders/${order.id}/status/`, { status: newStatus })
    Object.assign(order, data)
    if (selected.value?.id === order.id) selected.value = { ...data }
    notify(`Order ${order.order_number} → ${newStatus}`)
  } catch (e) {
    notify(e?.response?.data?.detail || 'Status update failed', 'error')
  } finally {
    updating.value = null
  }
}

function openOrder(o) {
  selected.value = { ...o }
  detailDialog.value = true
}

function lifecycleIndex(s) {
  if (s === 'cancelled') return -1
  return lifecycleSteps.findIndex(x => x.value === s)
}

function statusTone(s) {
  return ({ pending: 'orange', confirmed: 'blue', processing: 'indigo',
            ready: 'teal', completed: 'success', cancelled: 'error' })[s] || 'grey'
}
function paymentTone(m) { return ({ cash: 'success', mpesa: 'green' })[m] || 'grey' }
function paymentIcon(m) { return ({ cash: 'mdi-cash', mpesa: 'mdi-cellphone' })[m] || 'mdi-cash' }
function initials(n) {
  if (!n) return '?'
  return n.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('')
}
function avatarColor(name) {
  const palette = ['primary', 'indigo', 'teal', 'deep-purple', 'pink', 'orange', 'cyan', 'green']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function relativeTime(iso) {
  if (!iso) return ''
  const diff = (Date.now() - new Date(iso).getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`
  return new Date(iso).toLocaleDateString()
}
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

function exportCsv() {
  if (!filteredOrders.value.length) { notify('Nothing to export', 'warning'); return }
  const rows = [['Order #', 'Patient', 'Phone', 'Items', 'Payment', 'Subtotal', 'Delivery', 'Total', 'Status', 'Date']]
  filteredOrders.value.forEach(o => rows.push([
    o.order_number, o.patient_name, o.patient_phone || '',
    (o.items || []).length, o.payment_method,
    o.subtotal, o.delivery_fee, o.total, o.status, o.created_at,
  ]))
  const csv = rows.map(r => r.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `pharmacy-orders-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}

function printPage() { window.print() }

function printOrder(o) {
  const w = window.open('', '_blank', 'width=600,height=800')
  if (!w) return
  const itemRows = (o.items || []).map(it =>
    `<tr><td>${it.medication_name || it.product_name || ''}</td>
         <td style="text-align:right">${it.quantity}</td>
         <td style="text-align:right">${formatMoney(it.unit_price)}</td>
         <td style="text-align:right">${formatMoney(it.total ?? (it.quantity || 0) * (it.unit_price || 0))}</td></tr>`
  ).join('')
  w.document.write(`<html><head><title>${o.order_number}</title>
    <style>body{font-family:Arial,sans-serif;padding:20px;max-width:520px;margin:auto;color:#0f172a}
    h2{margin:0 0 4px}table{width:100%;border-collapse:collapse;margin:12px 0}
    th,td{border-bottom:1px solid #e2e8f0;padding:6px;font-size:13px}
    th{background:#f8fafc;text-align:left}.totals div{display:flex;justify-content:space-between;padding:3px 0}
    .grand{font-weight:bold;font-size:16px;border-top:2px solid #0f172a;padding-top:6px}</style></head>
    <body><h2>${o.order_number}</h2><div>${o.pharmacy_name || ''}</div>
    <div>${new Date(o.created_at).toLocaleString()}</div><hr/>
    <div><strong>Patient:</strong> ${o.patient_name}</div>
    <div><strong>Phone:</strong> ${o.patient_phone || '—'}</div>
    <div><strong>Address:</strong> ${o.delivery_address || 'Pickup'}</div>
    <div><strong>Payment:</strong> ${o.payment_method}</div>
    <table><thead><tr><th>Item</th><th style="text-align:right">Qty</th><th style="text-align:right">Unit</th><th style="text-align:right">Total</th></tr></thead><tbody>${itemRows}</tbody></table>
    <div class="totals"><div><span>Subtotal</span><span>${formatMoney(o.subtotal)}</span></div>
    <div><span>Delivery</span><span>${formatMoney(o.delivery_fee)}</span></div>
    <div class="grand"><span>Total</span><span>${formatMoney(o.total)}</span></div></div>
    <p style="text-align:center;margin-top:24px;font-size:12px;color:#64748b">Status: ${o.status}</p>
    </body></html>`)
  w.document.close()
  setTimeout(() => w.print(), 250)
}

let pollTimer
onMounted(() => {
  reload()
  pollTimer = setInterval(reload, 60_000)
})
onBeforeUnmount(() => clearInterval(pollTimer))
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #ec4899 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(99, 102, 241, 0.25);
}
.gap-2 > * + * { margin-left: 8px; }

.kpi-card {
  border: 1px solid rgba(0, 0, 0, 0.06);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.08); }
.v-theme--dark .kpi-card { border-color: rgba(255, 255, 255, 0.08); }

.board-scroll { overflow-x: auto; padding-bottom: 8px; }
.board-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(260px, 1fr));
  gap: 12px;
}
.board-col {
  background: rgba(0, 0, 0, 0.02);
  border-radius: 14px;
  padding: 10px;
  min-height: 240px;
}
.v-theme--dark .board-col { background: rgba(255, 255, 255, 0.03); }
.board-col-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 8px; margin-bottom: 8px; border-radius: 8px;
}
.col-orange  { background: rgba(249, 115, 22, 0.10); }
.col-blue    { background: rgba(59, 130, 246, 0.10); }
.col-indigo  { background: rgba(99, 102, 241, 0.10); }
.col-teal    { background: rgba(20, 184, 166, 0.10); }
.col-success { background: rgba(16, 185, 129, 0.10); }
.col-error   { background: rgba(239, 68, 68, 0.10); }

.board-card {
  cursor: pointer;
  border: 1px solid rgba(0, 0, 0, 0.06);
  background: rgb(var(--v-theme-surface));
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}
.board-card:hover { transform: translateY(-2px); box-shadow: 0 8px 18px rgba(0, 0, 0, 0.08); }
.v-theme--dark .board-card { border-color: rgba(255, 255, 255, 0.08); }

@media (max-width: 1200px) { .board-grid { grid-template-columns: repeat(3, minmax(260px, 1fr)); } }
@media (max-width: 720px)  { .board-grid { grid-template-columns: repeat(2, minmax(240px, 1fr)); } }

.info-tile, .totals-tile {
  background: rgba(0, 0, 0, 0.03);
  border: 1px solid rgba(0, 0, 0, 0.05);
}
.v-theme--dark .info-tile,
.v-theme--dark .totals-tile {
  background: rgba(255, 255, 255, 0.04);
  border-color: rgba(255, 255, 255, 0.08);
}
.items-table :deep(th) { background: rgba(0, 0, 0, 0.03); }
.v-theme--dark .items-table :deep(th) { background: rgba(255, 255, 255, 0.05); }

.timeline {
  display: flex; align-items: center; justify-content: space-between;
  position: relative; padding: 0 8px;
}
.timeline::before {
  content: ''; position: absolute; top: 14px; left: 24px; right: 24px;
  height: 2px; background: rgba(148, 163, 184, 0.3); z-index: 0;
}
.timeline-step {
  display: flex; flex-direction: column; align-items: center;
  position: relative; z-index: 1; flex: 1;
}
.step-dot {
  width: 30px; height: 30px; border-radius: 50%;
  background: rgba(148, 163, 184, 0.4);
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s ease;
}
.step-label { margin-top: 4px; color: rgb(var(--v-theme-on-surface)); opacity: 0.6; }
.step-done .step-dot { background: rgb(var(--v-theme-success)); }
.step-current .step-dot {
  background: rgb(var(--v-theme-primary));
  box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.25);
  transform: scale(1.1);
}
.step-done .step-label { opacity: 1; font-weight: 600; }

@media print {
  .hero, .kpi-card, .board-col-header,
  .v-toolbar, .v-card-actions, .v-btn { display: none !important; }
  .board-grid { grid-template-columns: 1fr !important; }
}
</style>
