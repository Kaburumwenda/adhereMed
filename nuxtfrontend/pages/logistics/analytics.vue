<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-chart-box-outline"
      eyebrow="IMS · LOGISTICS · ANALYTICS"
      title="Logistics Analytics"
      subtitle="Throughput, cost, punctuality, fleet utilisation and partner performance — computed from live shipment data."
      :facts="facts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-glass" prepend-icon="mdi-file-delimited-outline" @click="exportCsv">
          Export
        </v-btn>
      </template>
    </LogiHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense>
      <v-col cols="12" lg="7">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Shipment volume by status</div>
            <div class="text-caption text-medium-emphasis">Distribution across the delivery lifecycle</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="row in byStatus" :key="row.status" class="lg-bar-row">
              <div class="lg-bar-label">
                <v-icon size="14" :color="row.color">{{ row.icon }}</v-icon>
                {{ row.label }}
              </div>
              <div class="lg-bar-track">
                <div class="lg-bar-fill" :style="{ width: row.pct + '%', background: row.hex }" />
              </div>
              <div class="lg-bar-value">{{ row.count }}</div>
            </div>
            <div v-if="!byStatus.length" class="text-caption text-medium-emphasis">No data yet.</div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="5">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Movement mix</div>
            <div class="text-caption text-medium-emphasis">Where the volume comes from</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="row in byType" :key="row.value" class="lg-mix-row">
              <div class="d-flex align-center ga-2">
                <div class="lg-mix-dot" :style="{ background: row.hex }" />
                <v-icon size="15" :color="row.color">{{ row.icon }}</v-icon>
                <span class="text-body-2">{{ row.label }}</span>
              </div>
              <div class="d-flex align-center ga-3">
                <span class="text-body-2 font-weight-bold">{{ row.count }}</span>
                <span class="text-caption text-medium-emphasis" style="min-width:42px; text-align:right">{{ row.pct }}%</span>
              </div>
            </div>
            <div v-if="!byType.length" class="text-caption text-medium-emphasis">No data yet.</div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Cost breakdown</div>
            <div class="text-caption text-medium-emphasis">Freight, fuel and other charges</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="lg-cost-total">{{ formatMoney(costs.total) }}</div>
            <div class="text-caption text-medium-emphasis mb-3">total logistics cost</div>
            <div v-for="c in costRows" :key="c.key" class="mb-3">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span>{{ c.label }}</span>
                <span class="font-weight-medium">{{ formatMoney(c.value) }}</span>
              </div>
              <v-progress-linear :model-value="c.pct" height="7" rounded :color="c.color" bg-color="surface-variant" />
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Fleet utilisation</div>
            <div class="text-caption text-medium-emphasis">Capacity in use right now</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="lg-util-ring">
              <v-progress-circular
                :model-value="utilPct"
                :size="132"
                :width="13"
                color="teal"
                bg-color="surface-variant"
                rounded
              >
                <div class="text-center">
                  <div class="lg-util-value">{{ utilPct }}%</div>
                  <div class="text-caption text-medium-emphasis">in use</div>
                </div>
              </v-progress-circular>
            </div>
            <div class="lg-kv mt-4"><span>Available vehicles</span><strong>{{ fleet.available ?? 0 }}</strong></div>
            <div class="lg-kv"><span>On the road</span><strong>{{ fleet.in_use ?? 0 }}</strong></div>
            <div class="lg-kv"><span>In maintenance</span><strong>{{ fleet.maintenance ?? 0 }}</strong></div>
            <div class="lg-kv"><span>Drivers available</span><strong>{{ drivers.available ?? 0 }} / {{ drivers.total ?? 0 }}</strong></div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Service quality</div>
            <div class="text-caption text-medium-emphasis">Punctuality and exception rates</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="lg-quality-grid">
              <div class="lg-quality-tile lg-quality--good">
                <div class="lg-quality-value">{{ stats.on_time_pct ?? 0 }}%</div>
                <div class="lg-quality-label">on-time delivery</div>
              </div>
              <div class="lg-quality-tile lg-quality--warn">
                <div class="lg-quality-value">{{ stats.late ?? 0 }}</div>
                <div class="lg-quality-label">past ETA</div>
              </div>
              <div class="lg-quality-tile lg-quality--bad">
                <div class="lg-quality-value">{{ stats.failed ?? 0 }}</div>
                <div class="lg-quality-label">failed deliveries</div>
              </div>
              <div class="lg-quality-tile lg-quality--info">
                <div class="lg-quality-value">{{ stats.delivered_this_month ?? 0 }}</div>
                <div class="lg-quality-label">delivered this month</div>
              </div>
            </div>
            <v-divider class="my-4" />
            <div class="lg-kv"><span>Total distance</span><strong>{{ formatQty(stats.total_distance_km || 0) }} km</strong></div>
            <div class="lg-kv"><span>Cost per km</span><strong>{{ costPerKm }}</strong></div>
            <div class="lg-kv"><span>Open shipments</span><strong>{{ stats.open ?? 0 }}</strong></div>
            <div class="lg-kv"><span>Cold-chain open</span><strong>{{ stats.requires_refrigeration ?? 0 }}</strong></div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12">
        <v-card rounded="xl" border>
          <div class="pa-4 pb-2 d-flex align-center justify-space-between">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Carrier scorecard</div>
              <div class="text-caption text-medium-emphasis">Live ratings and on-time performance</div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/logistics/carriers" append-icon="mdi-arrow-right">Manage</v-btn>
          </div>
          <v-divider />
          <v-table density="comfortable" class="lg-table">
            <thead>
              <tr>
                <th>Carrier</th>
                <th>Service level</th>
                <th>Rate / km</th>
                <th>On-time</th>
                <th>Rating</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="c in carrierRows" :key="c.id">
                <td class="font-weight-medium">{{ c.name }}</td>
                <td>{{ titleCase(c.service_level) }}</td>
                <td>{{ formatMoney(c.rate_per_km) }}</td>
                <td>
                  <div class="d-flex align-center ga-2">
                    <v-progress-linear :model-value="Number(c.on_time_rate || 0)" height="6" rounded color="teal" bg-color="surface-variant" style="max-width: 90px" />
                    <span class="text-caption">{{ Number(c.on_time_rate || 0).toFixed(0) }}%</span>
                  </div>
                </td>
                <td>
                  <span class="d-inline-flex align-center ga-1">
                    <v-icon size="14" color="amber-darken-2">mdi-star</v-icon>
                    {{ Number(c.rating || 0).toFixed(1) }}
                  </span>
                </td>
                <td>
                  <v-chip size="x-small" variant="tonal" :color="c.is_active ? 'success' : 'grey'">
                    {{ c.is_active ? 'Active' : 'Inactive' }}
                  </v-chip>
                </td>
              </tr>
              <tr v-if="!carrierRows.length">
                <td colspan="6" class="text-caption text-medium-emphasis">No carriers registered yet.</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3200">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useLogistics } from '~/composables/useLogistics'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const L = useLogistics()

