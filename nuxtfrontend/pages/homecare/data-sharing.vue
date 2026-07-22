<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Data Sharing"
      subtitle="Control what each enrolled patient can see in their own AdhereMed portal."
      eyebrow="PRIVACY"
      icon="mdi-share-variant"
      :chips="[
        { icon: 'mdi-account-group', label: `${rows.length} patients` },
        { icon: 'mdi-eye-check',     label: `${fullyShared} fully shared` },
        { icon: 'mdi-eye-off',       label: `${restricted} restricted` }
      ]"
    />

    <v-alert type="info" variant="tonal" density="comfortable" rounded="lg" class="mb-4"
             icon="mdi-information">
      Patients sign in to their own account — they never log in to your homecare workspace.
      They only see the categories switched on below. By default everything is shared.
    </v-alert>

    <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                  placeholder="Search patient or record number…" density="comfortable"
                  variant="outlined" hide-details rounded="lg" class="mb-3"
                  style="max-width: 420px;" />

    <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-3" rounded />

    <EmptyState v-if="!loading && !filtered.length"
                icon="mdi-account-off" title="No enrolled patients"
                subtitle="Enrol a patient to manage their data sharing." />

    <v-row dense>
      <v-col v-for="r in filtered" :key="r.id" cols="12" lg="6">
        <v-card rounded="xl" :elevation="0" class="hc-share-card pa-4 h-100">
          <div class="d-flex align-center ga-3 mb-3">
            <v-avatar size="44" :color="r.is_shared ? 'teal' : 'grey'" variant="tonal">
              <v-icon :icon="r.is_shared ? 'mdi-share-variant' : 'mdi-share-off'" />
            </v-avatar>
            <div class="flex-grow-1 min-w-0">
              <div class="text-subtitle-1 font-weight-bold text-truncate">{{ r.patient_name }}</div>
              <div class="text-caption text-medium-emphasis">{{ r.medical_record_number }}</div>
            </div>
            <v-switch v-model="r.is_shared" color="teal" hide-details density="compact"
                      inset :loading="saving[r.patient]"
                      @update:model-value="save(r)" />
          </div>

          <v-divider class="mb-2" />

          <div :class="{ 'hc-dim': !r.is_shared }">
            <v-row dense>
              <v-col v-for="cat in categories" :key="cat.key" cols="12" sm="6">
                <div class="d-flex align-center ga-2 py-1">
                  <v-icon :icon="cat.icon" size="18"
                          :color="r.is_shared && r[cat.key] ? 'teal' : 'grey'" />
                  <span class="text-body-2 flex-grow-1">{{ cat.label }}</span>
                  <v-switch v-model="r[cat.key]" color="teal" hide-details density="compact"
                            :disabled="!r.is_shared" :loading="saving[r.patient]"
                            @update:model-value="save(r)" />
                </div>
              </v-col>
            </v-row>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const categories = [
  { key: 'share_profile',        label: 'Personal & medical profile', icon: 'mdi-card-account-details' },
  { key: 'share_care_team',      label: 'Care team',                  icon: 'mdi-account-group' },
  { key: 'share_vitals',         label: 'Vitals & measurements',      icon: 'mdi-heart-pulse' },
  { key: 'share_medications',    label: 'Medications & schedules',    icon: 'mdi-pill' },
  { key: 'share_treatment_plan', label: 'Treatment / care plan',      icon: 'mdi-clipboard-text' },
  { key: 'share_notes',          label: 'Visit notes',                icon: 'mdi-note-edit' },
  { key: 'share_adherence',      label: 'Adherence statistics',       icon: 'mdi-chart-line' },
  { key: 'share_escalations',    label: 'Escalations & alerts',       icon: 'mdi-alert' },
  { key: 'share_consents',       label: 'Consents',                   icon: 'mdi-file-sign' },
  { key: 'share_documents',      label: 'Documents & attachments',    icon: 'mdi-paperclip' }
]

const rows = ref([])
const loading = ref(false)
const saving = reactive({})
const search = ref('')
const snack = reactive({ show: false, text: '', color: 'success' })

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return rows.value
  return rows.value.filter(r =>
    (r.patient_name || '').toLowerCase().includes(q) ||
    (r.medical_record_number || '').toLowerCase().includes(q))
})

const fullyShared = computed(() =>
  rows.value.filter(r => r.is_shared && categories.every(c => r[c.key])).length)
const restricted = computed(() =>
  rows.value.filter(r => !r.is_shared || categories.some(c => !r[c.key])).length)

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/patients/sharing-overview/')
    rows.value = data
  } catch (e) {
    snack.text = 'Failed to load sharing settings'; snack.color = 'error'; snack.show = true
  } finally {
    loading.value = false
  }
}

async function save(r) {
  saving[r.patient] = true
  const payload = { is_shared: r.is_shared }
  categories.forEach(c => { payload[c.key] = r[c.key] })
  try {
    await $api.patch(`/homecare/patients/${r.patient}/sharing/`, payload)
    snack.text = 'Sharing updated'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = 'Failed to save'; snack.color = 'error'; snack.show = true
    await load()
  } finally {
    saving[r.patient] = false
  }
}

onMounted(load)
</script>

<style scoped>
.hc-share-card {
  background: rgba(255, 255, 255, 0.85);
  border: 1px solid rgba(13, 148, 136, 0.12);
  transition: box-shadow .2s ease;
}
.hc-share-card:hover { box-shadow: 0 8px 24px rgba(13, 148, 136, 0.12); }
.hc-dim { opacity: .45; }

:global(.v-theme--dark .hc-share-card) {
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(20, 184, 166, 0.18);
}
</style>
