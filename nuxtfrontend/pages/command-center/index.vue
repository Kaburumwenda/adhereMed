<template>
  <div class="cc-page">
    <!-- Background layers -->
    <div class="cc-bg-base cc-bg-fill" />
    <div class="cc-bg-grid cc-bg-fill" />
    <div class="cc-blob cc-blob-1" />
    <div class="cc-blob cc-blob-2" />
    <canvas ref="particleCanvas" class="cc-particles" />

    <div class="cc-inner">
      <!-- Top bar -->
      <header class="cc-header">
        <Transition name="slide-fade" appear>
          <div class="cc-brand">
            <v-avatar size="48" color="primary" variant="flat" class="cc-logo mr-3">
              <img v-if="orgData?.logo" :src="orgData.logo" alt="Logo" class="cc-logo-img" />
              <BrandLogo v-else :size="48" />
            </v-avatar>
            <div>
              <div class="cc-label">Command Center</div>
              <div class="text-h6 font-weight-bold text-surface-variant">{{ orgData?.name || 'Organization' }}</div>
              <div v-if="orgData?.motto" class="cc-motto">{{ orgData.motto }}</div>
            </div>
          </div>
        </Transition>
        <Transition name="fade" appear>
          <div class="cc-header-right">
            <v-btn variant="text" color="surface-variant" prepend-icon="mdi-refresh" @click="load" :loading="loading">
              <span class="d-none d-sm-inline">Refresh</span>
            </v-btn>
            <v-btn variant="text" color="surface-variant" prepend-icon="mdi-cog-outline" @click="navigateTo('/command-center/settings')">
              <span class="d-none d-sm-inline">Settings</span>
            </v-btn>
            <v-btn variant="text" color="surface-variant" prepend-icon="mdi-logout" @click="logout">
              <span class="d-none d-sm-inline">Sign out</span>
            </v-btn>
            <v-avatar size="42" color="primary" variant="flat" class="ml-2 cc-avatar">
              <span class="text-white font-weight-bold">{{ initial }}</span>
            </v-avatar>
          </div>
        </Transition>
      </header>

      <!-- Content -->
      <main class="cc-main">
        <!-- Loading -->
        <div v-if="loading && !orgData" class="text-center py-16">
          <div class="cc-loader-wrap">
            <v-progress-circular indeterminate size="56" width="4" color="primary" />
            <div class="cc-loader-pulse mt-4 text-body-1 text-medium-emphasis">Loading organization data…</div>
          </div>
        </div>

        <template v-else>
          <!-- Date + facility count bar -->
          <Transition name="fade-up" appear>
            <div class="cc-meta-bar">
              <div class="d-flex align-center">
                <v-icon color="primary" size="20" class="mr-2">mdi-calendar-month</v-icon>
                <span class="text-body-1 font-weight-medium">{{ today }}</span>
              </div>
              <div class="cc-meta-chips">
                <div class="cc-pulse-dot" :class="{ 'cc-pulse-dot--active': tenantList.length > 0 }" />
                <v-chip variant="flat" color="primary" size="small">
                  <v-icon start size="16">mdi-domain-multiple</v-icon>
                  {{ tenantList.length }} linked
                </v-chip>
              </div>
            </div>
          </Transition>

          <!-- KPI strip -->
          <v-row dense class="mb-2">
            <v-col
              v-for="(kpi, i) in kpis"
              :key="kpi.title"
              cols="6" md="4" lg="2"
            >
              <Transition name="scale-in" :style="{ transitionDelay: `${i * 80}ms` }" appear>
                <div class="kpi-tile">
                  <div class="kpi-tile__icon" :style="{ background: kpi.bg }">
                    <v-icon :color="kpi.color" size="22">{{ kpi.icon }}</v-icon>
                  </div>
                  <div class="kpi-tile__label">{{ kpi.title }}</div>
                  <div class="kpi-tile__value">{{ kpi.display }}</div>
                </div>
              </Transition>
            </v-col>
          </v-row>

          <!-- Tenant grid -->
          <h2 class="cc-section-title mt-6 mb-3">
            <v-icon class="mr-2" color="primary">mdi-domain-multiple</v-icon>
            Linked Facilities
          </h2>
          <v-row dense>
            <v-col
              v-for="(t, i) in tenantList"
              :key="t.id"
              cols="12" sm="6" md="4" lg="3"
            >
              <Transition name="card-in" :style="{ transitionDelay: `${i * 100}ms` }" appear>
                <div
                  class="tenant-card"
                  :class="{ 'tenant-card--inactive': !t.is_active }"
                  @click="t.is_active && enterTenant(t)"
                >
                  <!-- Gradient band -->
                  <div class="tenant-card__band" :style="{ background: typeGrad(t.type) }">
                    <v-icon size="36" color="white" class="tenant-card__band-icon">{{ typeIcon(t.type) }}</v-icon>
                    <div class="tenant-card__band-glow" :style="{ background: typeGrad(t.type) }" />
                  </div>
                  <!-- Body -->
                  <div class="tenant-card__body">
                    <div class="d-flex align-center justify-space-between mb-1">
                      <div class="text-subtitle-1 font-weight-bold text-truncate">{{ t.name }}</div>
                      <v-chip v-if="!t.is_active" size="x-small" variant="flat" color="grey">Inactive</v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis text-capitalize mb-3">
                      {{ (t.type || '').replace('_', ' ') }}
                    </div>

                    <!-- Mini stats -->
                    <div class="tenant-stats">
                      <div v-if="t.user_count != null" class="tenant-stat" title="Users">
                        <v-icon size="16" color="primary">mdi-account-group</v-icon>
                        <span>{{ t.user_count }}</span>
                      </div>
                      <div v-if="t.patient_count != null" class="tenant-stat" title="Patients">
                        <v-icon size="16" color="info">mdi-account-injury</v-icon>
                        <span>{{ t.patient_count }}</span>
                      </div>
                      <div v-if="t.stock_value != null" class="tenant-stat" title="Stock Value">
                        <v-icon size="16" color="amber-darken-2">mdi-package-variant-closed</v-icon>
                        <span>{{ formatKES(t.stock_value) }}</span>
                      </div>
                      <div v-if="t.low_stock_items != null" class="tenant-stat" title="Low Stock Items">
                        <v-icon size="16" :color="t.low_stock_items > 0 ? 'warning' : 'success'">mdi-alert-circle-outline</v-icon>
                        <span :class="t.low_stock_items > 0 ? 'text-warning' : ''">{{ t.low_stock_items }}</span>
                      </div>
                      <div v-if="t.active_alerts != null" class="tenant-stat" title="Active Alerts">
                        <v-icon size="16" :color="t.active_alerts > 0 ? 'error' : 'success'">mdi-bell</v-icon>
                        <span :class="t.active_alerts > 0 ? 'text-error' : ''">{{ t.active_alerts }}</span>
                      </div>
                    </div>

                    <!-- Enter button -->
                    <v-btn
                      block color="primary" rounded="lg" class="text-none mt-4 tenant-card__btn"
                      prepend-icon="mdi-arrow-right-bold"
                      :disabled="!t.is_active || switching"
                      @click.stop="enterTenant(t)"
                    >
                      Enter Facility
                    </v-btn>
                  </div>
                </div>
              </Transition>
            </v-col>
          </v-row>
        </template>

        <!-- Error snackbar -->
        <v-snackbar v-model="errorSnack" color="error" timeout="5000" location="top">
          {{ errorMsg }}
          <template #actions>
            <v-btn variant="text" @click="errorSnack = false">Close</v-btn>
          </template>
        </v-snackbar>

        <!-- Switching overlay -->
        <v-overlay v-model="switching" class="align-center justify-center cc-overlay" persistent>
          <div class="cc-switching">
            <div class="cc-switching-ring" />
            <v-progress-circular indeterminate size="56" width="4" color="primary" class="cc-switching-spinner" />
            <div class="text-body-1 mt-5 font-weight-medium">Switching to {{ switchingName }}…</div>
          </div>
        </v-overlay>
      </main>
    </div>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

