<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="warning" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-star-check-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Supplier Performance</h1>
          <div class="text-body-2 text-medium-emphasis">Evaluate and track supplier quality metrics</div>
        </div>
      </div>
      <v-btn color="warning" prepend-icon="mdi-plus" rounded="lg" class="text-none" @click="dialog = true">New Evaluation</v-btn>
    </div>

    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />
      <div v-if="!loading && !items.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-star-off</v-icon>
        <div class="text-h6 mt-3">No evaluations yet</div>
      </div>
      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr><th class="row-num">#</th><th>Supplier</th><th class="text-center">On-time</th><th class="text-center">Quality</th><th class="text-center">Responsiveness</th><th class="text-center">Pricing</th><th class="text-center">Payment</th><th class="text-center">Overall</th><th>Date</th><th class="text-right">Actions</th></tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in items" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
              <td class="font-weight-medium">{{ row.supplier_name }}</td>
              <td class="text-center"><v-rating :model-value="row.on_time_delivery_score" length="5" density="compact" size="small" readonly color="warning" /></td>
              <td class="text-center"><v-rating :model-value="row.quality_score" length="5" density="compact" size="small" readonly color="warning" /></td>
              <td class="text-center"><v-rating :model-value="row.responsiveness_score" length="5" density="compact" size="small" readonly color="warning" /></td>
              <td class="text-center"><v-rating :model-value="row.pricing_competitiveness" length="5" density="compact" size="small" readonly color="warning" /></td>
              <td class="text-center"><v-rating :model-value="row.payment_flexibility" length="5" density="compact" size="small" readonly color="warning" /></td>
              <td class="text-center">
                <v-chip size="small" variant="tonal" :color="overallColor(row.overall_rating)">{{ Number(row.overall_rating).toFixed(1) }}</v-chip>
              </td>
              <td class="text-medium-emphasis">{{ formatDate(row.evaluation_date) }}</td>
              <td class="text-right">
                <v-menu offset="4">
                  <template #activator="{ props }"><v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" /></template>
                  <v-list density="compact" min-width="160">
                    <v-list-item v-if="canDelete" prepend-icon="mdi-delete" title="Delete" @click="deleteEval(row)" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>

    <!-- New evaluation dialog -->
    <v-dialog v-model="dialog" max-width="600">
      <v-card rounded="lg">
        <v-card-title>Supplier Evaluation</v-card-title>
        <v-card-text>
          <v-select v-model="form.supplier" :items="supplierOptions" item-title="label" item-value="value" label="Supplier *" density="compact" variant="outlined" rounded="lg" class="mb-3" />
          <div v-for="c in scoreCategories" :key="c.key" class="d-flex align-center justify-space-between mb-2">
            <span class="text-body-2">{{ c.label }}</span>
            <v-rating v-model="form[c.key]" length="5" density="compact" color="warning" hover />
          </div>
          <v-textarea v-model="form.notes" label="Notes" variant="outlined" density="compact" rounded="lg" rows="2" class="mt-3" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" rounded="lg" class="text-none" @click="submit">Save Evaluation</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
import { ADMIN_ROLES } from '~/utils/permissions'

const { $api } = useNuxtApp()
const auth = useAuthStore()
const canDelete = computed(() => ADMIN_ROLES.has(auth.role))

const evalRes = useResource('/purchase-orders/evaluations/')
const loading = computed(() => evalRes.loading.value)
const items = computed(() => evalRes.items.value || [])

const dialog = ref(false)
const supplierOptions = ref([])
const form = ref({ supplier: null, on_time_delivery_score: 3, quality_score: 3, responsiveness_score: 3, pricing_competitiveness: 3, payment_flexibility: 3, notes: '' })

const scoreCategories = [
  { key: 'on_time_delivery_score', label: 'On-time Delivery' },
  { key: 'quality_score', label: 'Quality' },
  { key: 'responsiveness_score', label: 'Responsiveness' },
  { key: 'pricing_competitiveness', label: 'Pricing Competitiveness' },
  { key: 'payment_flexibility', label: 'Payment Flexibility' },
]

function overallColor(rating) {
  const r = Number(rating)
  if (r >= 4.5) return 'success'
  if (r >= 3.5) return 'info'
  if (r >= 2.5) return 'warning'
  return 'error'
}

async function submit() {
  try {
    await $api.post('/purchase-orders/evaluations/', form.value)
    dialog.value = false
    form.value = { supplier: null, on_time_delivery_score: 3, quality_score: 3, responsiveness_score: 3, pricing_competitiveness: 3, payment_flexibility: 3, notes: '' }
    evalRes.list({ page_size: 500 })
  } catch (e) {
    console.error(e)
    alert('Failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function deleteEval(row) {
  if (!confirm('Delete this evaluation?')) return
  try {
    await $api.delete(`/purchase-orders/evaluations/${row.id}/`)
    evalRes.list({ page_size: 500 })
  } catch (e) { console.error(e) }
}

async function loadSuppliers() {
  try {
    const { data } = await $api.get('/suppliers/', { params: { page_size: 500 } })
    const arr = data?.results || data || []
    supplierOptions.value = arr.map(s => ({ label: s.name, value: s.id }))
  } catch (e) { console.error(e) }
}

onMounted(() => { evalRes.list({ page_size: 500 }); loadSuppliers() })
</script>
