<template>
  <v-app-bar :elevation="0" color="surface" border>
    <template v-if="showMenu">
      <v-app-bar-nav-icon @click="$emit('toggle-drawer')" />
    </template>

    <v-btn
      v-if="!showMenu"
      icon
      variant="text"
      @click="$emit('toggle-rail')"
    >
      <v-icon>mdi-menu</v-icon>
      <v-tooltip activator="parent" location="bottom">
        {{ rail ? $t('topbar.expand') : $t('topbar.collapse') }}
      </v-tooltip>
    </v-btn>

    <!-- Live clock -->
    <div class="d-none d-lg-flex align-center mx-2 px-3 py-1 rounded-lg clock-chip">
      <span class="live-dot mr-2"></span>
      <v-icon size="16" class="mr-2" color="primary">mdi-clock-outline</v-icon>
      <span class="text-body-2 font-weight-medium clock-time">{{ clockTime }}</span>
      <span class="text-caption text-medium-emphasis clock-date ml-2">{{ clockDate }}</span>
    </div>

    <v-app-bar-title>
      <span class="text-body-1 font-weight-medium">{{ pageTitle }}</span>
    </v-app-bar-title>

    <!-- Back to Command Center (org admins with active tenant override) -->
    <v-btn
      v-if="auth.activeTenantOverride"
      variant="tonal"
      color="primary"
      rounded="lg"
      class="text-none mx-2"
      prepend-icon="mdi-view-dashboard-outline"
      @click="goCommandCenter"
    >
      Command Center
    </v-btn>

    <v-spacer />

    <!-- ── Notification bell ─────────────────────────────── -->
    <v-menu offset="8" max-width="420" :close-on-content-click="false">
      <template #activator="{ props: menuProps }">
        <v-btn v-bind="menuProps" icon variant="text" class="mx-1">
          <v-badge :model-value="unreadCount > 0" :content="unreadCount > 99 ? '99+' : unreadCount" color="error" offset-x="2" offset-y="2">
            <v-icon>mdi-bell-outline</v-icon>
          </v-badge>
          <v-tooltip activator="parent" location="bottom">Notifications</v-tooltip>
        </v-btn>
      </template>
      <v-card rounded="xl" class="notification-panel">
        <v-card-title class="d-flex align-center py-3 px-4">
          <v-icon class="mr-2" size="20" color="primary">mdi-bell-ring-outline</v-icon>
          <span class="text-subtitle-2 font-weight-bold">Notifications</span>
          <v-spacer />
          <v-btn v-if="unreadCount > 0" variant="text" size="small" class="text-none" prepend-icon="mdi-check-all" @click="markAllRead">
            Mark all read
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-list density="compact" class="notification-list" lines="three">
          <v-list-item
            v-for="n in notifications"
            :key="n.id"
            @click="markRead(n)"
            :class="{ 'notification-unread': !n.is_read }"
          >
            <template #prepend>
              <v-avatar :color="notificationColor(n)" variant="tonal" size="36" rounded="lg">
                <v-icon size="18">{{ notificationIcon(n) }}</v-icon>
              </v-avatar>
            </template>
            <v-list-item-title class="text-body-2 font-weight-medium">{{ n.title }}</v-list-item-title>
            <v-list-item-subtitle class="text-caption">{{ n.message }}</v-list-item-subtitle>
            <template #append>
              <div class="d-flex flex-column align-end">
                <v-icon v-if="!n.is_read" size="8" color="primary" class="mb-1">mdi-circle</v-icon>
                <span class="text-caption text-medium-emphasis">{{ timeAgo(n.created_at) }}</span>
              </div>
            </template>
          </v-list-item>
          <v-list-item v-if="!notifications.length" class="text-center py-6">
            <v-icon size="40" color="grey-lighten-1" class="mb-2">mdi-bell-off-outline</v-icon>
            <div class="text-body-2 text-medium-emphasis">No notifications</div>
          </v-list-item>
        </v-list>
        <v-divider />
        <v-card-actions class="pa-2">
          <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-truck-delivery-outline" @click="router.push('/ims/inventory/transfers'); notifMenu = false">
            View Transfers
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-menu>

    <v-btn icon variant="text" @click="refreshPage">
      <v-icon>mdi-refresh</v-icon>
      <v-tooltip activator="parent" location="bottom">{{ $t('topbar.refresh') }}</v-tooltip>
    </v-btn>

    <v-btn icon variant="text" @click="toggleFullscreen">
      <v-icon>{{ isFullscreen ? 'mdi-fullscreen-exit' : 'mdi-fullscreen' }}</v-icon>
      <v-tooltip activator="parent" location="bottom">
        {{ isFullscreen ? $t('topbar.exitFullscreen') : $t('topbar.fullscreen') }}
      </v-tooltip>
    </v-btn>

    <v-btn icon variant="text" @click="theme.cycle()">
      <v-icon>{{ themeIcon }}</v-icon>
      <v-tooltip activator="parent" location="bottom">{{ $t('topbar.theme') }}: {{ theme.mode }}</v-tooltip>
    </v-btn>

    <LanguageSwitcher />

    <!-- Branch selector -->
    <v-select
      v-if="branchStore.hasBranches && ['pharmacy', 'inventory'].includes(auth.tenantType)"
      :model-value="branchStore.currentBranchId"
      :items="branchItems"
      item-title="name"
      item-value="id"
      density="compact"
      variant="outlined"
      rounded="lg"
      hide-details
      prepend-inner-icon="mdi-store-marker"
      style="max-width: 200px"
      class="mx-1 d-none d-md-flex"
      :disabled="!branchStore.canSwitchBranch"
      :readonly="!branchStore.canSwitchBranch"
      @update:model-value="branchStore.select($event)"
    />

    <v-menu offset="8">
      <template #activator="{ props }">
        <v-btn v-bind="props" variant="text" class="text-none">
          <v-avatar size="32" color="primary" class="mr-2">
            <span class="text-white font-weight-bold">{{ initial }}</span>
          </v-avatar>
          <div class="d-none d-sm-flex flex-column align-start">
            <span class="text-body-2 font-weight-medium">{{ auth.user?.first_name || 'User' }}</span>
            <span class="text-caption text-medium-emphasis">{{ formatRole(auth.role) }}</span>
          </div>
          <v-icon size="18" class="ml-2">mdi-chevron-down</v-icon>
        </v-btn>
      </template>
      <v-list density="compact" min-width="180">
        <v-list-item prepend-icon="mdi-account" :title="$t('common.profile')" @click="goProfile" />
        <v-list-item prepend-icon="mdi-cog" :title="$t('common.settings')" to="/settings" />
        <v-divider />
        <v-list-item
          prepend-icon="mdi-logout"
          :title="$t('common.logout')"
          base-color="error"
          @click="onLogout"
        />
      </v-list>
    </v-menu>
  </v-app-bar>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useThemeStore } from '~/stores/theme'
