<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-bell-ring</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Notifications</div>
        <div class="text-body-2 text-medium-emphasis">
          Operational alerts, lab events &amp; system messages — all in one inbox
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-radar"
             :loading="scanning" @click="runScan">Scan inventory</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-cog-outline"
             @click="settingsDialog = true">Preferences</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-check-all"
             :disabled="!unreadCount" :loading="saving" @click="markAllRead">
        Mark all read
      </v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3"
                @click="k.filter && (readFilter = k.filter)" style="cursor: pointer">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills -->
    <v-card flat rounded="lg" class="section-pills pa-2 my-3">
      <v-chip-group v-model="tab" mandatory selected-class="text-primary">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                filter variant="tonal" :color="s.color">
          <v-icon size="16" start>{{ s.icon }}</v-icon>{{ s.label }}
          <v-badge v-if="s.value === 'unread' && unreadCount" :content="unreadCount"
                   color="error" inline class="ml-2" />
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- Filters -->
    <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search title or message…" persistent-placeholder
                        variant="outlined" density="compact" rounded="lg"
                        hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="typeFilter" :items="typeItems" label="Type"
                    variant="outlined" density="compact" rounded="lg"
                    persistent-placeholder hide-details>
            <template #selection="{ item }">
              <v-icon size="16" :color="typeColor(item.value)" class="mr-1">{{ typeIcon(item.value) }}</v-icon>
              {{ item.title }}
            </template>
            <template #item="{ item, props }">
              <v-list-item v-bind="props" :prepend-icon="typeIcon(item.value)" />
            </template>
          </v-select>
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="rangeFilter" :items="rangeItems" label="Period"
                    variant="outlined" density="compact" rounded="lg"
                    persistent-placeholder hide-details />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortOrder" :items="sortItems" label="Sort"
                    variant="outlined" density="compact" rounded="lg"
                    persistent-placeholder hide-details />
        </v-col>
        <v-col cols="6" md="1" class="text-right">
          <v-chip color="indigo" variant="tonal" rounded="lg">{{ filtered.length }}</v-chip>
        </v-col>
      </v-row>
      <div v-if="selectedIds.length" class="d-flex align-center ga-2 mt-3">
        <v-chip color="indigo" variant="flat" size="small">
          {{ selectedIds.length }} selected
        </v-chip>
        <v-btn size="small" variant="text" prepend-icon="mdi-check"
               @click="bulkMarkRead(true)">Mark read</v-btn>
        <v-btn size="small" variant="text" prepend-icon="mdi-email-mark-as-unread"
               @click="bulkMarkRead(false)">Mark unread</v-btn>
        <v-spacer />
        <v-btn size="small" variant="text" color="error" prepend-icon="mdi-delete"
               @click="bulkDelete">Delete</v-btn>
        <v-btn size="small" variant="text" @click="selectedIds = []">Clear</v-btn>
      </div>
    </v-card>

    <!-- Body -->
    <v-row v-if="loading" justify="center" class="my-12">
      <v-progress-circular indeterminate color="primary" size="40" />
    </v-row>

    <v-card v-else-if="!filtered.length" flat rounded="lg" class="pa-12 text-center section-card">
      <v-icon size="64" color="grey-lighten-1">mdi-bell-off-outline</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">You're all caught up</div>
      <div class="text-body-2 text-medium-emphasis">
        No notifications match the current filters.
      </div>
    </v-card>

    <template v-else>
      <!-- Inbox / Unread / Read tabs (grouped by day) -->
      <template v-if="tab !== 'types'">
        <div v-for="grp in grouped" :key="grp.label" class="mb-4">
          <div class="d-flex align-center mb-2">
            <div class="text-overline text-medium-emphasis">{{ grp.label }}</div>
            <v-divider class="ml-3" />
            <v-chip size="x-small" variant="tonal" class="ml-3">{{ grp.items.length }}</v-chip>
          </div>
          <v-card flat rounded="lg" class="section-card">
            <v-list lines="three" class="py-0">
              <template v-for="(n, i) in grp.items" :key="n.id">
                <v-list-item :class="['notif-row', !n.is_read && 'unread-item']"
                             @click="openDetail(n)">
                  <template #prepend>
                    <div class="d-flex align-center">
                      <v-checkbox-btn :model-value="selectedIds.includes(n.id)"
                                      density="compact" hide-details class="mr-1"
                                      @update:model-value="toggleSelect(n.id)"
                                      @click.stop />
                      <v-avatar :color="typeColor(n.type) + '-lighten-5'" size="42" class="ml-1">
                        <v-icon :color="typeColor(n.type) + '-darken-2'" size="22">
                          {{ typeIcon(n.type) }}
                        </v-icon>
                      </v-avatar>
                    </div>
                  </template>
                  <v-list-item-title class="d-flex align-center flex-wrap ga-1">
                    <span :class="!n.is_read ? 'font-weight-bold' : ''">{{ n.title }}</span>
                    <v-chip v-if="!n.is_read" size="x-small" color="error" variant="flat" class="ml-2">
                      New
                    </v-chip>
                    <v-chip size="x-small" :color="typeColor(n.type)" variant="tonal" class="ml-1 text-capitalize">
                      {{ typeLabel(n.type) }}
                    </v-chip>
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-body-2 mt-1 text-truncate-2">
                    {{ n.message }}
                  </v-list-item-subtitle>
                  <v-list-item-subtitle class="text-caption text-medium-emphasis mt-1">
                    <v-icon size="12">mdi-clock-outline</v-icon>
                    {{ relativeTime(n.created_at) }}
                    <span class="text-disabled"> · {{ formatDateTime(n.created_at) }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-btn v-if="!n.is_read" icon size="small" variant="text" color="success"
                           @click.stop="markRead(n, true)">
                      <v-icon size="20">mdi-check</v-icon>
                      <v-tooltip activator="parent" location="top">Mark as read</v-tooltip>
                    </v-btn>
                    <v-btn v-else icon size="small" variant="text"
                           @click.stop="markRead(n, false)">
                      <v-icon size="20">mdi-email-mark-as-unread</v-icon>
                      <v-tooltip activator="parent" location="top">Mark as unread</v-tooltip>
                    </v-btn>
                    <v-menu>
                      <template #activator="{ props }">
                        <v-btn v-bind="props" icon size="small" variant="text" @click.stop>
                          <v-icon size="20">mdi-dots-vertical</v-icon>
                        </v-btn>
                      </template>
                      <v-list density="compact">
                        <v-list-item @click="openDetail(n)" prepend-icon="mdi-eye" title="View details" />
                        <v-list-item v-if="goToLink(n)" @click="follow(n)"
                                     prepend-icon="mdi-arrow-right-circle" title="Open source" />
                        <v-list-item @click="copyText(n)"
                                     prepend-icon="mdi-content-copy" title="Copy" />
                        <v-divider />
                        <v-list-item @click="confirmDelete(n)"
                                     prepend-icon="mdi-delete" base-color="error" title="Delete" />
                      </v-list>
                    </v-menu>
                  </template>
                </v-list-item>
                <v-divider v-if="i < grp.items.length - 1" />
              </template>
            </v-list>
          </v-card>
        </div>
      </template>

      <!-- By type tab — grouped by notification type -->
      <template v-else>
        <v-row dense>
          <v-col v-for="g in byType" :key="g.type" cols="12" md="6" lg="4">
            <v-card flat rounded="lg" class="section-card pa-3 h-100">
              <div class="d-flex align-center mb-2">
                <v-avatar :color="typeColor(g.type) + '-lighten-5'" size="36" class="mr-2">
                  <v-icon :color="typeColor(g.type) + '-darken-2'" size="20">{{ typeIcon(g.type) }}</v-icon>
                </v-avatar>
                <div class="min-width-0">
                  <div class="font-weight-bold text-truncate">{{ typeLabel(g.type) }}</div>
                  <div class="text-caption text-medium-emphasis">
                    {{ g.items.length }} total · {{ g.unread }} unread
                  </div>
                </div>
                <v-spacer />
                <v-btn size="small" variant="text" color="indigo"
                       @click="typeFilter = g.type; tab = 'inbox'">
                  Open
                </v-btn>
              </div>
              <v-divider class="mb-2" />
              <v-list density="compact" class="py-0">
                <v-list-item v-for="n in g.items.slice(0, 4)" :key="n.id"
                             class="px-0" @click="openDetail(n)">
                  <v-list-item-title class="text-body-2"
                                     :class="!n.is_read ? 'font-weight-bold' : ''">
                    {{ n.title }}
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    {{ relativeTime(n.created_at) }}
                  </v-list-item-subtitle>
                </v-list-item>
                <v-list-item v-if="!g.items.length" class="px-0">
                  <v-list-item-subtitle class="text-caption text-disabled">
                    Nothing yet
                  </v-list-item-subtitle>
                </v-list-item>
              </v-list>
            </v-card>
          </v-col>
        </v-row>
      </template>
    </template>

    <!-- Detail drawer -->
    <v-navigation-drawer v-model="detailDrawer" location="right" temporary
                         width="460" class="detail-drawer">
      <div v-if="detail" class="pa-4">
        <div class="d-flex align-center mb-3">
          <v-avatar :color="typeColor(detail.type) + '-lighten-5'" size="48" class="mr-3">
            <v-icon :color="typeColor(detail.type) + '-darken-2'" size="26">
              {{ typeIcon(detail.type) }}
            </v-icon>
          </v-avatar>
          <div class="min-width-0 flex-grow-1">
            <div class="text-overline text-medium-emphasis">
              <v-chip size="x-small" :color="typeColor(detail.type)" variant="tonal" class="mr-1">
                {{ typeLabel(detail.type) }}
              </v-chip>
              <v-chip v-if="!detail.is_read" size="x-small" color="error" variant="flat">New</v-chip>
            </div>
            <div class="text-h6 font-weight-bold">{{ detail.title }}</div>
          </div>
          <v-btn icon variant="text" size="small" @click="detailDrawer = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </div>
        <v-divider class="mb-3" />
        <div class="text-body-1 mb-4" style="white-space: pre-wrap">{{ detail.message }}</div>
        <div class="text-caption text-medium-emphasis mb-3">
          <v-icon size="14">mdi-clock-outline</v-icon>
          {{ formatDateTime(detail.created_at) }}
          <span class="ml-2">· {{ relativeTime(detail.created_at) }}</span>
        </div>

        <v-card v-if="detail.data && Object.keys(detail.data).length" flat
                rounded="lg" class="notes-card pa-3 mb-3">
          <div class="text-overline text-medium-emphasis mb-2">
            <v-icon size="14">mdi-database</v-icon> Context data
          </div>
          <div v-for="[k, v] in Object.entries(detail.data)" :key="k"
               class="d-flex py-1 text-body-2">
            <div class="font-weight-medium" style="min-width: 110px">{{ k }}:</div>
            <div class="text-medium-emphasis text-truncate">{{ formatVal(v) }}</div>
          </div>
        </v-card>

        <div class="d-flex flex-wrap ga-2">
          <v-btn v-if="goToLink(detail)" color="primary" rounded="lg"
                 prepend-icon="mdi-arrow-right-circle" @click="follow(detail)">
            Open source
          </v-btn>
          <v-btn variant="outlined" rounded="lg"
                 :prepend-icon="detail.is_read ? 'mdi-email-mark-as-unread' : 'mdi-check'"
                 @click="markRead(detail, !detail.is_read)">
            {{ detail.is_read ? 'Mark unread' : 'Mark read' }}
          </v-btn>
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-content-copy"
                 @click="copyText(detail)">Copy</v-btn>
          <v-spacer />
          <v-btn variant="text" color="error" rounded="lg" prepend-icon="mdi-delete"
                 @click="confirmDelete(detail)">Delete</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- Preferences dialog -->
    <v-dialog v-model="settingsDialog" max-width="540" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">mdi-cog-outline</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Preferences</div>
            <div class="text-h6 font-weight-bold">Notification preferences</div>
          </div>
          <v-spacer />
          <v-btn icon variant="text" size="small" @click="settingsDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <div class="text-overline text-medium-emphasis mb-1">In-app behaviour</div>
          <v-switch v-model="prefs.autoRefresh" inset density="compact" hide-details
                    color="indigo" label="Auto-refresh inbox every 60s" class="mb-1" />
          <v-switch v-model="prefs.desktop" inset density="compact" hide-details
                    color="indigo" label="Show desktop notifications (browser permission)"
                    @update:model-value="onDesktopToggle" class="mb-1" />
          <v-switch v-model="prefs.sound" inset density="compact" hide-details
                    color="indigo" label="Play sound on new notifications" />
          <v-divider class="my-3" />
          <div class="text-overline text-medium-emphasis mb-1">Mute categories</div>
          <div class="text-caption text-medium-emphasis mb-2">
            Muted categories stay in the inbox but won't trigger pop-ups or sound.
          </div>
          <v-row dense>
            <v-col v-for="opt in typeOptions" :key="opt" cols="12" sm="6">
              <v-switch v-model="prefs.muted" :value="opt" inset density="compact"
                        hide-details color="grey-darken-1">
                <template #label>
                  <v-icon size="16" :color="typeColor(opt)" class="mr-1">{{ typeIcon(opt) }}</v-icon>
                  {{ typeLabel(opt) }}
                </template>
              </v-switch>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="settingsDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 @click="savePrefs">Save preferences</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="440" persistent>
      <v-card v-if="deleteTarget" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="error-lighten-5" size="40" class="mr-3">
            <v-icon color="error">mdi-delete-alert</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Confirm delete</div>
            <div class="text-h6 font-weight-bold">Delete notification?</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <strong>{{ deleteTarget.title }}</strong> will be permanently removed.
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" prepend-icon="mdi-delete"
                 :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const router = useRouter()

// ── State ───────────────────────────────────────────────
const loading = ref(false)
const saving = ref(false)
const scanning = ref(false)
const items = ref([])

const tab = ref('inbox')
const search = ref('')
const typeFilter = ref('all')
const readFilter = ref('all')
const rangeFilter = ref('30')
const sortOrder = ref('newest')
const selectedIds = ref([])

const sectionPills = [
  { value: 'inbox',  label: 'Inbox',   color: 'indigo',         icon: 'mdi-inbox' },
  { value: 'unread', label: 'Unread',  color: 'error',          icon: 'mdi-bell-badge' },
  { value: 'types',  label: 'By type', color: 'teal',           icon: 'mdi-tag-multiple' },
]

const typeOptions = [
  'appointment', 'lab_result', 'prescription', 'home_collection', 'billing',
  'system', 'dose_reminder', 'dose_missed', 'escalation', 'teleconsult',
  'insurance_claim', 'caregiver_update', 'stock_alert', 'consent',
]
const typeItems = [
  { title: 'All types', value: 'all' },
  ...typeOptions.map(v => ({ title: typeLabel(v), value: v })),
]
const rangeItems = [
  { title: 'Last 24 hours', value: '1' },
  { title: 'Last 7 days',   value: '7' },
  { title: 'Last 30 days',  value: '30' },
  { title: 'Last 90 days',  value: '90' },
  { title: 'All time',      value: 'all' },
]
const sortItems = [
  { title: 'Newest first', value: 'newest' },
  { title: 'Oldest first', value: 'oldest' },
  { title: 'Unread first', value: 'unread' },
]

// ── Loading ─────────────────────────────────────────────
async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/notifications/', { params: { page_size: 500 } })
    items.value = data?.results || data || []
  } catch (e) {
    notify(extractError(e) || 'Failed to load notifications', 'error')
  } finally { loading.value = false }
}
onMounted(() => {
  loadPrefs()
  loadAll()
  if (prefs.autoRefresh) startTimer()
})
onBeforeUnmount(stopTimer)

