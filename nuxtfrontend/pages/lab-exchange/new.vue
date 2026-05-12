<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn icon="mdi-arrow-left" variant="text" @click="$router.push('/lab-exchange')" />
      <v-avatar color="indigo-lighten-5" size="44">
        <v-icon color="indigo-darken-2">mdi-swap-horizontal-bold</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">New Lab Exchange Request</div>
        <div class="text-body-2 text-medium-emphasis">
          Send a test order to a partner laboratory
        </div>
      </div>
      <v-spacer />
      <v-btn variant="text" @click="$router.push('/lab-exchange')">Cancel</v-btn>
      <v-btn color="primary" rounded="lg" :loading="saving" :disabled="!canSubmit"
             prepend-icon="mdi-send" @click="submit">Send request</v-btn>
    </div>

    <v-row>
      <v-col cols="12" md="8">
        <!-- Patient -->
        <v-card flat rounded="lg" class="pa-4 mb-3">
          <div class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-account</v-icon>
            Patient
          </div>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.patient_name" label="Patient name *"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.patient_phone" label="Phone"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-phone" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.patient_user_id" label="Patient user ID"
                            variant="outlined" density="comfortable" type="number"
                            hint="Internal user ID for cross-schema reference" persistent-hint />
            </v-col>
          </v-row>
        </v-card>

        <!-- Tests -->
        <v-card flat rounded="lg" class="pa-4 mb-3">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-flask-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Tests</div>
            <v-spacer />
            <v-btn variant="tonal" color="primary" size="small" rounded="lg"
                   prepend-icon="mdi-plus" @click="addTest()">Add test</v-btn>
          </div>
          <div v-if="!form.tests.length" class="pa-6 text-center text-medium-emphasis">
            <v-icon size="40" color="grey-lighten-1">mdi-flask-empty-outline</v-icon>
            <div class="text-body-2 mt-1">No tests added yet.</div>
            <v-btn class="mt-3" color="primary" variant="tonal" rounded="lg"
                   prepend-icon="mdi-plus" @click="addTest()">Add your first test</v-btn>
          </div>
          <div v-else>
            <v-card v-for="(t, i) in form.tests" :key="i" flat
                    class="test-row pa-3 mb-2" rounded="lg">
              <v-row dense align="center">
                <v-col cols="12" md="4">
                  <v-text-field v-model="t.test_name" label="Test name *"
                                variant="outlined" density="compact" hide-details />
                </v-col>
                <v-col cols="6" md="2">
                  <v-text-field v-model="t.code" label="Code"
                                variant="outlined" density="compact" hide-details />
                </v-col>
                <v-col cols="6" md="3">
                  <v-combobox v-model="t.specimen_type" :items="specimenTypes" label="Specimen"
                              variant="outlined" density="compact" hide-details />
                </v-col>
                <v-col cols="11" md="2">
                  <v-text-field v-model="t.instructions" label="Instructions"
                                variant="outlined" density="compact" hide-details />
                </v-col>
                <v-col cols="1" class="text-right">
                  <v-btn icon="mdi-close" variant="text" size="small" @click="removeTest(i)" />
                </v-col>
              </v-row>
            </v-card>
          </div>
        </v-card>

        <!-- Clinical -->
        <v-card flat rounded="lg" class="pa-4">
          <div class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-stethoscope</v-icon>
            Clinical & logistics
          </div>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.priority" :items="priorities" label="Priority"
                        variant="outlined" density="comfortable">
                <template #selection="{ item }">
                  <v-chip size="small" variant="flat" :color="item.raw.color"
                          class="text-capitalize text-white">
                    <v-icon size="14" start>{{ item.raw.icon }}</v-icon>{{ item.raw.title }}
                  </v-chip>
                </template>
              </v-select>
            </v-col>
            <v-col cols="12" md="6">
              <v-card flat class="pa-3 collection-card h-100" rounded="lg">
                <div class="d-flex align-center">
                  <v-icon :color="form.is_home_collection ? 'teal-darken-2' : 'indigo-darken-2'"
                          size="28" class="mr-3">
                    {{ form.is_home_collection ? 'mdi-home-import-outline' : 'mdi-hospital-building' }}
                  </v-icon>
                  <div class="flex-grow-1">
                    <div class="font-weight-medium">
                      {{ form.is_home_collection ? 'Home collection' : 'In-lab collection' }}
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      {{ form.is_home_collection ? 'Lab phlebotomist visits patient' : 'Patient visits the lab' }}
                    </div>
                  </div>
                  <v-switch v-model="form.is_home_collection" color="teal" inset
                            hide-details density="compact" />
                </div>
              </v-card>
            </v-col>
            <v-col v-if="form.is_home_collection" cols="12">
              <v-textarea v-model="form.collection_address" rows="2" auto-grow
                          label="Collection address"
                          prepend-inner-icon="mdi-map-marker-outline"
                          variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.clinical_notes" rows="3" auto-grow
                          label="Clinical notes / relevant history"
                          variant="outlined" density="comfortable"
                          prepend-inner-icon="mdi-note-text-outline" />
            </v-col>
          </v-row>
        </v-card>
      </v-col>

      <!-- Sidebar summary -->
      <v-col cols="12" md="4">
        <v-card flat rounded="lg" class="pa-4 summary-card">
          <div class="d-flex align-center mb-3">
            <v-icon color="indigo-darken-2" class="mr-2">mdi-clipboard-check-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Request summary</div>
          </div>
          <div class="text-overline text-medium-emphasis">Patient</div>
          <div class="font-weight-medium mb-2">{{ form.patient_name || '—' }}</div>
          <div class="text-overline text-medium-emphasis">Tests</div>
          <div v-if="form.tests.length" class="d-flex flex-wrap ga-1 mb-3">
            <v-chip v-for="(t, i) in form.tests" :key="i" size="x-small" variant="tonal" color="indigo">
              {{ t.test_name || `Test ${i + 1}` }}
            </v-chip>
          </div>
          <div v-else class="text-body-2 text-medium-emphasis mb-3">No tests added</div>

          <div class="text-overline text-medium-emphasis">Priority</div>
          <v-chip size="small" variant="flat"
                  :color="priorityMeta(form.priority).color" class="text-capitalize text-white mb-3">
            <v-icon size="14" start>{{ priorityMeta(form.priority).icon }}</v-icon>{{ form.priority }}
          </v-chip>

          <div class="text-overline text-medium-emphasis">Collection</div>
          <div class="text-body-2 mb-3">
            {{ form.is_home_collection ? 'Home collection' : 'In-lab' }}
          </div>

          <v-alert v-if="!canSubmit" type="info" variant="tonal" density="compact">
            Add a patient name and at least one test to submit.
          </v-alert>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()

