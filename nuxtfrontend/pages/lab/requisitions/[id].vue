<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1100px">
    <PageHeader title="Requisition Details" :subtitle="order ? `${order.patient_name} · ${formatDateTime(order.created_at)}` : 'Loading…'"
                icon="mdi-clipboard-text-clock">
      <template #actions>
        <v-btn variant="text" @click="$router.push('/lab/requisitions')">Back</v-btn>
        <v-btn color="primary" prepend-icon="mdi-flask"
               @click="$router.push(`/lab/results?order=${$route.params.id}`)">Enter Results</v-btn>
      </template>
    </PageHeader>

    <v-row v-if="order">
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-4 mb-3">
          <div class="text-subtitle-1 font-weight-medium mb-2">Tests</div>
          <v-list density="compact">
            <v-list-item v-for="t in order.test_names" :key="t" :title="t" prepend-icon="mdi-flask-outline" />
          </v-list>
          <v-divider class="my-2" />
          <div class="text-body-2 text-medium-emphasis">{{ order.clinical_notes || 'No clinical notes.' }}</div>
        </v-card>

        <v-card rounded="lg" class="pa-4">
          <div class="text-subtitle-1 font-weight-medium mb-2">Results</div>
          <v-table v-if="order.results?.length" density="compact">
            <thead>
              <tr><th>Test</th><th>Value</th><th>Unit</th><th>Status</th><th>Performed By</th></tr>
            </thead>
            <tbody>
              <tr v-for="r in order.results" :key="r.id">
                <td>{{ r.test_name }}</td>
                <td>{{ r.result_value }}</td>
                <td>{{ r.unit }}</td>
                <td>
                  <v-chip size="x-small" :color="r.is_abnormal ? 'error' : 'success'" variant="flat">
                    {{ r.is_abnormal ? 'Abnormal' : 'Normal' }}
                  </v-chip>
                </td>
                <td>{{ r.performed_by_name || '—' }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-medium-emphasis text-body-2">No results recorded yet.</div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4">
          <div class="text-subtitle-2 mb-2">Order Info</div>
          <div class="d-flex justify-space-between mb-1"><span class="text-medium-emphasis">Status</span><StatusChip :status="order.status" /></div>
          <div class="d-flex justify-space-between mb-1"><span class="text-medium-emphasis">Priority</span><StatusChip :status="order.priority" /></div>
          <div class="d-flex justify-space-between mb-1"><span class="text-medium-emphasis">Home collection</span><span>{{ order.is_home_collection ? 'Yes' : 'No' }}</span></div>
          <div class="d-flex justify-space-between mb-1"><span class="text-medium-emphasis">Ordered by</span><span>{{ order.ordered_by_name || '—' }}</span></div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
const { $api } = useNuxtApp()
const route = useRoute()
const order = ref(null)
onMounted(async () => {
  const { data } = await $api.get(`/lab/orders/${route.params.id}/`)
  order.value = data
})
</script>
