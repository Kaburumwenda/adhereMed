<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Care pathways"
      subtitle="Evidence-based protocol bundles that auto-generate treatment plans and medication schedules on enrolment."
      eyebrow="CLINICAL PROTOCOLS"
      icon="mdi-clipboard-pulse"
      :chips="[
        { icon: 'mdi-clipboard-list', label: `${pathways.length} pathways` },
        { icon: 'mdi-account-group',  label: `${enrollments.length} active enrolments` },
        { icon: 'mdi-check-decagram', label: `${stats.completed} completed` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-plus" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">New pathway</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" lg="7">
        <HomecarePanel title="Pathway library" subtitle="Reusable protocol bundles"
                       icon="mdi-book-open-variant" color="#0d9488">
          <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-2" rounded />

          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search pathway, condition…" density="compact"
                        variant="outlined" hide-details rounded="lg" class="mb-2" />

          <v-card v-for="pw in filteredPathways" :key="pw.id"
                  class="hc-pw-card mb-2" rounded="xl" :elevation="0">
            <div class="hc-pw-band" :style="{ background: pwColor(pw).hex }" />
            <div class="pa-4">
              <div class="d-flex align-start ga-3">
                <v-avatar size="44" :color="pwColor(pw).vuetify" variant="tonal">
                  <v-icon :icon="pwIcon(pw)" />
                </v-avatar>
                <div class="flex-grow-1 min-w-0">
                  <div class="d-flex align-center ga-2 flex-wrap">
                    <div class="text-subtitle-1 font-weight-bold">{{ pw.name }}</div>
                    <v-chip v-if="pw.code" size="x-small" color="indigo" variant="tonal">
                      <v-icon start icon="mdi-tag" /> {{ pw.code }}
                    </v-chip>
                    <v-chip size="x-small" :color="pw.is_active ? 'success' : 'grey'"
                            variant="tonal">
                      {{ pw.is_active ? 'active' : 'inactive' }}
                    </v-chip>
                  </div>
                  <div class="text-caption text-medium-emphasis mt-1">
                    <v-icon icon="mdi-calendar-range" size="12" />
                    {{ pw.default_duration_days }}d ·
                    <v-icon icon="mdi-pill" size="12" />
                    {{ pw.medication_orders?.length || 0 }} med orders ·
                    <v-icon icon="mdi-checkbox-marked-circle-outline" size="12" />
                    {{ pw.tasks?.length || 0 }} tasks
                  </div>
                  <p class="text-body-2 mb-0 mt-1">{{ pw.description }}</p>
                </div>
                <div class="d-flex flex-column ga-1">
                  <v-btn size="small" color="teal" variant="flat" rounded="lg"
                         class="text-none" prepend-icon="mdi-account-plus"
                         @click="openEnroll(pw)">Enrol patient</v-btn>
                  <v-btn size="small" variant="text" rounded="lg" class="text-none"
                         prepend-icon="mdi-pencil" @click="openEdit(pw)">Edit</v-btn>
                </div>
              </div>
            </div>
          </v-card>
          <EmptyState v-if="!loading && !filteredPathways.length"
                      icon="mdi-clipboard-pulse" title="No pathways"
                      message="Create a pathway or run `seed_care_pathways`." />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="5">
        <HomecarePanel title="Recent enrolments" icon="mdi-account-multiple-check" color="#7c3aed">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="e in enrollments.slice(0, 12)" :key="e.id"
                         rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="34" :color="enrollColor(e.status).vuetify" variant="tonal">
                  <v-icon :icon="enrollIcon(e.status)" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ e.patient_name }}</v-list-item-title>
              <v-list-item-subtitle>
                {{ e.pathway_name }}
                · started {{ formatDate(e.started_at) }}
                <span v-if="e.target_end_date">· ends {{ formatDate(e.target_end_date) }}</span>
              </v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="enrollColor(e.status).vuetify" variant="tonal">
                  {{ e.status_label }}
                </v-chip>
                <v-menu v-if="e.status === 'active'">
                  <template #activator="{ props }">
                    <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
                  </template>
                  <v-list density="compact">
                    <v-list-item @click="completeEnrollment(e)" prepend-icon="mdi-check">
                      <v-list-item-title>Mark complete</v-list-item-title>
                    </v-list-item>
                    <v-list-item @click="withdrawEnrollment(e)" prepend-icon="mdi-close-circle">
                      <v-list-item-title>Withdraw</v-list-item-title>
                    </v-list-item>
                  </v-list>
                </v-menu>
              </template>
            </v-list-item>
            <EmptyState v-if="!enrollments.length" icon="mdi-account-multiple-outline"
                        title="No enrolments yet" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Pathway editor -->
    <v-dialog v-model="editDialog" max-width="820" scrollable persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-clipboard-pulse" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">PATHWAY</div>
              <h3 class="text-h6 ma-0">{{ form.id ? 'Edit pathway' : 'New pathway' }}</h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="editDialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" md="8">
              <v-text-field v-model="form.name" label="Name *" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model.number="form.default_duration_days"
                            label="Duration (days)" type="number" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.code" label="Code (SNOMED)"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.condition_label" label="Condition label"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="Description" rows="2"
                          auto-grow variant="outlined" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <div class="text-subtitle-2 mb-1">Goals (one per line)</div>
              <v-textarea v-model="goalsText" rows="3" auto-grow variant="outlined"
                          density="comfortable" rounded="lg"
                          hint="Each line becomes a structured goal." persistent-hint />
            </v-col>
            <v-col cols="12">
              <div class="d-flex align-center mb-1">
                <div class="text-subtitle-2">Medication orders</div>
                <v-spacer />
                <v-btn size="small" variant="tonal" color="teal" rounded="lg"
                       class="text-none" prepend-icon="mdi-plus" @click="addMed">Add</v-btn>
              </div>
              <v-card v-for="(m, idx) in form.medication_orders" :key="idx"
                      class="pa-3 mb-2" rounded="lg" :elevation="0"
                      style="background: rgba(13,148,136,0.05);">
                <v-row dense>
                  <v-col cols="12" md="4">
                    <v-text-field v-model="m.medication_name" label="Medication *"
                                  density="compact" variant="outlined" rounded="lg" />
                  </v-col>
                  <v-col cols="6" md="2">
                    <v-text-field v-model="m.dose" label="Dose"
                                  density="compact" variant="outlined" rounded="lg" />
                  </v-col>
                  <v-col cols="6" md="2">
                    <v-select v-model="m.route" :items="routeOptions" label="Route"
                              density="compact" variant="outlined" rounded="lg" />
                  </v-col>
                  <v-col cols="12" md="3">
                    <v-text-field v-model="m._times" label="Times (comma)"
                                  placeholder="08:00,20:00"
                                  density="compact" variant="outlined" rounded="lg" />
                  </v-col>
                  <v-col cols="12" md="1" class="d-flex align-center">
                    <v-btn icon="mdi-delete" variant="text" color="error" size="small"
                           @click="form.medication_orders.splice(idx, 1)" />
                  </v-col>
                  <v-col cols="6" md="2">
                    <v-text-field v-model.number="m.duration_days" label="Days"
                                  type="number" density="compact" variant="outlined"
                                  rounded="lg" />
                  </v-col>
                  <v-col cols="12" md="9">
                    <v-text-field v-model="m.instructions" label="Instructions"
                                  density="compact" variant="outlined" rounded="lg" />
                  </v-col>
                  <v-col cols="6" md="1" class="d-flex align-center">
                    <v-checkbox v-model="m.requires_caregiver" hide-details density="compact"
                                color="teal" label="CG" />
                  </v-col>
                </v-row>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="editDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-check" @click="savePathway">
            Save pathway
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Enrol dialog -->
    <v-dialog v-model="enrolDialog" max-width="560" persistent>
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-account-plus" color="teal" class="mr-1" />
          Enrol patient in pathway
        </v-card-title>
        <v-card-text>
          <p v-if="enrolPathway" class="text-body-2 mb-3">
            <strong>{{ enrolPathway.name }}</strong>
            ({{ enrolPathway.default_duration_days }}d) — auto-creates a treatment plan
            and {{ enrolPathway.medication_orders?.length || 0 }} medication schedule(s).
          </p>
          <v-autocomplete v-model="enrolPatient" :items="patients"
                          item-title="name" item-value="id" label="Patient *"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-account" />
          <v-text-field v-model="enrolStart" label="Start date"
                        type="date" variant="outlined" density="comfortable"
                        rounded="lg" prepend-inner-icon="mdi-calendar" />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="enrolDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="enrolling" :disabled="!enrolPatient" @click="submitEnrol">
            Enrol
          </v-btn>
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

