<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <!-- Background layers -->
      <div class="bg-base bg-fill" />
      <div class="bg-grid bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />
      <canvas ref="particleCanvas" class="auth-particles" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row no-gutters class="fill-height" align="center" justify="center">

          <!-- Branding panel (desktop) -->
          <v-col v-if="$vuetify.display.mdAndUp" md="6" class="pa-12">
            <v-btn
              variant="text"
              class="text-none nav-back mb-10"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back to home</v-btn>

            <!-- Brand lockup -->
            <div class="d-flex align-center mb-6">
              <BrandLogo :size="44" class="mr-3" />
              <BrandMark :size="22" />
            </div>

            <h2 class="panel-headline mb-3">
              Connected Healthcare.<br>
              <span class="grad-text">Simplified.</span>
            </h2>
            <p class="panel-sub mb-10">Africa's healthcare operating system — one intelligent platform for every actor in the care journey.</p>

            <div v-for="b in bullets" :key="b" class="bullet-row d-flex align-center mb-4">
              <div class="bullet-dot mr-3">
                <v-icon size="15" color="white">mdi-check</v-icon>
              </div>
              <span>{{ b }}</span>
            </div>
          </v-col>

          <!-- Form card -->
          <v-col cols="12" sm="9" md="5" lg="4" class="pa-4 pa-md-8">
            <!-- Mobile back -->
            <v-btn
              v-if="!$vuetify.display.mdAndUp"
              variant="text"
              class="text-none nav-back mb-4"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back</v-btn>

            <div class="form-card pa-7 pa-md-8">
              <div class="text-center mb-7">
                <BrandLogo :size="52" class="mx-auto mb-4" />
                <h2 class="form-title">Welcome back</h2>
                <p class="form-sub">Sign in to your AdhereMed account</p>
              </div>

              <v-alert
                v-if="errorMsg"
                type="error"
                variant="tonal"
                density="compact"
                rounded="lg"
                class="mb-5"
              >{{ errorMsg }}</v-alert>

              <v-form ref="formRef" @submit.prevent="onSubmit">
                <v-text-field
                  v-model="email"
                  label="Email"
                  type="email"
                  prepend-inner-icon="mdi-email-outline"
                  :rules="[v => !!v || 'Email required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                  autocomplete="email"
                  variant="outlined"
                  rounded="lg"
                  class="field-light mb-1"
                  density="comfortable"
                  color="brand"
                />
                <v-text-field
                  v-model="password"
                  label="Password"
                  :type="show ? 'text' : 'password'"
                  prepend-inner-icon="mdi-lock-outline"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  :rules="[v => !!v || 'Password required']"
                  autocomplete="current-password"
                  variant="outlined"
                  rounded="lg"
                  class="field-light"
                  density="comfortable"
                  color="brand"
                  @click:append-inner="show = !show"
                />

                <div class="d-flex justify-end mb-5 mt-1">
                  <v-btn variant="text" size="small" class="text-none forgot-link" to="/forgot-password">
                    Forgot password?
                  </v-btn>
                </div>

                <v-btn
                  type="submit"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none btn-primary mb-5"
                  :loading="auth.loading"
                >Sign In</v-btn>

                <div class="text-center text-body-2 form-footer-text">
                  Don't have an account?
                </div>
                <div class="d-flex flex-wrap justify-center ga-2 mt-3">
                  <v-btn size="small" variant="tonal" color="primary" rounded="lg" class="text-none"
                         prepend-icon="mdi-medical-bag" to="/register-pharmacy">
                    Pharmacy
                  </v-btn>
                  <v-btn size="small" variant="tonal" color="teal" rounded="lg" class="text-none"
                         prepend-icon="mdi-package-variant-closed" to="/register-inventory">
                    Inventory / Warehouse
                  </v-btn>
                  <v-btn size="small" variant="tonal" color="indigo" rounded="lg" class="text-none"
                         prepend-icon="mdi-account-heart" to="/register-patient">
                    Patient
                  </v-btn>
                </div>
              </v-form>
            </div>
          </v-col>

        </v-row>
      </v-container>
    </div>
  </NuxtLayout>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

definePageMeta({ layout: false })

const auth = useAuthStore()
const router = useRouter()

const formRef = ref(null)
const email = ref('')
const password = ref('')
const show = ref(false)
const errorMsg = ref('')

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

const bullets = [
  'Multi-tenant hospital, pharmacy & lab',
  'Real-time prescriptions & dispensing',
  'Patient online orders & exchange',
  'Role-based dashboards & analytics'
]

