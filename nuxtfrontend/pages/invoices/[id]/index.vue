<template>
  <ResourceDetailPage :resource="r" title="Invoice" icon="mdi-receipt-text" back-path="/invoices" :edit-path="`/invoices/${id}/edit`" :load-id="id">
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center justify-space-between mb-4">
          <div>
            <div class="text-h5 font-weight-bold">Invoice #{{ item.invoice_number }}</div>
            <div class="text-body-2 text-medium-emphasis">{{ item.patient_name }} • {{ formatDate(item.issued_at) }}</div>
          </div>
          <StatusChip :status="item.status" />
        </div>
        <v-table density="compact" class="mb-3">
          <thead><tr><th>Description</th><th class="text-end">Qty</th><th class="text-end">Unit</th><th class="text-end">{{ $t('common.subtotal') }}</th></tr></thead>
          <tbody>
            <tr v-for="(it, i) in (item.items || [])" :key="i">
              <td>{{ it.description }}</td>
              <td class="text-end">{{ it.quantity }}</td>
              <td class="text-end">{{ formatMoney(it.unit_price) }}</td>
              <td class="text-end">{{ formatMoney((it.quantity||0)*(it.unit_price||0)) }}</td>
            </tr>
          </tbody>
        </v-table>
        <div class="d-flex justify-end">
          <div class="text-h6">Total: {{ formatMoney(item.total) }}</div>
        </div>
      </v-card>
    </template>
  </ResourceDetailPage>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/billing/invoices/')
</script>
