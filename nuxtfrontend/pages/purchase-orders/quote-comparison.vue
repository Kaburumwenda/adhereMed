<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Quote Comparison"
      subtitle="Side-by-side bid analysis, weighted award scoring and savings capture"
      eyebrow="PROCUREMENT · SOURCING"
      icon="mdi-scale-balance"
      color="purple"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn variant="tonal" color="purple" rounded="lg" class="text-none" prepend-icon="mdi-file-document-plus"
               to="/ims/purchase-orders/rfqs/new">New RFQ</v-btn>
      </template>
    </ProcToolbar>

    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3" xl="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <!-- RFQ list -->
      <v-col cols="12" lg="4">
        <BiPanel :title="`Requests for quotation`" :subtitle="`${rfqEnriched.length} total · ${openRfqs.length} open`" icon="mdi-file-document-multiple-outline" color="purple">
          <template #actions>
            <v-text-field v-model="search" placeholder="Search…" variant="solo-filled" density="compact"
                          hide-details flat rounded="lg" bg-color="surface" prepend-inner-icon="mdi-magnify"
                          clearable style="max-width: 160px" />
          </template>
          <EmptyState v-if="!filteredRfqs.length" icon="mdi-file-document-outline" title="No RFQs" message="Raise an RFQ to invite supplier quotes." />
          <v-list v-else density="compact" class="bg-transparent pa-0" style="max-height: 560px; overflow: auto">
            <v-list-item
              v-for="r in filteredRfqs"
              :key="r.id"
              class="px-2 rounded mb-1"
              :class="{ 'bg-purple-lighten-5': activeRfqId === r.id }"
              @click="activeRfqId = r.id"
            >
              <template #prepend>
                <v-avatar size="34" :color="rfqStatusColor(r.status)" variant="tonal">
                  <v-icon size="16">mdi-file-document-outline</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">{{ r.rfq_number }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption text-truncate">{{ r.title }}</v-list-item-subtitle>
              <template #append>
                <div class="text-right">
                  <v-chip size="x-small" :color="rfqStatusColor(r.status)" variant="tonal">{{ r.quoteCount }} quotes</v-chip>
                  <div v-if="r.quoteCount > 1" class="text-caption text-success mt-1">
                    save {{ compactNumber(r.spread) }}
                  </div>
                </div>
              </template>
            </v-list-item>
          </v-list>
        </BiPanel>
      </v-col>

      <!-- Analysis -->
      <v-col cols="12" lg="8">
        <EmptyState
          v-if="!activeRfq"
          icon="mdi-scale-balance"
          title="Select an RFQ"
          message="Choose a request from the list to compare the supplier quotes side by side."
        />

        <template v-else>
          <!-- RFQ header -->
          <v-card rounded="lg" class="pa-4 mb-3" border>
            <div class="d-flex flex-wrap align-center justify-space-between ga-3">
              <div>
                <div class="d-flex align-center ga-2">
                  <span class="text-h6 font-weight-bold">{{ activeRfq.rfq_number }}</span>
                  <v-chip size="small" :color="rfqStatusColor(activeRfq.status)" variant="tonal">
                    {{ rfqStatusLabel(activeRfq.status) }}
                  </v-chip>
                  <v-chip v-if="activeRfq.expired" size="small" color="error" variant="tonal" prepend-icon="mdi-calendar-alert">
                    Deadline passed
                  </v-chip>
                </div>
                <div class="text-body-2 text-medium-emphasis">{{ activeRfq.title }}</div>
                <div class="text-caption text-medium-emphasis mt-1">
                  {{ activeRfq.items?.length || 0 }} requested lines
                  <span v-if="activeRfq.response_deadline"> · deadline {{ formatDate(activeRfq.response_deadline) }}</span>
                  <span v-if="activeRfq.awarded_supplier_name"> · awarded to {{ activeRfq.awarded_supplier_name }}</span>
                </div>
              </div>
              <div class="d-flex flex-wrap align-center ga-2">
                <v-btn v-if="['draft'].includes(activeRfq.status)" variant="tonal" color="purple" rounded="lg"
                       class="text-none" prepend-icon="mdi-send" :loading="acting" @click="sendToSuppliers">Send to suppliers</v-btn>
                <v-btn v-if="activeRfq.awarded_po" variant="tonal" color="teal" rounded="lg" class="text-none"
                       prepend-icon="mdi-cart-check" :to="`/ims/purchase-orders/${activeRfq.awarded_po}`">View PO</v-btn>
                <v-btn v-else-if="activeRfq.status === 'awarded'" color="teal" rounded="lg" class="text-none"
                       prepend-icon="mdi-cart-plus" :loading="acting" @click="createPo">Create PO from award</v-btn>
              </div>
            </div>
          </v-card>

          <!-- Verdict -->
          <v-alert v-if="analysis.recommendation" :color="analysis.recommendation.color" variant="tonal" rounded="lg"
                   border="start" prominent class="mb-3">
            <div class="d-flex flex-wrap align-center ga-3">
              <v-icon size="26">{{ analysis.recommendation.icon }}</v-icon>
              <div class="flex-grow-1">
                <div class="text-subtitle-2 font-weight-bold">{{ analysis.recommendation.headline }}</div>
                <div class="text-body-2">{{ analysis.recommendation.detail }}</div>
              </div>
              <v-chip variant="flat" :color="analysis.recommendation.color" class="font-weight-bold">
                {{ analysis.recommendation.chip }}
              </v-chip>
            </div>
          </v-alert>

          <EmptyState
            v-if="!activeRfq.quotes.length"
            icon="mdi-file-question-outline"
            title="No quotes received yet"
            message="Send the RFQ to suppliers and record their responses to unlock the comparison."
          />

          <template v-else>
            <!-- Summary stats -->
            <v-row dense class="mb-1">
              <v-col v-for="s in analysis.summary" :key="s.label" cols="6" md="3">
                <v-card rounded="lg" class="pa-3 h-100" variant="tonal" :color="s.color">
                  <div class="text-caption font-weight-medium">{{ s.label }}</div>
                  <div class="text-h6 font-weight-bold">{{ s.value }}</div>
                  <div class="text-caption">{{ s.hint }}</div>
                </v-card>
              </v-col>
            </v-row>

            <!-- Weighted scoring -->
            <BiPanel title="Weighted award scoring" subtitle="Price, delivery speed and supplier track record" icon="mdi-trophy-outline" color="purple" class="mt-3">
              <template #actions>
                <v-menu location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" variant="tonal" size="small" color="purple" rounded="lg"
                           class="text-none" prepend-icon="mdi-tune-variant">Weights</v-btn>
                  </template>
                  <v-card rounded="lg" class="pa-3" min-width="280">
                    <div v-for="w in weightControls" :key="w.key" class="mb-2">
                      <div class="d-flex justify-space-between text-caption mb-1">
                        <span>{{ w.label }}</span><span class="font-weight-medium">{{ weights[w.key] }}%</span>
                      </div>
                      <v-slider v-model="weights[w.key]" :min="0" :max="100" :step="5" :color="w.color" hide-details density="compact" />
                    </div>
                    <div class="text-caption text-medium-emphasis">Normalised automatically to 100%.</div>
                  </v-card>
                </v-menu>
              </template>
              <v-table density="compact" class="bg-transparent">
                <thead>
                  <tr>
                    <th>Supplier</th>
                    <th class="text-right">Quoted total</th>
                    <th class="text-right">vs best</th>
                    <th class="text-right">Delivery</th>
                    <th class="text-right">Track record</th>
                    <th class="text-right">Score</th>
                    <th class="text-center">Decision</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="q in analysis.scored" :key="q.id" :class="q.recommended ? 'bg-success-lighten-5' : ''">
                    <td>
                      <div class="d-flex align-center ga-2">
                        <v-avatar size="26" color="purple" variant="tonal">
                          <span class="text-caption font-weight-bold">{{ initials(q.supplier_name) }}</span>
                        </v-avatar>
                        <span class="font-weight-medium">{{ q.supplier_name }}</span>
                        <v-chip v-if="q.recommended" size="x-small" color="success" variant="tonal">Recommended</v-chip>
                        <v-chip v-if="q.isLowest" size="x-small" color="teal" variant="tonal">Lowest price</v-chip>
                      </div>
                    </td>
                    <td class="text-right font-weight-bold">{{ formatMoney(q.total_cost) }}</td>
                    <td class="text-right">
                      <span v-if="q.vsBest === 0" class="text-success font-medium">best</span>
                      <span v-else class="text-error">+{{ formatMoney(q.vsBest) }}</span>
                    </td>
                    <td class="text-right">{{ q.delivery_days ? `${q.delivery_days}d` : '—' }}</td>
                    <td class="text-right">
                      <span v-if="q.trackRecord == null" class="text-medium-emphasis">—</span>
                      <span v-else :class="q.trackRecord >= 80 ? 'text-success' : 'text-warning'">{{ q.trackRecord.toFixed(0) }}%</span>
                    </td>
                    <td class="text-right">
                      <div class="d-flex align-center justify-end ga-2">
                        <v-progress-linear :model-value="q.score" :color="q.recommended ? 'success' : 'purple'" height="6" rounded style="max-width: 80px" />
                        <span class="font-weight-bold">{{ q.score.toFixed(1) }}</span>
                      </div>
                    </td>
                    <td class="text-center">
                      <v-btn
                        v-if="q.status !== 'awarded'"
                        size="x-small" variant="tonal" color="success" class="text-none"
                        :loading="acting" :disabled="activeRfq.status === 'awarded'"
                        @click="award(q)"
                      >Award</v-btn>
                      <v-chip v-else size="x-small" color="success" variant="flat">Awarded</v-chip>
                    </td>
                  </tr>
                </tbody>
              </v-table>
            </BiPanel>

            <!-- Line-by-line matrix -->
            <BiPanel title="Line-by-line price matrix" subtitle="Unit cost per requested item, lowest offer highlighted" icon="mdi-table-large" color="indigo" class="mt-3">
              <template #actions>
                <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download" @click="exportMatrix">CSV</v-btn>
              </template>
              <div style="overflow: auto">
                <v-table density="compact" class="bg-transparent">
                  <thead>
                    <tr>
                      <th style="min-width: 200px">Item</th>
                      <th class="text-right">Requested qty</th>
                      <th v-for="q in activeRfq.quotes" :key="q.id" class="text-right">
                        {{ q.supplier_name }}
                      </th>
                      <th class="text-right">Spread</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="line in analysis.matrix" :key="line.name">
                      <td class="font-weight-medium text-truncate" style="max-width: 240px">{{ line.name }}</td>
                      <td class="text-right text-medium-emphasis">{{ line.qty }}</td>
                      <td v-for="(cell, i) in line.cells" :key="i" class="text-right"
                          :class="cell.best ? 'bg-success-lighten-5' : ''">
                        <span v-if="cell.unitCost == null" class="text-disabled">—</span>
                        <template v-else>
                          <span :class="cell.best ? 'text-success font-weight-bold' : ''">{{ formatMoney(cell.unitCost) }}</span>
                          <div v-if="cell.total != null" class="text-caption text-medium-emphasis">{{ formatMoney(cell.total) }}</div>
                        </template>
                      </td>
                      <td class="text-right">
                        <v-chip v-if="line.spread > 0" size="x-small" color="warning" variant="tonal">
                          {{ line.spreadPct.toFixed(1) }}%
                        </v-chip>
                        <span v-else class="text-medium-emphasis">—</span>
                      </td>
                    </tr>
                  </tbody>
                  <tfoot>
                    <tr class="font-weight-bold">
                      <td>Quoted total</td>
                      <td />
                      <td v-for="q in activeRfq.quotes" :key="`t-${q.id}`" class="text-right">{{ formatMoney(q.total_cost) }}</td>
                      <td />
                    </tr>
                    <tr>
                      <td class="text-medium-emphasis">Delivery (days)</td>
                      <td />
                      <td v-for="q in activeRfq.quotes" :key="`d-${q.id}`" class="text-right text-medium-emphasis">
                        {{ q.delivery_days || '—' }}
                      </td>
                      <td />
                    </tr>
                  </tfoot>
                </v-table>
              </div>
            </BiPanel>

            <!-- Quote notes -->
            <BiPanel v-if="quotesWithNotes.length" title="Supplier terms and notes" subtitle="Commercial conditions attached to each quote" icon="mdi-note-text-outline" color="teal" class="mt-3">
              <v-expansion-panels variant="accordion">
                <v-expansion-panel v-for="q in quotesWithNotes" :key="q.id">
                  <v-expansion-panel-title>
                    <div class="d-flex align-center ga-2">
                      <v-icon size="18">mdi-truck-outline</v-icon>
                      <span class="font-weight-medium">{{ q.supplier_name }}</span>
                      <v-chip size="x-small" variant="tonal">{{ formatMoney(q.total_cost) }}</v-chip>
                      <v-chip v-if="q.valid_until" size="x-small" :color="q.expired ? 'error' : 'grey'" variant="tonal">
                        valid to {{ formatDate(q.valid_until) }}
                      </v-chip>
                    </div>
                  </v-expansion-panel-title>
                  <v-expansion-panel-text>
                    <div class="text-body-2">{{ q.notes || 'No additional terms supplied.' }}</div>
                  </v-expansion-panel-text>
                </v-expansion-panel>
              </v-expansion-panels>
            </BiPanel>
          </template>
        </template>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney, formatDate } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum, mean, compactNumber, downloadCsv, clamp, round } from '~/utils/bi'

