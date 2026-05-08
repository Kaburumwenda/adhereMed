<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      :title="`Hello ${auth.user?.first_name || 'Caregiver'}`"
      :subtitle="`${visitsCount} visits scheduled · ${pendingDoses} doses pending`"
      eyebrow="MY DAY"
      icon="mdi-account-heart"
      :chips="heroChips"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" prepend-icon="mdi-refresh" class="text-none"
               color="rgba(255,255,255,0.18)" @click="load">
          <span class="text-white">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" md="4">
        <v-card class="hc-profile pa-5" rounded="xl" :elevation="0">
          <div class="d-flex align-center">
            <v-avatar size="64" color="teal-darken-1" class="hc-profile-avatar">
              <v-icon icon="mdi-account-heart" color="white" size="36" />
            </v-avatar>
            <div class="ml-4">
              <div class="text-h6 font-weight-bold">{{ data?.caregiver?.full_name || auth.fullName }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ (data?.caregiver?.specialties || []).join(' · ') || 'Caregiver' }}
              </div>
              <div class="d-flex align-center mt-1 ga-3">
                <span class="d-flex align-center">
                  <v-icon icon="mdi-star" color="amber" size="16" />
                  <span class="text-body-2 font-weight-bold ml-1">{{ data?.caregiver?.rating ?? 0 }}</span>
                </span>
                <span class="text-caption text-medium-emphasis">{{ data?.caregiver?.total_visits ?? 0 }} visits</span>
              </div>
            </div>
          </div>
          <v-divider class="my-4" />
          <v-row dense>
            <v-col cols="4">
              <div class="hc-cg-stat hc-cg-teal">
                <div class="text-h5 font-weight-bold">{{ visitsCount }}</div>
                <div class="text-caption">Visits</div>
              </div>
            </v-col>
            <v-col cols="4">
              <div class="hc-cg-stat hc-cg-blue">
                <div class="text-h5 font-weight-bold">{{ pendingDoses }}</div>
                <div class="text-caption">Pending</div>
              </div>
            </v-col>
            <v-col cols="4">
              <div class="hc-cg-stat hc-cg-green">
                <div class="text-h5 font-weight-bold">{{ takenDoses }}</div>
                <div class="text-caption">Done</div>
              </div>
            </v-col>
          </v-row>
          <v-btn block color="teal" variant="tonal" rounded="lg" prepend-icon="mdi-map-marker"
                 class="text-none mt-3" to="/homecare/calendar">View calendar</v-btn>
        </v-card>
      </v-col>

      <v-col cols="12" md="8">
        <HomecarePanel
          title="Today's visits"
          :subtitle="today"
          icon="mdi-calendar-clock"
          color="#0d9488"
        >
          <v-timeline density="compact" side="end" line-thickness="2" line-color="teal-lighten-3"
                      truncate-line="both" v-if="data?.visits?.length">
            <v-timeline-item v-for="v in data.visits" :key="v.id" size="small" :dot-color="dotColor(v.status)">
              <template #icon>
                <v-icon :icon="visitIcon(v.status)" color="white" size="14" />
              </template>
              <v-card variant="flat" class="hc-visit pa-3" rounded="lg">
                <div class="d-flex align-center flex-wrap ga-2">
                  <div class="flex-grow-1 min-w-0">
                    <div class="text-subtitle-2 font-weight-bold text-truncate">{{ v.patient_name }}</div>
                    <div class="text-caption text-medium-emphasis">
                      <v-icon icon="mdi-clock-outline" size="12" /> {{ formatRange(v.start_at, v.end_at) }}
                      <span v-if="v.address"> · <v-icon icon="mdi-map-marker" size="12" /> {{ v.address }}</span>
                    </div>
                  </div>
                  <StatusChip :status="v.status" />
                  <v-btn v-if="v.status === 'scheduled'" size="small" color="teal" variant="tonal"
                         prepend-icon="mdi-login-variant" class="text-none"
                         @click="action(v.id, 'check_in')">Check in</v-btn>
                  <v-btn v-if="v.status === 'checked_in'" size="small" color="success" variant="tonal"
                         prepend-icon="mdi-logout-variant" class="text-none"
                         @click="action(v.id, 'check_out')">Check out</v-btn>
                </div>
              </v-card>
            </v-timeline-item>
          </v-timeline>
          <EmptyState v-else icon="mdi-calendar-blank" title="No visits today" message="Enjoy your day off." />
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <v-col cols="12">
        <HomecarePanel
          title="Today's doses"
          subtitle="One-tap medication confirmation"
          icon="mdi-pill"
          color="#0ea5e9"
        >
          <template #actions>
            <v-btn size="small" variant="text" color="teal" to="/homecare/doses" append-icon="mdi-arrow-right">
              All doses
            </v-btn>
          </template>
          <v-row dense v-if="data?.doses?.length">
            <v-col v-for="d in data.doses" :key="d.id" cols="12" md="6" lg="4">
              <v-card class="hc-dose pa-3" rounded="lg" :elevation="0">
                <div class="d-flex align-center">
                  <v-avatar :color="doseDotColor(d.status)" size="44">
                    <v-icon icon="mdi-pill" color="white" size="22" />
                  </v-avatar>
                  <div class="ml-3 flex-grow-1 min-w-0">
                    <div class="text-body-2 font-weight-bold text-truncate">{{ d.medication_name }}</div>
                    <div class="text-caption text-medium-emphasis text-truncate">
                      {{ d.dose }} · {{ d.patient_name }}
                    </div>
                    <div class="text-caption text-teal font-weight-bold">
                      <v-icon icon="mdi-clock-outline" size="12" /> {{ formatTime(d.scheduled_at) }}
                    </div>
                  </div>
                </div>
                <div v-if="d.status === 'pending'" class="d-flex ga-1 mt-3">
                  <v-btn size="small" color="success" variant="tonal" prepend-icon="mdi-check"
                         class="text-none flex-grow-1" @click="markDose(d.id, 'mark_taken')">Taken</v-btn>
                  <v-btn size="small" color="error" variant="tonal" prepend-icon="mdi-close"
                         class="text-none" @click="markDose(d.id, 'mark_missed')">Missed</v-btn>
                  <v-btn size="small" variant="text" icon="mdi-skip-next"
                         @click="markDose(d.id, 'mark_skipped')" />
                </div>
                <StatusChip v-else :status="d.status" class="mt-2" />
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-pill-off" title="No doses scheduled" />
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useHomecareEvents } from '~/composables/useHomecare'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const data = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })
const today = computed(() => new Date().toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' }))

const visitsCount = computed(() => data.value?.visits?.length || 0)
const pendingDoses = computed(() => (data.value?.doses || []).filter(d => d.status === 'pending').length)
const takenDoses = computed(() => (data.value?.doses || []).filter(d => d.status === 'taken').length)

const heroChips = computed(() => [
  { icon: 'mdi-calendar', label: today.value },
  { icon: 'mdi-star', label: `${data.value?.caregiver?.rating || 0} rating` }
])

function dotColor(s) {
  return { scheduled: 'info', checked_in: 'teal', completed: 'success', missed: 'error', cancelled: 'grey' }[s] || 'grey'
}
function visitIcon(s) {
  return { scheduled: 'mdi-clock', checked_in: 'mdi-login-variant', completed: 'mdi-check', missed: 'mdi-close', cancelled: 'mdi-cancel' }[s] || 'mdi-circle'
}
function doseDotColor(s) {
  return { taken: 'success', missed: 'error', skipped: 'grey', pending: 'info' }[s] || 'grey'
}
function formatTime(iso) {
  return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''
}
function formatRange(a, b) { return `${formatTime(a)} – ${formatTime(b)}` }

async function load() {
  try {
    const { data: d } = await $api.get('/homecare/caregivers/me/my-day/')
    data.value = d
  } catch {
    snack.text = 'Failed to load your day'
    snack.color = 'error'
    snack.show = true
  }
}

async function action(id, verb) {
  try {
    await $api.post(`/homecare/schedules/${id}/${verb}/`)
    snack.text = verb === 'check_in' ? 'Checked in' : 'Checked out'
    snack.color = 'success'
    snack.show = true
    load()
  } catch {
    snack.text = 'Action failed'; snack.color = 'error'; snack.show = true
  }
}

async function markDose(id, verb) {
  try { await $api.post(`/homecare/doses/${id}/${verb}/`); load() }
  catch { snack.text = 'Could not update dose'; snack.color = 'error'; snack.show = true }
}

onMounted(load)
useHomecareEvents(() => load())
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: calc(100vh - 64px);
}
.hc-profile {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
.hc-profile-avatar {
  background: linear-gradient(135deg, #0d9488, #0284c7) !important;
  box-shadow: 0 10px 24px -10px rgba(13,148,136,0.6);
}
.hc-cg-stat {
  text-align: center; padding: 10px;
  border-radius: 12px;
}
.hc-cg-teal { background: rgba(13,148,136,0.08); color: #0d9488; }
.hc-cg-blue { background: rgba(14,165,233,0.08); color: #0284c7; }
.hc-cg-green { background: rgba(16,185,129,0.08); color: #059669; }
.hc-visit {
  background: rgba(13,148,136,0.05);
  border: 1px solid rgba(13,148,136,0.15);
}
.hc-dose {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.hc-dose:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 24px -14px rgba(13,148,136,0.4) !important;
}
.min-w-0 { min-width: 0; }
</style>
