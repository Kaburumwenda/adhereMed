<template>
  <v-container fluid class="pa-4 pa-md-6 so-shell">
    <PageHeader
      :title="loadId ? `Edit ${form.so_number || 'Sales Order'}` : 'New Sales Order'"
      icon="mdi-receipt-text-plus"
      subtitle="Manage customer orders and deliveries"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/sales-orders">Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" @submit.prevent="onSubmit">
      <!-- Header card -->
      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 so-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="primary" class="mr-2">mdi-file-document-edit-outline</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Order Details</div>
          <v-spacer />
          <v-chip v-if="form.so_number" size="small" color="primary" variant="tonal" prepend-icon="mdi-pound">{{ form.so_number }}</v-chip>
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-combobox
              v-model="customerPick"
              :items="customers"
              item-title="name"
              :return-object="true"
              label="Customer *"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-account-box-outline"
              :rules="customerRules"
              hide-details="auto"
              hint="Pick from list or type a customer name"
              persistent-hint
              @update:search="customerSearch = $event"
              @update:model-value="onPickCustomer"
            >
              <template #item="{ props: ip, item }">
                <v-list-item v-bind="ip" :title="item.raw.name">
                  <template #subtitle>
                    <div class="d-flex flex-wrap ga-1 align-center">
                      <span v-if="item.raw.phone">{{ item.raw.phone }}</span>
                      <v-chip v-if="item.raw.loyalty_tier" size="x-small" variant="tonal" color="amber">{{ item.raw.loyalty_tier }}</v-chip>
                      <v-chip v-if="Number(item.raw.total_purchases) > 0" size="x-small" variant="tonal" color="success">Spent {{ formatMoney(item.raw.total_purchases) }}</v-chip>
                    </div>
                  </template>
                </v-list-item>
              </template>
              <template #append-item>
                <div class="pa-2">
                  <v-btn
                    block
                    color="primary"
                    variant="tonal"
                    rounded="lg"
                    size="small"
                    class="text-none"
                    prepend-icon="mdi-account-plus-outline"
                    @click="openCustomerDialog"
                  >Manage Customer</v-btn>
                </div>
              </template>
            </v-combobox>
          </v-col>
          <v-col cols="6" md="3">
            <v-text-field
              v-model="form.customer_phone"
              label="Phone"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-phone"
              hide-details="auto"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-select
              v-model="form.branch"
              :items="branchOptions"
              item-title="label"
              item-value="value"
              label="Branch"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-store"
              :disabled="branchLocked"
              clearable
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
          <v-col cols="6" md="3">
            <v-text-field
              v-model="form.expected_delivery"
              label="Expected Delivery"
              type="date"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-calendar"
              hide-details="auto"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-text-field
              v-model.number="form.amount_paid"
              label="Amount paid (KSh)"
              type="number"
              min="0"
              step="0.01"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-cash-check"
              hide-details="auto"
              prefix="KSh"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-select
              v-model="form.payment_method"
              :items="paymentMethodOptions"
              item-title="label"
              item-value="value"
              label="Payment method"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-credit-card-outline"
              hide-details="auto"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-text-field
              v-model.number="form.discount_amount"
              label="Order discount (KSh)"
              type="number"
              min="0"
              step="0.01"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-sale-outline"
              hide-details="auto"
              prefix="KSh"
            />
          </v-col>
          <v-col cols="6" md="3">
            <v-text-field
              v-model.number="form.delivery_fee"
              label="Delivery fee (KSh)"
              type="number"
              min="0"
              step="0.01"
              variant="outlined"
              density="comfortable"
              prepend-inner-icon="mdi-truck-delivery-outline"
              hide-details="auto"
              prefix="KSh"
              hint="Charged to the customer — added to the order total"
              persistent-hint
            />
          </v-col>
        </v-row>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-menu
              v-model="addrMenu"
              :close-on-content-click="true"
              location="bottom start"
              offset="4"
              max-height="320"
              :open-on-click="false"
              :open-on-focus="false"
            >
              <template #activator="{ props: menuProps }">
                <v-text-field
                  v-bind="menuProps"
                  v-model="form.delivery_address"
                  label="Delivery address"
                  placeholder="Search a delivery address…"
                  variant="outlined"
                  density="comfortable"
                  prepend-inner-icon="mdi-map-marker-outline"
                  hide-details="auto"
                  :loading="addrSearching"
                  autocomplete="off"
                  @update:model-value="onAddressInput"
                >
                  <template #append-inner>
                    <v-chip
                      v-if="form.delivery_lat != null"
                      size="x-small"
                      variant="tonal"
                      color="teal"
                      class="mr-1"
                      title="Delivery location pinned"
                    >GPS</v-chip>
                    <v-btn
                      icon="mdi-map-search"
                      size="x-small"
                      variant="text"
                      color="teal"
                      title="Pick on map"
                      @click.stop="mapPickerOpen = true"
                    />
                  </template>
                </v-text-field>
              </template>
              <v-list density="compact" class="so-addr-list">
                <v-list-item
                  v-for="p in addressPredictions"
                  :key="p.place_id"
                  @click="pickAddressPrediction(p)"
                >
                  <template #prepend>
                    <v-icon icon="mdi-map-marker" size="18" color="teal" />
                  </template>
                  <v-list-item-title class="text-body-2">
                    {{ p.structured_formatting?.main_text || p.description }}
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    {{ p.description }}
                  </v-list-item-subtitle>
                </v-list-item>
                <v-list-item v-if="!addressPredictions.length && addrSearching">
                  <template #prepend>
                    <v-progress-circular size="16" width="2" indeterminate color="teal" />
                  </template>
                  <v-list-item-title class="text-body-2 text-medium-emphasis">Searching…</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
            <div v-if="form.delivery_place_name" class="text-caption text-medium-emphasis mt-1 ml-2">
              <v-icon size="12" class="mr-1">mdi-tag-outline</v-icon>{{ form.delivery_place_name }}
            </div>
          </v-col>
          <v-col cols="12" md="6">
            <v-textarea
              v-model="form.notes"
              label="Notes"
              placeholder="Optional notes about this order…"
              variant="outlined"
              density="comfortable"
              rows="2"
              auto-grow
              hide-details="auto"
              prepend-inner-icon="mdi-note-text-outline"
            />
          </v-col>
        </v-row>
        <v-alert
          v-if="Number(form.amount_paid) > 0 || form.status === 'fulfilled'"
          type="info"
          variant="tonal"
          density="compact"
          class="mt-3"
          icon="mdi-package-variant-closed"
        >
          Paid / partially paid orders <b>commit</b> their item quantities as reserved stock.
          Setting the status to <b>Fulfilled</b> (delivered) deducts the items from physical stock.
        </v-alert>
      </v-card>

      <!-- Items card -->
      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 so-card">
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
          message="Click 'Add Item' to start building your sales order."
        />

        <div v-else class="so-items">
          <div v-for="(it, i) in form.items" :key="i" class="so-item-row">
            <div class="so-item-num">{{ i + 1 }}</div>
            <div class="so-item-body">
              <v-row dense>
                <v-col cols="12" md="5">
                  <v-combobox
                    v-model="it.pick"
                    :items="itemSearchResults"
                    item-title="medication_name"
                    :return-object="true"
                    label="Item *"
                    variant="outlined"
                    density="comfortable"
                    hide-details="auto"
                    :rules="itemRules"
                    :loading="itemSearching"
                    :custom-filter="itemFilterAll"
                    hint="Search inventory (name, abbreviation or barcode)"
                    persistent-hint
                    @update:search="onItemSearch"
                    @update:model-value="onPickItem(it, $event)"
                  >
                    <template #no-data>
                      <v-list-item>
                        <v-list-item-title class="text-body-2 text-medium-emphasis">
                          {{ itemSearching ? 'Searching inventory…' : 'No matching inventory items.' }}
                        </v-list-item-title>
                      </v-list-item>
                    </template>
                    <template #item="{ props: ip, item }">
                      <v-list-item v-bind="ip" :title="item.raw.medication_name">
                        <template #subtitle>
                          <div class="d-flex flex-wrap ga-1 align-center">
                            <v-chip v-if="item.raw.selling_price" size="x-small" variant="tonal" color="success">Sell {{ formatMoney(item.raw.selling_price) }}</v-chip>
                            <v-chip size="x-small" variant="tonal" :color="(item.raw.total_quantity || 0) <= 0 ? 'error' : 'default'">Stock {{ item.raw.total_quantity || 0 }}</v-chip>
                            <v-chip v-if="Number(item.raw.committed_qty) > 0" size="x-small" variant="tonal" color="orange">Committed {{ item.raw.committed_qty }}</v-chip>
                          </div>
                        </template>
                      </v-list-item>
                    </template>
                  </v-combobox>
                  <div v-if="it.stock_id" class="mt-1 d-flex flex-wrap ga-1">
                    <v-chip size="x-small" variant="flat" color="info">In stock {{ it._current_stock ?? '—' }}</v-chip>
                    <v-chip v-if="Number(it._committed_qty) > 0" size="x-small" variant="flat" color="orange">Committed {{ it._committed_qty }}</v-chip>
                    <v-chip v-if="Number(it.qty) > Number(it._available_stock || 0)" size="x-small" variant="flat" color="error">Low stock — ordered {{ it.qty }}</v-chip>
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
                  />
                </v-col>
                <v-col cols="6" md="2">
                  <v-text-field
                    v-model.number="it.unit_price"
                    label="Unit price"
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
                <v-col cols="6" md="3" class="d-flex align-center justify-end flex-wrap ga-2">
                  <v-chip
                    size="small"
                    variant="tonal"
                    color="primary"
                    prepend-icon="mdi-cash"
                  >Line total {{ formatMoney(lineTotal(it)) }}</v-chip>
                </v-col>
              </v-row>
            </div>
            <v-btn
              icon="mdi-delete-outline"
              variant="text"
              color="error"
              size="small"
              class="so-item-remove"
              @click="form.items.splice(i, 1)"
            />
          </div>
        </div>
      </v-card>

      <!-- Summary -->
      <v-card rounded="lg" class="so-summary">
        <div class="so-summary-header pa-4 pa-md-5">
          <div class="d-flex align-center">
            <v-icon color="white" class="mr-2">mdi-receipt-text</v-icon>
            <div class="text-h6 font-weight-bold">Order Summary</div>
          </div>
          <div class="text-caption mt-1" style="opacity:0.85">Live order totals</div>
        </div>
        <div class="pa-4 pa-md-5">
          <v-row dense>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Items</div>
                <div class="text-h6 font-weight-bold">{{ form.items.length }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Total quantity</div>
                <div class="text-h6 font-weight-bold">{{ totalQty }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Subtotal</div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(itemsSubtotal) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Order discount</div>
                <div class="text-h6 font-weight-bold text-orange">{{ formatMoney(Number(form.discount_amount || 0)) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Delivery fee</div>
                <div class="text-h6 font-weight-bold text-info">{{ formatMoney(Number(form.delivery_fee || 0)) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat is-total">
                <div class="text-caption" style="opacity:0.85">Order total</div>
                <div class="text-h5 font-weight-bold">{{ formatMoney(orderTotal) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Amount paid</div>
                <div class="text-h6 font-weight-bold text-success">{{ formatMoney(Number(form.amount_paid || 0)) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Balance due</div>
                <div class="text-h6 font-weight-bold" :class="balanceDue > 0 ? 'text-error' : 'text-success'">{{ formatMoney(balanceDue) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="so-summary-stat">
                <div class="text-caption text-medium-emphasis">Payment status</div>
                <v-chip size="small" :color="paymentStatusColor" variant="tonal" class="mt-1">{{ paymentStatusLabel }}</v-chip>
              </div>
            </v-col>
          </v-row>

          <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mt-4">{{ topError }}</v-alert>

          <div class="d-flex flex-wrap justify-end ga-2 mt-4">
            <v-btn variant="text" rounded="lg" size="large" class="text-none" to="/sales-orders">Cancel</v-btn>
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

    <!-- Map picker for delivery address -->
    <MapPicker
      v-model="mapPickerOpen"
      :initial="mapPickerInitial"
      @picked="onMapPicked"
    />

    <!-- Add customer dialog -->
    <v-dialog v-model="customerDialog.show" max-width="480" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-account-plus-outline</v-icon>
          Manage Customer
          <v-spacer />
          <v-btn icon="mdi-close" size="small" variant="text" @click="customerDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-alert v-if="customerDialog.error" type="error" variant="tonal" density="compact" class="mb-3">
            {{ customerDialog.error }}
          </v-alert>
          <v-text-field
            v-model="customerDialog.name"
            label="Customer name *"
            variant="outlined"
            density="comfortable"
            prepend-inner-icon="mdi-account-outline"
            hide-details="auto"
            autofocus
            class="mb-3"
          />
          <v-text-field
            v-model="customerDialog.phone"
            label="Phone *"
            variant="outlined"
            density="comfortable"
            prepend-inner-icon="mdi-phone"
            hide-details="auto"
            class="mb-3"
          />
          <v-text-field
            v-model="customerDialog.email"
            label="Email"
            variant="outlined"
            density="comfortable"
            prepend-inner-icon="mdi-email-outline"
            hide-details="auto"
            class="mb-3"
          />
          <v-textarea
            v-model="customerDialog.address"
            label="Address"
            variant="outlined"
            density="comfortable"
            prepend-inner-icon="mdi-map-marker-outline"
            rows="2"
            auto-grow
            hide-details="auto"
          />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="customerDialog.show = false">Cancel</v-btn>
          <v-btn
            color="primary"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-check"
            :loading="customerDialog.busy"
            :disabled="!(customerDialog.name?.trim() && customerDialog.phone?.trim())"
            @click="createCustomer"
          >Save Customer</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { useGoogleMaps } from '~/composables/useGoogleMaps'
import { formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'

const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const { getPredictions, getPlaceDetails } = useGoogleMaps()
const loadId = computed(() => route.params.id || null)
const r = useResource('/sales-orders/orders/')

const branchStore = useBranchStore()
const auth = useAuthStore()

const formRef = ref(null)
const saving = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const customerRules = [v => {
  if (v && typeof v === 'object' && (v.name || v.id)) return true
  if (typeof v === 'string' && v.trim()) return true
  return 'Required'
}]
const itemRules = [v => {
  if (v && typeof v === 'object' && (v.id || v.medication_name)) return true
  if (typeof v === 'string' && v.trim()) return true
  return 'Required'
}]

const customerPick = ref(null)

const branchLocked = computed(() => auth.role === 'branch_admin')
const branchOptions = computed(() => {
  if (branchLocked.value) {
    const b = branchStore.currentBranch
    return b ? [{ label: b.name, value: b.id }] : []
  }
  return branchStore.activeBranches.map(b => ({ label: b.name, value: b.id }))
})

const statusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Partially Fulfilled', value: 'partial' },
  { label: 'Fulfilled', value: 'fulfilled' },
  { label: 'Cancelled', value: 'cancelled' },
]

const paymentMethodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Bank Transfer', value: 'bank' },
  { label: 'Card', value: 'card' },
  { label: 'Cheque', value: 'cheque' },
  { label: 'Insurance', value: 'insurance' },
  { label: 'Credit', value: 'credit' },
  { label: 'Other', value: 'other' },
]

const form = reactive({
  so_number: '',
  customer: null,
  customer_name: '',
  customer_phone: '',
  branch: null,
  status: 'draft',
  amount_paid: 0,
  payment_method: 'cash',
  discount_amount: 0,
  delivery_fee: 0,
  expected_delivery: '',
  delivery_address: '',
  delivery_place_name: '',
  delivery_lat: null,
  delivery_lng: null,
  notes: '',
  items: [],
})

// --- Delivery address: Google Places autocomplete + map picker ---
const addrMenu = ref(false)
const addrSearching = ref(false)
const addressPredictions = ref([])
let _addrTimer = null

function onAddressInput(v) {
  form.delivery_address = v || ''
  if (_addrTimer) clearTimeout(_addrTimer)
  if (!v || v.length < 3) {
    addressPredictions.value = []
    addrMenu.value = false
    return
  }
  addrSearching.value = true
  _addrTimer = setTimeout(async () => {
    try {
      addressPredictions.value = await getPredictions(v, { country: 'ke' })
      addrMenu.value = addressPredictions.value.length > 0
    } catch {
      addressPredictions.value = []
      addrMenu.value = false
    } finally {
      addrSearching.value = false
    }
  }, 280)
}

async function pickAddressPrediction(pred) {
  addrMenu.value = false
  try {
    const d = await getPlaceDetails(pred.place_id)
    form.delivery_address = d.address || pred.description
    form.delivery_lat = d.lat != null ? round6(d.lat) : null
    form.delivery_lng = d.lng != null ? round6(d.lng) : null
    form.delivery_place_name = d.name || pred.structured_formatting?.main_text || ''
  } catch {
    form.delivery_address = pred.description
  }
}

function round6(n) {
  return Math.round(Number(n) * 1e6) / 1e6
}

const mapPickerOpen = ref(false)
const mapPickerInitial = computed(() => ({
  lat: form.delivery_lat,
  lng: form.delivery_lng,
  address: form.delivery_address,
  place_name: form.delivery_place_name,
}))

function onMapPicked(p) {
  form.delivery_address = p.address || form.delivery_address
  form.delivery_lat = p.lat != null ? round6(p.lat) : null
  form.delivery_lng = p.lng != null ? round6(p.lng) : null
  form.delivery_place_name = p.place_name || ''
}

const customers = ref([])
const stocks = ref([])

// --- Branch-aware item search ---
const itemSearchResults = ref([])
const itemSearching = ref(false)
let _itemSearchTimer = null

// Bypass Vuetify's internal combobox filter — we control the results ourselves
// (the server may match by barcode/abbreviation, which the title filter would hide).
function itemFilterAll() {
  return true
}

function localItemMatches(q) {
  const needle = q.toLowerCase().trim()
  if (!needle) return stocks.value.map(s => ({ ...s }))
  return stocks.value.filter(s =>
    (s.medication_name || '').toLowerCase().includes(needle) ||
    (s.abbreviation || '').toLowerCase().includes(needle) ||
    (s.barcode || '').toLowerCase().includes(needle)
  )
}

async function onItemSearch(query) {
  clearTimeout(_itemSearchTimer)
  const q = (query || '').trim()
  // Instant: filter the preloaded branch inventory locally
  itemSearchResults.value = localItemMatches(q)
  if (!q || q.length < 2) return
  // Debounced: also ask the server for anything not preloaded
  _itemSearchTimer = setTimeout(async () => {
    itemSearching.value = true
    try {
      const params = { search: q, page_size: 50 }
      if (form.branch) params.branch = form.branch
      const res = await $api.get('/inventory/stocks/', { params })
      const serverItems = res.data?.results || res.data || []
      // Merge: server matches first, then local matches not already shown
      const seen = new Set(serverItems.map(s => s.id))
      const local = localItemMatches(q).filter(s => !seen.has(s.id))
      itemSearchResults.value = [...serverItems, ...local]
    } catch {
      // keep the local matches already displayed
    } finally {
      itemSearching.value = false
    }
  }, 300)
}

watch(() => form.branch, async (branchId) => {
  if (!branchId) return
  try {
    const params = { page_size: 1000 }
    if (branchId) params.branch = branchId
    const res = await $api.get('/inventory/stocks/', { params })
    stocks.value = res.data?.results || res.data || []
    itemSearchResults.value = stocks.value.map(s => ({ ...s }))
  } catch { /* silent */ }
})

function newItem() {
  return {
    pick: null,
    stock_id: null,
    name: '',
    qty: 1,
    unit_price: 0,
    discount_percent: 0,
    _current_stock: null,
    _committed_qty: null,
    _available_stock: null,
  }
}

function addItem() { form.items.push(newItem()) }

function onPickItem(it, value) {
  if (value && typeof value === 'object') {
    it.stock_id = value.id || null
    it.name = value.medication_name || ''
    it.unit_price = Number(value.selling_price || 0)
    it._current_stock = value.total_quantity ?? 0
    it._committed_qty = value.committed_qty ?? 0
    it._available_stock = value.available_quantity ?? Math.max(0, (value.total_quantity || 0) - (value.committed_qty || 0))
  } else if (typeof value === 'string') {
    it.stock_id = null
    it.name = value.trim()
    it._current_stock = null
    it._committed_qty = null
    it._available_stock = null
  } else {
    it.stock_id = null
    it.name = ''
    it._current_stock = null
    it._committed_qty = null
    it._available_stock = null
  }
}

function onPickCustomer(value) {
  if (value && typeof value === 'object') {
    form.customer = value.id || null
    form.customer_name = value.name || ''
    form.customer_phone = value.phone || ''
  } else if (typeof value === 'string') {
    form.customer = null
    form.customer_name = value.trim()
  } else {
    form.customer = null
    form.customer_name = ''
  }
}

// --- Manage Customer (add new from combobox) ---
const customerSearch = ref('')
const customerDialog = reactive({
  show: false, name: '', phone: '', email: '', address: '', busy: false, error: '',
})

function openCustomerDialog() {
  customerDialog.name = (customerSearch.value || '').trim()
  customerDialog.phone = ''
  customerDialog.email = ''
  customerDialog.address = ''
  customerDialog.error = ''
  customerDialog.show = true
}

async function createCustomer() {
  if (!customerDialog.name.trim() || !customerDialog.phone.trim()) {
    customerDialog.error = 'Name and phone are required.'
    return
  }
  customerDialog.busy = true
  try {
    const { data } = await $api.post('/pos/customers/', {
      name: customerDialog.name.trim(),
      phone: customerDialog.phone.trim(),
      email: customerDialog.email || '',
      address: customerDialog.address || '',
    })
    customers.value.push(data)
    // Auto-select the freshly created customer
    customerPick.value = data
    form.customer = data.id
    form.customer_name = data.name
    form.customer_phone = data.phone
    customerSearch.value = ''
    customerDialog.show = false
    snack.text = `Customer “${data.name}” created.`
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    const d = e?.response?.data
    customerDialog.error = (d?.phone?.[0]) || (d?.name?.[0]) || d?.detail || 'Failed to create customer.'
  } finally {
    customerDialog.busy = false
  }
}

function lineTotal(it) {
  return Number(it.qty || 0) * Number(it.unit_price || 0) * (1 - Number(it.discount_percent || 0) / 100)
}

const itemsSubtotal = computed(() => form.items.reduce((s, it) => s + lineTotal(it), 0))
const orderTotal = computed(() => Math.max(0, itemsSubtotal.value - Number(form.discount_amount || 0) + Number(form.delivery_fee || 0)))
const balanceDue = computed(() => Math.max(0, orderTotal.value - Number(form.amount_paid || 0)))
const totalQty = computed(() => form.items.reduce((s, it) => s + Number(it.qty || 0), 0))
const paymentStatusLabel = computed(() => {
  const paid = Number(form.amount_paid || 0)
  if (paid <= 0) return 'Unpaid'
  if (paid >= orderTotal.value) return 'Paid'
  return 'Partially Paid'
})
const paymentStatusColor = computed(() => {
  const paid = Number(form.amount_paid || 0)
  if (paid <= 0) return 'error'
  if (paid >= orderTotal.value) return 'success'
  return 'warning'
})

const canSave = computed(() => {
  const hasCustomer = (customerPick.value && (customerPick.value.id || (typeof customerPick.value === 'string' && customerPick.value.trim())))
  return !!hasCustomer && form.items.length > 0 && form.items.every(it => (it.stock_id || (it.name && it.name.trim())) && Number(it.qty) > 0)
})

function hydrateFromServer(data) {
  form.so_number = data.so_number || ''
  form.customer = data.customer ?? null
  form.customer_name = data.customer_name || ''
  form.customer_phone = data.customer_phone || ''
  form.branch = data.branch ?? form.branch
  form.status = data.status || 'draft'
  form.amount_paid = Number(data.amount_paid || 0)
  form.payment_method = data.payment_method || 'cash'
  form.discount_amount = Number(data.discount_amount || 0)
  form.delivery_fee = Number(data.delivery_fee || 0)
  form.expected_delivery = data.expected_delivery || ''
  form.delivery_address = data.delivery_address || ''
  form.delivery_place_name = data.delivery_place_name || ''
  form.delivery_lat = data.delivery_lat ?? null
  form.delivery_lng = data.delivery_lng ?? null
  form.notes = data.notes || ''
  customerPick.value = customers.value.find(c => c.id === form.customer)
    || (form.customer_name || null)
  form.items = (data.items || []).map(raw => {
    const stockObj = raw.stock_id ? stocks.value.find(x => x.id === raw.stock_id) : null
    return {
      pick: stockObj || raw.name || null,
      stock_id: raw.stock_id || null,
      name: raw.name || '',
      qty: Number(raw.qty || 0),
      unit_price: Number(raw.unit_price || 0),
      discount_percent: Number(raw.discount_percent || 0),
      _current_stock: stockObj?.total_quantity ?? null,
      _committed_qty: stockObj?.committed_qty ?? (raw._committed_qty ?? null),
      _available_stock: stockObj?.available_quantity ?? null,
    }
  })
}

onMounted(async () => {
  await branchStore.load()
  if (branchLocked.value) {
    form.branch = branchStore.currentBranchId
  } else if (branchStore.currentBranchId) {
    form.branch = branchStore.currentBranchId
  } else if (branchStore.activeBranches.length) {
    form.branch = branchStore.activeBranches[0].id
  }

  const safe = (p, params) => $api.get(p, { params }).then(res => res.data?.results || res.data || []).catch(() => [])
  const stockParams = { page_size: 1000 }
  if (form.branch) stockParams.branch = form.branch
  ;[customers.value, stocks.value] = await Promise.all([
    safe('/pos/customers/'),
    safe('/inventory/stocks/', stockParams),
  ])
  itemSearchResults.value = stocks.value.map(s => ({ ...s }))
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
    topError.value = 'Please choose a customer and ensure each item has an item and quantity.'
    return
  }
  const payload = {
    so_number: form.so_number || undefined,
    customer: form.customer || undefined,
    customer_name: form.customer_name || (typeof customerPick.value === 'string' ? customerPick.value.trim() : ''),
    customer_phone: form.customer_phone || '',
    branch: form.branch || undefined,
    status: form.status,
    amount_paid: Number(form.amount_paid || 0),
    payment_method: form.payment_method,
    discount_amount: Number(form.discount_amount || 0),
    delivery_fee: Number(form.delivery_fee || 0),
    expected_delivery: form.expected_delivery || null,
    delivery_address: form.delivery_address || '',
    delivery_place_name: form.delivery_place_name || '',
    delivery_lat: form.delivery_lat,
    delivery_lng: form.delivery_lng,
    notes: form.notes,
    items: form.items.map(it => ({
      stock_id: it.stock_id,
      name: it.name,
      qty: Number(it.qty || 0),
      unit_price: Number(it.unit_price || 0),
      discount_percent: Number(it.discount_percent || 0),
    })),
  }
  saving.value = true
  try {
    loadId.value
      ? await r.update(loadId.value, payload)
      : await r.create(payload)
    snack.text = 'Sales order saved'
    snack.color = 'success'
    snack.show = true
    router.push('/sales-orders')
  } catch (e) {
    const data = e?.response?.data
    topError.value = (data && (data.detail || JSON.stringify(data))) || r.error.value || 'Save failed.'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.so-shell { max-width: 1400px; margin: 0 auto; }
.so-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

.so-items { display: flex; flex-direction: column; gap: 10px; }
.so-item-row {
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
.so-item-row:hover {
  border-color: rgba(99, 102, 241, 0.45);
  box-shadow: 0 4px 14px rgba(99, 102, 241, 0.08);
}
.so-item-num {
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
.so-item-body { flex: 1; min-width: 0; }
.so-item-remove { position: absolute; top: 6px; right: 6px; }

.so-addr-list {
  background: white;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 12px 28px -14px rgba(15, 23, 42, 0.25);
  min-width: 320px;
}
:global(.v-theme--dark .so-addr-list) {
  background: rgb(30, 41, 59);
  border-color: rgba(255, 255, 255, 0.1);
}

.so-summary {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  overflow: hidden;
}
.so-summary-header {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
}
.so-summary-stat {
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(99, 102, 241, 0.06);
  height: 100%;
}
.so-summary-stat.is-total {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
}
</style>
