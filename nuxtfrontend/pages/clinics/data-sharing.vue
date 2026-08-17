<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Data Sharing" subtitle="Patient data sharing agreements"
      icon="mdi-share-variant" color="cyan">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="load">Refresh</v-btn>
        <v-btn color="cyan" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNew">New Agreement</v-btn>
      </template>
    </PageHeader>

    <v-alert type="info" variant="tonal" density="comfortable" rounded="lg" class="mb-3"
      icon="mdi-information">
      Data sharing agreements control what patient information can be shared with external parties.
    </v-alert>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="7">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search agreements by patient, recipient…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="5">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact"
            hide-details clearable />
        </v-col>
      </v-row>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="cyan" size="48" />
      </div>

      <div v-else-if="!filteredAgreements.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-share-variant</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No data sharing agreements found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ statusFilter || r.search.value ? 'Try adjusting your filters.' : 'Create your first data sharing agreement.' }}
        </div>
        <v-btn v-if="!statusFilter && !r.search.value" color="cyan" rounded="lg"
          prepend-icon="mdi-plus" @click="openNew">New Agreement</v-btn>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredAgreements"
        :items-per-page="20"
        item-value="id"
        hover
        class="agreements-table">
        <template #item.patient="{ value, item }">
          {{ item.patient_name || value || '—' }}
        </template>
        <template #item.granted_to="{ value }">
          <span v-if="value" class="font-weight-medium">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.notes="{ value }">
          <span v-if="value" class="text-truncate d-inline-block" style="max-width: 200px">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.shared_fields="{ item }">
          <div v-if="sharedFields(item).length">
            <v-chip v-for="f in sharedFields(item).slice(0, 3)" :key="f"
              size="x-small" variant="tonal" color="cyan" class="mr-1 mb-1">
              {{ f }}
            </v-chip>
            <v-chip v-if="sharedFields(item).length > 3" size="x-small" variant="text">
              +{{ sharedFields(item).length - 3 }}
            </v-chip>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.granted_at="{ value }">{{ formatDate(value) }}</template>
        <template #item.expires_at="{ value }">{{ formatDate(value) }}</template>
        <template #item.status="{ item }">
          <v-chip size="small" :color="statusColor(item)" variant="tonal">
            {{ statusLabel(item) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn v-if="!item.revoked_at && agreementActive(item)"
              icon="mdi-cancel" variant="text" size="small" color="error"
              @click="confirmRevoke(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ New agreement dialog ═══════════════════════════════════ -->
    <v-dialog v-model="dialog" max-width="600" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon color="cyan" class="mr-2">mdi-share-variant</v-icon>
          New Data Sharing Agreement
        </v-card-title>
        <v-card-text>
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12">
                <v-select v-model="form.patient" :items="patientOptions"
                  label="Patient" required variant="outlined" density="compact"
                  prepend-inner-icon="mdi-account" :rules="req"
                  :loading="patientR.loading.value" />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="form.granted_to" label="Shared With (Organization)"
                  required variant="outlined" density="compact"
                  prepend-inner-icon="mdi-hospital-building" :rules="req"
                  hint="e.g. Riverside Pharmacy, NHIF" persistent-hint />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Purpose"
                  required rows="2" auto-grow variant="outlined" density="compact"
                  prepend-inner-icon="mdi-text-box" :rules="req" />
              </v-col>
              <v-col cols="12">
                <div class="text-subtitle-2 text-medium-emphasis mb-2">Shared Fields</div>
                <v-row dense>
                  <v-col v-for="f in fieldOptions" :key="f.key" cols="6" sm="4" md="6">
                    <v-checkbox v-model="form.shared_fields" :label="f.label"
                      :value="f.key" density="compact" hide-details color="cyan" />
                  </v-col>
                </v-row>
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.expires_at" label="Expiry Date"
                  type="date" variant="outlined" density="compact"
                  prepend-inner-icon="mdi-calendar-clock" />
              </v-col>
            </v-row>
            <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mt-3">
              {{ r.error.value }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="cyan" rounded="lg" class="text-none" :loading="r.saving.value"
            prepend-icon="mdi-check" @click="save">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Revoke confirmation dialog ══════════════════════════════ -->
    <v-dialog v-model="revokeDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Revoke Agreement</v-card-title>
        <v-card-text>
          Revoke the data sharing agreement for
          <strong>{{ revokeTarget?.patient_name || 'this patient' }}</strong>?
          <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="revokeDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="revoking" @click="performRevoke">Revoke</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const ns = '/clinics'
const r = useResource('/homecare/consents/')
const patientR = useResource('/patients/')

const { $api } = useNuxtApp()
const req = [v => !!v || 'Required']

const statusOptions = [
  { title: 'Active', value: 'active' },
  { title: 'Expired', value: 'expired' },
  { title: 'Revoked', value: 'revoked' },
]

const fieldOptions = [
  { key: 'profile', label: 'Profile' },
  { key: 'medications', label: 'Medications' },
  { key: 'vitals', label: 'Vitals' },
  { key: 'lab_results', label: 'Lab Results' },
  { key: 'diagnosis', label: 'Diagnosis' },
  { key: 'insurance', label: 'Insurance' },
  { key: 'consultations', label: 'Consultations' },
  { key: 'billing', label: 'Billing' },
]

const headers = [
  { title: 'Patient', key: 'patient', width: 180 },
  { title: 'Shared With', key: 'granted_to', width: 180 },
  { title: 'Purpose', key: 'notes' },
  { title: 'Shared Fields', key: 'shared_fields', width: 200 },
  { title: 'Date', key: 'granted_at', width: 130 },
  { title: 'Expiry', key: 'expires_at', width: 130 },
  { title: 'Status', key: 'status', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 90 },
]

// Data sharing consents have scope=data_sharing; include them all and filter client-side
const statusFilter = ref(null)

const filteredAgreements = computed(() => {
  let list = r.items.value.filter(c =>
    (c.scope || '') === 'data_sharing' || (c.scope || '').includes('sharing'),
  )
  if (statusFilter.value === 'active') list = list.filter(c => agreementActive(c))
  else if (statusFilter.value === 'expired') list = list.filter(c => !c.revoked_at && (c.expires_at && new Date(c.expires_at) < new Date()))
  else if (statusFilter.value === 'revoked') list = list.filter(c => c.revoked_at)
  const q = (r.search.value || '').toLowerCase()
  if (q) {
    list = list.filter(c =>
      (c.patient_name || '').toLowerCase().includes(q) ||
      (c.granted_to || '').toLowerCase().includes(q) ||
      (c.notes || '').toLowerCase().includes(q),
    )
  }
  return list
})

function sharedFields(item) {
  const raw = item.shared_fields
  if (Array.isArray(raw)) return raw.map((f) => {
    const label = fieldOptions.find(o => o.key === f)?.label || f
    return label
  })
  if (raw && typeof raw === 'object') {
    return Object.entries(raw).filter(([, v]) => v).map(([k]) => fieldOptions.find(o => o.key === k)?.label || k)
  }
  return []
}

function agreementActive(c) {
  if (c.revoked_at) return false
  if (c.expires_at && new Date(c.expires_at) < new Date()) return false
  return true
}

function statusLabel(c) {
  if (c.revoked_at) return 'Revoked'
  if (c.expires_at && new Date(c.expires_at) < new Date()) return 'Expired'
  return 'Active'
}

function statusColor(c) {
  const s = statusLabel(c)
  return s === 'Active' ? 'success' : s === 'Expired' ? 'warning' : 'error'
}

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: p.patient_number || p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown',
    value: p.id,
  })),
)

