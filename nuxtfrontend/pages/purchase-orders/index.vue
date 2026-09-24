<template>
  <v-container fluid class="pa-4 pa-md-6 po-list-shell">
    <PageHeader title="Purchase Orders" icon="mdi-cart" subtitle="Track procurement, deliveries and supplier spend">
      <template #actions>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" @click="refresh" :loading="loading">Refresh</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-file-chart-outline" :loading="exporting === 'report'" @click="downloadReport">Report (PDF)</v-btn>
        <v-btn variant="tonal" color="success" rounded="lg" class="text-none" prepend-icon="mdi-microsoft-excel" :loading="exporting === 'excel'" @click="exportOrders('excel')">Export Excel</v-btn>
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-file-delimited" :loading="exporting === 'csv'" @click="exportOrders('csv')">Export CSV</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/purchase-orders/new">New PO</v-btn>
      </template>
    </PageHeader>

    <!-- Stat cards -->
    <v-row dense class="mb-2">
      <v-col v-for="s in statCards" :key="s.key" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 po-stat" :class="`po-stat-${s.key}`">
          <div class="d-flex align-center mb-2">
            <v-icon :color="s.color" class="mr-2">{{ s.icon }}</v-icon>
            <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">{{ s.label }}</div>
          </div>
          <div class="text-h5 font-weight-bold">{{ s.value }}</div>
          <div v-if="s.sub" class="text-caption text-medium-emphasis mt-1">{{ s.sub }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters / search -->
    <v-card rounded="lg" class="pa-3 mb-3 po-filter-bar">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search"
          placeholder="Search PO #, supplierâ€¦"
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
        >
          <template #item="{ props, item }">
            <v-list-item v-bind="props" :subtitle="item.raw.description || undefined">
              <template v-if="item.raw.value !== 'all'" #prepend>
                <span class="mr-1"><StatusChip :status="item.raw.value" /></span>
              </template>
            </v-list-item>
          </template>
        </v-select>
        <v-select
          v-model="supplierFilter"
          :items="supplierFilterOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-truck-delivery"
          style="max-width: 240px; min-width: 180px"
          clearable
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
          <v-text-field
            v-model="dateFrom"
            label="From"
            type="date"
            variant="solo-filled"
            density="comfortable"
            hide-details
            flat
            rounded="lg"
            bg-color="surface"
            style="max-width: 170px"
          />
          <v-text-field
            v-model="dateTo"
            label="To"
            type="date"
            variant="solo-filled"
            density="comfortable"
            hide-details
            flat
            rounded="lg"
            bg-color="surface"
            style="max-width: 170px"
          />
        </template>
        <v-btn-toggle v-model="viewMode" mandatory density="comfortable" rounded="lg" variant="outlined" color="primary">
          <v-btn value="table" icon="mdi-table" size="small" title="Table view" />
          <v-btn value="cards" icon="mdi-view-grid" size="small" title="Card view" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Body -->
    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>
    <EmptyState
      v-else-if="!filtered.length"
      icon="mdi-cart-outline"
      title="No purchase orders"
      :message="search || statusFilter !== 'all' || supplierFilter ? 'Try a different filter or search term.' : 'Create your first purchase order to get started.'"
    >
      <template #actions>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/purchase-orders/new" class="text-none">New PO</v-btn>
      </template>
    </EmptyState>

    <!-- Table view -->
    <v-card v-else-if="viewMode === 'table'" rounded="lg" class="po-table-card">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :items-per-page="20"
        :items-per-page-options="[10, 20, 50, 100]"
        density="comfortable"
        hover
        class="po-data-table"
        @click:row="(_, { item }) => goDetail(item)"
      >
        <template #item.rowIndex="{ item }">
          <span class="text-caption text-medium-emphasis">{{ filtered.findIndex(p => p.id === item.id) + 1 }}</span>
        </template>
        <template #item.po_number="{ item }">
          <span class="font-weight-bold text-primary">{{ item.po_number }}</span>
        </template>
        <template #item.supplier_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(item.supplier_name) }}</span>
            </v-avatar>
            <span>{{ item.supplier_name || 'â€”' }}</span>
          </div>
        </template>
        <template #item.items="{ item }">
          <v-chip size="small" variant="tonal" color="primary">{{ (item.items || []).length }}</v-chip>
        </template>
        <template #item.total_cost="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.total_cost) }}</span>
        </template>
        <template #item.shipping_cost="{ item }">
          <span v-if="Number(item.shipping_cost) > 0" class="text-medium-emphasis">{{ formatMoney(item.shipping_cost) }}</span>
          <span v-else class="text-disabled">â€”</span>
        </template>
        <template #item.status="{ item }">
          <div class="status-cell" @click.stop>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" variant="text" size="small" class="text-none px-2 status-btn"
                       :loading="updatingStatusId === item.id" :disabled="updatingStatusId === item.id">
                  <StatusChip :status="item.status" />
                  <v-icon size="14" class="ml-1" color="medium-emphasis">mdi-chevron-down</v-icon>
                </v-btn>
              </template>
              <v-list density="compact" min-width="260">
                <v-list-subheader class="text-caption">Change status</v-list-subheader>
                <v-list-item v-for="opt in statusOptions" :key="opt.value"
                             :disabled="opt.value === item.status"
                             density="compact" two-line
                             :append-icon="opt.value === item.status ? 'mdi-check' : undefined"
                             @click="changeStatus(item, opt.value)">
                  <v-list-item-title>
                    <StatusChip :status="opt.value" />
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption text-medium-emphasis">
                    {{ opt.description }}
                  </v-list-item-subtitle>
                </v-list-item>
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #item.order_date="{ item }">{{ formatDate(item.order_date) }}</template>
        <template #item.expected_delivery="{ item }">
          <span v-if="item.expected_delivery">{{ formatDate(item.expected_delivery) }}</span>
          <span v-else class="text-medium-emphasis">â€”</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn icon="mdi-receipt-text-outline" size="x-small" variant="text" color="teal" title="Download Purchase Order (PDF)" :loading="invoicingId === item.id" @click.stop="downloadInvoice(item)" />
            <v-btn icon="mdi-eye-outline" size="x-small" variant="text" :to="`/purchase-orders/${item.id}`" @click.stop />
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/purchase-orders/${item.id}/edit`" @click.stop />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Card view -->
    <v-row v-else dense>
      <v-col v-for="po in filtered" :key="po.id" cols="12" sm="6" lg="4">
        <v-card rounded="lg" class="po-card-tile pa-4" @click="goDetail(po)">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <div class="text-caption text-medium-emphasis">PO Number</div>
              <div class="text-h6 font-weight-bold text-primary">{{ po.po_number }}</div>
            </div>
            <div @click.stop>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" variant="text" size="small" class="text-none px-2"
                         :loading="updatingStatusId === po.id" :disabled="updatingStatusId === po.id">
                    <StatusChip :status="po.status" />
                    <v-icon size="14" class="ml-1" color="medium-emphasis">mdi-chevron-down</v-icon>
                  </v-btn>
                </template>
                <v-list density="compact" min-width="260">
                  <v-list-subheader class="text-caption">Change status</v-list-subheader>
                  <v-list-item v-for="opt in statusOptions" :key="opt.value"
                               :disabled="opt.value === po.status"
                               density="compact" two-line
                               :append-icon="opt.value === po.status ? 'mdi-check' : undefined"
                               @click="changeStatus(po, opt.value)">
                    <v-list-item-title>
                      <StatusChip :status="opt.value" />
                    </v-list-item-title>
                    <v-list-item-subtitle class="text-caption text-medium-emphasis">
                      {{ opt.description }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </v-list>
              </v-menu>
            </div>
          </div>
          <div class="d-flex align-center mb-2 ga-2">
            <v-avatar size="32" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(po.supplier_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-body-2 font-weight-medium text-truncate">{{ po.supplier_name || 'â€”' }}</div>
              <div class="text-caption text-medium-emphasis">{{ formatDate(po.order_date) }}</div>
            </div>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between align-center">
            <div>
              <div class="text-caption text-medium-emphasis">Items</div>
              <div class="font-weight-bold">{{ (po.items || []).length }}</div>
            </div>
            <div class="text-end">
              <div class="text-caption text-medium-emphasis">Total</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(po.total_cost) }}</div>
            </div>
          </div>
          <div v-if="po.expected_delivery" class="text-caption text-medium-emphasis mt-2">
            <v-icon size="14" class="mr-1">mdi-calendar-clock</v-icon>
            Expected {{ formatDate(po.expected_delivery) }}
          </div>
          <div class="d-flex justify-end ga-1 mt-2">
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/purchase-orders/${po.id}/edit`" @click.stop />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(po)" />
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="400" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Purchase Order
        </v-card-title>
        <v-card-text>
          Delete <b>{{ deleteDialog.po?.po_number }}</b>? This cannot be undone.
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
const r = useResource('/purchase-orders/orders/')

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
const supplierFilter = ref(null)
const datePreset = ref('all')
const dateFrom = ref(null)
const dateTo = ref(null)
const viewMode = ref('table')
const snack = reactive({ show: false, color: 'success', text: '' })
const deleteDialog = reactive({ show: false, po: null, busy: false })

const statusFilterOptions = [
  { label: 'All statuses', value: 'all', description: '' },
  { label: 'Draft', value: 'draft', description: 'Being prepared — not sent yet' },
  { label: 'Sent', value: 'sent', description: 'Order placed with the supplier' },
  { label: 'Received', value: 'received', description: 'Fully delivered & stocked in' },
  { label: 'Partially Received', value: 'partial', description: 'Some items delivered so far' },
  { label: 'Returned', value: 'returned', description: 'Goods sent back to the supplier' },
  { label: 'Cancelled', value: 'cancelled', description: 'Order cancelled — no goods expected' },
]
const statusOptions = statusFilterOptions.filter(o => o.value !== 'all')

// â”€â”€ Inline status change (dropdown in the status column) â”€â”€â”€â”€â”€
const updatingStatusId = ref(null)

async function changeStatus(po, newStatus) {
  if (!newStatus || newStatus === po.status || updatingStatusId.value) return
  const prev = po.status
  po.status = newStatus            // optimistic update
  updatingStatusId.value = po.id
  try {
    await $api.patch(`/purchase-orders/orders/${po.id}/`, { status: newStatus })
    snack.text = `${po.po_number} is now "${statusOptions.find(o => o.value === newStatus)?.label || newStatus}"`
    snack.color = 'success'
    snack.show = true
    await refresh()
  } catch (e) {
    po.status = prev               // roll back
    snack.text = e?.response?.data?.detail || 'Failed to update status.'
    snack.color = 'error'
    snack.show = true
  } finally {
    updatingStatusId.value = null
  }
}

const supplierFilterOptions = computed(() => {
  const map = new Map()
  for (const po of items.value) {
    if (po.supplier && po.supplier_name && !map.has(po.supplier)) {
      map.set(po.supplier, { label: po.supplier_name, value: po.supplier })
    }
  }
  return [...map.values()].sort((a, b) => a.label.localeCompare(b.label))
})

const filtered = computed(() => {
  let arr = items.value
  if (statusFilter.value !== 'all') arr = arr.filter(p => p.status === statusFilter.value)
  if (supplierFilter.value) arr = arr.filter(p => p.supplier === supplierFilter.value)
  const q = (search.value || '').toLowerCase().trim()
  if (q) arr = arr.filter(p =>
    (p.po_number || '').toLowerCase().includes(q) ||
    (p.supplier_name || '').toLowerCase().includes(q)
  )
  return arr
})

const statCards = computed(() => {
  const all = items.value
  const totalSpend = all.reduce((s, p) => s + Number(p.total_cost || 0), 0)
  const open = all.filter(p => ['draft', 'sent', 'partial'].includes(p.status))
  const received = all.filter(p => p.status === 'received')
  const pendingValue = open.reduce((s, p) => s + Number(p.total_cost || 0), 0)
  return [
    { key: 'total', label: 'Total Orders', icon: 'mdi-cart-outline', color: 'primary', value: all.length, sub: `${supplierFilterOptions.value.length} suppliers` },
    { key: 'open', label: 'Open Orders', icon: 'mdi-progress-clock', color: 'warning', value: open.length, sub: 'Draft / sent / partial' },
    { key: 'received', label: 'Received', icon: 'mdi-package-variant-closed-check', color: 'success', value: received.length, sub: 'Stock updated' },
    { key: 'spend', label: 'Total Spend', icon: 'mdi-cash-multiple', color: 'info', value: formatMoney(totalSpend), sub: `Pending: ${formatMoney(pendingValue)}` },
  ]
})

const headers = [
  { title: '#', key: 'rowIndex', width: 60, sortable: false },
  { title: 'PO #', key: 'po_number', width: 130 },
  { title: 'Supplier', key: 'supplier_name' },
  { title: 'Items', key: 'items', width: 90, sortable: false, align: 'center' },
  { title: 'Total', key: 'total_cost', width: 120, align: 'end' },
  { title: 'Shipping', key: 'shipping_cost', width: 110, align: 'end' },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Order date', key: 'order_date', width: 120 },
  { title: 'Expected', key: 'expected_delivery', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase()
}

function goDetail(po) { router.push(`/purchase-orders/${po.id}`) }

// â”€â”€ Date filter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    from.setDate(now.getDate() - ((now.getDay() + 6) % 7)) // Monday
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

async function refresh() {
  const params = { ...resolveDateRange() }
  if (branchFilter.value) params.branch = branchFilter.value
  await r.list(params)
}

function confirmDelete(po) {
  deleteDialog.po = po
  deleteDialog.show = true
}

async function doDelete() {
  if (!deleteDialog.po) return
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.po.id)
    snack.text = 'Purchase order deleted'
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

const exporting = ref('')

const invoicingId = ref(null)

async function downloadInvoice(po) {
  invoicingId.value = po.id
  try {
    const blob = (await $api.get(`/purchase-orders/orders/${po.id}/po-pdf/`, { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `purchase_order_${po.po_number || po.id}.pdf`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Invoice download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'Invoice download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    invoicingId.value = null
  }
}

async function downloadReport() {
  exporting.value = 'report'
  try {
    const params = { ...resolveDateRange() }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (supplierFilter.value) params.supplier = supplierFilter.value
    if (branchFilter.value) params.branch = branchFilter.value
    const blob = (await $api.get('/purchase-orders/orders/report-pdf/', { params, responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `purchase_orders_report_${new Date().toISOString().slice(0, 10)}.pdf`
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

async function exportOrders(fmt) {
  exporting.value = fmt
  try {
    const params = { fmt, ...resolveDateRange() }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (supplierFilter.value) params.supplier = supplierFilter.value
    if (branchFilter.value) params.branch = branchFilter.value
    const blob = (await $api.get('/purchase-orders/orders/export/', { params, responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `purchase_orders_${new Date().toISOString().slice(0, 10)}.${fmt === 'excel' ? 'xlsx' : 'csv'}`
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

onMounted(() => {
  if (isBranchLocked.value && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  }
  refresh()
})
</script>

<style scoped>
.po-list-shell { max-width: 1500px; margin: 0 auto; }

.po-stat {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  position: relative;
  overflow: hidden;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.po-stat::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: rgb(var(--v-theme-primary));
}
.po-stat-open::before { background: rgb(var(--v-theme-warning)); }
.po-stat-received::before { background: rgb(var(--v-theme-success)); }
.po-stat-spend::before { background: rgb(var(--v-theme-info)); }
.po-stat:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }

.po-filter-bar {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}

.po-table-card {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  overflow: hidden;
}
.po-data-table :deep(tbody tr) { cursor: pointer; }
.po-data-table :deep(tbody tr:hover) { background: rgba(99, 102, 241, 0.05); }

.po-card-tile {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.po-card-tile:hover {
  transform: translateY(-3px);
  border-color: rgba(99, 102, 241, 0.5);
  box-shadow: 0 8px 22px rgba(99, 102, 241, 0.12);
}

.min-width-0 { min-width: 0; }
</style>
