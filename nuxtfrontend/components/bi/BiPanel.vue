<template>
  <v-card rounded="lg" class="h-100 d-flex flex-column" :border="border" :elevation="border ? 0 : 1">
    <div v-if="title || $slots.actions" class="d-flex align-center justify-space-between px-4 pt-3 pb-2">
      <div class="d-flex align-center">
        <v-avatar v-if="icon" size="30" :color="color" variant="tonal" class="mr-2">
          <v-icon size="16">{{ icon }}</v-icon>
        </v-avatar>
        <div>
          <div class="text-subtitle-1 font-weight-bold">{{ title }}</div>
          <div v-if="subtitle" class="text-caption text-medium-emphasis">{{ subtitle }}</div>
        </div>
      </div>
      <div class="d-flex align-center ga-1">
        <slot name="actions" />
      </div>
    </div>
    <v-divider v-if="title || $slots.actions" />
    <div :class="noPadding ? '' : 'pa-4'" class="flex-grow-1 d-flex flex-column">
      <slot />
    </div>
    <div v-if="$slots.footer">
      <v-divider />
      <div class="px-4 py-2"><slot name="footer" /></div>
    </div>
  </v-card>
</template>

<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  color: { type: String, default: 'primary' },
  noPadding: { type: Boolean, default: false },
  border: { type: Boolean, default: true }
})
</script>
