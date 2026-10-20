<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-bullhorn-outline"
      eyebrow="IMS · CUSTOMER CRM · MARKETING"
      title="Campaigns"
      subtitle="Plan and measure outbound campaigns — email, SMS, WhatsApp and call rounds — with ROI per audience."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New campaign
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense>
      <v-col v-for="c in rows" :key="c.id" cols="12" sm="6" lg="4">
        <v-card rounded="xl" border class="crm-camp h-100" @click="openEdit(c)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <div class="crm-camp-icon" :class="`crm-camp--${c.status}`">
                <v-icon size="20">{{ channelMeta(c.channel).icon }}</v-icon>
              </div>
              <div>
                <div class="crm-camp-name">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ channelMeta(c.channel).label }}<span v-if="c.segment_name"> · {{ c.segment_name }}</span></div>
              </div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="campaignStatus(c.status).color" class="font-weight-bold">{{ campaignStatus(c.status).label }}</v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="crm-camp-grid">
            <div>
              <div class="crm-camp-label">Sent</div>
              <div class="crm-camp-value">{{ c.sent_count }}</div>
            </div>
            <div>
              <div class="crm-camp-label">Converted</div>
              <div class="crm-camp-value">{{ c.converted_count }}</div>
            </div>
            <div>
              <div class="crm-camp-label">Revenue</div>
              <div class="crm-camp-value">{{ formatMoney(c.revenue) }}</div>
            </div>
            <div>
              <div class="crm-camp-label">ROI</div>
              <div class="crm-camp-value" :class="c.roi >= 0 ? 'text-success' : 'text-error'">{{ c.roi }}%</div>
            </div>
          </div>

          <div class="mt-3">
            <div class="d-flex justify-space-between text-caption mb-1">
              <span>Conversion rate</span><span class="font-weight-medium">{{ c.conversion_rate }}%</span>
            </div>
            <v-progress-linear :model-value="c.conversion_rate" color="success" height="6" rounded bg-color="surface-variant" />
          </div>

          <div class="d-flex align-center justify-space-between mt-3 text-caption text-medium-emphasis">
            <span>{{ c.start_date || '—' }} → {{ c.end_date || '—' }}</span>
            <span>{{ formatMoney(c.actual_cost) }} spend</span>
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!rows.length" cols="12">
        <v-card rounded="xl" border>
          <div class="crm-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-bullhorn-outline</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No campaigns yet</div>
            <div class="text-caption text-medium-emphasis">Create a campaign to reach a customer segment.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">New campaign</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="formDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? 'Edit campaign' : 'New campaign'"
          subtitle="Reach a customer audience"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="8"><v-text-field v-model="form.name" label="Campaign name *" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.status" :items="statusOptions" item-title="label" item-value="value" label="Status" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.channel" :items="channelOptions" item-title="label" item-value="value" label="Channel" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="form.segment" :items="segments" item-title="name" item-value="id" label="Audience segment" variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" md="4"><v-text-field v-model.number="form.target_count" type="number" label="Target audience" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model="form.start_date" type="date" label="Start" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model="form.end_date" type="date" label="End" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.budget" type="number" step="0.01" label="Budget" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.actual_cost" type="number" step="0.01" label="Actual cost" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.sent_count" type="number" label="Sent" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.converted_count" type="number" label="Converted" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.clicked_count" type="number" label="Clicked" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="form.revenue" type="number" step="0.01" label="Revenue" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="remove">Delete</v-btn>
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
import { campaignStatus, channelMeta, useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { campaigns, campaignStats, segments: fetchSegments, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const stats = ref({})
const segments = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const formDialog = ref(false)
const editing = ref(false)
const form = ref(blank())

const statusOptions = [
  { value: 'draft', label: 'Draft' }, { value: 'scheduled', label: 'Scheduled' },
  { value: 'running', label: 'Running' }, { value: 'completed', label: 'Completed' },
  { value: 'paused', label: 'Paused' }, { value: 'cancelled', label: 'Cancelled' },
]
const channelOptions = [
  { value: 'email', label: 'Email' }, { value: 'sms', label: 'SMS' },
  { value: 'whatsapp', label: 'WhatsApp' }, { value: 'call', label: 'Call round' },
  { value: 'in_store', label: 'In-store' }, { value: 'social', label: 'Social' },
]

const heroFacts = computed(() => [
  { value: stats.value.total ?? 0, label: 'campaigns' },
  { value: stats.value.running ?? 0, label: 'running' },
  { value: `${stats.value.conversion_rate ?? 0}%`, label: 'conversion' },
  { value: formatMoney(stats.value.revenue || 0), label: 'revenue' },
])

const kpis = computed(() => [
  { title: 'Campaigns', value: stats.value.total ?? 0, sub: 'all time', icon: 'mdi-bullhorn-outline', color: 'primary' },
  { title: 'Running', value: stats.value.running ?? 0, sub: 'live now', icon: 'mdi-play-circle-outline', color: 'success' },
  { title: 'Budget', value: formatMoney(stats.value.budget || 0), sub: 'allocated', icon: 'mdi-cash', color: 'deep-purple' },
  { title: 'Spend', value: formatMoney(stats.value.spend || 0), sub: 'actual', icon: 'mdi-cash-minus', color: 'amber' },
  { title: 'Revenue', value: formatMoney(stats.value.revenue || 0), sub: 'attributed', icon: 'mdi-cash-plus', color: 'teal' },
  { title: 'Conversion', value: `${stats.value.conversion_rate ?? 0}%`, sub: `${stats.value.converted ?? 0} converted`, icon: 'mdi-target', color: 'info' },
])

function blank() {
  return {
    name: '', status: 'draft', channel: 'email', segment: null, target_count: 0,
    start_date: '', end_date: '', budget: 0, actual_cost: 0,
    sent_count: 0, clicked_count: 0, converted_count: 0, revenue: 0, notes: '',
  }
}

async function load() {
  loading.value = true
  try {
    const [list, st] = await Promise.all([
      campaigns({ page_size: 300, ordering: '-created_at' }),
      campaignStats(),
    ])
    rows.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load campaigns' }
  } finally {
    loading.value = false
  }
}

async function loadSegments() {
  try {
    segments.value = unpack(await fetchSegments({ page_size: 200 }))
  } catch { /* optional */ }
}

function openCreate() {
  editing.value = false
  form.value = blank()
  loadSegments()
  formDialog.value = true
}

function openEdit(c) {
  editing.value = true
  form.value = { ...blank(), ...c }
  loadSegments()
  formDialog.value = true
}

async function save() {
  if (!form.value.name) {
    snack.value = { show: true, color: 'error', text: 'Campaign name is required' }
    return
  }
  saving.value = true
  try {
    const body = { ...form.value }
    for (const k of ['start_date', 'end_date']) if (!body[k]) body[k] = null
    if (!body.segment) body.segment = null
    if (editing.value && form.value.id) {
      await $api.patch(`/crm/campaigns/${form.value.id}/`, body)
      snack.value = { show: true, color: 'success', text: 'Campaign updated' }
    } else {
      await $api.post('/crm/campaigns/', body)
      snack.value = { show: true, color: 'success', text: 'Campaign created' }
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

async function remove() {
  if (!form.value.id) return
  try {
    await $api.delete(`/crm/campaigns/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Campaign deleted' }
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
.crm-camp { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.crm-camp:hover { box-shadow: 0 8px 22px rgba(0,0,0,.09); transform: translateY(-1px); }
.crm-camp-icon { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; background: rgba(var(--v-theme-primary), .1); color: rgb(var(--v-theme-primary)); }
.crm-camp--running { background: rgba(16,185,129,.14); color: #0f766e; }
.crm-camp--completed { background: rgba(59,130,246,.14); color: #1d4ed8; }
.crm-camp--paused { background: rgba(245,158,11,.16); color: #b45309; }
.crm-camp--cancelled { background: rgba(239,68,68,.14); color: #b91c1c; }
.crm-camp--draft { background: rgba(107,114,128,.14); color: #4b5563; }
.crm-camp-name { font-size: 14px; font-weight: 800; }
.crm-camp-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.crm-camp-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-camp-value { font-size: 13px; font-weight: 600; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
