<template>
  <div class="pos-shell">
    <!-- Top bar -->
    <div class="pos-topbar d-flex align-center px-4">
      <v-icon color="primary" size="28" class="mr-2">mdi-point-of-sale</v-icon>
      <div>
        <div class="text-subtitle-1 font-weight-bold">Point of Sale <span class="text-caption text-medium-emphasis font-weight-regular">· Walk-in / OTC sales</span></div>
        <div class="text-caption text-medium-emphasis">{{ today }} · Cashier: {{ auth.user?.first_name || 'Staff' }}</div>
      </div>
      <v-spacer />
      <v-tooltip text="POS = Walk-in retail sales without prescription. For prescription-based dispensing use Dispensing." location="bottom">
        <template #activator="{ props }">
          <v-btn v-bind="props" variant="text" prepend-icon="mdi-pill" class="text-none d-none d-md-flex" to="/dispensing">Dispensing</v-btn>
        </template>
      </v-tooltip>
      <v-chip prepend-icon="mdi-receipt-text" variant="tonal" color="info" class="mr-2 d-none d-sm-flex">
        Today: {{ todayStats.count }} · {{ formatMoney(todayStats.revenue) }}
      </v-chip>
      <v-btn variant="text" prepend-icon="mdi-history" class="text-none" to="/pos/customers">Customers</v-btn>
      <v-btn variant="text" prepend-icon="mdi-receipt-text-outline" class="text-none d-none d-sm-flex" to="/pos/history">Sales History</v-btn>
      <v-badge :content="parkedCount" :model-value="parkedCount > 0" color="warning" offset-x="6" offset-y="6">
        <v-btn variant="text" prepend-icon="mdi-tray-arrow-up" class="text-none" to="/pos/parked?source=pharmacy" title="Sales on hold">Hold</v-btn>
      </v-badge>
      <v-btn variant="text" prepend-icon="mdi-chart-bar" class="text-none d-none d-sm-flex" to="/analytics">Analytics</v-btn>
      <v-btn variant="tonal" color="primary" prepend-icon="mdi-cart-variant" class="text-none ml-1" to="/pos/supermarket">Smart POS</v-btn>
    </div>

    <!-- Main grid -->
    <div class="pos-grid">
      <!-- LEFT: products -->
      <div class="pos-products">
        <div class="pos-search-bar pa-3 d-flex align-center" style="gap:10px">
          <v-text-field
            v-model="search"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search products by name or SKU…"
            variant="solo-filled"
            density="comfortable"
            hide-details
            clearable
            flat
            rounded="lg"
            bg-color="surface"
            autofocus
            class="flex-grow-1"
          />
          <v-select
            v-model="activeCat"
            :items="categoryOptions"
            item-title="title"
            item-value="value"
            placeholder="All categories"
            prepend-inner-icon="mdi-tag-multiple"
            variant="solo-filled"
            density="comfortable"
            hide-details
            flat
            rounded="lg"
            bg-color="surface"
            clearable
            style="max-width:240px; min-width:180px"
          />
          <v-btn-toggle v-model="viewMode" mandatory density="comfortable" rounded="lg" variant="outlined" color="primary">
            <v-btn value="grid" icon="mdi-view-grid" size="small" title="Grid view" />
            <v-btn value="list" icon="mdi-view-list" size="small" title="List view" />
          </v-btn-toggle>
        </div>

        <div class="pos-products-scroll px-3 pb-3">
          <div v-if="loading" class="text-center py-12">
            <v-progress-circular indeterminate color="primary" />
          </div>
          <EmptyState
            v-else-if="!filtered.length"
            icon="mdi-package-variant-closed"
            title="No products found"
            message="Try a different search term or category."
          />
          <div v-else class="pos-product-grid" :class="{ 'is-list': viewMode === 'list' }">
            <button
              v-for="p in paginated" :key="p.id"
              class="pos-product-card"
              :class="{ 'is-out': stockOf(p) <= 0, 'is-list': viewMode === 'list' }"
              :disabled="stockOf(p) <= 0"
              @click="addToCart(p)"
            >
              <div class="pos-product-thumb">
                <v-icon :size="viewMode === 'list' ? 28 : 36" color="primary">mdi-pill</v-icon>
                <span v-if="p.abbreviation" class="pos-abbr-badge" :title="`Abbreviation: ${p.abbreviation}`">
                  {{ p.abbreviation }}
                </span>
                <span v-if="stockOf(p) <= 0" class="pos-stock-badge bg-error">Out</span>
                <span v-else-if="stockOf(p) <= (p.reorder_level || 0)" class="pos-stock-badge bg-warning">Low</span>
                <span
                  v-if="rxBadge(p)"
                  class="pos-rx-badge"
                  :class="rxBadge(p).cls"
                  :title="rxBadge(p).title"
                >
                  <v-icon size="11" class="mr-1">mdi-prescription</v-icon>{{ rxBadge(p).label }}
                </span>
              </div>
              <div class="pos-product-body">
                <div class="pos-product-name">{{ nameOf(p) }}</div>
                <div class="pos-product-meta">
                  <span class="text-caption text-medium-emphasis">Stock: {{ stockOf(p) }}</span>
                </div>
              </div>
              <div class="pos-product-price">{{ formatMoney(p.selling_price) }}</div>
            </button>
          </div>
          <div v-if="!loading && filtered.length > pageSize" class="pos-pagination d-flex align-center justify-space-between mt-3 px-1">
            <div class="d-flex align-center ga-2">
              <span class="text-caption text-medium-emphasis">
                {{ (page - 1) * pageSize + 1 }}–{{ Math.min(page * pageSize, filtered.length) }} of {{ filtered.length }}
              </span>
              <v-select
                v-model="pageSize"
                :items="[12, 24, 48, 96]"
                density="compact"
                variant="outlined"
                hide-details
                style="max-width: 90px"
              />
            </div>
            <v-pagination
              v-model="page"
              :length="pageCount"
              :total-visible="5"
              density="comfortable"
              size="small"
              rounded="lg"
              color="primary"
            />
          </div>
        </div>
      </div>

      <!-- RIGHT: cart -->
      <div class="pos-cart">
        <div class="pos-cart-header pa-4 pb-3">
          <div class="d-flex align-center">
            <v-icon color="primary" class="mr-2">mdi-cart</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Current Sale</div>
            <v-spacer />
            <v-chip v-if="cart.length" size="small" color="primary" variant="tonal">
              {{ itemCount }} item{{ itemCount === 1 ? '' : 's' }}
            </v-chip>
          </div>

          <v-text-field
            v-model="customerName"
            prepend-inner-icon="mdi-account"
            placeholder="Walk-in customer"
            variant="outlined"
            density="compact"
            hide-details
            class="mt-3"
          />
        </div>

        <v-divider />

        <div class="pos-cart-items">
          <EmptyState
            v-if="!cart.length"
            icon="mdi-cart-outline"
            title="Cart is empty"
            message="Tap a product to start a sale."
          />
          <div v-else class="px-3 py-2">
            <div v-for="(it, i) in cart" :key="it.id" class="pos-cart-row">
              <div class="flex-grow-1 min-width-0">
                <div class="d-flex align-center" style="gap:6px">
                  <div class="text-body-2 font-weight-medium text-truncate">{{ it.name }}</div>
                  <span
                    v-if="it.rx && it.rx !== 'none'"
                    class="pos-rx-chip"
                    :class="it.rx === 'required' ? 'rx-required' : 'rx-recommended'"
                  >
                    <v-icon size="10" class="mr-1">mdi-prescription</v-icon>{{ it.rx === 'required' ? 'Rx' : 'Rx?' }}
                  </span>
                </div>
                <div class="text-caption text-medium-emphasis">{{ formatMoney(it.selling_price) }} ea</div>
              </div>
              <div class="pos-qty">
                <v-btn icon="mdi-minus" size="x-small" variant="tonal" rounded="lg" @click="dec(i)" />
                <span class="mx-2 text-body-2 font-weight-bold" style="min-width:20px; text-align:center">{{ it.quantity }}</span>
                <v-btn icon="mdi-plus" size="x-small" variant="tonal" color="primary" rounded="lg"
                  :disabled="it.quantity >= (it.max_qty || 9999)" @click="inc(i)" />
              </div>
              <div class="pos-line-total">{{ formatMoney(it.quantity * Number(it.selling_price || 0)) }}</div>
              <v-btn icon="mdi-close" size="x-small" variant="text" color="error" @click="cart.splice(i,1)" />
            </div>
          </div>
        </div>

        <div class="pos-cart-footer">
          <div class="px-4 py-3">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-medium-emphasis">Subtotal</span>
              <span>{{ formatMoney(subtotal) }}</span>
            </div>
            <div class="d-flex align-center justify-space-between text-body-2 mb-1">
              <span class="text-medium-emphasis">Discount</span>
              <v-text-field
                v-model.number="discount"
                type="number" min="0" :max="subtotal"
                density="compact" variant="plain" hide-details
                style="max-width:90px" class="text-right"
                suffix="KES"
              />
            </div>
            <div class="d-flex justify-space-between text-body-2 mb-2">
              <span class="text-medium-emphasis">VAT incl. (16%)</span>
              <span>{{ formatMoney(tax) }}</span>
            </div>
            <v-divider class="mb-2" />
            <div class="d-flex justify-space-between align-baseline">
              <span class="text-h6 font-weight-bold">Total</span>
              <span class="text-h4 font-weight-bold text-primary">{{ formatMoney(total) }}</span>
            </div>
          </div>

          <div class="px-4 pb-3">
            <v-select
              v-model="paymentMethod"
              :items="paymentMethods"
              item-title="label"
              item-value="value"
              label="Payment method"
              variant="outlined"
              density="comfortable"
              hide-details
              rounded="lg"
              :prepend-inner-icon="paymentMethodIcon"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props" :prepend-icon="item.raw.icon" :title="item.raw.label" />
              </template>
            </v-select>
          </div>

          <!-- Credit details (only when Credit is selected) -->
          <v-expand-transition>
            <div v-if="isCredit" class="px-4 pb-3">
              <v-card variant="tonal" color="warning" rounded="lg" class="pa-3">
                <div class="d-flex align-center mb-2" style="gap:8px">
                  <v-icon size="18">mdi-account-cash</v-icon>
                  <span class="text-subtitle-2 font-weight-bold">Credit sale details</span>
                </div>
                <v-text-field
                  v-model="customerName"
                  label="Customer name *"
                  density="compact" variant="outlined" hide-details class="mb-2"
                  prepend-inner-icon="mdi-account"
                />
                <v-text-field
                  v-model="credit.customerPhone"
                  label="Phone number *"
                  density="compact" variant="outlined" hide-details class="mb-2"
                  prepend-inner-icon="mdi-phone"
                />
                <v-text-field
                  v-model="credit.dueDate"
                  type="date" label="Due date"
                  density="compact" variant="outlined" hide-details class="mb-2"
                  prepend-inner-icon="mdi-calendar"
                />
                <v-text-field
                  v-model="credit.reference"
                  label="Reference / Account #"
                  density="compact" variant="outlined" hide-details class="mb-2"
                  prepend-inner-icon="mdi-pound"
                />
                <v-textarea
                  v-model="credit.notes"
                  label="Notes" rows="2" auto-grow
                  density="compact" variant="outlined" hide-details
                />
                <div v-if="!creditValid" class="text-caption text-error mt-2">
                  Customer name and phone are required for credit sales.
                </div>
              </v-card>
            </div>
          </v-expand-transition>

          <div class="px-4 pb-4 d-flex">
            <v-btn variant="outlined" color="warning" rounded="lg" class="text-none mr-2" :disabled="!cart.length" prepend-icon="mdi-pause-circle" @click="openHold">
              Hold
            </v-btn>
            <v-btn
              color="primary" rounded="lg" class="text-none flex-grow-1" size="large"
              :disabled="!cart.length || !creditValid" :loading="checkingOut"
              prepend-icon="mdi-cash-register"
              @click="checkout"
            >
              {{ isCredit ? `Charge ${formatMoney(total)} on credit` : `Charge ${formatMoney(total)}` }}
            </v-btn>
          </div>
        </div>
      </div>
    </div>

    <!-- Hold dialog -->
    <v-dialog v-model="holdPrompt.show" max-width="460" persistent>
      <v-card rounded="lg" class="pa-5">
        <div class="d-flex align-center mb-3">
          <v-avatar color="warning" variant="tonal" rounded="lg" size="40" class="mr-3">
            <v-icon>mdi-pause-circle</v-icon>
          </v-avatar>
          <div>
            <h3 class="text-h6 font-weight-bold mb-0">Hold sale</h3>
            <div class="text-caption text-medium-emphasis">Save this cart for later under a customer name</div>
          </div>
        </div>
        <v-text-field
          ref="holdNameInput"
          v-model="holdPrompt.name"
          label="Customer name"
          placeholder="e.g. John Doe"
          variant="outlined" density="comfortable" autofocus
          prepend-inner-icon="mdi-account"
          :rules="[v => !!(v && v.trim()) || 'Customer name is required']"
          @keydown.enter="confirmHold"
        />
        <v-text-field
          v-model="holdPrompt.phone"
          label="Phone number (optional)"
          placeholder="e.g. 0712 345 678"
          variant="outlined" density="comfortable"
          prepend-inner-icon="mdi-phone"
          hide-details="auto" class="mb-2"
          @keydown.enter="confirmHold"
        />
        <v-textarea
          v-model="holdPrompt.notes"
          label="Notes (optional)"
          variant="outlined" density="comfortable" rows="2" auto-grow
          prepend-inner-icon="mdi-note-text-outline"
          hide-details
        />
        <div class="d-flex align-center mt-4" style="gap:8px">
          <div class="text-caption text-medium-emphasis">{{ itemCount }} items · {{ formatMoney(total) }}</div>
          <v-spacer />
          <v-btn variant="text" class="text-none" :disabled="holdPrompt.saving" @click="holdPrompt.show = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" rounded="lg" prepend-icon="mdi-pause-circle" class="text-none"
            :loading="holdPrompt.saving"
            :disabled="!(holdPrompt.name || '').trim()"
            @click="confirmHold">
            Hold sale
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- Receipt dialog -->
    <v-dialog v-model="receipt.show" max-width="380" persistent>
      <v-card rounded="lg" class="pa-4">
        <div class="text-center mb-3">
          <v-avatar color="success" variant="tonal" size="64" class="mb-2">
            <v-icon size="36">mdi-check-bold</v-icon>
          </v-avatar>
          <h3 class="text-h6 font-weight-bold">Sale completed</h3>
          <div class="text-caption text-medium-emphasis">
            Receipt #{{ receipt.id }} · {{ receipt.time }}
          </div>
        </div>
        <v-divider class="mb-3" />
        <div v-for="it in receipt.items" :key="it.name" class="d-flex justify-space-between text-body-2 mb-1">
          <span>{{ it.quantity }} × {{ it.name }}</span>
          <span>{{ formatMoney(it.line) }}</span>
        </div>
        <v-divider class="my-2" />
        <div class="d-flex justify-space-between font-weight-bold">
          <span>Total paid</span>
          <span class="text-primary">{{ formatMoney(receipt.total) }}</span>
        </div>
        <div class="text-caption text-medium-emphasis text-center mt-1">
          via {{ receipt.method }}
        </div>
        <v-btn block color="primary" rounded="lg" class="text-none mt-4" @click="receipt.show = false">
          New Sale
        </v-btn>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { formatMoney } from '~/utils/format'

