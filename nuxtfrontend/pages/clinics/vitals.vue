<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Vital Signs" subtitle="Patient vital signs tracking with NEWS2 scoring"
      icon="mdi-heart-pulse" color="red">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="r.list({ page_size: 1000 })">Refresh</v-btn>
        <v-btn color="red" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openDialog()">New Vitals</v-btn>
      </template>
    </PageHeader>

    <!-- ── KPI cards ───────────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col cols="6" md="3">
        <v-card flat rounded="lg" variant="outlined" class="kpi-card pa-3">
          <div class="d-flex align-center">
            <v-avatar color="red-lighten-5" size="40" rounded class="mr-3">
              <v-icon color="red" size="22">mdi-heart-pulse</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold">{{ r.items.value.length }}</div>
              <div class="text-caption text-medium-emphasis">Total Records</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="lg" variant="outlined" class="kpi-card pa-3">
          <div class="d-flex align-center">
            <v-avatar color="success-lighten-5" size="40" rounded class="mr-3">
              <v-icon color="success" size="22">mdi-shield-check</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold text-success">{{ lowRiskCount }}</div>
              <div class="text-caption text-medium-emphasis">Low Risk</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="lg" variant="outlined" class="kpi-card pa-3">
          <div class="d-flex align-center">
            <v-avatar color="warning-lighten-5" size="40" rounded class="mr-3">
              <v-icon color="warning" size="22">mdi-alert</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold text-warning">{{ medRiskCount }}</div>
              <div class="text-caption text-medium-emphasis">Medium Risk</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="lg" variant="outlined" class="kpi-card pa-3">
          <div class="d-flex align-center">
            <v-avatar color="error-lighten-5" size="40" rounded class="mr-3">
              <v-icon color="error" size="22">mdi-alert-circle</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold text-error">{{ highRiskCount }}</div>
              <div class="text-caption text-medium-emphasis">High Risk</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search patient…" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="4">
          <v-select v-model="patientFilter" :items="patientOptions"
            label="Filter by patient" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="3" v-if="patientOptions.length">
          <v-select v-model="riskFilter" :items="riskFilterOptions"
            label="NEWS2 Risk" variant="outlined" density="compact" hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="red" size="48" />
      </div>

      <div v-else-if="!filteredVitals.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-heart-pulse</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No vitals recorded</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ r.search.value || patientFilter || riskFilter ? 'Try adjusting your filters.' : 'Record vital signs to get started.' }}
        </div>
        <v-btn v-if="!r.search.value && !patientFilter && !riskFilter" color="red" rounded="lg"
          prepend-icon="mdi-plus" class="text-none" @click="openDialog()">New Vitals</v-btn>
      </div>

      <v-data-table v-else :headers="headers" :items="filteredVitals"
        :items-per-page="15" item-value="id" hover class="vitals-table">
        <template #item.index="{ index }">
          <span class="text-body-2 text-medium-emphasis font-weight-bold">{{ index + 1 }}</span>
        </template>
        <template #item.patient_name="{ item, value }">
          <div class="d-flex align-center py-1">
            <v-avatar color="red-lighten-5" size="32" class="mr-2">
              <v-icon color="red-darken-2" size="18">mdi-account</v-icon>
            </v-avatar>
            <div>
              <span class="font-weight-medium">{{ value || '—' }}</span>
              <div v-if="item.patient_number" class="text-caption text-medium-emphasis">ID: {{ item.patient_number }}</div>
            </div>
          </div>
        </template>
        <template #item.news2="{ item }">
          <v-chip v-if="item.vital_signs?.news2_score != null"
            :color="news2TableColor(item.vital_signs.news2_score)" variant="flat" size="small"
            class="font-weight-bold text-white">
            {{ item.vital_signs.news2_score }} — {{ news2TableLabel(item.vital_signs.news2_score) }}
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.vital_signs.temperature="{ value }">
          <v-chip v-if="value != null" size="small" variant="text" class="font-weight-medium px-1">
            {{ value }} °C
          </v-chip>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.bp="{ item }">
          <span v-if="bpLabel(item) !== '—'" class="font-weight-medium">{{ bpLabel(item) }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.vital_signs.heart_rate="{ value }">
          <span v-if="value != null" class="font-weight-medium">{{ value }} bpm</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.vital_signs.respiratory_rate="{ value }">
          <span v-if="value != null" class="font-weight-medium">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.vital_signs.oxygen_saturation="{ value }">
          <span v-if="value != null" class="font-weight-medium">{{ value }}%</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.vital_signs.weight="{ value }">
          <span v-if="value != null" class="font-weight-medium">{{ value }} kg</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.created_at="{ value }">
          <span class="text-body-2 text-medium-emphasis">{{ formatDateTime(value) }}</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end">
            <v-btn icon="mdi-pencil" variant="text" size="small" @click="openDialog(item)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ── New / Edit dialog ─────────────────────────────────────── -->
    <v-dialog v-model="dialog" max-width="900" persistent scrollable>
      <v-card rounded="lg">
        <div class="dialog-header">
          <v-card-title class="text-h6 d-flex align-center py-3">
            <v-icon color="red" class="mr-2">mdi-heart-pulse</v-icon>
            {{ editing ? 'Edit Vitals' : 'New Vitals' }}
            <v-spacer />
            <v-chip :color="news2ChipColor" variant="flat" size="large"
              class="font-weight-bold text-white" v-if="showNews2Chip">
              NEWS2: {{ news2Total }} — {{ news2CategoryLabel }}
            </v-chip>
          </v-card-title>
        </div>
        <v-divider />
        <v-card-text class="pt-4">
          <v-form ref="formRef">
            <v-alert type="info" variant="tonal" density="compact" class="mb-4 rounded-lg">
              <span class="text-body-2">
                <strong>NEWS2 (National Early Warning Score 2)</strong> — Enter vital signs below.
                Each parameter is colour-coded: <span class="text-success">green = score 0</span>,
                <span class="text-warning">amber = 1–2</span>, <span class="text-error">red = 3</span>.
                The aggregate score determines the clinical risk response.
              </span>
            </v-alert>

            <v-select v-model="vitalsForm.patient" :items="patientOptions"
              label="Patient" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-account" class="mb-3"
              :loading="patientR.loading.value" />

            <!-- ── NEWS2 parameter cards ─────────────────────────────── -->
            <v-row dense>
              <!-- Respiratory Rate -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.respiratoryRate)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Respiratory Rate</span>
                      <v-chip :color="scoreColorClass(news2Scores.respiratoryRate)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.respiratoryRate }}</v-chip>
                    </div>
                    <v-text-field v-model.number="vitalsForm.respiratory_rate" type="number"
                      label="breaths / min" variant="outlined" density="compact" hide-details
                      suffix="/min" />
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('rr')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- SpO₂ -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.spo2)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">SpO₂</span>
                      <v-chip :color="scoreColorClass(news2Scores.spo2)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.spo2 }}</v-chip>
                    </div>
                    <v-text-field v-model.number="vitalsForm.oxygen_saturation" type="number"
                      label="SpO₂" variant="outlined" density="compact" hide-details
                      suffix="%" />
                    <v-btn-toggle v-model="vitalsForm.spo2_scale" mandatory density="compact"
                      class="mt-2 w-100" color="primary">
                      <v-btn size="x-small" :value="1">Scale 1</v-btn>
                      <v-btn size="x-small" :value="2">Scale 2</v-btn>
                    </v-btn-toggle>
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('spo2')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Air / Oxygen -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.airOxygen)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Air / Oxygen</span>
                      <v-chip :color="scoreColorClass(news2Scores.airOxygen)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.airOxygen }}</v-chip>
                    </div>
                    <v-btn-toggle v-model="vitalsForm.on_oxygen" mandatory density="compact"
                      class="w-100" color="primary">
                      <v-btn size="small" :value="false">Air</v-btn>
                      <v-btn size="small" :value="true">On O₂</v-btn>
                    </v-btn-toggle>
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('oxygen')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Systolic BP -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.systolicBP)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Systolic BP</span>
                      <v-chip :color="scoreColorClass(news2Scores.systolicBP)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.systolicBP }}</v-chip>
                    </div>
                    <v-text-field v-model.number="vitalsForm.bp_systolic" type="number"
                      label="Systolic" variant="outlined" density="compact" hide-details
                      suffix="mmHg" />
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('bp')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Diastolic BP (no NEWS2 score, still capture) -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Diastolic BP</span>
                      <v-chip variant="flat" size="x-small" color="grey">—</v-chip>
                    </div>
                    <v-text-field v-model.number="vitalsForm.bp_diastolic" type="number"
                      label="Diastolic" variant="outlined" density="compact" hide-details
                      suffix="mmHg" />
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Heart Rate -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.heartRate)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Heart Rate</span>
                      <v-chip :color="scoreColorClass(news2Scores.heartRate)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.heartRate }}</v-chip>
                    </div>
                    <v-text-field v-model.number="vitalsForm.heart_rate" type="number"
                      label="Heart Rate" variant="outlined" density="compact" hide-details
                      suffix="bpm" />
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('hr')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Consciousness (AVPU) -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.consciousness)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Consciousness</span>
                      <v-chip :color="scoreColorClass(news2Scores.consciousness)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.consciousness }}</v-chip>
                    </div>
                    <v-select v-model="vitalsForm.consciousness" :items="consciousnessOptions"
                      variant="outlined" density="compact" hide-details />
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('avpu')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Temperature -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg"
                  :class="['news2-param', scoreColorClass(news2Scores.temperature)]">
                  <v-card-text class="pa-3">
                    <div class="d-flex align-center justify-between mb-1">
                      <span class="text-caption font-weight-bold">Temperature</span>
                      <v-chip :color="scoreColorClass(news2Scores.temperature)" variant="flat" size="x-small"
                        class="text-white">{{ news2Scores.temperature }}</v-chip>
                    </div>
                    <v-text-field v-model.number="vitalsForm.temperature" type="number"
                      label="Temperature" variant="outlined" density="compact" hide-details
                      suffix="°C" />
                    <div class="text-caption mt-1" v-html="news2ScaleLabel('temp')"></div>
                  </v-card-text>
                </v-card>
              </v-col>

              <!-- Weight & Height -->
              <v-col cols="12" sm="6" md="4">
                <v-card flat variant="outlined" rounded="lg">
                  <v-card-text class="pa-3">
                    <v-row dense>
                      <v-col cols="12" sm="6">
                        <v-text-field v-model.number="vitalsForm.weight" type="number"
                          label="Weight" variant="outlined" density="compact" hide-details
                          suffix="kg" />
                      </v-col>
                      <v-col cols="12" sm="6">
                        <v-text-field v-model.number="vitalsForm.height" type="number"
                          label="Height" variant="outlined" density="compact" hide-details
                          suffix="cm" />
                      </v-col>
                    </v-row>
                    <div v-if="bmi" class="text-caption mt-2">
                      BMI: <strong>{{ bmi }}</strong>
                    </div>
                  </v-card-text>
                </v-card>
              </v-col>
            </v-row>

            <!-- ── NEWS2 Summary panel ──────────────────────────────── -->
            <v-alert :color="news2ChipColor" variant="tonal" class="mt-4 rounded-lg"
              v-if="news2Total > 0 || hasAnyInput">
              <div class="d-flex align-center">
                <v-icon :color="news2ChipColor" size="32" class="mr-3">mdi-clipboard-pulse</v-icon>
                <div>
                  <div class="text-h6 font-weight-bold">
                    Total NEWS2 Score: {{ news2Total }}
                    <v-chip :color="news2ChipColor" variant="flat" size="small"
                      class="ml-2 text-white font-weight-bold">{{ news2CategoryLabel }}</v-chip>
                  </div>
                  <div class="text-body-2">{{ news2ClinicalResponse }}</div>
                </div>
              </div>
            </v-alert>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="dialog = false">Cancel</v-btn>
          <v-btn color="red" rounded="lg" :loading="r.saving.value"
            @click="saveVitals">{{ editing ? 'Update' : 'Create' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="440">
      <v-card rounded="lg" class="text-center pb-2">
        <div class="pt-6">
          <v-avatar color="error-lighten-5" size="64" class="mb-3">
            <v-icon color="error" size="36">mdi-delete-alert</v-icon>
          </v-avatar>
        </div>
        <v-card-title class="text-h6 d-block">Delete Vitals Record?</v-card-title>
        <v-card-text>
          <div class="text-body-2">
            Are you sure you want to delete the vitals record for
            <strong>{{ deleteTarget?.patient_name || '—' }}</strong>?
          </div>
          <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
        </v-card-text>
        <v-card-actions class="px-6 pb-4">
          <v-spacer />
          <v-btn variant="outlined" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" prepend-icon="mdi-delete" :loading="deleting"
            @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'

const ns = '/clinics'

const r = useResource('/triage/')
const patientR = useResource('/patients/')

onMounted(() => {
  r.list({ page_size: 1000 })
  patientR.list({ page_size: 1000 })
})

const headers = [
  { title: '#', key: 'index', sortable: false, width: 50 },
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'NEWS2', key: 'news2', sortable: false, width: 150 },
  { title: 'Temp', key: 'vital_signs.temperature', sortable: false, width: 90 },
  { title: 'BP', key: 'bp', sortable: false, width: 90 },
  { title: 'HR', key: 'vital_signs.heart_rate', sortable: false, width: 90 },
  { title: 'RR', key: 'vital_signs.respiratory_rate', sortable: false, width: 80 },
  { title: 'SpO₂', key: 'vital_signs.oxygen_saturation', sortable: false, width: 80 },
  { title: 'Weight', key: 'vital_signs.weight', sortable: false, width: 90 },
  { title: 'Date', key: 'created_at', width: 160 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]

const patientFilter = ref(null)
const riskFilter = ref(null)
const riskFilterOptions = [
  { title: 'Low Risk (0–4)', value: 'low' },
  { title: 'Medium Risk (5–6)', value: 'medium' },
  { title: 'High Risk (≥7)', value: 'high' },
]
const req = [v => !!v || 'Required']
const formRef = ref(null)
const dialog = ref(false)
const editing = ref(null)
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const consciousnessOptions = [
  { title: 'A — Alert', value: 'A' },
  { title: 'CVPU — New Confusion', value: 'CVPU' },
  { title: 'V — Responds to Voice', value: 'V' },
  { title: 'P — Responds to Pain', value: 'P' },
  { title: 'U — Unresponsive', value: 'U' },
]

const vitalsForm = reactive({
  patient: null,
  temperature: null,
  bp_systolic: null,
  bp_diastolic: null,
  heart_rate: null,
  respiratory_rate: null,
  oxygen_saturation: null,
  weight: null,
  height: null,
  // NEWS2 extras
  spo2_scale: 1,
  on_oxygen: false,
  consciousness: 'A',
})

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: `${p.patient_number || ''} — ${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown'}`.trim(),
    value: p.id,
  })),
)

