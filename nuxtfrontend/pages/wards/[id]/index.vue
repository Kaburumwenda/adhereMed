<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="ward?.name || 'Ward'" icon="mdi-bed" :subtitle="ward?.description">
      <template #actions>
        <v-btn variant="text" prepend-icon="mdi-arrow-left" to="/wards" class="text-none">Back</v-btn>
        <v-btn color="primary" prepend-icon="mdi-pencil" rounded="lg" class="text-none ml-2" :to="`/wards/${id}/edit`">Edit</v-btn>
      </template>
    </PageHeader>

    <v-row v-if="ward">
      <v-col cols="12">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Beds</h3>
          <EmptyState v-if="!beds.length" icon="mdi-bed-empty" title="No beds" message="Add beds to this ward." />
          <v-row v-else dense>
            <v-col v-for="b in beds" :key="b.id" cols="6" sm="3" md="2">
              <v-card variant="outlined" class="pa-3 text-center" :color="b.is_occupied ? 'error' : 'success'" :variant="b.is_occupied ? 'tonal' : 'tonal'">
                <v-icon size="32" :color="b.is_occupied ? 'error' : 'success'">mdi-bed</v-icon>
                <div class="text-subtitle-2 mt-1">{{ b.bed_number }}</div>
                <div class="text-caption">{{ b.is_occupied ? 'Occupied' : 'Free' }}</div>
              </v-card>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()
const id = computed(() => route.params.id)
const ward = ref(null)
const beds = ref([])
onMounted(async () => {
  ward.value = await $api.get(`/wards/wards/${id.value}/`).then(r => r.data).catch(() => null)
  beds.value = await $api.get(`/wards/beds/?ward=${id.value}`).then(r => r.data?.results || r.data || []).catch(() => [])
})
</script>
