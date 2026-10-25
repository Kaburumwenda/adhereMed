<template>
  <div class="ttc">
    <!-- ── Legend: click a chip to isolate / restore a series ── -->
    <div v-if="showLegend" class="ttc__legend" role="group" aria-label="Toggle series">
      <button
        v-for="s in series"
        :key="s.id"
        type="button"
        class="ttc__chip"
        :class="{ 'is-off': isHidden(s.id) }"
        :style="{ '--chip': s.color }"
        :aria-pressed="!isHidden(s.id)"
        @click="toggle(s.id)"
      >
        <span class="ttc__swatch" />
        <span class="ttc__chip-label">{{ s.label }}</span>
        <span class="ttc__chip-total">{{ fmt(s.total ?? sum(s.values)) }}</span>
      </button>
      <button
        v-if="hidden.size"
        type="button"
        class="ttc__reset"
        @click="hidden = new Set()"
      >
        Show all
      </button>
    </div>

    <!-- ── Plot ── -->
    <div
      ref="plotRef"
      class="ttc__plot"
      :style="{ height: height + 'px' }"
      @mousemove="onMove"
      @mouseleave="onLeave"
      @touchstart.passive="onTouch"
      @touchmove.passive="onTouch"
      @touchend="onLeave"
    >
      <svg
        v-if="width > 0"
        :width="width"
        :height="height"
        :viewBox="`0 0 ${width} ${height}`"
        class="ttc__svg"
        role="img"
        :aria-label="ariaLabel"
      >
        <defs>
          <linearGradient
            v-for="s in visibleSeries"
            :id="gradId(s.id)"
            :key="`g-${s.id}`"
            x1="0" y1="0" x2="0" y2="1"
          >
            <stop offset="0%" :stop-color="s.color" stop-opacity="0.34" />
            <stop offset="55%" :stop-color="s.color" stop-opacity="0.11" />
            <stop offset="100%" :stop-color="s.color" stop-opacity="0.01" />
          </linearGradient>
        </defs>

        <!-- Horizontal grid -->
        <g class="ttc__grid">
          <line
            v-for="(tick, i) in yTicks"
            :key="`gy-${i}`"
            :x1="padL" :x2="width - padR"
            :y1="tick.y" :y2="tick.y"
            :class="{ 'is-base': i === yTicks.length - 1 }"
          />
        </g>

        <!-- Y labels -->
        <g class="ttc__ylabels">
          <text
            v-for="(tick, i) in yTicks"
            :key="`ty-${i}`"
            :x="padL - 10"
            :y="tick.y + 3.5"
            text-anchor="end"
          >{{ fmt(tick.value) }}</text>
        </g>

        <!-- Previous-period ghost (network total, dashed) -->
        <path
          v-if="showPrevious && previousPath"
          :d="previousPath"
          class="ttc__ghost"
        />

        <!-- Areas -->
        <g v-if="mode !== 'line'">
          <path
            v-for="s in visibleSeries"
            :key="`a-${s.id}`"
            :d="areaPath(s)"
            :fill="`url(#${gradId(s.id)})`"
            class="ttc__area"
          />
        </g>

        <!-- Lines -->
        <g>
          <path
            v-for="s in visibleSeries"
            :key="`l-${s.id}`"
            :d="linePath(s)"
            :stroke="s.color"
            class="ttc__line"
            :class="{ 'is-dim': hoverIndex === -1 }"
          />
        </g>

        <!-- Hover crosshair -->
        <g v-if="hoverIndex >= 0" class="ttc__cross">
          <line
            :x1="xAt(hoverIndex)" :x2="xAt(hoverIndex)"
            :y1="padT" :y2="padT + innerH"
          />
          <circle
            v-for="s in visibleSeries"
            :key="`c-${s.id}`"
            :cx="xAt(hoverIndex)"
            :cy="yAt(s.values[hoverIndex] ?? 0)"
            r="4.5"
            :fill="s.color"
            stroke="var(--ttc-surface, #fff)"
            stroke-width="2"
          />
        </g>
      </svg>

      <!-- Empty overlay -->
      <div v-if="!hasData" class="ttc__empty">
        <v-icon size="24">mdi-chart-timeline-variant-shimmer</v-icon>
        <span>No traffic recorded in this range</span>
      </div>

      <!-- Tooltip -->
      <div
        v-if="hoverIndex >= 0 && hasData"
        class="ttc__tip"
        :class="{ 'is-right': tipOnLeft }"
        :style="tipStyle"
      >
        <div class="ttc__tip-date">{{ labels[hoverIndex] }}</div>
        <div class="ttc__tip-rows">
          <div
            v-for="s in tipRows"
            :key="s.id"
            class="ttc__tip-row"
          >
            <span class="ttc__tip-dot" :style="{ background: s.color }" />
            <span class="ttc__tip-label">{{ s.label }}</span>
            <span class="ttc__tip-value">{{ fmt(s.value) }}</span>
          </div>
        </div>
        <div class="ttc__tip-foot">
          <span>Total</span>
          <b>{{ fmt(tipTotal) }}</b>
        </div>
      </div>
    </div>

    <!-- ── X axis ── -->
    <div class="ttc__axis" :style="{ paddingLeft: padL + 'px', paddingRight: padR + 'px' }">
      <span
        v-for="(l, i) in axisLabels"
        :key="`x-${i}`"
        class="ttc__tick"
        :class="{ 'is-hover': hoverIndex === i }"
        :style="{ left: axisPct(i) }"
      >{{ l.text }}</span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from 'vue'

