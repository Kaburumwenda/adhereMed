<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Invoice' : 'New Invoice'"
    icon="mdi-receipt-text"
    back-path="/invoices"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/invoices')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete
            v-model="form.patient"
            :items="patients"
            :item-title="patientLabel"
            item-value="id"
            label="Patient"
            placeholder="Type a name, email or patient number"
            prepend-inner-icon="mdi-account-search"
            :rules="req"
            :loading="loadingPatients"
            :search="patientSearch"
            @update:search="onPatientSearch"
            no-filter
            clearable
            hide-no-data
            return-object="false"
            menu-icon="mdi-chevron-down"
          >
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :title="patientLabel(item.raw)"
                           :subtitle="patientSubLabel(item.raw)" />
            </template>
          </v-autocomplete>
        </v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.status" :items="['draft','unpaid','paid','cancelled']" label="Status" />
        </v-col>
        <v-col cols="12">
          <h4 class="text-subtitle-1 font-weight-bold mt-2 mb-2">Line items</h4>
          <v-card v-for="(it, i) in form.items" :key="i" class="pa-3 mb-2" variant="outlined">
            <v-row dense>
              <v-col cols="12" sm="5"><v-text-field v-model="it.description" label="Description" density="compact" /></v-col>
              <v-col cols="6" sm="2"><v-text-field v-model.number="it.quantity" label="Qty" type="number" density="compact" /></v-col>
              <v-col cols="6" sm="2"><v-text-field v-model.number="it.unit_price" label="Unit price" type="number" density="compact" /></v-col>
              <v-col cols="8" sm="2" class="d-flex align-center">{{ formatMoney((it.quantity||0)*(it.unit_price||0)) }}</v-col>
              <v-col cols="4" sm="1" class="text-end">
                <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="form.items.splice(i,1)" />
              </v-col>
            </v-row>
          </v-card>
          <v-btn variant="tonal" prepend-icon="mdi-plus" @click="form.items.push({description:'',quantity:1,unit_price:0})">Add Item</v-btn>
        </v-col>
        <v-col cols="12" class="text-end">
          <span class="text-h6">Total: {{ formatMoney(total(form)) }}</span>
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/billing/invoices/')
const req = [v => !!v || 'Required']
const initial = { patient: null, status: 'draft', items: [{ description: '', quantity: 1, unit_price: 0 }], notes: '' }
const patients = ref([])
const loadingPatients = ref(false)
const patientSearch = ref('')
let searchTimer = null
function patientLabel(p) {
  if (!p) return ''
  const name = p.user_name || p.user_email || ''
  return p.patient_number ? `${name} · ${p.patient_number}` : (name || `Patient #${p.id}`)
}
function patientSubLabel(p) {
  if (!p) return ''
  return [p.user_email, p.user_phone].filter(Boolean).join(' · ')
}
async function fetchPatients(q = '') {
  loadingPatients.value = true
  try {
    const params = { page_size: 20 }
    if (q) params.search = q
    const { data } = await $api.get('/patients/', { params })
    patients.value = data?.results || data || []
  } catch { patients.value = [] } finally { loadingPatients.value = false }
}
function onPatientSearch(q) {
  patientSearch.value = q || ''
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => fetchPatients(patientSearch.value), 250)
}
function total(f) { return (f.items || []).reduce((s, it) => s + (Number(it.quantity)||0) * (Number(it.unit_price)||0), 0) }
onMounted(() => fetchPatients())
</script>
