<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col>
          <div class="d-flex align-center">
            <v-avatar color="white" size="48" class="mr-3 elevation-2">
              <v-icon color="orange-darken-3" size="28">mdi-truck</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold">{{ loadId ? 'Edit supplier' : 'New supplier' }}</div>
              <div class="text-body-2" style="opacity:0.9">
                Capture contact details and the items this supplier provides.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="auto">
          <v-btn variant="flat" color="white" class="text-orange-darken-3"
                 prepend-icon="mdi-arrow-left" to="/suppliers">Back</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border class="pa-4 pa-md-6">
      <v-form ref="formRef" v-model="valid" @submit.prevent="save">
        <div class="text-subtitle-1 font-weight-bold mb-3">Contact</div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.name" label="Name *" :rules="[req]"
                          variant="outlined" density="comfortable" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.contact_person" label="Contact person"
                          variant="outlined" density="comfortable" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.phone" label="Phone" prepend-inner-icon="mdi-phone"
                          variant="outlined" density="comfortable" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.email" label="Email" type="email"
                          prepend-inner-icon="mdi-email" variant="outlined" density="comfortable" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.payment_terms" label="Payment terms"
                          placeholder="e.g. Net 30" variant="outlined" density="comfortable" />
          </v-col>
          <v-col cols="12" md="6">
            <v-switch v-model="form.is_active" label="Active" color="success"
                      density="comfortable" hide-details inset />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.address" label="Address" rows="2" auto-grow
                        variant="outlined" density="comfortable" />
          </v-col>
        </v-row>

        <v-divider class="my-5" />

        <div class="d-flex align-center mb-3">
          <div class="text-subtitle-1 font-weight-bold">Items supplied</div>
          <v-chip class="ml-2" size="small" color="primary" variant="tonal">
            {{ form.items.length }}
          </v-chip>
          <v-spacer />
          <v-btn color="primary" variant="tonal" prepend-icon="mdi-plus" @click="addItem">
            Add item
          </v-btn>
        </div>

        <v-alert v-if="!form.items.length" type="info" variant="tonal" density="compact">
          Add at least one item this supplier provides. You can search existing stock or
          enter a new item manually.
        </v-alert>

        <v-card v-for="(it, i) in form.items" :key="i" variant="outlined" rounded="lg"
                class="pa-3 mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="5">
              <v-autocomplete
                v-if="!it._manual"
                v-model="it.stock"
                v-model:search="it._search"
                :items="it._options"
                :loading="it._loading"
                item-title="medication_name"
                item-value="id"
                label="Item *"
                placeholder="Search stock by name…"
                variant="outlined" density="comfortable"
                clearable hide-no-data hide-details auto-select-first
                no-filter
                @update:search="onItemSearch(i, $event)"
                @update:model-value="onStockSelected(i, $event)"
              >
                <template #item="{ props, item }">
                  <v-list-item v-bind="props" :title="item.raw.medication_name">
                    <template #subtitle>
                      <span class="text-caption">
                        Cost {{ formatMoney(item.raw.cost_price || 0) }} ·
                        Sell {{ formatMoney(item.raw.selling_price || 0) }} ·
                        In stock {{ item.raw.total_quantity || 0 }}
                      </span>
                    </template>
                  </v-list-item>
                </template>
                <template #append-inner>
                  <v-tooltip text="Switch to manual entry" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-pencil" variant="text" size="x-small"
                             @click.stop="enableManual(i)" />
                    </template>
                  </v-tooltip>
                </template>
              </v-autocomplete>
              <v-text-field v-else v-model="it.item_name" label="Item name *"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-pencil"
                            hint="Manual entry – not in stock yet" persistent-hint
                            :rules="[req]">
                <template #append-inner>
                  <v-tooltip text="Search stock instead" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-magnify" variant="text" size="x-small"
                             @click.stop="disableManual(i)" />
                    </template>
                  </v-tooltip>
                </template>
              </v-text-field>
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model.number="it.unit_cost" type="number" min="0" step="0.01"
                            label="Unit cost" prepend-inner-icon="mdi-cash"
                            variant="outlined" density="comfortable" hide-details />
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model.number="it.unit_price" type="number" min="0" step="0.01"
                            label="Selling price" prepend-inner-icon="mdi-tag"
                            variant="outlined" density="comfortable" hide-details />
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model.number="it.quantity" type="number" min="0" step="1"
                            label="Quantity"
                            variant="outlined" density="comfortable" hide-details>
                <template v-if="it._stockQty != null" #append-inner>
                  <v-tooltip :text="`In stock: ${it._stockQty}`" location="top">
                    <template #activator="{ props }">
                      <v-icon v-bind="props" size="16" color="info">mdi-information</v-icon>
                    </template>
                  </v-tooltip>
                </template>
              </v-text-field>
            </v-col>
            <v-col cols="6" md="1" class="text-right">
              <v-btn icon="mdi-delete" variant="text" color="error" size="small"
                     @click="removeItem(i)" />
            </v-col>
            <v-col v-if="it.stock && it._stockName" cols="12">
              <v-chip size="x-small" color="success" variant="tonal" prepend-icon="mdi-package-variant">
                Linked: {{ it._stockName }}
              </v-chip>
            </v-col>
          </v-row>
        </v-card>

        <div class="d-flex mt-5">
          <v-btn variant="text" to="/suppliers">Cancel</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" type="submit" :loading="saving"
                 :disabled="!form.name">
            {{ loadId ? 'Update supplier' : 'Create supplier' }}
          </v-btn>
        </div>
      </v-form>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()
