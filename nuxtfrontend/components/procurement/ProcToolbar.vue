<template>
  <div class="mb-4">
    <div class="d-flex flex-wrap align-center justify-space-between ga-3">
      <div class="d-flex align-center">
        <v-avatar v-if="icon" :color="color" variant="tonal" size="46" class="mr-3">
          <v-icon size="26">{{ icon }}</v-icon>
        </v-avatar>
        <div>
          <div class="text-caption text-medium-emphasis text-uppercase" style="letter-spacing: 1px">
            <v-icon size="12" color="primary" class="mr-1">mdi-circle</v-icon>{{ eyebrow }}
          </div>
          <h1 class="text-h6 text-md-h5 font-weight-bold mb-0">{{ title }}</h1>
          <div v-if="subtitle" class="text-body-2 text-medium-emphasis">{{ subtitle }}</div>
        </div>
      </div>

      <div class="d-flex flex-wrap align-center ga-2">
        <v-select
          v-if="branchItems && branchItems.length > 1"
          :model-value="branchFilter"
          :items="branchItems"
          item-title="name"
          item-value="id"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          :disabled="branchLocked"
          prepend-inner-icon="mdi-store-marker"
          style="min-width: 170px"
          @update:model-value="(v) => $emit('update:branchFilter', v)"
        />
        <v-chip v-if="stamp" size="small" variant="tonal" color="grey" prepend-icon="mdi-clock-outline">
          {{ stamp }}
        </v-chip>
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="$emit('refresh')" />
        <slot name="actions" />
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  eyebrow: { type: String, default: 'PROCUREMENT' },
  icon: { type: String, default: 'mdi-cart-variant' },
  color: { type: String, default: 'primary' },
  loading: { type: Boolean, default: false },
  stamp: { type: String, default: '' },
  branchFilter: { type: [Number, String, null], default: null },
  branchItems: { type: Array, default: () => [] },
  branchLocked: { type: Boolean, default: false }
})

defineEmits(['refresh', 'update:branchFilter'])
</script>
