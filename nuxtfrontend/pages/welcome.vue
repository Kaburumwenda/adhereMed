<template>
  <NuxtLayout name="auth">
    <div class="welcome-root">
      <!-- Background -->
      <div class="bg-base bg-fill" />
      <div class="bg-grid bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />
      <div class="blob blob-3" />

      <!-- Top nav -->
      <header class="top-nav">
        <div class="nav-inner d-flex align-center px-4 px-md-10 py-3">
          <div class="brand-lockup d-flex align-center">
            <div class="brand-badge d-flex align-center justify-center mr-3">
              <v-icon size="18" color="white">mdi-heart-pulse</v-icon>
            </div>
            <span class="brand-word">
              <span class="bold">Adhere</span><span class="light">Med</span>
            </span>
          </div>
          <v-spacer />
          <v-btn
            variant="text"
            class="text-none nav-link d-none d-sm-inline-flex mr-1"
            rounded="lg"
            prepend-icon="mdi-tag-outline"
            @click="$router.push('/pricing')"
          >
            Pricing
          </v-btn>
          <v-btn
            variant="text"
            class="text-none nav-link d-none d-md-inline-flex mr-1"
            rounded="lg"
            prepend-icon="mdi-book-open-variant"
            @click="$router.push('/docs')"
          >
            Documentation
          </v-btn>
          <v-btn
            variant="outlined"
            class="text-none nav-outline mr-2"
            rounded="lg"
            @click="$router.push('/login')"
          >
            Sign In
          </v-btn>
          <v-btn
            class="text-none nav-cta"
            rounded="lg"
            @click="$router.push('/get-started')"
          >
            Get Started
          </v-btn>
        </div>
      </header>

      <!-- HERO -->
      <section class="hero">
        <v-container class="content-wrapper">
          <v-row align="center" class="hero-row">
            <v-col cols="12" md="6" class="hero-copy reveal">
              <div class="eyebrow mb-5">
                <span class="dot" />
                AFRICA'S HEALTHCARE OPERATING SYSTEM
              </div>
              <h1 class="hero-title mb-5">
                Connected Healthcare.
                <span class="grad-text">Simplified.</span>
              </h1>
              <p class="hero-sub mb-8">
                AdhereMed unifies patients, doctors, hospitals, pharmacies, labs, radiology,
                homecare, insurance and government into a single intelligent platform —
                improving medication adherence, care coordination and population health.
              </p>
              <div class="hero-actions d-flex flex-wrap mb-10">
                <v-btn
                  size="large"
                  class="text-none btn-primary mr-3 mb-3"
                  rounded="lg"
                  append-icon="mdi-arrow-right"
                  @click="$router.push('/get-started')"
                >
                  Get Started
                </v-btn>
                <v-btn
                  size="large"
                  variant="outlined"
                  class="text-none btn-ghost mb-3"
                  rounded="lg"
                  @click="$router.push('/login')"
                >
                  Launch the platform
                </v-btn>
              </div>
              <div class="stat-strip d-flex flex-wrap">
                <div v-for="s in stats" :key="s.label" class="stat-item">
                  <div class="stat-value">{{ s.value }}</div>
                  <div class="stat-label">{{ s.label }}</div>
                </div>
              </div>
            </v-col>

            <!-- Animated ecosystem orbit -->
            <v-col cols="12" md="6" class="d-flex justify-center reveal">
              <div class="orbit-stage">
                <div class="orbit-ring ring-outer" />
                <div class="orbit-ring ring-inner" />

                <!-- Radar sweep + expanding waves -->
                <div class="radar-sweep" />
                <div class="radar-wave" />
                <div class="radar-wave" style="animation-delay: 1s;" />
                <div class="radar-wave" style="animation-delay: 2s;" />

                <!-- Dotted data links with send/receive packets -->
                <svg class="orbit-lines" viewBox="0 0 100 100" preserveAspectRatio="none">
                  <g v-for="(n, i) in orbitNodes" :key="'link-' + n.label">
                    <line
                      x1="50"
                      y1="50"
                      :x2="nodePos(i, orbitNodes.length).x"
                      :y2="nodePos(i, orbitNodes.length).y"
                      class="dot-line"
                    />
                    <!-- sending: cloud -> node -->
                    <circle r="1.3" class="send-dot">
                      <animateMotion
                        :path="`M 50 50 L ${nodePos(i, orbitNodes.length).x} ${nodePos(i, orbitNodes.length).y}`"
                        dur="2.4s"
                        repeatCount="indefinite"
                        :begin="`${i * 0.3}s`"
                      />
                    </circle>
                    <!-- receiving: node -> cloud -->
                    <circle r="1.3" class="recv-dot">
                      <animateMotion
                        :path="`M ${nodePos(i, orbitNodes.length).x} ${nodePos(i, orbitNodes.length).y} L 50 50`"
                        dur="2.4s"
                        repeatCount="indefinite"
                        :begin="`${i * 0.3 + 1.2}s`"
                      />
                    </circle>
                  </g>
                </svg>

                <div class="orbit-core">
                  <span class="core-shadow" />
                  <span class="core-sphere">
                    <span class="core-shade" />
                    <span class="core-gloss" />
                    <span class="core-content">
                      <v-icon size="28" color="white">mdi-cloud</v-icon>
                      <span>AdhereMed<br>Cloud</span>
                    </span>
                  </span>
                </div>
                <div
                  v-for="(n, i) in orbitNodes"
                  :key="n.label"
                  class="orbit-node"
                  :style="orbitStyle(i, orbitNodes.length)"
                >
                  <div class="node-chip">
                    <v-icon size="18" color="#2f6dff">{{ n.icon }}</v-icon>
                  </div>
                  <span class="node-label">{{ n.label }}</span>
                </div>
              </div>
            </v-col>
          </v-row>
        </v-container>
      </section>

      <!-- ECOSYSTEM -->
      <section class="band">
        <v-container class="content-wrapper">
          <div class="section-head text-center reveal">
            <div class="kicker">THE ADHEREMED ECOSYSTEM</div>
            <h2 class="section-title">Every actor. One intelligent flow.</h2>
            <p class="section-lead">
              Healthcare is fragmented across disconnected systems. AdhereMed links them into a
              single flow — from the patient all the way to population analytics — with secure
              data flowing into one unified cloud.
            </p>
          </div>
          <v-row class="mt-2" justify="center">
            <v-col
              v-for="(a, i) in actors"
              :key="a.title"
              cols="6"
              sm="4"
              md="3"
              class="reveal"
              :style="{ '--d': i * 70 + 'ms' }"
            >
              <div class="actor-card">
                <div class="actor-index">{{ String(i + 1).padStart(2, '0') }}</div>
                <div class="actor-icon">
                  <v-icon size="26">{{ a.icon }}</v-icon>
                </div>
                <div class="actor-title">{{ a.title }}</div>
                <div class="actor-desc">{{ a.desc }}</div>
              </div>
            </v-col>
          </v-row>
        </v-container>
      </section>

      <!-- CAPABILITIES -->
      <section class="band band-alt">
        <v-container class="content-wrapper">
          <div class="section-head text-center reveal">
            <div class="kicker">PLATFORM CAPABILITIES</div>
            <h2 class="section-title">A full healthcare hub in one platform</h2>
            <p class="section-lead">
              Dashboards, workflows and integrations that simplify healthcare delivery for every
              actor in the ecosystem.
            </p>
          </div>
          <v-row class="mt-2">
            <v-col
              v-for="(c, i) in capabilities"
              :key="c.title"
              cols="12"
              sm="6"
              md="4"
              class="reveal"
              :style="{ '--d': i * 60 + 'ms' }"
            >
              <div class="cap-card">
                <div class="cap-icon">
                  <v-icon size="24" color="white">{{ c.icon }}</v-icon>
                </div>
                <div class="cap-title">{{ c.title }}</div>
                <div class="cap-desc">{{ c.desc }}</div>
              </div>
            </v-col>
          </v-row>
        </v-container>
      </section>

      <!-- SELF REGISTRATION NOTE -->
      <section class="band">
        <v-container class="content-wrapper">
          <div class="notice reveal">
            <v-icon size="22" color="#2f6dff" class="mr-3">mdi-information-outline</v-icon>
            <div>
              <strong>Self-registration:</strong> The <strong>Patient</strong> and
              <strong>Pharmacy</strong> modules are currently available for self-registration
              in your jurisdiction. For hospitals, laboratories, radiology centres or homecare
              facilities, please contact our team.
            </div>
          </div>
        </v-container>
      </section>

      <!-- CTA -->
      <section class="band">
        <v-container class="content-wrapper">
          <div class="cta-card reveal">
            <div class="cta-glow" />
            <h2 class="cta-title">Ready to connect your healthcare?</h2>
            <p class="cta-sub">Join the platform building Africa's healthcare operating system.</p>
            <div class="d-flex flex-wrap justify-center">
              <v-btn
                size="large"
                class="text-none btn-primary mr-3 mb-3"
                rounded="lg"
                append-icon="mdi-arrow-right"
                @click="$router.push('/get-started')"
              >
                Get started
              </v-btn>
              <v-btn
                size="large"
                variant="outlined"
                class="text-none btn-ghost mb-3"
                rounded="lg"
                @click="$router.push('/login')"
              >
                Sign In
              </v-btn>
            </div>
          </div>
        </v-container>
      </section>

      <!-- FOOTER -->
      <footer class="footer">
        <v-container class="content-wrapper d-flex flex-wrap align-center">
          <div class="brand-lockup d-flex align-center mb-2">
            <div class="brand-badge sm d-flex align-center justify-center mr-2">
              <v-icon size="14" color="white">mdi-heart-pulse</v-icon>
            </div>
            <span class="brand-word small">
              <span class="bold">Adhere</span><span class="light">Med</span>
            </span>
          </div>
          <v-spacer />
          <span class="footer-note">© 2026 AdhereMed. Connected Healthcare. Simplified.</span>
        </v-container>
      </footer>
    </div>
  </NuxtLayout>
