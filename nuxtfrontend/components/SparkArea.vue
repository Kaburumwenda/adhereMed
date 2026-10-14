<template>
  <div class="spark-area-outer" :style="{ height: height + 'px' }">
    <!-- Fixed Y-axis -->
    <svg v-if="showYAxis" class="spark-area-yaxis" :width="yAxisW" :height="height">
      <g>
        <text v-for="(t, i) in yTicks" :key="i"
          :x="yAxisW - 6"
          :y="padY + (i * (innerH / 3)) + 4"
          text-anchor="end"
          font-size="11"
          fill="currentColor"
          fill-opacity="0.55"
        >{{ t }}</text>
      </g>
    </svg>
    <div class="spark-area" :style="{ height: height + 'px', flex: 1, minWidth: 0 }">
      <svg :viewBox="`0 0 ${width} ${height}`" preserveAspectRatio="none" width="100%" :height="height">
        <defs>
          <linearGradient :id="gradId" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" :stop-color="color" stop-opacity="0.45" />
            <stop offset="50%" :stop-color="color" stop-opacity="0.15" />
            <stop offset="100%" :stop-color="color" stop-opacity="0.02" />
          </linearGradient>
        </defs>

        <!-- Y grid lines (dashed) -->
        <g v-if="showGrid">
          <line v-for="(g, i) in 4" :key="i"
            :x1="padX" :x2="width - padX"
            :y1="padY + (i * (innerH / 3))"
            :y2="padY + (i * (innerH / 3))"
            stroke="currentColor" stroke-opacity="0.07" stroke-width="1"
            :stroke-dasharray="i === 3 ? '0' : '3,4'" />
        </g>

        <!-- Area -->
        <path v-if="areaPath" :d="areaPath" :fill="`url(#${gradId})`" />
        <!-- Line (smooth) -->
        <path v-if="linePath" :d="linePath" fill="none" :stroke="color" stroke-width="2.5"
          stroke-linejoin="round" stroke-linecap="round" />
        <!-- Dots -->
        <g>
          <circle v-for="(p, i) in points" :key="i"
            :cx="p.x" :cy="p.y" r="2.5" :fill="color" fill-opacity="0.7" />
        </g>

        <!-- Hover indicator -->
        <g v-if="hoverIndex >= 0 && points[hoverIndex]">
          <line
            :x1="points[hoverIndex].x" :x2="points[hoverIndex].x"
            :y1="padY" :y2="padY + innerH"
            :stroke="color" stroke-opacity="0.4" stroke-width="1" stroke-dasharray="4,3" />
          <circle
            :cx="points[hoverIndex].x" :cy="points[hoverIndex].y"
            r="5" :fill="color" stroke="white" stroke-width="2" />
        </g>

        <!-- Mouse tracking overlay -->
        <rect
          :x="padX" :y="0" :width="innerW" :height="height"
          fill="transparent"
          @mousemove="onMouseMove" @mouseleave="onMouseLeave"
        />
      </svg>

      <!-- Tooltip -->
      <div v-if="hoverIndex >= 0 && tooltipData" class="spark-tooltip" :style="tooltipStyle">
        <div class="spark-tooltip-date">{{ tooltipData.label }}</div>
        <div class="spark-tooltip-val" :style="{ color: color }">{{ tooltipData.value }}</div>
      </div>

      <div class="d-flex justify-space-between mt-1 px-1">
        <div v-for="(l, i) in displayLabels" :key="i" class="text-caption text-medium-emphasis">{{ l }}</div>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  values: { type: Array, default: () => [] },
  labels: { type: Array, default: () => [] },
  height: { type: Number, default: 200 },
  color: { type: String, default: '#3b82f6' },
  showGrid: { type: Boolean, default: true },
  showYAxis: { type: Boolean, default: true },
  yFormatter: { type: Function, default: null }
})

