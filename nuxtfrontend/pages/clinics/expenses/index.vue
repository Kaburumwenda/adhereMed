<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Expenses" subtitle="Clinic expense tracking"
      icon="mdi-cash-minus" color="warning">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="load">Refresh</v-btn>
        <v-btn color="warning" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNew">New Expense</v-btn>
      </template>
    </PageHeader>

    <!-- ── KPI stat cards ─────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="44" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline text-medium-emphasis" style="line-height:1.1">
                {{ k.label }}
              </div>
              <div class="text-h5 font-weight-bold" style="line-height:1.2">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search expenses…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="categoryFilter" :items="categoryOptions"
            label="Category" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="dateFrom" type="date" label="From"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="dateTo" type="date" label="To"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="1" class="d-flex align-center justify-end">
          <v-btn v-if="activeFilters" size="small" variant="text" class="text-none"
            prepend-icon="mdi-filter-remove" @click="clearFilters">Clear</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="warning" size="48" />
      </div>

      <div v-else-if="!filteredExpenses.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-cash-minus</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No expenses found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ activeFilters ? 'Try adjusting your filters.' : 'Record your first expense to get started.' }}
        </div>
        <v-btn v-if="!activeFilters" color="warning" rounded="lg" prepend-icon="mdi-plus"
          @click="openNew">New Expense</v-btn>
        <v-btn v-else variant="text" rounded="lg" prepend-icon="mdi-filter-remove"
          @click="clearFilters">Clear filters</v-btn>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredExpenses"
        :items-per-page="20"
        item-value="id"
        hover
        class="expenses-table">
        <template #item.amount="{ value }">{{ formatMoney(value) }}</template>
        <template #item.date="{ value }">{{ formatDate(value) }}</template>
        <template #item.category="{ value }">
          <v-chip size="small" variant="tonal" color="warning"
            class="text-capitalize">{{ value || 'other' }}</v-chip>
        </template>
        <template #item.status="{ value }">
          <v-chip size="small" variant="tonal" :color="value === 'approved' ? 'success' : value === 'pending' ? 'warning' : 'grey'"
            class="text-capitalize">{{ value || 'pending' }}</v-chip>
        </template>
        <template #item.paid_by="{ item }">
          {{ item.paid_by_name || item.paid_by?.name || item.paid_by || '—' }}
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ New expense dialog ═══════════════════════════════════ -->
    <v-dialog v-model="newDialog" max-width="600">
      <v-card rounded="lg" class="pa-4">
        <div class="text-h6 font-weight-bold mb-4">New Expense</div>
        <v-form ref="formRef" @submit.prevent="saveNew">
          <v-row dense>
            <v-col cols="12">
              <v-text-field v-model="newForm.description" label="Description"
                variant="outlined" :rules="req" prepend-inner-icon="mdi-text" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="newForm.category" :items="categoryOptions" label="Category"
                variant="outlined" :rules="req" prepend-inner-icon="mdi-tag" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="newForm.amount" label="Amount" type="number"
                min="0" variant="outlined" :rules="amountRules"
                prepend-inner-icon="mdi-cash" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="newForm.date" label="Date" type="date"
                variant="outlined" :rules="req" prepend-inner-icon="mdi-calendar" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="newForm.notes" label="Notes" rows="2" auto-grow
                variant="outlined" prepend-inner-icon="mdi-note-text" />
            </v-col>
          </v-row>
          <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="my-3">
            {{ r.error.value }}
          </v-alert>
          <div class="d-flex justify-end ga-2 mt-3">
            <v-btn variant="text" class="text-none" @click="newDialog = false">Cancel</v-btn>
            <v-btn type="submit" color="warning" class="text-none"
              :loading="r.saving.value" prepend-icon="mdi-check">Save Expense</v-btn>
          </div>
        </v-form>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatMoney } from '~/utils/format'

const ns = '/clinics'

const r = useResource('/expenses/')
function load() { r.list({ page_size: 1000 }) }
onMounted(load)

const categoryFilter = ref(null)
const dateFrom = ref('')
const dateTo = ref('')

const categoryOptions = ['utilities', 'supplies', 'salaries', 'rent', 'equipment', 'maintenance', 'other']

const headers = [
  { title: 'Description', key: 'description' },
  { title: 'Category', key: 'category', width: 140 },
  { title: 'Amount', key: 'amount', width: 140, align: 'end' },
  { title: 'Date', key: 'date', width: 130 },
  { title: 'Status', key: 'status', width: 120 },
  { title: 'Paid By', key: 'paid_by', width: 160 },
]

const activeFilters = computed(() =>
  categoryFilter.value || dateFrom.value || dateTo.value || r.search.value
)

function clearFilters() {
  categoryFilter.value = null
  dateFrom.value = ''
  dateTo.value = ''
  r.search.value = ''
}

const filteredExpenses = computed(() => {
  let list = r.filtered.value
  if (categoryFilter.value) list = list.filter(e => e.category === categoryFilter.value)
  if (dateFrom.value) {
    list = list.filter(e => (e.date || '').slice(0, 10) >= dateFrom.value)
  }
  if (dateTo.value) {
    list = list.filter(e => (e.date || '').slice(0, 10) <= dateTo.value)
  }
  return list
})

const kpis = computed(() => {
  const list = r.items.value
  const total = list.reduce((s, e) => s + (Number(e.amount) || 0), 0)
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().slice(0, 10)
  const todayStr = now.toISOString().slice(0, 10)
  const thisMonth = list.filter(e => (e.date || '').slice(0, 10) >= monthStart)
    .reduce((s, e) => s + (Number(e.amount) || 0), 0)
  const today = list.filter(e => (e.date || '').slice(0, 10) === todayStr)
    .reduce((s, e) => s + (Number(e.amount) || 0), 0)
  const avg = list.length ? total / list.length : 0
  return [
    { label: 'Total Expenses', value: formatMoney(total), icon: 'mdi-cash-multiple', color: 'warning' },
    { label: 'This Month', value: formatMoney(thisMonth), icon: 'mdi-calendar-month', color: 'orange' },
    { label: 'Today', value: formatMoney(today), icon: 'mdi-calendar-today', color: 'red' },
    { label: 'Average', value: formatMoney(avg), icon: 'mdi-chart-line-variant', color: 'amber' },
  ]
})

// ── New expense dialog ──
const formRef = ref(null)
const newDialog = ref(false)
const req = [v => !!v || 'Required']
const amountRules = [v => (v != null && Number(v) > 0) || 'Enter a valid amount']
const newForm = reactive(blankForm())

function blankForm() {
  return {
    description: '',
    category: 'other',
    amount: 0,
    date: new Date().toISOString().slice(0, 10),
    notes: '',
  }
}

function openNew() {
  Object.assign(newForm, blankForm())
  newDialog.value = true
}

const snack = reactive({ show: false, color: 'success', text: '' })

async function saveNew() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    await r.create({ ...newForm, amount: Number(newForm.amount) || 0 })
    newDialog.value = false
    snack.text = 'Expense recorded successfully'
    snack.color = 'success'
    snack.show = true
    await load()
  } catch {
    snack.text = r.error.value || 'Failed to record expense'
    snack.color = 'error'
    snack.show = true
  }
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
