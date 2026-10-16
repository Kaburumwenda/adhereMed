<template>
  <v-container fluid class="pa-4 pa-md-6 po-list-shell">
    <PageHeader title="Purchase Orders" icon="mdi-cart" :subtitle="pageSubtitle">
      <template #actions>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" @click="refresh" :loading="loading">Refresh</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" class="text-none" prepend-icon="mdi-file-chart-outline" :loading="exporting === 'report'" @click="downloadReport">Report (PDF)</v-btn>
        <v-btn variant="tonal" color="success" rounded="lg" class="text-none" prepend-icon="mdi-microsoft-excel" :loading="exporting === 'excel'" @click="exportOrders('excel')">Export Excel</v-btn>
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-file-delimited" :loading="exporting === 'csv'" @click="exportOrders('csv')">Export CSV</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/purchase-orders/new">New PO</v-btn>
      </template>
    </PageHeader>

    <!-- Stat cards -->
    <v-row dense class="mb-2">
      <v-col v-for="s in statCards" :key="s.key" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 po-stat" :class="`po-stat-${s.key}`">
          <div class="d-flex align-center mb-2">
            <v-icon :color="s.color" class="mr-2">{{ s.icon }}</v-icon>
            <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">{{ s.label }}</div>
          </div>
          <div class="text-h5 font-weight-bold">{{ s.value }}</div>
          <div v-if="s.sub" class="text-caption text-medium-emphasis mt-1">{{ s.sub }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters / search -->
    <v-card rounded="lg" class="pa-3 mb-3 po-filter-bar">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search"
          placeholder="Search PO #, supplierâ€¦"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          prepend-inner-icon="mdi-magnify"
          bg-color="surface"
          clearable
          class="flex-grow-1"
          style="min-width: 220px"
        />
        <v-select
          v-model="statusFilter"
          :items="statusFilterOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-progress-check"
        >
          <template #item="{ props, item }">
            <v-list-item v-bind="props" :subtitle="item.raw.description || undefined">
              <template v-if="item.raw.value !== 'all'" #prepend>
                <span class="mr-1"><StatusChip :status="item.raw.value" /></span>
              </template>
            </v-list-item>
          </template>
        </v-select>
        <v-select
          v-model="supplierFilter"
          :items="supplierFilterOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-truck-delivery"
          style="max-width: 240px; min-width: 180px"
          clearable
        />
        <v-select
          v-if="branchStore.hasBranches"
          v-model="branchFilter"
          :items="branchFilterItems"
          item-title="name"
          item-value="id"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          :disabled="isBranchLocked"
          prepend-inner-icon="mdi-store-marker"
          style="max-width: 220px; min-width: 180px"
        />
        <v-select
          v-model="datePreset"
          :items="dateOptions"
          item-title="label"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-calendar-range"
          style="max-width: 200px; min-width: 170px"
        />
        <template v-if="datePreset === 'custom'">
          <v-text-field
            v-model="dateFrom"
            label="From"
            type="date"
            variant="solo-filled"
            density="comfortable"
            hide-details
            flat
            rounded="lg"
            bg-color="surface"
            style="max-width: 170px"
          />
          <v-text-field
            v-model="dateTo"
            label="To"
            type="date"
            variant="solo-filled"
            density="comfortable"
            hide-details
            flat
            rounded="lg"
            bg-color="surface"
            style="max-width: 170px"
          />
        </template>
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
      icon="mdi-cart-outline"
      title="No purchase orders"
      :message="search || statusFilter !== 'all' || supplierFilter ? 'Try a different filter or search term.' : 'Create your first purchase order to get started.'"
    >
      <template #actions>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/purchase-orders/new" class="text-none">New PO</v-btn>
      </template>
    </EmptyState>

    <!-- Table view -->
    <v-card v-else-if="viewMode === 'table'" rounded="lg" class="po-table-card">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :items-per-page="20"
        :items-per-page-options="[10, 20, 50, 100]"
        density="comfortable"
        hover
        class="po-data-table"
        @click:row="(_, { item }) => goDetail(item)"
      >
        <template #item.rowIndex="{ item }">
          <span class="text-caption text-medium-emphasis">{{ filtered.findIndex(p => p.id === item.id) + 1 }}</span>
        </template>
        <template #item.po_number="{ item }">
          <span class="font-weight-bold text-primary">{{ item.po_number }}</span>
        </template>
        <template #item.supplier_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(item.supplier_name) }}</span>
            </v-avatar>
            <span>{{ item.supplier_name || 'â€”' }}</span>
          </div>
        </template>
        <template #item.items="{ item }">
          <v-chip size="small" variant="tonal" color="primary">{{ (item.items || []).length }}</v-chip>
        </template>
        <template #item.total_cost="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.total_cost) }}</span>
        </template>
        <template #item.shipping_cost="{ item }">
          <span v-if="Number(item.shipping_cost) > 0" class="text-medium-emphasis">{{ formatMoney(item.shipping_cost) }}</span>
          <span v-else class="text-disabled">â€”</span>
        </template>
        <template #item.status="{ item }">
          <div class="status-cell" @click.stop>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" variant="text" size="small" class="text-none px-2 status-btn"
                       :loading="updatingStatusId === item.id" :disabled="updatingStatusId === item.id">
                  <StatusChip :status="item.status" />
                  <v-icon size="14" class="ml-1" color="medium-emphasis">mdi-chevron-down</v-icon>
                </v-btn>
              </template>
              <v-list density="compact" min-width="260">
                <v-list-subheader class="text-caption">Change status</v-list-subheader>
                <v-list-item v-for="opt in statusOptions" :key="opt.value"
                             :disabled="opt.value === item.status"
                             density="compact" two-line
                             :append-icon="opt.value === item.status ? 'mdi-check' : undefined"
                             @click="changeStatus(item, opt.value)">
                  <v-list-item-title>
                    <StatusChip :status="opt.value" />
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption text-medium-emphasis">
                    {{ opt.description }}
                  </v-list-item-subtitle>
                </v-list-item>
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #item.order_date="{ item }">{{ formatDate(item.order_date) }}</template>
        <template #item.expected_delivery="{ item }">
          <span v-if="item.expected_delivery">{{ formatDate(item.expected_delivery) }}</span>
          <span v-else class="text-medium-emphasis">â€”</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn icon="mdi-receipt-text-outline" size="x-small" variant="text" color="teal" title="Download Purchase Order (PDF)" :loading="invoicingId === item.id" @click.stop="downloadInvoice(item)" />
            <v-btn icon="mdi-eye-outline" size="x-small" variant="text" :to="`/purchase-orders/${item.id}`" @click.stop />
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/purchase-orders/${item.id}/edit`" @click.stop />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Card view -->
    <v-row v-else dense>
      <v-col v-for="po in filtered" :key="po.id" cols="12" sm="6" lg="4">
        <v-card rounded="lg" class="po-card-tile pa-4" @click="goDetail(po)">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <div class="text-caption text-medium-emphasis">PO Number</div>
              <div class="text-h6 font-weight-bold text-primary">{{ po.po_number }}</div>
            </div>
            <div @click.stop>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" variant="text" size="small" class="text-none px-2"
                         :loading="updatingStatusId === po.id" :disabled="updatingStatusId === po.id">
                    <StatusChip :status="po.status" />
                    <v-icon size="14" class="ml-1" color="medium-emphasis">mdi-chevron-down</v-icon>
                  </v-btn>
                </template>
                <v-list density="compact" min-width="260">
                  <v-list-subheader class="text-caption">Change status</v-list-subheader>
                  <v-list-item v-for="opt in statusOptions" :key="opt.value"
                               :disabled="opt.value === po.status"
                               density="compact" two-line
                               :append-icon="opt.value === po.status ? 'mdi-check' : undefined"
                               @click="changeStatus(po, opt.value)">
                    <v-list-item-title>
                      <StatusChip :status="opt.value" />
                    </v-list-item-title>
                    <v-list-item-subtitle class="text-caption text-medium-emphasis">
                      {{ opt.description }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </v-list>
              </v-menu>
            </div>
          </div>
          <div class="d-flex align-center mb-2 ga-2">
            <v-avatar size="32" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(po.supplier_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-body-2 font-weight-medium text-truncate">{{ po.supplier_name || 'â€”' }}</div>
              <div class="text-caption text-medium-emphasis">{{ formatDate(po.order_date) }}</div>
            </div>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between align-center">
            <div>
              <div class="text-caption text-medium-emphasis">Items</div>
              <div class="font-weight-bold">{{ (po.items || []).length }}</div>
            </div>
            <div class="text-end">
              <div class="text-caption text-medium-emphasis">Total</div>
              <div class="text-h6 font-weight-bold text-primary">{{ formatMoney(po.total_cost) }}</div>
            </div>
          </div>
          <div v-if="po.expected_delivery" class="text-caption text-medium-emphasis mt-2">
            <v-icon size="14" class="mr-1">mdi-calendar-clock</v-icon>
            Expected {{ formatDate(po.expected_delivery) }}
          </div>
          <div class="d-flex justify-end ga-1 mt-2">
            <v-btn icon="mdi-pencil-outline" size="x-small" variant="text" color="primary" :to="`/purchase-orders/${po.id}/edit`" @click.stop />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click.stop="confirmDelete(po)" />
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="400" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Purchase Order
        </v-card-title>
        <v-card-text>
          Delete <b>{{ deleteDialog.po?.po_number }}</b>? This cannot be undone.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="deleteDialog.busy" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Receive confirmation dialog -->
    <v-dialog v-model="receiveDialog.show" max-width="480" persistent>
      <v-card rounded="lg" class="pa-2">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon color="success">mdi-package-variant-closed-check</v-icon>
          Confirm Receipt
        </v-card-title>
        <v-card-subtitle class="pb-2 text-wrap" style="white-space: normal; line-height: 1.5">
          <span v-if="receiveDialog.po">Mark <strong>{{ receiveDialog.po.po_number }}</strong> as received?</span>
          <span v-if="receiveDialog.po" class="d-block mt-1">This will sync all line items into inventory, update stock levels and cost prices. This action cannot be reversed without a formal return.</span>
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="info" variant="tonal" density="compact" class="mb-3">
            Enter your password to confirm that the goods have been received and stocked in.
          </v-alert>
          <div class="text-caption text-medium-emphasis mb-1 d-flex align-center ga-1">
            <v-icon size="14" color="success">mdi-lock-outline</v-icon>
            Enter your password to approve and confirm this receipt entry.
          </div>
          <v-text-field
            v-model="receiveDialog.password"
            label="Your password"
            type="password"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-lock-outline"
            :error-messages="receiveDialog.error"
            hide-details="auto"
            @keyup.enter="confirmReceive"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="closeReceiveDialog">Cancel</v-btn>
          <v-btn color="success" variant="flat" class="text-none"
                 :loading="receiveDialog.busy"
                 prepend-icon="mdi-check"
                 @click="confirmReceive">Confirm Receipt</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Return confirmation dialog -->
    <v-dialog v-model="returnDialog.show" max-width="480" persistent>
      <v-card rounded="lg" class="pa-2">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon color="warning">mdi-keyboard-return</v-icon>
          Confirm Return to Supplier
        </v-card-title>
        <v-card-subtitle class="pb-2 text-wrap" style="white-space: normal; line-height: 1.5">
          <span v-if="returnDialog.po">Return <strong>{{ returnDialog.po.po_number }}</strong>?</span>
          <span v-if="returnDialog.po" class="d-block mt-1">This will reverse all stock movements, restore previous cost and selling prices, and mark the order as returned. Some items may have already been consumed.</span>
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="warning" variant="tonal" density="compact" class="mb-3">
            Enter your password to confirm the return. This action reverses stock levels and price changes.
          </v-alert>
          <v-checkbox
            v-if="returnDialog.needsForce"
            v-model="returnDialog.force"
            label="Force return even if some items have been consumed"
            density="compact"
            hide-details
            color="warning"
            class="mb-3"
          />
          <div class="text-caption text-medium-emphasis mb-1 d-flex align-center ga-1">
            <v-icon size="14" color="warning">mdi-lock-outline</v-icon>
            Enter your password to approve and confirm this return to supplier.
          </div>
          <v-text-field
            v-model="returnDialog.password"
            label="Your password"
            type="password"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-lock-outline"
            :error-messages="returnDialog.error"
            hide-details="auto"
            @keyup.enter="confirmReturn"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="closeReturnDialog">Cancel</v-btn>
          <v-btn color="warning" variant="flat" class="text-none"
                 :loading="returnDialog.busy"
                 prepend-icon="mdi-keyboard-return"
                 @click="confirmReturn">Confirm Return</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Cancel confirmation dialog -->
    <v-dialog v-model="cancelDialog.show" max-width="480" persistent>
      <v-card rounded="lg" class="pa-2">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon color="error">mdi-close-circle-outline</v-icon>
          Cancel Purchase Order
        </v-card-title>
        <v-card-subtitle class="pb-2 text-wrap" style="white-space: normal; line-height: 1.5">
          <span v-if="cancelDialog.po">Cancel <strong>{{ cancelDialog.po.po_number }}</strong>?</span>
          <span v-if="cancelDialog.po" class="d-block mt-1">This will cancel the order and no further goods will be expected from the supplier. This action cannot be undone.</span>
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="error" variant="tonal" density="compact" class="mb-3">
            Enter your password to confirm cancellation of this purchase order.
          </v-alert>
          <div class="text-caption text-medium-emphasis mb-1 d-flex align-center ga-1">
            <v-icon size="14" color="error">mdi-lock-outline</v-icon>
            Enter your password to approve and confirm this cancellation.
          </div>
          <v-text-field
            v-model="cancelDialog.password"
            label="Your password"
            type="password"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-lock-outline"
            :error-messages="cancelDialog.error"
            hide-details="auto"
            @keyup.enter="confirmCancel"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="closeCancelDialog">Cancel</v-btn>
          <v-btn color="error" variant="flat" class="text-none"
                 :loading="cancelDialog.busy"
                 prepend-icon="mdi-close"
                 @click="confirmCancel">Cancel Order</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Partial receive dialog -->
    <v-dialog v-model="partialDialog.show" max-width="800" persistent scrollable>
      <v-card rounded="lg" class="pa-2">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon color="warning">mdi-package-variant</v-icon>
          Partial Receipt — {{ partialDialog.po?.po_number }}
        </v-card-title>
        <v-card-subtitle class="pb-2 text-wrap" style="white-space: normal; line-height: 1.5">
          Enter the quantity received for each line item. Stock will be updated for received quantities only. Items fully received will be marked as complete.
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="info" variant="tonal" density="compact" class="mb-3">
            This creates a Goods Received Note and syncs stock batches into inventory. Enter your password at the bottom to confirm.
          </v-alert>

          <v-table density="compact" class="partial-recv-table">
            <thead>
              <tr>
                <th style="width: 40px">#</th>
                <th>Item</th>
                <th class="text-right" style="width: 90px">Ordered</th>
                <th class="text-right" style="width: 90px">Prev Recv</th>
                <th class="text-right" style="width: 100px">Recv Now</th>
                <th class="text-right" style="width: 90px">Total Recv</th>
                <th class="text-right" style="width: 90px">Variance</th>
                <th class="text-center" style="width: 70px">Done</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, idx) in partialDialog.lines" :key="it.medication_stock_id">
                <td class="text-center text-caption text-medium-emphasis">{{ idx + 1 }}</td>
                <td class="text-truncate" style="max-width: 180px">{{ it.name }}</td>
                <td class="text-right text-medium-emphasis">{{ it.ordered_qty }}</td>
                <td class="text-right text-medium-emphasis">{{ it.prev_received }}</td>
                <td class="py-1">
                  <v-text-field
                    v-model.number="it.recv_qty"
                    type="number"
                    variant="outlined"
                    density="compact"
                    hide-details
                    :min="0"
                    :max="it.ordered_qty - it.prev_received"
                    style="width: 100px"
                    class="partial-qty-input"
                  />
                </td>
                <td class="text-right font-weight-medium">{{ it.prev_received + (it.recv_qty || 0) }}</td>
                <td class="text-right" :class="varianceClass(it)">
                  {{ varianceText(it) }}
                </td>
                <td class="text-center">
                  <v-icon v-if="it.prev_received + (it.recv_qty || 0) >= it.ordered_qty" color="success" size="18">mdi-check-circle</v-icon>
                  <v-icon v-else color="grey-lighten-1" size="18">mdi-circle-outline</v-icon>
                </td>
              </tr>
            </tbody>
          </v-table>

          <v-textarea
            v-model="partialDialog.notes"
            label="Notes (optional)"
            variant="outlined"
            density="compact"
            rows="2"
            auto-grow
            class="mt-3"
            hide-details
          />

          <div class="text-caption text-medium-emphasis mt-3 mb-1 d-flex align-center ga-1">
            <v-icon size="14" color="warning">mdi-lock-outline</v-icon>
            Enter your password to approve and confirm this partial receipt entry.
          </div>
          <v-text-field
            v-model="partialDialog.password"
            label="Your password"
            type="password"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-lock-outline"
            :error-messages="partialDialog.error"
            hide-details="auto"
            @keyup.enter="confirmPartial"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="closePartialDialog">Cancel</v-btn>
          <v-btn color="warning" variant="flat" class="text-none"
                 :loading="partialDialog.busy"
                 prepend-icon="mdi-package-variant"
                 @click="confirmPartial">Confirm Receipt</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const router = useRouter()
const branchStore = useBranchStore()
const auth = useAuthStore()
const r = useResource('/purchase-orders/orders/')

const isBranchLocked = computed(() => auth.role === 'branch_admin')
const branchFilter = ref(null)
const branchFilterItems = computed(() => {
  if (isBranchLocked.value) {
    const b = branchStore.currentBranch
    return b ? [{ id: b.id, name: b.name }] : []
  }
  const items = branchStore.activeBranches.map(b => ({ id: b.id, name: b.name }))
  items.unshift({ id: null, name: 'All Branches' })
  return items
})

const items = computed(() => r.items.value)
const loading = computed(() => r.loading.value)

const pageSubtitle = computed(() => {
  const base = 'Track procurement, deliveries and supplier spend'
  const bn = branchFilterItems.value.find(b => b.id === branchFilter.value)?.name
  return bn && bn !== 'All Branches' ? `${base} · ${bn}` : base
})

const search = ref('')
const statusFilter = ref('all')
const supplierFilter = ref(null)
const datePreset = ref('all')
const dateFrom = ref(null)
const dateTo = ref(null)
const viewMode = ref('table')
const snack = reactive({ show: false, color: 'success', text: '' })
const deleteDialog = reactive({ show: false, po: null, busy: false })

const statusFilterOptions = [
  { label: 'All statuses', value: 'all', description: '' },
  { label: 'Draft', value: 'draft', description: 'Being prepared — not sent yet' },
  { label: 'Sent', value: 'sent', description: 'Order placed with the supplier' },
  { label: 'Received', value: 'received', description: 'Fully delivered & stocked in' },
  { label: 'Partially Received', value: 'partial', description: 'Some items delivered so far' },
  { label: 'Returned', value: 'returned', description: 'Goods sent back to the supplier' },
  { label: 'Cancelled', value: 'cancelled', description: 'Order cancelled — no goods expected' },
]
const statusOptions = statusFilterOptions.filter(o => o.value !== 'all')

// â”€â”€ Receive confirmation (password required) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const receiveDialog = reactive({ show: false, po: null, password: '', error: '', busy: false })

function openReceiveDialog(po) {
  receiveDialog.po = po
  receiveDialog.password = ''
  receiveDialog.error = ''
  receiveDialog.show = true
}

function closeReceiveDialog() {
  receiveDialog.show = false
  receiveDialog.po = null
  receiveDialog.password = ''
  receiveDialog.error = ''
}

async function confirmReceive() {
  if (!receiveDialog.po) return
  if (!receiveDialog.password) { receiveDialog.error = 'Password is required.'; return }
  receiveDialog.error = ''
  receiveDialog.busy = true
  try {
    await $api.post(`/purchase-orders/orders/${receiveDialog.po.id}/confirm_receive/`, {
      password: receiveDialog.password,
    })
    snack.text = `${receiveDialog.po.po_number} marked as received.`
    snack.color = 'success'
    snack.show = true
    closeReceiveDialog()
    await refresh()
  } catch (e) {
    receiveDialog.error = e?.response?.data?.detail || 'Failed to confirm receipt.'
  } finally {
    receiveDialog.busy = false
  }
}

// ── Return confirmation (password required) ──────────────────────────────────
const returnDialog = reactive({ show: false, po: null, password: '', error: '', busy: false, needsForce: false, force: false })

function openReturnDialog(po) {
  returnDialog.po = po
  returnDialog.password = ''
  returnDialog.error = ''
  returnDialog.needsForce = false
  returnDialog.force = false
  returnDialog.show = true
}

function closeReturnDialog() {
  returnDialog.show = false
  returnDialog.po = null
  returnDialog.password = ''
  returnDialog.error = ''
  returnDialog.needsForce = false
  returnDialog.force = false
}

async function confirmReturn() {
  if (!returnDialog.po) return
  if (!returnDialog.password) { returnDialog.error = 'Password is required.'; return }
  returnDialog.error = ''
  returnDialog.busy = true
  try {
    await $api.post(`/purchase-orders/orders/${returnDialog.po.id}/confirm_return/`, {
      password: returnDialog.password,
      force: returnDialog.force,
    })
    snack.text = `${returnDialog.po.po_number} returned to supplier.`
    snack.color = 'success'
    snack.show = true
    closeReturnDialog()
    await refresh()
  } catch (e) {
    const data = e?.response?.data
    if (data?.needs_force) {
      returnDialog.needsForce = true
      returnDialog.error = data.message || 'Some items have been consumed. Check the box to force return.'
    } else {
      returnDialog.error = data?.detail || 'Failed to return order.'
    }
  } finally {
    returnDialog.busy = false
  }
}

// ── Cancel confirmation (password required) ─────────────────────────────────
const cancelDialog = reactive({ show: false, po: null, password: '', error: '', busy: false })

function openCancelDialog(po) {
  cancelDialog.po = po
  cancelDialog.password = ''
  cancelDialog.error = ''
  cancelDialog.show = true
}

function closeCancelDialog() {
  cancelDialog.show = false
  cancelDialog.po = null
  cancelDialog.password = ''
  cancelDialog.error = ''
}

async function confirmCancel() {
  if (!cancelDialog.po) return
  if (!cancelDialog.password) { cancelDialog.error = 'Password is required.'; return }
  cancelDialog.error = ''
  cancelDialog.busy = true
  try {
    await $api.post(`/purchase-orders/orders/${cancelDialog.po.id}/confirm_cancel/`, {
      password: cancelDialog.password,
    })
    snack.text = `${cancelDialog.po.po_number} has been cancelled.`
    snack.color = 'success'
    snack.show = true
    closeCancelDialog()
    await refresh()
  } catch (e) {
    cancelDialog.error = e?.response?.data?.detail || 'Failed to cancel order.'
  } finally {
    cancelDialog.busy = false
  }
}

// ── Partial receipt (password required) ──────────────────────────────────────
const partialDialog = reactive({
  show: false,
  po: null,
  lines: [],
  notes: '',
  password: '',
  error: '',
  busy: false,
})

function openPartialDialog(po) {
  partialDialog.po = po
  partialDialog.notes = ''
  partialDialog.password = ''
  partialDialog.error = ''
  partialDialog.lines = (po.items || []).map((it) => ({
    medication_stock_id: it.medication_stock_id,
    name: it.name || '—',
    ordered_qty: intSafe(it.qty),
    prev_received: intSafe(it.received_qty),
    recv_qty: 0,
  }))
  partialDialog.show = true
}

function closePartialDialog() {
  partialDialog.show = false
  partialDialog.po = null
  partialDialog.lines = []
  partialDialog.notes = ''
  partialDialog.password = ''
  partialDialog.error = ''
}

function intSafe(v) {
  const n = parseInt(v)
  return isNaN(n) ? 0 : n
}

function varianceText(it) {
  const totalRecv = it.prev_received + (it.recv_qty || 0)
  const v = it.ordered_qty - totalRecv
  return v === 0 ? 'Complete' : `${v} short`
}

function varianceClass(it) {
  const totalRecv = it.prev_received + (it.recv_qty || 0)
  const v = it.ordered_qty - totalRecv
  if (v === 0) return 'text-success font-weight-medium'
  if (totalRecv === 0) return 'text-error'
  return 'text-warning'
}

async function confirmPartial() {
  if (!partialDialog.po) return
  if (!partialDialog.password) { partialDialog.error = 'Password is required.'; return }
  const items = partialDialog.lines
    .filter((it) => (it.recv_qty || 0) > 0)
    .map((it) => ({
      medication_stock_id: it.medication_stock_id,
      received_qty: it.recv_qty,
    }))
  if (!items.length) { partialDialog.error = 'Enter at least one received quantity.'; return }
  partialDialog.error = ''
  partialDialog.busy = true
  try {
    const res = await $api.post(`/purchase-orders/orders/${partialDialog.po.id}/confirm_partial/`, {
      password: partialDialog.password,
      items,
      notes: partialDialog.notes,
    })
    const fullyReceived = res.data?.status === 'received'
    snack.text = `${partialDialog.po.po_number} ${fullyReceived ? 'fully received' : 'partially received'}. GRN: ${res.data?.grn_number || ''}`
    snack.color = 'success'
    snack.show = true
    closePartialDialog()
    await refresh()
  } catch (e) {
    partialDialog.error = e?.response?.data?.detail || 'Failed to process partial receipt.'
  } finally {
    partialDialog.busy = false
  }
}

// â”€â”€ Inline status change (dropdown in the status column) â”€â”€â”€â”€â”€
const updatingStatusId = ref(null)

async function changeStatus(po, newStatus) {
  if (!newStatus || newStatus === po.status || updatingStatusId.value) return
  // Intercept 'received' — requires password confirmation
  if (newStatus === 'received') {
    openReceiveDialog(po)
    return
  }
  // Intercept 'returned' — requires password confirmation
  if (newStatus === 'returned') {
    openReturnDialog(po)
    return
  }
  // Intercept 'cancelled' — requires password confirmation
  if (newStatus === 'cancelled') {
    openCancelDialog(po)
    return
  }
  // Intercept 'partial' — shows comprehensive partial receipt dialog
  if (newStatus === 'partial') {
    openPartialDialog(po)
    return
  }
  const prev = po.status
  po.status = newStatus            // optimistic update
  updatingStatusId.value = po.id
  try {
    await $api.patch(`/purchase-orders/orders/${po.id}/`, { status: newStatus })
    snack.text = `${po.po_number} is now "${statusOptions.find(o => o.value === newStatus)?.label || newStatus}"`
    snack.color = 'success'
    snack.show = true
    await refresh()
  } catch (e) {
    po.status = prev               // roll back
    snack.text = e?.response?.data?.detail || 'Failed to update status.'
    snack.color = 'error'
    snack.show = true
  } finally {
    updatingStatusId.value = null
  }
}

const supplierFilterOptions = computed(() => {
  const map = new Map()
  for (const po of items.value) {
    if (po.supplier && po.supplier_name && !map.has(po.supplier)) {
      map.set(po.supplier, { label: po.supplier_name, value: po.supplier })
    }
  }
  return [...map.values()].sort((a, b) => a.label.localeCompare(b.label))
})

const filtered = computed(() => {
  let arr = items.value
  if (statusFilter.value !== 'all') arr = arr.filter(p => p.status === statusFilter.value)
  if (supplierFilter.value) arr = arr.filter(p => p.supplier === supplierFilter.value)
  const q = (search.value || '').toLowerCase().trim()
  if (q) arr = arr.filter(p =>
    (p.po_number || '').toLowerCase().includes(q) ||
    (p.supplier_name || '').toLowerCase().includes(q)
  )
  return arr
})

const statCards = computed(() => {
  const all = items.value
  const totalSpend = all.reduce((s, p) => s + Number(p.total_cost || 0), 0)
  const open = all.filter(p => ['draft', 'sent', 'partial'].includes(p.status))
  const received = all.filter(p => p.status === 'received')
  const pendingValue = open.reduce((s, p) => s + Number(p.total_cost || 0), 0)
  return [
    { key: 'total', label: 'Total Orders', icon: 'mdi-cart-outline', color: 'primary', value: all.length, sub: `${supplierFilterOptions.value.length} suppliers` },
    { key: 'open', label: 'Open Orders', icon: 'mdi-progress-clock', color: 'warning', value: open.length, sub: 'Draft / sent / partial' },
    { key: 'received', label: 'Received', icon: 'mdi-package-variant-closed-check', color: 'success', value: received.length, sub: 'Stock updated' },
    { key: 'spend', label: 'Total Spend', icon: 'mdi-cash-multiple', color: 'info', value: formatMoney(totalSpend), sub: `Pending: ${formatMoney(pendingValue)}` },
  ]
})

const headers = [
  { title: '#', key: 'rowIndex', width: 60, sortable: false },
  { title: 'PO #', key: 'po_number', width: 130 },
  { title: 'Supplier', key: 'supplier_name' },
  { title: 'Items', key: 'items', width: 90, sortable: false, align: 'center' },
  { title: 'Total', key: 'total_cost', width: 120, align: 'end' },
  { title: 'Shipping', key: 'shipping_cost', width: 110, align: 'end' },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Order date', key: 'order_date', width: 120 },
  { title: 'Expected', key: 'expected_delivery', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase()
}

function goDetail(po) { router.push(`/purchase-orders/${po.id}`) }

// â”€â”€ Date filter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const dateOptions = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'This week', value: 'week' },
  { label: 'This month', value: 'month' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'Last 90 days', value: '90d' },
  { label: 'This year', value: 'year' },
  { label: 'Custom range', value: 'custom' },
]

function isoDate(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function resolveDateRange() {
  if (datePreset.value === 'all') return {}
  if (datePreset.value === 'custom') {
    const out = {}
    if (dateFrom.value) out.date_from = dateFrom.value
    if (dateTo.value) out.date_to = dateTo.value
    return out
  }
  const now = new Date()
  const to = isoDate(now)
  let from = now
  if (datePreset.value === 'today') {
    from = now
  } else if (datePreset.value === 'week') {
    from = new Date(now)
    from.setDate(now.getDate() - ((now.getDay() + 6) % 7)) // Monday
  } else if (datePreset.value === 'month') {
    from = new Date(now.getFullYear(), now.getMonth(), 1)
  } else if (datePreset.value === '30d') {
    from = new Date(now)
    from.setDate(now.getDate() - 30)
  } else if (datePreset.value === '90d') {
    from = new Date(now)
    from.setDate(now.getDate() - 90)
  } else if (datePreset.value === 'year') {
    from = new Date(now.getFullYear(), 0, 1)
  }
  return { date_from: isoDate(from), date_to: to }
}

async function refresh() {
  const params = { ...resolveDateRange() }
  if (branchFilter.value) params.branch = branchFilter.value
  await r.list(params)
}

function confirmDelete(po) {
  deleteDialog.po = po
  deleteDialog.show = true
}

async function doDelete() {
  if (!deleteDialog.po) return
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.po.id)
    snack.text = 'Purchase order deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.show = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Delete failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleteDialog.busy = false
  }
}

watch(branchFilter, () => refresh())
watch(datePreset, () => refresh())
watch(dateFrom, () => { if (datePreset.value === 'custom') refresh() })
watch(dateTo, () => { if (datePreset.value === 'custom') refresh() })

watch(() => branchStore.currentBranchId, (newId) => {
  if (isBranchLocked.value) {
    branchFilter.value = newId
  } else {
    branchFilter.value = newId || null
  }
})

const exporting = ref('')

const invoicingId = ref(null)

async function downloadInvoice(po) {
  invoicingId.value = po.id
  try {
    const blob = (await $api.get(`/purchase-orders/orders/${po.id}/po-pdf/`, { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `purchase_order_${po.po_number || po.id}.pdf`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Invoice download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'Invoice download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    invoicingId.value = null
  }
}

async function downloadReport() {
  exporting.value = 'report'
  try {
    const params = { ...resolveDateRange() }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (supplierFilter.value) params.supplier = supplierFilter.value
    if (branchFilter.value) params.branch = branchFilter.value
    const blob = (await $api.get('/purchase-orders/orders/report-pdf/', { params, responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `purchase_orders_report_${new Date().toISOString().slice(0, 10)}.pdf`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Report download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'Report download failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exporting.value = ''
  }
}

async function exportOrders(fmt) {
  exporting.value = fmt
  try {
    const params = { fmt, ...resolveDateRange() }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (supplierFilter.value) params.supplier = supplierFilter.value
    if (branchFilter.value) params.branch = branchFilter.value
    const blob = (await $api.get('/purchase-orders/orders/export/', { params, responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = `purchase_orders_${new Date().toISOString().slice(0, 10)}.${fmt === 'excel' ? 'xlsx' : 'csv'}`
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.text = 'Export download started.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    snack.text = 'Export failed.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exporting.value = ''
  }
}

onMounted(() => {
  if (isBranchLocked.value && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  } else if (!isBranchLocked.value && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  }
  refresh()
})
</script>

<style scoped>
.po-list-shell { max-width: 1500px; margin: 0 auto; }

.po-stat {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  position: relative;
  overflow: hidden;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.po-stat::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: rgb(var(--v-theme-primary));
}
.po-stat-open::before { background: rgb(var(--v-theme-warning)); }
.po-stat-received::before { background: rgb(var(--v-theme-success)); }
.po-stat-spend::before { background: rgb(var(--v-theme-info)); }
.po-stat:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }

.po-filter-bar {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}

.po-table-card {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  overflow: hidden;
}
.po-data-table :deep(tbody tr) { cursor: pointer; }
.po-data-table :deep(tbody tr:hover) { background: rgba(99, 102, 241, 0.05); }

.po-card-tile {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.po-card-tile:hover {
  transform: translateY(-3px);
  border-color: rgba(99, 102, 241, 0.5);
  box-shadow: 0 8px 22px rgba(99, 102, 241, 0.12);
}

.min-width-0 { min-width: 0; }
.partial-recv-table { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); border-radius: 8px; overflow: hidden; }
.partial-qty-input :deep(input) { text-align: right; }
</style>
