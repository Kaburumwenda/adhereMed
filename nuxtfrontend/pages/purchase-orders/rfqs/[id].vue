<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-progress-linear v-if="loading" color="primary" indeterminate class="mb-3" />

    <div v-if="!loading && !rfq" class="pa-10 text-center text-medium-emphasis">
      <v-icon size="64" color="grey">mdi-file-question</v-icon>
      <div class="text-h6 mt-3">RFQ not found</div>
      <v-btn color="purple" variant="flat" rounded="lg" class="text-none mt-3" @click="navigateTo('/purchase-orders/rfqs')">Back to RFQs</v-btn>
    </div>

    <template v-if="!loading && rfq">
      <div class="d-flex flex-wrap align-center justify-space-between mb-4">
        <div class="d-flex align-center" style="gap:14px">
          <v-avatar color="purple" variant="tonal" rounded="lg" size="52">
            <v-icon size="28">mdi-file-document-multiple</v-icon>
          </v-avatar>
          <div>
            <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ rfq.title }}</h1>
            <div class="text-body-2 text-medium-emphasis">{{ rfq.rfq_number }} • Created {{ formatStamp(rfq.created_at) }}</div>
          </div>
        </div>
        <div class="d-flex align-center flex-wrap" style="gap:8px">
          <v-btn variant="tonal" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" @click="navigateTo('/purchase-orders/rfqs')">Back</v-btn>
          <v-btn v-if="rfq.status === 'draft'" color="info" variant="tonal" prepend-icon="mdi-send" rounded="lg" class="text-none" @click="sendToSuppliers">Send to Suppliers</v-btn>
          <v-btn v-if="rfq.status === 'awarded'" color="success" variant="flat" prepend-icon="mdi-cart-plus" rounded="lg" class="text-none" @click="createPO">Create Purchase Order</v-btn>
        </div>
      </div>

      <div class="d-flex flex-wrap mb-3" style="gap:8px">
        <v-chip :color="rfqStatusColor(rfq.status)" variant="tonal">{{ rfqStatusLabel(rfq.status) }}</v-chip>
        <v-chip v-if="rfq.branch_name" color="info" variant="tonal" prepend-icon="mdi-store">{{ rfq.branch_name }}</v-chip>
        <v-chip v-if="rfq.expected_delivery" color="warning" variant="tonal" prepend-icon="mdi-truck-clock">Expected: {{ formatDate(rfq.expected_delivery) }}</v-chip>
        <v-chip v-if="rfq.response_deadline" color="error" variant="tonal" prepend-icon="mdi-calendar-clock">Deadline: {{ formatDate(rfq.response_deadline) }}</v-chip>
      </div>

      <v-row>
        <v-col cols="12" lg="6">
          <v-card rounded="lg" elevation="0" class="pa-4 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-2"><v-icon start>mdi-text</v-icon>Description</div>
            <div class="text-body-2" style="white-space:pre-wrap; line-height:1.7">{{ rfq.description || 'No description provided.' }}</div>
            <v-divider class="my-3" />
            <div class="text-subtitle-2 mb-2">Requested Items</div>
            <div v-for="(item, i) in (rfq.items || [])" :key="i" class="d-flex align-center py-1">
              <v-icon size="18" class="mr-2">mdi-package-variant-closed</v-icon>
              <span class="font-weight-medium">{{ item.name }}</span>
              <span class="text-medium-emphasis ml-2">×{{ item.qty }} {{ item.unit || '' }}</span>
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" lg="6">
          <v-card rounded="lg" elevation="0" class="pa-4 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="d-flex align-center mb-3">
              <span class="text-subtitle-1 font-weight-bold"><v-icon start>mdi-clipboard-list</v-icon>Supplier Quotes</span>
              <v-spacer />
              <v-btn size="small" color="purple" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="addQuoteDialog = true">Add Quote</v-btn>
            </div>

            <div v-for="quote in (rfq.quotes || [])" :key="quote.id" class="mb-3 pa-3 rounded-lg" style="border:1px solid rgba(0,0,0,0.06)">
              <div class="d-flex align-center justify-space-between mb-1">
                <div class="d-flex align-center" style="gap:8px">
                  <v-avatar color="info" variant="tonal" size="32"><v-icon size="16">mdi-truck</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ quote.supplier_name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ quote.delivery_days }}d delivery • Quote: {{ formatStamp(quote.submitted_at) }}</div>
                  </div>
                </div>
                <div class="d-flex align-center" style="gap:8px">
                  <div class="text-h6 font-weight-bold">{{ formatMoney(quote.total_cost) }}</div>
                  <v-chip :color="quoteStatusColor(quote.status)" size="x-small" variant="tonal">{{ quote.status }}</v-chip>
                </div>
              </div>
              <div v-if="quote.notes" class="text-caption text-medium-emphasis mt-1">{{ quote.notes }}</div>
              <div class="d-flex justify-end mt-1" style="gap:4px">
                <v-btn v-if="rfq.status === 'sent' || rfq.status === 'quoted'" size="x-small" color="success" variant="tonal" rounded="lg" class="text-none" @click="awardQuote(quote)">Award</v-btn>
              </div>
            </div>

            <div v-if="!(rfq.quotes || []).length" class="text-center text-medium-emphasis pa-3">No quotes received yet.</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Add Quote dialog -->
      <v-dialog v-model="addQuoteDialog" max-width="500">
        <v-card rounded="lg">
          <v-card-title>Add Supplier Quote</v-card-title>
          <v-card-text>
            <v-select v-model="quoteForm.supplier" :items="supplierOptions" item-title="label" item-value="value" label="Supplier *" density="compact" variant="outlined" rounded="lg" class="mb-3" />
            <v-text-field v-model.number="quoteForm.total_cost" label="Total Cost *" type="number" density="compact" variant="outlined" rounded="lg" class="mb-3" />
            <v-text-field v-model.number="quoteForm.delivery_days" label="Delivery Days" type="number" density="compact" variant="outlined" rounded="lg" class="mb-3" />
            <v-textarea v-model="quoteForm.notes" label="Notes" variant="outlined" density="compact" rounded="lg" rows="2" hide-details />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn variant="text" class="text-none" @click="addQuoteDialog = false">Cancel</v-btn>
            <v-btn color="purple" variant="flat" rounded="lg" class="text-none" @click="submitQuote">Add Quote</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatMoney, formatDate, formatStamp } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const rfqId = route.params.id

