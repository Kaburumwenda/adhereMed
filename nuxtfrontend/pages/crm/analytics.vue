<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-chart-box-outline"
      eyebrow="IMS · CUSTOMER CRM · ANALYTICS"
      title="CRM Analytics"
      subtitle="Retention, value, service quality and marketing return — all computed from live CRM data."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-glass" prepend-icon="mdi-file-delimited-outline" @click="exportCsv">
          Export
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense>
      <!-- lifecycle -->
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Lifecycle distribution</div>
            <div class="text-caption text-medium-emphasis">Customer base by stage</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="r in lifecycleRows" :key="r.key" class="crm-bar-row">
              <div class="crm-bar-label"><v-icon size="14" :color="r.color">{{ r.icon }}</v-icon>{{ r.label }}</div>
              <div class="crm-bar-track"><div class="crm-bar-fill" :style="{ width: r.pct + '%', background: r.hex }" /></div>
              <div class="crm-bar-count">{{ r.count }}</div>
              <div class="crm-bar-pct">{{ r.share }}%</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- tiers -->
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Loyalty tiers</div>
            <div class="text-caption text-medium-emphasis">Spread across the programme</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="r in tierRows" :key="r.key" class="crm-bar-row">
              <div class="crm-bar-label"><v-icon size="14" :style="{ color: r.color }">{{ r.icon }}</v-icon>{{ r.label }}</div>
              <div class="crm-bar-track"><div class="crm-bar-fill" :style="{ width: r.pct + '%', background: r.color }" /></div>
              <div class="crm-bar-count">{{ r.count }}</div>
              <div class="crm-bar-pct">{{ r.share }}%</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- pipeline -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Pipeline health</div>
            <div class="text-caption text-medium-emphasis">Deal stages and value</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-big">{{ formatMoney(oppStats.pipeline_value || 0) }}</div>
            <div class="text-caption text-medium-emphasis mb-3">open pipeline value</div>
            <div v-for="r in stageRows" :key="r.key" class="mb-2">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span>{{ r.label }}</span><span class="font-weight-medium">{{ r.count }} · {{ formatMoney(r.value) }}</span>
              </div>
              <v-progress-linear :model-value="r.pct" :color="r.color" height="6" rounded bg-color="surface-variant" />
            </div>
            <v-divider class="my-3" />
            <div class="crm-kv"><span>Win rate</span><strong>{{ oppStats.win_rate ?? 0 }}%</strong></div>
            <div class="crm-kv"><span>Weighted value</span><strong>{{ formatMoney(oppStats.expected_value || 0) }}</strong></div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- service quality -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Service quality</div>
            <div class="text-caption text-medium-emphasis">Support performance</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-quality-grid mb-3">
              <div class="crm-quality crm-q--good"><div class="crm-q-n">{{ ticketStats.resolved ?? 0 }}</div><div class="crm-q-l">resolved</div></div>
              <div class="crm-quality crm-q--bad"><div class="crm-q-n">{{ ticketStats.open ?? 0 }}</div><div class="crm-q-l">open</div></div>
              <div class="crm-quality crm-q--warn"><div class="crm-q-n">{{ ticketStats.overdue ?? 0 }}</div><div class="crm-q-l">SLA breached</div></div>
              <div class="crm-quality crm-q--info"><div class="crm-q-n">{{ ticketStats.avg_resolution_hours ?? 0 }}h</div><div class="crm-q-l">avg resolution</div></div>
            </div>
            <v-divider class="mb-3" />
            <div class="crm-kv"><span>NPS</span><strong :class="(feedbackStats.nps || 0) >= 0 ? 'text-success' : 'text-error'">{{ feedbackStats.nps ?? 0 }}</strong></div>
            <div class="crm-kv"><span>CSAT</span><strong>{{ feedbackStats.csat ?? 0 }} / 5</strong></div>
            <div class="crm-kv"><span>Unhandled feedback</span><strong>{{ feedbackStats.unhandled ?? 0 }}</strong></div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- marketing -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Marketing return</div>
            <div class="text-caption text-medium-emphasis">Campaign performance</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-big">{{ formatMoney(campaignStats.revenue || 0) }}</div>
            <div class="text-caption text-medium-emphasis mb-3">attributed revenue</div>
            <div class="crm-kv"><span>Budget</span><strong>{{ formatMoney(campaignStats.budget || 0) }}</strong></div>
            <div class="crm-kv"><span>Spend</span><strong>{{ formatMoney(campaignStats.spend || 0) }}</strong></div>
            <div class="crm-kv"><span>Sent</span><strong>{{ (campaignStats.sent ?? 0).toLocaleString() }}</strong></div>
            <div class="crm-kv"><span>Converted</span><strong>{{ campaignStats.converted ?? 0 }}</strong></div>
            <div class="crm-kv"><span>Conversion rate</span><strong>{{ campaignStats.conversion_rate ?? 0 }}%</strong></div>
            <div class="mt-3">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span>Spend vs revenue</span><span class="font-weight-medium">{{ roiLabel }}</span>
              </div>
              <v-progress-linear :model-value="roiBar" :color="roiBar >= 50 ? 'success' : 'amber'" height="8" rounded bg-color="surface-variant" />
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- top customers -->
      <v-col cols="12">
        <v-card rounded="xl" border>
          <div class="pa-4 pb-2 d-flex align-center justify-space-between">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Highest-value customers</div>
              <div class="text-caption text-medium-emphasis">By lifetime spend — protect and grow these relationships</div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/crm/customers" append-icon="mdi-arrow-right">All customers</v-btn>
          </div>
          <v-divider />
          <v-table density="comfortable" class="crm-table">
            <thead><tr><th>#</th><th>Customer</th><th>Tier</th><th class="text-right">Visits</th><th class="text-right">Spend</th><th class="text-right">Points</th><th>Lifecycle</th></tr></thead>
            <tbody>
              <tr v-for="(c, i) in leaders" :key="c.id" class="crm-row" @click="goCustomer(c.id)">
                <td class="text-medium-emphasis">{{ i + 1 }}</td>
                <td>
                  <div class="d-flex align-center ga-2">
                    <v-avatar size="28" :color="avatarColor(c.name)" variant="flat" class="text-white" style="font-size: 11px">{{ initials(c.name) }}</v-avatar>
                    <div>
                      <div class="font-weight-medium">{{ c.name }}</div>
                      <div class="text-caption text-medium-emphasis">{{ c.phone }}</div>
                    </div>
                  </div>
                </td>
                <td><v-chip size="x-small" variant="tonal" :color="tierMeta(c.loyalty_tier).color">{{ tierMeta(c.loyalty_tier).label }}</v-chip></td>
                <td class="text-right">{{ c.visit_count }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(c.total_purchases) }}</td>
                <td class="text-right">{{ (c.loyalty_points || 0).toLocaleString() }}</td>
                <td><v-chip size="x-small" variant="tonal" :color="lifecycleMeta(c.lifecycle_stage).color">{{ lifecycleMeta(c.lifecycle_stage).label }}</v-chip></td>
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
import {
  avatarColor, initials, lifecycleMeta, stageMeta, tierMeta, useCrm,
} from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const {
  customerStats, leaderboard, opportunityStats,
  ticketStats: fetchTicketStats, feedbackStats: fetchFeedbackStats,
  campaignStats: fetchCampaignStats,
} = useCrm()

