<template>
  <ResourceListPage
    :resource="r"
    title="Users"
    icon="mdi-account-multiple"
    :headers="headers"
    create-path="/superadmin/users/new"
    create-label="New User"
    singular="user"
    :detail-path="(p) => `/superadmin/users/${p.id}/edit`"
    :edit-path="(p) => `/superadmin/users/${p.id}/edit`"
  >
    <template #cell-role="{ value }"><v-chip size="small" variant="tonal" class="text-capitalize">{{ formatRole(value) }}</v-chip></template>
    <template #cell-is_active="{ value }">
      <v-chip size="small" :color="value ? 'success' : 'grey'" variant="tonal">{{ value ? 'Active' : 'Inactive' }}</v-chip>
    </template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatRole } from '~/utils/format'
const r = useResource('/accounts/users/')
const headers = [
  { title: 'Email', key: 'email' },
  { title: 'Name', key: 'full_name' },
  { title: 'Role', key: 'role' },
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Active', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