definePageMeta({ layout: false })

const auth = useAuthStore()
const $api = useNuxtApp().$api

const loading = ref(false)
const switching = ref(false)
const switchingName = ref('')
const errorSnack = ref(false)
const errorMsg = ref('')

const orgData = ref(null)
const tenantList = ref([])
const totals = ref({})

const today = new Date().toLocaleDateString('en-US', {
  weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
})

const initial = computed(() => {
  const n = auth.user?.first_name || 'U'
  return (n[0] || 'U').toUpperCase()
})

const TENANT_META = {
  hospital: { icon: 'mdi-hospital-building', color: 'red', grad: 'linear-gradient(135deg, #ef4444, #b91c1c)' },
  clinic: { icon: 'mdi-stethoscope', color: 'teal', grad: 'linear-gradient(135deg, #14b8a6, #0d9488)' },
  pharmacy: { icon: 'mdi-pill', color: 'green', grad: 'linear-gradient(135deg, #22c55e, #15803d)' },
  inventory: { icon: 'mdi-warehouse', color: 'amber-darken-2', grad: 'linear-gradient(135deg, #f59e0b, #b45309)' },
  lab: { icon: 'mdi-test-tube', color: 'purple', grad: 'linear-gradient(135deg, #a855f7, #7e22ce)' },
  homecare: { icon: 'mdi-home-heart', color: 'pink', grad: 'linear-gradient(135deg, #ec4899, #be185d)' },
  radiology_center: { icon: 'mdi-xray-box', color: 'indigo', grad: 'linear-gradient(135deg, #6366f1, #4338ca)' },
}

