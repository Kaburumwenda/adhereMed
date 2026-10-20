<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-account-hard-hat"
      eyebrow="OHSMS · Contractor control"
      title="Contractor Safety Management"
      subtitle="Pre-qualification, document currency, induction validity and live site engagements for every contractor on your sites."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">Add contractor</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-account-hard-hat</v-icon>
        <b>{{ contractors.count.value }}</b> contractors</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.approved }}</b> approved</span>
      <span v-if="stats.expired" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-file-alert</v-icon>
        <b>{{ stats.expired }}</b> with expired documents</span>
      <span v-if="stats.active" class="ohs-chip">
        <v-icon size="12">mdi-hard-hat</v-icon>
        <b>{{ stats.active }}</b> on site
      </span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Approved" :value="stats.approved" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`of ${contractors.count.value} contractors`" />
      <OhsKpi label="Active engagements" :value="stats.active" icon="mdi-hard-hat" tone="primary"
              :sub="`${stats.workers} workers on site`" />
      <OhsKpi label="Expired documents" :value="stats.expired" icon="mdi-file-alert"
              :tone="stats.expired ? 'err' : 'ok'" sub="suspend site access" />
      <OhsKpi label="Expiring ≤ 30d" :value="stats.expiring" icon="mdi-file-clock"
              :tone="stats.expiring ? 'warn' : 'ok'" sub="renew before expiry" />
      <OhsKpi label="Avg performance" :value="stats.avgScore" icon="mdi-trophy-outline"
              :tone="stats.avgScore >= 80 ? 'ok' : 'warn'" sub="safety scorecard" />
    </div>

    <OhsPanel title="Contractor register" :subtitle="`${filtered.length} shown`"
              icon="mdi-account-hard-hat" flush>
      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search name, registration, contact…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:260px" />
        <v-select v-model="tradeFilter" :items="tradeOptions" item-title="label" item-value="value"
                  placeholder="All trades" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="Any status" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
        <v-spacer />
        <v-btn-toggle v-model="view" mandatory density="compact" variant="outlined" rounded="lg" divided>
          <v-btn value="table" size="small" icon="mdi-format-list-bulleted" />
          <v-btn value="cards" size="small" icon="mdi-view-grid-outline" />
        </v-btn-toggle>
      </div>

      <v-progress-linear v-if="contractors.loading.value" indeterminate color="primary" height="2" />

      <!-- TABLE -->
      <div v-if="view === 'table'" class="ohs-scroll" style="max-height:60vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th>Contractor</th>
              <th style="width:128px">Trade</th>
              <th style="width:96px">Risk</th>
              <th style="width:150px">Documents</th>
              <th style="width:120px">Insurance</th>
              <th style="width:120px">Safety file</th>
              <th style="width:110px">Induction</th>
              <th style="width:80px" class="num">Score</th>
              <th style="width:105px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in filtered" :key="c.id" @click="openDetail(c)">
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:270px">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ c.contact_person || '—' }}<span v-if="c.phone"> · {{ c.phone }}</span>
                </div>
              </td>
              <td class="text-caption">{{ c.trade_display }}</td>
              <td>
                <span class="ohs-badge" :class="`ohs-badge--${riskTone(c.risk_rating)}`">
                  {{ c.risk_rating_display }}
                </span>
              </td>
              <td>
                <div class="doc-pips">
                  <span v-for="(pip, i) in docPips(c)" :key="i" class="doc-pip"
                        :class="`doc-pip--${pip}`" />
                </div>
                <div class="text-caption text-medium-emphasis">{{ c.compliance_pct }}% current</div>
              </td>
              <td>
                <span class="text-caption" :style="{ color: expiryColor(c.insurance_days) }">
                  {{ formatDate(c.insurance_expiry) }}
                </span>
              </td>
              <td>
                <span class="text-caption" :style="{ color: expiryColor(c.safety_file_days) }">
                  {{ formatDate(c.safety_file_expiry) }}
                </span>
              </td>
              <td>
                <span class="text-caption" :style="{ color: expiryColor(c.induction_days) }">
                  {{ formatDate(c.induction_valid_until) }}
                </span>
              </td>
              <td class="num font-weight-bold" :style="{ color: pctColor(c.performance_score) }">
                {{ c.performance_score ?? '—' }}
              </td>
              <td><span class="ohs-badge" :class="`ohs-badge--${toneFor(c.status)}`">{{ c.status_display }}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !contractors.loading.value" class="ohs-empty">
          No contractors match these filters.
        </div>
      </div>

      <!-- CARDS -->
      <div v-else class="contractor-grid">
        <div v-for="c in filtered" :key="c.id" class="contractor-card" @click="openDetail(c)">
          <div class="d-flex align-center justify-space-between" style="gap:8px">
            <div class="d-flex align-center" style="gap:9px">
              <span class="avatar-sm" :style="avatarStyle(c.name)">{{ initialsOf(c.name) }}</span>
              <div>
                <div class="text-body-2 font-weight-bold" style="line-height:1.2">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ c.trade_display }}</div>
              </div>
            </div>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(c.status)}`">{{ c.status_display }}</span>
          </div>

          <div class="d-flex align-center justify-space-between mt-3">
            <div>
              <div class="cc-label">Compliance</div>
              <div class="cc-value" :style="{ color: pctColor(c.compliance_pct) }">{{ c.compliance_pct }}%</div>
            </div>
            <div class="text-right">
              <div class="cc-label">Performance</div>
              <div class="cc-value" :style="{ color: pctColor(c.performance_score) }">
                {{ c.performance_score ?? '—' }}
              </div>
            </div>
          </div>
          <div class="ohs-meter mt-1" :style="{ color: pctColor(c.compliance_pct) }">
            <div class="ohs-meter-fill" :style="{ width: c.compliance_pct + '%' }" />
          </div>

          <div class="d-flex flex-wrap mt-2" style="gap:4px">
            <span v-if="c.expired_documents" class="mini-chip mini-chip--err">
              {{ c.expired_documents }} expired
            </span>
            <span v-if="c.expiring_documents" class="mini-chip mini-chip--warn">
              {{ c.expiring_documents }} expiring
            </span>
            <span v-if="c.active_engagements" class="mini-chip mini-chip--info">
              {{ c.active_engagements }} on site
            </span>
            <span class="mini-chip">{{ c.workers_count }} workers</span>
            <span class="mini-chip mini-chip--risk">{{ c.risk_rating_display }} risk</span>
          </div>
        </div>
        <div v-if="!filtered.length" class="ohs-empty">No contractors match these filters.</div>
      </div>
    </OhsPanel>

    <!-- ═════ DETAIL DRAWER ═════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="600">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color:rgba(255,255,255,.8)">
                {{ detail.registration_no || 'No registration' }}
              </div>
              <div class="text-h6 font-weight-bold" style="line-height:1.25">{{ detail.name }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="glass-chip">{{ detail.trade_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span class="glass-chip">{{ detail.risk_rating_display }} risk</span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <div class="compliance-grid">
            <div v-for="doc in documentChecks" :key="doc.label" class="cgrid-item"
                 :class="`cgrid-item--${doc.state}`">
              <v-icon size="15">{{ doc.icon }}</v-icon>
              <div class="flex-grow-1">
                <div class="text-caption font-weight-bold">{{ doc.label }}</div>
                <div class="text-caption">{{ doc.value }}</div>
              </div>
            </div>
          </div>

          <v-row dense class="mt-1">
            <v-col cols="6"><div class="meta"><span>Contact</span><b>{{ detail.contact_person || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Phone</span><b>{{ detail.phone || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Email</span><b>{{ detail.email || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Prequalified</span><b>{{ formatDate(detail.prequalified_on) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Workers</span><b>{{ detail.workers_count }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Incidents attributed</span><b>{{ detail.incidents_attributed }}</b></div></v-col>
          </v-row>

          <div v-if="detail.notes" class="text-body-2 mt-2">{{ detail.notes }}</div>

          <div class="section-title">Site engagements</div>
          <div v-for="e in detail.engagements" :key="e.id" class="engagement-row">
            <div class="flex-grow-1" style="min-width:0">
              <div class="text-body-2 font-weight-medium">{{ e.scope || 'General works' }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ e.site_name }} · {{ formatDate(e.start_date) }} → {{ formatDate(e.end_date) }}
              </div>
              <div class="d-flex flex-wrap mt-1" style="gap:4px">
                <span class="mini-chip">{{ e.workers_on_site }} workers</span>
                <span class="mini-chip" :class="{ 'mini-chip--ok': e.induction_completed, 'mini-chip--err': !e.induction_completed }">
                  {{ e.induction_completed ? 'Inducted' : 'No induction' }}
                </span>
                <span v-if="e.permit_required" class="mini-chip mini-chip--warn">Permit</span>
                <span v-if="e.ppe_provided" class="mini-chip mini-chip--ok">PPE</span>
              </div>
            </div>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(e.status)}`">{{ e.status_display }}</span>
          </div>
          <div v-if="!detail.engagements?.length" class="text-caption text-medium-emphasis">
            No engagements recorded.
          </div>
        </div>

        <div class="drawer-actions">
          <v-btn v-if="detail.status === 'pending'" variant="tonal" color="success" rounded="lg"
                 class="text-none" @click="setStatus(detail, 'approved')">Approve</v-btn>
          <v-btn v-else-if="detail.status === 'approved'" variant="tonal" color="warning" rounded="lg"
                 class="text-none" @click="setStatus(detail, 'suspended')">Suspend</v-btn>
          <v-btn v-else variant="tonal" color="success" rounded="lg" class="text-none"
                 @click="setStatus(detail, 'approved')">Reinstate</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═════ CREATE ═════ -->
    <v-dialog v-model="createDialog" max-width="700" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-hard-hat" title="Add a contractor"
                           subtitle="Capture pre-qualification and every compliance document expiry." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.name" label="Contractor name" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.registration_no" label="Registration no." variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.trade" :items="tradeOptions" item-title="label" item-value="value"
                        label="Trade" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.risk_rating" :items="riskOptions" item-title="label" item-value="value"
                        label="Risk rating" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.workers_count" type="number" min="0" label="Workers"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.contact_person" label="Contact person" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.email" label="Email" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.insurance_expiry" type="date" label="Insurance expiry"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.safety_file_expiry" type="date" label="Safety file expiry"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.induction_valid_until" type="date" label="Induction valid until"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.licence_expiry" type="date" label="Licence expiry"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="contractors.saving.value"
                 :disabled="!form.name" @click="save">Add contractor</v-btn>
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
useHead({ title: 'Contractors · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const contractors = ohs.resource('contractors')
const lookups = ref({})
const search = ref('')
const tradeFilter = ref(null)
const statusFilter = ref(null)
const view = ref('table')
const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  name: '', registration_no: '', trade: 'other', risk_rating: 'medium', workers_count: 0,
  contact_person: '', phone: '', email: '', insurance_expiry: '',
  safety_file_expiry: '', induction_valid_until: '', licence_expiry: '',
})

