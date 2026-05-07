<template>
  <v-container fluid class="pa-4 pa-md-6 exp-shell">
    <PageHeader title="Expenses" icon="mdi-cash-minus" subtitle="Track, approve and pay business expenses">
      <template #actions>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-shape-outline" to="/expenses/categories">Categories</v-btn>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="reload">Refresh</v-btn>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-download" @click="exportCsv">Export</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/expenses/new">New Expense</v-btn>
      </template>
    </PageHeader>

    <!-- KPI cards -->
    <v-row dense class="mb-2">
      <v-col v-for="s in statCards" :key="s.key" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 exp-stat" :class="`exp-stat-${s.key}`">
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
    <v-card rounded="lg" class="pa-3 mb-3 exp-filter-bar">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search"
          placeholder="Search reference, title, vendor…"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
          prepend-inner-icon="mdi-magnify" bg-color="surface" clearable class="flex-grow-1"
          style="min-width: 220px"
        />
        <v-select
          v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
          bg-color="surface" prepend-inner-icon="mdi-progress-check"
          style="max-width: 180px; min-width: 150px"
        />
        <v-select
          v-model="categoryFilter" :items="categoryOptions" item-title="label" item-value="value"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
          bg-color="surface" prepend-inner-icon="mdi-shape" clearable
          style="max-width: 200px; min-width: 160px"
        />
        <v-select
          v-model="methodFilter" :items="methodOptions" item-title="label" item-value="value"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
          bg-color="surface" prepend-inner-icon="mdi-credit-card-outline" clearable
          style="max-width: 180px; min-width: 150px"
        />
        <v-text-field
          v-model="dateFrom" type="date" label="From" variant="solo-filled" density="comfortable"
          hide-details flat rounded="lg" bg-color="surface" style="max-width: 170px"
        />
        <v-text-field
          v-model="dateTo" type="date" label="To" variant="solo-filled" density="comfortable"
          hide-details flat rounded="lg" bg-color="surface" style="max-width: 170px"
        />
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
      icon="mdi-cash-remove"
      title="No expenses"
      :message="hasFilters ? 'Try a different filter or search.' : 'Record your first expense.'"
    >
      <template #actions>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/expenses/new" class="text-none">New Expense</v-btn>
      </template>
    </EmptyState>

    <v-card v-else-if="viewMode === 'table'" rounded="lg" class="exp-table-card">
      <v-data-table
        :headers="headers" :items="filtered" :items-per-page="20"
        :items-per-page-options="[10, 20, 50, 100]" density="comfortable" hover
        class="exp-data-table" @click:row="(_, { item }) => goDetail(item)"
      >
        <template #item.reference="{ item }">
          <span class="font-weight-bold text-primary">{{ item.reference }}</span>
        </template>
        <template #item.title="{ item }">
          <div class="font-weight-medium">{{ item.title }}</div>
          <div v-if="item.vendor" class="text-caption text-medium-emphasis">{{ item.vendor }}</div>
        </template>
        <template #item.category_name="{ item }">
          <v-chip v-if="item.category_name" size="small" variant="tonal" color="primary">
            {{ item.category_name }}
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.amount="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.total_amount || item.amount) }}</span>
        </template>
        <template #item.payment_method="{ item }">
          <v-chip size="x-small" variant="tonal">{{ methodLabel(item.payment_method) }}</v-chip>
        </template>
        <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
        <template #item.expense_date="{ item }">{{ formatDate(item.expense_date) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn icon="mdi-eye-outline" size="x-small" variant="text" :to="`/expenses/${item.id}`" @click.stop />
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/expenses/${item.id}/edit`" @click.stop />
            <v-btn v-if="item.status === 'pending'" icon="mdi-check-circle-outline" size="x-small" variant="text" color="success" title="Approve" @click.stop="quickApprove(item)" />
            <v-btn v-if="['pending','approved'].includes(item.status)" icon="mdi-cash-check" size="x-small" variant="text" color="info" title="Mark paid" @click.stop="quickPay(item)" />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <v-row v-else dense>
      <v-col v-for="exp in filtered" :key="exp.id" cols="12" sm="6" lg="4">
        <v-card rounded="lg" class="exp-card-tile pa-4" @click="goDetail(exp)">
          <div class="d-flex align-center justify-space-between mb-2">
            <div>
              <div class="text-caption text-medium-emphasis">{{ exp.reference }}</div>
              <div class="text-h6 font-weight-bold">{{ exp.title }}</div>
            </div>
            <StatusChip :status="exp.status" />
          </div>
          <div v-if="exp.category_name" class="mb-1">
            <v-chip size="x-small" variant="tonal" color="primary">{{ exp.category_name }}</v-chip>
          </div>
          <div class="text-body-2 text-medium-emphasis mb-2 text-truncate">{{ exp.vendor || '—' }}</div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between align-center">
            <div>
              <div class="text-caption text-medium-emphasis">Date</div>
              <div>{{ formatDate(exp.expense_date) }}</div>
            </div>
            <div class="text-end">
              <div class="text-caption text-medium-emphasis">Amount</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(exp.total_amount || exp.amount) }}</div>
            </div>
          </div>
          <div class="d-flex justify-end ga-1 mt-2">
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/expenses/${exp.id}/edit`" @click.stop />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(exp)" />
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="deleteDialog.show" max-width="400" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Expense
        </v-card-title>
        <v-card-text>Delete <b>{{ deleteDialog.exp?.reference }}</b>? This cannot be undone.</v-card-text>
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

