<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Requisitions"
      subtitle="Demand-driven buying signals raised from stock cover and reorder points"
      eyebrow="PROCUREMENT · DEMAND PLANNING"
      icon="mdi-clipboard-list-outline"
      color="orange"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn variant="tonal" color="orange" rounded="lg" class="text-none" prepend-icon="mdi-autorenew"
               :loading="generating" @click="generate">Re-scan stock</v-btn>
        <v-btn variant="tonal" color="purple" rounded="lg" class="text-none" prepend-icon="mdi-file-document-plus"
               :disabled="!selected.length" @click="raiseRfq">Raise RFQ</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-cart-plus"
               :disabled="!selected.length" @click="raisePo">Create PO</v-btn>
      </template>
    </ProcToolbar>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3" xl="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- Coverage explanation -->
    <v-alert type="info" variant="tonal" rounded="lg" class="my-3" icon="mdi-lightbulb-on-outline">
      Requisitions are generated automatically whenever an item's on-hand quantity reaches its reorder level. Select lines and
      convert them into a purchase order or an RFQ with one click — the system carries the recommended supplier and last unit cost forward.
    </v-alert>

    <!-- Filters -->
    <v-card rounded="lg" class="pa-3 mb-3" border>
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search"
          placeholder="Search item…"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
          bg-color="surface" prepend-inner-icon="mdi-magnify" clearable
          class="flex-grow-1" style="min-width: 220px"
        />
        <v-select
          v-model="statusFilter"
          :items="statusOptions"
          item-title="label" item-value="value"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg" bg-color="surface"
          prepend-inner-icon="mdi-progress-check" style="max-width: 190px"
        />
        <v-select
          v-model="urgencyFilter"
          :items="urgencyOptions"
          item-title="label" item-value="value"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg" bg-color="surface"
          prepend-inner-icon="mdi-alert-outline" style="max-width: 180px"
        />
        <v-select
          v-model="supplierFilter"
          :items="supplierOptions"
          item-title="label" item-value="value"
          variant="solo-filled" density="comfortable" hide-details flat rounded="lg" bg-color="surface"
          prepend-inner-icon="mdi-truck-delivery" style="max-width: 210px" clearable
        />
        <v-spacer />
        <v-chip size="small" variant="tonal" color="primary">
          {{ selected.length }} selected · {{ formatMoney(selectedValue) }}
        </v-chip>
      </div>
    </v-card>

    <!-- Empty -->
    <EmptyState
      v-if="!loading && !filtered.length"
      icon="mdi-clipboard-check-outline"
      title="No requisitions"
      :message="requisitions.length ? 'Try a different filter.' : 'Stock cover is healthy — nothing needs replenishing.'"
    />

    <!-- Table -->
    <v-card v-else rounded="lg" border>
      <v-data-table
        v-model="selected"
        :headers="headers"
        :items="filtered"
        :loading="loading"
        item-value="id"
        show-select
        :items-per-page="25"
        :items-per-page-options="[10, 25, 50, 100]"
        density="comfortable"
        hover
      >
        <template #item.index="{ index }">
          <span class="text-caption text-medium-emphasis">{{ index + 1 }}</span>
        </template>
        <template #item.itemName="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" :color="urgencyColor(item.urgency)" variant="tonal">
              <v-icon size="14">{{ item.urgency === 'critical' ? 'mdi-alert-octagon' : 'mdi-pill' }}</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium text-truncate" style="max-width: 230px">{{ item.itemName }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.recommended_supplier_name || 'No supplier linked' }}</div>
            </div>
          </div>
        </template>
        <template #item.current_quantity="{ item }">
          <div class="d-flex align-center ga-2">
            <span class="font-weight-bold" :class="num(item.current_quantity) <= 0 ? 'text-error' : ''">
              {{ num(item.current_quantity) }}
            </span>
            <v-progress-linear
              :model-value="coveragePct(item)"
              :color="urgencyColor(item.urgency)"
              height="5"
              rounded
              style="min-width: 60px; max-width: 90px"
            />
          </div>
        </template>
        <template #item.reorder_level="{ item }">
          <span class="text-medium-emphasis">{{ num(item.reorder_level) }}</span>
        </template>
        <template #item.qty="{ item }">
          <span class="font-weight-bold text-primary">+{{ Math.round(item.qty) }}</span>
        </template>
        <template #item.unitCost="{ item }">{{ item.unitCost ? formatMoney(item.unitCost) : '—' }}</template>
        <template #item.estimatedCost="{ item }">
          <span class="font-weight-medium">{{ formatMoney(item.estimatedCost) }}</span>
        </template>
        <template #item.urgency="{ item }">
          <v-chip size="small" :color="urgencyColor(item.urgency)" variant="tonal" class="text-capitalize">
            {{ item.urgency }}
          </v-chip>
        </template>
        <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn icon="mdi-cart-plus" size="x-small" variant="text" color="primary"
                   :to="`/ims/purchase-orders/new?stock=${item.stock}`" title="Create purchase order" />
            <v-btn icon="mdi-check" size="x-small" variant="text" color="success"
                   :loading="busy === item.id" title="Mark as ordered" @click="markOrdered(item)" />
            <v-btn icon="mdi-close" size="x-small" variant="text" color="error"
                   :loading="busy === item.id" title="Dismiss" @click="dismiss(item)" />
          </div>
        </template>
        <template #no-data>
          <div class="py-8 text-center text-medium-emphasis">No requisitions match the filters.</div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Bulk convert dialog -->
    <v-dialog v-model="convertDialog" max-width="1100" scrollable>
      <v-card rounded="lg" class="convert-dialog-card">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">{{ convertMode === 'po' ? 'mdi-cart-plus' : 'mdi-file-document-plus' }}</v-icon>
          {{ convertMode === 'po' ? 'Create purchase orders' : 'Raise request for quotation' }}
        </v-card-title>
        <v-card-subtitle>
          {{ selected.length }} line{{ selected.length === 1 ? '' : 's' }} ·
          {{ formatMoney(dialogTotalValue) }} estimated
        </v-card-subtitle>
        <v-card-text>
          <v-alert v-if="convertMode === 'po'" type="warning" variant="tonal" density="compact" class="mb-3 text-caption">
            Lines are grouped by recommended supplier — one purchase order will be created per supplier.
          </v-alert>
          <v-alert v-if="convertError" type="error" variant="tonal" density="compact" class="mb-3 text-caption">
            {{ convertError }}
          </v-alert>
          <div v-for="g in editableGroups" :key="g.supplier" class="mb-3">
            <div class="d-flex align-center mb-1">
              <v-icon size="16" color="primary" class="mr-1">mdi-truck-outline</v-icon>
              <span class="text-body-2 font-weight-bold">{{ g.supplier }}</span>
              <v-spacer />
              <span class="text-caption text-medium-emphasis">
                {{ g.items.length }} line{{ g.items.length === 1 ? '' : 's' }} · {{ formatMoney(groupTotal(g)) }}
              </span>
            </div>
            <!-- Supplier picker for groups without a recommended supplier.
                 The PurchaseOrder model rejects a null supplier FK with a 400. -->
            <v-select
              v-if="convertMode === 'po' && !g.supplierId"
              v-model="supplierOverrides[g.supplier]"
              :items="supplierOptions"
              item-title="label"
              item-value="value"
              label="Select supplier for this group"
              variant="outlined"
              density="compact"
              hide-details
              prepend-inner-icon="mdi-truck-delivery"
              class="mb-2"
              style="max-width: 360px"
            />
            <v-table density="compact" class="bg-transparent">
              <thead v-if="convertMode === 'po'">
                <tr>
                  <th style="width: 40px">#</th>
                  <th>Item</th>
                  <th class="text-right" style="width: 160px">Qty</th>
                  <th class="text-right" style="width: 120px">Unit cost</th>
                  <th class="text-right" style="width: 120px">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(i, idx) in g.items" :key="i.id">
                  <td class="text-center text-caption text-medium-emphasis" style="width: 40px">{{ idx + 1 }}</td>
                  <td class="text-truncate" style="max-width: 200px">
                    {{ i.itemName }}
                    <div class="text-caption text-medium-emphasis">{{ num(i.current_quantity) }} on hand</div>
                  </td>
                  <!-- RFQ mode: read-only -->
                  <td v-if="convertMode === 'rfq'" class="text-right font-weight-medium">+{{ Math.round(i.qty) }}</td>
                  <td v-if="convertMode === 'rfq'" class="text-right">{{ formatMoney(i.estimatedCost) }}</td>
                  <!-- PO mode: editable -->
                  <td v-if="convertMode === 'po'" class="py-1" style="min-width: 150px">
                    <v-text-field
                      v-model.number="i.editQty"
                      type="number"
                      variant="outlined"
                      density="compact"
                      hide-details
                      prefix="+"
                      class="qty-input"
                      style="width: 160px"
                    />
                  </td>
                  <td v-if="convertMode === 'po'" class="py-1">
                    <v-text-field
                      v-model.number="i.editUnitCost"
                      type="number"
                      variant="outlined"
                      density="compact"
                      hide-details
                      class="cost-input"
                    />
                  </td>
                  <td v-if="convertMode === 'po'" class="text-right font-weight-medium">
                    {{ formatMoney(lineTotal(i)) }}
                  </td>
                </tr>
              </tbody>
            </v-table>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="() => { convertDialog = false; supplierOverrides = {}; editableGroups = [] }">Cancel</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            class="text-none"
            :loading="converting"
            :disabled="convertMode === 'po' && !canConvert"
            @click="confirmConvert"
          >
            {{ convertMode === 'po' ? `Create ${editableGroups.length} PO${editableGroups.length === 1 ? '' : 's'}` : 'Continue to RFQ' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum, compactNumber } from '~/utils/bi'

const { $api } = useNuxtApp()
const {
  loading, requisitions, suppliers, branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const search = ref('')
const statusFilter = ref('pending')
const urgencyFilter = ref('all')
const supplierFilter = ref(null)
const selected = ref([])
const busy = ref(null)
const generating = ref(false)
const converting = ref(false)
const convertDialog = ref(false)
const convertMode = ref('po')

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Ordered', value: 'ordered' },
  { label: 'Dismissed', value: 'dismissed' },
  { label: 'All statuses', value: 'all' }
]
const urgencyOptions = [
  { label: 'All urgency', value: 'all' },
  { label: 'Critical', value: 'critical' },
  { label: 'High', value: 'high' },
  { label: 'Normal', value: 'normal' }
]
const supplierOptions = computed(() => [
  { label: 'All suppliers', value: null },
  ...suppliers.value.map((s) => ({ label: s.name, value: s.id }))
])

const filtered = computed(() =>
  requisitions.value.filter((r) => {
    if (statusFilter.value !== 'all' && r.status !== statusFilter.value) return false
    if (urgencyFilter.value !== 'all' && r.urgency !== urgencyFilter.value) return false
    if (supplierFilter.value != null && r.recommended_supplier !== supplierFilter.value) return false
    if (search.value) {
      const q = search.value.toLowerCase()
      if (!String(r.itemName || '').toLowerCase().includes(q)) return false
    }
    return true
  })
)

const headers = [
  { title: '#', key: 'index', sortable: false, align: 'center', width: '50px' },
  { title: 'Item', key: 'itemName', sortable: true },
  { title: 'On hand', key: 'current_quantity', align: 'start' },
  { title: 'Reorder at', key: 'reorder_level', align: 'end' },
  { title: 'Suggested', key: 'qty', align: 'end' },
  { title: 'Unit cost', key: 'unitCost', align: 'end' },
  { title: 'Value', key: 'estimatedCost', align: 'end' },
  { title: 'Urgency', key: 'urgency', align: 'center' },
  { title: 'Status', key: 'status', align: 'center' },
  { title: '', key: 'actions', align: 'end', sortable: false }
]

const selectedRows = computed(() => requisitions.value.filter((r) => selected.value.includes(r.id)))
const selectedValue = computed(() => sum(selectedRows.value, (r) => r.estimatedCost))

const kpis = computed(() => {
  const pending = requisitions.value.filter((r) => r.status === 'pending')
  const critical = pending.filter((r) => r.urgency === 'critical')
  const high = pending.filter((r) => r.urgency === 'high')
  return [
    { title: 'Pending lines', value: String(pending.length), valueNum: pending.length, icon: 'mdi-clipboard-list-outline', color: 'orange', hint: 'Awaiting decision' },
    { title: 'Estimated value', value: formatMoney(sum(pending, (r) => r.estimatedCost)), valueNum: sum(pending, (r) => r.estimatedCost), icon: 'mdi-cash-multiple', color: 'primary', hint: 'At last-known cost' },
    { title: 'Critical (zero stock)', value: String(critical.length), valueNum: critical.length, icon: 'mdi-alert-octagon', color: 'error', invertDelta: true, hint: 'Cannot fulfil demand' },
    { title: 'High priority', value: String(high.length), valueNum: high.length, icon: 'mdi-alert-outline', color: 'warning', invertDelta: true, hint: 'Below half the reorder level' },
    { title: 'Ordered', value: String(requisitions.value.filter((r) => r.status === 'ordered').length), icon: 'mdi-cart-check', color: 'success', hint: 'Converted to purchasing' },
    { title: 'Suppliers involved', value: String(new Set(pending.map((r) => r.recommended_supplier).filter(Boolean)).size), icon: 'mdi-truck-outline', color: 'teal', hint: 'Recommended sources' }
  ]
})

const groupedSelection = computed(() => {
  const map = new Map()
  for (const r of selectedRows.value) {
    const key = r.recommended_supplier_name || 'Unassigned supplier'
    if (!map.has(key)) {
      map.set(key, {
        supplier: key,
        supplierId: r.recommended_supplier || null,
        items: [],
        value: 0
      })
    }
    const g = map.get(key)
    g.items.push(r)
    g.value += r.estimatedCost
  }
  return [...map.values()]
})

// Per-group supplier overrides for groups whose recommended supplier is null
// (the PurchaseOrder model rejects a null supplier FK with a 400). Keyed by
// the group's display name so re-computing `groupedSelection` doesn't lose
// state when selectedRows changes. Cleared when the dialog closes.
const supplierOverrides = ref({})
const convertError = ref('')

// Editable deep-copy of `groupedSelection` — built when the dialog opens so
// the user can tweak qty / unit cost before committing. Each item carries
// `editQty` and `editUnitCost` number fields; the line total and group totals
// are derived from those, not from the original requisition values.
const editableGroups = ref([])

function lineTotal(i) {
  return (num(i.editQty) || 0) * (num(i.editUnitCost) || 0)
}
function groupTotal(g) {
  return sum(g.items, lineTotal)
}
const dialogTotalValue = computed(() =>
  sum(editableGroups.value, groupTotal)
)

function buildEditableGroups() {
  editableGroups.value = groupedSelection.value.map((g) => ({
    ...g,
    items: g.items.map((r) => ({
      ...r,
      editQty: Math.round(r.qty),
      editUnitCost: r.unitCost || 0,
    })),
  }))
}

function effectiveSupplierId(g) {
  if (g.supplierId) return g.supplierId
  return supplierOverrides.value[g.supplier] || null
}

const canConvert = computed(() =>
  editableGroups.value.length > 0 &&
  editableGroups.value.every((g) => effectiveSupplierId(g) != null)
)

function urgencyColor(u) {
  return u === 'critical' ? 'error' : u === 'high' ? 'warning' : 'info'
}
function coveragePct(r) {
  const level = num(r.reorder_level) || 1
  return Math.max(0, Math.min(100, (num(r.current_quantity) / level) * 100))
}

async function markOrdered(r) {
  busy.value = r.id
  try {
    await $api.post(`/purchase-orders/reorder-suggestions/${r.id}/mark_ordered/`)
    r.status = 'ordered'
  } finally {
    busy.value = null
  }
}

async function dismiss(r) {
  busy.value = r.id
  try {
    await $api.post(`/purchase-orders/reorder-suggestions/${r.id}/dismiss/`)
    r.status = 'dismissed'
    selected.value = selected.value.filter((id) => id !== r.id)
  } finally {
    busy.value = null
  }
}

async function generate() {
  generating.value = true
  try {
    await $api.post('/purchase-orders/reorder-suggestions/generate/', { branch: branchFilter.value || undefined })
    await load()
  } finally {
    generating.value = false
  }
}

function raisePo() {
  convertMode.value = 'po'
  convertError.value = ''
  buildEditableGroups()
  convertDialog.value = true
}
function raiseRfq() {
  convertMode.value = 'rfq'
  convertError.value = ''
  buildEditableGroups()
  convertDialog.value = true
}

async function confirmConvert() {
  if (convertMode.value === 'rfq') {
    // Hand off to the RFQ builder with the selected lines pre-filled.
    const payload = editableGroups.value
      .flatMap((g) => g.items)
      .map((i) => ({ stock: i.stock, name: i.itemName, qty: num(i.editQty) || 0 }))
    if (import.meta.client) sessionStorage.setItem('procurement.rfqDraft', JSON.stringify(payload))
    convertDialog.value = false
    navigateTo('/ims/purchase-orders/rfqs/new')
    return
  }

  converting.value = true
  convertError.value = ''
  try {
    // Create one PO per supplier group, then mark the source suggestions ordered.
    for (const g of editableGroups.value) {
      const supplierId = effectiveSupplierId(g)
      if (!supplierId) {
        convertError.value = `Group "${g.supplier}" has no supplier selected.`
        return
      }
      const items = g.items.map((i) => ({
        medication_stock_id: i.stock,
        name: i.itemName,
        qty: num(i.editQty) || 0,
        unit_cost: num(i.editUnitCost) || 0,
        total: lineTotal(i),
      }))
      const groupVal = groupTotal(g)
      try {
        // eslint-disable-next-line no-await-in-loop
        await $api.post('/purchase-orders/orders/', {
          supplier: supplierId,
          items,
          total_cost: groupVal,
          status: 'draft',
          branch: branchFilter.value || null,
          notes: `Auto-generated from ${g.items.length} requisition line(s).`
        })
      } catch (err) {
        const detail = err?.response?.data
        const msg = typeof detail === 'string'
          ? detail
          : (detail?.supplier?.[0] || detail?.detail || err?.message || JSON.stringify(detail || {}))
        convertError.value = `Failed to create PO for ${g.supplier}: ${msg}`
        return
      }
      for (const i of g.items) {
        // eslint-disable-next-line no-await-in-loop
        await $api.post(`/purchase-orders/reorder-suggestions/${i.id}/mark_ordered/`).catch(() => {})
        const orig = requisitions.value.find((r) => r.id === i.id)
        if (orig) orig.status = 'ordered'
      }
    }
    selected.value = []
    supplierOverrides.value = {}
    editableGroups.value = []
    convertDialog.value = false
    await load()
  } finally {
    converting.value = false
  }
}

void compactNumber
</script>

<style scoped>
.qty-input :deep(input) { text-align: right; }
.cost-input :deep(input) { text-align: right; }
.qty-input, .cost-input { font-size: 13px; }
.qty-input { width: 160px; }
.cost-input { width: 110px; }
.convert-dialog-card {
  min-height: 60vh;
  display: flex;
  flex-direction: column;
}
.convert-dialog-card :deep(.v-card-text) {
  flex: 1 1 auto;
  overflow-y: auto;
  max-height: 65vh;
}
</style>
