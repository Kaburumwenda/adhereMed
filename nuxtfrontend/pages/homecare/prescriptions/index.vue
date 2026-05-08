<template>
  <ResourceListPage
    title="Prescriptions"
    subtitle="Homecare prescriptions and pharmacy fulfilment"
    icon="mdi-prescription"
    :resource="resource"
    :headers="headers"
    singular="prescription"
    empty-icon="mdi-prescription"
    empty-title="No prescriptions yet"
  >
    <template #cell-items_count="{ item }">{{ (item.items || []).length }}</template>
    <template #cell-pharmacy_status="{ item }"><StatusChip :status="item.pharmacy_status" /></template>
    <template #actions="{ item }">
      <v-btn size="small" color="teal" variant="text" prepend-icon="mdi-truck-delivery"
             @click="openForward(item)">Forward</v-btn>
    </template>
  </ResourceListPage>

  <v-dialog v-model="dialog" max-width="600">
    <v-card rounded="xl">
      <v-card-title>Forward to pharmacy</v-card-title>
      <v-card-text>
        <v-select v-model="form.pharmacy_tenant_id" :items="pharmacies"
                  item-title="name" item-value="id" label="Pharmacy" />
        <v-text-field v-model="form.pharmacy_name" label="Pharmacy name" />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
        <v-btn color="teal" :loading="saving" @click="forward">Forward</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
<script setup>
const { $api } = useNuxtApp()
const resource = useResource('/homecare/prescriptions/')
const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Items', key: 'items_count', sortable: false },
  { title: 'Forwarded to', key: 'forwarded_pharmacy_name' },
  { title: 'Status', key: 'pharmacy_status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
const dialog = ref(false)
const saving = ref(false)
const target = ref(null)
const form = reactive({ pharmacy_tenant_id: null, pharmacy_name: '' })
const pharmacies = ref([])
async function openForward(item) {
  target.value = item
  dialog.value = true
  try {
    const { data } = await $api.get('/tenants/', { params: { type: 'pharmacy' } })
    pharmacies.value = (data?.results || data || []).map(t => ({ id: t.id, name: t.name }))
  } catch { pharmacies.value = [] }
}
async function forward() {
  saving.value = true
  try {
    await $api.post(`/homecare/prescriptions/${target.value.id}/forward_to_pharmacy/`, form)
    dialog.value = false
    resource.list()
  } finally { saving.value = false }
}
</script>
