<template>
  <NuxtLayout name="auth">
    <div class="pricing-root">
      <!-- Background -->
      <div class="bg-base bg-fill" />
      <div class="bg-grid bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />

      <!-- Top nav -->
      <header class="top-nav">
        <div class="nav-inner d-flex align-center px-4 px-md-10 py-3">
          <div class="brand-lockup d-flex align-center" style="cursor:pointer" @click="$router.push('/welcome')">
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
            class="text-none nav-link d-none d-md-inline-flex mr-1"
            rounded="lg"
            prepend-icon="mdi-arrow-left"
            @click="$router.push('/welcome')"
          >
            Home
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
            @click="$router.push('/register-pharmacy')"
          >
            Register Pharmacy
          </v-btn>
        </div>
      </header>

      <!-- HERO -->
      <section class="hero">
        <v-container class="content-wrapper text-center">
          <div class="eyebrow mb-5">
            <span class="dot" />
            USAGE-BASED PRICING
          </div>
          <h1 class="hero-title mb-5">
            Pay only for <span class="grad-text">what you use</span>
          </h1>
          <p class="hero-sub mb-2 mx-auto">
            Simple, transparent API pricing at
            <strong>$0.077 per 1,000 requests</strong>. No tiers, no lock-in, no surprises —
            your cost scales linearly with usage. Model your spend in real time below.
          </p>
        </v-container>
      </section>

      <!-- ESTIMATOR + CHART -->
      <section class="band">
        <v-container class="content-wrapper">
          <v-row>
            <!-- Estimator -->
            <v-col cols="12" md="5">
              <div class="panel">
                <div class="panel-kicker">USAGE ESTIMATOR</div>
                <div class="rate-pill mb-6">${{ RATE_PER_K.toFixed(3) }} / 1,000 requests</div>

                <div class="d-flex justify-space-between align-baseline mb-1">
                  <span class="slider-label">Monthly API requests</span>
                  <span class="slider-value">{{ fmtInt(requests) }}</span>
                </div>
                <v-slider
                  v-model="sliderPos"
                  :min="0"
                  :max="100"
                  :step="0.5"
                  hide-details
                  color="#3b82f6"
                  track-color="rgba(255,255,255,0.12)"
                  thumb-color="#60a5fa"
                  class="mt-1"
                />
                <div class="d-flex justify-space-between scale-marks mb-7">
                  <span>1K</span><span>100K</span><span>1M</span><span>10M</span><span>50M</span>
                </div>

                <div class="cost-hero mb-6">
                  <div class="cost-label">Estimated monthly cost</div>
                  <div class="cost-value">{{ fmtMoney(monthlyCost) }}</div>
                  <div class="cost-annual">{{ fmtMoney(annualCost) }} projected annually</div>
                </div>

                <div class="metric-rows">
                  <div class="metric-row">
                    <span>Requests / month</span>
                    <strong>{{ fmtInt(requests) }}</strong>
                  </div>
                  <div class="metric-row">
                    <span>Billable units (per 1K)</span>
                    <strong>{{ fmtInt(billableUnits) }}</strong>
                  </div>
                  <div class="metric-row">
                    <span>Effective cost / request</span>
                    <strong>${{ perRequest.toFixed(6) }}</strong>
                  </div>
                </div>
              </div>
            </v-col>

            <!-- Chart -->
            <v-col cols="12" md="7">
              <div class="panel chart-panel">
                <div class="d-flex align-center mb-1">
                  <div>
                    <div class="panel-kicker mb-0">COST VS. VOLUME ANALYSIS</div>
                    <div class="chart-sub">Linear, pay-as-you-go pricing — cost scales directly with usage.</div>
                  </div>
                  <v-spacer />
                  <div class="legend">
                    <span class="legend-dot" /> Monthly cost
                  </div>
                </div>

                <svg :viewBox="`0 0 ${chart.W} ${chart.H}`" class="chart-svg" preserveAspectRatio="none">
                  <defs>
                    <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stop-color="#3b82f6" stop-opacity="0.45" />
                      <stop offset="100%" stop-color="#3b82f6" stop-opacity="0" />
                    </linearGradient>
                    <linearGradient id="lineStroke" x1="0" y1="0" x2="1" y2="0">
                      <stop offset="0%" stop-color="#60a5fa" />
                      <stop offset="100%" stop-color="#2563eb" />
                    </linearGradient>
                  </defs>

                  <!-- horizontal gridlines + y labels -->
                  <g>
                    <line
                      v-for="(t, i) in chart.yTicks"
                      :key="'gy' + i"
                      :x1="chart.pl"
                      :x2="chart.W - chart.pr"
                      :y1="t.y"
                      :y2="t.y"
                      class="grid-line"
                    />
                    <text
                      v-for="(t, i) in chart.yTicks"
                      :key="'ly' + i"
                      :x="chart.pl - 2"
                      :y="t.y - 2"
                      class="axis-label y"
                    >{{ t.label }}</text>
                  </g>

                  <!-- area + line -->
                  <path :d="chart.area" fill="url(#areaGrad)" />
                  <path :d="chart.line" fill="none" stroke="url(#lineStroke)" stroke-width="2" stroke-linecap="round" />

                  <!-- current usage marker -->
                  <line :x1="chart.mx" :y1="chart.my" :x2="chart.mx" :y2="chart.baseY" class="marker-drop" />
                  <circle :cx="chart.mx" :cy="chart.my" r="4.5" class="marker-dot" />

                  <!-- x labels -->
                  <text
                    v-for="(t, i) in chart.xTicks"
                    :key="'lx' + i"
                    :x="t.x"
                    :y="chart.H - 6"
                    class="axis-label x"
                  >{{ t.label }}</text>
                </svg>

                <div class="chart-callout">
                  At <strong>{{ fmtInt(requests) }}</strong> requests / month your cost is
                  <strong>{{ fmtMoney(monthlyCost) }}</strong>.
                </div>
              </div>
            </v-col>
          </v-row>
        </v-container>
      </section>

      <!-- TIER TABLE -->
      <section class="band band-alt">
        <v-container class="content-wrapper">
          <div class="section-head text-center">
            <div class="kicker">REFERENCE PRICING</div>
            <h2 class="section-title">Cost at common volumes</h2>
            <p class="section-lead">Every request is billed at the same flat rate — these are just handy reference points.</p>
          </div>
          <div class="table-wrap">
            <table class="price-table">
              <thead>
                <tr>
                  <th>Monthly requests</th>
                  <th>Billable units (1K)</th>
                  <th class="ta-right">Monthly cost</th>
                  <th class="ta-right">Annual cost</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in tierRows" :key="row.req">
                  <td>{{ fmtInt(row.req) }}</td>
                  <td>{{ fmtInt(row.req / 1000) }}</td>
                  <td class="ta-right strong">{{ fmtMoney(row.req * RATE_PER_REQUEST) }}</td>
                  <td class="ta-right">{{ fmtMoney(row.req * RATE_PER_REQUEST * 12) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </v-container>
      </section>

      <!-- INCLUDED -->
      <section class="band">
        <v-container class="content-wrapper">
          <div class="section-head text-center">
            <div class="kicker">EVERY PLAN INCLUDES</div>
            <h2 class="section-title">No hidden fees. Full platform access.</h2>
          </div>
          <v-row justify="center">
            <v-col v-for="f in included" :key="f.title" cols="12" sm="6" md="4">
              <div class="incl-card">
                <v-icon size="22" color="#93C5FD" class="mb-3">{{ f.icon }}</v-icon>
                <div class="incl-title">{{ f.title }}</div>
                <div class="incl-desc">{{ f.desc }}</div>
              </div>
            </v-col>
          </v-row>
        </v-container>
      </section>

      <!-- CTA -->
      <section class="band">
        <v-container class="content-wrapper">
          <div class="cta-card">
            <div class="cta-glow" />
            <h2 class="cta-title">Start building on AdhereMed</h2>
            <p class="cta-sub">Transparent, usage-based pricing that grows with you.</p>
            <div class="d-flex flex-wrap justify-center">
              <v-btn size="large" class="text-none btn-primary mr-3 mb-3" rounded="lg" append-icon="mdi-arrow-right" @click="$router.push('/register-pharmacy')">
                Register your Pharmacy
              </v-btn>
              <v-btn size="large" variant="outlined" class="text-none btn-ghost mb-3" rounded="lg" @click="$router.push('/docs')">
                Read the docs
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
import { ref, computed } from 'vue'

definePageMeta({ layout: false })

const RATE_PER_K = 0.077
const RATE_PER_REQUEST = RATE_PER_K / 1000 // 0.000077

// Slider position 0..100 mapped logarithmically from 1,000 to 50,000,000 requests
const sliderPos = ref(53)
const MIN_REQ = 1000
const MAX_REQ = 50000000

const requests = computed(() => {
  const factor = MAX_REQ / MIN_REQ // 50,000
  return Math.round(MIN_REQ * Math.pow(factor, sliderPos.value / 100))
})
const monthlyCost = computed(() => requests.value * RATE_PER_REQUEST)
const annualCost = computed(() => monthlyCost.value * 12)
const billableUnits = computed(() => Math.round(requests.value / 1000))
const perRequest = RATE_PER_REQUEST

const tierRows = [
  { req: 100000 },
  { req: 500000 },
  { req: 1000000 },
  { req: 5000000 },
  { req: 25000000 }
]

const included = [
  { icon: 'mdi-api', title: 'Full API access', desc: 'Every endpoint across the platform with no feature gating.' },
  { icon: 'mdi-shield-lock', title: 'Security & compliance', desc: 'Encrypted data, audit trails and role-based access control.' },
  { icon: 'mdi-chart-box', title: 'Usage dashboards', desc: 'Real-time request, cost and adherence analytics down to the request.' },
  { icon: 'mdi-account-multiple', title: 'Unlimited users', desc: 'Add your whole team and connected actors at no extra seat cost.' },
  { icon: 'mdi-lifebuoy', title: 'Standard support', desc: 'Documentation, guides and responsive technical support.' },
  { icon: 'mdi-update', title: 'Continuous updates', desc: 'New modules and improvements rolled out automatically.' }
]

// ---------- Formatters ----------
const fmtInt = (n) => Number(n).toLocaleString('en-US')
const fmtMoney = (n) =>
  '$' + Number(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const fmtCompact = (n) =>
  new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(n)
const fmtMoneyCompact = (n) =>
  '$' + new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(n)

// ---------- Reactive chart geometry ----------
const chart = computed(() => {
  const W = 340, H = 180
  const pl = 36, pr = 10, pt = 14, pb = 24
  const plotW = W - pl - pr
  const plotH = H - pt - pb
  const baseY = pt + plotH

  const maxVol = Math.max(requests.value * 1.6, 1600)
  const maxCost = maxVol * RATE_PER_REQUEST

  const x = (v) => pl + (v / maxVol) * plotW
  const y = (c) => pt + plotH - (c / maxCost) * plotH

  const x0 = x(0), y0 = y(0)
  const x1 = x(maxVol), y1 = y(maxCost)
  const line = `M ${x0} ${y0} L ${x1} ${y1}`
  const area = `M ${x0} ${y0} L ${x1} ${y1} L ${x1} ${baseY} L ${x0} ${baseY} Z`

  const mx = x(requests.value)
  const my = y(monthlyCost.value)

  const yTicks = [0, 0.25, 0.5, 0.75, 1].map((f) => ({
    y: pt + plotH - f * plotH,
    label: fmtMoneyCompact(maxCost * f)
  }))
  const xTicks = [0, 0.5, 1].map((f) => ({
    x: pl + f * plotW,
    label: fmtCompact(maxVol * f)
  }))

  return { W, H, pl, pr, pt, pb, baseY, line, area, mx, my, yTicks, xTicks }
})
</script>

<style scoped>
/* ---------- Layout shell ---------- */
.pricing-root {
  position: relative;
  min-height: 100vh;
  overflow-x: hidden;
  color: #fff;
}
.bg-fill { position: fixed; inset: 0; }
.bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(37, 99, 235, 0.35), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(59, 130, 246, 0.18), transparent 55%),
    linear-gradient(160deg, #060b18 0%, #081226 45%, #0a1530 100%);
}
.bg-grid {
  z-index: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.04) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.04) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
}
.blob { position: fixed; border-radius: 50%; filter: blur(70px); z-index: 0; }
.blob-1 { top: -120px; right: -80px; width: 360px; height: 360px; background: rgba(37, 99, 235, 0.4); animation: float 14s ease-in-out infinite; }
.blob-2 { bottom: 5%; left: -120px; width: 420px; height: 420px; background: rgba(29, 78, 216, 0.28); animation: float 18s ease-in-out infinite reverse; }
.content-wrapper { position: relative; z-index: 2; max-width: 1180px; }

