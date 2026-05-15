<template>
  <ResourceListPage
    :resource="r"
    title="Report Templates"
    icon="mdi-printer-pos"
    :headers="headers"
    create-path="/radiology/report-templates/new"
    create-label="New Template"
    singular="template"
    :edit-path="(p) => `/radiology/report-templates/${p.id}/edit`"
  >
    <template #cell-is_active="{ value }">
      <v-chip size="x-small" :color="value ? 'success' : 'grey'" variant="tonal">{{ value ? 'Active' : 'Inactive' }}</v-chip>
    </template>
  </ResourceListPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/radiology/report-templates/')
const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Modality', key: 'modality_type' },
  { title: 'Body Region', key: 'body_region' },
  { title: 'Active', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 },
]
</script>
