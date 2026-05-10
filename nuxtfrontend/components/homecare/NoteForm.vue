<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      :title="editing ? 'Edit care note' : 'New care note'"
      :subtitle="editing ? 'Update an existing shift note, observation or incident.' : 'Document a new shift note, observation, vitals reading or incident.'"
      eyebrow="HOMECARE · DOCUMENTATION"
      icon="mdi-note-edit"
      :chips="[]"
    >
      <template #actions>
        <v-btn variant="text" rounded="pill" color="white" prepend-icon="mdi-arrow-left"
               class="text-none" @click="goBack">
          <span class="font-weight-bold">Back to notes</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense class="mt-2">
      <v-col cols="12" lg="8">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 pa-md-6">
          <v-progress-linear v-if="loading" indeterminate color="teal" rounded class="mb-4" />

          <div class="text-subtitle-1 font-weight-bold mb-3">Note details</div>

          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.patient" :items="patientOptions" label="Patient *"
                        variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.caregiver" :items="caregiverOptions" label="Caregiver *"
                        variant="outlined" rounded="lg" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.category" :items="categoryOptions" label="Category *"
                        item-title="label" item-value="value"
                        variant="outlined" rounded="lg" density="comfortable">
                <template #item="{ item, props: itemProps }">
                  <v-list-item v-bind="itemProps" :title="item.raw.label">
                    <template #prepend>
                      <v-icon :icon="item.raw.icon" :color="item.raw.color" />
                    </template>
                  </v-list-item>
                </template>
                <template #selection="{ item }">
                  <v-icon :icon="item.raw.icon" :color="item.raw.color" class="mr-2" size="18" />
                  {{ item.raw.label }}
                </template>
              </v-select>
            </v-col>
            <v-col cols="12" md="6">
              <div class="d-flex ga-2">
                <v-text-field v-model="form.recorded_date" type="date" label="Recorded date *"
                              variant="outlined" rounded="lg" density="comfortable"
                              prepend-inner-icon="mdi-calendar"
                              hide-details="auto" style="flex:1 1 60%;" />
                <v-text-field v-model="form.recorded_time" type="time" label="Time"
                              variant="outlined" rounded="lg" density="comfortable"
                              prepend-inner-icon="mdi-clock-outline"
                              hide-details="auto" style="flex:1 1 40%;" />
              </div>
              <div class="text-caption text-medium-emphasis mt-1 ml-1">
                <v-icon icon="mdi-information-outline" size="14" class="mr-1" />
                Should reflect when the event happened, not when you typed it.
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field :model-value="createdAtDisplay" label="Created at"
                            variant="outlined" rounded="lg" density="comfortable"
                            prepend-inner-icon="mdi-clock-check-outline"
                            readonly persistent-hint
                            hint="Auto-filled when the note is created." />
            </v-col>
          </v-row>

          <div class="text-subtitle-1 font-weight-bold mt-4 mb-2">Note *</div>
          <RichTextEditor v-model="form.content" placeholder="Write the note here. Use the toolbar to add lists, bold, headings…" />

          <div class="d-flex align-center mt-5 mb-2">
            <div class="text-subtitle-1 font-weight-bold">Attachments</div>
            <v-chip size="x-small" color="grey" variant="tonal" class="ml-2">Optional</v-chip>
          </div>

          <v-file-input v-model="newFiles"
                        label="Add files (PDF, JPG, PNG, DOC, TXT)"
                        multiple chips show-size counter clearable
                        prepend-icon="mdi-paperclip"
                        accept=".pdf,.jpg,.jpeg,.png,.doc,.docx,.txt"
                        variant="outlined" rounded="lg" density="comfortable"
                        :hint="`Up to ${MAX_FILE_MB}MB per file. Multiple files supported.`"
                        persistent-hint />

          <div v-if="existingFiles.length" class="mt-3">
            <div class="text-caption text-medium-emphasis mb-1">Already attached</div>
            <div class="d-flex flex-wrap ga-2">
              <v-chip v-for="(f, i) in existingFiles" :key="`ex-${i}`" size="small"
                      color="teal" variant="tonal" closable
                      @click:close="removeExisting(i)">
                <v-icon icon="mdi-paperclip" start size="14" />
                {{ f.name || `attachment ${i + 1}` }}
                <span v-if="f.size" class="text-caption ml-1">({{ formatSize(f.size) }})</span>
              </v-chip>
            </div>
          </div>

          <v-alert v-if="attachError" type="warning" variant="tonal" density="compact" class="mt-2">
            {{ attachError }}
          </v-alert>

          <v-alert v-if="formError" type="error" variant="tonal" density="compact" class="mt-2">
            {{ formError }}
          </v-alert>

          <v-divider class="my-4" />

          <div class="d-flex justify-end ga-2">
            <v-btn variant="text" rounded="pill" class="text-none" @click="goBack">Cancel</v-btn>
            <v-btn color="teal-darken-2" rounded="pill" class="text-none px-5" :loading="saving"
                   prepend-icon="mdi-content-save" @click="save">
              {{ editing ? 'Save changes' : 'Create note' }}
            </v-btn>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4">
          <div class="d-flex align-center ga-2 mb-2">
            <v-icon icon="mdi-information-outline" color="teal-darken-2" />
            <div class="text-subtitle-1 font-weight-bold">Tips</div>
          </div>
          <ul class="hc-tips">
            <li>Use <b>Headings</b> and <b>lists</b> to make notes easy to scan during handovers.</li>
            <li>Pick the right <b>category</b> – it drives filters, dashboards and alerts.</li>
            <li>Attach photos, lab PDFs or signed forms as <b>attachments</b>.</li>
            <li>The <b>recorded at</b> time should reflect when the event happened, not when you typed it.</li>
          </ul>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const props = defineProps({
  noteId: { type: [String, Number], default: null },
})