definePageMeta({ layout: 'default' })

const auth = useAuthStore()
const { $api } = useNuxtApp()

const today = new Date().toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'short', year: 'numeric' })

const products = ref([])
const loading = ref(false)
const search = ref('')
const activeCat = ref(null)
const viewMode = ref('grid')
const page = ref(1)
const pageSize = ref(24)
const cart = ref([])
const paymentMethod = ref('cash')
const customerName = ref('')
const discount = ref(0)
const checkingOut = ref(false)
const snack = reactive({ show: false, text: '', color: 'success' })
const todayStats = reactive({ count: 0, revenue: 0 })

const receipt = reactive({ show: false, id: '', time: '', items: [], total: 0, method: '' })
const parkedCount = ref(0)
const holdPrompt = reactive({ show: false, name: '', phone: '', notes: '', saving: false })
const holdNameInput = ref(null)

const paymentMethods = [
  { value: 'cash', label: 'Cash', icon: 'mdi-cash' },
  { value: 'mpesa', label: 'M-Pesa', icon: 'mdi-cellphone' },
  { value: 'card', label: 'Card', icon: 'mdi-credit-card' },
  { value: 'insurance', label: 'Insurance', icon: 'mdi-shield-account' },
  { value: 'credit', label: 'Credit', icon: 'mdi-account-cash' }
]

