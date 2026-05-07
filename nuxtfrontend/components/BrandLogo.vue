<template>
  <div
    class="d-flex align-center justify-center"
    :style="{
      width: size + 'px',
      height: size + 'px',
      borderRadius: (size * 0.29) + 'px',
      background: 'linear-gradient(135deg, #0F766E 0%, #1D4ED8 100%)',
      boxShadow: '0 3px 10px rgba(15,118,110,0.32)'
    }"
  >
    <v-icon :size="size * 0.55" color="white">mdi-heart</v-icon>
  </div>
</template>

<script setup>
defineProps({
  size: { type: Number, default: 38 }
})
</script>
