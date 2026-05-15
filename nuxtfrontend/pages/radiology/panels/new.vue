<template>
  <v-container fluid class="pa-4 pa-md-6">
    <v-row>
      <!-- Main form -->
      <v-col cols="12" md="8">
        <!-- Header -->
        <div class="hero-header pa-5 rounded-xl mb-5">
          <div class="d-flex align-center ga-3">
            <v-btn icon="mdi-arrow-left" variant="text" color="white" to="/radiology/panels" />
            <v-avatar size="48" color="rgba(255,255,255,0.15)">
              <v-icon color="white" size="26">mdi-package-variant-plus</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold text-white">New Exam Panel</div>
              <div class="text-body-2" style="color:rgba(255,255,255,0.75)">Bundle multiple exams into one package</div>
            </div>
          </div>
        </div>

        <v-form ref="formRef" @submit.prevent="submit">

          <!-- STEP 1: Panel Details -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" color="primary" class="text-white text-caption font-weight-bold">1</v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Panel Details</div>
                  <div class="text-caption text-medium-emphasis">Name, pricing &amp; description</div>
                </div>
              </div>
            </div>
            <div class="pa-5">
              <v-row dense>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="form.name" label="Panel Name *" :rules="req" variant="outlined"
                    density="compact" rounded="lg" prepend-inner-icon="mdi-tag"
                    hint="e.g. Trauma Panel, Cardiac Workup" persistent-hint />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field v-model.number="form.price" label="Bundle Price" type="number" prefix="KSh"
                    variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-cash"
                    hint="Override price (usually discounted)" persistent-hint />
                </v-col>
                <v-col cols="12">
                  <v-textarea v-model="form.description" label="Description" rows="2" auto-grow
                    variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-text" />
                </v-col>
              </v-row>
            </div>
          </v-card>

          <!-- STEP 2: Exam Selection -->
          <v-card flat rounded="xl" class="mb-4 section-card overflow-hidden">
            <div class="section-header px-5 py-3">
              <div class="d-flex align-center ga-3">
                <v-avatar size="28" :color="form.exam_ids.length ? 'success' : 'primary'" class="text-white text-caption font-weight-bold">
                  <v-icon v-if="form.exam_ids.length" size="16">mdi-check</v-icon>
                  <span v-else>2</span>
                </v-avatar>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Included Exams <span class="text-error">*</span></div>
                  <div class="text-caption text-medium-emphasis">Select exams to bundle in this panel</div>
                </div>
                <v-spacer />
                <v-chip v-if="form.exam_ids.length" size="small" variant="tonal" color="indigo">
                  {{ form.exam_ids.length }} selected
                </v-chip>
              </div>
            </div>
            <div class="pa-5">
              <v-autocomplete v-model="form.exam_ids" :items="exams" item-title="name" item-value="id"
                label="Search & select exams" multiple chips closable-chips variant="outlined" density="compact" rounded="lg"
                prepend-inner-icon="mdi-magnify" :rules="[v => v.length > 0 || 'Select at least one exam']">
                <template #chip="{ props, item }">
                  <v-chip v-bind="props" variant="tonal" color="indigo" size="small">
                    <v-icon start size="14">mdi-flask</v-icon>{{ item.title }}
                  </v-chip>
                </template>
                <template #item="{ props: itemProps, item }">
                  <v-list-item v-bind="itemProps">
                    <template #prepend>
                      <v-icon size="18" color="indigo">mdi-flask-outline</v-icon>
                    </template>
                    <template #append>
                      <span class="text-caption font-weight-medium">{{ fmtMoney(item.raw?.price) }}</span>
                    </template>
                  </v-list-item>
                </template>
              </v-autocomplete>

              <!-- Price comparison -->
              <v-expand-transition>
                <div v-if="form.exam_ids.length" class="savings-card pa-4 rounded-xl mt-3">
                  <div class="d-flex align-center ga-2 mb-3">
                    <v-icon size="18" color="success">mdi-sale</v-icon>
                    <span class="text-subtitle-2 font-weight-bold">Price Comparison</span>
                  </div>
                  <div class="d-flex justify-space-between mb-1">
                    <span class="text-body-2">Individual total ({{ form.exam_ids.length }} exams)</span>
                    <span class="text-body-2 font-weight-bold">{{ fmtMoney(individualTotal) }}</span>
                  </div>
                  <div class="d-flex justify-space-between mb-1">
                    <span class="text-body-2">Bundle price</span>
                    <span class="text-body-2 font-weight-bold" :class="savings > 0 ? 'text-success' : ''">{{ fmtMoney(form.price) }}</span>
                  </div>
                  <v-divider class="my-2" />
                  <div class="d-flex justify-space-between align-center">
                    <span class="text-body-2 font-weight-bold">Patient Savings</span>
                    <v-chip :color="savings > 0 ? 'success' : 'grey'" variant="tonal" size="small">
                      <v-icon start size="14">{{ savings > 0 ? 'mdi-arrow-down' : 'mdi-minus' }}</v-icon>
                      {{ fmtMoney(savings) }} ({{ savingsPct }}%)
                    </v-chip>
                  </div>
                </div>
              </v-expand-transition>
            </div>
          </v-card>

          <!-- Status & Submit -->
          <v-card flat rounded="xl" class="pa-5 mb-4 section-card">
            <div class="d-flex align-center justify-space-between flex-wrap ga-3">
              <div class="d-flex align-center ga-3">
                <v-switch v-model="form.is_active" color="success" hide-details density="compact" />
                <div>
                  <div class="text-body-2 font-weight-medium">{{ form.is_active ? 'Active' : 'Inactive' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ form.is_active ? 'Available for ordering' : 'Hidden from orders' }}</div>
                </div>
              </div>
              <div class="d-flex ga-2">
                <v-btn variant="outlined" rounded="lg" class="text-none" to="/radiology/panels">Cancel</v-btn>
                <v-btn type="submit" color="primary" rounded="lg" class="text-none" :loading="saving" size="large"
                       prepend-icon="mdi-content-save">Save Panel</v-btn>
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
              <div class="d-flex align-center justify-space-between mb-3">
                <div class="text-subtitle-1 font-weight-bold">{{ form.name || 'Panel Name' }}</div>
                <v-chip size="x-small" :color="form.is_active ? 'success' : 'grey'" variant="tonal">
                  {{ form.is_active ? 'Active' : 'Inactive' }}
                </v-chip>
              </div>

              <div v-if="form.description" class="text-body-2 text-medium-emphasis mb-3">{{ form.description }}</div>

              <!-- Selected exams -->
              <div class="text-caption font-weight-bold text-uppercase mb-2">
                <v-icon size="12" class="mr-1">mdi-flask-outline</v-icon>
                Included Exams ({{ selectedExams.length }})
              </div>
              <div v-if="selectedExams.length" class="d-flex flex-wrap ga-1 mb-3">
                <v-chip v-for="e in selectedExams.slice(0, 8)" :key="e.id" size="x-small" variant="tonal" color="indigo">{{ e.name }}</v-chip>
                <v-chip v-if="selectedExams.length > 8" size="x-small" variant="flat" color="indigo-lighten-4">+{{ selectedExams.length - 8 }} more</v-chip>
              </div>
              <div v-else class="text-caption text-medium-emphasis text-italic mb-3">No exams selected</div>

              <v-divider class="mb-3" />

              <!-- Price -->
              <div class="d-flex ga-4 mb-3">
                <div>
                  <div class="text-caption text-medium-emphasis">Bundle Price</div>
                  <div class="text-body-2 font-weight-bold text-primary">{{ fmtMoney(form.price) }}</div>
                </div>
                <div v-if="form.exam_ids.length">
                  <div class="text-caption text-medium-emphasis">Individual Total</div>
                  <div class="text-body-2 font-weight-bold text-decoration-line-through text-medium-emphasis">{{ fmtMoney(individualTotal) }}</div>
                </div>
              </div>

              <!-- Completeness -->
              <v-divider class="mb-3" />
              <div class="d-flex align-center ga-2 mb-1">
                <v-progress-linear :model-value="completeness" :color="completeness === 100 ? 'success' : 'primary'" rounded height="6" />
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
const req = [v => !!v || 'Required']
const exams = ref([])
const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')
const form = reactive({ name: '', description: '', price: 0, exam_ids: [], is_active: true })