// Credit-sale details (only used when payment_method === 'credit')
const credit = reactive({ customerPhone: '', dueDate: '', reference: '', notes: '' })
const isCredit = computed(() => paymentMethod.value === 'credit')
const paymentMethodIcon = computed(() => paymentMethods.find(m => m.value === paymentMethod.value)?.icon || 'mdi-cash')
const creditValid = computed(() => !isCredit.value || (
  (customerName.value || '').trim().length > 1 && (credit.customerPhone || '').trim().length >= 7
))

function nameOf(p) { return p.medication_name || p.name || 'Unnamed' }
function stockOf(p) { return Number(p.total_quantity ?? p.quantity ?? 0) }
function rxOf(p) { return (p.prescription_required || 'none').toLowerCase() }
function rxBadge(p) {
  const r = rxOf(p)
  if (r === 'required') return { label: 'Rx', cls: 'rx-required', title: 'Prescription required' }
  if (r === 'recommended') return { label: 'Rx?', cls: 'rx-recommended', title: 'Prescription recommended' }
  return null
}

const categories = computed(() => {
  const map = new Map()
  for (const p of products.value) {
    const c = p.category_name || p.category || 'Other'
    map.set(c, (map.get(c) || 0) + 1)
  }
  return [...map.entries()].map(([name, count]) => ({ name, count }))
})

