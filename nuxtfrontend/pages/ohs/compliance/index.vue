<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-gavel"
      eyebrow="OHSMS · Legal & compliance"
      title="Legal Register & Audits"
      subtitle="Every statutory and ISO 45001 obligation mapped to an owner, an evidence trail and a review cadence."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="tab === 'legal' ? openLegal() : openAudit()">
          {{ tab === 'legal' ? 'Add requirement' : 'Schedule audit' }}
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-format-list-checks</v-icon>
        <b>{{ legal.count.value }}</b> obligations</span>
      <span v-if="legalStats.nonCompliant" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-gavel</v-icon>
        <b>{{ legalStats.nonCompliant }}</b> non-compliant</span>
      <span v-if="legalStats.reviewDue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-calendar-alert</v-icon>
        <b>{{ legalStats.reviewDue }}</b> reviews due</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Compliance" :value="`${legalStats.compliance}%`" icon="mdi-shield-check-outline"
              :tone="legalStats.compliance >= 85 ? 'ok' : legalStats.compliance >= 65 ? 'warn' : 'err'"
              sub="compliant + half-credit partial" />
      <OhsKpi label="Compliant" :value="legalStats.compliant" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`of ${legal.count.value} obligations`" />
      <OhsKpi label="Partial" :value="legalStats.partial" icon="mdi-progress-wrench"
              :tone="legalStats.partial ? 'warn' : 'ok'" sub="gaps being closed" />
      <OhsKpi label="Non-compliant" :value="legalStats.nonCompliant" icon="mdi-gavel"
              :tone="legalStats.nonCompliant ? 'err' : 'ok'" sub="immediate action" />
      <OhsKpi label="Audit score" :value="`${auditStats.avg}%`" icon="mdi-clipboard-check-multiple-outline"
              :tone="auditStats.avg >= 85 ? 'ok' : 'warn'" :sub="`${audits.count.value} audits`" />
    </div>

    <v-tabs v-model="tab" color="primary" density="compact" class="mb-3">
      <v-tab value="legal" class="text-none">
        <v-icon start size="16">mdi-format-list-checks</v-icon> Legal register
      </v-tab>
      <v-tab value="audits" class="text-none">
        <v-icon start size="16">mdi-clipboard-check-multiple-outline</v-icon> Audits
      </v-tab>
    </v-tabs>

    <v-window v-model="tab">
      <!-- LEGAL -->
      <v-window-item value="legal">
        <OhsPanel title="Legal & other requirements" :subtitle="`${filteredLegal.length} shown`"
                  icon="mdi-format-list-checks" flush>
          <div class="ohs-toolbar">
            <v-text-field v-model="search" placeholder="Search obligation, standard, clause…"
                          prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                          hide-details single-line clearable style="max-width:300px" />
            <v-select v-model="standardFilter" :items="standardOptions" item-title="label" item-value="value"
                      placeholder="All standards" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:220px" />
            <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                      placeholder="Any status" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:190px" />
          </div>
          <div class="ohs-scroll" style="max-height:64vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th style="width:170px">Standard</th>
                  <th style="width:80px">Clause</th>
                  <th>Requirement</th>
                  <th style="width:130px">Applies to</th>
                  <th style="width:110px">Owner</th>
                  <th style="width:120px">Last assessed</th>
                  <th style="width:110px">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in filteredLegal" :key="r.id">
                  <td class="text-caption font-weight-medium">{{ r.standard || '—' }}</td>
                  <td class="ohs-mono">{{ r.clause || '—' }}</td>
                  <td>
                    <div class="font-weight-medium text-truncate" style="max-width:400px">{{ r.title }}</div>
                    <div v-if="r.gap_description" class="text-caption text-medium-emphasis text-truncate"
                         style="max-width:400px">{{ r.gap_description }}</div>
                  </td>
                  <td class="text-caption">{{ r.applies_to || 'All sites' }}</td>
                  <td class="text-caption">{{ r.owner_name || '—' }}</td>
                  <td class="text-caption">{{ formatDate(r.last_assessed_on) }}</td>
                  <td>
                    <span class="ohs-badge" :class="`ohs-badge--${toneFor(r.compliance_status)}`">
                      {{ r.compliance_status_display }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!filteredLegal.length" class="ohs-empty">No obligations match these filters.</div>
          </div>
        </OhsPanel>
      </v-window-item>

      <!-- AUDITS -->
      <v-window-item value="audits">
        <OhsPanel title="Audit programme" :subtitle="`${audits.items.value.length} audit(s)`"
                  icon="mdi-clipboard-check-multiple-outline" flush>
          <div class="ohs-scroll" style="max-height:64vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th style="width:110px">Ref</th>
                  <th>Audit</th>
                  <th style="width:150px">Standard</th>
                  <th style="width:120px">Type</th>
                  <th style="width:130px">Auditor</th>
                  <th style="width:110px">Scheduled</th>
                  <th style="width:80px" class="num">Score</th>
                  <th style="width:110px" class="num">Findings</th>
                  <th style="width:110px">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="a in audits.items.value" :key="a.id">
                  <td class="ohs-mono">{{ a.reference }}</td>
                  <td>
                    <div class="font-weight-medium text-truncate" style="max-width:320px">{{ a.title }}</div>
                    <div class="text-caption text-medium-emphasis">{{ a.site_name || 'All sites' }}</div>
                  </td>
                  <td class="text-caption">{{ a.standard || '—' }}</td>
                  <td class="text-caption">{{ a.audit_type_display }}</td>
                  <td class="text-caption">{{ a.auditor || '—' }}</td>
                  <td class="text-caption">{{ formatDate(a.scheduled_on) }}</td>
                  <td class="num font-weight-bold" :style="{ color: scoreColor(a.score) }">
                    {{ a.score ?? '—' }}
                  </td>
                  <td class="num text-caption">
                    <span class="text-error">{{ a.findings_major }} major</span> ·
                    {{ a.findings_minor }} minor
                  </td>
                  <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(a.status)}`">{{ a.status_display }}</span></td>
                </tr>
              </tbody>
            </table>
            <div v-if="!audits.items.value.length" class="ohs-empty">No audits scheduled.</div>
          </div>
        </OhsPanel>
      </v-window-item>
    </v-window>

    <!-- Add legal requirement -->
    <v-dialog v-model="legalDialog" max-width="640">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-gavel" title="Add a legal requirement"
                           subtitle="Map the obligation to an owner and evidence trail." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="legalForm.standard" label="Standard / Act" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="legalForm.clause" label="Clause" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="legalForm.title" label="Requirement" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="legalForm.compliance_status" :items="statusOptions" item-title="label"
                        item-value="value" label="Status" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="legalForm.owner_name" label="Owner" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="legalForm.gap_description" label="Gap / notes" rows="2"
                          variant="outlined" density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="legalDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="legal.saving.value"
                 :disabled="!legalForm.title" @click="saveLegal">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Schedule audit -->
    <v-dialog v-model="auditDialog" max-width="620">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-clipboard-plus-outline" title="Schedule an audit"
                           subtitle="Internal, external or certification body." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="auditForm.title" label="Audit title" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="auditForm.scheduled_on" type="date" label="Date" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="auditForm.audit_type" :items="auditTypes" item-title="label" item-value="value"
                        label="Type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="auditForm.standard" label="Standard" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="auditForm.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="auditForm.auditor" label="Auditor" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="auditDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="audits.saving.value"
                 :disabled="!auditForm.title" @click="saveAudit">Schedule</v-btn>
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
useHead({ title: 'Compliance · OHSMS' })

const ohs = useOhs()

const legal = ohs.resource('legal')
const audits = ohs.resource('audits')
const lookups = ref({})
const tab = ref('legal')
const search = ref('')
const standardFilter = ref(null)
const statusFilter = ref(null)
const legalDialog = ref(false)
const auditDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const legalForm = reactive({
  standard: '', clause: '', title: '', compliance_status: 'not_assessed',
  owner_name: '', gap_description: '',
})
const auditForm = reactive({
  title: '', scheduled_on: new Date().toISOString().slice(0, 10), audit_type: 'internal',
  standard: 'ISO 45001:2018', site: null, auditor: '',
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const statusOptions = computed(() => lookups.value.legal_status || [
  { value: 'compliant', label: 'Compliant' },
  { value: 'partial', label: 'Partially compliant' },
  { value: 'non_compliant', label: 'Non-compliant' },
  { value: 'not_assessed', label: 'Not assessed' },
])
const auditTypes = computed(() => lookups.value.audit_types || [
  { value: 'internal', label: 'Internal' },
  { value: 'external', label: 'External' },
  { value: 'certification', label: 'Certification' },
  { value: 'supplier', label: 'Supplier' },
])
const standardOptions = computed(() => (legal.items.value || [])
  .map((l) => ({ label: l.standard || 'Unspecified', value: l.standard }))
  .filter((v, i, arr) => arr.findIndex((x) => x.value === v.value) === i))

const filteredLegal = computed(() => (legal.items.value || []).filter((r) => {
  if (standardFilter.value && r.standard !== standardFilter.value) return false
  if (statusFilter.value && r.compliance_status !== statusFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q && !`${r.standard} ${r.clause} ${r.title} ${r.owner_name}`.toLowerCase().includes(q)) return false
  return true
}))

const legalStats = computed(() => {
  const all = legal.items.value || []
  const count = (s) => all.filter((r) => r.compliance_status === s).length
  const compliant = count('compliant')
  const partial = count('partial')
  const total = all.length || 1
  const today = new Date().toISOString().slice(0, 10)
  return {
    compliant,
    partial,
    nonCompliant: count('non_compliant'),
    compliance: Math.round(((compliant + partial * 0.5) / total) * 100),
    reviewDue: all.filter((r) => r.next_review_on && r.next_review_on <= today).length,
  }
})

const auditStats = computed(() => {
  const scored = (audits.items.value || []).filter((a) => a.score !== null && a.score !== undefined)
  return {
    avg: scored.length ? Math.round(scored.reduce((s, a) => s + a.score, 0) / scored.length) : 0,
  }
})

function scoreColor(s) {
  if (s === null || s === undefined) return 'rgba(var(--v-theme-on-surface), .4)'
  if (s >= 85) return '#16a34a'
  if (s >= 70) return '#f59e0b'
  return '#dc2626'
}

async function load() {
  await Promise.all([
    legal.list({ ordering: 'standard,clause' }),
    audits.list({ ordering: '-scheduled_on' }),
  ])
  lookups.value = await ohs.loadLookups()
}

function openLegal() {
  error.value = ''
  Object.assign(legalForm, {
    standard: '', clause: '', title: '', compliance_status: 'not_assessed',
    owner_name: '', gap_description: '',
  })
  legalDialog.value = true
}

async function saveLegal() {
  error.value = ''
  try {
    await legal.create({ ...legalForm })
    legalDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Requirement added.' }
    await load()
  } catch (e) {
    error.value = legal.message(e)
  }
}

function openAudit() {
  error.value = ''
  Object.assign(auditForm, {
    title: '', scheduled_on: new Date().toISOString().slice(0, 10), audit_type: 'internal',
    standard: 'ISO 45001:2018', site: null, auditor: '',
  })
  auditDialog.value = true
}

async function saveAudit() {
  error.value = ''
  try {
    const payload = { ...auditForm }
    if (!payload.site) delete payload.site
    await audits.create(payload)
    auditDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Audit scheduled.' }
    tab.value = 'audits'
    await load()
  } catch (e) {
    error.value = audits.message(e)
  }
}

function exportData() {
  const date = new Date().toISOString().slice(0, 10)
  if (tab.value === 'legal') {
    exportCsv(`legal_register_${date}.csv`, filteredLegal.value, [
      { key: 'standard', label: 'Standard' },
      { key: 'clause', label: 'Clause' },
      { key: 'title', label: 'Requirement' },
      { key: 'compliance_status_display', label: 'Status' },
      { key: 'owner_name', label: 'Owner' },
      { key: 'applies_to', label: 'Applies to' },
      { key: 'last_assessed_on', label: 'Last assessed' },
      { key: 'next_review_on', label: 'Next review' },
      { key: 'gap_description', label: 'Gap' },
    ])
  } else {
    exportCsv(`audits_${date}.csv`, audits.items.value, [
      { key: 'reference', label: 'Reference' },
      { key: 'title', label: 'Audit' },
      { key: 'standard', label: 'Standard' },
      { key: 'audit_type_display', label: 'Type' },
      { key: 'auditor', label: 'Auditor' },
      { key: 'scheduled_on', label: 'Scheduled' },
      { key: 'completed_on', label: 'Completed' },
      { key: 'score', label: 'Score' },
      { key: 'findings_major', label: 'Major findings' },
      { key: 'findings_minor', label: 'Minor findings' },
      { key: 'status_display', label: 'Status' },
    ])
  }
}

watch([standardFilter, statusFilter], load)
onMounted(load)
</script>
