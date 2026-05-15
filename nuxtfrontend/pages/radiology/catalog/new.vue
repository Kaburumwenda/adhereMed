<template>
  <v-container fluid class="pa-4 pa-md-6">
    <v-row>
      <!-- Main form column -->
      <v-col cols="12" md="8">
        <!-- Header -->
        <div class="hero-header pa-5 rounded-xl mb-5">
          <div class="d-flex align-center ga-3">
            <v-btn icon="mdi-arrow-left" variant="text" color="white" to="/radiology/catalog" />
            <v-avatar size="48" color="rgba(255,255,255,0.15)">
              <v-icon color="white" size="26">mdi-flask-plus</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold text-white">New Exam</div>
              <div class="text-body-2" style="color:rgba(255,255,255,0.75)">Add an imaging exam to the catalog</div>
            </div>
          </div>
        </div>

        <!-- Duplicate alert -->
        <v-expand-transition>
          <v-alert v-if="duplicateExam" type="warning" variant="tonal" rounded="xl" class="mb-4" closable border="start">
            <div class="d-flex align-center justify-space-between flex-wrap ga-2">
              <div>
                <div class="font-weight-bold">Exam already exists</div>
                <div class="text-body-2">"{{ duplicateExam.name }}" ({{ duplicateExam.code }}) is already in the catalog.</div>
              </div>
              <v-btn variant="flat" color="warning" size="small" rounded="lg" class="text-none"
                     prepend-icon="mdi-pencil" :to="`/radiology/catalog/${duplicateExam.id}/edit`">Edit Existing</v-btn>
            </div>
          </v-alert>
        </v-expand-transition>

        <v-form ref="formRef" @submit.prevent="submit">

          <!-- STEP 1: Basic Info -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" color="primary" class="text-white text-caption font-weight-bold">1</v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Identification</div>
                  <div class="text-caption text-medium-emphasis">Code, name &amp; search existing catalog</div>
                </div>
              </div>
            </div>
            <div class="pa-5">
              <v-row dense>
                <v-col cols="12" sm="4">
                  <v-text-field v-model="form.code" label="Exam Code *" :rules="req" variant="outlined"
                    density="compact" rounded="lg" prepend-inner-icon="mdi-identifier"
                    hint="CPT or internal code" persistent-hint />
                </v-col>
                <v-col cols="12" sm="8">
                  <v-autocomplete v-model="form.name" :items="examNames" label="Exam Name *" :rules="req"
                    variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-magnify"
                    no-filter :search="nameSearch" @update:search="onNameSearch"
                    clearable hint="Search or pick from catalog" persistent-hint>
                    <template #item="{ props: itemProps, item }">
                      <v-list-item v-bind="itemProps">
                        <template #prepend>
                          <v-icon size="18" :color="existingSet.has(item.value) ? 'warning' : 'grey'">
                            {{ existingSet.has(item.value) ? 'mdi-alert-circle' : 'mdi-flask-outline' }}
                          </v-icon>
                        </template>
                        <template #append>
                          <v-chip v-if="existingSet.has(item.value)" size="x-small" color="warning" variant="tonal">Exists</v-chip>
                        </template>
                      </v-list-item>
                    </template>
                  </v-autocomplete>
                </v-col>
              </v-row>
            </div>
          </v-card>

          <!-- STEP 2: Modality -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" :color="form.modality_type ? 'success' : 'primary'" class="text-white text-caption font-weight-bold">
                  <v-icon v-if="form.modality_type" size="16">mdi-check</v-icon>
                  <span v-else>2</span>
                </v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Modality Type <span class="text-error">*</span></div>
                  <div class="text-caption text-medium-emphasis">Select imaging modality or type custom</div>
                </div>
              </div>
            </div>
            <div class="pa-5">
              <div class="modality-palette pa-3 rounded-xl mb-3">
                <div class="d-flex align-center ga-2 mb-3">
                  <v-icon size="16" color="deep-purple">mdi-view-grid</v-icon>
                  <span class="text-caption font-weight-bold text-uppercase" style="letter-spacing:0.5px">Select Modality</span>
                  <v-chip size="x-small" variant="tonal" color="deep-purple">{{ modalityTypes.length }}</v-chip>
                </div>
                <div class="d-flex flex-wrap ga-2">
                  <v-chip v-for="m in modalityTypes" :key="m.value" size="default"
                    :variant="form.modality_type === m.value ? 'elevated' : 'tonal'"
                    :color="form.modality_type === m.value ? modalityColor(m.value) : 'default'"
                    :class="{ 'modality-chip--active': form.modality_type === m.value }"
                    class="modality-chip px-3" @click="form.modality_type = m.value">
                    <v-icon start size="18">{{ modalityIcon(m.value) }}</v-icon>
                    {{ m.title }}
                  </v-chip>
                </div>
              </div>
              <v-text-field v-model="form.modality_type" label="Or type custom modality" variant="outlined"
                density="compact" rounded="lg" prepend-inner-icon="mdi-radiology" hide-details />
            </div>
          </v-card>

          <!-- STEP 3: Body Region -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" :color="form.body_region ? 'success' : 'primary'" class="text-white text-caption font-weight-bold">
                  <v-icon v-if="form.body_region" size="16">mdi-check</v-icon>
                  <span v-else>3</span>
                </v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Body Region</div>
                  <div class="text-caption text-medium-emphasis">Anatomical area for this exam</div>
                </div>
              </div>
            </div>
            <div class="pa-5">
              <div class="body-palette pa-3 rounded-xl mb-3">
                <div class="d-flex align-center ga-2 mb-3">
                  <v-icon size="16" color="indigo">mdi-human-handsup</v-icon>
                  <span class="text-caption font-weight-bold text-uppercase" style="letter-spacing:0.5px">Select Body Region</span>
                  <v-chip size="x-small" variant="tonal" color="indigo">{{ bodyRegions.length }}</v-chip>
                </div>
                <div class="d-flex flex-wrap ga-2">
                  <v-chip v-for="b in bodyRegions" :key="b"
                    :variant="form.body_region === b ? 'elevated' : 'tonal'"
                    :color="form.body_region === b ? 'indigo' : 'default'"
                    size="small" class="body-chip" @click="form.body_region = form.body_region === b ? '' : b">
                    <v-icon v-if="form.body_region === b" start size="14">mdi-check-circle</v-icon>
                    {{ b }}
                  </v-chip>
                </div>
              </div>
              <v-text-field v-model="form.body_region" label="Or type custom body region" variant="outlined"
                density="compact" rounded="lg" prepend-inner-icon="mdi-human" hide-details />
            </div>
          </v-card>

          <!-- STEP 4: Parameters -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" color="primary" class="text-white text-caption font-weight-bold">4</v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Parameters</div>
                  <div class="text-caption text-medium-emphasis">Duration, pricing &amp; contrast settings</div>
                </div>
              </div>
            </div>
            <div class="pa-5">
              <v-row dense>
                <v-col cols="12" sm="4">
                  <v-text-field v-model.number="form.estimated_duration_minutes" label="Duration (min)" type="number"
                    variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-clock-outline" />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field v-model.number="form.price" label="Price" type="number" prefix="KSh"
                    variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-cash" />
                </v-col>
                <v-col cols="12" sm="4" class="d-flex align-center">
                  <v-card flat rounded="lg" class="pa-3 w-100 contrast-toggle" :class="{ 'contrast-toggle--on': form.contrast_required }">
                    <div class="d-flex align-center ga-2">
                      <v-switch v-model="form.contrast_required" color="warning" hide-details density="compact" />
                      <div>
                        <div class="text-body-2 font-weight-medium">Contrast</div>
                        <div class="text-caption text-medium-emphasis">{{ form.contrast_required ? 'Required' : 'Not needed' }}</div>
                      </div>
                    </div>
                  </v-card>
                </v-col>
              </v-row>
            </div>
          </v-card>

          <!-- STEP 5: Protocol & Prep -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" color="primary" class="text-white text-caption font-weight-bold">5</v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Protocol &amp; Preparation</div>
                  <div class="text-caption text-medium-emphasis">Click chips to quickly build instructions</div>
                </div>
              </div>
            </div>
            <div class="pa-5">
              <!-- Default Protocol -->
              <div class="protocol-section mb-5">
                <div class="d-flex align-center ga-2 mb-2">
                  <v-avatar size="24" color="indigo" variant="tonal" class="text-caption font-weight-bold">
                    <v-icon size="14">mdi-text-box</v-icon>
                  </v-avatar>
                  <span class="text-subtitle-2 font-weight-bold">Default Protocol</span>
                  <v-chip size="x-small" variant="tonal" color="indigo">{{ protocolChips.length }} options</v-chip>
                </div>
                <div class="chip-palette pa-3 rounded-lg mb-2">
                  <div class="d-flex flex-wrap ga-2">
                    <v-chip v-for="p in protocolChips" :key="p" size="small" variant="flat" color="indigo"
                      class="quick-chip font-weight-medium" @click="appendField('default_protocol', p)">
                      <v-icon start size="14">mdi-plus-circle-outline</v-icon>{{ p }}
                    </v-chip>
                  </div>
                </div>
                <v-textarea v-model="form.default_protocol" placeholder="e.g. Axial T1, T2, FLAIR, DWI…" rows="3" auto-grow
                  variant="outlined" density="compact" rounded="lg" />
              </div>

              <!-- Prep Instructions -->
              <div class="prep-section">
                <div class="d-flex align-center ga-2 mb-2">
                  <v-avatar size="24" color="teal" variant="tonal" class="text-caption font-weight-bold">
                    <v-icon size="14">mdi-format-list-checks</v-icon>
                  </v-avatar>
                  <span class="text-subtitle-2 font-weight-bold">Prep Instructions</span>
                  <v-chip size="x-small" variant="tonal" color="teal">{{ prepChips.length }} options</v-chip>
                </div>
                <div class="chip-palette chip-palette--prep pa-3 rounded-lg mb-2">
                  <div class="d-flex flex-wrap ga-2">
                    <v-chip v-for="p in prepChips" :key="p" size="small" variant="flat" color="teal"
                      class="quick-chip font-weight-medium" @click="appendField('prep_instructions', p)">
                      <v-icon start size="14">mdi-plus-circle-outline</v-icon>{{ p }}
                    </v-chip>
                  </div>
                </div>
                <v-textarea v-model="form.prep_instructions" placeholder="e.g. NPO 6 hours. Remove jewelry…" rows="3" auto-grow
                  variant="outlined" density="compact" rounded="lg" />
              </div>
            </div>
          </v-card>

          <!-- Status & Submit -->
          <v-card flat rounded="xl" class="pa-5 mb-4 section-card">
            <div class="d-flex align-center justify-space-between flex-wrap ga-3">
              <div class="d-flex align-center ga-3">
                <v-switch v-model="form.is_active" color="success" hide-details density="compact" />
                <div>
                  <div class="text-body-2 font-weight-medium">{{ form.is_active ? 'Active' : 'Inactive' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ form.is_active ? 'Visible in orders' : 'Hidden from orders' }}</div>
                </div>
              </div>
              <div class="d-flex ga-2">
                <v-btn variant="outlined" rounded="lg" class="text-none" to="/radiology/catalog">Cancel</v-btn>
                <v-btn type="submit" color="primary" rounded="lg" class="text-none" :loading="saving" size="large"
                       prepend-icon="mdi-content-save">Save Exam</v-btn>
              </div>
            </div>
          </v-card>

        </v-form>
      </v-col>

      <!-- Live preview sidebar -->
      <v-col cols="12" md="4" class="d-none d-md-block">
        <div class="sticky-preview">
          <v-card flat rounded="xl" class="section-card overflow-hidden">
            <div class="preview-header px-4 py-3">
              <div class="text-caption font-weight-bold text-uppercase text-white" style="letter-spacing:1px">
                <v-icon size="14" class="mr-1">mdi-eye</v-icon> Live Preview
              </div>
            </div>
            <div class="pa-4">
              <!-- Code badge -->
              <div class="d-flex align-center ga-2 mb-3">
                <code v-if="form.code" class="preview-code px-2 py-1 rounded font-weight-bold">{{ form.code }}</code>
                <span v-else class="text-caption text-medium-emphasis text-italic">No code</span>
                <v-spacer />
                <v-chip size="x-small" :color="form.is_active ? 'success' : 'grey'" variant="tonal">
                  {{ form.is_active ? 'Active' : 'Inactive' }}
                </v-chip>
              </div>

              <!-- Name -->
              <div class="text-subtitle-1 font-weight-bold mb-3">{{ form.name || 'Exam Name' }}</div>

              <!-- Modality & region -->
              <div class="d-flex flex-wrap ga-2 mb-3">
                <v-chip v-if="form.modality_type" size="small" variant="tonal" :color="modalityColor(form.modality_type)">
                  <v-icon start size="14">{{ modalityIcon(form.modality_type) }}</v-icon>
                  {{ modalityLabel(form.modality_type) }}
                </v-chip>
                <v-chip v-if="form.body_region" size="small" variant="outlined">
                  <v-icon start size="14">mdi-human</v-icon>{{ form.body_region }}
                </v-chip>
                <v-chip v-if="form.contrast_required" size="small" variant="tonal" color="warning">
                  <v-icon start size="14">mdi-water</v-icon>Contrast
                </v-chip>
              </div>

              <v-divider class="mb-3" />

              <!-- Stats -->
              <div class="d-flex ga-4 mb-3">
                <div>
                  <div class="text-caption text-medium-emphasis">Duration</div>
                  <div class="text-body-2 font-weight-bold">{{ form.estimated_duration_minutes || 0 }}m</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Price</div>
                  <div class="text-body-2 font-weight-bold">KSh {{ Number(form.price || 0).toLocaleString() }}</div>
                </div>
              </div>

              <!-- Protocol preview -->
              <div v-if="form.default_protocol" class="mb-3">
                <div class="text-caption font-weight-bold text-uppercase mb-1">Protocol</div>
                <div class="text-caption preview-text pa-2 rounded-lg">{{ form.default_protocol }}</div>
              </div>

              <!-- Prep preview -->
              <div v-if="form.prep_instructions">
                <div class="text-caption font-weight-bold text-uppercase mb-1">Prep Instructions</div>
                <div class="text-caption preview-text pa-2 rounded-lg">{{ form.prep_instructions }}</div>
              </div>

              <!-- Completeness indicator -->
              <v-divider class="my-3" />
              <div class="d-flex align-center ga-2 mb-1">
                <v-progress-linear :model-value="completeness" :color="completeness === 100 ? 'success' : 'primary'"
                  rounded height="6" />
                <span class="text-caption font-weight-bold" style="min-width:32px">{{ completeness }}%</span>
              </div>
              <div class="text-caption text-medium-emphasis">{{ completenessLabel }}</div>
            </div>
          </v-card>
        </div>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack" :color="snackColor" rounded="lg" timeout="2500" location="bottom right">{{ snackMsg }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()
