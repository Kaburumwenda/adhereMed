<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Billing Coupons & Offers"
      icon="mdi-ticket-percent"
      subtitle="Discount codes tenants can redeem against overdue / outstanding API bills"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-arrow-left" to="/superadmin/billing">Back</v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreate">New coupon</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4" closable @click:close="error = null">{{ error }}</v-alert>
    <v-alert v-if="toast" type="success" variant="tonal" class="mb-4" closable @click:close="toast = null">{{ toast }}</v-alert>

    <v-card rounded="lg">
      <v-card-title class="d-flex align-center">
        <v-icon class="mr-2">mdi-format-list-bulleted</v-icon>
        All coupons
        <v-spacer />
        <v-text-field
          v-model="search"
          density="compact"
          variant="outlined"
          hide-details
          placeholder="Search code / tenant"
          prepend-inner-icon="mdi-magnify"
          style="max-width: 260px"
        />
      </v-card-title>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" density="comfortable" :items-per-page="15">
        <template #item.code="{ item }">
          <span class="font-weight-bold">{{ item.code }}</span>
          <div v-if="item.description" class="text-caption text-medium-emphasis">{{ item.description }}</div>
        </template>
        <template #item.discount_value="{ item }">
          <span v-if="item.discount_type === 'percent'">{{ item.discount_value }}%</span>
          <span v-else>{{ formatMoney(item.discount_value, item.currency) }}</span>
        </template>
        <template #item.tenant_name="{ item }">
          <span v-if="item.tenant_name">{{ item.tenant_name }}</span>
          <span v-else class="text-medium-emphasis">Any tenant</span>
        </template>
        <template #item.usage="{ item }">
          {{ item.times_used }} / {{ item.max_uses }}
        </template>
        <template #item.valid_until="{ item }">
          <span v-if="item.valid_until">{{ formatDateTime(item.valid_until) }}</span>
          <span v-else class="text-medium-emphasis">No expiry</span>
        </template>
        <template #item.is_active="{ item }">
          <v-chip :color="item.is_active ? 'success' : 'default'" size="small" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" size="small" variant="text" @click="openEdit(item)" />
          <v-btn
            :icon="item.is_active ? 'mdi-pause' : 'mdi-play'"
            size="small" variant="text"
            @click="toggleActive(item)"
          />
          <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="remove(item)" />
        </template>
        <template #no-data>
          <div class="text-medium-emphasis py-6 text-center">No coupons yet.</div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create / edit dialog -->
    <v-dialog v-model="dialog" max-width="520">
      <v-card>
        <v-card-title>{{ editing ? 'Edit coupon' : 'New coupon' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.code" label="Coupon code" variant="outlined" density="comfortable"
                        class="mb-2" :disabled="!!editing" placeholder="e.g. WELCOME20" />
          <v-textarea v-model="form.description" label="Description" variant="outlined" density="comfortable"
                      rows="2" class="mb-2" />
          <v-row dense>
            <v-col cols="6">
              <v-select v-model="form.discount_type" :items="DISCOUNT_TYPES" label="Discount type"
                        variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="form.discount_value" type="number" min="0"
                            :label="form.discount_type === 'percent' ? 'Percentage' : 'Amount'"
                            variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model.number="form.max_uses" type="number" min="1" label="Max uses"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="form.min_bill_amount" type="number" min="0" label="Min. bill amount"
                            variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <v-select v-model="form.tenant" :items="tenantOptions" item-title="name" item-value="id"
                    label="Restrict to tenant (optional)" variant="outlined" density="comfortable"
                    clearable class="mb-2" />
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model="form.valid_from" type="datetime-local" label="Valid from"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="form.valid_until" type="datetime-local" label="Valid until (optional)"
                            variant="outlined" density="comfortable" clearable />
            </v-col>
          </v-row>
          <v-switch v-model="form.is_active" color="primary" label="Active" density="compact" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">{{ editing ? 'Save changes' : 'Create coupon' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatMoney, formatDateTime } from '~/utils/format'

definePageMeta({ middleware: [] })

const { $api } = useNuxtApp()
const coupons = ref([])
const tenants = ref([])
const loading = ref(false)
const error = ref(null)
const toast = ref(null)
const search = ref('')

const dialog = ref(false)
const editing = ref(null)
const saving = ref(false)

const DISCOUNT_TYPES = [
  { value: 'percent', title: 'Percentage' },
  { value: 'fixed', title: 'Fixed amount' },
]

const emptyForm = () => ({
  code: '', description: '', discount_type: 'percent', discount_value: 10,
  max_uses: 1, min_bill_amount: 0, tenant: null,
  valid_from: nowLocal(), valid_until: '', is_active: true,
})
const form = ref(emptyForm())

function nowLocal() {
  const d = new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset())
  return d.toISOString().slice(0, 16)
}

const headers = [
  { title: 'Code', key: 'code' },
  { title: 'Discount', key: 'discount_value' },
  { title: 'Tenant', key: 'tenant_name' },
  { title: 'Usage', key: 'usage' },
  { title: 'Valid until', key: 'valid_until' },
  { title: 'Status', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const tenantOptions = computed(() => tenants.value.map(t => ({ id: t.tenant_id, name: t.tenant_name })))

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return coupons.value
  return coupons.value.filter(c =>
    (c.code || '').toLowerCase().includes(q) || (c.tenant_name || '').toLowerCase().includes(q))
})

async function loadCoupons() {
  loading.value = true
  try {
    const { data } = await $api.get('/usage-billing/admin/coupons/')
    coupons.value = Array.isArray(data) ? data : data.results || []
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load coupons.'
  } finally {
    loading.value = false
  }
}

async function loadTenants() {
  try {
    const { data } = await $api.get('/usage-billing/admin/usage/')
    tenants.value = data?.tenants || []
  } catch { tenants.value = [] }
}

function openCreate() {
  editing.value = null
  form.value = emptyForm()
  dialog.value = true
}

function openEdit(item) {
  editing.value = item
  form.value = {
    code: item.code,
    description: item.description || '',
    discount_type: item.discount_type,
    discount_value: Number(item.discount_value),
    max_uses: item.max_uses,
    min_bill_amount: Number(item.min_bill_amount || 0),
    tenant: item.tenant || null,
    valid_from: item.valid_from ? item.valid_from.slice(0, 16) : nowLocal(),
    valid_until: item.valid_until ? item.valid_until.slice(0, 16) : '',
    is_active: item.is_active,
  }
  dialog.value = true
}

async function save() {
  saving.value = true
  error.value = null
  try {
    const payload = {
      ...form.value,
      valid_from: form.value.valid_from ? new Date(form.value.valid_from).toISOString() : undefined,
      valid_until: form.value.valid_until ? new Date(form.value.valid_until).toISOString() : null,
    }
    if (editing.value) {
      await $api.patch(`/usage-billing/admin/coupons/${editing.value.id}/`, payload)
      toast.value = 'Coupon updated.'
    } else {
      await $api.post('/usage-billing/admin/coupons/', payload)
      toast.value = 'Coupon created.'
    }
    dialog.value = false
    await loadCoupons()
  } catch (e) {
    error.value = e?.response?.data?.detail || JSON.stringify(e?.response?.data) || 'Failed to save coupon.'
  } finally {
    saving.value = false
  }
}

async function toggleActive(item) {
  try {
    await $api.patch(`/usage-billing/admin/coupons/${item.id}/`, { is_active: !item.is_active })
    await loadCoupons()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to update coupon.'
  }
}

async function remove(item) {
  try {
    await $api.delete(`/usage-billing/admin/coupons/${item.id}/`)
    toast.value = 'Coupon removed.'
    await loadCoupons()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to remove coupon.'
  }
}

onMounted(() => {
  loadCoupons()
  loadTenants()
})
</script>
