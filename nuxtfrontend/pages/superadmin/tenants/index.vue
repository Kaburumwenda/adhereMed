<template>
  <ResourceListPage
    :resource="r"
    title="Tenants"
    icon="mdi-domain"
    :headers="headers"
    create-path="/superadmin/tenants/new"
    create-label="New Tenant"
    singular="tenant"
    :detail-path="(p) => `/superadmin/tenants/${p.id}/edit`"
    :edit-path="(p) => `/superadmin/tenants/${p.id}/edit`"
  >
    <template #cell-tenant_type="{ value }">
      <v-chip size="small" variant="tonal" class="text-capitalize">{{ value }}</v-chip>
    </template>
    <template #cell-is_active="{ value }">
      <v-chip size="small" :color="value ? 'success' : 'grey'" variant="tonal">{{ value ? 'Active' : 'Inactive' }}</v-chip>
    </template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/tenants/')
const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Schema', key: 'schema_name' },
  { title: 'Type', key: 'tenant_type' },
  { title: 'Domain', key: 'domain' },
  { title: 'Active', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
