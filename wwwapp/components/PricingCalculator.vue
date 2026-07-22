<template>
  <div class="grid gap-8 lg:grid-cols-[1fr_1.1fr]">
    <!-- Calculator panel -->
    <div class="card">
      <div class="flex items-center justify-between">
        <h3 class="font-display text-lg font-bold text-white">Usage estimator</h3>
        <span class="rounded-full bg-brand-500/15 px-3 py-1 text-xs font-semibold text-brand-200">
          ${{ RATE.toFixed(3) }} / 1,000 requests
        </span>
      </div>

      <div class="mt-6">
        <label class="flex items-baseline justify-between text-sm text-slate-400">
          <span>Monthly API requests</span>
          <span class="font-display text-base font-bold text-white">{{ formatInt(requests) }}</span>
        </label>
        <input
          v-model.number="sliderPos"
          type="range"
          min="0"
          max="100"
          step="0.5"
          class="range mt-3 w-full"
        />
        <div class="mt-2 flex justify-between text-[11px] text-slate-500">
          <span>1K</span><span>100K</span><span>1M</span><span>10M</span><span>100M+</span>
        </div>
      </div>

      <div class="mt-6 flex flex-wrap gap-2">
        <button
          v-for="p in presets"
          :key="p.value"
          class="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-semibold text-slate-300 transition hover:border-brand-400/50 hover:text-white"
          @click="setRequests(p.value)"
        >
          {{ p.label }}
        </button>
      </div>

      <!-- cost output -->
      <div class="mt-8 grid grid-cols-2 gap-4">
        <div class="rounded-2xl border border-brand-400/30 bg-brand-500/10 p-5">
          <p class="text-xs uppercase tracking-wider text-brand-200">Est. monthly cost</p>
          <p class="mt-1 font-display text-3xl font-extrabold text-white">${{ formatMoney(monthlyCost) }}</p>
        </div>
        <div class="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
          <p class="text-xs uppercase tracking-wider text-slate-500">Projected annual</p>
          <p class="mt-1 font-display text-3xl font-extrabold text-white">${{ formatMoney(monthlyCost * 12) }}</p>
        </div>
      </div>

      <dl class="mt-5 space-y-2 text-sm">
        <div class="flex justify-between border-b border-white/5 py-1.5">
          <dt class="text-slate-400">Requests / month</dt>
          <dd class="font-semibold text-white">{{ formatInt(requests) }}</dd>
        </div>
        <div class="flex justify-between border-b border-white/5 py-1.5">
          <dt class="text-slate-400">Billable units (1K)</dt>
          <dd class="font-semibold text-white">{{ formatInt(Math.ceil(requests / 1000)) }}</dd>
        </div>
        <div class="flex justify-between py-1.5">
          <dt class="text-slate-400">Effective cost / request</dt>
          <dd class="font-semibold text-white">${{ (RATE / 1000).toFixed(6) }}</dd>
        </div>
      </dl>
    </div>

    <!-- Chart panel -->
    <div class="card">
      <div class="flex items-center justify-between">
        <h3 class="font-display text-lg font-bold text-white">Cost vs. volume analysis</h3>
        <div class="flex gap-1 rounded-full border border-white/10 p-1">
          <button
            v-for="mode in ['Month', 'Year']"
            :key="mode"
            class="rounded-full px-3 py-1 text-xs font-semibold transition"
            :class="view === mode ? 'bg-brand-500 text-white' : 'text-slate-400 hover:text-white'"
            @click="view = mode"
          >
            {{ mode }}
          </button>
        </div>
      </div>

      <p class="mt-1 text-xs text-slate-500">
        Linear, pay-as-you-go pricing — your cost scales directly with usage.
      </p>

      <!-- area chart -->
      <div class="mt-6">
        <svg viewBox="0 0 460 220" class="w-full">
          <defs>
            <linearGradient id="pc-area" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#2f6dff" stop-opacity="0.5" />
              <stop offset="100%" stop-color="#2f6dff" stop-opacity="0" />
            </linearGradient>
          </defs>

          <!-- y grid + labels -->
          <g>
            <g v-for="(g, i) in yTicks" :key="'y' + i">
              <line x1="44" :y1="g.y" x2="452" :y2="g.y" stroke="rgba(255,255,255,0.06)" />
              <text x="38" :y="g.y + 3" text-anchor="end" class="fill-slate-500" style="font-size: 9px">${{ g.label }}</text>
            </g>
          </g>

          <!-- area + line -->
          <path :d="areaPath" fill="url(#pc-area)" />
          <path :d="linePath" fill="none" stroke="#5996ff" stroke-width="2.5" stroke-linecap="round" />

          <!-- current marker -->
          <line :x1="markerX" y1="20" :x2="markerX" y2="190" stroke="#37d6ff" stroke-width="1" stroke-dasharray="3 3" stroke-opacity="0.7" />
          <circle :cx="markerX" :cy="markerY" r="5" fill="#37d6ff" />
          <circle :cx="markerX" :cy="markerY" r="9" fill="none" stroke="#37d6ff" stroke-opacity="0.4" />
          <g :transform="`translate(${labelShift}, ${Math.max(markerY - 34, 8)})`">
            <rect x="-2" y="0" width="92" height="26" rx="6" fill="#0b1226" stroke="rgba(89,150,255,0.4)" />
            <text x="44" y="16" text-anchor="middle" class="fill-white" style="font-size: 10px; font-weight: 700">
              ${{ formatMoney(view === 'Year' ? monthlyCost * 12 : monthlyCost) }}
            </text>
          </g>

          <!-- x labels -->
          <g>
            <text v-for="(p, i) in xLabels" :key="'x' + i" :x="p.x" y="208" text-anchor="middle" class="fill-slate-500" style="font-size: 9px">{{ p.label }}</text>
          </g>
        </svg>
      </div>

      <!-- tier table -->
      <div class="mt-6 overflow-hidden rounded-xl border border-white/10">
        <table class="w-full text-left text-sm">
          <thead class="bg-white/[0.03] text-[11px] uppercase tracking-wider text-slate-500">
            <tr>
              <th class="px-4 py-2 font-semibold">Monthly requests</th>
              <th class="px-4 py-2 text-right font-semibold">Monthly</th>
              <th class="px-4 py-2 text-right font-semibold">Annual</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-white/5">
            <tr v-for="t in tiers" :key="t.req" class="text-slate-300">
              <td class="px-4 py-2.5">{{ formatInt(t.req) }}</td>
              <td class="px-4 py-2.5 text-right font-semibold text-white">${{ formatMoney(cost(t.req)) }}</td>
              <td class="px-4 py-2.5 text-right text-slate-400">${{ formatMoney(cost(t.req) * 12) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const RATE = 0.077 // USD per 1,000 requests
const MAX = 100_000_000 // 100M requests at top of slider

// logarithmic slider mapping 0..100 -> 1,000..100,000,000
const sliderPos = ref(50)

function posToRequests(pos) {
  const minLog = Math.log10(1000)
  const maxLog = Math.log10(MAX)
  const val = Math.pow(10, minLog + (pos / 100) * (maxLog - minLog))
  // round to a friendly number
  const mag = Math.pow(10, Math.floor(Math.log10(val)) - 1)
  return Math.max(1000, Math.round(val / mag) * mag)
}
function requestsToPos(req) {
  const minLog = Math.log10(1000)
  const maxLog = Math.log10(MAX)
  return ((Math.log10(req) - minLog) / (maxLog - minLog)) * 100
}

const requests = computed(() => posToRequests(sliderPos.value))
const view = ref('Month')

const monthlyCost = computed(() => cost(requests.value))
function cost(req) {
  return (req / 1000) * RATE
}

function setRequests(v) {
  sliderPos.value = Math.min(100, Math.max(0, requestsToPos(v)))
}

const presets = [
  { label: '100K', value: 100_000 },
  { label: '1M', value: 1_000_000 },
  { label: '10M', value: 10_000_000 },
  { label: '50M', value: 50_000_000 }
]

const tiers = [
  { req: 100_000 },
  { req: 500_000 },
  { req: 1_000_000 },
  { req: 5_000_000 },
  { req: 25_000_000 }
]

// ---- chart geometry ----
const chart = { x0: 44, x1: 452, y0: 20, y1: 190 }
const samples = 40
const maxReq = computed(() => requests.value * 1.6 + 1)

const curve = computed(() => {
  const pts = []
  for (let i = 0; i <= samples; i++) {
    const req = (maxReq.value / samples) * i
    const c = cost(req) * (view.value === 'Year' ? 12 : 1)
    pts.push({ req, c })
  }
  return pts
})

const maxCost = computed(() => Math.max(...curve.value.map((p) => p.c), 1))

function sx(req) {
  return chart.x0 + (req / maxReq.value) * (chart.x1 - chart.x0)
}
function sy(c) {
  return chart.y1 - (c / maxCost.value) * (chart.y1 - chart.y0)
}

const linePath = computed(() =>
  curve.value.map((p, i) => `${i === 0 ? 'M' : 'L'} ${sx(p.req).toFixed(1)} ${sy(p.c).toFixed(1)}`).join(' ')
)
const areaPath = computed(() => `${linePath.value} L ${chart.x1} ${chart.y1} L ${chart.x0} ${chart.y1} Z`)

const markerX = computed(() => sx(requests.value))
const markerY = computed(() => sy(monthlyCost.value * (view.value === 'Year' ? 12 : 1)))
const labelShift = computed(() => Math.min(Math.max(markerX.value - 44, 4), chart.x1 - 90))

const yTicks = computed(() => {
  const ticks = []
  for (let i = 0; i <= 4; i++) {
    const c = (maxCost.value / 4) * (4 - i)
    ticks.push({ y: chart.y0 + ((chart.y1 - chart.y0) / 4) * i, label: formatMoney(c) })
  }
  return ticks
})

const xLabels = computed(() => {
  const labels = []
  for (let i = 0; i <= 4; i++) {
    const req = (maxReq.value / 4) * i
    labels.push({ x: chart.x0 + ((chart.x1 - chart.x0) / 4) * i, label: shortNum(req) })
  }
  return labels
})

// ---- formatting ----
function formatInt(n) {
  return new Intl.NumberFormat('en-US').format(Math.round(n))
}
function formatMoney(n) {
  return new Intl.NumberFormat('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)
}
function shortNum(n) {
  if (n >= 1e9) return (n / 1e9).toFixed(1).replace(/\.0$/, '') + 'B'
  if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M'
  if (n >= 1e3) return (n / 1e3).toFixed(0) + 'K'
  return String(Math.round(n))
}
</script>

<style scoped>
.range {
  -webkit-appearance: none;
  appearance: none;
  height: 6px;
  border-radius: 999px;
  background: linear-gradient(90deg, #2f6dff, #37d6ff);
  outline: none;
}
.range::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  height: 20px;
  width: 20px;
  border-radius: 50%;
  background: #fff;
  border: 3px solid #2f6dff;
  box-shadow: 0 0 16px rgba(47, 109, 255, 0.7);
  cursor: pointer;
}
.range::-moz-range-thumb {
  height: 20px;
  width: 20px;
  border-radius: 50%;
  background: #fff;
  border: 3px solid #2f6dff;
  box-shadow: 0 0 16px rgba(47, 109, 255, 0.7);
  cursor: pointer;
}
</style>