const categoryOptions = computed(() =>
  categories.value.map(c => ({ title: `${c.name} (${c.count})`, value: c.name }))
)

const filtered = computed(() => {
  let arr = products.value
  if (activeCat.value) arr = arr.filter(p => (p.category_name || p.category || 'Other') === activeCat.value)
  const q = search.value.toLowerCase().trim()
  if (q) arr = arr.filter(p =>
    nameOf(p).toLowerCase().includes(q) ||
    (p.abbreviation || '').toLowerCase().includes(q) ||
    (p.barcode || p.sku || '').toLowerCase().includes(q) ||
    (p.medication_id || '').toLowerCase().includes(q)
  )
  return arr
})

const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)))
const paginated = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})
watch([search, activeCat, pageSize], () => { page.value = 1 })
watch(pageCount, (n) => { if (page.value > n) page.value = n })

const itemCount = computed(() => cart.value.reduce((s, it) => s + it.quantity, 0))
const subtotal = computed(() => cart.value.reduce((s, it) => s + it.quantity * Number(it.selling_price || 0), 0))
// Selling prices are VAT-inclusive (16%). Total = subtotal - discount; tax is the embedded VAT portion.
const total = computed(() => Math.max(0, subtotal.value - (Number(discount.value) || 0)))
const tax = computed(() => total.value * (0.16 / 1.16))