const { $api } = useNuxtApp()

const caregivers = ref([])
const patients = ref([])
const loading = ref(false)
const saving = ref(false)
const formError = ref('')

const editing = computed(() => !!props.noteId)

const form = reactive({
  id: null, patient: null, caregiver: null, category: '', content: '',
  recorded_date: '', recorded_time: '',
  vitals: {},
})
const existingFiles = ref([])   // already-stored attachments [{name,type,size,data}]
const newFiles = ref([])         // freshly picked File objects from v-file-input
const attachError = ref('')
const MAX_FILE_MB = 5
const createdAt = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

const categoryOptions = [
  { value: 'diet',        label: 'Diet',        icon: 'mdi-food-apple',     color: 'green' },
  { value: 'activity',    label: 'Activity',    icon: 'mdi-run',            color: 'blue' },
  { value: 'observation', label: 'Observation', icon: 'mdi-eye',            color: 'teal' },
  { value: 'vitals',      label: 'Vitals',      icon: 'mdi-heart-pulse',    color: 'pink' },
  { value: 'incident',    label: 'Incident',    icon: 'mdi-alert-octagon',  color: 'red' },
  { value: 'medication',  label: 'Medication',  icon: 'mdi-pill',           color: 'purple' },
]

const caregiverOptions = computed(() =>
  caregivers.value.map(c => ({ title: c.user?.full_name || c.user?.email, value: c.id }))
)
const patientOptions = computed(() =>
  patients.value.map(p => ({ title: p.user?.full_name || p.medical_record_number, value: p.id }))
)

const createdAtDisplay = computed(() => {
  if (createdAt.value) {
    return new Date(createdAt.value).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })
  }
  return editing.value ? '—' : 'Will be set on save'
})

