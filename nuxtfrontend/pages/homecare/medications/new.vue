<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- ───────────── Hero ───────────── -->
    <v-card rounded="xl" class="hc-rx-hero pa-5 mb-4 text-white" :elevation="0">
      <div class="d-flex align-center ga-3">
        <v-btn icon="mdi-arrow-left" variant="text" color="white"
               @click="goBack" />
        <v-avatar size="56" color="white" variant="flat">
          <v-icon icon="mdi-pill" color="purple-darken-2" size="30" />
        </v-avatar>
        <div class="flex-grow-1 min-w-0">
          <div class="text-overline" style="opacity:.85;">
            {{ editing ? 'EDIT SCHEDULE' : 'NEW SCHEDULE' }}
          </div>
          <h2 class="text-h5 font-weight-bold ma-0 text-truncate">
            {{ editing ? (form.medication_name || 'Update medication schedule')
                       : 'Create medication schedule' }}
          </h2>
          <div class="text-caption" style="opacity:.85;">
            Configure dosing, timing and instructions for safe administration.
          </div>
        </div>
        <v-btn variant="tonal" color="white" rounded="pill" class="text-none d-none d-md-inline-flex"
               prepend-icon="mdi-restore" :disabled="saving" @click="resetForm">
          Reset
        </v-btn>
      </div>
      <!-- Live preview chips -->
      <div v-if="form.medication_name || form.dose" class="d-flex flex-wrap ga-2 mt-3">
        <v-chip v-if="form.medication_name" size="small" color="white" variant="flat"
                class="text-purple-darken-3 font-weight-bold">
          <v-icon icon="mdi-pill" size="14" class="mr-1" /> {{ form.medication_name }}
        </v-chip>
        <v-chip v-if="form.dose" size="small" color="white" variant="outlined">
          <v-icon icon="mdi-scale-balance" size="14" class="mr-1" /> {{ form.dose }}
        </v-chip>
        <v-chip v-if="form.route" size="small" color="white" variant="outlined">
          <v-icon icon="mdi-needle" size="14" class="mr-1" /> {{ routeLabel(form.route) }}
        </v-chip>
        <v-chip v-if="selectedFrequencyLabel" size="small" color="white" variant="outlined">
          <v-icon icon="mdi-repeat" size="14" class="mr-1" /> {{ selectedFrequencyLabel }}
        </v-chip>
        <v-chip v-if="form.times_of_day?.length" size="small" color="white" variant="outlined">
          <v-icon icon="mdi-clock-outline" size="14" class="mr-1" />
          {{ form.times_of_day.join(' · ') }}
        </v-chip>
      </div>
    </v-card>

    <v-row dense>
      <!-- ───────────── Form ───────────── -->
      <v-col cols="12" lg="8">
        <v-card rounded="xl" class="pa-5" :elevation="0">
          <v-form ref="formRef" @submit.prevent="save">
            <!-- Section 1: Patient & plan -->
            <div class="hc-rx-section">
              <div class="hc-rx-section-title">
                <v-icon icon="mdi-account-heart" color="teal" size="18" class="mr-1" />
                Patient & treatment plan
              </div>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-autocomplete v-model="form.patient" :items="patientOptions"
                                  item-title="name" item-value="id"
                                  label="Patient *" variant="outlined" density="comfortable"
                                  rounded="lg" prepend-inner-icon="mdi-account"
                                  :rules="[v => !!v || 'Patient required']"
                                  :loading="loadingPatients"
                                  @update:model-value="onPatientSelected" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-autocomplete v-model="form.treatment_plan" :items="plansForPatient"
                                  item-title="title" item-value="id"
                                  :label="plansForPatient.length
                                    ? 'Treatment plan'
                                    : 'Treatment plan (none for patient)'"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-clipboard-text" clearable
                                  :hint="planAutofillHint" :persistent-hint="!!planAutofillHint" />
                </v-col>
              </v-row>
            </div>

            <!-- Section 2: Medication & dose -->
            <div class="hc-rx-section">
              <div class="hc-rx-section-title">
                <v-icon icon="mdi-pill" color="purple" size="18" class="mr-1" />
                Medication & dose
              </div>
              <v-row dense>
                <v-col cols="12" md="8">
                  <v-autocomplete v-model="form.medication_name" :items="medicationOptions"
                                  label="Medication *" variant="outlined" density="comfortable"
                                  rounded="lg" prepend-inner-icon="mdi-pill"
                                  :rules="[v => !!v || 'Medication required']"
                                  auto-select-first :return-object="false"
                                  item-title="title" item-value="value"
                                  :custom-filter="medFilter" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-select v-model="form.route" :items="routeOptions" label="Route"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-needle" />
                </v-col>
                <v-col cols="12">
                  <v-text-field v-model="form.dose" label="Dose *"
                                placeholder="e.g. 500 mg, 10 mL, 1 tab"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-scale-balance"
                                :rules="[v => !!v || 'Dose required']" />
                  <div class="d-flex flex-wrap ga-1 mt-1 mb-1">
                    <v-chip v-for="d in doseChipOptions" :key="d" size="small"
                            :color="form.dose === d ? 'purple' : undefined"
                            :variant="form.dose === d ? 'flat' : 'outlined'"
                            class="hc-chip-pick" @click="form.dose = d">
                      {{ d }}
                    </v-chip>
                  </div>
                </v-col>
              </v-row>
            </div>

            <!-- Section 3: Frequency & timing -->
            <div class="hc-rx-section">
              <div class="hc-rx-section-title">
                <v-icon icon="mdi-repeat" color="indigo" size="18" class="mr-1" />
                Frequency & timing
              </div>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-select v-model="form.frequency" :items="frequencyOptions"
                            item-title="title" item-value="value"
                            label="Frequency" variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-repeat"
                            @update:model-value="onFrequencyChange" />
                </v-col>
                <v-col cols="12" md="6">
                  <div class="text-caption text-medium-emphasis mb-1">Quick presets</div>
                  <div class="d-flex flex-wrap ga-1">
                    <v-chip v-for="f in quickFrequencyChips" :key="f.value" size="small"
                            :color="form.frequency === f.value ? 'indigo' : undefined"
                            :variant="form.frequency === f.value ? 'flat' : 'outlined'"
                            class="hc-chip-pick"
                            @click="form.frequency = f.value; onFrequencyChange(f.value)">
                      <v-icon :icon="f.icon" size="12" class="mr-1" /> {{ f.title }}
                    </v-chip>
                  </div>
                </v-col>
                <v-col cols="12">
                  <v-combobox v-model="form.times_of_day" :items="commonTimes"
                              label="Times of day (optional)"
                              multiple chips closable-chips clearable
                              hint='Pick or type 24h times like "08:00". Leave blank for as-needed (PRN).'
                              persistent-hint variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-clock-outline" />
                  <div class="d-flex flex-wrap ga-1 mt-1">
                    <v-chip v-for="t in commonTimes" :key="t" size="small"
                            :color="(form.times_of_day || []).includes(t) ? 'teal' : undefined"
                            :variant="(form.times_of_day || []).includes(t) ? 'flat' : 'outlined'"
                            class="hc-chip-pick" @click="toggleTime(t)">
                      <v-icon icon="mdi-clock-outline" size="12" class="mr-1" /> {{ t }}
                    </v-chip>
                    <v-chip size="small" variant="text" color="grey"
                            @click="form.times_of_day = []">
                      <v-icon icon="mdi-close-circle" size="12" class="mr-1" /> Clear
                    </v-chip>
                  </div>
                </v-col>
              </v-row>
            </div>

            <!-- Section 4: Schedule window -->
            <div class="hc-rx-section">
              <div class="hc-rx-section-title">
                <v-icon icon="mdi-calendar-range" color="teal" size="18" class="mr-1" />
                Schedule window
              </div>
              <v-row dense>
                <v-col cols="12" md="4">
                  <v-text-field v-model="form.start_date" type="date" label="Start *"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-calendar-start"
                                :rules="[v => !!v || 'Start date required']" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-text-field v-model="form.end_date" type="date" label="End (optional)"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-calendar-end" />
                </v-col>
                <v-col cols="12" md="4">
                  <div class="text-caption text-medium-emphasis mb-1">Duration presets</div>
                  <div class="d-flex flex-wrap ga-1">
                    <v-chip v-for="d in durationPresets" :key="d.days" size="small"
                            variant="outlined" class="hc-chip-pick"
                            @click="applyDuration(d.days)">
                      {{ d.label }}
                    </v-chip>
                  </div>
                </v-col>
              </v-row>
            </div>

            <!-- Section 5: Instructions -->
            <div class="hc-rx-section">
              <div class="hc-rx-section-title">
                <v-icon icon="mdi-information" color="orange" size="18" class="mr-1" />
                Instructions
              </div>
              <v-row dense>
                <v-col cols="12">
                  <v-textarea v-model="form.instructions" label="Patient/caregiver instructions"
                              rows="3" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-information"
                              placeholder="e.g. Take with food. Avoid grapefruit juice." />
                  <div class="text-caption text-medium-emphasis mt-1 mb-1">
                    Tap a chip to append a common instruction
                  </div>
                  <div class="d-flex flex-wrap ga-1">
                    <v-chip v-for="i in instructionChips" :key="i" size="small"
                            variant="outlined" class="hc-chip-pick"
                            @click="appendInstruction(i)">
                      <v-icon icon="mdi-plus" size="12" class="mr-1" /> {{ i }}
                    </v-chip>
                  </div>
                </v-col>
              </v-row>
            </div>

            <!-- Section 6: Status & administration -->
            <div class="hc-rx-section">
              <div class="hc-rx-section-title">
                <v-icon icon="mdi-flag" color="green" size="18" class="mr-1" />
                Status & administration
              </div>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-select v-model="form.status" :items="statusOptions"
                            item-title="title" item-value="value"
                            label="Status" variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-flag">
                    <template #selection="{ item }">
                      <v-chip size="small" :color="item.raw.color" variant="tonal">
                        <v-icon :icon="item.raw.icon" size="14" class="mr-1" />
                        {{ item.raw.title }}
                      </v-chip>
                    </template>
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="undefined">
                        <template #prepend>
                          <v-icon :icon="item.raw.icon" :color="item.raw.color" />
                        </template>
                        <v-list-item-title>{{ item.raw.title }}</v-list-item-title>
                        <v-list-item-subtitle>{{ item.raw.hint }}</v-list-item-subtitle>
                      </v-list-item>
                    </template>
                  </v-select>
                </v-col>
                <v-col cols="12" md="6" class="d-flex align-center">
                  <v-switch v-model="form.requires_caregiver" color="warning"
                            label="Requires caregiver to administer" hide-details
                            density="comfortable" />
                </v-col>
              </v-row>
            </div>
          </v-form>
        </v-card>
      </v-col>

      <!-- ───────────── Summary side panel ───────────── -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" class="pa-4 mb-3 hc-summary" :elevation="0">
          <div class="text-overline text-medium-emphasis mb-1">SUMMARY</div>
          <div class="text-subtitle-1 font-weight-bold mb-2">
            {{ form.medication_name || 'New regimen' }}
          </div>
          <v-divider class="mb-3" />
          <div class="hc-summary-row">
            <v-icon icon="mdi-account" size="16" class="mr-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2">Patient</span>
            <span class="text-body-2 font-weight-medium">
              {{ patientName(form.patient) || '—' }}
            </span>
          </div>
          <div class="hc-summary-row">
            <v-icon icon="mdi-clipboard-text" size="16" class="mr-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2">Plan</span>
            <span class="text-body-2 font-weight-medium">
              {{ planTitle(form.treatment_plan) || '—' }}
            </span>
          </div>
          <div class="hc-summary-row">
            <v-icon icon="mdi-scale-balance" size="16" class="mr-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2">Dose</span>
            <span class="text-body-2 font-weight-medium">
              {{ form.dose || '—' }} <span class="text-medium-emphasis">·
              {{ routeLabel(form.route) }}</span>
            </span>
          </div>
          <div class="hc-summary-row">
            <v-icon icon="mdi-repeat" size="16" class="mr-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2">Frequency</span>
            <span class="text-body-2 font-weight-medium">
              {{ selectedFrequencyLabel || '—' }}
            </span>
          </div>
          <div class="hc-summary-row align-start">
            <v-icon icon="mdi-clock-outline" size="16" class="mr-1 mt-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2 mt-1">Times</span>
            <div class="d-flex flex-wrap ga-1">
              <v-chip v-for="t in (form.times_of_day || [])" :key="t" size="x-small"
                      color="teal" variant="tonal">{{ t }}</v-chip>
              <span v-if="!form.times_of_day?.length" class="text-body-2">PRN</span>
            </div>
          </div>
          <div class="hc-summary-row">
            <v-icon icon="mdi-calendar-range" size="16" class="mr-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2">Window</span>
            <span class="text-body-2 font-weight-medium">
              {{ fmtDate(form.start_date) }}
              <template v-if="form.end_date"> → {{ fmtDate(form.end_date) }}</template>
              <template v-else> · ongoing</template>
            </span>
          </div>
          <div class="hc-summary-row">
            <v-icon icon="mdi-flag" size="16" class="mr-1 text-medium-emphasis" />
            <span class="text-caption text-medium-emphasis mr-2">Status</span>
            <v-chip size="x-small" :color="statusMeta(form.status).color" variant="tonal">
              <v-icon :icon="statusMeta(form.status).icon" size="12" class="mr-1" />
              {{ statusMeta(form.status).title }}
            </v-chip>
          </div>
        </v-card>

        <v-alert type="info" variant="tonal" rounded="lg" density="compact" class="mb-3">
          <span class="text-caption">
            After saving you can generate dose events for the next 7 or 30 days
            from the regimens list.
          </span>
        </v-alert>
      </v-col>
    </v-row>

    <!-- ───────────── Sticky action bar ───────────── -->
    <div class="hc-action-bar">
      <div class="d-flex align-center ga-2 px-4 py-3">
        <v-btn variant="text" rounded="lg" class="text-none"
               prepend-icon="mdi-restore" :disabled="saving"
               @click="resetForm">Reset</v-btn>
        <v-spacer />
        <v-btn variant="text" rounded="lg" class="text-none"
               :disabled="saving" @click="goBack">Cancel</v-btn>
        <v-btn color="purple" variant="flat" rounded="lg" class="text-none"
               :loading="saving" prepend-icon="mdi-content-save" @click="save">
          {{ editing ? 'Save changes' : 'Create schedule' }}
        </v-btn>
      </div>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()
