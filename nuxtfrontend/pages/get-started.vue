<template>
  <NuxtLayout name="auth">
    <div class="gs-root">
      <!-- Background -->
      <div class="gs-bg gs-fill" />
      <div class="gs-grid gs-fill" />
      <div class="gs-blob gs-blob-1" />
      <div class="gs-blob gs-blob-2" />
      <div class="gs-blob gs-blob-3" />

      <!-- Top nav -->
      <header class="gs-nav">
        <div class="gs-nav-inner d-flex align-center px-4 px-md-10 py-3">
          <div class="brand-lockup d-flex align-center" role="button" @click="$router.push('/welcome')">
            <div class="brand-badge d-flex align-center justify-center mr-3">
              <v-icon size="18" color="white">mdi-heart-pulse</v-icon>
            </div>
            <span class="brand-word">
              <span class="bold">Adhere</span><span class="light">Med</span>
            </span>
          </div>
          <v-spacer />
          <v-btn variant="text" class="text-none gs-link mr-1" rounded="lg"
                 prepend-icon="mdi-arrow-left" @click="$router.push('/welcome')">
            Back
          </v-btn>
          <v-btn variant="outlined" class="text-none gs-outline" rounded="lg"
                 @click="$router.push('/login')">
            Sign In
          </v-btn>
        </div>
      </header>

      <!-- Header -->
      <section class="gs-head">
        <div class="gs-eyebrow">
          <span class="dot" />
          REGISTRATION HUB
        </div>
        <h1 class="gs-title">Join the <span class="grad-text">AdhereMed</span> ecosystem</h1>
        <p class="gs-sub">
          Choose your role below to get started. Every node connects into one secure,
          interoperable healthcare cloud. More modules are opening for self-registration soon.
        </p>
      </section>

      <!-- Ecosystem nodes grid -->
      <section class="gs-grid-wrap">
        <div class="gs-nodes">
          <button
            v-for="(n, i) in nodes"
            :key="n.key"
            class="gs-node"
            :class="{ 'is-active': n.active, 'is-soon': !n.active }"
            :style="{ '--d': i * 90 + 'ms', '--accent': n.color }"
            :disabled="!n.active"
            @click="n.active && go(n)"
          >
            <span class="gs-node-glow" />
            <span class="gs-node-ping" v-if="n.active" />
            <span class="gs-node-icon">
              <v-icon size="30" color="white">{{ n.icon }}</v-icon>
            </span>
            <span class="gs-node-label">{{ n.label }}</span>
            <span class="gs-node-status">
              <template v-if="n.active">
                <v-icon size="13" color="#2f6dff" class="mr-1">mdi-check-decagram</v-icon> Active
              </template>
              <template v-else>
                <v-icon size="13" class="mr-1">mdi-clock-outline</v-icon> Coming soon
              </template>
            </span>
            <span v-if="n.active" class="gs-node-cta">
              Register <v-icon size="15">mdi-arrow-right</v-icon>
            </span>
          </button>
        </div>
      </section>

      <!-- Note -->
      <section class="gs-note-wrap">
        <div class="gs-note">
          <v-icon size="20" color="#2f6dff" class="mr-3">mdi-shield-check</v-icon>
          <span>
            Only <strong>Patients</strong>, <strong>Pharmacies</strong> and
            <strong>Inventory / Warehouse</strong> providers can self-register today.
            Hospitals, labs, radiology, insurers and homecare providers are onboarded by our team —
            <a class="gs-contact" @click="$router.push('/welcome')">contact us</a>.
          </span>
        </div>
      </section>

      <footer class="gs-footer">
        <span>© 2026 AdhereMed. Connected Healthcare. Simplified.</span>
      </footer>
    </div>
  </NuxtLayout>
</template>

<script setup>
definePageMeta({ layout: false })

const router = useRouter()

