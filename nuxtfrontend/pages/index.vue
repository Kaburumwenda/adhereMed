<script setup>
// Root → dashboard (middleware will redirect to /welcome if not logged in)
definePageMeta({ middleware: () => navigateTo('/dashboard', { replace: true }) })
</script>

<template><div /></template>