const route = useRoute()

const editing = computed(() => !!route.query.id)
const editId = computed(() => route.query.id || null)

const patientOptions = ref([])
const planOptions = ref([])
const loadingPatients = ref(false)
const saving = ref(false)
const formRef = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })
const planAutofillHint = ref('')

const blank = () => ({
  id: null, patient: null, treatment_plan: null,
  medication_name: '', dose: '', route: 'oral',
  frequency: 'OD', frequency_cron: '', times_of_day: ['08:00'],
  start_date: new Date().toISOString().slice(0, 10),
  end_date: '', instructions: '',
  requires_caregiver: false,
  status: 'active'
})
const form = reactive(blank())

const routeOptions = [
  { value: 'oral',    title: 'Oral' },
  { value: 'iv',      title: 'IV' },
  { value: 'im',      title: 'Intramuscular' },
  { value: 'sc',      title: 'Subcutaneous' },
  { value: 'topical', title: 'Topical' },
  { value: 'inhaled', title: 'Inhaled' },
  { value: 'sublingual', title: 'Sublingual' },
  { value: 'rectal',  title: 'Rectal' },
  { value: 'ophthalmic', title: 'Ophthalmic' },
  { value: 'otic',    title: 'Otic (ear)' },
  { value: 'nasal',   title: 'Nasal' },
  { value: 'vaginal', title: 'Vaginal' },
  { value: 'transdermal', title: 'Transdermal' },
  { value: 'other',   title: 'Other' }
]
const commonTimes = ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00', '20:00', '22:00']

