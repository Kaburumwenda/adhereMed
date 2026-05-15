<template>
  <v-app-bar :elevation="0" color="surface" border>
    <template v-if="showMenu">
      <v-app-bar-nav-icon @click="$emit('toggle-drawer')" />
    </template>

    <v-app-bar-title>
      <span class="text-body-1 font-weight-medium">{{ pageTitle }}</span>
    </v-app-bar-title>

    <v-spacer />

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
      v-if="branchStore.hasBranches && auth.tenantType === 'pharmacy'"
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
  pageTitle: { type: String, default: '' }
})
defineEmits(['toggle-drawer'])

const auth = useAuthStore()
const theme = useThemeStore()
const branchStore = useBranchStore()
const router = useRouter()

const isFullscreen = ref(false)

// Admin sees "All Branches" + each branch; staff sees only active branches
const branchItems = computed(() => {
  const items = branchStore.activeBranches.map(b => ({ id: b.id, name: b.name }))
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

onMounted(() => {
  if (typeof document !== 'undefined') {
    document.addEventListener('fullscreenchange', syncFullscreen)
    syncFullscreen()
  }
})

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

function goProfile() {
  if (auth.role === 'patient') router.push('/my-profile')
  else if (['doctor', 'clinical_officer', 'dentist'].includes(auth.role)) router.push('/doctor-profile')
  else router.push('/settings')
}
</script>