function typeIcon(type) {
  return TENANT_META[type]?.icon || 'mdi-domain'
}
function typeColor(type) {
  return TENANT_META[type]?.color || 'primary'
}
function typeGrad(type) {
  return TENANT_META[type]?.grad || 'linear-gradient(135deg, #2f6dff, #143ce1)'
}

function formatKES(val) {
  if (!val || val === null) return '—'
  if (val >= 1_000_000) return `KSh ${(val / 1_000_000).toFixed(1)}M`
  if (val >= 1_000) return `KSh ${(val / 1_000).toFixed(0)}K`
  return `KSh ${val.toFixed(0)}`
}

const kpis = computed(() => {
  const t = totals.value || {}
  return [
    { title: 'Total Users', display: t.user_count ?? 0, icon: 'mdi-account-group', color: 'primary', bg: 'rgba(47,109,255,0.10)' },
    { title: 'Patients', display: t.patient_count ?? 0, icon: 'mdi-account-injury', color: 'info', bg: 'rgba(0,184,217,0.10)' },
    { title: 'Revenue 30d', display: formatKES(t.revenue_30d), icon: 'mdi-cash-multiple', color: 'success', bg: 'rgba(32,197,122,0.10)' },
    { title: 'Stock Value', display: formatKES(t.stock_value), icon: 'mdi-package-variant-closed', color: 'amber-darken-2', bg: 'rgba(245,158,11,0.10)' },
    { title: 'Appts Today', display: t.appointments_today ?? 0, icon: 'mdi-calendar-check', color: 'teal', bg: 'rgba(20,184,166,0.10)' },
    { title: 'Active Alerts', display: t.active_alerts ?? 0, icon: 'mdi-bell-alert', color: 'error', bg: 'rgba(239,68,68,0.10)' },
  ]
})

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/organizations/stats/')
    orgData.value = data.org
    tenantList.value = data.tenants || []
    totals.value = data.totals || {}
  } catch (err) {
    errorMsg.value = err?.response?.data?.detail || 'Failed to load organization stats.'
    errorSnack.value = true
  } finally {
    loading.value = false
  }
}

async function enterTenant(tenant) {
  switching.value = true
  switchingName.value = tenant.name
  try {
    await auth.switchTenant(tenant.id)
    // Navigate to the tenant's home path
    const homePath = getTenantHomePath(tenant.type)
    await navigateTo(homePath, { replace: true })
  } catch (err) {
    errorMsg.value = err?.response?.data?.detail || 'Failed to switch tenant.'
    errorSnack.value = true
  } finally {
    switching.value = false
  }
}

