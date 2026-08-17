<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Care Escalations" subtitle="Patient care escalations and alerts"
      icon="mdi-bell-alert" color="error">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="reload">Refresh</v-btn>
        <v-btn color="error" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openDialog()">New Escalation</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search reason, patient…" variant="outlined"
            density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="4">
          <v-select v-model="priorityFilter" :items="priorityOptions"
            label="Priority" variant="outlined" density="compact" hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="error" size="48" />
      </div>

      <div v-else-if="!filteredEscalations.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-bell-alert</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No escalations found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ r.search.value || statusFilter || priorityFilter ? 'Try adjusting your filters.' : 'Create an escalation to track a care concern.' }}
        </div>
        <v-btn v-if="!r.search.value && !statusFilter && !priorityFilter" color="error"
          rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openDialog()">New Escalation</v-btn>
      </div>

      <v-data-table v-else :headers="headers" :items="filteredEscalations"
        :items-per-page="20" item-value="id" hover class="escalations-table">
        <template #item.patient_name="{ value }">
          <span class="font-weight-medium">{{ value || '—' }}</span>
        </template>
        <template #item.reason="{ value }">
          <span class="text-truncate d-inline-block" style="max-width: 220px;">{{ value || '—' }}</span>
        </template>
        <template #item.severity="{ value }">
          <v-chip size="small" variant="tonal" :color="priorityColor(value)"
            class="text-capitalize font-weight-medium">{{ value }}</v-chip>
        </template>
        <template #item.status="{ value }">
          <v-chip size="small" variant="tonal" :color="statusColor(value)"
            class="text-capitalize font-weight-medium">{{ value }}</v-chip>
        </template>
        <template #item.triggered_at="{ value }">{{ formatDateTime(value) }}</template>
        <template #item.resolved_at="{ value }">
          {{ value ? formatDateTime(value) : '—' }}
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn v-if="canResolve(item)" icon="mdi-check-decagram" variant="text"
              size="small" color="success" @click="resolveEscalation(item)" />
            <v-btn v-if="canClose(item)" icon="mdi-close-circle" variant="text"
              size="small" color="grey" @click="closeEscalation(item)" />
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
          <v-icon color="error" class="mr-2">mdi-bell-alert</v-icon>
          {{ editing ? 'Edit Escalation' : 'New Escalation' }}
        </v-card-title>
        <v-divider />
        <v-card-text>
          <v-form ref="formRef">
            <v-select v-model="escForm.patient" :items="patientOptions"
              label="Patient" variant="outlined" :rules="req"
              prepend-inner-icon="mdi-account" class="mb-2"
              :loading="patientR.loading.value" />
            <v-text-field v-model="escForm.reason" label="Reason"
              variant="outlined" :rules="req" class="mb-2" />
            <v-select v-model="escForm.severity" :items="priorityOptions"
              label="Priority" variant="outlined" prepend-inner-icon="mdi-flag"
              class="mb-2" />
            <v-textarea v-model="escForm.detail" label="Description"
              variant="outlined" rows="3" auto-grow class="mb-2" />
            <v-select v-model="escForm.assigned_to" :items="staffOptions"
              label="Assigned to" variant="outlined"
              prepend-inner-icon="mdi-account-tie"
              :loading="staffR.loading.value" />
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="dialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="r.saving.value"
            @click="saveEscalation">{{ editing ? 'Update' : 'Create' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Escalation?</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete this escalation for
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
const { $api } = useNuxtApp()

const r = useResource('/homecare/escalations/')
const patientR = useResource('/patients/')
const staffR = useResource('/auth/staff/')

onMounted(reload)

async function reload() {
  await Promise.all([
    r.list({ page_size: 1000 }),
    patientR.list({ page_size: 1000 }),
    staffR.list({ page_size: 1000 }),
  ])
}

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Reason', key: 'reason', sortable: false },
  { title: 'Priority', key: 'severity', sortable: false, width: 110 },
  { title: 'Status', key: 'status', sortable: false, width: 120 },
  { title: 'Escalated By', key: 'acknowledged_by_name', sortable: false },
  { title: 'Date', key: 'triggered_at', width: 160 },
  { title: 'Resolved', key: 'resolved_at', width: 160 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

const statusOptions = ['open', 'in_progress', 'resolved', 'closed']
const priorityOptions = ['low', 'medium', 'high', 'critical']

const statusFilter = ref(null)
const priorityFilter = ref(null)
const req = [v => !!v || 'Required']
const formRef = ref(null)
const dialog = ref(false)
const editing = ref(null)
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const escForm = reactive({ patient: null, reason: '', severity: 'medium', detail: '', assigned_to: null })

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: `${p.patient_number || ''} — ${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown'}`.trim(),
    value: p.id,
  })),
)
const staffOptions = computed(() =>
  staffR.items.value.map(s => ({ title: s.full_name || s.email, value: s.id })),
)