const loading = ref(false)
const stats = ref({})
const fleet = ref({})
const drivers = ref({})
const carrierRows = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })

const hexByStatus = {
  draft: '#6b7280',
  planned: '#4f46e5',
  assigned: '#2563eb',
  picked_up: '#0891b2',
  in_transit: '#0d9488',
  out_for_delivery: '#d97706',
  delivered: '#16a34a',
  failed: '#dc2626',
  cancelled: '#6b7280',
  returned: '#ea580c',
}

const facts = computed(() => [
  { value: stats.value.total ?? 0, label: 'shipments' },
  { value: `${stats.value.on_time_pct ?? 0}%`, label: 'on time' },
  { value: formatMoney(stats.value.total_cost || 0), label: 'logistics cost' },
  { value: `${formatQty(stats.value.total_distance_km || 0)} km`, label: 'distance' },
])

const kpis = computed(() => [
  { title: 'Total shipments', value: stats.value.total ?? 0, sub: 'all time', icon: 'mdi-truck-fast-outline', color: 'primary' },
  { title: 'Delivered', value: stats.value.delivered ?? 0, sub: `${stats.value.delivered_this_month ?? 0} this month`, icon: 'mdi-check-decagram', color: 'success' },
  { title: 'On-time rate', value: `${stats.value.on_time_pct ?? 0}%`, sub: 'of delivered', icon: 'mdi-clock-check-outline', color: 'teal' },
  { title: 'Exceptions', value: (stats.value.failed ?? 0) + (stats.value.late ?? 0), sub: 'late or failed', icon: 'mdi-alert-circle-outline', color: 'error' },
  { title: 'Cost / km', value: costPerKm.value, sub: 'avg freight', icon: 'mdi-cash-multiple', color: 'deep-purple' },
  { title: 'Fleet in use', value: `${fleet.value.in_use ?? 0}/${fleet.value.total ?? 0}`, sub: 'vehicles', icon: 'mdi-truck-cargo-container', color: 'blue' },
])

const byStatus = computed(() => {
  const rows = stats.value.by_status || []
  const total = rows.reduce((a, r) => a + r.count, 0) || 1
  return rows
    .map((r) => {
      const meta = L.shipmentStatus(r.status)
      return {
        status: r.status,
        label: meta.label,
        icon: meta.icon,
        color: meta.color,
        hex: hexByStatus[r.status] || '#6b7280',
        count: r.count,
        pct: Math.round((r.count / total) * 100),
      }
    })
    .sort((a, b) => b.count - a.count)
})

