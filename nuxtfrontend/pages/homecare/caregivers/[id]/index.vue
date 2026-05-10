<template>
  <div class="hc-bg">
    <!-- Hero header -->
    <div class="hc-cg-hero" :style="{ background: meta.gradient }">
      <div class="pa-4 pa-md-6">
        <div class="d-flex align-center ga-2 mb-3">
          <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
                 class="text-none text-white" to="/homecare/caregivers">Caregivers</v-btn>
          <v-spacer />
          <v-btn v-if="cg" variant="flat" color="white" rounded="pill"
                 prepend-icon="mdi-pencil" class="text-none mr-2"
                 :to="`/homecare/caregivers/${cg.id}/edit`">
            <span class="text-teal-darken-2 font-weight-bold">Edit</span>
          </v-btn>
          <v-btn v-if="cg" variant="flat" color="white" rounded="pill"
                 :prepend-icon="cg.is_available ? 'mdi-pause-circle' : 'mdi-check-circle'"
                 class="text-none mr-2" @click="toggleAvailability">
            <span class="text-teal-darken-2 font-weight-bold">
              {{ cg.is_available ? 'Set off-duty' : 'Set available' }}
            </span>
          </v-btn>
        </div>

        <div v-if="cg" class="d-flex align-center ga-4 flex-wrap">
          <v-avatar size="92" color="white" variant="flat" class="hc-cg-hero-avatar">
            <span class="text-h4 font-weight-bold" :style="{ color: meta.solid }">
              {{ initials }}
            </span>
          </v-avatar>
          <div class="flex-grow-1 min-w-0">
            <div class="text-overline text-white text-uppercase" style="opacity:0.85;">
              {{ meta.label }}
            </div>
            <div class="text-h4 font-weight-bold text-white text-truncate">
              {{ cg.user?.full_name || cg.user?.email || 'Caregiver' }}
            </div>
            <div class="d-flex flex-wrap ga-2 mt-2">
              <v-chip size="small" variant="flat" color="white" :class="`text-${meta.color}-darken-2`">
                <v-icon icon="mdi-email" start size="14" />
                {{ cg.user?.email || '—' }}
              </v-chip>
              <v-chip v-if="cg.license_number" size="small" variant="flat" color="white"
                      :class="`text-${meta.color}-darken-2`">
                <v-icon icon="mdi-card-account-details" start size="14" />
                Lic. {{ cg.license_number }}
              </v-chip>
              <v-chip size="small" variant="flat"
                      :color="cg.is_available ? 'success' : 'grey-darken-1'">
                <v-icon :icon="cg.is_available ? 'mdi-check-circle' : 'mdi-pause-circle'"
                        start size="14" />
                {{ cg.is_available ? 'Available' : 'Off duty' }}
              </v-chip>
            </div>
          </div>

          <!-- Stats panel -->
          <div class="d-flex ga-2">
            <div class="hc-stat-pill">
              <div class="text-h5 font-weight-bold">
                <v-icon icon="mdi-star" color="amber" size="20" />
                {{ Number(cg.rating || 0).toFixed(1) }}
              </div>
              <div class="text-caption">Rating</div>
            </div>
            <div class="hc-stat-pill">
              <div class="text-h5 font-weight-bold text-teal-darken-2">{{ cg.active_patients_count || 0 }}</div>
              <div class="text-caption">Patients</div>
            </div>
            <div class="hc-stat-pill">
              <div class="text-h5 font-weight-bold text-indigo-darken-2">{{ cg.total_visits || 0 }}</div>
              <div class="text-caption">Visits</div>
            </div>
          </div>
        </div>
        <v-skeleton-loader v-else type="article" class="bg-transparent" />
      </div>
    </div>

    <!-- Tabs -->
    <div class="px-4 px-md-6 pt-4">
      <v-card rounded="xl" elevation="0" class="hc-card pa-2">
        <v-tabs v-model="tab" align-tabs="start" color="teal" density="comfortable" class="hc-tabs">
          <v-tab value="profile"><v-icon start icon="mdi-account-details" />Profile</v-tab>
          <v-tab value="visits"><v-icon start icon="mdi-calendar-clock" />Visits</v-tab>
          <v-tab value="patients"><v-icon start icon="mdi-account-multiple" />Patients</v-tab>
        </v-tabs>
      </v-card>
    </div>

    <!-- Body -->
    <div v-if="cg" class="pa-4 pa-md-6 pt-3">
      <v-window v-model="tab">
        <!-- Profile -->
        <v-window-item value="profile">
          <v-row>
            <v-col cols="12" md="7">
              <v-card rounded="xl" elevation="0" class="hc-card pa-4">
                <SectionHead icon="mdi-card-account-details-outline" title="Profile details" />
                <v-row dense>
                  <v-col cols="6" md="4">
                    <div class="text-caption text-medium-emphasis">Category</div>
                    <v-chip size="small" :color="meta.color" variant="tonal">
                      <v-icon :icon="meta.icon" start size="14" />{{ meta.label }}
                    </v-chip>
                  </v-col>
                  <v-col cols="6" md="4">
                    <div class="text-caption text-medium-emphasis">Hire date</div>
                    <div class="font-weight-medium">{{ cg.hire_date || '—' }}</div>
                  </v-col>
                  <v-col cols="6" md="4">
                    <div class="text-caption text-medium-emphasis">Hourly rate</div>
                    <div class="font-weight-medium">KSh {{ cg.hourly_rate || 0 }}</div>
                  </v-col>
                  <v-col cols="6" md="4">
                    <div class="text-caption text-medium-emphasis">Employment</div>
                    <StatusChip :status="cg.employment_status" />
                  </v-col>
                  <v-col cols="6" md="4">
                    <div class="text-caption text-medium-emphasis">Engagement</div>
                    <v-chip size="small" :color="cg.is_independent ? 'orange' : 'blue'" variant="tonal">
                      {{ cg.is_independent ? 'Independent' : 'Employee' }}
                    </v-chip>
                  </v-col>
                  <v-col cols="6" md="4">
                    <div class="text-caption text-medium-emphasis">Phone</div>
                    <div class="font-weight-medium">{{ cg.user?.phone || '—' }}</div>
                  </v-col>
                  <v-col cols="12">
                    <div class="text-caption text-medium-emphasis mt-1">Bio</div>
                    <div>{{ cg.bio || '—' }}</div>
                  </v-col>
                </v-row>
              </v-card>
            </v-col>
            <v-col cols="12" md="5">
              <v-card rounded="xl" elevation="0" class="hc-card pa-4 h-100">
                <SectionHead icon="mdi-star-circle" title="Specialties & skills" />
                <div v-if="(cg.specialties || []).length" class="d-flex flex-wrap ga-1 mt-2">
                  <v-chip v-for="s in cg.specialties" :key="s" size="small"
                          :color="meta.color" variant="tonal">{{ s }}</v-chip>
                </div>
                <EmptyState v-else icon="mdi-star-off" title="No specialties listed"
                            message="Add specialties from the edit page." />
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

        <!-- Visits -->
        <v-window-item value="visits">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead icon="mdi-calendar-clock" title="Upcoming visits" />
            <v-list density="comfortable" class="bg-transparent">
              <v-list-item v-for="v in upcomingVisits" :key="v.id"
                           :title="v.patient_name || ('Patient #' + v.patient)"
                           :subtitle="formatDate(v.start_at)" prepend-icon="mdi-calendar-clock">
                <template #append><StatusChip :status="v.status" /></template>
              </v-list-item>
              <EmptyState v-if="!upcomingVisits.length" icon="mdi-calendar-blank"
                          title="No upcoming visits" />
            </v-list>
          </v-card>
        </v-window-item>

        <!-- Patients -->
        <v-window-item value="patients">
          <v-card rounded="xl" elevation="0" class="hc-card pa-4">
            <SectionHead icon="mdi-account-multiple" title="Active patients" />
            <EmptyState icon="mdi-information-outline" title="Coming soon"
                        message="Active patient assignments will appear here." />
          </v-card>
        </v-window-item>
      </v-window>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()