function nowLocal() {
  const now = new Date()
  const pad = n => n.toString().padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`
}

async function loadOptions() {
  try {
    const [c, p] = await Promise.all([
      $api.get('/homecare/caregivers/', { params: { page_size: 500 } }),
      $api.get('/homecare/patients/',   { params: { page_size: 500 } }),
    ])
    caregivers.value = c.data?.results || c.data || []
    patients.value   = p.data?.results || p.data || []
  } catch { caregivers.value = []; patients.value = [] }
}

async function loadNote() {
  if (!props.noteId) return
  loading.value = true
  try {
    const { data } = await $api.get(`/homecare/notes/${props.noteId}/`)
    const recorded = data.recorded_at ? splitDateTime(data.recorded_at) : { date: '', time: '' }
    Object.assign(form, {
      id: data.id,
      patient: data.patient,
      caregiver: data.caregiver,
      category: data.category,
      content: data.content || '',
      recorded_date: recorded.date,
      recorded_time: recorded.time,
      vitals: data.vitals || {},
    })
    existingFiles.value = Array.isArray(data.attached_files) ? [...data.attached_files] : []
    newFiles.value = []
    createdAt.value = data.created_at || data.recorded_at || null
  } catch {
    formError.value = 'Could not load note.'
  } finally {
    loading.value = false
  }
}

function splitDateTime(iso) {
  const d = new Date(iso)
  const pad = n => n.toString().padStart(2, '0')
  return {
    date: `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`,
    time: `${pad(d.getHours())}:${pad(d.getMinutes())}`,
  }
}

function toLocalInput(iso) {
  const d = new Date(iso)
  const pad = n => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function save() {
  if (!form.patient || !form.caregiver || !form.category || !(form.content || '').trim()) {
    formError.value = 'Patient, caregiver, category, and note are required.'
    return
  }
  if (!form.recorded_date) {
    formError.value = 'Please pick the date the event happened.'
    return
  }
  saving.value = true
  formError.value = ''
  attachError.value = ''

  let encodedNew = []
  try {
    encodedNew = await encodeNewFiles()
  } catch (err) {
    saving.value = false
    attachError.value = err?.message || 'Could not read attachments.'
    return
  }

  const recordedIso = combineDateTime(form.recorded_date, form.recorded_time)
  const payload = {
    patient: form.patient,
    caregiver: form.caregiver,
    category: form.category,
    content: form.content,
    recorded_at: recordedIso,
    attached_files: [...existingFiles.value, ...encodedNew],
    vitals: form.vitals,
  }
  try {
    if (editing.value) {
      await $api.patch(`/homecare/notes/${form.id}/`, payload)
      Object.assign(snack, { show: true, text: 'Note updated', color: 'success' })
    } else {
      await $api.post('/homecare/notes/', payload)
      Object.assign(snack, { show: true, text: 'Note created', color: 'success' })
    }
    setTimeout(() => navigateTo('/homecare/notes'), 600)
  } catch (e) {
    const d = e?.response?.data
    formError.value = (typeof d === 'string' ? d : d?.detail) ||
      Object.entries(d || {}).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join('\n') ||
      'Could not save note.'
  } finally {
    saving.value = false
  }
}

function stripHtml(html) {
  if (!html) return ''
  return String(html).replace(/<[^>]*>/g, '')
}

function combineDateTime(date, time) {
  if (!date) return undefined
  const t = time && /^\d{2}:\d{2}$/.test(time) ? time : '00:00'
  // Treat as local time, then convert to ISO.
  return new Date(`${date}T${t}`).toISOString()
}

function normalizeFiles(v) {
  if (!v) return []
  if (Array.isArray(v)) return v.filter(f => f instanceof File)
  if (v instanceof File) return [v]
  return []
}

function formatSize(bytes) {
  if (!bytes && bytes !== 0) return ''
  const units = ['B', 'KB', 'MB', 'GB']
  let n = Number(bytes), i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return `${n.toFixed(n < 10 && i ? 1 : 0)} ${units[i]}`
}

function removeExisting(idx) {
  existingFiles.value.splice(idx, 1)
}

function readAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = () => reject(new Error(`Could not read ${file.name}`))
    reader.readAsDataURL(file)
  })
}

async function encodeNewFiles() {
  const files = normalizeFiles(newFiles.value)
  if (!files.length) return []
  const out = []
  for (const f of files) {
    if (f.size > MAX_FILE_MB * 1024 * 1024) {
      throw new Error(`"${f.name}" is larger than ${MAX_FILE_MB}MB.`)
    }
    const data = await readAsDataUrl(f)
    out.push({
      name: f.name,
      type: f.type || '',
      size: f.size,
      data, // base64 data URL
    })
  }
  return out
}

function goBack() {
  navigateTo('/homecare/notes')
}

onMounted(async () => {
  await loadOptions()
  await loadNote()
  // Allow ?patient=<id> deep link to pre-select the patient
  const route = useRoute()
  if (!props.noteId && route.query.patient && !form.patient) {
    form.patient = Number(route.query.patient)
  }
})
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); }
.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
.hc-tips {
  margin: 0;
  padding-left: 1.1rem;
  color: rgba(15,23,42,0.75);
  font-size: 0.9rem;
  line-height: 1.6;
}
:global(.v-theme--dark) .hc-tips { color: rgba(226,232,240,0.8); }
.hc-tips li + li { margin-top: 6px; }
</style>
