<template>
  <div class="doctor-workspace">
    <!-- ── Allergy Banner ── -->
    <v-slide-y-transition>
      <div v-if="allergyBanner" class="allergy-banner d-flex align-center px-4 py-2">
        <v-icon color="white" class="mr-2" size="20">mdi-alert-circle</v-icon>
        <span class="text-body-2 font-weight-bold text-white flex-grow-1">{{ allergyBanner }}</span>
        <v-chip color="white" variant="plain" size="x-small" class="text-uppercase">High Alert</v-chip>
      </div>
    </v-slide-y-transition>

    <!-- ── Addendum Banner ── -->
    <div v-if="addendumMode" class="addendum-banner d-flex align-center px-4 py-1">
      <v-icon color="warning" class="mr-2" size="18">mdi-plus-circle-outline</v-icon>
      <span class="text-caption font-weight-bold text-warning-darken-2">
        Adding addendum to signed note dated {{ formatDate(consultation.signed_at) }}
      </span>
    </div>

    <!-- ── Top Action Bar ── -->
    <div class="top-bar d-flex align-center justify-space-between px-4 py-2 border-b">
      <div class="d-flex align-center ga-2">
        <v-btn icon variant="text" to="/clinics/consultations"><v-icon>mdi-arrow-left</v-icon></v-btn>
        <v-avatar color="primary" variant="tonal" size="36" class="mr-1">
          <v-icon size="20">mdi-stethoscope</v-icon>
        </v-avatar>
        <div>
          <div class="text-subtitle-1 font-weight-bold d-flex align-center ga-2">
            {{ consultation?.patient_name || 'Doctor Workspace' }}
            <v-chip :color="statusColor" variant="tonal" size="x-small">{{ statusLabel }}</v-chip>
            <v-chip v-if="consultation?.disposition && consultation.disposition !== 'pending'" color="red-darken-2" variant="tonal" size="x-small">
              {{ dispositionLabel }}
            </v-chip>
          </div>
          <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
            <template v-if="consultation">
              <v-icon size="12">mdi-content-save-cog</v-icon>
              {{ autoSaveStatus }}
              <v-divider vertical class="mx-1" />
              <span>Updated {{ timeAgo(consultation.updated_at) }}</span>
            </template>
            <span v-else>Loading consultation…</span>
          </div>
        </div>
      </div>
      <div class="d-flex align-center ga-2">
        <!-- Sign checklist -->
        <v-menu v-if="!isLocked" :close-on-content-click="false" location="bottom">
          <template #activator="{ props }">
            <v-btn variant="text" size="small" v-bind="props" prepend-icon="mdi-clipboard-check-outline">
              <span class="text-none">Sign-Check ({{ signProgress.completed }}/{{ signProgress.total }})</span>
              <v-progress-circular :model-value="signProgress.pct" size="14" width="2" class="ml-2" color="success" />
            </v-btn>
          </template>
          <v-card min-width="280" rounded="lg">
            <v-list density="compact">
              <v-list-item v-for="(c, i) in signChecklist" :key="i">
                <template #prepend>
                  <v-icon :color="c.done ? 'success' : 'grey'" size="18">{{ c.done ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                </template>
                <v-list-item-title class="text-body-2">{{ c.label }}</v-list-item-title>
              </v-list-item>
            </v-list>
            <v-divider />
            <v-card-text class="text-caption text-medium-emphasis">{{ signChecklist.filter(c => c.done).length }}/{{ signChecklist.length }} required items complete</v-card-text>
          </v-card>
        </v-menu>

        <!-- Command Palette -->
        <v-btn variant="text" size="small" @click="cmdPalette = true" prepend-icon="mdi-keyboard">
          <span class="text-none">⌘K</span>
        </v-btn>
        <v-divider vertical class="mx-1" />
        <v-btn v-if="canAddendum" variant="outlined" rounded="lg" size="small" @click="startAddendum">Add Addendum</v-btn>
        <v-btn color="primary" rounded="lg" size="small" prepend-icon="mdi-draw" :disabled="!canSign" @click="signDialog = true">
          <v-icon v-if="isLocked" left size="small">mdi-lock</v-icon>
          Sign Encounter
        </v-btn>
      </div>
    </div>

    <!-- ── Three-Panel Layout ── -->
    <div class="three-panels">
      <!-- ═══ Left: Patient Context ═══ -->
      <div class="left-panel">
        <PatientContextCard v-if="patient" :patient="patient" :triage="triageData" :activeMeds="activeMeds" :pastVisits="pastVisits" />
        <div v-else class="pa-4 text-center">
          <v-progress-circular indeterminate color="primary" size="24" />
        </div>
      </div>

      <!-- ═══ Center: Documentation ═══ -->
      <div class="center-panel">
        <!-- Section navigation rail -->
        <div class="section-nav">
          <v-btn
            v-for="s in sections"
            :key="s.id"
            :color="activeSection === s.id ? 'primary' : 'default'"
            size="small"
            variant="text"
            class="text-none nav-btn"
            @click="scrollTo(s.id)"
          >
            <v-icon :icon="s.icon" size="16" start />
            <span class="nav-label">{{ s.label }}</span>
            <v-icon v-if="sectionFilled(s.id)" size="10" color="success" class="ml-1">mdi-circle</v-icon>
          </v-btn>
        </div>

        <div class="scroll-container">
          <template v-if="!addendumMode">
            <!-- ── Chief Complaint ── -->
            <DocSection id="cc" icon="mdi-format-text" title="Chief Complaint" color="primary" :expanded="true" :readonly="isLocked" :filled="!!form.chief_complaint">
              <v-text-field v-model="form.chief_complaint" placeholder="Chief complaint…" variant="outlined" density="compact" hide-details :readonly="isLocked" />
              <div class="d-flex flex-wrap ga-1 mt-2">
                <v-chip v-for="q in commonComplaints" :key="q" size="x-small" variant="outlined" @click="form.chief_complaint = q" class="cursor-pointer">{{ q }}</v-chip>
              </div>
            </DocSection>

            <!-- ── HPI ── -->
            <DocSection id="hpi" icon="mdi-text-box" title="History of Present Illness (HPI)" color="blue" :filled="!!form.history_present_illness" :readonly="isLocked">
              <div v-if="!isLocked" class="d-flex ga-1 mb-2 flex-wrap">
                <v-chip v-for="t in hpiTemplates" :key="t.label" size="x-small" variant="outlined" color="blue" @click="insertHpiTemplate(t)" class="cursor-pointer">
                  <v-icon size="12" start>mdi-lightning-bolt</v-icon>{{ t.label }}
                </v-chip>
              </div>
              <v-textarea v-model="form.history_present_illness" placeholder="HPI narrative (OPQRST: Onset, Provocation, Quality, Radiation, Severity, Time)…" variant="outlined" density="compact" rows="5" :readonly="isLocked" />
            </DocSection>

            <!-- ── ROS ── -->
            <DocSection id="ros" icon="mdi-check-all" title="Review of Systems (ROS)" color="teal" :filled="rosFilled" :readonly="isLocked">
              <div class="d-flex ga-2 mb-2">
                <v-btn size="small" variant="tonal" prepend-icon="mdi-check-all" @click="rosNormal" :disabled="isLocked">All Normal</v-btn>
                <v-btn size="small" variant="text" prepend-icon="mdi-refresh" @click="resetROS" :disabled="isLocked">Reset</v-btn>
              </div>
              <div class="ros-grid">
                <div v-for="sys in rosSystems" :key="sys.key" class="ros-item">
                  <v-checkbox v-model="form.review_of_systems[sys.key]" color="primary" density="compact" hide-details :label="sys.label" :disabled="isLocked" />
                  <v-icon v-if="form.review_of_systems[sys.key] === false" size="12" color="error" class="ml-1">mdi-alert</v-icon>
                </div>
              </div>
            </DocSection>

            <!-- ── Past Medical History ── -->
            <DocSection id="pmh" icon="mdi-medical-bag" title="Past Medical History" color="indigo" :filled="!!form.past_medical_history" :readonly="isLocked">
              <v-textarea v-model="form.past_medical_history" placeholder="PMH…" variant="outlined" density="compact" rows="3" :readonly="isLocked" />
            </DocSection>

            <!-- Compact histories in a 3-col grid -->
            <v-row dense>
              <v-col cols="12" sm="4">
                <DocSection icon="mdi-cut" title="Surgical Hx" color="orange" :expanded="false" :readonly="isLocked" :filled="!!form.surgical_history">
                  <v-textarea v-model="form.surgical_history" placeholder="Surgical history…" variant="outlined" density="compact" rows="2" :readonly="isLocked" />
                </DocSection>
              </v-col>
              <v-col cols="12" sm="4">
                <DocSection icon="mdi-family-tree" title="Family Hx" color="green" :expanded="false" :readonly="isLocked" :filled="!!form.family_history">
                  <v-textarea v-model="form.family_history" placeholder="Family history…" variant="outlined" density="compact" rows="2" :readonly="isLocked" />
                </DocSection>
              </v-col>
              <v-col cols="12" sm="4">
                <DocSection icon="mdi-smoking-off" title="Social Hx" color="brown" :expanded="false" :readonly="isLocked" :filled="!!form.social_history">
                  <v-textarea v-model="form.social_history" placeholder="Social history…" variant="outlined" density="compact" rows="2" :readonly="isLocked" />
                </DocSection>
              </v-col>
            </v-row>

            <!-- ── Medication Reconciliation ── -->
            <DocSection id="medrec" icon="mdi-pill" title="Medication Reconciliation" color="purple" :filled="reconciledFilled" :readonly="isLocked" badge="reconciled">
              <div v-for="(m, i) in form.medication_history" :key="i" class="d-flex align-center ga-2 mb-2">
                <v-text-field v-model="m.name" placeholder="Drug" variant="outlined" density="compact" hide-details :readonly="isLocked" />
                <v-text-field v-model="m.dose" placeholder="Dose" variant="outlined" density="compact" hide-details style="max-width: 100px" :readonly="isLocked" />
                <v-text-field v-model="m.frequency" placeholder="Freq" variant="outlined" density="compact" hide-details style="max-width: 100px" :readonly="isLocked" />
                <v-checkbox v-model="m.reconciled" label="Recon" density="compact" hide-details :readonly="isLocked" />
                <v-btn v-if="!isLocked" icon="mdi-delete" size="small" variant="text" color="error" @click="form.medication_history.splice(i, 1)" />
              </div>
              <v-btn v-if="!isLocked" size="small" variant="text" prepend-icon="mdi-plus" @click="form.medication_history.push({name:'', dose:'', frequency:'', reconciled: false})">Add</v-btn>
            </DocSection>

            <!-- ── Allergies ── -->
            <DocSection icon="mdi-alert" title="Allergies (Confirmed)" color="red" :filled="!!form.allergies_confirmed.length" :readonly="isLocked">
              <div class="d-flex flex-wrap ga-2 align-center">
                <v-chip v-for="(a,i) in form.allergies_confirmed" :key="i" color="error" variant="tonal" closable @click:close="form.allergies_confirmed.splice(i,1)" :disabled="isLocked">
                  {{ a }}
                </v-chip>
                <span v-if="!form.allergies_confirmed.length" class="text-body-2 text-medium-emphasis">No known allergies (NKA)</span>
              </div>
              <div v-if="!isLocked" class="d-flex ga-2 mt-2">
                <v-text-field v-model="newAllergy" placeholder="Add allergy…" variant="outlined" density="compact" hide-details @keydown.enter="addAllergy" />
                <v-btn variant="tonal" color="error" @click="addAllergy" prepend-icon="mdi-plus">Add</v-btn>
              </div>
            </DocSection>

            <!-- ── Physical Examination ── -->
            <DocSection id="exam" icon="mdi-stethoscope" title="Physical Examination" color="cyan" :filled="!!form.examination_findings" :readonly="isLocked">
              <v-textarea v-model="form.examination_findings" placeholder="Examination findings (general, system-by-system)…" variant="outlined" density="compact" rows="4" :readonly="isLocked" />
            </DocSection>

            <!-- ── Assessment ── -->
            <DocSection id="assessment" icon="mdi-clipboard-pulse" title="Assessment" color="warning" :expanded="true" :readonly="isLocked" :filled="!!form.assessment">
              <v-textarea v-model="form.assessment" placeholder="Clinical assessment narrative…" variant="outlined" density="compact" rows="4" :readonly="isLocked" />
            </DocSection>

            <!-- ── Differential Diagnosis ── -->
            <DocSection icon="mdi-source-branch" title="Differential Diagnosis" color="deep-purple" :filled="!!form.differential_diagnosis.length" :readonly="isLocked">
              <div v-for="(d, i) in form.differential_diagnosis" :key="i" class="d-flex align-center ga-2 mb-2">
                <v-text-field v-model="d.code" placeholder="ICD-10" variant="outlined" density="compact" hide-details style="max-width: 120px" :readonly="isLocked" />
                <v-text-field v-model="d.description" placeholder="Differential…" variant="outlined" density="compact" hide-details :readonly="isLocked" />
                <v-chip size="x-small" variant="tonal" color="deep-purple">{{ i + 1 }}</v-chip>
                <v-btn v-if="!isLocked" icon="mdi-delete" size="small" variant="text" color="error" @click="form.differential_diagnosis.splice(i, 1)" />
              </div>
              <v-btn v-if="!isLocked" size="small" variant="text" prepend-icon="mdi-plus" @click="form.differential_diagnosis.push({code:'', description:''})">Add</v-btn>
            </DocSection>

            <!-- ── Final Diagnosis ── -->
            <DocSection id="diagnosis" icon="mdi-clipboard-check" title="Final Diagnosis (ICD-10)" color="success" :expanded="true" :readonly="isLocked" :filled="!!form.diagnosis.length">
              <div v-for="(d, i) in form.diagnosis" :key="i" class="d-flex align-center ga-2 mb-2">
                <v-chip size="small" variant="tonal" :color="i === 0 ? 'primary' : 'grey'">{{ i === 0 ? 'Primary' : `#${i+1}` }}</v-chip>
                <v-text-field v-model="d.code" placeholder="ICD-10 code" variant="outlined" density="compact" hide-details style="max-width: 120px" :readonly="isLocked" />
                <v-text-field v-model="d.description" placeholder="Diagnosis description" variant="outlined" density="compact" hide-details :readonly="isLocked" />
                <v-btn v-if="!isLocked" icon="mdi-arrow-up" size="small" variant="text" @click="moveDiagUp(i)" :disabled="i === 0" />
                <v-btn v-if="!isLocked" icon="mdi-delete" size="small" variant="text" color="error" @click="form.diagnosis.splice(i, 1)" />
              </div>
              <v-btn v-if="!isLocked" size="small" variant="text" prepend-icon="mdi-magnify" @click="icdSearch = true">Search ICD-10</v-btn>
            </DocSection>

            <!-- ── Clinical Decision Making ── -->
            <DocSection icon="mdi-brain" title="Clinical Decision Making" color="indigo-darken-2" :filled="!!form.clinical_decision_making" :readonly="isLocked">
              <v-textarea v-model="form.clinical_decision_making" placeholder="CDM narrative…" variant="outlined" density="compact" rows="3" :readonly="isLocked" />
            </DocSection>

            <!-- ── Management Plan ── -->
            <DocSection id="plan" icon="mdi-clipboard-text" title="Management Plan" color="teal-darken-2" :filled="!!form.treatment_plan" :readonly="isLocked">
              <v-textarea v-model="form.treatment_plan" placeholder="Plan…" variant="outlined" density="compact" rows="3" :readonly="isLocked" />
            </DocSection>

            <!-- ── Notes ── -->
            <DocSection icon="mdi-note-text" title="Notes" color="grey-darken-2" :expanded="false" :filled="!!form.notes" :readonly="isLocked">
              <v-textarea v-model="form.notes" placeholder="Additional notes…" variant="outlined" density="compact" rows="3" :readonly="isLocked" />
            </DocSection>

            <!-- Review Panel -->
            <template v-if="reviewMode">
              <DocSection icon="mdi-microscope" title="Lab Results (Review)" color="teal" :expanded="true" :readonly="false">
                <ResultsReviewPanel type="lab" :consultationId="consultationId" />
              </DocSection>
              <DocSection icon="mdi-x-ray" title="Radiology Results (Review)" color="blue" :expanded="true" :readonly="false">
                <ResultsReviewPanel type="radiology" :consultationId="consultationId" />
              </DocSection>
            </template>
          </template>

          <!-- Addendum Mode -->
          <template v-else>
            <v-alert type="warning" variant="tonal" class="mb-3" prepend-icon="mdi-information">
              <span class="font-weight-bold">Addendum Mode</span> — Your addition will be appended to the locked note. The original note is not modified.
            </v-alert>
            <v-card rounded="lg" variant="outlined" class="pa-4">
              <div class="text-subtitle-2 font-weight-bold mb-2">Addendum Content</div>
              <v-textarea v-model="addendumContent" placeholder="Enter addendum content…" variant="outlined" density="compact" rows="8" autofocus />
              <div class="d-flex justify-end ga-2 mt-3">
                <v-btn variant="text" @click="cancelAddendum">Cancel</v-btn>
                <v-btn color="warning" prepend-icon="mdi-draw" :loading="addendumSaving" @click="saveAddendum">Sign Addendum</v-btn>
              </div>
            </v-card>
          </template>

          <!-- Disposition -->
          <DocSection v-if="!addendumMode" id="disposition" icon="mdi-exit-run" title="Disposition" color="red-darken-2" :expanded="true" :readonly="isLocked">
            <v-select v-model="form.disposition" :items="dispositionOptions" item-title="title" item-value="value" label="Disposition" variant="outlined" density="compact" :readonly="isLocked" />
          </DocSection>

          <!-- Existing addenda -->
          <template v-if="consultation?.addenda?.length && !addendumMode">
            <v-card rounded="lg" variant="outlined" class="mb-3">
              <div class="pa-3 bg-warning-lighten-4 d-flex align-center">
                <v-icon color="warning" class="mr-2">mdi-plus-circle</v-icon>
                <span class="text-subtitle-2 font-weight-bold">Addenda ({{ consultation.addenda.length }})</span>
              </div>
              <v-divider />
              <div v-for="a in consultation.addenda" :key="a.id" class="pa-3 border-b">
                <div class="d-flex align-center justify-space-between mb-1">
                  <span class="text-caption font-weight-bold">{{ a.author_name }} — {{ formatDateTime(a.signed_at) }}</span>
                </div>
                <div class="text-body-2" style="white-space: pre-wrap;">{{ a.content }}</div>
              </div>
            </v-card>
          </template>
        </div>
      </div>

      <!-- ═══ Right: Orders and Plan ═══ -->
      <div class="right-panel">
        <OrdersPanel
          :consultationId="consultationId"
          :patientId="form.patient"
          :readonly="isLocked"
          :orders="orders"
          :allergies="form.allergies_confirmed?.length ? form.allergies_confirmed : patient?.allergies || []"
          @order-placed="onOrderPlaced"
          @refresh-orders="loadConsultation"
        />
      </div>
    </div>

    <!-- ── Sign Encounter Dialog ── -->
    <v-dialog v-model="signDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-draw-pen</v-icon>
          Sign Encounter
        </v-card-title>
        <v-card-text>
          <v-alert type="info" variant="tonal" class="mb-3">
            Once signed, the encounter will be locked and immutable. Further changes require an addendum.
          </v-alert>
          <div class="text-body-2 mb-2">
            <strong>Diagnosis:</strong> {{ form.diagnosis?.map(d => d.code).join(', ') || 'None' }}<br>
            <strong>Disposition:</strong> {{ dispositionLabel }}
          </div>
          <v-alert v-for="(c, i) in incompleteSignItems" :key="i" type="warning" variant="tonal" density="compact" class="mb-1" icon="mdi-alert">
            {{ c.label }} is missing
          </v-alert>
          <v-text-field v-model="signPassword" label="Re-enter password to sign" type="password" variant="outlined" density="compact" class="mt-2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="signDialog = false">Cancel</v-btn>
          <v-btn color="primary" prepend-icon="mdi-lock" :loading="signing" @click="signEncounter">Sign and Lock</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── ICD-10 Search Dialog ── -->
    <v-dialog v-model="icdSearch" max-width="600">
      <v-card rounded="xl">
        <v-card-title class="text-h6"><v-icon class="mr-2">mdi-magnify</v-icon>ICD-10 Code Search</v-card-title>
        <v-card-text>
          <v-text-field v-model="icdQuery" prepend-inner-icon="mdi-magnify" placeholder="Search ICD-10…" variant="outlined" density="compact" @update:model-value="searchICD" autofocus />
          <v-list density="compact" max-height="400" class="overflow-y-auto">
            <v-list-item v-for="code in icdResults" :key="code.code" @click="addDiagnosis(code)" :title="code.code" :subtitle="code.description">
              <template #prepend><v-icon>mdi-clipboard-check</v-icon></template>
            </v-list-item>
            <div v-if="icdResults.length === 0" class="text-center pa-4 text-medium-emphasis">
              {{ icdQuery ? 'No results — enter manually' : 'Start typing to search ICD-10 codes' }}
            </div>
          </v-list>
        </v-card-text>
      </v-card>
    </v-dialog>

    <!-- ── Command Palette ── -->
    <v-dialog v-model="cmdPalette" max-width="600">
      <v-card rounded="xl">
        <v-text-field v-model="cmdQuery" prepend-inner-icon="mdi-magnify" placeholder="Jump to section, insert template…" variant="outlined" density="compact" autofocus class="px-4 pt-4" @keydown.enter="executeCmd" />
        <v-list density="compact">
          <v-list-item v-for="cmd in filteredCmds" :key="cmd.id" :prepend-icon="cmd.icon" :title="cmd.label" @click="runCmd(cmd)" />
        </v-list>
      </v-card>
    </v-dialog>

    <!-- ── Toast ── -->
    <v-snackbar v-model="toast.visible" :color="toast.color" :timeout="3000" location="top right">
      {{ toast.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { formatDate, formatDateTime } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const auth = useAuthStore()

const consultationId = computed(() => route.params.id)
const consultation = ref(null)
const patient = ref(null)
const triageData = ref(null)
const activeMeds = ref([])
const pastVisits = ref([])
const orders = ref([])
const saving = ref(false)
const lastSaved = ref(null)
const signing = ref(false)
const signDialog = ref(false)
const signPassword = ref('')
const icdSearch = ref(false)
const icdQuery = ref('')
const icdResults = ref([])
const cmdPalette = ref(false)
const cmdQuery = ref('')
const addendumMode = ref(false)
const addendumContent = ref('')
const addendumSaving = ref(false)
const newAllergy = ref('')
const activeSection = ref('cc')
const toast = reactive({ visible: false, text: '', color: 'success' })

function showToast(text, color = 'success') {
  toast.text = text; toast.color = color; toast.visible = true
}

const form = reactive({
  patient: null, doctor: null, triage: null, appointment: null,
  chief_complaint: '', history_present_illness: '',
  review_of_systems: {}, past_medical_history: '',
  surgical_history: '', family_history: '', social_history: '',
  medication_history: [], allergies_confirmed: [],
  examination_findings: '', assessment: '',
  differential_diagnosis: [], diagnosis: [],
  clinical_decision_making: '', treatment_plan: '',
  disposition: 'pending', notes: '',
  vital_signs: {}, status: 'draft',
})

const rosSystems = [
  { key: 'constitutional', label: 'Constitutional' },
  { key: 'eyes', label: 'Eyes' },
  { key: 'ent', label: 'ENT' },
  { key: 'cardiovascular', label: 'Cardiovascular' },
  { key: 'respiratory', label: 'Respiratory' },
  { key: 'gastrointestinal', label: 'GI' },
  { key: 'genitourinary', label: 'GU' },
  { key: 'musculoskeletal', label: 'Musculoskeletal' },
  { key: 'neurological', label: 'Neurological' },
  { key: 'skin', label: 'Skin' },
  { key: 'psychiatric', label: 'Psychiatric' },
  { key: 'endocrine', label: 'Endocrine' },
]

const dispositionOptions = [
  { title: 'Pending', value: 'pending' },
  { title: 'Discharge', value: 'discharge' },
  { title: 'Referral', value: 'referral' },
  { title: 'Admission', value: 'admission' },
  { title: 'Observation', value: 'observation' },
  { title: 'Transfer', value: 'transfer' },
  { title: 'Left AMA', value: 'left_ama' },
]

const sections = [
  { id: 'cc', label: 'CC', icon: 'mdi-format-text' },
  { id: 'hpi', label: 'HPI', icon: 'mdi-text-box' },
  { id: 'ros', label: 'ROS', icon: 'mdi-check-all' },
  { id: 'pmh', label: 'PMH', icon: 'mdi-medical-bag' },
  { id: 'medrec', label: 'Med Rec', icon: 'mdi-pill' },
  { id: 'exam', label: 'Exam', icon: 'mdi-stethoscope' },
  { id: 'assessment', label: 'A', icon: 'mdi-clipboard-pulse' },
  { id: 'diagnosis', label: 'Dx', icon: 'mdi-clipboard-check' },
  { id: 'plan', label: 'Plan', icon: 'mdi-clipboard-text' },
  { id: 'disposition', label: 'Disp', icon: 'mdi-exit-run' },
]

const commonComplaints = [
  'Fever', 'Headache', 'Abdominal pain', 'Chest pain', 'Cough', 'Shortness of breath',
  'Back pain', 'Nausea and vomiting', 'Dizziness', 'Fatigue', 'Sore throat', 'Joint pain',
]
const hpiTemplates = [
  { label: 'Sudden onset', text: 'Symptom onset was sudden, occurring approximately ___ hours/days ago. ' },
  { label: 'Gradual onset', text: 'Symptoms began gradually over ___ days/weeks and have progressively worsened. ' },
  { label: 'Sharp pain', text: 'Patient describes the pain as sharp, rated ___/10 in severity, located in ___. ' },
  { label: 'Dull ache', text: 'Patient describes a dull, aching pain rated ___/10, exacerbated by ___, relieved by ___. ' },
  { label: 'No relief', text: 'Symptoms have not responded to over-the-counter analgesics or rest. ' },
]

const isLocked = computed(() => consultation.value?.status === 'locked')
const canSign = computed(() => signChecklist.value.every(c => c.done) && !isLocked.value)
const canAddendum = computed(() => isLocked.value)
const statusColor = computed(() => ({ draft: 'info', signed: 'primary', locked: 'error' })[form.status] || 'grey')
const statusLabel = computed(() => ({ draft: 'Draft', signed: 'Signed', locked: 'Locked' })[form.status] || 'Draft')
const dispositionLabel = computed(() => dispositionOptions.find(d => d.value === form.disposition)?.title || form.disposition)
const reviewMode = computed(() => isLocked.value && orders.value.some(o => o.status === 'completed'))

const allergyBanner = computed(() => {
  const a = form.allergies_confirmed?.length ? form.allergies_confirmed : patient.value?.allergies
  if (!a?.length) return ''
  return `ALLERGIES: ${a.join(', ')}`
})
const autoSaveStatus = computed(() => {
  if (saving.value) return 'Saving…'
  if (lastSaved.value) return `Saved ${timeAgo(lastSaved.value)}`
  return 'Auto-save on'
})

// Sign checklist
const signChecklist = computed(() => [
  { label: 'Chief complaint', done: !!form.chief_complaint },
  { label: 'HPI', done: !!form.history_present_illness },
  { label: 'Physical Examination', done: !!form.examination_findings },
  { label: 'Assessment', done: !!form.assessment },
  { label: 'Diagnosis', done: !!form.diagnosis?.length },
  { label: 'Management Plan', done: !!form.treatment_plan },
])
const signProgress = computed(() => {
  const done = signChecklist.value.filter(c => c.done).length
  const total = signChecklist.value.length
  return { completed: done, total, pct: Math.round(done / total * 100) }
})
const incompleteSignItems = computed(() => signChecklist.value.filter(c => !c.done))

function sectionFilled(id) {
  return ({
    cc: !!form.chief_complaint,
    hpi: !!form.history_present_illness,
    ros: rosFilled.value,
    pmh: !!form.past_medical_history,
    medrec: reconciledFilled.value,
    exam: !!form.examination_findings,
    assessment: !!form.assessment,
    diagnosis: !!form.diagnosis?.length,
    plan: !!form.treatment_plan,
    disposition: form.disposition !== 'pending',
  })[id] || false
}
const rosFilled = computed(() => Object.keys(form.review_of_systems).length >= rosSystems.length)
const reconciledFilled = computed(() => form.medication_history.length > 0 && form.medication_history.every(m => m.reconciled))

function timeAgo(d) {
  if (!d) return ''
  const diff = Math.floor((Date.now() - new Date(d)) / 1000)
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  return `${Math.floor(diff / 3600)}h ago`
}

function rosNormal() { rosSystems.forEach(s => form.review_of_systems[s.key] = true) }
function resetROS() { form.review_of_systems = {} }

function addAllergy() {
  if (newAllergy.value && !form.allergies_confirmed.includes(newAllergy.value)) {
    form.allergies_confirmed.push(newAllergy.value)
    newAllergy.value = ''
  }
}

function insertHpiTemplate(t) {
  form.history_present_illness = (form.history_present_illness || '') + t.text
}

function moveDiagUp(i) {
  if (i > 0) { const a = form.diagnosis[i]; form.diagnosis.splice(i, 1); form.diagnosis.splice(i - 1, 0, a) }
}
function addDiagnosis(code) {
  form.diagnosis.push({ code: code.code, description: code.description })
  icdSearch.value = false; icdQuery.value = ''
  showToast(`Added ${code.code}`, 'success')
}

const icdList = [
  { code: 'J00', description: 'Acute nasopharyngitis [common cold]' },
  { code: 'J02.9', description: 'Acute pharyngitis, unspecified' },
  { code: 'J03.90', description: 'Acute tonsillitis, unspecified' },
  { code: 'J45.909', description: 'Unspecified asthma, uncomplicated' },
  { code: 'J20.9', description: 'Acute bronchitis, unspecified' },
  { code: 'J11.1', description: 'Influenza with other respiratory manifestations' },
  { code: 'I10', description: 'Essential (primary) hypertension' },
  { code: 'I11.9', description: 'Hypertensive heart disease without heart failure' },
  { code: 'E11.9', description: 'Type 2 diabetes mellitus without complications' },
  { code: 'E78.5', description: 'Hyperlipidemia, unspecified' },
  { code: 'K21.9', description: 'Gastro-esophageal reflux disease without esophagitis' },
  { code: 'K59.00', description: 'Constipation, unspecified' },
  { code: 'N39.0', description: 'Urinary tract infection, site not specified' },
  { code: 'R51.9', description: 'Headache, unspecified' },
  { code: 'R10.9', description: 'Unspecified abdominal pain' },
  { code: 'R50.9', description: 'Fever, unspecified' },
  { code: 'M54.5', description: 'Low back pain' },
  { code: 'M25.561', description: 'Pain in right knee' },
  { code: 'M25.562', description: 'Pain in left knee' },
  { code: 'S93.401A', description: 'Unspecified sprain of right ankle' },
  { code: 'S93.402A', description: 'Unspecified sprain of left ankle' },
  { code: 'F41.9', description: 'Anxiety disorder, unspecified' },
  { code: 'F32.9', description: 'Major depressive disorder, single episode, unspecified' },
  { code: 'F90.9', description: 'Attention-deficit hyperactivity disorder, unspecified type' },
  { code: 'A09', description: 'Infectious gastroenteritis and colitis, unspecified' },
  { code: 'B34.9', description: 'Viral infection, unspecified' },
  { code: 'L30.9', description: 'Dermatitis, unspecified' },
  { code: 'H66.90', description: 'Otitis media, unspecified, unspecified ear' },
  { code: 'H10.9', description: 'Unspecified conjunctivitis' },
  { code: 'M25.50', description: 'Pain in unspecified joint' },
  { code: 'R07.9', description: 'Chest pain, unspecified' },
  { code: 'I50.9', description: 'Heart failure, unspecified' },
  { code: 'N17.9', description: 'Acute kidney failure, unspecified' },
  { code: 'N18.9', description: 'Chronic kidney disease, unspecified' },
  { code: 'C50.9', description: 'Malignant neoplasm of breast, unspecified' },
]
function searchICD(q) {
  if (!q) { icdResults.value = []; return }
  const ql = q.toLowerCase()
  icdResults.value = icdList.filter(c => c.code.toLowerCase().includes(ql) || c.description.toLowerCase().includes(ql)).slice(0, 20)
}

const cmds = [
  { id: 'cc', label: 'Jump to Chief Complaint', icon: 'mdi-format-text', action: () => scrollTo('cc') },
  { id: 'hpi', label: 'Jump to HPI', icon: 'mdi-text-box', action: () => scrollTo('hpi') },
  { id: 'ros', label: 'Jump to ROS', icon: 'mdi-check-all', action: () => scrollTo('ros') },
  { id: 'assessment', label: 'Jump to Assessment', icon: 'mdi-clipboard-pulse', action: () => scrollTo('assessment') },
  { id: 'diagnosis', label: 'Jump to Diagnosis', icon: 'mdi-clipboard-check', action: () => scrollTo('diagnosis') },
  { id: 'plan', label: 'Jump to Plan', icon: 'mdi-clipboard-text', action: () => scrollTo('plan') },
  { id: 'icd', label: 'Search ICD-10', icon: 'mdi-magnify', action: () => { cmdPalette.value = false; icdSearch.value = true } },
  { id: 'lab', label: 'Order Lab (right panel)', icon: 'mdi-microscope', action: () => showToast('Use the Lab tab on the right panel') },
  { id: 'normal_ros', label: 'Fill ROS - All Normal', icon: 'mdi-check-all', action: () => { rosNormal(); cmdPalette.value = false; showToast('ROS marked all normal') } },
  { id: 'sign', label: 'Sign Encounter', icon: 'mdi-draw', action: () => { cmdPalette.value = false; if (canSign.value) signDialog.value = true; else showToast('Sign checklist incomplete', 'warning') } },
]
const filteredCmds = computed(() => {
  if (!cmdQuery.value) return cmds
  const q = cmdQuery.value.toLowerCase()
  return cmds.filter(c => c.label.toLowerCase().includes(q))
})
function executeCmd() { if (filteredCmds.value[0]) runCmd(filteredCmds.value[0]) }
function runCmd(cmd) { if (cmd.action) cmd.action(); cmdPalette.value = false }
function scrollTo(id) {
  cmdPalette.value = false
  activeSection.value = id
  document.getElementById(`section-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

onMounted(() => {
  if (process.client) {
    window.addEventListener('keydown', handleGlobalKey)
    if (consultationId.value && consultationId.value !== 'new') loadConsultation()
    if (route.query.patient) form.patient = Number(route.query.patient)
    if (route.query.triage) form.triage = Number(route.query.triage)
    if (route.query.appointment) form.appointment = Number(route.query.appointment)
    if (route.query.patient && (!consultationId.value || consultationId.value === 'new')) createNewConsultation()
  }
})
onBeforeUnmount(() => {
  if (process.client) window.removeEventListener('keydown', handleGlobalKey)
})
function handleGlobalKey(e) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') { e.preventDefault(); cmdPalette.value = true }
  if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); saveDraft(); showToast('Saved') }
}

function onOrderPlaced(order) {
  if (order.type === 'error') { showToast(order.name + ': ' + order.detail, 'error'); return }
  orders.value.push(order)
  showToast(`${order.name} ordered`)
}

let saveTimer = null
watch(form, () => {
  if (isLocked.value || addendumMode.value || !consultationId.value || consultationId.value === 'new') return
  if (saveTimer) clearTimeout(saveTimer)
  saveTimer = setTimeout(() => saveDraft(), 8000)
}, { deep: true })

async function saveDraft() {
  if (!consultationId.value || consultationId.value === 'new' || isLocked.value) return
  saving.value = true
  try {
    await $api.patch(`/consultations/${consultationId.value}/`, form)
    lastSaved.value = new Date().toISOString()
  } catch (e) { console.error('Auto-save failed', e); showToast('Auto-save failed', 'error') }
  finally { saving.value = false }
}

async function signEncounter() {
  if (!signPassword.value) { showToast('Enter your password to confirm', 'warning'); return }
  signing.value = true
  try {
    await $api.post('/auth/login/', { email: auth.user?.email, password: signPassword.value })
    await $api.patch(`/consultations/${consultationId.value}/sign/`, { disposition: form.disposition })
    signDialog.value = false; signPassword.value = ''
    showToast('Encounter signed and locked', 'success')
    await loadConsultation()
  } catch (e) {
    console.error('Sign failed', e)
    showToast(e?.response?.data?.detail || 'Sign failed - check password', 'error')
  } finally { signing.value = false }
}

function startAddendum() { addendumMode.value = true; addendumContent.value = '' }
function cancelAddendum() { addendumMode.value = false; addendumContent.value = '' }
async function saveAddendum() {
  if (!addendumContent.value) { showToast('Addendum content is empty', 'warning'); return }
  addendumSaving.value = true
  try {
    await $api.post(`/consultations/${consultationId.value}/addendum/`, { content: addendumContent.value })
    addendumMode.value = false; addendumContent.value = ''
    showToast('Addendum added', 'success')
    await loadConsultation()
  } catch (e) { console.error('Addendum failed', e); showToast('Failed to add addendum', 'error') }
  finally { addendumSaving.value = false }
}

async function loadConsultation() {
  if (!consultationId.value || consultationId.value === 'new') return
  try {
    const { data } = await $api.get(`/consultations/${consultationId.value}/`)
    consultation.value = data
    Object.assign(form, {
      ...data,
      review_of_systems: data.review_of_systems || {},
      medication_history: data.medication_history || [],
      allergies_confirmed: data.allergies_confirmed || [],
      differential_diagnosis: data.differential_diagnosis || [],
      diagnosis: data.diagnosis || [],
      vital_signs: data.vital_signs || {},
    })
    // Build placed orders list from embedded consultation data
    const placed = []
    ;(data.lab_orders || []).forEach(o => placed.push({
      id: o.id, type: 'lab',
      name: `Lab - ${(o.test_names || []).slice(0, 2).join(', ')}${(o.test_names || []).length > 2 ? ' +' + (o.test_names.length - 2) : ''}`,
      detail: `${(o.test_names || []).length} test(s)`,
      status: o.status, results: (o.results || []).map(r => ({
        id: r.id, test_name: r.test_name, result_value: r.result_value, unit: r.unit, is_abnormal: r.is_abnormal,
      })),
    }))
    ;(data.radiology_orders || []).forEach(o => placed.push({
      id: o.id, type: 'radiology',
      name: `Rad - ${o.imaging_type_display || ''}${o.body_part ? ' - ' + o.body_part : ''}`,
      detail: o.clinical_indication, status: o.status, results: [],
    }))
    ;(data.prescriptions || []).forEach(o => placed.push({
      id: o.id, type: 'pharmacy',
      name: `Rx - ${(o.items || []).map(i => i.medication_name).slice(0, 2).join(', ')}${(o.items || []).length > 2 ? ' +' + (o.items.length - 2) : ''}`,
      detail: `${(o.items || []).length} medication(s)`, status: o.status, results: [],
    }))
    orders.value = placed
    if (data.patient) {
      const { data: pat } = await $api.get(`/patients/${data.patient}/`)
      patient.value = pat
      if (!form.allergies_confirmed.length && pat.allergies) form.allergies_confirmed = [...pat.allergies]
    }
    if (data.triage) {
      const { data: t } = await $api.get(`/triage/${data.triage}/`)
      triageData.value = t
      if (!form.chief_complaint && t.chief_complaint) form.chief_complaint = t.chief_complaint
      if (!Object.keys(form.vital_signs).length && t.vital_signs) form.vital_signs = t.vital_signs
    }
    if (data.patient) {
      try {
        const { data: meds } = await $api.get('/prescriptions/', { params: { patient: data.patient, page_size: 100 } })
        activeMeds.value = meds.results || []
        if (!form.medication_history.length && activeMeds.value.length) {
          form.medication_history = activeMeds.value.flatMap(p => (p.items || []).map(it => ({
            name: it.medication_name || it.custom_medication_name || '—',
            dose: it.dosage || '', frequency: it.frequency || '', reconciled: false,
          })))
          if (!form.medication_history.length) {
            form.medication_history = activeMeds.value.map(p => ({ name: p.items?.[0]?.medication_name || '—', dose: p.items?.[0]?.dosage || '', frequency: p.items?.[0]?.frequency || '', reconciled: false }))
          }
        }
      } catch {}
      try {
        const { data: visits } = await $api.get('/consultations/', { params: { patient: data.patient, page_size: 5 } })
        pastVisits.value = visits.results || []
      } catch {}
    }
  } catch (e) { console.error('Failed to load consultation', e); showToast('Failed to load consultation', 'error') }
}

async function createNewConsultation() {
  try {
    const payload = { ...form, doctor: auth.user?.id, status: 'draft', draft_owner: auth.user?.id }
    const { data } = await $api.post('/consultations/', payload)
    router.replace(`/clinics/consultations/workspace/${data.id}`)
  } catch (e) { console.error('Failed to create consultation', e); showToast('Failed to create consultation', 'error') }
}
</script>

<style scoped>
.doctor-workspace { height: 100vh; display: flex; flex-direction: column; background: rgb(var(--v-theme-surface)); }
.allergy-banner { background: linear-gradient(90deg, #d32f2f, #b71c1c); }
.addendum-banner { background: rgb(var(--v-theme-warning-lighten-4)); }
.top-bar { flex-shrink: 0; }
.border-b { border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.12); }
.three-panels { display: flex; flex: 1; overflow: hidden; }
.left-panel { width: 270px; flex-shrink: 0; overflow-y: auto; border-right: 1px solid rgba(var(--v-theme-on-surface), 0.08); padding: 12px; }
.center-panel { flex: 1; overflow: hidden; display: flex; flex-direction: column; min-width: 0; }
.right-panel { width: 340px; flex-shrink: 0; overflow-y: auto; border-left: 1px solid rgba(var(--v-theme-on-surface), 0.08); padding: 12px; }
.section-nav {
  display: flex; gap: 2px; padding: 6px 12px; flex-shrink: 0;
  overflow-x: auto; border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  background: rgba(var(--v-theme-surface), 0.6); position: sticky; top: 0; z-index: 5;
}
.nav-btn { flex-shrink: 0; }
.nav-label { font-size: 0.7rem; }
.scroll-container { flex: 1; overflow-y: auto; padding: 12px; }
.ros-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 2px; }
.ros-item { display: flex; align-items: center; }
.cursor-pointer { cursor: pointer; }

@media (max-width: 1280px) {
  .left-panel { width: 220px; }
  .right-panel { width: 290px; }
}
@media (max-width: 960px) {
  .three-panels { flex-direction: column; }
  .left-panel, .right-panel { width: 100%; max-height: 240px; }
  .section-nav { flex-wrap: wrap; }
}
</style>
