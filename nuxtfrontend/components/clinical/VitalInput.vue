<template>
  <div class="vital-input-wrapper">
    <div class="d-flex align-center ga-1 mb-1">
      <span class="text-caption text-medium-emphasis font-weight-bold">{{ label }}</span>
      <v-chip v-if="status !== 'unknown'" :color="statusColor" size="x-small" variant="flat" class="ml-auto">{{ statusIcon }}</v-chip>
    </div>
    <div class="d-flex align-center">
      <v-text-field
        :model-value="modelValue"
        @update:model-value="$emit('update:modelValue', $event === '' ? null : Number($event))"
        type="number"
        :step="step || 1"
        variant="outlined"
        density="compact"
        hide-details
        class="vital-field"
        :class="statusClass"
      />
      <span class="text-body-2 text-medium-emphasis ml-2" style="min-width: 40px">{{ unit }}</span>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: [Number, String, null], default: null },
  label: { type: String, required: true },
  unit: { type: String, default: '' },
  normal: { type: Array, default: () => [0, 0] },
  step: { type: [Number, String], default: null },
})
defineEmits(['update:modelValue'])

const val = computed(() => Number(props.modelValue) || 0)
const [lo, hi] = props.normal

const status = computed(() => {
  if (!val.value) return 'unknown'
  if (lo === 0 && hi === 0) return 'unknown'
  if (val.value < lo) return 'low'
  if (val.value > hi) return 'high'
  return 'normal'
})

const statusColor = computed(() => ({
  normal: 'success', low: 'error', high: 'error', unknown: 'grey',
}[status.value]))

const statusIcon = computed(() => ({
  normal: '✓', low: '↓', high: '↑', unknown: '',
}[status.value]))

const statusClass = computed(() => ({
  normal: 'vital-normal', low: 'vital-low', high: 'vital-high', unknown: '',
}[status.value]))
</script>

<style scoped>
.vital-input-wrapper { min-width: 140px; }
.vital-field :deep(input) { font-size: 1.15rem !important; font-weight: bold; text-align: center; }
.vital-normal :deep(.v-field__outline) { color: rgb(var(--v-theme-success)); }
.vital-low :deep(.v-field__outline), .vital-high :deep(.v-field__outline) { color: rgb(var(--v-theme-error)); }
</style>