const nodes = [
  { key: 'patient',   label: 'Patient',     icon: 'mdi-account-heart',      color: '#2f6dff', active: true,  to: '/register-patient' },
  { key: 'pharmacy',  label: 'Pharmacy',    icon: 'mdi-medical-bag',        color: '#143ce1', active: true,  to: '/register-pharmacy' },
  { key: 'inventory', label: 'Inventory / Warehouse', icon: 'mdi-package-variant-closed', color: '#0d9488', active: true, to: '/register-inventory' },
  { key: 'doctor',    label: 'Doctor',      icon: 'mdi-doctor',             color: '#37d6ff', active: false },
  { key: 'hospital',  label: 'Hospital',    icon: 'mdi-hospital-building',  color: '#5b8def', active: false },
  { key: 'lab',       label: 'Laboratory',  icon: 'mdi-flask',              color: '#1a56db', active: false },
  { key: 'radiology', label: 'Radiology',   icon: 'mdi-radiology-box',      color: '#4b8bf5', active: false },
  { key: 'homecare',  label: 'Homecare',    icon: 'mdi-home-heart',         color: '#143ce1', active: false },
  { key: 'insurance', label: 'Insurance',   icon: 'mdi-shield-check',       color: '#2f6dff', active: false },
  { key: 'analytics', label: 'Analytics',   icon: 'mdi-chart-areaspline',   color: '#64748b', active: false }
]

function go(n) {
  if (n.to) router.push(n.to)
}
</script>