const loading = ref(false)
const stats = ref({})
const leaders = ref([])
const oppStatsData = ref({})
const ticketStatsData = ref({})
const feedbackStatsData = ref({})
const campaignStatsData = ref({})
const snack = reactive({ show: false, color: 'success', text: '' })

const oppStats = computed(() => oppStatsData.value || {})
const ticketStats = computed(() => ticketStatsData.value || {})
const feedbackStats = computed(() => feedbackStatsData.value || {})
const campaignStats = computed(() => campaignStatsData.value || {})

const hexByLifecycle = {
  lead: '#6b7280', prospect: '#2563eb', active: '#16a34a',
  at_risk: '#d97706', dormant: '#64748b', churned: '#dc2626',
}

const heroFacts = computed(() => [
  { value: stats.value.total_customers ?? 0, label: 'customers' },
  { value: formatMoney(stats.value.lifetime_value || 0), label: 'lifetime value' },
  { value: stats.value.avg_health ?? 0, label: 'avg health' },
  { value: `${Math.round(100 - (stats.value.avg_health || 0))}%`, label: 'churn exposure' },
])

const kpis = computed(() => [
  { title: 'Customers', value: stats.value.total_customers ?? 0, sub: `${stats.value.new_30_days ?? 0} new (30d)`, icon: 'mdi-account-multiple-outline', color: 'primary' },
  { title: 'Lifetime value', value: formatMoney(stats.value.lifetime_value || 0), sub: 'all-time spend', icon: 'mdi-cash-multiple', color: 'success' },
  { title: 'Avg health', value: stats.value.avg_health ?? 0, sub: 'out of 100', icon: 'mdi-heart-pulse', color: 'teal' },
  { title: 'At risk', value: stats.value.at_risk ?? 0, sub: 'churn ≥ 60%', icon: 'mdi-account-alert-outline', color: 'error' },
  { title: 'Pipeline', value: formatMoney(stats.value.pipeline_value || 0), sub: 'open deals', icon: 'mdi-chart-timeline-variant-shimmer', color: 'info' },
  { title: 'NPS', value: feedbackStats.value.nps ?? 0, sub: 'net promoter score', icon: 'mdi-gauge', color: 'deep-purple' },
])

const lifecycleRows = computed(() => {
  const by = stats.value.by_lifecycle || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0) || 1
  return ['lead', 'prospect', 'active', 'at_risk', 'dormant', 'churned'].map((key) => {
    const meta = lifecycleMeta(key)
    const count = by[key] || 0
    return {
      key, label: meta.label, icon: meta.icon, color: meta.color,
      hex: hexByLifecycle[key], count, share: Math.round((count / total) * 100),
      pct: Math.max(1, Math.round((count / total) * 100)),
    }
  })
})