function _news2RiskCategory(score) {
  if (score == null) return null
  if (score >= 7) return 'high'
  if (score >= 5) return 'medium'
  return 'low'
}

const filteredVitals = computed(() => {
  let list = r.filtered.value
  if (patientFilter.value) list = list.filter(v => v.patient === patientFilter.value)
  if (riskFilter.value) list = list.filter(v => _news2RiskCategory(v.vital_signs?.news2_score) === riskFilter.value)
  return list
})

const lowRiskCount = computed(() => r.items.value.filter(v => _news2RiskCategory(v.vital_signs?.news2_score) === 'low').length)
const medRiskCount = computed(() => r.items.value.filter(v => _news2RiskCategory(v.vital_signs?.news2_score) === 'medium').length)
const highRiskCount = computed(() => r.items.value.filter(v => _news2RiskCategory(v.vital_signs?.news2_score) === 'high').length)

function bpLabel(item) {
  const vs = item.vital_signs || {}
  const sys = vs.bp_systolic || vs.blood_pressure_systolic
  const dia = vs.bp_diastolic || vs.blood_pressure_diastolic
  if (sys && dia) return `${sys}/${dia}`
  return '—'
}

function news2TableColor(score) {
  if (score >= 7) return 'error'
  if (score >= 5) return 'orange'
  if (score >= 1) return 'warning'
  return 'success'
}