<style scoped>
.gs-root {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  background: #f8fafc;
  color: #0a0f1f;
  display: flex;
  flex-direction: column;
}
.gs-fill { position: absolute; inset: 0; z-index: 0; }
.gs-bg {
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47,109,255,0.1), transparent 60%),
    radial-gradient(1000px 500px at 0% 110%, rgba(55,214,255,0.06), transparent 60%),
    #f8fafc;
}
.gs-grid {
  background-image:
    linear-gradient(rgba(15,23,42,0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15,23,42,0.03) 1px, transparent 1px);
  background-size: 44px 44px;
  mask-image: radial-gradient(1000px 700px at 50% 20%, #000 40%, transparent 80%);
}
.gs-blob { position: absolute; border-radius: 50%; filter: blur(70px); opacity: 0.5; z-index: 0; animation: gsFloat 14s ease-in-out infinite; }
.gs-blob-1 { width: 320px; height: 320px; background: rgba(47,109,255,0.2); top: -60px; right: 8%; }
.gs-blob-2 { width: 280px; height: 280px; background: rgba(55,214,255,0.12); bottom: -40px; left: 6%; animation-delay: 3s; }
.gs-blob-3 { width: 240px; height: 240px; background: rgba(47,109,255,0.1); top: 40%; left: 45%; animation-delay: 6s; }
@keyframes gsFloat { 0%,100% { transform: translateY(0) } 50% { transform: translateY(-24px) } }

/* Nav */
.gs-nav { position: relative; z-index: 5; }
.gs-nav-inner { max-width: 1180px; margin: 0 auto; }
.brand-lockup { cursor: pointer; }
.brand-badge {
  width: 34px; height: 34px; border-radius: 10px;
  background: linear-gradient(135deg, #2f6dff, #143ce1);
  box-shadow: 0 8px 24px rgba(47,109,255,0.3);
}
.brand-word { font-size: 20px; font-weight: 800; letter-spacing: -0.5px; }
.brand-word .bold { color: #0a0f1f; }
.brand-word .light { color: #2f6dff; }
.gs-link { color: rgba(15,23,42,0.6) !important; }
.gs-outline { color: #0a0f1f !important; border-color: rgba(15,23,42,0.2) !important; }

/* Header */
.gs-head { position: relative; z-index: 3; text-align: center; max-width: 720px; margin: 24px auto 8px; padding: 0 20px; }
.gs-eyebrow {
  display: inline-flex; align-items: center; gap: 8px;
  font-size: 12px; font-weight: 700; letter-spacing: 2px;
  color: #2f6dff; padding: 6px 14px; border-radius: 999px;
  background: rgba(47,109,255,0.08); border: 1px solid rgba(47,109,255,0.2);
  margin-bottom: 18px;
}
.gs-eyebrow .dot { width: 7px; height: 7px; border-radius: 50%; background: #2f6dff; box-shadow: 0 0 0 0 rgba(47,109,255,0.6); animation: gsPulse 2s infinite; }
@keyframes gsPulse { 0% { box-shadow: 0 0 0 0 rgba(47,109,255,0.5) } 70% { box-shadow: 0 0 0 10px rgba(47,109,255,0) } 100% { box-shadow: 0 0 0 0 rgba(47,109,255,0) } }
.gs-title { font-size: clamp(28px, 5vw, 46px); font-weight: 800; letter-spacing: -1px; margin-bottom: 12px; color: #0a0f1f; }
.grad-text { background: linear-gradient(90deg, #2f6dff, #37d6ff); -webkit-background-clip: text; background-clip: text; color: transparent; }
.gs-sub { color: #64748b; font-size: 15px; line-height: 1.7; }

/* Nodes grid */
.gs-grid-wrap { position: relative; z-index: 3; padding: 26px 20px 6px; }
.gs-nodes {
  max-width: 1100px; margin: 0 auto;
  display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
  gap: 18px;
}
.gs-node {
  position: relative;
  display: flex; flex-direction: column; align-items: center; gap: 10px;
  padding: 26px 18px 20px;
  border-radius: 20px;
  background: rgba(255,255,255,0.92);
  border: 1px solid rgba(15,23,42,0.08);
  backdrop-filter: blur(8px);
  color: inherit; text-align: center; cursor: pointer;
  overflow: hidden;
  opacity: 0; transform: translateY(18px);
  animation: gsReveal 0.6s ease forwards; animation-delay: var(--d);
  transition: transform 0.25s ease, border-color 0.25s ease, box-shadow 0.25s ease;
  box-shadow: 0 2px 12px rgba(10,15,31,0.04);
}
@keyframes gsReveal { to { opacity: 1; transform: translateY(0) } }
.gs-node.is-active:hover {
  transform: translateY(-6px);
  border-color: color-mix(in srgb, var(--accent) 55%, transparent);
  box-shadow: 0 18px 40px rgba(10,15,31,0.1), 0 0 0 1px color-mix(in srgb, var(--accent) 20%, transparent);
}
.gs-node.is-soon { cursor: not-allowed; opacity: 0.5; }
.gs-node-glow {
  position: absolute; inset: -1px; border-radius: 20px; z-index: 0; opacity: 0;
  background: radial-gradient(200px 120px at 50% 0%, color-mix(in srgb, var(--accent) 20%, transparent), transparent 70%);
  transition: opacity 0.3s ease;
}
.gs-node.is-active:hover .gs-node-glow { opacity: 1; }
.gs-node-ping {
  position: absolute; top: 14px; right: 14px; width: 9px; height: 9px; border-radius: 50%;
  background: var(--accent); box-shadow: 0 0 0 0 var(--accent);
  animation: gsPing 1.8s cubic-bezier(0,0,0.2,1) infinite;
}
@keyframes gsPing { 0% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--accent) 50%, transparent) } 70% { box-shadow: 0 0 0 12px transparent } 100% { box-shadow: 0 0 0 0 transparent } }
.gs-node-icon {
  position: relative; z-index: 1;
  width: 62px; height: 62px; border-radius: 18px;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 90%, #fff), color-mix(in srgb, var(--accent) 60%, #fff));
  box-shadow: 0 10px 24px color-mix(in srgb, var(--accent) 25%, transparent);
}
.gs-node.is-active .gs-node-icon { animation: gsBob 3s ease-in-out infinite; }
@keyframes gsBob { 0%,100% { transform: translateY(0) } 50% { transform: translateY(-5px) } }
.gs-node-label { position: relative; z-index: 1; font-size: 16px; font-weight: 700; color: #0a0f1f; }
.gs-node-status {
  position: relative; z-index: 1;
  display: inline-flex; align-items: center;
  font-size: 11px; font-weight: 600; letter-spacing: 0.3px;
  padding: 3px 10px; border-radius: 999px;
}
.gs-node.is-active .gs-node-status { color: #2f6dff; background: rgba(47,109,255,0.08); }
.gs-node.is-soon .gs-node-status { color: #94a3b8; background: rgba(148,163,184,0.1); }
.gs-node-cta {
  position: relative; z-index: 1;
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 13px; font-weight: 700; color: var(--accent);
  margin-top: 2px; opacity: 0; transform: translateY(4px);
  transition: opacity 0.25s ease, transform 0.25s ease;
}
.gs-node.is-active:hover .gs-node-cta { opacity: 1; transform: translateY(0); }

/* Note */
.gs-note-wrap { position: relative; z-index: 3; padding: 22px 20px 0; }
.gs-note {
  max-width: 760px; margin: 0 auto;
  display: flex; align-items: center;
  padding: 14px 18px; border-radius: 14px;
  background: rgba(47,109,255,0.05); border: 1px solid rgba(47,109,255,0.15);
  color: #475569; font-size: 13.5px; line-height: 1.6;
}
.gs-contact { color: #2f6dff; cursor: pointer; text-decoration: underline; }

.gs-footer { position: relative; z-index: 3; text-align: center; padding: 26px 20px; color: #94a3b8; font-size: 12.5px; margin-top: auto; }
</style>
