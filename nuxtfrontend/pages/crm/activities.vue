<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-history"
      eyebrow="IMS · CUSTOMER CRM · ACTIVITY"
      title="Activities & Follow-ups"
      subtitle="Every call, email, meeting and note — plus the tasks that keep relationships moving."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-glass" prepend-icon="mdi-checkbox-marked-circle-outline" to="/ims/crm/tasks">
          Tasks
        </v-btn>
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openLog">
          Log activity
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="3">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense>
      <!-- timeline -->
      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex flex-wrap align-center ga-3 pa-3">
            <v-text-field
              v-model="search"
              placeholder="Search subject, notes, customer…"
              prepend-inner-icon="mdi-magnify"
              density="comfortable" variant="solo-filled" rounded="lg" flat bg-color="surface"
              hide-details clearable class="crm-search"
              @keyup.enter="load" @click:clear="load"
            />
            <v-select v-model="kindFilter" :items="kindOptions" item-title="label" item-value="value" label="Type" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
          </div>
          <v-divider />
          <v-card-text v-if="rows.length" class="pt-3">
            <div v-for="i in rows" :key="i.id" class="crm-timeline-item">
              <div class="crm-timeline-dot" :style="{ background: interactionColor(i.kind) }">
                <v-icon size="13" color="white">{{ interactionIcon(i.kind) }}</v-icon>
              </div>
              <div class="flex-grow-1">
                <div class="d-flex align-center justify-space-between ga-2 flex-wrap">
                  <span class="text-body-2 font-weight-medium">{{ i.subject }}</span>
                  <span class="text-caption text-medium-emphasis">{{ dt(i.occurred_at) }}</span>
                </div>
                <div class="text-caption text-medium-emphasis">
                  <span class="font-weight-medium">{{ i.customer_name }}</span> ·
                  {{ interactionLabel(i.kind) }} · {{ titleCase(i.direction) }} · {{ titleCase(i.outcome) }}
                </div>
                <div v-if="i.summary" class="text-body-2 mt-1">{{ i.summary }}</div>
                <v-chip v-if="i.follow_up_required" size="x-small" variant="tonal" color="amber" class="mt-1">
                  <v-icon start size="11">mdi-clock-outline</v-icon>Follow-up {{ dt(i.follow_up_at) }}
                </v-chip>
              </div>
            </div>
          </v-card-text>
          <div v-else class="crm-empty pa-8">
            <v-icon size="42" color="medium-emphasis">mdi-history</v-icon>
            <div class="text-body-2 font-weight-medium mt-2">No activity logged</div>
            <div class="text-caption text-medium-emphasis">Record a call, email or meeting to build the timeline.</div>
          </div>
        </v-card>
      </v-col>

      <!-- follow-ups -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="mb-3">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="amber">mdi-clock-alert-outline</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Follow-ups</div>
              <div class="text-caption text-medium-emphasis">{{ statsData.overdue_follow_ups ?? 0 }} overdue · {{ statsData.follow_ups_open ?? 0 }} upcoming</div>
            </div>
          </div>
          <v-divider />
          <v-card-text v-if="followUps.length" class="pt-3">
            <div v-for="i in followUps" :key="i.id" class="crm-task-row">
              <v-icon size="16" color="amber">mdi-clock-outline</v-icon>
              <div class="flex-grow-1">
                <div class="text-body-2 font-weight-medium">{{ i.subject }}</div>
                <div class="text-caption text-medium-emphasis">{{ i.customer_name }} · {{ dt(i.follow_up_at) }}</div>
              </div>
              <v-btn icon="mdi-check" size="x-small" variant="text" color="success" title="Mark handled" @click="clearFollowUp(i)" />
            </div>
          </v-card-text>
          <div v-else class="crm-empty pa-5">
            <v-icon size="30" color="success">mdi-check-decagram</v-icon>
            <div class="text-caption text-medium-emphasis mt-1">No follow-ups outstanding</div>
          </div>
        </v-card>

        <v-card rounded="xl" border>
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="primary">mdi-chart-donut</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Activity mix</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="row in kindRows" :key="row.key" class="mb-2">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="d-flex align-center ga-1"><v-icon size="13" :color="row.color">{{ row.icon }}</v-icon>{{ row.label }}</span>
                <span class="font-weight-medium">{{ row.count }}</span>
              </div>
              <v-progress-linear :model-value="row.pct" :color="row.color" height="6" rounded bg-color="surface-variant" />
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- log dialog -->
    <v-dialog v-model="logDialog" max-width="560">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-plus"
          title="Log activity"
          subtitle="Capture a customer touchpoint"
          @close="logDialog = false"
        />
        <v-card-text>
          <v-select v-model="form.customer" :items="customerOptions" item-title="label" item-value="id" label="Customer *" variant="outlined" density="comfortable" class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="form.kind" :items="kindOptions" item-title="label" item-value="value" label="Type" variant="outlined" density="comfortable" />
            <v-select v-model="form.direction" :items="directions" item-title="label" item-value="value" label="Direction" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="form.subject" label="Subject *" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="form.summary" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" class="mb-2" />
          <v-select v-model="form.outcome" :items="outcomes" item-title="label" item-value="value" label="Outcome" variant="outlined" density="comfortable" class="mb-2" />
          <v-switch v-model="form.follow_up_required" color="primary" density="compact" hide-details label="Schedule follow-up" class="mb-2" />
          <v-text-field v-if="form.follow_up_required" v-model="form.follow_up_at" type="datetime-local" label="Follow-up at" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="logDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="save">Save activity</v-btn>
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
const { interactions, interactionStats, customers, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const statsData = ref({})
const search = ref('')
const kindFilter = ref(null)
const customerOptions = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const logDialog = ref(false)

const form = reactive({
  customer: null, kind: 'call', direction: 'outbound', subject: '',
  summary: '', outcome: 'connected', follow_up_required: false, follow_up_at: '',
})

const kindOptions = [
  { value: 'call', label: 'Phone call' }, { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' }, { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'meeting', label: 'Meeting' }, { value: 'visit', label: 'Site visit' },
  { value: 'note', label: 'Note' }, { value: 'complaint', label: 'Complaint' },
]
const directions = [
  { value: 'inbound', label: 'Inbound' }, { value: 'outbound', label: 'Outbound' },
  { value: 'internal', label: 'Internal' },
]
const outcomes = [
  { value: 'connected', label: 'Connected' }, { value: 'no_answer', label: 'No answer' },
  { value: 'left_message', label: 'Left message' }, { value: 'resolved', label: 'Resolved' },
  { value: 'follow_up', label: 'Follow-up required' }, { value: 'no_action', label: 'No action' },
]

const META = {
  call: { label: 'Phone call', icon: 'mdi-phone-outline', color: 'blue', hex: '#2563eb' },
  email: { label: 'Email', icon: 'mdi-email-outline', color: 'indigo', hex: '#4f46e5' },
  sms: { label: 'SMS', icon: 'mdi-message-text-outline', color: 'cyan', hex: '#0891b2' },
  whatsapp: { label: 'WhatsApp', icon: 'mdi-whatsapp', color: 'success', hex: '#16a34a' },
  meeting: { label: 'Meeting', icon: 'mdi-account-group-outline', color: 'purple', hex: '#7c3aed' },
  visit: { label: 'Site visit', icon: 'mdi-map-marker-outline', color: 'teal', hex: '#0d9488' },
  note: { label: 'Note', icon: 'mdi-note-text-outline', color: 'grey', hex: '#64748b' },
  complaint: { label: 'Complaint', icon: 'mdi-alert-outline', color: 'error', hex: '#dc2626' },
}

function interactionLabel(k) { return META[k]?.label || k }
function interactionIcon(k) { return META[k]?.icon || 'mdi-note-outline' }
function interactionColor(k) { return META[k]?.hex || '#64748b' }

const heroFacts = computed(() => [
  { value: statsData.value.total ?? 0, label: 'activities' },
  { value: statsData.value.this_week ?? 0, label: 'this week' },
  { value: statsData.value.follow_ups_open ?? 0, label: 'follow-ups' },
  { value: statsData.value.overdue_follow_ups ?? 0, label: 'overdue' },
])

const kpis = computed(() => [
  { title: 'Total activity', value: statsData.value.total ?? 0, sub: 'all time', icon: 'mdi-history', color: 'primary' },
  { title: 'This week', value: statsData.value.this_week ?? 0, sub: 'last 7 days', icon: 'mdi-calendar-week-outline', color: 'success' },
  { title: 'Upcoming follow-ups', value: statsData.value.follow_ups_open ?? 0, sub: 'scheduled', icon: 'mdi-clock-outline', color: 'info' },
  { title: 'Overdue', value: statsData.value.overdue_follow_ups ?? 0, sub: 'need action', icon: 'mdi-clock-alert-outline', color: 'error' },
])

const followUps = computed(() =>
  rows.value.filter((i) => i.follow_up_required).slice(0, 8))

const kindRows = computed(() => {
  const by = statsData.value.by_kind || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0) || 1
  return Object.entries(META).map(([key, m]) => ({
    key, label: m.label, icon: m.icon, color: m.color,
    count: by[key] || 0, pct: Math.round(((by[key] || 0) / total) * 100),
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

async function load() {
  loading.value = true
  try {
    const params = { page_size: 300, ordering: '-occurred_at' }
    if (search.value) params.search = search.value
    if (kindFilter.value) params.kind = kindFilter.value
    const [list, st] = await Promise.all([interactions(params), interactionStats()])
    rows.value = unpack(list)
    statsData.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load activity' }
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

function openLog() {
  loadCustomers()
  form.subject = ''
  form.summary = ''
  form.follow_up_required = false
  form.follow_up_at = ''
  logDialog.value = true
}

async function save() {
  if (!form.customer || !form.subject) {
    snack.value = { show: true, color: 'error', text: 'Customer and subject are required' }
    return
  }
  saving.value = true
  try {
    const body = {
      customer: form.customer, kind: form.kind, direction: form.direction,
      subject: form.subject, summary: form.summary, outcome: form.outcome,
      follow_up_required: form.follow_up_required,
      occurred_at: new Date().toISOString(),
    }
    if (form.follow_up_required && form.follow_up_at) body.follow_up_at = new Date(form.follow_up_at).toISOString()
    await $api.post('/crm/interactions/', body)
    logDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Activity logged' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to log activity' }
  } finally {
    saving.value = false
  }
}

async function clearFollowUp(i) {
  try {
    await $api.patch(`/crm/interactions/${i.id}/`, { follow_up_required: false })
    snack.value = { show: true, color: 'success', text: 'Follow-up cleared' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to clear follow-up' }
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-hero-btn-glass { background: rgba(255,255,255,.16) !important; color: #fff !important; font-weight: 600 !important; border: 1px solid rgba(255,255,255,.34) !important; }
.crm-search { flex: 1 1 280px; max-width: 420px; }
.crm-select { width: 160px; }
.crm-timeline-item { display: flex; gap: 12px; padding: 9px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.crm-timeline-item:last-child { border-bottom: none; }
.crm-timeline-dot { width: 26px; height: 26px; border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.crm-task-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.crm-task-row:last-child { border-bottom: none; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