const formRef = ref(null)
const saving = ref(false)
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')
const req = [v => !!v || 'Required']

// Existing exams for duplicate detection
const existingExams = ref([])
const nameSearch = ref('')
const existingSet = computed(() => new Set(existingExams.value.map(e => e.name)))
const examNames = computed(() => {
  const q = (nameSearch.value || '').toLowerCase()
  if (!q) return existingExams.value.map(e => e.name).slice(0, 20)
  return existingExams.value
    .filter(e => e.name.toLowerCase().includes(q))
    .map(e => e.name)
    .slice(0, 20)
})
const duplicateExam = computed(() => {
  if (!form.name) return null
  return existingExams.value.find(e => e.name.toLowerCase() === form.name.toLowerCase())
})
function onNameSearch(val) { nameSearch.value = val || '' }

const modalityTypes = [
  { title: 'X-Ray', value: 'xray' }, { title: 'CT Scan', value: 'ct' }, { title: 'MRI', value: 'mri' },
  { title: 'Ultrasound', value: 'ultrasound' }, { title: 'Mammography', value: 'mammogram' },
  { title: 'Fluoroscopy', value: 'fluoroscopy' }, { title: 'PET-CT', value: 'pet_ct' },
  { title: 'DEXA', value: 'dexa' }, { title: 'Other', value: 'other' },
]
const bodyRegions = ['Head','Brain','Neck','Chest','Thorax','Abdomen','Pelvis','Spine - Cervical','Spine - Thoracic','Spine - Lumbar','Spine - Full','Upper Extremity','Shoulder','Elbow','Wrist','Hand','Lower Extremity','Hip','Knee','Ankle','Foot','Whole Body']

