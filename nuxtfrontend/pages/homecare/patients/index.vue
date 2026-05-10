<template>
  <div class="hc-patients pa-4 pa-md-6">
    <!-- Hero -->
    <div class="hc-hero pa-5 pa-md-6 mb-5">
      <div class="d-flex align-center flex-wrap ga-4">
        <v-avatar size="56" class="hc-hero-icon">
          <v-icon icon="mdi-account-multiple" color="white" size="28" />
        </v-avatar>
        <div class="flex-grow-1">
          <div class="text-overline text-white-soft">HOMECARE · PATIENTS</div>
          <h1 class="text-h4 font-weight-bold text-white ma-0">Patients in care</h1>
          <p class="text-body-2 text-white-soft mb-0 mt-1">
            {{ stats.total }} enrolled · {{ stats.active }} active · {{ stats.critical }} critical
          </p>
        </div>
        <v-btn variant="flat" rounded="pill" prepend-icon="mdi-account-plus"
               color="white" class="text-none" to="/homecare/patients/new">
          <span class="text-teal-darken-2 font-weight-bold">Enrol patient</span>
        </v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <MetricTile label="Total patients" :value="stats.total" icon="mdi-account-multiple"
                    color="#0d9488" />
      </v-col>
      <v-col cols="6" md="3">
        <MetricTile label="Active" :value="stats.active" icon="mdi-account-check"
                    color="#10b981" />
      </v-col>
      <v-col cols="6" md="3">
        <MetricTile label="High risk" :value="stats.high" icon="mdi-shield-alert"
                    color="#f59e0b" />
      </v-col>
      <v-col cols="6" md="3">
        <MetricTile label="Critical" :value="stats.critical" icon="mdi-shield-off"
                    color="#ef4444" />
      </v-col>
    </v-row>

    <!-- Filter bar -->
    <v-card rounded="xl" :elevation="0" class="hc-card pa-3 mb-4">
      <div class="d-flex align-center flex-wrap ga-2">
        <v-text-field v-model="search" placeholder="Search by name, MRN, email…"
                      prepend-inner-icon="mdi-magnify" density="comfortable"
                      hide-details variant="solo-filled" flat rounded="lg"
                      class="flex-grow-1" style="min-width: 240px" />
        <v-select v-model="riskFilter" :items="riskOptions" item-title="label" item-value="value"
                  density="comfortable" hide-details variant="solo-filled" flat rounded="lg"
                  prepend-inner-icon="mdi-shield" style="max-width: 180px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  density="comfortable" hide-details variant="solo-filled" flat rounded="lg"
                  prepend-inner-icon="mdi-filter-variant" style="max-width: 160px" />
        <v-btn-toggle v-model="view" mandatory rounded="lg" density="comfortable" color="teal">
          <v-btn value="grid" icon="mdi-view-grid" size="small" />
          <v-btn value="list" icon="mdi-format-list-bulleted" size="small" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Loading -->
    <div v-if="loading" class="d-flex justify-center py-12">
      <v-progress-circular indeterminate color="teal" size="48" />
    </div>

    <!-- Empty -->
    <v-card v-else-if="!filtered.length" rounded="xl" :elevation="0" class="hc-card pa-12 text-center">
      <v-icon icon="mdi-account-multiple-outline" size="72" color="grey-lighten-1" />
      <h3 class="text-h6 font-weight-bold mt-3">No patients found</h3>
      <p class="text-body-2 text-medium-emphasis mb-4">
        {{ search || riskFilter !== 'all' || statusFilter !== 'all'
            ? 'Try clearing filters or adjusting your search.'
            : 'Enrol your first patient to get started.' }}
      </p>
      <v-btn color="teal" rounded="lg" class="text-none" prepend-icon="mdi-account-plus"
             to="/homecare/patients/new">Enrol patient</v-btn>
    </v-card>

    <!-- Grid view -->
    <v-row v-else-if="view === 'grid'" dense>
      <v-col v-for="p in filtered" :key="p.id" cols="12" sm="6" md="4" lg="3">
        <v-card rounded="xl" :elevation="0" class="hc-pcard pa-4 h-100"
                :to="`/homecare/patients/${p.id}`">
          <div class="d-flex align-start mb-3">
            <v-avatar size="48" :color="riskColor(p.risk_level)" variant="tonal" class="mr-3">
              <span class="text-subtitle-2 font-weight-bold">{{ initials(p) }}</span>
            </v-avatar>
            <div class="flex-grow-1 min-w-0">
              <div class="text-subtitle-1 font-weight-bold text-truncate">
                {{ patientName(p) }}
              </div>
              <div class="text-caption text-medium-emphasis text-truncate">
                {{ p.medical_record_number }}
              </div>
            </div>
            <v-chip size="x-small" :color="riskColor(p.risk_level)" variant="flat"
                    class="text-uppercase font-weight-bold">
              {{ p.risk_level }}
            </v-chip>
          </div>

          <div v-if="p.primary_diagnosis" class="hc-pcard-row">
            <v-icon icon="mdi-clipboard-pulse" size="14" class="mr-1 text-medium-emphasis" />
            <span class="text-body-2 text-truncate">{{ p.primary_diagnosis }}</span>
          </div>
          <div v-if="p.assigned_caregiver_name" class="hc-pcard-row">
            <v-icon icon="mdi-account-tie" size="14" class="mr-1 text-medium-emphasis" />
            <span class="text-body-2 text-truncate">{{ p.assigned_caregiver_name }}</span>
            <v-chip v-if="p.additional_caregivers_detail?.length"
                    size="x-small" color="purple" variant="tonal" class="ml-2">
              +{{ p.additional_caregivers_detail.length }}
            </v-chip>
          </div>
          <div v-if="p.age != null" class="hc-pcard-row">
            <v-icon icon="mdi-cake-variant" size="14" class="mr-1 text-medium-emphasis" />
            <span class="text-body-2">{{ p.age }} yrs · {{ p.gender || '—' }}</span>
          </div>

          <v-divider class="my-3" />

          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">Adherence</div>
              <div :class="adherenceClass(p.adherence_rate)" class="text-h6 font-weight-bold">
                {{ p.adherence_rate != null ? p.adherence_rate + '%' : '—' }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-caption text-medium-emphasis">Status</div>
              <v-chip size="x-small" :color="p.is_active ? 'success' : 'grey'"
                      variant="tonal" class="font-weight-bold">
                {{ p.is_active ? 'Active' : 'Closed' }}
              </v-chip>
            </div>
            <v-badge v-if="p.open_escalations" :content="p.open_escalations"
                     color="error" inline>
              <v-icon icon="mdi-alert-octagon" color="error" />
            </v-badge>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- List/table view -->
    <v-card v-else rounded="xl" :elevation="0" class="hc-card overflow-hidden">
      <v-table density="comfortable" hover>
        <thead>
          <tr>
            <th>Patient</th>
            <th>Diagnosis</th>
            <th>Care team</th>
            <th>Risk</th>
            <th>Adherence</th>
            <th>Status</th>
            <th class="text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.id" class="hc-row">
            <td>
              <div class="d-flex align-center">
                <v-avatar size="36" :color="riskColor(p.risk_level)" variant="tonal" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(p) }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ patientName(p) }}</div>
                  <div class="text-caption text-medium-emphasis">{{ p.medical_record_number }}</div>
                </div>
              </div>
            </td>
            <td class="text-body-2">{{ p.primary_diagnosis || '—' }}</td>
            <td class="text-body-2">
              <span>{{ p.assigned_caregiver_name || '—' }}</span>
              <v-chip v-if="p.additional_caregivers_detail?.length"
                      size="x-small" color="purple" variant="tonal" class="ml-2">
                +{{ p.additional_caregivers_detail.length }}
              </v-chip>
            </td>
            <td>
              <v-chip size="small" :color="riskColor(p.risk_level)" variant="tonal"
                      class="text-capitalize font-weight-bold">
                {{ p.risk_level }}
              </v-chip>
            </td>
            <td :class="adherenceClass(p.adherence_rate)" class="font-weight-bold">
              {{ p.adherence_rate != null ? p.adherence_rate + '%' : '—' }}
            </td>
            <td>
              <v-chip size="small" :color="p.is_active ? 'success' : 'grey'" variant="tonal">
                {{ p.is_active ? 'Active' : 'Closed' }}
              </v-chip>
            </td>
            <td class="text-right">
              <v-btn icon="mdi-eye" size="small" variant="text"
                     :to="`/homecare/patients/${p.id}`" />
              <v-btn icon="mdi-pencil" size="small" variant="text"
                     :to="`/homecare/patients/${p.id}/edit`" />
            </td>
          </tr>
        </tbody>
      </v-table>
    </v-card>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const items = ref([])
