<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-alert-circle-outline"
      eyebrow="OHSMS · Incident management"
      title="Incident & Investigation Log"
      subtitle="Report, investigate and close out injuries, near misses, property damage and dangerous occurrences with full CAPA tracking."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportLog">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Report incident
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-format-list-bulleted</v-icon>
        <b>{{ incidents.count.value }}</b> total reports</span>
      <span class="ohs-chip"><v-icon size="12">mdi-progress-alert</v-icon>
        <b>{{ stats.open }}</b> open</span>
      <span v-if="stats.recordable" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-file-alert</v-icon>
        <b>{{ stats.recordable }}</b> recordable</span>
      <span v-if="stats.fatal" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-skull-crossbones</v-icon>
        <b>{{ stats.fatal }}</b> fatality</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Total incidents" :value="incidents.count.value" icon="mdi-alert-circle-outline" tone="primary"
              :sub="`${stats.period} in last 90 days`" />
      <OhsKpi label="Lost-time injuries" :value="stats.lti" icon="mdi-ambulance"
              :tone="stats.lti ? 'err' : 'ok'" :sub="`${stats.lostDays} days lost`" />
      <OhsKpi label="Recordable" :value="stats.recordable" icon="mdi-file-alert-outline" tone="warn"
              sub="reportable to regulator" />
      <OhsKpi label="Open investigations" :value="stats.investigating" icon="mdi-account-search-outline" tone="info"
              sub="awaiting root cause" />
      <OhsKpi label="Open CAPA" :value="stats.capa" icon="mdi-source-branch-check"
              :tone="stats.capaOverdue ? 'err' : 'info'" :sub="`${stats.capaOverdue} overdue`" />
    </div>

    <OhsPanel title="Incident register" :subtitle="`${filtered.length} report(s) shown`" icon="mdi-format-list-bulleted" flush>
      <template #actions>
        <v-chip-group v-model="statusFilter" mandatory selected-class="text-primary">
          <v-chip v-for="f in statusFilters" :key="f.value" :value="f.value" size="small" variant="tonal"
                  :color="f.color" class="text-caption">
            {{ f.label }}
            <span v-if="f.value !== 'all'" class="ml-1 opacity-70">{{ countByStatus(f.value) }}</span>
          </v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search reference, person, location…" prepend-inner-icon="mdi-magnify"
                      density="compact" variant="outlined" rounded="lg" hide-details single-line clearable
                      style="max-width:280px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg" hide-details clearable
                  style="max-width:190px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  placeholder="All types" density="compact" variant="outlined" rounded="lg" hide-details clearable
                  style="max-width:190px" />
        <v-select v-model="severityFilter" :items="severityOptions" item-title="label" item-value="value"
                  placeholder="Any severity" density="compact" variant="outlined" rounded="lg" hide-details clearable
                  style="max-width:180px" />
        <v-spacer />
        <v-checkbox v-model="onlyLti" density="compact" hide-details label="LTI only" color="error" />
      </div>

      <v-progress-linear v-if="incidents.loading.value" indeterminate color="primary" height="2" />

      <div class="ohs-scroll">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:110px">Ref</th>
              <th>Incident</th>
              <th style="width:130px">Site</th>
              <th style="width:120px">Type</th>
              <th style="width:100px">Severity</th>
              <th style="width:110px">Occurred</th>
              <th style="width:74px" class="num">Days</th>
              <th style="width:80px" class="num">Lost d</th>
              <th style="width:80px" class="num">CAPA</th>
              <th style="width:110px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="i in filtered" :key="i.id" @click="openDetail(i)">
              <td class="ohs-mono">{{ i.reference }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:340px">{{ i.title }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ i.person_involved || 'No person involved' }} · {{ i.location || i.department || '—' }}
                </div>
              </td>
              <td class="text-caption">{{ i.site_name }}</td>
              <td class="text-caption">{{ i.incident_type_display }}</td>
              <td>
                <span class="ohs-badge" :class="`ohs-badge--${toneFor(i.severity)}`">{{ i.severity_display }}</span>
              </td>
              <td class="text-caption">{{ formatDate(i.occurred_at) }}</td>
              <td class="num">{{ i.days_open }}</td>
              <td class="num" :class="{ 'text-error font-weight-bold': i.lost_days }">{{ i.lost_days || '—' }}</td>
              <td class="num">
                <span v-if="i.open_actions" class="ohs-badge ohs-badge--warn">{{ i.open_actions }}</span>
                <span v-else class="text-caption text-medium-emphasis">—</span>
              </td>
              <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(i.status)}`">{{ i.status_display }}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !incidents.loading.value" class="ohs-empty">
          <v-icon size="34" color="success">mdi-check-decagram</v-icon>
          No incidents match these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- ═══════════ DETAIL DRAWER ═══════════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="580">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color: rgba(255,255,255,.8)">{{ detail.reference }}</div>
              <div class="text-h6 font-weight-bold" style="line-height:1.25">{{ detail.title }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(detail.severity)}`">{{ detail.severity_display }}</span>
            <span class="glass-chip">{{ detail.incident_type_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span v-if="detail.is_lost_time" class="ohs-badge ohs-badge--crit">LTI</span>
            <span v-if="detail.is_recordable" class="glass-chip">Recordable</span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6"><div class="meta"><span>Site</span><b>{{ detail.site_name }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Location</span><b>{{ detail.location || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Person</span><b>{{ detail.person_involved || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Role</span><b>{{ detail.person_role || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Occurred</span><b>{{ formatDateTime(detail.occurred_at) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Reported</span><b>{{ formatDateTime(detail.reported_at) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Investigator</span><b>{{ detail.investigator || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Lost days</span><b>{{ detail.lost_days || 0 }}</b></div></v-col>
          </v-row>

          <div class="section-title">Description</div>
          <div class="text-body-2">{{ detail.description || '—' }}</div>

          <div class="section-title">Immediate action</div>
          <div class="text-body-2">{{ detail.immediate_action || '—' }}</div>

          <div class="section-title">Root cause</div>
          <div class="text-body-2">{{ detail.root_cause || 'Not established yet.' }}</div>
          <div v-if="detail.cause_category_display" class="mt-1">
            <span class="ohs-badge ohs-badge--muted">{{ detail.cause_category_display }}</span>
          </div>

          <div class="d-flex align-center justify-space-between mt-4 mb-2">
            <span class="text-subtitle-2 font-weight-bold">Corrective & preventive actions</span>
            <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none"
                   prepend-icon="mdi-plus" @click="capaDialog = true">Add CAPA</v-btn>
          </div>
          <div v-for="a in detail.actions" :key="a.id" class="capa-card">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="ohs-badge ohs-badge--info">{{ a.action_type_display }}</span>
              <span class="ohs-badge" :class="a.is_overdue ? 'ohs-badge--err' : `ohs-badge--${toneFor(a.status)}`">
                {{ a.is_overdue ? 'Overdue' : a.status_display }}
              </span>
            </div>
            <div class="text-body-2 mt-1">{{ a.description }}</div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ a.owner_name || 'Unassigned' }} · due {{ formatDate(a.due_date) }}
            </div>
          </div>
          <div v-if="!detail.actions?.length" class="text-caption text-medium-emphasis">No actions recorded.</div>
        </div>

        <div class="drawer-actions">
          <v-btn variant="text" class="text-none" prepend-icon="mdi-close-circle-outline" :disabled="detail.status === 'closed'"
                 @click="closeIncident">Close incident</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═══════════ REPORT INCIDENT ═══════════ -->
    <v-dialog v-model="createDialog" max-width="760" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-alert-plus" title="Report an incident"
                           subtitle="Log what happened — investigation and CAPA can follow." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Short title" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.occurred_at" type="datetime-local" label="Occurred at"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.incident_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Incident type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.severity" :items="severityOptions" item-title="label" item-value="value"
                        label="Severity" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.location" label="Location / area" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.person_involved" label="Person involved" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.department" label="Department" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="What happened" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.immediate_action" label="Immediate action taken" rows="2"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.lost_days" type="number" min="0" label="Lost days"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6" class="d-flex flex-column justify-center">
              <v-checkbox v-model="form.is_lost_time" density="compact" hide-details label="Lost-time injury" />
              <v-checkbox v-model="form.is_recordable" density="compact" hide-details label="Recordable to regulator" />
            </v-col>
          </v-row>
          <v-alert v-if="createError" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ createError }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="incidents.saving.value"
                 :disabled="!form.title || !form.site" @click="saveIncident">Submit report</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ ADD CAPA ═══════════ -->
    <v-dialog v-model="capaDialog" max-width="540">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-source-branch-check" title="Add corrective action"
                           subtitle="Assign an owner and a due date so it lands in the action queue." />
        <v-card-text>
          <v-select v-model="capaForm.action_type" :items="actionTypes" item-title="label" item-value="value"
                    label="Action type" variant="outlined" density="compact" rounded="lg" class="mb-2" />
          <v-textarea v-model="capaForm.description" label="Action" rows="2" variant="outlined"
                      density="compact" rounded="lg" class="mb-2" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="capaForm.owner_name" label="Owner" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="capaForm.due_date" type="date" label="Due date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="capaDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingCapa"
                 :disabled="!capaForm.description" @click="saveCapa">Add action</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { toneFor } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Incidents · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const incidents = ohs.resource('incidents')
