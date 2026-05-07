<template>
  <ResourceListPage
    :resource="r"
    title="My Orders"
    icon="mdi-receipt-text"
    :headers="headers"
    :detail-path="(p) => `/pharmacy-store/orders/${p.id}`"
    :edit-path="null"
    :deletable="false"
  >
    <template #cell-status="{ value }"><StatusChip :status="value" /></template>
    <template #cell-total="{ value }">{{ formatMoney(value) }}</template>
    <template #cell-created_at="{ value }">{{ formatDateTime(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime, formatMoney } from '~/utils/format'
const r = useResource('/exchange/orders/')
const headers = [
  { title: 'Order #', key: 'order_number', width: 130 },
  { title: 'Pharmacy', key: 'pharmacy_name' },
  { title: 'Total', key: 'total' },
  { title: 'Status', key: 'status' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 }
]
</script>