const width = 800
const padX = 16
const padY = 12
const yAxisW = 56
const innerW = computed(() => width - padX * 2)
const innerH = computed(() => props.height - padY * 2)
const gradId = `sg-${Math.random().toString(36).slice(2, 9)}`

const max = computed(() => Math.max(1, ...props.values))
const min = computed(() => Math.min(0, ...props.values))

function defaultFormat(v) {
  if (v >= 1_000_000) return (v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1) + 'M'
  if (v >= 1_000) return (v / 1_000).toFixed(v >= 10_000 ? 0 : 1) + 'k'
  return Math.round(v).toString()
}
const fmt = (v) => (props.yFormatter ? props.yFormatter(v) : defaultFormat(v))
const yTicks = computed(() => {
  const m = max.value, lo = min.value
  const span = m - lo
  return [fmt(m), fmt(lo + span * 2 / 3), fmt(lo + span / 3), fmt(lo)]
})

const points = computed(() => {
  const n = props.values.length
  if (!n) return []
  return props.values.map((v, i) => {
    const x = padX + (n === 1 ? innerW.value / 2 : (i / (n - 1)) * innerW.value)
    const t = (v - min.value) / (max.value - min.value || 1)
    const y = padY + (1 - t) * innerH.value
    return { x, y }
  })
})

const linePath = computed(() => {
  if (!points.value.length) return ''
  if (points.value.length < 3)
    return points.value.map((p, i) => `${i ? 'L' : 'M'} ${p.x} ${p.y}`).join(' ')
  // Smooth cardinal spline
  let d = `M ${points.value[0].x.toFixed(1)} ${points.value[0].y.toFixed(1)}`
  for (let i = 0; i < points.value.length - 1; i++) {
    const p0 = points.value[i === 0 ? 0 : i - 1]
    const p1 = points.value[i]
    const p2 = points.value[i + 1]
    const p3 = points.value[i + 2 < points.value.length ? i + 2 : i + 1]
    const t = 0.18
    const cp1x = p1.x + (p2.x - p0.x) * t
    const cp1y = p1.y + (p2.y - p0.y) * t
    const cp2x = p2.x - (p3.x - p1.x) * t
    const cp2y = p2.y - (p3.y - p1.y) * t
    d += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`
  }
  return d
})

const areaPath = computed(() => {
  if (!points.value.length) return ''
  const baseY = padY + innerH.value
  const first = points.value[0]
  const last = points.value[points.value.length - 1]
  return `M ${first.x} ${baseY} ` +
    points.value.map(p => `L ${p.x} ${p.y}`).join(' ') +
    ` L ${last.x} ${baseY} Z`
})

const displayLabels = computed(() => {
  const arr = props.labels
  if (arr.length <= 8) return arr
  // Show ~8 evenly spaced labels for long ranges
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
    value: fmt(props.values[hoverIndex.value] ?? 0),
  }
})

const tooltipStyle = computed(() => ({
  left: `${hoverX.value}%`,
}))

function onMouseMove(e) {
  const svg = e.currentTarget.closest('svg')
  if (!svg) return
  const rect = svg.getBoundingClientRect()
  const pct = (e.clientX - rect.left) / rect.width
  const n = props.values.length
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
.spark-area-outer {
  display: flex;
  align-items: stretch;
  width: 100%;
}
.spark-area-yaxis {
  flex-shrink: 0;
  display: block;
}
.spark-area svg { display: block; }
.spark-area { position: relative; }
.spark-tooltip {
  position: absolute;
  top: 0;
  transform: translateX(-50%);
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.15);
  border-radius: 10px;
  padding: 6px 12px;
  pointer-events: none;
  white-space: nowrap;
  z-index: 10;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.18);
}
.spark-tooltip-date {
  font-size: 11px;
  font-weight: 700;
  opacity: 0.85;
  margin-bottom: 2px;
}
.spark-tooltip-val {
  font-size: 13px;
  font-weight: 700;
}
</style>