// ── Filters ─────────────────────────────────────────────
const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  const since = rangeFilter.value === 'all'
    ? null
    : Date.now() - parseInt(rangeFilter.value, 10) * 86400000
  let out = items.value.filter(n => {
    if (tab.value === 'unread' && n.is_read) return false
    if (readFilter.value === 'unread' && n.is_read) return false
    if (readFilter.value === 'read' && !n.is_read) return false
    if (typeFilter.value !== 'all' && n.type !== typeFilter.value) return false
    if (since && new Date(n.created_at).getTime() < since) return false
    if (!q) return true
    return [n.title, n.message].some(v => (v || '').toString().toLowerCase().includes(q))
  })
  if (sortOrder.value === 'oldest') {
    out = [...out].sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
  } else if (sortOrder.value === 'unread') {
    out = [...out].sort((a, b) => Number(a.is_read) - Number(b.is_read)
      || new Date(b.created_at) - new Date(a.created_at))
  } else {
    out = [...out].sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
  }
  return out
})

const grouped = computed(() => {
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1)
  const lastWeek = new Date(today); lastWeek.setDate(lastWeek.getDate() - 7)
  const buckets = { Today: [], Yesterday: [], 'This week': [], Earlier: [] }
  for (const n of filtered.value) {
    const d = new Date(n.created_at)
    if (d >= today) buckets.Today.push(n)
    else if (d >= yesterday) buckets.Yesterday.push(n)
    else if (d >= lastWeek) buckets['This week'].push(n)
    else buckets.Earlier.push(n)
  }
  return Object.entries(buckets)
    .filter(([, v]) => v.length)
    .map(([label, list]) => ({ label, items: list }))
})

