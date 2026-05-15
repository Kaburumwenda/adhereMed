<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Stock Item' : 'New Stock Item'"
    :subtitle="loadId ? 'Update inventory details and stock levels' : 'Register a new item in your inventory'"
    icon="mdi-package-variant-plus"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    :transform="transformPayload"
    @saved="onSaved"
  >
    <template #default="{ form }">
      <ClientOnly>
        <span v-if="autofill(form)" />
        <span v-if="syncEdit(form)" />
      </ClientOnly>

      <!-- ── Section 1 · Item Details ─────────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-primary">
            <v-icon size="18" color="white">mdi-tag-outline</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Item Details</div>
            <div class="stock-section__sub">Name, code, and classification</div>
          </div>
        </div>
        <v-row>
          <v-col cols="12" md="6">
            <v-combobox
              v-model="nameSelection"
              :items="catalogResults"
              :item-title="item => typeof item === 'string' ? item : item.generic_name"
              :item-value="item => typeof item === 'string' ? item : item.generic_name"
              :search="nameQuery"
              :loading="catalogLoading"
              label="Item Name *"
              :rules="req"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              no-filter
              clearable
              return-object
              placeholder="Search medication catalog or type a name..."
              @update:search="onNameSearch"
              @update:model-value="onNameSelected($event, form)"
            >
              <template #no-data><div /></template>
              <template #item="{ item, props: ip }">
                <v-list-item v-bind="ip" :title="undefined" :subtitle="undefined">
                  <template #prepend>
                    <v-icon size="18" color="primary">mdi-book-outline</v-icon>
                  </template>
                  <template #title>{{ item.raw?.generic_name || item.title }}</template>
                  <template #subtitle>{{ [item.raw?.dosage_form, item.raw?.strength].filter(Boolean).join(' · ') || 'Catalog item' }}</template>
                </v-list-item>
              </template>
            </v-combobox>

            <!-- Not in catalog warning -->
            <v-alert v-if="showNotInCatalog && !loadId" type="warning" variant="tonal" rounded="lg" class="mt-n2 mb-2">
              <template #prepend><v-icon size="18">mdi-alert-outline</v-icon></template>
              <div class="text-body-2">"<strong>{{ nameQuery }}</strong>" is not in the medication catalog. Please add it to the catalog first.</div>
              <div class="d-flex ga-2 mt-3">
                <v-btn size="small" variant="flat" color="warning" rounded="lg" class="text-none" prepend-icon="mdi-book-plus-outline" @click="router.push('/pharmacy/medications')">
                  Go to Catalog
                </v-btn>
              </div>
            </v-alert>

            <!-- Duplicate warning -->
            <v-alert v-if="existingStock && !loadId" type="error" variant="tonal" rounded="lg" class="mt-n2 mb-2">
              <template #prepend><v-icon size="18">mdi-alert-circle-outline</v-icon></template>
              <div class="text-body-2">
                <strong>{{ existingStock.medication_name }}</strong> already exists in your inventory
                <span v-if="existingStock.total_quantity != null" class="text-medium-emphasis">
                  · {{ existingStock.total_quantity }} in stock
                </span>
              </div>
              <div class="text-body-2 text-medium-emphasis mt-1">To avoid duplicate entries, edit the existing item instead.</div>
              <div class="d-flex ga-2 mt-3">
                <v-btn size="small" variant="flat" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-pencil-outline" @click="goEditExisting">
                  Edit Existing Item
                </v-btn>
                <v-btn size="small" variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-swap-vertical" @click="goAdjust">
                  Stock Adjustment
                </v-btn>
              </div>
            </v-alert>
          </v-col>
          <v-col v-if="!loadId" cols="12" md="6">
            <v-text-field v-model="form.barcode" label="SKU / Code" placeholder="Auto-generated" persistent-hint hint="Generated automatically" variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled">
              <template #append-inner>
                <v-tooltip text="Regenerate SKU" location="top">
                  <template #activator="{ props: tp }">
                    <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="form.barcode = generateSku()" />
                  </template>
                </v-tooltip>
              </template>
            </v-text-field>
          </v-col>
          <v-col cols="12" md="6">
            <v-autocomplete v-model="form.category" :items="categories" item-title="name" item-value="id" label="Category" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" md="6">
            <v-autocomplete v-model="form.unit" :items="units" item-title="name" item-value="id" label="Unit of Measure" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" md="6" class="d-flex align-center">
            <v-switch
              v-model="form.is_active"
              :label="form.is_active ? 'Active' : 'Inactive'"
              color="success"
              density="comfortable"
              hide-details
              inset
              :disabled="formDisabled"
            />
          </v-col>
        </v-row>
      </div>

      <v-divider class="my-1" />

      <!-- ── Section 2 · Stock Levels ─────────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-teal">
            <v-icon size="18" color="white">mdi-cube-outline</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Stock Levels</div>
            <div class="stock-section__sub">Quantity and reorder thresholds</div>
          </div>
          <v-chip size="x-small" variant="tonal" color="teal" class="ml-auto" label>
            <v-icon start size="12">mdi-auto-fix</v-icon> Auto-calculated
          </v-chip>
        </div>
        <v-card variant="flat" rounded="xl" class="pa-4 inner-card">
          <v-row>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.quantity" :label="(loadId ? 'Current Stock Qty' : 'Initial Quantity') + ' *'" type="number" min="0" :rules="reqNum" :hint="loadId ? 'Edits create a Count Correction' : 'Stock on hand'" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" @update:model-value="recalc(form, $event)" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.reorder_level" label="Reorder Level" type="number" min="0" :hint="levelTouched ? 'Custom value' : 'Auto: 30 % of qty'" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" @update:model-value="levelTouched = true">
                <template #append-inner>
                  <v-tooltip text="Reset to 30% of quantity" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="resetLevel(form)" />
                    </template>
                  </v-tooltip>
                </template>
              </v-text-field>
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.reorder_quantity" label="Reorder Quantity" type="number" min="0" :hint="qtyTouched ? 'Custom value' : 'Auto: 50 % of qty'" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" @update:model-value="qtyTouched = true">
                <template #append-inner>
                  <v-tooltip text="Reset to 50% of quantity" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="resetQty(form)" />
                    </template>
                  </v-tooltip>
                </template>
              </v-text-field>
            </v-col>
          </v-row>
        </v-card>
      </div>

      <v-divider class="my-1" />

      <!-- ── Section 3 · Pricing ──────────────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-amber-darken-1">
            <v-icon size="18" color="white">mdi-cash-register</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Pricing</div>
            <div class="stock-section__sub">Cost, selling price, and discounts</div>
          </div>
        </div>
        <v-row>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.cost_price" label="Unit Cost (Before Tax) *" type="number" step="0.01" :rules="reqNum" variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.tax_percent" label="VAT / Tax" type="number" min="0" max="100" step="0.01" suffix="%" hint="Applied on cost price" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.selling_price" label="Selling Price *" type="number" step="0.01" variant="outlined" density="comfortable" rounded="lg" :rules="reqNum" :hint="taxHint(form)" persistent-hint :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.discount_percent" label="Default Discount" type="number" min="0" max="100" step="0.01" suffix="%" hint="Applied at POS" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
        </v-row>

        <!-- Profit Analysis -->
        <v-card variant="tonal" :color="marginColor(form)" rounded="xl" class="pa-5 mt-3 profit-card" :class="'profit-card--' + marginColor(form)">
          <div class="d-flex align-center mb-4">
            <v-icon :color="marginColor(form)" size="22" class="mr-2">mdi-chart-line-variant</v-icon>
            <span class="text-subtitle-2 font-weight-bold text-uppercase" style="letter-spacing:.5px">Profit Analysis</span>
            <v-spacer />
            <v-chip size="x-small" variant="outlined" :color="marginColor(form)" label>
              <v-icon start size="12">mdi-autorenew</v-icon> Live
            </v-chip>
          </div>
          <v-row dense>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">Tax per unit</div>
                <div class="profit-metric__value">{{ formatMoney(taxPerUnit(form)) }}</div>
                <div class="profit-metric__hint">Cost incl. tax: {{ formatMoney(costWithTax(form)) }}</div>
              </div>
            </v-col>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">Margin per unit</div>
                <div class="profit-metric__value">{{ formatMoney(margin(form)) }}</div>
                <div v-if="(Number(form.discount_percent) || 0) > 0" class="profit-metric__hint">
                  After {{ Number(form.discount_percent).toFixed(1) }}% disc. ({{ formatMoney(effectivePrice(form)) }} ea)
                </div>
              </div>
            </v-col>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">Margin %</div>
                <div class="profit-metric__value">{{ marginPercent(form).toFixed(1) }}%</div>
              </div>
            </v-col>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">
                  Total profit
                  <span class="text-medium-emphasis">({{ Number(form.quantity) || 0 }} units)</span>
                </div>
                <div class="profit-metric__value">{{ formatMoney(totalProfit(form)) }}</div>
                <div v-if="(Number(form.tax_percent) || 0) > 0" class="profit-metric__hint">
                  Total tax: {{ formatMoney(taxPerUnit(form) * (Number(form.quantity) || 0)) }}
                </div>
                <div v-if="(Number(form.discount_percent) || 0) > 0" class="profit-metric__hint text-error">
                  − {{ formatMoney(discountAmount(form) * (Number(form.quantity) || 0)) }} discount
                </div>
              </div>
            </v-col>
          </v-row>
        </v-card>
      </div>

      <v-divider class="my-1" />

      <!-- ── Section 4 · Batch & Expiry ───────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-deep-purple">
            <v-icon size="18" color="white">mdi-barcode</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Batch & Expiry</div>
            <div class="stock-section__sub">Tracking and shelf life</div>
          </div>
        </div>
        <v-row>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.batch_number" label="Batch Number" placeholder="Auto-generated" readonly persistent-hint hint="Generated automatically" variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled">
              <template #append-inner>
                <v-tooltip text="Regenerate batch #" location="top">
                  <template #activator="{ props: tp }">
                    <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="form.batch_number = generateBatch()" />
                  </template>
                </v-tooltip>
              </template>
            </v-text-field>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.expiry_date" label="Expiry Date" type="date" variant="outlined" density="comfortable" rounded="lg" hint="Default: 5 years from today. Change if needed." persistent-hint clearable :disabled="formDisabled" />
          </v-col>
        </v-row>
      </div>

      <v-divider class="my-1" />

      <!-- ── Section 5 · Additional Details ───────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-blue-grey">
            <v-icon size="18" color="white">mdi-text-box-outline</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Additional Details</div>
            <div class="stock-section__sub">Optional notes or description</div>
          </div>
        </div>
        <v-row>
          <v-col cols="12">
            <v-textarea v-model="form.description" label="Description" rows="3" auto-grow variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
        </v-row>
      </div>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/inventory/stocks/')
