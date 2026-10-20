<template>
  <section class="ohs-panel">
    <header v-if="title || $slots.actions" class="ohs-panel-head">
      <div class="d-flex align-center" style="gap:9px">
        <v-avatar v-if="icon" :size="28" :color="tone" variant="tonal">
          <v-icon size="15">{{ icon }}</v-icon>
        </v-avatar>
        <div>
          <div class="ohs-panel-title">{{ title }}</div>
          <div v-if="subtitle" class="ohs-panel-sub">{{ subtitle }}</div>
        </div>
      </div>
      <div class="d-flex flex-wrap align-center" style="gap:6px">
        <slot name="actions" />
      </div>
    </header>
    <div :class="['ohs-panel-body', { 'ohs-panel-body--flush': flush }]">
      <slot />
    </div>
  </section>
</template>

<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  tone: { type: String, default: 'primary' },
  flush: { type: Boolean, default: false },
})
</script>
