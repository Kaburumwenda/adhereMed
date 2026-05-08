<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Medical Equipment"
      subtitle="Track loaned devices, oxygen concentrators, beds and accessories."
      eyebrow="ASSETS"
      icon="mdi-medical-bag"
      :chips="[{ icon: 'mdi-cube', label: `${items.length} items` }, { icon: 'mdi-truck', label: `${onLoan} on loan` }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus"
               class="text-none" @click="dialog = true">
          <span class="text-teal-darken-2 font-weight-bold">Add item</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Available" :value="available" icon="mdi-check-circle" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="On loan" :value="onLoan" icon="mdi-truck-delivery" color="#0ea5e9" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Maintenance" :value="maintenance" icon="mdi-wrench" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Retired" :value="retired" icon="mdi-archive" color="#94a3b8" /></v-col>
    </v-row>

    <HomecarePanel title="Equipment inventory" subtitle="All trackable assets" icon="mdi-cube"
                   color="#7c3aed" class="mt-3">
      <v-row dense>
        <v-col cols="12" md="6"><v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search…" density="compact" variant="outlined" hide-details /></v-col>
        <v-col cols="12" md="6">
          <v-select v-model="filterCategory" :items="categories" label="Category" density="compact" variant="outlined" hide-details clearable />
        </v-col>
      </v-row>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id" class="mt-2">
        <template #[`item.status`]="{ item }"><StatusChip :status="item.status || 'available'" /></template>
        <template #[`item.assigned_to_name`]="{ item }">
          <span v-if="item.assigned_to_name" class="text-body-2">
            <v-icon icon="mdi-account" size="14" /> {{ item.assigned_to_name }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn v-if="item.status === 'available'" size="small" variant="text" color="teal"
                 prepend-icon="mdi-truck" @click="loan(item)">Loan</v-btn>
          <v-btn v-if="item.status === 'on_loan'" size="small" variant="text" color="success"
                 prepend-icon="mdi-keyboard-return" @click="returnItem(item)">Return</v-btn>
        </template>
      </v-data-table>
    </HomecarePanel>

    <v-dialog v-model="dialog" max-width="540">
      <v-card rounded="xl">
        <v-card-title>Add equipment</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.name" label="Name" />
          <v-text-field v-model="form.serial_number" label="Serial number" />
          <v-select v-model="form.category" :items="categories" label="Category" />
          <v-text-field v-model.number="form.value" label="Value (KSh)" type="number" />
          <v-text-field v-model="form.purchase_date" label="Purchased" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="loanDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title>Loan to patient</v-card-title>
        <v-card-text>
          <v-select v-model="loanForm.patient" :items="patients" item-title="patient_name" item-value="id" label="Patient" />
          <v-text-field v-model="loanForm.expected_return" label="Expected return" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="loanDialog = false">Cancel</v-btn>
          <v-btn color="teal" @click="confirmLoan">Loan out</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const items = ref([])
const patients = ref([])
const search = ref('')
const filterCategory = ref(null)
const loading = ref(false)
const dialog = ref(false)
const loanDialog = ref(false)
const saving = ref(false)
const loanTarget = ref(null)
const form = reactive({ name: '', serial_number: '', category: 'oxygen', value: 0, purchase_date: '' })
const loanForm = reactive({ patient: null, expected_return: '' })

const categories = ['oxygen', 'bed', 'wheelchair', 'mobility', 'monitor', 'pump', 'other']
const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Serial', key: 'serial_number' },
  { title: 'Category', key: 'category' },
  { title: 'Assigned to', key: 'assigned_to_name' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]

const filtered = computed(() => {
  const q = (search.value || '').toLowerCase()
  return items.value.filter(i => {
    if (filterCategory.value && i.category !== filterCategory.value) return false
    if (q && !`${i.name} ${i.serial_number}`.toLowerCase().includes(q)) return false
    return true
  })
})
const available = computed(() => items.value.filter(i => (i.status || 'available') === 'available').length)
const onLoan = computed(() => items.value.filter(i => i.status === 'on_loan').length)
const maintenance = computed(() => items.value.filter(i => i.status === 'maintenance').length)
const retired = computed(() => items.value.filter(i => i.status === 'retired').length)

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/equipment/')
    items.value = data?.results || data || []
  } catch { items.value = [] }
  finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}
async function save() {
  saving.value = true
  try { await $api.post('/homecare/equipment/', form); dialog.value = false; load() }
  catch (e) { console.warn('equipment endpoint missing', e) }
  finally { saving.value = false }
}
function loan(item) { loanTarget.value = item; loanDialog.value = true }
async function confirmLoan() {
  try { await $api.post(`/homecare/equipment/${loanTarget.value.id}/loan/`, loanForm); loanDialog.value = false; load() }
  catch { /* */ }
}
async function returnItem(item) {
  try { await $api.post(`/homecare/equipment/${item.id}/return/`); load() } catch { /* */ }
}
onMounted(() => { load(); loadPatients() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
</style>
