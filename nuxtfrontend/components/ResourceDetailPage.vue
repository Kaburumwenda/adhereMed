<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:1080px;">
    <PageHeader :title="title" :icon="icon" :subtitle="subtitle">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" :to="backPath">{{ $t('common.back') }}</v-btn>
        <v-btn v-if="editPath" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-pencil" :to="editPath">{{ $t('common.edit') }}</v-btn>
        <slot name="actions" />
      </template>
    </PageHeader>

    <v-progress-linear v-if="resource.loading.value" indeterminate color="primary" />
    <slot v-else :item="resource.item.value" />
  </v-container>
</template>

<script setup>
const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  backPath: { type: String, required: true },
  editPath: { type: String, default: '' },
  resource: { type: Object, required: true },
  loadId: { type: [String, Number], required: true }
})

onMounted(() => props.resource.get(props.loadId))
</script>