const MED_CATALOG = [
  { group: 'Analgesics & Antipyretics', items: ['Paracetamol', 'Ibuprofen', 'Diclofenac', 'Naproxen', 'Aspirin', 'Tramadol', 'Codeine', 'Morphine'] },
  { group: 'Antibiotics', items: ['Amoxicillin', 'Amoxicillin/Clavulanate', 'Azithromycin', 'Ciprofloxacin', 'Doxycycline', 'Metronidazole', 'Ceftriaxone', 'Erythromycin', 'Cloxacillin', 'Cotrimoxazole'] },
  { group: 'Antihypertensives', items: ['Amlodipine', 'Lisinopril', 'Losartan', 'Enalapril', 'Hydrochlorothiazide', 'Atenolol', 'Bisoprolol', 'Carvedilol', 'Methyldopa', 'Nifedipine'] },
  { group: 'Antidiabetics', items: ['Metformin', 'Glibenclamide', 'Gliclazide', 'Insulin (Mixtard 30/70)', 'Insulin Glargine', 'Insulin Regular', 'Sitagliptin', 'Empagliflozin'] },
  { group: 'Cardiac & Lipid', items: ['Atorvastatin', 'Simvastatin', 'Rosuvastatin', 'Clopidogrel', 'Warfarin', 'Apixaban', 'Digoxin', 'Isosorbide Dinitrate'] },
  { group: 'Diuretics', items: ['Furosemide', 'Spironolactone', 'Hydrochlorothiazide', 'Indapamide'] },
  { group: 'Respiratory', items: ['Salbutamol', 'Salbutamol Inhaler', 'Beclomethasone Inhaler', 'Budesonide/Formoterol', 'Ipratropium', 'Montelukast', 'Theophylline', 'Prednisolone'] },
  { group: 'GI & Antiemetic', items: ['Omeprazole', 'Pantoprazole', 'Esomeprazole', 'Ranitidine', 'Famotidine', 'Ondansetron', 'Metoclopramide', 'Loperamide', 'Lactulose'] },
  { group: 'Endocrine & Hormones', items: ['Levothyroxine', 'Carbimazole', 'Hydrocortisone', 'Prednisolone', 'Dexamethasone'] },
  { group: 'Neuro & Psych', items: ['Amitriptyline', 'Sertraline', 'Fluoxetine', 'Citalopram', 'Diazepam', 'Lorazepam', 'Carbamazepine', 'Sodium Valproate', 'Phenytoin', 'Levetiracetam', 'Risperidone', 'Olanzapine', 'Haloperidol', 'Donepezil'] },
  { group: 'Allergy & Antihistamine', items: ['Cetirizine', 'Loratadine', 'Chlorpheniramine', 'Diphenhydramine'] },
  { group: 'Antimalarials & Antiparasitic', items: ['Artemether/Lumefantrine', 'Quinine', 'Albendazole', 'Mebendazole'] },
  { group: 'Topical & Wound', items: ['Hydrocortisone Cream', 'Silver Sulfadiazine', 'Povidone-Iodine', 'Mupirocin Ointment', 'Clotrimazole Cream'] },
  { group: 'Vitamins & Supplements', items: ['Folic Acid', 'Ferrous Sulphate', 'Vitamin B Complex', 'Vitamin D3', 'Calcium Carbonate', 'Multivitamin', 'Zinc Sulphate'] }
]
const medicationOptions = computed(() => {
  const out = []
  MED_CATALOG.forEach((cat, idx) => {
    if (idx > 0) out.push({ type: 'divider' })
    out.push({ type: 'subheader', title: cat.group })
    cat.items.forEach(name => out.push({ title: name, value: name, _group: cat.group }))
  })
  return out
})
function medFilter(value, query, item) {
  const q = (query || '').toLowerCase()
  const raw = item?.raw || item
  const t = (raw?.title || raw?.value || '').toString().toLowerCase()
  const g = (raw?._group || '').toString().toLowerCase()
  return t.includes(q) || g.includes(q)
}