const req = [v => !!v || 'Required']
const reqNum = [v => (v !== null && v !== '' && v !== undefined) || 'Required']

// ── Catalog search + duplicate detection ─────────────
const nameQuery = ref('')
const nameSelection = ref(null)
const catalogResults = ref([])
const catalogLoading = ref(false)
const existingStock = ref(null)
const showNotInCatalog = ref(false)
let searchTimer = null

// Disable all fields except item name when item not in catalog or already exists in inventory
const formDisabled = computed(() => !loadId.value && (showNotInCatalog.value || !!existingStock.value))

function onNameSearch(val) {
  nameQuery.value = val
  clearTimeout(searchTimer)
  if (!val || val.length < 2) {
    catalogResults.value = []
    existingStock.value = null
    showNotInCatalog.value = false
    return
  }
  catalogLoading.value = true
  searchTimer = setTimeout(() => searchCatalogAndInventory(val), 300)
}

async function searchCatalogAndInventory(q) {
  try {
    const [catRes, invRes] = await Promise.all([
      $api.get('/medications/search/', { params: { q } }).catch(() => ({ data: [] })),
      $api.get('/inventory/stocks/', { params: { search: q, page_size: 10 } }).catch(() => ({ data: { results: [] } })),
    ])
    const catalogItems = (Array.isArray(catRes.data) ? catRes.data : catRes.data?.results || []).map(m => ({ ...m, _source: 'catalog' }))
    catalogResults.value = catalogItems
    // Show "not in catalog" alert when search returns no results
    showNotInCatalog.value = q.length >= 2 && catalogItems.length === 0
    // Check for existing inventory match (exact or close)
    const invItems = invRes.data?.results || invRes.data || []
    const exact = invItems.find(s => s.medication_name?.toLowerCase() === q.toLowerCase())
    existingStock.value = exact || null
  } catch { /* swallow */ } finally {
    catalogLoading.value = false
  }
}

