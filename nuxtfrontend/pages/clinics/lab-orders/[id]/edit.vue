<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 900px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-btn icon="mdi-arrow-left" variant="text" :to="`/clinics/lab-orders/${orderId}`" />
      <v-avatar color="amber-lighten-5" size="44">
        <v-icon color="amber-darken-3" size="24">mdi-pencil</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Edit Order #{{ orderId }}</div>
        <div class="text-body-2 text-medium-emphasis">Modify laboratory order details</div>
      </div>
    </div>

    <v-form v-if="loaded" ref="formRef" @submit.prevent="submit">
      <!-- Order info -->
      <v-card flat rounded="xl" class="pa-5 mb-4 edit-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="primary" class="mr-2">mdi-information</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Order Info</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.patient" :items="patients" item-title="full_name" item-value="id"
              label="Patient" :rules="req" variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-account-search" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.priority" :items="priorities" label="Priority"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-flag" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.status" :items="statuses" label="Status"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-list-status" />
          </v-col>
          <v-col cols="12" sm="6" class="d-flex align-center">
            <v-checkbox v-model="form.is_home_collection" label="Home sample collection" color="purple"
              hide-details density="compact" />
          </v-col>
          <v-col cols="12">
            <v-autocomplete v-model="form.test_ids" :items="testCatalog" item-title="name" item-value="id"
              label="Tests" multiple chips closable-chips clearable :rules="testReq"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-test-tube">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <v-list-item-subtitle>
                    {{ item.raw.department }} · {{ item.raw.specimen_type }} · {{ formatMoney(item.raw.price) }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.clinical_notes" label="Clinical Notes" rows="3" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-text-box" />
          </v-col>
        </v-row>
      </v-card>

      <!-- Referring & billing (order extra) -->
      <v-card flat rounded="xl" class="pa-5 mb-4 edit-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="indigo" class="mr-2">mdi-hospital-building</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Referring &amp; Billing</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="extraForm.referring_doctor" :items="refDoctors" item-title="full_name" item-value="id"
              label="Referring Doctor" clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-doctor" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="extraForm.referring_facility" :items="refFacilities" item-title="name" item-value="id"
              label="Referring Facility" clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-office-building" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="extraForm.payer_type" :items="payerTypes" label="Payer Type"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-cash" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="extraForm.notes_for_lab" label="Notes for Lab" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-clipboard-text" />
          </v-col>
        </v-row>
      </v-card>

      <v-alert v-if="submitError" type="error" variant="tonal" rounded="lg" class="mb-4" closable @click:close="submitError = ''">
        {{ submitError }}
      </v-alert>

      <div class="d-flex justify-end ga-2">
        <v-btn variant="text" rounded="lg" class="text-none" :to="`/clinics/lab-orders/${orderId}`">Cancel</v-btn>
        <v-btn type="submit" color="primary" rounded="lg" class="text-none" :loading="saving"
               prepend-icon="mdi-content-save">Save Changes</v-btn>
      </div>
    </v-form>
    <div v-else class="d-flex justify-center pa-10">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()
const orderId = route.params.id
const formRef = ref(null)
const saving = ref(false)
const loaded = ref(false)
const submitError = ref('')
const req = [v => (v != null && v !== '') || 'Required']
const testReq = [v => (Array.isArray(v) && v.length > 0) || 'Select at least one test']
const existingExtraId = ref(null)

const form = reactive({ patient: null, test_ids: [], priority: 'routine', status: 'pending', is_home_collection: false, clinical_notes: '' })
const extraForm = reactive({ referring_doctor: null, referring_facility: null, payer_type: 'self', notes_for_lab: '' })

const priorities = [{ title: 'Routine', value: 'routine' }, { title: 'Urgent', value: 'urgent' }, { title: 'STAT', value: 'stat' }]
const statuses = [
  { title: 'Pending', value: 'pending' }, { title: 'Sample Collected', value: 'sample_collected' },
  { title: 'Processing', value: 'processing' }, { title: 'Completed', value: 'completed' },
  { title: 'Cancelled', value: 'cancelled' },
]
const payerTypes = [
  { title: 'Self-pay', value: 'self' }, { title: 'Insurance', value: 'insurance' },
  { title: 'Referring Facility', value: 'facility' }, { title: 'Corporate', value: 'corporate' },
]

const patients = ref([])
const testCatalog = ref([])
const refDoctors = ref([])
const refFacilities = ref([])

onMounted(async () => {
  const [oRes, exRes, pRes, tRes, dRes, fRes] = await Promise.allSettled([
    $api.get(`/lab/orders/${orderId}/`),
    $api.get(`/lab/order-extras/?lab_order=${orderId}`),
    $api.get('/patients/?page_size=1000'),
    $api.get('/lab/catalog/?page_size=1000'),
    $api.get('/lab/referring-doctors/?page_size=500'),
    $api.get('/lab/referring-facilities/?page_size=200'),
  ])
  if (oRes.status === 'fulfilled') {
    const o = oRes.value.data
    Object.assign(form, {
      patient: o.patient,
      test_ids: o.tests || o.test_ids || [],
      priority: o.priority,
      status: o.status,
      is_home_collection: o.is_home_collection,
      clinical_notes: o.clinical_notes || '',
    })
  }
  const extras = exRes.status === 'fulfilled' ? (exRes.value.data?.results || exRes.value.data || []) : []
  if (extras[0]) {
    existingExtraId.value = extras[0].id
    Object.assign(extraForm, {
      referring_doctor: extras[0].referring_doctor,
      referring_facility: extras[0].referring_facility,
      payer_type: extras[0].payer_type || 'self',
      notes_for_lab: extras[0].notes_for_lab || '',
    })
  }
  patients.value = (pRes.status === 'fulfilled' ? pRes.value.data?.results || pRes.value.data || [] : []).map(p => ({
    ...p, full_name: `${p.first_name || ''} ${p.last_name || ''}`.trim() || p.user_email || `Patient #${p.id}`,
  }))
  testCatalog.value = tRes.status === 'fulfilled' ? tRes.value.data?.results || tRes.value.data || [] : []
  refDoctors.value = dRes.status === 'fulfilled' ? dRes.value.data?.results || dRes.value.data || [] : []
  refFacilities.value = fRes.status === 'fulfilled' ? fRes.value.data?.results || fRes.value.data || [] : []
  loaded.value = true
})

function formatMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  submitError.value = ''
  try {
    await $api.patch(`/lab/orders/${orderId}/`, form)
    const hasExtra = extraForm.referring_doctor || extraForm.referring_facility || extraForm.notes_for_lab || extraForm.payer_type !== 'self'
    if (hasExtra) {
      if (existingExtraId.value) {
        await $api.patch(`/lab/order-extras/${existingExtraId.value}/`, extraForm).catch(() => {})
      } else {
        await $api.post('/lab/order-extras/', { ...extraForm, lab_order: orderId }).catch(() => {})
      }
    }
    router.push(`/clinics/lab-orders/${orderId}`)
  } catch (e) {
    submitError.value = e.response?.data?.detail || 'Failed to save changes.'
  }
  saving.value = false
}
</script>

<style scoped>
.edit-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
