<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" variant="text" color="white" :to="'/dispensing'" class="mr-2" />
        <v-avatar color="white" size="48" class="mr-3 elevation-2">
          <v-icon color="green-darken-3" size="28">mdi-cash-register</v-icon>
        </v-avatar>
        <div>
          <div class="text-h5 text-md-h4 font-weight-bold">{{ $t('newDispense.title') }}</div>
          <div class="text-body-2" style="opacity:0.9">
            Search items, build the cart and complete the sale.
          </div>
        </div>
      </div>
    </v-card>

    <v-form ref="formRef" v-model="valid">
      <v-row dense>
        <!-- Left: patient + items cart -->
        <v-col cols="12" lg="8">
          <v-card flat rounded="xl" border class="pa-4 mb-3">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon class="mr-2" color="primary">mdi-account</v-icon>Patient
            </div>
            <v-row dense>
              <v-col cols="12" md="5">
                <v-autocomplete
                  v-model="selectedPatient"
                  :items="patientOptions"
                  :loading="patientLoading"
                  :search="patientSearch"
                  @update:search="onPatientSearch"
                  item-title="display"
                  item-value="id"
                  return-object
                  label="Search registered patient"
                  placeholder="Type a name or patient #"
                  prepend-inner-icon="mdi-account-search"
                  variant="outlined"
                  density="comfortable"
                  clearable
                  hide-no-data
                  hide-details
                  @update:model-value="onPatientSelected"
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="form.patient_name" label="Patient name *"
                              :rules="[v => !!v || 'Required']"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="form.patient_phone" label="Phone" prepend-inner-icon="mdi-phone"
                              variant="outlined" density="comfortable" />
              </v-col>
            </v-row>
          </v-card>

          <!-- Add item search -->
          <v-card flat rounded="xl" border class="pa-4 mb-3">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="text-subtitle-1 font-weight-bold">
                <v-icon class="mr-2" color="primary">mdi-pill</v-icon>Items
                <v-chip size="small" class="ml-2" color="primary" variant="tonal">{{ items.length }}</v-chip>
              </div>
              <v-btn variant="text" size="small" prepend-icon="mdi-plus" @click="addManual">Add manual line</v-btn>
            </div>
            <v-autocomplete
              v-model="addPicker"
              :items="stockOptions"
              :loading="stockLoading"
              :search="stockSearch"
              @update:search="onStockSearch"
              item-title="medication_name"
              item-value="id"
              return-object
              label="Search & add medication"
              placeholder="Type medication name…"
              prepend-inner-icon="mdi-magnify"
              variant="outlined"
              density="comfortable"
              clearable
              hide-no-data
              @update:model-value="onAddStock"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props">
                  <template #subtitle>
                    KSh {{ item.raw.selling_price }} · In stock {{ item.raw.total_quantity ?? 0 }} {{ item.raw.unit_abbreviation || '' }}
                  </template>
                </v-list-item>
              </template>
            </v-autocomplete>

            <v-divider class="my-3" />

            <div v-if="!items.length" class="text-center py-6 text-medium-emphasis">
              <v-icon size="40" color="grey-lighten-1">mdi-cart-off</v-icon>
              <div class="text-body-2 mt-2">Cart is empty. Search above to add items.</div>
            </div>

            <v-table v-else density="comfortable" class="cart-table">
              <thead>
                <tr>
                  <th>Medication</th>
                  <th style="width:120px">{{ $t('newDispense.qty') }}</th>
                  <th style="width:140px">Unit price</th>
                  <th style="width:140px" class="text-right">{{ $t('common.total') }}</th>
                  <th style="width:60px"></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(it, i) in items" :key="i">
                  <td>
                    <div class="font-weight-medium">{{ it.medication_name }}</div>
                    <div v-if="it._inStock != null" class="text-caption"
                         :class="it.qty > it._inStock ? 'text-error' : 'text-medium-emphasis'">
                      <v-icon size="12">mdi-package-variant</v-icon>
                      {{ it._inStock }} in stock
                      <span v-if="it.qty > it._inStock"> · INSUFFICIENT</span>
                    </div>
                    <v-text-field v-if="it._manual" v-model="it.medication_name"
                                  density="compact" variant="plain" hide-details
                                  placeholder="Item name" />
                  </td>
                  <td>
                    <v-text-field v-model.number="it.qty" type="number" min="1"
                                  density="compact" variant="outlined" hide-details
                                  @update:model-value="recalc" />
                  </td>
                  <td>
                    <v-text-field v-model.number="it.unit_price" type="number" min="0"
                                  density="compact" variant="outlined" hide-details prefix="KSh"
                                  @update:model-value="recalc" />
                  </td>
                  <td class="text-right font-weight-bold">
                    KSh {{ ((it.qty || 0) * (it.unit_price || 0)).toLocaleString() }}
                  </td>
                  <td>
                    <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="removeItem(i)" />
                  </td>
                </tr>
              </tbody>
            </v-table>
          </v-card>

          <v-card flat rounded="xl" border class="pa-4">
            <div class="text-subtitle-2 font-weight-bold mb-2">Notes (optional)</div>
            <v-textarea v-model="form.notes" rows="2" auto-grow variant="outlined" density="comfortable"
                        placeholder="Internal notes for this dispense…" hide-details />
          </v-card>
        </v-col>

        <!-- Right: summary + payment -->
        <v-col cols="12" lg="4">
          <v-card flat rounded="xl" class="summary-card pa-4 mb-3" sticky>
            <div class="text-subtitle-1 font-weight-bold mb-3 text-white">
              <v-icon color="white" class="mr-2">mdi-receipt</v-icon>Summary
            </div>
            <div class="d-flex justify-space-between text-white py-1">
              <span>{{ $t('common.subtotal') }}</span><span>KSh {{ subtotal.toLocaleString() }}</span>
            </div>
            <v-text-field v-model.number="form.discount" type="number" min="0"
                          density="compact" variant="solo-filled" flat hide-details
                          prefix="− KSh" label="Discount" class="my-2" @update:model-value="recalc" />
            <v-divider class="my-2 border-opacity-50" color="white" />
            <div class="d-flex justify-space-between text-h6 font-weight-bold text-white">
              <span>{{ $t('common.total') }}</span><span>KSh {{ total.toLocaleString() }}</span>
            </div>
          </v-card>

          <v-card flat rounded="xl" border class="pa-4 mb-3">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon class="mr-2" color="primary">mdi-cash-multiple</v-icon>Payment
            </div>
            <v-select v-model="form.payment_method" :items="paymentMethods"
                      item-title="label" item-value="value"
                      label="Method" variant="outlined" density="comfortable" class="mb-2" hide-details />
            <v-text-field v-model.number="form.paid_amount" type="number" min="0"
                          label="Amount paid" prefix="KSh"
                          variant="outlined" density="comfortable" hide-details
                          @update:model-value="recalc" />
            <div class="d-flex justify-space-between mt-3 py-2 px-2 rounded"
                 :class="change >= 0 ? 'bg-green-lighten-5' : 'bg-red-lighten-5'">
              <span class="font-weight-medium">{{ change >= 0 ? 'Change' : 'Balance due' }}</span>
              <span class="font-weight-bold"
                    :class="change >= 0 ? 'text-success' : 'text-error'">
                KSh {{ Math.abs(change).toLocaleString() }}
              </span>
            </div>
            <v-row dense class="mt-3">
              <v-col v-for="q in quickAmounts" :key="q" cols="6">
                <v-btn block size="small" variant="tonal"
                       @click="form.paid_amount = q; recalc()">
                  KSh {{ q.toLocaleString() }}
                </v-btn>
              </v-col>
              <v-col cols="6">
                <v-btn block size="small" variant="tonal" color="primary"
                       @click="form.paid_amount = total; recalc()">Exact</v-btn>
              </v-col>
            </v-row>
          </v-card>

          <v-btn block size="large" color="success" prepend-icon="mdi-check-bold"
                 :loading="saving" :disabled="!canSave" @click="save">
            Complete Dispense
          </v-btn>
          <v-btn block class="mt-2" variant="text" :to="'/dispensing'">{{ $t('common.cancel') }}</v-btn>
        </v-col>
      </v-row>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted, watch } from 'vue'
