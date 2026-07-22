<template>
  <div class="card card-hover group reveal">
    <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30 transition group-hover:bg-brand-500 group-hover:text-white" v-html="icon"></span>
    <h3 class="mt-5 font-display text-lg font-bold text-white">{{ title }}</h3>
    <p class="mt-2 text-sm leading-relaxed text-slate-400">{{ desc }}</p>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  desc: { type: String, required: true },
  icon: { type: String, default: '' }
})
</script>
