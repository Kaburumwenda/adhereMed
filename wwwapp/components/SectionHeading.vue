<template>
  <div :class="['reveal', center ? 'mx-auto max-w-2xl text-center' : 'max-w-2xl']">
    <span v-if="eyebrow" class="eyebrow">
      <span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span>
      {{ eyebrow }}
    </span>
    <h2 class="mt-5 font-display text-3xl font-extrabold leading-tight tracking-tight text-white sm:text-4xl md:text-[2.75rem]">
      <slot name="title">{{ title }}</slot>
    </h2>
    <p v-if="subtitle || $slots.default" class="mt-4 text-base leading-relaxed text-slate-400 sm:text-lg">
      <slot>{{ subtitle }}</slot>
    </p>
  </div>
</template>

<script setup>
defineProps({
  eyebrow: { type: String, default: '' },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  center: { type: Boolean, default: false }
})
</script>
