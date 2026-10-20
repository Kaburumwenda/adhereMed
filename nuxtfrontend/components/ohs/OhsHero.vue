<template>
  <div class="ohs-hero mb-3">
    <span class="ohs-glow" />
    <span class="ohs-glow ohs-glow-2" />

    <div class="ohs-hero-top d-flex flex-wrap align-center justify-space-between ga-3">
      <div class="d-flex align-center" style="gap:14px">
        <v-btn
          v-if="back"
          icon="mdi-arrow-left"
          variant="text"
          size="small"
          class="ohs-hero-back"
          :to="back"
        />
        <div class="ohs-hero-icon">
          <v-icon size="26">{{ icon }}</v-icon>
        </div>
        <div>
          <div class="ohs-eyebrow">
            <v-icon size="10">mdi-shield-check</v-icon>
            {{ eyebrow }}
          </div>
          <h1 class="ohs-title">{{ title }}</h1>
          <div v-if="subtitle" class="ohs-sub">{{ subtitle }}</div>
        </div>
      </div>

      <div class="d-flex flex-wrap align-center ga-2">
        <slot name="actions" />
      </div>
    </div>

    <div v-if="$slots.default" class="ohs-hero-foot">
      <slot />
    </div>
  </div>
</template>

<script setup>
defineProps({
  icon: { type: String, default: 'mdi-shield-check-outline' },
  eyebrow: { type: String, default: 'OHSMS' },
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  back: { type: [String, Object], default: '' },
})
</script>

<style scoped>
.ohs-hero-back {
  color: #fff !important;
  background: rgba(255, 255, 255, 0.14) !important;
  border: 1px solid rgba(255, 255, 255, 0.28) !important;
}
.ohs-hero-back:hover { background: rgba(255, 255, 255, 0.26) !important; }
.ohs-hero-back :deep(.v-icon) { color: #fff !important; opacity: 1 !important; }
</style>
