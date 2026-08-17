<script setup>
// This is a thin wrapper — the real billing overdue page at /billing/overdue
// handles all tenant types (pharmacy, lab, hospital, clinic, etc.)
definePageMeta({ layout: 'default' })
const route = useRoute()
// Redirect to the main overdue page which handles clinic tenants
navigateTo('/billing/overdue', { replace: true })
</script>
<template><div /></template>
