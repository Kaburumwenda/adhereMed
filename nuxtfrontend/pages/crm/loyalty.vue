<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-star-circle-outline"
      eyebrow="IMS · CUSTOMER CRM · LOYALTY"
      title="Loyalty Programme"
      subtitle="Points balance, tier distribution and the full earn/redeem ledger across the customer base."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openAdjust">
          Adjust points
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" flat />
      </v-col>
    </v-row>

    <v-row dense class="mb-2">
      <!-- tiers -->
      <v-col cols="12" lg="5">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="amber-darken-2">mdi-crown-outline</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Tier distribution</div>
              <div class="text-caption text-medium-emphasis">Members by loyalty tier</div>
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="t in tierRows" :key="t.key" class="mb-3">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="d-flex align-center ga-2 text-body-2">
                  <v-icon size="16" :color="t.color">{{ t.icon }}</v-icon>{{ t.label }}
                </span>
                <span class="text-body-2 font-weight-bold">{{ t.count }}</span>
              </div>
              <v-progress-linear :model-value="t.pct" :style="{ color: t.color }" height="7" rounded bg-color="surface-variant" />
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ledger stats -->
      <v-col cols="12" lg="7">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="deep-purple">mdi-swap-vertical-bold</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Points flow</div>
              <div class="text-caption text-medium-emphasis">Earned vs redeemed</div>
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <v-row dense class="mb-3">
              <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Earned</div><div class="crm-stat-value text-success">{{ (stats.points_earned ?? 0).toLocaleString() }}</div></div></v-col>
              <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Redeemed</div><div class="crm-stat-value text-error">{{ (stats.points_redeemed ?? 0).toLocaleString() }}</div></div></v-col>
              <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Net movement</div><div class="crm-stat-value">{{ (stats.net ?? 0).toLocaleString() }}</div></div></v-col>
              <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Outstanding</div><div class="crm-stat-value">{{ (stats.liability_points ?? 0).toLocaleString() }}</div></div></v-col>
            </v-row>
            <v-divider class="mb-3" />
            <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Top point holders</div>
            <div v-for="c in topHolders" :key="c.id" class="d-flex align-center justify-space-between py-1">
              <div class="d-flex align-center ga-2">
                <v-avatar size="26" :color="avatarColor(c.name)" variant="flat" class="text-white" style="font-size: 10px">{{ initials(c.name) }}</v-avatar>
                <span class="text-body-2">{{ c.name }}</span>
                <v-chip size="x-small" variant="tonal" :color="tierMeta(c.loyalty_tier).color">{{ tierMeta(c.loyalty_tier).label }}</v-chip>
              </div>
              <span class="text-body-2 font-weight-bold">{{ (c.loyalty_points || 0).toLocaleString() }}</span>
            </div>
            <div v-if="!topHolders.length" class="text-caption text-medium-emphasis">No loyalty members yet.</div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ledger -->
    <v-card rounded="xl" border>
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <div class="text-subtitle-1 font-weight-bold">Points ledger</div>
        <v-spacer />
        <v-select v-model="kindFilter" :items="kindOptions" item-title="label" item-value="value" label="Kind" density="compact" variant="outlined" rounded="lg" hide-details clearable class="crm-select" @update:model-value="load" />
      </div>
      <v-divider />
      <v-table density="comfortable" class="crm-table">
        <thead><tr><th>Date</th><th>Customer</th><th>Kind</th><th>Reason</th><th class="text-right">Points</th><th class="text-right">Balance</th></tr></thead>
        <tbody>
          <tr v-for="p in rows" :key="p.id">
            <td class="text-caption">{{ dt(p.created_at) }}</td>
            <td>{{ p.customer_name }}</td>
            <td><v-chip size="x-small" variant="tonal" :color="p.points > 0 ? 'success' : 'error'">{{ titleCase(p.kind) }}</v-chip></td>
            <td class="text-caption">{{ p.reason || '—' }}</td>
            <td class="text-right font-weight-medium" :class="p.points > 0 ? 'text-success' : 'text-error'">{{ p.points > 0 ? '+' : '' }}{{ p.points }}</td>
            <td class="text-right">{{ p.balance_after }}</td>
          </tr>
          <tr v-if="!rows.length"><td colspan="6"><div class="crm-empty pa-6"><v-icon size="40" color="medium-emphasis">mdi-star-circle-outline</v-icon><div class="text-body-2 font-weight-medium mt-2">No points activity</div></div></td></tr>
        </tbody>
      </v-table>
    </v-card>

    <v-dialog v-model="adjustDialog" max-width="460">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-star-circle-outline"
          title="Adjust loyalty points"
          subtitle="Earn, redeem or correct a balance"
          @close="adjustDialog = false"
        />
        <v-card-text>
          <v-select v-model="form.customer" :items="customerOptions" item-title="label" item-value="id" label="Customer *" variant="outlined" density="comfortable" class="mb-2" />
          <v-select v-model="form.kind" :items="kindOptions" item-title="label" item-value="value" label="Kind" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model.number="form.points" type="number" label="Points (negative to deduct)" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="form.reason" label="Reason" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="adjustDialog = false">Cancel</v-btn>
          <v-btn color="deep-purple" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveAdjust">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { avatarColor, initials, tierMeta, useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { points, pointsStats, customers, leaderboard, customerStats, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const rows = ref([])
