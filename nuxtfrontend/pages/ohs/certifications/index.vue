<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-certificate-outline"
      eyebrow="OHSMS · Licences & certifications"
      title="Certifications & Licences"
      subtitle="ISO certifications, statutory approvals, equipment inspections, personnel credentials and insurance cover — all tracked to expiry."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">Add certificate</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-certificate</v-icon>
        <b>{{ items.count.value }}</b> certificates</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-decagram</v-icon>
        <b>{{ stats.active }}</b> valid</span>
      <span v-if="stats.expired" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-alert-octagon</v-icon>
        <b>{{ stats.expired }}</b> expired</span>
      <span v-if="stats.expiring" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-timer-alert</v-icon>
        <b>{{ stats.expiring }}</b> expiring</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Valid" :value="stats.active" icon="mdi-check-decagram-outline" tone="ok"
              :sub="`of ${items.count.value} on register`" />
      <OhsKpi label="Expiring ≤ 60d" :value="stats.expiring" icon="mdi-timer-alert"
              :tone="stats.expiring ? 'warn' : 'ok'" sub="start renewal now" />
      <OhsKpi label="Expired" :value="stats.expired" icon="mdi-alert-octagon-outline"
              :tone="stats.expired ? 'err' : 'ok'" sub="non-compliant" />
      <OhsKpi label="Renewal cost" :value="compactMoney(stats.cost)" icon="mdi-cash-multiple" tone="info"
              sub="annualised estimate" />
      <OhsKpi label="Next expiry" :value="stats.nextLabel" icon="mdi-calendar-clock"
              :tone="stats.nextTone" :sub="stats.nextName" />
    </div>

    <OhsPanel title="Certification register" :subtitle="`${filtered.length} shown`"
              icon="mdi-certificate-outline" flush>
      <template #actions>
        <v-chip-group v-model="statusFilter" mandatory selected-class="text-primary">
          <v-chip v-for="f in statusFilters" :key="f.value" :value="f.value" size="small" variant="tonal"
                  :color="f.color">{{ f.label }}</v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search name, reference, issuer…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:260px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  placeholder="All types" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
      </div>

      <v-progress-linear v-if="items.loading.value" indeterminate color="primary" height="2" />

      <div class="ohs-scroll" style="max-height:62vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th>Certificate</th>
              <th style="width:130px">Type</th>
              <th style="width:90px" class="num">Ref</th>
              <th style="width:170px">Issuing body</th>
              <th style="width:130px">Site / holder</th>
              <th style="width:110px">Issued</th>
              <th style="width:110px">Expires</th>
              <th style="width:130px">Days left</th>
              <th style="width:105px">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in filtered" :key="c.id">
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:270px">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ c.notes || '—' }}</div>
              </td>
              <td class="text-caption">{{ c.cert_type_display }}</td>
              <td class="ohs-mono">{{ c.reference_no || '—' }}</td>
              <td class="text-caption">{{ c.issuing_body || '—' }}</td>
              <td>
                <div class="text-caption">{{ c.site_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ c.holder_name || '' }}</div>
              </td>
              <td class="text-caption">{{ formatDate(c.issued_on) }}</td>
              <td class="text-caption">{{ formatDate(c.expires_on) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:6px">
                  <div class="ohs-meter" style="width:58px" :style="{ color: expiryBar(c.days_to_expiry) }">
                    <div class="ohs-meter-fill" :style="{ width: expiryPct(c) + '%' }" />
                  </div>
                  <span class="text-caption" :style="{ color: expiryText(c.days_to_expiry) }">
                    {{ c.days_to_expiry === null ? '—' : c.days_to_expiry < 0
                      ? `${Math.abs(c.days_to_expiry)}d ago` : `${c.days_to_expiry}d` }}
                  </span>
                </div>
              </td>
              <td>
                <span class="ohs-badge" :class="certBadge(c)">{{ certLabel(c) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !items.loading.value" class="ohs-empty">
          No certificates match these filters.
        </div>
      </div>
    </OhsPanel>

    <v-dialog v-model="createDialog" max-width="680" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-certificate-plus" title="Add a certificate"
                           subtitle="Renewal alerts fire before the expiry date." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.name" label="Certificate name" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-select v-model="form.cert_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.reference_no" label="Reference no." variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.issuing_body" label="Issuing body" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.holder_name" label="Holder" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.issued_on" type="date" label="Issued on" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.expires_on" type="date" label="Expires on" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.renewal_lead_days" type="number" min="0"
                            label="Alert days before" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="items.saving.value"
                 :disabled="!form.name" @click="save">Add certificate</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Certifications · OHSMS' })

const ohs = useOhs()

const items = ohs.resource('certifications')
const lookups = ref({})
const search = ref('')
const typeFilter = ref(null)
const siteFilter = ref(null)
const statusFilter = ref('all')
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  name: '', cert_type: 'license', reference_no: '', issuing_body: '', holder_name: '',
  site: null, issued_on: '', expires_on: '', renewal_lead_days: 60, notes: '',
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const typeOptions = computed(() => lookups.value.cert_types || [])
const statusFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Valid', value: 'active', color: 'success' },
  { label: 'Expiring', value: 'expiring', color: 'warning' },
  { label: 'Expired', value: 'expired', color: 'error' },
]

const rows = computed(() => items.items.value || [])

const filtered = computed(() => rows.value.filter((c) => {
  if (statusFilter.value !== 'all' && c.status !== statusFilter.value) return false
  if (typeFilter.value && c.cert_type !== typeFilter.value) return false
  if (siteFilter.value && c.site !== siteFilter.value) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${c.name} ${c.reference_no} ${c.issuing_body} ${c.holder_name}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const upcoming = all
    .filter((c) => c.days_to_expiry !== null && c.days_to_expiry >= 0)
    .sort((a, b) => a.days_to_expiry - b.days_to_expiry)
  const next = upcoming[0]
  return {
    active: all.filter((c) => c.status === 'active').length,
    expiring: all.filter((c) => c.status === 'expiring').length,
    expired: all.filter((c) => c.status === 'expired').length,
    cost: all.reduce((s, c) => s + Number(c.cost || 0), 0),
    nextLabel: next ? `${next.days_to_expiry}d` : '—',
    nextName: next?.name || 'nothing upcoming',
    nextTone: next && next.days_to_expiry <= 30 ? 'warn' : 'ok',
  }
})

function compactMoney(v) {
  const n = Number(v || 0)
  if (!n) return 'KES 0'
  if (n >= 1e6) return `KES ${(n / 1e6).toFixed(1)}M`
  if (n >= 1e3) return `KES ${(n / 1e3).toFixed(0)}K`
  return `KES ${n.toFixed(0)}`
}
function expiryBar(days) {
  if (days === null || days === undefined) return '#94a3b8'
  if (days < 0) return '#dc2626'
  if (days <= 30) return '#dc2626'
  if (days <= 90) return '#f59e0b'
  return '#16a34a'
}
function expiryText(days) {
  if (days === null || days === undefined) return 'inherit'
  if (days < 0) return '#dc2626'
  if (days <= 30) return '#b45309'
  return 'inherit'
}
function expiryPct(c) {
  if (!c.expires_on || c.days_to_expiry === null) return 0
  const window = 365
  const left = Math.max(0, Math.min(c.days_to_expiry, window))
  return Math.round((left / window) * 100)
}
function certBadge(c) {
  if (c.status === 'expired' || c.is_expired) return 'ohs-badge--err'
  if (c.status === 'expiring' || c.is_expiring) return 'ohs-badge--warn'
  if (c.status === 'suspended') return 'ohs-badge--muted'
  if (c.status === 'pending') return 'ohs-badge--info'
  return 'ohs-badge--ok'
}
function certLabel(c) {
  if (c.status === 'expired' || c.is_expired) return 'Expired'
  if (c.status === 'expiring' || c.is_expiring) return 'Expiring'
  return c.status_display
}

async function load() {
  await items.list({ ordering: 'expires_on' })
  lookups.value = await ohs.loadLookups()
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    name: '', cert_type: 'license', reference_no: '', issuing_body: '', holder_name: '',
    site: null, issued_on: '', expires_on: '', renewal_lead_days: 60, notes: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    for (const key of ['issued_on', 'expires_on']) {
      if (!payload[key]) delete payload[key]
    }
    if (!payload.site) delete payload.site
    await items.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Certificate added.' }
    await load()
  } catch (e) {
    error.value = items.message(e)
  }
}

function exportData() {
  exportCsv(`certifications_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'name', label: 'Certificate' },
    { key: 'cert_type_display', label: 'Type' },
    { key: 'reference_no', label: 'Reference' },
    { key: 'issuing_body', label: 'Issuing body' },
    { key: 'holder_name', label: 'Holder' },
    { key: 'site_name', label: 'Site' },
    { key: 'issued_on', label: 'Issued' },
    { key: 'expires_on', label: 'Expires' },
    { key: 'days_to_expiry', label: 'Days left' },
    { key: 'status_display', label: 'Status' },
    { key: 'cost', label: 'Cost' },
  ])
}

watch([statusFilter, typeFilter, siteFilter], load)
onMounted(load)
</script>
