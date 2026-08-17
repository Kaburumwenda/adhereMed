<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Patient Consents" subtitle="Patient consent management"
      icon="mdi-clipboard-check" color="teal">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="load">Refresh</v-btn>
        <v-btn color="teal" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNew">New Consent</v-btn>
      </template>
    </PageHeader>

    <!-- ── KPI stat cards ─────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="44" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-overline text-medium-emphasis" style="line-height:1.1">
                {{ k.label }}
              </div>
              <div class="text-h5 font-weight-bold" style="line-height:1.2">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="7">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search consents by patient, grantee…"
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
        <v-progress-circular indeterminate color="teal" size="48" />
      </div>

      <div v-else-if="!filteredConsents.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-clipboard-check</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No consents found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ statusFilter || r.search.value ? 'Try adjusting your filters.' : 'Record your first consent to get started.' }}
        </div>
        <v-btn v-if="!statusFilter && !r.search.value" color="teal" rounded="lg"
          prepend-icon="mdi-plus" @click="openNew">New Consent</v-btn>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredConsents"
        :items-per-page="20"
        item-value="id"
        hover
        class="consents-table">
        <template #item.patient="{ value, item }">
          {{ item.patient_name || value || '—' }}
        </template>
        <template #item.scope="{ value }">
          <v-chip size="small" variant="tonal" color="teal" class="text-capitalize">
            {{ scopeLabel(value) }}
          </v-chip>
        </template>
        <template #item.granted_to="{ value }">
          <span v-if="value" class="text-body-2">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" :color="statusColor(item)" variant="tonal">
            {{ statusLabel(item) }}
          </v-chip>
        </template>
        <template #item.granted_at="{ value }">{{ formatDate(value) }}</template>
        <template #item.expires_at="{ value }">{{ formatDate(value) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn v-if="!item.revoked_at && consentActive(item)"
              icon="mdi-cancel" variant="text" size="small" color="error"
              @click="confirmRevoke(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ New consent dialog ═════════════════════════════════════ -->
    <v-dialog v-model="dialog" max-width="600" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon color="teal" class="mr-2">mdi-clipboard-check</v-icon>
          New Consent
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
              <v-col cols="12" sm="6">
                <v-select v-model="form.scope" :items="scopeOptions"
                  label="Consent Type" required variant="outlined" density="compact"
                  prepend-inner-icon="mdi-shield-key" :rules="req" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.granted_to" label="Granted To"
                  variant="outlined" density="compact"
                  prepend-inner-icon="mdi-account-arrow-right"
                  hint="Recipient clinic, pharmacy or insurer"
                  persistent-hint />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Description / Notes"
                  rows="2" auto-grow variant="outlined" density="compact"
                  prepend-inner-icon="mdi-text" />
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
          <v-btn color="teal" rounded="lg" class="text-none" :loading="r.saving.value"
            prepend-icon="mdi-check" @click="save">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Revoke confirmation dialog ══════════════════════════════ -->
    <v-dialog v-model="revokeDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Revoke Consent</v-card-title>
        <v-card-text>
          Are you sure you want to revoke the consent for
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

const scopeOptions = [
  { title: 'Medical Records', value: 'records' },
  { title: 'Medication Plan', value: 'medication' },
  { title: 'Insurance Sharing', value: 'insurance' },
  { title: 'Teleconsult', value: 'teleconsult' },
  { title: 'Data Analytics', value: 'data_analytics' },
  { title: 'Treatment', value: 'treatment' },
  { title: 'Data Sharing', value: 'data_sharing' },
  { title: 'Procedure', value: 'procedure' },
  { title: 'Research', value: 'research' },
]

const headers = [
  { title: 'Patient', key: 'patient', width: 200 },
  { title: 'Type', key: 'scope', width: 160 },
  { title: 'Granted To', key: 'granted_to', width: 160 },
  { title: 'Status', key: 'status', width: 120 },
  { title: 'Granted', key: 'granted_at', width: 130 },
  { title: 'Expiry', key: 'expires_at', width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 90 },
]

const filteredConsents = computed(() => {
  let list = r.filtered.value
  if (statusFilter.value === 'active') list = list.filter(c => consentActive(c))
  else if (statusFilter.value === 'expired') list = list.filter(c => !c.revoked_at && (c.expires_at && new Date(c.expires_at) < new Date()))
  else if (statusFilter.value === 'revoked') list = list.filter(c => c.revoked_at)
  return list
})

const statusFilter = ref(null)

function scopeLabel(v) {
  const map = { records: 'Medical Records', medication: 'Medication Plan',
    insurance: 'Insurance', teleconsult: 'Teleconsult',
    data_analytics: 'Data Analytics', treatment: 'Treatment',
    data_sharing: 'Data Sharing', procedure: 'Procedure', research: 'Research' }
  return map[v] || (v || '—').split('_').map(w => w[0]?.toUpperCase() + w.slice(1)).join(' ')
}

function consentActive(c) {
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

const kpis = computed(() => {
  const list = r.items.value
  return [
    { label: 'Total', value: list.length, icon: 'mdi-clipboard-check', color: 'teal' },
    { label: 'Active', value: list.filter(consentActive).length, icon: 'mdi-check-decagram', color: 'success' },
    { label: 'Expired', value: list.filter(c => !c.revoked_at && c.expires_at && new Date(c.expires_at) < new Date()).length, icon: 'mdi-clock-alert', color: 'warning' },
    { label: 'Revoked', value: list.filter(c => c.revoked_at).length, icon: 'mdi-cancel', color: 'error' },
  ]
})

const patientOptions = computed(() =>
  patientR.items.value.map(p => ({
    title: p.patient_number || p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim() || 'Unknown',
    value: p.id,
  })),
)

// ── New dialog ─────────────────────────────────────────────────
const dialog = ref(false)
const formRef = ref(null)
const blankForm = () => ({ patient: null, scope: 'treatment', granted_to: '', notes: '', expires_at: '' })
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
    snack.text = 'Consent created successfully'
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
    snack.text = 'Consent revoked'
    snack.color = 'success'
    snack.show = true
    revokeDialog.value = false
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to revoke consent.'
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
