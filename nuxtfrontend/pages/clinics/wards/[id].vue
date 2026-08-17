<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="r.item.value?.name || 'Ward'" subtitle="Ward bed management" icon="mdi-bed" color="warning">
      <template #actions>
        <v-btn variant="text" to="/clinics/wards">Back</v-btn>
      </template>
    </PageHeader>

    <v-progress-circular v-if="r.loading.value" indeterminate color="primary" />
    <v-alert v-else-if="!r.item.value" type="info" variant="tonal">Ward not found.</v-alert>
    <template v-else>
      <v-row dense class="mb-3">
        <v-col cols="12" md="6">
          <v-card rounded="lg">
            <v-card-title class="text-subtitle-1 font-weight-bold">Ward Info</v-card-title>
            <v-card-text>
              <v-list density="compact">
                <v-list-item title="Name"><template #subtitle>{{ r.item.value.name }}</template></v-list-item>
                <v-list-item title="Type"><template #subtitle>{{ r.item.value.ward_type || 'general' }}</template></v-list-item>
                <v-list-item title="Total Beds"><template #subtitle>{{ r.item.value.total_beds }}</template></v-list-item>
                <v-list-item title="Description"><template #subtitle>{{ r.item.value.description || '—' }}</template></v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card rounded="lg">
            <v-card-title class="text-subtitle-1 font-weight-bold">Bed Status</v-card-title>
            <v-card-text>
              <div class="d-flex flex-wrap ga-2">
                <v-chip v-for="b in beds" :key="b.number" :color="bedColor(b.status)" variant="tonal" size="large">
                  <v-icon start>{{ bedIcon(b.status) }}</v-icon>
                  Bed {{ b.number }}
                </v-chip>
              </div>
              <div v-if="!beds.length" class="text-center pa-4 text-medium-emphasis">No bed data available.</div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </v-container>
</template>

<script setup>
const route = useRoute()
const r = useResource('/wards/wards/')
onMounted(() => r.get(route.params.id))

const beds = computed(() => {
  const w = r.item.value
  if (!w) return []
  if (w.beds?.length) return w.beds.map((b, i) => ({ number: b.number || i + 1, status: b.status, patient: b.patient }))
  const total = w.total_beds || 0
  return Array.from({ length: total }, (_, i) => ({ number: i + 1, status: w.occupied_beds && i < w.occupied_beds ? 'occupied' : 'available' }))
})

function bedColor(s) { return { available: 'success', occupied: 'error', maintenance: 'grey' }[s] || 'grey' }
function bedIcon(s) { return { available: 'mdi-bed-empty', occupied: 'mdi-bed', maintenance: 'mdi-bed-clock' }[s] || 'mdi-bed' }
</script>
