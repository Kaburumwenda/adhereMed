<template>
  <div class="donut-ring" :style="{ width: size + 'px', height: size + 'px' }">
    <svg :width="size" :height="size" :viewBox="`0 0 ${size} ${size}`">
      <!-- Background ring -->
      <circle :cx="cx" :cy="cy" :r="radius" fill="none" stroke="currentColor" stroke-opacity="0.08" :stroke-width="thickness" />
      <!-- Segments -->
      <g :transform="`rotate(-90 ${cx} ${cy})`">
        <circle v-for="(s, i) in computedSegments" :key="i"
          :cx="cx" :cy="cy" :r="radius" fill="none"
          :stroke="s.color" :stroke-width="thickness"
          :stroke-dasharray="`${s.length} ${circumference}`"
          :stroke-dashoffset="-s.offset"
          stroke-linecap="butt" />
      </g>
    </svg>
    <div class="donut-center">
      <slot />
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  segments: { type: Array, default: () => [] }, // {value, color, label}
  size: { type: Number, default: 160 },
  thickness: { type: Number, default: 14 }
})

const cx = computed(() => props.size / 2)
const cy = computed(() => props.size / 2)
const radius = computed(() => props.size / 2 - props.thickness / 2 - 2)
const circumference = computed(() => 2 * Math.PI * radius.value)

const total = computed(() => props.segments.reduce((s, x) => s + (Number(x.value) || 0), 0) || 1)

const computedSegments = computed(() => {
  let acc = 0
  return props.segments.map(s => {
    const frac = (Number(s.value) || 0) / total.value
    const length = frac * circumference.value
    const offset = acc
    acc += length
    return { ...s, length, offset }
  })
})
</script>

<style scoped>
.donut-ring { position: relative; }
.donut-center {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
}
</style>