</template>

<script setup>
import { onMounted, onBeforeUnmount } from 'vue'

definePageMeta({ layout: false })

const stats = [
  { value: '9+', label: 'Connected actors' },
  { value: '91%', label: 'Avg. adherence' },
  { value: '99.98%', label: 'Platform uptime' }
]

const orbitNodes = [
  { icon: 'mdi-account-heart', label: 'Patient' },
  { icon: 'mdi-doctor', label: 'Doctor' },
  { icon: 'mdi-hospital-building', label: 'Hospital' },
  { icon: 'mdi-medical-bag', label: 'Pharmacy' },
  { icon: 'mdi-flask', label: 'Lab' },
  { icon: 'mdi-shield-check', label: 'Insurance' },
  { icon: 'mdi-bank', label: 'Government' },
  { icon: 'mdi-chart-areaspline', label: 'Analytics' }
]

const actors = [
  { icon: 'mdi-account-heart', title: 'Patient', desc: 'Engagement, reminders & adherence' },
  { icon: 'mdi-doctor', title: 'Doctor', desc: 'Telemedicine & digital prescriptions' },
  { icon: 'mdi-hospital-building', title: 'Hospital', desc: 'Admissions, EMR & care coordination' },
  { icon: 'mdi-medical-bag', title: 'Pharmacy', desc: 'e-Prescriptions & dispensing' },
  { icon: 'mdi-flask', title: 'Laboratory', desc: 'Orders, results & diagnostics' },
  { icon: 'mdi-shield-check', title: 'Insurance', desc: 'Claims, approvals & coverage' },
  { icon: 'mdi-bank', title: 'Government', desc: 'Regulation, reporting & policy' },
  { icon: 'mdi-chart-areaspline', title: 'Population Analytics', desc: 'Insights, trends & public health' }
]