const filteredEscalations = computed(() => {
  let list = r.filtered.value
  if (statusFilter.value) list = list.filter(e => statusOf(e) === statusFilter.value)
  if (priorityFilter.value) list = list.filter(e => e.severity === priorityFilter.value)
  return list
})

function statusOf(e) { return e.status || 'open' }

function statusColor(s) {
  const map = {
    open: 'error',
    in_progress: 'info',
    acknowledged: 'warning',
    resolved: 'success',
    closed: 'grey',
  }
  return map[s] || 'grey'
}

function priorityColor(p) {
  const map = { low: 'grey', medium: 'info', high: 'warning', critical: 'error' }
  return map[p] || 'grey'
}

function canResolve(item) {
  const s = statusOf(item)
  return s === 'open' || s === 'acknowledged' || s === 'in_progress'
}
function canClose(item) {
  const s = statusOf(item)
  return s === 'open' || s === 'acknowledged' || s === 'in_progress'
}

function openDialog(item) {
  if (item) {
    editing.value = item.id
    escForm.patient = item.patient
    escForm.reason = item.reason || ''
    escForm.severity = item.severity || 'medium'
    escForm.detail = item.detail || ''
    escForm.assigned_to = item.acknowledged_by || null
  } else {
    editing.value = null
    Object.assign(escForm, { patient: null, reason: '', severity: 'medium', detail: '', assigned_to: null })
  }
  dialog.value = true
}

async function saveEscalation() {
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    if (editing.value) {
      await r.update(editing.value, {
        patient: escForm.patient, reason: escForm.reason,
        severity: escForm.severity, detail: escForm.detail,
      })
    } else {
      await r.create({
        patient: escForm.patient, reason: escForm.reason,
        severity: escForm.severity, detail: escForm.detail,
      })
    }
    snack.text = editing.value ? 'Escalation updated' : 'Escalation created'
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    r.list({ page_size: 1000 })
  } catch {
    snack.text = r.error.value || 'Failed to save escalation'
    snack.color = 'error'
    snack.show = true
  }
}

async function resolveEscalation(item) {
  try {
    await $api.post(`/homecare/escalations/${item.id}/resolve`, item.resolution_notes ? { resolution_notes: item.resolution_notes } : {})
    snack.text = 'Escalation resolved'
    snack.color = 'success'
    snack.show = true
    r.list({ page_size: 1000 })
  } catch (e) {
    snack.text = 'Failed to resolve escalation'
    snack.color = 'error'
    snack.show = true
  }
}

async function closeEscalation(item) {
  try {
    await r.update(item.id, { status: 'closed' })
    snack.text = 'Escalation closed'
    snack.color = 'success'
    snack.show = true
    r.list({ page_size: 1000 })
  } catch {
    snack.text = r.error.value || 'Failed to close escalation'
    snack.color = 'error'
    snack.show = true
  }
}

function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Escalation deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    deleteTarget.value = null
  } catch {
    snack.text = r.error.value || 'Failed to delete escalation'
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
