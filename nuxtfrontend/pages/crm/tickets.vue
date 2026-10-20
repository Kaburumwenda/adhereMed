<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-lifebuoy"
      eyebrow="IMS · CUSTOMER CRM · SUPPORT DESK"
      title="Support Tickets"
      subtitle="Log, triage and resolve customer cases with SLA tracking, priority queues and satisfaction scoring."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New ticket
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search reference, subject, customer…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable" variant="solo-filled" rounded="lg" flat bg-color="surface"
          hide-details clearable class="crm-search"
          @keyup.enter="load" @click:clear="load"
        />
        <v-select v-model="filters.priority" :items="priorityOptions" item-title="label" item-value="value" label="Priority" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
        <v-select v-model="filters.category" :items="categoryOptions" item-title="label" item-value="value" label="Category" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
        <v-spacer />
        <v-btn variant="text" size="small" color="error" class="text-none" prepend-icon="mdi-filter-remove-outline" :disabled="!hasFilters" @click="clearFilters">Clear</v-btn>
      </div>
      <v-divider />
      <div class="d-flex flex-wrap align-center ga-2 pa-3">
        <v-chip-group :model-value="filters.status || 'all'" selected-class="text-primary" mandatory class="crm-chips">
          <v-chip v-for="s in statusChips" :key="s.value" :value="s.value" size="small" rounded="lg" variant="tonal" class="text-none" @click="filterByStatus(s.value)">
            <v-icon v-if="s.icon" start size="15">{{ s.icon }}</v-icon>
            {{ s.label }}<span class="ml-1 font-weight-bold">{{ s.count }}</span>
          </v-chip>
        </v-chip-group>
      </div>
    </v-card>

    <v-card rounded="xl" border>
      <v-table density="comfortable" class="crm-table">
        <thead>
          <tr><th>Ticket</th><th>Customer</th><th>Category</th><th>Priority</th><th>Status</th><th>Assigned</th><th>Opened</th><th>SLA</th><th /></tr>
        </thead>
        <tbody>
          <tr v-for="t in rows" :key="t.id" class="crm-row" @click="openDetail(t)">
            <td>
              <div class="font-weight-medium">{{ t.subject }}</div>
              <div class="text-caption text-medium-emphasis">{{ t.reference }}</div>
            </td>
            <td>
              <div>{{ t.customer_name }}</div>
              <div class="text-caption text-medium-emphasis">{{ t.customer_phone }}</div>
            </td>
            <td class="text-caption">{{ titleCase(t.category) }}</td>
            <td><v-chip size="x-small" variant="tonal" :color="priorityMeta(t.priority).color">{{ priorityMeta(t.priority).label }}</v-chip></td>
            <td><v-chip size="small" variant="tonal" :color="ticketStatus(t.status).color"><v-icon start size="12">{{ ticketStatus(t.status).icon }}</v-icon>{{ ticketStatus(t.status).label }}</v-chip></td>
            <td class="text-caption">{{ t.assigned_to_name || '—' }}</td>
            <td class="text-caption">{{ dt(t.opened_at) }}</td>
            <td>
              <v-chip v-if="t.is_overdue" size="x-small" variant="tonal" color="error">Overdue</v-chip>
              <span v-else-if="t.sla_due_at" class="text-caption text-medium-emphasis">{{ dt(t.sla_due_at) }}</span>
              <span v-else class="text-caption text-medium-emphasis">—</span>
            </td>
            <td class="text-right"><v-btn icon="mdi-chevron-right" size="x-small" variant="text" /></td>
          </tr>
          <tr v-if="!rows.length"><td colspan="9"><div class="crm-empty pa-6"><v-icon size="40" color="medium-emphasis">mdi-lifebuoy</v-icon><div class="text-body-2 font-weight-medium mt-2">No tickets</div><div class="text-caption text-medium-emphasis">Create a ticket to start tracking a case.</div></div></td></tr>
        </tbody>
      </v-table>
    </v-card>

    <!-- create -->
    <v-dialog v-model="formDialog" max-width="640" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-plus"
          title="New support ticket"
          subtitle="Log a customer issue for the service desk"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-select v-model="form.customer" :items="customerOptions" item-title="label" item-value="id" label="Customer *" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="form.subject" label="Subject *" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="form.description" label="Description" rows="3" auto-grow variant="outlined" density="comfortable" class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="form.category" :items="categoryOptions" item-title="label" item-value="value" label="Category" variant="outlined" density="comfortable" />
            <v-select v-model="form.priority" :items="priorityOptions" item-title="label" item-value="value" label="Priority" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="form.sla_due_at" type="datetime-local" label="SLA due at" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="save">Create ticket</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- detail -->
    <v-dialog v-model="detailDialog" max-width="640" scrollable>
      <v-card v-if="active" rounded="xl">
        <BrandDialogHeader
          :icon="ticketStatus(active.status).icon"
          :title="active.reference"
          :subtitle="`${active.customer_name} · ${titleCase(active.category)} · ${priorityMeta(active.priority).label}`"
          @close="detailDialog = false"
        >
          <template #actions>
            <v-chip size="small" variant="flat" class="bdh-chip-solid font-weight-bold">{{ ticketStatus(active.status).label }}</v-chip>
          </template>
        </BrandDialogHeader>
        <v-card-text>
          <div class="text-subtitle-1 font-weight-bold">{{ active.subject }}</div>
          <v-divider class="my-3" />
          <div v-if="active.description" class="text-body-2 mb-3">{{ active.description }}</div>
          <v-row dense class="mb-2">
            <v-col cols="6"><div class="crm-stat"><div class="crm-stat-label">Opened</div><div class="crm-stat-value crm-small">{{ dt(active.opened_at) }}</div></div></v-col>
            <v-col cols="6"><div class="crm-stat"><div class="crm-stat-label">First response</div><div class="crm-stat-value crm-small">{{ dt(active.first_response_at) }}</div></div></v-col>
            <v-col cols="6"><div class="crm-stat"><div class="crm-stat-label">Resolved</div><div class="crm-stat-value crm-small">{{ dt(active.resolved_at) }}</div></div></v-col>
            <v-col cols="6"><div class="crm-stat"><div class="crm-stat-label">SLA due</div><div class="crm-stat-value crm-small" :class="active.is_overdue ? 'text-error' : ''">{{ dt(active.sla_due_at) }}</div></div></v-col>
          </v-row>
          <v-textarea v-model="resolveNotes" label="Resolution notes" rows="2" auto-grow variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions class="flex-wrap">
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="info" class="text-none" @click="setStatus('in_progress')">In progress</v-btn>
          <v-btn size="small" variant="tonal" color="amber" class="text-none" @click="setStatus('waiting')">Waiting</v-btn>
          <v-btn size="small" variant="flat" color="success" rounded="lg" class="text-none" prepend-icon="mdi-check" @click="resolve">Resolve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { crmPriority, ticketStatus, useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { tickets, ticketStats, customers, unpack } = useCrm()
const priorityMeta = crmPriority

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const stats = ref({})
const search = ref('')
const filters = reactive({ status: null, priority: null, category: null })
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const detailDialog = ref(false)
const active = ref(null)
const resolveNotes = ref('')
const customerOptions = ref([])
const form = ref(blank())

const priorityOptions = [
  { value: 'low', label: 'Low' }, { value: 'normal', label: 'Normal' },
  { value: 'high', label: 'High' }, { value: 'urgent', label: 'Urgent' },
]
const categoryOptions = [
  { value: 'order', label: 'Order issue' }, { value: 'delivery', label: 'Delivery' },
  { value: 'billing', label: 'Billing' }, { value: 'product', label: 'Product quality' },
  { value: 'account', label: 'Account' }, { value: 'other', label: 'Other' },
]

const heroFacts = computed(() => [
  { value: stats.value.total ?? 0, label: 'tickets' },
  { value: stats.value.open ?? 0, label: 'open' },
  { value: stats.value.overdue ?? 0, label: 'overdue' },
  { value: `${stats.value.avg_resolution_hours ?? 0}h`, label: 'avg resolution' },
])

const kpis = computed(() => [
  { title: 'Open', value: stats.value.open ?? 0, sub: 'awaiting triage', icon: 'mdi-alert-circle-outline', color: 'error' },
  { title: 'In progress', value: stats.value.in_progress ?? 0, sub: 'being worked', icon: 'mdi-progress-clock', color: 'info' },
  { title: 'Waiting', value: stats.value.waiting ?? 0, sub: 'on customer', icon: 'mdi-pause-circle-outline', color: 'amber' },
  { title: 'Resolved', value: stats.value.resolved ?? 0, sub: 'closed cases', icon: 'mdi-check-circle-outline', color: 'success' },
  { title: 'Overdue SLA', value: stats.value.overdue ?? 0, sub: 'breached', icon: 'mdi-timer-alert-outline', color: 'error' },
  { title: 'Avg resolution', value: `${stats.value.avg_resolution_hours ?? 0}h`, sub: 'all resolved', icon: 'mdi-clock-check-outline', color: 'teal' },
])

const statusChips = computed(() => {
  const map = { open: stats.value.open, in_progress: stats.value.in_progress, waiting: stats.value.waiting, resolved: stats.value.resolved, closed: stats.value.closed }
  const total = Object.values(map).reduce((a, b) => a + (b || 0), 0)
  return [{ value: 'all', label: 'All', icon: 'mdi-view-grid-outline', count: total },
    ...['open', 'in_progress', 'waiting', 'resolved', 'closed'].map((k) => ({
      value: k, label: ticketStatus(k).label, icon: ticketStatus(k).icon, count: map[k] || 0,
    }))]
})

const hasFilters = computed(() => !!filters.status || !!filters.priority || !!filters.category || !!search.value)

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function blank() {
  return { customer: null, subject: '', description: '', category: 'other', priority: 'normal', sla_due_at: '' }
}

function filterByStatus(v) {
  filters.status = v === 'all' ? null : v
  load()
}

function clearFilters() {
  filters.status = null
  filters.priority = null
  filters.category = null
  search.value = ''
  load()
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: '-created_at' }
    if (search.value) params.search = search.value
    if (filters.status) params.status = filters.status
    if (filters.priority) params.priority = filters.priority
    if (filters.category) params.category = filters.category
    const [list, st] = await Promise.all([tickets(params), ticketStats()])
    rows.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load tickets' }
  } finally {
    loading.value = false
  }
}

