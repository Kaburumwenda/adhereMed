<template>
  <ResourceDetailPage
    :resource="r"
    title="Patient Detail"
    icon="mdi-account"
    back-path="/radiology/patients"
    :edit-path="`/radiology/patients/${id}/edit`"
    :load-id="id"
  >
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center mb-6">
          <v-avatar size="72" color="deep-purple" variant="tonal">
            <v-icon size="48">mdi-account</v-icon>
          </v-avatar>
          <div class="ml-4">
            <div class="text-h5 font-weight-bold">{{ patientName(item) }}</div>
            <div class="text-body-2 text-medium-emphasis">Patient #{{ item.patient_number || '—' }}</div>
          </div>
          <v-spacer />
          <v-btn color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-radiology"
                 :to="`/radiology/orders?patient=${id}`">
            View Orders
          </v-btn>
        </div>
        <v-divider class="mb-4" />
        <InfoGrid :item="item" :fields="fields" />

        <!-- Imaging history -->
        <div class="mt-6">
          <div class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon size="20" class="mr-1">mdi-history</v-icon>
            Recent Imaging Orders
          </div>
          <v-data-table
            v-if="orders.length"
            :headers="orderHeaders"
            :items="orders"
            :items-per-page="5"
            density="compact"
            hover
            @click:row="(_, { item: o }) => $router.push(`/radiology/orders/${o.id}`)"
            class="orders-table"
          >
            <template #item.status="{ value }">
              <v-chip size="x-small" variant="tonal"
                      :color="statusColor(value)">
                {{ value }}
              </v-chip>
            </template>
            <template #item.priority="{ value }">
              <v-chip size="x-small" variant="flat"
                      :color="value === 'stat' ? 'red' : value === 'urgent' ? 'orange' : 'grey'">
                {{ value }}
              </v-chip>
            </template>
            <template #item.created_at="{ value }">
              {{ formatDate(value) }}
            </template>
          </v-data-table>
          <v-card v-else flat rounded="lg" class="pa-4 text-center text-medium-emphasis" style="border: 1px dashed rgba(var(--v-theme-on-surface), 0.12);">
            <v-icon size="32" class="mb-2">mdi-radiology</v-icon>
            <div class="text-body-2">No imaging orders yet</div>
          </v-card>
        </div>
      </v-card>
    </template>
  </ResourceDetailPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/patients/')
const orders = ref([])

const fields = [
  { key: 'user_email', label: 'Email' },
  { key: 'national_id', label: 'National ID' },
  { key: 'date_of_birth', label: 'Date of Birth', format: formatDate },
  { key: 'gender', label: 'Gender' },
  { key: 'blood_type', label: 'Blood Type' },
  { key: 'phone', label: 'Phone' },
  { key: 'address', label: 'Address', md: 8 },
  { key: 'allergies', label: 'Allergies', format: v => (v || []).join(', ') || '—' },
  { key: 'chronic_conditions', label: 'Chronic Conditions', format: v => (v || []).join(', ') || '—' },
  { key: 'emergency_contact_name', label: 'Emergency Contact' },
  { key: 'emergency_contact_phone', label: 'Emergency Phone' },
  { key: 'insurance_provider', label: 'Insurance Provider' },
  { key: 'insurance_id', label: 'Insurance ID' },
]

const orderHeaders = [
  { title: 'Accession #', key: 'accession_number', width: 140 },
  { title: 'Status', key: 'status', width: 120 },
  { title: 'Priority', key: 'priority', width: 100 },
  { title: 'Imaging Type', key: 'imaging_type_display', width: 130 },
  { title: 'Date', key: 'created_at', width: 140 },
]

function statusColor(s) {
  const map = { pending: 'grey', scheduled: 'info', checked_in: 'indigo', in_progress: 'orange', completed: 'success', cancelled: 'red' }
  return map[s] || 'grey'
}

function patientName(item) {
  if (item.user_name) return item.user_name
  const fn = item.user?.first_name || ''
  const ln = item.user?.last_name || ''
  return `${fn} ${ln}`.trim() || item.user_email || '—'
}

onMounted(async () => {
  try {
    const { data } = await $api.get('/api/radiology/orders/', { params: { patient: id.value } })
    orders.value = (data.results || data || []).slice(0, 10)
  } catch {}
})
</script>

<style scoped>
.orders-table :deep(tbody tr) { cursor: pointer; }
</style>
