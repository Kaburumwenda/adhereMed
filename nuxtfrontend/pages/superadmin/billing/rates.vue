<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Billing rates"
      icon="mdi-tune"
      subtitle="Set how API requests are priced. Newest rate becomes the active one."
    >
      <template #actions>
        <v-btn variant="tonal" to="/superadmin/billing">Back to billing</v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="openNew">New rate</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

    <v-card v-if="active" rounded="lg" class="pa-4 mb-4" color="primary" variant="tonal">
      <div class="text-caption text-medium-emphasis">Currently active rate</div>
      <div class="text-h5 font-weight-bold mt-1">
        {{ Number(active.requests_per_unit).toLocaleString() }} requests
        = {{ formatMoney(active.unit_cost, active.currency) }}
      </div>
      <div class="text-caption mt-1">
        Effective {{ formatDate(active.effective_from) }}
        <span v-if="active.notes"> · {{ active.notes }}</span>
      </div>
    </v-card>

    <v-card rounded="lg">
      <v-data-table
        :headers="headers"
        :items="rates"
        :loading="loading"
        density="comfortable"
      >
        <template #item.requests_per_unit="{ item }">
          {{ Number(item.requests_per_unit).toLocaleString() }}
        </template>
        <template #item.unit_cost="{ item }">
          {{ formatMoney(item.unit_cost, item.currency) }}
        </template>
        <template #item.is_active="{ item }">
          <v-chip :color="item.is_active ? 'success' : 'default'" size="small" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.effective_from="{ item }">{{ formatDate(item.effective_from) }}</template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="dialog" max-width="520">
      <v-card>
        <v-card-title>New billing rate</v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-3">
            Default: <strong>1000 requests = 1 KSH</strong>. Saving will deactivate
            previous rates and immediately apply this one.
          </p>
          <v-row dense>
            <v-col cols="6">
              <v-text-field
                v-model.number="form.requests_per_unit"
                type="number"
                min="1"
                label="Requests per unit"
              />
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="form.unit_cost"
                type="number"
                step="0.0001"
                min="0"
                label="Unit cost"
              />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="form.currency" label="Currency" />
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model="form.effective_from"
                type="datetime-local"
                label="Effective from"
              />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" rows="2" label="Notes (optional)" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatDate, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const rates = ref([])
const loading = ref(false)
const saving = ref(false)
const error = ref(null)
const dialog = ref(false)

const headers = [
  { title: 'Requests per unit', key: 'requests_per_unit' },
  { title: 'Unit cost', key: 'unit_cost' },
  { title: 'Currency', key: 'currency' },
  { title: 'Effective from', key: 'effective_from' },
  { title: 'Status', key: 'is_active' },
  { title: 'Notes', key: 'notes' }
]

const active = computed(() => rates.value.find((r) => r.is_active))

const form = ref({
  requests_per_unit: 1000,
  unit_cost: 1,
  currency: 'KSH',
  effective_from: new Date().toISOString().slice(0, 16),
  notes: ''
})

function openNew() {
  form.value = {
    requests_per_unit: 1000,
    unit_cost: 1,
    currency: 'KSH',
    effective_from: new Date().toISOString().slice(0, 16),
    notes: ''
  }
  dialog.value = true
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data } = await $api.get('/usage-billing/admin/rates/')
    rates.value = Array.isArray(data) ? data : data.results || []
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load rates.'
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  try {
    await $api.post('/usage-billing/admin/rates/', {
      ...form.value,
      effective_from: new Date(form.value.effective_from).toISOString()
    })
    dialog.value = false
    await load()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to save.'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>
