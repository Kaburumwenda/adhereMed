<template>
  <div class="results-review">
    <div v-if="loading" class="text-center pa-4">
      <v-progress-circular indeterminate color="primary" />
    </div>
    <div v-else-if="!results.length" class="text-center pa-4 text-medium-emphasis">
      <v-icon size="40" color="grey-lighten-2">mdi-microscope</v-icon>
      <div class="text-body-2 mt-2">No {{ type }} results yet for this encounter</div>
    </div>
    <div v-else class="d-flex flex-column ga-2">
      <v-card v-for="(r, i) in results" :key="i" variant="outlined" class="pa-3 result-card" :class="{ 'abnormal': r.is_abnormal }">
        <div class="d-flex align-center justify-space-between mb-1">
          <span class="text-subtitle-2 font-weight-bold">{{ r.test_name || r.test_type || 'Result' }}</span>
          <v-chip :color="r.is_abnormal ? 'error' : 'success'" size="x-small" variant="tonal">
            {{ r.is_abnormal ? 'ABNORMAL' : 'NORMAL' }}
          </v-chip>
        </div>
        <div class="d-flex flex-wrap ga-4 text-body-2">
          <div>
            <span class="text-medium-emphasis">Value: </span>
            <span class="font-weight-bold" :class="{ 'text-error': r.is_abnormal }">{{ r.result_value || '—' }}</span>
            <span class="text-medium-emphasis ml-1">{{ r.unit || '' }}</span>
          </div>
          <div v-if="r.reference_range"><span class="text-medium-emphasis">Ref: </span>{{ r.reference_range }}</div>
        </div>
        <div v-if="r.comments" class="text-caption text-medium-emphasis mt-1">Comments: {{ r.comments }}</div>
        <div class="text-caption text-medium-emphasis mt-1">
          {{ formatDateTime(r.result_date || r.created_at) }} — By {{ r.performed_by_name || r.verified_by_name || '—' }}
        </div>
      </v-card>
    </div>
  </div>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'

const props = defineProps({
  type: { type: String, default: 'lab' }, // 'lab' or 'radiology'
  consultationId: { type: [String, Number], default: null },
})

const { $api } = useNuxtApp()
const loading = ref(false)
const results = ref([])

onMounted(() => loadResults())

async function loadResults() {
  if (!props.consultationId) return
  loading.value = true
  try {
    const endpoint = props.type === 'lab' ? '/lab/orders/' : '/radiology/orders/'
    const { data } = await $api.get(endpoint, { params: { consultation: props.consultationId, page_size: 100 } })
    const orders = data.results || data || []
    if (props.type === 'lab') {
      // Lab results are embedded in the order's `results` array (from LabOrderSerializer)
      const allResults = []
      for (const o of orders) {
        if (o.results?.length) {
          o.results.forEach(r => { allResults.push(r) })
        }
      }
      results.value = allResults
    } else {
      results.value = orders.filter(o => o.status === 'completed' || o.result || o.report)
    }
  } catch (e) { console.error('Failed to load results', e) }
  finally { loading.value = false }
}
</script>

<style scoped>
.result-card.abnormal { border-left: 3px solid rgb(var(--v-theme-error)); }
</style>
