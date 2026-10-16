<template>
  <v-card rounded="lg" class="bi-kpi pa-4 h-100" :elevation="flat ? 0 : 1" :border="flat">
    <div class="d-flex align-start justify-space-between mb-2">
      <v-avatar size="38" :color="color" variant="tonal">
        <v-icon size="20">{{ icon }}</v-icon>
      </v-avatar>
      <div class="d-flex flex-column align-end" style="gap:4px">
        <v-chip v-if="delta != null" size="x-small" :color="deltaColor" variant="tonal" class="font-weight-bold">
          <v-icon start size="12">{{ deltaIcon }}</v-icon>{{ deltaText }}
        </v-chip>
        <span v-if="deltaLabel" class="text-caption text-medium-emphasis">{{ deltaLabel }}</span>
      </div>
    </div>

    <div class="bi-kpi-title text-uppercase">{{ title }}</div>
    <div class="bi-kpi-value font-weight-bold mt-1">{{ value }}</div>
    <div v-if="sub" class="text-caption text-medium-emphasis">{{ sub }}</div>

    <div v-if="spark && spark.length > 1" class="bi-spark mt-3">
      <svg viewBox="0 0 100 26" preserveAspectRatio="none" width="100%" height="26">
        <polygon :points="sparkArea" :fill="strokeColor" fill-opacity="0.12" />
        <polyline
          :points="sparkPoints"
          fill="none"
          :stroke="strokeColor"
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
          vector-effect="non-scaling-stroke"
        />
      </svg>
    </div>

    <div v-if="target && target > 0" class="mt-3">
      <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-1">
        <span>Target attainment</span>
        <span class="font-weight-medium">{{ attainmentText }}%</span>
      </div>
      <v-progress-linear :model-value="attainmentBar" :color="attainmentColor" height="6" rounded />
    </div>

    <div v-if="hint" class="text-caption text-medium-emphasis mt-2">{{ hint }}</div>
    <slot />
  </v-card>
</template>

<script setup>
const props = defineProps({
  title: { type: String, required: true },
  value: { type: [String, Number], default: '—' },
  sub: { type: String, default: '' },
  /** Numeric value used for target-attainment maths (defaults to `value`). */
  valueNum: { type: Number, default: null },
  icon: { type: String, default: 'mdi-chart-line' },
  color: { type: String, default: 'primary' },
  delta: { type: Number, default: null },
  deltaLabel: { type: String, default: 'vs prev.' },
  /** When true, a falling number is good (e.g. stockouts, wastage). */
  invertDelta: { type: Boolean, default: false },
  target: { type: Number, default: 0 },
  hint: { type: String, default: '' },
  spark: { type: Array, default: () => [] },
  sparkColor: { type: String, default: '' },
  flat: { type: Boolean, default: false }
})

const goodWhenUp = computed(() => !props.invertDelta)
const numericValue = computed(() => (props.valueNum != null ? props.valueNum : Number(props.value) || 0))
const deltaPositive = computed(() => Number(props.delta) >= 0)
const deltaGood = computed(() => (goodWhenUp.value ? deltaPositive.value : !deltaPositive.value))
const deltaColor = computed(() => (!props.delta ? 'grey' : deltaGood.value ? 'success' : 'error'))
const deltaIcon = computed(() => (deltaPositive.value ? 'mdi-trending-up' : 'mdi-trending-down'))
const deltaText = computed(() => `${Math.abs(Number(props.delta) || 0).toFixed(1)}%`)

const strokeColor = computed(() => props.sparkColor || (deltaGood.value ? '#0d9488' : '#ef4444'))

const sparkPoints = computed(() => {
  const v = props.spark || []
  if (v.length < 2) return ''
  const max = Math.max(...v)
  const min = Math.min(...v)
  const range = max - min || 1
  return v
    .map((val, i) => {
      const x = (i / (v.length - 1)) * 100
      const y = 24 - ((Number(val) - min) / range) * 22
      return `${x.toFixed(2)},${y.toFixed(2)}`
    })
    .join(' ')
})

const sparkArea = computed(() => {
  const pts = sparkPoints.value
  if (!pts) return ''
  return `0,26 ${pts} 100,26`
})

const attainment = computed(() => (props.target ? (numericValue.value / props.target) * 100 : 0))
const attainmentText = computed(() => attainment.value.toFixed(1))
const attainmentBar = computed(() => Math.max(0, Math.min(100, attainment.value)))
const attainmentColor = computed(() => {
  const a = attainment.value
  if (a >= 100) return 'success'
  if (a >= 85) return 'warning'
  return 'error'
})
</script>

<style scoped>
.bi-kpi {
  transition: box-shadow 0.18s ease, transform 0.18s ease;
}
.bi-kpi:hover {
  box-shadow: 0 10px 26px rgba(15, 23, 42, 0.1) !important;
  transform: translateY(-1px);
}
.bi-kpi-title {
  font-size: 11px;
  letter-spacing: 0.7px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.bi-kpi-value {
  font-size: 24px;
  line-height: 1.15;
}
.bi-spark {
  height: 26px;
}
</style>