const doseChipOptions = [
  '125 mg', '250 mg', '500 mg', '1 g',
  '5 mg', '10 mg', '20 mg', '25 mg', '50 mg', '75 mg', '100 mg',
  '1 tab', '2 tabs', '½ tab',
  '5 mL', '10 mL', '15 mL',
  '1 puff', '2 puffs',
  '2 drops', '4 IU', '8 IU', '10 IU'
]

const frequencyOptions = [
  { value: 'OD',     title: 'Once daily (OD)',          times: ['08:00'],          icon: 'mdi-numeric-1-circle' },
  { value: 'BD',     title: 'Twice daily (BD)',          times: ['08:00','20:00'],  icon: 'mdi-numeric-2-circle' },
  { value: 'TDS',    title: 'Three times daily (TDS)',   times: ['08:00','14:00','20:00'], icon: 'mdi-numeric-3-circle' },
  { value: 'QID',    title: 'Four times daily (QID)',    times: ['06:00','12:00','18:00','22:00'], icon: 'mdi-numeric-4-circle' },
  { value: 'Q4H',    title: 'Every 4 hours',             times: ['00:00','04:00','08:00','12:00','16:00','20:00'], icon: 'mdi-clock-time-four' },
  { value: 'Q6H',    title: 'Every 6 hours',             times: ['00:00','06:00','12:00','18:00'], icon: 'mdi-clock-time-six' },
  { value: 'Q8H',    title: 'Every 8 hours',             times: ['08:00','16:00','00:00'], icon: 'mdi-clock-time-eight' },
  { value: 'Q12H',   title: 'Every 12 hours',            times: ['08:00','20:00'],  icon: 'mdi-clock-time-twelve' },
  { value: 'AM',     title: 'In the morning',            times: ['08:00'],          icon: 'mdi-weather-sunset-up' },
  { value: 'NOON',   title: 'At noon',                   times: ['12:00'],          icon: 'mdi-weather-sunny' },
  { value: 'PM',     title: 'In the evening',            times: ['18:00'],          icon: 'mdi-weather-sunset-down' },
  { value: 'NOCTE',  title: 'At bedtime',                times: ['22:00'],          icon: 'mdi-weather-night' },
  { value: 'WEEKLY', title: 'Once weekly',               times: ['08:00'],          icon: 'mdi-calendar-week' },
  { value: 'PRN',    title: 'As needed (PRN)',           times: [],                 icon: 'mdi-help-circle' },
  { value: 'STAT',   title: 'Stat (one-off)',            times: ['08:00'],          icon: 'mdi-flash' },
  { value: 'CUSTOM', title: 'Custom',                    times: null,               icon: 'mdi-tune' }
]
const quickFrequencyChips = computed(() =>
  frequencyOptions.filter(f => ['OD','BD','TDS','QID','NOCTE','PRN'].includes(f.value))
)
const selectedFrequencyLabel = computed(() => {
  const f = frequencyOptions.find(o => o.value === form.frequency)
  return f ? f.title : ''
})

