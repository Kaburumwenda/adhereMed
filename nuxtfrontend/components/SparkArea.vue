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
            <stop offset="0%" :stop-color="color" stop-opacity="0.35" />
            <stop offset="100%" :stop-color="color" stop-opacity="0.02" />
          </linearGradient>
        </defs>

        <!-- Y grid lines -->
        <g v-if="showGrid">
          <line v-for="(g, i) in 4" :key="i"
            :x1="padX" :x2="width - padX"
            :y1="padY + (i * (innerH / 3))"
            :y2="padY + (i * (innerH / 3))"
            stroke="currentColor" stroke-opacity="0.08" stroke-width="1" />
        </g>

        <!-- Area -->
        <path v-if="areaPath" :d="areaPath" :fill="`url(#${gradId})`" />
        <!-- Line -->
        <path v-if="linePath" :d="linePath" fill="none" :stroke="color" stroke-width="2.5"
          stroke-linejoin="round" stroke-linecap="round" />
        <!-- Dots -->
        <g>
          <circle v-for="(p, i) in points" :key="i"
            :cx="p.x" :cy="p.y" r="3" :fill="color" />
        </g>
      </svg>

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
  return points.value.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`).join(' ')
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
</style>