function modalityColor(t) { return { xray:'blue-grey',ct:'indigo',mri:'deep-purple',ultrasound:'teal',mammogram:'pink',fluoroscopy:'amber-darken-2',pet_ct:'orange',dexa:'cyan',other:'grey' }[t] || 'grey' }
function modalityIcon(t) { return { xray:'mdi-radiology',ct:'mdi-rotate-3d-variant',mri:'mdi-magnet',ultrasound:'mdi-waveform',mammogram:'mdi-radiology',fluoroscopy:'mdi-movie-open',pet_ct:'mdi-atom',dexa:'mdi-bone',other:'mdi-image' }[t] || 'mdi-radiology' }
function modalityLabel(t) { return modalityTypes.find(m => m.value === t)?.title || t }

// Protocol & prep quick-insert chips
const protocolChips = [
  'AP view','PA view','Lateral view','Oblique views','Axial slices',
  'Sagittal reformat','Coronal reformat','3D reconstruction','Thin-section 1-2mm',
  'T1 weighted','T2 weighted','FLAIR','DWI','Post-contrast','Fat saturation',
  'STIR','PD fat-sat','Dynamic contrast','Breath-hold','Bone window','Lung window',
  'Mediastinal window','Colour Doppler','Spectral Doppler',
]
const prepChips = [
  'NPO 4 hours','NPO 6 hours','NPO 8 hours','Check renal function (creatinine)',
  'Remove all jewelry & metal','Remove dentures','Full bladder required',
  'Empty bladder before exam','MRI safety screening','IV access required',
  'Consent form required','Check coagulation profile','Pregnancy test required',
  'No deodorant/powder/lotion','Wear loose comfortable clothing',
  'Bring prior imaging if available','No strenuous exercise 24hrs before',
  'Hold anticoagulants if advised','Oral contrast 1hr before if indicated',
]
function appendField(field, text) {
  const cur = form[field]?.trim()
  form[field] = cur ? `${cur}. ${text}` : text
}