const durationPresets = [
  { days: 5,  label: '5 days' },
  { days: 7,  label: '1 week' },
  { days: 14, label: '2 weeks' },
  { days: 30, label: '1 month' },
  { days: 90, label: '3 months' },
  { days: 0,  label: 'Ongoing' }
]

const statusOptions = [
  { value: 'active',       title: 'Active',       icon: 'mdi-play-circle',  color: 'success', hint: 'Currently being administered' },
  { value: 'paused',       title: 'Paused',       icon: 'mdi-pause-circle', color: 'warning', hint: 'Temporarily on hold' },
  { value: 'completed',    title: 'Completed',    icon: 'mdi-check-circle', color: 'info',    hint: 'Course finished as planned' },
  { value: 'discontinued', title: 'Discontinued', icon: 'mdi-close-circle', color: 'grey',    hint: 'Stopped before completion' }
]

const instructionChips = [
  'Take with food', 'Take on empty stomach', 'Take with plenty of water',
  'Avoid grapefruit juice', 'Avoid alcohol', 'Do not crush or chew',
  'Shake well before use', 'Refrigerate after opening',
  'May cause drowsiness', 'Take at bedtime',
  'Complete the full course', 'Stop and call clinician if rash develops',
  'Monitor blood pressure', 'Monitor blood glucose',
  'Apply thinly to affected area', 'For external use only',
  'Rinse mouth after inhaler use'
]