const tradeOptions = computed(() => lookups.value.trades || [])
const statusOptions = computed(() => lookups.value.contractor_status || [])
const riskOptions = computed(() => lookups.value.risk_ratings || [])

const rows = computed(() => contractors.items.value || [])

const filtered = computed(() => rows.value.filter((c) => {
  if (tradeFilter.value && c.trade !== tradeFilter.value) return false
  if (statusFilter.value && c.status !== statusFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${c.name} ${c.registration_no} ${c.contact_person} ${c.email} ${c.phone}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const scored = all.filter((c) => c.performance_score !== null && c.performance_score !== undefined)
  return {
    approved: all.filter((c) => c.status === 'approved').length,
    expired: all.filter((c) => c.expired_documents).length,
    expiring: all.filter((c) => c.expiring_documents).length,
    active: all.reduce((s, c) => s + (c.active_engagements || 0), 0),
    workers: all.reduce((s, c) => s + (c.workers_count || 0), 0),
    avgScore: scored.length
      ? Math.round(scored.reduce((s, c) => s + c.performance_score, 0) / scored.length) : 0,
  }
})

const documentChecks = computed(() => {
  const c = detail.value
  if (!c) return []
  const mk = (label, date) => {
    if (!date) return { label, value: 'Not recorded', state: 'err', icon: 'mdi-close-circle' }
    const days = Math.round((new Date(date) - new Date()) / 86400000)
    if (days < 0) return { label, value: `Expired ${Math.abs(days)}d ago`, state: 'err', icon: 'mdi-close-circle' }
    if (days <= 30) return { label, value: `Expires in ${days}d`, state: 'warn', icon: 'mdi-alert-circle' }
    return { label, value: `Valid to ${formatDate(date)}`, state: 'ok', icon: 'mdi-check-circle' }
  }
  return [
    mk('Insurance', c.insurance_expiry),
    mk('Safety file', c.safety_file_expiry),
    mk('Induction', c.induction_valid_until),
    mk('Licence', c.licence_expiry),
  ]
})

function docPips(c) {
  const checks = [c.insurance_days, c.safety_file_days, c.induction_days, c.licence_days]
  return checks.map((d) => {
    if (d === null || d === undefined) return 'err'
    if (d < 0) return 'err'
    if (d <= 30) return 'warn'
    return 'ok'
  })
}
function riskTone(r) {
  return { low: 'ok', medium: 'info', high: 'err' }[r] || 'muted'
}
function expiryColor(days) {
  if (days === null || days === undefined) return 'rgba(var(--v-theme-on-surface),.45)'
  if (days < 0) return '#dc2626'
  if (days <= 30) return '#b45309'
  return 'inherit'
}
function pctColor(v) {
  if (v === null || v === undefined) return 'rgba(var(--v-theme-on-surface),.4)'
  const n = Number(v)
  if (n >= 80) return '#16a34a'
  if (n >= 60) return '#f59e0b'
  return '#dc2626'
}
function avatarStyle(name) {
  const hue = hueOf(name)
  return { background: `hsl(${hue} 62% 92%)`, color: `hsl(${hue} 55% 32%)` }
}

async function load() {
  await contractors.list({ ordering: 'name' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(c) {
  drawer.value = true
  detail.value = c
  try {
    const { data } = await $api.get(`/ohs/contractors/${c.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    name: '', registration_no: '', trade: 'other', risk_rating: 'medium', workers_count: 0,
    contact_person: '', phone: '', email: '', insurance_expiry: '',
    safety_file_expiry: '', induction_valid_until: '', licence_expiry: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    for (const key of ['insurance_expiry', 'safety_file_expiry',
                       'induction_valid_until', 'licence_expiry']) {
      if (!payload[key]) delete payload[key]
    }
    await contractors.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Contractor added.' }
    await load()
  } catch (e) {
    error.value = contractors.message(e)
  }
}

async function setStatus(contractor, status) {
  try {
    const { data } = await $api.patch(`/ohs/contractors/${contractor.id}/`, { status })
    if (detail.value?.id === contractor.id) detail.value = data
    snack.value = { show: true, color: 'success', text: `Contractor ${status}.` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: contractors.message(e) }
  }
}

function exportData() {
  exportCsv(`contractors_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'name', label: 'Contractor' },
    { key: 'registration_no', label: 'Registration' },
    { key: 'trade_display', label: 'Trade' },
    { key: 'risk_rating_display', label: 'Risk' },
    { key: 'status_display', label: 'Status' },
    { key: 'contact_person', label: 'Contact' },
    { key: 'phone', label: 'Phone' },
    { key: 'insurance_expiry', label: 'Insurance expiry' },
    { key: 'safety_file_expiry', label: 'Safety file expiry' },
    { key: 'induction_valid_until', label: 'Induction' },
    { key: 'compliance_pct', label: 'Compliance %' },
    { key: 'performance_score', label: 'Performance' },
    { key: 'active_engagements', label: 'On site' },
  ])
}

watch([tradeFilter, statusFilter], load)
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
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 8px;
}

.doc-pips { display: flex; gap: 3px; margin-bottom: 2px; }
.doc-pip { width: 14px; height: 5px; border-radius: 999px; }
.doc-pip--ok { background: #16a34a; }
.doc-pip--warn { background: #f59e0b; }
.doc-pip--err { background: #dc2626; }

.contractor-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(266px, 1fr));
  gap: 10px;
  padding: 12px;
}
.contractor-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 12px;
  padding: 12px;
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: transform .15s ease, box-shadow .15s ease;
}
.contractor-card:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(15,23,42,.08); }
.cc-label {
  font-size: 9.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px;
  color: rgba(var(--v-theme-on-surface), .5);
}
.cc-value { font-size: 19px; font-weight: 800; line-height: 1.2; }
.avatar-sm {
  width: 30px; height: 30px; border-radius: 9px;
  display: inline-flex; align-items: center; justify-content: center;
  font-size: 11px; font-weight: 800; flex-shrink: 0;
}
.mini-chip {
  font-size: 10px; font-weight: 600; padding: 1px 7px; border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), .62); background: rgba(15, 23, 42, 0.05);
}
.mini-chip--ok { color: #15803d; background: rgba(34, 197, 94, .13); }
.mini-chip--warn { color: #b45309; background: rgba(245, 158, 11, .14); }
.mini-chip--err { color: #b91c1c; background: rgba(239, 68, 68, .12); }
.mini-chip--info { color: #0369a1; background: rgba(14, 165, 233, .12); }
.mini-chip--risk { color: #6b21a8; background: rgba(147, 51, 234, .12); }

.compliance-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; }
.cgrid-item {
  display: flex; align-items: flex-start; gap: 8px;
  padding: 8px 10px; border-radius: 10px; border: 1px solid transparent;
}
.cgrid-item--ok { background: rgba(34, 197, 94, .07); border-color: rgba(34, 197, 94, .2); color: #15803d; }
.cgrid-item--warn { background: rgba(245, 158, 11, .09); border-color: rgba(245, 158, 11, .25); color: #b45309; }
.cgrid-item--err { background: rgba(239, 68, 68, .08); border-color: rgba(239, 68, 68, .22); color: #b91c1c; }

.engagement-row {
  display: flex; align-items: center; gap: 10px;
  padding: 9px 11px; margin-bottom: 6px;
  border: 1px solid rgba(15, 23, 42, 0.08); border-radius: 10px;
}
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