const form = reactive({
  code: '', name: '', modality_type: '', body_region: '', default_protocol: '',
  prep_instructions: '', estimated_duration_minutes: 30, price: 0, contrast_required: false, is_active: true,
})

// Completeness
const completeness = computed(() => {
  let score = 0
  if (form.code) score += 20
  if (form.name) score += 20
  if (form.modality_type) score += 20
  if (form.body_region) score += 10
  if (form.price > 0) score += 10
  if (form.default_protocol) score += 10
  if (form.prep_instructions) score += 10
  return score
})
const completenessLabel = computed(() => {
  if (completeness.value === 100) return 'All fields complete'
  const missing = []
  if (!form.code) missing.push('code')
  if (!form.name) missing.push('name')
  if (!form.modality_type) missing.push('modality')
  if (!form.body_region) missing.push('body region')
  if (!form.price) missing.push('price')
  return `Missing: ${missing.join(', ')}`
})

onMounted(async () => {
  try {
    const res = await $api.get('/radiology/exam-catalog/?page_size=500&ordering=name')
    existingExams.value = res.data?.results || res.data || []
  } catch { existingExams.value = [] }
})

async function submit() {
  if (!form.modality_type) { snackMsg.value = 'Select a modality type'; snackColor.value = 'error'; snack.value = true; return }
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await $api.post('/radiology/exam-catalog/', form)
    snackMsg.value = 'Exam created'; snackColor.value = 'success'; snack.value = true
    setTimeout(() => router.push('/radiology/catalog'), 400)
  } catch (e) {
    snackMsg.value = e?.response?.data?.detail || 'Save failed'; snackColor.value = 'error'; snack.value = true
  }
  saving.value = false
}
</script>

