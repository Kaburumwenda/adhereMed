<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-truck-fast-outline"
      eyebrow="IMS · LOGISTICS · COMMAND CENTER"
      title="Transport & Logistics"
      subtitle="Move stock between warehouses, distribution centres, customers and suppliers — planned, dispatched and tracked end to end."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn
          icon="mdi-refresh"
          variant="text"
          size="small"
          class="lg-hero-iconbtn"
          title="Refresh"
          :loading="loading"
          @click="load"
        />
        <v-btn
          variant="flat"
          elevation="0"
          rounded="lg"
          class="text-none lg-hero-btn-glass"
          prepend-icon="mdi-clipboard-text-outline"
          to="/ims/logistics/dispatch"
        >Dispatch Board</v-btn>
        <v-btn
          variant="flat"
          elevation="0"
          rounded="lg"
          class="text-none lg-hero-btn-strong"
          prepend-icon="mdi-plus"
          to="/ims/logistics/shipments?new=1"
        >New Shipment</v-btn>
      </template>
    </LogiHero>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile
          :title="k.title"
          :value="k.value"
          :sub="k.sub"
          :icon="k.icon"
          :color="k.color"
          :hint="k.hint"
          flat
        />
      </v-col>
    </v-row>

    <!-- Pipeline + alerts -->
    <v-row dense class="mb-2">
      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="lg-panel h-100">
          <div class="d-flex align-center justify-space-between pa-4 pb-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-icon color="primary">mdi-transit-connection-variant</v-icon>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Live shipment pipeline</div>
                <div class="text-caption text-medium-emphasis">Every open movement across the network</div>
              </div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/logistics/shipments" append-icon="mdi-arrow-right">
              All shipments
            </v-btn>
          </div>
          <v-divider />
          <v-card-text class="pt-4">
            <div class="lg-pipeline">
              <div v-for="s in pipeline" :key="s.status" class="lg-pipe-item">
                <div class="d-flex align-center justify-space-between mb-1">
                  <span class="lg-pipe-label">
                    <v-icon size="15" :color="s.color">{{ s.icon }}</v-icon>
                    {{ s.label }}
                  </span>
                  <span class="lg-pipe-count">{{ s.count }}</span>
                </div>
                <v-progress-linear
                  :model-value="s.pct"
                  :color="s.color"
                  height="7"
                  rounded
                  bg-color="surface-variant"
                />
              </div>
            </div>

            <v-divider class="my-4" />

            <div class="text-caption text-uppercase text-medium-emphasis font-weight-bold mb-2">Open by movement</div>
            <div class="d-flex flex-wrap ga-2">
              <v-chip
                v-for="m in openByType"
                :key="m.value"
                size="small"
                variant="tonal"
                :color="m.color"
                rounded="lg"
                class="text-none"
              >
                <v-icon start size="14">{{ m.icon }}</v-icon>
                {{ m.label }}
                <span class="ml-1 font-weight-bold">{{ m.count }}</span>
              </v-chip>
              <div v-if="!openByType.length" class="text-caption text-medium-emphasis">
                No open movements yet.
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="error">mdi-alert-decagram-outline</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Needs attention</div>
              <div class="text-caption text-medium-emphasis">{{ attention.length }} item(s) flagged</div>
            </div>
          </div>
          <v-divider />
          <v-card-text class="pt-3">
            <div v-if="!attention.length" class="lg-empty">
              <v-icon size="38" color="success">mdi-check-decagram</v-icon>
              <div class="text-body-2 font-weight-medium mt-2">Everything is on track</div>
              <div class="text-caption text-medium-emphasis">No late, urgent or compliance issues.</div>
            </div>
            <div v-else class="lg-attention">
              <div
                v-for="a in attention"
                :key="a.key"
                class="lg-attention-row"
                :class="`lg-attention--${a.tone}`"
              >
                <v-icon size="18" :color="a.tone === 'error' ? 'error' : a.tone === 'warning' ? 'amber' : 'primary'">
                  {{ a.icon }}
                </v-icon>
                <div class="flex-grow-1">
                  <div class="text-body-2 font-weight-medium">{{ a.title }}</div>
                  <div class="text-caption text-medium-emphasis">{{ a.detail }}</div>
                </div>
                <v-btn
                  v-if="a.to"
                  :to="a.to"
                  size="x-small"
                  variant="text"
                  class="text-none"
                  :color="a.tone === 'error' ? 'error' : 'primary'"
                >Open</v-btn>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Recent shipments + fleet snapshot -->
    <v-row dense>
      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center justify-space-between pa-4 pb-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-icon color="primary">mdi-truck-delivery-outline</v-icon>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Latest shipments</div>
                <div class="text-caption text-medium-emphasis">Most recent movements in the network</div>
              </div>
            </div>
            <v-btn icon="mdi-refresh" size="small" variant="text" :loading="loading" @click="load" />
          </div>
          <v-divider />
          <div v-if="!recentShipments.length" class="lg-empty pa-6">
            <v-icon size="42" color="medium-emphasis">mdi-truck-outline</v-icon>
            <div class="text-body-2 font-weight-medium mt-2">No shipments yet</div>
            <div class="text-caption text-medium-emphasis">Create your first shipment to start tracking movements.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" to="/ims/logistics/shipments?new=1">
              Create shipment
            </v-btn>
          </div>
          <v-table v-else density="comfortable" class="lg-table">
            <thead>
              <tr>
                <th>Reference</th>
                <th>Route</th>
                <th>Driver / carrier</th>
                <th>Status</th>
                <th class="text-right">ETA</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in recentShipments" :key="s.id" class="lg-row" @click="goToShipment(s)">
                <td>
                  <div class="font-weight-medium">{{ s.reference }}</div>
                  <div class="text-caption text-medium-emphasis">{{ typeOf(s.movement_type).label }}</div>
                </td>
                <td>
                  <div class="d-flex align-center ga-1 text-body-2">
                    <span class="text-truncate" style="max-width:150px">{{ s.origin_name || '—' }}</span>
                    <v-icon size="13" color="medium-emphasis">mdi-arrow-right</v-icon>
                    <span class="text-truncate" style="max-width:150px">{{ s.dest_name || '—' }}</span>
                  </div>
                </td>
                <td>
                  <div class="text-body-2">{{ s.driver_name || s.carrier_name || 'Unassigned' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ s.vehicle_plate || '—' }}</div>
                </td>
                <td>
                  <v-chip size="x-small" :color="statusOf(s.status).color" variant="tonal" class="font-weight-medium">
                    <v-icon start size="12">{{ statusOf(s.status).icon }}</v-icon>
                    {{ statusOf(s.status).label }}
                  </v-chip>
                </td>
                <td class="text-right">
                  <div class="text-body-2" :class="s.is_late ? 'text-error font-weight-medium' : ''">
                    {{ etaLabel(s) }}
                  </div>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="primary">mdi-truck-cargo-container</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Fleet snapshot</div>
              <div class="text-caption text-medium-emphasis">Capacity ready to move</div>
            </div>
          </div>
          <v-divider />
          <v-card-text class="pt-4">
            <div class="lg-fleet-grid mb-4">
              <div class="lg-fleet-tile lg-fleet--ok">
                <div class="lg-fleet-value">{{ fleet.available }}</div>
                <div class="lg-fleet-label">vehicles ready</div>
              </div>
              <div class="lg-fleet-tile lg-fleet--busy">
                <div class="lg-fleet-value">{{ fleet.in_use }}</div>
                <div class="lg-fleet-label">on the road</div>
              </div>
              <div class="lg-fleet-tile lg-fleet--warn">
                <div class="lg-fleet-value">{{ fleet.maintenance }}</div>
                <div class="lg-fleet-label">in service</div>
              </div>
            </div>

            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-caption text-medium-emphasis">Drivers available</span>
              <span class="text-body-2 font-weight-bold">{{ drivers.available }} / {{ drivers.total }}</span>
            </div>
            <v-progress-linear
              :model-value="driverReadiness"
              color="teal"
              height="8"
              rounded
              bg-color="surface-variant"
            />

            <v-divider class="my-4" />

            <div class="d-flex align-center justify-space-between mb-2">
              <span class="text-caption text-medium-emphasis">Carrier partners</span>
              <span class="text-body-2 font-weight-bold">{{ carriers.active }}</span>
            </div>
            <div class="d-flex align-center justify-space-between mb-2">
              <span class="text-caption text-medium-emphasis">Open freight value</span>
              <span class="text-body-2 font-weight-bold">{{ formatMoney(stats.total_cost) }}</span>
            </div>
            <div class="d-flex align-center justify-space-between">
              <span class="text-caption text-medium-emphasis">Distance planned</span>
              <span class="text-body-2 font-weight-bold">{{ formatQty(stats.total_distance_km) }} km</span>
            </div>

            <v-btn
              block
              variant="tonal"
              color="primary"
              rounded="lg"
              class="text-none mt-4"
              prepend-icon="mdi-arrow-right-circle-outline"
              to="/ims/logistics/fleet"
            >Manage fleet</v-btn>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const {
  shipmentStats, shipments, vehicleStats, driverStats, carrierStats,
  shipmentStatus, movementType,
} = useLogistics()

