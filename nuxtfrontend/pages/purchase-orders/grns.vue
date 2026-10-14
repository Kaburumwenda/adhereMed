<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="success" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-truck-check-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Goods Received Notes</h1>
          <div class="text-body-2 text-medium-emphasis">Track all received shipments against purchase orders</div>
        </div>
      </div>
      <v-btn variant="tonal" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" @click="navigateTo('/purchase-orders')">Back to Purchase Orders</v-btn>
    </div>

    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />
      <div v-if="!loading && !items.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-truck-check-outline</v-icon>
        <div class="text-h6 mt-3">No GRNs recorded</div>
        <div class="text-body-2">GRNs are created automatically when purchase orders are marked as received.</div>
      </div>
      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>GRN #</th>
              <th>Purchase Order</th>
              <th>Received by</th>
              <th>Date</th>
              <th>Notes</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in items" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
              <td class="font-weight-medium">{{ row.grn_number }}</td>
              <td>
                <v-btn size="small" variant="text" class="text-none" @click="navigateTo(`/purchase-orders/${row.purchase_order}`)">View PO</v-btn>
              </td>
              <td class="text-medium-emphasis">{{ row.received_by_name || '—' }}</td>
              <td class="text-medium-emphasis">{{ formatDate(row.received_date) }}</td>
              <td class="text-medium-emphasis text-truncate" style="max-width:240px">{{ row.notes || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const grnRes = useResource('/purchase-orders/grns/')
const loading = computed(() => grnRes.loading.value)
const items = computed(() => grnRes.items.value || [])

onMounted(() => grnRes.list({ page_size: 500 }))
</script>
