<template>
  <ResourceListPage
    :resource="r"
    title="Staff Performance"
    icon="mdi-chart-line"
    :headers="headers"
    :detail-path="null"
    :edit-path="null"
    :deletable="false"
  >
    <template #cell-revenue="{ value }">{{ formatMoney(value) }}</template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'
const r = useResource('/accounts/staff/performance/')
const headers = [
  { title: 'Staff', key: 'full_name' },
  { title: 'Role', key: 'role' },
  { title: 'Sales', key: 'sales_count' },
  { title: 'Revenue', key: 'revenue' },
  { title: 'Hours', key: 'hours_worked' }
]
</script>