const props = defineProps({
  /** [{ id, label, color, values: number[], total? }] */
  series: { type: Array, default: () => [] },
  /** Human labels per point (already formatted), same length as `values`. */
  labels: { type: Array, default: () => [] },
  /** Optional dashed comparison line (network previous period). */
  previous: { type: Array, default: () => [] },
  showPrevious: { type: Boolean, default: false },
  height: { type: Number, default: 260 },
  /** `area` (gradient fill) or `line`. */
  mode: { type: String, default: 'area' },
  showLegend: { type: Boolean, default: true },
  yFormatter: { type: Function, default: null }
})

const padL = 54
const padR = 14
const padT = 16
const padB = 10

const plotRef = ref(null)
const width = ref(0)
const hidden = ref(new Set())
const hoverIndex = ref(-1)

const innerW = computed(() => Math.max(1, width.value - padL - padR))
const innerH = computed(() => Math.max(1, props.height - padT - padB))

const pointCount = computed(() => Math.max(1, props.labels.length))

const visibleSeries = computed(() => props.series.filter(s => !isHidden(s.id)))

const hasData = computed(() =>
  visibleSeries.value.some(s => (s.values || []).some(v => Number(v) > 0))
)

// ── Scaling ────────────────────────────────────────────────────────────────
const Y_STEPS = 4

const maxValue = computed(() => {
  const vals = []
  visibleSeries.value.forEach(s => (s.values || []).forEach(v => vals.push(Number(v) || 0)))
  if (props.showPrevious) (props.previous || []).forEach(v => vals.push(Number(v) || 0))
  const peak = vals.length ? Math.max(...vals) : 0
  return axisMax(peak)
})

/** A nice 1/1.5/2/2.5/3/4/5/6/8 × 10^n multiplier for a per-step increment. */
const NICE_MULTS = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]

function niceStepAtLeast(raw) {
  if (!raw || raw <= 0) return 1
  const exp = Math.floor(Math.log10(raw))
  const base = Math.pow(10, exp)
  for (const m of NICE_MULTS) {
    const candidate = m * base
    if (candidate >= raw) return candidate
  }
  return 10 * base
}

/**
 * Top of the axis: the smallest nice step that still clears the peak, times the
 * step count. Every gridline then lands on a round number
 * (`0 / 1.5K / 3K / 4.5K / 6K`) with only a little unused headroom.
 */
function axisMax(peak) {
  if (!peak || peak <= 0) return Y_STEPS
  const step = niceStepAtLeast(peak / Y_STEPS)
  return step * Y_STEPS
}

