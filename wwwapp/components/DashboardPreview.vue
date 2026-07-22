<template>
  <div class="relative">
    <!-- glow -->
    <div class="absolute -inset-4 -z-10 rounded-[2rem] bg-brand-500/20 blur-3xl"></div>

    <div class="overflow-hidden rounded-2xl border border-white/10 bg-ink-950/90 shadow-card backdrop-blur">
      <!-- top bar -->
      <div class="flex items-center gap-2 border-b border-white/10 bg-white/[0.03] px-4 py-3">
        <span class="h-3 w-3 rounded-full bg-red-400/70"></span>
        <span class="h-3 w-3 rounded-full bg-amber-400/70"></span>
        <span class="h-3 w-3 rounded-full bg-emerald-400/70"></span>
        <div class="ml-3 flex items-center gap-2 rounded-md bg-white/5 px-3 py-1 text-[11px] text-slate-400">
          <span class="h-1.5 w-1.5 rounded-full bg-emerald-400"></span>
          app.adheremed.com / dashboard
        </div>
      </div>

      <div class="flex">
        <!-- sidebar -->
        <aside class="hidden w-14 shrink-0 flex-col items-center gap-4 border-r border-white/10 bg-white/[0.02] py-5 sm:flex">
          <div class="h-7 w-7 rounded-lg bg-gradient-to-br from-brand-400 to-cyanx-400"></div>
          <div v-for="n in 5" :key="n" class="h-7 w-7 rounded-lg bg-white/5"></div>
        </aside>

        <div class="flex-1 p-4 sm:p-5">
          <!-- header row -->
          <div class="mb-4 flex items-center justify-between">
            <div>
              <p class="text-[11px] uppercase tracking-wider text-slate-500">Population Health</p>
              <p class="font-display text-sm font-bold text-white">Adherence Overview</p>
            </div>
            <div class="flex gap-2">
              <span class="rounded-md bg-brand-500/15 px-2 py-1 text-[10px] font-semibold text-brand-200">Live</span>
              <span class="rounded-md bg-white/5 px-2 py-1 text-[10px] text-slate-400">Last 30d</span>
            </div>
          </div>

          <!-- stat cards -->
          <div class="grid grid-cols-3 gap-3">
            <div v-for="s in stats" :key="s.label" class="rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <p class="text-[10px] text-slate-500">{{ s.label }}</p>
              <p class="mt-1 font-display text-lg font-bold text-white">{{ s.value }}</p>
              <p class="text-[10px] font-semibold" :class="s.up ? 'text-emerald-400' : 'text-red-400'">
                {{ s.up ? '▲' : '▼' }} {{ s.delta }}
              </p>
            </div>
          </div>

          <!-- chart -->
          <div class="mt-3 rounded-xl border border-white/10 bg-white/[0.03] p-4">
            <div class="mb-3 flex items-center justify-between">
              <p class="text-xs font-semibold text-slate-300">API Requests / Adherence Rate</p>
              <p class="text-[10px] text-slate-500">7-day trend</p>
            </div>
            <svg viewBox="0 0 320 96" class="h-24 w-full">
              <defs>
                <linearGradient id="dash-area" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stop-color="#2f6dff" stop-opacity="0.45" />
                  <stop offset="100%" stop-color="#2f6dff" stop-opacity="0" />
                </linearGradient>
              </defs>
              <g stroke="rgba(255,255,255,0.06)">
                <line x1="0" y1="24" x2="320" y2="24" />
                <line x1="0" y1="48" x2="320" y2="48" />
                <line x1="0" y1="72" x2="320" y2="72" />
              </g>
              <path :d="areaPath" fill="url(#dash-area)" />
              <path :d="linePath" fill="none" stroke="#5996ff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
              <path :d="linePath2" fill="none" stroke="#37d6ff" stroke-width="2" stroke-dasharray="3 4" stroke-linecap="round" />
            </svg>
            <div class="mt-2 flex gap-4 text-[10px] text-slate-500">
              <span class="inline-flex items-center gap-1"><span class="h-1.5 w-3 rounded bg-brand-400"></span>Requests</span>
              <span class="inline-flex items-center gap-1"><span class="h-1.5 w-3 rounded bg-cyanx-400"></span>Adherence</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const stats = [
  { label: 'Active patients', value: '128.4k', delta: '12.6%', up: true },
  { label: 'Adherence rate', value: '91.2%', delta: '4.1%', up: true },
  { label: 'API uptime', value: '99.98%', delta: '0.2%', up: true }
]

const points = [12, 30, 22, 46, 38, 64, 58, 78, 70, 88]
const points2 = [40, 38, 44, 50, 48, 58, 60, 66, 70, 75]

function toPath(arr) {
  const w = 320
  const max = 96
  const step = w / (arr.length - 1)
  return arr
    .map((v, i) => `${i === 0 ? 'M' : 'L'} ${(i * step).toFixed(1)} ${(max - (v / 100) * max).toFixed(1)}`)
    .join(' ')
}

const linePath = computed(() => toPath(points))
const linePath2 = computed(() => toPath(points2))
const areaPath = computed(() => `${linePath.value} L 320 96 L 0 96 Z`)
</script>