const pathways = ref([])
const enrollments = ref([])
const patients = ref([])
const loading = ref(false)
const saving = ref(false)
const enrolling = ref(false)

const search = ref('')
const editDialog = ref(false)
const enrolDialog = ref(false)
const enrolPathway = ref(null)
const enrolPatient = ref(null)
const enrolStart = ref('')
const snack = reactive({ show: false, text: '', color: 'info' })

const routeOptions = [
  { value: 'oral', title: 'Oral' }, { value: 'iv', title: 'IV' },
  { value: 'im', title: 'IM' }, { value: 'sc', title: 'Subcut' },
  { value: 'topical', title: 'Topical' }, { value: 'inhaled', title: 'Inhaled' },
  { value: 'other', title: 'Other' }
]

const blank = () => ({
  id: null, name: '', code: '', condition_label: '',
  description: '', default_duration_days: 14, goals: [],
  medication_orders: [], vital_targets: {}, tasks: [], is_active: true
})
const form = reactive(blank())
const goalsText = ref('')

async function loadAll() {
  loading.value = true
  try {
    const [a, b, c] = await Promise.all([
      $api.get('/homecare/care-pathways/', { params: { page_size: 200 } }),
      $api.get('/homecare/pathway-enrollments/', { params: { page_size: 200 } }),
      $api.get('/homecare/patients/', { params: { page_size: 200 } })
    ])
    pathways.value = a.data?.results || a.data || []
    enrollments.value = b.data?.results || b.data || []
    const list = c.data?.results || c.data || []
    patients.value = list.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'}${p.medical_record_number ? ' · ' + p.medical_record_number : ''}`
    }))
  } catch {
    snack.text = 'Load failed'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(loadAll)

const filteredPathways = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return pathways.value
  return pathways.value.filter(p =>
    [p.name, p.code, p.condition_label, p.description].filter(Boolean)
      .some(s => s.toLowerCase().includes(q))
  )
})

