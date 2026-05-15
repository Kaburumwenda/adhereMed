<template>
  <v-app :class="{ 'rtl-layout': isRtl }">
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
    <PwaPrompt />
  </v-app>
</template>

<script setup>
import { useI18n } from 'vue-i18n'

const { locale } = useI18n()

const isRtl = computed(() => locale.value === 'ar')

watch(locale, (code) => {
  if (typeof document !== 'undefined') {
    document.documentElement.dir = code === 'ar' ? 'rtl' : 'ltr'
    document.documentElement.lang = code
  }
}, { immediate: true })
</script>

<style>
.rtl-layout {
  direction: rtl;
}
.rtl-layout .v-navigation-drawer {
  right: 0;
  left: auto !important;
}
</style>
