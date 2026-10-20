<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-crosshairs-gps"
      eyebrow="IMS · LOGISTICS · LIVE TRACKING"
      title="Live Tracking"
      subtitle="Follow every movement in real time — search by tracking number, monitor transit progress and see the latest checkpoint."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-switch v-model="autoRefresh" color="white" density="compact" hide-details inset label="Auto" class="lg-auto-switch" />
      </template>
    </LogiHero>

    <!-- search -->
    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="trackingQuery"
          placeholder="Enter tracking number or shipment reference (e.g. TRK00000012 / SHP-00012)"
          prepend-inner-icon="mdi-barcode-scan"
          density="comfortable"
          variant="solo-filled"
          rounded="lg"
          flat
          bg-color="surface"
          hide-details
          clearable
          class="lg-search"
          @keyup.enter="track"
          @click:clear="tracked = null"
        />
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-magnify" :loading="tracking" @click="track">Track</v-btn>
        <v-spacer />
        <v-btn-toggle v-model="scope" density="comfortable" rounded="lg" variant="outlined" divided mandatory>
          <v-btn value="active" size="small" class="text-none">Active</v-btn>
          <v-btn value="all" size="small" class="text-none">All</v-btn>
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- tracked result -->
    <v-card v-if="tracked" rounded="xl" border class="mb-3 lg-tracked-card">
      <v-card-text>
        <div class="d-flex flex-wrap align-center justify-space-between ga-2 mb-3">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar size="46" color="primary" variant="tonal">
              <v-icon size="24">{{ statusOf(tracked.status).icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="d-flex align-center ga-2">
                <span class="text-h6 font-weight-bold">{{ tracked.reference }}</span>
                <v-chip size="small" variant="tonal" :color="statusOf(tracked.status).color" class="font-weight-bold">{{ statusOf(tracked.status).label }}</v-chip>
              </div>
              <div class="text-caption text-medium-emphasis">
                {{ tracked.tracking_number }} · {{ typeOf(tracked.movement_type).label }}
              </div>
            </div>
          </div>
          <v-btn variant="text" class="text-none" color="primary" :to="`/ims/logistics/shipments?focus=${tracked.id}`" append-icon="mdi-arrow-right">Open shipment</v-btn>
        </div>

        <div class="lg-progress-wrap mb-3">
          <div class="d-flex align-center justify-space-between mb-1">
            <span class="text-caption font-weight-medium">{{ tracked.origin_name || 'Origin' }}</span>
            <span class="text-caption font-weight-medium">{{ tracked.dest_name || 'Destination' }}</span>
          </div>
          <v-progress-linear :model-value="statusOf(tracked.status).pct" height="10" rounded color="primary" bg-color="surface-variant" />
          <div class="d-flex align-center justify-space-between mt-1">
            <span class="text-caption text-medium-emphasis">{{ progressLabel(tracked) }}</span>
            <span class="text-caption" :class="tracked.is_late ? 'text-error font-weight-medium' : 'text-medium-emphasis'">
              ETA {{ dt(tracked.scheduled_delivery) }}
            </span>
          </div>
        </div>

        <v-row dense>
          <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-stat-label">Driver</div><div class="lg-stat-value lg-stat-value--sm">{{ tracked.driver_name || '—' }}</div></div></v-col>
          <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-stat-label">Vehicle</div><div class="lg-stat-value lg-stat-value--sm">{{ tracked.vehicle_plate || '—' }}</div></div></v-col>
          <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-stat-label">Last event</div><div class="lg-stat-value lg-stat-value--sm">{{ lastEvent(tracked) }}</div></div></v-col>
          <v-col cols="6" md="3"><div class="lg-stat"><div class="lg-stat-label">Updated</div><div class="lg-stat-value lg-stat-value--sm">{{ rel(tracked.updated_at) }}</div></div></v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- list -->
    <v-row dense>
      <v-col v-for="s in visibleRows" :key="s.id" cols="12" md="6" xl="4">
        <v-card rounded="xl" border class="lg-track-card h-100" @click="focus(s)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <div class="lg-track-icon" :class="`lg-track--${s.status}`">
                <v-icon size="19">{{ statusOf(s.status).icon }}</v-icon>
              </div>
              <div>
                <div class="lg-track-ref">{{ s.reference }}</div>
                <div class="text-caption text-medium-emphasis">{{ s.tracking_number }}</div>
              </div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="statusOf(s.status).color" class="font-weight-bold">{{ statusOf(s.status).label }}</v-chip>
          </div>

          <div class="mt-3">
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-caption text-truncate" style="max-width:45%">{{ s.origin_name || '—' }}</span>
              <v-icon size="12" color="medium-emphasis">mdi-arrow-right</v-icon>
              <span class="text-caption text-truncate" style="max-width:45%">{{ s.dest_name || '—' }}</span>
            </div>
            <v-progress-linear :model-value="statusOf(s.status).pct" height="7" rounded :color="statusOf(s.status).color" bg-color="surface-variant" />
          </div>

          <div class="d-flex align-center justify-space-between mt-2">
            <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
              <v-icon size="13">{{ s.driver_name ? 'mdi-account-check-outline' : 'mdi-account-question-outline' }}</v-icon>
              {{ s.driver_name || 'Unassigned' }}
            </span>
            <span class="text-caption" :class="s.is_late ? 'text-error font-weight-medium' : 'text-medium-emphasis'">
              {{ s.is_late ? 'Late' : rel(s.updated_at) }}
            </span>
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!visibleRows.length" cols="12">
        <v-card rounded="xl" border>
          <div class="lg-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-crosshairs-gps</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">Nothing to track</div>
            <div class="text-caption text-medium-emphasis">No shipments are currently on the road.</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3200">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { relativeTime, useLogistics } from '~/composables/useLogistics'

definePageMeta({ layout: 'default' })

const L = useLogistics()
const { shipments } = L
const statusOf = L.shipmentStatus
const typeOf = L.movementType

const loading = ref(false)
const tracking = ref(false)
const autoRefresh = ref(false)
const scope = ref('active')
const trackingQuery = ref('')
const rows = ref([])
const tracked = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

let timer = null

const nowMs = ref(Date.now())

const activeStatuses = ['assigned', 'picked_up', 'in_transit', 'out_for_delivery']

const visibleRows = computed(() => {
  if (scope.value === 'all') return rows.value
  return rows.value.filter((s) => activeStatuses.includes(s.status))
})

const facts = computed(() => [
  { value: visibleRows.value.length, label: 'in view' },
  { value: rows.value.filter((s) => s.status === 'in_transit').length, label: 'in transit' },
  { value: rows.value.filter((s) => s.status === 'out_for_delivery').length, label: 'out for delivery' },
  { value: rows.value.filter((s) => s.is_late).length, label: 'late' },
])

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function rel(v) {
  return relativeTime(v, nowMs.value)
}

function progressLabel(s) {
  const meta = statusOf(s.status)
  return meta.label
}

function lastEvent(s) {
  const ev = (s.events || [])[0]
  if (!ev) return 'No events'
  return ev.description || String(ev.event_type || '').replace(/_/g, ' ')
}

async function load() {
  loading.value = true
  try {
    const { data } = await shipments({ page_size: 300, ordering: '-updated_at' })
    rows.value = data?.results || data || []
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load tracking data' }
  } finally {
    loading.value = false
  }
}

async function track() {
  const q = (trackingQuery.value || '').trim()
  if (!q) return
  tracking.value = true
  try {
    const { data } = await shipments({ search: q, page_size: 5 })
    const list = data?.results || data || []
    if (!list.length) {
      tracked.value = null
      snack.value = { show: true, color: 'info', text: 'No shipment matches that number' }
      return
    }
    const { data: full } = await L.shipment(list[0].id)
    tracked.value = full
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Tracking lookup failed' }
  } finally {
    tracking.value = false
  }
}

async function focus(s) {
  trackingQuery.value = s.tracking_number || s.reference
  await track()
}

onMounted(() => {
  load()
  timer = setInterval(() => {
    nowMs.value = Date.now()
    if (autoRefresh.value) load()
  }, 30000)
})

onBeforeUnmount(() => { if (timer) clearInterval(timer) })
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-auto-switch :deep(.v-label) { color: rgba(255, 255, 255, .9) !important; font-size: 12px; }
.lg-search { flex: 1 1 380px; max-width: 560px; }
.lg-tracked-card { border: 2px solid rgba(var(--v-theme-primary), .25) !important; }
.lg-progress-wrap { padding: 4px 0; }
.lg-stat { border: 1px solid rgba(var(--v-border-color), .16); border-radius: 12px; padding: 10px 12px; }
.lg-stat-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-stat-value { font-size: 17px; font-weight: 800; }
.lg-stat-value--sm { font-size: 13px; }
.lg-track-card { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.lg-track-card:hover { box-shadow: 0 8px 22px rgba(0,0,0,.09); transform: translateY(-1px); }
.lg-track-icon { width: 36px; height: 36px; border-radius: 11px; display: flex; align-items: center; justify-content: center; background: rgba(var(--v-theme-primary), .1); color: rgb(var(--v-theme-primary)); }
.lg-track--in_transit { background: rgba(13,148,136,.14); color: #0f766e; }
.lg-track--out_for_delivery { background: rgba(245,158,11,.16); color: #b45309; }
.lg-track--assigned { background: rgba(59,130,246,.14); color: #1d4ed8; }
.lg-track--picked_up { background: rgba(8,145,178,.14); color: #0e7490; }
.lg-track--delivered { background: rgba(16,185,129,.14); color: #0f766e; }
.lg-track--failed { background: rgba(239,68,68,.14); color: #b91c1c; }
.lg-track-ref { font-size: 13.5px; font-weight: 800; }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
