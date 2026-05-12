<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1400px">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn icon="mdi-arrow-left" variant="text" @click="$router.push('/lab/requisitions')" />
      <v-avatar color="indigo-lighten-5" size="44">
        <v-icon color="indigo-darken-2">mdi-clipboard-text-clock</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">New Lab Requisition</div>
        <div class="text-body-2 text-medium-emphasis">
          Register a test request and queue it for the laboratory
        </div>
      </div>
      <v-spacer />
      <v-btn variant="text" @click="$router.push('/lab/requisitions')">Cancel</v-btn>
      <v-btn color="primary" rounded="lg" :loading="saving" :disabled="!canSubmit"
             prepend-icon="mdi-check" @click="submit">Create Requisition</v-btn>
    </div>

    <!-- Stepper -->
    <v-card flat rounded="lg" class="mb-4 pa-2">
      <v-stepper v-model="step" alt-labels flat hide-actions class="bg-transparent">
        <v-stepper-header>
          <v-stepper-item :value="1" :complete="step > 1" title="Patient" subtitle="Who is being tested" />
          <v-divider />
          <v-stepper-item :value="2" :complete="step > 2" title="Tests" subtitle="Pick tests & panels"
                          :error="step > 2 && cart.length === 0 ? 'Required' : undefined" />
          <v-divider />
          <v-stepper-item :value="3" :complete="step > 3" title="Clinical" subtitle="Referral & notes" />
          <v-divider />
          <v-stepper-item :value="4" title="Review" subtitle="Confirm & submit" />
        </v-stepper-header>
      </v-stepper>
    </v-card>

    <v-row>
      <!-- Main content -->
      <v-col cols="12" md="8">
        <!-- STEP 1: Patient -->
        <v-card v-show="step === 1" flat rounded="lg" class="pa-4">
          <div class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-account-search</v-icon>
            Select patient
          </div>
          <v-autocomplete
            v-model="form.patient"
            :items="patients"
            item-title="display"
            item-value="id"
            label="Search patient by name, ID or phone *"
            variant="outlined" density="comfortable"
            :loading="patientsLoading"
            return-object
            @update:model-value="onPatientPicked"
          >
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :title="item.raw.display" :subtitle="item.raw.subtitle">
                <template #prepend>
                  <v-avatar :color="hashColor(item.raw.id)" size="36">
                    <span class="text-white font-weight-bold">{{ initials(item.raw.fullName) }}</span>
                  </v-avatar>
                </template>
              </v-list-item>
            </template>
          </v-autocomplete>

          <v-alert v-if="!form.patient" type="info" variant="tonal" density="compact" class="mt-3">
            Tip: start typing the patient's name. Need to register a new patient?
            <NuxtLink to="/patients/new" class="ml-1">Add patient</NuxtLink>.
          </v-alert>

          <v-card v-if="selectedPatient" flat class="mt-4 pa-3 patient-summary">
            <div class="d-flex align-center">
              <v-avatar :color="hashColor(selectedPatient.id)" size="52" class="mr-3">
                <span class="text-white text-h6 font-weight-bold">
                  {{ initials(selectedPatient.fullName) }}
                </span>
              </v-avatar>
              <div class="flex-grow-1">
                <div class="text-h6 font-weight-bold">{{ selectedPatient.fullName || '—' }}</div>
                <div class="text-caption text-medium-emphasis">
                  <span class="font-monospace">{{ selectedPatient.patient_number || selectedPatient.patient_id || '—' }}</span>
                  <span v-if="selectedPatient.gender"> · <span class="text-capitalize">{{ selectedPatient.gender }}</span></span>
                  <span v-if="selectedPatient.date_of_birth"> · {{ ageOf(selectedPatient.date_of_birth) }} yrs</span>
                  <span v-if="selectedPatient.blood_type"> · Blood {{ selectedPatient.blood_type }}</span>
                </div>
              </div>
              <v-chip v-if="selectedPatient.insurance_provider" size="small" variant="tonal" color="green">
                <v-icon size="14" start>mdi-shield-check</v-icon>{{ selectedPatient.insurance_provider }}
              </v-chip>
            </div>
            <v-divider class="my-3" />
            <v-row dense>
              <v-col v-if="selectedPatient.user?.phone" cols="12" sm="6">
                <v-icon size="14" class="mr-1" color="medium-emphasis">mdi-phone</v-icon>
                {{ selectedPatient.user.phone }}
              </v-col>
              <v-col v-if="selectedPatient.user_email || selectedPatient.user?.email" cols="12" sm="6">
                <v-icon size="14" class="mr-1" color="medium-emphasis">mdi-email</v-icon>
                {{ selectedPatient.user_email || selectedPatient.user?.email }}
              </v-col>
              <v-col v-if="(selectedPatient.allergies || []).length" cols="12">
                <v-icon size="14" class="mr-1" color="red-darken-2">mdi-alert-circle</v-icon>
                <b>Allergies:</b> {{ selectedPatient.allergies.join(', ') }}
              </v-col>
              <v-col v-if="(selectedPatient.chronic_conditions || []).length" cols="12">
                <v-icon size="14" class="mr-1" color="amber-darken-3">mdi-pulse</v-icon>
                <b>Chronic:</b> {{ selectedPatient.chronic_conditions.join(', ') }}
              </v-col>
            </v-row>
          </v-card>

          <div class="d-flex justify-end mt-4">
            <v-btn color="primary" rounded="lg" :disabled="!form.patient" @click="step = 2">
              Next: Tests <v-icon end>mdi-arrow-right</v-icon>
            </v-btn>
          </div>
        </v-card>

        <!-- STEP 2: Tests -->
        <v-card v-show="step === 2" flat rounded="lg" class="pa-4">
          <div class="d-flex align-center mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-flask-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Tests & panels</div>
            <v-spacer />
            <v-btn-toggle v-model="catalogTab" mandatory density="compact" rounded="lg" color="primary">
              <v-btn value="tests" size="small">Tests</v-btn>
              <v-btn value="panels" size="small">Panels</v-btn>
            </v-btn-toggle>
          </div>

          <v-text-field
            v-model="catalogSearch"
            prepend-inner-icon="mdi-magnify"
            :placeholder="catalogTab === 'tests' ? 'Search tests by name or code…' : 'Search panels…'"
            variant="outlined" density="compact" hide-details clearable class="mb-3"
          />

          <!-- Departments quick filter -->
          <div v-if="catalogTab === 'tests' && departments.length" class="d-flex flex-wrap ga-1 mb-3">
            <v-chip
              :color="!deptFilter ? 'primary' : undefined"
              :variant="!deptFilter ? 'flat' : 'tonal'"
              size="x-small" @click="deptFilter = null"
            >All</v-chip>
            <v-chip
              v-for="d in departments" :key="d"
              :color="deptFilter === d ? 'primary' : undefined"
              :variant="deptFilter === d ? 'flat' : 'tonal'"
              size="x-small" @click="deptFilter = d"
            >{{ d }}</v-chip>
          </div>

          <!-- Test grid -->
          <div v-if="catalogTab === 'tests'" class="catalog-grid">
            <v-card
              v-for="t in filteredCatalog" :key="t.id"
              flat rounded="lg" hover class="test-tile pa-3"
              :class="{ 'is-picked': pickedTestIds.has(t.id) }"
              @click="toggleTest(t)"
            >
              <div class="d-flex align-start">
                <v-icon size="20" :color="pickedTestIds.has(t.id) ? 'primary' : 'grey-lighten-1'">
                  {{ pickedTestIds.has(t.id) ? 'mdi-checkbox-marked' : 'mdi-checkbox-blank-outline' }}
                </v-icon>
                <div class="ml-2 flex-grow-1 min-width-0">
                  <div class="font-weight-medium text-truncate">{{ t.name }}</div>
                  <div class="text-caption text-medium-emphasis">
                    <span class="font-monospace">{{ t.code }}</span>
                    <span v-if="t.department"> · {{ t.department }}</span>
                  </div>
                  <div class="text-caption text-medium-emphasis mt-1">
                    <v-icon size="12">mdi-test-tube</v-icon> {{ t.specimen_type || '—' }}
                    <span v-if="t.turnaround_time" class="ml-2">
                      <v-icon size="12">mdi-clock-outline</v-icon> {{ t.turnaround_time }}
                    </span>
                  </div>
                </div>
                <div class="text-right">
                  <div class="font-weight-bold">{{ formatMoney(t.price) }}</div>
                </div>
              </div>
            </v-card>
            <div v-if="!filteredCatalog.length" class="pa-6 text-center text-medium-emphasis">
              No tests match your search.
            </div>
          </div>

          <!-- Panel grid -->
          <div v-else class="catalog-grid">
            <v-card
              v-for="p in filteredPanels" :key="p.id"
              flat rounded="lg" hover class="test-tile pa-3"
              :class="{ 'is-picked': pickedPanelIds.has(p.id) }"
              @click="togglePanel(p)"
            >
              <div class="d-flex align-start">
                <v-icon size="20" :color="pickedPanelIds.has(p.id) ? 'primary' : 'grey-lighten-1'">
                  {{ pickedPanelIds.has(p.id) ? 'mdi-checkbox-marked' : 'mdi-checkbox-blank-outline' }}
                </v-icon>
                <div class="ml-2 flex-grow-1 min-width-0">
                  <div class="font-weight-medium text-truncate">
                    <v-icon size="14" color="indigo-darken-2" class="mr-1">mdi-package-variant</v-icon>
                    {{ p.name }}
                  </div>
                  <div class="text-caption text-medium-emphasis">
                    <span class="font-monospace">{{ p.code }}</span>
                    <span v-if="p.department"> · {{ p.department }}</span>
                  </div>
                  <div class="text-caption mt-1">
                    {{ (p.test_names || []).slice(0, 4).join(', ') }}
                    <span v-if="(p.test_names || []).length > 4">
                      +{{ p.test_names.length - 4 }} more
                    </span>
                  </div>
                </div>
                <div class="text-right">
                  <div class="font-weight-bold">{{ formatMoney(p.price) }}</div>
                  <div class="text-caption text-medium-emphasis">
                    {{ (p.tests || []).length }} tests
                  </div>
                </div>
              </div>
            </v-card>
            <div v-if="!filteredPanels.length" class="pa-6 text-center text-medium-emphasis">
              No panels match your search.
            </div>
          </div>

          <div class="d-flex justify-space-between mt-4">
            <v-btn variant="text" @click="step = 1">
              <v-icon start>mdi-arrow-left</v-icon>Back
            </v-btn>
            <v-btn color="primary" rounded="lg" :disabled="cart.length === 0" @click="step = 3">
              Next: Clinical <v-icon end>mdi-arrow-right</v-icon>
            </v-btn>
          </div>
        </v-card>

        <!-- STEP 3: Clinical -->
        <v-card v-show="step === 3" flat rounded="lg" class="pa-4">
          <div class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-stethoscope</v-icon>
            Clinical & referral
          </div>

          <v-row dense>
            <v-col cols="12" md="6">
              <v-select
                v-model="form.priority" :items="priorityItems"
                label="Priority" variant="outlined" density="comfortable"
              >
                <template #selection="{ item }">
                  <v-chip size="small" variant="flat" :color="item.raw.color"
                          class="text-capitalize text-white">
                    <v-icon size="14" start>{{ item.raw.icon }}</v-icon>{{ item.raw.title }}
                  </v-chip>
                </template>
              </v-select>
            </v-col>
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="pa-3 collection-card h-100">
                <div class="d-flex align-center">
                  <v-icon :color="form.is_home_collection ? 'teal-darken-2' : 'indigo-darken-2'" size="28" class="mr-3">
                    {{ form.is_home_collection ? 'mdi-home-import-outline' : 'mdi-hospital-building' }}
                  </v-icon>
                  <div class="flex-grow-1">
                    <div class="font-weight-medium">
                      {{ form.is_home_collection ? 'Home collection' : 'In-lab collection' }}
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      {{ form.is_home_collection ? 'A phlebotomist will visit the patient' : 'Patient comes to the lab' }}
                    </div>
                  </div>
                  <v-switch v-model="form.is_home_collection" color="teal" inset hide-details density="compact" />
                </div>
              </v-card>
            </v-col>

            <v-col cols="12" md="6">
              <v-autocomplete
                v-model="extra.referring_doctor" :items="refDoctors"
                item-title="full_name" item-value="id"
                label="Referring doctor" variant="outlined" density="comfortable"
                clearable prepend-inner-icon="mdi-doctor"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-autocomplete
                v-model="extra.referring_facility" :items="refFacilities"
                item-title="name" item-value="id"
                label="Referring facility" variant="outlined" density="comfortable"
                clearable prepend-inner-icon="mdi-hospital-building"
              />
            </v-col>

            <v-col cols="12" md="6">
              <v-select
                v-model="extra.payer_type" :items="payers"
                label="Payer" variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-cash-multiple"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="form.next_collection_date" type="date"
                label="Schedule for (optional)" variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-calendar-clock"
              />
            </v-col>

            <v-col cols="12">
              <v-textarea
                v-model="form.clinical_notes" rows="3" auto-grow
                label="Clinical notes / relevant history"
                placeholder="e.g., Suspected anemia, on iron supplementation 4 weeks…"
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-note-text-outline"
              />
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="extra.notes_for_lab" rows="2" auto-grow
                label="Notes for the lab (handling, urgency, etc.)"
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-information-outline"
              />
            </v-col>
          </v-row>

          <div class="d-flex justify-space-between mt-2">
            <v-btn variant="text" @click="step = 2">
              <v-icon start>mdi-arrow-left</v-icon>Back
            </v-btn>
            <v-btn color="primary" rounded="lg" @click="step = 4">
              Next: Review <v-icon end>mdi-arrow-right</v-icon>
            </v-btn>
          </div>
        </v-card>

        <!-- STEP 4: Review -->
        <v-card v-show="step === 4" flat rounded="lg" class="pa-4">
          <div class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon class="mr-2" color="indigo-darken-2">mdi-clipboard-check-outline</v-icon>
            Review & submit
          </div>

          <v-card flat rounded="lg" class="patient-summary pa-3 mb-3">
            <div class="text-overline text-medium-emphasis">Patient</div>
            <div class="d-flex align-center">
              <v-avatar :color="hashColor(selectedPatient?.id || 0)" size="40" class="mr-3">
                <span class="text-white font-weight-bold">{{ initials(selectedPatient?.fullName) }}</span>
              </v-avatar>
              <div>
                <div class="font-weight-bold">{{ selectedPatient?.fullName || '—' }}</div>
                <div class="text-caption text-medium-emphasis font-monospace">
                  {{ selectedPatient?.patient_number || selectedPatient?.patient_id || '—' }}
                </div>
              </div>
            </div>
          </v-card>

          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="text-overline text-medium-emphasis">Priority</div>
              <v-chip size="small" variant="flat" :color="PRIORITY_META[form.priority]?.color"
                      class="text-capitalize text-white">
                <v-icon size="14" start>{{ PRIORITY_META[form.priority]?.icon }}</v-icon>{{ form.priority }}
              </v-chip>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-overline text-medium-emphasis">Collection</div>
              <v-chip size="small" variant="tonal"
                      :color="form.is_home_collection ? 'teal' : 'indigo'">
                <v-icon size="14" start>
                  {{ form.is_home_collection ? 'mdi-home-import-outline' : 'mdi-hospital-building' }}
                </v-icon>
                {{ form.is_home_collection ? 'Home collection' : 'In-lab' }}
              </v-chip>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-overline text-medium-emphasis">Referring doctor</div>
              <div>{{ refDoctorName || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-overline text-medium-emphasis">Referring facility</div>
              <div>{{ refFacilityName || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-overline text-medium-emphasis">Payer</div>
              <div class="text-capitalize">{{ extra.payer_type }}</div>
            </v-col>
            <v-col v-if="form.next_collection_date" cols="12" sm="6">
              <div class="text-overline text-medium-emphasis">Scheduled</div>
              <div>{{ form.next_collection_date }}</div>
            </v-col>
            <v-col v-if="form.clinical_notes" cols="12">
              <div class="text-overline text-medium-emphasis">Clinical notes</div>
              <div class="text-body-2">{{ form.clinical_notes }}</div>
            </v-col>
            <v-col v-if="extra.notes_for_lab" cols="12">
              <div class="text-overline text-medium-emphasis">Notes for lab</div>
              <div class="text-body-2">{{ extra.notes_for_lab }}</div>
            </v-col>
          </v-row>

          <div class="d-flex justify-space-between mt-4">
            <v-btn variant="text" @click="step = 3">
              <v-icon start>mdi-arrow-left</v-icon>Back
            </v-btn>
            <v-btn color="primary" rounded="lg" :loading="saving" :disabled="!canSubmit"
                   prepend-icon="mdi-check" @click="submit">
              Create Requisition
            </v-btn>
          </div>
        </v-card>
      </v-col>

      <!-- Sticky cart -->
      <v-col cols="12" md="4">
        <v-card flat rounded="lg" class="pa-4 cart-card">
          <div class="d-flex align-center mb-3">
            <v-icon color="indigo-darken-2" class="mr-2">mdi-cart-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Requisition summary</div>
            <v-spacer />
            <v-chip size="x-small" color="indigo" variant="tonal">{{ cart.length }} items</v-chip>
          </div>

          <div v-if="cart.length === 0" class="text-center pa-6 text-medium-emphasis">
            <v-icon size="48" color="grey-lighten-1">mdi-tray-remove</v-icon>
            <div class="text-body-2 mt-2">No tests selected yet.</div>
            <div class="text-caption">Pick tests or panels from step 2.</div>
          </div>

          <div v-else class="cart-list">
            <div v-for="line in cart" :key="line.kind + line.id" class="cart-item d-flex align-start py-2">
              <v-icon
                :color="line.kind === 'panel' ? 'indigo-darken-2' : 'grey-darken-1'"
                size="18" class="mt-1 mr-2"
              >
                {{ line.kind === 'panel' ? 'mdi-package-variant' : 'mdi-flask-outline' }}
              </v-icon>
              <div class="flex-grow-1 min-width-0">
                <div class="font-weight-medium text-body-2 text-truncate">{{ line.name }}</div>
                <div class="text-caption text-medium-emphasis font-monospace">{{ line.code }}</div>
              </div>
              <div class="text-right ml-2">
                <div class="font-weight-medium text-body-2">{{ formatMoney(line.price) }}</div>
                <v-btn
                  icon="mdi-close" variant="text" size="x-small"
                  @click="removeLine(line)"
                />
              </div>
            </div>
          </div>

          <v-divider class="my-3" />
          <div class="d-flex align-center justify-space-between">
            <span class="text-body-2 text-medium-emphasis">Subtotal</span>
            <span class="text-body-1">{{ formatMoney(subtotal) }}</span>
          </div>
          <div class="d-flex align-center justify-space-between">
            <span class="text-body-2 text-medium-emphasis">
              Discount {{ discountPercent ? `(${discountPercent}%)` : '' }}
            </span>
            <span class="text-body-1">- {{ formatMoney(discountAmount) }}</span>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex align-center justify-space-between">
            <span class="text-subtitle-1 font-weight-bold">Total</span>
            <span class="text-h6 font-weight-bold text-primary">{{ formatMoney(total) }}</span>
          </div>
          <div v-if="discountSource" class="text-caption text-medium-emphasis mt-1">
            <v-icon size="12">mdi-tag-outline</v-icon> {{ discountSource }}
          </div>

          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-2">Estimated turnaround</div>
          <div class="d-flex align-center">
            <v-icon size="18" color="amber-darken-2" class="mr-2">mdi-clock-fast</v-icon>
            <span class="font-weight-medium">{{ estimatedTat }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const router = useRouter()

const step = ref(1)
const saving = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const patients = ref([])
const patientsLoading = ref(false)
const catalog = ref([])
const panels = ref([])
const refDoctors = ref([])
const refFacilities = ref([])

const form = reactive({
  patient: null,
  priority: 'routine',
  is_home_collection: false,
  clinical_notes: '',
  next_collection_date: null,
  test_ids: [],
})
const extra = reactive({
  referring_doctor: null,
  referring_facility: null,
  payer_type: 'self',
  notes_for_lab: '',
})

const selectedPatient = ref(null)
const pickedTestIds = ref(new Set())
const pickedPanelIds = ref(new Set())

const catalogTab = ref('tests')
const catalogSearch = ref('')
const deptFilter = ref(null)

const PRIORITY_META = {
  routine: { color: 'grey-darken-1', icon: 'mdi-clock-outline' },
  urgent: { color: 'orange-darken-2', icon: 'mdi-alert' },
  stat: { color: 'red-darken-2', icon: 'mdi-flash' },
}
const priorityItems = [
  { title: 'Routine', value: 'routine', color: 'grey-darken-1', icon: 'mdi-clock-outline' },
  { title: 'Urgent', value: 'urgent', color: 'orange-darken-2', icon: 'mdi-alert' },
  { title: 'STAT', value: 'stat', color: 'red-darken-2', icon: 'mdi-flash' },
]
const payers = [
  { title: 'Self pay', value: 'self' },
  { title: 'Insurance', value: 'insurance' },
  { title: 'Facility', value: 'facility' },
  { title: 'Corporate', value: 'corporate' },
]

async function loadAll() {
  patientsLoading.value = true
  try {
    const [p, c, pn, rd, rf] = await Promise.all([
      $api.get('/patients/').then(r => r.data).catch(() => []),
      $api.get('/lab/catalog/').then(r => r.data).catch(() => []),
      $api.get('/lab/panels/').then(r => r.data).catch(() => []),
      $api.get('/lab/referring-doctors/').then(r => r.data).catch(() => []),
      $api.get('/lab/referring-facilities/').then(r => r.data).catch(() => []),
    ])
    const patientList = (p.results || p) || []
    patients.value = patientList.map(x => {
      const fullName = x.user_name
        || `${x.user?.first_name || ''} ${x.user?.last_name || ''}`.trim()
        || x.user?.email
        || x.user_email
        || 'Unknown'
      return {
        ...x,
        fullName,
        display: `${fullName} — ${x.patient_number || x.patient_id || ''}`.trim(),
        subtitle: [x.gender, x.date_of_birth, x.user?.phone].filter(Boolean).join(' · '),
      }
    })
    catalog.value = c.results || c || []
    panels.value = pn.results || pn || []
    refDoctors.value = rd.results || rd || []
    refFacilities.value = rf.results || rf || []
  } finally {
    patientsLoading.value = false
  }
}
onMounted(loadAll)

function onPatientPicked(value) {
  if (value && typeof value === 'object') {
    selectedPatient.value = value
    form.patient = value.id
  } else {
    selectedPatient.value = patients.value.find(p => p.id === value) || null
  }
}

const departments = computed(() => {
  return [...new Set(catalog.value.map(t => t.department).filter(Boolean))].sort()
})
const filteredCatalog = computed(() => {
  const q = (catalogSearch.value || '').toLowerCase().trim()
  return catalog.value
    .filter(t => t.is_active !== false)
    .filter(t => !deptFilter.value || t.department === deptFilter.value)
    .filter(t => !q || (t.name || '').toLowerCase().includes(q) || (t.code || '').toLowerCase().includes(q))
    .slice(0, 200)
})
const filteredPanels = computed(() => {
  const q = (catalogSearch.value || '').toLowerCase().trim()
  return panels.value
    .filter(p => p.is_active !== false)
    .filter(p => !q || (p.name || '').toLowerCase().includes(q) || (p.code || '').toLowerCase().includes(q))
})

function toggleTest(t) {
  const set = new Set(pickedTestIds.value)
  if (set.has(t.id)) set.delete(t.id)
  else set.add(t.id)
  pickedTestIds.value = set
}
function togglePanel(p) {
  const set = new Set(pickedPanelIds.value)
  if (set.has(p.id)) set.delete(p.id)
  else set.add(p.id)
  pickedPanelIds.value = set
}
function removeLine(line) {
  if (line.kind === 'panel') {
    const set = new Set(pickedPanelIds.value)
    set.delete(line.id)
    pickedPanelIds.value = set
  } else {
    const set = new Set(pickedTestIds.value)
    set.delete(line.id)
    pickedTestIds.value = set
  }
}

const cart = computed(() => {
  const lines = []
  for (const id of pickedPanelIds.value) {
    const p = panels.value.find(x => x.id === id)
    if (p) lines.push({ kind: 'panel', id: p.id, name: p.name, code: p.code, price: Number(p.price || 0) })
  }
  for (const id of pickedTestIds.value) {
    const t = catalog.value.find(x => x.id === id)
    if (t) lines.push({ kind: 'test', id: t.id, name: t.name, code: t.code, price: Number(t.price || 0) })
  }
  return lines
})

// Compose final test_ids = direct picks + tests inside selected panels (deduped)
const effectiveTestIds = computed(() => {
  const merged = new Set(pickedTestIds.value)
  for (const id of pickedPanelIds.value) {
    const p = panels.value.find(x => x.id === id)
    if (!p) continue
    for (const t of (p.tests || [])) {
      merged.add(typeof t === 'object' ? t.id : t)
    }
  }
  return [...merged]
})

const subtotal = computed(() => cart.value.reduce((s, l) => s + (l.price || 0), 0))
const discountInfo = computed(() => {
  // Facility discount wins if higher
  let pct = 0
  let src = ''
  if (extra.referring_facility) {
    const f = refFacilities.value.find(x => x.id === extra.referring_facility)
    if (f && Number(f.discount_percent) > 0) {
      pct = Number(f.discount_percent)
      src = `Facility discount from ${f.name}`
    }
  }
  return { pct, src }
})
const discountPercent = computed(() => discountInfo.value.pct)
const discountSource = computed(() => discountInfo.value.src)
const discountAmount = computed(() => (subtotal.value * discountPercent.value) / 100)
const total = computed(() => Math.max(0, subtotal.value - discountAmount.value))

const estimatedTat = computed(() => {
  const tats = cart.value.map(l => {
    if (l.kind === 'test') {
      const t = catalog.value.find(x => x.id === l.id)
      return t?.turnaround_time || ''
    }
    return ''
  }).filter(Boolean)
  if (form.priority === 'stat') return 'STAT — within 1 hour'
  if (form.priority === 'urgent') return 'Urgent — within 4 hours'
  if (!tats.length) return 'Routine — same day'
  return tats[0] + (tats.length > 1 ? ' (longest)' : '')
})

const refDoctorName = computed(() => {
  const d = refDoctors.value.find(x => x.id === extra.referring_doctor)
  return d?.full_name || ''
})
const refFacilityName = computed(() => {
  const f = refFacilities.value.find(x => x.id === extra.referring_facility)
  return f?.name || ''
})

const canSubmit = computed(() => !!form.patient && effectiveTestIds.value.length > 0)

function initials(name) {
  if (!name) return '?'
  const parts = name.split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function hashColor(seed) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(seed) || 0) % colors.length]
}
function ageOf(dob) {
  if (!dob) return ''
  const d = new Date(dob)
  if (isNaN(d)) return ''
  const t = new Date()
  let a = t.getFullYear() - d.getFullYear()
  const m = t.getMonth() - d.getMonth()
  if (m < 0 || (m === 0 && t.getDate() < d.getDate())) a--
  return a
}

async function submit() {
  if (!canSubmit.value) {
    snack.text = 'Patient and at least one test are required'
    snack.color = 'error'
    snack.show = true
    return
  }
  saving.value = true
  try {
    const payload = {
      patient: form.patient,
      priority: form.priority,
      is_home_collection: form.is_home_collection,
      clinical_notes: form.clinical_notes,
      test_ids: effectiveTestIds.value,
    }
    if (form.next_collection_date) payload.next_collection_date = form.next_collection_date

    const order = (await $api.post('/lab/orders/', payload)).data

    const hasExtra = extra.referring_doctor || extra.referring_facility
      || extra.notes_for_lab || extra.payer_type !== 'self' || pickedPanelIds.value.size
    if (hasExtra) {
      try {
        await $api.post('/lab/order-extras/', {
          lab_order: order.id,
          referring_doctor: extra.referring_doctor,
          referring_facility: extra.referring_facility,
          payer_type: extra.payer_type,
          notes_for_lab: extra.notes_for_lab,
          panel_ids: [...pickedPanelIds.value],
        })
      } catch (_) { /* extras optional */ }
    }
    snack.text = `Requisition REQ-${String(order.id).padStart(5, '0')} created`
    snack.color = 'success'
    snack.show = true
    setTimeout(() => router.push(`/lab/requisitions/${order.id}`), 600)
  } catch (e) {
    const detail = e?.response?.data?.detail
      || (typeof e?.response?.data === 'object' ? Object.values(e.response.data).flat().join(' ') : '')
      || 'Failed to create requisition'
    snack.text = detail
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.patient-summary {
  border: 1px solid rgba(var(--v-theme-primary), 0.16);
  background: rgba(var(--v-theme-primary), 0.03);
}
.collection-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.cart-card {
  position: sticky;
  top: 16px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.cart-list { max-height: 360px; overflow-y: auto; }
.cart-item + .cart-item { border-top: 1px solid rgba(var(--v-theme-on-surface), 0.05); }

.catalog-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 8px;
  max-height: 540px;
  overflow-y: auto;
  padding-right: 4px;
}
.test-tile {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  cursor: pointer;
  transition: all 120ms ease;
}
.test-tile:hover {
  border-color: rgba(var(--v-theme-primary), 0.4);
  transform: translateY(-1px);
}
.test-tile.is-picked {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.05);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