const saving = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  patient_name: '',
  patient_phone: '',
  patient_user_id: null,
  tests: [],
  priority: 'routine',
  clinical_notes: '',
  is_home_collection: false,
  collection_address: '',
})

const priorities = [
  { title: 'Routine', value: 'routine', color: 'grey-darken-1', icon: 'mdi-clock-outline' },
  { title: 'Urgent', value: 'urgent', color: 'orange-darken-2', icon: 'mdi-alert' },
  { title: 'STAT', value: 'stat', color: 'red-darken-2', icon: 'mdi-flash' },
]
const specimenTypes = ['Blood', 'Serum', 'Plasma', 'Urine', 'Stool', 'Sputum', 'Swab', 'Tissue', 'CSF']

function priorityMeta(v) {
  return priorities.find(p => p.value === v) || priorities[0]
}

function addTest() {
  form.tests.push({ test_name: '', code: '', specimen_type: '', instructions: '' })
}
function removeTest(i) {
  form.tests.splice(i, 1)
}

const canSubmit = computed(() =>
  !!form.patient_name?.trim()
  && form.tests.length > 0
  && form.tests.every(t => (t.test_name || '').trim())
)

async function submit() {
  if (!canSubmit.value) return
  saving.value = true
  try {
    const payload = {
      patient_name: form.patient_name.trim(),
      patient_phone: form.patient_phone || '',
      patient_user_id: form.patient_user_id || 0,
      tests: form.tests.map(t => ({
        test_name: t.test_name.trim(),
        code: t.code || '',
        specimen_type: t.specimen_type || '',
        instructions: t.instructions || '',
      })),
      priority: form.priority,
      clinical_notes: form.clinical_notes || '',
      is_home_collection: form.is_home_collection,
      collection_address: form.collection_address || '',
    }
    const { data } = await $api.post('/exchange/lab/', payload)
    snack.text = `Request LX-${String(data.id).padStart(5, '0')} sent`
    snack.color = 'success'
    snack.show = true
    setTimeout(() => router.push(`/lab-exchange/${data.id}`), 600)
  } catch (e) {
    const detail = e?.response?.data?.detail
      || (typeof e?.response?.data === 'object' ? Object.values(e.response.data).flat().join(' ') : '')
      || 'Failed to send request'
    snack.text = detail
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.test-row { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
.collection-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.summary-card {
  position: sticky;
  top: 16px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
</style>
