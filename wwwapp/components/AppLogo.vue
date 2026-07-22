<template>
  <NuxtLink to="/" class="group inline-flex items-center gap-2.5" aria-label="AdhereMed home">
    <span class="relative inline-flex h-10 w-10 items-center justify-center">
      <svg viewBox="0 0 64 64" class="h-10 w-10 drop-shadow-[0_0_12px_rgba(47,109,255,0.55)]">
        <rect width="64" height="64" rx="16" fill="#0A0F1F" />
        <rect width="64" height="64" rx="16" :fill="`url(#${uid}bg)`" fill-opacity="0.16" />
        <path d="M20 44V20h5l7 11 7-11h5v24h-5V29l-7 10-7-10v15z" :fill="`url(#${uid}m)`" />
        <circle cx="32" cy="32" r="29" :stroke="`url(#${uid}m)`" stroke-opacity="0.5" stroke-width="2" fill="none" />
        <defs>
          <linearGradient :id="`${uid}m`" x1="16" y1="16" x2="48" y2="48" gradientUnits="userSpaceOnUse">
            <stop stop-color="#8ebcff" />
            <stop offset="1" stop-color="#37d6ff" />
          </linearGradient>
          <linearGradient :id="`${uid}bg`" x1="0" y1="0" x2="64" y2="64" gradientUnits="userSpaceOnUse">
            <stop stop-color="#2f6dff" />
            <stop offset="1" stop-color="#37d6ff" />
          </linearGradient>
        </defs>
      </svg>
    </span>
    <span v-if="!iconOnly" class="font-display text-lg font-extrabold leading-none tracking-tight text-white">
      Adhere<span class="text-brand-400">Med</span>
    </span>
  </NuxtLink>
</template>

<script setup>
import { useId } from 'vue'

defineProps({
  iconOnly: { type: Boolean, default: false }
})

// SSR-stable unique id per instance so duplicate gradient defs never collide across the page.
const uid = 'lg' + useId().replace(/[^a-zA-Z0-9]/g, '')
</script>
