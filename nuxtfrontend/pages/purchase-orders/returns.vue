<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Returns to Vendor"
      subtitle="Reverse logistics — return received stock to the supplier and reconcile inventory"
      eyebrow="PROCUREMENT · REVERSE LOGISTICS"
      icon="mdi-undo-variant"
      color="deep-orange"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    />

    <v-alert type="info" variant="tonal" rounded="lg" class="mb-4" icon="mdi-information-outline">
      A return reverses the receipt: stock and batches are reduced, and the purchase price is restored to its previous value.
      Lines that have already been consumed since receipt can be previewed but not returned.
    </v-alert>

    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <v-tabs v-model="tab" color="deep-orange" density="compact" class="mt-4 border-b">
      <v-tab value="eligible" prepend-icon="mdi-tray-arrow-up" class="text-none">
        Eligible for return
        <v-chip v-if="returnable.length" size="x-small" color="deep-orange" variant="tonal" class="ml-2">{{ returnable.length }}</v-chip>
      </v-tab>
      <v-tab value="history" prepend-icon="mdi-history" class="text-none">
        Return history
        <v-chip v-if="returned.length" size="x-small" variant="tonal" class="ml-2">{{ returned.length }}</v-chip>
      </v-tab>
    </v-tabs>

    <!-- Eligible -->
    <template v-if="tab === 'eligible'">
      <EmptyState
        v-if="!loading && !returnable.length"
        icon="mdi-check-decagram-outline"
        title="Nothing to return"
        message="No received purchase orders have returnable lines."
      />
      <v-row v-else dense class="mt-2">
        <v-col v-for="po in returnable" :key="po.id" cols="12" md="6" xl="4">
          <v-card rounded="lg" class="pa-4 h-100 return-card" border>
            <div class="d-flex align-start justify-space-between mb-2">
              <div>
                <div class="text-caption text-medium-emphasis">Purchase order</div>
                <div class="text-h6 font-weight-bold text-primary" style="cursor:pointer"
                     @click="navigateTo(`/ims/purchase-orders/${po.id}`)">{{ po.po_number }}</div>
                <div class="text-body-2 text-medium-emphasis">{{ po.supplier_name || '—' }}</div>
              </div>
              <StatusChip :status="po.status" />
            </div>

            <v-divider class="my-3" />

            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-medium-emphasis">Order value</span>
              <span class="font-weight-medium">{{ formatMoney(po.landedCost) }}</span>
            </div>
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-medium-emphasis">Lines synced</span>
              <span class="font-weight-medium">{{ syncedLines(po).length }} / {{ (po.items || []).length }}</span>
            </div>
            <div class="d-flex justify-space-between text-body-2 mb-3">
              <span class="text-medium-emphasis">Received</span>
              <span class="font-weight-medium">{{ formatDate(po.receivedDate) }}</span>
            </div>

            <v-progress-linear
              :model-value="(syncedLines(po).length / Math.max(1, (po.items || []).length)) * 100"
              color="deep-orange" height="5" rounded class="mb-3"
            />

            <v-btn block color="deep-orange" variant="tonal" rounded="lg" class="text-none"
                   prepend-icon="mdi-file-eye-outline" :loading="previewing === po.id"
                   @click="openPreview(po)">Preview return</v-btn>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- History -->
    <template v-else>
      <EmptyState
        v-if="!returned.length"
        icon="mdi-history"
        title="No returns recorded"
        message="Completed vendor returns will appear here."
      />
      <v-card v-else rounded="lg" class="mt-2" border>
        <v-data-table
          :headers="historyHeaders"
          :items="returned"
          :items-per-page="25"
          density="comfortable"
          hover
        >
          <template #item.po_number="{ item }">
            <span class="font-weight-bold text-primary" style="cursor:pointer"
                  @click="navigateTo(`/ims/purchase-orders/${item.id}`)">{{ item.po_number }}</span>
          </template>
          <template #item.landedCost="{ item }">{{ formatMoney(item.landedCost) }}</template>
          <template #item.order_date="{ item }">{{ formatDate(item.order_date) }}</template>
          <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
        </v-data-table>
      </v-card>
    </template>

    <!-- Preview / confirm dialog -->
    <v-dialog v-model="dialog" max-width="820" scrollable>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="deep-orange" class="mr-2">mdi-undo-variant</v-icon>
          Return preview — {{ preview?.po_number }}
        </v-card-title>
        <v-card-subtitle>
          {{ preview?.items?.length || 0 }} line{{ (preview?.items?.length || 0) === 1 ? '' : 's' }} ·
          stock and batch quantities will be reduced and purchase prices restored
        </v-card-subtitle>
        <v-card-text>
          <v-progress-linear v-if="previewLoading" indeterminate color="deep-orange" class="mb-3" />

          <v-alert v-if="preview?.has_consumed" type="warning" variant="tonal" density="compact" class="mb-3 text-caption">
            Some lines have been consumed since receipt. Those lines will be skipped — only unconsumed quantities can be returned.
          </v-alert>

          <v-table v-if="preview?.items?.length" density="compact">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right">Received</th>
                <th class="text-right">Consumed</th>
                <th class="text-right">Returnable</th>
                <th class="text-right">Cost now → was</th>
                <th class="text-right">Price now → was</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, i) in preview.items" :key="i" :class="it.consumed > 0 ? 'text-disabled' : ''">
                <td class="text-truncate font-weight-medium" style="max-width: 200px">{{ it.name }}</td>
                <td class="text-right">{{ it.received }}</td>
                <td class="text-right">{{ it.consumed }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="it.remaining > 0 ? 'success' : 'grey'" variant="tonal">{{ it.remaining }}</v-chip>
                </td>
                <td class="text-right text-caption">
                  {{ formatMoney(it.current_cost_price) }}
                  <v-icon size="12" class="mx-1">mdi-arrow-right</v-icon>
                  {{ it.previous_cost_price != null ? formatMoney(it.previous_cost_price) : '—' }}
                </td>
                <td class="text-right text-caption">
                  {{ formatMoney(it.current_selling_price) }}
                  <v-icon size="12" class="mx-1">mdi-arrow-right</v-icon>
                  {{ it.previous_selling_price != null ? formatMoney(it.previous_selling_price) : '—' }}
                </td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else-if="!previewLoading" icon="mdi-package-variant-remove" title="No returnable lines" />

          <v-textarea
            v-model="returnNote"
            label="Reason for return (reference for the vendor)"
            variant="outlined"
            density="compact"
            rows="2"
            hide-details
            class="mt-4"
          />
        </v-card-text>
        <v-card-actions>
          <v-btn variant="text" class="text-none" @click="dialog = false">Close</v-btn>
          <v-spacer />
          <v-btn
            color="deep-orange"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-undo-variant"
            :loading="returning"
            :disabled="!preview?.items?.length"
            @click="confirmReturn"
          >Confirm return</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum } from '~/utils/bi'

