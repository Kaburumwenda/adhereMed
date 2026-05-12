<template>
  <v-container fluid class="pa-4 pa-md-6 po-detail-shell">
    <PageHeader
      :title="item ? `Purchase Order ${item.po_number}` : 'Purchase Order'"
      icon="mdi-cart"
      :subtitle="item ? `${item.supplier_name || '—'} • ${formatDate(item.order_date)}` : ''"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/purchase-orders">Back</v-btn>
        <v-btn v-if="item" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-printer" @click="printPO">Print</v-btn>
        <v-btn
          v-if="item && item.status !== 'received' && item.status !== 'cancelled' && item.status !== 'returned'"
          color="success"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-check-circle-outline"
          :loading="busy"
          @click="markReceived"
        >Mark Received</v-btn>
        <v-btn
          v-if="item && (item.status === 'received' || item.status === 'partial')"
          color="error"
          variant="tonal"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-undo-variant"
          @click="openReturn"
        >Return Purchase</v-btn>
        <v-btn v-if="item && item.status !== 'returned'" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-pencil" :to="`/purchase-orders/${id}/edit`">Edit</v-btn>
      </template>
    </PageHeader>

    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <div v-else-if="item">
      <!-- Hero summary card -->
      <v-card rounded="lg" class="po-hero pa-5 pa-md-6 mb-4">
        <v-row align="center">
          <v-col cols="12" md="6">
            <div class="d-flex align-center mb-3">
              <v-avatar size="48" color="white" class="mr-3">
                <v-icon color="primary" size="28">mdi-cart</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption" style="opacity:0.85">PO Number</div>
                <div class="text-h4 font-weight-bold">{{ item.po_number }}</div>
              </div>
            </div>
            <div class="d-flex flex-wrap ga-2 align-center">
              <StatusChip :status="item.status" />
              <v-chip size="small" variant="flat" color="white" prepend-icon="mdi-truck-delivery" class="text-primary font-weight-bold">{{ item.supplier_name || '—' }}</v-chip>
              <v-chip size="small" variant="flat" color="white" prepend-icon="mdi-calendar" class="text-primary font-weight-bold">Ordered {{ formatDate(item.order_date) }}</v-chip>
              <v-chip v-if="item.expected_delivery" size="small" variant="flat" color="white" prepend-icon="mdi-calendar-clock" class="text-primary font-weight-bold">Expected {{ formatDate(item.expected_delivery) }}</v-chip>
            </div>
          </v-col>
          <v-col cols="12" md="6" class="text-md-end">
            <div class="text-caption" style="opacity:0.85">Total cost</div>
            <div class="text-h3 font-weight-bold">{{ formatMoney(item.total_cost) }}</div>
            <div class="text-caption mt-1" style="opacity:0.85">{{ totalItems }} items • {{ totalQty }} units</div>
          </v-col>
        </v-row>
      </v-card>

      <!-- Items (full width) -->
      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 po-card">
        <div class="d-flex align-center mb-3">
          <v-icon color="primary" class="mr-2">mdi-package-variant</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Items</div>
          <v-chip size="x-small" variant="tonal" color="primary" class="ml-2">{{ (item.items || []).length }}</v-chip>
        </div>
        <v-table class="po-detail-table">
          <thead>
            <tr>
              <th>Item</th>
              <th class="text-end">Qty</th>
              <th class="text-end">Unit cost</th>
              <th class="text-end">Selling</th>
              <th class="text-end">Disc</th>
              <th class="text-end">Margin</th>
              <th>Batch</th>
              <th>Expiry</th>
              <th class="text-end">Subtotal</th>
              <th class="text-center">Synced</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(it, i) in (item.items || [])" :key="i">
              <td class="font-weight-medium">{{ it.name || '—' }}</td>
              <td class="text-end">{{ it.qty || it.quantity || 0 }}</td>
              <td class="text-end">{{ formatMoney(it.unit_cost || it.unit_price || 0) }}</td>
              <td class="text-end">{{ formatMoney(it.unit_selling_price || 0) }}</td>
              <td class="text-end">{{ it.discount_percent || 0 }}%</td>
              <td class="text-end">
                <v-chip size="x-small" variant="tonal" :color="marginColor(it)">{{ marginPct(it).toFixed(1) }}%</v-chip>
              </td>
              <td><span v-if="it.batch_number">{{ it.batch_number }}</span><span v-else class="text-medium-emphasis">—</span></td>
              <td><span v-if="it.expiry_date">{{ formatDate(it.expiry_date) }}</span><span v-else class="text-medium-emphasis">—</span></td>
              <td class="text-end font-weight-bold">{{ formatMoney(it.total || (Number(it.qty || it.quantity || 0) * Number(it.unit_cost || it.unit_price || 0))) }}</td>
              <td class="text-center">
                <v-icon v-if="it._synced" color="success" size="18">mdi-check-circle</v-icon>
                <v-icon v-else color="grey" size="18">mdi-circle-outline</v-icon>
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr>
              <td colspan="8" class="text-end font-weight-bold">Total</td>
              <td class="text-end text-h6 font-weight-bold text-primary">{{ formatMoney(item.total_cost) }}</td>
              <td></td>
            </tr>
          </tfoot>
        </v-table>
      </v-card>

      <!-- Notes (full width) -->
      <v-card v-if="item.notes" rounded="lg" class="pa-4 pa-md-5 mb-4 po-card">
        <div class="d-flex align-center mb-2">
          <v-icon color="primary" class="mr-2">mdi-note-text-outline</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Notes</div>
        </div>
        <div class="text-body-2" style="white-space: pre-wrap">{{ item.notes }}</div>
      </v-card>

      <!-- Details + Goods Received side by side -->
      <v-row dense>
        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 pa-md-5 po-card h-100">
            <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
              <v-icon color="primary" class="mr-2">mdi-information-outline</v-icon>Details
            </div>
            <div class="po-meta">
              <div><span class="text-medium-emphasis">PO Number</span><span class="font-weight-bold">{{ item.po_number }}</span></div>
              <div><span class="text-medium-emphasis">Supplier</span><span>{{ item.supplier_name || '—' }}</span></div>
              <div><span class="text-medium-emphasis">Ordered by</span><span>{{ item.ordered_by_name || '—' }}</span></div>
              <div><span class="text-medium-emphasis">Order date</span><span>{{ formatDate(item.order_date) }}</span></div>
              <div><span class="text-medium-emphasis">Expected</span><span>{{ item.expected_delivery ? formatDate(item.expected_delivery) : '—' }}</span></div>
              <div><span class="text-medium-emphasis">Created</span><span>{{ formatDate(item.created_at) }}</span></div>
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" md="6">
          <v-card rounded="lg" class="pa-4 pa-md-5 po-card h-100">
            <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
              <v-icon color="primary" class="mr-2">mdi-package-variant-closed-check</v-icon>Goods Received
            </div>
            <EmptyState
              v-if="!(item.grns && item.grns.length)"
              icon="mdi-package-variant-closed"
              title="No GRNs yet"
              :message="item.status === 'received' ? 'Stock batches were created automatically.' : 'No goods received notes recorded.'"
            />
            <v-list v-else density="compact">
              <v-list-item
                v-for="g in item.grns"
                :key="g.id"
                :title="`GRN ${g.grn_number}`"
                :subtitle="`${formatDate(g.received_date)} • ${g.received_by_name || '—'}`"
                prepend-icon="mdi-package-check"
              />
            </v-list>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Return purchase dialog -->
    <v-dialog v-model="returnDialog.show" max-width="640" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center text-subtitle-1 font-weight-bold">
          <v-icon color="error" class="mr-2">mdi-alert-octagon</v-icon>
          Return Purchase Order
        </v-card-title>
        <v-card-text>
          <v-alert type="warning" variant="tonal" density="compact" class="mb-3" border="start">
            <div class="font-weight-bold mb-1">This action will reverse the receipt:</div>
            <ul class="ml-4" style="font-size: 13px">
              <li>Stock batches created from this PO will be removed</li>
              <li>Item cost / selling prices will be reset to their previous values</li>
              <li>The PO status will be set to <b>Returned</b></li>
            </ul>
          </v-alert>

          <div v-if="returnDialog.loading" class="text-center py-4">
            <v-progress-circular indeterminate color="primary" size="24" />
          </div>
          <div v-else>
            <v-table density="compact" class="po-return-table">
              <thead>
                <tr>
                  <th>Item</th>
                  <th class="text-end">Received</th>
                  <th class="text-end">Consumed</th>
                  <th class="text-end">Remaining</th>
                  <th class="text-end">Cost (now → prev)</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(p, i) in returnDialog.preview" :key="i" :class="{ 'bg-red-lighten-5': p.consumed > 0 }">
                  <td>{{ p.name }}</td>
                  <td class="text-end">{{ p.received }}</td>
                  <td class="text-end">
                    <span v-if="p.consumed > 0" class="text-error font-weight-bold">{{ p.consumed }}</span>
                    <span v-else>0</span>
                  </td>
                  <td class="text-end">{{ p.remaining }}</td>
                  <td class="text-end" style="font-size: 12px">
                    {{ formatMoney(p.current_cost_price) }} → {{ formatMoney(p.previous_cost_price) }}
                  </td>
                </tr>
                <tr v-if="!returnDialog.preview.length">
                  <td colspan="5" class="text-center text-medium-emphasis py-3">Nothing to return.</td>
                </tr>
              </tbody>
            </v-table>

            <v-alert
              v-if="returnDialog.hasConsumed"
              type="error"
              variant="tonal"
              density="compact"
              class="mt-3"
              border="start"
            >
              <div class="font-weight-bold mb-1">Some stock has already been used!</div>
              <div style="font-size: 13px">
                Items highlighted in red have units already consumed (sold/dispensed). You cannot recover those units.
                Enable <b>Force return</b> to remove only the remaining stock from this PO.
              </div>
              <v-checkbox v-model="returnDialog.force" label="Force return (remove remaining stock only)" density="compact" hide-details color="error" class="mt-2" />
            </v-alert>
          </div>
        </v-card-text>
        <v-card-actions class="px-6 pb-4">
          <v-spacer />
          <v-btn variant="text" @click="returnDialog.show = false" :disabled="returnDialog.busy">Cancel</v-btn>
          <v-btn
            color="error"
            variant="flat"
            :loading="returnDialog.busy"
            :disabled="returnDialog.loading || (returnDialog.hasConsumed && !returnDialog.force) || !returnDialog.preview.length"
            @click="confirmReturn"
          >Confirm Return</v-btn>
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
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/purchase-orders/orders/')