const { $api } = useNuxtApp()
const router = useRouter()

const formRef = ref(null)
const valid = ref(true)
const saving = ref(false)
const snack = ref({ show: false, color: 'success', text: '' })

const form = ref({
  patient_name: '',
  patient_phone: '',
  patient_user_id: null,
  notes: '',
  discount: 0,
  payment_method: 'cash',
  paid_amount: 0,
})
const items = ref([])

const paymentMethods = [
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Card', value: 'card' },
  { label: 'Insurance', value: 'insurance' },
  { label: 'Credit / On Account', value: 'credit' },
]
const quickAmounts = [100, 500, 1000, 2000]

// Patient autocomplete
const selectedPatient = ref(null)
const patientOptions = ref([])
const patientLoading = ref(false)
const patientSearch = ref('')
let patientTimer = null
function onPatientSearch(q) {
  patientSearch.value = q || ''
  clearTimeout(patientTimer)
  patientTimer = setTimeout(async () => {
    if (!q || q.length < 2) { patientOptions.value = []; return }
    patientLoading.value = true
    try {
      const data = await $api.get('/patients/', { params: { search: q, page_size: 15 } })
        .then(r => r.data?.results || r.data || [])
      patientOptions.value = data.map(p => ({
        ...p,
        display: `${p.user?.first_name || ''} ${p.user?.last_name || ''} · ${p.patient_number || ''}`.trim(),
      }))
    } catch { patientOptions.value = [] }
    finally { patientLoading.value = false }
  }, 300)
}
function onPatientSelected(p) {
  if (!p) return
  form.value.patient_user_id = p.user?.id || null
  form.value.patient_name = `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || p.patient_number || ''
  form.value.patient_phone = p.user?.phone || ''
}

// Stock autocomplete
const addPicker = ref(null)
const stockOptions = ref([])
const stockLoading = ref(false)
const stockSearch = ref('')
let stockTimer = null
function onStockSearch(q) {
  stockSearch.value = q || ''
  clearTimeout(stockTimer)
  stockTimer = setTimeout(async () => {
    if (!q || q.length < 1) { stockOptions.value = []; return }
    stockLoading.value = true
    try {
      const data = await $api.get('/inventory/stocks/', { params: { search: q, page_size: 20 } })
        .then(r => r.data?.results || r.data || [])
      stockOptions.value = data
    } catch { stockOptions.value = [] }
    finally { stockLoading.value = false }
  }, 250)
}
function onAddStock(s) {
  if (!s) return
  // If already in cart, just bump qty
  const existing = items.value.find(i => i.stock_id === s.id)
  if (existing) {
    existing.qty = (existing.qty || 0) + 1
  } else {
    items.value.push({
      stock_id: s.id,
      medication_name: s.medication_name,
      qty: 1,
      unit_price: Number(s.selling_price) || 0,
      _inStock: s.total_quantity ?? null,
      _manual: false,
    })
  }
  addPicker.value = null
  stockOptions.value = []
  recalc()
}
function addManual() {
  items.value.push({ stock_id: null, medication_name: '', qty: 1, unit_price: 0, _manual: true })
}
function removeItem(i) { items.value.splice(i, 1); recalc() }

// Totals
const subtotal = computed(() => items.value.reduce((s, i) => s + (Number(i.qty) || 0) * (Number(i.unit_price) || 0), 0))
const total = computed(() => Math.max(0, subtotal.value - (Number(form.value.discount) || 0)))
const change = computed(() => (Number(form.value.paid_amount) || 0) - total.value)
function recalc() { /* reactive via computed */ }

const canSave = computed(() => items.value.length > 0 && form.value.patient_name && total.value >= 0)

async function save() {
  const ok = await formRef.value?.validate()
  if (ok && ok.valid === false) return
  if (!items.value.length) return showSnack('Add at least one item', 'error')

  saving.value = true
  try {
    const payload = {
      patient_name: form.value.patient_name,
      patient_phone: form.value.patient_phone,
      patient_user_id: form.value.patient_user_id,
      notes: form.value.notes,
      discount: form.value.discount || 0,
      payment_method: form.value.payment_method,
      paid_amount: form.value.paid_amount || 0,
      items: items.value.map(i => ({
        stock_id: i.stock_id,
        medication_name: i.medication_name,
        qty: Number(i.qty) || 0,
        unit_price: Number(i.unit_price) || 0,
      })),
    }
    await $api.post('/dispensing/', payload)
    showSnack('Dispense recorded', 'success')
    setTimeout(() => router.push('/dispensing'), 600)
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to save', 'error')
  } finally {
    saving.value = false
  }
}

function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
</script>

<style scoped>
.hero { background: linear-gradient(135deg, #14532d 0%, #16a34a 50%, #4ade80 100%); }
.summary-card {
  background: linear-gradient(160deg, #0f766e 0%, #14b8a6 100%);
  position: sticky;
  top: 16px;
}
.summary-card :deep(.v-field) { background: rgba(255, 255, 255, 0.15) !important; }
.summary-card :deep(input), .summary-card :deep(label) { color: #fff !important; }
.cart-table th { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(0,0,0,.6); }
</style>
