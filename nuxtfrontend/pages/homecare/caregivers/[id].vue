<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="cg?.user?.full_name || 'Caregiver'" icon="mdi-account-heart" :subtitle="cg?.license_number">
      <template #actions>
        <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
               class="text-none" to="/homecare/caregivers">Back</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" prepend-icon="mdi-toggle-switch"
               class="text-none" @click="toggleAvailability">
          {{ cg?.is_available ? 'Set off-duty' : 'Set available' }}
        </v-btn>
      </template>
    </PageHeader>
    <v-row v-if="cg">
      <v-col cols="12" md="4">
        <v-card rounded="xl" class="pa-4 text-center">
          <v-avatar size="100" color="indigo" variant="tonal">
            <v-icon icon="mdi-account-heart" size="60" />
          </v-avatar>
          <div class="text-h5 font-weight-bold mt-2">{{ cg.user?.full_name }}</div>
          <div class="text-caption text-medium-emphasis">{{ cg.user?.email }}</div>
          <div class="d-flex justify-center mt-2 ga-1 flex-wrap">
            <v-chip v-for="s in cg.specialties || []" :key="s" size="small" color="teal" variant="tonal">{{ s }}</v-chip>
          </div>
          <v-divider class="my-3" />
          <div class="d-flex justify-space-around">
            <div><div class="text-h5 font-weight-bold text-amber">{{ cg.rating || 0 }}</div><div class="text-caption">Rating</div></div>
            <div><div class="text-h5 font-weight-bold text-teal">{{ cg.total_visits || 0 }}</div><div class="text-caption">Visits</div></div>
            <div><div class="text-h5 font-weight-bold text-info">{{ cg.active_patients_count || 0 }}</div><div class="text-caption">Patients</div></div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="12" md="8">
        <v-card rounded="xl" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Profile</h3>
          <v-row dense>
            <v-col cols="6" md="4"><div class="text-caption text-medium-emphasis">Hire date</div><div>{{ cg.hire_date || '—' }}</div></v-col>
            <v-col cols="6" md="4"><div class="text-caption text-medium-emphasis">Hourly rate</div><div>KSh {{ cg.hourly_rate || 0 }}</div></v-col>
            <v-col cols="6" md="4"><div class="text-caption text-medium-emphasis">Status</div><div><StatusChip :status="cg.employment_status" /></div></v-col>
            <v-col cols="12"><div class="text-caption text-medium-emphasis">Bio</div><div>{{ cg.bio || '—' }}</div></v-col>
          </v-row>
          <v-divider class="my-4" />
          <h3 class="text-h6 font-weight-bold mb-3">Upcoming visits</h3>
          <v-list density="compact">
            <v-list-item v-for="v in upcomingVisits" :key="v.id" :title="v.patient_name"
                         :subtitle="formatDate(v.start_at)" prepend-icon="mdi-calendar-clock">
              <template #append><StatusChip :status="v.status" /></template>
            </v-list-item>
            <EmptyState v-if="!upcomingVisits.length" icon="mdi-calendar-blank" title="No upcoming visits" />
          </v-list>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>
<script setup>
const route = useRoute()
const { $api } = useNuxtApp()
const cg = ref(null)
const upcomingVisits = ref([])
async function load() {
  const { data } = await $api.get(`/homecare/caregivers/${route.params.id}/`)
  cg.value = data
  const { data: vs } = await $api.get(`/homecare/schedules/?caregiver=${route.params.id}`)
  upcomingVisits.value = (vs?.results || vs || []).slice(0, 10)
}
async function toggleAvailability() {
  const { data } = await $api.post(`/homecare/caregivers/${route.params.id}/toggle_availability/`)
  cg.value = data
}
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }
onMounted(load)
</script>