const stats = ref({})
const customerStatsData = ref({})
const topHolders = ref([])
const kindFilter = ref(null)
const customerOptions = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const adjustDialog = ref(false)
const form = reactive({ customer: null, kind: 'bonus', points: 0, reason: '' })

const kindOptions = [
  { value: 'earn', label: 'Earned' }, { value: 'redeem', label: 'Redeemed' },
  { value: 'bonus', label: 'Bonus' }, { value: 'adjust', label: 'Adjustment' },
  { value: 'expire', label: 'Expired' },
]

const heroFacts = computed(() => [
  { value: (stats.value.points_earned ?? 0).toLocaleString(), label: 'points earned' },
  { value: (stats.value.points_redeemed ?? 0).toLocaleString(), label: 'redeemed' },
  { value: (stats.value.liability_points ?? 0).toLocaleString(), label: 'outstanding' },
  { value: stats.value.total_entries ?? 0, label: 'ledger entries' },
])

const kpis = computed(() => [
  { title: 'Outstanding', value: (stats.value.liability_points ?? 0).toLocaleString(), sub: 'point liability', icon: 'mdi-star-circle-outline', color: 'deep-purple' },
  { title: 'Earned', value: (stats.value.points_earned ?? 0).toLocaleString(), sub: 'all time', icon: 'mdi-plus-circle-outline', color: 'success' },
  { title: 'Redeemed', value: (stats.value.points_redeemed ?? 0).toLocaleString(), sub: 'all time', icon: 'mdi-minus-circle-outline', color: 'error' },
  { title: 'Net movement', value: (stats.value.net ?? 0).toLocaleString(), sub: 'earned − redeemed', icon: 'mdi-swap-vertical-bold', color: 'primary' },
  { title: 'Platinum', value: (customerStatsData.value.by_tier?.platinum ?? 0), sub: 'top tier members', icon: 'mdi-crown-outline', color: 'amber' },
  { title: 'Ledger entries', value: stats.value.total_entries ?? 0, sub: 'records', icon: 'mdi-format-list-bulleted', color: 'teal' },
])

const tierRows = computed(() => {
  const by = customerStatsData.value.by_tier || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0) || 1
  return ['bronze', 'silver', 'gold', 'platinum'].map((k) => ({
    key: k, ...tierMeta(k), count: by[k] || 0, pct: Math.round(((by[k] || 0) / total) * 100),
  }))
})

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 300, ordering: '-created_at' }
    if (kindFilter.value) params.kind = kindFilter.value
    const [list, st, cs, lead] = await Promise.all([
      points(params), pointsStats(), customerStats(), leaderboard(6),
    ])
    rows.value = unpack(list)
    stats.value = st.data || {}
    customerStatsData.value = cs.data || {}
    topHolders.value = lead.data || []
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load loyalty data' }
  } finally {
    loading.value = false
  }
}

async function openAdjust() {
  adjustDialog.value = true
  if (customerOptions.value.length) return
  try {
    const { data } = await customers({ page_size: 300 })
    customerOptions.value = (data?.results || data || []).map((c) => ({ ...c, label: `${c.name} · ${c.phone}` }))
  } catch { /* optional */ }
}

async function saveAdjust() {
  if (!form.customer || !form.points) {
    snack.value = { show: true, color: 'error', text: 'Customer and non-zero points are required' }
    return
  }
  saving.value = true
  try {
    await $api.post('/crm/points/', {
      customer: form.customer, kind: form.kind, points: Number(form.points), reason: form.reason,
    })
    adjustDialog.value = false
    form.points = 0
    form.reason = ''
    snack.value = { show: true, color: 'success', text: 'Points adjusted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to adjust points' }
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-select { width: 160px; }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-stat { border: 1px solid rgba(var(--v-border-color), .16); border-radius: 12px; padding: 10px 12px; }
.crm-stat-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-stat-value { font-size: 17px; font-weight: 800; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
