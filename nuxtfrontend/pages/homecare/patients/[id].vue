<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      :title="patient?.patient_name || 'Patient'"
      :subtitle="patient?.medical_record_number || ''"
      icon="mdi-account"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
               class="text-none" to="/homecare/patients">Back</v-btn>
        <v-btn variant="tonal" color="teal" rounded="lg" prepend-icon="mdi-pencil"
               class="text-none" :to="`/homecare/patients/${id}/edit`">Edit</v-btn>
      </template>
    </PageHeader>

    <v-row v-if="patient" class="mb-2">
      <v-col cols="12" md="3">
        <v-card rounded="xl" class="pa-4 text-center">
          <v-avatar size="80" color="teal" variant="tonal">
            <v-icon icon="mdi-account" size="48" />
          </v-avatar>
          <div class="text-h6 font-weight-bold mt-2">{{ patient.patient_name }}</div>
          <div class="text-caption text-medium-emphasis">{{ patient.primary_diagnosis }}</div>
          <div class="d-flex justify-center mt-2 ga-1">
            <StatusChip :status="patient.risk_level" />
            <StatusChip :status="patient.is_active ? 'active' : 'closed'" />
          </div>
        </v-card>
      </v-col>
      <v-col cols="12" md="9">
        <v-card rounded="xl" class="pa-4">
          <v-row dense>
            <v-col cols="12" sm="6" md="3">
              <div class="text-caption text-medium-emphasis">DOB</div>
              <div>{{ patient.date_of_birth || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6" md="3">
              <div class="text-caption text-medium-emphasis">Gender</div>
              <div>{{ patient.gender || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6" md="3">
              <div class="text-caption text-medium-emphasis">Caregiver</div>
              <div>{{ patient.caregiver_name || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6" md="3">
              <div class="text-caption text-medium-emphasis">Adherence</div>
              <div class="font-weight-bold" :class="adherenceClass(patient.adherence_rate)">
                {{ patient.adherence_rate != null ? patient.adherence_rate + '%' : '—' }}
              </div>
            </v-col>
            <v-col cols="12">
              <div class="text-caption text-medium-emphasis">Address</div>
              <div>{{ patient.address || '—' }}</div>
            </v-col>
            <v-col cols="12">
              <div class="text-caption text-medium-emphasis">Allergies</div>
              <div>{{ patient.allergies || 'None' }}</div>
            </v-col>
          </v-row>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="xl">
      <v-tabs v-model="tab" bg-color="transparent" color="teal" grow>
        <v-tab value="overview">Overview</v-tab>
        <v-tab value="plans">Treatment plans</v-tab>
        <v-tab value="meds">Medications</v-tab>
        <v-tab value="doses">Doses</v-tab>
        <v-tab value="notes">Notes & vitals</v-tab>
        <v-tab value="consents">Consents</v-tab>
        <v-tab value="insurance">Insurance</v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4">
        <v-window-item value="overview">
          <v-row>
            <v-col cols="12" md="6">
              <h4 class="text-subtitle-1 font-weight-bold mb-2">Open escalations</h4>
              <v-list density="compact">
                <v-list-item v-for="e in overview?.open_escalations" :key="e.id"
                             :title="e.reason" :subtitle="e.detail">
                  <template #append><StatusChip :status="e.severity" /></template>
                </v-list-item>
                <EmptyState v-if="!overview?.open_escalations?.length"
                  icon="mdi-shield-check" title="No open escalations" />
              </v-list>
            </v-col>
            <v-col cols="12" md="6">
              <h4 class="text-subtitle-1 font-weight-bold mb-2">Adherence breakdown</h4>
              <DonutRing :segments="adherenceSegments" :size="180" :thickness="18">
                <div class="text-h5 font-weight-bold">
                  {{ overview?.adherence?.total ? Math.round((overview.adherence.taken / overview.adherence.total) * 100) + '%' : '—' }}
                </div>
              </DonutRing>
            </v-col>
          </v-row>
        </v-window-item>

        <v-window-item value="plans">
          <v-list>
            <v-list-item v-for="p in plans" :key="p.id" :title="p.title"
                         :subtitle="`${p.diagnosis} · ${p.start_date}`">
              <template #append><StatusChip :status="p.status" /></template>
            </v-list-item>
            <EmptyState v-if="!plans.length" icon="mdi-clipboard-outline"
              title="No treatment plans yet" />
          </v-list>
        </v-window-item>

        <v-window-item value="meds">
          <v-list>
            <v-list-item v-for="m in meds" :key="m.id"
              :title="`${m.medication_name} · ${m.dose}`"
              :subtitle="`${m.route} · ${(m.times_of_day || []).join(', ')}`">
              <template #append>
                <StatusChip :status="m.is_active ? 'active' : 'closed'" />
              </template>
            </v-list-item>
            <EmptyState v-if="!meds.length" icon="mdi-pill-off"
              title="No medication schedules yet" />
          </v-list>
        </v-window-item>

        <v-window-item value="doses">
          <v-list>
            <v-list-item v-for="d in doses" :key="d.id"
              :title="`${d.medication_name} · ${d.dose}`"
              :subtitle="formatDateTime(d.scheduled_at)">
              <template #append><StatusChip :status="d.status" /></template>
            </v-list-item>
            <EmptyState v-if="!doses.length" icon="mdi-pill-off"
              title="No doses yet" />
          </v-list>
        </v-window-item>

        <v-window-item value="notes">
          <v-list>
            <v-list-item v-for="n in notes" :key="n.id"
              :title="n.content" :subtitle="`${n.caregiver_name} · ${formatDateTime(n.recorded_at)}`">
              <template #prepend><v-icon icon="mdi-note-edit" /></template>
            </v-list-item>
            <EmptyState v-if="!notes.length" icon="mdi-note-off"
              title="No notes yet" />
          </v-list>
        </v-window-item>

        <v-window-item value="consents">
          <v-list>
            <v-list-item v-for="c in consents" :key="c.id"
              :title="c.scope" :subtitle="`${c.granted_to || ''} · ${c.granted_at || ''}`">
              <template #append>
                <StatusChip :status="c.is_active ? 'active' : 'closed'" />
              </template>
            </v-list-item>
            <EmptyState v-if="!consents.length" icon="mdi-file-document-outline"
              title="No consents on file" />
          </v-list>
        </v-window-item>

        <v-window-item value="insurance">
          <v-list>
            <v-list-item v-for="p in policies" :key="p.id"
              :title="`${p.provider_name} · ${p.policy_number}`"
              :subtitle="`Valid ${p.valid_from} – ${p.valid_to || '∞'}`">
              <template #append>
                <StatusChip :status="p.is_active ? 'active' : 'closed'" />
              </template>
            </v-list-item>
            <EmptyState v-if="!policies.length" icon="mdi-shield-off"
              title="No insurance policies" />
          </v-list>
        </v-window-item>
      </v-window>
    </v-card>
  </v-container>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()
const id = computed(() => route.params.id)

const tab = ref('overview')
const patient = ref(null)
const overview = ref(null)
const plans = ref([])
const meds = ref([])
const doses = ref([])
const notes = ref([])
const consents = ref([])
const policies = ref([])

const adherenceSegments = computed(() => {
  const a = overview.value?.adherence || {}
  return [
    { label: 'Taken', value: a.taken || 0, color: 'success' },
    { label: 'Missed', value: a.missed || 0, color: 'error' },
    { label: 'Other', value: Math.max(0, (a.total || 0) - (a.taken || 0) - (a.missed || 0)), color: 'grey' }
  ]
})

function adherenceClass(r) {
  if (r == null) return ''
  if (r >= 85) return 'text-success'
  if (r >= 60) return 'text-warning'
  return 'text-error'
}
function formatDateTime(iso) {
  return iso ? new Date(iso).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : ''
}

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  const ovw = await $api.get(`/homecare/patients/${id.value}/overview/`).catch(() => null)
  if (ovw) {
    overview.value = ovw.data
    patient.value = ovw.data.patient
    plans.value = ovw.data.active_plan ? [ovw.data.active_plan] : []
    meds.value = ovw.data.medication_schedules || []
    notes.value = ovw.data.recent_notes || []
  }
  doses.value = await safe(`/homecare/doses/?schedule__patient=${id.value}`)
  consents.value = await safe(`/homecare/consents/?patient=${id.value}`)
  policies.value = await safe(`/homecare/insurance-policies/?patient=${id.value}`)
}
onMounted(load)
</script>
