<template>
  <v-row>
    <v-col v-for="(field, i) in fields" :key="i" :cols="field.cols || 12" :sm="field.sm || 6" :md="field.md || 4">
      <div class="text-caption text-medium-emphasis text-uppercase" style="letter-spacing:0.5px;">
        {{ field.label }}
      </div>
      <div class="text-body-1 mt-1">
        <slot :name="field.key" :value="getValue(field)">
          {{ format(field) }}
        </slot>
      </div>
    </v-col>
  </v-row>
</template>

<script setup>
const props = defineProps({
  item: { type: Object, default: () => ({}) },
  fields: { type: Array, required: true } // [{ key, label, format?, cols?, sm?, md? }]
})

function getValue(f) {
  return f.key.split('.').reduce((acc, k) => (acc ? acc[k] : null), props.item)
}

function format(f) {
  const v = getValue(f)
  if (v == null || v === '') return '—'
  if (f.format) return f.format(v, props.item)
  return v
}
</script>