const loading = ref(false)
const stats = ref({})
const fleet = ref({ available: 0, in_use: 0, maintenance: 0, total: 0 })
const drivers = ref({ available: 0, total: 0 })
const carriers = ref({ active: 0 })
const openRows = ref([])
const recentShipments = ref([])
const compliance = ref({ vehicles: [], drivers: [] })
const snack = reactive({ show: false, color: 'success', text: '' })

const statusOf = shipmentStatus
const typeOf = movementType

const heroFacts = computed(() => [
  { value: stats.value.open ?? 0, label: 'open shipments' },
  { value: stats.value.in_transit ?? 0, label: 'in transit' },
  { value: stats.value.late ?? 0, label: 'past ETA' },
  { value: fleet.value.available ?? 0, label: 'vehicles ready' },
])

const kpis = computed(() => [
  {
    title: 'Open shipments',
    value: stats.value.open ?? 0,
    sub: `${stats.value.unassigned ?? 0} unassigned`,
    icon: 'mdi-truck-fast-outline',
    color: 'primary',
    hint: 'Not yet delivered',
  },
  {
    title: 'Delivered this month',
    value: stats.value.delivered_this_month ?? 0,
    sub: `${stats.value.on_time_pct ?? 0}% on time`,
    icon: 'mdi-check-decagram',
    color: 'success',
    hint: 'Proof of delivery captured',
  },
  {
    title: 'Past ETA',
    value: stats.value.late ?? 0,
    sub: 'need follow-up',
    icon: 'mdi-clock-alert-outline',
    color: 'error',
    hint: 'Scheduled delivery missed',
  },
  {
    title: 'Urgent',
    value: stats.value.urgent ?? 0,
    sub: 'priority movements',
    icon: 'mdi-alert-decagram',
    color: 'amber',
    hint: 'Escalate before dispatch',
  },
  {
    title: 'Cold chain',
    value: stats.value.requires_refrigeration ?? 0,
    sub: 'temperature controlled',
    icon: 'mdi-snowflake',
    color: 'info',
    hint: 'Requires refrigerated vehicle',
  },
  {
    title: 'Freight spend',
    value: formatMoney(stats.value.total_cost || 0),
    sub: `${formatQty(stats.value.total_distance_km || 0)} km planned`,
    icon: 'mdi-cash-multiple',
    color: 'deep-purple',
    hint: 'All shipments to date',
  },
])

