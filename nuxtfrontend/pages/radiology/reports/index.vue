<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">Radiology Reports</h1>
      <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
    </div>

    <v-card rounded="lg" class="pa-3 mb-4" border>
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" label="Search..." density="compact" hide-details clearable variant="outlined" rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterStatus" :items="statusOpts" label="Status" density="compact" hide-details clearable variant="outlined" rounded="lg" />
        </v-col>
      </v-row>
    </v-card>

    <v-tabs v-model="tab" class="mb-3" density="compact" color="primary">
      <v-tab value="">All ({{ reports.length }})</v-tab>
      <v-tab v-for="s in statusOpts" :key="s.value" :value="s.value">{{ s.title }} ({{ reports.filter(r => r.report_status === s.value).length }})</v-tab>
    </v-tabs>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.report_status="{ item }">
          <v-chip size="x-small" :color="reportColor(item.report_status)" variant="tonal">{{ item.report_status_display }}</v-chip>
        </template>
        <template #item.critical_finding="{ item }">
          <v-icon v-if="item.critical_finding" color="error" size="18">mdi-alert-circle</v-icon>
        </template>
        <template #item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" size="small" variant="text" :to="`/radiology/reports/${item.id}`" />
          <v-btn v-if="item.report_status === 'draft' || item.report_status === 'preliminary'" icon="mdi-pencil" size="small" variant="text" :to="`/radiology/reports/${item.id}?edit=1`" />
          <v-btn v-if="item.report_status !== 'final'" icon="mdi-check-decagram" size="small" variant="text" color="success" title="Sign" @click="signReport(item.id)" />
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const reports = ref([])
const search = ref('')
const filterStatus = ref(null)
const tab = ref('')

const statusOpts = [
  { title: 'Draft', value: 'draft' }, { title: 'Preliminary', value: 'preliminary' },
  { title: 'Final', value: 'final' }, { title: 'Amended', value: 'amended' },
  { title: 'Addendum', value: 'addendum' },
]
const headers = [
  { title: 'Order #', key: 'order' },
  { title: 'Radiologist', key: 'radiologist_name' },
  { title: 'Status', key: 'report_status' },
  { title: 'Critical', key: 'critical_finding', align: 'center' },
  { title: 'Date', key: 'created_at' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 120 },
]

function reportColor(s) { return { draft: 'grey', preliminary: 'warning', final: 'success', amended: 'info', addendum: 'purple' }[s] || 'grey' }
function formatDate(d) { return d ? new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) : '—' }

const filtered = computed(() => {
  let list = reports.value
  if (tab.value) list = list.filter(r => r.report_status === tab.value)
  if (filterStatus.value) list = list.filter(r => r.report_status === filterStatus.value)
  return list
})

async function signReport(id) {
  try {
    await $api.post(`/radiology/reports/${id}/sign/`)
    await load()
  } catch (e) { console.error(e) }
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/radiology/reports/?page_size=500&ordering=-created_at')
    reports.value = res.data?.results || res.data || []
  } catch { reports.value = [] }
  loading.value = false
}
onMounted(load)
</script>
