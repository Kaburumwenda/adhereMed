<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Stock' : 'Add Stock'"
    icon="mdi-package-variant"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    :transform="transformPayload"
    @saved="onSaved"
  >
    <template #default="{ form }">
      <!-- Auto-fill SKU & batch # once on create -->
      <ClientOnly>
        <span v-if="autofill(form)" />
        <span v-if="syncEdit(form)" />
      </ClientOnly>
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.medication_name" label="Item name" :rules="req" /></v-col>
        <v-col v-if="!loadId" cols="12" sm="6">
          <v-text-field
            v-model="form.barcode"
            label="SKU / Code"
            placeholder="Auto-generated"
            persistent-hint
            hint="Generated automatically"
          >
            <template #append-inner>
              <v-tooltip text="Regenerate SKU" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="form.barcode = generateSku()" />
                </template>
              </v-tooltip>
            </template>
          </v-text-field>
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.category" :items="categories" item-title="name" item-value="id" label="Category" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.unit" :items="units" item-title="name" item-value="id" label="Unit" />
        </v-col>
        <v-col cols="6" sm="3">
          <v-text-field
            v-model.number="form.quantity"
            :label="loadId ? 'Quantity (current stock)' : 'Initial quantity'"
            type="number"
            min="0"
            :hint="loadId ? 'Edits create a Count Correction adjustment' : 'Stock on hand'"
            persistent-hint
            @update:model-value="recalc(form, $event)"
          />
        </v-col>
        <v-col cols="6" sm="3">
          <v-text-field
            v-model.number="form.reorder_level"
            label="Reorder level"
            type="number"
            min="0"
            :hint="levelTouched ? 'Custom value' : 'Auto: 30% of quantity'"
            persistent-hint
            @update:model-value="levelTouched = true"
          >
            <template #append-inner>
              <v-tooltip text="Reset to 30% of quantity" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="resetLevel(form)" />
                </template>
              </v-tooltip>
            </template>
          </v-text-field>
        </v-col>
        <v-col cols="6" sm="3">
          <v-text-field
            v-model.number="form.reorder_quantity"
            label="Reorder quantity"
            type="number"
            min="0"
            :hint="qtyTouched ? 'Custom value' : 'Auto: 50% of quantity'"
            persistent-hint
            @update:model-value="qtyTouched = true"
          >
            <template #append-inner>
              <v-tooltip text="Reset to 50% of quantity" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="resetQty(form)" />
                </template>
              </v-tooltip>
            </template>
          </v-text-field>
        </v-col>
        <v-col cols="6" sm="3"><v-text-field v-model.number="form.cost_price" label="Unit Cost (Before Tax)" type="number" step="0.01" /></v-col>
        <v-col cols="6" sm="3"><v-text-field v-model.number="form.selling_price" label="Unit Selling Price (Inc. Tax)" type="number" step="0.01" /></v-col>
        <v-col cols="12">
          <v-card variant="tonal" :color="marginColor(form)" rounded="lg" class="pa-3">
            <div class="d-flex flex-wrap align-center" style="gap:18px">
              <v-icon :color="marginColor(form)">mdi-chart-line-variant</v-icon>
              <div>
                <div class="text-caption text-medium-emphasis text-uppercase">Profit margin</div>
                <div class="text-h6 font-weight-bold">
                  {{ formatMoney(margin(form)) }}
                  <span class="text-body-2 font-weight-regular text-medium-emphasis">per unit</span>
                </div>
                <div v-if="(Number(form.discount_percent) || 0) > 0" class="text-caption text-medium-emphasis">
                  After {{ Number(form.discount_percent).toFixed(2) }}% discount ({{ formatMoney(effectivePrice(form)) }} ea)
                </div>
              </div>
              <v-divider vertical />
              <div>
                <div class="text-caption text-medium-emphasis text-uppercase">Margin %</div>
                <div class="text-h6 font-weight-bold">{{ marginPercent(form).toFixed(2) }}%</div>
              </div>
              <v-divider vertical />
              <div>
                <div class="text-caption text-medium-emphasis text-uppercase">
                  Total profit <span class="text-medium-emphasis">({{ Number(form.quantity) || 0 }} units)</span>
                </div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(totalProfit(form)) }}</div>
                <div v-if="(Number(form.discount_percent) || 0) > 0" class="text-caption text-error">
                  − {{ formatMoney(discountAmount(form) * (Number(form.quantity) || 0)) }} discount given
                </div>
              </div>
              <v-spacer />
              <span class="text-caption text-medium-emphasis">Computed live · not stored</span>
            </div>
          </v-card>
        </v-col>
        <v-col cols="6" sm="3">
          <v-text-field
            v-model.number="form.discount_percent"
            label="Discount %"
            type="number"
            min="0"
            max="100"
            step="0.01"
            suffix="%"
            hint="Default discount at POS"
            persistent-hint
          />
        </v-col>
        <v-col cols="12" sm="6">
          <v-text-field
            v-model="form.batch_number"
            label="Batch #"
            placeholder="Auto-generated"
            readonly
            persistent-hint
            hint="Generated automatically"
          >
            <template #append-inner>
              <v-tooltip text="Regenerate batch #" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="form.batch_number = generateBatch()" />
                </template>
              </v-tooltip>
            </template>
          </v-text-field>
        </v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.expiry_date" label="Expiry date" type="date" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.description" label="Description" rows="2" auto-grow /></v-col>
      </v-row>
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

function margin(form) {
  return effectivePrice(form) - (Number(form.cost_price) || 0)
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
  const cost = Number(form.cost_price) || 0
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

const initial = { medication_name: '', barcode: '', category: null, unit: null, quantity: 0, reorder_level: 0, reorder_quantity: 0, cost_price: 0, selling_price: 0, discount_percent: 0, batch_number: '', expiry_date: '', description: '' }
const categories = ref([]); const units = ref([])

// Map form fields to backend payload. Strip read-only/derived fields.
function transformPayload(data) {
  const payload = { ...data }
  // total_quantity is server-computed and read-only
  delete payload.total_quantity
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
