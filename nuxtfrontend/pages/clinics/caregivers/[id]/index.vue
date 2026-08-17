<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- ── Toolbar ──────────────────────────────────────────────── -->
    <PageHeader :title="caregiver?.patient_name || 'Caregiver'"
      :subtitle="caregiver ? `Assigned ${formatDate(caregiver.assigned_date)}` : ''"
      icon="mdi-account-heart" color="pink">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
          @click="navigateTo(`${ns}/caregivers`)">Back</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
          @click="navigateTo(`${ns}/caregivers/${id}/edit`)">Edit</v-btn>
      </template>
    </PageHeader>

    <!-- ── Loading state ────────────────────────────────────────── -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="pink" size="48" />
    </div>

    <div v-else-if="!caregiver" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-account-heart</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Caregiver not found</div>
      <v-btn color="pink" rounded="lg" class="text-none mt-3"
        @click="navigateTo(`${ns}/caregivers`)">Back to Caregivers</v-btn>
    </div>

    <template v-else>
      <!-- ═══ Detail cards ═══════════════════════════════════════ -->
      <v-row dense>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="pink-lighten-5" size="32" class="mr-2">
                <v-icon color="pink-darken-2" size="20">mdi-account</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Patient</div>
            </div>
            <DetailField label="Patient" :value="caregiver.patient_name" />
            <v-btn v-if="caregiver.patient" size="small" variant="tonal" color="pink"
              rounded="lg" class="text-none mt-2" prepend-icon="mdi-account-details"
              @click="navigateTo(`${ns}/patients/${caregiver.patient}`)">
              View Patient
            </v-btn>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="pink-lighten-5" size="32" class="mr-2">
                <v-icon color="pink-darken-2" size="20">mdi-account-heart</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Caregiver</div>
            </div>
            <DetailField label="Caregiver name" :value="caregiver.caregiver_name" />
            <DetailField label="Relationship" :value="caregiver.relationship" />
            <v-chip size="small" variant="tonal"
              :color="caregiver.is_active ? 'success' : 'grey'" class="mt-2">
              {{ caregiver.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="pink-lighten-5" size="32" class="mr-2">
                <v-icon color="pink-darken-2" size="20">mdi-contact-phone</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Contact</div>
            </div>
            <DetailField label="Phone" :value="caregiver.phone" />
            <DetailField label="Email" :value="caregiver.email" />
            <DetailField label="Address" :value="caregiver.address" />
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="info-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="pink-lighten-5" size="32" class="mr-2">
                <v-icon color="pink-darken-2" size="20">mdi-note-text</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">Notes</div>
            </div>
            <div class="text-body-2 text-medium-emphasis"
              style="white-space: pre-wrap;">{{ caregiver.notes || '—' }}</div>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const ns = '/clinics'
const route = useRoute()

const r = useResource('/homecare/caregivers/')

const id = computed(() => route.params.id)
const caregiver = ref(null)
const loading = ref(false)

onMounted(async () => {
  loading.value = true
  try {
    const data = await r.get(id.value)
    caregiver.value = data
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.info-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
