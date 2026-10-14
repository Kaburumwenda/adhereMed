<template>
  <div class="kpi-tile__value">{{ displayValue }}</div>
</template>

<script setup>
const props = defineProps({
  value: { type: Number, default: 0 },
  duration: { type: Number, default: 800 },
  prefix: { type: String, default: '' },
  suffix: { type: String, default: '' },
})

const displayValue = ref(props.prefix + '0' + props.suffix)

onMounted(() => {
  if (!import.meta.client) {
    displayValue.value = formatValue(props.value)
    return
  }
  animateTo(props.value)
})

watch(() => props.value, (newVal) => {
  if (import.meta.client) {
    animateTo(newVal)
  } else {
    displayValue.value = formatValue(newVal)
  }
})

function formatValue(v) {
  const n = Math.round(v)
  return props.prefix + n.toLocaleString() + props.suffix
}

function animateTo(target) {
  if (target <= 0) {
    displayValue.value = formatValue(0)
    return
  }
  const start = 0
  const startTime = performance.now()
  const dur = props.duration

  function tick(now) {
    const elapsed = now - startTime
    const t = Math.min(elapsed / dur, 1)
    // ease-out-cubic: 1 - (1-t)^3
    const eased = 1 - Math.pow(1 - t, 3)
    const current = start + (target - start) * eased
    displayValue.value = formatValue(current)
    if (t < 1) requestAnimationFrame(tick)
  }
  requestAnimationFrame(tick)
}
</script>