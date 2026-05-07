<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Doctor Directory" icon="mdi-doctor" subtitle="Find a doctor by name or specialization" />

    <v-row class="mb-2">
      <v-col cols="12" md="8">
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search doctors…" variant="outlined" density="compact" hide-details clearable />
      </v-col>
      <v-col cols="12" md="4">
        <v-autocomplete v-model="spec" :items="specs" item-title="name" item-value="id" label="Specialization" density="compact" variant="outlined" clearable hide-details />
      </v-col>
    </v-row>

    <v-row v-if="loading"><v-col cols="12"><v-skeleton-loader type="card" /></v-col></v-row>
    <EmptyState v-else-if="!filtered.length" icon="mdi-doctor" title="No doctors found" />
    <v-row v-else>
      <v-col v-for="d in filtered" :key="d.id" cols="12" sm="6" md="4">
        <v-card rounded="lg" class="pa-4" hover :to="`/doctors/${d.id}`">
          <div class="d-flex align-center mb-3">
            <v-avatar size="56" color="primary" variant="tonal">
              <v-img v-if="d.picture" :src="d.picture" />
              <v-icon v-else size="32">mdi-doctor</v-icon>
            </v-avatar>
            <div class="ml-3">
              <h3 class="text-h6 font-weight-bold">Dr. {{ d.full_name }}</h3>
              <div class="text-caption text-medium-emphasis">{{ d.specialization_name || '—' }}</div>
            </div>
          </div>
          <p class="text-body-2 text-medium-emphasis text-truncate-2">{{ d.bio || 'No bio yet.' }}</p>
          <div class="d-flex justify-space-between align-center mt-2">
            <v-chip size="small" variant="tonal" color="primary">{{ d.experience_years || 0 }}y exp</v-chip>
            <v-rating :model-value="d.rating || 0" density="compact" size="small" readonly half-increments />
          </div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const search = ref('')
const spec = ref(null)
const items = ref([])
const specs = ref([])
const loading = ref(true)
const filtered = computed(() => {
  let arr = items.value
  const q = search.value.toLowerCase()
  if (q) arr = arr.filter(d => (d.full_name || '').toLowerCase().includes(q))
  if (spec.value) arr = arr.filter(d => d.specialization === spec.value)
  return arr
})
onMounted(async () => {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  items.value = await safe('/doctors/')
  specs.value = await safe('/doctors/specializations/')
  loading.value = false
})
</script>

<style scoped>
.text-truncate-2 {
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
