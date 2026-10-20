<template>
  <div class="ohs-redirect d-flex flex-column align-center justify-center">
    <v-progress-circular indeterminate color="primary" size="38" width="3" />
    <div class="text-body-2 text-medium-emphasis mt-3">Opening the Safety Command Centre…</div>
  </div>
</template>

<script setup>
// `pages/dashboard.vue` already redirects OHSMS tenants to /ohs during setup.
// This stub exists so the dashboard component switcher never falls through to
// GenericDashboard and flashes the wrong UI while the redirect settles.
defineProps({})
</script>

<style scoped>
.ohs-redirect {
  min-height: 60vh;
}
</style>