<style scoped>
.hero-header {
  background: linear-gradient(135deg, rgb(var(--v-theme-primary)) 0%, #7c4dff 100%);
}
.section-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.section-header { background: rgba(var(--v-theme-on-surface), 0.02); border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.modality-palette { background: linear-gradient(135deg, rgba(103,58,183,0.04) 0%, rgba(81,45,168,0.02) 100%); border: 1px solid rgba(103,58,183,0.10); }
.body-palette { background: linear-gradient(135deg, rgba(63,81,181,0.04) 0%, rgba(48,63,159,0.02) 100%); border: 1px solid rgba(63,81,181,0.10); }
.modality-chip { cursor: pointer; transition: all 0.18s ease; font-weight: 500; }
.modality-chip:hover { transform: translateY(-2px); box-shadow: 0 3px 10px rgba(0,0,0,0.10); }
.modality-chip--active { box-shadow: 0 3px 12px rgba(0,0,0,0.15); transform: translateY(-1px); }
.body-chip { cursor: pointer; transition: all 0.15s ease; }
.body-chip:hover { transform: translateY(-1px); box-shadow: 0 2px 6px rgba(0,0,0,0.08); }
.chip-palette { background: linear-gradient(135deg, rgba(63,81,181,0.06) 0%, rgba(92,107,192,0.03) 100%); border: 1px solid rgba(63,81,181,0.12); }
.chip-palette--prep { background: linear-gradient(135deg, rgba(0,150,136,0.06) 0%, rgba(38,166,154,0.03) 100%); border-color: rgba(0,150,136,0.12); }
.quick-chip { cursor: pointer; transition: all 0.12s ease; }
.quick-chip:hover { transform: translateY(-1px); box-shadow: 0 2px 6px rgba(0,0,0,0.12); }
.contrast-toggle { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); transition: all 0.2s ease; }
.contrast-toggle--on { border-color: rgb(var(--v-theme-warning)); background: rgba(var(--v-theme-warning), 0.04); }
.sticky-preview { position: sticky; top: 80px; }
.preview-header { background: linear-gradient(135deg, rgb(var(--v-theme-primary)) 0%, #7c4dff 100%); }
.preview-code { background: rgba(var(--v-theme-primary), 0.08); color: rgb(var(--v-theme-primary)); font-size: 0.8rem; letter-spacing: 0.5px; }
.preview-text { background: rgba(var(--v-theme-on-surface), 0.03); line-height: 1.5; word-break: break-word; }
</style>