function addToCart(p) {
  if (stockOf(p) <= 0) return
  const found = cart.value.find(i => i.id === p.id)
  if (found) {
    if (found.quantity < stockOf(p)) found.quantity++
    else flash('Stock limit reached', 'warning')
  } else {
    cart.value.push({
      id: p.id, name: nameOf(p),
      selling_price: p.selling_price, quantity: 1,
      max_qty: stockOf(p),
      rx: rxOf(p)
    })
  }
}
function inc(i) {
  const it = cart.value[i]
  if (it.quantity < (it.max_qty || 9999)) it.quantity++
}
function dec(i) {
  if (cart.value[i].quantity > 1) cart.value[i].quantity--
  else cart.value.splice(i, 1)
}
function clearCart() {
  cart.value = []; customerName.value = ''; discount.value = 0
  credit.customerPhone = ''; credit.dueDate = ''; credit.reference = ''; credit.notes = ''
}

async function openHold() {
  if (!cart.value.length) return
  holdPrompt.name = customerName.value || ''
  holdPrompt.phone = credit.customerPhone || ''
  holdPrompt.notes = ''
  holdPrompt.show = true
  await nextTick()
  holdNameInput.value?.focus?.()
}

async function confirmHold() {
  if (!cart.value.length) return
  const name = (holdPrompt.name || '').trim()
  if (!name) { flash('Customer name is required', 'error'); return }
  holdPrompt.saving = true
  try {
    const payload = {
      customer_name: name,
      customer_phone: (holdPrompt.phone || '').trim(),
      payment_method: paymentMethod.value || '',
      discount: Number(discount.value) || 0,
      notes: holdPrompt.notes || '',
      items: cart.value.map(it => ({
        stock_id: it.id,
        name: it.name,
        sku: it.sku || '',
        category: it.category || '',
        selling_price: Number(it.selling_price) || 0,
        quantity: it.quantity,
        max_qty: it.max_qty || 9999,
      })),
    }
    await $api.post('/pos/parked-sales/', payload)
    parkedCount.value += 1
    flash(`Sale held under "${name}"`)
    holdPrompt.show = false
    clearCart()
  } catch (e) {
    flash(e?.response?.data?.detail || 'Failed to hold sale', 'error')
  } finally {
    holdPrompt.saving = false
  }
}

