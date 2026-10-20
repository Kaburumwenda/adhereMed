<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-account-multiple-outline"
      eyebrow="IMS · CUSTOMER CRM · CUSTOMERS"
      title="Customers"
      subtitle="Search, segment and manage the full customer base — lifecycle, health, loyalty and credit in one table."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-glass" prepend-icon="mdi-file-delimited-outline" :loading="exporting" @click="exportCsv">
          Export
        </v-btn>
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-account-plus-outline" @click="openCreate">
          Add customer
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <!-- filter bar -->
    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search name, phone, email, company, tag…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable"
          variant="solo-filled"
          rounded="lg"
          flat
          bg-color="surface"
          hide-details
          clearable
          class="crm-search"
          @keyup.enter="load"
          @click:clear="load"
        />
        <v-select v-model="filters.lifecycle_stage" :items="lifecycleOptions" item-title="label" item-value="value" label="Lifecycle" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
        <v-select v-model="filters.tier" :items="tierOptions" item-title="label" item-value="value" label="Tier" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select-sm" @update:model-value="load" />
        <v-select v-model="filters.segment" :items="segments" item-title="name" item-value="id" label="Segment" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select-sm" @update:model-value="load" />
        <v-switch v-model="filters.vip" color="amber" density="compact" hide-details label="VIP only" @update:model-value="load" />
        <v-spacer />
        <v-btn variant="text" size="small" color="error" class="text-none" prepend-icon="mdi-filter-remove-outline" :disabled="!hasFilters" @click="clearFilters">Clear</v-btn>
      </div>
      <v-divider />
      <div class="d-flex flex-wrap align-center ga-2 pa-3">
        <v-chip-group :model-value="filters.lifecycle_stage || 'all'" selected-class="text-primary" mandatory class="crm-chips">
          <v-chip v-for="s in lifecycleChips" :key="s.value" :value="s.value" size="small" rounded="lg" variant="tonal" class="text-none" @click="setLifecycle(s.value)">
            <v-icon v-if="s.icon" start size="15">{{ s.icon }}</v-icon>
            {{ s.label }}
            <span class="ml-1 font-weight-bold">{{ s.count }}</span>
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ rows.length }} shown</span>
      </div>
    </v-card>

    <!-- table -->
    <v-card rounded="xl" border>
      <v-table density="comfortable" class="crm-table">
        <thead>
          <tr>
            <th>Customer</th>
            <th>Lifecycle</th>
            <th>Segment</th>
            <th>Tier</th>
            <th class="text-center">Health</th>
            <th class="text-center">Risk</th>
            <th class="text-right">Spend</th>
            <th class="text-right">Points</th>
            <th class="text-center">Cases</th>
            <th>Last contact</th>
            <th />
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in rows" :key="c.id" class="crm-row" @click="goCustomer(c.id)">
            <td>
              <div class="d-flex align-center ga-3">
                <v-avatar size="34" :color="avatarColor(c.name)" variant="flat" class="text-white font-weight-bold" style="font-size: 12px">
                  {{ initials(c.name) }}
                </v-avatar>
                <div>
                  <div class="d-flex align-center ga-1">
                    <span class="font-weight-medium">{{ c.name }}</span>
                    <v-icon v-if="c.is_vip" size="14" color="amber">mdi-crown-outline</v-icon>
                  </div>
                  <div class="text-caption text-medium-emphasis">{{ c.phone }}<span v-if="c.email"> · {{ c.email }}</span></div>
                </div>
              </div>
            </td>
            <td>
              <v-chip size="x-small" variant="tonal" :color="lifecycleMeta(c.lifecycle_stage).color" class="font-weight-medium">
                <v-icon start size="11">{{ lifecycleMeta(c.lifecycle_stage).icon }}</v-icon>
                {{ lifecycleMeta(c.lifecycle_stage).label }}
              </v-chip>
            </td>
            <td>
              <v-chip v-if="c.segment_name" size="x-small" variant="tonal" :style="{ color: c.segment_color, borderColor: c.segment_color }">
                {{ c.segment_name }}
              </v-chip>
              <span v-else class="text-caption text-medium-emphasis">—</span>
            </td>
            <td>
              <v-chip size="x-small" variant="tonal" :color="tierMeta(c.loyalty_tier).color">
                <v-icon start size="11">{{ tierMeta(c.loyalty_tier).icon }}</v-icon>{{ tierMeta(c.loyalty_tier).label }}
              </v-chip>
            </td>
            <td class="text-center">
              <div class="crm-score">
                <div class="crm-score-bar">
                  <div class="crm-score-fill" :style="{ width: (c.health_score || 0) + '%', background: healthHex(c.health_score) }" />
                </div>
                <span class="text-caption">{{ c.health_score }}</span>
              </div>
            </td>
            <td class="text-center">
              <v-chip size="x-small" variant="tonal" :color="riskColor(c.churn_risk)">{{ c.churn_risk }}%</v-chip>
            </td>
            <td class="text-right font-weight-medium">{{ formatMoney(c.total_purchases) }}</td>
            <td class="text-right">{{ (c.loyalty_points || 0).toLocaleString() }}</td>
            <td class="text-center">
              <v-badge v-if="c.open_tickets" :content="c.open_tickets" color="error" inline />
              <span v-else class="text-caption text-medium-emphasis">—</span>
            </td>
            <td>
              <span class="text-caption">{{ c.last_contact_at ? rel(c.last_contact_at) : 'Never' }}</span>
            </td>
            <td class="text-right">
              <v-btn icon="mdi-chevron-right" size="x-small" variant="text" />
            </td>
          </tr>
          <tr v-if="!rows.length">
            <td colspan="11">
              <div class="crm-empty pa-8">
                <v-icon size="44" color="medium-emphasis">mdi-account-multiple-outline</v-icon>
                <div class="text-body-1 font-weight-medium mt-2">No customers match your filters</div>
                <div class="text-caption text-medium-emphasis">Try clearing filters or add a new customer.</div>
                <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-account-plus-outline" @click="openCreate">Add customer</v-btn>
              </div>
            </td>
          </tr>
        </tbody>
      </v-table>
    </v-card>

    <!-- create / edit -->
    <v-dialog v-model="formDialog" max-width="820" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-account-plus-outline'"
          :title="editing ? `Edit ${form.name}` : 'Add customer'"
          subtitle="Identity, contact details and loyalty"
          @close="formDialog = false"
        />
        <v-card-text>
          <div class="text-subtitle-2 font-weight-bold mb-2">Identity</div>
          <v-row dense>
            <v-col cols="12" md="6"><v-text-field v-model="form.name" label="Full name *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.phone" label="Phone *" variant="outlined" density="comfortable" prepend-inner-icon="mdi-phone-outline" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="form.email" label="Email" variant="outlined" density="comfortable" prepend-inner-icon="mdi-email-outline" /></v-col>
            <v-col cols="12" md="6"><v-select v-model="form.branch" :items="branches" item-title="name" item-value="id" label="Branch" variant="outlined" density="comfortable" clearable /></v-col>
            <v-col cols="12"><v-textarea v-model="form.address" label="Address" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>

          <v-divider class="my-3" />
          <div class="text-subtitle-2 font-weight-bold mb-2">CRM profile</div>
          <v-row dense>
            <v-col cols="12" md="4">
              <v-select v-model="form.lifecycle_stage" :items="lifecycleOptions" item-title="label" item-value="value" label="Lifecycle stage" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.segment" :items="segments" item-title="name" item-value="id" label="Segment" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.preferred_channel" :items="channelOptions" item-title="label" item-value="value" label="Preferred channel" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.lead_source" :items="sourceOptions" item-title="label" item-value="value" label="Lead source" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.company" label="Company" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model="form.date_of_birth" type="date" label="Date of birth" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.credit_limit" type="number" step="0.01" label="Credit limit" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="form.payment_terms_days" type="number" label="Payment terms (days)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-switch v-model="form.is_vip" color="amber" density="compact" hide-details label="VIP customer" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveCustomer">Save customer</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import {
  avatarColor, healthColor, initials, lifecycleMeta, riskColor, tierMeta, useCrm,
} from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const route = useRoute()
const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const { customers, customerStats, segments: fetchSegments, ensureProfile, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const exporting = ref(false)
const rows = ref([])
const stats = ref({})
const segments = ref([])
const branches = ref([])
const search = ref('')
const filters = reactive({ lifecycle_stage: null, tier: null, segment: null, vip: false })
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const editing = ref(false)
const form = ref(blankForm())

const lifecycleOptions = [
  { value: 'lead', label: 'Lead' }, { value: 'prospect', label: 'Prospect' },
  { value: 'active', label: 'Active' }, { value: 'at_risk', label: 'At risk' },
  { value: 'dormant', label: 'Dormant' }, { value: 'churned', label: 'Churned' },
]
const tierOptions = [
  { value: 'bronze', label: 'Bronze' }, { value: 'silver', label: 'Silver' },
  { value: 'gold', label: 'Gold' }, { value: 'platinum', label: 'Platinum' },
]
const channelOptions = [
  { value: 'phone', label: 'Phone' }, { value: 'sms', label: 'SMS' },
  { value: 'email', label: 'Email' }, { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'in_person', label: 'In person' },
]
const sourceOptions = [
  { value: 'walk_in', label: 'Walk-in' }, { value: 'referral', label: 'Referral' },
  { value: 'website', label: 'Website' }, { value: 'social', label: 'Social media' },
  { value: 'campaign', label: 'Campaign' }, { value: 'partner', label: 'Partner' },
  { value: 'outbound', label: 'Outbound' }, { value: 'other', label: 'Other' },
]

const heroFacts = computed(() => [
  { value: stats.value.total_customers ?? 0, label: 'customers' },
  { value: stats.value.active ?? 0, label: 'active' },
  { value: stats.value.vip ?? 0, label: 'VIP' },
  { value: formatMoney(stats.value.lifetime_value || 0), label: 'lifetime value' },
])

const kpis = computed(() => [
  { title: 'Total', value: stats.value.total_customers ?? 0, sub: `${stats.value.new_30_days ?? 0} new (30d)`, icon: 'mdi-account-multiple-outline', color: 'primary' },
  { title: 'VIP', value: stats.value.vip ?? 0, sub: 'highest value', icon: 'mdi-crown-outline', color: 'amber' },
  { title: 'At risk', value: stats.value.at_risk ?? 0, sub: 'churn ≥ 60%', icon: 'mdi-account-alert-outline', color: 'error' },
  { title: 'Avg health', value: stats.value.avg_health ?? 0, sub: 'out of 100', icon: 'mdi-heart-pulse', color: 'success' },
  { title: 'Outstanding', value: formatMoney(stats.value.outstanding_balance || 0), sub: 'credit balance', icon: 'mdi-cash-clock', color: 'deep-purple' },
  { title: 'Open cases', value: stats.value.open_tickets ?? 0, sub: 'support tickets', icon: 'mdi-lifebuoy', color: 'info' },
])

const lifecycleChips = computed(() => {
  const by = stats.value.by_lifecycle || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0)
  const chips = [{ value: 'all', label: 'All', icon: 'mdi-view-grid-outline', count: total }]
  for (const key of ['lead', 'prospect', 'active', 'at_risk', 'dormant', 'churned']) {
    const meta = lifecycleMeta(key)
    chips.push({ value: key, label: meta.label, icon: meta.icon, count: by[key] || 0 })
  }
  return chips
})