const { $api } = useNuxtApp()
const {
  loading, rfqEnriched, openRfqs, awardedRfqs, identifiedSavings, rfqSavings, bestQuotes,
  supplierRows, branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const search = ref('')
const activeRfqId = ref(null)
const acting = ref(false)
const weights = ref({ price: 60, delivery: 25, quality: 15 })

const weightControls = [
  { key: 'price', label: 'Price competitiveness', color: 'purple' },
  { key: 'delivery', label: 'Delivery speed', color: 'indigo' },
  { key: 'quality', label: 'Supplier track record', color: 'teal' }
]

const filteredRfqs = computed(() => {
  const q = search.value?.toLowerCase()
  const rows = q
    ? rfqEnriched.value.filter((r) => `${r.rfq_number} ${r.title}`.toLowerCase().includes(q))
    : rfqEnriched.value
  // Prefer RFQs that actually have quotes, newest first.
  return [...rows].sort((a, b) => {
    if (b.quoteCount !== a.quoteCount) return b.quoteCount - a.quoteCount
    return new Date(b.created_at || 0) - new Date(a.created_at || 0)
  })
})

const activeRfq = computed(() => rfqEnriched.value.find((r) => r.id === activeRfqId.value) || null)

// Auto-select the first RFQ with quotes once data arrives.
watchEffect(() => {
  if (activeRfqId.value != null) return
  const first = filteredRfqs.value.find((r) => r.quoteCount > 0) || filteredRfqs.value[0]
  if (first) activeRfqId.value = first.id
})

const kpis = computed(() => [
  { title: 'Open RFQs', value: String(openRfqs.value.length), valueNum: openRfqs.value.length, icon: 'mdi-file-document-multiple-outline', color: 'purple', hint: 'Awaiting award' },
  { title: 'Quotes received', value: String(sum(rfqEnriched.value, (r) => r.quoteCount)), icon: 'mdi-file-check-outline', color: 'indigo', hint: 'Across all RFQs' },
  { title: 'Identified savings', value: formatMoney(identifiedSavings.value), valueNum: identifiedSavings.value, icon: 'mdi-piggy-bank-outline', color: 'success', hint: 'Best vs worst quote' },
  { title: 'Realised savings', value: formatMoney(rfqSavings.value), valueNum: rfqSavings.value, icon: 'mdi-cash-check', color: 'teal', hint: 'On awarded RFQs' },
  { title: 'Lowest-price wins', value: String(bestQuotes.value.filter((q) => q.status === 'awarded').length), icon: 'mdi-trophy-outline', color: 'amber', hint: 'Awarded at best price' },
  { title: 'Average quotes / RFQ', value: rfqEnriched.value.length ? (sum(rfqEnriched.value, (r) => r.quoteCount) / rfqEnriched.value.length).toFixed(1) : '0', icon: 'mdi-scale-balance', color: 'cyan', hint: 'Competition depth' }
])

// ── analysis for the active RFQ ─────────────────────────────────────────
const analysis = computed(() => {
  const rfq = activeRfq.value
  if (!rfq) return { summary: [], scored: [], matrix: [], recommendation: null }

  const quotes = rfq.quotes || []
  if (!quotes.length) return { summary: [], scored: [], matrix: [], recommendation: null }

  const totals = quotes.map((q) => num(q.total_cost)).filter((v) => v > 0)
  const best = totals.length ? Math.min(...totals) : 0
  const worst = totals.length ? Math.max(...totals) : 0
  const avg = totals.length ? mean(totals) : 0
  const fastest = quotes.filter((q) => q.delivery_days > 0).sort((a, b) => a.delivery_days - b.delivery_days)[0]

  // Normalise the weights to 100%.
  const wSum = Math.max(1, num(weights.value.price) + num(weights.value.delivery) + num(weights.value.quality))
  const wPrice = num(weights.value.price) / wSum
  const wDelivery = num(weights.value.delivery) / wSum
  const wQuality = num(weights.value.quality) / wSum

  const trackRecord = (name) => {
    const row = supplierRows.value.find((s) => s.name === name)
    return row && row.score != null ? row.score : null
  }

  const scored = quotes.map((q) => {
    const total = num(q.total_cost)
    // Price score: best price = 100, worst = 0 (linear).
    const priceScore = worst > best ? ((worst - total) / (worst - best)) * 100 : 100
    // Delivery score: fastest = 100; each extra day costs 4 points.
    const deliveryScore = fastest && q.delivery_days
      ? clamp(100 - (num(q.delivery_days) - num(fastest.delivery_days)) * 4, 0, 100)
      : 60
    const record = trackRecord(q.supplier_name)
    const recordScore = record == null ? 65 : record
    const score = round(priceScore * wPrice + deliveryScore * wDelivery + recordScore * wQuality, 1)
    return {
      ...q,
      vsBest: total - best,
      trackRecord: record,
      priceScore: round(priceScore, 1),
      deliveryScore: round(deliveryScore, 1),
      recordScore: round(recordScore, 1),
      score
    }
  })

  const ranked = [...scored].sort((a, b) => b.score - a.score)
  const recommendedQuote = ranked[0]
  const lowestQuote = scored.find((q) => q.isLowest || num(q.total_cost) === best)
  ranked.forEach((q) => { q.recommended = recommendedQuote && q.id === recommendedQuote.id })

  // Line-by-line matrix keyed on item name.
  const names = new Set()
  for (const q of quotes) for (const it of q.items || []) names.add(String(it.name || it.item_name || '').trim())
  for (const it of rfq.items || []) names.add(String(it.name || it.item_name || '').trim())

  const matrix = [...names].filter(Boolean).map((name) => {
    const cells = quotes.map((q) => {
      const line = (q.items || []).find((it) => String(it.name || it.item_name || '').trim() === name)
      return {
        unitCost: line ? num(line.unit_cost) : null,
        total: line ? num(line.total) : null
      }
    })
    const costs = cells.map((c) => c.unitCost).filter((c) => c != null && c > 0)
    const min = costs.length ? Math.min(...costs) : null
    const max = costs.length ? Math.max(...costs) : null
    cells.forEach((c) => { c.best = c.unitCost != null && min != null && c.unitCost === min })
    const requestLine = (rfq.items || []).find((it) => String(it.name || it.item_name || '').trim() === name)
    return {
      name,
      qty: requestLine ? num(requestLine.qty) : '',
      cells,
      spread: min != null && max != null ? max - min : 0,
      spreadPct: max ? ((max - min) / max) * 100 : 0
    }
  })

  const summary = [
    { label: 'Lowest quote', value: formatMoney(best), hint: lowestQuote?.supplier_name || '—', color: 'success' },
    { label: 'Highest quote', value: formatMoney(worst), hint: `${((worst - best) / (best || 1) * 100).toFixed(1)}% above best`, color: 'error' },
    { label: 'Average quote', value: formatMoney(avg), hint: `${quotes.length} supplier${quotes.length === 1 ? '' : 's'}`, color: 'info' },
    { label: 'Potential saving', value: formatMoney(worst - best), hint: 'Taking best over worst', color: 'warning' }
  ]

  const priceGap = best && recommendedQuote ? num(recommendedQuote.total_cost) - best : 0
  let recommendation = null
  if (recommendedQuote && lowestQuote) {
    if (recommendedQuote.id === lowestQuote.id) {
      recommendation = {
        color: 'success',
        icon: 'mdi-check-decagram',
        headline: `${recommendedQuote.supplier_name} is both the lowest cost and the highest weighted score`,
        detail: `Award on price with no trade-off. Quoted ${formatMoney(recommendedQuote.total_cost)}${recommendedQuote.delivery_days ? ` with ${recommendedQuote.delivery_days} day delivery` : ''}.`,
        chip: `${recommendedQuote.score} / 100`
      }
    } else {
      recommendation = {
        color: 'info',
        icon: 'mdi-scale-balance',
        headline: `Weighted scoring favours ${recommendedQuote.supplier_name}`,
        detail: `It costs ${formatMoney(priceGap)} more than the cheapest offer${lowestQuote ? ` (${lowestQuote.supplier_name})` : ''}, but wins on delivery and track record. Lower the delivery or quality weight if price must dominate.`,
        chip: `${recommendedQuote.score} / 100`
      }
    }
  }

  return { summary, scored: ranked, matrix, recommendation }
})

const quotesWithNotes = computed(() => (activeRfq.value?.quotes || []).filter((q) => q.notes || q.valid_until))

function initials(name) {
  return String(name || '?').split(/\s+/).map((p) => p[0]).slice(0, 2).join('').toUpperCase()
}
function rfqStatusColor(s) {
  const map = { draft: 'grey', sent: 'info', quoted: 'warning', awarded: 'success', closed: 'grey', cancelled: 'error' }
  return map[s] || 'grey'
}
function rfqStatusLabel(s) {
  const map = { draft: 'Draft', sent: 'Sent', quoted: 'Quotes received', awarded: 'Awarded', closed: 'Closed', cancelled: 'Cancelled' }
  return map[s] || s
}

async function award(q) {
  acting.value = true
  try {
    await $api.post(`/purchase-orders/rfqs/${activeRfq.value.id}/award/`, { quote_id: q.id })
    await load()
  } finally {
    acting.value = false
  }
}

async function sendToSuppliers() {
  acting.value = true
  try {
    await $api.post(`/purchase-orders/rfqs/${activeRfq.value.id}/send_to_suppliers/`)
    await load()
  } finally {
    acting.value = false
  }
}

async function createPo() {
  acting.value = true
  try {
    const { data } = await $api.post(`/purchase-orders/rfqs/${activeRfq.value.id}/create_po/`)
    await load()
    if (data?.id) navigateTo(`/ims/purchase-orders/${data.id}`)
  } finally {
    acting.value = false
  }
}

function exportMatrix() {
  const rfq = activeRfq.value
  if (!rfq) return
  const headers = ['item', 'requested_qty', ...rfq.quotes.map((q) => q.supplier_name), 'spread_pct']
  const rows = analysis.value.matrix.map((line) => {
    const row = { item: line.name, requested_qty: line.qty, spread_pct: line.spreadPct.toFixed(2) }
    rfq.quotes.forEach((q, i) => { row[q.supplier_name] = line.cells[i]?.unitCost ?? '' })
    return row
  })
  downloadCsv(`quote-comparison-${rfq.rfq_number}`, headers, rows)
}
</script>
