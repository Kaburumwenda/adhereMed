<template>
  <div class="d-flex align-center mb-4 ga-3">
    <div class="hc-section-icon" :style="iconStyle">
      <v-icon :icon="icon" color="white" size="20" />
    </div>
    <div class="flex-grow-1 min-w-0">
      <h3 class="text-h6 font-weight-bold ma-0">{{ title }}</h3>
      <div v-if="subtitle" class="text-caption text-medium-emphasis">{{ subtitle }}</div>
    </div>
    <slot name="actions" />
  </div>
</template>

<script setup>
const props = defineProps({
  title: { type: String, required: true },
  subtitle: String,
  icon: { type: String, default: 'mdi-information' },
  color: { type: String, default: '#0d9488' }
})
const iconStyle = computed(() => ({
  background: `linear-gradient(135deg, ${props.color}, ${props.color}cc)`
}))
</script>

<style scoped>
.hc-section-icon {
  width: 40px; height: 40px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.min-w-0 { min-width: 0; }
</style>
