<script setup>
// Thin wrapper — redirects to the shared billing locked page
definePageMeta({ layout: 'default' })
navigateTo('/billing/locked', { replace: true })
</script>
<template><div /></template>
