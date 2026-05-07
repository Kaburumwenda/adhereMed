<template>
  <div class="text-center pa-12">
    <v-icon :size="size" :color="iconColor" class="mb-4">{{ icon }}</v-icon>
    <h3 class="text-h6 font-weight-bold">{{ title }}</h3>
    <p class="text-body-2 text-medium-emphasis mt-1">{{ message }}</p>
    <slot />
  </div>
</template>

<script setup>
defineProps({
  icon: { type: String, default: 'mdi-inbox-outline' },
  iconColor: { type: String, default: 'grey' },
  size: { type: Number, default: 64 },
  title: { type: String, default: 'No data yet' },
  message: { type: String, default: '' }
})
</script>