// ─────── data
async function loadPatients() {
  loadingPatients.value = true
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 200 } })
    const items = data?.results || data || []
    patientOptions.value = items.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'}${p.medical_record_number ? ' · ' + p.medical_record_number : ''}`,
      primary_diagnosis: p.primary_diagnosis || ''
    }))
  } catch { /* ignore */ }
  finally { loadingPatients.value = false }
}
async function loadPlans() {
  try {
    const { data } = await $api.get('/homecare/treatment-plans/', { params: { page_size: 200 } })
    const items = data?.results || data || []
    planOptions.value = items.map(p => ({
      id: p.id,
      title: `${p.title}${p.patient_name ? ' · ' + p.patient_name : ''}`,
      patient: p.patient,
      status: p.status
    }))
  } catch { /* ignore */ }
}
async function loadExisting() {
  if (!editId.value) return
  try {
    const { data } = await $api.get(`/homecare/medication-schedules/${editId.value}/`)
    Object.assign(form, {
      id: data.id, patient: data.patient, treatment_plan: data.treatment_plan,
      medication_name: data.medication_name, dose: data.dose, route: data.route,
      frequency: deduceFrequency(data.times_of_day || []),
      frequency_cron: data.frequency_cron || '',
      times_of_day: [...(data.times_of_day || [])],
      start_date: data.start_date,
      end_date: data.end_date || '',
      instructions: data.instructions || '',
      requires_caregiver: !!data.requires_caregiver,
      status: data.is_active ? (data.status || 'active') : (data.status || 'paused')
    })
  } catch {
    snack.text = 'Failed to load schedule'; snack.color = 'error'; snack.show = true
  }
}

