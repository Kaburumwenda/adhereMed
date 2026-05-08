
<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Care Notes"
      subtitle="Shift notes, observations, and patient updates."
      eyebrow="DOCUMENTATION"
      icon="mdi-note-edit"
      :chips="[{ icon: 'mdi-note-multiple', label: `${notes.length} notes` }]"
    >
      <template #actions>
        <v-btn color="white" rounded="pill" prepend-icon="mdi-plus" class="text-none" @click="openDialog()">
          <span class="text-teal-darken-2 font-weight-bold">New note</span>
        </v-btn>
      </template>
    </HomecareHero>

    <HomecarePanel title="All notes" subtitle="Filter by patient, category, or date" icon="mdi-note-multiple" color="#6366f1">
      <v-row dense class="mb-2">
        <v-col cols="12" md="3">
          <v-select v-model="filter.patient" :items="patients" item-title="patient_name" item-value="id" label="Patient" clearable density="compact" />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filter.category" :items="categories" label="Category" clearable density="compact" />
        </v-col>
        <v-col cols="12" md="3">
          <v-text-field v-model="filter.date" label="Date" type="date" density="compact" clearable />
        </v-col>
        <v-col cols="12" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search notes…" density="compact" clearable />
        </v-col>
      </v-row>
      <v-data-table :headers="headers" :items="filteredNotes" :loading="loading" item-value="id" class="elevation-0">
        <template #[`item.content`]="{ item }">
          <div class="text-truncate" style="max-width:400px;">{{ item.content }}</div>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn icon="mdi-eye-outline" size="small" variant="text" @click="view(item)" />
          <v-btn icon="mdi-pencil-outline" size="small" variant="text" color="primary" @click="edit(item)" />
          <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="remove(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-note-off" title="No notes found" />
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- Note dialog -->
    <v-dialog v-model="dialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title>{{ dialogMode === 'edit' ? 'Edit note' : dialogMode === 'view' ? 'Note details' : 'New note' }}</v-card-title>
        <v-card-text>
          <v-combobox
            v-model="form.patient"
            :items="patients"
            item-title="patient_name"
            item-value="id"
            label="Patient"
            :disabled="dialogMode==='view'"
            clearable
            allow-overflow
            hint="Type to enter a new name or select an existing patient."
            persistent-hint
          />
          <v-select v-model="form.category" :items="categories" label="Category" :disabled="dialogMode==='view'" />
          <v-textarea v-model="form.content" label="Note" rows="4" :disabled="dialogMode==='view'" />
          <v-file-input
            v-model="form.attachments"
            label="Attachments"
            multiple
            prepend-icon="mdi-paperclip"
            :disabled="dialogMode==='view'"
            accept=".pdf,.jpg,.jpeg,.png,.doc,.docx,.txt"
            hint="Supported: PDF, JPG, PNG, DOC, TXT"
            persistent-hint
          />
          <div v-if="form.attachments && form.attachments.length && dialogMode==='view'" class="mt-2">
            <div v-for="(file, i) in form.attachments" :key="i" class="text-caption">
              <v-icon icon="mdi-paperclip" size="14" class="mr-1" /> {{ file.name || file }}
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Close</v-btn>
          <v-btn v-if="dialogMode==='edit'" color="teal" :loading="saving" @click="save">Save</v-btn>
          <v-btn v-if="dialogMode==='create'" color="teal" :loading="saving" @click="save">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const notes = ref([])
const patients = ref([])
const categories = [
  'Shift', 'Vitals', 'Incident', 'Medication', 'General', 'Family', 'Other'
]
const loading = ref(false)
const dialog = ref(false)
const dialogMode = ref('create') // create | edit | view
const form = reactive({ id: null, patient: null, category: '', content: '', attachments: [] })
const filter = reactive({ patient: null, category: null, date: null })
const search = ref('')
const saving = ref(false)

const headers = [
  { title: 'Recorded', key: 'recorded_at' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Caregiver', key: 'caregiver_name' },
  { title: 'Category', key: 'category' },
  { title: 'Note', key: 'content', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]

const filteredNotes = computed(() => {
  let out = notes.value
  if (filter.patient) out = out.filter(n => n.patient === filter.patient)
  if (filter.category) out = out.filter(n => n.category === filter.category)
  if (filter.date) out = out.filter(n => (n.recorded_at || '').slice(0,10) === filter.date)
  if (search.value) {
    const q = search.value.toLowerCase()
    out = out.filter(n => (n.content || '').toLowerCase().includes(q))
  }
  return out
})

function openDialog(mode = 'create', item = null) {
  dialogMode.value = mode
  dialog.value = true
  if (mode === 'edit' || mode === 'view') {
    Object.assign(form, item)
    if (!form.attachments) form.attachments = []
  } else {
    Object.assign(form, { id: null, patient: null, category: '', content: '', attachments: [] })
  }
}
function view(item) { openDialog('view', item) }
function edit(item) { openDialog('edit', item) }
function remove(item) {
  if (!confirm('Delete this note?')) return
  $api.delete(`/homecare/notes/${item.id}/`).then(load)
}
async function save() {
  saving.value = true
  try {
    if (dialogMode.value === 'edit') {
      await $api.put(`/homecare/notes/${form.id}/`, form)
    } else {
      await $api.post('/homecare/notes/', form)
    }
    dialog.value = false
    load()
  } catch (e) { alert('Failed to save note.') }
  finally { saving.value = false }
}
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/notes/')
    notes.value = data?.results || data || []
  } catch { notes.value = [] }
  finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}
onMounted(() => { load(); loadPatients() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
</style>