function news2TableLabel(score) {
  if (score >= 7) return 'High Risk'
  if (score >= 5) return 'Med Risk'
  if (score >= 1) return 'Low Risk'
  return 'Normal'
}

// ── NEWS2 Scoring ──────────────────────────────────────────────────────────

function _rrScore(rr) {
  if (rr == null) return 0
  if (rr <= 8 || rr >= 25) return 3
  if (rr >= 9 && rr <= 11) return 1
  if (rr >= 21) return 2  // 21-24 = 2
  return 0  // 12-20
}

function _spo2Score(sat, scale) {
  if (sat == null) return 0
  if (scale === 2) {
    // Scale 2 (hypercapnic patients)
    if (sat <= 83 || sat >= 97) return 3  // ≤83 = 3, ≥97 = 0... wait
    // Actually SpO₂ Scale 2:
    // ≤83: 3, 84-85: 2, 86-87: 1, 88-92: 0, 93-94: 1, 95-96: 2, ≥97: 0
    if (sat >= 97) return 0
    if (sat >= 95 && sat <= 96) return 2
    if (sat >= 93 && sat <= 94) return 1
    if (sat >= 88 && sat <= 92) return 0
    if (sat >= 86 && sat <= 87) return 1
    if (sat >= 84 && sat <= 85) return 2
    if (sat <= 83) return 3
  } else {
    // Scale 1 (standard)
    if (sat <= 91) return 3
    if (sat >= 92 && sat <= 93) return 2
    if (sat >= 94 && sat <= 95) return 1
    return 0  // ≥96
  }
  return 0
}

