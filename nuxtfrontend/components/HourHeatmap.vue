<template>
  <div class="hour-heatmap">
    <!-- Summary strip -->
    <div class="hh-summary mb-3">
      <div class="hh-stat">
        <v-icon size="16" color="warning" class="mr-1">mdi-fire</v-icon>
        <span class="text-caption text-medium-emphasis">Peak</span>
        <span class="text-body-2 font-weight-bold ml-1">{{ peakHourLabel }}</span>
        <span class="text-caption text-medium-emphasis ml-1">· {{ peakValue }} {{ unit }}</span>
      </div>
      <div class="hh-stat">
        <v-icon size="16" color="info" class="mr-1">mdi-weather-sunset</v-icon>
        <span class="text-caption text-medium-emphasis">Busiest period</span>
        <span class="text-body-2 font-weight-bold ml-1">{{ busiestPeriodLabel }}</span>
      </div>
      <div class="hh-stat">
        <v-icon size="16" color="success" class="mr-1">mdi-counter</v-icon>
        <span class="text-caption text-medium-emphasis">Total</span>
        <span class="text-body-2 font-weight-bold ml-1">{{ total }}</span>
      </div>
    </div>

    <!-- Period bands -->
    <div class="hh-periods">
      <div v-for="p in periods" :key="p.key" class="hh-period" :style="{ flex: p.span }">
        <span class="hh-period-label">{{ p.label }}</span>
      </div>
    </div>

    <!-- Bars -->
    <div class="hh-grid" :style="{ '--hh-color': color }">
      <div
        v-for="h in 24" :key="h"
        class="hh-cell"
        :class="{ 'is-peak': (h - 1) === peakHour, 'is-empty': !(counts[h - 1]) }"
        :title="`${formatHour(h - 1)} — ${counts[h - 1] || 0} ${unit}`"
      >
        <div class="hh-tooltip">
          <div class="hh-tooltip-time">{{ formatHour(h - 1) }}</div>
          <div class="hh-tooltip-val">{{ counts[h - 1] || 0 }} {{ unit }}</div>
        </div>
        <div class="hh-bar-wrap">
          <div
            class="hh-bar"
            :style="{
              height: barHeight(counts[h - 1] || 0) + '%',
              background: heatColor(counts[h - 1] || 0)
            }"
          >
            <v-icon v-if="(h - 1) === peakHour" size="12" color="white" class="hh-crown">mdi-crown</v-icon>
          </div>
        </div>
        <div class="hh-label" :class="{ 'is-major': showLabel(h - 1) }">
          {{ showLabel(h - 1) ? formatHourShort(h - 1) : '' }}
        </div>
      </div>
    </div>

    <!-- Legend scale -->
    <div class="hh-legend mt-3">
      <span class="text-caption text-medium-emphasis">Less</span>
      <div class="hh-legend-bar">
        <div v-for="step in 5" :key="step" class="hh-legend-step" :style="{ background: heatColor(((step - 1) / 4) * (peakValue || 1)) }"></div>
      </div>
      <span class="text-caption text-medium-emphasis">More</span>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  counts: { type: Array, default: () => new Array(24).fill(0) }, // length 24
  unit: { type: String, default: 'sales' },
  color: { type: String, default: '#3b82f6' } // base hue for ramp
})

const peakValue = computed(() => Math.max(0, ...props.counts))
const peakHour = computed(() => {
  let p = 0, m = -1
  props.counts.forEach((v, i) => { if (v > m) { m = v; p = i } })
  return peakValue.value > 0 ? p : -1
})
const total = computed(() => props.counts.reduce((s, v) => s + (v || 0), 0))

const periods = [
  { key: 'night', label: 'Night', start: 0, end: 6 },
  { key: 'morning', label: 'Morning', start: 6, end: 12 },
  { key: 'afternoon', label: 'Afternoon', start: 12, end: 18 },
  { key: 'evening', label: 'Evening', start: 18, end: 24 }
].map(p => ({ ...p, span: p.end - p.start }))

const busiestPeriodLabel = computed(() => {
  let best = periods[0], bestSum = -1
  for (const p of periods) {
    let s = 0
    for (let h = p.start; h < p.end; h++) s += props.counts[h] || 0
    if (s > bestSum) { bestSum = s; best = p }
  }
  return best.label
})

const peakHourLabel = computed(() => peakHour.value < 0 ? '—' : formatHour(peakHour.value))

function formatHour(h) {
  const period = h < 12 ? 'AM' : 'PM'
  const hh = h % 12 === 0 ? 12 : h % 12
  return `${hh}:00 ${period}`
}
function formatHourShort(h) {
  if (h === 0) return '12a'
  if (h === 12) return '12p'
  return h < 12 ? `${h}a` : `${h - 12}p`
}
function showLabel(h) { return h % 3 === 0 }