async function onSubmit() {
  errorMsg.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  const ok = await auth.login(email.value.trim(), password.value)
  if (ok) {
    // Org admins (who are not super_admin) go to command center
    if (auth.isOrgAdmin && auth.role !== 'super_admin') {
      router.push('/command-center')
      return
    }
    const home = auth.tenantType === 'pharmacy' ? '/pharmacy'
      : auth.tenantType === 'lab' ? '/lab'
      : auth.tenantType === 'radiology_center' ? '/radiology'
      : auth.tenantType === 'hospital' ? '/hos'
      : auth.tenantType === 'clinic' ? '/clinics'
      : auth.tenantType === 'inventory' ? '/ims'
      : '/dashboard'
    router.push(home)
  }
  else errorMsg.value = auth.error || 'Login failed.'
}

onMounted(() => {
  if (particleCanvas.value) {
    cleanupParticles = startParticleNetwork(particleCanvas.value)
  }
})
onBeforeUnmount(() => {
  if (cleanupParticles) cleanupParticles()
})
</script>

<style scoped>
/* ---------- Root / Background ---------- */
.auth-root {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  color: #0a0f1f;
}
.bg-fill { position: absolute; inset: 0; }
.auth-particles { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }
.bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47, 109, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(55, 214, 255, 0.08), transparent 55%),
    linear-gradient(160deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}
.bg-grid {
  z-index: 0;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.03) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
}
.blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(70px);
  z-index: 0;
}
.blob-1 { top: -120px; right: -80px; width: 380px; height: 380px; background: rgba(47, 109, 255, 0.15); }
.blob-2 { bottom: -80px; left: -80px; width: 340px; height: 340px; background: rgba(55, 214, 255, 0.1); }

/* ---------- Brand ---------- */
.brand-badge {
  width: 46px; height: 46px; border-radius: 13px;
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%);
  box-shadow: 0 6px 18px rgba(47, 109, 255, 0.35);
  display: flex; align-items: center; justify-content: center;
}
.brand-word { font-size: 22px; letter-spacing: -0.4px; }
.brand-word .bold { font-weight: 800; color: #0a0f1f; }
.brand-word .light { font-weight: 300; color: #2f6dff; }

/* ---------- Left panel ---------- */
.nav-back { color: rgba(15, 23, 42, 0.6) !important; }
.panel-headline {
  font-size: clamp(1.9rem, 3.4vw, 2.8rem);
  font-weight: 800;
  line-height: 1.12;
  letter-spacing: -1px;
  color: #0a0f1f;
}
.grad-text {
  background: linear-gradient(90deg, #2f6dff, #37d6ff, #143ce1);
  background-size: 200% auto;
  -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent;
  animation: shimmer 5s linear infinite;
}
.panel-sub { font-size: 1rem; line-height: 1.65; color: #475569; }
.bullet-row { color: #334155; font-size: 0.95rem; }
.bullet-dot {
  width: 26px; height: 26px; border-radius: 8px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #2f6dff, #143ce1);
  box-shadow: 0 4px 12px rgba(47, 109, 255, 0.3);
}

/* ---------- Form card ---------- */
.form-card {
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.85);
  border: 1px solid rgba(47, 109, 255, 0.12);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  box-shadow: 0 12px 40px rgba(10, 15, 31, 0.08);
}
.form-title {
  font-size: 1.55rem; font-weight: 800; color: #0a0f1f; letter-spacing: -0.4px;
}
.form-sub { font-size: 0.9rem; color: #64748b; margin-top: 4px; }
.form-footer-text { color: #64748b; }
.form-link { color: #2f6dff !important; }
.forgot-link { color: #2f6dff !important; }

/* ---------- Fields ---------- */
:deep(.field-light .v-field) {
  background: #f8fafc !important;
  border: 1px solid rgba(15, 23, 42, 0.12) !important;
  border-radius: 12px !important;
  color: #0a0f1f !important;
}
:deep(.field-light .v-field--focused) {
  border-color: rgba(47, 109, 255, 0.6) !important;
}
:deep(.field-light .v-label) { color: rgba(15, 23, 42, 0.5) !important; }
:deep(.field-light .v-icon) { color: rgba(47, 109, 255, 0.5) !important; }
:deep(.field-light input) { color: #0a0f1f !important; }

/* ---------- Button ---------- */
.btn-primary {
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 10px 26px rgba(47, 109, 255, 0.35);
}

@keyframes shimmer { to { background-position: 200% center; } }
</style>
