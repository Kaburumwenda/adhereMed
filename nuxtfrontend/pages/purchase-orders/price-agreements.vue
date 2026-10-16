<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Price Agreements"
      subtitle="Supplier price lists, best-price benchmarking and contract price variance"
      eyebrow="PROCUREMENT · SOURCING"
      icon="mdi-tag-multiple-outline"
      color="amber"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn variant="tonal" color="amber" rounded="lg" class="text-none" prepend-icon="mdi-download"
               @click="exportBenchmarks">Export</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-truck-plus-outline"
               to="/ims/suppliers/new">Add supplier</v-btn>
      </template>
    </ProcToolbar>

    <v-alert v-if="priceSavingOpportunity > 0" color="success" variant="tonal" rounded="lg" border="start" prominent class="mb-4">
      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center">
          <v-icon size="28" class="mr-3">mdi-piggy-bank-outline</v-icon>
          <div>
            <div class="text-subtitle-1 font-weight-bold">
              {{ formatMoney(priceSavingOpportunity) }} annualised saving identified
            </div>
            <div class="text-body-2">
              Buying {{ multiSourced.length }} co-sourced item{{ multiSourced.length === 1 ? '' : 's' }} at the best agreed
              price instead of the highest would release this value over twelve months.
            </div>
          </div>
        </div>
        <v-chip variant="flat" color="success" class="font-weight-bold">{{ multiSourced.length }} items</v-chip>
      </div>
    </v-alert>

    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <v-tabs v-model="tab" color="amber" density="compact" class="mt-4 border-b">
      <v-tab value="benchmarks" prepend-icon="mdi-scale-balance" class="text-none">Price benchmarking</v-tab>
      <v-tab value="agreements" prepend-icon="mdi-file-sign" class="text-none">Supplier price lists</v-tab>
      <v-tab value="variance" prepend-icon="mdi-chart-scatter-plot" class="text-none">Purchase price variance</v-tab>
    </v-tabs>

    <!-- Benchmarking -->
    <template v-if="tab === 'benchmarks'">
      <v-card rounded="lg" class="mt-2" border>
        <div class="d-flex flex-wrap align-center ga-2 pa-3">
          <v-text-field v-model="search" placeholder="Search item…" variant="solo-filled" density="compact"
                        hide-details flat rounded="lg" bg-color="surface" prepend-inner-icon="mdi-magnify"
                        clearable style="max-width: 260px" />
          <v-select v-model="scopeFilter" :items="scopeOptions" item-title="label" item-value="value"
                    variant="solo-filled" density="compact" hide-details flat rounded="lg" bg-color="surface"
                    style="max-width: 200px" />
          <v-spacer />
          <v-chip size="small" variant="tonal" color="amber">{{ filteredBenchmarks.length }} items</v-chip>
        </div>
        <v-divider />
        <EmptyState
          v-if="!filteredBenchmarks.length"
          icon="mdi-tag-off-outline"
          title="No price data"
          message="Add items to supplier price lists to build the benchmark."
        />
        <v-data-table
          v-else
          :headers="benchmarkHeaders"
          :items="filteredBenchmarks"
          :items-per-page="25"
          density="comfortable"
          hover
          expand-strategy="multiple"
          show-expand
        >
          <template #item.item="{ item }">
            <span class="font-weight-medium text-truncate" style="max-width: 240px">{{ item.item }}</span>
          </template>
          <template #item.supplierCount="{ item }">
            <v-chip size="small" :color="item.supplierCount > 1 ? 'teal' : 'grey'" variant="tonal">
              {{ item.supplierCount }}
            </v-chip>
          </template>
          <template #item.best="{ item }">
            <div>
              <div class="font-weight-bold text-success">{{ formatMoney(item.best) }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.bestSupplier }}</div>
            </div>
          </template>
          <template #item.worst="{ item }">
            <div>
              <div>{{ formatMoney(item.worst) }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.worstSupplier }}</div>
            </div>
          </template>
          <template #item.avg="{ item }">{{ formatMoney(item.avg) }}</template>
          <template #item.savingPerUnit="{ item }">
            <span v-if="item.savingPerUnit > 0" class="font-weight-bold text-success">
              {{ formatMoney(item.savingPerUnit) }}
            </span>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
          <template #item.spreadPct="{ item }">
            <v-chip v-if="item.spreadPct > 0" size="x-small" :color="item.spreadPct > 30 ? 'error' : 'warning'" variant="tonal">
              {{ item.spreadPct.toFixed(1) }}%
            </v-chip>
            <span v-else class="text-medium-emphasis">single source</span>
          </template>
          <template #expanded-row="{ columns, item }">
            <tr>
              <td :colspan="columns.length" class="pa-3">
                <div class="text-caption font-weight-bold text-uppercase mb-2" style="letter-spacing: .6px">
                  Offers for {{ item.item }}
                </div>
                <v-table density="compact">
                  <thead>
                    <tr>
                      <th>Supplier</th>
                      <th class="text-right">Unit cost</th>
                      <th class="text-right">Recommended retail</th>
                      <th class="text-right">Typical qty</th>
                      <th class="text-right">Margin</th>
                      <th>Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="o in item.offers" :key="o.supplier" :class="o.unitCost === item.best ? 'bg-success-lighten-5' : ''">
                      <td class="font-weight-medium">
                        {{ o.supplier }}
                        <v-chip v-if="o.unitCost === item.best" size="x-small" color="success" variant="tonal" class="ml-1">best</v-chip>
                      </td>
                      <td class="text-right font-weight-medium">{{ formatMoney(o.unitCost) }}</td>
                      <td class="text-right">{{ o.unitPrice ? formatMoney(o.unitPrice) : '—' }}</td>
                      <td class="text-right">{{ o.quantity || '—' }}</td>
                      <td class="text-right">
                        <span v-if="o.unitPrice && o.unitCost" :class="marginPct(o) >= 20 ? 'text-success' : 'text-warning'">
                          {{ marginPct(o).toFixed(1) }}%
                        </span>
                        <span v-else class="text-medium-emphasis">—</span>
                      </td>
                      <td class="text-caption text-medium-emphasis">{{ o.notes || '—' }}</td>
                    </tr>
                  </tbody>
                </v-table>
              </td>
            </tr>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- Supplier price lists -->
    <template v-else-if="tab === 'agreements'">
      <v-row dense class="mt-2">
        <v-col v-for="s in suppliersWithItems" :key="s.id" cols="12" md="6" xl="4">
          <v-card rounded="lg" class="h-100 d-flex flex-column" border>
            <div class="d-flex align-center pa-4 pb-2">
              <v-avatar size="40" color="amber" variant="tonal" class="mr-3">
                <v-icon size="20">mdi-truck-outline</v-icon>
              </v-avatar>
              <div class="flex-grow-1">
                <div class="text-subtitle-2 font-weight-bold">{{ s.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ (s.items || []).length }} agreed item{{ (s.items || []).length === 1 ? '' : 's' }}
                  <span v-if="s.payment_terms"> · {{ s.payment_terms }}</span>
                </div>
              </div>
              <v-btn icon="mdi-pencil-outline" size="small" variant="text" color="primary"
                     :to="`/ims/suppliers/${s.id}/edit`" />
            </div>
            <v-divider />
            <div class="pa-2 flex-grow-1" style="max-height: 300px; overflow: auto">
              <v-list density="compact" class="bg-transparent pa-0">
                <v-list-item v-for="it in s.items" :key="it.id" class="px-2">
                  <v-list-item-title class="text-body-2 text-truncate">{{ it.item_name }}</v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    Cost {{ formatMoney(it.unit_cost) }}
                    <span v-if="it.unit_price"> · sells {{ formatMoney(it.unit_price) }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip v-if="isBestPrice(it)" size="x-small" color="success" variant="tonal">best</v-chip>
                    <span v-else class="text-caption text-medium-emphasis">qty {{ it.quantity || '—' }}</span>
                  </template>
                </v-list-item>
              </v-list>
              <div v-if="!(s.items || []).length" class="text-caption text-medium-emphasis pa-3">
                No agreed items recorded for this supplier.
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
      <EmptyState v-if="!suppliersWithItems.length" icon="mdi-file-sign" title="No supplier price lists"
                  message="Attach agreed items and prices to a supplier to formalise the agreement." />
    </template>

    <!-- Purchase price variance -->
    <template v-else>
      <BiPanel class="mt-2" title="Purchase price variance" subtitle="Actual PO unit cost versus the agreed supplier price" icon="mdi-chart-scatter-plot" color="deep-orange">
        <EmptyState v-if="!ppv.length" icon="mdi-chart-scatter-plot" title="No variance detected"
                    message="Actual purchase prices match the agreed supplier price lists." />
        <v-table v-else density="compact" class="bg-transparent">
          <thead>
            <tr>
              <th>PO</th><th>Supplier</th><th>Item</th>
              <th class="text-right">Agreed</th><th class="text-right">Paid</th>
              <th class="text-right">Variance</th><th class="text-right">Var %</th>
              <th class="text-right">Value impact</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(r, i) in ppv" :key="i">
              <td class="font-weight-medium text-primary" style="cursor:pointer"
                  @click="navigateTo(`/ims/purchase-orders/${r.id}`)">{{ r.poNumber }}</td>
              <td class="text-truncate" style="max-width: 150px">{{ r.supplier }}</td>
              <td class="text-truncate" style="max-width: 200px">{{ r.item }}</td>
              <td class="text-right">{{ formatMoney(r.agreed) }}</td>
              <td class="text-right">{{ formatMoney(r.paid) }}</td>
              <td class="text-right" :class="r.variance > 0 ? 'text-error' : 'text-success'">
                {{ r.variance > 0 ? '+' : '' }}{{ formatMoney(r.variance) }}
              </td>
              <td class="text-right">
                <v-chip size="x-small" :color="r.variancePct > 5 ? 'error' : r.variancePct > 0 ? 'warning' : 'success'" variant="tonal">
                  {{ r.variancePct > 0 ? '+' : '' }}{{ r.variancePct.toFixed(1) }}%
                </v-chip>
              </td>
              <td class="text-right font-weight-medium" :class="r.impact > 0 ? 'text-error' : 'text-success'">
                {{ r.impact > 0 ? '+' : '' }}{{ formatMoney(r.impact) }}
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="font-weight-bold">
              <td colspan="7">Net variance</td>
              <td class="text-right" :class="ppvTotal > 0 ? 'text-error' : 'text-success'">
                {{ ppvTotal > 0 ? '+' : '' }}{{ formatMoney(ppvTotal) }}
              </td>
            </tr>
          </tfoot>
        </v-table>
      </BiPanel>
    </template>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum, mean, downloadCsv, round } from '~/utils/bi'

