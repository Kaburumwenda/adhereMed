<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Audit Trail" subtitle="System audit log and activity tracking"
      icon="mdi-shield-search" color="grey-darken-1">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="loading" @click="load">Refresh</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-tray-arrow-down"
          :disabled="!events.length" @click="exportCsv">Export CSV</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="searchLocal" prepend-inner-icon="mdi-magnify"
            placeholder="Search activity, resource, description…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="userFilter" :items="userOptions"
            label="User" variant="outlined" density="compact"
            hide-details clearable />
        </v-col>
        <v-col cols="12" md="2">
          <v-select v-model="actionFilter" :items="actionOptions"
            label="Action" variant="outlined" density="compact"
            hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-text-field v-model="dateFrom" type="date" label="From"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="1">
          <v-text-field v-model="dateTo" type="date" label="To"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
      </v-row>
      <div v-if="activeFilters" class="px-1 pt-2 d-flex flex-wrap ga-2">
        <v-btn size="small" variant="text" class="text-none"
          prepend-icon="mdi-filter-remove" @click="clearFilters">Clear all</v-btn>
      </div>
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="loading" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="grey-darken-1" size="48" />
      </div>

      <div v-else-if="endpointError" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-shield-off</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">Audit logs endpoint not configured</div>
        <div class="text-body-2 text-medium-emphasis mb-2">
          No audit log endpoint is available for this workspace.
        </div>
        <div class="text-caption text-medium-emphasis">
          Configure <code>/audit/logs/</code> or <code>/homecare/audit-events/</code> to start tracking activity.
        </div>
      </div>

      <div v-else-if="!filteredEvents.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-shield-search</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No audit entries found</div>
        <div class="text-body-2 text-medium-emphasis">
          {{ activeFilters ? 'Try adjusting your filters.' : 'Activity will appear here once recorded.' }}
        </div>
      </div>

      <v-data-table v-else
        :headers="headers"
        :items="filteredEvents"
        :items-per-page="25"
        item-value="id"
        hover
        class="audit-table">
        <template #item.created_at="{ value }">{{ formatDateTime(value) }}</template>
        <template #item.actor="{ item }">
          {{ actorName(item) || '—' }}
        </template>
        <template #item.action="{ value }">
          <v-chip size="small" :color="actionColor(value)" variant="tonal"
            class="text-capitalize font-weight-medium">
            <v-icon start size="14">{{ actionIcon(value) }}</v-icon>
            {{ value || '—' }}
          </v-chip>
        </template>
        <template #item.resource="{ item }">
          {{ item.object_type || item.resource_type || item.resource || '—' }}
          <span v-if="item.object_id" class="text-caption text-medium-emphasis"> #{{ item.object_id }}</span>
        </template>
        <template #item.description="{ item }">
          <span v-if="item.object_repr || item.description"
            class="text-truncate d-inline-block" style="max-width: 260px">
            {{ item.object_repr || item.description }}
          </span>
          <span v-else-if="item.path" class="text-body-2 text-medium-emphasis">
            {{ (item.method || '') + ' ' }}{{ item.path }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.ip="{ value }">
          <span v-if="value" class="text-body-2 font-monospace">{{ value }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
      </v-data-table>
    </v-card>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const ns = '/clinics'

const loading = ref(false)
const events = ref([])
const endpointError = ref(false)
const searchLocal = ref('')
const userFilter = ref(null)
const actionFilter = ref(null)
const dateFrom = ref('')
const dateTo = ref('')

const actionOptions = ['create', 'update', 'delete', 'login', 'logout']

const headers = [
  { title: 'Timestamp', key: 'created_at', width: 170 },
  { title: 'User', key: 'actor', width: 180 },
  { title: 'Action', key: 'action', width: 130 },
  { title: 'Resource', key: 'resource', width: 170 },
  { title: 'Description', key: 'description' },
  { title: 'IP', key: 'ip', width: 140 },
]

const activeFilters = computed(() =>
  searchLocal.value || userFilter.value || actionFilter.value || dateFrom.value || dateTo.value,
)

function clearFilters() {
  searchLocal.value = ''
  userFilter.value = null
  actionFilter.value = null
  dateFrom.value = ''
  dateTo.value = ''
}

const userOptions = computed(() => {
  const set = new Map()
  events.value.forEach(e => {
    const id = e.actor_user_id || e.actor_email
    const name = actorName(e)
    if (id || name) {
      if (!set.has(id || name)) set.set(id || name, { title: name || id, value: id || name })
    }
  })
  return Array.from(set.values())
})

function actorName(e) {
  return e.actor_email || e.actor_name || (e.actor_user_id ? `user#${e.actor_user_id}` : '') || ''
}

const filteredEvents = computed(() => {
  let list = events.value
  if (userFilter.value) list = list.filter(e => (e.actor_user_id || e.actor_email) === userFilter.value)
  if (actionFilter.value) list = list.filter(e => e.action === actionFilter.value)
  if (dateFrom.value) list = list.filter(e => (e.created_at || '').slice(0, 10) >= dateFrom.value)
  if (dateTo.value) list = list.filter(e => (e.created_at || '').slice(0, 10) <= dateTo.value)
  const q = (searchLocal.value || '').toLowerCase()
  if (q) {
    list = list.filter(e =>
      (e.action || '').toLowerCase().includes(q) ||
      (actorName(e) || '').toLowerCase().includes(q) ||
      (e.object_type || '').toLowerCase().includes(q) ||
      (e.object_repr || e.description || '').toLowerCase().includes(q) ||
      (e.path || '').toLowerCase().includes(q),
    )
  }
  return list
})

function actionColor(a) {
  const map = {
    create: 'success', update: 'info', delete: 'error',
    login: 'teal', logout: 'grey', export: 'amber',
    view: 'grey', consent_grant: 'success', consent_revoke: 'error',
  }
  return map[a] || 'grey'
}

function actionIcon(a) {
  const map = {
    create: 'mdi-plus', update: 'mdi-pencil', delete: 'mdi-delete',
    login: 'mdi-login', logout: 'mdi-logout', export: 'mdi-download',
    view: 'mdi-eye', consent_grant: 'mdi-check', consent_revoke: 'mdi-cancel',
  }
  return map[a] || 'mdi-circle-medium'
}

async function load() {
  loading.value = true
  endpointError.value = false
  try {
    let data
    let endpoint = '/audit/logs/'
    try {
      const res = await $api.get(endpoint, { params: { page_size: 1000, ordering: '-created_at' } })
      data = res.data
    } catch {
      // Fallback to tenant homecare audit-events
      try {
        endpoint = '/homecare/audit-events/'
        const res = await $api.get(endpoint, { params: { page_size: 1000, ordering: '-created_at' } })
        data = res.data
      } catch {
        // No endpoint available
        events.value = []
        endpointError.value = true
        return
      }
    }
    events.value = Array.isArray(data) ? data : (data?.results || [])
  } catch (e) {
    endpointError.value = true
    events.value = []
  } finally {
    loading.value = false
  }
}

function exportCsv() {
  const rows = filteredEvents.value
  if (!rows.length) return
  const cols = ['Timestamp', 'User', 'Action', 'Resource', 'Description', 'IP']
  const header = cols.join(',')
  const body = rows.map(e => [
    e.created_at || '',
    `"${(actorName(e) || '').replace(/"/g, '""')}"`,
    e.action || '',
    `${e.object_type || e.resource_type || ''}${e.object_id ? '#' + e.object_id : ''}`,
    `"${(e.object_repr || e.description || `${e.method || ''} ${e.path || ''}` || '').replace(/"/g, '""')}"`,
    e.ip || '',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `clinic_audit_log_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const snack = reactive({ show: false, color: 'success', text: '' })

onMounted(load)
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
