<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-file-document-check-outline"
      eyebrow="OHSMS · Permit to work"
      title="Permit to Work Control"
      subtitle="Hot work, confined space, work at height and electrical isolation — authorised, time-boxed and closed out."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Raise permit
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.active }}</b> active</span>
      <span class="ohs-chip"><v-icon size="12">mdi-clock-outline</v-icon>
        <b>{{ stats.pending }}</b> pending approval</span>
      <span v-if="stats.expiring" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-timer-alert</v-icon>
        <b>{{ stats.expiring }}</b> expiring &lt; 24h</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Active permits" :value="stats.active" icon="mdi-file-document-check-outline" tone="ok"
              sub="authorised on site" />
      <OhsKpi label="Pending approval" :value="stats.pending" icon="mdi-account-clock-outline"
              :tone="stats.pending ? 'warn' : 'ok'" sub="awaiting approver" />
      <OhsKpi label="High-risk" :value="stats.high" icon="mdi-alert-octagon-outline"
              :tone="stats.high ? 'err' : 'ok'" sub="isolation / confined space" />
      <OhsKpi label="Closed this period" :value="stats.closed" icon="mdi-archive-check-outline" tone="info"
              sub="with closure note" />
      <OhsKpi label="Expired" :value="stats.expired" icon="mdi-timer-off-outline"
              :tone="stats.expired ? 'err' : 'ok'" sub="lapsed without closure" />
    </div>

    <OhsPanel title="Active & pending permits" subtitle="Live operational control" icon="mdi-file-document-multiple-outline">
      <div v-if="live.length" class="permit-grid">
        <div v-for="p in live" :key="p.id" class="permit-card" :class="`permit-card--${permitTone(p)}`">
          <div class="d-flex align-center justify-space-between" style="gap:8px">
            <span class="ohs-mono text-caption">{{ p.reference }}</span>
            <span class="ohs-badge" :class="`ohs-badge--${toneFor(p.status)}`">{{ p.status_display }}</span>
          </div>
          <div class="text-body-2 font-weight-bold mt-1">{{ p.title }}</div>
          <div class="text-caption text-medium-emphasis">{{ p.site_name }} · {{ p.area || '—' }}</div>
          <div class="permit-meta">
            <span><v-icon size="12">mdi-account-hard-hat</v-icon> {{ p.workers_count }} worker(s)</span>
            <span><v-icon size="12">mdi-clock-outline</v-icon> {{ formatDate(p.valid_to) }}</span>
          </div>
          <div class="d-flex align-center justify-space-between mt-2">
            <span class="ohs-badge ohs-badge--muted">{{ p.permit_type_display }}</span>
            <div class="d-flex" style="gap:4px">
              <v-btn v-if="p.status === 'pending'" size="x-small" variant="tonal" color="success" rounded="lg"
                     class="text-none" @click="setStatus(p, 'approved')">Approve</v-btn>
              <v-btn v-else-if="['approved', 'active'].includes(p.status)" size="x-small" variant="tonal"
                     color="primary" rounded="lg" class="text-none" @click="setStatus(p, 'closed')">Close</v-btn>
            </div>
          </div>
        </div>
      </div>
      <div v-else class="ohs-empty">No live permits.</div>
    </OhsPanel>

    <OhsPanel class="mt-3" title="Permit register" :subtitle="`${filtered.length} shown`"
              icon="mdi-format-list-bulleted" flush>
      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search reference, title, requester…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:290px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:195px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  placeholder="All permit types" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:215px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="Any status" density="compact" variant="outlined" rounded="lg" hide-details
                  clearable style="max-width:165px" />
      </div>

      <div class="ohs-scroll" style="max-height:56vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:110px">Ref</th>
              <th>Permit</th>
              <th style="width:130px">Site / area</th>
              <th style="width:130px">Type</th>
              <th style="width:90px">Risk</th>
              <th style="width:150px">Valid window</th>
              <th style="width:120px">Issued by</th>
              <th style="width:105px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in filtered" :key="p.id" @click="openDetail(p)">
              <td class="ohs-mono">{{ p.reference }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:330px">{{ p.title }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ p.requested_by || '—' }} → {{ p.issued_by || 'unissued' }}
                </div>
              </td>
              <td>
                <div class="text-caption font-weight-medium">{{ p.site_name }}</div>
                <div class="text-caption text-medium-emphasis">{{ p.area || '—' }}</div>
              </td>
              <td class="text-caption">{{ p.permit_type_display }}</td>
              <td>
                <span class="ohs-badge" :class="`ohs-badge--${toneFor(p.risk_level)}`">{{ p.risk_level_display }}</span>
              </td>
              <td class="text-caption">
                {{ formatDate(p.valid_from) }} → {{ formatDate(p.valid_to) }}
              </td>
              <td class="text-caption">{{ p.issued_by || '—' }}</td>
              <td>
                <span class="ohs-badge" :class="p.is_expired ? 'ohs-badge--err' : `ohs-badge--${toneFor(p.status)}`">
                  {{ p.is_expired ? 'Expired' : p.status_display }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length" class="ohs-empty">No permits match these filters.</div>
      </div>
    </OhsPanel>

    <!-- Detail -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="520">
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
            <span class="glass-chip">{{ detail.permit_type_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span class="glass-chip">{{ detail.risk_level_display }} risk</span>
            <span v-if="detail.gas_test_required" class="ohs-badge ohs-badge--crit">Gas test</span>
          </div>
        </div>
        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6"><div class="meta"><span>Site</span><b>{{ detail.site_name }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Area</span><b>{{ detail.area || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Requested by</span><b>{{ detail.requested_by || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Issued by</span><b>{{ detail.issued_by || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Valid from</span><b>{{ formatDateTime(detail.valid_from) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Valid to</span><b>{{ formatDateTime(detail.valid_to) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Workers</span><b>{{ detail.workers_count }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Approved by</span><b>{{ detail.approved_by || '—' }}</b></div></v-col>
          </v-row>
          <div class="section-title">Precautions</div>
          <div class="text-body-2">{{ detail.precautions || '—' }}</div>
          <div class="section-title">PPE required</div>
          <div class="text-body-2">{{ detail.ppe_required || '—' }}</div>
          <div v-if="detail.isolations" class="section-title">Isolations</div>
          <div v-if="detail.isolations" class="text-body-2">{{ detail.isolations }}</div>
          <div v-if="detail.closure_note" class="section-title">Closure note</div>
          <div v-if="detail.closure_note" class="text-body-2">{{ detail.closure_note }}</div>
        </div>
        <div class="drawer-actions">
          <v-btn v-if="detail.status === 'pending'" variant="tonal" color="success" rounded="lg"
                 class="text-none" @click="setStatus(detail, 'approved')">Approve</v-btn>
          <v-btn v-else-if="['approved', 'active'].includes(detail.status)" variant="tonal" color="primary"
                 rounded="lg" class="text-none" @click="setStatus(detail, 'closed')">Close permit</v-btn>
          <v-spacer />
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- Create -->
    <v-dialog v-model="createDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-file-document-plus-outline" title="Raise a permit"
                           subtitle="Define the window, precautions and isolations before work starts." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Permit title" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.risk_level" :items="riskLevels" item-title="label" item-value="value"
                        label="Risk" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.permit_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Permit type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.area" label="Area" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.workers_count" type="number" min="1" label="Workers"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.valid_from" type="datetime-local" label="Valid from"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.valid_to" type="datetime-local" label="Valid to"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.requested_by" label="Requested by" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.issued_by" label="Issued by" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.precautions" label="Precautions" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="form.ppe_required" label="PPE required" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-checkbox v-model="form.gas_test_required" density="compact" hide-details
                          label="Gas test required before entry" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.title || !form.site" @click="save">Raise permit</v-btn>
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
useHead({ title: 'Permits to Work · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()

const items = ohs.resource('permits')
const lookups = ref({})
const search = ref('')
const siteFilter = ref(null)
const typeFilter = ref(null)
const statusFilter = ref(null)
const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', site: null, permit_type: 'general', risk_level: 'medium', area: '',
  workers_count: 1, valid_from: new Date().toISOString().slice(0, 16), valid_to: '',
  requested_by: '', issued_by: '', precautions: '', ppe_required: '', gas_test_required: false,
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const typeOptions = computed(() => lookups.value.permit_types || [])
const riskLevels = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
]
const statusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Active', value: 'active' },
  { label: 'Closed', value: 'closed' },
  { label: 'Expired', value: 'expired' },
]

const rows = computed(() => items.items.value || [])
const live = computed(() => rows.value.filter((p) => ['pending', 'approved', 'active'].includes(p.status)).slice(0, 9))

const filtered = computed(() => rows.value.filter((p) => {
  if (siteFilter.value && p.site !== siteFilter.value) return false
  if (typeFilter.value && p.permit_type !== typeFilter.value) return false
  if (statusFilter.value && p.status !== statusFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${p.reference} ${p.title} ${p.area} ${p.requested_by} ${p.issued_by} ${p.site_name}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const soon = Date.now() + 86400000
  return {
    active: all.filter((p) => ['approved', 'active'].includes(p.status)).length,
    pending: all.filter((p) => p.status === 'pending').length,
    high: all.filter((p) => p.risk_level === 'high' && ['approved', 'active'].includes(p.status)).length,
    closed: all.filter((p) => p.status === 'closed').length,
    expired: all.filter((p) => p.is_expired || p.status === 'expired').length,
    expiring: all.filter((p) => ['approved', 'active'].includes(p.status) && p.valid_to
      && new Date(p.valid_to).getTime() <= soon).length,
  }
})

function permitTone(p) {
  if (p.is_expired) return 'err'
  if (p.risk_level === 'high') return 'err'
  if (p.status === 'pending') return 'warn'
  return 'ok'
}

async function load() {
  await items.list({ ordering: '-valid_from' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(p) {
  drawer.value = true
  detail.value = p
  try {
    const { data } = await $api.get(`/ohs/permits/${p.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: '', site: siteOptions.value[0]?.value || null, permit_type: 'general',
    risk_level: 'medium', area: '', workers_count: 1,
    valid_from: new Date().toISOString().slice(0, 16), valid_to: '',
    requested_by: '', issued_by: '', precautions: '', ppe_required: '', gas_test_required: false,
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.valid_to) delete payload.valid_to
    await items.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Permit raised.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

async function setStatus(permit, status) {
  try {
    const { data } = await $api.post(`/ohs/permits/${permit.id}/set_status/`, { status })
    if (detail.value?.id === permit.id) detail.value = data
    snack.value = { show: true, color: 'success', text: `Permit ${status}.` }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: items.message(e) }
  }
}

function exportData() {
  exportCsv(`permits_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'title', label: 'Permit' },
    { key: 'site_name', label: 'Site' },
    { key: 'area', label: 'Area' },
    { key: 'permit_type_display', label: 'Type' },
    { key: 'risk_level_display', label: 'Risk' },
    { key: 'valid_from', label: 'Valid from' },
    { key: 'valid_to', label: 'Valid to' },
    { key: 'requested_by', label: 'Requested by' },
    { key: 'issued_by', label: 'Issued by' },
    { key: 'workers_count', label: 'Workers' },
    { key: 'status_display', label: 'Status' },
  ])
}

watch([siteFilter, typeFilter, statusFilter], load)
onMounted(load)
</script>

<style scoped>
.permit-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(252px, 1fr));
  gap: 10px;
}
.permit-card {
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-left-width: 3px;
  border-radius: 11px;
  padding: 10px 12px;
  background: rgb(var(--v-theme-surface));
  transition: box-shadow .16s ease;
}
.permit-card:hover { box-shadow: 0 8px 20px rgba(15, 23, 42, 0.08); }
.permit-card--ok { border-left-color: #16a34a; }
.permit-card--warn { border-left-color: #f59e0b; }
.permit-card--err { border-left-color: #dc2626; }
.permit-meta {
  display: flex; flex-wrap: wrap; gap: 10px; margin-top: 6px;
  font-size: 11px; color: rgba(var(--v-theme-on-surface), .6);
}
.permit-meta span { display: inline-flex; align-items: center; gap: 3px; }
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
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 4px;
}
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