const item = computed(() => r.item.value)
const loading = computed(() => r.loading.value)
const busy = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const totalItems = computed(() => (item.value?.items || []).length)
const totalQty = computed(() => (item.value?.items || []).reduce((s, it) => s + Number(it.qty || it.quantity || 0), 0))

function effectiveSelling(it) {
  const sell = Number(it.unit_selling_price || 0)
  const disc = Number(it.discount_percent || 0)
  return sell * (1 - disc / 100)
}
function marginPct(it) {
  const rev = effectiveSelling(it)
  if (!rev) return 0
  return ((rev - Number(it.unit_cost || it.unit_price || 0)) / rev) * 100
}
function marginColor(it) {
  const m = marginPct(it)
  if (m >= 30) return 'success'
  if (m >= 15) return 'info'
  if (m >= 0) return 'warning'
  return 'error'
}

const returnDialog = reactive({ show: false, loading: false, busy: false, preview: [], hasConsumed: false, force: false })

async function openReturn() {
  returnDialog.show = true
  returnDialog.loading = true
  returnDialog.force = false
  returnDialog.preview = []
  returnDialog.hasConsumed = false
  try {
    const { data } = await $api.get(`/purchase-orders/orders/${id.value}/return_preview/`)
    returnDialog.preview = data?.items || []
    returnDialog.hasConsumed = !!data?.has_consumed
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to load return preview.'
    snack.color = 'error'
    snack.show = true
    returnDialog.show = false
  } finally {
    returnDialog.loading = false
  }
}

