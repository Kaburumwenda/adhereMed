<template>
  <v-row class="ma-0">
    <v-col v-for="s in stats" :key="s.title" cols="12" sm="6" :md="md">
      <v-card rounded="lg" class="pa-4">
        <div class="d-flex align-center mb-2">
          <v-avatar size="40" :color="s.color" variant="tonal" class="mr-3">
            <v-icon :color="s.color">{{ s.icon }}</v-icon>
          </v-avatar>
          <span class="text-body-2 text-medium-emphasis">{{ s.title }}</span>
        </div>
        <div class="text-h4 font-weight-bold">{{ s.value }}</div>
        <div v-if="s.hint" class="text-caption text-medium-emphasis mt-1">{{ s.hint }}</div>
      </v-card>
    </v-col>
  </v-row>
</template>

<script setup>
defineProps({
  stats: { type: Array, required: true },
  md: { type: [Number, String], default: 3 }
})
</script>