function _airOxygenScore(onOxygen) {
  return onOxygen ? 2 : 0
}

function _systolicBPScore(sys) {
  if (sys == null) return 0
  if (sys <= 90 || sys >= 220) return 3
  if (sys >= 91 && sys <= 100) return 2
  if (sys >= 101 && sys <= 110) return 1
  return 0  // 111-219
}

function _heartRateScore(hr) {
  if (hr == null) return 0
  if (hr <= 40 || hr >= 131) return 3
  if (hr >= 111 && hr <= 130) return 2
  if (hr >= 41 && hr <= 50) return 1
  if (hr >= 91 && hr <= 110) return 1
  return 0  // 51-90
}

function _consciousnessScore(avpu) {
  if (!avpu || avpu === 'A') return 0
  return 3  // CVPU, V, P, U all score 3
}

function _temperatureScore(temp) {
  if (temp == null) return 0
  if (temp <= 35.0) return 3
  if (temp >= 35.1 && temp <= 36.0) return 1
  if (temp >= 38.1 && temp <= 39.0) return 1
  if (temp >= 39.1) return 2
  return 0  // 36.1-38.0
}

const news2Scores = computed(() => ({
  respiratoryRate: _rrScore(vitalsForm.respiratory_rate),
  spo2: _spo2Score(vitalsForm.oxygen_saturation, vitalsForm.spo2_scale),
  airOxygen: _airOxygenScore(vitalsForm.on_oxygen),
  systolicBP: _systolicBPScore(vitalsForm.bp_systolic),
  heartRate: _heartRateScore(vitalsForm.heart_rate),
  consciousness: _consciousnessScore(vitalsForm.consciousness),
  temperature: _temperatureScore(vitalsForm.temperature),
}))