const byType = computed(() => {
  const rows = stats.value.by_type || []
  const total = rows.reduce((a, r) => a + r.count, 0) || 1
  return rows
    .map((r) => {
      const meta = L.movementType(r.movement_type)
      return {
        value: r.movement_type,
        label: meta.label,
        icon: meta.icon,
        color: meta.color,
        hex: '#0d9488',
        count: r.count,
        pct: Math.round((r.count / total) * 100),
      }
    })
    .sort((a, b) => b.count - a.count)
})

const costs = computed(() => {
  const total = Number(stats.value.total_cost || 0)
  const freight = Number(stats.value.freight_cost || 0)
  const fuel = Number(stats.value.fuel_cost || 0)
  const other = Number(stats.value.other_cost || 0)
  const known = freight + fuel + other
  return { total, freight, fuel, other, known }
})

const costRows = computed(() => {
  const c = costs.value
  const base = c.known || 1
  return [
    { key: 'freight', label: 'Freight', value: c.freight, color: 'primary', pct: Math.round((c.freight / base) * 100) },
    { key: 'fuel', label: 'Fuel', value: c.fuel, color: 'amber', pct: Math.round((c.fuel / base) * 100) },
    { key: 'other', label: 'Other', value: c.other, color: 'teal', pct: Math.round((c.other / base) * 100) },
  ]
})

const utilPct = computed(() => {
  const total = Number(fleet.value.total || 0)
  if (!total) return 0
  return Math.round((Number(fleet.value.in_use || 0) / total) * 100)
})

const costPerKm = computed(() => {
  const km = Number(stats.value.total_distance_km || 0)
  if (!km) return formatMoney(0)
  return formatMoney(Number(stats.value.total_cost || 0) / km)
})

function formatQty(v) {
  return (Number(v) || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

async function load() {
  loading.value = true
  try {
    const [st, vs, ds, cs] = await Promise.all([
      L.shipmentStats(),
      L.vehicleStats(),
      L.driverStats(),
      L.carriers({ page_size: 200, ordering: '-rating' }),
    ])
    stats.value = st.data || {}
    fleet.value = vs.data || {}
    drivers.value = ds.data || {}
    carrierRows.value = cs.data?.results || cs.data || []
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load analytics' }
  } finally {
    loading.value = false
  }
}

function exportCsv() {
  const lines = ['metric,value']
  for (const [k, v] of Object.entries(stats.value)) {
    if (['by_status', 'by_type', 'by_priority'].includes(k)) continue
    lines.push(`"${k}","${v}"`)
  }
  for (const r of byStatus.value) lines.push(`"status:${r.status}","${r.count}"`)
  for (const r of byType.value) lines.push(`"type:${r.value}","${r.count}"`)
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `logistics_analytics_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(load)
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-hero-btn-glass { background: rgba(255,255,255,.16) !important; color: #fff !important; font-weight: 600 !important; border: 1px solid rgba(255,255,255,.34) !important; }
.lg-bar-row { display: grid; grid-template-columns: 150px 1fr 44px; align-items: center; gap: 10px; margin-bottom: 10px; }
.lg-bar-label { display: flex; align-items: center; gap: 6px; font-size: 12.5px; }
.lg-bar-track { height: 9px; border-radius: 999px; background: rgba(var(--v-theme-surface-variant), .7); overflow: hidden; }
.lg-bar-fill { height: 100%; border-radius: 999px; transition: width .3s; }
.lg-bar-value { text-align: right; font-size: 12.5px; font-weight: 700; }
.lg-mix-row { display: flex; align-items: center; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.lg-mix-dot { width: 8px; height: 8px; border-radius: 50%; }
.lg-cost-total { font-size: 26px; font-weight: 800; line-height: 1.1; }
.lg-util-ring { display: flex; justify-content: center; padding: 8px 0 4px; }
.lg-util-value { font-size: 26px; font-weight: 800; line-height: 1.1; }
.lg-kv { display: flex; align-items: center; justify-content: space-between; padding: 5px 0; font-size: 13px; }
.lg-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.lg-quality-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.lg-quality-tile { border-radius: 12px; padding: 12px 10px; text-align: center; border: 1px solid rgba(var(--v-border-color), .14); }
.lg-quality--good { background: rgba(16,185,129,.08); border-color: rgba(16,185,129,.24); }
.lg-quality--warn { background: rgba(245,158,11,.08); border-color: rgba(245,158,11,.24); }
.lg-quality--bad { background: rgba(239,68,68,.08); border-color: rgba(239,68,68,.24); }
.lg-quality--info { background: rgba(59,130,246,.08); border-color: rgba(59,130,246,.24); }
.lg-quality-value { font-size: 21px; font-weight: 800; line-height: 1.1; }
.lg-quality-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.lg-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
</style>
