<template>
  <div class="stock-flow-outer" :style="{ height: (height + 36) + 'px' }">
    <!-- Y-axis -->
    <svg class="sf-yaxis" :width="yAxisW" :height="height">
      <g>
        <text v-for="(t, i) in yTicks" :key="i"
          :x="yAxisW - 8"
          :y="padY + (i * (innerH / 4)) + 4"
          text-anchor="end"
          font-size="10"
          fill="currentColor"
          fill-opacity="0.5"
        >{{ t }}</text>
      </g>
    </svg>
    <!-- Chart body -->
    <div class="sf-body" :style="{ height: height + 'px' }">
      <svg :viewBox="`0 0 ${width} ${height}`" preserveAspectRatio="none" width="100%" :height="height">
        <defs>
          <linearGradient :id="gradIn" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stop-color="#22c55e" stop-opacity="0.45" />
            <stop offset="100%" stop-color="#22c55e" stop-opacity="0.02" />
          </linearGradient>
          <linearGradient :id="gradOut" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stop-color="#ef4444" stop-opacity="0.40" />
            <stop offset="100%" stop-color="#ef4444" stop-opacity="0.02" />
          </linearGradient>
        </defs>

        <!-- Horizontal grid lines (dashed) -->
        <g v-if="showGrid">
          <line v-for="i in 5" :key="i"
            :x1="padX" :x2="width - padX"
            :y1="padY + ((i - 1) * (innerH / 4))"
            :y2="padY + ((i - 1) * (innerH / 4))"
            stroke="currentColor" stroke-opacity="0.07" stroke-width="1"
            :stroke-dasharray="i === 5 ? '0' : '3,4'" />
        </g>

        <!-- Area + line: outflow (behind) -->
        <path v-if="outAreaPath" :d="outAreaPath" :fill="`url(#${gradOut})`" />
        <path v-if="outLinePath" :d="outLinePath" fill="none"
          stroke="#ef4444" stroke-width="2"
          stroke-linejoin="round" stroke-linecap="round"
          opacity="0.85" />

        <!-- Area + line: inflow (on top) -->
        <path v-if="inAreaPath" :d="inAreaPath" :fill="`url(#${gradIn})`" />
        <path v-if="inLinePath" :d="inLinePath" fill="none"
          stroke="#22c55e" stroke-width="2.5"
          stroke-linejoin="round" stroke-linecap="round"
          opacity="0.9" />

        <!-- Data dots (hidden until hover) -->
        <g v-if="hoverIndex >= 0">
          <circle
            v-if="inPoints[hoverIndex]"
            :cx="inPoints[hoverIndex].x" :cy="inPoints[hoverIndex].y"
            r="5" fill="#22c55e" stroke="white" stroke-width="2" />
          <circle
            v-if="outPoints[hoverIndex]"
            :cx="outPoints[hoverIndex].x" :cy="outPoints[hoverIndex].y"
            r="5" fill="#ef4444" stroke="white" stroke-width="2" />
          <!-- Vertical crosshair -->
          <line
            :x1="xAt(hoverIndex)" :x2="xAt(hoverIndex)"
            :y1="padY" :y2="padY + innerH"
            stroke="currentColor" stroke-opacity="0.25" stroke-width="1"
            stroke-dasharray="4,3" />
        </g>

        <!-- Mouse tracking overlay -->
        <rect
          :x="padX" :y="0" :width="innerW" :height="height"
          fill="transparent"
          @mousemove="onMouseMove" @mouseleave="onMouseLeave"
        />
      </svg>

      <!-- Tooltip -->
      <div v-if="hoverIndex >= 0 && tooltipData" class="sf-tooltip" :style="tooltipStyle">
        <div class="sf-tooltip-date">{{ tooltipData.label }}</div>
        <div class="sf-tooltip-row">
          <span class="sf-dot" style="background:#22c55e"></span>
          <span>Inflow</span>
          <span class="sf-tooltip-val" style="color:#22c55e">{{ tooltipData.inflow }}</span>
        </div>
        <div class="sf-tooltip-row">
          <span class="sf-dot" style="background:#ef4444"></span>
          <span>Outflow</span>
          <span class="sf-tooltip-val" style="color:#ef4444">{{ tooltipData.outflow }}</span>
        </div>
      </div>

      <!-- X-axis labels -->
      <div class="sf-xaxis">
        <div v-for="(l, i) in displayLabels" :key="i" class="sf-xlabel">{{ l }}</div>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  inflow: { type: Array, default: () => [] },
  outflow: { type: Array, default: () => [] },
  labels: { type: Array, default: () => [] },
  height: { type: Number, default: 200 },
  showGrid: { type: Boolean, default: true },
})

const width = 800
const padX = 16
const padY = 14
const yAxisW = 44

const innerW = computed(() => width - padX * 2)
const innerH = computed(() => props.height - padY * 2)

const gradIn = `sfin-${Math.random().toString(36).slice(2, 8)}`
const gradOut = `sfout-${Math.random().toString(36).slice(2, 8)}`