const news2Total = computed(() => {
  const s = news2Scores.value
  return s.respiratoryRate + s.spo2 + s.airOxygen + s.systolicBP + s.heartRate + s.consciousness + s.temperature
})

const hasAnyInput = computed(() => {
  return [
    vitalsForm.respiratory_rate, vitalsForm.oxygen_saturation,
    vitalsForm.bp_systolic, vitalsForm.heart_rate, vitalsForm.temperature,
  ].some(v => v != null)
})

const news2ChipColor = computed(() => {
  const t = news2Total.value
  if (t >= 7) return 'error'
  if (t >= 5) return 'orange'
  if (t >= 1) return 'warning'
  return 'success'
})

// Title chip should only show when there's actual input
const showNews2Chip = computed(() => hasAnyInput.value || news2Total.value > 0)

const news2CategoryLabel = computed(() => {
  const t = news2Total.value
  const any3 = Object.values(news2Scores.value).some(v => v >= 3)
  if (t >= 7) return 'HIGH RISK'
  if (t >= 5 || any3) return 'MEDIUM RISK'
  if (t >= 1) return 'LOW RISK'
  return hasAnyInput.value ? 'LOW RISK' : 'No data'
})

const news2ClinicalResponse = computed(() => {
  const t = news2Total.value
  const any3 = Object.values(news2Scores.value).some(v => v >= 3)
  if (t >= 7) return 'Urgent response needed — inform a registrar/consultant immediately. Assess within 1 hour.'
  if (t >= 5 || any3) return 'Urgent ward-based review needed. Inform registrar. Assess within 1 hour.'
  if (t >= 1) return 'Routine monitoring — re-assess at next vitals round.'
  return hasAnyInput.value ? 'All parameters within normal range — continue routine monitoring.' : 'Waiting for vitals input...'
})