function getTenantHomePath(type) {
  if (type === 'pharmacy') return '/pharmacy'
  if (type === 'lab') return '/lab'
  if (type === 'radiology_center') return '/radiology'
  if (type === 'hospital') return '/hos'
  if (type === 'clinic') return '/clinics'
  if (type === 'inventory') return '/ims'
  return '/dashboard'
}

async function logout() {
  await auth.logout()
  navigateTo('/welcome', { replace: true })
}

onMounted(() => {
  if (!auth.isOrgAdmin) {
    navigateTo(getHomePathForUser(), { replace: true })
    return
  }
  load()
  if (particleCanvas.value) {
    cleanupParticles = startParticleNetwork(particleCanvas.value)
  }
})
onBeforeUnmount(() => {
  if (cleanupParticles) cleanupParticles()
})

// ── Particle network background ──
const particleCanvas = ref(null)
let cleanupParticles = null

function startParticleNetwork(canvas) {
  if (!import.meta.client || !canvas) return null
  const ctx = canvas.getContext('2d')
  if (!ctx) return null
  const PARTICLE_COUNT = 140
  const MAX_DISTANCE = 140
  const MOUSE_RADIUS = 180
  let mouse = { x: -9999, y: -9999 }
  let rafId = null
  const particles = []

  function resize() {
    canvas.width = canvas.clientWidth
    canvas.height = canvas.clientHeight
  }
  resize()
  const ro = new ResizeObserver(resize)
  ro.observe(canvas)
  window.addEventListener('resize', resize)

  for (let i = 0; i < PARTICLE_COUNT; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      vx: (Math.random() - 0.5) * 0.35,
      vy: (Math.random() - 0.5) * 0.35,
      r: Math.random() * 1.8 + 0.8,
    })
  }

  function onMouseMove(e) {
    mouse.x = e.clientX
    mouse.y = e.clientY
  }
  function onMouseLeave() { mouse.x = -9999; mouse.y = -9999 }
  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseout', onMouseLeave)

  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    for (const p of particles) {
      p.x += p.vx; p.y += p.vy
      if (p.x < 0 || p.x > canvas.width) p.vx *= -1
      if (p.y < 0 || p.y > canvas.height) p.vy *= -1
      const dx = p.x - mouse.x, dy = p.y - mouse.y
      const dist = Math.hypot(dx, dy)
      if (dist < MOUSE_RADIUS && dist > 0) {
 const force = (MOUSE_RADIUS - dist) / MOUSE_RADIUS * 0.6
 p.x += (dx / dist) * force
 p.y += (dy / dist) * force
      }
    }
    // Connection lines
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
 const dx = particles[i].x - particles[j].x
 const dy = particles[i].y - particles[j].y
 const dist = Math.hypot(dx, dy)
 if (dist < MAX_DISTANCE) {
   const alpha = (1 - dist / MAX_DISTANCE) * 0.22
   ctx.strokeStyle = `rgba(47,109,255,${alpha})`
   ctx.lineWidth = 0.7
   ctx.beginPath()
   ctx.moveTo(particles[i].x, particles[i].y)
   ctx.lineTo(particles[j].x, particles[j].y)
   ctx.stroke()
 }
      }
      // Mouse connections
      const mdx = particles[i].x - mouse.x
      const mdy = particles[i].y - mouse.y
      const mdist = Math.hypot(mdx, mdy)
      if (mdist < MOUSE_RADIUS) {
 const alpha = (1 - mdist / MOUSE_RADIUS) * 0.35
 ctx.strokeStyle = `rgba(55,214,255,${alpha})`
 ctx.lineWidth = 0.8
 ctx.beginPath()
 ctx.moveTo(particles[i].x, particles[i].y)
 ctx.lineTo(mouse.x, mouse.y)
 ctx.stroke()
      }
    }
    // Particle dots
    for (const p of particles) {
      ctx.beginPath()
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
      ctx.fillStyle = 'rgba(47,109,255,0.45)'
      ctx.fill()
    }
    rafId = requestAnimationFrame(draw)
  }
  draw()

  return () => {
    if (rafId) cancelAnimationFrame(rafId)
    ro.disconnect()
    window.removeEventListener('resize', resize)
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseout', onMouseLeave)
  }
}

