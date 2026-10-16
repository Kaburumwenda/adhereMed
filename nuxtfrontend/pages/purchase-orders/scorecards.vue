<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Supplier Scorecards"
      subtitle="Composite vendor performance from delivery, fill rate, lead time and formal evaluations"
      eyebrow="PROCUREMENT · SUPPLIER MANAGEMENT"
      icon="mdi-trophy-outline"
      color="teal"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn color="teal" rounded="lg" class="text-none" prepend-icon="mdi-star-plus-outline"
               @click="openEvaluation()">New evaluation</v-btn>
      </template>
    </ProcToolbar>

    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3" xl="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- Evaluation dimensions -->
    <v-row class="mt-1">
      <v-col cols="12" lg="4">
        <BiPanel title="Evaluation profile" subtitle="Average score across all recorded evaluations" icon="mdi-chart-radar" color="teal">
          <EmptyState v-if="!dimensions.length" icon="mdi-star-off-outline" title="No evaluations recorded"
                      message="Score a supplier to build the performance profile." />
          <template v-else>
            <div v-for="d in dimensions" :key="d.key" class="mb-3">
              <div class="d-flex align-center justify-space-between mb-1">
                <div class="d-flex align-center">
                  <v-icon size="16" color="teal" class="mr-1">{{ d.icon }}</v-icon>
                  <span class="text-body-2">{{ d.label }}</span>
                </div>
                <span class="text-body-2 font-weight-bold">{{ d.avg }} / 5</span>
              </div>
              <v-progress-linear :model-value="d.pct" :color="ratingColor(d.avg)" height="7" rounded />
            </div>
            <v-divider class="my-3" />
            <div class="d-flex justify-space-between text-body-2">
              <span class="text-medium-emphasis">Evaluations recorded</span>
              <span class="font-weight-medium">{{ evaluationRows.length }}</span>
            </div>
            <div class="d-flex justify-space-between text-body-2">
              <span class="text-medium-emphasis">Suppliers assessed</span>
              <span class="font-weight-medium">{{ latestEvaluationBySupplier.size }}</span>
            </div>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="8">
        <BiPanel title="Supplier league table" subtitle="Derived from purchasing history and formal evaluations" icon="mdi-podium" color="indigo">
          <template #actions>
            <v-text-field v-model="search" placeholder="Search supplier…" variant="solo-filled" density="compact"
                          hide-details flat rounded="lg" bg-color="surface" prepend-inner-icon="mdi-magnify"
                          clearable style="max-width: 220px" />
            <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportTable">CSV</v-btn>
          </template>
          <EmptyState v-if="!filtered.length" icon="mdi-truck-off-outline" title="No supplier data" />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th style="width: 40px">#</th>
                <th>Supplier</th>
                <th class="text-right">Spend</th>
                <th class="text-right">Orders</th>
                <th class="text-right">On-time</th>
                <th class="text-right">Fill rate</th>
                <th class="text-right">Lead time</th>
                <th class="text-right">Evaluation</th>
                <th class="text-right">Composite</th>
                <th class="text-center">Grade</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(s, i) in filtered" :key="s.name">
                <td class="text-medium-emphasis">{{ i + 1 }}</td>
                <td>
                  <div class="d-flex align-center ga-2">
                    <v-avatar size="26" color="teal" variant="tonal">
                      <span class="text-caption font-weight-bold">{{ initials(s.name) }}</span>
                    </v-avatar>
                    <div>
                      <div class="font-weight-medium text-truncate" style="max-width: 180px">{{ s.name }}</div>
                      <div class="text-caption text-medium-emphasis">
                        {{ s.paymentTerms || 'No payment terms' }}
                        <span v-if="!s.isActive"> · inactive</span>
                      </div>
                    </div>
                  </div>
                </td>
                <td class="text-right">{{ formatMoney(s.spend) }}</td>
                <td class="text-right">{{ s.orders }}</td>
                <td class="text-right">
                  <span v-if="s.onTimeRate == null" class="text-medium-emphasis">—</span>
                  <span v-else :class="s.onTimeRate >= 90 ? 'text-success' : s.onTimeRate >= 75 ? 'text-warning' : 'text-error'">
                    {{ s.onTimeRate.toFixed(0) }}%
                  </span>
                </td>
                <td class="text-right">
                  <span v-if="s.avgFillRate == null" class="text-medium-emphasis">—</span>
                  <span v-else>{{ s.avgFillRate.toFixed(0) }}%</span>
                </td>
                <td class="text-right">{{ s.avgLeadTime == null ? '—' : `${s.avgLeadTime.toFixed(0)}d` }}</td>
                <td class="text-right">
                  <span v-if="evaluationFor(s.name) == null" class="text-medium-emphasis">—</span>
                  <span v-else class="font-weight-medium">{{ evaluationFor(s.name).toFixed(1) }}</span>
                </td>
                <td class="text-right font-weight-bold">{{ s.score == null ? '—' : s.score }}</td>
                <td class="text-center">
                  <v-chip size="small" :color="gradeColor(s.score)" variant="tonal" class="font-weight-bold">
                    {{ grade(s.score) }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Detail cards -->
    <v-row class="mt-1">
      <v-col cols="12" lg="6">
        <BiPanel title="Scorecard detail" subtitle="Pick a supplier to inspect the full breakdown" icon="mdi-card-account-details-outline" color="purple">
          <v-select
            v-model="activeSupplierName"
            :items="supplierOptions"
            item-title="label" item-value="value"
            variant="outlined" density="compact" hide-details class="mb-3" prepend-inner-icon="mdi-truck-outline"
          />
          <EmptyState v-if="!activeSupplier" icon="mdi-truck-outline" title="Select a supplier" />
          <template v-else>
            <div class="d-flex flex-wrap align-center ga-3 mb-3">
              <v-avatar size="54" color="purple" variant="tonal">
                <span class="text-h6 font-weight-bold">{{ initials(activeSupplier.name) }}</span>
              </v-avatar>
              <div class="flex-grow-1">
                <div class="text-subtitle-1 font-weight-bold">{{ activeSupplier.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ activeSupplier.orders }} orders · {{ formatMoney(activeSupplier.spend) }} ·
                  {{ activeSupplier.share.toFixed(1) }}% of spend
                </div>
              </div>
              <v-chip :color="gradeColor(activeSupplier.score)" variant="flat" class="font-weight-bold">
                {{ grade(activeSupplier.score) }} · {{ activeSupplier.score ?? '—' }}
              </v-chip>
            </div>

            <div v-for="m in detailMetrics" :key="m.label" class="mb-2">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span>{{ m.label }}</span>
                <span class="font-weight-medium" :class="m.tone">{{ m.value }}</span>
              </div>
              <v-progress-linear :model-value="m.pct" :color="m.color" height="6" rounded />
            </div>

            <v-divider class="my-3" />
            <div class="text-caption text-medium-emphasis mb-1">Recent orders</div>
            <v-list density="compact" class="bg-transparent pa-0">
              <v-list-item v-for="o in recentOrdersForActive" :key="o.id" class="px-0"
                           :to="`/ims/purchase-orders/${o.id}`">
                <v-list-item-title class="text-body-2">{{ o.po_number }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ formatDate(o.order_date) }} · {{ formatMoney(o.landedCost) }}
                </v-list-item-subtitle>
                <template #append><StatusChip :status="o.status" /></template>
              </v-list-item>
            </v-list>
          </template>
        </BiPanel>
      </v-col>

      <v-col cols="12" lg="6">
        <BiPanel title="Evaluation history" subtitle="Formal scorecards recorded for suppliers" icon="mdi-clipboard-text-clock-outline" color="cyan">
          <EmptyState v-if="!evaluationRows.length" icon="mdi-clipboard-off-outline" title="No evaluations yet"
                      message="Record an evaluation to track qualitative performance over time." />
          <v-table v-else density="compact" class="bg-transparent">
            <thead>
              <tr>
                <th>Supplier</th>
                <th class="text-right">Date</th>
                <th class="text-right">OTD</th>
                <th class="text-right">Quality</th>
                <th class="text-right">Price</th>
                <th class="text-right">Overall</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="e in evaluationRows.slice(0, 12)" :key="e.id">
                <td class="text-truncate" style="max-width: 160px">{{ e.supplierName }}</td>
                <td class="text-right text-medium-emphasis">{{ formatDate(e.evaluation_date) }}</td>
                <td class="text-right">{{ num(e.on_time_delivery_score) }}</td>
                <td class="text-right">{{ num(e.quality_score) }}</td>
                <td class="text-right">{{ num(e.pricing_competitiveness) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="ratingColor(e.rating)" variant="tonal" class="font-weight-bold">
                    {{ e.rating.toFixed(1) }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
        </BiPanel>
      </v-col>
    </v-row>

    <!-- Evaluation dialog -->
    <v-dialog v-model="evalDialog" max-width="620">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Supplier evaluation</v-card-title>
        <v-card-subtitle>Score each dimension from 1 (poor) to 5 (excellent)</v-card-subtitle>
        <v-card-text>
          <v-select
            v-model="draft.supplier"
            :items="supplierOptions"
            item-title="label" item-value="value"
            label="Supplier" variant="outlined" density="compact" hide-details class="mb-3"
          />
          <div v-for="d in dimensionControls" :key="d.key" class="mb-3">
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span>{{ d.label }}</span>
              <span class="font-weight-bold">{{ draft[d.key] }} / 5</span>
            </div>
            <v-slider v-model="draft[d.key]" :min="1" :max="5" :step="1" show-ticks="always" tick-size="3"
                      :color="ratingColor(draft[d.key])" hide-details density="compact" />
          </div>
          <v-textarea v-model="draft.notes" label="Notes" variant="outlined" density="compact" rows="2" hide-details />
          <v-alert type="info" variant="tonal" density="compact" class="mt-3 text-caption">
            Overall rating will be recorded as {{ draftOverall.toFixed(1) }} / 5.
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="evalDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" class="text-none" :loading="saving" :disabled="!draft.supplier"
                 @click="saveEvaluation">Save evaluation</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum, mean, downloadCsv, round } from '~/utils/bi'

const { $api } = useNuxtApp()
const {
  loading, supplierRows, evaluationRows, latestEvaluationBySupplier, evaluationDimensions,
  ordersEnriched, branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const search = ref('')
const activeSupplierName = ref(null)
const evalDialog = ref(false)
const saving = ref(false)

const dimensionControls = [
  { key: 'on_time_delivery_score', label: 'On-time delivery' },
  { key: 'quality_score', label: 'Quality of goods' },
  { key: 'responsiveness_score', label: 'Responsiveness' },
  { key: 'pricing_competitiveness', label: 'Pricing competitiveness' },
  { key: 'payment_flexibility', label: 'Payment flexibility' }
]

const draft = ref({
  supplier: null,
  on_time_delivery_score: 3,
  quality_score: 3,
  responsiveness_score: 3,
  pricing_competitiveness: 3,
  payment_flexibility: 3,
  notes: ''
})

const supplierOptions = computed(() => supplierRows.value.map((s) => ({ label: s.name, value: s.name })))

const filtered = computed(() => {
  if (!search.value) return supplierRows.value
  const q = search.value.toLowerCase()
  return supplierRows.value.filter((s) => s.name.toLowerCase().includes(q))
})

const activeSupplier = computed(() => supplierRows.value.find((s) => s.name === activeSupplierName.value) || null)
const recentOrdersForActive = computed(() =>
  ordersEnriched.value
    .filter((o) => o.supplier_name === activeSupplierName.value)
    .sort((a, b) => new Date(b.order_date || b.created_at || 0) - new Date(a.order_date || a.created_at || 0))
    .slice(0, 5)
)

// Auto-select the largest supplier.
watchEffect(() => {
  if (activeSupplierName.value || !supplierRows.value.length) return
  activeSupplierName.value = supplierRows.value[0].name
})

const dimensions = computed(() => evaluationDimensions.value)

const draftOverall = computed(() =>
  mean(dimensionControls.map((d) => num(draft.value[d.key])))
)

const kpis = computed(() => {
  const scored = supplierRows.value.filter((s) => s.score != null)
  const best = [...scored].sort((a, b) => b.score - a.score)[0]
  const worst = [...scored].sort((a, b) => a.score - b.score)[0]
  const atRisk = supplierRows.value.filter((s) => s.risk !== 'low')
  return [
    { title: 'Active suppliers', value: String(supplierRows.value.filter((s) => s.isActive !== false).length), icon: 'mdi-truck-check-outline', color: 'teal', hint: `${supplierRows.value.length} with history` },
    { title: 'Top performer', value: best ? best.name : '—', icon: 'mdi-trophy-outline', color: 'success', hint: best ? `Score ${best.score}` : 'Insufficient data' },
    { title: 'Needs improvement', value: worst ? worst.name : '—', icon: 'mdi-alert-outline', color: 'warning', hint: worst ? `Score ${worst.score}` : 'Insufficient data' },
    { title: 'At-risk suppliers', value: String(atRisk.length), valueNum: atRisk.length, icon: 'mdi-shield-alert-outline', color: 'error', invertDelta: true, hint: 'Delivery or fill-rate risk' },
    { title: 'Evaluations', value: String(evaluationRows.value.length), icon: 'mdi-clipboard-text-outline', color: 'cyan', hint: `${latestEvaluationBySupplier.value.size} suppliers assessed` },
    { title: 'Average rating', value: evaluationRows.value.length ? (sum(evaluationRows.value, (e) => e.rating) / evaluationRows.value.length).toFixed(1) : '—', icon: 'mdi-star-outline', color: 'amber', hint: 'Out of 5' }
  ]
})

const detailMetrics = computed(() => {
  const s = activeSupplier.value
  if (!s) return []
  return [
    { label: 'On-time delivery', value: s.onTimeRate == null ? 'No history' : `${s.onTimeRate.toFixed(0)}%`, pct: s.onTimeRate ?? 0, color: s.onTimeRate >= 90 ? 'success' : 'warning', tone: '' },
    { label: 'Order fill rate', value: s.avgFillRate == null ? 'No history' : `${s.avgFillRate.toFixed(0)}%`, pct: Math.min(100, s.avgFillRate ?? 0), color: s.avgFillRate >= 95 ? 'success' : 'warning', tone: '' },
    { label: 'Average lead time', value: s.avgLeadTime == null ? 'No history' : `${s.avgLeadTime.toFixed(0)} days`, pct: Math.min(100, 100 - (s.avgLeadTime ?? 0)), color: 'info', tone: '' },
    { label: 'Spend share', value: `${s.share.toFixed(1)}%`, pct: Math.min(100, s.share), color: 'purple', tone: '' },
    { label: 'Open orders', value: String(s.openOrders), pct: Math.min(100, s.openOrders * 20), color: s.openOrders > 3 ? 'warning' : 'grey', tone: '' },
    {
      label: 'Evaluation rating',
      value: evaluationFor(s.name) == null ? 'Not evaluated' : `${evaluationFor(s.name).toFixed(1)} / 5`,
      pct: ((evaluationFor(s.name) ?? 0) / 5) * 100,
      color: 'amber',
      tone: ''
    }
  ]
})

function evaluationFor(name) {
  const e = latestEvaluationBySupplier.value.get(name)
  return e ? e.rating : null
}
function initials(name) {
  return String(name || '?').split(/\s+/).map((p) => p[0]).slice(0, 2).join('').toUpperCase()
}
function ratingColor(v) {
  const n = num(v)
  return n >= 4 ? 'success' : n >= 3 ? 'warning' : 'error'
}
function grade(score) {
  if (score == null) return 'N/A'
  if (score >= 90) return 'A'
  if (score >= 80) return 'B'
  if (score >= 70) return 'C'
  if (score >= 60) return 'D'
  return 'E'
}
function gradeColor(score) {
  if (score == null) return 'grey'
  if (score >= 85) return 'success'
  if (score >= 70) return 'info'
  if (score >= 60) return 'warning'
  return 'error'
}

function openEvaluation(name) {
  draft.value = {
    supplier: name || activeSupplierName.value || null,
    on_time_delivery_score: 3,
    quality_score: 3,
    responsiveness_score: 3,
    pricing_competitiveness: 3,
    payment_flexibility: 3,
    notes: ''
  }
  evalDialog.value = true
}

async function saveEvaluation() {
  const supplier = supplierRows.value.find((s) => s.name === draft.value.supplier)
  if (!supplier?.supplierId) return
  saving.value = true
  try {
    await $api.post('/purchase-orders/evaluations/', {
      supplier: supplier.supplierId,
      on_time_delivery_score: draft.value.on_time_delivery_score,
      quality_score: draft.value.quality_score,
      responsiveness_score: draft.value.responsiveness_score,
      pricing_competitiveness: draft.value.pricing_competitiveness,
      payment_flexibility: draft.value.payment_flexibility,
      notes: draft.value.notes
    })
    evalDialog.value = false
    await load()
  } finally {
    saving.value = false
  }
}

function exportTable() {
  downloadCsv(
    'supplier-scorecards',
    ['name', 'orders', 'spend', 'share', 'onTimeRate', 'avgFillRate', 'avgLeadTime', 'score', 'risk'],
    filtered.value.map((s) => ({
      ...s,
      spend: Math.round(s.spend),
      share: round(s.share, 2),
      onTimeRate: s.onTimeRate == null ? '' : round(s.onTimeRate, 1),
      avgFillRate: s.avgFillRate == null ? '' : round(s.avgFillRate, 1),
      avgLeadTime: s.avgLeadTime == null ? '' : round(s.avgLeadTime, 1)
    }))
  )
}
</script>