const yTicks = computed(() => {
  // With nothing to plot, a stacked 1/2/3/4/0 axis just looks broken — show a
  // single baseline instead.
  if (!hasData.value) return [{ value: 0, y: padT + innerH.value }]
  const max = maxValue.value
  return Array.from({ length: Y_STEPS + 1 }, (_, i) => ({
    value: (max / Y_STEPS) * (Y_STEPS - i),
    y: padT + (i / Y_STEPS) * innerH.value
  }))
})

// ── Coordinates ────────────────────────────────────────────────────────────
function xAt(index) {
  const n = pointCount.value
  if (n <= 1) return padL + innerW.value / 2
  return padL + (index / (n - 1)) * innerW.value
}

function yAt(value) {
  const max = maxValue.value || 1
  const t = Math.min(1, Math.max(0, (Number(value) || 0) / max))
  return padT + (1 - t) * innerH.value
}

/**
 * Monotone cubic interpolation (Fritsch–Carlson). Plain Catmull-Rom overshoots
 * on spiky traffic data, which renders spikes that were never in the numbers —
 * this keeps the curve inside the data.
 */
function linePath(s) {
  const values = s.values || []
  if (values.length < 2) return ''
  const n = values.length
  const xs = values.map((_, i) => xAt(i))
  const ys = values.map(v => yAt(v))

  const dx = []
  const slope = []
  for (let i = 0; i < n - 1; i++) {
    dx[i] = xs[i + 1] - xs[i] || 1
    slope[i] = (ys[i + 1] - ys[i]) / dx[i]
  }

  const m = new Array(n)
  m[0] = slope[0]
  m[n - 1] = slope[n - 2]
  for (let i = 1; i < n - 1; i++) {
    if (slope[i - 1] * slope[i] <= 0) m[i] = 0
    else {
      const w1 = 2 * dx[i] + dx[i - 1]
      const w2 = dx[i] + 2 * dx[i - 1]
      m[i] = (w1 + w2) / (w1 / slope[i - 1] + w2 / slope[i])
    }
  }

  let d = `M ${xs[0].toFixed(2)} ${ys[0].toFixed(2)}`
  for (let i = 0; i < n - 1; i++) {
    const c1x = xs[i] + dx[i] / 3
    const c1y = ys[i] + (m[i] * dx[i]) / 3
    const c2x = xs[i + 1] - dx[i] / 3
    const c2y = ys[i + 1] - (m[i + 1] * dx[i]) / 3
    d += ` C ${c1x.toFixed(2)} ${c1y.toFixed(2)}, ${c2x.toFixed(2)} ${c2y.toFixed(2)}, ${xs[i + 1].toFixed(2)} ${ys[i + 1].toFixed(2)}`
  }
  return d
}

function areaPath(s) {
  const line = linePath(s)
  if (!line) return ''
  const n = (s.values || []).length
  const baseY = padT + innerH.value
  return `${line} L ${xAt(n - 1).toFixed(2)} ${baseY.toFixed(2)} L ${xAt(0).toFixed(2)} ${baseY.toFixed(2)} Z`
}

const previousPath = computed(() => {
  if (!props.previous?.length) return ''
  return linePath({ values: props.previous })
})

// ── Legend ─────────────────────────────────────────────────────────────────
function isHidden(id) { return hidden.value.has(id) }

function toggle(id) {
  const next = new Set(hidden.value)
  if (next.has(id)) next.delete(id)
  // Keep at least one series visible, otherwise the chart is just empty axes.
  else if (next.size < props.series.length - 1) next.add(id)
  else return
  hidden.value = next
}

function sum(values) {
  return (values || []).reduce((a, b) => a + (Number(b) || 0), 0)
}

const gradId = (id) => `ttc-${String(id).replace(/[^a-zA-Z0-9_-]/g, '')}-${uid}`
const uid = Math.random().toString(36).slice(2, 8)

// ── Formatting ─────────────────────────────────────────────────────────────
function fmt(v) {
  if (props.yFormatter) return props.yFormatter(v)
  const n = Number(v) || 0
  if (Math.abs(n) >= 1_000_000) return `${trim(n / 1_000_000)}M`
  if (Math.abs(n) >= 1_000) return `${trim(n / 1_000)}K`
  return trim(n)
}