const capabilities = [
  { icon: 'mdi-pill', title: 'Medication Adherence', desc: 'Smart reminders, refill tracking and adherence scoring that keep patients on therapy.' },
  { icon: 'mdi-video-account', title: 'Telemedicine', desc: 'Secure video consultations, chat and remote triage connecting patients to clinicians anywhere.' },
  { icon: 'mdi-file-document-edit', title: 'Digital Prescriptions', desc: 'Paperless e-prescriptions routed instantly to any connected pharmacy with full audit trails.' },
  { icon: 'mdi-sitemap', title: 'Care Coordination', desc: 'Shared records and referral workflows that align doctors, hospitals, labs and homecare.' },
  { icon: 'mdi-account-group', title: 'Patient Engagement', desc: 'Personalised education, surveys and notifications in local languages that build trust.' },
  { icon: 'mdi-radiology-box', title: 'Lab & Radiology', desc: 'Order diagnostics, receive results and view imaging — fully integrated into the workflow.' },
  { icon: 'mdi-shield-account', title: 'Insurance & Claims', desc: 'Automated eligibility checks, pre-authorisation and claims that accelerate reimbursement.' },
  { icon: 'mdi-chart-box', title: 'Population Health', desc: 'Real-time dashboards and predictive analytics that surface disease trends and guide decisions.' },
  { icon: 'mdi-api', title: 'Open API Platform', desc: 'A developer-first API layer with usage-based billing so any system can plug into AdhereMed.' }
]

