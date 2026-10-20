<template>
  <span class="ohs-badge" :class="`ohs-badge--${meta.tone}`">
    {{ meta.label }}
  </span>
</template>

<script setup>
const props = defineProps({
  // Accepts a level name ('high') or a numeric score (16).
  level: { type: [String, Number], default: 'unrated' },
})

const meta = computed(() => riskMeta(props.level))
</script>