const lookups = ref({})
const search = ref('')
const siteFilter = ref(null)
const typeFilter = ref(null)
const severityFilter = ref(null)
const statusFilter = ref('all')
const onlyLti = ref(false)

const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const capaDialog = ref(false)
const savingCapa = ref(false)
const createError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', site: null, incident_type: 'injury', severity: 'minor',
  location: '', person_involved: '', department: '', description: '',
  immediate_action: '', lost_days: 0, is_lost_time: false, is_recordable: false,
  occurred_at: new Date().toISOString().slice(0, 16),
})
const capaForm = reactive({ action_type: 'corrective', description: '', owner_name: '', due_date: '' })

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const typeOptions = computed(() => lookups.value.incident_types || [])
const severityOptions = computed(() => lookups.value.severities || [])
const actionTypes = [
  { label: 'Containment', value: 'containment' },
  { label: 'Corrective', value: 'corrective' },
  { label: 'Preventive', value: 'preventive' },
  { label: 'Training', value: 'training' },
  { label: 'Engineering change', value: 'engineering' },
]
const statusFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Open', value: 'reported', color: 'info' },
  { label: 'Investigating', value: 'investigating', color: 'warning' },
  { label: 'Actions', value: 'actions', color: 'deep-orange' },
  { label: 'Closed', value: 'closed', color: 'success' },
]

