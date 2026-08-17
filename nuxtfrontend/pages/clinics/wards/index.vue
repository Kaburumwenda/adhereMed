<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Wards" subtitle="Inpatient wards and bed management" icon="mdi-bed" color="warning">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh" :loading="r.loading.value" @click="r.list({ page_size: 1000 })">Refresh</v-btn>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openDialog()">New Ward</v-btn>
      </template>
    </PageHeader>

    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="h-100">
          <v-card-text class="d-flex align-center ga-3 py-3">
            <v-avatar :color="k.color" size="40" rounded="lg" variant="tonal"><v-icon :icon="k.icon" :color="k.color" size="22" /></v-avatar>
            <div><div class="text-h6 font-weight-bold">{{ k.value }}</div><div class="text-caption text-medium-emphasis">{{ k.label }}</div></div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <v-col v-for="w in r.items.value" :key="w.id" cols="12" md="6" lg="4">
        <v-card rounded="lg" class="h-100" hover :to="`/clinics/wards/${w.id}`">
          <v-card-title class="d-flex align-center justify-space-between">
            <span class="text-subtitle-1 font-weight-bold">{{ w.name }}</span>
            <v-chip size="small" variant="tonal" color="warning">{{ w.ward_type || 'general' }}</v-chip>
          </v-card-title>
          <v-card-text>
            <div class="d-flex align-center ga-3 mb-2">
              <v-avatar color="warning" variant="tonal" size="36"><v-icon color="warning">mdi-bed</v-icon></v-avatar>
              <div>
                <div class="text-h5 font-weight-bold">{{ w.available_beds ?? w.total_beds - (w.occupied_beds || 0) }} / {{ w.total_beds }}</div>
                <div class="text-caption text-medium-emphasis">Beds available</div>
              </div>
            </div>
            <p v-if="w.description" class="text-body-2 text-medium-emphasis mb-0">{{ w.description }}</p>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <div v-if="!r.loading.value && !r.items.value.length" class="text-center pa-8">
      <v-icon size="64" color="grey-lighten-1">mdi-bed</v-icon>
      <div class="text-h6 mt-2">No wards yet</div>
      <v-btn color="primary" class="mt-3" @click="openDialog()">Create Ward</v-btn>
    </div>

    <v-dialog v-model="dialog" max-width="500">
      <v-card rounded="lg">
        <v-card-title class="text-h6">New Ward</v-card-title>
        <v-card-text>
          <v-form>
            <v-text-field v-model="wardForm.name" label="Ward Name" required variant="outlined" density="compact" class="mb-2" />
            <v-select v-model="wardForm.ward_type" :items="['general','private','icu','maternity','pediatric','surgical']" label="Type" variant="outlined" density="compact" class="mb-2" />
            <v-text-field v-model="wardForm.total_beds" label="Total Beds" type="number" variant="outlined" density="compact" class="mb-2" />
            <v-textarea v-model="wardForm.description" label="Description" variant="outlined" density="compact" rows="2" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="r.saving.value" @click="saveWard">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
const r = useResource('/wards/wards/')
onMounted(() => r.list({ page_size: 1000 }))

const kpis = computed(() => {
  const total = r.items.value.reduce((s, w) => s + (w.total_beds || 0), 0)
  const occupied = r.items.value.reduce((s, w) => s + (w.occupied_beds || 0), 0)
  const available = total - occupied
  return [
    { label: 'Total Beds', value: total, icon: 'mdi-bed', color: 'warning' },
    { label: 'Available', value: available, icon: 'mdi-bed-empty', color: 'success' },
    { label: 'Occupied', value: occupied, icon: 'mdi-bed-outline', color: 'error' },
    { label: 'Occupancy %', value: total ? Math.round(occupied / total * 100) + '%' : '—', icon: 'mdi-chart-donut', color: 'info' },
  ]
})

const dialog = ref(false)
const wardForm = reactive({ name: '', ward_type: 'general', total_beds: 10, description: '' })
function openDialog() { Object.assign(wardForm, { name: '', ward_type: 'general', total_beds: 10, description: '' }); dialog.value = true }
async function saveWard() {
  try { await r.create(wardForm); dialog.value = false; r.list({ page_size: 1000 }) } catch {}
}
</script>
