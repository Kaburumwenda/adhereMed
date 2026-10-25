<template>
  <div class="rc">
    <div class="rc-head">
      <div class="rc-title">
        <v-icon size="14">{{ icon }}</v-icon>
        {{ title }}
        <span class="rc-hint">{{ hint }}</span>
      </div>
      <v-btn v-if="hasSelection" variant="text" size="x-small" class="text-none rc-clear"
             prepend-icon="mdi-eraser-variant" @click="emit('update:modelValue', '')">
        Clear
      </v-btn>
    </div>

    <div v-for="group in groups" :key="group.key" class="rc-group">
      <div class="rc-group-label">{{ group.label }}</div>
      <div class="rc-row">
        <button v-for="reason in group.items" :key="reason" type="button"
                class="rc-chip" :class="{ 'rc-chip--on': isSelected(reason) }"
                :title="isSelected(reason) ? `Remove “${reason}”` : `Add “${reason}”`"
                @click="toggle(reason)">
          <v-icon v-if="isSelected(reason)" size="13" class="rc-chip-icon">mdi-check</v-icon>
          {{ reason }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
/**
 * Quick-select chips for the "Reason for visit" free-text field.
 *
 * The field stays a plain comma-separated string (that is what the visits API
 * expects as `chief_complaint`), so a chip simply appends its label or removes
 * it again. Selection is derived from the text, which means anything the user
 * types by hand is reflected too.
 */
const props = defineProps({
  modelValue: { type: String, default: '' },
  /** Override the quick-pick groups (defaults to symptom presets). */
  groups: { type: Array, default: null },
  title: { type: String, default: 'Common reasons' },
  hint: { type: String, default: 'tap to add · tap again to remove' },
  icon: { type: String, default: 'mdi-lightning-bolt-outline' },
})
const emit = defineEmits(['update:modelValue'])

// Ordered by how often they walk through a clinic front door.
const fallbackGroups = [
  {
    key: 'symptoms',
    label: 'Symptoms',
    items: [
      'Fever', 'Cough', 'Headache', 'Sore throat', 'Stomach pain',
      'Diarrhoea', 'Vomiting', 'Body aches', 'Dizziness', 'Skin rash',
    ],
  },
  {
    key: 'urgent',
    label: 'Urgent',
    items: ['Chest pain', 'Shortness of breath', 'Injury / wound', 'Severe pain'],
  },
  {
    key: 'followup',
    label: 'Follow-up & routine',
    items: [
      'Follow-up review', 'Refill prescription', 'Blood pressure check',
      'Diabetes review', 'Antenatal visit', 'Child immunisation',
    ],
  },
]

const groups = computed(() => props.groups || fallbackGroups)

/** Split the current text into trimmed, non-empty parts. */
const parts = computed(() =>
  String(props.modelValue || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
)

const lowerParts = computed(() => parts.value.map(p => p.toLowerCase()))

const hasSelection = computed(() => parts.value.length > 0)

function isSelected(reason) {
  return lowerParts.value.includes(reason.toLowerCase())
}

function toggle(reason) {
  const current = [...parts.value]
  const idx = current.findIndex(p => p.toLowerCase() === reason.toLowerCase())
  if (idx === -1) current.push(reason)
  else current.splice(idx, 1)
  emit('update:modelValue', current.join(', '))
}
</script>

<style scoped>
.rc {
  padding: 11px 13px 12px;
  border-radius: 12px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
  background: rgba(var(--v-theme-on-surface), 0.02);
}

.rc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 9px;
}
.rc-title {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.52);
}
.rc-hint {
  font-size: 9.5px;
  font-weight: 600;
  letter-spacing: 0.2px;
  text-transform: none;
  color: rgba(var(--v-theme-on-surface), 0.35);
}
.rc-clear { opacity: 0.8; }

.rc-group + .rc-group { margin-top: 9px; }
.rc-group-label {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.34);
  margin-bottom: 5px;
}

.rc-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.rc-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.72);
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.13);
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.14s ease;
}
.rc-chip:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 45%, transparent);
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
  transform: translateY(-1px);
}
.rc-chip--on {
  color: #fff;
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
  box-shadow: 0 3px 10px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 35%, transparent);
}
.rc-chip--on:hover {
  color: #fff;
  transform: translateY(-1px);
}
.rc-chip-icon { margin-left: -2px; }
</style>