const tierRows = computed(() => {
  const by = stats.value.by_tier || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0) || 1
  return ['bronze', 'silver', 'gold', 'platinum'].map((key) => {
    const meta = tierMeta(key)
    const count = by[key] || 0
    return {
      key, label: meta.label, icon: meta.icon, color: meta.color,
      count, share: Math.round((count / total) * 100),
      pct: Math.max(1, Math.round((count / total) * 100)),
    }
  })
})

const stageRows = computed(() => {
  const by = oppStats.value.by_stage || {}
  const max = Math.max(1, ...Object.values(by).map((v) => v.count || 0))
  return ['new', 'qualified', 'proposal', 'negotiation', 'won', 'lost'].map((key) => {
    const meta = stageMeta(key)
    const row = by[key] || { count: 0, value: 0 }
    return {
      key, label: meta.label, color: meta.color,
      count: row.count || 0, value: row.value || 0,
      pct: Math.round(((row.count || 0) / max) * 100),
    }
  })
})

const roiBar = computed(() => {
  const spend = Number(campaignStats.value.spend) || 0
  const revenue = Number(campaignStats.value.revenue) || 0
  if (!spend) return 0
  return Math.min(100, Math.round((revenue / (spend * 4)) * 100))
})

const roiLabel = computed(() => {
  const spend = Number(campaignStats.value.spend) || 0
  const revenue = Number(campaignStats.value.revenue) || 0
  if (!spend) return '—'
  return `${Math.round(((revenue - spend) / spend) * 100)}% ROI`
})

function goCustomer(id) {
  navigateTo(`/ims/crm/customers/${id}`)
}

async function load() {
  loading.value = true
  try {
    const [cs, lead, op, tk, fb, cp] = await Promise.all([
      customerStats(), leaderboard(10), opportunityStats(), fetchTicketStats(), fetchFeedbackStats(), fetchCampaignStats(),
    ])
    stats.value = cs.data || {}
    leaders.value = lead.data || []
    oppStatsData.value = op.data || {}
    ticketStatsData.value = tk.data || {}
    feedbackStatsData.value = fb.data || {}
    campaignStatsData.value = cp.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load analytics' }
  } finally {
    loading.value = false
  }
}

function exportCsv() {
  const lines = ['metric,value']
  for (const [k, v] of Object.entries(stats.value)) {
    if (['by_lifecycle', 'by_tier'].includes(k)) continue
    lines.push(`"${k}","${v}"`)
  }
  for (const r of lifecycleRows.value) lines.push(`"lifecycle:${r.key}","${r.count}"`)
  for (const r of tierRows.value) lines.push(`"tier:${r.key}","${r.count}"`)
  for (const c of leaders.value) lines.push(`"customer:${c.name}","${c.total_purchases}"`)
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `crm_analytics_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-glass { background: rgba(255,255,255,.16) !important; color: #fff !important; font-weight: 600 !important; border: 1px solid rgba(255,255,255,.34) !important; }
.crm-bar-row { display: grid; grid-template-columns: 130px 1fr 44px 44px; align-items: center; gap: 10px; margin-bottom: 10px; }
.crm-bar-label { display: flex; align-items: center; gap: 6px; font-size: 12.5px; }
.crm-bar-track { height: 9px; border-radius: 999px; background: rgba(var(--v-theme-surface-variant), .7); overflow: hidden; }
.crm-bar-fill { height: 100%; border-radius: 999px; transition: width .3s; }
.crm-bar-count { text-align: right; font-size: 12.5px; font-weight: 700; }
.crm-bar-pct { text-align: right; font-size: 11px; color: rgba(var(--v-theme-on-surface), .55); }
.crm-big { font-size: 26px; font-weight: 800; line-height: 1.1; }
.crm-kv { display: flex; align-items: center; justify-content: space-between; padding: 4px 0; font-size: 13px; }
.crm-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.crm-quality-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.crm-quality { border-radius: 12px; padding: 11px 8px; text-align: center; border: 1px solid rgba(var(--v-border-color), .14); }
.crm-q--good { background: rgba(16,185,129,.08); border-color: rgba(16,185,129,.24); }
.crm-q--warn { background: rgba(245,158,11,.08); border-color: rgba(245,158,11,.24); }
.crm-q--bad { background: rgba(239,68,68,.08); border-color: rgba(239,68,68,.24); }
.crm-q--info { background: rgba(59,130,246,.08); border-color: rgba(59,130,246,.24); }
.crm-q-n { font-size: 19px; font-weight: 800; line-height: 1.1; }
.crm-q-l { font-size: 9.5px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-row { cursor: pointer; }
.crm-row:hover { background: rgba(var(--v-theme-primary), .04); }
</style>