const driverReadiness = computed(() => {
  const total = drivers.value.total || 0
  if (!total) return 0
  return Math.round(((drivers.value.available || 0) / total) * 100)
})

const pipeline = computed(() => {
  const byStatus = {}
  for (const row of stats.value.by_status || []) byStatus[row.status] = row.count
  return ['planned', 'assigned', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered'].map((s) => {
    const meta = shipmentStatus(s)
    return { status: s, label: meta.label, icon: meta.icon, color: meta.color, pct: meta.pct, count: byStatus[s] || 0 }
  })
})

const openByType = computed(() => {
  const byStatus = {}
  for (const row of stats.value.by_status || []) byStatus[row.status] = row.count
  const byType = {}
  for (const row of stats.value.by_type || []) byType[row.movement_type] = row.count
  return Object.entries(byType)
    .filter(([key]) => key !== 'transfer' || true)
    .map(([key, count]) => {
      const meta = movementType(key)
      return { value: key, label: meta.label, icon: meta.icon, color: meta.color, count }
    })
    .sort((a, b) => b.count - a.count)
})

const attention = computed(() => {
  const list = []
  if (stats.value.late) {
    list.push({
      key: 'late',
      tone: 'error',
      icon: 'mdi-clock-alert-outline',
      title: `${stats.value.late} shipment(s) past ETA`,
      detail: 'Follow up with the driver or carrier immediately.',
      to: '/ims/logistics/shipments?status=in_transit',
    })
  }
  if (stats.value.urgent) {
    list.push({
      key: 'urgent',
      tone: 'warning',
      icon: 'mdi-alert-decagram',
      title: `${stats.value.urgent} urgent movement(s)`,
      detail: 'Prioritise dispatch and confirm capacity.',
      to: '/ims/logistics/dispatch',
    })
  }
  if (stats.value.unassigned) {
    list.push({
      key: 'unassigned',
      tone: 'info',
      icon: 'mdi-account-question-outline',
      title: `${stats.value.unassigned} shipment(s) without a driver`,
      detail: 'Assign a driver or carrier before dispatch.',
      to: '/ims/logistics/dispatch',
    })
  }
  const expVehicles = (compliance.value.vehicles || []).length
  if (expVehicles) {
    list.push({
      key: 'veh',
      tone: 'warning',
      icon: 'mdi-shield-alert-outline',
      title: `${expVehicles} vehicle document(s) expiring`,
      detail: 'Insurance or inspection due within 30 days.',
      to: '/ims/logistics/fleet',
    })
  }
  const expDrivers = (compliance.value.drivers || []).length
  if (expDrivers) {
    list.push({
      key: 'drv',
      tone: 'warning',
      icon: 'mdi-card-account-details-outline',
      title: `${expDrivers} driver licence(s) expiring`,
      detail: 'Renew before the next dispatch.',
      to: '/ims/logistics/drivers',
    })
  }
  return list
})

