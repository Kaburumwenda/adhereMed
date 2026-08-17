<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Care Notes" subtitle="Patient care notes and observations"
      icon="mdi-notebook-edit" color="purple">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="r.list({ page_size: 1000 })">Refresh</v-btn>
        <v-btn color="purple" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openDialog()">New Care Note</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search notes, patient…" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="4">
          <v-select v-model="patientFilter" :items="patientOptions"
            label="Filter by patient" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="purple" size="48" />
      </div>

      <div v-else-if="!filteredNotes.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-notebook-edit</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No care notes found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ r.search.value || patientFilter ? 'Try adjusting your filters.' : 'Create your first care note to get started.' }}
        </div>
        <v-btn v-if="!r.search.value && !patientFilter" color="purple" rounded="lg"
          prepend-icon="mdi-plus" class="text-none" @click="openDialog()">New Care Note</v-btn>
      </div>

      <v-data-table v-else :headers="headers" :items="filteredNotes"
        :items-per-page="20" item-value="id" hover class="notes-table">
        <template #item.patient_name="{ value }">
          <span class="font-weight-medium">{{ value || '—' }}</span>
        </template>
        <template #item.category="{ value }">
          <v-chip size="small" variant="tonal" :color="noteTypeColor(value)"
            class="text-capitalize">{{ value }}</v-chip>
        </template>
        <template #item.recorded_at="{ value }">{{ formatDateTime(value) }}</template>
        <template #item.content="{ value }">
          <span class="text-truncate d-inline-block" style="max-width: 280px;">{{ value || '—' }}</span>
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
    <v-dialog v-model="dialog" max-width="600" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6">
          <v-icon color="purple" class="mr-2">mdi-notebook-edit</v-icon>
          {{ editing ? 'Edit Care Note' : 'New Care Note' }}
        </v-card-title>
        <v-divider />
        <v-card-text>
          <v-form ref="formRef">
            <v-select v-model="noteForm.patient" :items="patientOptions"
              label="Patient" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-account" class="mb-2"
              :loading="patientR.loading.value" />
            <v-select v-model="noteForm.category" :items="noteTypeOptions"
              label="Note type" variant="outlined" prepend-inner-icon="mdi-tag"
              class="mb-2" />
            <v-select v-model="noteForm.priority" :items="priorityOptions"
              label="Priority" variant="outlined" prepend-inner-icon="mdi-flag"
              class="mb-2" />
            <v-textarea v-model="noteForm.content" label="Content"
              variant="outlined" rows="4" auto-grow :rules="req" />
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="dialog = false">Cancel</v-btn>
          <v-btn color="purple" rounded="lg" :loading="r.saving.value"
            @click="saveNote">{{ editing ? 'Update' : 'Create' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Care Note?</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete this care note for
              <strong>{{ deleteTarget?.patient_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
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

const r = useResource('/homecare/care-notes/')
const patientR = useResource('/patients/')

onMounted(() => {
  r.list({ page_size: 1000 })
  patientR.list({ page_size: 1000 })
})

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Type', key: 'category', sortable: false, width: 120 },
  { title: 'Author', key: 'caregiver_name', sortable: false },
  { title: 'Date', key: 'recorded_at', width: 160 },
  { title: 'Content', key: 'content', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]

const noteTypeOptions = ['general', 'observation', 'incident', 'medication', 'follow-up']
const priorityOptions = ['routine', 'important', 'urgent']
const patientFilter = ref(null)

const req = [v => !!v || 'Required']
const formRef = ref(null)
const dialog = ref(false)
const editing = ref(null)
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const noteForm = reactive({
  patient: null,
  category: 'general',
  priority: 'routine',
  content: '',
})

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: `${p.patient_number || ''} — ${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown'}`.trim(),
    value: p.id,
  })),
)

const filteredNotes = computed(() => {
  if (!patientFilter.value) return r.filtered.value
  return r.filtered.value.filter(n => n.patient === patientFilter.value)
})

function noteTypeColor(type) {
  const map = {
    general: 'grey',
    observation: 'info',
    incident: 'error',
    medication: 'warning',
    'follow-up': 'success',
  }
  return map[type] || 'grey'
}

function openDialog(item) {
  if (item) {
    editing.value = item.id
    noteForm.patient = item.patient
    noteForm.category = item.category || 'general'
    noteForm.priority = item.priority || 'routine'
    noteForm.content = item.content || ''
  } else {
    editing.value = null
    Object.assign(noteForm, { patient: null, category: 'general', priority: 'routine', content: '' })
  }
  dialog.value = true
}

async function saveNote() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    if (editing.value) await r.update(editing.value, { ...noteForm })
    else await r.create({ ...noteForm })
    snack.text = editing.value ? 'Care note updated' : 'Care note created'
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    r.list({ page_size: 1000 })
  } catch {
    snack.text = r.error.value || 'Failed to save care note'
    snack.color = 'error'
    snack.show = true
  }
}

function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Care note deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    deleteTarget.value = null
  } catch {
    snack.text = r.error.value || 'Failed to delete care note'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
</style>