/** One decimal only when it adds information (`2.5K` yes, `3.0K` no). */
function trim(n) {
  const r = Math.round(n * 10) / 10
  return Number.isInteger(r) ? String(r) : r.toFixed(1)
}

// ── Interaction ────────────────────────────────────────────────────────────
function indexFromX(clientX) {
  const rect = plotRef.value?.getBoundingClientRect()
  if (!rect) return -1
  const rel = clientX - rect.left - padL
  const n = pointCount.value
  if (n <= 1) return 0
  const step = innerW.value / (n - 1)
  const idx = Math.round(rel / (step || 1))
  return Math.min(n - 1, Math.max(0, idx))
}

function onMove(e) {
  hoverIndex.value = indexFromX(e.clientX)
}

function onTouch(e) {
  const t = e.touches?.[0]
  if (t) hoverIndex.value = indexFromX(t.clientX)
}

function onLeave() {
  hoverIndex.value = -1
}

const tipRows = computed(() => {
  if (hoverIndex.value < 0) return []
  return visibleSeries.value
    .map(s => ({
      id: s.id,
      label: s.label,
      color: s.color,
      value: Number(s.values?.[hoverIndex.value] || 0)
    }))
    .sort((a, b) => b.value - a.value)
})

const tipTotal = computed(() => tipRows.value.reduce((a, r) => a + r.value, 0))

const tipOnLeft = computed(() => xAt(Math.max(0, hoverIndex.value)) > width.value * 0.62)

const tipStyle = computed(() => {
  const x = xAt(Math.max(0, hoverIndex.value))
  return { left: `${Math.round(x)}px` }
})

// ── X axis ticks ───────────────────────────────────────────────────────────
const axisLabels = computed(() => {
  const labels = props.labels
  const n = labels.length
  if (!n) return []
  // Aim for a comfortable number of ticks for the available width.
  const maxTicks = Math.max(2, Math.min(10, Math.floor((width.value - padL - padR) / 78)))
  const stride = Math.max(1, Math.ceil(n / maxTicks))
  const out = []
  for (let i = 0; i < n; i += stride) out.push({ index: i, text: labels[i] })
  // Always anchor the last label when it would otherwise be dropped.
  const last = n - 1
  if (out.length && out[out.length - 1].index !== last) {
    if (last - out[out.length - 1].index < stride * 0.6) out.pop()
    out.push({ index: last, text: labels[last] })
  }
  return out
})

function axisPct(index) {
  const n = pointCount.value
  const ratio = n <= 1 ? 0.5 : index / (n - 1)
  return `${(padL + ratio * innerW.value)}px`
}

const ariaLabel = computed(() =>
  `Daily traffic for ${props.series.length} facilities over ${props.labels.length} days`
)

// ── Responsive width ───────────────────────────────────────────────────────
let ro = null

function measure() {
  const el = plotRef.value
  if (!el) return
  width.value = Math.round(el.clientWidth)
}

onMounted(async () => {
  await nextTick()
  measure()
  if (typeof ResizeObserver !== 'undefined' && plotRef.value) {
    ro = new ResizeObserver(measure)
    ro.observe(plotRef.value)
  } else if (typeof window !== 'undefined') {
    window.addEventListener('resize', measure)
  }
})

onBeforeUnmount(() => {
  ro?.disconnect()
  ro = null
  if (typeof window !== 'undefined') window.removeEventListener('resize', measure)
})

watch(() => props.series.map(s => s.id).join('|'), () => {
  // A range change can drop a facility; don't leave it stuck as hidden.
  const ids = new Set(props.series.map(s => s.id))
  const next = new Set([...hidden.value].filter(id => ids.has(id)))
  if (next.size !== hidden.value.size) hidden.value = next
  hoverIndex.value = -1
  nextTick(measure)
})

defineExpose({ measure })
</script>