function barHeight(v) {
  if (!peakValue.value) return 6
  // log-ish scale so small values still visible
  const t = v / peakValue.value
  const eased = Math.sqrt(t) // visually flatter
  return Math.max(v > 0 ? 10 : 4, eased * 100)
}

// Hex color ramp from cool blue → warm red via the supplied accent
function hexToRgb(hex) {
  const h = hex.replace('#', '')
  const n = parseInt(h.length === 3 ? h.split('').map(c => c + c).join('') : h, 16)
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
}
function rgb(r, g, b) { return `rgb(${r}, ${g}, ${b})` }
function lerp(a, b, t) { return Math.round(a + (b - a) * t) }
function lerpColor(c1, c2, t) {
  return rgb(lerp(c1.r, c2.r, t), lerp(c1.g, c2.g, t), lerp(c1.b, c2.b, t))
}
const COOL = { r: 191, g: 219, b: 254 }   // sky-200
const MID = { r: 59, g: 130, b: 246 }     // blue-500
const WARM = { r: 245, g: 158, b: 11 }    // amber-500
const HOT = { r: 239, g: 68, b: 68 }      // red-500

function heatColor(v) {
  if (!peakValue.value || !v) return 'rgba(148, 163, 184, 0.18)' // empty slate
  const t = v / peakValue.value
  if (t < 0.33) return lerpColor(COOL, MID, t / 0.33)
  if (t < 0.66) return lerpColor(MID, WARM, (t - 0.33) / 0.33)
  return lerpColor(WARM, HOT, (t - 0.66) / 0.34)
}
</script>

<style scoped>
.hour-heatmap { width: 100%; }

.hh-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 16px 24px;
  padding: 10px 12px;
  border-radius: 10px;
  background: rgba(var(--v-theme-primary), 0.04);
  border: 1px solid rgba(var(--v-theme-primary), 0.10);
}
.hh-stat { display: flex; align-items: center; }

.hh-periods {
  display: flex;
  margin-bottom: 6px;
  padding: 0 2px;
}
.hh-period {
  text-align: center;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
  padding-bottom: 4px;
}
.hh-period + .hh-period { border-left: 1px dashed rgba(var(--v-theme-on-surface), 0.08); }
.hh-period-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

.hh-grid {
  display: grid;
  grid-template-columns: repeat(24, minmax(0, 1fr));
  gap: 4px;
  align-items: end;
  padding: 4px 0 0;
}
.hh-cell {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  cursor: pointer;
}
.hh-bar-wrap {
  width: 100%;
  height: 110px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  background: linear-gradient(180deg, transparent 0%, rgba(var(--v-theme-on-surface), 0.025) 100%);
  border-radius: 6px;
}
.hh-bar {
  width: 100%;
  border-radius: 6px 6px 3px 3px;
  transition: transform 0.15s ease, filter 0.15s ease, box-shadow 0.15s ease;
  position: relative;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding-top: 2px;
}
.hh-cell:hover .hh-bar {
  transform: translateY(-2px);
  filter: brightness(1.08);
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.12);
}
.hh-cell.is-peak .hh-bar {
  box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.4), 0 4px 14px rgba(239, 68, 68, 0.25);
}
.hh-cell.is-empty .hh-bar { border: 1px dashed rgba(var(--v-theme-on-surface), 0.10); }
.hh-crown { filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.4)); }

.hh-label {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  height: 12px;
  line-height: 12px;
}
.hh-label.is-major {
  color: rgba(var(--v-theme-on-surface), 0.75);
  font-weight: 600;
}

/* Tooltip */
.hh-tooltip {
  position: absolute;
  bottom: calc(100% + 6px);
  left: 50%;
  transform: translateX(-50%) translateY(4px);
  background: rgba(15, 23, 42, 0.95);
  color: #fff;
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 11px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.15s ease, transform 0.15s ease;
  z-index: 5;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
}
.hh-tooltip::after {
  content: '';
  position: absolute;
  top: 100%; left: 50%;
  transform: translateX(-50%);
  border: 4px solid transparent;
  border-top-color: rgba(15, 23, 42, 0.95);
}
.hh-tooltip-time { font-weight: 700; }
.hh-tooltip-val { opacity: 0.85; }
.hh-cell:hover .hh-tooltip {
  opacity: 1;
  transform: translateX(-50%) translateY(0);
}

.hh-legend {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: flex-end;
}
.hh-legend-bar {
  display: flex;
  border-radius: 4px;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.hh-legend-step { width: 22px; height: 10px; }
</style>
