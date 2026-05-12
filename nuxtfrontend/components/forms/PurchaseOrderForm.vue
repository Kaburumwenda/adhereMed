<template>
  <v-container fluid class="pa-4 pa-md-6 po-shell">
    <PageHeader
      :title="loadId ? `Edit ${form.po_number || 'Purchase Order'}` : 'New Purchase Order'"
      icon="mdi-cart"
      subtitle="Manage stock procurement and receipts"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/purchase-orders">Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" @submit.prevent="onSubmit">
      <!-- Header card -->
      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 po-card">
            <div class="d-flex align-center mb-4">
              <v-icon color="primary" class="mr-2">mdi-file-document-edit-outline</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Order Details</div>
              <v-spacer />
              <v-chip v-if="form.po_number" size="small" color="primary" variant="tonal" prepend-icon="mdi-pound">{{ form.po_number }}</v-chip>
            </div>
            <v-row dense>
              <v-col cols="12" md="6">
                <v-combobox
                  v-model="supplierPick"
                  :items="suppliers"
                  item-title="name"
                  :return-object="true"
                  label="Supplier *"
                  variant="outlined"
                  density="comfortable"
                  prepend-inner-icon="mdi-truck-delivery"
                  :rules="supplierRules"
                  hide-details="auto"
                  hint="Pick from list or type a new supplier name"
                  persistent-hint
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field
                  v-model="form.expected_delivery"
                  label="Expected/Received Delivery"
                  type="date"
                  variant="outlined"
                  density="comfortable"
                  prepend-inner-icon="mdi-calendar"
                  hide-details="auto"
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-select
                  v-model="form.status"
                  :items="statusOptions"
                  item-title="label"
                  item-value="value"
                  label="Status"
                  variant="outlined"
                  density="comfortable"
                  prepend-inner-icon="mdi-progress-check"
                  hide-details="auto"
                />
              </v-col>
            </v-row>
            <v-alert
              v-if="form.status === 'received'"
              type="info"
              variant="tonal"
              density="compact"
              class="mt-3"
              icon="mdi-package-variant-closed-check"
            >
              Saving with status <b>Received</b> will create stock batches and update item quantities, cost, selling price and discount.
            </v-alert>
          </v-card>

          <!-- Items card -->
          <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 po-card">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-package-variant</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Items</div>
              <v-chip v-if="form.items.length" size="x-small" color="primary" variant="tonal" class="ml-2">{{ form.items.length }}</v-chip>
              <v-spacer />
              <v-btn color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" size="small" @click="addItem">Add Item</v-btn>
            </div>

            <EmptyState
              v-if="!form.items.length"
              icon="mdi-cart-outline"
              title="No items yet"
              message="Click 'Add Item' to start building your purchase order."
            />

            <div v-else class="po-items">
              <div v-for="(it, i) in form.items" :key="i" class="po-item-row">
                <div class="po-item-num">{{ i + 1 }}</div>
                <div class="po-item-body">
                  <v-row dense>
                    <v-col cols="12" md="5">
                      <v-combobox
                        v-model="it.pick"
                        :items="stocks"
                        item-title="medication_name"
                        :return-object="true"
                        label="Item *"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        :rules="itemRules"
                        hint="Pick from list or type a new item name"
                        persistent-hint
                        @update:model-value="onPickItem(it, $event)"
                      >
                        <template #item="{ props: ip, item }">
                          <v-list-item v-bind="ip" :title="item.raw.medication_name">
                            <template #subtitle>
                              <div class="d-flex flex-wrap ga-1 align-center">
                                <v-chip size="x-small" variant="tonal" color="primary">Cost {{ formatMoney(item.raw.cost_price) }}</v-chip>
                                <v-chip size="x-small" variant="tonal" color="success">Sell {{ formatMoney(item.raw.selling_price) }}</v-chip>
                                <v-chip v-if="Number(item.raw.discount_percent) > 0" size="x-small" variant="tonal" color="warning">{{ item.raw.discount_percent }}% off</v-chip>
                                <v-chip size="x-small" variant="tonal" :color="(item.raw.total_quantity || 0) <= 0 ? 'error' : 'default'">Stock {{ item.raw.total_quantity || 0 }}</v-chip>
                              </div>
                            </template>
                          </v-list-item>
                        </template>
                      </v-combobox>
                      <div v-if="it.stock_id" class="mt-1 d-flex flex-wrap ga-1">
                        <v-chip size="x-small" variant="flat" color="primary">Sell {{ formatMoney(it.unit_selling_price) }}</v-chip>
                        <v-chip size="x-small" variant="flat" color="info">In stock {{ it._current_stock ?? '—' }}</v-chip>
                        <v-chip size="x-small" variant="flat" color="success">+{{ it.qty || 0 }} after save</v-chip>
                      </div>
                      <div v-else-if="it.name" class="mt-1">
                        <v-chip size="x-small" variant="flat" color="warning" prepend-icon="mdi-plus-circle">New item — will be created on save</v-chip>
                      </div>
                    </v-col>
                    <v-col cols="6" md="2">
                      <v-text-field
                        v-model.number="it.qty"
                        label="Quantity *"
                        type="number"
                        min="1"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        :rules="qtyRules"
                      />
                    </v-col>
                    <v-col cols="6" md="2">
                      <v-text-field
                        v-model.number="it.unit_cost"
                        label="Unit cost"
                        type="number"
                        min="0"
                        step="0.01"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        prefix="KSh"
                      />
                    </v-col>
                    <v-col cols="6" md="2">
                      <v-text-field
                        v-model.number="it.unit_selling_price"
                        label="Unit selling price"
                        type="number"
                        min="0"
                        step="0.01"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        prefix="KSh"
                      />
                    </v-col>
                    <v-col cols="6" md="1">
                      <v-text-field
                        v-model.number="it.discount_percent"
                        label="Disc %"
                        type="number"
                        min="0"
                        max="100"
                        step="0.01"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        suffix="%"
                      />
                    </v-col>
                    <v-col cols="6" md="3">
                      <v-text-field
                        v-model="it.batch_number"
                        label="Batch #"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        placeholder="Auto"
                      />
                    </v-col>
                    <v-col cols="6" md="3">
                      <v-text-field
                        v-model="it.expiry_date"
                        label="Expiry date"
                        type="date"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                      />
                    </v-col>
                    <v-col cols="12" md="6" class="d-flex align-center justify-end flex-wrap ga-2">
                      <v-chip
                        size="small"
                        variant="tonal"
                        :color="marginColor(it)"
                        prepend-icon="mdi-trending-up"
                      >Margin {{ marginPct(it).toFixed(1) }}%</v-chip>
                      <v-chip
                        size="small"
                        variant="tonal"
                        color="success"
                        prepend-icon="mdi-cash-plus"
                      >Profit {{ formatMoney(lineProfit(it)) }}</v-chip>
                      <div class="po-line-total">
                        <span class="text-caption text-medium-emphasis mr-2">Line total</span>
                        <span class="text-h6 font-weight-bold text-primary">{{ formatMoney(lineTotal(it)) }}</span>
                      </div>
                    </v-col>
                  </v-row>
                </div>
                <v-btn
                  icon="mdi-delete-outline"
                  variant="text"
                  color="error"
                  size="small"
                  class="po-item-remove"
                  @click="form.items.splice(i, 1)"
                />
              </div>
            </div>
          </v-card>

          <!-- Notes -->
          <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 po-card">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-note-text-outline</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Notes</div>
            </div>
            <v-textarea
              v-model="form.notes"
              placeholder="Optional notes about this order…"
              variant="outlined"
              density="comfortable"
              rows="3"
              auto-grow
              hide-details="auto"
            />
          </v-card>

        <!-- BOTTOM: summary -->
        <v-card rounded="lg" class="po-summary">
          <div class="po-summary-header pa-4 pa-md-5">
            <div class="d-flex align-center">
              <v-icon color="white" class="mr-2">mdi-receipt-text</v-icon>
              <div class="text-h6 font-weight-bold">Order Summary</div>
            </div>
            <div class="text-caption mt-1" style="opacity:0.85">Live order totals</div>
          </div>
          <div class="pa-4 pa-md-5">
            <v-row dense>
              <v-col cols="6" md="3">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Items</div>
                  <div class="text-h6 font-weight-bold">{{ form.items.length }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Total quantity</div>
                  <div class="text-h6 font-weight-bold">{{ totalQty }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Avg. unit cost</div>
                  <div class="text-h6 font-weight-bold">{{ formatMoney(avgUnitCost) }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <div class="po-summary-stat is-total">
                  <div class="text-caption" style="opacity:0.85">Total cost</div>
                  <div class="text-h5 font-weight-bold">{{ formatMoney(grandTotal) }}</div>
                </div>
              </v-col>
            </v-row>
            <v-row dense class="mt-1">
              <v-col cols="6" md="4">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Projected revenue</div>
                  <div class="text-h6 font-weight-bold">{{ formatMoney(grandRevenue) }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="4">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Projected profit</div>
                  <div class="text-h6 font-weight-bold" :class="grandProfit >= 0 ? 'text-success' : 'text-error'">{{ formatMoney(grandProfit) }}</div>
                </div>
              </v-col>
              <v-col cols="12" md="4">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Profit margin</div>
                  <div class="text-h6 font-weight-bold" :class="grandMarginPct >= 0 ? 'text-success' : 'text-error'">{{ grandMarginPct.toFixed(1) }}%</div>
                </div>
              </v-col>
            </v-row>

            <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mt-4">{{ topError }}</v-alert>

            <div class="d-flex flex-wrap justify-end ga-2 mt-4">
              <v-btn
                variant="text"
                rounded="lg"
                size="large"
                class="text-none"
                to="/purchase-orders"
              >Cancel</v-btn>
              <v-btn
                type="submit"
                color="primary"
                rounded="lg"
                size="large"
                class="text-none"
                :loading="saving"
                :disabled="!canSave"
                prepend-icon="mdi-content-save"
              >{{ loadId ? 'Update Order' : 'Create Order' }}</v-btn>
            </div>
          </div>
        </v-card>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'

const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/purchase-orders/orders/')

const formRef = ref(null)
const saving = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const req = [v => (v !== null && v !== undefined && v !== '') || 'Required']
const qtyRules = [v => (Number(v) > 0) || 'Must be > 0']
const supplierRules = [v => {
  if (v && typeof v === 'object' && v.id) return true
  if (typeof v === 'string' && v.trim()) return true
  return 'Required'
}]
const itemRules = [v => {
  if (v && typeof v === 'object' && (v.id || v.medication_name)) return true
  if (typeof v === 'string' && v.trim()) return true
  return 'Required'
}]

// supplierPick can be either a Supplier object (from list) or a string (free text)
const supplierPick = ref(null)

const statusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'Sent', value: 'sent' },
  { label: 'Received', value: 'received' },
  { label: 'Partially Received', value: 'partial' },
  { label: 'Cancelled', value: 'cancelled' },
]

const form = reactive({
  po_number: '',
  supplier: null,
  expected_delivery: '',
  status: 'draft',
  notes: '',
  items: [],
})

const suppliers = ref([])
const stocks = ref([])

function newItem() {
  return {
    pick: null,
    stock_id: null,
    name: '',
    qty: 1,
    unit_cost: 0,
    unit_selling_price: 0,
    discount_percent: 0,
    batch_number: '',
    expiry_date: '',
    _current_stock: null,
  }
}

function addItem() { form.items.push(newItem()) }

function onPickItem(it, value) {
  if (value && typeof value === 'object') {
    it.stock_id = value.id || null
    it.name = value.medication_name || ''
    it.unit_cost = Number(value.cost_price || 0)
    it.unit_selling_price = Number(value.selling_price || 0)
    it.discount_percent = Number(value.discount_percent || 0)
    it._current_stock = value.total_quantity ?? 0
  } else if (typeof value === 'string') {
    it.stock_id = null
    it.name = value.trim()
    it._current_stock = null
  } else {
    it.stock_id = null
    it.name = ''
    it._current_stock = null
  }
}

function lineTotal(it) {
  return Number(it.qty || 0) * Number(it.unit_cost || 0)
}
function effectiveSelling(it) {
  const sell = Number(it.unit_selling_price || 0)
  const disc = Number(it.discount_percent || 0)
  return sell * (1 - disc / 100)
}
function lineRevenue(it) {
  return Number(it.qty || 0) * effectiveSelling(it)
}
function lineProfit(it) {
  return lineRevenue(it) - lineTotal(it)
}
function marginPct(it) {
  const rev = effectiveSelling(it)
  if (!rev) return 0
  return ((rev - Number(it.unit_cost || 0)) / rev) * 100
}
function marginColor(it) {
  const m = marginPct(it)
  if (m >= 30) return 'success'
  if (m >= 15) return 'info'
  if (m >= 0) return 'warning'
  return 'error'
}
const grandTotal = computed(() => form.items.reduce((s, it) => s + lineTotal(it), 0))
const grandRevenue = computed(() => form.items.reduce((s, it) => s + lineRevenue(it), 0))
const grandProfit = computed(() => grandRevenue.value - grandTotal.value)
const grandMarginPct = computed(() => grandRevenue.value ? (grandProfit.value / grandRevenue.value) * 100 : 0)
const totalQty = computed(() => form.items.reduce((s, it) => s + Number(it.qty || 0), 0))
const avgUnitCost = computed(() => totalQty.value ? grandTotal.value / totalQty.value : 0)
const canSave = computed(() => {
  const hasSupplier = (supplierPick.value && (supplierPick.value.id || (typeof supplierPick.value === 'string' && supplierPick.value.trim())))
  return !!hasSupplier && form.items.length > 0 && form.items.every(it => (it.stock_id || (it.name && it.name.trim())) && Number(it.qty) > 0)
})

function hydrateFromServer(data) {
  form.po_number = data.po_number || ''
  form.supplier = data.supplier ?? null
  supplierPick.value = suppliers.value.find(s => s.id === form.supplier) || null
  form.expected_delivery = data.expected_delivery || ''
  form.status = data.status || 'draft'
  form.notes = data.notes || ''
  form.items = (data.items || []).map(raw => {
    const stock_id = raw.medication_stock_id || raw.stock || null
    const stockObj = stock_id ? stocks.value.find(x => x.id === stock_id) : null
    return {
      pick: stockObj || raw.name || null,
      stock_id,
      name: raw.name || '',
      qty: Number(raw.qty || raw.quantity || 0),
      unit_cost: Number(raw.unit_cost || raw.unit_price || 0),
      unit_selling_price: Number(raw.unit_selling_price || raw.selling_price || 0),
      discount_percent: Number(raw.discount_percent || raw.discount || 0),
      batch_number: raw.batch_number || '',
      expiry_date: raw.expiry_date || '',
      _current_stock: stockObj?.total_quantity ?? null,
      _synced: !!raw._synced,
    }
  })
}

onMounted(async () => {
  const safe = (p) => $api.get(p).then(res => res.data?.results || res.data || []).catch(() => [])
  ;[suppliers.value, stocks.value] = await Promise.all([
    safe('/suppliers/'),
    safe('/inventory/stocks/?page_size=1000'),
  ])
  if (loadId.value) {
    const data = await r.get(loadId.value)
    if (data) hydrateFromServer(data)
  } else {
    form.items.push(newItem())
  }
})

async function onSubmit() {
  topError.value = ''
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  if (!canSave.value) {
    topError.value = 'Please choose a supplier and ensure each item has an item and quantity.'
    return
  }
  // Resolve supplier: pick id if existing, otherwise create one from typed name
  let supplierId = null
  if (supplierPick.value && typeof supplierPick.value === 'object' && supplierPick.value.id) {
    supplierId = supplierPick.value.id
  } else if (typeof supplierPick.value === 'string' && supplierPick.value.trim()) {
    const name = supplierPick.value.trim()
    const existing = suppliers.value.find(s => (s.name || '').toLowerCase() === name.toLowerCase())
    if (existing) {
      supplierId = existing.id
    } else {
      try {
        const { data } = await $api.post('/suppliers/', { name })
        suppliers.value.push(data)
        supplierId = data.id
        supplierPick.value = data
      } catch (e) {
        topError.value = e?.response?.data?.detail || 'Failed to create supplier.'
        return
      }
    }
  }
  if (!supplierId) {
    topError.value = 'Supplier is required.'
    return
  }
  form.supplier = supplierId

  // Resolve item stock_ids: auto-create new MedicationStock entries for new item names
  for (const it of form.items) {
    if (it.stock_id) continue
    const name = (it.name || '').trim()
    if (!name) continue
    const existing = stocks.value.find(s => (s.medication_name || '').toLowerCase() === name.toLowerCase())
    if (existing) {
      it.stock_id = existing.id
      it._current_stock = existing.total_quantity ?? 0
      continue
    }
    try {
      const { data: created } = await $api.post('/inventory/stocks/', {
        medication_name: name,
        selling_price: Number(it.unit_selling_price || it.unit_cost || 0),
        cost_price: Number(it.unit_cost || 0),
        discount_percent: Number(it.discount_percent || 0),
      })
      stocks.value.push(created)
      it.stock_id = created.id
      it.pick = created
      it._current_stock = created.total_quantity ?? 0
    } catch (e) {
      const msg = e?.response?.data
      topError.value = (msg && (msg.detail || JSON.stringify(msg))) || `Failed to create item '${name}'.`
      return
    }
  }

  const payload = {
    po_number: form.po_number || undefined,
    supplier: supplierId,
    expected_delivery: form.expected_delivery || null,
    status: form.status,
    notes: form.notes,
    items: form.items.map(it => ({
      medication_stock_id: it.stock_id,
      name: it.name,
      qty: Number(it.qty || 0),
      unit_cost: Number(it.unit_cost || 0),
      unit_selling_price: Number(it.unit_selling_price || 0),
      discount_percent: Number(it.discount_percent || 0),
      batch_number: it.batch_number || '',
      expiry_date: it.expiry_date || '',
      _synced: !!it._synced,
    })),
  }
  saving.value = true
  try {
    const result = loadId.value
      ? await r.update(loadId.value, payload)
      : await r.create(payload)
    snack.text = form.status === 'received' ? 'Saved & stock updated' : 'Saved'
    snack.color = 'success'
    snack.show = true
    router.push('/purchase-orders')
    return result
  } catch (e) {
    const data = e?.response?.data
    topError.value = (data && (data.detail || JSON.stringify(data))) || r.error.value || 'Save failed.'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.po-shell { max-width: 1400px; margin: 0 auto; }
.po-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

.po-items { display: flex; flex-direction: column; gap: 10px; }
.po-item-row {
  position: relative;
  display: flex;
  align-items: stretch;
  gap: 10px;
  padding: 12px 36px 12px 12px;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 12px;
  background: linear-gradient(180deg, rgba(99, 102, 241, 0.03), transparent);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.po-item-row:hover {
  border-color: rgba(99, 102, 241, 0.45);
  box-shadow: 0 4px 14px rgba(99, 102, 241, 0.08);
}
.po-item-num {
  flex: 0 0 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 12px;
  margin-top: 6px;
}
.po-item-body { flex: 1; min-width: 0; }
.po-item-remove { position: absolute; top: 6px; right: 6px; }

.po-line-total {
  display: flex;
  align-items: baseline;
  background: rgba(99, 102, 241, 0.06);
  padding: 8px 14px;
  border-radius: 10px;
}

.po-summary {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  overflow: hidden;
}
.po-summary-header {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
}
.po-summary-stat {
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(99, 102, 241, 0.06);
  height: 100%;
}
.po-summary-stat.is-total {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
}
</style>
