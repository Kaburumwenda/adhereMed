<template>
  <v-card :to="to" class="hc-quick pa-4" rounded="xl" :elevation="0">
    <div class="hc-quick-icon" :style="iconStyle">
      <v-icon :icon="icon" color="white" />
    </div>
    <div class="text-subtitle-2 font-weight-bold mt-3">{{ label }}</div>
    <div v-if="hint" class="text-caption text-medium-emphasis">{{ hint }}</div>
  </v-card>
</template>

<script setup>
const props = defineProps({
  label: String,
  hint: String,
  icon: String,
  color: { type: String, default: '#0d9488' },
  to: String
})
const iconStyle = computed(() => ({
  background: `linear-gradient(135deg, ${props.color}, ${props.color}aa)`,
  boxShadow: `0 8px 22px -10px ${props.color}`
}))
</script>

<style scoped>
.hc-quick {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
  cursor: pointer;
}
.hc-quick:hover {
  transform: translateY(-3px);
  border-color: rgba(13,148,136,0.35);
  box-shadow: 0 16px 32px -18px rgba(13,148,136,0.45) !important;
}
.hc-quick-icon {
  width: 40px; height: 40px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
}
</style>
