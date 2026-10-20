<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-chart-timeline-variant-shimmer"
      eyebrow="IMS · CUSTOMER CRM · PIPELINE"
      title="Sales Pipeline"
      subtitle="Track every opportunity from first conversation to signed deal — drag-free kanban, weighted forecasting and win-rate insight."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New opportunity
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
          placeholder="Search opportunity, customer…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable" variant="solo-filled" rounded="lg" flat bg-color="surface"
          hide-details clearable class="crm-search"
          @keyup.enter="load" @click:clear="load"
        />
        <v-spacer />
        <v-btn-toggle v-model="view" density="comfortable" rounded="lg" variant="outlined" divided mandatory>
          <v-btn value="board" icon="mdi-view-column-outline" size="small" title="Board" />
          <v-btn value="list" icon="mdi-format-list-bulleted" size="small" title="List" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- BOARD -->
    <div v-if="view === 'board'" class="crm-board">
      <div v-for="col in columns" :key="col.key" class="crm-col">
        <div class="crm-col-head">
          <div class="d-flex align-center ga-2">
            <v-icon size="15" :color="col.color">{{ col.icon }}</v-icon>
            <span class="font-weight-bold text-body-2">{{ col.label }}</span>
          </div>
          <div class="d-flex align-center ga-2">
            <span class="text-caption text-medium-emphasis">{{ formatMoney(col.value) }}</span>
            <v-chip size="x-small" variant="tonal" :color="col.color" class="font-weight-bold">{{ col.rows.length }}</v-chip>
          </div>
        </div>
        <div class="crm-col-body">
          <div v-for="o in col.rows" :key="o.id" class="crm-deal" @click="openEdit(o)">
            <div class="d-flex align-center justify-space-between ga-2">
              <span class="crm-deal-title">{{ o.title }}</span>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn icon="mdi-dots-vertical" size="x-small" variant="text" v-bind="props" @click.stop />
                </template>
                <v-list density="compact">
                  <v-list-item v-for="s in stages" :key="s.value" :disabled="s.value === o.stage" @click.stop="move(o, s.value)">
                    <v-list-item-title>Move to {{ s.label }}</v-list-item-title>
                  </v-list-item>
                  <v-divider />
                  <v-list-item @click.stop="remove(o)">
                    <v-list-item-title class="text-error">Delete</v-list-item-title>
                  </v-list-item>
                </v-list>
              </v-menu>
            </div>
            <div class="crm-deal-customer mt-1">{{ o.customer_name }}</div>
            <div class="d-flex align-center justify-space-between mt-2">
              <span class="crm-deal-value">{{ formatMoney(o.value) }}</span>
              <v-chip size="x-small" variant="tonal" :color="probColor(o.probability)">{{ o.probability }}%</v-chip>
            </div>
            <div class="crm-deal-meta mt-1">
              <span><v-icon size="12">mdi-account-outline</v-icon>{{ o.owner_name || 'Unassigned' }}</span>
              <span v-if="o.expected_close_date"><v-icon size="12">mdi-calendar-outline</v-icon>{{ o.expected_close_date }}</span>
            </div>
          </div>
          <div v-if="!col.rows.length" class="crm-col-empty">
            <v-icon size="24" color="medium-emphasis">mdi-tray</v-icon>
            <div class="text-caption text-medium-emphasis mt-1">Empty</div>
          </div>
        </div>
      </div>
    </div>

    <!-- LIST -->
    <v-card v-else rounded="xl" border>
      <v-table density="comfortable" class="crm-table">
        <thead>
          <tr><th>Opportunity</th><th>Customer</th><th>Stage</th><th class="text-right">Value</th><th class="text-center">Prob.</th><th class="text-right">Weighted</th><th>Close date</th><th>Owner</th><th /></tr>
        </thead>
        <tbody>
          <tr v-for="o in rows" :key="o.id" class="crm-row" @click="openEdit(o)">
            <td class="font-weight-medium">{{ o.title }}</td>
            <td>{{ o.customer_name }}</td>
            <td><v-chip size="x-small" variant="tonal" :color="stageMeta(o.stage).color">{{ stageMeta(o.stage).label }}</v-chip></td>
            <td class="text-right font-weight-medium">{{ formatMoney(o.value) }}</td>
            <td class="text-center">{{ o.probability }}%</td>
            <td class="text-right">{{ formatMoney(o.weighted_value) }}</td>
            <td>{{ o.expected_close_date || '—' }}</td>
            <td>{{ o.owner_name || '—' }}</td>
            <td class="text-right"><v-btn icon="mdi-chevron-right" size="x-small" variant="text" /></td>
          </tr>
          <tr v-if="!rows.length"><td colspan="9"><div class="crm-empty pa-6"><v-icon size="40" color="medium-emphasis">mdi-chart-timeline-variant-shimmer</v-icon><div class="text-body-2 font-weight-medium mt-2">No opportunities yet</div></div></td></tr>
        </tbody>
      </v-table>
    </v-card>

    <!-- form -->
    <v-dialog v-model="formDialog" max-width="640" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? 'Edit opportunity' : 'New opportunity'"
          subtitle="Track a potential deal"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-select v-model="form.customer" :items="customerOptions" item-title="label" item-value="id" label="Customer *" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="form.title" label="Title *" variant="outlined" density="comfortable" class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="form.stage" :items="stages" item-title="label" item-value="value" label="Stage" variant="outlined" density="comfortable" />
            <v-text-field v-model.number="form.probability" type="number" min="0" max="100" label="Probability %" variant="outlined" density="comfortable" />
          </div>
          <div class="d-flex ga-2 mb-2">
            <v-text-field v-model.number="form.value" type="number" step="0.01" label="Value" variant="outlined" density="comfortable" />
            <v-text-field v-model="form.expected_close_date" type="date" label="Expected close" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="form.source" label="Source" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { stageMeta, useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { opportunities, opportunityStats, customers, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const stats = ref({})
const search = ref('')
const view = ref('board')
const customerOptions = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const editing = ref(false)
const form = ref(blank())

const stages = [
  { value: 'new', label: 'New' }, { value: 'qualified', label: 'Qualified' },
  { value: 'proposal', label: 'Proposal' }, { value: 'negotiation', label: 'Negotiation' },
  { value: 'won', label: 'Won' }, { value: 'lost', label: 'Lost' },
]

const heroFacts = computed(() => [
  { value: stats.value.open ?? 0, label: 'open deals' },
  { value: formatMoney(stats.value.pipeline_value || 0), label: 'pipeline' },
  { value: formatMoney(stats.value.won_value || 0), label: 'won' },
  { value: `${stats.value.win_rate ?? 0}%`, label: 'win rate' },
])

const kpis = computed(() => [
  { title: 'Open deals', value: stats.value.open ?? 0, sub: 'in progress', icon: 'mdi-briefcase-outline', color: 'primary' },
  { title: 'Pipeline value', value: formatMoney(stats.value.pipeline_value || 0), sub: 'unweighted', icon: 'mdi-chart-timeline-variant-shimmer', color: 'info' },
  { title: 'Expected value', value: formatMoney(stats.value.expected_value || 0), sub: 'probability weighted', icon: 'mdi-target', color: 'deep-purple' },
  { title: 'Won', value: stats.value.won ?? 0, sub: formatMoney(stats.value.won_value || 0), icon: 'mdi-trophy-outline', color: 'success' },
  { title: 'Lost', value: stats.value.lost ?? 0, sub: 'closed lost', icon: 'mdi-close-octagon-outline', color: 'error' },
  { title: 'Win rate', value: `${stats.value.win_rate ?? 0}%`, sub: 'closed deals', icon: 'mdi-percent-outline', color: 'teal' },
])

const columns = computed(() =>
  ['new', 'qualified', 'proposal', 'negotiation', 'won', 'lost'].map((key) => {
    const meta = stageMeta(key)
    const colRows = rows.value.filter((r) => r.stage === key)
    return {
      key, label: meta.label, color: meta.color, icon: meta.icon,
      rows: colRows,
      value: colRows.reduce((a, r) => a + (Number(r.value) || 0), 0),
    }
  })
)

function probColor(p) {
  const n = Number(p) || 0
  if (n >= 70) return 'success'
  if (n >= 40) return 'info'
  return 'grey'
}

function blank() {
  return {
    customer: null, title: '', stage: 'new', probability: 20, value: 0,
    expected_close_date: '', source: '', notes: '',
  }
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: '-created_at' }
    if (search.value) params.search = search.value
    const [list, st] = await Promise.all([opportunities(params), opportunityStats()])
    rows.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load pipeline' }
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
  editing.value = false
  form.value = blank()
  loadCustomers()
  formDialog.value = true
}

function openEdit(o) {
  editing.value = true
  form.value = { ...blank(), ...o }
  loadCustomers()
  formDialog.value = true
}

async function save() {
  if (!form.value.customer || !form.value.title) {
    snack.value = { show: true, color: 'error', text: 'Customer and title are required' }
    return
  }
  saving.value = true
  try {
    const body = {
      customer: form.value.customer,
      title: form.value.title,
      stage: form.value.stage,
      probability: Number(form.value.probability) || 0,
      value: Number(form.value.value) || 0,
      expected_close_date: form.value.expected_close_date || null,
      source: form.value.source,
      notes: form.value.notes,
    }
    if (editing.value && form.value.id) {
      await $api.patch(`/crm/opportunities/${form.value.id}/`, body)
      snack.value = { show: true, color: 'success', text: 'Opportunity updated' }
    } else {
      await $api.post('/crm/opportunities/', body)
      snack.value = { show: true, color: 'success', text: 'Opportunity created' }
    }
    formDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Save failed' }
  } finally {
    saving.value = false
  }
}

async function move(o, stage) {
  try {
    await $api.post(`/crm/opportunities/${o.id}/move-stage/`, { stage })
    snack.value = { show: true, color: 'success', text: `Moved to ${stage}` }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to move opportunity' }
  }
}

async function remove(o) {
  try {
    await $api.delete(`/crm/opportunities/${o.id}/`)
    snack.value = { show: true, color: 'success', text: 'Opportunity deleted' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to delete' }
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-search { flex: 1 1 300px; max-width: 440px; }
.crm-board { display: grid; grid-template-columns: repeat(auto-fit, minmax(235px, 1fr)); gap: 12px; align-items: start; }
.crm-col { background: rgb(var(--v-theme-surface)); border: 1px solid rgba(var(--v-border-color), .16); border-radius: 15px; overflow: hidden; display: flex; flex-direction: column; max-height: 72vh; }
.crm-col-head { display: flex; align-items: center; justify-content: space-between; padding: 10px 12px; border-bottom: 1px solid rgba(var(--v-border-color), .14); background: rgba(var(--v-theme-surface-variant), .4); }
.crm-col-body { padding: 9px; display: flex; flex-direction: column; gap: 9px; overflow-y: auto; }
.crm-col-empty { text-align: center; padding: 18px 0; }
.crm-deal { border: 1px solid rgba(var(--v-border-color), .18); border-radius: 12px; padding: 11px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.crm-deal:hover { box-shadow: 0 6px 18px rgba(0,0,0,.09); transform: translateY(-1px); }
.crm-deal-title { font-size: 12.5px; font-weight: 700; }
.crm-deal-customer { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), .62); }
.crm-deal-value { font-size: 12.5px; font-weight: 800; }
.crm-deal-meta { display: flex; flex-wrap: wrap; gap: 8px; font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55); }
.crm-deal-meta span { display: inline-flex; align-items: center; gap: 3px; }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-row { cursor: pointer; }
.crm-row:hover { background: rgba(var(--v-theme-primary), .04); }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
