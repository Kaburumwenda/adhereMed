<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader title="New Invoice" subtitle="Create a patient invoice"
      icon="mdi-receipt-text-plus" color="indigo">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/invoices`)">Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" @submit.prevent="save">
      <!-- ═══ Invoice details ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="indigo-lighten-5" size="36" class="mr-3">
            <v-icon color="indigo-darken-2" size="20">mdi-file-document-edit</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Invoice Details</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-select v-model="form.patient" :items="patientItems" item-title="title"
              item-value="value" label="Patient" variant="outlined"
              :rules="req" prepend-inner-icon="mdi-account" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model="form.invoice_date" label="Invoice date"
              type="date" variant="outlined" :rules="req" prepend-inner-icon="mdi-calendar" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model="form.due_date" label="Due date"
              type="date" variant="outlined" prepend-inner-icon="mdi-calendar-clock" />
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Line items ══════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center justify-space-between mb-4">
          <div class="d-flex align-center">
            <v-avatar color="teal-lighten-5" size="36" class="mr-3">
              <v-icon color="teal-darken-2" size="20">mdi-format-list-bulleted</v-icon>
            </v-avatar>
            <div class="text-h6 font-weight-bold">Line Items</div>
          </div>
          <v-btn color="primary" variant="tonal" rounded="lg" size="small"
            prepend-icon="mdi-plus" @click="addLine">Add Line</v-btn>
        </div>

        <div v-for="(line, idx) in form.line_items" :key="idx" class="line-item mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="4">
              <v-text-field v-model="line.description" label="Description"
                variant="outlined" density="compact" hide-details />
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model.number="line.quantity" label="Qty" type="number"
                variant="outlined" density="compact" hide-details min="1"
                @update:model-value="updateLineTotals" />
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model.number="line.unit_price" label="Unit price" type="number"
                variant="outlined" density="compact" hide-details min="0"
                @update:model-value="updateLineTotals" />
            </v-col>
            <v-col cols="6" md="2">
              <div class="text-body-1 font-weight-medium pt-2">
                {{ formatMoney(line.quantity * line.unit_price || 0) }}
              </div>
            </v-col>
            <v-col cols="6" md="2" class="text-right">
              <v-btn icon="mdi-delete" variant="text" color="error" size="small"
                :disabled="form.line_items.length <= 1"
                @click="removeLine(idx)" />
            </v-col>
          </v-row>
        </div>

        <v-divider class="my-3" />

        <!-- ═══ Totals ═══════════════════════════════════════════ -->
        <v-row dense justify="end">
          <v-col cols="12" md="5">
            <div class="d-flex justify-space-between text-body-2 pa-1">
              <span class="text-medium-emphasis">Subtotal</span>
              <span class="font-weight-medium">{{ formatMoney(subtotal) }}</span>
            </div>
            <div class="d-flex justify-space-between align-center text-body-2 pa-1">
              <span class="text-medium-emphasis">Tax rate (%)</span>
              <v-text-field v-model.number="form.tax_rate" type="number" min="0"
                variant="outlined" density="compact" hide-details style="max-width: 100px;"
                @update:model-value="updateLineTotals" />
            </div>
            <div class="d-flex justify-space-between text-body-2 pa-1">
              <span class="text-medium-emphasis">Tax amount</span>
              <span class="font-weight-medium">{{ formatMoney(taxAmount) }}</span>
            </div>
            <v-divider class="my-1" />
            <div class="d-flex justify-space-between text-h6 font-weight-bold pa-1">
              <span>Total</span>
              <span>{{ formatMoney(total) }}</span>
            </div>
          </v-col>
        </v-row>
      </v-card>

      <!-- ═══ Notes & status ═══════════════════════════════════════ -->
      <v-card flat rounded="lg" class="form-section pa-4 pa-md-5 mb-4">
        <div class="d-flex align-center mb-4">
          <v-avatar color="amber-lighten-5" size="36" class="mr-3">
            <v-icon color="amber-darken-3" size="20">mdi-note-text</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Notes</div>
        </div>
        <v-row dense>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
              variant="outlined" prepend-inner-icon="mdi-text" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.status" :items="statusOptions" label="Status"
              variant="outlined" prepend-inner-icon="mdi-list-status" />
          </v-col>
        </v-row>
      </v-card>

      <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mb-4">
        {{ r.error.value }}
      </v-alert>

      <div class="d-flex flex-wrap justify-end ga-2 mb-4">
        <v-btn variant="text" rounded="lg" class="text-none"
          @click="navigateTo(`${ns}/invoices`)">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none"
          :loading="r.saving.value" prepend-icon="mdi-content-save">Create Invoice</v-btn>
      </div>
    </v-form>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'

const ns = '/clinics'
const router = useRouter()
const r = useResource('/invoices/')
const patientR = useResource('/patients/')
const formRef = ref(null)

onMounted(() => patientR.list({ page_size: 1000 }))

const patientItems = computed(() =>
  patientR.items.value.map(p => ({
    title: p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || p.user_email || p.patient_number || `#${p.id}`,
    value: p.id,
  }))
)

const req = [v => !!v || 'Required']
const statusOptions = [
  { title: 'Unpaid', value: 'unpaid' },
  { title: 'Partial', value: 'partial' },
]

const form = reactive({
  patient: null,
  invoice_date: new Date().toISOString().slice(0, 10),
  due_date: '',
  notes: '',
  status: 'unpaid',
  tax_rate: 0,
  line_items: [blankLine()],
})

function blankLine() {
  return { description: '', quantity: 1, unit_price: 0, total: 0 }
}
function addLine() { form.line_items.push(blankLine()) }
function removeLine(idx) { form.line_items.splice(idx, 1) }

const subtotal = computed(() =>
  form.line_items.reduce((s, l) => s + (Number(l.quantity) || 0) * (Number(l.unit_price) || 0), 0)
)
const taxAmount = computed(() => subtotal.value * (Number(form.tax_rate) || 0) / 100)
const total = computed(() => subtotal.value + taxAmount.value)

const snack = reactive({ show: false, color: 'success', text: '' })

function updateLineTotals() {
  form.line_items.forEach(l => {
    l.total = (Number(l.quantity) || 0) * (Number(l.unit_price) || 0)
  })
}

async function save() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  const payload = {
    patient: form.patient,
    invoice_date: form.invoice_date,
    due_date: form.due_date || null,
    notes: form.notes,
    status: form.status,
    tax_rate: Number(form.tax_rate) || 0,
    line_items: form.line_items.map(l => ({
      description: l.description,
      quantity: Number(l.quantity) || 0,
      unit_price: Number(l.unit_price) || 0,
      total: (Number(l.quantity) || 0) * (Number(l.unit_price) || 0),
    })),
  }
  try {
    const created = await r.create(payload)
    snack.text = 'Invoice created successfully'
    snack.color = 'success'
    snack.show = true
    if (created?.id) {
      router.push(`${ns}/invoices/${created.id}`)
    } else {
      router.push(`${ns}/invoices`)
    }
  } catch {
    snack.text = r.error.value || 'Failed to create invoice'
    snack.color = 'error'
    snack.show = true
  }
}
</script>

<style scoped>
.form-section { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.line-item { border-left: 3px solid rgba(var(--v-theme-primary), 0.4); padding-left: 8px; }
</style>
