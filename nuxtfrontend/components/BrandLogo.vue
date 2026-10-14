<template>
  <div
    class="d-flex align-center justify-center"
    :style="{
      width: size + 'px',
      height: size + 'px',
      borderRadius: (size * 0.29) + 'px',
      overflow: 'hidden',
      boxShadow: '0 3px 10px rgba(15,118,110,0.32)'
    }"
  >
    <img
      :src="logoUrl"
      alt="AdhereMed logo"
      :style="{ width: size + 'px', height: size + 'px', objectFit: 'cover' }"
    />
  </div>
</template>

<script setup>
import logoUrl from '~/assets/images/logo.png'

defineProps({
  size: { type: Number, default: 38 }
})
</script>
