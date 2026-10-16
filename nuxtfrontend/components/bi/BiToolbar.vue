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
        <v-select
          :model-value="rangeKey"
          :items="rangeOptions"
          item-title="label"
          item-value="key"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-calendar-range"
          style="min-width: 200px"
          @update:model-value="(v) => $emit('update:rangeKey', v)"
        />
        <v-text-field
          v-if="showTarget"
          :model-value="target"
          type="number"
          label="Monthly target"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          prefix="$"
          style="max-width: 165px"
          @update:model-value="(v) => $emit('update:target', v)"
        />
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="$emit('refresh')" />
        <slot name="actions" />
      </div>
    </div>

    <v-dialog :model-value="customDialog" max-width="420" @update:model-value="(v) => $emit('update:customDialog', v)">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom date range</v-card-title>
        <v-card-text>
          <v-text-field
            :model-value="customStart"
            label="Start date"
            type="date"
            variant="outlined"
            density="compact"
            hide-details
            class="mb-3"
            @update:model-value="(v) => $emit('update:customStart', v)"
          />
          <v-text-field
            :model-value="customEnd"
            label="End date"
            type="date"
            variant="outlined"
            density="compact"
            hide-details
            @update:model-value="(v) => $emit('update:customEnd', v)"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="$emit('update:customDialog', false)">Cancel</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            class="text-none"
            :disabled="!customStart || !customEnd"
            @click="$emit('apply-custom')"
          >Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  eyebrow: { type: String, default: 'BUSINESS INTELLIGENCE' },
  icon: { type: String, default: 'mdi-brain' },
  color: { type: String, default: 'teal' },
  rangeKey: { type: String, default: '12m' },
  rangeOptions: { type: Array, default: () => [] },
  branchFilter: { type: [Number, String, null], default: null },
  branchItems: { type: Array, default: () => [] },
  branchLocked: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
  target: { type: [Number, String], default: 0 },
  showTarget: { type: Boolean, default: true },
  customDialog: { type: Boolean, default: false },
  customStart: { type: String, default: '' },
  customEnd: { type: String, default: '' }
})

defineEmits([
  'update:rangeKey',
  'update:branchFilter',
  'update:target',
  'update:customDialog',
  'update:customStart',
  'update:customEnd',
  'refresh',
  'apply-custom'
])
</script>
