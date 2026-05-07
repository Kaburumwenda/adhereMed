<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Wards" icon="mdi-bed" subtitle="Manage hospital wards and bed occupancy">
      <template #actions>
        <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" to="/wards/new">New Ward</v-btn>
      </template>
    </PageHeader>

    <v-row v-if="r.loading.value">
      <v-col cols="12"><v-skeleton-loader type="card" /></v-col>
    </v-row>
    <EmptyState v-else-if="!r.items.value.length" icon="mdi-bed-empty" title="No wards yet" message="Create a ward to start tracking beds." />
    <v-row v-else>
      <v-col v-for="w in r.items.value" :key="w.id" cols="12" sm="6" md="4">
        <v-card rounded="lg" class="pa-4" :to="`/wards/${w.id}`" hover>
          <div class="d-flex align-center mb-2">
            <v-icon color="primary" class="mr-2">mdi-bed</v-icon>
            <h3 class="text-h6 font-weight-bold">{{ w.name }}</h3>
          </div>
          <div class="text-body-2 text-medium-emphasis mb-2">{{ w.description || '—' }}</div>
          <div class="d-flex justify-space-between align-center">
            <v-chip size="small" variant="tonal" color="info">{{ w.total_beds || 0 }} beds</v-chip>
            <v-chip size="small" variant="tonal" color="success">{{ w.available_beds || 0 }} free</v-chip>
          </div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/wards/wards/')
onMounted(() => r.list())
</script>
