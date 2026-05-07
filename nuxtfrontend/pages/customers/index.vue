<template>
  <ResourceListPage
    :resource="r"
    title="Customers"
    icon="mdi-account-group"
    :headers="headers"
    create-path="/customers/new"
    create-label="New Customer"
    singular="customer"
    :detail-path="(p) => `/customers/${p.id}/edit`"
    :edit-path="(p) => `/customers/${p.id}/edit`"
  />
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/pos/customers/')
const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Phone', key: 'phone' },
  { title: 'Email', key: 'email' },
  { title: 'Loyalty pts', key: 'loyalty_points' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
