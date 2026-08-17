<template>
  <v-card rounded="lg" variant="outlined" class="mb-3 section-card">
    <div class="section-header" @click="toggle">
      <div class="d-flex align-center ga-2">
        <v-avatar :color="color + '-lighten-5'" size="36" rounded="lg">
          <v-icon :color="color + '-darken-2'" size="20">{{ icon }}</v-icon>
        </v-avatar>
        <span class="text-subtitle-2 font-weight-bold">{{ title }}</span>
        <v-chip v-if="badge" :color="badgeColor || color" size="x-small" variant="tonal">{{ badge }}</v-chip>
      </div>
      <v-btn :icon="expanded ? 'mdi-chevron-up' : 'mdi-chevron-down'" size="small" variant="text" />
    </div>
    <v-divider v-if="expanded" />
    <div v-if="expanded" class="pa-4">
      <slot />
    </div>
  </v-card>
</template>

<script setup>
const props = defineProps({
  icon: { type: String, default: 'mdi-circle-outline' },
  title: { type: String, required: true },
  color: { type: String, default: 'primary' },
  expanded: { type: Boolean, default: true },
  badge: { type: String, default: '' },
  badgeColor: { type: String, default: '' },
})

const expanded = ref(props.expanded)
function toggle() { expanded.value = !expanded.value }
</script>

<style scoped>
.section-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; cursor: pointer; user-select: none; }
.section-header:hover { background: rgba(var(--v-theme-on-surface), 0.04); }
.section-card { transition: box-shadow 0.2s; }
.section-card:has(.section-header:hover) { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
</style>
