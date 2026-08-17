<template>
  <div class="d-flex flex-column mb-2">
    <div class="field-label">{{ label }}</div>
    <div class="field-value">
      <span v-if="value == null || value === ''" class="text-medium-emphasis">—</span>
      <span v-else :class="{ 'font-monospace': mono, 'text-capitalize': capitalize }">{{ displayValue }}</span>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: null },
  mono: { type: Boolean, default: false },
  capitalize: { type: Boolean, default: false },
  full: { type: Boolean, default: false },
})

const displayValue = computed(() => {
  if (props.value == null || props.value === '') return '—'
  return props.value
})
</script>

<style scoped>
.field-label {
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-bottom: 2px;
}
.field-value {
  font-size: 0.95rem;
  line-height: 1.4;
}
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