// ── Category / Unit mapping from Medication catalog ──
const MEDICATION_CATEGORY_LABELS = {
  analgesic: 'Analgesic / Pain Reliever', antibiotic: 'Antibiotic', antifungal: 'Antifungal',
  antiviral: 'Antiviral', antiparasitic: 'Antiparasitic', antimalarial: 'Antimalarial',
  antihypertensive: 'Antihypertensive', antidiabetic: 'Antidiabetic', antihistamine: 'Antihistamine',
  antacid: 'Antacid / GI', cardiovascular: 'Cardiovascular', respiratory: 'Respiratory',
  cns: 'Central Nervous System', hormone: 'Hormonal', vitamin: 'Vitamin / Supplement',
  vaccine: 'Vaccine', dermatological: 'Dermatological', ophthalmic: 'Ophthalmic',
  oncology: 'Oncology', immunosuppressant: 'Immunosuppressant', nsaid: 'NSAID', other: 'Other',
}

function matchCategory(catalogCategory) {
  if (!catalogCategory) return null
  const label = (MEDICATION_CATEGORY_LABELS[catalogCategory] || catalogCategory).toLowerCase()
  const key = catalogCategory.toLowerCase()
  return categories.value.find(c => {
    const n = c.name.toLowerCase()
    return n === key || n === label || n.includes(key) || label.includes(n)
  })?.id || null
}

