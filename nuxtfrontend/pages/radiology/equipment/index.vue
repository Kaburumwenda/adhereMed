<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">Modalities / Equipment</h1>
      <div class="d-flex" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/radiology/equipment/new">Add Equipment</v-btn>
      </div>
    </div>

    <v-row dense class="mb-4">
      <v-col v-for="kpi in kpis" :key="kpi.label" cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" :color="kpi.color" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ kpi.value }}</div>
          <div class="text-caption">{{ kpi.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="modalities" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.is_active="{ item }">
          <v-chip size="x-small" :color="item.is_active ? 'success' : 'error'" variant="tonal">{{ item.is_active ? 'Active' : 'Offline' }}</v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" size="small" variant="text" :to="`/radiology/equipment/${item.id}/edit`" />
          <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="del(item)" />
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const modalities = ref([])

const kpis = computed(() => {
  const total = modalities.value.length
  const active = modalities.value.filter(m => m.is_active).length
  const offline = total - active
  const types = new Set(modalities.value.map(m => m.modality_type)).size
  return [
    { label: 'Total Equipment', value: total, color: 'primary' },
    { label: 'Active', value: active, color: 'success' },
    { label: 'Offline', value: offline, color: 'error' },
    { label: 'Types', value: types, color: 'info' },
  ]
})

const headers = [
  { title: 'Name', key: 'name' }, { title: 'Type', key: 'modality_type_display' },
  { title: 'Manufacturer', key: 'manufacturer' }, { title: 'Room', key: 'room_location' },
  { title: 'Serial #', key: 'serial_number' }, { title: 'Max Slots', key: 'max_daily_slots' },
  { title: 'Status', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

async function del(item) {
  if (!confirm(`Delete "${item.name}"?`)) return
  try { await $api.delete(`/radiology/modalities/${item.id}/`); await load() } catch (e) { console.error(e) }
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/modalities/?page_size=200')
    modalities.value = res.data?.results || res.data || []
  } catch { modalities.value = [] }
  loading.value = false
}
onMounted(load)
</script>