const max = computed(() => Math.max(1, ...props.inflow, ...props.outflow))

function fmt(v) {
  if (v >= 1_000_000) return (v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1) + 'M'
  if (v >= 1_000) return (v / 1_000).toFixed(v >= 10_000 ? 0 : 1) + 'k'
  return Math.round(v).toString()
}

const yTicks = computed(() => {
  const m = max.value
  return [fmt(m), fmt(m * 0.75), fmt(m * 0.5), fmt(m * 0.25), fmt(0)]
})

function xAt(i) {
  const n = props.inflow.length
  if (n <= 1) return padX + innerW.value / 2
  return padX + (i / (n - 1)) * innerW.value
}

function makePoints(arr) {
  const n = arr.length
  if (!n) return []
  return arr.map((v, i) => {
    const x = padX + (n === 1 ? innerW.value / 2 : (i / (n - 1)) * innerW.value)
    const t = v / max.value
    const y = padY + (1 - t) * innerH.value
    return { x, y }
  })
}

const inPoints = computed(() => makePoints(props.inflow))
const outPoints = computed(() => makePoints(props.outflow))

// Smooth cardinal spline path
function smoothPath(pts) {
  if (!pts.length) return ''
  if (pts.length < 3) return pts.map((p, i) => `${i ? 'L' : 'M'} ${p.x} ${p.y}`).join(' ')
  let d = `M ${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i === 0 ? 0 : i - 1]
    const p1 = pts[i]
    const p2 = pts[i + 1]
    const p3 = pts[i + 2 < pts.length ? i + 2 : i + 1]
    const t = 0.18 // tension
    const cp1x = p1.x + (p2.x - p0.x) * t
    const cp1y = p1.y + (p2.y - p0.y) * t
    const cp2x = p2.x - (p3.x - p1.x) * t
    const cp2y = p2.y - (p3.y - p1.y) * t
    d += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`
  }
  return d
}

const inLinePath = computed(() => smoothPath(inPoints.value))
const outLinePath = computed(() => smoothPath(outPoints.value))

function makeAreaPath(pts) {
  if (!pts.length) return ''
  const baseY = padY + innerH.value
  const line = smoothPath(pts)
  const last = pts[pts.length - 1]
  const first = pts[0]
  return `${line} L ${last.x.toFixed(1)} ${baseY} L ${first.x.toFixed(1)} ${baseY} Z`
}

const inAreaPath = computed(() => makeAreaPath(inPoints.value))
const outAreaPath = computed(() => makeAreaPath(outPoints.value))

const displayLabels = computed(() => {
  const arr = props.labels
  if (arr.length <= 8) return arr
  const step = Math.ceil(arr.length / 8)
  return arr.filter((_, i) => i % step === 0)
})

// --- Hover / Tooltip ---
const hoverIndex = ref(-1)
const hoverX = ref(0)

const tooltipData = computed(() => {
  if (hoverIndex.value < 0) return null
  return {
    label: props.labels[hoverIndex.value] || '',
    inflow: fmt(props.inflow[hoverIndex.value] ?? 0),
    outflow: fmt(props.outflow[hoverIndex.value] ?? 0),
  }
})

const tooltipStyle = computed(() => ({
  left: `clamp(60px, ${hoverX.value}%, calc(100% - 60px))`,
}))

function onMouseMove(e) {
  const svg = e.currentTarget.closest('svg')
  if (!svg) return
  const rect = svg.getBoundingClientRect()
  const pct = (e.clientX - rect.left) / rect.width
  const n = props.inflow.length
  if (!n) return
  const idx = Math.round((1 - 2 * padX / width) * pct * (n - 1))
  hoverIndex.value = Math.max(0, Math.min(n - 1, idx))
  hoverX.value = Math.max(0, Math.min(100, pct * 100))
}

function onMouseLeave() {
  hoverIndex.value = -1
}
</script>

<style scoped>
.stock-flow-outer {
  display: flex;
  align-items: stretch;
  width: 100%;
}
.sf-yaxis {
  flex-shrink: 0;
  display: block;
}
.sf-body {
  position: relative;
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.sf-body > svg { display: block; }

.sf-xaxis {
  display: flex;
  justify-content: space-between;
  padding: 6px 4px 0 4px;
  min-height: 22px;
}
.sf-xlabel {
  font-size: 10px;
  opacity: 0.5;
  text-align: center;
}

.sf-tooltip {
  position: absolute;
  top: 0;
  transform: translateX(-50%);
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.15);
  border-radius: 10px;
  padding: 8px 14px;
  pointer-events: none;
  white-space: nowrap;
  z-index: 10;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.18);
}
.sf-tooltip-date {
  font-size: 11px;
  font-weight: 700;
  margin-bottom: 4px;
  opacity: 0.85;
}
.sf-tooltip-row {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  line-height: 1.4;
}
.sf-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.sf-tooltip-val {
  margin-left: auto;
  font-weight: 700;
}
</style>
