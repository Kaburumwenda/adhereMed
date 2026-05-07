<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Adjustment' : 'New Stock Adjustment'"
    icon="mdi-swap-vertical-bold"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    :transform="transformPayload"
    @saved="() => router.push('/inventory')"
  >
    <template #default="{ form }">
      <template v-if="syncEdit(form)" />
      <v-row dense>
        <v-col cols="12">
          <div class="text-caption text-medium-emphasis mb-1">STOCK SELECTION</div>
          <v-divider class="mb-3" />
        </v-col>

        <v-col cols="12" sm="8">
          <v-autocomplete
            v-model="form.stock"
            :items="stocks"
            item-title="medication_name"
            item-value="id"
            label="Stock item"
            placeholder="Search by medication name"
            prepend-inner-icon="mdi-pill"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            :rules="req"
            :loading="loadingStocks"
          >
            <template #item="{ props: itemProps, item }">
              <v-list-item v-bind="itemProps" :title="item.raw.medication_name">
                <template #subtitle>
                  <span class="text-caption">
                    On hand: <strong>{{ item.raw.total_quantity ?? 0 }}</strong>
                    <span v-if="item.raw.barcode"> · {{ item.raw.barcode }}</span>
                  </span>
                </template>
              </v-list-item>
            </template>
          </v-autocomplete>
        </v-col>

        <v-col cols="12" sm="4">
          <v-text-field
            label="Current on-hand"
            :model-value="stockOnHand(form.stock)"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            readonly
            prepend-inner-icon="mdi-package-variant"
          />
        </v-col>

        <v-col v-if="batchesFor(form.stock).length" cols="12">
          <v-select
            v-model="form.batch"
            :items="batchesFor(form.stock)"
            :item-title="b => `${b.batch_number} · qty ${b.quantity_remaining}${b.expiry_date ? ' · exp ' + b.expiry_date : ''}`"
            item-value="id"
            label="Batch (optional)"
            prepend-inner-icon="mdi-package"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            clearable
          />
        </v-col>

        <v-col cols="12" class="mt-2">
          <div class="text-caption text-medium-emphasis mb-1">ADJUSTMENT</div>
          <v-divider class="mb-3" />
        </v-col>

        <v-col cols="12" sm="6">
          <v-select
            v-model="form.reason"
            :items="reasonOptions"
            item-title="label"
            item-value="value"
            label="Reason"
            prepend-inner-icon="mdi-tag"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            :rules="req"
          />
        </v-col>

        <v-col cols="12" sm="3">
          <v-btn-toggle v-model="form._direction" mandatory variant="outlined" color="primary" rounded="lg" divided density="comfortable" class="d-flex">
            <v-btn value="add" class="text-none flex-grow-1" prepend-icon="mdi-plus">Add</v-btn>
            <v-btn value="remove" class="text-none flex-grow-1" prepend-icon="mdi-minus">Remove</v-btn>
          </v-btn-toggle>
        </v-col>

        <v-col cols="12" sm="3">
          <v-text-field
            v-model.number="form._abs_qty"
            label="Quantity"
            type="number"
            min="1"
            prepend-inner-icon="mdi-counter"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            :rules="qtyRules"
          />
        </v-col>

        <v-col cols="12">
          <v-textarea
            v-model="form.notes"
            label="Notes"
            placeholder="Why is this adjustment being made? Any reference numbers, receipts, etc."
            prepend-inner-icon="mdi-text"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            rows="3"
            auto-grow
          />
        </v-col>

        <v-col v-if="form.stock && Number(form._abs_qty) > 0" cols="12">
          <v-alert
            :type="previewAfter(form) < 0 ? 'error' : form._direction === 'add' ? 'success' : 'warning'"
            variant="tonal"
            density="compact"
            border="start"
          >
            <div class="d-flex align-center flex-wrap" style="gap:14px">
              <div>Current: <strong>{{ stockOnHand(form.stock) }}</strong></div>
              <v-icon size="18">mdi-arrow-right</v-icon>
              <div>After: <strong>{{ previewAfter(form) }}</strong></div>
              <v-chip
                size="small"
                :color="form._direction === 'add' ? 'success' : 'error'"
                variant="flat"
              >
                {{ form._direction === 'add' ? '+' : '-' }}{{ Number(form._abs_qty) || 0 }}
              </v-chip>
            </div>
            <div v-if="previewAfter(form) < 0" class="mt-2 text-caption">
              Warning: this will result in negative stock.
            </div>
          </v-alert>
        </v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'

const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/inventory/adjustments/')

const req = [v => v != null && v !== '' || 'Required']
const qtyRules = [v => (Number(v) > 0) || 'Must be greater than 0']

const reasonOptions = [
  { value: 'count_correction',   label: 'Count correction' },
  { value: 'damage',             label: 'Damage' },
  { value: 'theft',              label: 'Theft' },
  { value: 'expiry',             label: 'Expiry' },
  { value: 'return_to_supplier', label: 'Return to supplier' },
  { value: 'other',              label: 'Other' },
]

const initial = {
  stock: null,
  batch: null,
  reason: 'count_correction',
  notes: '',
  // transient UI fields, stripped in transformPayload
  _abs_qty: 1,
  _direction: 'add',
  // server field (set by transform)
  quantity_change: 0,
}

const stocks = ref([])
const loadingStocks = ref(false)

onMounted(async () => {
  loadingStocks.value = true
  try {
    const res = await $api.get('/inventory/stocks/', { params: { page_size: 5000 } })
    stocks.value = res.data?.results || res.data || []
  } catch { stocks.value = [] } finally { loadingStocks.value = false }
})

function findStock(id) { return stocks.value.find(s => s.id === id) || null }
function stockOnHand(id) { const s = findStock(id); return s ? Number(s.total_quantity || 0) : '—' }
function batchesFor(id) { const s = findStock(id); return s?.batches || [] }
function previewAfter(form) {
  const cur = Number(stockOnHand(form.stock)) || 0
  const sign = form._direction === 'remove' ? -1 : 1
  return cur + sign * (Number(form._abs_qty) || 0)
}

// Hydrate transient fields from loaded record on edit.
const _hydrated = new WeakSet()
function syncEdit(form) {
  if (!loadId.value || !form || _hydrated.has(form)) return false
  if (form.quantity_change != null) {
    _hydrated.add(form)
    form._direction = form.quantity_change < 0 ? 'remove' : 'add'
    form._abs_qty = Math.abs(form.quantity_change)
  }
  return false
}

function transformPayload(payload) {
  const sign = payload._direction === 'remove' ? -1 : 1
  payload.quantity_change = sign * Math.abs(Number(payload._abs_qty) || 0)
  delete payload._abs_qty
  delete payload._direction
  return payload
}
</script>


