<template>
  <ResourceListPage
    title="Consents"
    subtitle="Patient-signed authorisations"
    icon="mdi-file-document-check"
    :resource="resource"
    :headers="headers"
    singular="consent"
    empty-icon="mdi-file-document-outline"
    empty-title="No consents on file"
  >
    <template #cell-is_active="{ item }"><StatusChip :status="item.is_active ? 'active' : 'closed'" /></template>
    <template #actions="{ item }">
      <v-btn v-if="!item.revoked_at" size="small" color="error" variant="text"
             prepend-icon="mdi-cancel" @click="revoke(item)">Revoke</v-btn>
    </template>
  </ResourceListPage>
</template>
<script setup>
const { $api } = useNuxtApp()
const resource = useResource('/homecare/consents/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Scope', key: 'scope' },
  { title: 'Granted to', key: 'granted_to' },
  { title: 'Granted at', key: 'granted_at' },
  { title: 'Active', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
async function revoke(c) {
  await $api.post(`/homecare/consents/${c.id}/revoke/`)
  resource.list()
}
</script>
