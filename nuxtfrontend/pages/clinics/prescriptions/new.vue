<template>
  <div class="d-flex justify-center align-center" style="height: 50vh;">
    <div class="text-center">
      <v-progress-circular indeterminate color="purple" size="32" class="mb-3" />
      <div class="text-body-2 text-medium-emphasis">Redirecting to prescriptions…</div>
    </div>
  </div>
</template>

<script setup>
// New prescriptions are created via the inline dialog on the prescriptions index page.
onMounted(() => {
  navigateTo({ path: '/clinics/prescriptions', query: { new: '1' } })
})
</script>
