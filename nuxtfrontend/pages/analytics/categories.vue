<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" variant="text" to="/analytics" class="mr-2" />
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">Sales by category</h1>
          <div class="text-body-2 text-medium-emphasis">{{ rangeLabel }} · {{ allCategories.length }} categories sold · {{ stockByCategory.size }} in catalog</div>
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
          <v-avatar color="primary" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-tag-multiple</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Categories sold</div>
        </div>
        <div class="text-h5 font-weight-bold">{{ allCategories.length }}</div>
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
          <v-avatar color="info" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-counter</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Total units</div>
        </div>
        <div class="text-h5 font-weight-bold">{{ totalUnits.toLocaleString() }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="warning" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-speedometer-slow</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Slow moving</div>
        </div>
        <div class="text-h5 font-weight-bold text-warning">{{ slowMovingCategories.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="error" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-sleep</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Never sold</div>
        </div>
        <div class="text-h5 font-weight-bold text-error">{{ neverSoldCategories.length }}</div>
      </v-card></v-col>
      <v-col cols="6" md="2"><v-card rounded="lg" class="pa-4 h-100" border>
        <div class="d-flex align-center mb-1">
          <v-avatar color="teal" variant="tonal" size="32" class="mr-2"><v-icon size="16">mdi-trophy</v-icon></v-avatar>
          <div class="text-caption text-medium-emphasis">Top category</div>
        </div>
        <div class="text-h6 font-weight-bold text-truncate">{{ topCategory.name || '—' }}</div>
      </v-card></v-col>
    </v-row>

    <!-- Analysis view tabs -->
    <v-card rounded="lg" class="mt-4" border>
      <v-tabs v-model="analysisTab" color="primary" density="compact" class="border-b">
        <v-tab value="abc" prepend-icon="mdi-sort-alphabetical-variant" class="text-none">{{ $t('analyticsCategories.abcAnalysis') }}</v-tab>
        <v-tab value="categories" prepend-icon="mdi-tag-multiple" class="text-none">{{ $t('categoriesPage.title') }}</v-tab>
        <v-tab value="slow" prepend-icon="mdi-speedometer-slow" class="text-none">
          Slow Moving
          <v-chip v-if="slowMovingCategories.length" size="x-small" color="warning" variant="tonal" class="ml-2">{{ slowMovingCategories.length }}</v-chip>
        </v-tab>
        <v-tab value="never" prepend-icon="mdi-sleep" class="text-none">
          Never Sold
          <v-chip v-if="neverSoldCategories.length" size="x-small" color="error" variant="tonal" class="ml-2">{{ neverSoldCategories.length }}</v-chip>
        </v-tab>
        <v-tab value="dead" prepend-icon="mdi-archive-alert" class="text-none">
          Dead Stock
          <v-chip v-if="deadStockCategories.length" size="x-small" color="red-darken-2" variant="tonal" class="ml-2">{{ deadStockCategories.length }}</v-chip>
        </v-tab>
      </v-tabs>

      <div class="pa-4">
        <!-- ===================== ABC ANALYSIS ===================== -->
        <template v-if="analysisTab === 'abc'">
          <div class="d-flex align-center mb-3">
            <v-icon color="primary" class="mr-2">mdi-sort-alphabetical-variant</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">ABC Analysis (Pareto)</div>
              <div class="text-caption text-medium-emphasis">
                <strong>A</strong> = top 80% revenue · <strong>B</strong> = next 15% · <strong>C</strong> = bottom 5%. Focus resources on A categories.
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
                    <div class="text-caption text-medium-emphasis">{{ $t('categoriesPage.title') }}</div>
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
                <th>Category</th>
                <th class="text-right">Products</th>
                <th class="text-right">Revenue</th>
                <th class="text-right">Cumulative %</th>
                <th style="width:80px" class="text-center">Grade</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(c, i) in abcPaged" :key="c.name">
                <td class="text-medium-emphasis">{{ (abcPage - 1) * pageSize + i + 1 }}</td>
                <td>
                  <v-chip size="small" variant="tonal" :color="c.gradeColor" class="font-weight-medium">{{ c.name }}</v-chip>
                </td>
                <td class="text-right">{{ c.products }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(c.revenue) }}</td>
                <td class="text-right">
                  <v-progress-linear :model-value="c.cumulativePct" :color="c.gradeColor" height="6" rounded style="max-width: 120px; display: inline-flex" />
                  <span class="text-caption ml-2">{{ c.cumulativePct.toFixed(1) }}%</span>
                </td>
                <td class="text-center">
                  <v-chip :color="c.gradeColor" size="small" variant="flat">{{ c.grade }}</v-chip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="abcFiltered.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="abcPage" :length="Math.ceil(abcFiltered.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== CATEGORIES (existing view) ===================== -->
        <template v-if="analysisTab === 'categories'">
          <!-- Donut + Bar -->
          <v-row class="mt-1">
            <v-col cols="12" lg="5">
              <v-card rounded="lg" class="pa-4 h-100" variant="flat">
                <h3 class="text-h6 font-weight-bold mb-3">Revenue distribution</h3>
                <EmptyState v-if="!donutSegments.length" icon="mdi-tag-multiple" title="No category sales" />
                <div v-else class="d-flex flex-column align-center">
                  <DonutRing :segments="donutSegments" :size="240" :thickness="22">
                    <div class="text-center">
                      <div class="text-caption text-medium-emphasis">{{ $t('common.total') }}</div>
                      <div class="text-h6 font-weight-bold">{{ formatMoney(totalRevenue) }}</div>
                    </div>
                  </DonutRing>
                  <div class="mt-4 w-100">
                    <div v-for="s in donutSegments" :key="s.label" class="d-flex align-center mb-2">
                      <span class="legend-dot" :style="{ background: s.color }"></span>
                      <span class="text-body-2 ml-2 flex-grow-1 text-truncate">{{ s.label }}</span>
                      <span class="text-body-2 font-weight-medium">{{ formatMoney(s.value) }}</span>
                      <span class="text-caption text-medium-emphasis ml-2" style="min-width:38px;text-align:right">{{ s.pct.toFixed(1) }}%</span>
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
            <v-col cols="12" lg="7">
              <v-card rounded="lg" class="pa-4 h-100" variant="flat">
                <div class="d-flex align-center justify-space-between mb-3">
                  <h3 class="text-h6 font-weight-bold">Top categories by {{ chartMetric }}</h3>
                  <v-btn-toggle v-model="chartMetric" density="compact" mandatory variant="outlined" color="primary" rounded="lg">
                    <v-btn value="revenue" class="text-none" size="small">Revenue</v-btn>
                    <v-btn value="qty" class="text-none" size="small">Qty</v-btn>
                    <v-btn value="orders" class="text-none" size="small">Orders</v-btn>
                  </v-btn-toggle>
                </div>
                <BarChart
                  v-if="chartData.values.length"
                  :values="chartData.values"
                  :labels="chartData.labels"
                  :colors="chartData.colors"
                  :height="320"
                  rotate-labels
                />
                <EmptyState v-else icon="mdi-chart-bar" title="No data" />
              </v-card>
            </v-col>
          </v-row>

          <!-- Detailed table -->
          <div class="d-flex flex-wrap align-center mb-3 mt-5" style="gap:8px">
            <h3 class="text-h6 font-weight-bold">Category breakdown</h3>
            <v-spacer />
            <v-text-field
              v-model="search"
              placeholder="Search category…"
              prepend-inner-icon="mdi-magnify"
              density="compact"
              variant="outlined"
              hide-details
              clearable
              style="min-width: 240px; max-width: 320px"
            />
          </div>
          <EmptyState v-if="!filteredCategories.length" icon="mdi-magnify" title="No categories match" />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Category</th>
                <th class="text-right cursor-pointer" @click="sortBy = 'products'">
                  Products
                  <v-icon v-if="sortBy === 'products'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right cursor-pointer" @click="sortBy = 'qty'">
                  Qty
                  <v-icon v-if="sortBy === 'qty'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right cursor-pointer" @click="sortBy = 'orders'">
                  Orders
                  <v-icon v-if="sortBy === 'orders'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right cursor-pointer" @click="sortBy = 'revenue'">
                  Revenue
                  <v-icon v-if="sortBy === 'revenue'" size="14">mdi-arrow-down</v-icon>
                </th>
                <th class="text-right">Avg. order</th>
                <th style="width:25%">Share</th>
                <th style="width:60px"></th>
              </tr>
            </thead>
            <tbody>
              <template v-for="(c, i) in filteredCategories" :key="c.name">
                <tr>
                  <td class="text-medium-emphasis">{{ i + 1 }}</td>
                  <td>
                    <v-chip size="small" variant="tonal" :color="catColor(i)" class="font-weight-medium">{{ c.name }}</v-chip>
                  </td>
                  <td class="text-right">{{ c.products }}</td>
                  <td class="text-right">{{ c.qty }}</td>
                  <td class="text-right">{{ c.orders }}</td>
                  <td class="text-right font-weight-medium">{{ formatMoney(c.revenue) }}</td>
                  <td class="text-right text-medium-emphasis">{{ formatMoney(c.avgOrder) }}</td>
                  <td>
                    <div class="d-flex align-center" style="gap:8px">
                      <v-progress-linear :model-value="c.share" :color="catColor(i)" height="6" rounded style="flex:1" />
                      <span class="text-caption text-medium-emphasis" style="min-width:42px;text-align:right">{{ c.share.toFixed(1) }}%</span>
                    </div>
                  </td>
                  <td>
                    <v-btn
                      :icon="expanded === c.name ? 'mdi-chevron-up' : 'mdi-chevron-down'"
                      size="small" variant="text"
                      @click="expanded = expanded === c.name ? null : c.name"
                    />
                  </td>
                </tr>
                <tr v-if="expanded === c.name" class="expanded-row">
                  <td colspan="9" class="pa-4">
                    <div class="text-subtitle-2 font-weight-bold mb-2">Top products in {{ c.name }}</div>
                    <v-table density="compact" class="bg-transparent">
                      <thead>
                        <tr>
                          <th>Product</th>
                          <th class="text-right">Qty</th>
                          <th class="text-right">Revenue</th>
                          <th class="text-right">Share of category</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="p in c.products_list.slice(0, 10)" :key="p.name">
                          <td class="font-weight-medium">{{ p.name }}</td>
                          <td class="text-right">{{ p.qty }}</td>
                          <td class="text-right">{{ formatMoney(p.revenue) }}</td>
                          <td class="text-right text-medium-emphasis">{{ ((p.revenue / c.revenue) * 100).toFixed(1) }}%</td>
                        </tr>
                      </tbody>
                    </v-table>
                  </td>
                </tr>
              </template>
            </tbody>
          </v-table>
        </template>

        <!-- ===================== SLOW MOVING ===================== -->
        <template v-if="analysisTab === 'slow'">
          <div class="d-flex align-center mb-3">
            <v-icon color="warning" class="mr-2">mdi-speedometer-slow</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Slow Moving Categories</div>
              <div class="text-caption text-medium-emphasis">Categories with total units sold ≤ {{ slowThreshold }} in {{ rangeLabel }}. These categories have stock but rarely sell.</div>
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

          <v-alert v-if="slowMovingCategories.length" type="warning" variant="tonal" density="compact" class="mb-3" icon="mdi-lightbulb">
            Consider running promotions or bundling products from these {{ slowMovingCategories.length }} slow-moving categories to free up capital.
            Tied-up cost: <strong>{{ formatMoney(slowCatStockValue) }}</strong>
          </v-alert>

          <EmptyState v-if="!slowMovingCategories.length" icon="mdi-check-circle" title="No slow-moving categories" message="All stocked categories are selling well." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Category</th>
                <th class="text-right">Products in stock</th>
                <th class="text-right">Total stock</th>
                <th class="text-right">Units sold</th>
                <th class="text-right">Revenue</th>
                <th class="text-right">Stock value (cost)</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(c, i) in slowCatPaged" :key="c.name">
                <td class="text-medium-emphasis">{{ (slowPage - 1) * pageSize + i + 1 }}</td>
                <td>
                  <v-chip size="small" variant="tonal" color="warning" class="font-weight-medium">{{ c.name }}</v-chip>
                </td>
                <td class="text-right">{{ c.productCount }}</td>
                <td class="text-right">{{ c.totalStock }}</td>
                <td class="text-right">
                  <v-chip size="x-small" :color="c.qtySold > 0 ? 'warning' : 'error'" variant="tonal">{{ c.qtySold }}</v-chip>
                </td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(c.revenue) }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(c.stockCostValue) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="slowMovingCategories.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="slowPage" :length="Math.ceil(slowMovingCategories.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== NEVER SOLD ===================== -->
        <template v-if="analysisTab === 'never'">
          <div class="d-flex align-center mb-3">
            <v-icon color="error" class="mr-2">mdi-sleep</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Never Sold Categories</div>
              <div class="text-caption text-medium-emphasis">Inventory categories that have never appeared in any POS transaction (all time).</div>
            </div>
          </div>

          <v-alert v-if="neverSoldCategories.length" type="error" variant="tonal" density="compact" class="mb-3" icon="mdi-alert">
            {{ neverSoldCategories.length }} categories have never been sold. Total capital locked: <strong>{{ formatMoney(neverSoldCatValue) }}</strong>.
            Consider returning to supplier, discounting, or removing from catalog.
          </v-alert>

          <EmptyState v-if="!neverSoldCategories.length" icon="mdi-check-circle" title="All categories have sales" message="Every category in your catalog has at least one sale." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Category</th>
                <th class="text-right">Products</th>
                <th class="text-right">Total stock</th>
                <th class="text-right">Stock value (cost)</th>
                <th class="text-right">Potential revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(c, i) in neverSoldCatPaged" :key="c.name">
                <td class="text-medium-emphasis">{{ (neverPage - 1) * pageSize + i + 1 }}</td>
                <td>
                  <v-chip size="small" variant="tonal" color="error" class="font-weight-medium">{{ c.name }}</v-chip>
                </td>
                <td class="text-right">{{ c.productCount }}</td>
                <td class="text-right">{{ c.totalStock }}</td>
                <td class="text-right font-weight-bold text-error">{{ formatMoney(c.stockCostValue) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(c.potentialRevenue) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="neverSoldCategories.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="neverPage" :length="Math.ceil(neverSoldCategories.length / pageSize)" rounded="lg" density="compact" />
          </div>
        </template>

        <!-- ===================== DEAD STOCK ===================== -->
        <template v-if="analysisTab === 'dead'">
          <div class="d-flex align-center mb-3">
            <v-icon color="red-darken-2" class="mr-2">mdi-archive-alert</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Dead Stock Categories</div>
              <div class="text-caption text-medium-emphasis">Categories with stock on hand but zero sales in the selected period. Capital sitting idle on shelves.</div>
            </div>
          </div>

          <v-alert v-if="deadStockCategories.length" type="error" variant="tonal" density="compact" class="mb-3" icon="mdi-currency-usd-off">
            {{ deadStockCategories.length }} categories have stock but zero sales in {{ rangeLabel }}.
            Idle capital: <strong>{{ formatMoney(deadStockCatValue) }}</strong>
          </v-alert>

          <EmptyState v-if="!deadStockCategories.length" icon="mdi-check-circle" title="No dead stock" message="All stocked categories had sales in this period." />
          <v-table v-else density="comfortable" hover class="bg-transparent">
            <thead>
              <tr>
                <th style="width:48px">#</th>
                <th>Category</th>
                <th class="text-right">Products</th>
                <th class="text-right">Total stock</th>
                <th class="text-right">Stock value (cost)</th>
                <th class="text-right">Potential revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(c, i) in deadStockCatPaged" :key="c.name">
                <td class="text-medium-emphasis">{{ (deadPage - 1) * pageSize + i + 1 }}</td>
                <td>
                  <v-chip size="small" variant="tonal" color="red-darken-2" class="font-weight-medium">{{ c.name }}</v-chip>
                </td>
                <td class="text-right">{{ c.productCount }}</td>
                <td class="text-right">{{ c.totalStock }}</td>
                <td class="text-right font-weight-bold text-error">{{ formatMoney(c.stockCostValue) }}</td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(c.potentialRevenue) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-if="deadStockCategories.length > pageSize" class="d-flex justify-center mt-3">
            <v-pagination v-model="deadPage" :length="Math.ceil(deadStockCategories.length / pageSize)" rounded="lg" density="compact" />
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
const chartMetric = ref('revenue')
const expanded = ref(null)
const analysisTab = ref('abc')
const abcFilter = ref(null)
const abcPage = ref(1)
const slowPage = ref(1)
const neverPage = ref(1)
const deadPage = ref(1)
const pageSize = 25
const slowThreshold = ref(3)

const barColors = ['#3b82f6', '#22c55e', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4', '#ef4444', '#14b8a6', '#0ea5e9', '#f97316']
const chipColors = ['primary', 'success', 'warning', 'pink', 'purple', 'cyan', 'error', 'teal', 'info', 'orange']
function catColor(i) { return chipColors[i % chipColors.length] }

// --- range picker ---
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

// --- aggregation ---
const inRange = computed(() => txAll.value.filter(t => {
  const d = new Date(t.created_at || t.date || 0)
  if (d < rangeStart.value || d >= rangeEnd.value) return false
  if (branchFilter.value != null && t.branch !== branchFilter.value) return false
  return true
}))

const allCategories = computed(() => {
  const map = new Map()
  for (const t of inRange.value) {
    const seenInOrder = new Set()
    for (const it of (t.items || [])) {
      const cat = it.category_name || it.category || 'Uncategorized'
      const name = it.product_name || it.name || it.medication_name || 'Item'
      const qty = Number(it.quantity || 1)
      const rev = Number(it.total || it.subtotal || (it.unit_price * qty) || 0)
      if (!map.has(cat)) map.set(cat, { name: cat, qty: 0, revenue: 0, orders: 0, productMap: new Map() })
      const cur = map.get(cat)
      cur.qty += qty
      cur.revenue += rev
      if (!seenInOrder.has(cat)) {
        cur.orders += 1
        seenInOrder.add(cat)
      }
      const p = cur.productMap.get(name) || { name, qty: 0, revenue: 0 }
      p.qty += qty; p.revenue += rev
      cur.productMap.set(name, p)
    }
  }
  const arr = [...map.values()]
  const total = arr.reduce((s, c) => s + c.revenue, 0) || 1
  return arr.map(c => ({
    name: c.name,
    qty: c.qty,
    revenue: c.revenue,
    orders: c.orders,
    products: c.productMap.size,
    avgOrder: c.orders ? c.revenue / c.orders : 0,
    share: (c.revenue / total) * 100,
    products_list: [...c.productMap.values()].sort((a, b) => b.revenue - a.revenue)
  }))
})

const totalRevenue = computed(() => allCategories.value.reduce((s, c) => s + c.revenue, 0))
const totalUnits = computed(() => allCategories.value.reduce((s, c) => s + c.qty, 0))
const topCategory = computed(() => [...allCategories.value].sort((a, b) => b.revenue - a.revenue)[0] || {})

const filteredCategories = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = allCategories.value
  if (q) arr = arr.filter(c => c.name.toLowerCase().includes(q))
  const key = sortBy.value
  return [...arr].sort((a, b) => b[key] - a[key])
})

const donutSegments = computed(() => {
  const sorted = [...allCategories.value].sort((a, b) => b.revenue - a.revenue)
  const top = sorted.slice(0, 7)
  const rest = sorted.slice(7)
  const segments = top.map((c, i) => ({
    label: c.name,
    value: c.revenue,
    color: barColors[i % barColors.length],
    pct: c.share
  }))
  if (rest.length) {
    const restRev = rest.reduce((s, c) => s + c.revenue, 0)
    const restPct = rest.reduce((s, c) => s + c.share, 0)
    segments.push({ label: `Other (${rest.length})`, value: restRev, color: '#94a3b8', pct: restPct })
  }
  return segments
})

const chartData = computed(() => {
  const top = [...allCategories.value].sort((a, b) => b[chartMetric.value] - a[chartMetric.value]).slice(0, 10)
  return {
    values: top.map(c => c[chartMetric.value]),
    labels: top.map(c => c.name.length > 22 ? c.name.slice(0, 22) + '…' : c.name),
    colors: top.map((_, i) => barColors[i % barColors.length])
  }
})

// --- all-time sold category names (for never-sold detection) ---
const allTimeSoldCategoryNames = computed(() => {
  const names = new Set()
  for (const t of txAll.value) {
    for (const it of (t.items || [])) {
      const cat = it.category_name || it.category || ''
      if (cat) names.add(cat.toLowerCase())
    }
  }
  return names
})

// sold category names in current range
const soldCatNamesInRange = computed(() => {
  const names = new Set()
  for (const c of allCategories.value) {
    names.add(c.name.toLowerCase())
  }
  return names
})

// --- stock grouped by category ---
const stockByCategory = computed(() => {
  const map = new Map()
  for (const s of allStocks.value) {
    const cat = (s.category_name || 'Uncategorized').toLowerCase()
    if (!map.has(cat)) map.set(cat, { name: s.category_name || 'Uncategorized', products: [], totalStock: 0, stockCostValue: 0, potentialRevenue: 0 })
    const g = map.get(cat)
    g.products.push(s)
    const qty = Number(s.total_quantity || 0)
    g.totalStock += qty
    g.stockCostValue += qty * Number(s.cost_price || 0)
    g.potentialRevenue += qty * Number(s.selling_price || 0)
  }
  return map
})

const rangeDays = computed(() => Math.max(1, Math.round((rangeEnd.value - rangeStart.value) / 86400000)))

// --- ABC Analysis ---
const abcCategories = computed(() => {
  const sorted = [...allCategories.value].sort((a, b) => b.revenue - a.revenue)
  const total = totalRevenue.value || 1
  let cumulative = 0
  return sorted.map(c => {
    cumulative += c.revenue
    const cumulativePct = (cumulative / total) * 100
    let grade, gradeColor
    if (cumulativePct <= 80) { grade = 'A'; gradeColor = 'success' }
    else if (cumulativePct <= 95) { grade = 'B'; gradeColor = 'warning' }
    else { grade = 'C'; gradeColor = 'error' }
    return { ...c, cumulativePct, grade, gradeColor }
  })
})

const abcSummary = computed(() => {
  const groups = {
    A: { grade: 'A', color: 'success', description: 'Top 80% revenue — vital few', count: 0, revenue: 0, pct: 0 },
    B: { grade: 'B', color: 'warning', description: 'Next 15% revenue — useful many', count: 0, revenue: 0, pct: 0 },
    C: { grade: 'C', color: 'error', description: 'Bottom 5% revenue — trivial many', count: 0, revenue: 0, pct: 0 }
  }
  const total = totalRevenue.value || 1
  abcCategories.value.forEach(c => {
    const g = groups[c.grade]
    g.count++
    g.revenue += c.revenue
  })
  Object.values(groups).forEach(g => { g.pct = (g.revenue / total) * 100 })
  return Object.values(groups)
})

const abcFiltered = computed(() => {
  if (!abcFilter.value) return abcCategories.value
  return abcCategories.value.filter(c => c.grade === abcFilter.value)
})

const abcPaged = computed(() => {
  const start = (abcPage.value - 1) * pageSize
  return abcFiltered.value.slice(start, start + pageSize)
})

// --- Slow Moving Categories ---
const slowMovingCategories = computed(() => {
  const results = []
  for (const [catKey, catStock] of stockByCategory.value) {
    if (catStock.totalStock <= 0) continue
    const sold = allCategories.value.find(c => c.name.toLowerCase() === catKey)
    const qtySold = sold ? sold.qty : 0
    const revenue = sold ? sold.revenue : 0
    if (qtySold <= slowThreshold.value) {
      results.push({
        name: catStock.name,
        productCount: catStock.products.length,
        totalStock: catStock.totalStock,
        qtySold,
        revenue,
        stockCostValue: catStock.stockCostValue,
      })
    }
  }
  return results.sort((a, b) => a.qtySold - b.qtySold)
})

const slowCatStockValue = computed(() => slowMovingCategories.value.reduce((s, c) => s + c.stockCostValue, 0))
const slowCatPaged = computed(() => {
  const start = (slowPage.value - 1) * pageSize
  return slowMovingCategories.value.slice(start, start + pageSize)
})

// --- Never Sold Categories ---
const neverSoldCategories = computed(() => {
  const results = []
  for (const [catKey, catStock] of stockByCategory.value) {
    if (!allTimeSoldCategoryNames.value.has(catKey)) {
      results.push({
        name: catStock.name,
        productCount: catStock.products.length,
        totalStock: catStock.totalStock,
        stockCostValue: catStock.stockCostValue,
        potentialRevenue: catStock.potentialRevenue,
      })
    }
  }
  return results.sort((a, b) => b.stockCostValue - a.stockCostValue)
})

const neverSoldCatValue = computed(() => neverSoldCategories.value.reduce((s, c) => s + c.stockCostValue, 0))
const neverSoldCatPaged = computed(() => {
  const start = (neverPage.value - 1) * pageSize
  return neverSoldCategories.value.slice(start, start + pageSize)
})

// --- Dead Stock Categories (stock but zero sales in period) ---
const deadStockCategories = computed(() => {
  const results = []
  for (const [catKey, catStock] of stockByCategory.value) {
    if (catStock.totalStock <= 0) continue
    if (!soldCatNamesInRange.value.has(catKey)) {
      results.push({
        name: catStock.name,
        productCount: catStock.products.length,
        totalStock: catStock.totalStock,
        stockCostValue: catStock.stockCostValue,
        potentialRevenue: catStock.potentialRevenue,
      })
    }
  }
  return results.sort((a, b) => b.stockCostValue - a.stockCostValue)
})

const deadStockCatValue = computed(() => deadStockCategories.value.reduce((s, c) => s + c.stockCostValue, 0))
const deadStockCatPaged = computed(() => {
  const start = (deadPage.value - 1) * pageSize
  return deadStockCategories.value.slice(start, start + pageSize)
})

function exportCsv() {
  const rows = [['Rank', 'Category', 'Products', 'Quantity', 'Orders', 'Revenue', 'Avg Order', 'Share %']]
  filteredCategories.value.forEach((c, i) => {
    rows.push([i + 1, c.name, c.products, c.qty, c.orders, c.revenue.toFixed(2), c.avgOrder.toFixed(2), c.share.toFixed(2)])
  })
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `category-sales-${new Date().toISOString().slice(0, 10)}.csv`
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
.legend-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.expanded-row { background: rgba(var(--v-theme-on-surface), 0.03); }
.w-100 { width: 100%; }
</style>