const byType = computed(() => {
  const map = new Map()
  for (const t of typeOptions) map.set(t, [])
  for (const n of items.value) {
    if (!map.has(n.type)) map.set(n.type, [])
    map.get(n.type).push(n)
  }
  return [...map.entries()].map(([type, list]) => ({
    type, items: list, unread: list.filter(n => !n.is_read).length,
  })).sort((a, b) => b.items.length - a.items.length)
})

const unreadCount = computed(() => items.value.filter(n => !n.is_read).length)
const todayCount = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return items.value.filter(n => (n.created_at || '').slice(0, 10) === today).length
})
const criticalCount = computed(() =>
  items.value.filter(n => ['stock_alert', 'escalation', 'dose_missed'].includes(n.type)).length,
)

const kpiTiles = computed(() => [
  { label: 'Total inbox',  value: items.value.length, icon: 'mdi-inbox',
    color: 'indigo' },
  { label: 'Unread',       value: unreadCount.value,  icon: 'mdi-bell-badge',
    color: 'red',     filter: 'unread', sub: `${items.value.length - unreadCount.value} read` },
  { label: 'Today',        value: todayCount.value,   icon: 'mdi-calendar-today',
    color: 'teal' },
  { label: 'Critical',     value: criticalCount.value, icon: 'mdi-alert-octagon',
    color: 'amber',   sub: 'Stock · Escalation · Missed dose' },
])

