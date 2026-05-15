<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">
        <v-icon color="error" class="mr-1">mdi-alert-octagram</v-icon>Critical Findings
      </h1>
      <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
    </div>

    <v-card rounded="lg" class="pa-3 mb-4" border>
      <v-row dense align="center">
        <v-col cols="12" sm="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" label="Search..." density="compact" hide-details clearable variant="outlined" rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3">
          <v-select v-model="filterAck" :items="[{title:'Pending',value:false},{title:'Acknowledged',value:true}]" label="Acknowledged" density="compact" hide-details clearable variant="outlined" rounded="lg" />
        </v-col>
      </v-row>
    </v-card>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.severity="{ item }">
          <v-chip size="x-small" :color="item.severity === 'critical' ? 'error' : 'warning'" variant="flat">{{ item.severity_display }}</v-chip>
        </template>
        <template #item.acknowledged="{ item }">
          <v-chip size="x-small" :color="item.acknowledged ? 'success' : 'warning'" variant="tonal">{{ item.acknowledged ? 'Yes' : 'Pending' }}</v-chip>
        </template>
        <template #item.communicated_at="{ item }">{{ formatDate(item.communicated_at) }}</template>
        <template #item.actions="{ item }">
          <v-btn v-if="!item.acknowledged" icon="mdi-check" size="small" variant="text" color="success" title="Acknowledge" @click="acknowledge(item.id)" />
          <v-btn icon="mdi-eye" size="small" variant="text" :to="`/radiology/reports/${item.report}`" />
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const alerts = ref([])
const search = ref('')
const filterAck = ref(null)

const headers = [
  { title: 'Finding', key: 'finding_description' },
  { title: 'Severity', key: 'severity' },
  { title: 'Communicated To', key: 'communicated_to' },
  { title: 'By', key: 'communicated_by_name' },
  { title: 'Method', key: 'method' },
  { title: 'Date', key: 'communicated_at' },
  { title: 'Acknowledged', key: 'acknowledged', align: 'center' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

const filtered = computed(() => {
  let list = alerts.value
  if (filterAck.value !== null && filterAck.value !== undefined) list = list.filter(a => a.acknowledged === filterAck.value)
  return list
})

function formatDate(d) { return d ? new Date(d).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—' }

async function acknowledge(id) {
  try {
    await $api.patch(`/radiology/critical-alerts/${id}/`, { acknowledged: true, acknowledged_at: new Date().toISOString() })
    await load()
  } catch (e) { console.error(e) }
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/critical-alerts/?page_size=500&ordering=-communicated_at')
    alerts.value = res.data?.results || res.data || []
  } catch { alerts.value = [] }
  loading.value = false
}
onMounted(load)
</script>