function matchUnit(catalogUnit) {
  if (!catalogUnit) return null
  const u = catalogUnit.toLowerCase()
  return units.value.find(x => {
    const n = x.name.toLowerCase()
    const a = (x.abbreviation || '').toLowerCase()
    return n === u || a === u || n.includes(u) || u.includes(n)
  })?.id || null
}

function onNameSelected(val, form) {
  if (!val) {
    form.medication_name = ''
    existingStock.value = null
    showNotInCatalog.value = false
    return
  }
  if (typeof val === 'object' && val.generic_name) {
    // Selected from catalog
    form.medication_name = val.generic_name
    showNotInCatalog.value = false
    // Auto-fill description from catalog if empty
    if (!form.description && val.description) form.description = val.description
    // Auto-populate category and unit of measure from catalog
    const cat = matchCategory(val.category)
    if (cat) form.category = cat
    const unit = matchUnit(val.unit || val.dosage_form)
    if (unit) form.unit = unit
    // Re-check inventory for this exact name
    checkInventoryDuplicate(val.generic_name)
  } else {
    // Typed text not from catalog
    const text = typeof val === 'string' ? val : val?.generic_name || String(val)
    form.medication_name = text
    showNotInCatalog.value = text.length >= 2 && !catalogResults.value.some(c => c.generic_name?.toLowerCase() === text.toLowerCase())
    checkInventoryDuplicate(text)
  }
}

async function checkInventoryDuplicate(name) {
  if (!name || name.length < 2) { existingStock.value = null; return }
  try {
    const res = await $api.get('/inventory/stocks/', { params: { search: name, page_size: 5 } })
    const items = res.data?.results || res.data || []
    const exact = items.find(s => s.medication_name?.toLowerCase() === name.toLowerCase())
    existingStock.value = exact || null
  } catch { existingStock.value = null }
}