// ── Actions ─────────────────────────────────────────────
async function markRead(n, value = true) {
  try {
    if (value) {
      await $api.post(`/notifications/${n.id}/mark_read/`)
    } else {
      await $api.patch(`/notifications/${n.id}/`, { is_read: false })
    }
    n.is_read = value
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
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

async function runScan() {
  scanning.value = true
  try {
    const r = await $api.post('/notifications/scan-inventory/', { days: 30 })
    notify(`Scan complete · ${r.data?.output || 'no new alerts'}`, 'success')
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Scan failed', 'error') }
  finally { scanning.value = false }
}

function toggleSelect(id) {
  const i = selectedIds.value.indexOf(id)
  if (i === -1) selectedIds.value.push(id)
  else selectedIds.value.splice(i, 1)
}
async function bulkMarkRead(value) {
  const ids = [...selectedIds.value]
  await Promise.all(ids.map(id => {
    const n = items.value.find(x => x.id === id)
    if (!n) return null
    return value
      ? $api.post(`/notifications/${id}/mark_read/`).then(() => (n.is_read = true))
      : $api.patch(`/notifications/${id}/`, { is_read: false }).then(() => (n.is_read = false))
  }))
  selectedIds.value = []
  notify(`${ids.length} updated`, 'success')
}
async function bulkDelete() {
  const ids = [...selectedIds.value]
  if (!ids.length) return
  if (!confirm(`Delete ${ids.length} notification${ids.length > 1 ? 's' : ''}?`)) return
  await Promise.all(ids.map(id => $api.delete(`/notifications/${id}/`)))
  items.value = items.value.filter(n => !ids.includes(n.id))
  selectedIds.value = []
  notify(`${ids.length} deleted`, 'success')
}

// ── Detail drawer ───────────────────────────────────────
const detailDrawer = ref(false)
const detail = ref(null)
function openDetail(n) {
  detail.value = n
  detailDrawer.value = true
  if (!n.is_read) markRead(n, true)
}
function copyText(n) {
  const text = `${n.title}\n\n${n.message}`
  navigator.clipboard?.writeText(text)
    .then(() => notify('Copied to clipboard', 'info'))
    .catch(() => notify('Copy failed', 'warning'))
}
function follow(n) {
  const url = goToLink(n)
  if (!url) return
  detailDrawer.value = false
  router.push(url)
}
function goToLink(n) {
  if (!n) return null
  const d = n.data || {}
  if (d.url) return d.url
  if (d.path) return d.path
  if (n.type === 'lab_result' && d.test_id) return `/lab/results/${d.test_id}`
  if (n.type === 'lab_result' && d.order_id) return `/lab/orders/${d.order_id}`
  if (n.type === 'appointment' && d.appointment_id) return `/lab/appointments/${d.appointment_id}`
  if (n.type === 'stock_alert') return '/lab/inventory'
  if (n.type === 'billing' && d.invoice_id) return `/lab/invoices/${d.invoice_id}`
  return null
}
function formatVal(v) {
  if (v == null) return '—'
  if (typeof v === 'object') return JSON.stringify(v)
  return String(v)
}

// ── Delete ──────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(n) { deleteTarget.value = n; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/notifications/${deleteTarget.value.id}/`)
    items.value = items.value.filter(n => n.id !== deleteTarget.value.id)
    deleteDialog.value = false
    detailDrawer.value = false
    notify('Notification deleted', 'success')
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { saving.value = false }
}

// ── Preferences ────────────────────────────────────────
const settingsDialog = ref(false)
const PREFS_KEY = 'lab.notifications.prefs'
const prefs = reactive({
  autoRefresh: true,
  desktop: false,
  sound: false,
  muted: [],
})
function loadPrefs() {
  try {
    const raw = localStorage.getItem(PREFS_KEY)
    if (raw) Object.assign(prefs, JSON.parse(raw))
  } catch (_) {}
}
function savePrefs() {
  try { localStorage.setItem(PREFS_KEY, JSON.stringify(prefs)) } catch (_) {}
  notify('Preferences saved', 'success')
  settingsDialog.value = false
  if (prefs.autoRefresh) startTimer()
  else stopTimer()
}
function onDesktopToggle(v) {
  if (v && 'Notification' in window && Notification.permission !== 'granted') {
    Notification.requestPermission().then(p => {
      if (p !== 'granted') prefs.desktop = false
    })
  }
}

let pollTimer = null
function startTimer() { stopTimer(); pollTimer = setInterval(loadAll, 60000) }
function stopTimer() { if (pollTimer) { clearInterval(pollTimer); pollTimer = null } }
watch(() => prefs.autoRefresh, (v) => { v ? startTimer() : stopTimer() })

// React to new items: desktop notification + sound
let lastSeenIds = new Set()
watch(items, (list) => {
  const ids = new Set(list.map(n => n.id))
  if (lastSeenIds.size) {
    const fresh = list.filter(n => !lastSeenIds.has(n.id) && !n.is_read
                                && !prefs.muted.includes(n.type))
    if (fresh.length) {
      if (prefs.desktop && 'Notification' in window
          && Notification.permission === 'granted') {
        fresh.slice(0, 3).forEach(n => new Notification(n.title, { body: n.message }))
      }
      if (prefs.sound) playPing()
    }
  }
  lastSeenIds = ids
})
function playPing() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    const o = ctx.createOscillator(); const g = ctx.createGain()
    o.connect(g); g.connect(ctx.destination)
    o.type = 'sine'; o.frequency.value = 880
    g.gain.setValueAtTime(0.0001, ctx.currentTime)
    g.gain.exponentialRampToValueAtTime(0.15, ctx.currentTime + 0.02)
    g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.4)
    o.start(); o.stop(ctx.currentTime + 0.42)
  } catch (_) {}
}

