<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="data?.tenant?.name || 'Tenant usage'"
      icon="mdi-domain"
      :subtitle="data?.tenant?.schema ? `Schema: ${data.tenant.schema} · Type: ${data.tenant.type}` : ''"
    >
      <template #actions>
        <v-btn variant="tonal" to="/superadmin/billing">Back</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

    <div v-if="data">
      <v-row dense>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Requests this month</div>
            <div class="text-h4 font-weight-bold">
              {{ Number(data.current_month.total_requests).toLocaleString() }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4" color="primary" variant="tonal">
            <div class="text-caption text-medium-emphasis">Cost so far</div>
            <div class="text-h4 font-weight-bold">
              {{ formatMoney(data.current_month.cost_so_far, data.rate.currency) }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Current rate</div>
            <div class="text-h6 font-weight-bold">
              {{ Number(data.rate.requests_per_unit).toLocaleString() }} req
              = {{ formatMoney(data.rate.unit_cost, data.rate.currency) }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" sm="6" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Status</div>
            <v-chip :color="data.tenant.is_active ? 'success' : 'default'" variant="tonal">
              {{ data.tenant.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </v-card>
        </v-col>
      </v-row>

      <v-card rounded="lg" class="mt-4 pa-4">
        <h3 class="text-h6 font-weight-bold mb-3">Daily requests (last 90 days)</h3>
        <div v-if="!data.daily_last_90_days.length" class="text-medium-emphasis">
          No requests recorded.
        </div>
        <div v-else class="usage-bars">
          <div
            v-for="d in data.daily_last_90_days"
            :key="d.date"
            class="usage-bar-wrap"
            :title="`${d.date}: ${d.request_count} requests`"
          >
            <div class="usage-bar" :style="{ height: barHeight(d.request_count) + '%' }" />
          </div>
        </div>
      </v-card>

      <v-card rounded="lg" class="mt-4">
        <v-card-title>Monthly bills</v-card-title>
        <v-data-table
          :headers="billHeaders"
          :items="data.bills"
          density="comfortable"
          :items-per-page="20"
        >
          <template #item.period="{ item }">
            {{ item.year }}-{{ String(item.month).padStart(2, '0') }}
          </template>
          <template #item.total_requests="{ item }">
            {{ Number(item.total_requests).toLocaleString() }}
          </template>
          <template #item.amount="{ item }">{{ formatMoney(item.amount, item.currency) }}</template>
          <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
        </v-data-table>
      </v-card>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="primary" />
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { formatMoney } from '~/utils/format'

const route = useRoute()
const { $api } = useNuxtApp()
const data = ref(null)
const loading = ref(false)
const error = ref(null)

const billHeaders = [
  { title: 'Period', key: 'period' },
  { title: 'Requests', key: 'total_requests' },
  { title: 'Amount', key: 'amount' },
  { title: 'Status', key: 'status' }
]

const maxRequests = computed(() => {
  const arr = data.value?.daily_last_90_days || []
  return Math.max(1, ...arr.map((d) => d.request_count))
})

function barHeight(v) {
  return Math.max(2, Math.round((v / maxRequests.value) * 100))
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data: res } = await $api.get(`/usage-billing/admin/usage/${route.params.id}/`)
    data.value = res
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load tenant usage.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.usage-bars {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  height: 200px;
  overflow-x: auto;
}
.usage-bar-wrap {
  flex: 1 0 8px;
  min-width: 8px;
  height: 100%;
  display: flex;
  align-items: flex-end;
}
.usage-bar {
  width: 100%;
  background: linear-gradient(180deg, rgb(var(--v-theme-primary)) 0%, rgba(var(--v-theme-primary), 0.4) 100%);
  border-radius: 2px 2px 0 0;
}
</style>