async function loadParkedCount() {
  try {
    const res = await $api.get('/pos/parked-sales/?page_size=1')
    parkedCount.value = res.data?.count ?? (Array.isArray(res.data?.results) ? res.data.results.length : (Array.isArray(res.data) ? res.data.length : 0))
  } catch (e) { parkedCount.value = 0 }
}

function flash(text, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true
}

async function load() {
  loading.value = true
  products.value = await $api.get('/inventory/stocks/?page_size=500')
    .then(r => r.data?.results || r.data || []).catch(() => [])
  // today stats
  const tx = await $api.get('/pos/transactions/?page_size=200')
    .then(r => r.data?.results || r.data || []).catch(() => [])
  const todayKey = new Date().toISOString().slice(0, 10)
  const todayTx = tx.filter(t => (t.created_at || '').startsWith(todayKey))
  todayStats.count = todayTx.length
  todayStats.revenue = todayTx.reduce((s, t) => s + Number(t.total || t.total_amount || 0), 0)
  loading.value = false
  loadParkedCount()
}
onMounted(load)

// ===== Persist cart & sale state to localStorage =====
const LS_KEY = 'pharm_pos_state_v1'
onMounted(async () => {
  if (typeof window === 'undefined') return
  // Resume from parked sales page
  try {
    const raw = sessionStorage.getItem('pharm_resume_parked')
    if (raw) {
      sessionStorage.removeItem('pharm_resume_parked')
      const p = JSON.parse(raw)
      cart.value = (p.items || []).map(it => ({
        id: it.stock_id ?? it.id,
        name: it.name,
        sku: it.sku || '',
        category: it.category || '',
        selling_price: it.selling_price,
        quantity: it.quantity,
        max_qty: it.max_qty || 9999,
      }))
      customerName.value = p.customer_name || ''
      if (p.customer_phone) credit.customerPhone = p.customer_phone
      if (p.payment_method) paymentMethod.value = p.payment_method
      if (p.discount != null) discount.value = Number(p.discount) || 0
      try { await $api.delete(`/pos/parked-sales/${p.id}/`) } catch (e) {}
      flash(`Resumed sale for "${p.customer_name || 'Walk-in'}"`)
      return
    }
  } catch (e) {}
  try {
    const raw = localStorage.getItem(LS_KEY)
    if (!raw) return
    const s = JSON.parse(raw)
    if (Array.isArray(s.cart)) cart.value = s.cart
    if (typeof s.customerName === 'string') customerName.value = s.customerName
    if (typeof s.discount === 'number') discount.value = s.discount
    if (typeof s.paymentMethod === 'string') paymentMethod.value = s.paymentMethod
    if (s.credit && typeof s.credit === 'object') Object.assign(credit, s.credit)
  } catch (e) { /* ignore corrupt state */ }
})
watch(
  () => ({
    cart: cart.value,
    customerName: customerName.value,
    discount: discount.value,
    paymentMethod: paymentMethod.value,
    credit: { ...credit },
  }),
  (s) => {
    if (typeof window === 'undefined') return
    try { localStorage.setItem(LS_KEY, JSON.stringify(s)) } catch (e) {}
  },
  { deep: true }
)