onMounted(async () => {
  // Allow ?patient=<id> deep link
  if (route.query.patient) form.patient = Number(route.query.patient)
  await Promise.all([loadPatients(), loadPlans()])
  await loadExisting()
  if (form.patient && !editing.value) onPatientSelected(form.patient)
})

// ─────── derived
const plansForPatient = computed(() => {
  if (!form.patient) return planOptions.value
  return planOptions.value.filter(p => p.patient === form.patient)
})

// ─────── helpers
function routeLabel(r) {
  return (routeOptions.find(o => o.value === r) || {}).title || r
}
function statusMeta(v) {
  return statusOptions.find(o => o.value === v) || statusOptions[0]
}
function patientName(id) {
  return (patientOptions.value.find(p => p.id === id) || {}).name || ''
}
function planTitle(id) {
  return (planOptions.value.find(p => p.id === id) || {}).title || ''
}
function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}

// ─────── interactions
function onPatientSelected(id) {
  if (form.treatment_plan) {
    const cur = planOptions.value.find(p => p.id === form.treatment_plan)
    if (cur && cur.patient !== id) form.treatment_plan = null
  }
  const plans = planOptions.value.filter(p => p.patient === id)
  if (!plans.length) {
    planAutofillHint.value = 'No treatment plan on file for this patient'
    return
  }
  if (!form.treatment_plan) {
    const preferred = plans.find(p => p.status === 'active') || plans[0]
    form.treatment_plan = preferred.id
    planAutofillHint.value = `Auto-selected: ${preferred.title}`
  } else {
    planAutofillHint.value = ''
  }
}
function onFrequencyChange(value) {
  const f = frequencyOptions.find(o => o.value === value)
  if (!f || f.times === null) return
  form.times_of_day = [...f.times]
}
function toggleTime(t) {
  const arr = form.times_of_day || []
  const i = arr.indexOf(t)
  if (i >= 0) form.times_of_day = arr.filter(x => x !== t)
  else form.times_of_day = [...arr, t].sort()
}
function applyDuration(days) {
  if (!days) { form.end_date = ''; return }
  const start = form.start_date ? new Date(form.start_date) : new Date()
  const end = new Date(start)
  end.setDate(end.getDate() + days - 1)
  form.end_date = end.toISOString().slice(0, 10)
}
function appendInstruction(text) {
  const cur = (form.instructions || '').trim()
  if (cur.toLowerCase().includes(text.toLowerCase())) return
  form.instructions = cur ? `${cur}. ${text}` : text
}
function deduceFrequency(times) {
  const key = [...(times || [])].sort().join(',')
  for (const f of frequencyOptions) {
    if (f.times === null) continue
    if ([...f.times].sort().join(',') === key) return f.value
  }
  return 'CUSTOM'
}
function resetForm() {
  const id = editing.value ? form.id : null
  Object.assign(form, blank())
  if (id) form.id = id
  planAutofillHint.value = ''
}
function goBack() {
  router.push('/homecare/medications')
}

