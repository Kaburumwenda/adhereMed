<template>
  <div class="ohs-kpi" :style="{ color: toneColor }">
    <div class="ohs-kpi-top">
      <span class="ohs-kpi-label">{{ label }}</span>
      <span class="ohs-kpi-icon">
        <v-icon size="15">{{ icon }}</v-icon>
      </span>
    </div>
    <div class="ohs-kpi-value">{{ value }}</div>
    <div v-if="sub" class="ohs-kpi-sub">
      <span v-if="delta !== null && delta !== undefined" class="ohs-kpi-delta">
        {{ delta > 0 ? '▲' : delta < 0 ? '▼' : '■' }} {{ Math.abs(delta) }}{{ deltaSuffix }}
      </span>
      {{ sub }}
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: '—' },
  icon: { type: String, default: 'mdi-chart-box-outline' },
  tone: { type: String, default: 'primary' }, // primary | ok | info | warn | err | neutral
  sub: { type: String, default: '' },
  delta: { type: Number, default: null },
  deltaSuffix: { type: String, default: '' },
})

const PALETTE = {
  primary: 'var(--brand-primary, #2f6dff)',
  ok: '#16a34a',
  info: '#0284c7',
  warn: '#f59e0b',
  err: '#dc2626',
  neutral: '#64748b',
}

const toneColor = computed(() => PALETTE[props.tone] || PALETTE.primary)
</script>