function goEditExisting() {
  if (existingStock.value?.id) {
    router.push(`/inventory/stocks/${existingStock.value.id}/edit`)
  }
}

function goAdjust() {
  if (existingStock.value?.id) {
    router.push(`/inventory/adjustments/new?stock=${existingStock.value.id}`)
  } else {
    router.push('/inventory/adjustments/new')
  }
}

function costWithTax(form) {
  const cost = Number(form.cost_price) || 0
  const tax = Math.min(Math.max(Number(form.tax_percent) || 0, 0), 100)
  return cost * (1 + tax / 100)
}
function taxPerUnit(form) {
  return costWithTax(form) - (Number(form.cost_price) || 0)
}
function taxHint(form) {
  const tax = Number(form.tax_percent) || 0
  if (tax > 0) return `Cost + ${tax}% tax = ${formatMoney(costWithTax(form))}`
  return ''
}
function margin(form) {
  return effectivePrice(form) - costWithTax(form)
}
function effectivePrice(form) {
  const sp = Number(form.selling_price) || 0
  const d = Math.min(Math.max(Number(form.discount_percent) || 0, 0), 100)
  return sp * (1 - d / 100)
}
function discountAmount(form) {
  return (Number(form.selling_price) || 0) - effectivePrice(form)
}
function marginPercent(form) {
  const cost = costWithTax(form)
  if (cost <= 0) return 0
  return (margin(form) / cost) * 100
}
function totalProfit(form) {
  return margin(form) * (Number(form.quantity) || 0)
}
function marginColor(form) {
  const m = margin(form)
  if (m < 0) return 'error'
  if (m === 0) return 'warning'
  return 'success'
}