async function loadCustomers() {
  if (customerOptions.value.length) return
  try {
    const { data } = await customers({ page_size: 300 })
    customerOptions.value = (data?.results || data || []).map((c) => ({ ...c, label: `${c.name} · ${c.phone}` }))
  } catch { /* optional */ }
}

function openCreate() {
  form.value = blank()
  loadCustomers()
  formDialog.value = true
}

function openDetail(t) {
  active.value = t
  resolveNotes.value = t.resolution_notes || ''
  detailDialog.value = true
}

async function save() {
  if (!form.value.customer || !form.value.subject) {
    snack.value = { show: true, color: 'error', text: 'Customer and subject are required' }
    return
  }
  saving.value = true
  try {
    const body = {
      customer: form.value.customer,
      subject: form.value.subject,
      description: form.value.description,
      category: form.value.category,
      priority: form.value.priority,
    }
    if (form.value.sla_due_at) body.sla_due_at = new Date(form.value.sla_due_at).toISOString()
    await $api.post('/crm/tickets/', body)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Ticket created' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to create ticket' }
  } finally {
    saving.value = false
  }
}

async function setStatus(s) {
  if (!active.value) return
  try {
    await $api.post(`/crm/tickets/${active.value.id}/set-status/`, { status: s })
    snack.value = { show: true, color: 'success', text: `Status: ${ticketStatus(s).label}` }
    detailDialog.value = false
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to update status' }
  }
}

async function resolve() {
  if (!active.value) return
  try {
    await $api.post(`/crm/tickets/${active.value.id}/resolve/`, { resolution_notes: resolveNotes.value })
    snack.value = { show: true, color: 'success', text: 'Ticket resolved' }
    detailDialog.value = false
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to resolve ticket' }
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-search { flex: 1 1 300px; max-width: 440px; }
.crm-select { width: 165px; }
.crm-chips { overflow-x: auto; flex-wrap: nowrap; }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-row { cursor: pointer; }
.crm-row:hover { background: rgba(var(--v-theme-primary), .04); }
.crm-stat { border: 1px solid rgba(var(--v-border-color), .16); border-radius: 12px; padding: 9px 11px; }
.crm-stat-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-stat-value { font-size: 16px; font-weight: 800; }
.crm-small { font-size: 12px; font-weight: 600; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