const stats = computed(() => ({
  completed: enrollments.value.filter(e => e.status === 'completed').length,
  active: enrollments.value.filter(e => e.status === 'active').length,
  withdrawn: enrollments.value.filter(e => e.status === 'withdrawn').length
}))

function pwColor(p) {
  const palette = [
    { hex: '#0d9488', vuetify: 'teal' },
    { hex: '#7c3aed', vuetify: 'purple' },
    { hex: '#0284c7', vuetify: 'info' },
    { hex: '#f59e0b', vuetify: 'warning' },
    { hex: '#10b981', vuetify: 'success' },
    { hex: '#ef4444', vuetify: 'error' }
  ]
  const seed = (p.code || p.name || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0)
  return palette[seed % palette.length]
}
function pwIcon(p) {
  const n = (p.name || '').toLowerCase()
  if (n.includes('hip') || n.includes('post-op')) return 'mdi-bone'
  if (n.includes('chf') || n.includes('heart')) return 'mdi-heart-pulse'
  if (n.includes('palliative')) return 'mdi-hand-heart'
  if (n.includes('diabet')) return 'mdi-water-percent'
  return 'mdi-clipboard-pulse'
}
function enrollColor(s) {
  return ({ active: { vuetify: 'teal' }, completed: { vuetify: 'success' },
            withdrawn: { vuetify: 'grey' } })[s] || { vuetify: 'grey' }
}
function enrollIcon(s) {
  return ({ active: 'mdi-progress-clock', completed: 'mdi-check-circle',
            withdrawn: 'mdi-close-circle' })[s] || 'mdi-circle'
}
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}

