<template>
  <ResourceDetailPage :resource="r" title="Order" icon="mdi-receipt-text" back-path="/pharmacy-store/orders" :load-id="id">
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center justify-space-between mb-4">
          <div>
            <div class="text-h5 font-weight-bold">Order #{{ item.order_number }}</div>
            <div class="text-body-2 text-medium-emphasis">{{ item.pharmacy_name }} • {{ formatDateTime(item.created_at) }}</div>
          </div>
          <StatusChip :status="item.status" />
        </div>
        <InfoGrid :item="item" :fields="[{key:'delivery_address',label:'Delivery Address',md:8},{key:'contact_phone',label:'Phone'}]" />
        <v-divider class="my-4" />
        <h3 class="text-subtitle-1 font-weight-bold mb-2">Items</h3>
        <v-table density="compact">
          <thead><tr><th>Product</th><th class="text-end">Qty</th><th class="text-end">Unit</th><th class="text-end">{{ $t('common.subtotal') }}</th></tr></thead>
          <tbody>
            <tr v-for="(it, i) in (item.items || [])" :key="i">
              <td>{{ it.product_name }}</td>
              <td class="text-end">{{ it.quantity }}</td>
              <td class="text-end">{{ formatMoney(it.unit_price) }}</td>
              <td class="text-end">{{ formatMoney((it.quantity||0)*(it.unit_price||0)) }}</td>
            </tr>
          </tbody>
        </v-table>
        <div class="d-flex justify-end mt-2"><div class="text-h6">Total: {{ formatMoney(item.total) }}</div></div>
      </v-card>
    </template>
  </ResourceDetailPage>
</template>
<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { useResource } from '~/composables/useResource'
import { formatDateTime, formatMoney } from '~/utils/format'
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/exchange/orders/')
</script>
