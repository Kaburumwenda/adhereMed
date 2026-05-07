<template>
  <ResourceListPage
    :resource="r"
    title="Departments"
    icon="mdi-domain"
    :headers="headers"
    create-path="/departments/new"
    create-label="New Department"
    singular="department"
    :detail-path="(p) => `/departments/${p.id}/edit`"
    :edit-path="(p) => `/departments/${p.id}/edit`"
  >
    <template #cell-is_active="{ value }">
      <v-chip size="small" :color="value ? 'success' : 'grey'" variant="tonal">{{ value ? 'Active' : 'Inactive' }}</v-chip>
    </template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/departments/')
const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Head', key: 'head_name' },
  { title: 'Description', key: 'description' },
  { title: 'Active', key: 'is_active', width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>