import { useBranchStore } from '~/stores/branch'
import { ADMIN_ROLES } from '~/utils/permissions'
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'

defineProps({
  showMenu: { type: Boolean, default: false },
  pageTitle: { type: String, default: '' },
  rail: { type: Boolean, default: false }
})
defineEmits(['toggle-drawer', 'toggle-rail'])

const auth = useAuthStore()
const theme = useThemeStore()
const branchStore = useBranchStore()
const router = useRouter()
const { $api } = useNuxtApp()

// ── Notifications ─────────────────────────────────────────────────────────
const notifications = ref([])
const unreadCount = ref(0)
let notifPollTimer = null

async function loadNotifications() {
  try {
    const { data } = await $api.get('/notifications/', { params: { page_size: 20 } })
    notifications.value = data?.results || data || []
    unreadCount.value = notifications.value.filter(n => !n.is_read).length
  } catch { /* silent */ }
}

async function markRead(n) {
  if (n.is_read) return
  try {
    await $api.post(`/notifications/${n.id}/mark_read/`)
    n.is_read = true
    unreadCount.value = Math.max(0, unreadCount.value - 1)
  } catch { /* silent */ }
}

async function markAllRead() {
  try {
    await $api.post('/notifications/mark_all_read/')
    notifications.value.forEach(n => { n.is_read = true })
    unreadCount.value = 0
  } catch { /* silent */ }
}

function notificationIcon(n) {
  if (n.type === 'system' && n.data?.status === 'in_transit') return 'mdi-truck-fast'
  if (n.type === 'system' && n.data?.status === 'completed') return 'mdi-package-check'
  if (n.type === 'system' && n.data?.status === 'requested') return 'mdi-send'
  if (n.type === 'system' && n.data?.status === 'cancelled') return 'mdi-cancel'
  if (n.type === 'stock_alert') return 'mdi-package-variant-remove'
  if (n.type === 'billing') return 'mdi-receipt-text'
  if (n.type === 'appointment') return 'mdi-calendar-clock'
  return 'mdi-bell'
}

function notificationColor(n) {
  if (n.type === 'system' && n.data?.status === 'in_transit') return 'blue'
  if (n.type === 'system' && n.data?.status === 'completed') return 'success'
  if (n.type === 'system' && n.data?.status === 'requested') return 'info'
  if (n.type === 'system' && n.data?.status === 'cancelled') return 'error'
  if (n.type === 'stock_alert') return 'warning'
  if (n.type === 'billing') return 'amber'
  return 'grey'
}

function timeAgo(iso) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  const days = Math.floor(hrs / 24)
  if (days < 7) return `${days}d ago`
  return new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
}

const isFullscreen = ref(false)