async function checkout() {
  if (!cart.value.length) return
  checkingOut.value = true
  try {
    const items = cart.value.map(c => ({
      stock_id: c.id, quantity: c.quantity
    }))
    const payload = {
      payment_method: paymentMethod.value,
      customer_name: customerName.value || 'Walk-in',
      discount: Number(discount.value) || 0,
      items
    }
    if (isCredit.value) {
      payload.customer_phone = credit.customerPhone
      const refBits = []
      if (credit.reference) refBits.push(`Ref: ${credit.reference}`)
      if (credit.dueDate) refBits.push(`Due: ${credit.dueDate}`)
      if (credit.notes) refBits.push(credit.notes)
      if (refBits.length) payload.payment_reference = refBits.join(' | ').slice(0, 100)
    }
    const res = await $api.post('/pos/transactions/', payload)
    receipt.id = res.data?.receipt_number || res.data?.id || '—'
    receipt.time = new Date().toLocaleTimeString()
    receipt.items = cart.value.map(c => ({
      name: c.name, quantity: c.quantity,
      line: c.quantity * Number(c.selling_price || 0)
    }))
    receipt.total = total.value
    receipt.method = paymentMethods.find(m => m.value === paymentMethod.value)?.label || paymentMethod.value
    receipt.show = true
    clearCart()
    await load()
  } catch (e) {
    const data = e?.response?.data
    let msg = data?.detail
    if (!msg && data && typeof data === 'object') {
      const parts = []
      for (const [k, v] of Object.entries(data)) {
        const text = Array.isArray(v) ? v.join(', ') : (typeof v === 'string' ? v : JSON.stringify(v))
        parts.push(k === 'non_field_errors' ? text : `${k}: ${text}`)
      }
      if (parts.length) msg = parts.join(' \u2014 ')
    }
    flash(msg || 'Failed to complete sale', 'error')
  } finally {
    checkingOut.value = false
  }
}
</script>

<style scoped>
.pos-shell {
  height: calc(100vh - 64px);
  display: flex;
  flex-direction: column;
  background: linear-gradient(180deg, rgba(99, 102, 241, 0.04), rgb(var(--v-theme-background)) 220px);
}

.pos-topbar {
  height: 60px;
  flex-shrink: 0;
  background: rgb(var(--v-theme-surface));
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
}

.pos-brand {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  box-shadow: 0 4px 12px rgba(99, 102, 241, 0.35);
}

.pos-grid {
  flex: 1;
  display: grid;
  grid-template-columns: 60% 40%;
  gap: 14px;
  padding: 14px;
  overflow: hidden;
}

@media (max-width: 960px) {
  .pos-grid { grid-template-columns: 1fr; }
}

/* Products panel */
.pos-products {
  display: flex;
  flex-direction: column;
  background: rgb(var(--v-theme-surface));
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.04);
}

.pos-search-bar {
  flex-shrink: 0;
  border-bottom: 1px solid rgba(var(--v-border-color), 0.06);
  background: linear-gradient(180deg, rgba(99, 102, 241, 0.04), transparent);
}

.pos-products-scroll { flex: 1; overflow-y: auto; }

.pos-products-scroll::-webkit-scrollbar,
.pos-cart::-webkit-scrollbar { width: 8px; }
.pos-products-scroll::-webkit-scrollbar-thumb,
.pos-cart::-webkit-scrollbar-thumb {
  background: rgba(99, 102, 241, 0.25);
  border-radius: 4px;
}

.pos-product-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 12px;
  padding-top: 10px;
}
.pos-product-grid.is-list {
  grid-template-columns: 1fr;
  gap: 8px;
}

.pos-product-card {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  text-align: left;
  padding: 12px;
  border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
  font-family: inherit;
  position: relative;
  overflow: hidden;
}

.pos-product-card::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 3px;
  background: linear-gradient(90deg, #6366f1, #8b5cf6);
  opacity: 0;
  transition: opacity 0.18s ease;
}

.pos-product-card:hover:not(:disabled) {
  transform: translateY(-3px);
  border-color: rgba(99, 102, 241, 0.6);
  box-shadow: 0 8px 22px rgba(99, 102, 241, 0.18);
}
.pos-product-card:hover:not(:disabled)::before { opacity: 1; }
.pos-product-card:active:not(:disabled) { transform: translateY(-1px); }
.pos-product-card.is-out { opacity: 0.55; cursor: not-allowed; }

.pos-product-card.is-list {
  flex-direction: row;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
}
.pos-product-card.is-list .pos-product-thumb {
  width: 48px; height: 48px;
  margin-bottom: 0;
  flex-shrink: 0;
}
.pos-product-card.is-list .pos-product-body {
  flex: 1; min-width: 0;
}
.pos-product-card.is-list .pos-product-name {
  -webkit-line-clamp: 1;
  margin-bottom: 2px;
}
.pos-product-card.is-list .pos-product-meta { margin-bottom: 0; }
.pos-product-card.is-list .pos-product-price {
  margin-left: auto;
  font-size: 1.05rem;
  flex-shrink: 0;
}
.pos-product-card.is-list .pos-stock-badge,
.pos-product-card.is-list .pos-rx-badge { font-size: 9px; padding: 1px 5px; }

