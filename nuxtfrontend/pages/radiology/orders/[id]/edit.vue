<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 900px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-btn icon="mdi-arrow-left" variant="text" :to="`/radiology/orders/${orderId}`" />
      <v-avatar color="amber-lighten-5" size="44">
        <v-icon color="amber-darken-3" size="24">mdi-pencil</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Edit Order #{{ orderId }}</div>
        <div class="text-body-2 text-medium-emphasis">Modify imaging order details</div>
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
            <v-select v-model="form.status" :items="statuses" label="Status"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-list-status" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.modality" :items="modalities" item-title="name" item-value="id"
              label="Equipment / Modality" clearable variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-cog">
              <template #item="{ item, props: p }">
                <v-list-item v-bind="p">
                  <v-list-item-subtitle>{{ item.raw.manufacturer }} · {{ item.raw.room_location || '' }}</v-list-item-subtitle>
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
                  <v-list-item-subtitle>{{ item.raw.modality_type }} · {{ item.raw.body_region }}</v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.clinical_indication" label="Clinical Indication" rows="3" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-text-box" />
          </v-col>
        </v-row>
      </v-card>

      <!-- Referring & clinical (order extra) -->
      <v-card flat rounded="xl" class="pa-5 mb-4 edit-card">
        <div class="d-flex align-center mb-4">
          <v-icon color="indigo" class="mr-2">mdi-hospital-building</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Referring &amp; Clinical</div>
        </div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="extraForm.referring_doctor" :items="refDoctors" item-title="name" item-value="id"
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
          <v-col cols="12" sm="6">
            <v-select v-model="extraForm.pregnancy_status" :items="pregnancyOptions" label="Pregnancy Status"
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-human-pregnant" clearable />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="extraForm.clinical_history" label="Clinical History" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-clipboard-text" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="extraForm.allergies_contrast" label="Contrast Allergies" rows="2" auto-grow
              variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-alert-circle" />
          </v-col>
        </v-row>
      </v-card>

      <v-alert v-if="submitError" type="error" variant="tonal" rounded="lg" class="mb-4" closable @click:close="submitError = ''">
        {{ submitError }}
      </v-alert>

      <div class="d-flex justify-end ga-2">
        <v-btn variant="text" rounded="lg" class="text-none" :to="`/radiology/orders/${orderId}`">Cancel</v-btn>
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
const req = [v => !!v || 'Required']
const existingExtraId = ref(null)

const form = reactive({ imaging_type: '', body_part: '', priority: 'routine', status: 'pending', modality: null, exam_ids: [], clinical_indication: '' })
const extraForm = reactive({ referring_doctor: null, referring_facility: null, payer_type: 'self', clinical_history: '', pregnancy_status: '', allergies_contrast: '' })

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
const statuses = [
  { title: 'Pending', value: 'pending' }, { title: 'Scheduled', value: 'scheduled' },
  { title: 'Checked In', value: 'checked_in' }, { title: 'In Progress', value: 'in_progress' },
  { title: 'Completed', value: 'completed' }, { title: 'Cancelled', value: 'cancelled' },
]
const payerTypes = [
  { title: 'Self-pay', value: 'self' }, { title: 'Insurance', value: 'insurance' },
  { title: 'Referring Facility', value: 'facility' }, { title: 'Corporate', value: 'corporate' },
]
const pregnancyOptions = [
  { title: 'Not pregnant', value: 'not_pregnant' }, { title: 'Possibly pregnant', value: 'possibly' },
  { title: 'Pregnant', value: 'pregnant' }, { title: 'Unknown', value: 'unknown' }, { title: 'N/A', value: 'na' },
]

const modalities = ref([])
const exams = ref([])
const refDoctors = ref([])
const refFacilities = ref([])

onMounted(async () => {
  const [oRes, exRes, mRes, eRes, dRes, fRes] = await Promise.allSettled([
    $api.get(`/radiology/orders/${orderId}/`),
    $api.get(`/radiology/order-extras/?order=${orderId}`),
    $api.get('/radiology/modalities/?page_size=200'),
    $api.get('/radiology/exam-catalog/?page_size=500'),
    $api.get('/radiology/referring-doctors/?page_size=500'),
    $api.get('/radiology/referring-facilities/?page_size=200'),
  ])
  if (oRes.status === 'fulfilled') {
    const o = oRes.value.data
    Object.assign(form, { imaging_type: o.imaging_type, body_part: o.body_part, priority: o.priority, status: o.status, modality: o.modality, exam_ids: o.exams || [], clinical_indication: o.clinical_indication })
  }
  const extras = exRes.status === 'fulfilled' ? (exRes.value.data?.results || exRes.value.data || []) : []
  if (extras[0]) {
    existingExtraId.value = extras[0].id
    Object.assign(extraForm, {
      referring_doctor: extras[0].referring_doctor, referring_facility: extras[0].referring_facility,
      payer_type: extras[0].payer_type || 'self', clinical_history: extras[0].clinical_history || '',
      pregnancy_status: extras[0].pregnancy_status || '', allergies_contrast: extras[0].allergies_contrast || '',
    })
  }
  modalities.value = mRes.status === 'fulfilled' ? mRes.value.data?.results || mRes.value.data || [] : []
  exams.value = eRes.status === 'fulfilled' ? eRes.value.data?.results || eRes.value.data || [] : []
  refDoctors.value = dRes.status === 'fulfilled' ? dRes.value.data?.results || dRes.value.data || [] : []
  refFacilities.value = fRes.status === 'fulfilled' ? fRes.value.data?.results || fRes.value.data || [] : []
  loaded.value = true
})

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  submitError.value = ''
  try {
    await $api.patch(`/radiology/orders/${orderId}/`, form)
    const hasExtra = extraForm.referring_doctor || extraForm.referring_facility || extraForm.clinical_history || extraForm.allergies_contrast || extraForm.pregnancy_status
    if (hasExtra) {
      if (existingExtraId.value) {
        await $api.patch(`/radiology/order-extras/${existingExtraId.value}/`, extraForm).catch(() => {})
      } else {
        await $api.post('/radiology/order-extras/', { ...extraForm, order: orderId }).catch(() => {})
      }
    }
    router.push(`/radiology/orders/${orderId}`)
  } catch (e) {
    submitError.value = e.response?.data?.detail || 'Failed to save changes.'
  }
  saving.value = false
}
</script>

<style scoped>
.edit-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
