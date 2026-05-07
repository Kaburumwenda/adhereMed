<template>
  <v-container fluid class="pa-4 pa-md-6 exp-form-shell">
    <PageHeader
      :title="loadId ? `Edit ${form.reference || 'Expense'}` : 'New Expense'"
      icon="mdi-cash-minus"
      :subtitle="loadId ? 'Update expense details' : 'Record a new business expense'"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/expenses">Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" v-model="formValid" @submit.prevent="onSubmit">
      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 exp-card">
        <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-information-outline</v-icon>Expense Details
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.title" label="Title *" :rules="reqRules" placeholder="e.g. Office rent — May" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.reference" label="Reference" placeholder="Auto-generated" hint="Leave blank to auto-generate" persistent-hint />
          </v-col>
          <v-col cols="12" md="3">
            <v-select v-model="form.category" :items="categoryOptions" item-title="label" item-value="value" label="Category" prepend-inner-icon="mdi-shape" clearable />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.description" label="Description" rows="2" auto-grow />
          </v-col>
        </v-row>
      </v-card>

      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 exp-card">
        <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-cash</v-icon>Amount &amp; Payment
        </div>
        <v-row dense>
          <v-col cols="12" md="3">
            <v-text-field v-model.number="form.amount" type="number" label="Amount *" :rules="amountRules" prefix="KSh" min="0" step="0.01" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model.number="form.tax_amount" type="number" label="Tax / VAT" prefix="KSh" min="0" step="0.01" />
          </v-col>
          <v-col cols="12" md="3">
            <v-select v-model="form.payment_method" :items="methodOptions" item-title="label" item-value="value" label="Payment Method" prepend-inner-icon="mdi-credit-card-outline" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.payment_reference" label="Payment Reference" placeholder="M-Pesa code, cheque #" />
          </v-col>

          <v-col cols="12" md="6">
            <v-combobox
              v-model="vendorPick"
              :items="suppliers"
              item-title="name"
              :return-object="true"
              label="Vendor / Payee"
              prepend-inner-icon="mdi-truck-delivery"
              hint="Pick a supplier or type any vendor name"
              persistent-hint
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props" :title="item.raw.name" :subtitle="item.raw.contact_person || item.raw.phone || ''" />
              </template>
            </v-combobox>
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.expense_date" type="date" label="Expense Date *" :rules="reqRules" />
          </v-col>
          <v-col cols="12" md="3">
            <v-text-field v-model="form.due_date" type="date" label="Due Date" hint="Optional" persistent-hint />
          </v-col>
        </v-row>
      </v-card>

      <v-card rounded="lg" class="pa-4 pa-md-5 mb-4 exp-card">
        <div class="text-subtitle-1 font-weight-bold mb-3 d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-cog-outline</v-icon>Status &amp; Options
        </div>
        <v-row dense>
          <v-col cols="12" md="4">
            <v-select v-model="form.status" :items="statusOptions" item-title="label" item-value="value" label="Status" />
          </v-col>
          <v-col cols="12" md="4">
            <v-checkbox v-model="form.is_recurring" label="Recurring expense" hide-details density="comfortable" />
          </v-col>
          <v-col v-if="form.is_recurring" cols="12" md="4">
            <v-select v-model="form.recurring_period" :items="recurringOptions" label="Recurring Period" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow />
          </v-col>
        </v-row>
      </v-card>

      <!-- Summary -->
      <v-card rounded="lg" class="mb-4 exp-summary-card">
        <div class="exp-summary-header pa-4">
          <div class="text-caption text-uppercase font-weight-bold" style="opacity:0.85">Summary</div>
          <div class="text-h5 font-weight-bold">{{ formatMoney(totalAmount) }}</div>
        </div>
        <div class="pa-4">
          <v-row dense>
            <v-col cols="6" md="3">
              <div class="exp-summary-stat">
                <div class="text-caption text-medium-emphasis">Subtotal</div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(form.amount || 0) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="exp-summary-stat">
                <div class="text-caption text-medium-emphasis">Tax</div>
                <div class="text-h6 font-weight-bold">{{ formatMoney(form.tax_amount || 0) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="exp-summary-stat">
                <div class="text-caption text-medium-emphasis">Method</div>
                <div class="text-body-1 font-weight-bold">{{ methodLabel(form.payment_method) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="exp-summary-stat is-total">
                <div class="text-caption" style="opacity:0.85">Total</div>
                <div class="text-h5 font-weight-bold">{{ formatMoney(totalAmount) }}</div>
              </div>
            </v-col>
          </v-row>

          <v-alert v-if="error" type="error" variant="tonal" density="compact" class="mt-3">{{ error }}</v-alert>

          <div class="d-flex justify-end ga-2 mt-3">
            <v-btn variant="text" rounded="lg" class="text-none" to="/expenses">Cancel</v-btn>
            <v-btn type="submit" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-content-save" :loading="saving" :disabled="!canSave">
              {{ loadId ? 'Save Changes' : 'Create Expense' }}
            </v-btn>
          </div>
        </div>
      </v-card>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()
const loadId = computed(() => route.params.id || null)

const r = useResource('/expenses/expenses/')
const cats = useResource('/expenses/categories/')
const supRes = useResource('/suppliers/')

const formRef = ref(null)
const formValid = ref(false)
const saving = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

function newForm() {
  return {
    reference: '',
    title: '',
    description: '',
    category: null,
    amount: 0,
    tax_amount: 0,
    expense_date: new Date().toISOString().slice(0, 10),
    due_date: '',
    payment_method: 'cash',
    payment_reference: '',
    vendor: '',
    supplier: null,
    status: 'pending',
    is_recurring: false,
    recurring_period: '',
    notes: '',
  }
}
const form = reactive(newForm())
const vendorPick = ref(null)

const methodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'M-Pesa', value: 'mpesa' },
  { label: 'Bank Transfer', value: 'bank' },
  { label: 'Card', value: 'card' },
  { label: 'Cheque', value: 'cheque' },
  { label: 'Other', value: 'other' },
]
function methodLabel(v) { return methodOptions.find(o => o.value === v)?.label || v }

const statusOptions = [
  { label: 'Pending Approval', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Paid', value: 'paid' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'Cancelled', value: 'cancelled' },
]
const recurringOptions = ['daily', 'weekly', 'monthly', 'quarterly', 'yearly']

const suppliers = computed(() => supRes.items.value || [])
const categoryOptions = computed(() => (cats.items.value || []).map(c => ({ label: c.name, value: c.id })))

const reqRules = [v => (v !== null && v !== undefined && v !== '') || 'Required']
const amountRules = [
  v => (v !== null && v !== undefined && v !== '') || 'Required',
  v => Number(v) > 0 || 'Must be greater than 0',
]

const totalAmount = computed(() => Number(form.amount || 0) + Number(form.tax_amount || 0))
const canSave = computed(() =>
  !!form.title && Number(form.amount) > 0 && !!form.expense_date
)

watch(vendorPick, (v) => {
  if (!v) { form.vendor = ''; form.supplier = null; return }
  if (typeof v === 'object') {
    form.vendor = v.name || ''
    form.supplier = v.id || null
  } else {
    form.vendor = String(v)
    form.supplier = null
  }
})

async function onSubmit() {
  error.value = ''
  if (formRef.value) {
    const { valid } = await formRef.value.validate()
    if (!valid) return
  }
  if (!canSave.value) { error.value = 'Please complete the required fields.'; return }
  saving.value = true
  try {
    const payload = {
      reference: form.reference || undefined,
      title: form.title,
      description: form.description,
      category: form.category || null,
      amount: form.amount,
      tax_amount: form.tax_amount || 0,
      expense_date: form.expense_date,
      due_date: form.due_date || null,
      payment_method: form.payment_method,
      payment_reference: form.payment_reference,
      vendor: form.vendor,
      supplier: form.supplier || null,
      status: form.status,
      is_recurring: !!form.is_recurring,
      recurring_period: form.is_recurring ? form.recurring_period : '',
      notes: form.notes,
    }
    let saved
    if (loadId.value) saved = await r.update(loadId.value, payload)
    else saved = await r.create(payload)
    snack.text = loadId.value ? 'Expense updated' : 'Expense created'
    snack.color = 'success'; snack.show = true
    router.push(`/expenses/${saved.id}`)
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      error.value = Object.entries(data).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join(' • ')
    } else {
      error.value = e?.message || 'Save failed.'
    }
  } finally { saving.value = false }
}

function hydrate(d) {
  Object.assign(form, newForm(), d)
  if (d.supplier && (supRes.items.value || []).length) {
    vendorPick.value = supRes.items.value.find(s => s.id === d.supplier) || d.vendor || null
  } else if (d.vendor) {
    vendorPick.value = d.vendor
  }
}

onMounted(async () => {
  await Promise.all([cats.list(), supRes.list()])
  if (loadId.value) {
    const data = await r.get(loadId.value)
    if (data) hydrate(data)
  }
})
</script>

<style scoped>
.exp-form-shell { max-width: 1200px; margin: 0 auto; }
.exp-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

.exp-summary-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); overflow: hidden; }
.exp-summary-header {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
  display: flex; justify-content: space-between; align-items: center;
}
.exp-summary-stat {
  background: rgba(99, 102, 241, 0.06);
  border-radius: 8px;
  padding: 12px 14px;
}
.exp-summary-stat.is-total {
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: white;
}
</style>