.pos-product-thumb {
  position: relative;
  height: 70px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.10), rgba(139, 92, 246, 0.06));
  border-radius: 10px;
  margin-bottom: 10px;
}

.pos-stock-badge {
  position: absolute;
  top: 5px; right: 5px;
  font-size: 10px;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 10px;
  color: white;
}

.pos-rx-badge {
  position: absolute;
  top: 5px; left: 5px;
  display: inline-flex;
  align-items: center;
  font-size: 10px;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 10px;
}
.pos-rx-badge.rx-required { background: rgba(239,68,68,0.15); color: #b91c1c; border: 1px solid rgba(239,68,68,0.35); }
.pos-rx-badge.rx-recommended { background: rgba(245,158,11,0.15); color: #b45309; border: 1px solid rgba(245,158,11,0.35); }

.pos-abbr-badge {
  position: absolute;
  bottom: 5px; left: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.4px;
  padding: 2px 7px;
  border-radius: 10px;
  background: rgba(99, 102, 241, 0.14);
  color: #4338ca;
  border: 1px solid rgba(99, 102, 241, 0.35);
  text-transform: uppercase;
  line-height: 1.3;
  pointer-events: none;
}

.pos-rx-chip {
  display: inline-flex; align-items: center;
  font-size: 9px; font-weight: 700;
  padding: 1px 5px; border-radius: 4px; flex-shrink: 0;
}
.pos-rx-chip.rx-required { background: rgba(239,68,68,0.15); color: #b91c1c; }
.pos-rx-chip.rx-recommended { background: rgba(245,158,11,0.15); color: #b45309; }

.pos-product-name {
  font-size: 0.875rem;
  font-weight: 600;
  line-height: 1.25;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin-bottom: 4px;
}

.pos-product-meta { margin-bottom: 6px; }

.pos-product-price {
  font-size: 1rem;
  font-weight: 800;
  color: rgb(var(--v-theme-primary));
  letter-spacing: -0.01em;
}

/* Cart panel */
.pos-cart {
  display: flex;
  flex-direction: column;
  background: rgb(var(--v-theme-surface));
  border-radius: 14px;
  overflow-y: auto;
  overflow-x: hidden;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.04);
  max-height: 100%;
}

.pos-cart-banner {
  padding: 14px 16px;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: white;
  position: sticky;
  top: 0;
  z-index: 3;
}

.pos-cart-items { flex: 1 0 auto; min-height: 0; }

.pos-cart-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 10px;
  border-radius: 10px;
  transition: background 0.15s ease;
}
.pos-cart-row:hover { background: rgba(99, 102, 241, 0.06); }

.pos-qty {
  display: flex;
  align-items: center;
  flex-shrink: 0;
  background: rgba(99, 102, 241, 0.08);
  border-radius: 8px;
  padding: 2px 4px;
}

.pos-line-total {
  font-weight: 700;
  font-size: 0.9rem;
  min-width: 80px;
  text-align: right;
  color: rgb(var(--v-theme-primary));
}

.pos-cart-footer {
  flex-shrink: 0;
  position: sticky;
  bottom: 0;
  z-index: 2;
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  background: rgb(var(--v-theme-surface));
}

.pos-totals-card {
  margin: 10px 12px 0 12px;
  border-radius: 14px;
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
  box-shadow: 0 6px 18px rgba(79, 70, 229, 0.25);
}

.pos-total-divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.25);
  margin-top: 4px;
}

.pos-disc-input :deep(input) {
  color: white !important;
  font-weight: 600;
  text-align: right;
}
.pos-disc-input :deep(.v-field__suffix) { color: rgba(255, 255, 255, 0.85) !important; }

.pos-charge-btn {
  background: linear-gradient(135deg, #6366f1, #8b5cf6) !important;
  color: white !important;
  box-shadow: 0 4px 14px rgba(99, 102, 241, 0.35);
}

.min-width-0 { min-width: 0; }
</style>
