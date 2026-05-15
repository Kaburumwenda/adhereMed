<template>
  <div class="d-flex flex-wrap align-center justify-space-between mb-5 ga-3">
    <div class="d-flex align-center">
      <v-avatar v-if="icon" :color="avatarColor" size="48" class="mr-3">
        <v-icon :color="iconColor" size="28">{{ icon }}</v-icon>
      </v-avatar>
      <div>
        <h1 class="text-h5 font-weight-bold mb-1">{{ title }}</h1>
        <p v-if="subtitle" class="text-body-2 text-medium-emphasis ma-0">{{ subtitle }}</p>
      </div>
    </div>
    <div class="d-flex align-center" style="gap:8px">
      <slot name="actions" />
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  color: { type: String, default: 'primary' },
})

const avatarColor = computed(() => {
  const c = props.color
  if (c.includes('-lighten') || c.includes('-darken')) return c
  return `${c}-lighten-5`
})

const iconColor = computed(() => {
  const c = props.color
  if (c.includes('-darken')) return c
  return `${c}-darken-2`
})
</script>