// ── Helpers ─────────────────────────────────────────────
function typeColor(t) {
  return ({
    appointment: 'indigo', lab_result: 'purple', prescription: 'teal',
    home_collection: 'cyan', billing: 'amber', system: 'grey',
    dose_reminder: 'blue', dose_missed: 'red', escalation: 'red',
    teleconsult: 'deep-purple', insurance_claim: 'green', caregiver_update: 'pink',
    stock_alert: 'orange', consent: 'brown',
  })[t] || 'grey'
}
function typeIcon(t) {
  return ({
    appointment: 'mdi-calendar', lab_result: 'mdi-microscope', prescription: 'mdi-pill',
    home_collection: 'mdi-truck-delivery', billing: 'mdi-receipt-text', system: 'mdi-cog',
    dose_reminder: 'mdi-alarm', dose_missed: 'mdi-alarm-off', escalation: 'mdi-alert-octagon',
    teleconsult: 'mdi-video', insurance_claim: 'mdi-shield-account',
    caregiver_update: 'mdi-account-heart', stock_alert: 'mdi-package-variant-remove',
    consent: 'mdi-file-document-check',
  })[t] || 'mdi-bell'
}
function typeLabel(t) {
  return (t || '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

function relativeTime(iso) {
  if (!iso) return ''
  const d = new Date(iso); const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`
  return d.toLocaleDateString()
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
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.kpi:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06); }
.section-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.section-pills { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.notif-row { cursor: pointer; transition: background 0.15s ease; }
.notif-row:hover { background: #eef2ff; }
.unread-item { background: rgba(99, 102, 241, 0.06); }
.unread-item:hover { background: rgba(99, 102, 241, 0.1); }
.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.min-width-0 { min-width: 0; }
.detail-drawer { border-left: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
</style>