function formatQty(v) {
  const n = Number(v) || 0
  return n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function etaLabel(s) {
  if (s.status === 'delivered' && s.actual_delivery) return 'Delivered'
  if (!s.scheduled_delivery) return '—'
  const t = new Date(s.scheduled_delivery)
  return t.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function goToShipment(s) {
  navigateTo(`/ims/logistics/shipments?focus=${s.id}`)
}

async function load() {
  loading.value = true
  try {
    const [st, list, vs, ds, cs, comp] = await Promise.all([
      shipmentStats({ page_size: 1 }),
      shipments({ page_size: 8, ordering: '-created_at' }),
      vehicleStats(),
      driverStats(),
      carrierStats(),
      $api.get('/logistics/shipments/expiring/').catch(() => ({ data: { vehicles: [], drivers: [] } })),
    ])
    stats.value = st.data || {}
    const rows = list.data?.results || list.data || []
    recentShipments.value = rows
    openRows.value = rows.filter((r) => !['delivered', 'cancelled', 'returned'].includes(r.status))
    fleet.value = vs.data || fleet.value
    drivers.value = ds.data || drivers.value
    carriers.value = cs.data || carriers.value
    compliance.value = comp.data || { vehicles: [], drivers: [] }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load logistics dashboard' }
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.lg-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.lg-hero-btn-glass:hover { background: rgba(255, 255, 255, 0.26) !important; }
.lg-panel { background: rgb(var(--v-theme-surface)); }
.lg-pipeline { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 14px; }
.lg-pipe-item { display: flex; flex-direction: column; }
.lg-pipe-label { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; }
.lg-pipe-count { font-size: 13px; font-weight: 800; }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
.lg-attention { display: flex; flex-direction: column; gap: 8px; }
.lg-attention-row {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 10px 12px; border-radius: 12px;
  border: 1px solid rgba(var(--v-border-color), 0.14);
  background: rgba(var(--v-theme-surface), 0.6);
}
.lg-attention--error { border-color: rgba(239, 68, 68, 0.28); background: rgba(239, 68, 68, 0.05); }
.lg-attention--warning { border-color: rgba(245, 158, 11, 0.28); background: rgba(245, 158, 11, 0.05); }
.lg-fleet-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.lg-fleet-tile {
  border-radius: 12px; padding: 10px 8px; text-align: center;
  border: 1px solid rgba(var(--v-border-color), 0.14);
}
.lg-fleet--ok { background: rgba(16, 185, 129, 0.08); border-color: rgba(16, 185, 129, 0.24); }
.lg-fleet--busy { background: rgba(59, 130, 246, 0.08); border-color: rgba(59, 130, 246, 0.24); }
.lg-fleet--warn { background: rgba(245, 158, 11, 0.08); border-color: rgba(245, 158, 11, 0.24); }
.lg-fleet-value { font-size: 20px; font-weight: 800; line-height: 1.1; }
.lg-fleet-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.4px; color: rgba(var(--v-theme-on-surface), 0.6); }
.lg-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: 0.4px; }
.lg-row { cursor: pointer; }
.lg-row:hover { background: rgba(var(--v-theme-primary), 0.04); }
</style>
