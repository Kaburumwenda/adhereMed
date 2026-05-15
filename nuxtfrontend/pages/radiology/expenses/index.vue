<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold"><v-icon class="mr-1">mdi-cash-minus</v-icon>Radiology Expenses</h1>
      <div class="d-flex" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/radiology/expenses/new">New Expense</v-btn>
      </div>
    </div>

    <v-row dense class="mb-4">
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" color="error" variant="tonal" border>
          <div class="text-h6 font-weight-bold">{{ formatMoney(totalExpenses) }}</div>
          <div class="text-caption">Total Expenses</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" color="info" variant="tonal" border>
          <div class="text-h6 font-weight-bold">{{ expenses.length }}</div>
          <div class="text-caption">Records</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="expenses" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.amount="{ item }"><span class="text-error font-weight-medium">{{ formatMoney(item.amount) }}</span></template>
        <template #item.date="{ item }">{{ formatDate(item.date) }}</template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" size="small" variant="text" :to="`/expenses/${item.id}/edit`" />
          <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="del(item)" />
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const loading = ref(false)
const expenses = ref([])

const totalExpenses = computed(() => expenses.value.reduce((s, e) => s + Number(e.amount || 0), 0))

const headers = [
  { title: 'Date', key: 'date' }, { title: 'Category', key: 'category_name' },
  { title: 'Description', key: 'description' }, { title: 'Amount', key: 'amount', align: 'end' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 80 },
]

function formatDate(d) { return d ? new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) : '—' }

async function del(item) {
  if (!confirm('Delete this expense?')) return
  try { await $api.delete(`/expenses/${item.id}/`); await load() } catch (e) { console.error(e) }
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/expenses/?page_size=500&ordering=-date')
    expenses.value = res.data?.results || res.data || []
  } catch { expenses.value = [] }
  loading.value = false
}
onMounted(load)
</script>
