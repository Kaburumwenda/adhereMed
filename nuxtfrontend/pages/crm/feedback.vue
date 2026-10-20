<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-emoticon-outline"
      eyebrow="IMS · CUSTOMER CRM · VOICE OF CUSTOMER"
      title="Feedback & NPS"
      subtitle="Net Promoter Score, satisfaction ratings, reviews and complaints — with a closed-loop workflow."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          Record feedback
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense class="mb-3">
      <!-- NPS gauge -->
      <v-col cols="12" md="5">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="primary">mdi-gauge</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Net Promoter Score</div>
              <div class="text-caption text-medium-emphasis">Promoters − detractors</div>
            </div>
          </div>
          <v-divider />
          <v-card-text class="text-center">
            <v-progress-circular
              :model-value="npsPct"
              :size="150"
              :width="14"
              :color="npsColor"
              bg-color="surface-variant"
              rounded
            >
              <div>
                <div class="crm-nps-value">{{ stats.nps ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">NPS</div>
              </div>
            </v-progress-circular>
            <div class="crm-nps-legend mt-4">
              <div class="crm-nps-tile crm-nps--good"><div class="crm-nps-n">{{ stats.promoters ?? 0 }}</div><div class="crm-nps-l">promoters</div></div>
              <div class="crm-nps-tile crm-nps--mid"><div class="crm-nps-n">{{ stats.passives ?? 0 }}</div><div class="crm-nps-l">passives</div></div>
              <div class="crm-nps-tile crm-nps--bad"><div class="crm-nps-n">{{ stats.detractors ?? 0 }}</div><div class="crm-nps-l">detractors</div></div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- breakdown -->
      <v-col cols="12" md="7">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="teal">mdi-chart-donut</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Feedback mix</div>
              <div class="text-caption text-medium-emphasis">By survey kind</div>
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="k in kindRows" :key="k.key" class="mb-3">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="d-flex align-center ga-2 text-body-2"><v-icon size="15" :color="k.color">{{ k.icon }}</v-icon>{{ k.label }}</span>
                <span class="text-body-2 font-weight-bold">{{ k.count }}</span>
              </div>
              <v-progress-linear :model-value="k.pct" :color="k.color" height="7" rounded bg-color="surface-variant" />
            </div>
            <v-divider class="my-3" />
            <div class="crm-kv"><span>CSAT average</span><strong>{{ stats.csat ?? 0 }} / 5</strong></div>
            <div class="crm-kv"><span>Unhandled</span><strong class="text-error">{{ stats.unhandled ?? 0 }}</strong></div>
            <div class="crm-kv"><span>Total responses</span><strong>{{ stats.total ?? 0 }}</strong></div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="xl" border>
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search comment, customer…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable" variant="solo-filled" rounded="lg" flat bg-color="surface"
          hide-details clearable class="crm-search"
          @keyup.enter="load" @click:clear="load"
        />
        <v-select v-model="kindFilter" :items="kindOptions" item-title="label" item-value="value" label="Kind" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
        <v-switch v-model="onlyUnhandled" color="primary" density="compact" hide-details label="Unhandled only" @update:model-value="load" />
      </div>
      <v-divider />
      <v-card-text v-if="rows.length">
        <div v-for="f in rows" :key="f.id" class="crm-fb">
          <v-chip size="small" variant="tonal" :color="scoreColor(f)" class="font-weight-bold">{{ f.score }}</v-chip>
          <div class="flex-grow-1">
            <div class="d-flex align-center justify-space-between ga-2 flex-wrap">
              <span class="text-body-2 font-weight-medium">{{ f.customer_name || 'Anonymous' }} · {{ titleCase(f.kind) }}</span>
              <span class="text-caption text-medium-emphasis">{{ dt(f.submitted_at) }}</span>
            </div>
            <div v-if="f.comment" class="text-body-2 mt-1">{{ f.comment }}</div>
            <div class="text-caption text-medium-emphasis mt-1">
              <span v-if="f.channel">{{ f.channel }} · </span>
              {{ f.handled ? 'Handled' : 'Awaiting follow-up' }}
            </div>
          </div>
          <v-btn v-if="!f.handled" size="x-small" variant="tonal" color="success" class="text-none" @click="handle(f)">Handle</v-btn>
        </div>
      </v-card-text>
      <div v-else class="crm-empty pa-8">
        <v-icon size="44" color="medium-emphasis">mdi-emoticon-outline</v-icon>
        <div class="text-body-1 font-weight-medium mt-2">No feedback recorded</div>
        <div class="text-caption text-medium-emphasis">Record a survey response to start measuring NPS.</div>
        <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">Record feedback</v-btn>
      </div>
    </v-card>

    <v-dialog v-model="formDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-emoticon-outline"
          title="Record feedback"
          subtitle="Capture sentiment, NPS or a complaint"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-select v-model="form.customer" :items="customerOptions" item-title="label" item-value="id" label="Customer" variant="outlined" density="comfortable" clearable class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="form.kind" :items="kindOptions" item-title="label" item-value="value" label="Kind" variant="outlined" density="comfortable" />
            <v-text-field v-model.number="form.score" type="number" :min="0" :max="form.kind === 'csat' ? 5 : 10" label="Score" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="form.channel" label="Channel (e.g. In-store, SMS)" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="form.comment" label="Comment" rows="3" auto-grow variant="outlined" density="comfortable" />
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
import { useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { feedback, feedbackStats, customers, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const stats = ref({})
const search = ref('')
const kindFilter = ref(null)
const onlyUnhandled = ref(false)
const customerOptions = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const formDialog = ref(false)
const form = reactive({ customer: null, kind: 'nps', score: 9, channel: '', comment: '' })

const kindOptions = [
  { value: 'nps', label: 'NPS survey' }, { value: 'csat', label: 'Satisfaction' },
  { value: 'review', label: 'Review' }, { value: 'complaint', label: 'Complaint' },
  { value: 'compliment', label: 'Compliment' },
]

const KIND_META = {
  nps: { label: 'NPS survey', icon: 'mdi-gauge', color: 'primary' },
  csat: { label: 'Satisfaction', icon: 'mdi-emoticon-happy-outline', color: 'teal' },
  review: { label: 'Review', icon: 'mdi-star-outline', color: 'amber' },
  complaint: { label: 'Complaint', icon: 'mdi-alert-outline', color: 'error' },
  compliment: { label: 'Compliment', icon: 'mdi-heart-outline', color: 'pink' },
}

const heroFacts = computed(() => [
  { value: stats.value.nps ?? 0, label: 'NPS' },
  { value: stats.value.promoters ?? 0, label: 'promoters' },
  { value: stats.value.detractors ?? 0, label: 'detractors' },
  { value: stats.value.unhandled ?? 0, label: 'unhandled' },
])

const kpis = computed(() => [
  { title: 'NPS', value: stats.value.nps ?? 0, sub: 'net promoter score', icon: 'mdi-gauge', color: 'primary' },
  { title: 'Promoters', value: stats.value.promoters ?? 0, sub: 'score 9-10', icon: 'mdi-emoticon-excited-outline', color: 'success' },
  { title: 'Passives', value: stats.value.passives ?? 0, sub: 'score 7-8', icon: 'mdi-emoticon-neutral-outline', color: 'amber' },
  { title: 'Detractors', value: stats.value.detractors ?? 0, sub: 'score 0-6', icon: 'mdi-emoticon-sad-outline', color: 'error' },
  { title: 'CSAT', value: `${stats.value.csat ?? 0}/5`, sub: 'avg satisfaction', icon: 'mdi-star-circle-outline', color: 'teal' },
  { title: 'Unhandled', value: stats.value.unhandled ?? 0, sub: 'need follow-up', icon: 'mdi-message-alert-outline', color: 'deep-purple' },
])

const npsPct = computed(() => Math.max(0, Math.min(100, ((Number(stats.value.nps) || 0) + 100) / 2)))
const npsColor = computed(() => {
  const n = Number(stats.value.nps) || 0
  if (n >= 50) return 'success'
  if (n >= 0) return 'amber'
  return 'error'
})

const kindRows = computed(() => {
  const by = stats.value.by_kind || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0) || 1
  return Object.entries(KIND_META).map(([key, m]) => ({
    key, ...m, count: by[key] || 0, pct: Math.round(((by[key] || 0) / total) * 100),
  }))
})

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function scoreColor(f) {
  if (f.kind === 'csat') return f.score >= 4 ? 'success' : f.score >= 3 ? 'amber' : 'error'
  return f.score >= 9 ? 'success' : f.score >= 7 ? 'amber' : 'error'
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 300, ordering: '-submitted_at' }
    if (search.value) params.search = search.value
    if (kindFilter.value) params.kind = kindFilter.value
    if (onlyUnhandled.value) params.handled = 'false'
    const [list, st] = await Promise.all([feedback(params), feedbackStats()])
    rows.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load feedback' }
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
  loadCustomers()
  form.comment = ''
  form.channel = ''
  form.score = 9
  formDialog.value = true
}

async function save() {
  saving.value = true
  try {
    const body = {
      customer: form.customer || null,
      kind: form.kind,
      score: Number(form.score) || 0,
      channel: form.channel,
      comment: form.comment,
      submitted_at: new Date().toISOString(),
    }
    await $api.post('/crm/feedback/', body)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Feedback recorded' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to save feedback' }
  } finally {
    saving.value = false
  }
}

async function handle(f) {
  try {
    await $api.patch(`/crm/feedback/${f.id}/`, { handled: true })
    snack.value = { show: true, color: 'success', text: 'Marked as handled' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to update feedback' }
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-search { flex: 1 1 280px; max-width: 420px; }
.crm-select { width: 160px; }
.crm-nps-value { font-size: 30px; font-weight: 800; line-height: 1.1; }
.crm-nps-legend { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.crm-nps-tile { border-radius: 12px; padding: 9px 6px; text-align: center; border: 1px solid rgba(var(--v-border-color), .14); }
.crm-nps--good { background: rgba(16,185,129,.08); border-color: rgba(16,185,129,.24); }
.crm-nps--mid { background: rgba(245,158,11,.08); border-color: rgba(245,158,11,.24); }
.crm-nps--bad { background: rgba(239,68,68,.08); border-color: rgba(239,68,68,.24); }
.crm-nps-n { font-size: 18px; font-weight: 800; line-height: 1.1; }
.crm-nps-l { font-size: 9.5px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-kv { display: flex; align-items: center; justify-content: space-between; padding: 4px 0; font-size: 13px; }
.crm-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.crm-fb { display: flex; gap: 12px; padding: 10px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); align-items: flex-start; }
.crm-fb:last-child { border-bottom: none; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
