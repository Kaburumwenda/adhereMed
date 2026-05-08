<template>
  <v-card class="hc-kpi pa-4" rounded="xl" :elevation="0" :to="to">
    <div class="d-flex align-start">
      <div class="hc-kpi-icon" :style="iconStyle">
        <v-icon :icon="icon" color="white" size="22" />
      </div>
      <div class="flex-grow-1 ml-3">
        <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">
          {{ label }}
        </div>
        <div class="d-flex align-baseline ga-2 mt-1">
          <span class="text-h4 font-weight-bold">{{ value }}</span>
          <span v-if="suffix" class="text-body-2 text-medium-emphasis">{{ suffix }}</span>
        </div>
        <div v-if="trend != null" class="d-flex align-center mt-1">
          <v-icon :color="trend >= 0 ? 'success' : 'error'"
                  :icon="trend >= 0 ? 'mdi-arrow-top-right-thick' : 'mdi-arrow-bottom-right-thick'"
                  size="14" />
          <span :class="trend >= 0 ? 'text-success' : 'text-error'" class="text-caption ml-1 font-weight-bold">
            {{ trend > 0 ? '+' : '' }}{{ trend }}{{ trendSuffix }}
          </span>
          <span v-if="trendLabel" class="text-caption text-medium-emphasis ml-1">{{ trendLabel }}</span>
        </div>
        <div v-else-if="hint" class="text-caption text-medium-emphasis mt-1">{{ hint }}</div>
      </div>
    </div>
    <div v-if="spark?.length" class="mt-3">
      <SparkArea :values="spark" :height="36" :color="color" />
    </div>
  </v-card>
</template>

<script setup>
const props = defineProps({
  label: String,
  value: { type: [String, Number], default: 0 },
  suffix: String,
  icon: String,
  color: { type: String, default: '#0d9488' },
  trend: { type: Number, default: null },
  trendSuffix: { type: String, default: '%' },
  trendLabel: String,
  hint: String,
  spark: Array,
  to: String
})
const iconStyle = computed(() => ({
  background: `linear-gradient(135deg, ${props.color}, ${shade(props.color, -15)})`,
  boxShadow: `0 6px 18px -8px ${props.color}`
}))
function shade(hex, percent) {
  // light shade adjustment
  const c = hex.replace('#', '')
  const num = parseInt(c, 16)
  const amt = Math.round(2.55 * percent)
  const r = Math.min(255, Math.max(0, (num >> 16) + amt))
  const g = Math.min(255, Math.max(0, ((num >> 8) & 0xff) + amt))
  const b = Math.min(255, Math.max(0, (num & 0xff) + amt))
  return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)
}
</script>

<style scoped>
.hc-kpi {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.hc-kpi:hover {
  transform: translateY(-2px);
  box-shadow: 0 14px 30px -16px rgba(15,23,42,0.18) !important;
}
.hc-kpi-icon {
  width: 44px; height: 44px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
}
</style>