const {
  loading, priceBenchmarks, priceSavingOpportunity, multiSourced, singleSourced,
  suppliers, ordersEnriched, branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const tab = ref('benchmarks')
const search = ref('')
const scopeFilter = ref('all')

const scopeOptions = [
  { label: 'All items', value: 'all' },
  { label: 'Multi-sourced only', value: 'multi' },
  { label: 'Single-sourced only', value: 'single' }
]

const benchmarkHeaders = [
  { title: 'Item', key: 'item' },
  { title: 'Suppliers', key: 'supplierCount', align: 'end' },
  { title: 'Best price', key: 'best', align: 'end' },
  { title: 'Highest price', key: 'worst', align: 'end' },
  { title: 'Average', key: 'avg', align: 'end' },
  { title: 'Saving / unit', key: 'savingPerUnit', align: 'end' },
  { title: 'Spread', key: 'spreadPct', align: 'end' },
  { title: '', key: 'data-table-expand', sortable: false }
]

const filteredBenchmarks = computed(() => {
  let rows = priceBenchmarks.value
  if (scopeFilter.value === 'multi') rows = rows.filter((r) => r.supplierCount > 1)
  if (scopeFilter.value === 'single') rows = rows.filter((r) => r.supplierCount === 1)
  if (search.value) {
    const q = search.value.toLowerCase()
    rows = rows.filter((r) => String(r.item || '').toLowerCase().includes(q))
  }
  return rows
})

const suppliersWithItems = computed(() =>
  suppliers.value.filter((s) => (s.items || []).length).sort((a, b) => (b.items || []).length - (a.items || []).length)
)

/** Lookup of the best unit cost per item name, for the "best" badge. */
const bestPriceByItem = computed(() => {
  const map = new Map()
  for (const b of priceBenchmarks.value) map.set(String(b.item || '').toLowerCase(), b.best)
  return map
})

function isBestPrice(item) {
  const best = bestPriceByItem.value.get(String(item.item_name || '').toLowerCase())
  return best != null && num(item.unit_cost) === best
}

function marginPct(o) {
  if (!o.unitPrice || !o.unitCost) return 0
  return ((o.unitPrice - o.unitCost) / o.unitPrice) * 100
}

// ── purchase price variance ─────────────────────────────────────────────
const ppv = computed(() => {
  const agreed = new Map()
  for (const s of suppliers.value) {
    for (const it of s.items || []) {
      const key = `${s.name}|||${String(it.item_name || '').trim().toLowerCase()}`
      agreed.set(key, num(it.unit_cost))
    }
  }
  const out = []
  for (const po of ordersEnriched.value) {
    for (const it of po.items || []) {
      const name = String(it.name || it.item_name || '').trim()
      if (!name) continue
      const key = `${po.supplier_name}|||${name.toLowerCase()}`
      const agreedCost = agreed.get(key)
      if (agreedCost == null || agreedCost <= 0) continue
      const paid = num(it.unit_cost)
      if (!paid) continue
      const variance = paid - agreedCost
      if (Math.abs(variance) < 0.01) continue
      const qty = num(it.qty)
      out.push({
        id: po.id,
        poNumber: po.po_number,
        supplier: po.supplier_name,
        item: name,
        agreed: agreedCost,
        paid,
        variance,
        variancePct: (variance / agreedCost) * 100,
        impact: variance * qty,
        qty
      })
    }
  }
  return out.sort((a, b) => Math.abs(b.impact) - Math.abs(a.impact)).slice(0, 60)
})

const ppvTotal = computed(() => sum(ppv.value, (r) => r.impact))

const kpis = computed(() => {
  const totalItems = priceBenchmarks.value.length
  const agreements = sum(suppliersWithItems.value, (s) => (s.items || []).length)
  return [
    { title: 'Agreed items', value: String(agreements), valueNum: agreements, icon: 'mdi-file-sign', color: 'amber', hint: `${suppliersWithItems.value.length} suppliers` },
    { title: 'Items benchmarked', value: String(totalItems), icon: 'mdi-scale-balance', color: 'teal', hint: `${multiSourced.value.length} with competition` },
    { title: 'Saving opportunity', value: formatMoney(priceSavingOpportunity.value), valueNum: priceSavingOpportunity.value, icon: 'mdi-piggy-bank-outline', color: 'success', hint: 'Annualised, best price' },
    { title: 'Price variance', value: formatMoney(ppvTotal.value), valueNum: ppvTotal.value, icon: 'mdi-chart-scatter-plot', color: ppvTotal.value > 0 ? 'error' : 'success', invertDelta: true, hint: 'Actual vs agreed' },
    { title: 'Single-sourced', value: String(singleSourced.value.length), valueNum: singleSourced.value.length, icon: 'mdi-source-branch-minus', color: 'deep-orange', invertDelta: true, hint: 'No price competition' },
    { title: 'Average spread', value: `${multiSourced.value.length ? mean(multiSourced.value.map((m) => m.spreadPct)).toFixed(1) : '0'}%`, icon: 'mdi-arrow-expand-horizontal', color: 'purple', hint: 'Between best and worst' }
  ]
})

function exportBenchmarks() {
  downloadCsv(
    'price-benchmarks',
    ['item', 'supplierCount', 'best', 'bestSupplier', 'worst', 'worstSupplier', 'avg', 'savingPerUnit', 'spreadPct'],
    filteredBenchmarks.value.map((r) => ({
      ...r,
      avg: round(r.avg, 2),
      savingPerUnit: round(r.savingPerUnit, 2),
      spreadPct: round(r.spreadPct, 2)
    }))
  )
}
</script>
