<template>
  <div class="d-flex align-center flex-wrap ga-2">
    <!-- Preset chips -->
    <div class="d-flex ga-1 flex-wrap">
      <v-chip v-for="p in presets" :key="p.value" size="small" rounded="pill"
              :variant="modelValue === p.value ? 'flat' : 'tonal'"
              :color="modelValue === p.value ? 'teal' : 'default'"
              class="text-none font-weight-medium cursor-pointer"
              @click="selectPreset(p.value)">
        {{ p.label }}
      </v-chip>
    </div>

    <!-- Custom date range menu -->
    <v-menu v-model="menu" :close-on-content-click="false" location="bottom end">
      <template #activator="{ props }">
        <v-chip v-bind="props" size="small" rounded="pill"
                :variant="modelValue === 'custom' ? 'flat' : 'outlined'"
                :color="modelValue === 'custom' ? 'teal' : 'default'"
                class="text-none font-weight-medium cursor-pointer">
          <v-icon start icon="mdi-calendar-cursor" size="14" />
          {{ modelValue === 'custom' ? customLabel : 'Custom' }}
        </v-chip>
      </template>
      <v-card rounded="lg" min-width="320" class="pa-4">
        <div class="text-subtitle-2 font-weight-bold mb-3">Custom date range</div>
        <v-text-field v-model="customFrom" label="From" type="date" variant="outlined"
                     density="compact" class="mb-3" hide-details />
        <v-text-field v-model="customTo" label="To" type="date" variant="outlined"
                     density="compact" class="mb-3" hide-details />
        <div class="d-flex ga-2 justify-end">
          <v-btn size="small" variant="text" class="text-none" @click="menu = false">Cancel</v-btn>
          <v-btn size="small" variant="flat" color="teal" class="text-none"
                 @click="applyCustom">Apply</v-btn>
        </div>
      </v-card>
    </v-menu>
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: String, default: '30d' },
  from: { type: String, default: '' },
  to: { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'update:from', 'update:to', 'change'])

const menu = ref(false)
const customFrom = ref(props.from)
const customTo = ref(props.to)

const presets = [
  { label: 'Today', value: 'today' },
  { label: 'Yesterday', value: 'yesterday' },
  { label: '7d', value: '7d' },
  { label: '30d', value: '30d' },
  { label: '90d', value: '90d' },
  { label: '1y', value: '1y' },
  { label: 'All', value: 'all' },
]

const customLabel = computed(() => {
  if (customFrom.value && customTo.value) {
    return `${customFrom.value.slice(5)} – ${customTo.value.slice(5)}`
  }
  return 'Custom'
})

function selectPreset(value) {
  emit('update:modelValue', value)
  emit('change', { range: value, from: '', to: '' })
}

function applyCustom() {
  menu.value = false
  emit('update:modelValue', 'custom')
  emit('update:from', customFrom.value)
  emit('update:to', customTo.value)
  emit('change', { range: 'custom', from: customFrom.value, to: customTo.value })
}

watch(() => props.from, (v) => { if (v) customFrom.value = v })
watch(() => props.to, (v) => { if (v) customTo.value = v })
</script>

<style scoped>
.cursor-pointer { cursor: pointer; }
</style>