function nodePos(i, total) {
  const angle = (360 / total) * i - 90
  const rad = (angle * Math.PI) / 180
  const radius = 46 // % of stage
  return {
    x: 50 + radius * Math.cos(rad),
    y: 50 + radius * Math.sin(rad)
  }
}

function orbitStyle(i, total) {
  const { x, y } = nodePos(i, total)
  return {
    left: `${x}%`,
    top: `${y}%`,
    animationDelay: `${i * 0.4}s`
  }
}

let observer = null
onMounted(() => {
  if (typeof window === 'undefined' || !('IntersectionObserver' in window)) {
    document.querySelectorAll('.reveal').forEach((el) => el.classList.add('is-visible'))
    return
  }
  observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible')
          observer.unobserve(entry.target)
        }
      })
    },
    { threshold: 0.12 }
  )
  document.querySelectorAll('.reveal').forEach((el) => observer.observe(el))
})
onBeforeUnmount(() => observer && observer.disconnect())
</script>

<style scoped>
/* ---------- Layout shell ---------- */
.welcome-root {
  position: relative;
  min-height: 100vh;
  overflow-x: hidden;
  color: #0a0f1f;
}
.bg-fill {
  position: fixed;
  inset: 0;
}
.bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47, 109, 255, 0.1), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(55, 214, 255, 0.06), transparent 55%),
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
  position: fixed;
  border-radius: 50%;
  filter: blur(70px);
  z-index: 0;
}
.blob-1 {
  top: -120px;
  right: -80px;
  width: 360px;
  height: 360px;
  background: rgba(47, 109, 255, 0.15);
  animation: float 14s ease-in-out infinite;
}
.blob-2 {
  bottom: 5%;
  left: -120px;
  width: 420px;
  height: 420px;
  background: rgba(55, 214, 255, 0.1);
  animation: float 18s ease-in-out infinite reverse;
}
.blob-3 {
  top: 40%;
  right: 10%;
  width: 200px;
  height: 200px;
  background: rgba(47, 109, 255, 0.08);
  animation: float 12s ease-in-out infinite;
}
.content-wrapper {
  position: relative;
  z-index: 2;
  max-width: 1180px;
}

/* ---------- Brand lockup ---------- */
.brand-badge {
  width: 38px;
  height: 38px;
  border-radius: 11px;
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%);
  box-shadow: 0 6px 18px rgba(47, 109, 255, 0.35);
}
.brand-badge.sm {
  width: 30px;
  height: 30px;
  border-radius: 9px;
}
.brand-word {
  font-size: 20px;
  letter-spacing: -0.4px;
}
.brand-word.small {
  font-size: 16px;
}
.brand-word .bold {
  font-weight: 800;
  color: #0a0f1f;
}
.brand-word .light {
  font-weight: 300;
  color: #2f6dff;
}

/* ---------- Top nav ---------- */
.top-nav {
  position: sticky;
  top: 0;
  z-index: 20;
  backdrop-filter: blur(14px);
  background: rgba(255, 255, 255, 0.75);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}
.nav-inner {
  max-width: 1180px;
  margin: 0 auto;
}
.nav-link {
  color: rgba(15, 23, 42, 0.7) !important;
}
.nav-outline {
  color: #0a0f1f !important;
  border-color: rgba(15, 23, 42, 0.2) !important;
}
.nav-cta {
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 4px 14px rgba(47, 109, 255, 0.3);
}

