<template>
  <v-dialog
    :model-value="modelValue"
    :max-width="width"
    persistent
    @update:model-value="close"
  >
    <v-card rounded="xl" class="idlg" :style="themeVars">
      <BrandDialogHeader
        :icon="toneMeta.icon"
        :title="title"
        :subtitle="subtitle"
        @close="close(false)"
      >
        <template #actions>
          <span class="idlg-chip">{{ toneMeta.label }}</span>
        </template>
      </BrandDialogHeader>

      <div class="idlg-body">
        <div class="idlg-lead">
          <div class="idlg-badge" :class="`is-${tone}`">
            <v-icon size="21">{{ toneMeta.icon }}</v-icon>
          </div>
          <p class="idlg-message">
            <slot>{{ message }}</slot>
          </p>
        </div>

        <ul v-if="points.length" class="idlg-points">
          <li v-for="(point, index) in points" :key="index">
            <v-icon size="13">{{ toneMeta.bullet }}</v-icon>
            <span>{{ point }}</span>
          </li>
        </ul>

        <div v-if="hint" class="idlg-hint">
          <v-icon size="14">{{ toneMeta.hint }}</v-icon>
          <span>{{ hint }}</span>
        </div>
      </div>

      <footer class="idlg-actions">
        <button
          v-if="secondaryLabel"
          type="button"
          class="idlg-btn"
          @click="close(true)"
        >
          {{ secondaryLabel }}
        </button>
        <v-spacer />
        <button type="button" class="idlg-btn is-primary" @click="confirm">
          <v-icon size="15">{{ toneMeta.confirmIcon }}</v-icon>
          <span>{{ confirmLabel }}</span>
        </button>
      </footer>
    </v-card>
  </v-dialog>
</template>

<script setup>
/**
 * Premium information dialog for blocked/explained actions.
 *
 * Used where an action is refused for a clinical or process reason — e.g.
 * completing an order before anyone has signed as performer, or downloading a
 * report that is not yet verified. Deliberately non-destructive: only one
 * primary acknowledgement button (plus an optional secondary "go there" link).
 */
const props = defineProps({
  modelValue: { type: Boolean, default: false },
  /** 'info' | 'warning' | 'danger' | 'success' */
  tone: { type: String, default: 'info' },
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  message: { type: String, default: '' },
  /** Extra explanatory lines rendered as a bulleted list. */
  points: { type: Array, default: () => [] },
  /** Small footer note with a lock/info icon. */
  hint: { type: String, default: '' },
  confirmLabel: { type: String, default: 'Got it' },
  secondaryLabel: { type: String, default: '' },
  width: { type: [Number, String], default: 520 },
})

const emit = defineEmits(['update:modelValue', 'secondary', 'confirm'])

const brand = useBranding()

const themeVars = computed(() => ({
  '--id-accent': brand.primary.value,
  '--id-on-accent': brand.onPrimary.value,
  '--id-accent-ink': brand.ink.value,
  '--id-accent-ring': brand.tint('primary', 0.24),
}))

const TONES = {
  info: {
    icon: 'mdi-information-outline',
    label: 'Heads up',
    bullet: 'mdi-circle-small',
    hint: 'mdi-lightbulb-on-outline',
    confirmIcon: 'mdi-check',
  },
  warning: {
    icon: 'mdi-alert-outline',
    label: 'Action needed',
    bullet: 'mdi-circle-small',
    hint: 'mdi-arrow-right-thin',
    confirmIcon: 'mdi-check',
  },
  danger: {
    icon: 'mdi-alert-octagon-outline',
    label: 'Blocked',
    bullet: 'mdi-circle-small',
    hint: 'mdi-shield-alert-outline',
    confirmIcon: 'mdi-check',
  },
  success: {
    icon: 'mdi-check-decagram-outline',
    label: 'All good',
    bullet: 'mdi-circle-small',
    hint: 'mdi-check-circle-outline',
    confirmIcon: 'mdi-check',
  },
}

const toneMeta = computed(() => TONES[props.tone] || TONES.info)

function close(secondary = false) {
  emit('update:modelValue', false)
  if (secondary) emit('secondary')
}