<style scoped>
.ttc {
  --ttc-surface: var(--v-theme-surface, #fff);
  display: flex;
  flex-direction: column;
  gap: 10px;
  width: 100%;
}

/* ── Legend ── */
.ttc__legend {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
}
.ttc__chip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 5px 10px 5px 8px;
  border-radius: 999px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  background: transparent;
  font-family: inherit;
  cursor: pointer;
  transition: background-color 0.16s ease, border-color 0.16s ease, opacity 0.16s ease;
}
.ttc__chip:hover { background: rgba(var(--v-theme-on-surface), 0.04); }
.ttc__chip.is-off { opacity: 0.4; }
.ttc__chip.is-off .ttc__chip-total { text-decoration: line-through; }
.ttc__swatch {
  width: 9px;
  height: 9px;
  border-radius: 3px;
  flex: 0 0 auto;
  background: var(--chip);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--chip) 18%, transparent);
}
.ttc__chip-label {
  font-size: 11px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.78);
  white-space: nowrap;
}
.ttc__chip-total {
  font-size: 10.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: var(--chip);
}
.ttc__reset {
  margin-left: 2px;
  padding: 4px 9px;
  border-radius: 999px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.22);
  background: transparent;
  font-family: inherit;
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.6);
  cursor: pointer;
}
.ttc__reset:hover { color: rgb(var(--v-theme-primary)); border-color: currentColor; }

/* ── Plot ── */
.ttc__plot {
  position: relative;
  width: 100%;
  cursor: crosshair;
}
.ttc__svg { display: block; overflow: visible; }

.ttc__grid line {
  stroke: currentColor;
  stroke-opacity: 0.08;
  stroke-width: 1;
}
.ttc__grid line.is-base { stroke-opacity: 0.16; }

.ttc__ylabels text {
  font-size: 10px;
  font-weight: 700;
  fill: currentColor;
  fill-opacity: 0.42;
  font-variant-numeric: tabular-nums;
}

.ttc__area { transition: opacity 0.2s ease; }

.ttc__line {
  fill: none;
  stroke-width: 2.2;
  stroke-linecap: round;
  stroke-linejoin: round;
  transition: opacity 0.2s ease;
}
.ttc__line.is-dim { opacity: 0.85; }

.ttc__ghost {
  fill: none;
  stroke: currentColor;
  stroke-opacity: 0.28;
  stroke-width: 1.4;
  stroke-dasharray: 5 4;
  stroke-linecap: round;
}

.ttc__cross line {
  stroke: currentColor;
  stroke-opacity: 0.28;
  stroke-width: 1;
  stroke-dasharray: 4 3;
}

/* ── Tooltip ── */
.ttc__tip {
  position: absolute;
  top: 8px;
  z-index: 3;
  min-width: 168px;
  padding: 9px 11px;
  border-radius: 11px;
  pointer-events: none;
  transform: translateX(12px);
  background: rgba(var(--v-theme-surface, 255, 255, 255), 0.97);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
  box-shadow: 0 18px 38px -20px rgba(2, 6, 23, 0.5);
  backdrop-filter: blur(8px);
}
.ttc__tip.is-right { transform: translateX(calc(-100% - 12px)); }
.ttc__tip-date {
  margin-bottom: 6px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.ttc__tip-rows { display: flex; flex-direction: column; gap: 3px; }
.ttc__tip-row {
  display: grid;
  grid-template-columns: 7px minmax(0, 1fr) auto;
  align-items: center;
  gap: 6px;
}
.ttc__tip-dot { width: 7px; height: 7px; border-radius: 2px; }
.ttc__tip-label {
  font-size: 11px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.72);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ttc__tip-value {
  font-size: 11px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-on-surface));
}
.ttc__tip-foot {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin-top: 7px;
  padding-top: 6px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.ttc__tip-foot b {
  font-size: 11px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-on-surface));
}

/* ── X axis ── */
.ttc__axis {
  position: relative;
  height: 16px;
  margin-top: -4px;
}
.ttc__tick {
  position: absolute;
  top: 0;
  transform: translateX(-50%);
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.4);
  transition: color 0.15s ease;
}
.ttc__tick.is-hover { color: rgb(var(--v-theme-primary)); }

/* ── Empty ── */
.ttc__empty {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.4);
  pointer-events: none;
}
.ttc__empty .v-icon { opacity: 0.5; }

@media (prefers-reduced-motion: reduce) {
  .ttc__chip, .ttc__line, .ttc__area, .ttc__tick { transition: none; }
}
</style>
