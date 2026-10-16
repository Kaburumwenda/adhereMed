<template>
  <v-card rounded="lg" class="bi-narrative pa-4 h-100" :border="true">
    <div class="d-flex align-center mb-2">
      <v-avatar size="34" :color="color" variant="tonal" class="mr-2">
        <v-icon size="18">{{ icon }}</v-icon>
      </v-avatar>
      <div class="flex-grow-1">
        <div class="text-subtitle-2 font-weight-bold">{{ title }}</div>
        <div class="text-caption text-medium-emphasis">{{ subtitle }}</div>
      </div>
      <v-chip size="x-small" :color="color" variant="flat" class="font-weight-bold">
        <v-icon start size="12">mdi-creation</v-icon>{{ toneLabel }}
      </v-chip>
    </div>

    <div v-if="headline" class="bi-headline mb-2">{{ headline }}</div>

    <v-progress-linear v-if="loading" indeterminate color="primary" height="3" rounded class="mb-2" />

    <ul v-if="points && points.length" class="bi-points">
      <li v-for="(p, i) in points" :key="i">
        <v-icon size="14" :color="pointColor(p)" class="mr-1">{{ pointIcon(p) }}</v-icon>
        <span v-html="p" />
      </li>
    </ul>

    <div v-if="footer" class="text-caption text-medium-emphasis mt-2">{{ footer }}</div>
    <slot />
  </v-card>
</template>

<script setup>
const props = defineProps({
  title: { type: String, default: 'Automated insight' },
  subtitle: { type: String, default: 'Generated from live operational data' },
  icon: { type: String, default: 'mdi-lightbulb-on-outline' },
  color: { type: String, default: 'amber' },
  tone: { type: String, default: 'neutral' }, // positive | warning | negative | neutral
  headline: { type: String, default: '' },
  points: { type: Array, default: () => [] },
  footer: { type: String, default: '' },
  loading: { type: Boolean, default: false }
})

const toneLabel = computed(() => {
  const t = props.tone
  if (t === 'positive') return 'Positive'
  if (t === 'warning') return 'Watch'
  if (t === 'negative') return 'Alert'
  return 'Info'
})

// A point may be a plain string, or prefixed with a marker:
//   "+ …" good, "- …" bad, "! …" warning, otherwise neutral info.
function marker(p) {
  const s = String(p).trim()
  if (s.startsWith('+ ')) return 'good'
  if (s.startsWith('- ')) return 'bad'
  if (s.startsWith('! ')) return 'warn'
  return 'info'
}
function pointIcon(p) {
  const m = marker(p)
  if (m === 'good') return 'mdi-check-circle-outline'
  if (m === 'bad') return 'mdi-alert-circle-outline'
  if (m === 'warn') return 'mdi-alert-outline'
  return 'mdi-information-outline'
}
function pointColor(p) {
  const m = marker(p)
  if (m === 'good') return 'success'
  if (m === 'bad') return 'error'
  if (m === 'warn') return 'warning'
  return 'info'
}
</script>

<style scoped>
.bi-narrative {
  background-image: linear-gradient(135deg, rgba(var(--v-theme-primary), 0.05), transparent 55%);
}
.bi-headline {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.45;
}
.bi-points {
  margin: 0;
  padding-left: 0;
  list-style: none;
}
.bi-points li {
  display: flex;
  align-items: flex-start;
  font-size: 12.5px;
  line-height: 1.5;
  margin-bottom: 6px;
  color: rgba(var(--v-theme-on-surface), 0.82);
}
</style>
