<template>
  <v-container class="pa-12 text-center">
    <v-icon size="64" color="primary" class="mb-4">mdi-tools</v-icon>
    <h1 class="text-h4 font-weight-bold mb-2">{{ title }}</h1>
    <p class="text-body-1 text-medium-emphasis mb-6">
      This screen will be built in a later phase.
    </p>
    <v-btn color="primary" rounded="lg" class="text-none" to="/dashboard">
      Back to dashboard
    </v-btn>
  </v-container>
</template>

<script setup>
const route = useRoute()
const title = computed(() => {
  const segs = route.path.split('/').filter(Boolean)
  if (!segs.length) return 'Coming soon'
  return segs[0].split('-').map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
})
</script>
