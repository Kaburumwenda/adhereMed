<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Treatment Plans"
      subtitle="Personalised care plans linking diagnoses, goals and medication regimens."
      eyebrow="CARE PLANNING"
      icon="mdi-clipboard-text"
      :chips="[
        { icon: 'mdi-pulse',         label: `${stats.active} active` },
        { icon: 'mdi-pill',          label: `${stats.medications} medications` },
        { icon: 'mdi-check-decagram',label: `${stats.completed} completed` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-plus" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">New plan</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- ───────────── Stat cards ───────────── -->
    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="44" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
            <v-chip v-if="s.delta" size="x-small" :color="s.color" variant="tonal">
              {{ s.delta }}
            </v-chip>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ───────────── Filters ───────────── -->
    <HomecarePanel title="Plans library" subtitle="Search, filter and switch between board & list views"
                   icon="mdi-clipboard-list" color="#0d9488">
      <v-row dense class="mb-2">
        <v-col cols="12" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search title, diagnosis, patient…"
                        density="compact" variant="outlined" hide-details rounded="lg" />
        </v-col>
        <v-col cols="12" md="3">
          <v-autocomplete v-model="filterPatient" :items="patientOptions"
                          item-title="name" item-value="id"
                          label="Patient" density="compact" variant="outlined"
                          hide-details clearable rounded="lg" :loading="loadingPatients" />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filterStatus" :items="statusOptions" label="Status"
                    density="compact" variant="outlined" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="12" md="2">
          <v-btn-toggle v-model="view" mandatory density="comfortable" rounded="lg"
                        color="teal" class="w-100">
            <v-btn value="board" icon><v-icon icon="mdi-view-column" /></v-btn>
            <v-btn value="list" icon><v-icon icon="mdi-view-list" /></v-btn>
          </v-btn-toggle>
        </v-col>
      </v-row>

      <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-2" rounded />

      <!-- Board (kanban) view -->
      <v-row v-if="view === 'board'" dense>
        <v-col v-for="col in board" :key="col.status" cols="12" md="6" lg="3">
          <v-card class="hc-board-col h-100" rounded="xl" :elevation="0">
            <div class="d-flex align-center ga-2 pa-3 hc-board-head"
                 :style="{ background: col.bg }">
              <v-avatar size="32" :color="col.color" variant="flat">
                <v-icon :icon="col.icon" color="white" size="16" />
              </v-avatar>
              <div class="flex-grow-1">
                <div class="text-subtitle-2 font-weight-bold">{{ col.label }}</div>
                <div class="text-caption text-medium-emphasis">{{ col.items.length }} plan(s)</div>
              </div>
              <v-chip size="x-small" :color="col.color" variant="flat" class="text-white">
                {{ col.items.length }}
              </v-chip>
            </div>
            <div class="pa-2" style="min-height: 120px;">
              <v-card v-for="p in col.items" :key="p.id" class="hc-plan-card mb-2"
                      rounded="lg" :elevation="0" @click="openDetail(p)">
                <div class="hc-plan-band" :style="{ background: col.color }" />
                <div class="pa-3">
                  <div class="d-flex align-center ga-2 mb-1">
                    <div class="text-subtitle-2 font-weight-bold flex-grow-1 text-truncate">
                      {{ p.title }}
                    </div>
                    <v-menu>
                      <template #activator="{ props: a }">
                        <v-btn v-bind="a" icon="mdi-dots-vertical" size="x-small"
                               variant="text" @click.stop />
                      </template>
                      <v-list density="compact">
                        <v-list-item prepend-icon="mdi-eye"
                                     title="View" @click="openDetail(p)" />
                        <v-list-item prepend-icon="mdi-pencil"
                                     title="Edit" @click="openEdit(p)" />
                        <v-divider />
                        <v-list-item v-for="t in transitionsFor(p)" :key="t.value"
                                     :prepend-icon="t.icon" :title="t.label"
                                     @click="changeStatus(p, t.value)" />
                        <v-divider />
                        <v-list-item prepend-icon="mdi-delete" title="Delete"
                                     base-color="error" @click="confirmDelete(p)" />
                      </v-list>
                    </v-menu>
                  </div>
                  <div class="text-caption text-medium-emphasis text-truncate mb-2">
                    <v-icon icon="mdi-stethoscope" size="12" class="mr-1" />
                    {{ p.diagnosis || 'No diagnosis recorded' }}
                  </div>
                  <div class="d-flex align-center ga-1 text-caption text-medium-emphasis mb-2">
                    <v-icon icon="mdi-account" size="12" />
                    <span class="text-truncate">{{ p.patient_name }}</span>
                  </div>
                  <v-progress-linear :model-value="planProgress(p)" rounded
                                     height="6" :color="col.color" bg-opacity="0.15"
                                     class="mb-2" />
                  <div class="d-flex align-center ga-1 text-caption text-medium-emphasis">
                    <v-icon icon="mdi-calendar-start" size="12" />
                    {{ fmtDate(p.start_date) }}
                    <v-icon v-if="p.end_date" icon="mdi-arrow-right" size="12" class="mx-1" />
                    <span v-if="p.end_date">{{ fmtDate(p.end_date) }}</span>
                    <v-spacer />
                    <v-chip size="x-small" variant="tonal" color="purple">
                      <v-icon icon="mdi-pill" size="12" class="mr-1" />
                      {{ p.medication_count || 0 }}
                    </v-chip>
                  </div>
                </div>
              </v-card>
              <EmptyState v-if="!col.items.length" icon="mdi-tray-remove"
                          :title="`No ${col.label.toLowerCase()} plans`" message="" dense />
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- List view -->
      <v-data-table v-else
                    :items="filteredPlans" :headers="tableHeaders"
                    :search="search" density="comfortable" hover
                    items-per-page="10" class="hc-table">
        <template #item.title="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="32" :color="statusMeta(item.status).color" variant="tonal">
              <v-icon :icon="statusMeta(item.status).icon" size="16" />
            </v-avatar>
            <div>
              <div class="font-weight-bold">{{ item.title }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.diagnosis }}</div>
            </div>
          </div>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" :color="statusMeta(item.status).color" variant="tonal">
            <v-icon :icon="statusMeta(item.status).icon" size="14" class="mr-1" />
            {{ statusMeta(item.status).label }}
          </v-chip>
        </template>
        <template #item.start_date="{ item }">
          <span class="text-caption">{{ fmtDate(item.start_date) }}</span>
        </template>
        <template #item.end_date="{ item }">
          <span class="text-caption">{{ item.end_date ? fmtDate(item.end_date) : '—' }}</span>
        </template>
        <template #item.medication_count="{ item }">
          <v-chip size="x-small" variant="tonal" color="purple">
            <v-icon icon="mdi-pill" size="12" class="mr-1" />
            {{ item.medication_count || 0 }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" variant="text" size="small" @click="openDetail(item)" />
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error"
                 @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-clipboard-text-off" title="No treatment plans yet"
                      message="Create the first care plan for a patient." />
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- ───────────── Create / Edit dialog ───────────── -->
    <v-dialog v-model="formDialog" max-width="780" scrollable persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4">
          <div class="d-flex align-center ga-3 text-white">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-clipboard-edit" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">
                {{ editing ? 'EDIT PLAN' : 'NEW PLAN' }}
              </div>
              <h3 class="text-h6 ma-0">
                {{ editing ? form.title || 'Update treatment plan' : 'Create treatment plan' }}
              </h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="formDialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
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
                <v-combobox v-model="form.title" :items="planTitleOptions"
                            label="Plan title *"
                            hint="Pick a template or type your own"
                            persistent-hint
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-format-title"
                            :rules="[v => !!(v && String(v).trim()) || 'Title required']" />
              </v-col>
              <v-col cols="12" md="8">
                <v-text-field v-model="form.diagnosis" label="Primary diagnosis"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-stethoscope"
                              :hint="diagnosisHint" :persistent-hint="!!diagnosisHint"
                              readonly />
              </v-col>
              <v-col cols="12" md="4">
                <v-select v-model="form.status" :items="statusOptions" label="Status"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-flag" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.start_date" type="date" label="Start date *"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-calendar-start"
                              :rules="[v => !!v || 'Start date required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.end_date" type="date" label="Target end date"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-calendar-end" />
              </v-col>
              <v-col cols="12">
                <v-combobox v-model="form.goals" :items="smartGoalOptions" label="Care goals"
                            multiple chips closable-chips clearable
                            :hint="goalsHint"
                            persistent-hint variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-target" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Clinical notes"
                            rows="3" auto-grow variant="outlined" density="comfortable"
                            rounded="lg" prepend-inner-icon="mdi-note-text" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="formDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-content-save" @click="save">
            {{ editing ? 'Save changes' : 'Create plan' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────── Detail drawer ───────────── -->
    <v-dialog v-model="detailDialog" max-width="960" scrollable>
      <v-card v-if="active" rounded="xl" class="overflow-hidden">
        <div class="hc-detail-hero pa-5"
             :style="{ background: gradientFor(active.status) }">
          <div class="d-flex align-center ga-3">
            <v-avatar size="56" color="white" variant="flat">
              <v-icon :icon="statusMeta(active.status).icon"
                      :color="statusMeta(active.status).color" size="28" />
            </v-avatar>
            <div class="flex-grow-1 text-white min-w-0">
              <div class="text-overline" style="opacity:.85;">
                {{ statusMeta(active.status).label.toUpperCase() }} PLAN
              </div>
              <h2 class="text-h5 font-weight-bold ma-0 text-truncate">{{ active.title }}</h2>
              <div class="text-body-2" style="opacity:.85;">
                <v-icon icon="mdi-account" size="14" /> {{ active.patient_name }}
                <span class="mx-1">·</span>
                <v-icon icon="mdi-stethoscope" size="14" />
                {{ active.diagnosis || 'No diagnosis' }}
              </div>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="detailDialog = false" />
          </div>
          <div class="d-flex flex-wrap ga-2 mt-3">
            <v-chip size="small" color="white" variant="flat" class="text-grey-darken-3">
              <v-icon icon="mdi-calendar-start" size="14" class="mr-1" />
              {{ fmtDate(active.start_date) }}
            </v-chip>
            <v-chip v-if="active.end_date" size="small" color="white" variant="flat"
                    class="text-grey-darken-3">
              <v-icon icon="mdi-calendar-end" size="14" class="mr-1" />
              {{ fmtDate(active.end_date) }}
            </v-chip>
            <v-chip size="small" color="white" variant="outlined">
              <v-icon icon="mdi-pill" size="14" class="mr-1" />
              {{ activeMedications.length }} medications
            </v-chip>
            <v-chip size="small" color="white" variant="outlined">
              <v-icon icon="mdi-target" size="14" class="mr-1" />
              {{ (active.goals || []).length }} goals
            </v-chip>
          </div>
        </div>

        <v-card-text class="pa-0">
          <v-tabs v-model="detailTab" color="teal" grow>
            <v-tab value="overview"><v-icon icon="mdi-view-dashboard" class="mr-1" /> Overview</v-tab>
            <v-tab value="meds"><v-icon icon="mdi-pill" class="mr-1" /> Medications</v-tab>
            <v-tab value="goals"><v-icon icon="mdi-target" class="mr-1" /> Goals</v-tab>
            <v-tab value="notes"><v-icon icon="mdi-note-text" class="mr-1" /> Notes</v-tab>
          </v-tabs>
          <v-divider />

          <v-window v-model="detailTab" class="pa-5">
            <!-- Overview -->
            <v-window-item value="overview">
              <v-row dense>
                <v-col cols="12" md="6">
                  <div class="hc-info-row">
                    <div class="text-caption text-medium-emphasis">Status</div>
                    <v-chip size="small" :color="statusMeta(active.status).color" variant="tonal">
                      {{ statusMeta(active.status).label }}
                    </v-chip>
                  </div>
                  <div class="hc-info-row">
                    <div class="text-caption text-medium-emphasis">Diagnosis</div>
                    <div class="text-body-2 font-weight-bold">
                      {{ active.diagnosis || '—' }}
                    </div>
                  </div>
                  <div class="hc-info-row">
                    <div class="text-caption text-medium-emphasis">Duration</div>
                    <div class="text-body-2 font-weight-bold">{{ durationLabel(active) }}</div>
                  </div>
                </v-col>
                <v-col cols="12" md="6">
                  <div class="hc-info-row">
                    <div class="text-caption text-medium-emphasis">Start</div>
                    <div class="text-body-2 font-weight-bold">{{ fmtDate(active.start_date) }}</div>
                  </div>
                  <div class="hc-info-row">
                    <div class="text-caption text-medium-emphasis">Target end</div>
                    <div class="text-body-2 font-weight-bold">
                      {{ active.end_date ? fmtDate(active.end_date) : 'Open-ended' }}
                    </div>
                  </div>
                  <div class="hc-info-row">
                    <div class="text-caption text-medium-emphasis">Last updated</div>
                    <div class="text-body-2 font-weight-bold">
                      {{ active.updated_at ? fmtDateTime(active.updated_at) : '—' }}
                    </div>
                  </div>
                </v-col>
              </v-row>

              <v-divider class="my-4" />

              <div class="d-flex flex-wrap ga-2">
                <v-btn v-for="t in transitionsFor(active)" :key="t.value"
                       :prepend-icon="t.icon" :color="t.color" variant="tonal" rounded="lg"
                       class="text-none" @click="changeStatus(active, t.value)">
                  {{ t.label }}
                </v-btn>
                <v-spacer />
                <v-btn variant="tonal" rounded="lg" color="indigo" class="text-none"
                       prepend-icon="mdi-pencil" @click="openEdit(active)">Edit plan</v-btn>
              </div>
            </v-window-item>

            <!-- Medications -->
            <v-window-item value="meds">
              <div v-if="loadingMeds" class="pa-6 text-center">
                <v-progress-circular indeterminate color="teal" />
              </div>
              <v-list v-else-if="activeMedications.length" class="bg-transparent">
                <v-list-item v-for="m in activeMedications" :key="m.id"
                             rounded="lg" class="hc-row mb-1">
                  <template #prepend>
                    <v-avatar size="40" color="purple" variant="tonal">
                      <v-icon icon="mdi-pill" />
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-bold">
                    {{ m.medication_name }} · {{ m.dose }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    <v-chip size="x-small" variant="tonal" color="indigo" class="mr-1">
                      {{ m.route }}
                    </v-chip>
                    <span v-if="(m.times_of_day || []).length">
                      {{ (m.times_of_day || []).join(', ') }}
                    </span>
                    <span v-else-if="m.frequency_cron">{{ m.frequency_cron }}</span>
                    <span v-if="m.instructions"> · {{ m.instructions }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip size="x-small" :color="m.is_active ? 'success' : 'grey'" variant="tonal">
                      {{ m.is_active ? 'Active' : 'Stopped' }}
                    </v-chip>
                  </template>
                </v-list-item>
              </v-list>
              <EmptyState v-else icon="mdi-pill-off" title="No medications scheduled"
                          message="Add a medication schedule from the prescriptions module." />
            </v-window-item>

            <!-- Goals -->
            <v-window-item value="goals">
              <div v-if="(active.goals || []).length">
                <v-timeline density="comfortable" side="end" line-thickness="2"
                            line-color="grey-lighten-2">
                  <v-timeline-item v-for="(g, i) in active.goals" :key="i" size="small"
                                   dot-color="teal">
                    <template #icon>
                      <v-icon icon="mdi-target" color="white" size="14" />
                    </template>
                    <div class="text-body-2 font-weight-bold">Goal {{ i + 1 }}</div>
                    <div class="text-body-2">{{ g }}</div>
                  </v-timeline-item>
                </v-timeline>
              </div>
              <EmptyState v-else icon="mdi-target" title="No goals defined"
                          message="Edit the plan to add SMART care goals." />
            </v-window-item>

            <!-- Notes -->
            <v-window-item value="notes">
              <p v-if="active.notes" class="text-body-2" style="white-space: pre-wrap;">
                {{ active.notes }}
              </p>
              <EmptyState v-else icon="mdi-note-off" title="No clinical notes"
                          message="Notes added to the plan will appear here." />
            </v-window-item>
          </v-window>
        </v-card-text>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-alert" color="error" class="mr-1" /> Delete plan?
        </v-card-title>
        <v-card-text>
          This permanently removes the plan and any unscheduled doses linked to it.
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none"
                 :loading="deleting" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const plans = ref([])
const patientOptions = ref([])
const activeMedications = ref([])
const loading = ref(false)
const loadingPatients = ref(false)
const loadingMeds = ref(false)
const saving = ref(false)
const deleting = ref(false)

const search = ref('')
const filterPatient = ref(null)
const filterStatus = ref(null)
const view = ref('board')

const formDialog = ref(false)
const detailDialog = ref(false)
const deleteDialog = ref(false)
const editing = ref(false)
const detailTab = ref('overview')
const active = ref(null)
const toDelete = ref(null)
const formRef = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

const blank = () => ({
  id: null, patient: null, title: '', diagnosis: '',
  status: 'active', start_date: new Date().toISOString().slice(0, 10),
  end_date: '', goals: [], notes: ''
})
const form = reactive(blank())

const statusOptions = [
  { value: 'active',    title: 'Active' },
  { value: 'paused',    title: 'Paused' },
  { value: 'completed', title: 'Completed' },
  { value: 'cancelled', title: 'Cancelled' }
]

// Common homecare plan templates — selectable in the title combobox.
// Users can also type a custom title; the combobox accepts free text.
const planTitleOptions = [
  'Diabetes Management Plan',
  'Hypertension Care Plan',
  'Post-Surgical Recovery Plan',
  'Wound Care Plan',
  'Palliative Care Plan',
  'Stroke Rehabilitation Plan',
  'Chronic Kidney Disease Plan',
  'COPD Management Plan',
  'Heart Failure Care Plan',
  'Dementia Support Plan',
  'Elderly Daily Living Support',
  'Maternal & Newborn Care Plan',
  'Paediatric Home Care Plan',
  'Mental Health Support Plan',
  'Physiotherapy & Mobility Plan',
  'Nutritional Support Plan',
  'Medication Adherence Plan'
]

const diagnosisHint = computed(() => (
  form.patient && form.diagnosis
    ? 'Auto-filled from the patient record'
    : ''
))

// Common SMART (Specific, Measurable, Achievable, Relevant, Time-bound)
// care goals grouped by diagnosis category. The combobox shows the goals
// that match the patient's primary diagnosis first; users can also type
// their own goals.
const GENERIC_SMART_GOALS = [
  '100% medication adherence verified weekly',
  'No hospital readmission within 30 days of discharge',
  'Independent in activities of daily living (ADLs) within 8 weeks',
  'Patient verbalises understanding of condition within 2 weeks',
  'Caregiver demonstrates safe care technique within 1 week',
  'Pain score ≤3/10 within 2 weeks',
  'Achieve restful sleep ≥6 hours/night within 4 weeks'
]

// Each entry: keywords (lowercase) → list of goals tailored for it.
const DIAGNOSIS_GOAL_MAP = [
  {
    keys: ['diabetes', 'dm', 'hyperglyc', 'hypoglyc'],
    goals: [
      'Achieve HbA1c <7.0% within 3 months',
      'Maintain fasting blood glucose between 4.4–7.0 mmol/L within 12 weeks',
      'Demonstrate correct insulin self-administration within 2 weeks',
      'Daily blood glucose monitoring logged for 90 days',
      'No hypoglycaemic episodes (<3.9 mmol/L) over 8 weeks',
      'Adopt diabetic diet plan within 4 weeks'
    ]
  },
  {
    keys: ['hypertension', 'htn', 'high blood pressure', 'bp'],
    goals: [
      'Reduce blood pressure to <130/80 mmHg within 8 weeks',
      'Daily home BP readings logged for 12 weeks',
      'Reduce daily salt intake to <5 g within 4 weeks',
      'Achieve 150 minutes of moderate exercise weekly within 8 weeks'
    ]
  },
  {
    keys: ['heart failure', 'chf', 'cardiac', 'cardio', 'ihd', 'mi ', 'myocardial'],
    goals: [
      'No hospital readmission for cardiac cause within 30 days',
      'Maintain weight gain <1 kg/day (fluid balance) over 12 weeks',
      'Tolerate 10 minutes of light activity without dyspnoea within 6 weeks',
      'Adhere to fluid restriction (1.5 L/day) verified weekly',
      'NYHA class improved by 1 grade within 12 weeks'
    ]
  },
  {
    keys: ['copd', 'asthma', 'respiratory', 'pneumon', 'bronch'],
    goals: [
      'Improve oxygen saturation to ≥95% on room air within 4 weeks',
      'Demonstrate correct inhaler technique within 1 week',
      'Reduce exacerbations to zero over the next 3 months',
      'Walk 6 minutes without desaturation <90% within 8 weeks',
      'Smoking cessation maintained for 90 days'
    ]
  },
  {
    keys: ['stroke', 'cva', 'tia', 'hemiparesis', 'hemiplegia'],
    goals: [
      'Walk independently for 15 minutes daily within 6 weeks',
      'Regain independent feeding within 4 weeks',
      'Improve Barthel Index score by 20 points within 12 weeks',
      'Achieve clear speech in short sentences within 8 weeks',
      'Caregiver demonstrates safe transfer technique within 1 week'
    ]
  },
  {
    keys: ['wound', 'ulcer', 'pressure sore', 'bedsore', 'burn', 'laceration'],
    goals: [
      'Achieve full wound closure within 4 weeks',
      'Reduce wound size by 50% within 2 weeks',
      'No signs of wound infection over 30 days',
      'Maintain skin integrity — no new pressure ulcers over 90 days',
      'Pain score at dressing change ≤2/10 within 2 weeks'
    ]
  },
  {
    keys: ['post-op', 'post op', 'postoperative', 'surgery', 'surgical', 'post-surgical'],
    goals: [
      'Resume light home exercises 3×/week within 6 weeks',
      'Wound healing without complications by week 4',
      'Pain score ≤3/10 within 2 weeks',
      'Independent in ADLs within 6 weeks',
      'No post-surgical infection over 30 days'
    ]
  },
  {
    keys: ['ckd', 'kidney', 'renal', 'dialysis'],
    goals: [
      'Adhere to renal diet (low K, low Na, low PO4) within 4 weeks',
      'Maintain fluid restriction (1 L/day) verified weekly',
      'Attend 100% of scheduled dialysis sessions over 90 days',
      'Maintain dry weight within 1 kg of target over 12 weeks'
    ]
  },
  {
    keys: ['cancer', 'oncolog', 'chemo', 'palliat', 'hospice', 'terminal'],
    goals: [
      'Pain score ≤3/10 within 2 weeks',
      'Maintain oral intake ≥1500 kcal/day over 4 weeks',
      'Patient and family report comfort and dignity weekly',
      'Manage nausea — ≤1 episode/day within 2 weeks',
      'Advance care plan documented within 2 weeks'
    ]
  },
  {
    keys: ['demen', 'alzheim', 'cognitive', 'memory'],
    goals: [
      'Reduce fall incidents to zero over the next 3 months',
      'Caregiver completes safety training within 2 weeks',
      'Maintain stable weight (±2 kg) over 12 weeks',
      'Engage in cognitive stimulation activity 5×/week',
      'No wandering incidents over 90 days'
    ]
  },
  {
    keys: ['mental', 'depress', 'anxiety', 'psych', 'phq', 'mood'],
    goals: [
      'Stable mood with PHQ-9 score <10 within 8 weeks',
      'Achieve restful sleep ≥6 hours/night within 4 weeks',
      'Attend 100% of scheduled counselling sessions over 12 weeks',
      'Resume one social/recreational activity weekly within 4 weeks'
    ]
  },
  {
    keys: ['matern', 'postnatal', 'antenatal', 'pregnan', 'newborn', 'neonat'],
    goals: [
      'Establish exclusive breastfeeding within 1 week',
      'Newborn gains ≥150 g/week over first 6 weeks',
      'Mother attends 100% of postnatal visits',
      'No signs of postpartum depression at 6-week assessment'
    ]
  },
  {
    keys: ['malnutri', 'underweight', 'nutrition', 'weight loss'],
    goals: [
      'Increase oral fluid intake to 1.5–2 L/day within 2 weeks',
      'Gain 0.5 kg/week until target weight reached',
      'Consume ≥1800 kcal/day verified by food diary',
      'Improve serum albumin to ≥35 g/L within 12 weeks'
    ]
  },
  {
    keys: ['fall', 'mobility', 'physio', 'rehab', 'fracture', 'arthrit'],
    goals: [
      'Walk independently for 15 minutes daily within 6 weeks',
      'Reduce fall incidents to zero over the next 3 months',
      'Independent in transfers within 4 weeks',
      'Climb 10 stairs unaided within 8 weeks',
      'Pain score ≤3/10 within 2 weeks'
    ]
  }
]

// Build the suggestions list based on the current primary diagnosis.
// Matched goals appear first; generic SMART goals follow as a fallback.
const smartGoalOptions = computed(() => {
  const dx = (form.diagnosis || '').toLowerCase().trim()
  const matched = []
  if (dx) {
    for (const entry of DIAGNOSIS_GOAL_MAP) {
      if (entry.keys.some(k => dx.includes(k))) {
        matched.push(...entry.goals)
      }
    }
  }
  // De-duplicate while preserving order, matched goals first.
  const seen = new Set()
  const out = []
  for (const g of [...matched, ...GENERIC_SMART_GOALS]) {
    if (!seen.has(g)) { seen.add(g); out.push(g) }
  }
  return out
})

const goalsHint = computed(() => {
  const dx = (form.diagnosis || '').trim()
  if (!dx) return 'Pick a SMART goal or type your own and press Enter.'
  return `Suggestions tailored to "${dx}". Type your own and press Enter.`
})

function onPatientSelected(id) {
  const p = patientOptions.value.find(x => x.id === id)
  // Always reflect the selected patient's primary diagnosis
  form.diagnosis = p?.primary_diagnosis || ''
  // Suggest a default title if none chosen yet
  if (!form.title && p?.primary_diagnosis) {
    form.title = `${p.primary_diagnosis} Care Plan`
  }
}

const statusBoard = [
  { status: 'active',    label: 'Active',    color: '#0d9488', bg: 'rgba(13,148,136,0.08)',  icon: 'mdi-play-circle' },
  { status: 'paused',    label: 'Paused',    color: '#f59e0b', bg: 'rgba(245,158,11,0.08)',  icon: 'mdi-pause-circle' },
  { status: 'completed', label: 'Completed', color: '#0284c7', bg: 'rgba(2,132,199,0.08)',   icon: 'mdi-check-circle' },
  { status: 'cancelled', label: 'Cancelled', color: '#64748b', bg: 'rgba(100,116,139,0.08)', icon: 'mdi-close-circle' }
]

const tableHeaders = [
  { title: 'Plan',       key: 'title' },
  { title: 'Patient',    key: 'patient_name' },
  { title: 'Status',     key: 'status' },
  { title: 'Start',      key: 'start_date' },
  { title: 'End',        key: 'end_date' },
  { title: 'Meds',       key: 'medication_count', align: 'center' },
  { title: '',           key: 'actions', sortable: false, align: 'end' }
]

// ─────── data load
async function loadPlans() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/treatment-plans/', { params: { page_size: 200 } })
    plans.value = data?.results || data || []
  } catch (e) {
    snack.text = 'Failed to load treatment plans'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
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
async function loadMedications(planId) {
  loadingMeds.value = true
  activeMedications.value = []
  try {
    const { data } = await $api.get('/homecare/medication-schedules/', {
      params: { treatment_plan: planId, page_size: 100 }
    })
    activeMedications.value = data?.results || data || []
  } catch { /* ignore */ }
  finally { loadingMeds.value = false }
}

onMounted(() => { loadPlans(); loadPatients() })

// ─────── derived
const filteredPlans = computed(() => {
  const q = search.value.trim().toLowerCase()
  return plans.value.filter(p => {
    if (filterPatient.value && p.patient !== filterPatient.value) return false
    if (filterStatus.value && p.status !== filterStatus.value) return false
    if (!q) return true
    return [p.title, p.diagnosis, p.patient_name].filter(Boolean)
      .some(s => s.toLowerCase().includes(q))
  })
})

const board = computed(() => statusBoard.map(c => ({
  ...c, items: filteredPlans.value.filter(p => p.status === c.status)
})))

const stats = computed(() => {
  const list = plans.value
  return {
    active:    list.filter(p => p.status === 'active').length,
    paused:    list.filter(p => p.status === 'paused').length,
    completed: list.filter(p => p.status === 'completed').length,
    total:     list.length,
    medications: list.reduce((n, p) => n + (p.medication_count || 0), 0)
  }
})

const summary = computed(() => [
  { label: 'Active plans',   value: stats.value.active,    color: 'teal',    icon: 'mdi-play-circle' },
  { label: 'Paused',         value: stats.value.paused,    color: 'warning', icon: 'mdi-pause-circle' },
  { label: 'Completed',      value: stats.value.completed, color: 'info',    icon: 'mdi-check-circle' },
  { label: 'Medications',    value: stats.value.medications, color: 'purple', icon: 'mdi-pill' }
])

// ─────── helpers
function statusMeta(s) {
  const c = statusBoard.find(x => x.status === s) || statusBoard[0]
  return { color: c.color === '#0d9488' ? 'teal' :
                  c.color === '#f59e0b' ? 'warning' :
                  c.color === '#0284c7' ? 'info' : 'grey',
           icon: c.icon, label: c.label }
}
function gradientFor(s) {
  return ({
    active:    'linear-gradient(135deg,#0d9488 0%,#0f766e 100%)',
    paused:    'linear-gradient(135deg,#f59e0b 0%,#d97706 100%)',
    completed: 'linear-gradient(135deg,#0ea5e9 0%,#0284c7 100%)',
    cancelled: 'linear-gradient(135deg,#64748b 0%,#475569 100%)'
  })[s] || 'linear-gradient(135deg,#0d9488 0%,#0f766e 100%)'
}
function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}
function fmtDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
  })
}
function durationLabel(p) {
  if (!p.start_date) return '—'
  const start = new Date(p.start_date)
  const end = p.end_date ? new Date(p.end_date) : new Date()
  const days = Math.max(0, Math.round((end - start) / 86400000))
  if (days < 31) return `${days} day(s)`
  if (days < 365) return `${Math.round(days / 7)} week(s)`
  return `${(days / 365).toFixed(1)} year(s)`
}
function planProgress(p) {
  if (p.status === 'completed') return 100
  if (p.status === 'cancelled') return 100
  if (!p.start_date || !p.end_date) return 25
  const start = new Date(p.start_date).getTime()
  const end = new Date(p.end_date).getTime()
  const now = Date.now()
  if (end <= start) return 100
  return Math.min(100, Math.max(0, Math.round(((now - start) / (end - start)) * 100)))
}
function transitionsFor(p) {
  const all = [
    { value: 'active',    label: 'Resume',   icon: 'mdi-play',   color: 'teal' },
    { value: 'paused',    label: 'Pause',    icon: 'mdi-pause',  color: 'warning' },
    { value: 'completed', label: 'Complete', icon: 'mdi-check',  color: 'info' },
    { value: 'cancelled', label: 'Cancel',   icon: 'mdi-close',  color: 'grey' }
  ]
  return all.filter(t => t.value !== p.status)
}

// ─────── actions
function openCreate() {
  Object.assign(form, blank())
  editing.value = false
  formDialog.value = true
}
function openEdit(p) {
  Object.assign(form, {
    id: p.id, patient: p.patient, title: p.title, diagnosis: p.diagnosis || '',
    status: p.status, start_date: p.start_date,
    end_date: p.end_date || '', goals: [...(p.goals || [])], notes: p.notes || ''
  })
  editing.value = true
  formDialog.value = true
  detailDialog.value = false
}
async function save() {
  const v = await formRef.value?.validate()
  if (v && v.valid === false) return
  saving.value = true
  const payload = {
    patient: form.patient, title: form.title, diagnosis: form.diagnosis,
    status: form.status, start_date: form.start_date,
    end_date: form.end_date || null, goals: form.goals, notes: form.notes
  }
  try {
    if (editing.value && form.id) {
      const { data } = await $api.patch(`/homecare/treatment-plans/${form.id}/`, payload)
      const i = plans.value.findIndex(p => p.id === form.id)
      if (i >= 0) plans.value.splice(i, 1, data)
      snack.text = 'Plan updated'; snack.color = 'success'
    } else {
      const { data } = await $api.post('/homecare/treatment-plans/', payload)
      plans.value.unshift(data)
      snack.text = 'Plan created'; snack.color = 'success'
    }
    snack.show = true
    formDialog.value = false
  } catch (e) {
    const msg = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Save failed'
    snack.text = msg; snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}

function openDetail(p) {
  active.value = p
  detailTab.value = 'overview'
  detailDialog.value = true
  loadMedications(p.id)
}

async function changeStatus(p, status) {
  try {
    const { data } = await $api.patch(`/homecare/treatment-plans/${p.id}/`, { status })
    const i = plans.value.findIndex(x => x.id === p.id)
    if (i >= 0) plans.value.splice(i, 1, data)
    if (active.value?.id === p.id) active.value = data
    snack.text = `Status updated to ${status}`; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Status update failed'; snack.color = 'error'; snack.show = true
  }
}

function confirmDelete(p) { toDelete.value = p; deleteDialog.value = true }
async function doDelete() {
  if (!toDelete.value) return
  deleting.value = true
  try {
    await $api.delete(`/homecare/treatment-plans/${toDelete.value.id}/`)
    plans.value = plans.value.filter(p => p.id !== toDelete.value.id)
    if (active.value?.id === toDelete.value.id) detailDialog.value = false
    snack.text = 'Plan deleted'; snack.color = 'success'; snack.show = true
    deleteDialog.value = false
  } catch {
    snack.text = 'Delete failed'; snack.color = 'error'; snack.show = true
  } finally { deleting.value = false }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
  transition: transform .15s ease, box-shadow .15s ease;
}
.hc-stat:hover { transform: translateY(-2px); box-shadow: 0 10px 28px -16px rgba(15,23,42,0.25); }

.hc-board-col {
  background: rgba(255,255,255,0.6);
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
}
.hc-board-head { border-bottom: 1px solid rgba(15,23,42,0.05); }

.hc-plan-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  cursor: pointer;
  transition: transform .12s ease, box-shadow .12s ease;
  overflow: hidden;
}
.hc-plan-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 14px 28px -18px rgba(15,23,42,0.3);
}
.hc-plan-band {
  position: absolute;
  left: 0; top: 0; bottom: 0;
  width: 4px;
}

.hc-form-hero {
  background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%);
}
.hc-detail-hero { color: white; }

.hc-info-row {
  padding: 8px 0;
  border-bottom: 1px dashed rgba(15,23,42,0.08);
}

.hc-row { background: rgba(15,23,42,0.03); }
.hc-table :deep(thead th) { background: rgba(13,148,136,0.06); }

:global(.v-theme--dark) .hc-plan-card,
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-board-col {
  background: rgba(30,41,59,0.7);
  border-color: rgba(255,255,255,0.06);
}
:global(.v-theme--dark) .hc-row { background: rgba(255,255,255,0.04); }
</style>
