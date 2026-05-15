<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">Quality Control</h1>
      <div class="d-flex" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/radiology/qc/new">New QC Record</v-btn>
      </div>
    </div>

    <!-- Summary cards -->
    <v-row dense class="mb-4">
      <v-col v-for="kpi in kpis" :key="kpi.label" cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" :color="kpi.color" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ kpi.value }}</div>
          <div class="text-caption">{{ kpi.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="records" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.status="{ item }">
          <v-chip size="x-small" :color="item.status === 'pass' ? 'success' : item.status === 'warn' ? 'warning' : 'error'" variant="flat">{{ item.status_display }}</v-chip>
        </template>
        <template #item.qc_date="{ item }">{{ new Date(item.qc_date).toLocaleDateString() }}</template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="del(item)" />
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const records = ref([])

const kpis = computed(() => {
  const pass = records.value.filter(r => r.status === 'pass').length
  const warn = records.value.filter(r => r.status === 'warn').length
  const fail = records.value.filter(r => r.status === 'fail').length
  return [
    { label: 'Total Records', value: records.value.length, color: 'primary' },
    { label: 'Pass', value: pass, color: 'success' },
    { label: 'Warning', value: warn, color: 'warning' },
    { label: 'Fail', value: fail, color: 'error' },
  ]
})

const headers = [
  { title: 'Modality', key: 'modality_name' }, { title: 'Performed By', key: 'performed_by_name' },
  { title: 'Date', key: 'qc_date' }, { title: 'Status', key: 'status' },
  { title: 'Dose Output', key: 'dose_output' }, { title: 'Image Quality', key: 'image_quality_score' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]

async function del(item) {
  if (!confirm('Delete this QC record?')) return
  try { await $api.delete(`/radiology/qc/${item.id}/`); await load() } catch (e) { console.error(e) }
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/qc/?page_size=500&ordering=-qc_date')
    records.value = res.data?.results || res.data || []
  } catch { records.value = [] }
  loading.value = false
}
onMounted(load)
</script>
