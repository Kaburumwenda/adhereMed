<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold"><v-icon class="mr-1">mdi-bank</v-icon>Radiology Accounts</h1>
      <div class="d-flex" style="gap:8px">
        <v-select v-model="period" :items="periods" density="compact" variant="outlined" rounded="lg" hide-details style="max-width:180px" />
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </div>

    <v-row dense class="mb-4">
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-4 text-center" color="success" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ formatMoney(totalRevenue) }}</div>
          <div class="text-caption">Revenue</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-4 text-center" color="error" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ formatMoney(totalExpenses) }}</div>
          <div class="text-caption">Expenses</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-4 text-center" color="warning" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ formatMoney(outstanding) }}</div>
          <div class="text-caption">Outstanding</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-4 text-center" color="primary" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ formatMoney(totalRevenue - totalExpenses) }}</div>
          <div class="text-caption">Net Income</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Recent payments -->
    <v-card rounded="lg" class="pa-4" border>
      <h3 class="text-subtitle-1 font-weight-bold mb-3">Recent Payments</h3>
      <v-table v-if="payments.length" density="comfortable" hover class="bg-transparent">
        <thead><tr><th>Date</th><th>Invoice</th><th>Method</th><th>Reference</th><th>By</th><th class="text-end">Amount</th></tr></thead>
        <tbody>
          <tr v-for="p in payments.slice(0, 20)" :key="p.id">
            <td>{{ formatDate(p.payment_date) }}</td>
            <td>{{ p.invoice }}</td>
            <td>{{ p.method_display }}</td>
            <td>{{ p.reference || '—' }}</td>
            <td>{{ p.received_by_name }}</td>
            <td class="text-end font-weight-medium text-success">{{ formatMoney(p.amount) }}</td>
          </tr>
        </tbody>
      </v-table>
      <div v-else class="text-body-2 text-medium-emphasis">No payments recorded</div>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const loading = ref(false)
const invoices = ref([])
const payments = ref([])
const expenses = ref([])
const period = ref('this_month')
const periods = [
  { title: 'This Month', value: 'this_month' }, { title: 'Last Month', value: 'last_month' },
  { title: 'This Year', value: 'this_year' }, { title: 'All Time', value: 'all' },
]

const totalRevenue = computed(() => payments.value.reduce((s, p) => s + Number(p.amount || 0), 0))
const totalExpenses = computed(() => expenses.value.reduce((s, e) => s + Number(e.amount || 0), 0))
const outstanding = computed(() => invoices.value.reduce((s, i) => s + Math.max(0, Number(i.total || 0) - Number(i.amount_paid || 0)), 0))

function formatDate(d) { return d ? new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }) : '—' }

async function load() {
  loading.value = true
  try {
    const [iRes, pRes, eRes] = await Promise.allSettled([
      $api.get('/radiology/invoices/?page_size=500'),
      $api.get('/radiology/payments/?page_size=200&ordering=-payment_date'),
      $api.get('/expenses/?page_size=500'),
    ])
    invoices.value = iRes.status === 'fulfilled' ? iRes.value.data?.results || iRes.value.data || [] : []
    payments.value = pRes.status === 'fulfilled' ? pRes.value.data?.results || pRes.value.data || [] : []
    expenses.value = eRes.status === 'fulfilled' ? eRes.value.data?.results || eRes.value.data || [] : []
  } catch { }
  loading.value = false
}
onMounted(load)
</script>
