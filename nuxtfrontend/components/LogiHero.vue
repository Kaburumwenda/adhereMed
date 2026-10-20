<template>
  <div class="lg-hero mb-4" :style="heroTheme">
    <span class="lg-hero-glow" />
    <span class="lg-hero-glow lg-hero-glow-2" />

    <div class="d-flex flex-wrap align-center justify-space-between ga-3">
      <div class="d-flex align-center" style="gap:16px">
        <div class="lg-hero-icon">
          <v-icon size="30">{{ icon }}</v-icon>
        </div>
        <div>
          <div class="lg-eyebrow">
            <v-icon size="11">mdi-circle</v-icon>
            {{ eyebrow }}
          </div>
          <h1 class="lg-title">{{ title }}</h1>
          <div class="lg-sub">
            {{ subtitle }}
            <span v-if="branchName"> · {{ branchName }}</span>
          </div>
        </div>
      </div>

      <div class="d-flex flex-wrap align-center ga-2">
        <slot name="actions" />
      </div>
    </div>

    <div v-if="facts && facts.length" class="lg-hero-facts">
      <template v-for="(f, i) in facts" :key="f.label">
        <span v-if="i" class="lg-hero-divider" />
        <div class="lg-hero-fact">
          <div class="lg-hero-fact-value">{{ f.value }}</div>
          <div class="lg-hero-fact-label">{{ f.label }}</div>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
defineProps({
  icon: { type: String, default: 'mdi-truck-fast-outline' },
  eyebrow: { type: String, default: 'IMS · LOGISTICS' },
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  facts: { type: Array, default: () => [] },
  branchName: { type: String, default: '' },
})

const brand = useBranding()

// Mirrors the branded hero bridge used by the inventory pages.
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))
</script>

<style scoped>
.lg-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.lg-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.lg-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.lg-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.lg-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.lg-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.lg-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.lg-hero-facts {
  position: relative;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 18px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.lg-hero-fact-value {
  font-size: 18px;
  font-weight: 800;
  line-height: 1.1;
}
.lg-hero-fact-label {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.78);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.lg-hero-divider {
  width: 1px;
  height: 26px;
  background: rgba(255, 255, 255, 0.24);
}
</style>