const loading = ref(true)
const search = ref('')
const riskFilter = ref('all')
const statusFilter = ref('all')
const view = ref('grid')

const riskOptions = [
  { value: 'all',      label: 'All risks' },
  { value: 'low',      label: 'Low risk' },
  { value: 'medium',   label: 'Medium risk' },
  { value: 'high',     label: 'High risk' },
  { value: 'critical', label: 'Critical' }
]
const statusOptions = [
  { value: 'all',    label: 'All statuses' },
  { value: 'active', label: 'Active only' },
  { value: 'closed', label: 'Closed' }
]

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 200 } })
    items.value = data?.results || data || []
  } finally {
    loading.value = false
  }
}
onMounted(load)

const stats = computed(() => {
  const total = items.value.length
  const active = items.value.filter(p => p.is_active).length
  const high = items.value.filter(p => p.risk_level === 'high').length
  const critical = items.value.filter(p => p.risk_level === 'critical').length
  return { total, active, high, critical }
})

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return items.value.filter(p => {
    if (riskFilter.value !== 'all' && p.risk_level !== riskFilter.value) return false
    if (statusFilter.value === 'active' && !p.is_active) return false
    if (statusFilter.value === 'closed' && p.is_active) return false
    if (!q) return true
    const hay = [
      patientName(p), p.medical_record_number, p.user?.email,
      p.primary_diagnosis, p.assigned_caregiver_name
    ].filter(Boolean).join(' ').toLowerCase()
    return hay.includes(q)
  })
})

