<template>
  <div class="d-flex align-center flex-wrap mb-6 ga-3">
    <div class="flex-grow-1">
      <h1 class="text-h4 font-weight-bold mb-1">
        <v-icon v-if="icon" :icon="icon" class="mr-2" color="primary" />
        {{ title }}
      </h1>
      <p v-if="subtitle" class="text-body-2 text-medium-emphasis ma-0">{{ subtitle }}</p>
    </div>
    <slot name="actions" />
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' }
})
</script>