function openCreate() {
  Object.assign(form, blank())
  goalsText.value = ''
  editDialog.value = true
}
function openEdit(pw) {
  Object.assign(form, JSON.parse(JSON.stringify(pw)))
  goalsText.value = (pw.goals || []).join('\n')
  // Pre-fill _times helper from times_of_day
  for (const m of form.medication_orders) {
    m._times = (m.times_of_day || []).join(',')
  }
  editDialog.value = true
}
function addMed() {
  form.medication_orders.push({
    medication_name: '', dose: '', route: 'oral', _times: '',
    duration_days: form.default_duration_days || 14,
    instructions: '', requires_caregiver: false
  })
}
async function savePathway() {
  if (!form.name.trim()) {
    snack.text = 'Name required'; snack.color = 'warning'; snack.show = true; return
  }
  // Project _times into times_of_day
  const orders = form.medication_orders.map(m => ({
    medication_name: m.medication_name,
    dose: m.dose, route: m.route,
    times_of_day: (m._times || '').split(',').map(s => s.trim()).filter(Boolean),
    duration_days: m.duration_days || null,
    instructions: m.instructions || '',
    requires_caregiver: !!m.requires_caregiver
  }))
  const goals = goalsText.value.split('\n').map(s => s.trim()).filter(Boolean)
  const payload = { ...form, goals, medication_orders: orders }
  delete payload.id
  saving.value = true
  try {
    if (form.id) {
      const { data } = await $api.put(`/homecare/care-pathways/${form.id}/`, payload)
      const i = pathways.value.findIndex(x => x.id === data.id)
      if (i >= 0) pathways.value.splice(i, 1, data)
    } else {
      const { data } = await $api.post('/homecare/care-pathways/', payload)
      pathways.value.unshift(data)
    }
    snack.text = 'Pathway saved'; snack.color = 'success'; snack.show = true
    editDialog.value = false
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Save failed'
    snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}

function openEnroll(pw) {
  enrolPathway.value = pw
  enrolPatient.value = null
  enrolStart.value = ''
  enrolDialog.value = true
}
async function submitEnrol() {
  if (!enrolPathway.value || !enrolPatient.value) return
  enrolling.value = true
  try {
    const { data } = await $api.post(
      `/homecare/patients/${enrolPatient.value}/apply-pathway/`,
      { pathway: enrolPathway.value.id, start_date: enrolStart.value || undefined }
    )
    enrollments.value.unshift(data)
    snack.text = 'Patient enrolled — plan + schedules created'
    snack.color = 'success'; snack.show = true
    enrolDialog.value = false
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Enrol failed'
    snack.color = 'error'; snack.show = true
  } finally { enrolling.value = false }
}
async function completeEnrollment(e) {
  try {
    const { data } = await $api.post(`/homecare/pathway-enrollments/${e.id}/complete/`)
    const i = enrollments.value.findIndex(x => x.id === data.id)
    if (i >= 0) enrollments.value.splice(i, 1, data)
    snack.text = 'Enrolment marked complete'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Action failed'; snack.color = 'error'; snack.show = true
  }
}
async function withdrawEnrollment(e) {
  try {
    const { data } = await $api.post(`/homecare/pathway-enrollments/${e.id}/withdraw/`,
                                     { reason: 'Withdrawn by clinician' })
    const i = enrollments.value.findIndex(x => x.id === data.id)
    if (i >= 0) enrollments.value.splice(i, 1, data)
    snack.text = 'Enrolment withdrawn'; snack.color = 'warning'; snack.show = true
  } catch {
    snack.text = 'Action failed'; snack.color = 'error'; snack.show = true
  }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(124,58,237,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-pw-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
  transition: transform .15s ease;
}
.hc-pw-card:hover { transform: translateY(-1px); }
.hc-pw-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
.hc-form-hero { background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%); }
:global(.v-theme--dark) .hc-pw-card {
  background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06);
}
</style>
