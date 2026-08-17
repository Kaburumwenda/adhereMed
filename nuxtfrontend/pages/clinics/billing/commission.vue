<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="My Commission" subtitle="Your commission earnings" icon="mdi-percent" color="success">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="loading" @click="loadData">Refresh</v-btn>
      </template>
    </PageHeader>

    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="h-100">
          <v-card-text class="d-flex align-center ga-3 py-3">
            <v-avatar :color="k.color" size="40" rounded="lg" variant="tonal"><v-icon :icon="k.icon" :color="k.color" size="22" /></v-avatar>
            <div><div class="text-h6 font-weight-bold">{{ k.value }}</div><div class="text-caption text-medium-emphasis">{{ k.label }}</div></div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg">
      <v-card-text>
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search commission…" variant="outlined" density="compact" hide-details clearable class="mb-3" />
        <v-data-table :headers="headers" :items="filteredItems" :loading="loading" density="compact" hover>
          <template #item.amount="{ value }">{{ formatMoney(value) }}</template>
          <template #item.date="{ value }">{{ formatDate(value) }}</template>
          <template #item.status="{ value }"><v-chip :color="statusColor(value)" size="small" variant="tonal">{{ value }}</v-chip></template>
          <template #no-data>
            <div class="text-center pa-8">
              <v-icon size="64" color="grey-lighten-1">mdi-percent</v-icon>
              <div class="text-h6 mt-2">No commission records</div>
            </div>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatDate, formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const items = ref([])
const loading = ref(false)
const search = ref('')

const headers = [
  { title: 'Date', key: 'date' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Service', key: 'service_type' },
  { title: 'Amount', key: 'amount' },
  { title: 'Rate', key: 'commission_rate' },
  { title: 'Status', key: 'status' },
]

onMounted(() => loadData())
async function loadData() {
  loading.value = true
  try {
    const { data } = await $api.get('/billing/commission/', { params: { page_size: 1000 } })
    items.value = data?.results || data || []
  } catch { items.value = [] }
  finally { loading.value = false }
}

const filteredItems = computed(() => {
  if (!search.value) return items.value
  const q = search.value.toLowerCase()
  return items.value.filter(i => JSON.stringify(i).toLowerCase().includes(q))
})

const kpis = computed(() => [
  { label: 'Total Earned', value: formatMoney(items.value.reduce((s, i) => s + Number(i.amount || 0), 0)), icon: 'mdi-cash', color: 'success' },
  { label: 'Pending', value: formatMoney(items.value.filter(i => i.status === 'pending').reduce((s, i) => s + Number(i.amount || 0), 0)), icon: 'mdi-clock-outline', color: 'warning' },
  { label: 'Paid', value: formatMoney(items.value.filter(i => i.status === 'paid').reduce((s, i) => s + Number(i.amount || 0), 0)), icon: 'mdi-check-circle', color: 'primary' },
  { label: 'Total Records', value: items.value.length, icon: 'mdi-list-status', color: 'info' },
])

function statusColor(s) { return { pending: 'warning', paid: 'success', cancelled: 'error' }[s] || 'grey' }
</script>
