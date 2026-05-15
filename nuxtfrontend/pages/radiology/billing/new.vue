<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">New Invoice</h1>
      <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/radiology/billing">Back</v-btn>
    </div>

    <v-form ref="formRef" @submit.prevent="submit">
      <v-card rounded="lg" class="pa-5 mb-4" border>
        <h3 class="text-subtitle-1 font-weight-bold mb-3">Invoice Details</h3>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.order" :items="ordersForInvoice" item-title="label" item-value="id" label="Order *" :rules="req" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.patient" :items="patients" item-title="full_name" item-value="id" label="Patient *" :rules="req" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.payer_type" :items="payerTypes" label="Payer Type" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.due_date" label="Due Date" type="date" variant="outlined" density="compact" />
          </v-col>
        </v-row>
      </v-card>

      <v-card rounded="lg" class="pa-5 mb-4" border>
        <div class="d-flex align-center justify-space-between mb-3">
          <h3 class="text-subtitle-1 font-weight-bold">Line Items</h3>
          <v-btn variant="tonal" size="small" class="text-none" prepend-icon="mdi-plus" @click="addItem">Add Item</v-btn>
        </div>
        <v-table v-if="items.length" density="compact">
          <thead><tr><th>Description</th><th>Qty</th><th>Unit Price</th><th>Discount</th><th>Total</th><th></th></tr></thead>
          <tbody>
            <tr v-for="(it, idx) in items" :key="idx">
              <td><v-text-field v-model="it.description" variant="plain" density="compact" hide-details /></td>
              <td style="width:80px"><v-text-field v-model.number="it.quantity" type="number" variant="plain" density="compact" hide-details /></td>
              <td style="width:120px"><v-text-field v-model.number="it.unit_price" type="number" variant="plain" density="compact" hide-details /></td>
              <td style="width:100px"><v-text-field v-model.number="it.discount" type="number" variant="plain" density="compact" hide-details /></td>
              <td class="font-weight-medium">{{ formatMoney((it.unit_price * it.quantity) - it.discount) }}</td>
              <td><v-btn icon="mdi-close" size="x-small" variant="text" @click="items.splice(idx, 1)" /></td>
            </tr>
          </tbody>
        </v-table>
        <div v-else class="text-body-2 text-medium-emphasis">No items added</div>

        <v-divider class="my-3" />
        <v-row dense>
          <v-col cols="6" sm="3"><v-text-field v-model.number="form.discount" label="Discount" type="number" variant="outlined" density="compact" /></v-col>
          <v-col cols="6" sm="3"><v-text-field v-model.number="form.tax" label="Tax" type="number" variant="outlined" density="compact" /></v-col>
          <v-col cols="12" sm="6" class="d-flex align-center justify-end">
            <div class="text-h6 font-weight-bold">Total: {{ formatMoney(computedTotal) }}</div>
          </v-col>
        </v-row>
      </v-card>

      <v-card rounded="lg" class="pa-5 mb-4" border>
        <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="compact" />
      </v-card>

      <div class="d-flex justify-end" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" to="/radiology/billing">Cancel</v-btn>
        <v-btn type="submit" color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving">Create Invoice</v-btn>
      </div>
    </v-form>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const { $api } = useNuxtApp()
const router = useRouter()
const formRef = ref(null)
const saving = ref(false)
const req = [v => !!v || 'Required']

const form = reactive({ order: null, patient: null, payer_type: 'self', due_date: null, discount: 0, tax: 0, notes: '' })
const items = reactive([])
const orders = ref([])
const patients = ref([])
const payerTypes = [
  { title: 'Self-pay', value: 'self' }, { title: 'Insurance', value: 'insurance' },
  { title: 'Referring Facility', value: 'facility' }, { title: 'Corporate', value: 'corporate' },
]

const ordersForInvoice = computed(() =>
  orders.value.map(o => ({ id: o.id, label: `#${o.id} ${o.patient_name} — ${o.body_part}` }))
)

const computedTotal = computed(() => {
  const subtotal = items.reduce((s, it) => s + (it.unit_price * it.quantity - it.discount), 0)
  return subtotal - (form.discount || 0) + (form.tax || 0)
})

function addItem() { items.push({ description: '', quantity: 1, unit_price: 0, discount: 0 }) }

onMounted(async () => {
  const [oRes, pRes] = await Promise.allSettled([
    $api.get('/radiology/orders/?page_size=500'),
    $api.get('/patients/?page_size=1000'),
  ])
  orders.value = oRes.status === 'fulfilled' ? oRes.value.data?.results || oRes.value.data || [] : []
  patients.value = (pRes.status === 'fulfilled' ? pRes.value.data?.results || pRes.value.data || [] : []).map(p => ({
    ...p, full_name: `${p.first_name || ''} ${p.last_name || ''}`.trim() || p.user_email || `Patient #${p.id}`
  }))
})

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    const subtotal = items.reduce((s, it) => s + (it.unit_price * it.quantity - it.discount), 0)
    const invRes = await $api.post('/radiology/invoices/', {
      ...form, subtotal, total: computedTotal.value, amount_paid: 0, status: 'draft',
    })
    const invId = invRes.data.id
    for (const it of items) {
      await $api.post('/radiology/invoice-items/', { invoice: invId, ...it, total: (it.unit_price * it.quantity) - it.discount })
    }
    router.push(`/radiology/billing/${invId}`)
  } catch (e) { console.error(e) }
  saving.value = false
}
</script>
