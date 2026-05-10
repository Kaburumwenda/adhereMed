<template>
  <NoteForm :note-id="route.params.id" />
</template>

<script setup>
const route = useRoute()
definePageMeta({ title: 'Edit care note' })
</script>