const { $api } = useNuxtApp()
const router = useRouter()
const r = useResource('/expenses/expenses/')
const cats = useResource('/expenses/categories/')

const loading = computed(() => r.loading.value)
const items = computed(() => r.items.value)

const search = ref('')
const statusFilter = ref('all')
const categoryFilter = ref(null)
const methodFilter = ref(null)
const dateFrom = ref('')
const dateTo = ref('')
const viewMode = ref('table')
const snack = reactive({ show: false, color: 'success', text: '' })
const deleteDialog = reactive({ show: false, exp: null, busy: false })

const statusOptions = [
  { label: 'All statuses', value: 'all' },
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Paid', value: 'paid' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'Cancelled', value: 'cancelled' },
]
const methodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Bank Transfer', value: 'bank' },
  { label: 'Card', value: 'card' },
  { label: 'Cheque', value: 'cheque' },
  { label: 'Other', value: 'other' },
]
function methodLabel(v) { return methodOptions.find(o => o.value === v)?.label || v }

const categoryOptions = computed(() =>
  (cats.items.value || []).map(c => ({ label: c.name, value: c.id }))
)

const filtered = computed(() => {
  let arr = items.value
  if (statusFilter.value !== 'all') arr = arr.filter(x => x.status === statusFilter.value)
  if (categoryFilter.value) arr = arr.filter(x => x.category === categoryFilter.value)
  if (methodFilter.value) arr = arr.filter(x => x.payment_method === methodFilter.value)
  if (dateFrom.value) arr = arr.filter(x => x.expense_date >= dateFrom.value)
  if (dateTo.value) arr = arr.filter(x => x.expense_date <= dateTo.value)
  const q = (search.value || '').toLowerCase().trim()
  if (q) arr = arr.filter(x =>
    (x.reference || '').toLowerCase().includes(q) ||
    (x.title || '').toLowerCase().includes(q) ||
    (x.vendor || '').toLowerCase().includes(q) ||
    (x.payment_reference || '').toLowerCase().includes(q)
  )
  return arr
})

const hasFilters = computed(() => !!(search.value || categoryFilter.value || methodFilter.value || dateFrom.value || dateTo.value || statusFilter.value !== 'all'))

