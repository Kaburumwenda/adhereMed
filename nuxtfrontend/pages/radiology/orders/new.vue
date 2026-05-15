<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1100px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-btn icon="mdi-arrow-left" variant="text" to="/radiology/orders" />
      <v-avatar color="primary-lighten-5" size="44">
        <v-icon color="primary" size="24">mdi-clipboard-plus</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">New Radiology Order</div>
        <div class="text-body-2 text-medium-emphasis">Create an imaging order in 3 steps</div>
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
      <!-- Step 1: Patient & imaging -->
      <v-card v-show="step === 0" flat rounded="xl" class="pa-5 mb-4 step-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="primary" class="mr-2">mdi-account-heart</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Patient &amp; Imaging Type</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.patient" :items="patients" item-title="full_name" item-value="id"
              label="Patient" :rules="req" variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-account-search" placeholder="Search by name…">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <template #prepend>
                    <v-avatar :color="avatarColor(item.value)" size="32" class="mr-2">
                      <span class="text-white text-caption font-weight-bold">{{ (item.title || '?')[0] }}</span>
                    </v-avatar>
                  </template>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.imaging_type" :items="imagingTypes" label="Imaging Type" :rules="req"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-radiology" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-combobox v-model="form.body_part" :items="bodyParts" label="Body Part" :rules="req"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-human"
              placeholder="Select or type…" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.priority" :items="priorities" label="Priority"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-flag" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.modality" :items="modalities" item-title="name" item-value="id"
              label="Equipment / Modality" clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-cog">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <v-list-item-subtitle>{{ item.raw.manufacturer }} · {{ item.raw.room_location || 'No room' }}</v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.exam_ids" :items="exams" item-title="name" item-value="id"
              label="Exams" multiple chips closable-chips clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-format-list-checks">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <v-list-item-subtitle>{{ item.raw.modality_type }} · {{ item.raw.body_region }} · {{ formatMoney(item.raw.price) }}</v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.clinical_indication" label="Clinical Indication" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-text-box" />
          </v-col>
        </v-row>

        <!-- Selected exams summary -->
        <v-expand-transition>
          <div v-if="selectedExams.length" class="mt-3">
            <v-divider class="mb-3" />
            <div class="text-caption font-weight-bold text-medium-emphasis mb-2">SELECTED EXAMS</div>
            <v-table density="compact" class="rounded-lg">
              <thead><tr><th>Exam</th><th>Modality</th><th>Region</th><th class="text-end">Price</th></tr></thead>
              <tbody>
                <tr v-for="e in selectedExams" :key="e.id">
                  <td class="text-body-2 font-weight-medium">{{ e.name }}</td>
                  <td class="text-body-2">{{ e.modality_type }}</td>
                  <td class="text-body-2">{{ e.body_region }}</td>
                  <td class="text-body-2 text-end">{{ formatMoney(e.price) }}</td>
                </tr>
                <tr class="bg-grey-lighten-5">
                  <td colspan="3" class="font-weight-bold">Total</td>
                  <td class="font-weight-bold text-end">{{ formatMoney(examTotal) }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>
        </v-expand-transition>
      </v-card>

      <!-- Step 2: Referring & clinical -->
      <v-card v-show="step === 1" flat rounded="xl" class="pa-5 mb-4 step-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="indigo" class="mr-2">mdi-hospital-building</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Referring &amp; Clinical Info</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="extra.referring_doctor" :items="refDoctors" item-title="name" item-value="id"
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
            <v-select v-model="extra.pregnancy_status" :items="pregnancyOptions" label="Pregnancy Status"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-human-pregnant" clearable />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="extra.clinical_history" label="Clinical History" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-clipboard-text" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="extra.allergies_contrast" label="Contrast Allergies / Contraindications" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-alert-circle">
              <template #message="{ message }"><span class="text-error">{{ message }}</span></template>
            </v-textarea>
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
              <div class="review-row"><span>Imaging</span><strong>{{ imagingLabel(form.imaging_type) }}</strong></div>
              <div class="review-row"><span>Body Part</span><strong>{{ form.body_part }}</strong></div>
              <div class="review-row"><span>Priority</span>
                <v-chip size="x-small" :color="form.priority === 'stat' ? 'error' : form.priority === 'urgent' ? 'warning' : 'info'" variant="tonal">{{ form.priority }}</v-chip>
              </div>
              <div class="review-row"><span>Equipment</span><strong>{{ selectedModalityName }}</strong></div>
              <div v-if="selectedExams.length" class="review-row"><span>Exams</span><strong>{{ selectedExams.length }} selected ({{ formatMoney(examTotal) }})</strong></div>
            </div>
          </v-col>
          <v-col cols="12" md="6">
            <div class="review-section pa-4 rounded-lg mb-3">
              <div class="text-caption font-weight-bold text-medium-emphasis mb-2">REFERRING &amp; PAYMENT</div>
              <div class="review-row"><span>Doctor</span><strong>{{ selectedRefDocName }}</strong></div>
              <div class="review-row"><span>Facility</span><strong>{{ selectedRefFacName }}</strong></div>
              <div class="review-row"><span>Payer</span><strong>{{ payerLabel(extra.payer_type) }}</strong></div>
              <div v-if="extra.pregnancy_status" class="review-row"><span>Pregnancy</span><strong>{{ extra.pregnancy_status }}</strong></div>
              <div v-if="extra.allergies_contrast" class="review-row">
                <span>Allergies</span>
                <v-chip size="x-small" color="error" variant="tonal" prepend-icon="mdi-alert">Present</v-chip>
              </div>
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
        <v-btn variant="text" rounded="lg" class="text-none" to="/radiology/orders">Cancel</v-btn>
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
const formRef = ref(null)
const saving = ref(false)
const step = ref(0)
const submitError = ref('')
const req = [v => !!v || 'Required']

const steps = [
  { title: 'Patient & Imaging', sub: 'Select patient and exam type' },
  { title: 'Referring & Clinical', sub: 'Referral and medical details' },
  { title: 'Review', sub: 'Confirm and submit' },
]

const form = reactive({ patient: null, imaging_type: '', body_part: '', priority: 'routine', modality: null, exam_ids: [], clinical_indication: '' })
const extra = reactive({ referring_doctor: null, referring_facility: null, payer_type: 'self', clinical_history: '', pregnancy_status: '', allergies_contrast: '' })

const bodyParts = [
  'Head','Brain','Skull','Face','Orbits','Sinuses','Temporal Bones','Mandible','TMJ',
  'Neck','Cervical Spine','Soft Tissue Neck','Thyroid','Salivary Glands',
  'Chest','Lungs','Ribs','Sternum','Thoracic Spine','Mediastinum','Heart','Breast (Left)','Breast (Right)','Breast (Bilateral)',
  'Abdomen','Liver','Gallbladder','Pancreas','Spleen','Kidneys','Adrenal Glands','Abdominal Aorta',
  'Pelvis','Bladder','Prostate','Uterus','Ovaries','Rectum','Sacrum','Coccyx','SI Joints','Hips (Bilateral)',
  'Lumbar Spine','Lumbosacral Spine','Whole Spine',
  'Shoulder (Left)','Shoulder (Right)','Clavicle','Scapula',
  'Upper Arm (Left)','Upper Arm (Right)','Humerus','Elbow (Left)','Elbow (Right)',
  'Forearm (Left)','Forearm (Right)','Wrist (Left)','Wrist (Right)','Hand (Left)','Hand (Right)','Fingers',
  'Hip (Left)','Hip (Right)','Femur (Left)','Femur (Right)',
  'Knee (Left)','Knee (Right)','Tibia/Fibula (Left)','Tibia/Fibula (Right)',
  'Ankle (Left)','Ankle (Right)','Foot (Left)','Foot (Right)','Toes','Calcaneus',
  'Upper Extremity (Left)','Upper Extremity (Right)','Lower Extremity (Left)','Lower Extremity (Right)',
  'Whole Body','Bone Survey','Skeletal Survey',
  'Carotid Arteries','Renal Arteries','Peripheral Arteries','Peripheral Veins','Aorta','Pulmonary Arteries',
  'KUB','IVP','Barium Swallow','Barium Meal','Barium Enema','Voiding Cystourethrogram','Fistulogram','Myelogram',
]

const imagingTypes = [
  { title: 'X-Ray', value: 'xray' }, { title: 'CT Scan', value: 'ct' }, { title: 'MRI', value: 'mri' },
  { title: 'Ultrasound', value: 'ultrasound' }, { title: 'Mammogram', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' }, { title: 'Other', value: 'other' },
]
const priorities = [{ title: 'Routine', value: 'routine' }, { title: 'Urgent', value: 'urgent' }, { title: 'STAT', value: 'stat' }]
const payerTypes = [
  { title: 'Self-pay', value: 'self' }, { title: 'Insurance', value: 'insurance' },
  { title: 'Referring Facility', value: 'facility' }, { title: 'Corporate', value: 'corporate' },
]
const pregnancyOptions = [
  { title: 'Not pregnant', value: 'not_pregnant' }, { title: 'Possibly pregnant', value: 'possibly' },
  { title: 'Pregnant', value: 'pregnant' }, { title: 'Unknown', value: 'unknown' }, { title: 'N/A', value: 'na' },
]

const patients = ref([])
const modalities = ref([])
const exams = ref([])
const refDoctors = ref([])
const refFacilities = ref([])

const selectedExams = computed(() => exams.value.filter(e => form.exam_ids.includes(e.id)))
const examTotal = computed(() => selectedExams.value.reduce((s, e) => s + (parseFloat(e.price) || 0), 0))
const selectedPatientName = computed(() => patients.value.find(p => p.id === form.patient)?.full_name || '—')
const selectedModalityName = computed(() => modalities.value.find(m => m.id === form.modality)?.name || '—')
const selectedRefDocName = computed(() => refDoctors.value.find(d => d.id === extra.referring_doctor)?.name || '—')
const selectedRefFacName = computed(() => refFacilities.value.find(f => f.id === extra.referring_facility)?.name || '—')

function imagingLabel(v) { return imagingTypes.find(t => t.value === v)?.title || v || '—' }
function payerLabel(v) { return payerTypes.find(t => t.value === v)?.title || v || '—' }
function formatMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }

async function nextStep() {
  if (step.value === 0) {
    const { valid } = await formRef.value.validate()
    if (!valid) return
  }
  step.value++
}

onMounted(async () => {
  const [pRes, mRes, eRes, dRes, fRes] = await Promise.allSettled([
    $api.get('/patients/?page_size=1000'),
    $api.get('/radiology/modalities/?page_size=200'),
    $api.get('/radiology/exam-catalog/?page_size=500'),
    $api.get('/radiology/referring-doctors/?page_size=500'),
    $api.get('/radiology/referring-facilities/?page_size=200'),
  ])
  patients.value = (pRes.status === 'fulfilled' ? pRes.value.data?.results || pRes.value.data || [] : []).map(p => ({
    ...p, full_name: `${p.first_name || ''} ${p.last_name || ''}`.trim() || p.user_email || `Patient #${p.id}`
  }))
  modalities.value = mRes.status === 'fulfilled' ? mRes.value.data?.results || mRes.value.data || [] : []
  exams.value = eRes.status === 'fulfilled' ? eRes.value.data?.results || eRes.value.data || [] : []
  refDoctors.value = dRes.status === 'fulfilled' ? dRes.value.data?.results || dRes.value.data || [] : []
  refFacilities.value = fRes.status === 'fulfilled' ? fRes.value.data?.results || fRes.value.data || [] : []
})

async function submit() {
  saving.value = true
  submitError.value = ''
  try {
    const orderRes = await $api.post('/radiology/orders/', form)
    const orderId = orderRes.data.id
    if (extra.referring_doctor || extra.referring_facility || extra.clinical_history || extra.allergies_contrast || extra.pregnancy_status) {
      await $api.post('/radiology/order-extras/', { ...extra, order: orderId }).catch(() => {})
    }
    router.push(`/radiology/orders/${orderId}`)
  } catch (e) {
    submitError.value = e.response?.data?.detail || e.response?.data?.non_field_errors?.[0] || 'Failed to create order. Please check required fields.'
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
</style>