const cg = ref(null)
const upcomingVisits = ref([])
const tab = ref('profile')
const snack = reactive({ show: false, text: '', color: 'info' })

const CAT_META = {
  nurse: { label: 'Nurse', icon: 'mdi-medical-bag', color: 'indigo', solid: '#4f46e5',
    gradient: 'linear-gradient(135deg, #4338ca 0%, #6366f1 60%, #818cf8 100%)' },
  hca:   { label: 'Health Care Assistant', icon: 'mdi-hand-heart', color: 'pink', solid: '#db2777',
    gradient: 'linear-gradient(135deg, #be185d 0%, #db2777 60%, #f472b6 100%)' },
}
const meta = computed(() => CAT_META[cg.value?.category] ||
  { label: 'Caregiver', icon: 'mdi-account-heart', color: 'teal', solid: '#0d9488',
    gradient: 'linear-gradient(135deg, #0f766e 0%, #14b8a6 100%)' })

const initials = computed(() => {
  const n = (cg.value?.user?.full_name || cg.value?.user?.email || '').trim()
  if (!n) return '?'
  const parts = n.split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || n[0].toUpperCase()
})

async function load() {
  try {
    const { data } = await $api.get(`/homecare/caregivers/${route.params.id}/`)
    cg.value = data
    const { data: vs } = await $api.get(`/homecare/schedules/?caregiver=${route.params.id}`)
    upcomingVisits.value = (vs?.results || vs || []).slice(0, 10)
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to load caregiver', color: 'error' })
  }
}
async function toggleAvailability() {
  try {
    const { data } = await $api.post(`/homecare/caregivers/${route.params.id}/toggle_availability/`)
    cg.value = data
    Object.assign(snack, { show: true,
      text: data.is_available ? 'Marked available' : 'Set off-duty', color: 'success' })
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to update', color: 'error' })
  }
}
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }
onMounted(load)
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); background: rgb(248, 250, 252); }
:global(.v-theme--dark) .hc-bg { background: rgb(15,23,42); }

.hc-cg-hero { color: white; position: relative; overflow: hidden; }
.hc-cg-hero::after {
  content: ''; position: absolute; right: -60px; top: -60px;
  width: 240px; height: 240px; border-radius: 50%;
  background: rgba(255,255,255,0.08);
}
.hc-cg-hero-avatar { box-shadow: 0 8px 28px rgba(0,0,0,0.25); border: 4px solid rgba(255,255,255,0.7); }

.hc-stat-pill {
  background: rgba(255,255,255,0.95);
  border-radius: 14px;
  padding: 10px 18px;
  text-align: center;
  min-width: 92px;
  color: #0f172a;
  box-shadow: 0 8px 20px -10px rgba(0,0,0,0.25);
}

.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
.hc-tabs :deep(.v-tab) { text-transform: none; font-weight: 600; }
.min-w-0 { min-width: 0; }
.h-100 { height: 100%; }
</style>
