<template>
  <span class="brand-mark">
    <span class="bold" :style="{ color: boldColor, fontSize: size + 'px' }">Adhere</span><span
      class="light" :style="{ color: lightColor, fontSize: size + 'px' }">Med</span>
  </span>
</template>

<script setup>
defineProps({
  size: { type: Number, default: 17 },
  boldColor: { type: String, default: '#0F766E' },
  lightColor: { type: String, default: '#0F766E' }
})
</script>
