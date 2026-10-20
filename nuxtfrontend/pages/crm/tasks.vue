<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-checkbox-marked-circle-outline"
      eyebrow="IMS · CUSTOMER CRM · TASKS"
      title="Follow-up Tasks"
      subtitle="Everything the team owes a customer — prioritised, dated and assigned."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New task
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="3">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search task, customer…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable" variant="solo-filled" rounded="lg" flat bg-color="surface"
          hide-details clearable class="crm-search"
          @keyup.enter="load" @click:clear="load"
        />
        <v-select v-model="priorityFilter" :items="priorityOptions" item-title="label" item-value="value" label="Priority" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
        <v-spacer />
        <v-btn-toggle v-model="statusFilter" density="comfortable" rounded="lg" variant="outlined" divided mandatory @update:model-value="load">
          <v-btn value="open" size="small" class="text-none">Open</v-btn>
          <v-btn value="done" size="small" class="text-none">Done</v-btn>
          <v-btn value="all" size="small" class="text-none">All</v-btn>
        </v-btn-toggle>
      </div>
    </v-card>

    <v-card rounded="xl" border>
      <v-table density="comfortable" class="crm-table">
        <thead>
          <tr><th style="width:52px" /><th>Task</th><th>Customer</th><th>Priority</th><th>Due</th><th>Assigned</th><th>Status</th></tr>
        </thead>
        <tbody>
          <tr v-for="t in visible" :key="t.id" :class="t.status === 'done' ? 'text-medium-emphasis' : ''">
            <td>
              <v-checkbox-btn :model-value="t.status === 'done'" color="success" density="compact" hide-details @click="complete(t)" />
            </td>
            <td>
              <div class="font-weight-medium" :class="t.status === 'done' ? 'text-decoration-line-through' : ''">{{ t.title }}</div>
              <div v-if="t.description" class="text-caption text-medium-emphasis">{{ t.description }}</div>
            </td>
            <td>{{ t.customer_name || '—' }}</td>
            <td><v-chip size="x-small" variant="tonal" :color="priorityMeta(t.priority).color">{{ priorityMeta(t.priority).label }}</v-chip></td>
            <td>
              <span :class="isOverdue(t) ? 'text-error font-weight-medium' : ''">{{ dt(t.due_at) }}</span>
              <v-chip v-if="isOverdue(t)" size="x-small" variant="tonal" color="error" class="ml-1">Overdue</v-chip>
            </td>
            <td class="text-caption">{{ t.assigned_to_name || '—' }}</td>
            <td>
              <v-chip size="x-small" variant="tonal" :color="t.status === 'done' ? 'success' : t.status === 'in_progress' ? 'info' : 'grey'">
                {{ titleCase(t.status) }}
              </v-chip>
            </td>
          </tr>
          <tr v-if="!visible.length">
            <td colspan="7">
              <div class="crm-empty pa-8">
                <v-icon size="42" color="medium-emphasis">mdi-checkbox-marked-circle-outline</v-icon>
                <div class="text-body-2 font-weight-medium mt-2">No tasks</div>
                <div class="text-caption text-medium-emphasis">Create a follow-up to keep the team on track.</div>
              </div>
            </td>
          </tr>
        </tbody>
      </v-table>
    </v-card>

    <v-dialog v-model="formDialog" max-width="560">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-plus"
          title="New follow-up task"
          subtitle="Remind yourself to reach out"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-text-field v-model="form.title" label="Title *" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="form.description" label="Description" rows="2" auto-grow variant="outlined" density="comfortable" class="mb-2" />
          <v-select v-model="form.customer" :items="customerOptions" item-title="label" item-value="id" label="Customer (optional)" variant="outlined" density="comfortable" clearable class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="form.priority" :items="priorityOptions" item-title="label" item-value="value" label="Priority" variant="outlined" density="comfortable" />
            <v-text-field v-model="form.due_at" type="datetime-local" label="Due at" variant="outlined" density="comfortable" />
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="save">Create task</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { crmPriority, useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { tasks, taskStats, customers, unpack } = useCrm()
const priorityMeta = crmPriority

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const stats = ref({})
const search = ref('')
const priorityFilter = ref(null)
const statusFilter = ref('open')
const customerOptions = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const formDialog = ref(false)
const form = reactive({ title: '', description: '', customer: null, priority: 'normal', due_at: '' })

const priorityOptions = [
  { value: 'low', label: 'Low' }, { value: 'normal', label: 'Normal' },
  { value: 'high', label: 'High' }, { value: 'urgent', label: 'Urgent' },
]

const heroFacts = computed(() => [
  { value: stats.value.total ?? 0, label: 'tasks' },
  { value: stats.value.todo ?? 0, label: 'to do' },
  { value: stats.value.overdue ?? 0, label: 'overdue' },
  { value: stats.value.done ?? 0, label: 'done' },
])

const kpis = computed(() => [
  { title: 'To do', value: stats.value.todo ?? 0, sub: 'not started', icon: 'mdi-format-list-checks', color: 'grey' },
  { title: 'In progress', value: stats.value.in_progress ?? 0, sub: 'being worked', icon: 'mdi-progress-clock', color: 'info' },
  { title: 'Overdue', value: stats.value.overdue ?? 0, sub: 'need attention', icon: 'mdi-clock-alert-outline', color: 'error' },
  { title: 'Due today', value: stats.value.due_today ?? 0, sub: 'today', icon: 'mdi-calendar-today', color: 'amber' },
])

const visible = computed(() => {
  if (statusFilter.value === 'all') return rows.value
  if (statusFilter.value === 'done') return rows.value.filter((t) => t.status === 'done')
  return rows.value.filter((t) => !['done', 'cancelled'].includes(t.status))
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

function isOverdue(t) {
  if (t.status === 'done' || !t.due_at) return false
  return new Date(t.due_at).getTime() < Date.now()
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 400, ordering: 'due_at' }
    if (search.value) params.search = search.value
    if (priorityFilter.value) params.priority = priorityFilter.value
    const [list, st] = await Promise.all([tasks(params), taskStats()])
    rows.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load tasks' }
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
  form.title = ''
  form.description = ''
  form.customer = null
  form.priority = 'normal'
  form.due_at = ''
  formDialog.value = true
}

async function save() {
  if (!form.title) {
    snack.value = { show: true, color: 'error', text: 'Title is required' }
    return
  }
  saving.value = true
  try {
    const body = {
      title: form.title, description: form.description,
      customer: form.customer || null, priority: form.priority,
    }
    if (form.due_at) body.due_at = new Date(form.due_at).toISOString()
    await $api.post('/crm/tasks/', body)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Task created' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to create task' }
  } finally {
    saving.value = false
  }
}

async function complete(t) {
  if (t.status === 'done') return
  try {
    await $api.post(`/crm/tasks/${t.id}/complete/`)
    snack.value = { show: true, color: 'success', text: 'Task completed' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to complete task' }
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
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
