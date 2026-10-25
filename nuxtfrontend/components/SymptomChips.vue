<template>
  <div class="sc">
    <div class="sc-head">
      <div class="sc-title">
        <v-icon size="13">mdi-lightning-bolt-outline</v-icon>
        Quick select
        <span class="sc-hint">tap to add · tap again to remove</span>
      </div>
      <div class="d-flex align-center ga-1">
        <v-chip v-if="selectedCount" size="x-small" variant="tonal" color="primary" class="font-weight-bold">
          {{ selectedCount }} selected
        </v-chip>
        <v-btn v-if="selectedCount" variant="text" size="x-small" class="text-none sc-clear"
               prepend-icon="mdi-eraser-variant" @click="emit('update:modelValue', '')">
          Clear
        </v-btn>
      </div>
    </div>

    <div class="sc-scroll">
      <div v-for="group in groups" :key="group.key" class="sc-group">
        <div class="sc-group-label">
          <v-icon size="11">{{ group.icon }}</v-icon>
          {{ group.label }}
        </div>
        <div class="sc-row">
          <button v-for="symptom in group.items" :key="symptom" type="button"
                  class="sc-chip" :class="{ 'sc-chip--on': isSelected(symptom) }"
                  :title="isSelected(symptom) ? `Remove “${symptom}”` : `Add “${symptom}”`"
                  @click="toggle(symptom)">
            <v-icon v-if="isSelected(symptom)" size="12" class="sc-chip-icon">mdi-check</v-icon>
            {{ symptom }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
/**
 * Quick-select chips for an allergy's `common_symptoms` field.
 *
 * The backend stores this as a plain comma-separated string, so a chip simply
 * appends its label or removes it again. Selection is derived from the text,
 * which means anything typed by hand is reflected in the chip state too.
 */
const props = defineProps({
  modelValue: { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue'])

// Grouped the way a clinician reasons about an allergic reaction: where it
// shows, then how severe it is.
const groups = [
  {
    key: 'skin',
    label: 'Skin',
    icon: 'mdi-hand-back-right-outline',
    items: [
      'Hives', 'Itching', 'Rash', 'Redness', 'Eczema',
      'Blisters', 'Swelling', 'Scaling / peeling',
    ],
  },
  {
    key: 'face',
    label: 'Face, nose & eyes',
    icon: 'mdi-face-man-outline',
    items: [
      'Facial swelling', 'Lip swelling', 'Tongue swelling',
      'Itchy eyes', 'Watery eyes', 'Runny nose', 'Sneezing', 'Nasal congestion',
    ],
  },
  {
    key: 'airway',
    label: 'Airway & breathing',
    icon: 'mdi-lungs',
    items: [
      'Throat tightness', 'Hoarseness', 'Difficulty swallowing',
      'Wheezing', 'Cough', 'Shortness of breath', 'Chest tightness',
    ],
  },
  {
    key: 'digestive',
    label: 'Digestive',
    icon: 'mdi-stomach',
    items: [
      'Nausea', 'Vomiting', 'Diarrhoea', 'Stomach cramps',
      'Abdominal pain', 'Mouth / throat itching',
    ],
  },
  {
    key: 'systemic',
    label: 'Whole body (severe)',
    icon: 'mdi-alert-circle-outline',
    items: [
      'Anaphylaxis', 'Dizziness', 'Fainting', 'Low blood pressure',
      'Rapid pulse', 'Fatigue', 'Headache',
    ],
  },
]

const parts = computed(() =>
  String(props.modelValue || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
)

const lowerParts = computed(() => parts.value.map(p => p.toLowerCase()))
const selectedCount = computed(() => parts.value.length)

function isSelected(symptom) {
  return lowerParts.value.includes(symptom.toLowerCase())
}

function toggle(symptom) {
  const current = [...parts.value]
  const idx = current.findIndex(p => p.toLowerCase() === symptom.toLowerCase())
  if (idx === -1) current.push(symptom)
  else current.splice(idx, 1)
  emit('update:modelValue', current.join(', '))
}
</script>

<style scoped>
.sc {
  padding: 10px 12px 11px;
  border-radius: 12px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
  background: rgba(var(--v-theme-on-surface), 0.02);
}

.sc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 8px;
}
.sc-title {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.52);
}
.sc-hint {
  font-size: 9.5px;
  font-weight: 600;
  letter-spacing: 0.2px;
  text-transform: none;
  color: rgba(var(--v-theme-on-surface), 0.35);
}
.sc-clear { opacity: 0.85; }

/* Bounded height keeps the dialog compact — the chip list scrolls instead of
   pushing the form and footer off screen. */
.sc-scroll {
  max-height: 148px;
  overflow-y: auto;
  padding-right: 4px;
  scrollbar-width: thin;
}
.sc-scroll::-webkit-scrollbar { width: 6px; }
.sc-scroll::-webkit-scrollbar-thumb {
  background: rgba(var(--v-theme-on-surface), 0.18);
  border-radius: 3px;
}

.sc-group + .sc-group { margin-top: 8px; }
.sc-group-label {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.36);
  margin-bottom: 5px;
}

.sc-row {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}

.sc-chip {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.72);
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.13);
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.14s ease;
}
.sc-chip:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 45%, transparent);
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
  transform: translateY(-1px);
}
.sc-chip--on {
  color: #fff;
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
  box-shadow: 0 3px 10px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 32%, transparent);
}
.sc-chip--on:hover { color: #fff; transform: translateY(-1px); }
.sc-chip-icon { margin-left: -1px; }
</style>
