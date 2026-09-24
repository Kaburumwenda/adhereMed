<template>
  <v-container fluid class="pa-4 pa-md-6 so-list-shell">
    <PageHeader title="Sales Orders" icon="mdi-receipt-text-plus" subtitle="Manage customer orders, deliveries and payments">
      <template #actions>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" @click="refresh" :loading="loading">Refresh</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-file-chart-outline" :loading="exporting === 'report'" @click="downloadReport">Report (PDF)</v-btn>
        <v-btn variant="tonal" color="success" rounded="lg" class="text-none" prepend-icon="mdi-microsoft-excel" :loading="exporting === 'excel'" @click="exportOrders('excel')">Export Excel</v-btn>
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-file-delimited" :loading="exporting === 'csv'" @click="exportOrders('csv')">Export CSV</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/sales-orders/new">New SO</v-btn>
      </template>
    </PageHeader>

    <!-- Stat cards -->
    <v-row dense class="mb-2">
      <v-col v-for="s in statCards" :key="s.key" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 so-stat" :class="`so-stat-${s.key}`">
          <div class="d-flex align-center mb-2">
            <v-icon :color="s.color" class="mr-2">{{ s.icon }}</v-icon>
            <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">{{ s.label }}</div>
          </div>
          <div class="text-h5 font-weight-bold">{{ s.value }}</div>
          <div v-if="s.sub" class="text-caption text-medium-emphasis mt-1">{{ s.sub }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters -->
    <v-card rounded="lg" class="pa-3 mb-3 so-filter-bar">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search"
          placeholder="Search SO #, customer…"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          prepend-inner-icon="mdi-magnify"
          bg-color="surface"
          clearable
          class="flex-grow-1"
          style="min-width: 220px"
        />
        <v-select
          v-model="statusFilter"
          :items="statusFilterOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-progress-check"
          style="max-width: 200px; min-width: 170px"
        />
        <v-select
          v-model="paymentFilter"
          :items="paymentFilterOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-cash-check"
          style="max-width: 200px; min-width: 170px"
        />
        <v-select
          v-if="branchStore.hasBranches"
          v-model="branchFilter"
          :items="branchFilterItems"
          item-title="name"
          item-value="id"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          :disabled="isBranchLocked"
          prepend-inner-icon="mdi-store-marker"
          style="max-width: 220px; min-width: 180px"
        />
        <v-select
          v-model="datePreset"
          :items="dateOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-calendar-range"
          style="max-width: 200px; min-width: 170px"
        />
        <template v-if="datePreset === 'custom'">
          <v-text-field v-model="dateFrom" label="From" type="date" variant="solo-filled" density="comfortable"
                        hide-details flat rounded="lg" bg-color="surface" style="max-width: 170px" />
          <v-text-field v-model="dateTo" label="To" type="date" variant="solo-filled" density="comfortable"
                        hide-details flat rounded="lg" bg-color="surface" style="max-width: 170px" />
        </template>
      </div>
    </v-card>

    <!-- Body -->
    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>
    <EmptyState
      v-else-if="!filtered.length"
      icon="mdi-receipt-text-plus-outline"
      title="No sales orders"
      :message="search || statusFilter !== 'all' || paymentFilter !== 'all' ? 'Try a different filter or search term.' : 'Create your first sales order to get started.'"
    >
      <template #actions>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/sales-orders/new" class="text-none">New SO</v-btn>
      </template>
    </EmptyState>

    <!-- Table -->
    <v-card v-else rounded="lg" class="so-table-card">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :items-per-page="20"
        :items-per-page-options="[10, 20, 50, 100]"
        density="comfortable"
        hover
        class="so-data-table"
        @click:row="(_, { item }) => goDetail(item)"
      >
        <template #item.rowIndex="{ item }">
          <span class="text-caption text-medium-emphasis">{{ filtered.findIndex(p => p.id === item.id) + 1 }}</span>
        </template>
        <template #item.so_number="{ item }">
          <span class="font-weight-bold text-primary">{{ item.so_number }}</span>
        </template>
        <template #item.customer_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(item.customer_name) }}</span>
            </v-avatar>
            <div>
              <div>{{ item.customer_name || '—' }}</div>
              <div v-if="item.customer_phone" class="text-caption text-medium-emphasis">{{ item.customer_phone }}</div>
            </div>
          </div>
        </template>
        <template #item.items="{ item }">
          <v-chip size="small" variant="tonal" color="primary">{{ (item.items || []).length }}</v-chip>
        </template>
        <template #item.total_amount="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.total_amount) }}</span>
        </template>
        <template #item.amount_paid="{ item }">
          <span :class="Number(item.amount_paid) > 0 ? 'text-success' : 'text-disabled'">{{ formatMoney(item.amount_paid) }}</span>
        </template>
        <template #item.balance_due="{ item }">
          <span :class="Number(item.balance_due) > 0 ? 'font-weight-bold text-error' : 'text-disabled'">{{ formatMoney(item.balance_due) }}</span>
        </template>
        <template #item.payment_status="{ item }">
          <v-chip size="small" :color="paymentColor(item.payment_status)" variant="tonal">{{ paymentLabel(item.payment_status) }}</v-chip>
        </template>
        <template #item.status="{ item }">
          <v-menu :close-on-content-click="true" location="bottom center">
            <template #activator="{ props: menuProps }">
              <v-chip
                v-bind="menuProps"
                size="small"
                variant="tonal"
                :color="soStatusMeta(item.status).color"
                append-icon="mdi-menu-down"
                :loading="statusUpdatingId === item.id"
                class="text-capitalize"
                title="Click to change status"
              >
                <v-icon start size="14">{{ soStatusMeta(item.status).icon }}</v-icon>
                {{ item.status?.replace(/_/g, ' ') || '—' }}
              </v-chip>
            </template>
            <v-list density="compact" class="so-status-list">
              <v-list-subheader class="text-caption">Change status</v-list-subheader>
              <v-list-item
                v-for="s in soStatuses"
                :key="s.value"
                :active="s.value === item.status"
                @click="changeStatus(item, s.value)"
              >
                <template #prepend>
                  <v-icon :color="s.color" size="18">{{ s.icon }}</v-icon>
                </template>
                <v-list-item-title>{{ s.label }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">{{ s.desc }}</v-list-item-subtitle>
                <template #append>
                  <v-icon v-if="s.value === item.status" size="16">mdi-check</v-icon>
                </template>
              </v-list-item>
            </v-list>
          </v-menu>
        </template>
        <template #item.expected_delivery="{ item }">
          <span v-if="item.expected_delivery">{{ formatDate(item.expected_delivery) }}</span>
          <span v-else class="text-disabled">—</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn icon="mdi-receipt-text-outline" size="x-small" variant="text" color="teal" title="Download Sales Order (PDF)" :loading="pdfId === item.id" @click.stop="downloadSoPdf(item)" />
            <v-btn icon="mdi-eye-outline" size="x-small" variant="text" :to="`/sales-orders/${item.id}`" @click.stop />
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/sales-orders/${item.id}/edit`" @click.stop />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="400" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Sales Order
        </v-card-title>
        <v-card-text>
          Delete <b>{{ deleteDialog.so?.so_number }}</b>? This cannot be undone.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="deleteDialog.busy" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const router = useRouter()
const branchStore = useBranchStore()
const auth = useAuthStore()
const r = useResource('/sales-orders/orders/')

const isBranchLocked = computed(() => auth.role === 'branch_admin')
const branchFilter = ref(null)
const branchFilterItems = computed(() => {
  if (isBranchLocked.value) {
    const b = branchStore.currentBranch
    return b ? [{ id: b.id, name: b.name }] : []
  }
  const items = branchStore.activeBranches.map(b => ({ id: b.id, name: b.name }))
  items.unshift({ id: null, name: 'All Branches' })
  return items
})

const items = computed(() => r.items.value)
const loading = computed(() => r.loading.value)

const search = ref('')
const statusFilter = ref('all')
const paymentFilter = ref('all')
const datePreset = ref('all')
const dateFrom = ref(null)
const dateTo = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })
const deleteDialog = reactive({ show: false, so: null, busy: false })
const exporting = ref('')
const pdfId = ref(null)

const statusFilterOptions = [
  { label: 'All statuses', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Partially Fulfilled', value: 'partial' },
  { label: 'Fulfilled', value: 'fulfilled' },
  { label: 'Cancelled', value: 'cancelled' },
]

const paymentFilterOptions = [
  { label: 'All payments', value: 'all' },
  { label: 'Unpaid', value: 'unpaid' },
  { label: 'Partially Paid', value: 'partial' },
  { label: 'Paid', value: 'paid' },
]

const dateOptions = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'This week', value: 'week' },
  { label: 'This month', value: 'month' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'Last 90 days', value: '90d' },
  { label: 'This year', value: 'year' },
  { label: 'Custom range', value: 'custom' },
]

function isoDate(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function resolveDateRange() {
  if (datePreset.value === 'all') return {}
  if (datePreset.value === 'custom') {
    const out = {}
    if (dateFrom.value) out.date_from = dateFrom.value
    if (dateTo.value) out.date_to = dateTo.value
    return out
  }
  const now = new Date()
  const to = isoDate(now)
  let from = now
  if (datePreset.value === 'today') {
    from = now
  } else if (datePreset.value === 'week') {
    from = new Date(now)
    from.setDate(now.getDate() - ((now.getDay() + 6) % 7))
  } else if (datePreset.value === 'month') {
    from = new Date(now.getFullYear(), now.getMonth(), 1)
  } else if (datePreset.value === '30d') {
    from = new Date(now)
    from.setDate(now.getDate() - 30)
  } else if (datePreset.value === '90d') {
    from = new Date(now)
    from.setDate(now.getDate() - 90)
  } else if (datePreset.value === 'year') {
    from = new Date(now.getFullYear(), 0, 1)
  }
  return { date_from: isoDate(from), date_to: to }
}

const filtered = computed(() => {
  let arr = items.value
  if (statusFilter.value !== 'all') arr = arr.filter(s => s.status === statusFilter.value)
  if (paymentFilter.value !== 'all') arr = arr.filter(s => s.payment_status === paymentFilter.value)
  const q = (search.value || '').toLowerCase().trim()
  if (q) arr = arr.filter(s =>
    (s.so_number || '').toLowerCase().includes(q) ||
    (s.customer_name || '').toLowerCase().includes(q) ||
    (s.customer_phone || '').includes(q)
  )
  return arr
})

const statCards = computed(() => {
  const all = items.value
  const open = all.filter(s => ['draft', 'confirmed', 'partial'].includes(s.status))
  const fulfilled = all.filter(s => s.status === 'fulfilled')
  const totalValue = all.reduce((sum, s) => sum + Number(s.total_amount || 0), 0)
  const outstanding = all.reduce((sum, s) => sum + Number(s.balance_due || 0), 0)
  return [
    { key: 'total', label: 'Total Orders', icon: 'mdi-receipt-text-plus-outline', color: 'primary', value: all.length, sub: `${open.length} open` },
    { key: 'fulfilled', label: 'Fulfilled', icon: 'mdi-package-variant-closed-check', color: 'success', value: fulfilled.length, sub: 'completed orders' },
    { key: 'value', label: 'Total Value', icon: 'mdi-cash-multiple', color: 'info', value: formatMoney(totalValue), sub: 'all orders' },
    { key: 'outstanding', label: 'Outstanding', icon: 'mdi-cash-clock', color: 'warning', value: formatMoney(outstanding), sub: 'balance due' },
  ]
})

const headers = [
  { title: '#', key: 'rowIndex', width: 55, sortable: false },
  { title: 'SO #', key: 'so_number', width: 130 },
  { title: 'Customer', key: 'customer_name' },
  { title: 'Items', key: 'items', width: 80, sortable: false, align: 'center' },
  { title: 'Total', key: 'total_amount', width: 120, align: 'end' },
  { title: 'Paid', key: 'amount_paid', width: 110, align: 'end' },
  { title: 'Balance', key: 'balance_due', width: 110, align: 'end' },
  { title: 'Payment', key: 'payment_status', width: 130 },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Delivery', key: 'expected_delivery', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase()
}

function paymentColor(s) { return { unpaid: 'error', partial: 'warning', paid: 'success' }[s] || 'grey' }
function paymentLabel(s) { return { unpaid: 'Unpaid', partial: 'Partially Paid', paid: 'Paid' }[s] || s }

// ── Inline status change ──────────────────────────────────────────
const soStatuses = [
  { value: 'draft', label: 'Draft', color: 'grey', icon: 'mdi-file-document-edit-outline', desc: 'Not yet confirmed by the customer' },
  { value: 'confirmed', label: 'Confirmed', color: 'info', icon: 'mdi-calendar-check', desc: 'Order accepted — a delivery is created' },
  { value: 'partial', label: 'Partially Fulfilled', color: 'warning', icon: 'mdi-progress-alert', desc: 'Some items have been delivered' },
  { value: 'fulfilled', label: 'Fulfilled', color: 'success', icon: 'mdi-package-variant-closed-check', desc: 'Delivered — items deducted from stock' },
  { value: 'cancelled', label: 'Cancelled', color: 'error', icon: 'mdi-cancel', desc: 'Order void — reserved stock is released' },
]

function soStatusMeta(s) {
  return soStatuses.find(x => x.value === s) || { color: 'grey', icon: 'mdi-circle-medium' }
}

const statusUpdatingId = ref(null)

async function changeStatus(so, status) {
  if (status === so.status || statusUpdatingId.value) return
  statusUpdatingId.value = so.id
  try {
    await $api.patch(`/sales-orders/orders/${so.id}/`, { status })
    snack.text = `${so.so_number} marked ${soStatusMeta(status).label.toLowerCase()}`
    snack.color = 'success'
    snack.show = true
    await refresh()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Status update failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    statusUpdatingId.value = null
  }
}

function goDetail(so) { router.push(`/sales-orders/${so.id}`) }

async function refresh() {
  const params = { ...resolveDateRange() }
  if (branchFilter.value) params.branch = branchFilter.value
  await r.list(params)
}

async function exportOrders(fmt) {
  exporting.value = fmt
  try {
    const params = { fmt, ...resolveDateRange() }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (paymentFilter.value !== 'all') params.payment_status = paymentFilter.value
    if (branchFilter.value) params.branch = branchFilter.value
    const blob = (await $api.get('/sales-orders/orders/export/', { params, responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `sales_orders_${new Date().toISOString().slice(0, 10)}.${fmt === 'excel' ? 'xlsx' : 'csv'}`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Export download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'Export failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exporting.value = ''
  }
}

async function downloadReport() {
  exporting.value = 'report'
  try {
    const params = { ...resolveDateRange() }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (paymentFilter.value !== 'all') params.payment_status = paymentFilter.value
    if (branchFilter.value) params.branch = branchFilter.value
    const blob = (await $api.get('/sales-orders/orders/report-pdf/', { params, responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `sales_orders_report_${new Date().toISOString().slice(0, 10)}.pdf`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Report download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'Report download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exporting.value = ''
  }
}

async function downloadSoPdf(so) {
  pdfId.value = so.id
  try {
    const blob = (await $api.get(`/sales-orders/orders/${so.id}/so-pdf/`, { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `sales_order_${so.so_number || so.id}.pdf`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Sales order download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'PDF download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    pdfId.value = null
  }
}

function confirmDelete(so) {
  deleteDialog.so = so
  deleteDialog.show = true
}

async function doDelete() {
  if (!deleteDialog.so) return
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.so.id)
    snack.text = 'Sales order deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.show = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Delete failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleteDialog.busy = false
  }
}

watch(branchFilter, () => refresh())
watch(datePreset, () => refresh())
watch(dateFrom, () => { if (datePreset.value === 'custom') refresh() })
watch(dateTo, () => { if (datePreset.value === 'custom') refresh() })
onMounted(() => {
  if (isBranchLocked.value && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  }
  refresh()
})
</script>

<style scoped>
.so-list-shell { max-width: 1500px; margin: 0 auto; }

.so-stat {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  position: relative;
  overflow: hidden;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.so-stat::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: rgb(var(--v-theme-primary));
}
.so-stat-fulfilled::before { background: rgb(var(--v-theme-success)); }
.so-stat-value::before { background: rgb(var(--v-theme-info)); }
.so-stat-outstanding::before { background: rgb(var(--v-theme-warning)); }
.so-stat:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }

.so-filter-bar { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }
.so-table-card {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  overflow: hidden;
}
.so-data-table :deep(tbody tr) { cursor: pointer; }
.so-data-table :deep(tbody tr:hover) { background: rgba(99, 102, 241, 0.05); }

.so-status-list { min-width: 280px; }
</style>