/* ---------- Brand lockup ---------- */
.brand-badge { width: 38px; height: 38px; border-radius: 11px; background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%); box-shadow: 0 6px 18px rgba(37, 99, 235, 0.5); }
.brand-badge.sm { width: 30px; height: 30px; border-radius: 9px; }
.brand-word { font-size: 20px; letter-spacing: -0.4px; }
.brand-word.small { font-size: 16px; }
.brand-word .bold { font-weight: 800; color: #fff; }
.brand-word .light { font-weight: 300; color: #60a5fa; }

/* ---------- Top nav ---------- */
.top-nav { position: sticky; top: 0; z-index: 20; backdrop-filter: blur(14px); background: rgba(6, 11, 24, 0.55); border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
.nav-inner { max-width: 1180px; margin: 0 auto; }
.nav-link { color: rgba(255, 255, 255, 0.78) !important; }
.nav-outline { color: #fff !important; border-color: rgba(255, 255, 255, 0.3) !important; }
.nav-cta { background: #fff !important; color: #0b1530 !important; font-weight: 600; }

/* ---------- Hero ---------- */
.hero { padding: 64px 0 8px; }
.eyebrow {
  display: inline-flex; align-items: center; gap: 9px;
  font-size: 12px; font-weight: 600; letter-spacing: 1.6px; color: #93c5fd;
  padding: 7px 14px; border-radius: 999px;
  background: rgba(59, 130, 246, 0.12); border: 1px solid rgba(96, 165, 250, 0.28);
}
.eyebrow .dot { width: 7px; height: 7px; border-radius: 50%; background: #60a5fa; box-shadow: 0 0 0 0 rgba(96, 165, 250, 0.7); animation: pulse 2s infinite; }
.hero-title { font-size: clamp(2.2rem, 4.6vw, 3.4rem); font-weight: 800; line-height: 1.08; letter-spacing: -1.2px; }
.grad-text {
  background: linear-gradient(90deg, #60a5fa, #93c5fd, #3b82f6);
  background-size: 200% auto;
  -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent;
  animation: shimmer 5s linear infinite;
}
.hero-sub { font-size: 1.05rem; line-height: 1.7; color: rgba(255, 255, 255, 0.72); max-width: 680px; }

/* ---------- Buttons ---------- */
.btn-primary { background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%) !important; color: #fff !important; font-weight: 600; box-shadow: 0 10px 26px rgba(37, 99, 235, 0.45); }
.btn-ghost { color: #fff !important; border-color: rgba(255, 255, 255, 0.28) !important; }

/* ---------- Sections ---------- */
.band { padding: 48px 0; position: relative; z-index: 2; }
.band-alt { background: rgba(255, 255, 255, 0.015); border-top: 1px solid rgba(255, 255, 255, 0.05); border-bottom: 1px solid rgba(255, 255, 255, 0.05); }
.section-head { max-width: 720px; margin: 0 auto 32px; }
.kicker { font-size: 12px; font-weight: 700; letter-spacing: 2px; color: #60a5fa; margin-bottom: 12px; }
.section-title { font-size: clamp(1.6rem, 3.2vw, 2.3rem); font-weight: 800; letter-spacing: -0.7px; margin-bottom: 12px; }
.section-lead { font-size: 1rem; line-height: 1.7; color: rgba(255, 255, 255, 0.66); }

/* ---------- Panels ---------- */
.panel {
  height: 100%;
  padding: 28px 26px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.09);
  backdrop-filter: blur(8px);
}
.panel-kicker { font-size: 11px; font-weight: 700; letter-spacing: 2px; color: #60a5fa; margin-bottom: 14px; }
.rate-pill {
  display: inline-block; font-size: 13px; font-weight: 700; color: #bfdbfe;
  padding: 6px 14px; border-radius: 999px;
  background: rgba(59, 130, 246, 0.14); border: 1px solid rgba(96, 165, 250, 0.3);
}
.slider-label { font-size: 0.86rem; color: rgba(255, 255, 255, 0.72); }
.slider-value { font-size: 1.05rem; font-weight: 800; color: #fff; }
.scale-marks { font-size: 0.68rem; color: rgba(255, 255, 255, 0.42); }

.cost-hero {
  border-radius: 16px; padding: 20px;
  background: linear-gradient(135deg, rgba(37, 99, 235, 0.2), rgba(10, 21, 48, 0.4));
  border: 1px solid rgba(96, 165, 250, 0.25);
}
.cost-label { font-size: 0.78rem; letter-spacing: 1px; text-transform: uppercase; color: rgba(255, 255, 255, 0.6); }
.cost-value { font-size: 2.6rem; font-weight: 800; line-height: 1.1; color: #fff; }
.cost-annual { font-size: 0.85rem; color: #93c5fd; }

.metric-rows { display: flex; flex-direction: column; gap: 2px; }
.metric-row { display: flex; justify-content: space-between; align-items: center; padding: 11px 2px; font-size: 0.9rem; color: rgba(255, 255, 255, 0.7); border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
.metric-row:last-child { border-bottom: 0; }
.metric-row strong { color: #fff; font-weight: 700; }

/* ---------- Chart ---------- */
.chart-panel { display: flex; flex-direction: column; }
.chart-sub { font-size: 0.82rem; color: rgba(255, 255, 255, 0.6); margin-top: 2px; }
.legend { font-size: 0.78rem; color: rgba(255, 255, 255, 0.66); display: flex; align-items: center; gap: 7px; }
.legend-dot { width: 10px; height: 10px; border-radius: 50%; background: #60a5fa; box-shadow: 0 0 8px rgba(96, 165, 250, 0.8); }
.chart-svg { width: 100%; height: auto; margin-top: 14px; flex: 1; }
.grid-line { stroke: rgba(255, 255, 255, 0.07); stroke-width: 0.6; }
.axis-label { fill: rgba(255, 255, 255, 0.45); font-size: 7px; font-family: inherit; }
.axis-label.y { text-anchor: end; }
.axis-label.x { text-anchor: middle; }
.marker-drop { stroke: rgba(96, 165, 250, 0.55); stroke-width: 1; stroke-dasharray: 2 2; }
.marker-dot { fill: #60a5fa; stroke: #fff; stroke-width: 1.5; filter: drop-shadow(0 0 6px rgba(96, 165, 250, 0.9)); }
.chart-callout { margin-top: 14px; font-size: 0.9rem; color: rgba(255, 255, 255, 0.74); }
.chart-callout strong { color: #fff; }

/* ---------- Table ---------- */
.table-wrap { max-width: 880px; margin: 0 auto; overflow-x: auto; border-radius: 18px; border: 1px solid rgba(255, 255, 255, 0.08); }
.price-table { width: 100%; border-collapse: collapse; min-width: 560px; }
.price-table th { text-align: left; font-size: 0.74rem; letter-spacing: 1px; text-transform: uppercase; color: #93c5fd; padding: 16px 20px; background: rgba(59, 130, 246, 0.08); border-bottom: 1px solid rgba(255, 255, 255, 0.08); }
.price-table td { padding: 15px 20px; font-size: 0.92rem; color: rgba(255, 255, 255, 0.78); border-bottom: 1px solid rgba(255, 255, 255, 0.05); }
.price-table tbody tr:last-child td { border-bottom: 0; }
.price-table tbody tr:hover { background: rgba(255, 255, 255, 0.03); }
.price-table .strong { color: #fff; font-weight: 700; }
.ta-right { text-align: right; }

/* ---------- Included ---------- */
.incl-card {
  height: 100%; padding: 24px 22px; border-radius: 18px;
  background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.08);
  transition: transform 0.3s ease, border-color 0.3s ease;
}
.incl-card:hover { transform: translateY(-5px); border-color: rgba(96, 165, 250, 0.5); }
.incl-title { font-size: 1.02rem; font-weight: 700; margin-bottom: 6px; }
.incl-desc { font-size: 0.88rem; line-height: 1.55; color: rgba(255, 255, 255, 0.62); }

/* ---------- CTA ---------- */
.cta-card { position: relative; max-width: 880px; margin: 0 auto; text-align: center; padding: 52px 32px; border-radius: 26px; background: linear-gradient(135deg, rgba(37, 99, 235, 0.18), rgba(10, 21, 48, 0.6)); border: 1px solid rgba(96, 165, 250, 0.28); overflow: hidden; }
.cta-glow { position: absolute; top: -50%; left: 50%; transform: translateX(-50%); width: 600px; height: 600px; background: radial-gradient(circle, rgba(59, 130, 246, 0.35), transparent 60%); pointer-events: none; }
.cta-title { position: relative; font-size: clamp(1.6rem, 3.2vw, 2.2rem); font-weight: 800; letter-spacing: -0.6px; margin-bottom: 12px; }
.cta-sub { position: relative; font-size: 1rem; color: rgba(255, 255, 255, 0.72); margin-bottom: 26px; }

/* ---------- Footer ---------- */
.footer { position: relative; z-index: 2; padding: 28px 0; border-top: 1px solid rgba(255, 255, 255, 0.06); }
.footer-note { font-size: 0.82rem; color: rgba(255, 255, 255, 0.45); }

/* ---------- Keyframes ---------- */
@keyframes float { 0%, 100% { transform: translate(0, 0); } 50% { transform: translate(20px, -28px); } }
@keyframes pulse { 0% { box-shadow: 0 0 0 0 rgba(96, 165, 250, 0.7); } 70% { box-shadow: 0 0 0 10px rgba(96, 165, 250, 0); } 100% { box-shadow: 0 0 0 0 rgba(96, 165, 250, 0); } }
@keyframes shimmer { to { background-position: 200% center; } }

@media (prefers-reduced-motion: reduce) {
  .blob, .grad-text, .eyebrow .dot { animation: none !important; }
}
</style>
