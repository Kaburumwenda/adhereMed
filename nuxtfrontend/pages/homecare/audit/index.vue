<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Audit Log"
      subtitle="Compliance trail of every action taken in your homecare workspace."
      eyebrow="COMPLIANCE"
      icon="mdi-history"
      :chips="[{ icon: 'mdi-shield-check', label: 'HIPAA / GDPR ready' }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-download"
               class="text-none" @click="exportCsv">
          <span class="text-teal-darken-2 font-weight-bold">Export CSV</span>
        </v-btn>
      </template>
    </HomecareHero>

    <HomecarePanel title="Recent activity" subtitle="Filter by user, resource or action"
                   icon="mdi-format-list-bulleted" color="#475569">
      <v-row dense>
        <v-col cols="12" md="4"><v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search…" density="compact" variant="outlined" hide-details /></v-col>
        <v-col cols="12" md="4"><v-select v-model="filterAction" :items="actionList" label="Action" density="compact" variant="outlined" hide-details clearable /></v-col>
        <v-col cols="12" md="4"><v-text-field v-model="filterDate" type="date" label="On date" density="compact" variant="outlined" hide-details clearable /></v-col>
      </v-row>
      <v-timeline density="compact" side="end" line-thickness="2" line-color="grey-lighten-2" class="mt-3">
        <v-timeline-item v-for="e in filteredEvents" :key="e.id" size="small" :dot-color="actionColor(e.action)">
          <template #icon>
            <v-icon :icon="actionIcon(e.action)" color="white" size="14" />
          </template>
          <div class="d-flex flex-wrap align-center ga-2">
            <span class="text-body-2 font-weight-bold">{{ e.action }}</span>
            <v-chip size="x-small" variant="tonal" color="grey">{{ e.resource_type }}</v-chip>
            <span class="text-caption text-medium-emphasis">by {{ e.actor_name || 'system' }}</span>
            <v-spacer />
            <span class="text-caption text-medium-emphasis">{{ formatDate(e.created_at) }}</span>
          </div>
          <div v-if="e.summary" class="text-caption text-medium-emphasis">{{ e.summary }}</div>
        </v-timeline-item>
      </v-timeline>
      <EmptyState v-if="!filteredEvents.length" icon="mdi-history" title="No audit entries"
                  message="Start using the system to populate this log." />
    </HomecarePanel>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const events = ref([])
const search = ref('')
const filterAction = ref(null)
const filterDate = ref(null)
const actionList = ['create', 'update', 'delete', 'view', 'login', 'export', 'consent_grant', 'consent_revoke']

const filteredEvents = computed(() => {
  const q = (search.value || '').toLowerCase()
  return events.value.filter(e => {
    if (filterAction.value && e.action !== filterAction.value) return false
    if (filterDate.value && (e.created_at || '').slice(0,10) !== filterDate.value) return false
    if (q) {
      const blob = `${e.action} ${e.resource_type} ${e.actor_name} ${e.summary}`.toLowerCase()
      if (!blob.includes(q)) return false
    }
    return true
  })
})

function actionIcon(a) {
  return { create: 'mdi-plus', update: 'mdi-pencil', delete: 'mdi-delete',
    view: 'mdi-eye', login: 'mdi-login', export: 'mdi-download',
    consent_grant: 'mdi-check', consent_revoke: 'mdi-cancel' }[a] || 'mdi-circle'
}
function actionColor(a) {
  return { create: 'success', update: 'info', delete: 'error',
    view: 'grey', login: 'teal', export: 'amber',
    consent_grant: 'success', consent_revoke: 'error' }[a] || 'grey'
}
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }
function exportCsv() {
  const rows = [['When','Actor','Action','Resource','Summary'],
    ...filteredEvents.value.map(e => [e.created_at, e.actor_name, e.action, e.resource_type, e.summary])]
  const csv = rows.map(r => r.map(c => `"${(c ?? '').toString().replace(/"/g,'""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob); a.download = `audit-${Date.now()}.csv`; a.click()
}

async function load() {
  try {
    const { data } = await $api.get('/homecare/audit-events/', { params: { ordering: '-created_at' } })
    const raw = data?.results || data || []
    events.value = raw.map(e => ({
      id: e.id,
      action: e.action,
      resource_type: e.object_type,
      actor_name: e.actor_email || (e.actor_user_id ? `user#${e.actor_user_id}` : 'system'),
      summary: `${(e.method || '').toUpperCase()} ${e.path || ''}${e.object_id ? ' → #' + e.object_id : ''}`,
      created_at: e.created_at,
    }))
  } catch { events.value = [] }
}
onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
</style>