/** Primary button: close, then tell the caller the action was accepted. */
function confirm() {
  emit('update:modelValue', false)
  emit('confirm')
}
</script>

<style scoped>
.idlg {
  --id-line: rgba(var(--v-theme-on-surface), 0.1);
  --id-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --id-muted: rgba(var(--v-theme-on-surface), 0.6);
  --id-faint: rgba(var(--v-theme-on-surface), 0.44);
  --id-raise: rgba(var(--v-theme-on-surface), 0.035);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.idlg-chip {
  display: inline-flex;
  align-items: center;
  height: 21px;
  padding: 0 9px;
  border-radius: 999px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: #fff;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.idlg-body {
  padding: 18px 20px 16px;
  display: flex;
  flex-direction: column;
  gap: 13px;
}

.idlg-lead {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.idlg-badge {
  width: 42px;
  height: 42px;
  border-radius: 13px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
}
.idlg-badge.is-info {
  color: #1d4ed8;
  background: rgba(37, 99, 235, 0.11);
  border: 1px solid rgba(37, 99, 235, 0.24);
}
.idlg-badge.is-warning {
  color: #b45309;
  background: rgba(245, 158, 11, 0.13);
  border: 1px solid rgba(245, 158, 11, 0.3);
}
.idlg-badge.is-danger {
  color: #b91c1c;
  background: rgba(239, 68, 68, 0.11);
  border: 1px solid rgba(239, 68, 68, 0.26);
}
.idlg-badge.is-success {
  color: #047857;
  background: rgba(16, 185, 129, 0.12);
  border: 1px solid rgba(16, 185, 129, 0.28);
}

.idlg-message {
  margin: 0;
  font-size: 12.5px;
  font-weight: 600;
  line-height: 1.6;
  color: rgb(var(--v-theme-on-surface));
}

.idlg-points {
  list-style: none;
  margin: 0;
  padding: 11px 13px;
  border-radius: 11px;
  border: 1px solid var(--id-line-soft);
  background: var(--id-raise);
  display: grid;
  gap: 7px;
}
.idlg-points li {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.5;
  color: var(--id-muted);
}
.idlg-points li :deep(.v-icon) {
  margin-top: 1px;
  color: var(--id-accent);
  opacity: 0.85;
}

.idlg-hint {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 9px 11px;
  border-radius: 10px;
  border: 1px dashed var(--id-line);
  font-size: 10.5px;
  font-weight: 700;
  line-height: 1.5;
  color: var(--id-faint);
}
.idlg-hint :deep(.v-icon) {
  margin-top: 1px;
  color: var(--id-accent);
}

.idlg-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 11px 20px;
  border-top: 1px solid var(--id-line-soft);
  background: var(--id-raise);
}

.idlg-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 35px;
  padding: 0 15px;
  border-radius: 9px;
  border: 1px solid var(--id-line);
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease;
}
.idlg-btn:hover { background: var(--id-raise); transform: translateY(-1px); }
.idlg-btn.is-primary {
  background: var(--id-accent);
  color: var(--id-on-accent);
  border-color: transparent;
  box-shadow: 0 7px 18px var(--id-accent-ring);
}
.idlg-btn.is-primary:hover {
  background: var(--id-accent);
  color: var(--id-on-accent);
  filter: brightness(1.06);
}
.idlg-btn.is-primary:active { filter: brightness(0.96); transform: none; }

:global(.v-theme--dark .idlg-badge.is-info) {
  color: #93c5fd;
  background: rgba(37, 99, 235, 0.16);
  border-color: rgba(147, 197, 253, 0.32);
}
:global(.v-theme--dark .idlg-badge.is-warning) {
  color: #fbbf24;
  background: rgba(245, 158, 11, 0.14);
  border-color: rgba(251, 191, 36, 0.34);
}
:global(.v-theme--dark .idlg-badge.is-danger) {
  color: #f87171;
  background: rgba(239, 68, 68, 0.14);
  border-color: rgba(248, 113, 113, 0.34);
}
:global(.v-theme--dark .idlg-badge.is-success) {
  color: #34d399;
  background: rgba(16, 185, 129, 0.14);
  border-color: rgba(52, 211, 153, 0.34);
}
</style>
