<template>
  <div class="bdh" :style="heroTheme">
    <span class="bdh-glow" />
    <span class="bdh-glow bdh-glow-2" />

    <div class="bdh-row">
      <div class="bdh-lead">
        <div v-if="icon" class="bdh-icon">
          <v-icon size="22">{{ icon }}</v-icon>
        </div>
        <div class="bdh-text">
          <div class="bdh-title">{{ title }}</div>
          <div v-if="subtitle" class="bdh-sub">{{ subtitle }}</div>
          <slot name="meta" />
        </div>
      </div>

      <div class="bdh-trail">
        <slot name="actions" />
        <v-btn
          v-if="closable"
          icon="mdi-close"
          variant="text"
          size="small"
          type="button"
          class="bdh-close"
          :title="closeLabel"
          :aria-label="closeLabel"
          @click="close"
        />
      </div>
    </div>

    <slot />
  </div>
</template>

<script setup>
const emit = defineEmits(['close'])

defineProps({
  icon: { type: String, default: '' },
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  closable: { type: Boolean, default: true },
  closeLabel: { type: String, default: 'Close' },
})

const brand = useBranding()
const instance = getCurrentInstance()

// Same branded gradient bridge used by the page heroes.
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

/**
 * Find the overlay owner (`v-dialog` / `v-bottom-sheet`) wrapping this header.
 *
 * Vuetify renders slot content behind a few wrapper components
 * (`VDefaultsProvider` → `BaseTransition` → `VDialogTransition` → `VOverlay`),
 * so the dialog is not the direct parent — walk the instance tree until we
 * reach it.
 */
function findOverlayOwner() {
  let node = instance
  let guard = 0
  while (node && guard < 24) {
    const name = node.type?.name || node.type?.__name
    if (name === 'VDialog' || name === 'VBottomSheet') return node
    node = node.parent
    guard += 1
  }
  return null
}

/**
 * Close the dialog this header belongs to.
 *
 * The ``close`` event is emitted first so a page that binds ``@close`` keeps
 * full control. But most dialogs don't — historically that made the ✕ a
 * no-op — so we then drive the overlay's own `v-model` closed. Emitting on
 * the dialog instance also bypasses `persistent`, giving the ✕ the
 * unconditional escape hatch a visible close button implies.
 */
function close() {
  emit('close')

  const owner = findOverlayOwner()
  if (owner) {
    owner.emit('update:modelValue', false)
    return
  }

  // Last resort for a header not rendered inside a Vuetify overlay: fall back
  // to the Escape key path Vuetify itself listens for.
  if (import.meta.client) {
    nextTick(() => {
      window.dispatchEvent(
        new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }),
      )
    })
  }
}
</script>

<style scoped>
.bdh {
  position: relative;
  overflow: hidden;
  padding: 15px 18px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
}
.bdh-glow {
  position: absolute;
  width: 240px;
  height: 240px;
  border-radius: 50%;
  right: -90px;
  top: -130px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.bdh-glow-2 {
  right: auto;
  left: -110px;
  top: auto;
  bottom: -160px;
  width: 200px;
  height: 200px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.bdh-row {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.bdh-lead {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}
.bdh-icon {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(6px);
}
.bdh-text {
  min-width: 0;
}
.bdh-title {
  font-size: 16px;
  font-weight: 800;
  line-height: 1.25;
  letter-spacing: -0.1px;
}
.bdh-sub {
  font-size: 11.5px;
  color: rgba(255, 255, 255, 0.82);
  margin-top: 1px;
}
.bdh-trail {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}
.bdh-close {
  color: #fff !important;
}
</style>

<style>
/* Chip helpers for use inside the branded dialog header (slots). */
.bdh-chip-solid {
  background: #fff !important;
  color: var(--hero-ink, #143ce1) !important;
}
.bdh-chip-outline {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #fff !important;
  border: 1px solid rgba(255, 255, 255, 0.45) !important;
}
.bdh-iconbtn {
  color: #fff !important;
}
</style>