const { $api } = useNuxtApp()
const {
  loading, returnableOrders, returnedOrders, branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const tab = ref('eligible')
const dialog = ref(false)
const preview = ref(null)
const previewLoading = ref(false)
const previewing = ref(null)
const returning = ref(false)
const returnNote = ref('')
const previewId = ref(null)

const returnable = computed(() => returnableOrders.value)
const returned = computed(() => returnedOrders.value)

function syncedLines(po) {
  return (po.items || []).filter((it) => it._synced && !it._returned)
}

const kpis = computed(() => {
  const value = sum(returnable.value, (po) => po.landedCost)
  const units = sum(returnable.value.flatMap((po) => syncedLines(po)), (it) => num(it.qty))
  const credit = sum(returned.value, (po) => po.landedCost)
  return [
    { title: 'Eligible orders', value: String(returnable.value.length), valueNum: returnable.value.length, icon: 'mdi-tray-arrow-up', color: 'deep-orange', hint: 'Received with synced lines' },
    { title: 'Returnable value', value: formatMoney(value), valueNum: value, icon: 'mdi-cash-refund', color: 'orange', hint: 'Credit potential' },
    { title: 'Returnable units', value: units.toLocaleString(), valueNum: units, icon: 'mdi-package-variant-remove', color: 'amber', hint: 'Unconsumed quantity' },
    { title: 'Completed returns', value: String(returned.value.length), valueNum: returned.value.length, icon: 'mdi-history', color: 'teal', hint: `${formatMoney(credit)} processed` }
  ]
})

const historyHeaders = [
  { title: 'PO', key: 'po_number' },
  { title: 'Supplier', key: 'supplier_name' },
  { title: 'Lines', key: 'grnCount', align: 'end', sortable: false },
  { title: 'Value', key: 'landedCost', align: 'end' },
  { title: 'Order date', key: 'order_date', align: 'end' },
  { title: 'Status', key: 'status', align: 'center' }
]

async function openPreview(po) {
  previewing.value = po.id
  previewLoading.value = true
  dialog.value = true
  preview.value = { po_number: po.po_number, items: [] }
  try {
    const { data } = await $api.get(`/purchase-orders/orders/${po.id}/return_preview/`)
    preview.value = data
    previewId.value = po.id
  } catch {
    preview.value = { po_number: po.po_number, items: [] }
  } finally {
    previewLoading.value = false
    previewing.value = null
  }
}

async function confirmReturn() {
  if (!previewId.value) return
  returning.value = true
  try {
    await $api.post(`/purchase-orders/orders/${previewId.value}/return_purchase/`, { notes: returnNote.value })
    dialog.value = false
    returnNote.value = ''
    await load()
    tab.value = 'history'
  } finally {
    returning.value = false
  }
}
</script>

<style scoped>
.return-card {
  transition: box-shadow 0.16s ease;
}
.return-card:hover {
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.08);
}
</style>