const rfqRes = useResource('/purchase-orders/rfqs/')
const loading = computed(() => rfqRes.loading.value)
const rfq = computed(() => rfqRes.item.value)

const addQuoteDialog = ref(false)
const quoteForm = ref({ supplier: null, total_cost: 0, delivery_days: 7, notes: '' })
const supplierOptions = ref([])

function rfqStatusLabel(s) { return { draft: 'Draft', sent: 'Sent', quoted: 'Quoted', awarded: 'Awarded', closed: 'Closed', cancelled: 'Cancelled' }[s] || s }
function rfqStatusColor(s) { return { draft: 'grey', sent: 'info', quoted: 'warning', awarded: 'success', closed: 'default', cancelled: 'error' }[s] || 'grey' }
function quoteStatusColor(s) { return { pending: 'warning', awarded: 'success', rejected: 'error' }[s] || 'default' }

async function loadRFQ() { await rfqRes.get(rfqId) }

async function loadSuppliers() {
  try {
    const { data } = await $api.get('/suppliers/', { params: { page_size: 500 } })
    const arr = data?.results || data || []
    supplierOptions.value = arr.map(s => ({ label: s.name, value: s.id }))
  } catch (e) { console.error(e) }
}

async function sendToSuppliers() {
  try {
    await $api.post(`/purchase-orders/rfqs/${rfqId}/send_to_suppliers/`)
    loadRFQ()
  } catch (e) { console.error(e) }
}

async function awardQuote(quote) {
  try {
    await $api.post(`/purchase-orders/rfqs/${rfqId}/award/`, { quote_id: quote.id })
    loadRFQ()
  } catch (e) { console.error(e) }
}

async function createPO() {
  try {
    const { data } = await $api.post(`/purchase-orders/rfqs/${rfqId}/create_po/`)
    navigateTo(`/purchase-orders/${data.id}`)
  } catch (e) {
    console.error(e)
    alert('Failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function submitQuote() {
  try {
    await $api.post('/purchase-orders/quotes/', { rfq: rfqId, ...quoteForm.value })
    addQuoteDialog.value = false
    quoteForm.value = { supplier: null, total_cost: 0, delivery_days: 7, notes: '' }
    loadRFQ()
  } catch (e) {
    console.error(e)
    alert('Failed: ' + (e?.response?.data?.detail || e.message))
  }
}

onMounted(() => { loadRFQ(); loadSuppliers() })
</script>
