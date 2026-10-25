<template>
  <div class="vital-input-wrapper">
    <div class="vital-head">
      <span class="vital-label">{{ label }}</span>
      <!-- Acceptable range is always visible, not just on error, so the nurse
           knows the bounds before typing rather than being corrected after. -->
      <span v-if="hasRange" class="vital-range" :class="{ 'is-bad': outOfRange }">
        {{ rangeText }}
      </span>
      <v-chip
        v-else-if="status !== 'unknown'"
        :color="statusColor"
        size="x-small"
        variant="flat"
        class="ml-auto"
      >
        {{ statusIcon }}
      </v-chip>
      <span
        v-if="hasRange && status !== 'unknown'"
        class="vital-flag"
        :class="'is-' + status"
      >{{ statusIcon }}</span>
    </div>

    <div class="vital-body">
      <v-text-field
        :model-value="displayValue"
        :min="min ?? undefined"
        :max="max ?? undefined"
        :step="step || 1"
        type="number"
        variant="outlined"
        density="compact"
        hide-details
        class="vital-field"
        :class="[statusClass, { 'vital-invalid': outOfRange }]"
        @update:model-value="onInput"
        @blur="onBlur"
      />
      <span class="vital-unit">{{ unit }}</span>
    </div>

    <!-- Hard range breach while typing. The value is clamped on blur, so this
         is transient feedback rather than a permanent error state. -->
    <div v-if="outOfRange" class="vital-error">
      <v-icon size="11">mdi-alert-circle-outline</v-icon>
      {{ min }}–{{ max }} {{ unit }} only
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: [Number, String, null], default: null },
  label: { type: String, required: true },
  unit: { type: String, default: '' },
  /** Clinically normal band — drives the ✓ / ↓ / ↑ indicator. */
  normal: { type: Array, default: () => [0, 0] },
  /** Physiologically possible bounds — hard limit on what can be entered. */
  min: { type: [Number, null], default: null },
  max: { type: [Number, null], default: null },
  step: { type: [Number, String], default: null },
})
const emit = defineEmits(['update:modelValue'])

const hasRange = computed(() => props.min !== null || props.max !== null)

const rangeText = computed(() => {
  if (props.min !== null && props.max !== null) return `${props.min}–${props.max}`
  if (props.min !== null) return `≥ ${props.min}`
  return `≤ ${props.max}`
})

const displayValue = computed(() =>
  props.modelValue === null || props.modelValue === undefined || props.modelValue === ''
    ? ''
    : props.modelValue)

const val = computed(() => Number(props.modelValue) || 0)
const [lo, hi] = props.normal

/** True when a value is present but outside the hard physiological bounds. */
const outOfRange = computed(() => {
  const raw = props.modelValue
  if (raw === null || raw === undefined || raw === '') return false
  const n = Number(raw)
  if (!Number.isFinite(n)) return false
  if (props.min !== null && n < props.min) return true
  if (props.max !== null && n > props.max) return true
  return false
})

/** Accept the keystroke, but reject non-numeric; bounds are applied on blur. */
function onInput(raw) {
  if (raw === '' || raw === null || raw === undefined) {
    emit('update:modelValue', null)
    return
  }
  const n = Number(raw)
  emit('update:modelValue', Number.isFinite(n) ? n : null)
}

/**
 * Clamp on blur rather than on every keystroke — clamping while typing would
 * rewrite "1" into "50" before the nurse finished typing "120".
 */
function onBlur() {
  const raw = props.modelValue
  if (raw === null || raw === undefined || raw === '') return
  const n = Number(raw)
  if (!Number.isFinite(n)) { emit('update:modelValue', null); return }
  if (props.min !== null && n < props.min) { emit('update:modelValue', props.min); return }
  if (props.max !== null && n > props.max) { emit('update:modelValue', props.max) }
}

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

.vital-head {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-bottom: 4px;
  min-height: 16px;
}
.vital-label {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.vital-range {
  margin-left: auto;
  flex-shrink: 0;
  font-size: 9.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  padding: 1px 6px;
  border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), 0.42);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.vital-range.is-bad { color: #b91c1c; background: rgba(220, 38, 38, 0.12); }

.vital-flag { font-size: 11px; font-weight: 800; flex-shrink: 0; }
.vital-flag.is-normal { color: #16a34a; }
.vital-flag.is-low, .vital-flag.is-high { color: #dc2626; }

.vital-body { display: flex; align-items: center; }
.vital-unit {
  font-size: 12px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.45);
  margin-left: 7px;
  min-width: 42px;
  white-space: nowrap;
}

.vital-field :deep(input) {
  font-size: 1.15rem !important;
  font-weight: 700;
  text-align: center;
}
.vital-normal :deep(.v-field__outline) { color: rgb(var(--v-theme-success)); }
.vital-low :deep(.v-field__outline), .vital-high :deep(.v-field__outline) { color: rgb(var(--v-theme-error)); }
.vital-invalid :deep(.v-field__outline) { color: #dc2626 !important; }
.vital-invalid :deep(.v-field) { background: rgba(220, 38, 38, 0.05); }

.vital-error {
  display: flex;
  align-items: center;
  gap: 3px;
  margin-top: 3px;
  font-size: 10px;
  font-weight: 700;
  color: #b91c1c;
}
</style>