function getHomePathForUser() {
  if (auth.tenantType === 'pharmacy') return '/pharmacy'
  if (auth.tenantType === 'lab') return '/lab'
  if (auth.tenantType === 'radiology_center') return '/radiology'
  if (auth.tenantType === 'hospital') return '/hos'
  if (auth.tenantType === 'clinic') return '/clinics'
  if (auth.tenantType === 'inventory') return '/ims'
  return '/dashboard'
}
</script>

<style scoped>
/* ── Page & Background (login-style) ── */
.cc-page {
  min-height: 100vh;
  position: relative;
  overflow: hidden;
  color: #0a0f1f;
}
.cc-bg-fill { position: absolute; inset: 0; }
.cc-bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47, 109, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(55, 214, 255, 0.08), transparent 55%),
    linear-gradient(160deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}
.cc-bg-grid {
  z-index: 0;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.03) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
}
.cc-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(70px);
  z-index: 0;
}
.cc-blob-1 { top: -120px; right: -80px; width: 380px; height: 380px; background: rgba(47, 109, 255, 0.15); animation: float-orb1 18s ease-in-out infinite; }
.cc-blob-2 { bottom: -80px; left: -80px; width: 340px; height: 340px; background: rgba(55, 214, 255, 0.10); animation: float-orb2 22s ease-in-out infinite; }
.cc-particles { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }
@keyframes float-orb1 {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(-40px, 30px) scale(1.1); }
}
@keyframes float-orb2 {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(50px, -40px) scale(1.15); }
}

/* ── Layout ── */
.cc-inner {
  position: relative;
  z-index: 1;
  max-width: 1400px;
  margin: 0 auto;
  padding: 16px;
}
@media (min-width: 960px) {
  .cc-inner { padding: 24px 32px; }
}

/* ── Header ── */
.cc-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 0 24px;
  flex-wrap: wrap;
  gap: 12px;
}
.cc-brand {
  display: flex;
  align-items: center;
  gap: 0;
}
.cc-logo {
  box-shadow: 0 4px 16px rgba(47,109,255,0.25);
  animation: logo-pulse 3s ease-in-out infinite;
}
.cc-logo-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: inherit;
}
@keyframes logo-pulse {
  0%, 100% { box-shadow: 0 4px 16px rgba(47,109,255,0.25); }
  50% { box-shadow: 0 4px 24px rgba(47,109,255,0.4); }
}
.cc-label {
  color: rgba(15, 23, 42, 0.5);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 1px;
}
.cc-motto {
  font-size: 0.875rem;
  font-style: italic;
  color: rgba(47, 109, 255, 0.7);
  line-height: 1.3;
  margin-top: 2px;
}
.cc-header-right {
  display: flex;
  align-items: center;
  gap: 4px;
}
.cc-avatar {
  transition: transform 0.2s;
}
.cc-avatar:hover {
  transform: scale(1.08);
}
/* text-white-60 removed — using .cc-label instead */

/* ── Main card ── */
.cc-main {
  background: rgb(var(--v-theme-surface));
  border-radius: 24px;
  padding: 20px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.18);
  min-height: 500px;
  animation: cc-main-in 0.5s ease-out;
}
@keyframes cc-main-in {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
@media (min-width: 960px) {
  .cc-main { padding: 32px; }
}
.cc-section-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.87);
}

/* ── Meta bar ── */
.cc-meta-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 8px;
}
.cc-meta-chips {
  display: flex;
  align-items: center;
  gap: 10px;
}
.cc-pulse-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgba(var(--v-theme-on-surface), 0.2);
}
.cc-pulse-dot--active {
  background: #22c55e;
  box-shadow: 0 0 0 0 rgba(34,197,94,0.5);
  animation: pulse-ring 2s ease-out infinite;
}
@keyframes pulse-ring {
  0% { box-shadow: 0 0 0 0 rgba(34,197,94,0.5); }
  100% { box-shadow: 0 0 0 12px rgba(34,197,94,0); }
}