const bmi = computed(() => {
  if (!vitalsForm.weight || !vitalsForm.height) return null
  const m = vitalsForm.height / 100
  if (m <= 0) return null
  return (vitalsForm.weight / (m * m)).toFixed(1)
})

function scoreColorClass(score) {
  if (score >= 3) return 'news2-red'
  if (score >= 1) return 'news2-amber'
  return 'news2-green'
}

// Scale legend labels for each parameter
function news2ScaleLabel(param) {
  const labels = {
    rr: '<span class="text-success">12-20: 0</span> · <span class="text-warning">9-11: 1 · 21-24: 2</span> · <span class="text-error">≤8 or ≥25: 3</span>',
    spo2: vitalsForm.spo2_scale === 2
      ? '<span class="text-success">88-92%: 0 · ≥97%: 0</span> · <span class="text-warning">86-87/93-94: 1 · 84-85/95-96: 2</span> · <span class="text-error">≤83%: 3</span>'
      : '<span class="text-success">≥96%: 0</span> · <span class="text-warning">94-95%: 1 · 92-93%: 2</span> · <span class="text-error">≤91%: 3</span>',
    oxygen: '<span class="text-success">Air: 0</span> · <span class="text-warning">On O₂: 2</span>',
    bp: '<span class="text-success">111-219: 0</span> · <span class="text-warning">101-110: 1 · 91-100: 2</span> · <span class="text-error">≤90 or ≥220: 3</span>',
    hr: '<span class="text-success">51-90: 0</span> · <span class="text-warning">41-50/91-110: 1 · 111-130: 2</span> · <span class="text-error">≤40 or ≥131: 3</span>',
    avpu: '<span class="text-success">Alert: 0</span> · <span class="text-error">CVPU/V/P/U: 3</span>',
    temp: '<span class="text-success">36.1-38.0°C: 0</span> · <span class="text-warning">35.1-36.0/38.1-39.0: 1 · ≥39.1: 2</span> · <span class="text-error">≤35.0: 3</span>',
  }
  return labels[param] || ''
}

// ── Dialog management ──────────────────────────────────────────────────────

