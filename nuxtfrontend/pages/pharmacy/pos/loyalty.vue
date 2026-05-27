<template>
  <component :is="Page" />
</template>

<script setup>
import { defineAsyncComponent } from 'vue'
definePageMeta({ layout: 'default' })
const Page = defineAsyncComponent(() => import('~/pages/pos/loyalty.vue'))
</script>
