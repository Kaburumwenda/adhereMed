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
              <v-col cols="6" md="3">
                <v-text-field
                  v-model.number="form.shipping_cost"
                  label="Shipping cost"
                  type="number"
                  min="0"
                  step="0.01"
                  variant="outlined"
                  density="comfortable"
                  prepend-inner-icon="mdi-truck-delivery"
                  hide-details="auto"
                  prefix="KSh"
                  hint="Recorded in Expenses; excluded from order totals"
                  persistent-hint
                />
              </v-col>
            </v-row>
            <v-row dense>
              <v-col cols="12">
                <div
                  class="proof-dropzone"
                  :class="{ 'proof-dropzone-active': proofDragging }"
                  @dragover.prevent="proofDragging = true"
                  @dragleave.prevent="proofDragging = false"
                  @drop.prevent="onProofDrop"
                  @click="proofInputRef?.click()"
                >
                  <input ref="proofInputRef" type="file" accept="image/*" class="d-none" @change="onProofInputChange" />
                  <svg class="proof-ants" aria-hidden="true">
                    <rect x="1.25" y="1.25" width="calc(100% - 2.5px)" height="calc(100% - 2.5px)" rx="10" />
                  </svg>
                  <div v-if="proofPreview || proofUrl" class="d-flex align-center justify-center flex-wrap ga-3">
                    <v-avatar rounded="lg" size="72" class="proof-thumb">
                      <v-img :src="proofPreview || proofUrl" cover />
                    </v-avatar>
                    <div class="text-body-2 text-medium-emphasis">
                      {{ proofFile ? 'New proof image ready to upload' : 'Proof image attached' }} · optional
                    </div>
                    <v-btn
                      icon="mdi-close-circle-outline"
                      size="small"
                      variant="text"
                      color="error"
                      title="Remove proof image"
                      :loading="proofBusy"
                      @click.stop="removeProof"
                    />
                  </div>
                  <div v-else class="d-flex flex-column align-center py-1">
                    <v-icon size="30" color="primary" class="mb-1">{{ proofDragging ? 'mdi-file-image-plus-outline' : 'mdi-image-plus-outline' }}</v-icon>
                    <div class="text-body-2 text-medium-emphasis">
                      Drop a <b>PO proof image</b> here or <span class="text-primary font-weight-medium">browse</span> · optional
                    </div>
                    <div class="text-caption text-disabled">Signed delivery note, receipt photo, etc.</div>
                  </div>
                </div>
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
              Saving with status <b>Received</b> will create stock batches and update item quantities, cost, selling price, discount and VAT tax.
            </v-alert>
          </v-card>

          <!-- Items card -->
          <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 po-card">
            <div class="d-flex align-center mb-3">
              <v-icon color="primary" class="mr-2">mdi-package-variant</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Items</div>
              <v-chip v-if="form.items.length" size="x-small" color="primary" variant="tonal" class="ml-2">{{ form.items.length }}</v-chip>
              <v-spacer />
              <input ref="importFileRef" type="file" accept=".xlsx,.csv" class="d-none" @change="onImportFile" />
              <v-btn
                color="success"
                variant="tonal"
                rounded="lg"
                prepend-icon="mdi-microsoft-excel"
                size="small"
                class="mr-2"
                :loading="importParsing"
                @click="importFileRef?.click()"
              >Import Excel</v-btn>
              <v-btn
                variant="tonal"
                color="success"
                rounded="lg"
                prepend-icon="mdi-file-export"
                size="small"
                class="mr-2"
                :disabled="!form.items.length"
                :loading="exportingItems"
                @click="exportItems"
              >Export Items</v-btn>
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
                        :items="itemSearchResults"
                        item-title="medication_name"
                        :return-object="true"
                        label="Item *"
                        variant="outlined"
                        density="comfortable"
                        hide-details="auto"
                        :rules="itemRules"
                        :loading="itemSearching"
                        hint="Search inventory or catalog"
                        persistent-hint
                        @update:search="onItemSearch"
                        @update:model-value="onPickItem(it, $event)"
                      >
                        <template #item="{ props: ip, item }">
                          <v-list-item v-bind="ip" :title="item.raw.medication_name || item.raw.generic_name">
                            <template #subtitle>
                              <div class="d-flex flex-wrap ga-1 align-center">
                                <v-chip v-if="item.raw._source === 'inventory'" size="x-small" variant="tonal" color="primary">Inventory</v-chip>
                                <v-chip v-else-if="item.raw._source === 'catalog'" size="x-small" variant="tonal" color="purple">Catalog — not in inventory</v-chip>
                                <v-chip v-if="item.raw.cost_price" size="x-small" variant="tonal" color="primary">Cost {{ formatMoney(item.raw.cost_price) }}</v-chip>
                                <v-chip v-if="item.raw.selling_price" size="x-small" variant="tonal" color="success">Sell {{ formatMoney(item.raw.selling_price) }}</v-chip>
                                <v-chip v-if="item.raw._source === 'inventory'" size="x-small" variant="tonal" :color="(item.raw.total_quantity || 0) <= 0 ? 'error' : 'default'">Stock {{ item.raw.total_quantity || 0 }}</v-chip>
                              </div>
                            </template>
                          </v-list-item>
                        </template>
                        <template #no-data>
                          <v-list-item v-if="itemSearchQuery && !itemSearching">
                            <div class="text-body-2 text-medium-emphasis pa-2">
                              <div class="mb-2">No items found in inventory or catalog.</div>
                              <v-btn
                                size="small"
                                color="purple"
                                variant="tonal"
                                prepend-icon="mdi-pill"
                                to="/pharmacy/medications"
                                target="_blank"
                              >Add to Medication Catalog first</v-btn>
                            </div>
                          </v-list-item>
                        </template>
                      </v-combobox>
                      <div v-if="it.stock_id && it._source === 'inventory'" class="mt-1 d-flex flex-wrap ga-1">
                        <v-chip size="x-small" variant="flat" color="primary">Sell {{ formatMoney(it.unit_selling_price) }}</v-chip>
                        <v-chip size="x-small" variant="flat" color="info">In stock {{ it._current_stock ?? '—' }}</v-chip>
                        <v-chip size="x-small" variant="flat" color="success">+{{ it.qty || 0 }} after save</v-chip>
                      </div>
                      <div v-else-if="it._source === 'catalog'" class="mt-1 d-flex flex-wrap ga-1 align-center">
                        <v-chip size="x-small" variant="flat" color="purple" prepend-icon="mdi-plus-circle">From catalog — will create inventory item on save</v-chip>
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
                    <v-col cols="6" md="1">
                      <v-text-field
                        v-model.number="it.tax_percent"
                        label="VAT %"
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
                      <v-chip
                        v-if="Number(it.tax_percent) > 0"
                        size="small"
                        variant="tonal"
                        color="orange"
                        prepend-icon="mdi-percent"
                      >VAT {{ formatMoney(lineTax(it)) }}</v-chip>
                      <div class="po-line-total">
                        <div class="text-center">
                          <span class="text-caption text-medium-emphasis d-block">Line total</span>
                          <span class="text-h6 font-weight-bold text-primary">{{ formatMoney(lineTotal(it)) }}</span>
                          <span v-if="Number(it.tax_percent) > 0" class="text-caption text-medium-emphasis d-block">
                            excl. {{ formatMoney(lineTax(it)) }} VAT
                          </span>
                        </div>
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
              <v-col cols="6" md="2">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Items</div>
                  <div class="text-h6 font-weight-bold">{{ form.items.length }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="2">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Total quantity</div>
                  <div class="text-h6 font-weight-bold">{{ totalQty }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="2">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Subtotal (excl. VAT)</div>
                  <div class="text-h6 font-weight-bold">{{ formatMoney(grandSubtotal) }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="2">
                <div class="po-summary-stat" style="background: rgba(255, 152, 0, 0.08);">
                  <div class="text-caption text-medium-emphasis">VAT Tax</div>
                  <div class="text-h6 font-weight-bold text-orange">{{ formatMoney(grandTax) }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="2">
                <div class="po-summary-stat">
                  <div class="text-caption text-medium-emphasis">Avg. unit cost</div>
                  <div class="text-h6 font-weight-bold">{{ formatMoney(avgUnitCost) }}</div>
                </div>
              </v-col>
              <v-col cols="6" md="2">
                <div class="po-summary-stat is-total">
                  <div class="text-caption" style="opacity:0.85">Total cost (incl. VAT)</div>
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

            <v-alert
              v-if="Number(form.shipping_cost) > 0"
              type="info"
              variant="tonal"
              density="compact"
              class="mt-3"
              icon="mdi-truck-delivery"
            >
              Shipping <b>{{ formatMoney(form.shipping_cost) }}</b> is excluded from the order total — when the order is <b>received</b>, it is recorded in Expenses under the <b>Shipping Cost</b> category (auto-approved).
            </v-alert>

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

    <!-- Excel import review dialog -->
    <v-dialog v-model="importDialog" max-width="960" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center flex-wrap ga-2">
          <v-icon color="success">mdi-microsoft-excel</v-icon>
          Review imported items
          <v-spacer />
          <v-chip v-if="importRows.length" size="small" variant="tonal" color="primary" prepend-icon="mdi-table">{{ importRows.length }} rows</v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-alert v-if="importError" type="error" variant="tonal" density="compact" class="mb-4">
            <template #prepend><v-icon>mdi-alert-circle</v-icon></template>
            {{ importError }}
          </v-alert>

          <template v-if="importRows.length">
            <div class="d-flex align-center flex-wrap ga-2 mb-3">
              <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-check-circle-outline">
                {{ importSummary.matched }} matched in inventory
              </v-chip>
              <v-chip size="small" variant="tonal" color="warning" prepend-icon="mdi-plus-circle-outline">
                {{ importSummary.new }} new (created on save)
              </v-chip>
              <v-chip v-if="importSummary.error" size="small" variant="tonal" color="error" prepend-icon="mdi-alert-circle-outline">
                {{ importSummary.error }} skipped
              </v-chip>
              <span class="text-caption text-medium-emphasis">Rows with errors are skipped; the rest are added to the order.</span>
            </div>

            <div class="po-import-sheet-wrap">
              <table class="po-import-sheet">
                <thead>
                  <tr>
                    <th>Row</th>
                    <th>Status</th>
                    <th>Item</th>
                    <th>Qty</th>
                    <th>Unit cost</th>
                    <th>Selling</th>
                    <th>Disc %</th>
                    <th>VAT %</th>
                    <th>Batch #</th>
                    <th>Expiry</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="r in importRows" :key="r.row_num" :class="`po-import-row-${r.status}`">
                    <td class="text-caption text-medium-emphasis">{{ r.row_num }}</td>
                    <td>
                      <v-chip :color="importStatusColor(r.status)" variant="tonal" size="x-small">
                        <v-icon start size="12">{{ importStatusIcon(r.status) }}</v-icon>
                        {{ r.status }}
                      </v-chip>
                    </td>
                    <td>
                      <div class="font-weight-medium">{{ r.name }}</div>
                      <div v-if="r.errors && r.errors.name" class="text-caption text-error">{{ r.errors.name }}</div>
                    </td>
                    <td>
                      <div>{{ r.qty }}</div>
                      <div v-if="r.errors && r.errors.qty" class="text-caption text-error">{{ r.errors.qty }}</div>
                    </td>
                    <td>{{ formatMoney(r.unit_cost) }}</td>
                    <td>{{ formatMoney(r.unit_selling_price) }}</td>
                    <td>{{ r.discount_percent }}</td>
                    <td>{{ r.tax_percent }}</td>
                    <td>{{ r.batch_number || '—' }}</td>
                    <td>{{ r.expiry_date || '—' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-file-download-outline" :loading="importDownloading" @click="downloadPoTemplate">Download template</v-btn>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="closeImportDialog">Cancel</v-btn>
          <v-btn
            color="primary"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-plus-circle"
            :disabled="!importApplyCount"
            @click="applyImport"
          >Add {{ importApplyCount }} item{{ importApplyCount === 1 ? '' : 's' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'

const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/purchase-orders/orders/')

const branchStore = useBranchStore()
const auth = useAuthStore()

const formRef = ref(null)
const saving = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

// ── Proof image (optional) ───────────────────────────────────────────
const proofInputRef = ref(null)
const proofFile = ref(null)
const proofPreview = ref(null)
const proofUrl = ref('')
const proofBusy = ref(false)
const proofDragging = ref(false)

function onProofSelected(file) {
  const f = Array.isArray(file) ? file[0] : file
  if (!f) { proofPreview.value = null; return }
  const reader = new FileReader()
  reader.onload = e => { proofPreview.value = e.target.result }
  reader.readAsDataURL(f)
}

function onProofInputChange(e) {
  const file = e.target?.files?.[0]
  if (file) {
    proofFile.value = file
    onProofSelected(file)
  }
  e.target.value = ''
}

function onProofDrop(e) {
  proofDragging.value = false
  const file = e.dataTransfer?.files?.[0]
  if (file && file.type.startsWith('image/')) {
    proofFile.value = file
    onProofSelected(file)
  }
}

async function removeProof() {
  // Clearing a newly selected (not yet uploaded) file — keep any existing proof
  if (!loadId.value || !proofUrl.value || proofFile.value) {
    proofFile.value = null
    proofPreview.value = null
    return
  }
  proofBusy.value = true
  try {
    await $api.post(`/purchase-orders/orders/${loadId.value}/clear-proof/`)
    proofUrl.value = ''
    proofFile.value = null
    proofPreview.value = null
    snack.text = 'Proof image removed.'
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = 'Could not remove proof image.'
    snack.color = 'error'
    snack.show = true
  } finally {
    proofBusy.value = false
  }
}

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

// --- Branch logic ---
const branchLocked = computed(() => {
  const role = auth.role
  // tenant_admin/super_admin can pick any branch; branch_admin is locked
  return role === 'branch_admin'
})
const branchOptions = computed(() => {
  if (branchLocked.value) {
    const b = branchStore.currentBranch
    return b ? [{ label: b.name, value: b.id }] : []
  }
  return branchStore.activeBranches.map(b => ({ label: b.name, value: b.id }))
})

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
  branch: null,
  expected_delivery: '',
  status: 'draft',
  shipping_cost: 0,
  notes: '',
  items: [],
})

const suppliers = ref([])
const stocks = ref([])

// --- Branch-aware item search ---
const itemSearchResults = ref([])
const itemSearching = ref(false)
const itemSearchQuery = ref('')
let _itemSearchTimer = null

async function onItemSearch(query) {
  itemSearchQuery.value = query || ''
  clearTimeout(_itemSearchTimer)
  if (!query || query.length < 2) {
    // Show all branch inventory as default
    itemSearchResults.value = stocks.value.map(s => ({ ...s, _source: 'inventory' }))
    return
  }
  _itemSearchTimer = setTimeout(async () => {
    itemSearching.value = true
    try {
      const branchId = form.branch
      const params = { search: query, page_size: 50 }
      if (branchId) params.branch = branchId

      // 1. Search inventory for this branch
      const invRes = await $api.get('/inventory/stocks/', { params }).catch(() => ({ data: [] }))
      const invItems = (invRes.data?.results || invRes.data || []).map(s => ({ ...s, _source: 'inventory' }))

      // 2. If few results, also search medication catalog
      let catalogItems = []
      if (invItems.length < 5) {
        const catRes = await $api.get('/medications/search/', { params: { q: query } }).catch(() => ({ data: [] }))
        const catRaw = catRes.data?.results || catRes.data || []
        // Exclude catalog items already in inventory results
        const invNames = new Set(invItems.map(i => (i.medication_name || '').toLowerCase()))
        catalogItems = catRaw
          .filter(c => !invNames.has((c.generic_name || '').toLowerCase()))
          .map(c => ({
            medication_name: c.generic_name,
            generic_name: c.generic_name,
            cost_price: 0,
            selling_price: 0,
            _source: 'catalog',
            _catalog_id: c.id,
          }))
      }

      itemSearchResults.value = [...invItems, ...catalogItems]
    } catch {
      itemSearchResults.value = []
    } finally {
      itemSearching.value = false
    }
  }, 300)
}

// Reload inventory stocks when branch changes
watch(() => form.branch, async (branchId) => {
  if (!branchId) return
  try {
    const params = { page_size: 1000 }
    if (branchId) params.branch = branchId
    const res = await $api.get('/inventory/stocks/', { params })
    stocks.value = res.data?.results || res.data || []
    itemSearchResults.value = stocks.value.map(s => ({ ...s, _source: 'inventory' }))
  } catch { /* silent */ }
})

function newItem() {
  return {
    pick: null,
    stock_id: null,
    name: '',
    qty: 1,
    unit_cost: 0,
    unit_selling_price: 0,
    discount_percent: 0,
    tax_percent: 0,
    batch_number: '',
    expiry_date: '',
    _current_stock: null,
    _source: null,
    _catalog_id: null,
  }
}

function addItem() { form.items.push(newItem()) }

// --- Excel import for items ---
const importFileRef = ref(null)
const importDialog = ref(false)
const importParsing = ref(false)
const importDownloading = ref(false)
const importError = ref('')
const importRows = ref([])

const importSummary = computed(() => ({
  matched: importRows.value.filter(r => r.status === 'matched').length,
  new: importRows.value.filter(r => r.status === 'new').length,
  error: importRows.value.filter(r => r.status === 'error').length,
}))
const importApplyCount = computed(() => importRows.value.filter(r => r.status !== 'error').length)

function importStatusColor(s) { return { matched: 'success', new: 'warning', error: 'error' }[s] || 'grey' }
function importStatusIcon(s) { return { matched: 'mdi-check', new: 'mdi-plus', error: 'mdi-alert' }[s] || 'mdi-help' }

function closeImportDialog() {
  importDialog.value = false
  importRows.value = []
  importError.value = ''
}

async function onImportFile(e) {
  const file = e.target?.files?.[0]
  e.target.value = ''
  if (!file) return
  if (!/\.(xlsx|csv)$/i.test(file.name)) {
    importError.value = 'Unsupported file type. Use .xlsx or .csv'
    importRows.value = []
    importDialog.value = true
    return
  }
  importParsing.value = true
  importError.value = ''
  try {
    const fd = new FormData()
    fd.append('file', file)
    const params = {}
    if (form.branch) params.branch = form.branch
    const { data } = await $api.post('/purchase-orders/orders/import-items-preview/', fd, { params })
    importRows.value = data.rows || []
    if (!importRows.value.length) importError.value = 'No data rows found in the file.'
    importDialog.value = true
  } catch (err) {
    importError.value = err?.response?.data?.detail || 'Could not read the file. Check the format and try again.'
    importRows.value = []
    importDialog.value = true
  } finally {
    importParsing.value = false
  }
}

function applyImport() {
  // Drop untouched blank rows (e.g. the initial empty item) before appending
  const keep = form.items.filter(it => it.stock_id || (it.name && it.name.trim()))
  form.items.splice(0, form.items.length, ...keep)

  for (const row of importRows.value) {
    if (row.status === 'error') continue
    const it = newItem()
    it.name = row.name
    it.qty = Number(row.qty) > 0 ? Number(row.qty) : 1
    it.unit_cost = Number(row.unit_cost || 0)
    it.unit_selling_price = Number(row.unit_selling_price || 0)
    it.discount_percent = Number(row.discount_percent || 0)
    it.tax_percent = Number(row.tax_percent || 0)
    it.batch_number = row.batch_number || ''
    it.expiry_date = row.expiry_date || ''
    if (row.stock_id) {
      it.stock_id = row.stock_id
      it._source = 'inventory'
      it._current_stock = row.current_stock
      const stockObj = stocks.value.find(s => s.id === row.stock_id)
      it.pick = stockObj || { id: row.stock_id, medication_name: row.name }
    } else {
      it.pick = row.name
    }
    form.items.push(it)
  }

  snack.text = `${importApplyCount.value} item(s) added from spreadsheet`
  snack.color = 'success'
  snack.show = true
  closeImportDialog()
}

async function downloadPoTemplate() {
  importDownloading.value = true
  try {
    const blob = (await $api.get('/purchase-orders/orders/import-items-template/', { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `po_items_import_template_${new Date().toISOString().slice(0, 10)}.xlsx`
    a.click()
    URL.revokeObjectURL(objectUrl)
  } catch {
    snack.text = 'Template download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    importDownloading.value = false
  }
}

const exportingItems = ref(false)

async function exportItems() {
  const items = form.items
    .filter(it => it.stock_id || (it.name && it.name.trim()))
    .map(it => ({
      name: it.name,
      qty: Number(it.qty || 0),
      unit_cost: Number(it.unit_cost || 0),
      unit_selling_price: Number(it.unit_selling_price || 0),
      discount_percent: Number(it.discount_percent || 0),
      tax_percent: Number(it.tax_percent || 0),
      batch_number: it.batch_number || '',
      expiry_date: it.expiry_date || '',
    }))
  if (!items.length) {
    snack.text = 'No items to export.'
    snack.color = 'warning'
    snack.show = true
    return
  }
  exportingItems.value = true
  try {
    const blob = (await $api.post('/purchase-orders/orders/export-items/', { items }, { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `po_items_${form.po_number ? form.po_number.toLowerCase().replace(/\s+/g, '_') : new Date().toISOString().slice(0, 10)}.xlsx`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Item export download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Export failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exportingItems.value = false
  }
}

function onPickItem(it, value) {
  if (value && typeof value === 'object') {
    if (value._source === 'catalog') {
      // From catalog — will create inventory item on save
      it.stock_id = null
      it.name = value.generic_name || value.medication_name || ''
      it.unit_cost = 0
      it.unit_selling_price = 0
      it.discount_percent = 0
      it.tax_percent = 0
      it._current_stock = null
      it._source = 'catalog'
      it._catalog_id = value._catalog_id || null
    } else {
      it.stock_id = value.id || null
      it.name = value.medication_name || ''
      it.unit_cost = Number(value.cost_price || 0)
      it.unit_selling_price = Number(value.selling_price || 0)
      it.discount_percent = Number(value.discount_percent || 0)
      it.tax_percent = Number(value.tax_percent || 0)
      it._current_stock = value.total_quantity ?? 0
      it._source = 'inventory'
      it._catalog_id = null
    }
  } else if (typeof value === 'string') {
    it.stock_id = null
    it.name = value.trim()
    it._current_stock = null
    it._source = null
    it._catalog_id = null
  } else {
    it.stock_id = null
    it.name = ''
    it._current_stock = null
    it._source = null
    it._catalog_id = null
  }
}

function lineTotal(it) {
  return Number(it.qty || 0) * Number(it.unit_cost || 0)
}
function lineTax(it) {
  const total = lineTotal(it)
  const pct = Number(it.tax_percent || 0)
  return pct > 0 ? total * pct / 100 : 0
}
function lineTotalWithTax(it) {
  return lineTotal(it) + lineTax(it)
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
const grandTotal = computed(() => form.items.reduce((s, it) => s + lineTotalWithTax(it), 0))
const grandSubtotal = computed(() => form.items.reduce((s, it) => s + lineTotal(it), 0))
const grandTax = computed(() => form.items.reduce((s, it) => s + lineTax(it), 0))
const grandRevenue = computed(() => form.items.reduce((s, it) => s + lineRevenue(it), 0))
const grandProfit = computed(() => grandRevenue.value - grandTotal.value)
const grandMarginPct = computed(() => grandRevenue.value ? (grandProfit.value / grandRevenue.value) * 100 : 0)
const totalQty = computed(() => form.items.reduce((s, it) => s + Number(it.qty || 0), 0))
const avgUnitCost = computed(() => totalQty.value ? grandSubtotal.value / totalQty.value : 0)
const canSave = computed(() => {
  const hasSupplier = (supplierPick.value && (supplierPick.value.id || (typeof supplierPick.value === 'string' && supplierPick.value.trim())))
  return !!hasSupplier && form.items.length > 0 && form.items.every(it => (it.stock_id || (it.name && it.name.trim())) && Number(it.qty) > 0)
})

function hydrateFromServer(data) {
  form.po_number = data.po_number || ''
  form.supplier = data.supplier ?? null
  form.branch = data.branch ?? form.branch
  supplierPick.value = suppliers.value.find(s => s.id === form.supplier) || null
  form.expected_delivery = data.expected_delivery || ''
  form.status = data.status || 'draft'
  form.shipping_cost = Number(data.shipping_cost || 0)
  form.notes = data.notes || ''
  proofUrl.value = data.proof_image_url || ''
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
      tax_percent: Number(raw.tax_percent || 0),
      batch_number: raw.batch_number || '',
      expiry_date: raw.expiry_date || '',
      _current_stock: stockObj?.total_quantity ?? null,
      _synced: !!raw._synced,
    }
  })
}

onMounted(async () => {
  await branchStore.load()
  // Set default branch
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
  ;[suppliers.value, stocks.value] = await Promise.all([
    safe('/suppliers/'),
    safe('/inventory/stocks/', stockParams),
  ])
  itemSearchResults.value = stocks.value.map(s => ({ ...s, _source: 'inventory' }))
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
        tax_percent: Number(it.tax_percent || 0),
        branch: form.branch || undefined,
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
    branch: form.branch || undefined,
    expected_delivery: form.expected_delivery || null,
    status: form.status,
    shipping_cost: Number(form.shipping_cost || 0),
    notes: form.notes,
    items: form.items.map(it => ({
      medication_stock_id: it.stock_id,
      name: it.name,
      qty: Number(it.qty || 0),
      unit_cost: Number(it.unit_cost || 0),
      unit_selling_price: Number(it.unit_selling_price || 0),
      discount_percent: Number(it.discount_percent || 0),
      tax_percent: Number(it.tax_percent || 0),
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
    // Optional proof image — uploaded after the PO is saved
    const f = Array.isArray(proofFile.value) ? proofFile.value[0] : proofFile.value
    if (f && result?.id) {
      try {
        const fd = new FormData()
        fd.append('image', f)
        await $api.post(`/purchase-orders/orders/${result.id}/upload-proof/`, fd)
      } catch {
        snack.text = 'Order saved, but the proof image failed to upload.'
        snack.color = 'warning'
        snack.show = true
        router.push('/purchase-orders')
        return result
      }
    }
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

/* Excel import review table */
.po-import-sheet-wrap {
  overflow: auto;
  max-height: 55vh;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 12px;
}
.po-import-sheet {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.po-import-sheet thead th {
  position: sticky;
  top: 0;
  background: rgb(var(--v-theme-surface));
  border-bottom: 2px solid rgba(var(--v-theme-on-surface), 0.08);
  padding: 10px;
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  text-align: left;
  white-space: nowrap;
  z-index: 1;
}
.po-import-sheet tbody td {
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  padding: 8px 10px;
  white-space: nowrap;
  vertical-align: top;
}
.po-import-row-matched td { background: rgba(var(--v-theme-success), 0.05); }
.po-import-row-new td { background: rgba(var(--v-theme-warning), 0.05); }
.po-import-row-error td { background: rgba(var(--v-theme-error), 0.07); }

/* Proof image dropzone — dotted animated border */
.proof-dropzone {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 14px 16px;
  border: 2px dashed rgba(var(--v-theme-primary), 0.18);
  border-radius: 12px;
  background: rgba(var(--v-theme-primary), 0.02);
  cursor: pointer;
  transition: background 0.15s ease;
}
.proof-dropzone-active {
  background: rgba(var(--v-theme-primary), 0.06);
}

/* Marching-ants dotted border (animated dots) */
.proof-ants {
  position: absolute;
  inset: -2px;
  width: calc(100% + 4px);
  height: calc(100% + 4px);
  pointer-events: none;
}
.proof-ants rect {
  fill: none;
  stroke: rgb(var(--v-theme-primary));
  stroke-width: 2.5;
  stroke-linecap: round;
  stroke-dasharray: 0.5 14;
  opacity: 0.55;
  animation: proof-march 1.2s linear infinite;
}
.proof-dropzone:hover .proof-ants rect,
.proof-dropzone-active .proof-ants rect {
  opacity: 1;
  animation-duration: 0.45s;
}
@keyframes proof-march {
  to { stroke-dashoffset: -29; }
}
@media (prefers-reduced-motion: reduce) {
  .proof-ants rect { animation: none; }
}
.proof-thumb {
  border: 2px solid rgba(var(--v-theme-primary), 0.25);
}
</style>
