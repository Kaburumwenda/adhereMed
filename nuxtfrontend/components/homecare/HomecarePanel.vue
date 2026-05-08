<template>
  <v-card class="hc-panel pa-5" rounded="xl" :elevation="0">
    <div class="d-flex align-center mb-4">
      <v-avatar v-if="icon" size="36" class="hc-panel-icon mr-3" :style="iconStyle">
        <v-icon :icon="icon" color="white" size="18" />
      </v-avatar>
      <div class="flex-grow-1">
        <h3 class="text-subtitle-1 font-weight-bold ma-0">{{ title }}</h3>
        <div v-if="subtitle" class="text-caption text-medium-emphasis">{{ subtitle }}</div>
      </div>
      <slot name="actions" />
    </div>
    <slot />
  </v-card>
</template>

<script setup>
const props = defineProps({
  title: String,
  subtitle: String,
  icon: String,
  color: { type: String, default: '#0d9488' }
})
const iconStyle = computed(() => ({
  background: `linear-gradient(135deg, ${props.color}, ${props.color}cc)`
}))
</script>

<style scoped>
.hc-panel {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  height: 100%;
}
.hc-panel-icon { border-radius: 10px; }
</style>