/* ---------- Hero ---------- */
.hero {
  padding: 70px 0 40px;
}
.hero-row {
  min-height: 70vh;
}
.eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 1.6px;
  color: #2f6dff;
  padding: 7px 14px;
  border-radius: 999px;
  background: rgba(47, 109, 255, 0.08);
  border: 1px solid rgba(47, 109, 255, 0.2);
}
.eyebrow .dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #2f6dff;
  box-shadow: 0 0 0 0 rgba(47, 109, 255, 0.7);
  animation: pulse 2s infinite;
}
.hero-title {
  font-size: clamp(2.4rem, 5vw, 3.8rem);
  font-weight: 800;
  line-height: 1.05;
  letter-spacing: -1.5px;
  color: #0a0f1f;
}
.grad-text {
  background: linear-gradient(90deg, #2f6dff, #37d6ff, #143ce1);
  background-size: 200% auto;
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: shimmer 5s linear infinite;
}
.hero-sub {
  font-size: 1.08rem;
  line-height: 1.7;
  color: #475569;
  max-width: 540px;
}
.stat-strip {
  gap: 34px;
}
.stat-value {
  font-size: 1.7rem;
  font-weight: 800;
  color: #0a0f1f;
}
.stat-label {
  font-size: 0.8rem;
  color: #64748b;
}

/* ---------- Buttons ---------- */
.btn-primary {
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 10px 26px rgba(47, 109, 255, 0.35);
}
.btn-ghost {
  color: #0a0f1f !important;
  border-color: rgba(15, 23, 42, 0.2) !important;
}

/* ---------- Orbit visual ---------- */
.orbit-stage {
  position: relative;
  width: min(460px, 86vw);
  aspect-ratio: 1;
}
.orbit-ring {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  border: 1px dashed rgba(47, 109, 255, 0.2);
}
.ring-inner {
  inset: 18%;
  border-style: solid;
  border-color: rgba(47, 109, 255, 0.12);
  animation: spin 40s linear infinite;
}
.ring-outer {
  animation: spin 60s linear infinite reverse;
}

/* Radar sweep beam rotating from the cloud core */
.radar-sweep {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: conic-gradient(
    from 0deg,
    rgba(47, 109, 255, 0) 0deg,
    rgba(47, 109, 255, 0) 290deg,
    rgba(47, 109, 255, 0.12) 340deg,
    rgba(55, 214, 255, 0.35) 360deg
  );
  -webkit-mask: radial-gradient(circle, #000 0%, #000 99%, transparent 100%);
  mask: radial-gradient(circle, #000 0%, #000 99%, transparent 100%);
  animation: spin 4.5s linear infinite;
  z-index: 1;
  pointer-events: none;
}
/* Expanding radar waves */
.radar-wave {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 118px;
  height: 118px;
  transform: translate(-50%, -50%);
  border-radius: 50%;
  border: 1px solid rgba(47, 109, 255, 0.3);
  animation: radarWave 3s ease-out infinite;
  z-index: 1;
  pointer-events: none;
}
/* Dotted data links with send/receive packets */
.orbit-lines {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
  overflow: visible;
  pointer-events: none;
}
.dot-line {
  stroke: rgba(47, 109, 255, 0.5);
  stroke-width: 0.7;
  stroke-linecap: round;
  stroke-dasharray: 0.5 2.2;
  filter: drop-shadow(0 0 1.5px rgba(47, 109, 255, 0.4));
}
.send-dot {
  fill: #37d6ff;
  filter: drop-shadow(0 0 2px rgba(55, 214, 255, 0.7));
}
.recv-dot {
  fill: #2f6dff;
  filter: drop-shadow(0 0 2px rgba(47, 109, 255, 0.7));
}

.orbit-core {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 124px;
  height: 124px;
  transform: translate(-50%, -50%);
  z-index: 3;
  perspective: 420px;
  animation: coreFloat 6s ease-in-out infinite;
}
/* soft ground/contact shadow beneath the sphere */
.core-shadow {
  position: absolute;
  left: 50%;
  bottom: -14px;
  width: 78%;
  height: 22px;
  transform: translateX(-50%);
  border-radius: 50%;
  background: radial-gradient(ellipse at center, rgba(10, 15, 31, 0.2), transparent 70%);
  filter: blur(4px);
  animation: coreShadow 6s ease-in-out infinite;
}
/* the 3D ball */
.core-sphere {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background:
    radial-gradient(circle at 32% 26%, #37d6ff 0%, #2f6dff 34%, #143ce1 66%, #0c1e8a 100%);
  box-shadow:
    0 0 0 8px rgba(47, 109, 255, 0.08),
    0 18px 42px rgba(20, 60, 225, 0.35),
    inset -14px -16px 34px rgba(8, 16, 45, 0.5),
    inset 10px 12px 26px rgba(191, 219, 254, 0.35);
  transform: rotateX(12deg) rotateY(-12deg);
  animation: coreSpin 12s ease-in-out infinite;
}
/* inner bottom shading to deepen the curve */
.core-shade {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: radial-gradient(circle at 70% 82%, rgba(7, 13, 38, 0.4), transparent 55%);
  pointer-events: none;
}
/* glossy top highlight */
.core-gloss {
  position: absolute;
  top: 9%;
  left: 18%;
  width: 56%;
  height: 40%;
  border-radius: 50%;
  background: radial-gradient(ellipse at 50% 35%, rgba(255, 255, 255, 0.7), rgba(255, 255, 255, 0) 70%);
  filter: blur(1px);
  pointer-events: none;
}
.core-content {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  text-align: center;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.2;
  color: #fff;
  text-shadow: 0 1px 4px rgba(6, 12, 35, 0.6);
  z-index: 2;
}
.orbit-node {
  position: absolute;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  animation: nodeFloat 5s ease-in-out infinite;
  z-index: 2;
}
.node-chip {
  width: 50px;
  height: 50px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.8);
  border: 1px solid rgba(47, 109, 255, 0.15);
  backdrop-filter: blur(6px);
  transition: transform 0.25s ease, border-color 0.25s ease;
  box-shadow: 0 4px 12px rgba(10, 15, 31, 0.06);
}
.node-chip:hover {
  transform: scale(1.12);
  border-color: rgba(47, 109, 255, 0.5);
}
.node-label {
  font-size: 11px;
  font-weight: 600;
  color: #475569;
}

/* ---------- Sections ---------- */
.band {
  padding: 64px 0;
  position: relative;
  z-index: 2;
}
.band-alt {
  background: rgba(47, 109, 255, 0.02);
  border-top: 1px solid rgba(15, 23, 42, 0.05);
  border-bottom: 1px solid rgba(15, 23, 42, 0.05);
}
.section-head {
  max-width: 720px;
  margin: 0 auto 40px;
}
.kicker {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 2px;
  color: #2f6dff;
  margin-bottom: 12px;
}
.section-title {
  font-size: clamp(1.7rem, 3.4vw, 2.5rem);
  font-weight: 800;
  letter-spacing: -0.8px;
  margin-bottom: 14px;
  color: #0a0f1f;
}
.section-lead {
  font-size: 1.02rem;
  line-height: 1.7;
  color: #475569;
}

/* ---------- Actor cards ---------- */
.actor-card {
  position: relative;
  height: 100%;
  padding: 22px 18px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.8);
  border: 1px solid rgba(15, 23, 42, 0.06);
  backdrop-filter: blur(8px);
  transition: transform 0.3s ease, border-color 0.3s ease, background 0.3s ease;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(10, 15, 31, 0.04);
}
.actor-card:hover {
  transform: translateY(-6px);
  border-color: rgba(47, 109, 255, 0.3);
  background: rgba(47, 109, 255, 0.04);
  box-shadow: 0 8px 24px rgba(47, 109, 255, 0.1);
}
.actor-index {
  position: absolute;
  top: 14px;
  right: 16px;
  font-size: 12px;
  font-weight: 700;
  color: rgba(47, 109, 255, 0.35);
}
.actor-icon {
  width: 50px;
  height: 50px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 14px;
  color: #fff;
  background: linear-gradient(135deg, rgba(47, 109, 255, 0.2), rgba(20, 60, 225, 0.2));
  border: 1px solid rgba(47, 109, 255, 0.2);
}
.actor-icon :deep(.v-icon) {
  color: #2f6dff;
}
.actor-title {
  font-size: 1.02rem;
  font-weight: 700;
  margin-bottom: 4px;
  color: #0a0f1f;
}
.actor-desc {
  font-size: 0.84rem;
  line-height: 1.45;
  color: #64748b;
}

/* ---------- Capability cards ---------- */
.cap-card {
  height: 100%;
  padding: 26px 24px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.8);
  border: 1px solid rgba(15, 23, 42, 0.06);
  transition: transform 0.3s ease, border-color 0.3s ease;
  box-shadow: 0 2px 12px rgba(10, 15, 31, 0.04);
}
.cap-card:hover {
  transform: translateY(-6px);
  border-color: rgba(47, 109, 255, 0.3);
  box-shadow: 0 8px 24px rgba(47, 109, 255, 0.1);
}
.cap-icon {
  width: 48px;
  height: 48px;
  border-radius: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16px;
  background: linear-gradient(135deg, #2f6dff, #143ce1);
  box-shadow: 0 8px 20px rgba(47, 109, 255, 0.3);
}
.cap-title {
  font-size: 1.1rem;
  font-weight: 700;
  margin-bottom: 8px;
  color: #0a0f1f;
}
.cap-desc {
  font-size: 0.9rem;
  line-height: 1.6;
  color: #475569;
}

/* ---------- Notice ---------- */
.notice {
  display: flex;
  align-items: flex-start;
  max-width: 880px;
  margin: 0 auto;
  padding: 18px 22px;
  border-radius: 16px;
  background: rgba(47, 109, 255, 0.05);
  border: 1px solid rgba(47, 109, 255, 0.15);
  font-size: 0.92rem;
  line-height: 1.6;
  color: #334155;
}

/* ---------- CTA ---------- */
.cta-card {
  position: relative;
  max-width: 880px;
  margin: 0 auto;
  text-align: center;
  padding: 56px 32px;
  border-radius: 26px;
  background: linear-gradient(135deg, rgba(47, 109, 255, 0.08), rgba(255, 255, 255, 0.6));
  border: 1px solid rgba(47, 109, 255, 0.15);
  overflow: hidden;
}
.cta-glow {
  position: absolute;
  top: -50%;
  left: 50%;
  transform: translateX(-50%);
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, rgba(47, 109, 255, 0.12), transparent 60%);
  pointer-events: none;
}
.cta-title {
  position: relative;
  font-size: clamp(1.6rem, 3.2vw, 2.3rem);
  font-weight: 800;
  letter-spacing: -0.6px;
  margin-bottom: 12px;
  color: #0a0f1f;
}
.cta-sub {
  position: relative;
  font-size: 1.02rem;
  color: #475569;
  margin-bottom: 28px;
}

/* ---------- Footer ---------- */
.footer {
  position: relative;
  z-index: 2;
  padding: 28px 0;
  border-top: 1px solid rgba(15, 23, 42, 0.06);
}
.footer-note {
  font-size: 0.82rem;
  color: #94a3b8;
}

/* ---------- Reveal animation ---------- */
.reveal {
  opacity: 0;
  transform: translateY(28px);
  transition: opacity 0.7s ease, transform 0.7s ease;
  transition-delay: var(--d, 0ms);
}
.reveal.is-visible {
  opacity: 1;
  transform: none;
}

/* ---------- Keyframes ---------- */
@keyframes float {
  0%, 100% { transform: translate(0, 0); }
  50% { transform: translate(20px, -28px); }
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
@keyframes pulse {
  0% { box-shadow: 0 0 0 0 rgba(47, 109, 255, 0.7); }
  70% { box-shadow: 0 0 0 10px rgba(47, 109, 255, 0); }
  100% { box-shadow: 0 0 0 0 rgba(47, 109, 255, 0); }
}
@keyframes coreFloat {
  0%, 100% { transform: translate(-50%, -50%); }
  50% { transform: translate(-50%, -58%); }
}
@keyframes coreShadow {
  0%, 100% { opacity: 0.85; transform: translateX(-50%) scale(1); }
  50% { opacity: 0.5; transform: translateX(-50%) scale(0.82); }
}
@keyframes coreSpin {
  0% { transform: rotateX(12deg) rotateY(-14deg); }
  50% { transform: rotateX(12deg) rotateY(14deg); }
  100% { transform: rotateX(12deg) rotateY(-14deg); }
}
@keyframes nodeFloat {
  0%, 100% { transform: translate(-50%, -50%); }
  50% { transform: translate(-50%, -62%); }
}
@keyframes shimmer {
  to { background-position: 200% center; }
}
@keyframes radarWave {
  0% { width: 118px; height: 118px; opacity: 0.55; }
  100% { width: 100%; height: 100%; opacity: 0; }
}

@media (max-width: 960px) {
  .hero { padding: 48px 0 20px; }
  .hero-copy { text-align: center; }
  .hero-sub { margin-left: auto; margin-right: auto; }
  .eyebrow { margin-left: auto; margin-right: auto; }
  .hero-actions, .stat-strip { justify-content: center; }
  .orbit-stage { margin-top: 24px; }
}

@media (prefers-reduced-motion: reduce) {
  .blob, .ring-inner, .ring-outer, .orbit-node, .orbit-core, .core-sphere, .core-shadow,
  .grad-text, .eyebrow .dot, .radar-sweep, .radar-wave {
    animation: none !important;
  }
  .reveal { transition: none; opacity: 1; transform: none; }
}
</style>