const loadId = computed(() => route.params.id || null)

const formRef = ref(null)
const valid = ref(true)
const saving = ref(false)
const req = v => !!v || 'Required'

const form = reactive(blankForm())
function blankForm() {
  return {
    name: '', contact_person: '', phone: '', email: '', address: '',
    payment_terms: '', is_active: true,
    items: [],
  }
}
function blankItem() {
  return {
    stock: null, item_name: '', unit_cost: 0, unit_price: 0, quantity: 0,
    notes: '',
    _search: '', _options: [], _loading: false, _manual: false,
    _stockName: '', _stockQty: null,
  }
}

function addItem() { form.items.push(blankItem()) }
function removeItem(i) { form.items.splice(i, 1) }
function enableManual(i) {
  const it = form.items[i]
  it._manual = true
  it.stock = null
  it._stockName = ''
  it._stockQty = null
}
function disableManual(i) {
  const it = form.items[i]
  it._manual = false
}

const searchTimers = {}
function onItemSearch(i, q) {
  const it = form.items[i]
  if (!q) { it._options = []; return }
  it.item_name = q
  if (q.length < 2) return
  clearTimeout(searchTimers[i])
  searchTimers[i] = setTimeout(async () => {
    it._loading = true
    try {
      const { data } = await $api.get('/inventory/stocks/', {
        params: { search: q, page_size: 20 },
      })
      it._options = data?.results || data || []
    } catch { it._options = [] }
    finally { it._loading = false }
  }, 300)
}

function onStockSelected(i, stockId) {
  const it = form.items[i]
  if (!stockId) {
    it._stockName = ''
    it._stockQty = null
    return
  }
  const s = (it._options || []).find(o => o.id === stockId)
  if (!s) return
  it._manual = false
  it.item_name = s.medication_name
  it.unit_cost = Number(s.cost_price || 0)
  it.unit_price = Number(s.selling_price || 0)
  it.quantity = Number(s.total_quantity || 0)
  it._stockName = s.medication_name
  it._stockQty = s.total_quantity || 0
}

async function load() {
  if (!loadId.value) return
  try {
    const { data } = await $api.get(`/suppliers/${loadId.value}/`)
    Object.assign(form, blankForm(), {
      name: data.name, contact_person: data.contact_person, phone: data.phone,
      email: data.email, address: data.address, payment_terms: data.payment_terms,
      is_active: data.is_active,
      items: (data.items || []).map(it => ({
        ...blankItem(),
        stock: it.stock,
        item_name: it.item_name,
        unit_cost: Number(it.unit_cost || 0),
        unit_price: Number(it.unit_price || 0),
        quantity: Number(it.quantity || 0),
        notes: it.notes || '',
        _stockName: it.stock_name || '',
        _stockQty: it.stock_quantity != null ? it.stock_quantity : null,
        _manual: !it.stock,
        _options: it.stock ? [{
          id: it.stock,
          medication_name: it.stock_name || it.item_name,
          cost_price: it.unit_cost,
          selling_price: it.unit_price,
          total_quantity: it.stock_quantity || 0,
        }] : [],
      })),
    })
  } catch (e) { notify(extractError(e) || 'Failed to load supplier', 'error') }
}
onMounted(load)

async function save() {
  const result = await formRef.value.validate()
  if (!result.valid) return
  for (const it of form.items) {
    if (!it.stock && !it.item_name) {
      notify('Each item needs a name or a linked stock entry.', 'error')
      return
    }
  }
  saving.value = true
  try {
    const payload = {
      name: form.name,
      contact_person: form.contact_person,
      phone: form.phone,
      email: form.email,
      address: form.address,
      payment_terms: form.payment_terms,
      is_active: form.is_active,
      items: form.items.map(it => ({
        stock: it.stock || null,
        item_name: it.item_name || it._stockName || '',
        unit_cost: Number(it.unit_cost || 0),
        unit_price: Number(it.unit_price || 0),
        quantity: Number(it.quantity || 0),
        notes: it.notes || '',
      })),
    }
    if (loadId.value) await $api.put(`/suppliers/${loadId.value}/`, payload)
    else await $api.post('/suppliers/', payload)
    notify(loadId.value ? 'Supplier updated' : 'Supplier created')
    router.push('/suppliers')
  } catch (e) { notify(extractError(e) || 'Save failed', 'error') }
  finally { saving.value = false }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #c2410c 0%, #f97316 50%, #fbbf24 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(249, 115, 22, 0.25);
}
</style>
