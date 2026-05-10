<template>
  <v-card rounded="xl" :elevation="0" class="hc-metric pa-4">
    <div class="d-flex align-center">
      <div class="hc-metric-icon" :style="iconStyle">
        <v-icon :icon="icon" color="white" size="20" />
      </div>
      <div class="ml-3 flex-grow-1 min-w-0">
        <div class="text-caption text-medium-emphasis text-uppercase font-weight-medium">
          {{ label }}
        </div>
        <div class="text-h5 font-weight-bold">{{ value }}</div>
      </div>
    </div>
  </v-card>
</template>

<script setup>
const props = defineProps({
  label: String,
  value: { type: [String, Number], default: 0 },
  icon: { type: String, default: 'mdi-chart-box' },
  color: { type: String, default: '#0d9488' }
})
const iconStyle = computed(() => ({
  background: `linear-gradient(135deg, ${props.color}, ${props.color}cc)`,
  boxShadow: `0 6px 18px -8px ${props.color}`
}))
</script>

<style scoped>
.hc-metric {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-metric {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}
.hc-metric-icon {
  width: 40px; height: 40px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.min-w-0 { min-width: 0; }
</style>