const statCards = computed(() => {
  const all = items.value
  const total = all.reduce((s, x) => s + Number(x.total_amount || x.amount || 0), 0)
  const pending = all.filter(x => x.status === 'pending')
  const paid = all.filter(x => x.status === 'paid')
  const today = new Date()
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().slice(0, 10)
  const thisMonth = all.filter(x => x.expense_date >= monthStart).reduce((s, x) => s + Number(x.total_amount || x.amount || 0), 0)
  const pendingTotal = pending.reduce((s, x) => s + Number(x.total_amount || x.amount || 0), 0)
  return [
    { key: 'total', label: 'Total Expenses', icon: 'mdi-cash-multiple', color: 'primary', value: formatMoney(total), sub: `${all.length} record${all.length === 1 ? '' : 's'}` },
    { key: 'month', label: 'This Month', icon: 'mdi-calendar-month', color: 'info', value: formatMoney(thisMonth) },
    { key: 'pending', label: 'Pending Approval', icon: 'mdi-progress-clock', color: 'warning', value: pending.length, sub: formatMoney(pendingTotal) },
    { key: 'paid', label: 'Paid', icon: 'mdi-cash-check', color: 'success', value: paid.length, sub: 'Cleared' },
  ]
})

const headers = [
  { title: 'Reference', key: 'reference', width: 130 },
  { title: 'Title / Vendor', key: 'title' },
  { title: 'Category', key: 'category_name', width: 140 },
  { title: 'Amount', key: 'amount', width: 130, align: 'end' },
  { title: 'Method', key: 'payment_method', width: 110 },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Date', key: 'expense_date', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 180 },
]

function goDetail(exp) { router.push(`/expenses/${exp.id}`) }
async function reload() { await Promise.all([r.list(), cats.list()]) }

async function quickApprove(exp) {
  try {
    await $api.post(`/expenses/expenses/${exp.id}/approve/`)
    snack.text = `${exp.reference} approved`; snack.color = 'success'; snack.show = true
    await r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Approve failed.'; snack.color = 'error'; snack.show = true
  }
}
async function quickPay(exp) {
  try {
    await $api.post(`/expenses/expenses/${exp.id}/mark_paid/`)
    snack.text = `${exp.reference} marked paid`; snack.color = 'success'; snack.show = true
    await r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed.'; snack.color = 'error'; snack.show = true
  }
}
function confirmDelete(exp) { deleteDialog.exp = exp; deleteDialog.show = true }
async function doDelete() {
  if (!deleteDialog.exp) return
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.exp.id)
    snack.text = 'Expense deleted'; snack.color = 'success'; snack.show = true
    deleteDialog.show = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Delete failed.'; snack.color = 'error'; snack.show = true
  } finally { deleteDialog.busy = false }
}

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['reference','title','category_name','vendor','amount','tax_amount','total_amount','payment_method','status','expense_date','due_date','payment_reference']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [cols.join(',')].concat(rows.map(r => cols.map(c => esc(r[c])).join(','))).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `expenses-${new Date().toISOString().slice(0,10)}.csv`
  a.click(); URL.revokeObjectURL(url)
}

onMounted(reload)
</script>

<style scoped>
.exp-shell { max-width: 1500px; margin: 0 auto; }
.exp-stat {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  position: relative; overflow: hidden;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.exp-stat::before {
  content: ''; position: absolute; inset: 0 auto 0 0; width: 4px;
  background: rgb(var(--v-theme-primary));
}
.exp-stat-month::before { background: rgb(var(--v-theme-info)); }
.exp-stat-pending::before { background: rgb(var(--v-theme-warning)); }
.exp-stat-paid::before { background: rgb(var(--v-theme-success)); }
.exp-stat:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }

.exp-filter-bar { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }
.exp-table-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); overflow: hidden; }
.exp-data-table :deep(tbody tr) { cursor: pointer; }
.exp-data-table :deep(tbody tr:hover) { background: rgba(99, 102, 241, 0.05); }

.exp-card-tile {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.exp-card-tile:hover {
  transform: translateY(-3px);
  border-color: rgba(99, 102, 241, 0.5);
  box-shadow: 0 8px 22px rgba(99, 102, 241, 0.12);
}
</style>
