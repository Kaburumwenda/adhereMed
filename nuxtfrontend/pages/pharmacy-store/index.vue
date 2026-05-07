<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Browse Pharmacies" icon="mdi-storefront" subtitle="Find a nearby pharmacy and order medications" />

    <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search pharmacies…" variant="outlined" density="compact" hide-details clearable class="mb-4" />

    <v-row v-if="loading"><v-col cols="12"><v-skeleton-loader type="card" /></v-col></v-row>
    <EmptyState v-else-if="!filtered.length" icon="mdi-pharmacy" title="No pharmacies found" />
    <v-row v-else>
      <v-col v-for="p in filtered" :key="p.id" cols="12" sm="6" md="4">
        <v-card rounded="lg" class="pa-4" hover :to="`/pharmacy-store/${p.id}`">
          <v-icon size="40" color="primary">mdi-pharmacy</v-icon>
          <h3 class="text-h6 font-weight-bold mt-2">{{ p.name }}</h3>
          <p class="text-body-2 text-medium-emphasis">{{ p.address || '—' }}</p>
          <v-chip v-if="p.is_open" size="small" color="success" variant="tonal">Open</v-chip>
          <v-chip v-else size="small" color="grey" variant="tonal">Closed</v-chip>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const items = ref([])
const search = ref('')
const loading = ref(false)
const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return q ? items.value.filter(p => (p.name || '').toLowerCase().includes(q)) : items.value
})
onMounted(async () => {
  loading.value = true
  items.value = await $api.get('/exchange/pharmacies/').then(r => r.data?.results || r.data || []).catch(() => [])
  loading.value = false
})
</script>