const rows = computed(() => incidents.items.value || [])

const filtered = computed(() => rows.value.filter((i) => {
  if (siteFilter.value && i.site !== siteFilter.value) return false
  if (typeFilter.value && i.incident_type !== typeFilter.value) return false
  if (severityFilter.value && i.severity !== severityFilter.value) return false
  if (statusFilter.value !== 'all' && i.status !== statusFilter.value) return false
  if (onlyLti.value && !i.is_lost_time) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${i.reference} ${i.title} ${i.person_involved} ${i.location} ${i.department} ${i.site_name}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const cutoff = Date.now() - 90 * 86400000
  return {
    open: all.filter((i) => i.status !== 'closed').length,
    recordable: all.filter((i) => i.is_recordable).length,
    lti: all.filter((i) => i.is_lost_time).length,
    lostDays: all.reduce((s, i) => s + (i.lost_days || 0), 0),
    investigating: all.filter((i) => i.status === 'investigating').length,
    capa: all.reduce((s, i) => s + (i.open_actions || 0), 0),
    capaOverdue: 0,
    fatal: all.filter((i) => i.severity === 'fatality').length,
    period: all.filter((i) => new Date(i.occurred_at).getTime() >= cutoff).length,
  }
})

function countByStatus(status) {
  return rows.value.filter((i) => i.status === status).length
}

async function load() {
  await incidents.list({ ordering: '-occurred_at' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(i) {
  drawer.value = true
  detail.value = i
  try {
    const { data } = await $api.get(`/ohs/incidents/${i.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  createError.value = ''
  Object.assign(form, {
    title: '', site: siteOptions.value[0]?.value || null, incident_type: 'injury',
    severity: 'minor', location: '', person_involved: '', department: '',
    description: '', immediate_action: '', lost_days: 0, is_lost_time: false,
    is_recordable: false, occurred_at: new Date().toISOString().slice(0, 16),
  })
  createDialog.value = true
}

async function saveIncident() {
  createError.value = ''
  try {
    const payload = { ...form }
    if (!payload.lost_days) payload.lost_days = 0
    await incidents.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Incident reported.' }
    await load()
  } catch (e) {
    createError.value = incidents.message(e)
  }
}

async function saveCapa() {
  if (!detail.value) return
  savingCapa.value = true
  try {
    const payload = { incident: detail.value.id, ...capaForm }
    if (!payload.due_date) delete payload.due_date
    await $api.post(`/ohs/incidents/${detail.value.id}/add_action/`, payload)
    capaDialog.value = false
    Object.assign(capaForm, { action_type: 'corrective', description: '', owner_name: '', due_date: '' })
    snack.value = { show: true, color: 'success', text: 'Corrective action added.' }
    await openDetail(detail.value)
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: incidents.message(e) }
  } finally {
    savingCapa.value = false
  }
}

async function closeIncident() {
  if (!detail.value) return
  try {
    const { data } = await $api.post(`/ohs/incidents/${detail.value.id}/close/`)
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Incident closed.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: incidents.message(e) }
  }
}

function exportLog() {
  exportCsv(
    `incident_log_${new Date().toISOString().slice(0, 10)}.csv`,
    filtered.value,
    [
      { key: 'reference', label: 'Reference' },
      { key: 'title', label: 'Incident' },
      { key: 'site_name', label: 'Site' },
      { key: 'incident_type_display', label: 'Type' },
      { key: 'severity_display', label: 'Severity' },
      { key: 'occurred_at', label: 'Occurred' },
      { key: 'person_involved', label: 'Person' },
      { key: 'is_lost_time', label: 'LTI' },
      { key: 'is_recordable', label: 'Recordable' },
      { key: 'lost_days', label: 'Lost days' },
      { key: 'open_actions', label: 'Open CAPA' },
      { key: 'status_display', label: 'Status' },
      { key: 'days_open', label: 'Days open' },
    ],
  )
}

watch([siteFilter, typeFilter, severityFilter], load)
onMounted(load)
</script>

<style scoped>
.drawer-head { padding: 16px; color: #fff; background: var(--brand-gradient); }
.glass-chip {
  display: inline-flex; align-items: center; padding: 2px 9px; border-radius: 999px;
  font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .3px;
  background: rgba(255, 255, 255, 0.16); border: 1px solid rgba(255, 255, 255, 0.3); color: #fff;
}
.meta { display: flex; flex-direction: column; gap: 1px; }
.meta span { font-size: 10.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase; color: rgba(var(--v-theme-on-surface), .5); }
.meta b { font-size: 12.5px; font-weight: 600; }
.section-title {
  font-size: 11px; font-weight: 800; letter-spacing: .6px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55);
  margin: 16px 0 4px;
}
.capa-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 10px;
  padding: 9px 11px;
  margin-bottom: 7px;
}
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
