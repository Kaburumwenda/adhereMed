<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="`Hi ${auth.user?.first_name || ''} 💙`" subtitle="Your homecare at a glance." icon="mdi-home-heart" />
    <v-row>
      <v-col cols="12" md="4">
        <v-card rounded="xl" class="pa-4 text-center dash-card">
          <v-avatar size="80" color="teal" variant="tonal"><v-icon icon="mdi-pill" size="48" /></v-avatar>
          <div class="text-h4 font-weight-bold mt-2">{{ pendingCount }}</div>
          <div class="text-body-2">doses to take today</div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="xl" class="pa-4 text-center dash-card">
          <v-avatar size="80" color="indigo" variant="tonal"><v-icon icon="mdi-video" size="48" /></v-avatar>
          <div class="text-h4 font-weight-bold mt-2">{{ rooms.length }}</div>
          <div class="text-body-2">teleconsults scheduled</div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="xl" class="pa-4 text-center dash-card">
          <v-avatar size="80" color="amber" variant="tonal"><v-icon icon="mdi-shield-account" size="48" /></v-avatar>
          <div class="text-h4 font-weight-bold mt-2">{{ claims.length }}</div>
          <div class="text-body-2">insurance claims</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="xl" class="mt-4">
      <v-tabs v-model="tab" bg-color="transparent" color="teal" grow>
        <v-tab value="doses">My doses</v-tab>
        <v-tab value="teleconsult">Teleconsult</v-tab>
        <v-tab value="insurance">Insurance</v-tab>
        <v-tab value="consents">Consents</v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4">
        <v-window-item value="doses">
          <v-list>
            <v-list-item v-for="d in doses" :key="d.id"
              :title="`${d.medication_name} · ${d.dose}`"
              :subtitle="formatTime(d.scheduled_at)">
              <template #prepend>
                <v-avatar :color="dotColor(d.status)" size="36">
                  <v-icon icon="mdi-pill" color="white" />
                </v-avatar>
              </template>
              <template #append>
                <div class="d-flex ga-1">
                  <v-btn v-if="d.status === 'pending'" size="small" color="success" variant="tonal"
                         prepend-icon="mdi-check" @click="confirm(d)">I took it</v-btn>
                  <StatusChip v-else :status="d.status" />
                </div>
              </template>
            </v-list-item>
            <EmptyState v-if="!doses.length" icon="mdi-pill-off" title="No doses scheduled" />
          </v-list>
        </v-window-item>
        <v-window-item value="teleconsult">
          <v-list>
            <v-list-item v-for="r in rooms" :key="r.id"
              :title="`Doctor visit · ${formatDate(r.scheduled_at)}`"
              :subtitle="`Status: ${r.status}`">
              <template #append>
                <v-btn color="teal" variant="tonal" prepend-icon="mdi-video"
                       :loading="joining === r.id" @click="join(r)">Join</v-btn>
              </template>
            </v-list-item>
            <EmptyState v-if="!rooms.length" icon="mdi-video-off" title="No teleconsults scheduled" />
          </v-list>
          <v-card v-if="joinUrl" rounded="xl" class="pa-2 mt-3">
            <iframe :src="joinUrl" allow="camera; microphone; fullscreen" allowfullscreen
                    style="width:100%; height:520px; border:0; border-radius:12px;" />
          </v-card>
        </v-window-item>
        <v-window-item value="insurance">
          <v-list>
            <v-list-item v-for="c in claims" :key="c.id"
              :title="`Claim ${c.claim_number} · ${c.policy_provider}`"
              :subtitle="`KSh ${c.amount_requested} · ${c.claim_type}`">
              <template #append><StatusChip :status="c.status" /></template>
            </v-list-item>
            <EmptyState v-if="!claims.length" icon="mdi-shield-off" title="No claims yet" />
          </v-list>
        </v-window-item>
        <v-window-item value="consents">
          <v-list>
            <v-list-item v-for="c in consents" :key="c.id"
              :title="c.scope" :subtitle="`${c.granted_to || ''} · ${c.granted_at || ''}`">
              <template #append>
                <v-btn v-if="!c.revoked_at" size="small" color="error" variant="text"
                       prepend-icon="mdi-cancel" @click="revoke(c)">Revoke</v-btn>
                <StatusChip v-else status="closed" label="Revoked" />
              </template>
            </v-list-item>
            <EmptyState v-if="!consents.length" icon="mdi-file-document-outline" title="No consents on file" />
          </v-list>
        </v-window-item>
      </v-window>
    </v-card>
  </v-container>
</template>
<script setup>
import { useAuthStore } from '~/stores/auth'
import { useHomecareEvents } from '~/composables/useHomecare'

const auth = useAuthStore()
const { $api } = useNuxtApp()
const route = useRoute()
const tab = ref(route.query.tab || 'doses')
const doses = ref([])
const rooms = ref([])
const claims = ref([])
const consents = ref([])
const joinUrl = ref('')
const joining = ref(null)

const pendingCount = computed(() => doses.value.filter(d => d.status === 'pending').length)

function dotColor(s) { return { taken: 'success', missed: 'error', skipped: 'grey', pending: 'info' }[s] || 'grey' }
function formatTime(iso) { return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '' }
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  doses.value = await safe('/homecare/doses/today/')
  rooms.value = await safe('/homecare/teleconsult-rooms/')
  claims.value = await safe('/homecare/insurance-claims/')
  consents.value = await safe('/homecare/consents/')
}
async function confirm(d) {
  await $api.post(`/homecare/doses/${d.id}/mark_taken/`, {
    patient_confirmation: { method: 'self', at: new Date().toISOString() }
  })
  load()
}
async function join(r) {
  joining.value = r.id
  try {
    const { data } = await $api.post(`/homecare/teleconsult-rooms/${r.id}/join/`)
    joinUrl.value = data.join_url
  } finally { joining.value = null }
}
async function revoke(c) {
  await $api.post(`/homecare/consents/${c.id}/revoke/`)
  load()
}

onMounted(load)
useHomecareEvents(() => load())
</script>
<style scoped>
.dash-card {
  background: linear-gradient(160deg, rgba(20,184,166,0.05), rgba(56,189,248,0.05));
  border: 1px solid rgba(20,184,166,0.12);
}
</style>