function ymd(d = new Date()) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}${m}${day}`
}
function rand(n = 4) {
  return Math.random().toString(36).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, n).padEnd(n, '0')
}
function generateSku()   { return `SKU-${ymd()}-${rand(4)}` }
function generateBatch() { return `BN-${ymd()}-${rand(4)}` }

// Auto-fill on create only; never overwrite existing values (e.g. when editing)
const filled = ref(false)
function autofill(form) {
  if (filled.value || loadId.value) return false
  if (!form.barcode) form.barcode = generateSku()
  if (!form.batch_number) form.batch_number = generateBatch()
  filled.value = true
  return false
}

// On edit: mirror server-computed total_quantity into the displayed quantity field once loaded.
// total_quantity is NOT in `initial`, so it is undefined until the API response populates it.
const synced = ref(false)
const originalQty = ref(0)
const latestBatchId = ref(null)
function syncEdit(form) {
  if (!loadId.value || synced.value) return false
  if (form.total_quantity !== undefined) {
    const qty = Number(form.total_quantity) || 0
    form.quantity = qty
    originalQty.value = qty
    // Mirror latest batch info (batch_number/expiry_date are write-only on the serializer,
    // so they only come back nested under `batches`).
    const batches = Array.isArray(form.batches) ? form.batches.slice() : []
    if (batches.length) {
      // Pick the most recently received (or latest expiry) batch
      batches.sort((a, b) => {
        const ar = a.received_date || a.expiry_date || ''
        const br = b.received_date || b.expiry_date || ''
        return br.localeCompare(ar)
      })
      const latest = batches[0]
      latestBatchId.value = latest.id || null
      if (!form.batch_number) form.batch_number = latest.batch_number || ''
      if (!form.expiry_date)  form.expiry_date  = latest.expiry_date  || ''
    }
    if (!form.barcode) form.barcode = '' // ensure reactive key exists
    synced.value = true
  }
  return false
}

async function onSaved() {
  // If editing and quantity changed, create a count-correction adjustment to apply the delta.
  if (loadId.value && desiredQty.value != null && latestBatchId.value) {
    const delta = desiredQty.value - originalQty.value
    if (delta !== 0) {
      try {
        await $api.post('/inventory/adjustments/', {
          stock: loadId.value,
          batch: latestBatchId.value,
          quantity_change: delta,
          reason: 'count_correction',
          notes: 'Adjusted from stock edit form',
        })
      } catch (e) {
        console.warn('Failed to create stock adjustment:', e)
      }
    }
  }
  router.push('/inventory')
}

// Track the desired quantity entered by the user (captured in transformPayload)
const desiredQty = ref(null)

// Auto-calculate reorder level (30%) and reorder quantity (50%) from quantity.
// User overrides flip the *touched* flags, after which auto recalc stops.
const levelTouched = ref(false)
const qtyTouched = ref(false)
function recalc(form, raw) {
  const q = Math.max(0, Number(raw) || 0)
  if (!levelTouched.value) form.reorder_level = Math.round(q * 0.30)
  if (!qtyTouched.value)   form.reorder_quantity = Math.round(q * 0.50)
}
function resetLevel(form) {
  levelTouched.value = false
  form.reorder_level = Math.round((Number(form.quantity) || 0) * 0.30)
}
function resetQty(form) {
  qtyTouched.value = false
  form.reorder_quantity = Math.round((Number(form.quantity) || 0) * 0.50)
}

function defaultExpiry() {
  const d = new Date()
  d.setFullYear(d.getFullYear() + 5)
  return d.toISOString().slice(0, 10)
}
const initial = { medication_name: '', barcode: '', category: null, unit: null, is_active: true, quantity: 0, reorder_level: 0, reorder_quantity: 0, cost_price: 0, tax_percent: 0, selling_price: 0, discount_percent: 0, batch_number: '', expiry_date: defaultExpiry(), description: '' }
const categories = ref([]); const units = ref([])

// Sync nameSelection when editing an existing item
watch(loadId, (id) => { if (id) { showNotInCatalog.value = false } }, { immediate: true })

// Map form fields to backend payload. Strip read-only/derived fields.
function transformPayload(data) {
  const payload = { ...data }
  // total_quantity is server-computed and read-only
  delete payload.total_quantity
  // Strip empty expiry_date so backend doesn't reject it
  if (!payload.expiry_date) delete payload.expiry_date
  if (loadId.value) {
    // Capture the desired quantity for post-save adjustment, but don't send it
    desiredQty.value = Number(payload.quantity) || 0
    delete payload.quantity
    delete payload.initial_quantity
  } else {
    // On create: rename quantity -> initial_quantity for the first batch
    if (payload.quantity != null) {
      payload.initial_quantity = payload.quantity
      delete payload.quantity
    }
  }
  return payload
}
onMounted(async () => {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  categories.value = await safe('/inventory/categories/')
  units.value = await safe('/inventory/units/')
})
</script>

<style scoped>
/* ── Section Layout ─────────────────────────────────── */
.stock-section {
  padding: 20px 0 12px;
}
.stock-section__header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}
.stock-section__icon {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.stock-section__title {
  font-size: 0.95rem;
  font-weight: 600;
  line-height: 1.2;
}
.stock-section__sub {
  font-size: 0.78rem;
  opacity: 0.55;
  margin-top: 1px;
}

/* ── Stock-levels inner card ────────────────────────── */
.inner-card {
  background: rgba(var(--v-theme-surface-variant), 0.2);
  border: 1px solid rgba(var(--v-theme-outline), 0.08);
}

/* ── Profit Analysis Card ───────────────────────────── */
.profit-card {
  transition: box-shadow 0.2s ease;
}
.profit-card--success { border-left: 4px solid rgb(var(--v-theme-success)); }
.profit-card--warning { border-left: 4px solid rgb(var(--v-theme-warning)); }
.profit-card--error   { border-left: 4px solid rgb(var(--v-theme-error)); }

.profit-metric {
  padding: 6px 0;
}
.profit-metric__label {
  font-size: 0.72rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  opacity: 0.6;
  margin-bottom: 4px;
}
.profit-metric__value {
  font-size: 1.35rem;
  font-weight: 700;
  line-height: 1.3;
}
.profit-metric__hint {
  font-size: 0.75rem;
  opacity: 0.55;
  margin-top: 2px;
}
</style>