async function save() {
  const v = await formRef.value?.validate()
  if (v && v.valid === false) return
  saving.value = true
  const isActive = form.status === 'active'
  const payload = {
    patient: form.patient, treatment_plan: form.treatment_plan || null,
    medication_name: form.medication_name, dose: form.dose, route: form.route,
    frequency_cron: form.frequency_cron, times_of_day: form.times_of_day,
    start_date: form.start_date, end_date: form.end_date || null,
    instructions: form.instructions,
    requires_caregiver: form.requires_caregiver, is_active: isActive
  }
  try {
    if (editing.value && form.id) {
      await $api.patch(`/homecare/medication-schedules/${form.id}/`, payload)
      snack.text = 'Schedule updated'; snack.color = 'success'
    } else {
      await $api.post('/homecare/medication-schedules/', payload)
      snack.text = 'Schedule created'; snack.color = 'success'
    }
    snack.show = true
    setTimeout(() => router.push('/homecare/medications'), 600)
  } catch (e) {
    const msg = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Save failed'
    snack.text = msg; snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(124,58,237,0.05) 0%, rgba(13,148,136,0.05) 100%);
  min-height: calc(100vh - 64px);
  padding-bottom: 96px;
}
.hc-rx-hero {
  background: linear-gradient(135deg,#7c3aed 0%,#6d28d9 60%,#4f46e5 100%);
  box-shadow: 0 18px 40px -18px rgba(109,40,217,0.55);
}
.hc-rx-section + .hc-rx-section {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px dashed rgba(15,23,42,0.08);
}
.hc-rx-section-title {
  display: flex; align-items: center;
  font-size: 12px; font-weight: 700;
  letter-spacing: 0.06em; text-transform: uppercase;
  color: rgba(15,23,42,0.7);
  margin-bottom: 8px;
}
.hc-chip-pick { cursor: pointer; transition: transform .1s ease; }
.hc-chip-pick:hover { transform: translateY(-1px); }

.hc-summary {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  position: sticky; top: 84px;
}
.hc-summary-row {
  display: flex; align-items: center;
  padding: 6px 0;
  border-bottom: 1px dashed rgba(15,23,42,0.05);
}
.hc-summary-row:last-child { border-bottom: 0; }

.hc-action-bar {
  position: sticky; bottom: 0; left: 0; right: 0;
  background: rgba(255,255,255,0.92);
  backdrop-filter: blur(10px);
  border-top: 1px solid rgba(15,23,42,0.08);
  margin: 16px -16px -16px;
  z-index: 5;
}

:global(.v-theme--dark) .hc-rx-section + .hc-rx-section {
  border-top-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark) .hc-rx-section-title { color: rgba(255,255,255,0.75); }
:global(.v-theme--dark) .hc-summary {
  background: rgba(30,41,59,0.7);
  border-color: rgba(255,255,255,0.06);
}
:global(.v-theme--dark) .hc-action-bar {
  background: rgba(15,23,42,0.85);
  border-top-color: rgba(255,255,255,0.08);
}
</style>