function openDialog(item) {
  if (item) {
    editing.value = item.id
    const vs = item.vital_signs || {}
    vitalsForm.patient = item.patient
    vitalsForm.temperature = vs.temperature ?? null
    vitalsForm.bp_systolic = vs.bp_systolic ?? vs.blood_pressure_systolic ?? null
    vitalsForm.bp_diastolic = vs.bp_diastolic ?? vs.blood_pressure_diastolic ?? null
    vitalsForm.heart_rate = vs.heart_rate ?? null
    vitalsForm.respiratory_rate = vs.respiratory_rate ?? null
    vitalsForm.oxygen_saturation = vs.oxygen_saturation ?? null
    vitalsForm.weight = vs.weight ?? null
    vitalsForm.height = vs.height ?? null
    vitalsForm.spo2_scale = vs.spo2_scale || 1
    vitalsForm.on_oxygen = vs.on_oxygen || false
    vitalsForm.consciousness = vs.consciousness || 'A'
  } else {
    editing.value = null
    Object.assign(vitalsForm, {
      patient: null, temperature: null, bp_systolic: null, bp_diastolic: null,
      heart_rate: null, respiratory_rate: null, oxygen_saturation: null,
      weight: null, height: null, spo2_scale: 1, on_oxygen: false, consciousness: 'A',
    })
  }
  dialog.value = true
}

async function saveVitals() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  const payload = { ...vitalsForm }
  // Always send vital_signs as a nested dict with all fields + NEWS2 data
  payload.vital_signs = {
    temperature: vitalsForm.temperature,
    bp_systolic: vitalsForm.bp_systolic,
    bp_diastolic: vitalsForm.bp_diastolic,
    heart_rate: vitalsForm.heart_rate,
    respiratory_rate: vitalsForm.respiratory_rate,
    oxygen_saturation: vitalsForm.oxygen_saturation,
    weight: vitalsForm.weight,
    height: vitalsForm.height,
    spo2_scale: vitalsForm.spo2_scale,
    on_oxygen: vitalsForm.on_oxygen,
    consciousness: vitalsForm.consciousness,
    news2_score: news2Total.value,
    news2_category: news2CategoryLabel.value,
  }
  // Clean top-level copies
  delete payload.temperature
  delete payload.bp_systolic
  delete payload.bp_diastolic
  delete payload.heart_rate
  delete payload.respiratory_rate
  delete payload.oxygen_saturation
  delete payload.weight
  delete payload.height
  delete payload.spo2_scale
  delete payload.on_oxygen
  delete payload.consciousness
  try {
    if (editing.value) await r.update(editing.value, payload)
    else await r.create(payload)
    snack.text = editing.value ? 'Vitals updated' : 'Vitals recorded'
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    r.list({ page_size: 1000 })
  } catch {
    snack.text = r.error.value || 'Failed to save vitals'
    snack.color = 'error'
    snack.show = true
  }
}

function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Vitals record deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    deleteTarget.value = null
  } catch {
    snack.text = r.error.value || 'Failed to delete vitals'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.filter-bar {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.results-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
}
.kpi-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  transition: box-shadow 0.2s ease;
}
.kpi-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

/* Dialog header accent */
.dialog-header {
  background: linear-gradient(135deg, rgba(var(--v-theme-error), 0.06), rgba(var(--v-theme-error), 0.02));
}

/* Table row styling */
.vitals-table :deep(thead th) {
  font-weight: 600 !important;
  font-size: 0.75rem !important;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.vitals-table :deep(tbody td) {
  padding-top: 8px !important;
  padding-bottom: 8px !important;
}

/* NEWS2 parameter card colour accents */
.news2-param { border-width: 2px; }
.news2-green { border-color: rgb(var(--v-theme-success)); }
.news2-amber { border-color: rgb(var(--v-theme-warning)); }
.news2-red { border-color: rgb(var(--v-theme-error)); }
.news2-green .v-chip { background-color: rgb(var(--v-theme-success)) !important; background: rgb(var(--v-theme-success)) !important; }
.news2-amber .v-chip { background-color: rgb(var(--v-theme-warning)) !important; background: rgb(var(--v-theme-warning)) !important; }
.news2-red .v-chip { background-color: rgb(var(--v-theme-error)) !important; background: rgb(var(--v-theme-error)) !important; }
</style>