// ── Live clock ───────────────────────────────────────────────────────────
const clockTime = ref('')
const clockDate = ref('')
let clockTimer = null
function updateClock() {
  const now = new Date()
  clockTime.value = now.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  clockDate.value = now.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short' })
}
updateClock()
onMounted(() => {
  clockTimer = setInterval(updateClock, 1000)
  loadNotifications()
  notifPollTimer = setInterval(loadNotifications, 60000) // poll every 60s
})
onBeforeUnmount(() => {
  if (clockTimer) clearInterval(clockTimer)
  if (notifPollTimer) clearInterval(notifPollTimer)
})

// Admin sees "All Branches" + each branch; soft-assign roles see only nearby/assigned branches
const SOFT_ROLES = new Set(['cashier', 'pharmacist', 'pharmacy_tech'])
const branchItems = computed(() => {
  let source
  if (ADMIN_ROLES.has(auth.role)) {
    source = branchStore.activeBranches
  } else if (SOFT_ROLES.has(auth.role)) {
    source = branchStore.allowedBranches
  } else {
    source = branchStore.activeBranches
  }
  const items = source.map(b => ({ id: b.id, name: b.name }))
  if (ADMIN_ROLES.has(auth.role)) {
    items.unshift({ id: null, name: 'All Branches' })
  }
  return items
})

function syncFullscreen() {
  if (typeof document !== 'undefined') {
    isFullscreen.value = !!document.fullscreenElement
  }
}

function toggleFullscreen() {
  if (typeof document === 'undefined') return
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen?.().catch(() => {})
  } else {
    document.exitFullscreen?.().catch(() => {})
  }
}

function refreshPage() {
  if (typeof document === 'undefined' || typeof window === 'undefined') return
  // Flag that we want fullscreen after the reload
  sessionStorage.setItem('autoFullscreen', '1')
  // Enter fullscreen now with the user gesture, then reload
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen?.().finally(() => {
      window.location.reload()
    })
  } else {
    window.location.reload()
  }
}

onMounted(() => {
  if (typeof document !== 'undefined') {
    document.addEventListener('fullscreenchange', syncFullscreen)
    syncFullscreen()
    // Auto-enter fullscreen once the user logs in and reaches the dashboard
    attemptFullscreen()
  }
})

/** Try to enter fullscreen now; if blocked by browser, wait for first user interaction */
function attemptFullscreen() {
  if (typeof document === 'undefined') return
  if (document.fullscreenElement) return

  const requested = document.documentElement.requestFullscreen?.()
  if (requested) {
    requested.catch(() => {
      // Browser blocked it — wait for the first user click/keydown
      const onInteraction = () => {
        document.documentElement.requestFullscreen?.().catch(() => {})
      }
      document.addEventListener('click', onInteraction, { once: true })
      document.addEventListener('keydown', onInteraction, { once: true })
    })
  }

  // Clean up the sessionStorage flag used by refreshPage
  if (typeof sessionStorage !== 'undefined' && sessionStorage.getItem('autoFullscreen')) {
    sessionStorage.removeItem('autoFullscreen')
  }
}

onBeforeUnmount(() => {
  if (typeof document !== 'undefined') {
    document.removeEventListener('fullscreenchange', syncFullscreen)
  }
})

const initial = computed(() => {
  const n = auth.user?.first_name || 'U'
  return (n[0] || 'U').toUpperCase()
})

const themeIcon = computed(() => {
  return {
    light: 'mdi-white-balance-sunny',
    dark: 'mdi-weather-night',
    ocean: 'mdi-waves',
    sunset: 'mdi-weather-sunset'
  }[theme.mode] || 'mdi-palette'
})

function formatRole(r) {
  if (!r) return ''
  return r.split('_').map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
}

async function onLogout() {
  await auth.logout()
  router.push('/welcome')
}

async function goCommandCenter() {
  await auth.switchBack()
  router.push('/command-center')
}

function goProfile() {
  if (auth.role === 'patient') router.push('/my-profile')
  else if (['doctor', 'clinical_officer', 'dentist'].includes(auth.role)) router.push('/doctor-profile')
  else router.push('/settings')
}
</script>

<style scoped>
.clock-chip {
  background: rgba(var(--v-theme-primary), 0.06);
  border: 1px solid rgba(var(--v-theme-primary), 0.12);
  min-width: 120px;
}
.clock-time {
  font-variant-numeric: tabular-nums;
  line-height: 1.2;
}
.clock-date {
  line-height: 1.2;
  font-size: 0.7rem;
}
.live-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #22c55e;
  animation: live-blink 1.5s ease-in-out infinite;
}
@keyframes live-blink {
  0%, 100% { opacity: 1; box-shadow: 0 0 6px rgba(34, 197, 94, 0.6); }
  50% { opacity: 0.3; box-shadow: none; }
}

/* ── Notification panel ── */
.notification-panel { max-height: 500px; display: flex; flex-direction: column; }
.notification-list { max-height: 380px; overflow-y: auto; }
.notification-unread { background: rgba(var(--v-theme-primary), 0.04); }
.notification-unread:hover { background: rgba(var(--v-theme-primary), 0.08); }
</style>
