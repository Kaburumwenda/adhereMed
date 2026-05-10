<template>
  <div class="d-flex flex-wrap align-center ga-2 mb-3">
    <v-text-field
      :model-value="search"
      @update:model-value="(v) => $emit('update:search', v)"
      :placeholder="searchPlaceholder"
      density="compact" variant="outlined" rounded="lg" hide-details
      prepend-inner-icon="mdi-magnify"
      style="max-width:340px;"
    />
    <v-select
      :model-value="source"
      @update:model-value="(v) => $emit('update:source', v)"
      :items="sourceOpts" item-title="label" item-value="value"
      density="compact" variant="outlined" rounded="lg" hide-details
      style="max-width:180px;"
    />
    <v-spacer />
    <v-btn v-if="canAdmin" variant="tonal" color="indigo" rounded="lg"
           prepend-icon="mdi-database-import" class="text-none"
           :loading="loading" @click="$emit('seed')">
      {{ seedLabel }}
    </v-btn>
    <v-btn v-if="canAdmin" color="teal" rounded="lg" prepend-icon="mdi-plus"
           class="text-none" @click="$emit('add')">
      {{ addLabel }}
    </v-btn>
  </div>
</template>

<script setup>
defineProps({
  search: String,
  source: String,
  loading: Boolean,
  canAdmin: Boolean,
  searchPlaceholder: { type: String, default: 'Search…' },
  seedLabel: { type: String, default: 'Seed' },
  addLabel: { type: String, default: 'Add' },
})
defineEmits(['update:search', 'update:source', 'add', 'seed'])
const sourceOpts = [
  { value: '',       label: 'All sources' },
  { value: 'seed',   label: 'Seeded only' },
  { value: 'custom', label: 'Custom only' },
]
</script>
