<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1100px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-btn icon="mdi-arrow-left" variant="text" to="/clinics/lab-orders" />
      <v-avatar color="teal-lighten-5" size="44">
        <v-icon color="teal-darken-2" size="24">mdi-clipboard-plus</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">New Lab Order</div>
        <div class="text-body-2 text-medium-emphasis">Order laboratory tests &amp; panels in 3 steps</div>
      </div>
    </div>

    <!-- Stepper header -->
    <v-card flat rounded="xl" class="mb-5 stepper-header pa-3">
      <div class="d-flex align-center justify-center ga-0 flex-wrap">
        <template v-for="(s, i) in steps" :key="i">
          <div class="d-flex align-center ga-2 cursor-pointer step-item pa-2 px-3 rounded-lg"
               :class="{ 'step-active': step === i, 'step-done': step > i }"
               @click="i < step ? step = i : null">
            <v-avatar :color="step > i ? 'success' : step === i ? 'primary' : 'grey-lighten-2'" size="32">
              <v-icon v-if="step > i" size="18" color="white">mdi-check</v-icon>
              <span v-else class="text-caption font-weight-bold" :class="step === i ? 'text-white' : 'text-medium-emphasis'">{{ i + 1 }}</span>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium" :class="step === i ? 'text-primary' : ''">{{ s.title }}</div>
              <div class="text-caption text-medium-emphasis d-none d-sm-block">{{ s.sub }}</div>
            </div>
          </div>
          <v-icon v-if="i < steps.length - 1" color="grey-lighten-1" class="mx-1">mdi-chevron-right</v-icon>
        </template>
      </div>
    </v-card>

    <v-form ref="formRef">
      <!-- Step 1: Patient & tests -->
      <v-card v-show="step === 0" flat rounded="xl" class="pa-5 mb-4 step-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="primary" class="mr-2">mdi-account-heart</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Patient &amp; Tests</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.patient" :items="patients" item-title="full_name" item-value="id"
              label="Patient" :rules="req" variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-account-search" placeholder="Search by name or email…">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <template #prepend>
                    <v-avatar :color="avatarColor(item.value)" size="32" class="mr-2">
                      <span class="text-white text-caption font-weight-bold">{{ (item.title || '?')[0] }}</span>
                    </v-avatar>
                  </template>
                  <v-list-item-subtitle v-if="item.raw.user_email || item.raw.email">
                    <v-icon size="12" class="mr-1">mdi-email-outline</v-icon>{{ item.raw.user_email || item.raw.email }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.priority" :items="priorities" label="Priority"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-flag" />
          </v-col>
          <v-col cols="12">
            <v-autocomplete v-model="form.test_ids" :items="testCatalog" item-title="name" item-value="id"
              :item-props="itemProps" label="Tests" multiple chips closable-chips clearable
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-test-tube"
              placeholder="Search test catalog…">
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
            <div class="text-caption text-medium-emphasis mb-2">
              <v-icon size="14" class="mr-1">mdi-radiobox-marked</v-icon>Common tests — click to add
            </div>
            <div class="d-flex flex-wrap ga-2">
              <v-chip v-for="t in commonTestsList" :key="t.id" size="small" variant="outlined"
                :color="isTestSelected(t.id) ? 'teal' : 'default'"
                :class="{ 'common-chip--active': isTestSelected(t.id) }"
                @click="toggleCommonTest(t.id)">
                <v-icon size="14" start>{{ isTestSelected(t.id) ? 'mdi-check-circle' : 'mdi-plus-circle' }}</v-icon>
                {{ t.name }}
              </v-chip>
              <span v-if="!commonTestsList.length" class="text-caption text-medium-emphasis">No common tests configured.</span>
            </div>
          </v-col>
          <v-col cols="12">
            <v-autocomplete v-model="selectedPanels" :items="panels" item-title="name" item-value="id"
              label="Quick-add Panels (optional)" multiple chips closable-chips clearable
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-package-variant-closed"
              hint="Selecting a panel adds all its tests below"
              persistent-hint>
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <v-list-item-subtitle>
                    {{ item.raw.test_names?.length || 0 }} tests · {{ formatMoney(item.raw.price) }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.clinical_notes" label="Clinical Indication / Notes" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-text-box" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-checkbox v-model="form.is_home_collection" label="Home sample collection" color="purple"
              hide-details density="compact" />
          </v-col>
        </v-row>

        <!-- Selected tests summary -->
        <v-expand-transition>
          <div v-if="selectedTests.length" class="mt-3">
            <v-divider class="mb-3" />
            <div class="text-caption font-weight-bold text-medium-emphasis mb-2">SELECTED TESTS</div>
            <v-table density="compact" class="rounded-lg">
              <thead><tr><th>Test</th><th>Department</th><th>Specimen</th><th class="text-end">Price</th></tr></thead>
              <tbody>
                <tr v-for="t in selectedTests" :key="t.id">
                  <td class="text-body-2 font-weight-medium">{{ t.name }}</td>
                  <td class="text-body-2">{{ t.department || '—' }}</td>
                  <td class="text-body-2">{{ t.specimen_type || '—' }}</td>
                  <td class="text-body-2 text-end">{{ formatMoney(t.price) }}</td>
                </tr>
                <tr class="bg-grey-lighten-5">
                  <td colspan="3" class="font-weight-bold">Total</td>
                  <td class="font-weight-bold text-end">{{ formatMoney(testTotal) }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>
        </v-expand-transition>
      </v-card>

      <!-- Step 2: Referring & collection -->
      <v-card v-show="step === 1" flat rounded="xl" class="pa-5 mb-4 step-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="indigo" class="mr-2">mdi-hospital-building</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Referring &amp; Collection</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="extra.referring_doctor" :items="refDoctors" item-title="full_name" item-value="id"
              label="Referring Doctor" clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-doctor">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <v-list-item-subtitle>{{ item.raw.specialty }} · {{ item.raw.facility_name || 'Independent' }}</v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="extra.referring_facility" :items="refFacilities" item-title="name" item-value="id"
              label="Referring Facility" clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-office-building" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="extra.payer_type" :items="payerTypes" label="Payer Type"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-cash" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.priority" :items="priorities" label="Priority"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-flag" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="extra.notes_for_lab" label="Notes for Lab" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-clipboard-text" />
          </v-col>
        </v-row>
      </v-card>

      <!-- Step 3: Review -->
      <v-card v-show="step === 2" flat rounded="xl" class="pa-5 mb-4 step-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="success" class="mr-2">mdi-check-decagram</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Review &amp; Submit</div>
        </div>

        <v-row dense>
          <v-col cols="12" md="6">
            <div class="review-section pa-4 rounded-lg mb-3">
              <div class="text-caption font-weight-bold text-medium-emphasis mb-2">ORDER DETAILS</div>
              <div class="review-row"><span>Patient</span><strong>{{ selectedPatientName }}</strong></div>
              <div class="review-row"><span>Priority</span>
                <v-chip size="x-small" :color="form.priority === 'stat' ? 'error' : form.priority === 'urgent' ? 'warning' : 'info'" variant="tonal">{{ priorityLabel(form.priority) }}</v-chip>
              </div>
              <div class="review-row"><span>Home Collection</span>
                <v-chip size="x-small" :color="form.is_home_collection ? 'purple' : 'grey'" variant="tonal">{{ form.is_home_collection ? 'Yes' : 'No' }}</v-chip>
              </div>
              <div v-if="selectedTests.length" class="review-row"><span>Tests</span><strong>{{ selectedTests.length }} selected ({{ formatMoney(testTotal) }})</strong></div>
              <div v-if="form.clinical_notes" class="review-row"><span>Clinical Notes</span><strong class="text-right">{{ form.clinical_notes.substring(0, 60) }}{{ form.clinical_notes.length > 60 ? '…' : '' }}</strong></div>
            </div>
          </v-col>
          <v-col cols="12" md="6">
            <div class="review-section pa-4 rounded-lg mb-3">
              <div class="text-caption font-weight-bold text-medium-emphasis mb-2">REFERRING &amp; PAYMENT</div>
              <div class="review-row"><span>Doctor</span><strong>{{ selectedRefDocName }}</strong></div>
              <div class="review-row"><span>Facility</span><strong>{{ selectedRefFacName }}</strong></div>
              <div class="review-row"><span>Payer</span><strong>{{ payerLabel(extra.payer_type) }}</strong></div>
              <div v-if="extra.notes_for_lab" class="review-row"><span>Notes for Lab</span><strong class="text-right">{{ extra.notes_for_lab.substring(0, 40) }}{{ extra.notes_for_lab.length > 40 ? '…' : '' }}</strong></div>
            </div>
          </v-col>
        </v-row>

        <v-alert v-if="submitError" type="error" variant="tonal" rounded="lg" class="mt-3" closable @click:close="submitError = ''">
          {{ submitError }}
        </v-alert>
      </v-card>
    </v-form>

    <!-- Navigation -->
    <div class="d-flex justify-space-between align-center mt-2">
      <v-btn v-if="step > 0" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" @click="step--">Back</v-btn>
      <div v-else />
      <div class="d-flex ga-2">
        <v-btn variant="text" rounded="lg" class="text-none" to="/clinics/lab-orders">Cancel</v-btn>
        <v-btn v-if="step < 2" color="primary" rounded="lg" class="text-none" append-icon="mdi-arrow-right"
               @click="nextStep">Continue</v-btn>
        <v-btn v-else color="success" rounded="lg" class="text-none" prepend-icon="mdi-content-save-check"
               :loading="saving" @click="submit">Submit Order</v-btn>
      </div>
    </div>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()
const route = useRoute()
const formRef = ref(null)
const saving = ref(false)
const step = ref(0)
const submitError = ref('')
const req = [v => (v != null && v !== '' && (!Array.isArray(v) || v.length > 0)) || 'Required']

const steps = [
  { title: 'Patient & Tests', sub: 'Select patient and tests' },
  { title: 'Referring & Collection', sub: 'Referral and collection details' },
  { title: 'Review', sub: 'Confirm and submit' },
]

const form = reactive({ patient: null, test_ids: [], priority: 'routine', clinical_notes: '', is_home_collection: false })
const extra = reactive({ referring_doctor: null, referring_facility: null, payer_type: 'self', notes_for_lab: '' })

const priorities = [{ title: 'Routine', value: 'routine' }, { title: 'Urgent', value: 'urgent' }, { title: 'STAT', value: 'stat' }]
const payerTypes = [
  { title: 'Self-pay', value: 'self' }, { title: 'Insurance', value: 'insurance' },
  { title: 'Referring Facility', value: 'facility' }, { title: 'Corporate', value: 'corporate' },
]

const patients = ref([])
const testCatalog = ref([])
const panels = ref([])
const refDoctors = ref([])
const refFacilities = ref([])
const selectedPanels = ref([])

const selectedTests = computed(() => testCatalog.value.filter(t => form.test_ids.includes(t.id)))
const testTotal = computed(() => selectedTests.value.reduce((s, t) => s + (parseFloat(t.price) || 0), 0))
const commonTestNames = [
  'Full Blood Count', 'CBC', 'Complete Blood Count', 'Blood Urea', 'Urea', 'Creatinine',
  'Glucose', 'Fasting Blood Glucose', 'HbA1c', 'Lipid Profile', 'Liver Function Test', 'LFT',
  'Thyroid Function Test', 'TSH', 'Urine Analysis', 'Urinalysis', 'Malaria Parasite',
  'Widal Test', 'Stool Analysis', 'ESR', 'Blood Group', 'Rh Factor', 'Pregnancy Test', 'HIV Test',
  'Blood Smear', ' Differential', 'Electrolytes', 'Uric Acid', 'RBS', 'FBS',
]
const commonTestsList = computed(() => {
  const names = new Set(commonTestNames.map(n => n.toLowerCase()))
  return testCatalog.value.filter(t => names.has((t.name || '').toLowerCase()))
})
function isTestSelected(id) { return form.test_ids.includes(id) }
function toggleCommonTest(id) {
  const idx = form.test_ids.indexOf(id)
  if (idx >= 0) form.test_ids.splice(idx, 1)
  else form.test_ids.push(id)
}
const selectedPatientName = computed(() => patients.value.find(p => p.id === form.patient)?.full_name || '—')
const selectedRefDocName = computed(() => refDoctors.value.find(d => d.id === extra.referring_doctor)?.full_name || '—')
const selectedRefFacName = computed(() => refFacilities.value.find(f => f.id === extra.referring_facility)?.name || '—')

function priorityLabel(p) { return { routine: 'Routine', urgent: 'Urgent', stat: 'STAT' }[p] || p }
function payerLabel(v) { return payerTypes.find(t => t.value === v)?.title || v || '—' }
function itemProps(item) { return { subtitle: `${item.raw.department || ''} · ${item.raw.specimen_type || ''} · ${formatMoney(item.raw.price)}` } }
function formatMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }

watch(selectedPanels, (newPanels) => {
  for (const panelId of newPanels) {
    const panel = panels.value.find(p => p.id === panelId)
    if (panel && panel.test_names) {
      // Find matching test IDs from catalog by name
      for (const testName of panel.test_names) {
        const test = testCatalog.value.find(t => t.name === testName)
        if (test && !form.test_ids.includes(test.id)) {
          form.test_ids.push(test.id)
        }
      }
    }
  }
})

async function nextStep() {
  if (step.value === 0) {
    const { valid } = await formRef.value.validate()
    if (!valid) return
  }
  step.value++
}

onMounted(async () => {
  const [pRes, tRes, paRes, dRes, fRes] = await Promise.allSettled([
    $api.get('/patients/?page_size=1000'),
    $api.get('/lab/catalog/?page_size=1000'),
    $api.get('/lab/panels/?page_size=500'),
    $api.get('/lab/referring-doctors/?page_size=500'),
    $api.get('/lab/referring-facilities/?page_size=200'),
  ])
  patients.value = (pRes.status === 'fulfilled' ? pRes.value.data?.results || pRes.value.data || [] : []).map(p => ({
    ...p, full_name: `${p.first_name || ''} ${p.last_name || ''}`.trim() || p.user_email || p.email || `Patient #${p.id}`,
    user_email: p.user_email || p.email || '',
  }))
  testCatalog.value = tRes.status === 'fulfilled' ? tRes.value.data?.results || tRes.value.data || [] : []
  panels.value = paRes.status === 'fulfilled' ? paRes.value.data?.results || paRes.value.data || [] : []
  refDoctors.value = dRes.status === 'fulfilled' ? dRes.value.data?.results || dRes.value.data || [] : []
  refFacilities.value = fRes.status === 'fulfilled' ? fRes.value.data?.results || fRes.value.data || [] : []
  if (route.query.patient) form.patient = Number(route.query.patient)
})

async function submit() {
  saving.value = true
  submitError.value = ''
  try {
    const orderRes = await $api.post('/lab/orders/', {
      patient: form.patient,
      test_ids: form.test_ids,
      priority: form.priority,
      clinical_notes: form.clinical_notes,
      is_home_collection: form.is_home_collection,
    })
    const orderId = orderRes.data.id
    if (extra.referring_doctor || extra.referring_facility || extra.payer_type !== 'self' || extra.notes_for_lab) {
      await $api.post('/lab/order-extras/', {
        ...extra,
        lab_order: orderId,
      }).catch(() => {})
    }
    router.push(`/clinics/lab-orders/${orderId}`)
  } catch (e) {
    submitError.value = e.response?.data?.detail || e.response?.data?.non_field_errors?.[0]
      || (typeof e.response?.data === 'object' ? JSON.stringify(e.response.data) : null)
      || 'Failed to create order. Please check required fields.'
  }
  saving.value = false
}
</script>

<style scoped>
.stepper-header { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.step-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.step-item { transition: all 0.2s ease; }
.step-active { background: rgba(var(--v-theme-primary), 0.06); }
.step-done { opacity: 0.7; }
.step-done:hover { opacity: 1; }
.review-section { background: rgba(var(--v-theme-on-surface), 0.02); border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.review-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.04); }
.review-row:last-child { border-bottom: none; }
.review-row span { color: rgba(var(--v-theme-on-surface), 0.6); font-size: 0.875rem; }
.common-chip--active { font-weight: 600; background: rgba(var(--v-theme-primary), 0.06); }
</style>
