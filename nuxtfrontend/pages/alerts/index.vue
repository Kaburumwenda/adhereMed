<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="orange-lighten-5" size="48" class="mr-3">
          <v-icon color="orange-darken-2" size="28">mdi-bell-alert</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Alerts &amp; Notifications</h1>
          <div class="text-body-2 text-medium-emphasis">Stay on top of operational events &amp; system messages</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-radar" class="text-none"
                 :loading="scanning" @click="runScan">Scan Inventory</v-btn>
      <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-check-all" class="text-none"
                 :disabled="!unreadCount" :loading="saving" @click="markAllRead">
            Mark all read
          </v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by title or message…"
                        density="comfortable" variant="solo-filled" flat hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="typeFilter" :items="typeItems" label="Type"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="readFilter" :items="readItems" label="Status"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="12" md="2" class="text-right">
          <v-chip color="primary" variant="tonal">{{ filtered.length }} shown</v-chip>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-list lines="three">
        <template v-if="loading">
          <v-list-item v-for="i in 4" :key="i">
            <v-skeleton-loader type="list-item-three-line" />
          </v-list-item>
        </template>
        <template v-else-if="filtered.length">
          <template v-for="n in filtered" :key="n.id">
            <v-list-item :class="!n.is_read ? 'unread-item' : ''">
              <template #prepend>
                <v-avatar :color="typeColor(n.type)" size="40">
                  <v-icon color="white">{{ typeIcon(n.type) }}</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="d-flex align-center">
                <span :class="!n.is_read ? 'font-weight-bold' : ''">{{ n.title }}</span>
                <v-chip v-if="!n.is_read" size="x-small" color="primary" class="ml-2">New</v-chip>
                <v-chip size="x-small" :color="typeColor(n.type)" variant="tonal" class="ml-2 text-capitalize">
                  {{ (n.type || '').replace('_', ' ') }}
                </v-chip>
              </v-list-item-title>
              <v-list-item-subtitle class="text-body-2 mt-1">{{ n.message }}</v-list-item-subtitle>
              <v-list-item-subtitle class="text-caption text-medium-emphasis mt-1">
                {{ formatDateTime(n.created_at) }}
              </v-list-item-subtitle>
              <template #append>
                <v-btn v-if="!n.is_read" icon="mdi-check" variant="text" size="small"
                       color="success" @click="markRead(n)" />
              </template>
            </v-list-item>
            <v-divider />
          </template>
        </template>
        <EmptyState v-else icon="mdi-bell-off-outline" title="No alerts"
                    message="You're all caught up." />
      </v-list>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import EmptyState from '~/components/EmptyState.vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const items = ref([])

async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/notifications/', { params: { page_size: 200 } })
    items.value = data?.results || data || []
  } catch { notify('Failed to load alerts', 'error') }
  finally { loading.value = false }
}
onMounted(loadAll)

const scanning = ref(false)
async function runScan() {
  scanning.value = true
  try {
    const r = await $api.post('/notifications/scan-inventory/', { days: 30 })
    notify(`Scan complete: ${r.data?.output || 'no new alerts'}`, 'success')
    await loadAll()
  } catch { notify('Scan failed', 'error') }
  finally { scanning.value = false }
}

const search = ref('')
const typeFilter = ref('all')
const readFilter = ref('all')
const typeOptions = ['appointment', 'lab_result', 'prescription', 'home_collection', 'billing', 'system']
const typeItems = [{ title: 'All types', value: 'all' },
  ...typeOptions.map(v => ({ title: v.replace('_', ' '), value: v }))]
const readItems = [
  { title: 'All', value: 'all' },
  { title: 'Unread', value: 'unread' },
  { title: 'Read', value: 'read' },
]

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return items.value.filter(n => {
    if (typeFilter.value !== 'all' && n.type !== typeFilter.value) return false
    if (readFilter.value === 'unread' && n.is_read) return false
    if (readFilter.value === 'read' && !n.is_read) return false
    if (!q) return true
    return (n.title || '').toLowerCase().includes(q)
        || (n.message || '').toLowerCase().includes(q)
  })
})

const unreadCount = computed(() => items.value.filter(n => !n.is_read).length)
const todayCount = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return items.value.filter(n => (n.created_at || '').slice(0, 10) === today).length
})
const kpiTiles = computed(() => [
  { label: 'Total', value: items.value.length, icon: 'mdi-bell', color: 'orange-darken-2' },
  { label: 'Unread', value: unreadCount.value, icon: 'mdi-bell-badge', color: 'error' },
  { label: 'Today', value: todayCount.value, icon: 'mdi-calendar-today', color: 'info' },
  { label: 'System', value: items.value.filter(n => n.type === 'system').length,
    icon: 'mdi-cog', color: 'grey' },
])

function typeColor(t) {
  return ({ appointment: 'indigo', lab_result: 'purple', prescription: 'teal',
    home_collection: 'cyan', billing: 'amber-darken-2', system: 'grey' })[t] || 'grey'
}
function typeIcon(t) {
  return ({ appointment: 'mdi-calendar', lab_result: 'mdi-microscope', prescription: 'mdi-pill',
    home_collection: 'mdi-truck', billing: 'mdi-receipt', system: 'mdi-cog' })[t] || 'mdi-bell'
}

async function markRead(n) {
  try {
    await $api.post(`/notifications/${n.id}/mark_read/`)
    n.is_read = true
  } catch (e) { notify(extractError(e) || 'Failed', 'error') }
}
async function markAllRead() {
  saving.value = true
  try {
    await $api.post('/notifications/mark_all_read/')
    items.value.forEach(n => (n.is_read = true))
    notify('All marked as read')
  } catch (e) { notify(extractError(e) || 'Failed', 'error') }
  finally { saving.value = false }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

.unread-item { background: rgba(249, 115, 22, 0.04); }
</style>