function patientName(p) {
  return p.user?.full_name?.trim()
    || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim()
    || p.user?.email || 'Patient'
}
function initials(p) {
  const n = patientName(p)
  return n.split(/\s+/).slice(0, 2).map(s => s[0] || '').join('').toUpperCase() || 'P'
}
function adherenceClass(rate) {
  if (rate == null) return 'text-medium-emphasis'
  if (rate >= 85) return 'text-success'
  if (rate >= 60) return 'text-warning'
  return 'text-error'
}
function riskColor(level) {
  return ({ low: 'success', medium: 'warning', high: 'orange', critical: 'error' })[level] || 'grey'
}
</script>

<style scoped>
.hc-patients { min-height: calc(100vh - 64px); }

.hc-hero {
  position: relative;
  border-radius: 24px;
  overflow: hidden;
  background:
    radial-gradient(circle at 0% 0%, rgba(255,255,255,0.18) 0%, transparent 45%),
    linear-gradient(135deg, #0d9488 0%, #0ea5a4 35%, #0284c7 100%);
  box-shadow: 0 18px 40px -18px rgba(13,148,136,0.55);
}
.hc-hero-icon {
  background: rgba(255,255,255,0.18) !important;
  border: 1px solid rgba(255,255,255,0.28);
  backdrop-filter: blur(12px);
}
.text-white-soft { color: rgba(255,255,255,0.82) !important; }

.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}

.hc-pcard {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
  cursor: pointer;
}
.hc-pcard:hover {
  transform: translateY(-3px);
  border-color: rgba(13,148,136,0.4);
  box-shadow: 0 16px 32px -18px rgba(13,148,136,0.45) !important;
}
:global(.v-theme--dark) .hc-pcard {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark) .hc-pcard:hover {
  border-color: rgba(13,148,136,0.55);
  box-shadow: 0 16px 32px -18px rgba(13,148,136,0.7) !important;
}
.hc-pcard-row {
  display: flex; align-items: center;
  margin-bottom: 6px; min-width: 0;
}
.hc-pcard-row span { min-width: 0; }

.hc-row { transition: background 0.15s ease; }
.min-w-0 { min-width: 0; }
.h-100 { height: 100%; }
</style>