// ── New dialog ─────────────────────────────────────────────────
const dialog = ref(false)
const formRef = ref(null)
const blankForm = () => ({
  patient: null, scope: 'data_sharing', granted_to: '', notes: '',
  shared_fields: [], expires_at: '',
})
const form = reactive(blankForm())

function openNew() {
  Object.assign(form, blankForm())
  dialog.value = true
}

async function save() {
  const v = await formRef.value?.validate()
  if (v?.valid === false) return
  try {
    await r.create(form)
    snack.text = 'Data sharing agreement created successfully'
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    await load()
  } catch {}
}

// ── Revoke ─────────────────────────────────────────────────────
const revokeDialog = ref(false)
const revokeTarget = ref(null)
const revoking = ref(false)

function confirmRevoke(item) {
  revokeTarget.value = item
  revokeDialog.value = true
}

async function performRevoke() {
  revoking.value = true
  try {
    await $api.post(`/homecare/consents/${revokeTarget.value.id}/revoke/`)
    snack.text = 'Agreement revoked'
    snack.color = 'success'
    snack.show = true
    revokeDialog.value = false
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to revoke agreement.'
    snack.color = 'error'
    snack.show = true
  } finally {
    revoking.value = false
  }
}

const snack = reactive({ show: false, color: 'success', text: '' })

function load() {
  r.list({ page_size: 1000 })
}

onMounted(() => {
  load()
  patientR.list({ page_size: 1000 })
})
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
