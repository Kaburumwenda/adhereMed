<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="purple" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-file-document-multiple</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Requests for Quotation</h1>
          <div class="text-body-2 text-medium-emphasis">Send RFQs to suppliers and compare quotes</div>
        </div>
      </div>
      <v-btn color="purple" prepend-icon="mdi-plus" rounded="lg" class="text-none" @click="navigateTo('/purchase-orders/rfqs/new')">New RFQ</v-btn>
    </div>

    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />

      <div class="pa-3 d-flex flex-wrap align-center" style="gap:10px; border-bottom:1px solid rgba(0,0,0,0.06)">
        <v-text-field v-model="search" placeholder="Search RFQs…" prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg" hide-details clearable style="min-width:240px; max-width:360px; flex:1" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value" density="compact" variant="outlined" rounded="lg" hide-details prepend-inner-icon="mdi-filter-variant" style="min-width:160px" />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ items.length }} RFQs</span>
      </div>

      <div v-if="!loading && !items.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-file-document-outline</v-icon>
        <div class="text-h6 mt-3">No RFQs yet</div>
        <v-btn color="purple" variant="flat" rounded="lg" class="text-none mt-3" prepend-icon="mdi-plus" @click="navigateTo('/purchase-orders/rfqs/new')">Create RFQ</v-btn>
      </div>

      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr><th class="row-num">#</th><th>RFQ #</th><th>Title</th><th>Status</th><th class="text-right">Quotes</th><th>Deadline</th><th>Created</th><th class="text-right">Actions</th></tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in filteredItems" :key="row.id" class="inv-row-click" @click="navigateTo(`/purchase-orders/rfqs/${row.id}`)">
              <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
              <td class="font-weight-medium">{{ row.rfq_number }}</td>
              <td>{{ row.title }}</td>
              <td><v-chip size="x-small" variant="tonal" :color="rfqStatusColor(row.status)">{{ rfqStatusLabel(row.status) }}</v-chip></td>
              <td class="text-right">
                <v-chip size="x-small" variant="tonal" color="info">{{ row.quote_count }}</v-chip>
              </td>
              <td class="text-medium-emphasis">{{ row.response_deadline ? formatDate(row.response_deadline) : '—' }}</td>
              <td class="text-medium-emphasis">{{ formatDate(row.created_at) }}</td>
              <td class="text-right">
                <v-menu offset="4">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" @click.stop />
                  </template>
                  <v-list density="compact" min-width="180">
                    <v-list-item prepend-icon="mdi-eye-outline" title="View Details" @click="navigateTo(`/purchase-orders/rfqs/${row.id}`)" />
                    <v-list-item v-if="row.status === 'draft'" prepend-icon="mdi-send" title="Send to Suppliers" @click="sendToSuppliers(row)" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const { $api } = useNuxtApp()
const rfqRes = useResource('/purchase-orders/rfqs/')
const loading = computed(() => rfqRes.loading.value)
const items = computed(() => rfqRes.items.value || [])
const search = ref('')
const statusFilter = ref('all')

const statusOptions = [
  { label: 'All status', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'Sent', value: 'sent' },
  { label: 'Quoted', value: 'quoted' },
  { label: 'Awarded', value: 'awarded' },
  { label: 'Closed', value: 'closed' },
  { label: 'Cancelled', value: 'cancelled' },
]

function rfqStatusLabel(s) { return statusOptions.find(o => o.value === s)?.label || s }
function rfqStatusColor(s) {
  return { draft: 'grey', sent: 'info', quoted: 'warning', awarded: 'success', closed: 'default', cancelled: 'error' }[s] || 'grey'
}

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = items.value.slice()
  if (statusFilter.value !== 'all') arr = arr.filter(r => r.status === statusFilter.value)
  if (!q) return arr
  return arr.filter(row => Object.values(row).some(v => v != null && typeof v !== 'object' && String(v).toLowerCase().includes(q)))
})

async function sendToSuppliers(row) {
  try {
    await $api.post(`/purchase-orders/rfqs/${row.id}/send_to_suppliers/`)
    rfqRes.list({ page_size: 500 })
  } catch (e) { console.error(e) }
}

onMounted(() => rfqRes.list({ page_size: 500 }))
</script>
