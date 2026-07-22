<template>
  <div class="lock-bg d-flex align-center justify-center pa-4">
    <v-card rounded="xl" elevation="8" max-width="560" class="pa-2">
      <v-card-text class="text-center pa-6">
        <v-avatar size="88" color="amber-lighten-4" class="mb-4">
          <v-icon icon="mdi-lock-alert" size="48" color="amber-darken-3" />
        </v-avatar>

        <h1 class="text-h5 font-weight-bold mb-1">Access temporarily restricted</h1>
        <p class="text-body-1 text-medium-emphasis mb-4">
          <strong>{{ tenantName || 'Your organisation' }}</strong>'s account has been
          restricted because of unpaid API usage bills.
        </p>

        <v-alert type="warning" variant="tonal" rounded="lg" class="text-start mb-4">
          <div class="font-weight-medium mb-1">What this means</div>
          <div class="text-body-2">
            The service is paused for all staff until the outstanding balance is cleared.
            Please <strong>contact your administrator or management</strong> to settle the
            account and restore access.
          </div>
        </v-alert>

        <div v-if="Number(overdueTotal) > 0" class="mb-4">
          <div class="text-caption text-medium-emphasis">Outstanding balance</div>
          <div class="text-h4 font-weight-bold text-error">{{ money(overdueTotal) }}</div>
        </div>

        <div v-if="reason" class="text-caption text-medium-emphasis mb-4">
          <v-icon icon="mdi-information-outline" size="14" class="mr-1" />{{ reason }}
        </div>

        <div class="d-flex flex-column ga-2">
          <v-btn color="primary" variant="flat" rounded="lg" size="large"
                 :loading="checking" prepend-icon="mdi-refresh" @click="recheck">
            I've been cleared — re-check access
          </v-btn>
          <v-btn variant="text" rounded="lg" prepend-icon="mdi-logout" @click="doLogout">
            Sign out
          </v-btn>
        </div>

        <div class="text-caption text-medium-emphasis mt-5">
          Need help? Email
          <a href="mailto:billing@adheremed.co" class="text-decoration-none">billing@adheremed.co</a>
        </div>
      </v-card-text>
    </v-card>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useAuthStore } from '~/stores/auth'

const auth = useAuthStore()
const checking = ref(false)

const tenantName = computed(() => auth.tenantName)
const overdueTotal = computed(() => auth.overdueTotal)
const reason = computed(() => auth.billing?.reason || '')

function money(v) {
  const n = Number(v || 0)
  return 'KSh ' + n.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}

function homePath() {
  if (auth.tenantType === 'pharmacy') return '/pharmacy'
  if (auth.tenantType === 'lab') return '/lab'
  if (auth.tenantType === 'radiology_center') return '/radiology'
  return '/dashboard'
}

async function recheck() {
  checking.value = true
  try {
    await auth.refresh()
    if (!auth.billingLocked) {
      await navigateTo(homePath())
    }
  } finally {
    checking.value = false
  }
}

async function doLogout() {
  try { await auth.logout?.() } catch {}
  await navigateTo('/welcome')
}
</script>

<style scoped>
.lock-bg {
  min-height: 100vh;
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
}
:global(.v-theme--dark) .lock-bg {
  background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
}
</style>
