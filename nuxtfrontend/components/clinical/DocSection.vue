<template>
  <v-card :id="id ? `section-${id}` : undefined" rounded="lg" variant="outlined" class="mb-3 doc-section" :class="{ 'doc-section--filled': filled }">
    <div class="section-header" @click="toggle">
      <div class="d-flex align-center ga-2">
        <v-avatar :color="color + '-lighten-5'" size="32" rounded="lg">
          <v-icon :color="color + '-darken-2'" size="18">{{ icon }}</v-icon>
        </v-avatar>
        <span class="text-subtitle-2 font-weight-bold">{{ title }}</span>
        <v-chip v-if="badge" size="x-small" variant="tonal" :color="color" class="ml-1">{{ badge }}</v-chip>
        <v-icon v-if="readonly" size="12" color="grey" class="ml-1">mdi-lock</v-icon>
        <v-icon v-if="filled && !readonly" size="14" color="success" class="ml-1">mdi-check-circle</v-icon>
      </div>
      <v-btn :icon="expanded ? 'mdi-chevron-up' : 'mdi-chevron-down'" size="x-small" variant="text" />
    </div>
    <v-divider v-if="expanded" />
    <v-expand-transition>
      <div v-show="expanded" class="pa-3">
        <slot />
      </div>
    </v-expand-transition>
  </v-card>
</template>

<script setup>
const props = defineProps({
  icon: { type: String, default: 'mdi-circle-outline' },
  title: { type: String, required: true },
  color: { type: String, default: 'primary' },
  expanded: { type: Boolean, default: false },
  readonly: { type: Boolean, default: false },
  id: { type: String, default: '' },
  filled: { type: Boolean, default: false },
  badge: { type: String, default: '' },
})

const expanded = ref(props.expanded)
function toggle() { if (!props.readonly) expanded.value = !expanded.value }
watch(() => props.expanded, (v) => { expanded.value = v })
</script>

<style scoped>
.section-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; cursor: pointer; user-select: none; }
.section-header:hover { background: rgba(var(--v-theme-on-surface), 0.04); }
.doc-section--filled { border-left: 3px solid rgb(var(--v-theme-success)); }
</style>