const hasFilters = computed(() =>
  !!filters.lifecycle_stage || !!filters.tier || !!filters.segment || filters.vip || !!search.value)

function healthHex(score) {
  const n = Number(score) || 0
  if (n >= 75) return '#16a34a'
  if (n >= 50) return '#d97706'
  return '#dc2626'
}

function rel(v) {
  if (!v) return '—'
  const t = new Date(v).getTime()
  if (Number.isNaN(t)) return '—'
  const mins = Math.round(Math.abs(Date.now() - t) / 60000)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.round(hours / 24)}d ago`
}

function blankForm() {
  return {
    name: '', phone: '', email: '', address: '', branch: null,
    lifecycle_stage: 'active', segment: null, preferred_channel: 'phone',
    lead_source: 'walk_in', company: '', date_of_birth: '',
    credit_limit: 0, payment_terms_days: 0, is_vip: false, notes: '',
  }
}

function setLifecycle(v) {
  filters.lifecycle_stage = v === 'all' ? null : v
  load()
}

function clearFilters() {
  filters.lifecycle_stage = null
  filters.tier = null
  filters.segment = null
  filters.vip = false
  search.value = ''
  load()
}

function goCustomer(id) {
  navigateTo(`/ims/crm/customers/${id}`)
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: '-created_at' }
    if (search.value) params.search = search.value
    if (filters.lifecycle_stage) params.lifecycle_stage = filters.lifecycle_stage
    if (filters.tier) params.tier = filters.tier
    if (filters.segment) params.segment = filters.segment
    if (filters.vip) params.vip = 1
    const [list, st] = await Promise.all([customers(params), customerStats()])
    rows.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load customers' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const [seg, br] = await Promise.all([
      fetchSegments({ page_size: 200 }),
      $api.get(branchesApi.value, { params: { page_size: 200 } }),
    ])
    segments.value = unpack(seg)
    branches.value = unpack(br)
  } catch { /* optional */ }
}

function openCreate() {
  editing.value = false
  form.value = blankForm()
  formDialog.value = true
}

async function saveCustomer() {
  if (!form.value.name || !form.value.phone) {
    snack.value = { show: true, color: 'error', text: 'Name and phone are required' }
    return
  }
  saving.value = true
  try {
    const f = form.value
    const { data: created } = await $api.post('/pos/customers/', {
      name: f.name, phone: f.phone, email: f.email, address: f.address,
      branch: f.branch || null,
    })
    await ensureProfile(created.id)
    await $api.patch(`/crm/profiles/${(await $api.get(`/crm/profiles/?customer=${created.id}`)).data.results[0].id}/`, {
      lifecycle_stage: f.lifecycle_stage,
      segment: f.segment || null,
      preferred_channel: f.preferred_channel,
      lead_source: f.lead_source,
      company: f.company,
      date_of_birth: f.date_of_birth || null,
      credit_limit: Number(f.credit_limit) || 0,
      payment_terms_days: Number(f.payment_terms_days) || 0,
      is_vip: !!f.is_vip,
      notes: f.notes,
    })
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: `${created.name} added to CRM` }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to create customer' }
  } finally {
    saving.value = false
  }
}

function exportCsv() {
  exporting.value = true
  const cols = ['name', 'phone', 'email', 'lifecycle_stage', 'segment_name', 'loyalty_tier', 'health_score', 'churn_risk', 'total_purchases', 'loyalty_points', 'visit_count']
  const lines = [cols.join(',')]
  for (const r of rows.value) {
    lines.push(cols.map((c) => `"${String(r[c] ?? '').replace(/"/g, '""')}"`).join(','))
  }
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `crm_customers_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
  exporting.value = false
}

onMounted(async () => {
  if (route.query.risk === 'high') filters.lifecycle_stage = 'at_risk'
  await loadLookups()
  await load()
  if (route.query.new) openCreate()
})
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-hero-btn-glass { background: rgba(255,255,255,.16) !important; color: #fff !important; font-weight: 600 !important; border: 1px solid rgba(255,255,255,.34) !important; backdrop-filter: blur(6px); }
.crm-hero-btn-glass:hover { background: rgba(255,255,255,.26) !important; }
.crm-search { flex: 1 1 300px; max-width: 440px; }
.crm-select { width: 170px; }
.crm-select-sm { width: 145px; }
.crm-chips { overflow-x: auto; flex-wrap: nowrap; }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-row { cursor: pointer; }
.crm-row:hover { background: rgba(var(--v-theme-primary), .04); }
.crm-score { display: flex; align-items: center; gap: 6px; justify-content: center; }
.crm-score-bar { width: 48px; height: 6px; border-radius: 999px; background: rgba(var(--v-theme-surface-variant), .8); overflow: hidden; }
.crm-score-fill { height: 100%; border-radius: 999px; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
