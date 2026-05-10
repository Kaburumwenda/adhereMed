<template>
  <SideNav
    v-model="drawer"
    :rail="rail"
    :mobile="mobile"
    :user-name="auth.fullName"
    :user-role="auth.role"
    :tenant-type="auth.tenantType"
    :tenant-name="auth.tenantName"
    @toggle-rail="rail = !rail"
    @logout="onLogout"
  />
  <TopBar :show-menu="mobile" :page-title="pageTitle" @toggle-drawer="drawer = !drawer" />
  <v-main>
    <slot />
  </v-main>
</template>

<script setup>
import { useDisplay } from 'vuetify'
import { useAuthStore } from '~/stores/auth'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const { mobile, width } = useDisplay()

const drawer = ref(true)
const rail = ref(false)

watch(width, (w) => {
  rail.value = w < 1100 && !mobile.value
}, { immediate: true })

// Auto-collapse sidebar to rail mode whenever a POS page is open,
// except for /pos/history and /pos/parked which should keep the sidebar expanded.
watch(() => route.path, (p) => {
  if (p.startsWith('/pos') && !p.startsWith('/pos/history') && !p.startsWith('/pos/parked')) {
    rail.value = true
  }
}, { immediate: true })

const pageTitle = computed(() => {
  const segs = route.path.split('/').filter(Boolean)
  if (!segs.length) return 'Dashboard'
  return segs[0].split('-').map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
})

async function onLogout() {
  await auth.logout()
  router.push('/welcome')
}
</script>
