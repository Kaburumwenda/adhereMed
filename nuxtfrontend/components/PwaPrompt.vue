<template>
  <div>
    <!-- Install prompt -->
    <v-snackbar
      v-model="showInstall"
      location="bottom"
      timeout="-1"
      color="surface"
      class="pwa-snackbar"
    >
      <div class="d-flex align-center">
        <v-icon icon="mdi-download" color="primary" class="mr-3" />
        <div class="flex-grow-1">
          <div class="text-subtitle-2 font-weight-bold">Install AdhereMed</div>
          <div class="text-caption text-medium-emphasis">Add to your home screen for quick access.</div>
        </div>
      </div>
      <template #actions>
        <v-btn variant="text" size="small" class="text-none" @click="dismissInstall">Not now</v-btn>
        <v-btn color="primary" variant="flat" size="small" class="text-none" @click="onInstall">Install</v-btn>
      </template>
    </v-snackbar>

    <!-- Update available -->
    <v-snackbar
      v-model="needRefresh"
      location="bottom"
      timeout="-1"
      color="primary"
    >
      <div class="d-flex align-center">
        <v-icon icon="mdi-update" class="mr-3" />
        <span>A new version is available.</span>
      </div>
      <template #actions>
        <v-btn variant="text" size="small" class="text-none" @click="needRefresh = false">Later</v-btn>
        <v-btn variant="flat" color="white" size="small" class="text-none text-primary" @click="onReload">Reload</v-btn>
      </template>
    </v-snackbar>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'

const DISMISS_KEY = 'pwa-install-dismissed-at'
const DISMISS_TTL_MS = 1000 * 60 * 60 * 24 * 7 // 7 days

const showInstall = ref(false)
const needRefresh = ref(false)
let pwa = null

function recentlyDismissed() {
  if (typeof window === 'undefined') return false
  const v = Number(localStorage.getItem(DISMISS_KEY) || 0)
  return v && Date.now() - v < DISMISS_TTL_MS
}

onMounted(() => {
  const nuxtApp = useNuxtApp()
  pwa = nuxtApp.$pwa
  if (!pwa) return

  // Watch the reactive flags exposed by @vite-pwa/nuxt
  watchEffect(() => {
    showInstall.value = !!pwa.showInstallPrompt && !recentlyDismissed()
    needRefresh.value = !!pwa.needRefresh
  })
})

async function onInstall() {
  try {
    await pwa?.install?.()
  } finally {
    showInstall.value = false
  }
}

function dismissInstall() {
  showInstall.value = false
  pwa?.cancelInstall?.()
  try { localStorage.setItem(DISMISS_KEY, String(Date.now())) } catch {}
}

async function onReload() {
  try {
    await pwa?.updateServiceWorker?.(true)
  } catch {
    if (typeof window !== 'undefined') window.location.reload()
  }
}
</script>

<style scoped>
.pwa-snackbar :deep(.v-snackbar__content) {
  width: 100%;
}
</style>
