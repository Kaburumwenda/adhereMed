<template>
  <div class="line-chart-outer" :style="{ height: height + 'px' }">
    <!-- Fixed Y-axis -->
    <svg v-if="showYAxis" class="line-chart-yaxis" :width="yAxisW" :height="height">
      <g>
        <text v-for="(t, i) in yTicks" :key="i"
          :x="yAxisW - 8"
          :y="padY + (i * (innerH / 3)) + 4"
          text-anchor="end"
          font-size="11"
          fill="currentColor"
          fill-opacity="0.55"
        >{{ t }}</text>
      </g>
    </svg>
    <div class="line-chart-wrap" :style="{ height: height + 'px' }">
      <div class="line-chart" :style="{ height: height + 'px', width: chartWidth + 'px', minWidth: '100%' }">
        <svg :viewBox="`0 0 ${chartWidth} ${height}`" preserveAspectRatio="none" :width="chartWidth" :height="height">
          <!-- Grid lines -->
          <g v-if="showGrid">
            <line v-for="i in 4" :key="i"
              :x1="padX" :x2="chartWidth - padX"
              :y1="padY + ((i - 1) * (innerH / 3))"
              :y2="padY + ((i - 1) * (innerH / 3))"
              stroke="currentColor" stroke-opacity="0.08" stroke-width="1" />
          </g>

          <!-- Series lines -->
          <g v-for="(s, si) in series" :key="si">
            <path :d="getPath(s.values)" fill="none" :stroke="s.color" stroke-width="2.5"
                  stroke-linejoin="round" stroke-linecap="round" />
            <circle v-for="(v, vi) in s.values" :key="vi"
                    :cx="getX(vi)" :cy="getY(v)" r="3" :fill="s.color">
              <title>{{ s.label }}: {{ v }}</title>
            </circle>
          </g>

          <!-- X Labels -->
          <g v-if="labels.length">
            <text v-for="(l, i) in displayLabels" :key="i"
                  :x="getX(labels.indexOf(l))"
                  :y="height - 4"
                  text-anchor="middle"
                  font-size="10"
                  fill="currentColor"
                  fill-opacity="0.5"
            >{{ l }}</text>
          </g>
        </svg>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  series: { type: Array, default: () => [] }, // [{ label, color, values: [] }]
  labels: { type: Array, default: () => [] },
  height: { type: Number, default: 220 },
  showGrid: { type: Boolean, default: true },
  showYAxis: { type: Boolean, default: true },
  yFormatter: { type: Function, default: null }
})

const padX = 30
const padY = 20
const yAxisW = 56
const baseWidth = 800

const innerW = computed(() => Math.max(baseWidth, props.labels.length * 40))
const chartWidth = computed(() => innerW.value + padX * 2)
const innerH = computed(() => props.height - padY * 2 - 20)

const allValues = computed(() => props.series.flatMap(s => s.values))
const max = computed(() => Math.max(1, ...allValues.value))
const min = computed(() => Math.min(0, ...allValues.value))

function getX(index) {
  const n = props.labels.length || 1
  return padX + (index / (n > 1 ? n - 1 : 1)) * innerW.value
}

function getY(value) {
  const range = max.value - min.value || 1
  const t = (value - min.value) / range
  return padY + (1 - t) * innerH.value
}

function getPath(values) {
  if (!values.length) return ''
  return values.map((v, i) => `${i === 0 ? 'M' : 'L'} ${getX(i)} ${getY(v)}`).join(' ')
}

function defaultFormat(v) {
  if (v >= 1_000_000) return (v / 1_000_000).toFixed(1) + 'M'
  if (v >= 1_000) return (v / 1_000).toFixed(1) + 'k'
  return Math.round(v).toString()
}

const fmt = (v) => (props.yFormatter ? props.yFormatter(v) : defaultFormat(v))
const yTicks = computed(() => {
  const m = max.value, lo = min.value
  const span = m - lo
  return [fmt(m), fmt(lo + span * 2/3), fmt(lo + span / 3), fmt(lo)]
})

const displayLabels = computed(() => {
  const arr = props.labels
  if (arr.length <= 10) return arr
  const step = Math.ceil(arr.length / 10)
  return arr.filter((_, i) => i % step === 0)
})
</script>

<style scoped>
.line-chart-outer { display: flex; width: 100%; }
.line-chart-yaxis { flex-shrink: 0; }
.line-chart-wrap { flex: 1; min-width: 0; overflow-x: auto; }
.line-chart-wrap::-webkit-scrollbar { height: 6px; }
.line-chart-wrap::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.1); border-radius: 3px; }
.line-chart svg { display: block; }
</style>