async function confirmReturn() {
  returnDialog.busy = true
  try {
    const { data } = await $api.post(`/purchase-orders/orders/${id.value}/return_purchase/`, { force: returnDialog.force })
    let msg = `${item.value.po_number} returned. Stock and prices reverted.`
    if (data?.warnings?.length) msg += ` (${data.warnings.length} warning${data.warnings.length > 1 ? 's' : ''})`
    snack.text = msg
    snack.color = 'success'
    snack.show = true
    returnDialog.show = false
    await r.get(id.value)
  } catch (e) {
    if (e?.response?.status === 409 && e.response.data?.needs_force) {
      returnDialog.hasConsumed = true
      snack.text = 'Some stock already consumed — enable Force return to proceed.'
      snack.color = 'warning'
      snack.show = true
    } else {
      snack.text = e?.response?.data?.detail || e?.response?.data?.message || 'Return failed.'
      snack.color = 'error'
      snack.show = true
    }
  } finally {
    returnDialog.busy = false
  }
}

async function markReceived() {
  busy.value = true
  try {
    await $api.patch(`/purchase-orders/orders/${id.value}/`, { status: 'received' })
    snack.text = 'Marked received & stock updated'
    snack.color = 'success'
    snack.show = true
    await r.get(id.value)
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to update status.'
    snack.color = 'error'
    snack.show = true
  } finally {
    busy.value = false
  }
}

function printPO() {
  if (typeof window !== 'undefined') window.print()
}

onMounted(() => r.get(id.value))
</script>

<style scoped>
.po-detail-shell { max-width: 1400px; margin: 0 auto; }

.po-hero {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
  border: none;
}

.po-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

.po-detail-table :deep(thead th) {
  font-size: 11px !important;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: rgb(var(--v-theme-on-surface)) !important;
  background: rgba(99, 102, 241, 0.08);
  font-weight: 700 !important;
  opacity: 1 !important;
  border-bottom: 2px solid rgba(99, 102, 241, 0.25) !important;
}
.po-detail-table :deep(tfoot td) { border-top: 2px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

.po-meta { display: flex; flex-direction: column; gap: 8px; }
.po-meta > div {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 8px;
}
.po-meta > div span:last-child { text-align: right; font-weight: 500; }

@media print {
  .v-app-bar, .v-navigation-drawer, .po-card .v-btn, .po-hero .v-btn { display: none !important; }
  .po-detail-shell { max-width: 100%; }
}
</style>