const selectedExams = computed(() => form.exam_ids.map(id => exams.value.find(e => e.id === id)).filter(Boolean))
const individualTotal = computed(() => selectedExams.value.reduce((s, e) => s + Number(e.price || 0), 0))
const savings = computed(() => individualTotal.value - (form.price || 0))
const savingsPct = computed(() => individualTotal.value ? Math.round((savings.value / individualTotal.value) * 100) : 0)
function fmtMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }

const completeness = computed(() => {
  let score = 0
  if (form.name) score += 30
  if (form.exam_ids.length) score += 40
  if (form.price > 0) score += 20
  if (form.description) score += 10
  return score
})
const completenessLabel = computed(() => {
  if (completeness.value === 100) return 'All fields complete'
  const m = []
  if (!form.name) m.push('name')
  if (!form.exam_ids.length) m.push('exams')
  if (!form.price) m.push('price')
  return `Missing: ${m.join(', ')}`
})

onMounted(async () => {
  try {
    const res = await $api.get('/radiology/exam-catalog/?page_size=500&is_active=true&ordering=name')
    exams.value = res.data?.results || res.data || []
  } catch { exams.value = [] }
})

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await $api.post('/radiology/exam-panels/', form)
    snackMsg.value = 'Panel created'; snackColor.value = 'success'; snack.value = true
    setTimeout(() => router.push('/radiology/panels'), 400)
  } catch (e) {
    snackMsg.value = e?.response?.data?.detail || 'Save failed'; snackColor.value = 'error'; snack.value = true
  }
  saving.value = false
}
</script>

<style scoped>
.hero-header { background: linear-gradient(135deg, rgb(var(--v-theme-primary)) 0%, #7c4dff 100%); }
.section-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.section-header { background: rgba(var(--v-theme-on-surface), 0.02); border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.savings-card { background: linear-gradient(135deg, rgba(76,175,80,0.05) 0%, rgba(56,142,60,0.02) 100%); border: 1px solid rgba(76,175,80,0.12); }
.sticky-preview { position: sticky; top: 80px; }
.preview-header { background: linear-gradient(135deg, rgb(var(--v-theme-primary)) 0%, #7c4dff 100%); }
</style>
