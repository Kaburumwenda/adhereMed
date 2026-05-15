<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" variant="text" to="/analytics" class="mr-2" />
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">{{ $t('analyticsProducts.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">{{ rangeLabel }} · {{ allProducts.length }} products sold · {{ allStocks.length }} in catalog</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-select
          v-if="branchStore.hasBranches"
          v-model="branchFilter"
          :items="branchFilterItems"
          item-title="name"
          item-value="id"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-store-marker"
          style="min-width: 180px"
        />
        <v-select
          v-model="rangeKey"
          :items="rangeOptions"
          item-title="label"
          item-value="key"
          density="compact"
          variant="outlined"
          color="primary"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-calendar-range"
          style="min-width: 220px"
          @update:model-value="onRangeChange"
        />
        <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-download" @click="exportCsv">Export</v-btn>
      </div>
    </div>

    <!-- Custom range dialog -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom date range</v-card-title>
        <v-card-text>
          <v-text-field v-model="customStart" label="Start date" type="date" variant="outlined" density="compact" hide-details class="mb-3" />
          <v-text-field v-model="customEnd" label="End date" type="date" variant="outlined" density="compact" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="flat" class="text-none" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- KPIs -->
    <v-row dense>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="primary" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-package-variant</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Products sold</div>
        </div>
        <div class="text-h5 font-weight-bold">{{ allProducts.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="info" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-counter</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Total units</div>
        </div>
        <div class="text-h5 font-weight-bold">{{ totalUnits.toLocaleString() }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="success" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-cash-multiple</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Total revenue</div>
        </div>
        <div class="text-h5 font-weight-bold text-success">{{ formatMoney(totalRevenue) }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="warning" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-speedometer-slow</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Slow moving</div>
        </div>
        <div class="text-h5 font-weight-bold text-warning">{{ slowMovingProducts.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="error" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-sleep</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Never sold</div>
        </div>
        <div class="text-h5 font-weight-bold text-error">{{ neverSoldProducts.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="teal" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-chart-line</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Avg / product</div>
        </div>
        <div class="text-h5 font-weight-bold">{{ formatMoney(allProducts.length ? totalRevenue / allProducts.length : 0) }}</div>
      </v-card></v-col>
    </v-row>

    <!-- Analysis view tabs -->
    <v-card rounded="lg" class="mt-4" border>
      <v-tabs v-model="analysisTab" color="primary" density="compact" class="border-b">
        <v-tab value="abc" prepend-icon="mdi-sort-alphabetical-variant" class="text-none">{{ $t('analyticsProducts.abcAnalysis') }}</v-tab>
        <v-tab value="top" prepend-icon="mdi-trophy" class="text-none">Products</v-tab>
        <v-tab value="slow" prepend-icon="mdi-speedometer-slow" class="text-none">
          Slow Moving
          <v-chip v-if="slowMovingProducts.length" size="x-small" color="warning" variant="tonal" class="ml-2">{{ slowMovingProducts.length }}</v-chip>
        </v-tab>
        <v-tab value="never" prepend-icon="mdi-sleep" class="text-none">
          Never Sold
          <v-chip v-if="neverSoldProducts.length" size="x-small" color="error" variant="tonal" class="ml-2">{{ neverSoldProducts.length }}</v-chip>
        </v-tab>
        <v-tab value="dead" prepend-icon="mdi-archive-alert" class="text-none">
          Dead Stock
          <v-chip v-if="deadStockProducts.length" size="x-small" color="red-darken-2" variant="tonal" class="ml-2">{{ deadStockProducts.length }}</v-chip>
        </v-tab>
      </v-tabs>

      <div class="pa-4">
        <!-- ===================== TOP PRODUCTS ===================== -->
        <template v-if="analysisTab === 'top'">
          <!-- Top 20 chart -->
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">Top 20 by {{ sortBy }}</h3>
            <v-btn-toggle v-model="sortBy" density="compact" mandatory variant="outlined" color="primary" rounded="lg">
              <v-btn value="revenue" class="text-none" size="small">Revenue</v-btn>
              <v-btn value="qty" class="text-none" size="small">Quantity</v-btn>
              <v-btn value="orders" class="text-none" size="small">Orders</v-btn>
            </v-btn-toggle>
          </div>
          <div v-if="topTenChart.values.length" style="overflow-x: auto; -webkit-overflow-scrolling: touch">
            <div :style="{ minWidth: topTenChart.values.length > 12 ? topTenChart.values.length * 60 + 'px' : '100%' }">
              <BarChart
                :values="topTenChart.values"
                :labels="topTenChart.labels"
                :colors="topTenChart.colors"
                :height="420"
                rotate-labels
              />
            </div>
          </div>
          <EmptyState v-else icon="mdi-package-variant-closed" title="No sales in this period" />

          <!-- Filters + table -->
          <div class="d-flex flex-wrap align-center mb-3 mt-5" style="gap:8px">
            <v-text-field
              v-model="search"
              placeholder="Search product…"
              prepend-inner-icon="mdi-magnify"
              density="compact"
              variant="outlined"
              hide-details
              clearable
              style="min-width: 240px; max-width: 360px"
            />
            <v-select
              v-model="categoryFilter"
              :items="categoryFilterOptions"
              item-title="label"
              item-value="value"
              density="compact"
              variant="outlined"
              hide-details
              style="min-width: 200px; max-width: 240px"
              prepend-inner-icon="mdi-tag"
            />
            <v-spacer />
            <div class="text-body-2 text-medium-emphasis">{{ filteredProducts.length }} of {{ allProducts.length }}</div>
          </div>

          <EmptyState v-if="!filteredProducts.length" icon="mdi-magnify" title="No products match" />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Product</th>
                <th>Category</th>
                <th class="text-right cursor-pointer" @click="setSort('qty')">
                  Qty
                  <v-icon v-if="sortBy === 'qty'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right cursor-pointer" @click="setSort('orders')">
                  Orders
                  <v-icon v-if="sortBy === 'orders'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right cursor-pointer" @click="setSort('revenue')">
                  Revenue
                  <v-icon v-if="sortBy === 'revenue'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right">Avg. price</th>
                <th style="width:25%">Share of revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in pagedProducts" :key="p.name">
                <td class="text-medium-emphasis">{{ (page - 1) * pageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:240px">{{ p.name }}</td>
                <td>
                  <v-chip size="x-small" variant="tonal" color="primary">{{ p.category }}</v-chip>
                </td>
                <td class="text-right">{{ p.qty }}</td>
                <td class="text-right">{{ p.orders }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(p.revenue) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(p.avgPrice) }}</td>
                <td>
                  <div class="d-flex align-center" style="gap:8px">
                    <v-progress-linear :model-value="p.share" :color="barColors[i % barColors.length]" height="6" rounded style="flex:1" />
                    <span class="text-caption text-medium-emphasis" style="min-width:38px; text-align:right">{{ p.share.toFixed(1) }}%</span>
                  </div>
                </td>
              </tr>
            </tbody>
          </v-table>

          <div v-if="filteredProducts.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="page" :length="Math.ceil(filteredProducts.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== SLOW MOVING ===================== -->
        <template v-if="analysisTab === 'slow'">
          <div class="d-flex align-center mb-3">
            <v-icon color="warning" class="mr-2">mdi-speedometer-slow</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Slow Moving Products</div>
              <div class="text-caption text-medium-emphasis">Products sold ≤ {{ slowThreshold }} units in {{ rangeLabel }}. These items have stock but rarely sell.</div>
            </div>
            <v-spacer />
            <v-text-field
              v-model.number="slowThreshold"
              label="Max qty threshold"
              type="number"
              min="1"
              density="compact"
              variant="outlined"
              hide-details
              style="max-width: 160px"
            />
          </div>

          <v-alert v-if="slowMovingProducts.length" type="warning" variant="tonal" density="compact" class="mb-3" icon="mdi-lightbulb">
            Consider running promotions, bundling, or discounting these {{ slowMovingProducts.length }} slow-moving items to free up capital.
            Tied-up cost: <strong>{{ formatMoney(slowStockValue) }}</strong>
          </v-alert>

          <EmptyState v-if="!slowMovingProducts.length" icon="mdi-check-circle" title="No slow-moving products" message="All stocked products are selling well." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Product</th>
                <th>Category</th>
                <th class="text-right">Stock on hand</th>
                <th class="text-right">Units sold</th>
                <th class="text-right">Revenue</th>
                <th class="text-right">Stock value (cost)</th>
                <th class="text-right">Days of stock</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in slowMovingPaged" :key="p.id">
                <td class="text-medium-emphasis">{{ (slowPage - 1) * pageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:240px">{{ p.name }}</td>
                <td><v-chip size="x-small" variant="tonal" color="primary">{{ p.category }}</v-chip></td>
                <td class="text-right">{{ p.stock }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="p.qtySold > 0 ? 'warning' : 'error'" variant="tonal">{{ p.qtySold }}</v-chip>
                </td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(p.revenue) }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(p.stockCostValue) }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="p.daysOfStock > 180 ? 'error' : p.daysOfStock > 90 ? 'warning' : 'info'" variant="tonal">
                    {{ p.daysOfStock === Infinity ? '∞' : p.daysOfStock + 'd' }}
                  </v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="slowMovingProducts.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="slowPage" :length="Math.ceil(slowMovingProducts.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== NEVER SOLD ===================== -->
        <template v-if="analysisTab === 'never'">
          <div class="d-flex align-center mb-3">
            <v-icon color="error" class="mr-2">mdi-sleep</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Never Sold Products</div>
              <div class="text-caption text-medium-emphasis">Items in your inventory catalog that have never appeared in any POS transaction (all time).</div>
            </div>
          </div>

          <v-alert v-if="neverSoldProducts.length" type="error" variant="tonal" density="compact" class="mb-3" icon="mdi-alert">
            {{ neverSoldProducts.length }} products have never been sold. Total capital locked: <strong>{{ formatMoney(neverSoldCostValue) }}</strong>.
            Consider returning to supplier, discounting heavily, or removing from catalog.
          </v-alert>

          <EmptyState v-if="!neverSoldProducts.length" icon="mdi-check-circle" title="All products have been sold" message="Every item in your catalog has at least one sale." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Product</th>
                <th>Category</th>
                <th class="text-right">Stock on hand</th>
                <th class="text-right">Cost price</th>
                <th class="text-right">Selling price</th>
                <th class="text-right">Stock value (cost)</th>
                <th>Added</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in neverSoldPaged" :key="p.id">
                <td class="text-medium-emphasis">{{ (neverPage - 1) * pageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:240px">{{ p.name }}</td>
                <td><v-chip size="x-small" variant="tonal" color="primary">{{ p.category }}</v-chip></td>
                <td class="text-right">{{ p.stock }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(p.costPrice) }}</td>
                <td class="text-right">{{ formatMoney(p.sellingPrice) }}</td>
                <td class="text-right font-weight-bold text-error">{{ formatMoney(p.stockCostValue) }}</td>
                <td class="text-medium-emphasis">{{ formatDate(p.createdAt) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="neverSoldProducts.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="neverPage" :length="Math.ceil(neverSoldProducts.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== ABC ANALYSIS ===================== -->
        <template v-if="analysisTab === 'abc'">
          <div class="d-flex align-center mb-3">
            <v-icon color="primary" class="mr-2">mdi-sort-alphabetical-variant</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">ABC Analysis (Pareto)</div>
              <div class="text-caption text-medium-emphasis">
                <strong>A</strong> = top 80% revenue · <strong>B</strong> = next 15% · <strong>C</strong> = bottom 5%. Focus resources on A items.
              </div>
            </div>
          </div>

          <v-row dense class="mb-4">
            <v-col v-for="g in abcSummary" :key="g.grade" cols="12" md="4">
              <v-card
                rounded="lg"
                border
                class="pa-4 cursor-pointer"
                :variant="abcFilter === g.grade ? 'tonal' : 'flat'"
                :color="abcFilter === g.grade ? g.color : undefined"
                @click="abcFilter = abcFilter === g.grade ? null : g.grade; abcPage = 1"
              >
                <div class="d-flex align-center mb-2">
                  <v-avatar :color="g.color" size="36" class="mr-3">
                    <span class="text-h6 font-weight-bold text-white">{{ g.grade }}</span>
                  </v-avatar>
                  <div>
                    <div class="text-subtitle-2 font-weight-bold">Class {{ g.grade }}</div>
                    <div class="text-caption text-medium-emphasis">{{ g.description }}</div>
                  </div>
                  <v-spacer />
                  <v-icon v-if="abcFilter === g.grade" :color="g.color" size="20">mdi-filter-check</v-icon>
                </div>
                <v-row dense>
                  <v-col cols="4" class="text-center">
                    <div class="text-h6 font-weight-bold">{{ g.count }}</div>
                    <div class="text-caption text-medium-emphasis">Products</div>
                  </v-col>
                  <v-col cols="4" class="text-center">
                    <div class="text-h6 font-weight-bold">{{ formatMoney(g.revenue) }}</div>
                    <div class="text-caption text-medium-emphasis">Revenue</div>
                  </v-col>
                  <v-col cols="4" class="text-center">
                    <div class="text-h6 font-weight-bold">{{ g.pct.toFixed(1) }}%</div>
                    <div class="text-caption text-medium-emphasis">of total</div>
                  </v-col>
                </v-row>
              </v-card>
            </v-col>
          </v-row>

          <v-chip v-if="abcFilter" closable color="primary" variant="tonal" class="mb-3" @click:close="abcFilter = null; abcPage = 1">
            Showing Class {{ abcFilter }} only
          </v-chip>

          <v-table density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Product</th>
                <th>Category</th>
                <th class="text-right">Revenue</th>
                <th class="text-right">Cumulative %</th>
                <th style="width:80px" class="text-center">Grade</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in abcPaged" :key="p.name">
                <td class="text-medium-emphasis">{{ (abcPage - 1) * pageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:240px">{{ p.name }}</td>
                <td><v-chip size="x-small" variant="tonal" color="primary">{{ p.category }}</v-chip></td>
                <td class="text-right font-weight-medium">{{ formatMoney(p.revenue) }}</td>
                <td class="text-right">
                  <v-progress-linear :model-value="p.cumulativePct" :color="p.gradeColor" height="6" rounded style="max-width: 120px; display: inline-flex" />
                  <span class="text-caption ml-2">{{ p.cumulativePct.toFixed(1) }}%</span>
                </td>
                <td class="text-center">
                  <v-chip :color="p.gradeColor" size="small" variant="flat">{{ p.grade }}</v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="abcFiltered.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="abcPage" :length="Math.ceil(abcFiltered.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== DEAD STOCK ===================== -->
        <template v-if="analysisTab === 'dead'">
          <div class="d-flex align-center mb-3">
            <v-icon color="red-darken-2" class="mr-2">mdi-archive-alert</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">{{ $t('analyticsProducts.deadStock') }}</div>
              <div class="text-caption text-medium-emphasis">Items with stock on hand but zero sales in the selected period. Capital sitting idle on shelves.</div>
            </div>
          </div>

          <v-alert v-if="deadStockProducts.length" type="error" variant="tonal" density="compact" class="mb-3" icon="mdi-currency-usd-off">
            {{ deadStockProducts.length }} items have stock but zero sales in {{ rangeLabel }}.
            Idle capital: <strong>{{ formatMoney(deadStockValue) }}</strong>
          </v-alert>

          <EmptyState v-if="!deadStockProducts.length" icon="mdi-check-circle" title="No dead stock" message="All stocked items had sales in this period." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Product</th>
                <th>Category</th>
                <th class="text-right">Stock on hand</th>
                <th class="text-right">Cost price</th>
                <th class="text-right">Stock value (cost)</th>
                <th class="text-right">Selling price</th>
                <th class="text-right">Potential revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in deadStockPaged" :key="p.id">
                <td class="text-medium-emphasis">{{ (deadPage - 1) * pageSize + i + 1 }}</td>
                <td class="font-weight-medium text-truncate" style="max-width:240px">{{ p.name }}</td>
                <td><v-chip size="x-small" variant="tonal" color="primary">{{ p.category }}</v-chip></td>
                <td class="text-right">{{ p.stock }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(p.costPrice) }}</td>
                <td class="text-right font-weight-bold text-error">{{ formatMoney(p.stockCostValue) }}</td>
                <td class="text-right">{{ formatMoney(p.sellingPrice) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(p.potentialRevenue) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="deadStockProducts.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="deadPage" :length="Math.ceil(deadStockProducts.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const branchFilter = ref(null)
const branchFilterItems = computed(() => {
  const items = branchStore.activeBranches.map(b => ({ id: b.id, name: b.name }))
  items.unshift({ id: null, name: 'All Branches' })
  return items
})

const loading = ref(false)
const txAll = ref([])
const allStocks = ref([])
const search = ref('')
const sortBy = ref('revenue')
const categoryFilter = ref('all')
const page = ref(1)
const slowPage = ref(1)
const neverPage = ref(1)
const abcPage = ref(1)
const deadPage = ref(1)
const pageSize = 25
const analysisTab = ref('abc')
const slowThreshold = ref(3)
const abcFilter = ref(null)

const barColors = ['#3b82f6', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4', '#ef4444', '#14b8a6']

// --- range picker (shared logic) ---
const rangeKey = ref('30d')
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')
const customRange = ref(null)

const rangeOptions = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'thisMonth', label: 'This month' },
  { key: 'lastMonth', label: 'Last month' },
  { key: 'thisYear', label: 'This year' },
  { key: 'lastYear', label: 'Last year' },
  { key: '1y', label: 'Last 365 days' },
  { key: 'custom', label: 'Custom range…' }
]

function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
function addDays(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x }

function resolveRange(key) {
  const t = startOfDay(new Date())
  const tomorrow = addDays(t, 1)
  switch (key) {
    case 'today': return { start: t, end: tomorrow, label: 'Today' }
    case 'yesterday': return { start: addDays(t, -1), end: t, label: 'Yesterday' }
    case '7d': return { start: addDays(t, -6), end: tomorrow, label: 'Last 7 days' }
    case '30d': return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
    case '90d': return { start: addDays(t, -89), end: tomorrow, label: 'Last 90 days' }
    case '1y': return { start: addDays(t, -364), end: tomorrow, label: 'Last 365 days' }
    case 'thisMonth': return { start: new Date(t.getFullYear(), t.getMonth(), 1), end: tomorrow, label: 'This month' }
    case 'lastMonth': return { start: new Date(t.getFullYear(), t.getMonth() - 1, 1), end: new Date(t.getFullYear(), t.getMonth(), 1), label: 'Last month' }
    case 'thisYear': return { start: new Date(t.getFullYear(), 0, 1), end: tomorrow, label: 'This year' }
    case 'lastYear': return { start: new Date(t.getFullYear() - 1, 0, 1), end: new Date(t.getFullYear(), 0, 1), label: 'Last year' }
    case 'custom': return customRange.value || { start: addDays(t, -29), end: tomorrow, label: 'Custom' }
    default: return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
  }
}

const activeRange = computed(() => resolveRange(rangeKey.value))
const rangeStart = computed(() => activeRange.value.start)
const rangeEnd = computed(() => activeRange.value.end)
const rangeLabel = computed(() => activeRange.value.label)
const rangeDays = computed(() => Math.max(1, Math.round((rangeEnd.value - rangeStart.value) / 86400000)))

function onRangeChange(val) {
  if (val === 'custom') {
    if (!customStart.value) customStart.value = rangeStart.value.toISOString().slice(0, 10)
    if (!customEnd.value) customEnd.value = addDays(rangeEnd.value, -1).toISOString().slice(0, 10)
    customDialog.value = true
  }
}
function applyCustom() {
  const s = startOfDay(new Date(customStart.value))
  const e = addDays(startOfDay(new Date(customEnd.value)), 1)
  if (e <= s) return
  const fmt = (d) => d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
  customRange.value = { start: s, end: e, label: `${fmt(s)} – ${fmt(addDays(e, -1))}` }
  rangeKey.value = 'custom'
  customDialog.value = false
}

function formatDate(d) {
  if (!d) return '—'
  try { return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) } catch { return '—' }
}

// --- aggregation ---
const inRange = computed(() => txAll.value.filter(t => {
  const d = new Date(t.created_at || t.date || 0)
  if (d < rangeStart.value || d >= rangeEnd.value) return false
  if (branchFilter.value != null && t.branch !== branchFilter.value) return false
  return true
}))

const allProducts = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    const orderProductSet = new Set()
    for (const it of (t.items || [])) {
      const name = it.product_name || it.name || it.medication_name || 'Item'
      const qty = Number(it.quantity || 1)
      const rev = Number(it.total || it.subtotal || (it.unit_price * qty) || 0)
      const cat = it.category_name || it.category || 'Uncategorized'
      const stockId = it.stock || it.stock_id || null
      const cur = map.get(name) || { name, qty: 0, revenue: 0, orders: 0, category: cat, stockId }
      cur.qty += qty
      cur.revenue += rev
      if (!orderProductSet.has(name)) {
        cur.orders += 1
        orderProductSet.add(name)
      }
      map.set(name, cur)
    }
  }
  const total = [...map.values()].reduce((s, p) => s + p.revenue, 0) || 1
  return [...map.values()].map(p => ({
    ...p,
    avgPrice: p.qty ? p.revenue / p.qty : 0,
    share: (p.revenue / total) * 100
  }))
})

// Build lookup of sold product names (all time) for never-sold detection
const allTimeSoldNames = computed(() => {
  const names = new Set()
  for (const t of txAll.value) {
    for (const it of (t.items || [])) {
      const name = it.product_name || it.name || it.medication_name || ''
      if (name) names.add(name.toLowerCase())
    }
  }
  return names
})

// Sold stock IDs in range
const soldStockIdsInRange = computed(() => {
  const ids = new Set()
  for (const t of inRange.value) {
    for (const it of (t.items || [])) {
      const sid = it.stock || it.stock_id
      if (sid) ids.add(sid)
      const name = it.product_name || it.name || it.medication_name || ''
      if (name) ids.add(name.toLowerCase())
    }
  }
  return ids
})

// Sold names in range (for matching by name)
const soldNamesInRange = computed(() => {
  const map = new Map()
  for (const p of allProducts.value) {
    map.set(p.name.toLowerCase(), p)
  }
  return map
})

const totalRevenue = computed(() => allProducts.value.reduce((s, p) => s + p.revenue, 0))
const totalUnits = computed(() => allProducts.value.reduce((s, p) => s + p.qty, 0))

const categoryFilterOptions = computed(() => {
  const cats = [...new Set(allProducts.value.map(p => p.category))].sort()
  return [{ label: 'All categories', value: 'all' }, ...cats.map(c => ({ label: c, value: c }))]
})

const filteredProducts = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = allProducts.value
  if (categoryFilter.value !== 'all') arr = arr.filter(p => p.category === categoryFilter.value)
  if (q) arr = arr.filter(p => p.name.toLowerCase().includes(q))
  const key = sortBy.value
  return [...arr].sort((a, b) => b[key] - a[key])
})

const pagedProducts = computed(() => {
  const start = (page.value - 1) * pageSize
  return filteredProducts.value.slice(start, start + pageSize)
})

watch([search, categoryFilter, sortBy, rangeKey], () => { page.value = 1 })

const topTenChart = computed(() => {
  const top = [...allProducts.value].sort((a, b) => b[sortBy.value] - a[sortBy.value]).slice(0, 20)
  return {
    values: top.map(p => p[sortBy.value]),
    labels: top.map(p => p.name.length > 22 ? p.name.slice(0, 22) + '…' : p.name),
    colors: top.map((_, i) => barColors[i % barColors.length])
  }
})

function setSort(key) { sortBy.value = key }

// --- Slow moving products ---
const slowMovingProducts = computed(() => {
  return allStocks.value
    .filter(s => Number(s.total_quantity || 0) > 0)
    .map(s => {
      const sold = soldNamesInRange.value.get((s.medication_name || '').toLowerCase())
      const qtySold = sold ? sold.qty : 0
      const revenue = sold ? sold.revenue : 0
      const stock = Number(s.total_quantity || 0)
      const dailyRate = qtySold / rangeDays.value
      const daysOfStock = dailyRate > 0 ? Math.round(stock / dailyRate) : Infinity
      return {
        id: s.id,
        name: s.medication_name,
        category: s.category_name || 'Uncategorized',
        stock,
        qtySold,
        revenue,
        costPrice: Number(s.cost_price || 0),
        sellingPrice: Number(s.selling_price || 0),
        stockCostValue: stock * Number(s.cost_price || 0),
        daysOfStock,
      }
    })
    .filter(p => p.qtySold <= slowThreshold.value && p.qtySold >= 0)
    .sort((a, b) => a.qtySold - b.qtySold)
})

const slowStockValue = computed(() => slowMovingProducts.value.reduce((s, p) => s + p.stockCostValue, 0))
const slowMovingPaged = computed(() => {
  const start = (slowPage.value - 1) * pageSize
  return slowMovingProducts.value.slice(start, start + pageSize)
})

// --- Never sold products ---
const neverSoldProducts = computed(() => {
  return allStocks.value
    .filter(s => {
      const name = (s.medication_name || '').toLowerCase()
      return !allTimeSoldNames.value.has(name)
    })
    .map(s => ({
      id: s.id,
      name: s.medication_name,
      category: s.category_name || 'Uncategorized',
      stock: Number(s.total_quantity || 0),
      costPrice: Number(s.cost_price || 0),
      sellingPrice: Number(s.selling_price || 0),
      stockCostValue: Number(s.total_quantity || 0) * Number(s.cost_price || 0),
      createdAt: s.created_at,
    }))
    .sort((a, b) => b.stockCostValue - a.stockCostValue)
})

const neverSoldCostValue = computed(() => neverSoldProducts.value.reduce((s, p) => s + p.stockCostValue, 0))
const neverSoldPaged = computed(() => {
  const start = (neverPage.value - 1) * pageSize
  return neverSoldProducts.value.slice(start, start + pageSize)
})

// --- ABC Analysis ---
const abcProducts = computed(() => {
  const sorted = [...allProducts.value].sort((a, b) => b.revenue - a.revenue)
  const total = totalRevenue.value || 1
  let cumulative = 0
  return sorted.map(p => {
    cumulative += p.revenue
    const cumulativePct = (cumulative / total) * 100
    let grade, gradeColor
    if (cumulativePct <= 80) { grade = 'A'; gradeColor = 'success' }
    else if (cumulativePct <= 95) { grade = 'B'; gradeColor = 'warning' }
    else { grade = 'C'; gradeColor = 'error' }
    return { ...p, cumulativePct, grade, gradeColor }
  })
})

const abcSummary = computed(() => {
  const groups = { A: { grade: 'A', color: 'success', description: 'Top 80% revenue — vital few', count: 0, revenue: 0, pct: 0 },
                   B: { grade: 'B', color: 'warning', description: 'Next 15% revenue — useful many', count: 0, revenue: 0, pct: 0 },
                   C: { grade: 'C', color: 'error', description: 'Bottom 5% revenue — trivial many', count: 0, revenue: 0, pct: 0 } }
  const total = totalRevenue.value || 1
  abcProducts.value.forEach(p => {
    const g = groups[p.grade]
    g.count++
    g.revenue += p.revenue
  })
  Object.values(groups).forEach(g => { g.pct = (g.revenue / total) * 100 })
  return Object.values(groups)
})

const abcFiltered = computed(() => {
  if (!abcFilter.value) return abcProducts.value
  return abcProducts.value.filter(p => p.grade === abcFilter.value)
})

const abcPaged = computed(() => {
  const start = (abcPage.value - 1) * pageSize
  return abcFiltered.value.slice(start, start + pageSize)
})

// --- Dead stock (in stock but zero sales in period) ---
const deadStockProducts = computed(() => {
  return allStocks.value
    .filter(s => {
      const stock = Number(s.total_quantity || 0)
      if (stock <= 0) return false
      const name = (s.medication_name || '').toLowerCase()
      return !soldNamesInRange.value.has(name)
    })
    .map(s => {
      const stock = Number(s.total_quantity || 0)
      return {
        id: s.id,
        name: s.medication_name,
        category: s.category_name || 'Uncategorized',
        stock,
        costPrice: Number(s.cost_price || 0),
        sellingPrice: Number(s.selling_price || 0),
        stockCostValue: stock * Number(s.cost_price || 0),
        potentialRevenue: stock * Number(s.selling_price || 0),
      }
    })
    .sort((a, b) => b.stockCostValue - a.stockCostValue)
})

const deadStockValue = computed(() => deadStockProducts.value.reduce((s, p) => s + p.stockCostValue, 0))
const deadStockPaged = computed(() => {
  const start = (deadPage.value - 1) * pageSize
  return deadStockProducts.value.slice(start, start + pageSize)
})

function exportCsv() {
  const rows = [['Rank', 'Product', 'Category', 'Quantity', 'Orders', 'Revenue', 'Avg Price', 'Share %']]
  filteredProducts.value.forEach((p, i) => {
    rows.push([i + 1, p.name, p.category, p.qty, p.orders, p.revenue.toFixed(2), p.avgPrice.toFixed(2), p.share.toFixed(2)])
  })
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `product-analytics-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

async function load() {
  loading.value = true
  try {
    const [txRes, stockRes] = await Promise.allSettled([
      $api.get('/pos/transactions/?page_size=2000'),
      $api.get('/inventory/stocks/?page_size=1000'),
    ])
    txAll.value = txRes.status === 'fulfilled' ? (txRes.value.data?.results || (Array.isArray(txRes.value.data) ? txRes.value.data : [])) : []
    allStocks.value = stockRes.status === 'fulfilled' ? (stockRes.value.data?.results || (Array.isArray(stockRes.value.data) ? stockRes.value.data : [])) : []
  } catch {
    txAll.value = []
    allStocks.value = []
  }
  loading.value = false
}
onMounted(load)
</script>

<style scoped>
.cursor-pointer { cursor: pointer; user-select: none; }
</style>
