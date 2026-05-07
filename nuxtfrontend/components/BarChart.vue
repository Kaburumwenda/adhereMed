<template>
  <div class="bar-chart-outer" :style="{ height: (height + extraBottom) + 'px' }">
    <!-- Fixed Y-axis (does not scroll) -->
    <svg class="bar-chart-yaxis" :width="yAxisW" :height="height + extraBottom">
      <g>
        <text v-for="(t, i) in yTicks" :key="i"
          :x="yAxisW - 6"
          :y="padY + ((i) * (innerH / 3)) + 4"
          text-anchor="end"
          font-size="11"
          fill="currentColor"
          fill-opacity="0.55"
        >{{ t }}</text>
      </g>
    </svg>
    <div class="bar-chart-wrap" :style="{ height: (height + extraBottom) + 'px' }">
      <div class="bar-chart" :style="{ height: (height + extraBottom) + 'px', width: chartWidth + 'px', minWidth: '100%' }">
        <svg :viewBox="`0 0 ${chartWidth} ${height + extraBottom}`" preserveAspectRatio="none" :width="chartWidth" :height="height + extraBottom">
          <!-- Grid lines -->
          <g v-if="showGrid">
            <line v-for="i in 4" :key="i"
              :x1="padX" :x2="chartWidth - padX"
              :y1="padY + ((i - 1) * (innerH / 3))"
              :y2="padY + ((i - 1) * (innerH / 3))"
              stroke="currentColor" stroke-opacity="0.08" stroke-width="1" />
          </g>
          <!-- Bars -->
          <g>
            <rect v-for="(b, i) in bars" :key="i"
              :x="b.x" :y="b.y" :width="b.w" :height="b.h"
              :fill="b.color" rx="4" ry="4">
              <title>{{ b.label }}: {{ b.value }}</title>
            </rect>
          </g>
          <!-- Rotated labels -->
          <g v-if="rotateLabels">
            <text v-for="(b, i) in bars" :key="`l${i}`"
              :x="b.x + b.w / 2"
              :y="height - 2"
              text-anchor="end"
              font-size="11"
              fill="currentColor"
              fill-opacity="0.7"
              :transform="`rotate(-35 ${b.x + b.w / 2} ${height - 2})`"
            >{{ b.label }}</text>
          </g>
        </svg>
        <div v-if="!rotateLabels" class="d-flex justify-space-between mt-1 px-1">
          <div v-for="(l, i) in displayLabels" :key="i" class="text-caption text-medium-emphasis bar-label">{{ l }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  values: { type: Array, default: () => [] },
  labels: { type: Array, default: () => [] },
  colors: { type: Array, default: () => [] },
  color: { type: String, default: '#3b82f6' },
  height: { type: Number, default: 220 },
  showGrid: { type: Boolean, default: true },
  rotateLabels: { type: Boolean, default: false },
  minBarSlot: { type: Number, default: 0 },
  yFormatter: { type: Function, default: null }
})
const baseWidth = 800
const padX = 16
const padY = 12
const yAxisW = 48

const autoSlot = computed(() => props.rotateLabels ? 56 : 28)
const slotPx = computed(() => props.minBarSlot > 0 ? props.minBarSlot : autoSlot.value)

const chartWidth = computed(() => {
  const n = props.values.length || 1
  return Math.max(baseWidth, n * slotPx.value + padX * 2)
})
const innerW = computed(() => chartWidth.value - padX * 2)
const extraBottom = computed(() => props.rotateLabels ? 100 : 0)
const innerH = computed(() => props.height - padY * 2 - (props.rotateLabels ? 48 : 0))
const max = computed(() => Math.max(1, ...props.values))

function defaultFormat(v) {
  if (v >= 1_000_000) return (v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1) + 'M'
  if (v >= 1_000) return (v / 1_000).toFixed(v >= 10_000 ? 0 : 1) + 'k'
  return Math.round(v).toString()
}
const fmt = (v) => (props.yFormatter ? props.yFormatter(v) : defaultFormat(v))
const yTicks = computed(() => {
  const m = max.value
  return [fmt(m), fmt(m * 2 / 3), fmt(m / 3), fmt(0)]
})

const bars = computed(() => {
  const n = props.values.length
  if (!n) return []
  const slot = innerW.value / n
  const w = Math.max(4, slot * 0.7)
  return props.values.map((v, i) => {
    const t = v / max.value
    const h = t * innerH.value
    const x = padX + slot * i + (slot - w) / 2
    const y = padY + (innerH.value - h)
    return { x, y, w, h, value: v, label: props.labels[i] || '', color: props.colors[i] || props.color }
  })
})
const displayLabels = computed(() => {
  const arr = props.labels
  if (arr.length <= 12) return arr
  const step = Math.ceil(arr.length / 12)
  return arr.filter((_, i) => i % step === 0)
})
</script>

<style scoped>
.bar-chart-outer {
  display: flex;
  align-items: stretch;
  width: 100%;
}
.bar-chart-yaxis {
  flex-shrink: 0;
  display: block;
}
.bar-chart-wrap {
  flex: 1;
  min-width: 0;
  overflow-x: auto;
  overflow-y: hidden;
}
.bar-chart-wrap::-webkit-scrollbar { height: 8px; }
.bar-chart-wrap::-webkit-scrollbar-thumb {
  background: rgba(var(--v-theme-on-surface), 0.2);
  border-radius: 4px;
}
.bar-chart svg { display: block; }
.bar-label { flex: 1; text-align: center; font-size: 10px; }
</style>