/* ── KPI tiles ── */
.kpi-tile {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 16px;
  padding: 16px;
  transition: box-shadow 0.25s, border-color 0.25s, transform 0.25s;
  height: 100%;
  position: relative;
  overflow: hidden;
}
.kpi-tile::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 3px;
  background: var(--kpi-accent, transparent);
  opacity: 0;
  transition: opacity 0.25s;
}
.kpi-tile:hover {
  box-shadow: 0 8px 28px rgba(0,0,0,0.08);
  transform: translateY(-2px);
  border-color: rgba(var(--v-theme-primary), 0.2);
}
.kpi-tile:hover::before {
  opacity: 1;
}
.kpi-tile__icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 12px;
  transition: transform 0.3s ease;
}
.kpi-tile:hover .kpi-tile__icon {
  transform: scale(1.1) rotate(-5deg);
}
.kpi-tile__label {
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.kpi-tile__value {
  font-size: 1.5rem;
  font-weight: 800;
  margin-top: 2px;
  color: rgba(var(--v-theme-on-surface), 0.87);
}

/* ── Tenant cards ── */
.tenant-card {
  background: rgb(var(--v-theme-surface));
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  transition: box-shadow 0.3s, transform 0.3s, border-color 0.3s;
  cursor: pointer;
  height: 100%;
  display: flex;
  flex-direction: column;
  position: relative;
}
.tenant-card:hover {
  box-shadow: 0 20px 48px rgba(0,0,0,0.15);
  transform: translateY(-4px);
  border-color: rgba(var(--v-theme-primary), 0.15);
}
.tenant-card--inactive {
  opacity: 0.55;
  cursor: not-allowed;
}
.tenant-card--inactive:hover {
  transform: none;
  box-shadow: none;
  border-color: rgba(var(--v-theme-on-surface), 0.08);
}
.tenant-card__band {
  height: 88px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  position: relative;
  overflow: hidden;
}
.tenant-card__band-icon {
  transition: transform 0.3s ease;
  z-index: 1;
}
.tenant-card:hover .tenant-card__band-icon {
  transform: scale(1.15);
}
.tenant-card__band-glow {
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  opacity: 0;
  transition: opacity 0.4s;
  filter: blur(30px);
}
.tenant-card:hover .tenant-card__band-glow {
  opacity: 0.4;
}
.tenant-card__body {
  padding: 16px;
  flex-grow: 1;
  display: flex;
  flex-direction: column;
}
.tenant-stats {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 16px;
  margin-bottom: auto;
}
.tenant-stat {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 13px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.7);
  transition: transform 0.15s;
}
.tenant-stat:hover {
  transform: scale(1.05);
}
.tenant-card__btn {
  transition: transform 0.15s;
}
.tenant-card:hover .tenant-card__btn {
  transform: scale(1.02);
}

/* ── Switching overlay ── */
.cc-switching {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
}
.cc-switching-ring {
  position: absolute;
  top: -8px;
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 3px solid rgba(var(--v-theme-primary), 0.15);
  border-top-color: rgb(var(--v-theme-primary));
  animation: spin-ring 1s linear infinite;
}
@keyframes spin-ring {
  to { transform: rotate(360deg); }
}
.cc-switching-spinner {
  /* Hide Vuetify's own spinner, we use our ring */
  opacity: 0;
}

/* ── Vue Transitions ── */
.slide-fade-enter-active {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.slide-fade-enter-from {
  opacity: 0;
  transform: translateX(-30px);
}
.fade-enter-active {
  transition: opacity 0.5s ease;
}
.fade-enter-from {
  opacity: 0;
}
.fade-up-enter-active {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.fade-up-enter-from {
  opacity: 0;
  transform: translateY(20px);
}
.scale-in-enter-active {
  transition: all 0.45s cubic-bezier(0.16, 1, 0.3, 1);
}
.scale-in-enter-from {
  opacity: 0;
  transform: scale(0.85);
}
.card-in-enter-active {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.card-in-enter-from {
  opacity: 0;
  transform: translateY(30px) scale(0.95);
}
</style>
