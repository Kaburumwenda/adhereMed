<template>
  <div class="md-redirect">
    <v-progress-circular indeterminate color="primary" size="36" />
    <p>Opening your drug stores…</p>
  </div>
</template>

<script setup>
// Medication catalog merged into the drug stores page: each clinic branch
// owns a drug store, and that store owns its medication. The old route is kept
// as a redirect so existing links, bookmarks and prescriptions deep links work.
definePageMeta({ layout: 'default' })

if (import.meta.server) {
  await navigateTo('/clinics/drug-stores', { replace: true, redirectCode: 301 })
} else {
  navigateTo('/clinics/drug-stores', { replace: true })
}
</script>

<style scoped>
.md-redirect {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  min-height: 60vh;
  color: rgba(var(--v-theme-on-surface), 0.55);
  font-size: 12.5px;
}
</style>
